#!/bin/bash
# Close public access to RPC, WebSocket, and Yellowstone gRPC.
# Deletes every matching ufw rule (including previous allows) then denies the ports.
# Loopback is not filtered by these rules, so localhost RPC still works.

close_ufw_public_api_ports() {
  local port rule_num i status_out

  if ! command -v ufw >/dev/null 2>&1; then
    return 0
  fi

  for port in 8899 8900 10900; do
    i=0
    while ((i < 50)); do
      status_out=$(LC_ALL=C ufw status numbered 2>/dev/null || true)
      rule_num=$(awk -v p="$port" '
        {
          if ($0 !~ /^\[/) next
          line = $0
          sub(/^\[ */, "", line)
          sub(/\].*/, "", line)
          if (line !~ /^[0-9]+$/) next
          if ($0 ~ "(^|[^0-9])" p "([^0-9]|$)") {
            print line
            exit
          }
        }
      ' <<<"$status_out")
      [[ -n "$rule_num" ]] || break
      yes | ufw delete "$rule_num" >/dev/null 2>&1 || break
      i=$((i + 1))
    done
    ufw deny "$port"/tcp >/dev/null 2>&1 || true
  done
}
