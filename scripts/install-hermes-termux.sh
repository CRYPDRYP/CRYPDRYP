#!/data/data/com.termux/files/usr/bin/bash
# Install Hermes Agent inside Termux on Android (e.g. Solana Seeker).
#
# Bypasses Hermes's own shell installer (which downloads Chromium/ffmpeg from
# hosts that don't cleanly serve Android/aarch64) and installs the CLI via pip
# straight from PyPI. Also configures Anthropic Claude as the provider and
# runs a smoke test to confirm the install works end-to-end.
#
# Run inside Termux:
#   bash install-hermes-termux.sh
#   ANTHROPIC_API_KEY=sk-ant-... bash install-hermes-termux.sh

set -eu

if [ ! -d /data/data/com.termux ]; then
  echo "!! This script is Termux-only. On desktop Linux use install-hermes.sh." >&2
  exit 1
fi

DEFAULT_MODEL="${HERMES_MODEL:-claude-opus-4-6}"

step() { printf '\n\033[1;36m>>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

step "Updating Termux packages"
pkg update -y >/dev/null 2>&1 || warn "pkg update had warnings (continuing)"

step "Installing build toolchain and Python"
# python: interpreter. git: version control. rust + clang + binutils + make + pkg-config:
# needed to build cryptography / pydantic-core / uvloop wheels from source on aarch64.
# libffi + openssl + libjpeg-turbo + libcrypt + zlib: native lib deps for those wheels.
pkg install -y \
  python git rust clang binutils make pkg-config \
  libffi openssl libjpeg-turbo libcrypt zlib \
  >/dev/null || die "package install failed — run 'pkg install python git rust clang' manually to see the error"
ok "toolchain ready"

step "Upgrading pip"
python -m pip install --user --upgrade --quiet pip

step "Installing hermes-agent from PyPI (first run compiles wheels — 5–15 min)"
python -m pip install --user --upgrade hermes-agent \
  || die "pip install hermes-agent failed — scroll up for the wheel that broke"

# Make hermes available in this shell and future shells.
export PATH="$HOME/.local/bin:$PATH"
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  [ -f "$rc" ] || continue
  grep -q 'HOME/.local/bin' "$rc" 2>/dev/null && continue
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
done

command -v hermes >/dev/null 2>&1 || die "hermes not on PATH after install — try opening a new Termux tab"
ok "installed: $(hermes --version 2>/dev/null | head -1)"

step "Pinning provider=anthropic, model=$DEFAULT_MODEL"
hermes config set model.provider anthropic >/dev/null
hermes config set model.default "$DEFAULT_MODEL" >/dev/null
ok "config written to ~/.hermes/config.yaml"

step "Registering Anthropic credential"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  hermes auth add anthropic --type api-key --api-key "$ANTHROPIC_API_KEY" >/dev/null \
    && ok "API key from ANTHROPIC_API_KEY registered"
elif [ -t 0 ]; then
  echo "   Paste your Anthropic API key (starts with sk-ant-...) then press Enter."
  echo "   Get one at: https://console.anthropic.com/settings/keys"
  hermes auth add anthropic --type api-key
else
  warn "no API key provided and not running interactively — register one later with:"
  echo "     hermes auth add anthropic --type api-key"
fi

step "Enabling wake-lock so background features survive Android's doze"
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock && ok "wake-lock on" || warn "wake-lock failed (harmless if you don't use cron/gateway)"
fi

step "Smoke test: asking Claude to reply"
if hermes auth list 2>/dev/null | grep -q 'anthropic'; then
  if timeout 60 hermes -z "Reply with exactly: hermes ready" --provider anthropic --model "$DEFAULT_MODEL" 2>/dev/null | grep -qi 'hermes ready'; then
    ok "Claude round-trip works"
  else
    warn "smoke test did not return expected reply — key may be invalid or network is blocked"
  fi
else
  warn "smoke test skipped — no anthropic credential registered"
fi

cat <<EOF

╭──────────────────────────────────────────────╮
│ Done. Start Hermes with:                     │
│                                              │
│   hermes                     # chat TUI      │
│   hermes dashboard           # web UI        │
│   hermes -z "question"       # one-shot      │
│                                              │
│ If you opened a NEW Termux tab and 'hermes'  │
│ isn't found, run:                            │
│   export PATH="\$HOME/.local/bin:\$PATH"       │
╰──────────────────────────────────────────────╯
EOF
