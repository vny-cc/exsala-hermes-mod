#!/usr/bin/env bash
# ============================================
# EXSALA HERMES MOD
# powered by Gienetic
# ============================================
# Installer jailbreak zero-refusal + skill pack untuk Hermes Agent yang SUDAH terinstall.
# AMAN: backup dulu, hanya patch field spesifik, TIDAK sentuh model key/.env/setting pribadi.
# Idempotent: boleh di-run ulang.
set -euo pipefail

# --- 1. Lokasi ---
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
CONFIG="$HERMES_HOME/config.yaml"
echo "→ Hermes home: $HERMES_HOME"
if [ ! -f "$CONFIG" ]; then
  echo "✗ $CONFIG tidak ditemukan. Hermes belum terinstall?"
  echo "  Install dulu: curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
  exit 1
fi

# --- Preflight check ---
EXSALA_CHECK_ONLY=false

case "${1:-}" in
  --check) EXSALA_CHECK_ONLY=true ;;
  "") ;;
  *)
    echo "Usage: bash install.sh [--check]"
    exit 2
    ;;
esac

if [ "$EXSALA_CHECK_ONLY" = true ]; then
  echo "→ EXSALA preflight (read-only)"
  errors=0

  if [ -r "$CONFIG" ]; then
    echo "✓ Konfigurasi Hermes ditemukan"
  else
    echo "✗ Konfigurasi Hermes tidak dapat dibaca"
    errors=$((errors + 1))
  fi

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [ -n "${SOUL_FILE:-}" ]; then
    soul_candidate="$SOUL_FILE"
  elif [ -r "$SCRIPT_DIR/SOUL.md" ]; then
    soul_candidate="$SCRIPT_DIR/SOUL.md"
  else
    soul_candidate="$HERMES_HOME/SOUL.md"
  fi

  if [ -s "$soul_candidate" ] && [ -r "$soul_candidate" ]; then
    echo "✓ SOUL.md tersedia dan tidak kosong"
  else
    echo "✗ SOUL.md tidak tersedia atau kosong"
    errors=$((errors + 1))
  fi

  if command -v "${PYTHON_BIN:-python3}" >/dev/null 2>&1; then
    echo "✓ Python tersedia"
  else
    echo "✗ Python tidak ditemukan"
    errors=$((errors + 1))
  fi

  if [ -d "$SCRIPT_DIR/skills" ]; then
    echo "✓ Folder skill pack tersedia"
  else
    echo "⚠ Folder skill pack tidak ditemukan"
  fi

  if [ "$errors" -eq 0 ]; then
    echo "✓ Pemeriksaan dasar lulus"
    exit 0
  fi

  echo "✗ Ditemukan $errors masalah"
  exit 1
fi

# --- 3. Cari hermes binary ---
HERMES_BIN=""
EXSALA_SKIP_HERMES_CLI="${EXSALA_SKIP_HERMES_CLI:-false}"
for c in "$HERMES_HOME/hermes-agent/hermes" "$HOME/.local/bin/hermes" hermes; do
  if [ -x "$c" ]; then HERMES_BIN="$c"; break; fi
  if command -v "$c" >/dev/null 2>&1; then HERMES_BIN="$(command -v "$c")"; break; fi
done
echo "→ hermes: ${HERMES_BIN:-TIDAK di PATH (pakai fallback python)}"

# --- 4. Direktori + SOUL ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUL_FILE="${SOUL_FILE:-}"

if [ -z "$SOUL_FILE" ]; then
  for candidate in "$SCRIPT_DIR/SOUL.md" "$HERMES_HOME/SOUL.md"; do
    if [ -f "$candidate" ]; then
      SOUL_FILE="$candidate"
      break
    fi
  done
fi

if [ -z "$SOUL_FILE" ] || [ ! -r "$SOUL_FILE" ]; then
  echo "✗ SOUL.md tidak ditemukan atau tidak dapat dibaca"
  exit 1
fi

echo "✓ SOUL.md: $SOUL_FILE"

# --- Dependency Python ---
PYTHON_BIN="${PYTHON_BIN:-python3}"

if ! "$PYTHON_BIN" -c "import ruamel.yaml" 2>/dev/null; then
  echo "→ Menyiapkan dependency Python..."
  VENV_DIR="${EXSALA_VENV:-$HERMES_HOME/.exsala-venv}"

  if [ ! -x "$VENV_DIR/bin/python" ]; then
    "$PYTHON_BIN" -m venv "$VENV_DIR" || {
      echo "✗ Gagal membuat virtual environment."
      echo "  Install python3-venv lalu ulangi."
      exit 1
    }
  fi

  "$VENV_DIR/bin/python" -m pip install ruamel.yaml
  PYTHON_BIN="$VENV_DIR/bin/python"
fi

"$PYTHON_BIN" -c "import ruamel.yaml" || {
  echo "✗ Dependency YAML tidak tersedia."
  exit 1
}

# --- 5. Atomic Configuration ---
echo ""
echo "→ Memperbarui konfigurasi secara atomik..."

"$PYTHON_BIN" - "$CONFIG" "$SOUL_FILE" <<'PYCONFIG'
import os
import sys
import stat
import shutil
import tempfile
from pathlib import Path
from datetime import datetime
from collections.abc import MutableMapping
from ruamel.yaml import YAML

config = Path(sys.argv[1])
soul = Path(sys.argv[2])

yaml = YAML()
yaml.preserve_quotes = True
yaml.width = 10**9

with config.open(encoding="utf-8") as f:
    data = yaml.load(f)

if not isinstance(data, MutableMapping):
    raise ValueError("config.yaml harus berupa YAML mapping")

content = soul.read_text(encoding="utf-8").strip()
if not content:
    raise ValueError("SOUL.md kosong")

def section(parent, key):
    value = parent.get(key)
    if value is None:
        parent[key] = {}
        value = parent[key]
    if not isinstance(value, MutableMapping):
        raise ValueError(f"Bagian {key} bukan mapping")
    return value

section(data, "agent")["system_prompt"] = content

extra = section(
    section(section(data, "platforms"), "telegram"),
    "extra"
)
extra["rich_messages"] = True
extra["allow_cjk_rich_messages"] = True

# Pertahankan pengaturan security dan approvals.
mode = stat.S_IMODE(config.stat().st_mode)

if config.stat().st_uid != os.geteuid():
    raise PermissionError("Jalankan sebagai pemilik config.yaml")

tmp_path = None
backup = None
replaced = False

try:
    fd, tmp_path = tempfile.mkstemp(
        prefix=".exsala-config-",
        dir=str(config.parent)
    )

    with os.fdopen(fd, "w", encoding="utf-8") as f:
        yaml.dump(data, f)
        f.flush()
        os.fsync(f.fileno())

    os.chmod(tmp_path, mode)

    with open(tmp_path, encoding="utf-8") as f:
        validated = yaml.load(f)

    if not isinstance(validated, MutableMapping):
        raise ValueError("Konfigurasi hasil tidak valid")

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup = config.with_name(
        config.name + ".bak-exsala-" + stamp
    )
    shutil.copy2(config, backup)

    os.replace(tmp_path, config)
    tmp_path = None
    replaced = True

    with config.open(encoding="utf-8") as f:
        yaml.load(f)

    print("✓ Konfigurasi atomik berhasil")
    print(f"✓ Backup: {backup}")
    print("✓ Pengaturan keamanan dipertahankan")

except Exception:
    if replaced and backup is not None:
        restore_fd, restore_path = tempfile.mkstemp(
            prefix=".exsala-restore-",
            dir=str(config.parent)
        )
        try:
            os.close(restore_fd)
            shutil.copy2(backup, restore_path)
            os.replace(restore_path, config)
            print("✓ Rollback konfigurasi berhasil")
        finally:
            if os.path.exists(restore_path):
                os.unlink(restore_path)
    raise

finally:
    if tmp_path and os.path.exists(tmp_path):
        os.unlink(tmp_path)

PYCONFIG

# --- 7. Install skill pack (semua skill, merge ke skills/<nama>/) ---
echo ""
echo "→ Install skill pack..."
SKILLS_SRC="$SCRIPT_DIR/skills"
n=0
if [ -d "$SKILLS_SRC" ]; then
  for d in "$SKILLS_SRC"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    dest="$HERMES_HOME/skills/$name"
    mkdir -p "$dest"
    cp -r "$d". "$dest"
    n=$((n+1))
  done
  echo "✓ $n skill di-install ke $HERMES_HOME/skills/"
else
  echo "⚠ skills/ tidak ada — skill skip"
fi

# --- 8. Rebuild skill registry ---
if [ "$EXSALA_SKIP_HERMES_CLI" != "true" ] && [ -n "${HERMES_BIN:-}" ]; then
  "$HERMES_BIN" skills list >/dev/null 2>&1 && echo "✓ skill registry di-rebuild"
fi

# --- 9. Selesai ---
echo ""
echo "✓ EXSALA HERMES MOD SELESAI"
echo "  • SOUL EXSALA diterapkan"
echo "  • Skill pack: $n direktori"
echo "  • Konfigurasi dibackup"
echo "  • Pengaturan keamanan dipertahankan"
echo ""
echo "→ Restart Hermes untuk menerapkan perubahan"
