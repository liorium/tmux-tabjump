#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$CURRENT_DIR/common.sh"

current_tab="$(active_tab_number 2>/dev/null || true)"
last_tab="$(tmux show-option -gqv "@tabjump-last-tab" 2>/dev/null || true)"

if ! [[ "$last_tab" =~ ^[1-9][0-9]*$ ]]; then
  tmux display-message "$(t error.no_previous_tab)"
  exit 0
fi

if [ -n "$current_tab" ] && [ "$last_tab" = "$current_tab" ]; then
  tmux display-message "$(t error.already_previous_tab)"
  exit 0
fi

exec "$CURRENT_DIR/jump-visible-pane.sh" "$last_tab"
