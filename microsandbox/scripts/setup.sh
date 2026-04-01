#!/usr/bin/env bash
# Install microsandbox runtime (msb + libkrunfw)
set -euo pipefail

if command -v msb &>/dev/null; then
  echo "microsandbox is already installed: $(msb --version)"
  exit 0
fi

echo "Installing microsandbox..."
curl -fsSL https://install.microsandbox.dev | sh

echo ""
echo "Installation complete. You may need to restart your shell or run:"
echo "  source ~/.bashrc  # or ~/.zshrc"
