#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$CURRENT_DIR/common.sh"

target_index="${1:-}"

if ! [[ "$target_index" =~ ^[1-9][0-9]*$ ]]; then
  tmux display-message "$(t error.tab_index_positive)"
  exit 0
fi

tab_names=()
tab_panes=()
load_tabs tab_names tab_panes

target_pos=$((target_index - 1))
if [ "$target_pos" -ge "${#tab_names[@]}" ]; then
  tmux display-message "$(tf error.tab_unavailable "$target_index")"
  exit 0
fi

tab_name="${tab_names[$target_pos]}"
pane_id="${tab_panes[$target_pos]}"

if [ -z "$pane_id" ]; then
  tmux display-message "$(tf error.tab_is_empty "$tab_name")"
  exit 0
fi

if ! tab_has_live_pane "$pane_id"; then
  tmux display-message "$(tf error.tab_points_dead "$tab_name")"
  exit 0
fi

if focus_pane_by_id "$pane_id"; then
  tmux refresh-client -S >/dev/null 2>&1 || true
fi
