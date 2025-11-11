#!/bin/bash
# ==================================================================
# Solana RPC Validator - 128GB Memory Configuration
# ==================================================================
# Tier: OPTIMIZED STANDARD (For 128-160GB RAM systems)
# Target Peak: ~105-120GB
# RPC Threads: 8 | Cache: 1.5GB | Index Bins: 2048
# Transaction History: ✅ ENABLED (full RPC features)
# ==================================================================
# Slightly conservative compared to TIER 2, but full functionality
# ==================================================================

export RUST_LOG=warn
export RUST_BACKTRACE=1
export SOLANA_METRICS_CONFIG=""

TOTAL_MEM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)

echo "✅ TIER 1: 128GB OPTIMIZED STANDARD CONFIGURATION"
echo "   System RAM: ${TOTAL_MEM_GB}GB | Target Peak: ~105-120GB"
echo "   RPC Threads: 8 | Accounts Cache: 1.5GB | Index Bins: 2048"
echo "   ✅ Transaction History: ENABLED"
echo "   📊 Full RPC features with slightly conservative parameters"
echo "=================================================================="

exec agave-validator \
 --geyser-plugin-config /root/sol/bin/yellowstone-config.json \
 --ledger /root/sol/ledger \
 --accounts /root/sol/accounts \
 --identity /root/sol/bin/validator-keypair.json \
 --snapshots /root/sol/snapshot \
 --log /root/solana-rpc.log \
 --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint4.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint5.mainnet-beta.solana.com:8001 \
 --known-validator Certusm1sa411sMpV9FPqU5dXAYhmmhygvxJ23S6hJ24 \
 --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
 --known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
 --known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
 --known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
 --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
 --only-known-rpc --no-port-check \
 --dynamic-port-range 8000-8025 --gossip-port 8001 \
 --rpc-bind-address 0.0.0.0 --rpc-port 8899 \
 --full-rpc-api --private-rpc --rpc-threads 8 \
 --rpc-max-multiple-accounts 50 \
 --rpc-max-request-body-size 20971520 \
 --rpc-bigtable-timeout 180 --rpc-send-retry-ms 1000 \
 --account-index program-id \
 --account-index-include-key AddressLookupTab1e1111111111111111111111111 \
 --no-incremental-snapshots \
 --maximum-full-snapshots-to-retain 2 \
 --maximum-incremental-snapshots-to-retain 2 \
 --minimal-snapshot-download-speed 10485760 \
 --use-snapshot-archives-at-startup when-newest \
 --limit-ledger-size 50000000 \
 --wal-recovery-mode skip_any_corrupted_record \
 --enable-rpc-transaction-history \
 --accounts-db-cache-limit-mb 1536 \
 --accounts-shrink-ratio 0.90 --accounts-index-bins 2048 \
 --block-production-method central-scheduler \
 --health-check-slot-distance 150 \
 --no-voting --allow-private-addr --bind-address 0.0.0.0 \
 --log-messages-bytes-limit 201326592
