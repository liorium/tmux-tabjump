#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$CURRENT_DIR/common.sh"

action="${1:-show}"
arg1="${2:-}"
arg2="${3:-}"
arg3="${4:-}"

refresh_view() {
  tmux refresh-client -S >/dev/null 2>&1 || true
}

show_main_menu() {
  local client_target="${1:-}"
  local current_pane_id
  current_pane_id="$(tmux display-message -p '#{pane_id}')"

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local cmd=(
    tmux
    display-menu
    -T "Tabs"
    -x popup_centre_x
    -y popup_status_line_y
  )

  cmd+=(
    "＋ 새 탭 (현재 pane)" "n" "command-prompt -p 'Tab name' \"run-shell '$CURRENT_DIR/pane-menu.sh create-current \\\"%%\\\" $current_pane_id \\\"$client_target\\\"'\""
    "＋ 새 탭 (pane 선택)" "N" "command-prompt -p 'Tab name' \"run-shell '$CURRENT_DIR/pane-menu.sh show-pane-picker new \\\"%%\\\" \\\"$client_target\\\"'\""
    "↺ 죽은 탭 정리" "x" "run-shell '$CURRENT_DIR/pane-menu.sh prune \"$client_target\"'"
  )

  if tab_index_for_pane "$current_pane_id" >/dev/null 2>&1; then
    cmd+=("⊘ 현재 pane 탭 해제" "u" "run-shell '$CURRENT_DIR/pane-menu.sh detach-pane $current_pane_id \"$client_target\"'")
  fi

  cmd+=("" "" "")

  if [ "${#tab_names[@]}" -eq 0 ]; then
    cmd+=("(탭이 없습니다)" "" "")
  else
    local idx key status suffix
    for idx in "${!tab_names[@]}"; do
      key=""
      if [ $((idx + 1)) -le 9 ]; then
        key="$((idx + 1))"
      fi

      suffix=""
      if [ "${tab_panes[$idx]}" = "$current_pane_id" ]; then
        suffix=" ← current"
      elif [ -z "${tab_panes[$idx]}" ]; then
        suffix=" · empty"
      elif ! tab_has_live_pane "${tab_panes[$idx]}"; then
        suffix=" · dead"
      else
        status="$(pane_descriptor_from_id "${tab_panes[$idx]}")"
        [ -n "$status" ] && suffix=" · ${status}"
      fi

      cmd+=("$((idx + 1)) ${tab_names[$idx]}${suffix}" "$key" "run-shell '$CURRENT_DIR/pane-menu.sh show-tab $((idx + 1)) \"$client_target\"'")
    done
  fi

  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi

  "${cmd[@]}"
}

show_tab_menu() {
  local tab_number="$1"
  local client_target="${2:-}"

  if ! [[ "$tab_number" =~ ^[1-9][0-9]*$ ]]; then
    tmux display-message "invalid tab number"
    exit 0
  fi

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local tab_index=$((tab_number - 1))
  if [ "$tab_index" -ge "${#tab_names[@]}" ]; then
    tmux display-message "tab ${tab_number} does not exist"
    exit 0
  fi

  local tab_name="${tab_names[$tab_index]}"
  local pane_id="${tab_panes[$tab_index]}"
  local status="empty"
  if [ -n "$pane_id" ]; then
    if tab_has_live_pane "$pane_id"; then
      status="$(pane_descriptor_from_id "$pane_id")"
    else
      status="dead"
    fi
  fi

  local cmd=(
    tmux
    display-menu
    -T "Tab ${tab_number} · ${tab_name}"
    -x popup_centre_x
    -y popup_status_line_y
  )

  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi

  if [ -n "$pane_id" ] && tab_has_live_pane "$pane_id"; then
    cmd+=("→ 이동 · ${status}" "g" "run-shell '$CURRENT_DIR/pane-menu.sh focus $tab_number \"$client_target\"'")
  else
    cmd+=("(연결된 pane: ${status})" "" "")
  fi

  cmd+=(
    "⇄ pane 붙이기" "a" "run-shell '$CURRENT_DIR/pane-menu.sh show-pane-picker attach $tab_number \"$client_target\"'"
    "✎ 이름 변경" "r" "command-prompt -I \"$tab_name\" -p 'Rename tab' \"run-shell '$CURRENT_DIR/pane-menu.sh rename $tab_number \\\"%%\\\" \\\"$client_target\\\"'\""
  )

  if [ -n "$pane_id" ]; then
    cmd+=("⊘ pane 해제" "u" "run-shell '$CURRENT_DIR/pane-menu.sh detach-tab $tab_number \"$client_target\"'")
  fi

  cmd+=(
    "✕ 탭 삭제" "d" "run-shell '$CURRENT_DIR/pane-menu.sh delete $tab_number \"$client_target\"'"
    "" "" ""
    "← 메인 메뉴" "b" "run-shell '$CURRENT_DIR/pane-menu.sh show \"$client_target\"'"
  )

  "${cmd[@]}"
}

show_pane_picker() {
  local mode="$1"
  local target="$2"
  local client_target="${3:-}"

  local pane_rows=()
  load_pane_rows pane_rows

  local title
  if [ "$mode" = "attach" ]; then
    title="Attach pane → tab ${target}"
  else
    title="새 탭 '${target}' → pane 선택"
  fi

  local cmd=(
    tmux
    display-menu
    -T "$title"
    -x popup_centre_x
    -y popup_status_line_y
  )

  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi

  if [ "${#pane_rows[@]}" -eq 0 ]; then
    cmd+=("(pane이 없습니다)" "" "")
  else
    local idx row pane_id key label current_marker
    for idx in "${!pane_rows[@]}"; do
      row="${pane_rows[$idx]}"
      IFS=$'\t' read -r _ _ _ _ pane_id _ <<<"$row"
      key=""
      if [ $((idx + 1)) -le 9 ]; then
        key="$((idx + 1))"
      fi

      current_marker=""
      if [ "$pane_id" = "$(tmux display-message -p '#{pane_id}')" ]; then
        current_marker=" ← current"
      fi

      label="$((idx + 1)) $(pane_descriptor_from_row "$row")${current_marker}"
      if [ "$mode" = "attach" ]; then
        cmd+=("$label" "$key" "run-shell '$CURRENT_DIR/pane-menu.sh attach-pane $target $pane_id \"$client_target\"'")
      else
        cmd+=("$label" "$key" "run-shell '$CURRENT_DIR/pane-menu.sh create-selected \"$target\" $pane_id \"$client_target\"'")
      fi
    done
  fi

  cmd+=("" "" "" "← 돌아가기" "b" "run-shell '$CURRENT_DIR/pane-menu.sh show \"$client_target\"'")
  "${cmd[@]}"
}

create_tab() {
  local tab_name="$1"
  local pane_id="$2"
  local client_target="${3:-}"
  tab_name="$(normalize_tab_name "$tab_name")"
  [ -n "$tab_name" ] || { tmux display-message "tab name is required"; exit 0; }

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes
  remove_pane_from_tabs "$pane_id" tab_panes
  tab_names+=("$tab_name")
  tab_panes+=("$pane_id")
  save_tabs tab_names tab_panes
  persist_tabs_file
  refresh_view

  if [ -n "$client_target" ]; then
    show_main_menu "$client_target"
  fi
}

attach_pane_to_tab() {
  local tab_number="$1"
  local pane_id="$2"
  local client_target="${3:-}"

  if ! [[ "$tab_number" =~ ^[1-9][0-9]*$ ]]; then
    tmux display-message "invalid tab number"
    exit 0
  fi

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes
  local tab_index=$((tab_number - 1))

  if [ "$tab_index" -ge "${#tab_names[@]}" ]; then
    tmux display-message "tab ${tab_number} does not exist"
    exit 0
  fi

  remove_pane_from_tabs "$pane_id" tab_panes
  tab_panes[$tab_index]="$pane_id"
  save_tabs tab_names tab_panes
  persist_tabs_file
  refresh_view

  if [ -n "$client_target" ]; then
    show_tab_menu "$tab_number" "$client_target"
  fi
}

rename_tab() {
  local tab_number="$1"
  local new_name="$2"
  local client_target="${3:-}"
  new_name="$(normalize_tab_name "$new_name")"
  [ -n "$new_name" ] || { tmux display-message "tab name is required"; exit 0; }

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes
  local tab_index=$((tab_number - 1))
  [ "$tab_index" -lt "${#tab_names[@]}" ] || { tmux display-message "tab ${tab_number} does not exist"; exit 0; }

  tab_names[$tab_index]="$new_name"
  save_tabs tab_names tab_panes
  persist_tabs_file
  refresh_view

  if [ -n "$client_target" ]; then
    show_tab_menu "$tab_number" "$client_target"
  fi
}

detach_tab() {
  local tab_number="$1"
  local client_target="${2:-}"

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes
  local tab_index=$((tab_number - 1))
  [ "$tab_index" -lt "${#tab_names[@]}" ] || { tmux display-message "tab ${tab_number} does not exist"; exit 0; }

  tab_panes[$tab_index]=""
  save_tabs tab_names tab_panes
  persist_tabs_file
  refresh_view

  if [ -n "$client_target" ]; then
    show_tab_menu "$tab_number" "$client_target"
  fi
}

detach_current_pane() {
  local pane_id="$1"
  local client_target="${2:-}"
  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes
  remove_pane_from_tabs "$pane_id" tab_panes
  save_tabs tab_names tab_panes
  persist_tabs_file
  refresh_view

  if [ -n "$client_target" ]; then
    show_main_menu "$client_target"
  fi
}

delete_tab() {
  local tab_number="$1"
  local client_target="${2:-}"

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes
  local tab_index=$((tab_number - 1))
  [ "$tab_index" -lt "${#tab_names[@]}" ] || { tmux display-message "tab ${tab_number} does not exist"; exit 0; }

  local next_names=()
  local next_panes=()
  local idx
  for idx in "${!tab_names[@]}"; do
    [ "$idx" -eq "$tab_index" ] && continue
    next_names+=("${tab_names[$idx]}")
    next_panes+=("${tab_panes[$idx]}")
  done

  save_tabs next_names next_panes
  persist_tabs_file
  refresh_view

  if [ -n "$client_target" ]; then
    show_main_menu "$client_target"
  fi
}

prune_dead_tabs() {
  local client_target="${1:-}"
  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local next_names=()
  local next_panes=()
  local idx pane_id
  for idx in "${!tab_names[@]}"; do
    pane_id="${tab_panes[$idx]}"
    if [ -n "$pane_id" ] && ! tab_has_live_pane "$pane_id"; then
      continue
    fi
    next_names+=("${tab_names[$idx]}")
    next_panes+=("$pane_id")
  done

  save_tabs next_names next_panes
  persist_tabs_file
  refresh_view

  if [ -n "$client_target" ]; then
    show_main_menu "$client_target"
  fi
}

focus_tab() {
  local tab_number="$1"
  local client_target="${2:-}"
  "$CURRENT_DIR/jump-visible-pane.sh" "$tab_number" >/dev/null 2>&1 || true
  refresh_view
  if [ -n "$client_target" ]; then
    show_tab_menu "$tab_number" "$client_target"
  fi
}

case "$action" in
show)
  show_main_menu "$arg1"
  ;;
show-tab)
  show_tab_menu "$arg1" "$arg2"
  ;;
show-pane-picker)
  show_pane_picker "$arg1" "$arg2" "$arg3"
  ;;
create-current)
  create_tab "$arg1" "$arg2" "$arg3"
  ;;
create-selected)
  create_tab "$arg1" "$arg2" "$arg3"
  ;;
attach-pane)
  attach_pane_to_tab "$arg1" "$arg2" "$arg3"
  ;;
rename)
  rename_tab "$arg1" "$arg2" "$arg3"
  ;;
detach-tab)
  detach_tab "$arg1" "$arg2"
  ;;
detach-pane)
  detach_current_pane "$arg1" "$arg2"
  ;;
delete)
  delete_tab "$arg1" "$arg2"
  ;;
prune)
  prune_dead_tabs "$arg1"
  ;;
focus)
  focus_tab "$arg1" "$arg2"
  ;;
esac
