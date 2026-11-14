#!/usr/bin/env bash
# Fresh Ubuntu/Debian root VPS: Herdr -> private Hermes backup recovery.
set -euo pipefail
umask 077

if [[ "${1:-}" == "--plan" ]]; then
  echo "Fresh root VPS: dependencies -> Herdr -> GitHub device login -> private backup repo"
  echo "Then inside Herdr: recovery key -> verified latest snapshot -> recorded Hermes version"
  echo "-> recorded source patch -> restored data -> gateway + 15-minute backups -> Hermes"
  exit 0
fi
if [[ $# -gt 0 ]]; then
  echo "Usage: bootstrap-vps.sh [--plan]" >&2
  exit 2
fi
if [[ "$(id -u)" != 0 || "$HOME" != /root || ! -f /etc/debian_version ]]; then
  echo "Script ini untuk root di VPS Ubuntu/Debian baru." >&2
  exit 1
fi
if [[ -e /root/.hermes/config.yaml || -L /root/.hermes/config.yaml || -L /root/.hermes ]]; then
  echo "Hermes sudah memiliki konfigurasi. Berhenti agar VPS aktif tidak tertimpa." >&2
  exit 1
fi
if ! (: </dev/tty) 2>/dev/null; then
  echo "Jalankan lewat terminal SSH interaktif untuk login GitHub dan kunci pemulihan." >&2
  exit 1
fi
if ! systemctl show --property=Version >/dev/null 2>&1; then
  echo "Diperlukan VPS dengan systemd aktif; bukan container Codespaces." >&2
  exit 1
fi

export PATH="/root/.local/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl git python3 python3-venv gh age

state=/root/.config/hermes-backup
repo=/root/hermes-backup
mkdir -p "$state" /root/.local/bin
chmod 700 "$state"
if ! command -v herdr >/dev/null 2>&1; then
  curl -fsSL --retry 3 https://herdr.dev/install.sh -o "$state/install-herdr.sh"
  sh "$state/install-herdr.sh"
fi
command -v herdr >/dev/null
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  gh auth login --hostname github.com --git-protocol https --web </dev/tty
fi
gh auth setup-git
if [[ -e "$repo" ]]; then
  echo "$repo sudah ada. Berhenti; periksa checkout itu sebelum mencoba ulang." >&2
  exit 1
fi
gh repo clone vny-cc/hermes-backup "$repo"

cat > "$state/recovery-shell.sh" <<'SHELL'
#!/usr/bin/env bash
export PATH="/root/.local/bin:$PATH"
cd /root/hermes-backup || exit 1
if [[ ! -f /root/.config/hermes-backup/recovery-ready.json ]]; then
  if ! python3 /root/hermes-backup/recover_vps.py; then
    echo "Recovery berhenti. Data staging dipertahankan untuk pemeriksaan; Hermes tidak dibuka."
    exec /bin/bash
  fi
fi
exec hermes
SHELL
chmod 700 "$state/recovery-shell.sh"
cat > "$state/herdr.toml" <<'TOML'
onboarding = false
[terminal]
default_shell = "/root/.config/hermes-backup/recovery-shell.sh"
shell_mode = "non_login"
TOML
cat > /root/.local/bin/hermes-herdr <<'SHELL'
#!/usr/bin/env bash
export PATH="/root/.local/bin:$PATH"
exec env HERDR_CONFIG_PATH=/root/.config/hermes-backup/herdr.toml herdr --session hermes
SHELL
chmod 700 /root/.local/bin/hermes-herdr
echo "→ Masuk Herdr. Siapkan baris AGE-SECRET-KEY dari identity.txt."
if [[ "${HERDR_ENV:-}" == 1 ]]; then
  exec bash "$state/recovery-shell.sh"
fi
exec /root/.local/bin/hermes-herdr </dev/tty >/dev/tty 2>/dev/tty
