#!/bin/bash

# ============================================
# Solana RPC Node - 128GB Memory Optimized
# ============================================
# CRITICAL: Memory-constrained optimization
# Target: Stay under 100-105GB peak usage
# Optimizations: Fixed RPC threads, reduced cache/bins/logs
# Focus: Essential RPC functionality only
# ============================================

# Environment optimizations
export RUST_LOG=warn
export RUST_BACKTRACE=1
export SOLANA_METRICS_CONFIG=""

# Detect CPU cores for optimal threading
CPU_CORES=$(nproc)
# Fixed RPC threads to save memory (optimized for memory efficiency)
RPC_THREADS=8

echo "Starting Solana Validator - 128GB Memory Mode"
echo "CPU Cores: $CPU_CORES | RPC Threads: $RPC_THREADS"

# Memory distribution analysis (optimized):
# - Accounts DB: ~60-70GB (largest consumer)
# - Indexes: ~8-12GB (2048 bins, minimal indexing)
# - RPC cache: ~3-4GB (8 fixed threads)
# - Ledger/Snapshot: ~10GB
# - System/Geyser/Buffers: ~15-20GB
# Total: ~96-106GB peak (optimized from 110GB)

exec agave-validator \
 --geyser-plugin-config /root/sol/bin/yellowstone-config.json \
 --ledger /root/sol/ledger \
 --accounts /root/sol/accounts \
 --identity /root/sol/bin/validator-keypair.json \
 --snapshots /root/sol/snapshot \
 --log /root/solana-rpc.log \
 \
 `# ============ Network Configuration ============` \
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
 --only-known-rpc \
 --no-port-check \
 --dynamic-port-range 8000-8025 \
 --gossip-port 8001 \
 \
 `# ============ RPC Configuration (Memory-Optimized) ============` \
 --rpc-bind-address 0.0.0.0 \
 --rpc-port 8899 \
 --full-rpc-api \
 --private-rpc \
 --rpc-threads $RPC_THREADS \
 --rpc-max-multiple-accounts 50 \
 --rpc-max-request-body-size 20971520 \
 --rpc-bigtable-timeout 180 \
 --rpc-send-retry-ms 1000 \
 \
 `# ============ Account Index (MINIMAL - Critical for Memory) ============` \
 `# Each index adds ~2-5GB memory usage` \
 `# Only enable program-id (essential for RPC queries)` \
 --account-index program-id \
 --account-index-include-key AddressLookupTab1e1111111111111111111111111 \
 \
 `# ============ Snapshot Configuration (Memory-Efficient) ============` \
 --no-incremental-snapshots \
 --maximum-full-snapshots-to-retain 2 \
 --maximum-incremental-snapshots-to-retain 2 \
 --minimal-snapshot-download-speed 10485760 \
 --use-snapshot-archives-at-startup when-newest \
 \
 `# ============ Ledger Management ============` \
 --limit-ledger-size 50000000 \
 --wal-recovery-mode skip_any_corrupted_record \
 --enable-rpc-transaction-history \
 \
 `# ============ Accounts DB (CRITICAL Memory Settings) ============` \
 `# Optimized cache limit for memory efficiency (1.5GB)` \
 --accounts-db-cache-limit-mb 1536 \
 `# Aggressive shrink threshold to reduce DB bloat (ratio 0.90 = 90%)` \
 --accounts-shrink-ratio 0.90 \
 `# Reduced bins for lower memory overhead (2048 instead of 4096)` \
 --accounts-index-bins 2048 \
 \
 `# ============ Performance Tuning (Memory-Aware) ============` \
 --block-production-method central-scheduler \
 --health-check-slot-distance 150 \
 \
 `# ============ RPC Node Specific ============` \
 --no-voting \
 --allow-private-addr \
 \
 `# ============ Memory & Resource Management ============` \
 --bind-address 0.0.0.0 \
 `# Reduced log buffer for memory efficiency (256MB instead of 512MB)` \
 --log-messages-bytes-limit 268435456
