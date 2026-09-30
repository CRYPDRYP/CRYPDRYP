#!/data/data/com.termux/files/usr/bin/bash
# Install Hermes Agent inside Termux on Android (e.g. Solana Seeker).
#
# Bypasses Hermes's own shell installer (which downloads Chromium/ffmpeg from
# hosts that don't cleanly serve Android/aarch64) and installs the CLI via pip
# straight from PyPI. Also configures Anthropic Claude as the provider.
#
# Run inside Termux:
#   bash install-hermes-termux.sh
#   ANTHROPIC_API_KEY=sk-ant-... bash install-hermes-termux.sh

set -euo pipefail

if [ ! -d /data/data/com.termux ]; then
  echo "!! This script is Termux-only. On desktop Linux use install-hermes.sh."
  exit 1
fi

DEFAULT_MODEL="${HERMES_MODEL:-claude-opus-4-6}"

echo ">> Updating Termux packages..."
pkg update -y >/dev/null
pkg install -y python git rust binutils clang libjpeg-turbo libcrypt openssl

echo ">> Installing Hermes Agent from PyPI (this can take several minutes on first run)..."
pip install --user --upgrade pip
pip install --user --upgrade hermes-agent

# Persist PATH for future shells.
if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

if ! command -v hermes >/dev/null 2>&1; then
  echo "!! 'hermes' not on PATH. Open a new Termux tab and re-run the auth step."
  exit 0
fi

echo ">> Hermes installed: $(hermes --version 2>/dev/null | head -1 || echo unknown)"

echo ">> Pinning provider=anthropic, model=$DEFAULT_MODEL"
hermes config set model.provider anthropic >/dev/null
hermes config set model.default "$DEFAULT_MODEL" >/dev/null

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo ">> Registering Anthropic API key from ANTHROPIC_API_KEY env var."
  hermes auth add anthropic --type api-key --api-key "$ANTHROPIC_API_KEY"
else
  echo ">> No ANTHROPIC_API_KEY set. Run this after the script finishes:"
  echo "     hermes auth add anthropic --type api-key   # prompts securely"
fi

echo ">> Keeping Termux awake for background gateway/cron features (optional)..."
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock || true
fi

echo
echo ">> Done. Start Hermes with:  hermes"
echo "   Web dashboard on this device: hermes dashboard   (then open the printed URL)"
