#!/usr/bin/env bash
# setup-transcribe.sh - install the yt2midi toolchain. Opt-in: NOT run by
# init.sh, because it pulls multi-GB ML models most machines don't need.
#
# Installs, via uv (no system pip needed), each pinned to a Python that its
# newest release supports:
#   yt-dlp (3.12), demucs (3.12, +numpy), muscriptor (3.13), huggingface_hub (3.13)
# plus ffmpeg via Homebrew if missing. Safe to re-run.
#
# After this, do the one-time Hugging Face login to unlock MuScriptor's gated
# weights (see README for the account/token steps):
#   hf auth login

set -euo pipefail
log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

# uv - manages each tool's Python and isolated env.
if command -v uv &>/dev/null; then
  log "uv already installed"
else
  log "Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

# ffmpeg - yt-dlp/demucs need it for audio I/O.
if command -v ffmpeg &>/dev/null; then
  log "ffmpeg already installed"
elif command -v brew &>/dev/null; then
  log "Installing ffmpeg"
  brew install ffmpeg
else
  echo "  - ffmpeg missing and Homebrew not found; install ffmpeg manually" >&2
fi

# Pinned Pythons avoid uv silently picking an old system Python, which breaks
# yt-dlp and muscriptor. demucs under-declares numpy, so bundle it explicitly.
log "Installing transcription tools via uv"
uv tool install --python 3.12 yt-dlp
uv tool install --python 3.12 --with numpy demucs
uv tool install --python 3.13 muscriptor
uv tool install --python 3.13 huggingface_hub

log "Done. One-time next step: 'hf auth login' to unlock MuScriptor weights (see README)."
