#!/bin/bash
set -euo pipefail

# Shared Solana RPC launcher. RAM profiles are labels only; RPC threads,
# accounts-index bins, and Geyser concurrency stay on the 128GB-stable set.
# Scaling those knobs with RAM made getAccountInfo stall on 256GB/512GB hosts.
# Targets Agave/Jito v4.2+ only (default install: v4.2.1).

TOTAL_MEM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
PROFILE=${1:-auto}

if [[ "$PROFILE" == "auto" ]]; then
  if ((TOTAL_MEM_GB < 160)); then
    PROFILE=128g
  elif ((TOTAL_MEM_GB < 224)); then
    PROFILE=192g
  elif ((TOTAL_MEM_GB < 384)); then
    PROFILE=256g
  else
    PROFILE=512g
  fi
fi

# Keep the proven 128GB RPC/index/Geyser knobs on every host. Higher RAM does
# not need more bins or unary concurrency; those settings increase lock and
# disk contention on account reads.
RPC_THREADS=8
ACCOUNTS_INDEX_BINS=2048
GEYSER_CHANNEL_CAPACITY="50_000"
GEYSER_UNARY_LIMIT=128

case "$PROFILE" in
  128g)
    PROFILE_LABEL="128GB conservative"
    ;;
  192g)
    PROFILE_LABEL="192GB conservative"
    ;;
  256g)
    PROFILE_LABEL="256GB conservative"
    ;;
  512g)
    PROFILE_LABEL="512GB conservative"
    ;;
  *)
    echo "[ERROR] Unknown profile: $PROFILE (expected 128g, 192g, 256g, or 512g)" >&2
    exit 2
    ;;
esac

export RUST_LOG=${RUST_LOG:-info}
export RUST_BACKTRACE=1
export SOLANA_METRICS_CONFIG=""

DYNAMIC_PORT_RANGE=${DYNAMIC_PORT_RANGE:-8000-8030}
GOSSIP_PORT=${GOSSIP_PORT:-8000}
ACCOUNTS_CACHE_MB=${ACCOUNTS_CACHE_MB:-8192}
ENABLE_GEYSER=${ENABLE_GEYSER:-1}
ENABLE_ALT_INDEX=${ENABLE_ALT_INDEX:-1}
ENABLE_TX_HISTORY=${ENABLE_TX_HISTORY:-1}
GEYSER_CONFIG_PATH=""

if [[ ! "$ACCOUNTS_CACHE_MB" =~ ^[0-9]+$ ]] || ((ACCOUNTS_CACHE_MB < 1024)); then
  echo "[ERROR] ACCOUNTS_CACHE_MB must be an integer of at least 1024" >&2
  exit 2
fi
for toggle in ENABLE_GEYSER ENABLE_ALT_INDEX ENABLE_TX_HISTORY; do
  if [[ ! "${!toggle}" =~ ^[01]$ ]]; then
    echo "[ERROR] $toggle must be 0 or 1" >&2
    exit 2
  fi
done

if [[ "$ENABLE_GEYSER" == "1" ]]; then
  if [[ -n "${GEYSER_CONFIG:-}" ]]; then
    GEYSER_CONFIG_PATH=$GEYSER_CONFIG
  else
    GEYSER_CONFIG_SOURCE=/root/sol/bin/yellowstone-config.json
    if [[ ! -f "$GEYSER_CONFIG_SOURCE" ]]; then
      echo "[ERROR] Yellowstone config was not found: $GEYSER_CONFIG_SOURCE" >&2
      exit 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
      echo "[ERROR] jq is required to generate the profile-specific Yellowstone config" >&2
      exit 1
    fi
    mkdir -p /run/solana-rpc
    GEYSER_CONFIG_PATH="/run/solana-rpc/yellowstone-${PROFILE}.json"
    jq --arg capacity "$GEYSER_CHANNEL_CAPACITY" \
      --argjson unary "$GEYSER_UNARY_LIMIT" \
      '.grpc.channel_capacity = $capacity | .grpc.unary_concurrency_limit = $unary' \
      "$GEYSER_CONFIG_SOURCE" >"$GEYSER_CONFIG_PATH"
  fi

  if [[ ! -r "$GEYSER_CONFIG_PATH" ]]; then
    echo "[ERROR] Yellowstone config is not readable: $GEYSER_CONFIG_PATH" >&2
    exit 1
  fi
fi

if [[ -n "${VALIDATOR_BIN:-}" ]]; then
  if [[ ! -x "$VALIDATOR_BIN" ]]; then
    echo "[ERROR] VALIDATOR_BIN is not executable: $VALIDATOR_BIN" >&2
    exit 2
  fi
  VALIDATOR_CMD=$VALIDATOR_BIN
elif command -v agave-validator >/dev/null 2>&1; then
  VALIDATOR_CMD=$(command -v agave-validator)
elif command -v solana-validator >/dev/null 2>&1; then
  VALIDATOR_CMD=$(command -v solana-validator)
else
  echo "[ERROR] agave-validator or solana-validator was not found" >&2
  exit 1
fi

ARGS=(
  --ledger /root/sol/ledger
  --accounts /root/sol/accounts
  --identity /root/sol/bin/validator-keypair.json
  --snapshots /root/sol/snapshot
  --log /root/solana-rpc.log
  --entrypoint entrypoint.mainnet-beta.solana.com:8001
  --entrypoint entrypoint2.mainnet-beta.solana.com:8001
  --entrypoint entrypoint3.mainnet-beta.solana.com:8001
  --entrypoint entrypoint4.mainnet-beta.solana.com:8001
  --entrypoint entrypoint5.mainnet-beta.solana.com:8001
  --known-validator Certusm1sa411sMpV9FPqU5dXAYhmmhygvxJ23S6hJ24
  --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2
  --known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ
  --known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S
  --known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ
  --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d
  --only-known-rpc
  --no-port-check
  --no-xdp
  --dynamic-port-range "$DYNAMIC_PORT_RANGE"
  --gossip-port "$GOSSIP_PORT"
  --rpc-bind-address 0.0.0.0
  --rpc-port 8899
  --full-rpc-api
  --private-rpc
  --rpc-threads "$RPC_THREADS"
  --rpc-max-multiple-accounts 50
  --rpc-max-request-body-size 20971520
  --rpc-bigtable-timeout 180
  --rpc-send-retry-ms 1000
  --no-snapshots
  --minimal-snapshot-download-speed 10485760
  --use-snapshot-archives-at-startup when-newest
  --limit-ledger-size 50000000
  --wal-recovery-mode skip_any_corrupted_record
  --accounts-index-limit minimal
  --accounts-db-write-cache-limit "${ACCOUNTS_CACHE_MB}MB"
  --accounts-index-scan-results-limit-mb 256
  --accounts-shrink-ratio 0.80
  --accounts-index-bins "$ACCOUNTS_INDEX_BINS"
  --health-check-slot-distance 150
  --no-voting
  --allow-private-addr
  --bind-address 0.0.0.0
)

if [[ "$ENABLE_GEYSER" == "1" ]]; then
  ARGS+=(--geyser-plugin-config "$GEYSER_CONFIG_PATH")
fi

if [[ "$ENABLE_ALT_INDEX" == "1" ]]; then
  ARGS+=(
    --account-index program-id
    --account-index-include-key AddressLookupTab1e1111111111111111111111111
  )
fi

if [[ "$ENABLE_TX_HISTORY" == "1" ]]; then
  ARGS+=(--enable-rpc-transaction-history)
fi

echo "=================================================================="
echo "Solana RPC profile: $PROFILE_LABEL"
echo "System RAM: ${TOTAL_MEM_GB}GB"
echo "RPC threads: $RPC_THREADS | Accounts cache: ${ACCOUNTS_CACHE_MB}MB | Index bins: $ACCOUNTS_INDEX_BINS"
echo "Accounts shrink ratio: 0.80 | Disk-backed index: minimal"
echo "Geyser: $ENABLE_GEYSER | ALT index: $ENABLE_ALT_INDEX | TX history: $ENABLE_TX_HISTORY"
if [[ "$ENABLE_GEYSER" == "1" ]]; then
  echo "Geyser config: $GEYSER_CONFIG_PATH"
fi
echo "Validator: $VALIDATOR_CMD"
echo "=================================================================="

exec "$VALIDATOR_CMD" "${ARGS[@]}"
