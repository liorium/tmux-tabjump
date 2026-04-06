#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$CURRENT_DIR/common.sh"

range_value="${1:-}"
event_phase="${2:-down}"
client_target="${3:-}"
jump_visible_pane_script="${TABJUMP_JUMP_SCRIPT:-$CURRENT_DIR/jump-visible-pane.sh}"
pane_menu_script="${TABJUMP_PANE_MENU_SCRIPT:-$CURRENT_DIR/pane-menu.sh}"

case "$range_value" in
menu)
  if [ "$event_phase" = "up" ]; then
    exec "$pane_menu_script" show "" "$client_target"
  fi
  ;;
tab:*)
  if [ "$event_phase" = "down" ]; then
    tab_number="${range_value#tab:}"
    if "$jump_visible_pane_script" "$tab_number"; then
      tmux refresh-client -S >/dev/null 2>&1 || true
    fi
  fi
  ;;
esac
