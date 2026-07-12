# macbook-init

Bootstrap script for setting up a fresh Mac.

## Usage

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/l2ysho/macbook-init/main/init.sh)"
```

Note: use this form, not `curl ... | bash`. Piping ties the script's stdin to the
network stream, so anything downstream that reads stdin (a sudo prompt, an
installer) can desync bash mid-script. `bash -c "$(curl ...)"` downloads the whole
script first, keeping stdin attached to your real terminal.

Or, if you already have this repo cloned:

```sh
./init.sh
```

Safe to re-run — every step checks existing state before making changes.

## What it does

- Installs Xcode Command Line Tools (if missing)
- Clones this repo to `~/.macbook-init` (only when run via the `curl` one-liner, since there's no local checkout to read `bin/` from otherwise; re-running pulls the latest)
- Creates `~/Work/personal` and `~/bin`
- Copies custom scripts from [bin/](bin) into `~/bin` (currently `myip`, `psgrep`, `logic-reset`) and adds `~/bin` to `PATH` in `.zshrc` if it isn't already there (open a new terminal for this to take effect)
- Configures git identity (`user.name`/`user.email`, only if not already set)
- Installs Homebrew (if missing) and updates it
- Installs Rosetta 2 (if missing, Apple Silicon only) — needed for x86-only apps like `sony-ps-remote-play`
- Installs Atuin (if missing) via its own installer — not a brew formula, so shell integration in `.zshrc` (`~/.atuin/bin/env`) keeps working
- Installs nvm (if missing) via its own installer, pinned to v0.40.5 — not a brew formula, so `.zshrc`'s `NVM_DIR`/`nvm.sh` sourcing keeps working
- Installs Claude Code (if missing) via its own installer
- Installs CLI tools and apps via `brew` (edit the `FORMULAE`/`CASKS` arrays in [init.sh](init.sh) to customize), then runs `brew cleanup`
- Installs Mac App Store apps via `mas` (edit `MAS_APPS`) — requires you to already be signed into the App Store; if a specific app fails to install, sign in and re-run (recent `mas` versions can't pre-check sign-in status, so it just attempts each install directly)
- Applies macOS defaults: Finder (hidden files, extensions, path/status bar, list view, auto-empty Trash, no extension-change warning), keyboard (faster repeat, autocorrect off, F1-F12 as standard function keys), Dock (icon magnification, no auto-rearranging Spaces), trackpad (three-finger drag), screenshots saved to `~/Screenshots` with no drop shadow
  - Most of these apply immediately (the script restarts Finder/Dock/SystemUIServer). The trackpad three-finger-drag setting is cached at login by a lower-level system daemon, though — `killall` isn't enough for it, you need to log out and back in (or restart) before it takes effect
