#!/usr/bin/env bash
#
# macOS initialization script.
#
# Apps to install live in plain-text files under ./apps/. To add or remove
# an app, just edit the corresponding file:
#   apps/formulae.txt   Homebrew formulae
#   apps/casks.txt      Homebrew casks
#   apps/mas.txt        Mac App Store apps (format: "<id> <name>")
#
# Inside those files, `#` starts a comment and blank lines are ignored, so
# you can comment a line out to temporarily skip an app.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
APPS_DIR="$SCRIPT_DIR/apps"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

failed_installs=()
script_completed=false

install_formula() {
    local pkg="$1"
    log "Installing formula: $pkg"
    if ! brew install "$pkg"; then
        log "Warning: Failed to install formula '$pkg'"
        failed_installs+=("brew install $pkg")
    fi
}

install_cask() {
    local pkg="$1"
    log "Installing cask: $pkg"
    if ! brew install --cask "$pkg"; then
        log "Warning: Failed to install cask '$pkg'"
        failed_installs+=("brew install --cask $pkg")
    fi
}

install_mas_app() {
    local id="$1"
    local name="$2"
    log "Installing MAS app: $name ($id)"
    if ! mas install "$id"; then
        log "Warning: Failed to install MAS app '$name'"
        failed_installs+=("mas install $id  # $name")
    fi
}

# Read a list file, yielding one non-comment, non-blank, trimmed line at a
# time on stdout. `#` to end-of-line is stripped, so inline comments work.
read_list() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log "Warning: list file not found: $file"
        return 0
    fi
    sed -E -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]+//' -e 's/[[:space:]]+$//' "$file" \
        | grep -v '^$' || true
}

install_formulae_from() {
    local file="$1"
    local pkg
    while IFS= read -r pkg; do
        install_formula "$pkg"
    done < <(read_list "$file")
}

install_casks_from() {
    local file="$1"
    local pkg
    while IFS= read -r pkg; do
        install_cask "$pkg"
    done < <(read_list "$file")
}

install_mas_from() {
    local file="$1"
    local line id name
    while IFS= read -r line; do
        # Split into <id> <name>. If no name, fall back to the id.
        id="${line%%[[:space:]]*}"
        name="${line#"$id"}"
        name="${name#"${name%%[![:space:]]*}"}"
        [ -z "$name" ] && name="$id"
        install_mas_app "$id" "$name"
    done < <(read_list "$file")
}

print_summary() {
    echo ""
    echo "============================================================"
    if ! $script_completed; then
        log "Script exited early due to a fatal error."
    fi
    if [ ${#failed_installs[@]} -eq 0 ]; then
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

trap print_summary EXIT

log "Starting macOS initialization script..."

# Xcode command line tools
if ! xcode-select -p &> /dev/null; then
    log "Installing Xcode command line tools..."
    xcode-select --install 2>/dev/null || true
else
    log "Xcode command line tools already installed"
fi

# Administrator privileges with keep-alive
log "Requesting administrator privileges..."
sudo -v || error "Failed to obtain administrator privileges"

log "Setting up sudo keep-alive..."
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Homebrew
if ! command -v brew &> /dev/null; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || error "Failed to install Homebrew"
else
    log "Homebrew already installed"
fi

log "Updating Homebrew..."
brew update || log "Warning: brew update failed"
brew upgrade || log "Warning: brew upgrade failed"

# Mac App Store CLI (required for any apps in apps/mas.txt)
log "Installing Mac App Store CLI..."
install_formula mas

# Install everything from the app lists
log "Installing Mac App Store applications from $APPS_DIR/mas.txt..."
install_mas_from "$APPS_DIR/mas.txt"

log "Installing Homebrew formulae from $APPS_DIR/formulae.txt..."
install_formulae_from "$APPS_DIR/formulae.txt"

log "Installing Homebrew casks from $APPS_DIR/casks.txt..."
install_casks_from "$APPS_DIR/casks.txt"

# Cleanup
log "Cleaning up Homebrew..."
brew cleanup || log "Warning: Homebrew cleanup failed"

script_completed=true
log "macOS initialization script completed!"
