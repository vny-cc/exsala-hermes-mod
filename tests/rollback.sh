#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST="$(mktemp -d)"
trap 'rm -rf -- "$TEST"' EXIT

FAKE_HOME="$TEST/hermes"
FAKE_REPO="$TEST/repo"
FAKE_BIN="$TEST/bin"

mkdir -p \
  "$FAKE_HOME" \
  "$FAKE_REPO/skills/first-skill" \
  "$FAKE_REPO/skills/second-skill" \
  "$FAKE_BIN"

cp "$REPO/install.sh" "$FAKE_REPO/install.sh"
echo "Test identity" > "$FAKE_REPO/SOUL.md"
echo "First skill" > "$FAKE_REPO/skills/first-skill/SKILL.md"
echo "Second skill" > "$FAKE_REPO/skills/second-skill/SKILL.md"

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
cp "$FAKE_HOME/config.yaml" "$TEST/original.yaml"

# Wrapper cp untuk mensimulasikan kegagalan skill kedua.
cat > "$FAKE_BIN/cp" <<'SH'
#!/usr/bin/env bash
for arg in "$@"; do
  case "$arg" in
    *second-skill*)
      echo "SIMULATED: second skill copy failure" >&2
      exit 42
      ;;
  esac
done
exec /usr/bin/cp "$@"
SH
chmod +x "$FAKE_BIN/cp"

echo "=== TEST: Full Rollback ==="

set +e
EXSALA_SKIP_HERMES_CLI=true \
HERMES_HOME="$FAKE_HOME" \
SOUL_FILE="$FAKE_REPO/SOUL.md" \
PYTHON_BIN="$HOME/.venvs/exsala/bin/python" \
PATH="$FAKE_BIN:$PATH" \
bash "$FAKE_REPO/install.sh" > "$TEST/install.log" 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
  echo "FAIL: installer seharusnya gagal"
  cat "$TEST/install.log"
  exit 1
fi

if ! grep -q 'SIMULATED: second skill copy failure' "$TEST/install.log"; then
  echo "FAIL: kegagalan simulasi tidak terjadi"
  cat "$TEST/install.log"
  exit 1
fi

if ! cmp -s "$FAKE_HOME/config.yaml" "$TEST/original.yaml"; then
  echo "FAIL: konfigurasi tidak dipulihkan"
  exit 1
fi

if [ -e "$FAKE_HOME/skills/first-skill" ]; then
  echo "FAIL: skill pertama masih tertinggal"
  exit 1
fi

if [ -e "$FAKE_HOME/skills/second-skill" ]; then
  echo "FAIL: skill kedua masih tertinggal"
  exit 1
fi

echo "PASS: installer mengembalikan exit code gagal"
echo "PASS: konfigurasi asli dipulihkan"
echo "PASS: skill baru dibersihkan"
echo "=== ROLLBACK TEST PASSED ==="
