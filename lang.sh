#!/usr/bin/env bash
# Shared language selection for 1-prepare.sh, 2-install-jito-validator.sh, 3-start.sh
# Source this file, then call prompt_lang to set LANG_SCRIPT (zh or en)
# Language choice is cached so user only selects once.

LANG_CACHE_FILE="${LANG_CACHE_FILE:-/root/solana-rpc-lang}"

prompt_lang() {
  # Use cached language if valid
  if [[ -f "$LANG_CACHE_FILE" ]]; then
    cached=$(head -n1 "$LANG_CACHE_FILE" 2>/dev/null | tr -d '[:space:]')
    if [[ "$cached" == "zh" || "$cached" == "en" ]]; then
      export LANG_SCRIPT="$cached"
      return 0
    fi
  fi

  echo ""
  echo "Select language / 选择语言:"
  echo "  1) 中文"
  echo "  2) English"
  echo ""
  while true; do
    read -p "Choice [1/2]: " lang_choice
    case "${lang_choice:-1}" in
      1) export LANG_SCRIPT="zh"; break ;;
      2) export LANG_SCRIPT="en"; break ;;
      *) echo "Invalid. Enter 1 or 2. / 请输入 1 或 2。" ;;
    esac
  done

  # Cache selection for next run (any of 1-/2-/3- scripts)
  echo "$LANG_SCRIPT" > "$LANG_CACHE_FILE" 2>/dev/null || true
  echo ""
}
