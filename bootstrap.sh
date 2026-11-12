#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/vny-cc/exsala-hermes-mod.git"
BRANCH="${EXSALA_BRANCH:-fix/installer}"

command -v git >/dev/null || {
  echo "Error: Git belum terinstal"
  exit 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

echo "→ Download EXSALA Hermes Mod..."

git clone --quiet --depth 1 --branch "$BRANCH" \
  "$REPO" "$TMP_DIR/repo"

echo "→ Menjalankan installer..."

bash "$TMP_DIR/repo/install.sh" "$@"
