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
- Accepts the Xcode/SDK license (`sudo`, may prompt for your password) — needed even when CLT is already installed, since it's tracked separately and blocks git otherwise
- Clones this repo to `~/.macbook-init` (only when run via the `curl` one-liner, since there's no local checkout to read `bin/` from otherwise; re-running pulls the latest)
- Creates `~/Work/personal`, `~/bin`, and `~/.ssh` (mode `700`)
- Copies custom scripts from [bin/](bin) into `~/bin` (currently `myip`, `psgrep`, `logic-reset`, `yt2midi`) and adds `~/bin` to `PATH` in `.zshrc` if it isn't already there (open a new terminal for this to take effect)
- Configures git identity (`user.name`/`user.email`, only if not already set)
- Installs Homebrew (if missing) and updates it
- Installs Rosetta 2 (if missing, Apple Silicon only) — needed for x86-only apps like `sony-ps-remote-play`
- Installs Atuin (if missing) via its own installer — not a brew formula, so shell integration in `.zshrc` (`~/.atuin/bin/env`) keeps working
- Installs nvm (if missing) via its own installer, pinned to v0.40.5 — not a brew formula, so `.zshrc`'s `NVM_DIR`/`nvm.sh` sourcing keeps working
- Installs Claude Code (if missing) via its own installer and adds `~/.local/bin` to `PATH` in `.zshrc` if it isn't already there — the native installer puts `claude` there, which isn't on PATH by default
- Creates `~/.claude-work` and adds a `claude-work` alias (`CLAUDE_CONFIG_DIR=~/.claude-work claude`) to `.zshrc` if it isn't already there — just the folder/alias for now, contents (`CLAUDE.md`, `settings.json`, custom skills) still to be added
- Installs CLI tools and apps via `brew` (edit the `FORMULAE`/`CASKS` arrays in [init.sh](init.sh) to customize), then runs `brew cleanup`
- Installs Mac App Store apps via `mas` (edit `MAS_APPS`) — requires you to already be signed into the App Store; if a specific app fails to install, sign in and re-run (recent `mas` versions can't pre-check sign-in status, so it just attempts each install directly)
- Applies macOS defaults: Finder (hidden files, extensions, path/status bar, list view, auto-empty Trash, no extension-change warning), keyboard (faster repeat, autocorrect off, F1-F12 as standard function keys), Dock (icon magnification, no auto-rearranging Spaces), trackpad (three-finger drag, four-finger swipe down for App Exposé), menu bar (Bluetooth status shown), screenshots saved to `~/Screenshots` with no drop shadow
  - Most of these apply immediately (the script restarts Finder/Dock/SystemUIServer). The trackpad settings are cached at login by a lower-level system daemon, though — `killall` isn't enough for them, you need to log out and back in (or restart) before they take effect

## Audio transcription (`yt2midi`)

Turns a YouTube link into the original track, an isolated stem, a stem-less
track, and a MIDI transcription (with velocity + detected tempo). Pipeline:
`yt-dlp` → `demucs` (stem separation) → `muscriptor` (audio→MIDI) → a small
`librosa`/`pretty_midi` post-process. Defaults to **drums**; `-i` selects
another stem (only drums is verified so far).

The `yt2midi` command ships in [bin/](bin) and is installed to `~/bin` by
`init.sh` like the other scripts. Its heavy ML toolchain is **not** installed by
`init.sh` — run the opt-in setup once per machine:

```bash
./scripts/setup-transcribe.sh
```

That installs (via [`uv`](https://docs.astral.sh/uv/), no system pip) `yt-dlp`,
`demucs`, `muscriptor`, and `huggingface_hub`, plus `ffmpeg`. Safe to re-run.

**One-time Hugging Face setup** (manual — can't be scripted): MuScriptor's
weights are gated behind a license click-through.

1. Create a free account at <https://huggingface.co/join>
2. Accept the license at <https://huggingface.co/MuScriptor/muscriptor-large>
   (CC BY-NC 4.0 — non-commercial; you must have rights to whatever you transcribe)
3. Create a read token at <https://huggingface.co/settings/tokens>
4. `hf auth login` and paste the token

### Use

```bash
yt2midi "https://www.youtube.com/watch?v=aEbg9YZx3l0"           # drums
yt2midi -i bass "https://www.youtube.com/watch?v=aEbg9YZx3l0"   # another stem
yt2midi "https://www.youtube.com/watch?v=…" ~/Music/Transcriptions   # custom output dir
```

Output lands in `<output-dir>/<song title>/` (default base `~/Transcriptions`):
`original.wav`, `<stem>.wav`, `no_<stem>.wav`, `<stem>.mid`. Import the `.mid`
into GarageBand/Logic/Reaper, or open in MuseScore for notation.

### Housekeeping subcommands

```bash
yt2midi ps                  # list running pipeline processes
yt2midi kill                # kill them
yt2midi clean               # offer to delete leftover intermediates in the cwd
yt2midi clean --purge-cache # also offer to delete the HF/torch model caches
```

### Notes / limitations

- **First run is slower** — Demucs, MuScriptor, and the librosa post-process
  download models on first use, then reuse the cache.
- **yt-dlp breaks periodically** when YouTube changes anti-bot measures. Fix
  with `uv tool install --reinstall --python 3.12 yt-dlp` (a plain
  `uv tool upgrade` can no-op when pinned to an old Python).
- **Tempo can read half/double time** (70 vs 140 BPM) — sanity-check by ear.
- **Transcription is a strong first draft, not a perfect score** — hits get
  misclassified (snare vs rim, closed vs open hi-hat); spot-check by ear.
- **Weights are CC BY-NC 4.0** (non-commercial) — check the license before any
  commercial use.
