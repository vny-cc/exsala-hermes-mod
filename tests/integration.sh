#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST="$(mktemp -d)"
trap 'rm -rf "$TEST"' EXIT

FAKE_HOME="$TEST/hermes"
FAKE_REPO="$TEST/repo"

mkdir -p "$FAKE_HOME" "$FAKE_REPO/skills/test-skill"

cp "$REPO/install.sh" "$FAKE_REPO/install.sh"
printf 'Test agent identity\n' > "$FAKE_REPO/SOUL.md"
printf 'Test skill\n' > "$FAKE_REPO/skills/test-skill/SKILL.md"

cat > "$FAKE_HOME/config.yaml" <<'YAML'
agent:
  model: test-model
approvals:
  mode: ask
security:
  tirith_enabled: true
  protected_instruction_files: true
YAML

chmod 600 "$FAKE_HOME/config.yaml"

PYTHON="$HOME/.venvs/exsala/bin/python"
if [ ! -x "$PYTHON" ]; then
  PYTHON="$(command -v python3)"
fi

echo "=== TEST 1: Preflight ==="
EXSALA_SKIP_HERMES_CLI=true HERMES_HOME="$FAKE_HOME" \
  bash "$FAKE_REPO/install.sh" --check

echo "=== TEST 2: Install ==="
EXSALA_SKIP_HERMES_CLI=true HERMES_HOME="$FAKE_HOME" \
SOUL_FILE="$FAKE_REPO/SOUL.md" \
PYTHON_BIN="$PYTHON" \
  bash "$FAKE_REPO/install.sh"

echo "=== TEST 3: Verify ==="
"$PYTHON" - "$FAKE_HOME" <<'PY'
from pathlib import Path
import sys, stat
from ruamel.yaml import YAML

home = Path(sys.argv[1])
config = home / "config.yaml"
data = YAML().load(config.read_text())

assert data["agent"]["model"] == "test-model"
assert data["agent"]["system_prompt"] == "Test agent identity"
assert data["approvals"]["mode"] == "ask"
assert data["security"]["tirith_enabled"] is True
assert data["security"]["protected_instruction_files"] is True
assert stat.S_IMODE(config.stat().st_mode) == 0o600

assert list(home.glob("config.yaml.bak-exsala-*"))
assert (home / "skills/test-skill/SKILL.md").exists()

print("PASS: konfigurasi, keamanan, backup, permission, skill")
PY

echo "=== TEST 4: Idempotency ==="

BEFORE="$(sha256sum "$FAKE_HOME/config.yaml" | cut -d ' ' -f1)"

EXSALA_SKIP_HERMES_CLI=true \
HERMES_HOME="$FAKE_HOME" \
SOUL_FILE="$FAKE_REPO/SOUL.md" \
PYTHON_BIN="$PYTHON" \
  bash "$FAKE_REPO/install.sh"

AFTER="$(sha256sum "$FAKE_HOME/config.yaml" | cut -d ' ' -f1)"

if [ "$BEFORE" != "$AFTER" ]; then
  echo "FAIL: konfigurasi berubah setelah instalasi ulang"
  exit 1
fi

echo "PASS: konfigurasi tetap identik setelah instalasi ulang"

echo "=== TEST 5: Skill Conflict ==="

printf 'Custom user modification\n' > "$FAKE_HOME/skills/test-skill/SKILL.md"

EXSALA_SKIP_HERMES_CLI=true \
HERMES_HOME="$FAKE_HOME" \
SOUL_FILE="$FAKE_REPO/SOUL.md" \
PYTHON_BIN="$PYTHON" \
  bash "$FAKE_REPO/install.sh" > "$TEST/conflict.log" 2>&1

if ! grep -q 'Custom user modification' "$FAKE_HOME/skills/test-skill/SKILL.md"; then
  echo "FAIL: skill pengguna tertimpa"
  exit 1
fi

if ! grep -q 'Konflik skill: test-skill' "$TEST/conflict.log"; then
  echo "FAIL: konflik tidak dilaporkan"
  exit 1
fi

echo "PASS: skill pengguna dipertahankan dan konflik dilaporkan"

echo "=== TEST 6: Invalid YAML ==="
printf 'agent: [invalid\n' > "$FAKE_HOME/config.yaml"

if EXSALA_SKIP_HERMES_CLI=true HERMES_HOME="$FAKE_HOME" \
   SOUL_FILE="$FAKE_REPO/SOUL.md" \
   PYTHON_BIN="$PYTHON" \
   bash "$FAKE_REPO/install.sh" > "$TEST/error.log" 2>&1; then
  echo "FAIL: YAML rusak diterima"
  exit 1
fi

grep -q 'agent: \[invalid' "$FAKE_HOME/config.yaml"
echo "PASS: YAML rusak ditolak tanpa ditimpa"

echo "=== ALL TESTS PASSED ==="
