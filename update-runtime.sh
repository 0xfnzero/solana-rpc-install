#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN=${BIN:-/root/sol/bin}
SERVICE_NAME=${SERVICE_NAME:-sol}
RESTART=false
BACKUP_ROOT=${BACKUP_ROOT:-/root/sol/runtime-backups}

if [[ ${1:-} == "--restart" ]]; then
  RESTART=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--restart]" >&2
  exit 2
fi

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Please run as root: sudo bash $0 [--restart]" >&2
  exit 1
fi

if [[ ! $SERVICE_NAME =~ ^[A-Za-z0-9_.@-]+$ || $SERVICE_NAME == *.service ]]; then
  echo "[ERROR] SERVICE_NAME must be a systemd unit name without the .service suffix" >&2
  exit 1
fi

required_files=(
  validator.sh
  validator-128g.sh
  validator-192g.sh
  validator-256g.sh
  validator-512g.sh
  select-validator.sh
  performance-monitor.sh
  logrotate-solana-rpc
  sol.service
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
    echo "[ERROR] Missing runtime file: $SCRIPT_DIR/$file" >&2
    exit 1
  fi
done

for file in "$SCRIPT_DIR"/*.sh; do
  bash -n "$file"
done

if ! command -v systemd-analyze >/dev/null 2>&1; then
  echo "[ERROR] systemd-analyze is required to validate sol.service" >&2
  exit 1
fi

if ! systemd-analyze verify "$SCRIPT_DIR/sol.service"; then
  echo "[ERROR] systemd service validation failed; nothing was updated" >&2
  exit 1
fi

VALIDATOR_CMD=""
if command -v agave-validator >/dev/null 2>&1; then
  VALIDATOR_CMD=$(command -v agave-validator)
elif command -v solana-validator >/dev/null 2>&1; then
  VALIDATOR_CMD=$(command -v solana-validator)
fi

if [[ -z "$VALIDATOR_CMD" ]]; then
  echo "[ERROR] agave-validator or solana-validator was not found" >&2
  exit 1
fi

validator_help=$("$VALIDATOR_CMD" --help 2>&1 || true)
required_validator_flags=(
  --no-snapshots
  --accounts-index-limit
  --accounts-index-scan-results-limit-mb
  --accounts-shrink-ratio
  --accounts-index-bins
)
for flag in "${required_validator_flags[@]}"; do
  if ! grep -q -- "$flag" <<<"$validator_help"; then
    echo "[ERROR] Installed validator does not support $flag: $VALIDATOR_CMD" >&2
    exit 1
  fi
done

# Agave/Jito v4.2 renamed/removed several flags our launcher probes for at
# runtime. Warn when the installed binary predates v4.2 so an operator knows a
# rebuild is required before relying on the new behavior.
missing_v42=()
grep -q -- '--no-xdp' <<<"$validator_help" || missing_v42+=(--no-xdp)
grep -q -- '--accounts-db-write-cache-limit' <<<"$validator_help" \
  || missing_v42+=(--accounts-db-write-cache-limit)
if ((${#missing_v42[@]} > 0)); then
  echo "[WARN] Installed validator does not advertise: ${missing_v42[*]}"
  echo "       These are Agave/Jito v4.2+ flags. The launcher falls back for"
  echo "       pre-v4.2 binaries, but a v4.2+ node needs them to start."
  echo "       If startup fails after upgrade, rebuild with v4.2.1 or newer."
fi

missing_packages=()
command -v iostat >/dev/null 2>&1 || missing_packages+=(sysstat)
command -v logrotate >/dev/null 2>&1 || missing_packages+=(logrotate)
command -v jq >/dev/null 2>&1 || missing_packages+=(jq)
if ((${#missing_packages[@]} > 0)); then
  apt-get update -qq
  apt-get install -y "${missing_packages[@]}"
fi

logrotate_tmp=$(mktemp)
trap 'rm -f "$logrotate_tmp"' EXIT
sed "s/sol\.service/${SERVICE_NAME}.service/g" "$SCRIPT_DIR/logrotate-solana-rpc" > "$logrotate_tmp"
if ! logrotate --debug "$logrotate_tmp" >/dev/null; then
  echo "[ERROR] logrotate configuration validation failed; nothing was updated" >&2
  exit 1
fi

timestamp=$(date '+%Y%m%d-%H%M%S')
mkdir -p "$BACKUP_ROOT"
backup_dir=$(mktemp -d "$BACKUP_ROOT/${timestamp}-XXXXXX")
mkdir -p "$backup_dir/bin"

for file in validator.sh validator-128g.sh validator-192g.sh validator-256g.sh validator-512g.sh select-validator.sh; do
  [[ -f "$BIN/$file" ]] && cp -a "$BIN/$file" "$backup_dir/bin/$file"
done
[[ -f /root/performance-monitor.sh ]] && cp -a /root/performance-monitor.sh "$backup_dir/performance-monitor.sh"
[[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]] && \
  cp -a "/etc/systemd/system/${SERVICE_NAME}.service" "$backup_dir/sol.service"
[[ -f /etc/logrotate.d/solana-rpc ]] && \
  cp -a /etc/logrotate.d/solana-rpc "$backup_dir/logrotate-solana-rpc"

mkdir -p "$BIN"
install -m 0755 "$SCRIPT_DIR/validator.sh" "$BIN/validator.sh"
install -m 0755 "$SCRIPT_DIR/validator-128g.sh" "$BIN/validator-128g.sh"
install -m 0755 "$SCRIPT_DIR/validator-192g.sh" "$BIN/validator-192g.sh"
install -m 0755 "$SCRIPT_DIR/validator-256g.sh" "$BIN/validator-256g.sh"
install -m 0755 "$SCRIPT_DIR/validator-512g.sh" "$BIN/validator-512g.sh"
install -m 0755 "$SCRIPT_DIR/select-validator.sh" "$BIN/select-validator.sh"
install -m 0755 "$SCRIPT_DIR/performance-monitor.sh" /root/performance-monitor.sh
install -m 0644 "$SCRIPT_DIR/sol.service" "/etc/systemd/system/${SERVICE_NAME}.service"
install -m 0644 "$logrotate_tmp" /etc/logrotate.d/solana-rpc

systemctl daemon-reload

echo "Runtime configuration updated without deleting ledger, accounts, or snapshots."
echo "Previous configuration backup: $backup_dir"

if [[ -d /root/sol/snapshot ]]; then
  full_snapshot_count=$(find /root/sol/snapshot -maxdepth 1 -type f \
    -name 'snapshot-*.tar*' 2>/dev/null | wc -l)
  partial_snapshot_count=$(find /root/sol/snapshot -mindepth 1 -maxdepth 1 \
    \( -name 'tmp-*' -o -name '*.part' -o -name '*.tmp' -o -name '*.aria2' \) \
    2>/dev/null | wc -l)
  if [[ $full_snapshot_count -gt 1 || $partial_snapshot_count -gt 0 ]]; then
    echo "[WARN] Existing snapshot files were not deleted: full=$full_snapshot_count partial=$partial_snapshot_count"
    echo "       Run: bash /root/performance-monitor.sh diagnose"
  fi
fi

if [[ "$RESTART" == true ]]; then
  restart_ok=true
  if ! systemctl restart "$SERVICE_NAME"; then
    restart_ok=false
  else
    for _ in $(seq 1 15); do
      sleep 1
      if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        restart_ok=false
        break
      fi
    done
  fi

  if [[ "$restart_ok" != true ]]; then
    systemctl status "$SERVICE_NAME" --no-pager -l || true
    journalctl -u "$SERVICE_NAME" -n 100 --no-pager || true
    echo "[ERROR] Restart failed; restoring $backup_dir" >&2

    for file in "$backup_dir"/bin/*; do
      [[ -f "$file" ]] && install -m 0755 "$file" "$BIN/$(basename "$file")"
    done
    [[ -f "$backup_dir/performance-monitor.sh" ]] && \
      install -m 0755 "$backup_dir/performance-monitor.sh" /root/performance-monitor.sh
    [[ -f "$backup_dir/sol.service" ]] && \
      install -m 0644 "$backup_dir/sol.service" "/etc/systemd/system/${SERVICE_NAME}.service"
    [[ -f "$backup_dir/logrotate-solana-rpc" ]] && \
      install -m 0644 "$backup_dir/logrotate-solana-rpc" /etc/logrotate.d/solana-rpc
    systemctl daemon-reload
    systemctl restart "$SERVICE_NAME" || true
    exit 1
  fi
  echo "$SERVICE_NAME.service restarted successfully."
else
  echo "The running validator is unchanged. Re-run with --restart during a maintenance window."
fi
