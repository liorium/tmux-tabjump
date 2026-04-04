#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$CURRENT_DIR/common.sh"

ACTIVE_PANE_ID="${1:-}"
ACTIVE_TAB_ACCENT="#3B82F6"

render_badge() {
  local range="$1"
  local label="$2"
  local fg="$3"
  local bg="$4"
  local right_edge="${5:-round}"

  if [ "$right_edge" = "square" ]; then
    printf '#[range=user|%s]#[fg=%s,bg=#1e1e2e]#[bold,fg=%s,bg=%s] %s #[default]#[norange]' \
      "$range" "$bg" "$fg" "$bg" "$label"
    return
  fi

  printf '#[range=user|%s]#[fg=%s,bg=#1e1e2e]#[bold,fg=%s,bg=%s] %s #[fg=%s,bg=#1e1e2e]#[default]#[norange]' \
    "$range" "$bg" "$fg" "$bg" "$label" "$bg"
}

render_menu_badge() {
  printf '#[range=user|menu]#[fg=#6c7086,bg=#1e1e2e]#[bold,fg=#11111b,bg=#6c7086]m #[fg=#cdd6f4,bg=#313244] menu #[default]#[norange]'
}

render_tab_badge() {
  local index="$1"
  local label="$2"
  local number_bg="$3"
  local number_fg="${4:-#11111b}"
  local label_fg="$5"
  local label_bg="${6:-#313244}"

  printf '#[range=user|tab:%s]#[fg=%s,bg=#1e1e2e]#[bold,fg=%s,bg=%s]%s #[fg=%s,bg=%s] %s #[fg=%s,bg=#1e1e2e]#[default]#[norange]' \
    "$index" "$number_bg" "$number_fg" "$number_bg" "$index" "$label_fg" "$label_bg" "$label" "$label_bg"
}

append_segment() {
  local -n ref="$1"
  local segment="$2"

  if [ -n "$ref" ]; then
    ref+=" "
  fi
  ref+="$segment"
}

badges_output=""
tabs_output=""
client_width="$(tmux display-message -p -t "${ACTIVE_PANE_ID:-}" '#{client_width}' 2>/dev/null || printf '120')"
if ! [[ "$client_width" =~ ^[0-9]+$ ]]; then
  client_width=120
fi

append_segment badges_output "$(render_menu_badge)"

tab_names=()
tab_panes=()
load_tabs tab_names tab_panes

if [ "${#tab_names[@]}" -eq 0 ]; then
  append_segment tabs_output "$(render_badge "empty" "no tabs" "#11111b" "#45475a")"
  printf '#[align=left]%s#[align=right]%s' "$tabs_output" "$badges_output"
  exit 0
fi

label_budget=$((client_width - 18))
if [ "$label_budget" -lt 12 ]; then
  label_budget=12
fi

per_tab_budget=$((label_budget / ${#tab_names[@]}))
if [ "$per_tab_budget" -lt 10 ]; then
  per_tab_budget=10
fi
if [ "$per_tab_budget" -gt 24 ]; then
  per_tab_budget=24
fi

for idx in "${!tab_names[@]}"; do
  tab_number=$((idx + 1))
  tab_name="${tab_names[$idx]}"
  pane_id="${tab_panes[$idx]}"
  label_fg="#cdd6f4"
  number_bg="#6c7086"
  number_fg="#11111b"
  label_bg="#313244"

  if [ "$pane_id" = "$ACTIVE_PANE_ID" ] && [ -n "$pane_id" ]; then
    number_bg="$ACTIVE_TAB_ACCENT"
  elif [ -z "$pane_id" ]; then
    number_bg="#f9e2af"
    label_fg="#f9e2af"
    tab_name="${tab_name} · empty"
  elif ! tab_has_live_pane "$pane_id"; then
    number_bg="#f38ba8"
    label_fg="#f38ba8"
    tab_name="${tab_name} · dead"
  fi

  tab_name="$(truncate_label "$tab_name" "$per_tab_budget")"
  append_segment tabs_output "$(render_tab_badge "$tab_number" "$tab_name" "$number_bg" "$number_fg" "$label_fg" "$label_bg")"
done

printf '#[align=left]%s#[align=right]%s' "$tabs_output" "$badges_output"
