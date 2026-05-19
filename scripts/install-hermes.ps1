# Install Hermes Agent (Nous Research) and configure Anthropic Claude as the provider.
# Target: Windows (native, early beta) PowerShell.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install-hermes.ps1
#   $env:ANTHROPIC_API_KEY = "sk-ant-..."; .\install-hermes.ps1
#   $env:AUTH_MODE = "oauth"; .\install-hermes.ps1

$ErrorActionPreference = "Stop"

$AuthMode     = if ($env:AUTH_MODE)     { $env:AUTH_MODE }     else { "auto" }
$DefaultModel = if ($env:HERMES_MODEL)  { $env:HERMES_MODEL }  else { "claude-sonnet-4-6" }

Write-Host ">> Installing Hermes Agent..."
iex (irm https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1)

if (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
    Write-Host "!! 'hermes' not on PATH yet. Open a new PowerShell window and re-run the auth step."
    exit 0
}

Write-Host ">> Hermes installed."

if ($AuthMode -eq "oauth" -or ($AuthMode -eq "auto" -and -not $env:ANTHROPIC_API_KEY)) {
    Write-Host ">> Configuring Anthropic via OAuth (requires Claude Max + extra credits)."
    hermes auth add anthropic --type oauth
} elseif ($env:ANTHROPIC_API_KEY) {
    Write-Host ">> Configuring Anthropic via API key."
    hermes auth add anthropic --type api-key --api-key $env:ANTHROPIC_API_KEY
}

Write-Host ">> Setting default model to $DefaultModel"
$HermesDir = Join-Path $HOME ".hermes"
New-Item -ItemType Directory -Force -Path $HermesDir | Out-Null
@"
model:
  provider: anthropic
  default: $DefaultModel
"@ | Set-Content -Path (Join-Path $HermesDir "config.yaml") -Encoding utf8

Write-Host ">> Done. Start a chat with:  hermes"
Write-Host "   Or run the setup wizard:   hermes setup"
