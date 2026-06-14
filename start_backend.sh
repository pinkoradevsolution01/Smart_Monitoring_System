#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"

echo "Smart Monitoring System - Backend Launcher"
echo "==========================================="
echo

if [[ ! -f "$BACKEND_DIR/app.js" ]]; then
  echo "ERROR: backend/app.js not found."
  exit 1
fi

cd "$BACKEND_DIR"
echo "Starting backend from: $PWD"
echo
npm start
