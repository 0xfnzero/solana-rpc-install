#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Please run as root: sudo bash $0" >&2
  exit 1
fi

echo "[WARN] tcp-optimize.sh is deprecated."
echo "       Aggressive BBR/1GB socket settings were removed for 128GB stability."
echo "       Use system-optimize.sh to install the unified host configuration."

SYSCTL_CFG=/etc/sysctl.d/99-solana-tune.conf
if [[ ! -f "$SYSCTL_CFG" ]]; then
  echo "[ERROR] $SYSCTL_CFG was not found; run system-optimize.sh first." >&2
  exit 1
fi

exec sysctl -p "$SYSCTL_CFG"
