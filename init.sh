#!/usr/bin/env bash
#
# macbook-init — bootstrap a fresh Mac.
# Safe to re-run: every step checks state before changing anything.

# -e: exit on any failed command. -u: error on unset variables.
# -o pipefail: a failing stage in a pipeline fails the whole pipeline.
set -euo pipefail

# Prints a bold blue "==> message" section header.
log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

# --- Xcode Command Line Tools ---------------------------------------------
# Needed before anything below that touches git (including cloning this repo
# below, when run via curl).

if xcode-select -p &>/dev/null; then
  log "Xcode Command Line Tools already installed"
else
  log "Installing Xcode Command Line Tools"

  # Placeholder file that makes softwareupdate treat this as an unattended
  # background install instead of popping the interactive GUI dialog.
  CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  touch "$CLT_PLACEHOLDER"
  CLT_PACKAGE="$(softwareupdate -l 2>/dev/null | grep -B 1 "Command Line Tools" | awk -F'* ' '/^ *\*/ {print $2}' | tail -n1)"

  if [[ -n "$CLT_PACKAGE" ]]; then
    softwareupdate -i "$CLT_PACKAGE"
  else
    echo "  - couldn't find Command Line Tools in the softwareupdate catalog, falling back to interactive install"
    xcode-select --install
  fi

  rm -f "$CLT_PLACEHOLDER"

  until xcode-select -p &>/dev/null; do
    sleep 5
  done
fi

# --- Xcode license -----------------------------------------------------
# Having the Command Line Tools installed doesn't mean the Xcode/SDK license
# has been accepted (happens once Xcode.app is also present). Until it is,
# anything backed by Xcode — including git, used right below — blocks on an
# interactive license prompt. Accepting is a no-op if already accepted.

log "Accepting Xcode license"
sudo xcodebuild -license accept

# --- Repo location -------------------------------------------------------
# When run locally (./init.sh), bin/ lives next to this script. When run via
# `curl | bash`, there's no script file on disk, so clone the repo instead.

REPO_URL="https://github.com/l2ysho/macbook-init.git"
SCRIPT_PATH="${BASH_SOURCE[0]:-}"

if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  REPO_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
else
  REPO_DIR="$HOME/.macbook-init"
  if [[ -d "$REPO_DIR/.git" ]]; then
    log "Updating macbook-init checkout"
    git -C "$REPO_DIR" pull --quiet
  else
    log "Cloning macbook-init"
    git clone --quiet "$REPO_URL" "$REPO_DIR"
  fi
fi

# --- Directories -------------------------------------------------------------

log "Creating directories"
mkdir -p "$HOME/Work/personal"
mkdir -p "$HOME/bin"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# --- Custom scripts ----------------------------------------------------------

log "Installing custom scripts"
for script in "$REPO_DIR"/bin/*; do
  name="$(basename "$script")"
  cp "$script" "$HOME/bin/$name"
  chmod +x "$HOME/bin/$name"
  echo "  - $name"
done

if ! grep -q 'export PATH="\$HOME/bin:\$PATH"' "$HOME/.zshrc" 2>/dev/null; then
  echo "  - adding ~/bin to PATH in .zshrc"
  echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
else
  echo "  - ~/bin already on PATH in .zshrc"
fi

# --- Git identity -----------------------------------------------------------

log "Configuring git identity"

if git config --global user.name &>/dev/null; then
  echo "  - user.name already set"
else
  git config --global user.name "Richard Solár"
fi

if git config --global user.email &>/dev/null; then
  echo "  - user.email already set"
else
  git config --global user.email "solar.richard@gmail.com"
fi

# --- Homebrew ----------------------------------------------------------

if command -v brew &>/dev/null; then
  log "Homebrew already installed, updating"
  brew update
else
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -d /opt/homebrew/bin ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -d /usr/local/bin ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# --- Rosetta 2 -----------------------------------------------------------
# Needed for x86-only apps (e.g. the sony-ps-remote-play cask) on Apple Silicon.

if [[ "$(uname -m)" == "arm64" ]]; then
  if arch -x86_64 /usr/bin/true &>/dev/null; then
    log "Rosetta 2 already installed"
  else
    log "Installing Rosetta 2"
    softwareupdate --install-rosetta --agree-to-license
  fi
fi

# --- Atuin -------------------------------------------------------------

if [[ -x "$HOME/.atuin/bin/atuin" ]]; then
  log "Atuin already installed"
else
  log "Installing Atuin"
  # --non-interactive: skip the history-import and sync-signup prompts (no to both).
  curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive
fi

# --- nvm -----------------------------------------------------------------

if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  log "nvm already installed"
else
  log "Installing nvm"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash
fi

# --- Claude Code -----------------------------------------------------------

if command -v claude &>/dev/null || [[ -x "$HOME/.local/bin/claude" ]]; then
  log "Claude Code already installed"
else
  log "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
fi

# The native installer puts claude in ~/.local/bin, which isn't on PATH by
# default — without this, the command -v check above can't find it on
# re-run and `claude` won't resolve in new shells either.
if ! grep -q 'export PATH="\$HOME/.local/bin:\$PATH"' "$HOME/.zshrc" 2>/dev/null; then
  echo "  - adding ~/.local/bin to PATH in .zshrc"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
else
  echo "  - ~/.local/bin already on PATH in .zshrc"
fi

mkdir -p "$HOME/.claude-work"

if ! grep -q "alias claude-work=" "$HOME/.zshrc" 2>/dev/null; then
  echo "  - adding claude-work alias to .zshrc"
  echo "alias claude-work='CLAUDE_CONFIG_DIR=~/.claude-work claude'" >> "$HOME/.zshrc"
else
  echo "  - claude-work alias already in .zshrc"
fi

# --- Packages ------------------------------------------------------------

FORMULAE=(
  gh
  pyenv
  python@3.12
  xcodes
  ffmpeg
  mas
)

CASKS=(
  1password
  claude
  gitkraken
  google-chrome
  grandperspective
  hush
  hydrogen
  obsidian
  orbstack
  slack
  spotify
  steam
  warp
  zed
  zoom
  sony-ps-remote-play
  wifiman
)

# Mac App Store apps (no cask exists) — requires `mas`, and you must already
# be signed into the App Store (mas cannot authenticate for you).
MAS_APPS=(
  "497799835:Xcode"
  "1549412235:Ethernet Menu"
)

log "Installing formulae"
for pkg in "${FORMULAE[@]}"; do
  if brew list --formula "$pkg" &>/dev/null; then
    echo "  - $pkg already installed"
  else
    echo "  - installing $pkg"
    brew install "$pkg"
  fi
done

log "Installing casks"
for cask in "${CASKS[@]+"${CASKS[@]}"}"; do
  if brew list --cask "$cask" &>/dev/null; then
    echo "  - $cask already installed"
  else
    echo "  - installing $cask"
    brew install --cask "$cask"
  fi
done

log "Cleaning up Homebrew"
brew cleanup

# --- Mac App Store apps ------------------------------------------------------

log "Installing Mac App Store apps"

# Recent mas versions dropped the `account` command (Apple restricted the
# underlying API), so there's no reliable way to pre-check sign-in status.
# Just attempt each install; mas itself reports if you're not signed in.
for entry in "${MAS_APPS[@]+"${MAS_APPS[@]}"}"; do
  id="${entry%%:*}"
  name="${entry#*:}"
  if mas list | grep -q "^$id "; then
    echo "  - $name already installed"
  else
    echo "  - installing $name"
    mas install "$id" || echo "    failed — make sure you're signed into the App Store, then re-run"
  fi
done

# --- macOS defaults --------------------------------------------------------

log "Applying macOS defaults"

# Finder: show hidden (dotfiles) files
defaults write com.apple.finder AppleShowAllFiles -bool true
# Finder: always show file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Finder: show full path in the title bar
defaults write com.apple.finder ShowPathbar -bool true
# Finder: show status bar (item count, disk space)
defaults write com.apple.finder ShowStatusBar -bool true
# Finder: default to list view in new windows
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
# Finder: empty Trash automatically after 30 days
defaults write com.apple.finder FXRemoveOldTrashItems -bool true
# Finder: don't warn when changing a file's extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Keyboard: faster key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2
# Keyboard: shorter delay before repeat starts
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# Keyboard: disable autocorrect
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
# Keyboard: F1-F12 act as standard function keys by default (use Fn+F1..F12 for brightness/volume/etc.)
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true

# Dock: enable icon magnification on hover
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 70
# Dock: don't auto-rearrange Spaces by most recent use
defaults write com.apple.dock mru-spaces -bool false

# Trackpad: enable three-finger drag
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
# Trackpad: four-finger swipe down for App Exposé (all windows of the current app), up for Mission Control
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 2
defaults write com.apple.dock showAppExposeGestureEnabled -bool true

# Screenshots: save to ~/Screenshots instead of Desktop
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location "$HOME/Screenshots"
# Screenshots: no drop shadow around captured windows
defaults write com.apple.screencapture disable-shadow -bool true

# Menu bar: show Bluetooth status
defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -bool true

for app in Finder Dock SystemUIServer ControlCenter; do
  killall "$app" &>/dev/null || true
done

log "Done"
