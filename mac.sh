#!/usr/bin/env bash
#
# macOS initialization script.
#
#   ./mac.sh             pick what to install in an interactive list, then install it
#   ./mac.sh --yes       skip the picker and install the default selection
#   ./mac.sh --dry-run   print the install commands instead of running them
#
# Apps to install live in plain-text files under ./apps/. To add or remove
# an app, just edit the corresponding file:
#   apps/formulae.txt   Homebrew formulae
#   apps/casks.txt      Homebrew casks
#   apps/mas.txt        Mac App Store apps (format: "<id> <name>")
#   apps/npm.txt        npm global packages
#
# Inside those files:
#   - `#` starts a comment and blank lines are ignored, so commenting a line
#     out drops that app entirely.
#   - A `# === Title ===` line starts a new section in the picker.
#   - A `?` in front of an entry makes it optional: the picker shows it
#     unchecked, and --yes skips it.
#
# The picker is plain bash 3.2, so it runs on a fresh Mac before Homebrew.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APPS_DIR="$SCRIPT_DIR/apps"

ASSUME_YES=false
DRY_RUN=false

usage() {
    cat <<'EOF'
Usage: ./mac.sh [options]

Opens a picker to choose what to install, then installs the selection.
Without a terminal (e.g. piped or in CI) the default selection is installed.

Options:
  -y, --yes       skip the picker and install the default selection
  -n, --dry-run   print the install commands instead of running them
  -h, --help      show this help

Picker keys:
  up/down, j/k      move               space     toggle an item or a whole section
  left/right, h/l   fold / unfold      a n d     select all / none / defaults
  enter             review and install q         quit without installing
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)     ASSUME_YES=true ;;
        -n|--dry-run) DRY_RUN=true ;;
        -h|--help)    usage; exit 0 ;;
        *)            echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

# Run a command, or only print it in --dry-run mode.
run() {
    if $DRY_RUN; then
        echo "  + $*"
        return 0
    fi
    "$@"
}

# Put Homebrew on PATH if it is installed but this shell does not know it yet
# (Apple Silicon installs to /opt/homebrew, which is not on the default PATH).
load_brew_env() {
    local b
    if command -v brew &> /dev/null; then
        return 0
    fi
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$b" ]; then
            eval "$("$b" shellenv)"
            return 0
        fi
    done
}

# ---------------------------------------------------------------------------
# Installers
# ---------------------------------------------------------------------------

failed_installs=()
install_started=false
script_completed=false

install_formula() {
    local pkg="$1"
    log "Installing formula: $pkg"
    if ! run brew install "$pkg"; then
        log "Warning: Failed to install formula '$pkg'"
        failed_installs+=("brew install $pkg")
    fi
}

install_cask() {
    local pkg="$1"
    log "Installing cask: $pkg"
    if ! run brew install --cask "$pkg"; then
        log "Warning: Failed to install cask '$pkg'"
        failed_installs+=("brew install --cask $pkg")
    fi
}

install_mas_app() {
    local id="$1"
    local name="$2"
    log "Installing MAS app: $name ($id)"
    if ! run mas install "$id"; then
        log "Warning: Failed to install MAS app '$name'"
        failed_installs+=("mas install $id  # $name")
    fi
}

install_npm_package() {
    local pkg="$1"
    log "Installing npm global package: $pkg"
    if ! run npm install -g "$pkg"; then
        log "Warning: Failed to install npm package '$pkg'"
        failed_installs+=("npm install -g $pkg")
    fi
}

# ---------------------------------------------------------------------------
# Item model
# ---------------------------------------------------------------------------
# Everything the picker can toggle is an "item", stored across these parallel
# arrays because bash 3.2 has no associative arrays. Items are grouped into
# sections, and each section's items are contiguous.

ITEM_KIND=()        # step | mas | formula | cask | npm
ITEM_ID=()          # argument passed to the installer
ITEM_LABEL=()       # name shown to the user
ITEM_NOTE=()        # inline comment from the list file
ITEM_DEFAULT=()     # 1 = selected by default
ITEM_SEL=()         # 1 = currently selected
ITEM_INSTALLED=()   # 1 = already on this Mac
ITEM_GROUP=()       # index into GROUP_*

GROUP_TITLE=()
GROUP_FIRST=()      # index of the section's first item
GROUP_LAST=()       # index of the section's last item
GROUP_OPEN=()       # 1 = expanded in the picker

CUR_GROUP=0
HAS_INSTALLED=0
LABEL_W=10

add_group() {
    GROUP_TITLE+=("$1")
    GROUP_FIRST+=("${#ITEM_ID[@]}")
    GROUP_LAST+=("${#ITEM_ID[@]}")
    GROUP_OPEN+=(1)
    CUR_GROUP=$(( ${#GROUP_TITLE[@]} - 1 ))
}

# add_item <kind> <id> <label> <note> <default 1|0>
add_item() {
    GROUP_LAST[$CUR_GROUP]=${#ITEM_ID[@]}
    ITEM_KIND+=("$1")
    ITEM_ID+=("$2")
    ITEM_LABEL+=("$3")
    ITEM_NOTE+=("$4")
    ITEM_DEFAULT+=("$5")
    ITEM_SEL+=("$5")
    ITEM_INSTALLED+=(0)
    ITEM_GROUP+=("$CUR_GROUP")
}

# Strip leading and trailing whitespace from $1 into $TRIMMED (no subshell).
trim() {
    TRIMMED="${1#"${1%%[![:space:]]*}"}"
    TRIMMED="${TRIMMED%"${TRIMMED##*[![:space:]]}"}"
}

SECTION_RE='^[[:space:]]*#[[:space:]]*===[[:space:]]*(.*[^[:space:]])[[:space:]]*===[[:space:]]*$'

# load_list <kind> <file> <title>
# A `# === Name ===` line starts a section. A section only becomes a picker
# group once it has an entry, so memo-only sections stay out of the picker.
load_list() {
    local kind="$1" file="$2" title="$3"
    local line entry note default id label section="" group_section="" have_group=false
    if [ ! -f "$file" ]; then
        log "Warning: list file not found: $file"
        return 0
    fi
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ $line =~ $SECTION_RE ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi
        trim "$line"
        line="$TRIMMED"
        case "$line" in ''|'#'*) continue ;; esac

        note=""
        case "$line" in *'#'*) trim "${line#*#}"; note="$TRIMMED" ;; esac
        trim "${line%%#*}"
        entry="$TRIMMED"

        default=1
        case "$entry" in
            '?'*) default=0; trim "${entry#\?}"; entry="$TRIMMED" ;;
        esac
        if [ -z "$entry" ]; then
            continue
        fi

        if ! $have_group || [ "$group_section" != "$section" ]; then
            if [ -n "$section" ]; then
                add_group "$title · $section"
            else
                add_group "$title"
            fi
            group_section="$section"
            have_group=true
        fi

        if [ "$kind" = mas ]; then
            id="${entry%%[[:space:]]*}"
            trim "${entry#"$id"}"
            label="${TRIMMED:-$id}"
            note="$id${note:+ · $note}"
        else
            id="$entry"
            label="$entry"
        fi
        add_item "$kind" "$id" "$label" "$note" "$default"
    done < "$file"
}

load_items() {
    local i n
    add_group "Homebrew maintenance"
    add_item step update  "brew update"  "refresh the package index" 1
    add_item step upgrade "brew upgrade" "upgrade everything already installed, can be slow" 1
    add_item step cleanup "brew cleanup" "remove old versions and caches at the end" 1

    load_list mas     "$APPS_DIR/mas.txt"      "App Store"
    load_list formula "$APPS_DIR/formulae.txt" "Formulae"
    load_list cask    "$APPS_DIR/casks.txt"    "Casks"
    load_list npm     "$APPS_DIR/npm.txt"      "npm"

    for ((i = 0; i < ${#ITEM_ID[@]}; i++)); do
        n=${#ITEM_LABEL[$i]}
        if [ "$n" -gt "$LABEL_W" ]; then LABEL_W=$n; fi
    done
    if [ "$LABEL_W" -gt 28 ]; then LABEL_W=28; fi
}

# Mark items that are already on this Mac so the picker can say so.
detect_installed() {
    local formulae="" casks="" mas_ids="" npm_pkgs="" haystack i
    if command -v brew &> /dev/null; then
        formulae="$(brew list --formula -1 2>/dev/null || true)"
        casks="$(brew list --cask -1 2>/dev/null || true)"
    fi
    if command -v mas &> /dev/null; then
        mas_ids="$(mas list 2>/dev/null | awk '{print $1}' || true)"
    fi
    if command -v npm &> /dev/null; then
        npm_pkgs="$(npm ls -g --depth=0 --parseable 2>/dev/null | sed -n 's|.*/node_modules/||p' || true)"
    fi
    for ((i = 0; i < ${#ITEM_ID[@]}; i++)); do
        case "${ITEM_KIND[$i]}" in
            formula) haystack="$formulae" ;;
            cask)    haystack="$casks" ;;
            mas)     haystack="$mas_ids" ;;
            npm)     haystack="$npm_pkgs" ;;
            *)       continue ;;
        esac
        case $'\n'"$haystack"$'\n' in
            *$'\n'"${ITEM_ID[$i]}"$'\n'*) ITEM_INSTALLED[$i]=1; HAS_INSTALLED=1 ;;
        esac
    done
}

is_selected() {   # is_selected <kind> <id>
    local i
    for ((i = 0; i < ${#ITEM_ID[@]}; i++)); do
        if [ "${ITEM_KIND[$i]}" = "$1" ] && [ "${ITEM_ID[$i]}" = "$2" ]; then
            [ "${ITEM_SEL[$i]}" = 1 ]
            return
        fi
    done
    return 1
}

any_selected() {  # any_selected <kind>
    local i
    for ((i = 0; i < ${#ITEM_ID[@]}; i++)); do
        if [ "${ITEM_KIND[$i]}" = "$1" ] && [ "${ITEM_SEL[$i]}" = 1 ]; then
            return 0
        fi
    done
    return 1
}

count_selected() {
    local i
    SEL_COUNT=0
    for ((i = 0; i < ${#ITEM_ID[@]}; i++)); do
        if [ "${ITEM_SEL[$i]}" = 1 ]; then SEL_COUNT=$((SEL_COUNT + 1)); fi
    done
}

group_counts() {  # group_counts <group>  ->  $GC_SEL / $GC_ALL
    local i
    GC_SEL=0
    GC_ALL=$(( GROUP_LAST[$1] - GROUP_FIRST[$1] + 1 ))
    for ((i = GROUP_FIRST[$1]; i <= GROUP_LAST[$1]; i++)); do
        if [ "${ITEM_SEL[$i]}" = 1 ]; then GC_SEL=$((GC_SEL + 1)); fi
    done
}

set_group() {     # set_group <group> <1|0>
    local i
    for ((i = GROUP_FIRST[$1]; i <= GROUP_LAST[$1]; i++)); do
        ITEM_SEL[$i]=$2
    done
}

set_all() {       # set_all <1|0>
    local i
    for ((i = 0; i < ${#ITEM_ID[@]}; i++)); do
        ITEM_SEL[$i]=$1
    done
}

reset_defaults() {
    local i
    for ((i = 0; i < ${#ITEM_ID[@]}; i++)); do
        ITEM_SEL[$i]=${ITEM_DEFAULT[$i]}
    done
}

# ---------------------------------------------------------------------------
# Interactive picker
# ---------------------------------------------------------------------------
# All picker I/O goes through fd 3 on /dev/tty, so `./mac.sh | tee log`
# still shows the picker while the install log goes to the pipe.

C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_DIM=$'\033[2m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_CYAN=$'\033[36m'

TTY_OPEN=false
TUI_ACTIVE=false
TUI_STTY=""
ROWS=()           # visible rows: "g<group>" or "i<item>"
CURSOR=0
TOP=0
BODY=1
MSG=""
KEY=""
FOOTER=""
TUI_SIZE=""       # "rows cols" of the last frame, to spot window resizes

make_footer() {
    local pair
    FOOTER=" "
    for pair in "↑↓:move" "space:toggle" "←→:fold" "a:all" "n:none" "d:defaults" "enter:continue" "q:quit"; do
        FOOTER+="${C_BOLD}${pair%%:*}${C_RESET} ${C_DIM}${pair#*:}${C_RESET}   "
    done
}

tui_enter() {
    TUI_STTY="$(stty -g <&3)"
    stty -echo -icanon min 1 time 0 <&3
    # alternate screen, no line wrap (long notes are clipped), hide cursor
    printf '\033[?1049h\033[?7l\033[?25l\033[H\033[2J' >&3
    TUI_ACTIVE=true
    # bash 3.2 runs this trap while `read` is blocked, so the redraw is
    # immediate; bash 4+ runs it once the 1-second polling read returns.
    trap 'if $TUI_ACTIVE; then tui_draw; fi' WINCH
}

tui_leave() {
    if ! $TUI_ACTIVE; then
        return 0
    fi
    trap - WINCH
    printf '\033[?25h\033[?7h\033[?1049l' >&3
    if [ -n "$TUI_STTY" ]; then
        stty "$TUI_STTY" <&3
    fi
    TUI_ACTIVE=false
}

hrule() {         # hrule <width>  ->  $HR
    local n=$1
    if [ "$n" -lt 0 ]; then n=0; fi
    printf -v HR '%*s' "$n" ''
    HR="${HR// /─}"
}

build_rows() {
    local g i
    ROWS=()
    for ((g = 0; g < ${#GROUP_TITLE[@]}; g++)); do
        ROWS+=("g$g")
        if [ "${GROUP_OPEN[$g]}" = 1 ]; then
            for ((i = GROUP_FIRST[g]; i <= GROUP_LAST[g]; i++)); do
                ROWS+=("i$i")
            done
        fi
    done
}

cursor_group() {  # -> $CG, the section of the row under the cursor
    local row="${ROWS[$CURSOR]}" i
    case "$row" in
        g*) CG=${row#g} ;;
        *)  i=${row#i}; CG=${ITEM_GROUP[$i]} ;;
    esac
}

jump_to_group() {
    local r
    for ((r = 0; r < ${#ROWS[@]}; r++)); do
        if [ "${ROWS[$r]}" = "g$1" ]; then
            CURSOR=$r
            return 0
        fi
    done
}

render_row() {    # render_row <row index>  ->  $ROW_OUT
    local r=$1 row="${ROWS[$1]}" ptr=" " hi="" g i box arrow label inst
    if [ "$r" -eq "$CURSOR" ]; then
        ptr="${C_CYAN}❯${C_RESET}"
        hi="${C_CYAN}${C_BOLD}"
    fi
    case "$row" in
        g*)
            g=${row#g}
            group_counts "$g"
            if [ "$GC_SEL" -eq "$GC_ALL" ]; then
                box="[${C_GREEN}x${C_RESET}]"
            elif [ "$GC_SEL" -eq 0 ]; then
                box="[ ]"
            else
                box="[${C_YELLOW}-${C_RESET}]"
            fi
            if [ "${GROUP_OPEN[$g]}" = 1 ]; then arrow="▾"; else arrow="▸"; fi
            ROW_OUT=" $ptr $arrow $box ${C_BOLD}${hi}${GROUP_TITLE[$g]}${C_RESET}  ${C_DIM}${GC_SEL}/${GC_ALL}${C_RESET}"
            ;;
        i*)
            i=${row#i}
            if [ "${ITEM_SEL[$i]}" = 1 ]; then box="[${C_GREEN}x${C_RESET}]"; else box="[ ]"; fi
            printf -v label "%-${LABEL_W}s" "${ITEM_LABEL[$i]}"
            inst=""
            if [ "$HAS_INSTALLED" = 1 ]; then
                if [ "${ITEM_INSTALLED[$i]}" = 1 ]; then
                    inst="${C_GREEN}installed${C_RESET}  "
                else
                    inst="           "
                fi
            fi
            ROW_OUT=" $ptr     $box ${hi}${label}${C_RESET}  ${inst}${C_DIM}${ITEM_NOTE[$i]}${C_RESET}"
            ;;
    esac
}

tui_draw() {
    local size lines cols last r out left right padn pad
    size="$(stty size <&3 2>/dev/null || true)"
    TUI_SIZE="$size"
    lines="${size% *}"
    cols="${size#* }"
    case "$lines$cols" in ''|*[!0-9]*) lines=24; cols=80 ;; esac

    BODY=$(( lines - 4 ))
    if [ "$BODY" -lt 1 ]; then BODY=1; fi
    last=$(( ${#ROWS[@]} - 1 ))
    if [ "$CURSOR" -gt "$last" ]; then CURSOR=$last; fi
    if [ "$CURSOR" -lt "$TOP" ]; then TOP=$CURSOR; fi
    if [ "$CURSOR" -ge $(( TOP + BODY )) ]; then TOP=$(( CURSOR - BODY + 1 )); fi
    if [ "$TOP" -gt $(( ${#ROWS[@]} - BODY )) ]; then TOP=$(( ${#ROWS[@]} - BODY )); fi
    if [ "$TOP" -lt 0 ]; then TOP=0; fi

    count_selected
    left=" macOS init · choose what to install"
    right="$SEL_COUNT/${#ITEM_ID[@]} selected "
    if $DRY_RUN; then right="dry run · $right"; fi
    padn=$(( cols - ${#left} - ${#right} ))
    if [ "$padn" -lt 1 ]; then padn=1; fi
    printf -v pad '%*s' "$padn" ''

    out=$'\033[H'"${C_BOLD}${left}${C_RESET}${pad}${C_DIM}${right}${C_RESET}"$'\033[K\n'
    if [ "$TOP" -gt 0 ]; then
        hrule $(( cols - 8 )); out+="${C_DIM} ▲ more ${HR}${C_RESET}"
    else
        hrule "$cols"; out+="${C_DIM}${HR}${C_RESET}"
    fi
    out+=$'\033[K\n'
    for ((r = TOP; r < TOP + BODY; r++)); do
        if [ "$r" -le "$last" ]; then
            render_row "$r"
            out+="$ROW_OUT"
        fi
        out+=$'\033[K\n'
    done
    if [ $(( TOP + BODY )) -le "$last" ]; then
        hrule $(( cols - 8 )); out+="${C_DIM} ▼ more ${HR}${C_RESET}"
    else
        hrule "$cols"; out+="${C_DIM}${HR}${C_RESET}"
    fi
    out+=$'\033[K\n'
    if [ -n "$MSG" ]; then
        out+=" ${C_YELLOW}${MSG}${C_RESET}"
    else
        out+="$FOOTER"
    fi
    out+=$'\033[K'
    printf '%s' "$out" >&3
}

# Read one key press into $KEY. Returns read's status: >128 means the read
# timed out (bash 4+ polls once a second to notice resizes), 1 means EOF.
# bash 3.2 cannot tell a timeout from EOF, so it blocks and relies on the
# WINCH trap instead.
tui_read_key() {
    local c c2 c3 c4
    KEY=""
    if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
        IFS= read -rsn1 -t 1 -u 3 c || return $?
    else
        IFS= read -rsn1 -u 3 c || return $?
    fi
    case "$c" in
        $'\033')
            # bash 3.2 only takes whole-second timeouts; arrow keys arrive at once
            if ! IFS= read -rsn1 -t 1 -u 3 c2; then KEY=esc; return 0; fi
            if [ "$c2" != "[" ] && [ "$c2" != "O" ]; then KEY=other; return 0; fi
            if ! IFS= read -rsn1 -t 1 -u 3 c3; then KEY=other; return 0; fi
            case "$c3" in
                A) KEY=up ;;
                B) KEY=down ;;
                C) KEY=right ;;
                D) KEY=left ;;
                H) KEY=home ;;
                F) KEY=end ;;
                [0-9])
                    c4=""
                    IFS= read -rsn1 -t 1 -u 3 c4 || true
                    case "$c3$c4" in
                        5~) KEY=pgup ;;
                        6~) KEY=pgdn ;;
                        1~|7~) KEY=home ;;
                        4~|8~) KEY=end ;;
                        *) KEY=other ;;
                    esac
                    ;;
                *) KEY=other ;;
            esac
            ;;
        ''|$'\r'|$'\n') KEY=enter ;;
        ' ')  KEY=space ;;
        $'\t') KEY=tab ;;
        *)    KEY="$c" ;;
    esac
}

tui_move() {
    local n=$(( CURSOR + $1 )) last=$(( ${#ROWS[@]} - 1 ))
    if [ "$n" -lt 0 ]; then n=0; fi
    if [ "$n" -gt "$last" ]; then n=$last; fi
    CURSOR=$n
}

tui_toggle() {
    local row="${ROWS[$CURSOR]}" i g
    case "$row" in
        i*)
            i=${row#i}
            if [ "${ITEM_SEL[$i]}" = 1 ]; then ITEM_SEL[$i]=0; else ITEM_SEL[$i]=1; fi
            ;;
        g*)
            g=${row#g}
            group_counts "$g"
            if [ "$GC_SEL" -eq "$GC_ALL" ]; then set_group "$g" 0; else set_group "$g" 1; fi
            ;;
    esac
}

tui_fold() {      # tui_fold open|close|toggle
    local want
    cursor_group
    case "$1" in
        open)   want=1 ;;
        close)  want=0 ;;
        *)      want=$(( 1 - GROUP_OPEN[CG] )) ;;
    esac
    if [ "${GROUP_OPEN[$CG]}" = "$want" ]; then
        return 0
    fi
    GROUP_OPEN[$CG]=$want
    build_rows
    jump_to_group "$CG"
}

# Returns 0 when the user confirms a selection, 1 when they quit.
tui_pick() {
    local rc redraw=true
    tui_enter
    build_rows
    while true; do
        if $redraw; then tui_draw; fi
        redraw=true
        rc=0
        tui_read_key || rc=$?
        if [ "$rc" -ne 0 ]; then
            if [ "$rc" -gt 128 ]; then
                # poll timeout: redraw only if the window changed size
                if [ "$(stty size <&3 2>/dev/null || true)" = "$TUI_SIZE" ]; then redraw=false; fi
                continue
            fi
            return 1                                    # terminal closed
        fi
        MSG=""
        case "$KEY" in
            up|k)       tui_move -1 ;;
            down|j)     tui_move 1 ;;
            pgup)       tui_move $(( 0 - BODY )) ;;
            pgdn)       tui_move "$BODY" ;;
            home|g)     CURSOR=0 ;;
            end|G)      CURSOR=$(( ${#ROWS[@]} - 1 )) ;;
            space|x)    tui_toggle ;;
            right|l)    tui_fold open ;;
            left|h)     tui_fold close ;;
            tab)        tui_fold toggle ;;
            a|A)        set_all 1 ;;
            n|N)        set_all 0 ;;
            d|D)        reset_defaults ;;
            enter)
                count_selected
                if [ "$SEL_COUNT" -gt 0 ]; then return 0; fi
                MSG="Nothing selected. Press space to pick something, or q to quit."
                ;;
            q|Q|esc)    return 1 ;;
        esac
    done
}

term_cols() {     # -> $TERM_COLS
    local size=""
    if $TTY_OPEN; then size="$(stty size <&3 2>/dev/null || true)"; fi
    TERM_COLS="${size#* }"
    case "$TERM_COLS" in ''|*[!0-9]*) TERM_COLS=80 ;; esac
}

# wrap_words <indent> <width> <word>...  prints the words wrapped to width
wrap_words() {
    local indent=$1 width=$2 pad line="" w
    shift 2
    printf -v pad '%*s' "$indent" ''
    for w in "$@"; do
        if [ -n "$line" ] && [ $(( indent + ${#line} + 2 + ${#w} )) -gt "$width" ]; then
            echo "$pad$line"
            line=""
        fi
        if [ -n "$line" ]; then line+="  $w"; else line="$w"; fi
    done
    if [ -n "$line" ]; then echo "$pad$line"; fi
}

print_selection() {
    local g i total=0
    local -a names
    term_cols
    echo ""
    for ((g = 0; g < ${#GROUP_TITLE[@]}; g++)); do
        names=()
        for ((i = GROUP_FIRST[g]; i <= GROUP_LAST[g]; i++)); do
            if [ "${ITEM_SEL[$i]}" = 1 ]; then names+=("${ITEM_LABEL[$i]}"); fi
        done
        if [ "${#names[@]}" -eq 0 ]; then
            continue
        fi
        total=$(( total + ${#names[@]} ))
        echo "  ${GROUP_TITLE[$g]} (${#names[@]})"
        wrap_words 6 "$TERM_COLS" "${names[@]}"
    done
    echo ""
    log "Selected $total of ${#ITEM_ID[@]} item(s)."
}

choose_items() {
    local answer
    if $ASSUME_YES; then
        print_selection
        return 0
    fi
    if ! ( : <>/dev/tty ) 2>/dev/null; then
        log "No terminal available, installing the default selection."
        print_selection
        return 0
    fi
    exec 3<>/dev/tty
    TTY_OPEN=true
    printf 'Checking what is already installed...\n' >&3
    detect_installed
    make_footer
    while true; do
        if ! tui_pick; then
            tui_leave
            log "Cancelled, nothing was installed."
            exit 0
        fi
        tui_leave
        print_selection
        printf 'Proceed? [Y/n]  (e = back to the picker) ' >&3
        answer=""
        IFS= read -r -u 3 answer || answer=n
        case "$answer" in
            ''|y|Y|yes|YES) return 0 ;;
            e|E) continue ;;
            *) log "Cancelled, nothing was installed."; exit 0 ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Install run
# ---------------------------------------------------------------------------

print_summary() {
    echo ""
    echo "============================================================"
    if ! $script_completed; then
        log "Script exited early due to a fatal error."
    fi
    if $DRY_RUN; then
        log "Dry run finished, nothing was installed."
    elif [ ${#failed_installs[@]} -eq 0 ]; then
        log "All tracked installations completed successfully!"
    else
        log "Installation completed with ${#failed_installs[@]} failure(s)."
        echo ""
        echo "The following installs failed. To retry, run the commands below:"
        echo ""
        for cmd in "${failed_installs[@]}"; do
            echo "  $cmd"
        done
        echo ""
    fi
    echo "============================================================"
}

on_exit() {
    tui_leave
    if $install_started; then
        print_summary
    fi
}

install_selected() {   # install_selected <kind>
    local kind="$1" i
    for ((i = 0; i < ${#ITEM_ID[@]}; i++)); do
        if [ "${ITEM_KIND[$i]}" != "$kind" ] || [ "${ITEM_SEL[$i]}" != 1 ]; then
            continue
        fi
        case "$kind" in
            mas)     install_mas_app "${ITEM_ID[$i]}" "${ITEM_LABEL[$i]}" ;;
            formula) install_formula "${ITEM_ID[$i]}" ;;
            cask)    install_cask "${ITEM_ID[$i]}" ;;
            npm)     install_npm_package "${ITEM_ID[$i]}" ;;
        esac
    done
}

run_install() {
    install_started=true
    log "Starting macOS initialization script..."
    if $DRY_RUN; then
        log "Dry run: commands are printed, not executed."
    fi

    # Xcode command line tools
    if ! xcode-select -p &> /dev/null; then
        log "Installing Xcode command line tools..."
        run xcode-select --install 2>/dev/null || true
    else
        log "Xcode command line tools already installed"
    fi

    # Administrator privileges with keep-alive
    if $DRY_RUN; then
        log "Skipping sudo in dry run"
    else
        log "Requesting administrator privileges..."
        sudo -v || error "Failed to obtain administrator privileges"

        log "Setting up sudo keep-alive..."
        while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    fi

    # Homebrew
    if ! command -v brew &> /dev/null; then
        log "Installing Homebrew..."
        if $DRY_RUN; then
            echo '  + /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        else
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
                || error "Failed to install Homebrew"
            load_brew_env
            command -v brew &> /dev/null || error "Homebrew installed but brew is not on PATH"
        fi
    else
        log "Homebrew already installed"
    fi

    if is_selected step update; then
        log "Updating Homebrew..."
        run brew update || log "Warning: brew update failed"
    fi
    if is_selected step upgrade; then
        log "Upgrading installed packages..."
        run brew upgrade || log "Warning: brew upgrade failed"
    fi

    if any_selected mas; then
        log "Installing Mac App Store CLI..."
        install_formula mas
        log "Installing Mac App Store applications..."
        install_selected mas
    fi
    if any_selected formula; then
        log "Installing Homebrew formulae..."
        install_selected formula
    fi
    if any_selected cask; then
        log "Installing Homebrew casks..."
        install_selected cask
    fi
    if any_selected npm; then
        log "Installing npm global packages..."
        install_selected npm
    fi

    if is_selected step cleanup; then
        log "Cleaning up Homebrew..."
        run brew cleanup || log "Warning: Homebrew cleanup failed"
    fi

    script_completed=true
    log "macOS initialization script completed!"
}

trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

load_brew_env
load_items
choose_items
run_install
