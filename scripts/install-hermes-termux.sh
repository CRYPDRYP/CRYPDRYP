#!/data/data/com.termux/files/usr/bin/bash
# Install Hermes Agent inside Termux on Android (e.g. Solana Seeker).
#
# Uses Nous Research's official signed APT repo — the ONLY supported path
# on Termux. Pip does not work (psutil hard-rejects Android at build time).
#
# STATUS (2026-09): Nous documents the Termux package as currently broken
# with a fix in progress. This script sets up the correct repo so it will
# work as soon as their fix ships. Try it; if `pkg install hermes-agent`
# succeeds, you're set; if not, the officially supported install is not
# available yet on Termux.
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
KEY_URL="https://hermes-assets.nousresearch.com/releases/termux/stable/key.asc"
REPO_URL="https://hermes-assets.nousresearch.com/releases/termux/stable"
EXPECTED_FP="C572 B5FD D1A2 9CCF A9A9 12B6 840B 0848 E139 156D"

step() { printf '\n\033[1;36m>>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

step "Installing prerequisites (curl, gnupg)"
pkg install -y curl gnupg >/dev/null || die "pkg install curl gnupg failed"

step "Downloading Nous Research signing key"
mkdir -p "$PREFIX/etc/apt/keyrings"
curl -fsSL "$KEY_URL" -o "$PREFIX/etc/apt/keyrings/hermes-agent.asc" \
  || die "could not download signing key from $KEY_URL"

step "Verifying key fingerprint"
actual_fp=$(gpg --show-keys --with-fingerprint "$PREFIX/etc/apt/keyrings/hermes-agent.asc" 2>/dev/null \
  | grep -Eo '([0-9A-F]{4} ){9}[0-9A-F]{4}' | head -1)
if [ "$actual_fp" = "$EXPECTED_FP" ]; then
  ok "fingerprint matches: $EXPECTED_FP"
else
  die "fingerprint mismatch! expected $EXPECTED_FP, got $actual_fp — do not proceed"
fi

step "Adding Hermes APT repo"
printf '%s\n' \
  "deb [signed-by=$PREFIX/etc/apt/keyrings/hermes-agent.asc] $REPO_URL hermes-stable main" \
  > "$PREFIX/etc/apt/sources.list.d/hermes-agent.list"
ok "repo added: $PREFIX/etc/apt/sources.list.d/hermes-agent.list"

step "Updating package lists"
pkg update -y 2>&1 | tail -5

step "Installing hermes-agent"
if ! pkg install -y hermes-agent 2>&1 | tee /tmp/hermes-install.log; then
  echo
  warn "pkg install hermes-agent failed."
  warn "Nous Research currently documents this package as broken —"
  warn "  \"The Termux package does not work right now. A fix is in progress.\""
  warn "  https://hermes-agent.nousresearch.com/docs/getting-started/termux"
  warn "Retry this script after they announce the fix."
  exit 1
fi
ok "installed: $(hermes --version 2>/dev/null | head -1 || echo hermes)"

step "Pinning provider=anthropic, model=$DEFAULT_MODEL"
hermes config set model.provider anthropic >/dev/null
hermes config set model.default "$DEFAULT_MODEL" >/dev/null
ok "config written"

step "Registering Anthropic credential"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  hermes auth add anthropic --type api-key --api-key "$ANTHROPIC_API_KEY" >/dev/null \
    && ok "API key registered"
elif [ -t 0 ]; then
  echo "   Paste your Anthropic API key (starts with sk-ant-...) then press Enter."
  hermes auth add anthropic --type api-key
else
  warn "no API key provided and not running interactively"
  warn "run this later: hermes auth add anthropic --type api-key"
fi

command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock 2>/dev/null || true

cat <<EOF

╭──────────────────────────────────────────────╮
│ Done. Start Hermes with:                     │
│                                              │
│   hermes                     # chat TUI      │
│   hermes dashboard           # web UI        │
│   hermes -z "question"       # one-shot      │
╰──────────────────────────────────────────────╯
EOF
