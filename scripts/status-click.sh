#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$CURRENT_DIR/common.sh"

range_value="${1:-}"

case "$range_value" in
menu)
  exec "$CURRENT_DIR/pane-menu.sh" show
  ;;
tab:*)
  tab_number="${range_value#tab:}"
  if "$CURRENT_DIR/jump-visible-pane.sh" "$tab_number"; then
    tmux refresh-client -S >/dev/null 2>&1 || true
  fi
  ;;
esac
