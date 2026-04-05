#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/common.sh
source "$CURRENT_DIR/scripts/common.sh"

status_line="$(get_plugin_opt "status-line" "1")"
pane_menu_key="$(get_plugin_opt "pane-menu-key" "m")"
direct_jump="$(get_plugin_opt "direct-jump" "on")"
refresh_hook_cmd="run-shell '$CURRENT_DIR/scripts/refresh-status.sh'"

"$CURRENT_DIR/scripts/load-tabs.sh"

current_status_lines="$(tmux show-option -gqv "status" 2>/dev/null || true)"
if [ -z "$current_status_lines" ] || [ "$current_status_lines" = "on" ] || [ "$current_status_lines" = "1" ]; then
  target_lines=$((status_line + 1))
  tmux set -g status "$target_lines"
elif [ "$current_status_lines" -ge 2 ] 2>/dev/null && [ "$status_line" -ge "$current_status_lines" ]; then
  target_lines=$((status_line + 1))
  tmux set -g status "$target_lines"
fi

statusline_cmd="#[bg=#1e1e2e]#[fg=#cdd6f4]#($CURRENT_DIR/scripts/statusline.sh '#{pane_id}')"
current_format="$(tmux show-option -gqv "status-format[${status_line}]" 2>/dev/null || true)"
if [ "$current_format" != "$statusline_cmd" ]; then
  tmux set -g "status-format[${status_line}]" "$statusline_cmd"
fi

tmux unbind-key -n MouseDown1Status 2>/dev/null || true
tmux bind-key -n MouseDown1Status if-shell -F "#{==:#{mouse_status_line},${status_line}}" "run-shell -b '$CURRENT_DIR/scripts/status-click.sh \"#{mouse_status_range}\" down'" "select-window -t ="
tmux unbind-key -n MouseUp1Status 2>/dev/null || true
tmux bind-key -n MouseUp1Status if-shell -F "#{&&:#{==:#{mouse_status_line},${status_line}},#{==:#{mouse_status_range},menu}}" "run-shell '$CURRENT_DIR/scripts/status-click.sh \"menu\" up \"#{client_tty}\"'" ""
tmux unbind-key a 2>/dev/null || true
tmux unbind-key j 2>/dev/null || true
tmux unbind-key "$pane_menu_key" 2>/dev/null || true
tmux bind-key "$pane_menu_key" run-shell -b "$CURRENT_DIR/scripts/pane-menu.sh show \"\" \"#{client_tty}\""

if [ "$direct_jump" = "on" ]; then
  for i in 1 2 3 4 5 6 7 8 9; do
    tmux unbind-key -n "M-$i" 2>/dev/null || true
    tmux bind-key -n "M-$i" run-shell -b "$CURRENT_DIR/scripts/jump-visible-pane.sh $i"
  done
  tmux unbind-key -n "M-\`" 2>/dev/null || true
  tmux bind-key -n "M-\`" run-shell -b "$CURRENT_DIR/scripts/jump-last-tab.sh"
fi

tmux set-hook -g session-created "$refresh_hook_cmd"
tmux set-hook -g session-closed "$refresh_hook_cmd"
tmux set-hook -g session-renamed "$refresh_hook_cmd"
tmux set-hook -g session-window-changed "$refresh_hook_cmd"
tmux set-hook -g window-linked "$refresh_hook_cmd"
tmux set-hook -g window-unlinked "$refresh_hook_cmd"
tmux set-hook -g window-renamed "$refresh_hook_cmd"
tmux set-hook -g window-layout-changed "$refresh_hook_cmd"
tmux set-hook -g client-session-changed "$refresh_hook_cmd"
tmux set-hook -g pane-exited "$refresh_hook_cmd"
tmux set-hook -g after-new-session "$refresh_hook_cmd"
tmux set-hook -g after-new-window "$refresh_hook_cmd"
tmux set-hook -g after-split-window "$refresh_hook_cmd"
tmux set-hook -g after-kill-pane "$refresh_hook_cmd"
tmux set-hook -g after-rename-session "$refresh_hook_cmd"
tmux set-hook -g after-rename-window "$refresh_hook_cmd"
tmux set-hook -g after-select-pane "$refresh_hook_cmd"
tmux set-hook -g after-select-window "$refresh_hook_cmd"

"$CURRENT_DIR/scripts/refresh-status.sh"
