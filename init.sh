#!/usr/bin/env bash
#
# macbook-init — bootstrap a fresh Mac.
# Safe to re-run: every step checks state before changing anything.

# -e: exit on any failed command. -u: error on unset variables.
# -o pipefail: a failing stage in a pipeline fails the whole pipeline.
set -euo pipefail

# Prints a bold blue "==> message" section header.
log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

# Directory this script lives in, so bin/ can be found regardless of cwd.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Directories -------------------------------------------------------------

log "Creating directories"
mkdir -p "$HOME/Work/personal"
mkdir -p "$HOME/bin"

# --- Custom scripts ----------------------------------------------------------

log "Installing custom scripts"
for script in "$REPO_DIR"/bin/*; do
  name="$(basename "$script")"
  cp "$script" "$HOME/bin/$name"
  chmod +x "$HOME/bin/$name"
  echo "  - $name"
done

# --- Xcode Command Line Tools ---------------------------------------------

if xcode-select -p &>/dev/null; then
  log "Xcode Command Line Tools already installed"
else
  log "Installing Xcode Command Line Tools"
  xcode-select --install

  until xcode-select -p &>/dev/null; do
    sleep 5
  done
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

# --- Atuin -------------------------------------------------------------

if [[ -x "$HOME/.atuin/bin/atuin" ]]; then
  log "Atuin already installed"
else
  log "Installing Atuin"
  curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
fi

# --- nvm -----------------------------------------------------------------

if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  log "nvm already installed"
else
  log "Installing nvm"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash
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
  warp
  zed
  zoom
  sony-ps-remote-play
  wifiman
)

# Mac App Store apps (no cask exists) — requires `mas`, and you must already
# be signed into the App Store (mas cannot authenticate for you).
MAS_APPS=(
  "634148309:Logic Pro"
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

# --- Mac App Store apps ------------------------------------------------------

log "Installing Mac App Store apps"

if ! mas account &>/dev/null; then
  echo "  - not signed into the App Store, skipping (sign in via the App Store app, then re-run)"
else
  for entry in "${MAS_APPS[@]+"${MAS_APPS[@]}"}"; do
    id="${entry%%:*}"
    name="${entry#*:}"
    if mas list | grep -q "^$id "; then
      echo "  - $name already installed"
    else
      echo "  - installing $name"
      mas install "$id"
    fi
  done
fi

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

# Keyboard: faster key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2
# Keyboard: shorter delay before repeat starts
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# Keyboard: disable autocorrect
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Dock: enable icon magnification on hover
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 70

# Trackpad: enable three-finger drag
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true

# Screenshots: save to ~/Screenshots instead of Desktop
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -- "$HOME/Screenshots"

for app in Finder Dock SystemUIServer; do
  killall "$app" &>/dev/null || true
done

log "Done"
