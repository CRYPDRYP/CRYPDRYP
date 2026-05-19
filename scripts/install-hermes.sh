#!/usr/bin/env bash
# Install Hermes Agent (Nous Research) and configure Anthropic Claude as the provider.
# Targets: Linux, macOS, WSL2, Termux.
#
# Usage:
#   bash install-hermes.sh                      # install only, then run `hermes model` interactively
#   ANTHROPIC_API_KEY=sk-ant-... bash install-hermes.sh   # install + register API key
#   AUTH_MODE=oauth bash install-hermes.sh      # install + start OAuth flow (Claude Max)

set -euo pipefail

AUTH_MODE="${AUTH_MODE:-auto}"
DEFAULT_MODEL="${HERMES_MODEL:-claude-sonnet-4-6}"

echo ">> Installing Hermes Agent..."
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

# Make `hermes` available in this shell without requiring a re-login.
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  [ -f "$rc" ] && . "$rc" || true
done

if ! command -v hermes >/dev/null 2>&1; then
  echo "!! 'hermes' not on PATH yet. Open a new terminal (or 'source ~/.bashrc') and re-run the auth step."
  exit 0
fi

echo ">> Hermes installed: $(hermes --version 2>/dev/null || echo 'version unknown')"

if [ "$AUTH_MODE" = "oauth" ] || { [ "$AUTH_MODE" = "auto" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; }; then
  echo ">> Configuring Anthropic via OAuth (requires Claude Max + extra credits)."
  hermes auth add anthropic --type oauth
elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo ">> Configuring Anthropic via API key."
  hermes auth add anthropic --type api-key --api-key "$ANTHROPIC_API_KEY"
fi

echo ">> Setting default model to $DEFAULT_MODEL"
mkdir -p "$HOME/.hermes"
cat > "$HOME/.hermes/config.yaml" <<EOF
model:
  provider: anthropic
  default: $DEFAULT_MODEL
EOF

echo ">> Done. Start a chat with:  hermes"
echo "   Or run the setup wizard:   hermes setup"
