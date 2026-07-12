# macbook-init

Bootstrap script for setting up a fresh Mac.

## Usage

```sh
curl -fsSL https://raw.githubusercontent.com/l2ysho/macbook-init/main/init.sh | bash
```

Or, if you already have this repo cloned:

```sh
./init.sh
```

Safe to re-run — every step checks existing state before making changes.

## What it does

- Installs Xcode Command Line Tools (if missing)
- Clones this repo to `~/.macbook-init` (only when run via the `curl` one-liner, since there's no local checkout to read `bin/` from otherwise; re-running pulls the latest)
- Creates `~/Work/personal` and `~/bin`
- Copies custom scripts from [bin/](bin) into `~/bin` (currently `myip`, `psgrep`, `logic-reset`)
- Configures git identity (`user.name`/`user.email`, only if not already set)
- Installs Homebrew (if missing) and updates it
- Installs Atuin (if missing) via its own installer — not a brew formula, so shell integration in `.zshrc` (`~/.atuin/bin/env`) keeps working
- Installs nvm (if missing) via its own installer, pinned to v0.40.5 — not a brew formula, so `.zshrc`'s `NVM_DIR`/`nvm.sh` sourcing keeps working
- Installs CLI tools and apps via `brew` (edit the `FORMULAE`/`CASKS` arrays in [init.sh](init.sh) to customize), then runs `brew cleanup`
- Installs Mac App Store apps via `mas` (edit `MAS_APPS`) — requires you to already be signed into the App Store
- Applies macOS defaults: Finder (hidden files, extensions, path/status bar, list view, auto-empty Trash, no extension-change warning), keyboard (faster repeat, autocorrect off), Dock (icon magnification, no auto-rearranging Spaces), trackpad (three-finger drag), screenshots saved to `~/Screenshots` with no drop shadow
