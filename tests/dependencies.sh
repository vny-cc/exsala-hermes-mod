#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST="$(mktemp -d)"
trap 'rm -rf -- "$TEST"' EXIT

FAKE_HOME="$TEST/hermes"
FAKE_REPO="$TEST/repo"
CLEAN_PYTHON="$TEST/clean-python"
EXSALA_VENV="$TEST/exsala-venv"

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

echo "=== TEST 1: Create clean Python ==="

python3 -m venv "$CLEAN_PYTHON"

"$CLEAN_PYTHON/bin/python" - <<'PY'
import importlib.util

assert importlib.util.find_spec("ruamel") is None
assert importlib.util.find_spec("yaml") is None

print("PASS: Python tidak memiliki dependency YAML")
PY

echo "=== TEST 2: Automatic dependency installation ==="

EXSALA_SKIP_HERMES_CLI=true \
HERMES_HOME="$FAKE_HOME" \
SOUL_FILE="$FAKE_REPO/SOUL.md" \
PYTHON_BIN="$CLEAN_PYTHON/bin/python" \
EXSALA_VENV="$EXSALA_VENV" \
bash "$FAKE_REPO/install.sh"

echo "=== TEST 3: Verify dependencies ==="

"$EXSALA_VENV/bin/python" - <<'PY'
from ruamel.yaml import YAML
print("PASS: ruamel.yaml berhasil terinstal")
PY

echo "=== TEST 4: Verify configuration ==="

"$EXSALA_VENV/bin/python" - "$FAKE_HOME/config.yaml" <<'PY'
from pathlib import Path
from ruamel.yaml import YAML
import sys

config = Path(sys.argv[1])
data = YAML().load(config.read_text())

assert data["agent"]["model"] == "test-model"
assert data["agent"]["system_prompt"] == "Test agent identity"
assert data["approvals"]["mode"] == "ask"
assert data["security"]["tirith_enabled"] is True
assert data["security"]["protected_instruction_files"] is True

print("PASS: konfigurasi valid dan security dipertahankan")
PY

echo "=== CLEAN ENVIRONMENT TEST PASSED ==="
