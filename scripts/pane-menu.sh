#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$CURRENT_DIR/common.sh"

action="${1:-show}"
arg1="${2:-}"
arg2="${3:-}"
arg3="${4:-}"
arg4="${5:-}"
MENU_Y="${TABJUMP_MENU_Y:-C}"
MENU_X="${TABJUMP_MENU_X:-C}"

refresh_view() {
  tmux refresh-client -S >/dev/null 2>&1 || true
}

resolve_client_target() {
  local primary="${1:-}"
  local fallback="${2:-}"
  if [ -n "$primary" ]; then
    printf '%s\n' "$primary"
    return
  fi
  printf '%s\n' "$fallback"
}

add_menu_position() {
  local -n cmd_ref="$1"
  cmd_ref+=(-x "$MENU_X" -y "$MENU_Y")
}

tab_status_label() {
  local kind="$1"
  case "$kind" in
  current)
    printf '현재 pane\n'
    ;;
  empty)
    printf '비어 있음\n'
    ;;
  dead)
    printf '죽은 pane\n'
    ;;
  *)
    printf '연결됨\n'
    ;;
  esac
}

tab_status_kind() {
  local pane_id="$1"
  local current_pane_id="${2:-}"

  if [ -n "$pane_id" ] && [ "$pane_id" = "$current_pane_id" ]; then
    printf 'current\n'
  elif [ -z "$pane_id" ]; then
    printf 'empty\n'
  elif ! tab_has_live_pane "$pane_id"; then
    printf 'dead\n'
  else
    printf 'connected\n'
  fi
}

tab_status_style() {
  local kind="$1"
  case "$kind" in
  current)
    printf '#[fg=#3B82F6,bold]'
    ;;
  empty)
    printf '#[fg=#f9e2af]'
    ;;
  dead)
    printf '#[fg=#f38ba8]'
    ;;
  *)
    printf '#[fg=#cdd6f4]'
    ;;
  esac
}

tab_menu_label() {
  local tab_number="$1"
  local tab_name="$2"
  local pane_id="$3"
  local current_pane_id="$4"
  local kind
  kind="$(tab_status_kind "$pane_id" "$current_pane_id")"
  printf '%s%s %s · %s#[default]\n' "$(tab_status_style "$kind")" "$tab_number" "$tab_name" "$(tab_status_label "$kind")"
}

tab_status_row_label() {
  local pane_id="$1"
  local current_pane_id="$2"
  local kind
  kind="$(tab_status_kind "$pane_id" "$current_pane_id")"
  printf '상태 · %s%s#[default]\n' "$(tab_status_style "$kind")" "$(tab_status_label "$kind")"
}

current_pane_summary_label() {
  local current_pane_id="$1"
  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local tab_index
  if tab_index="$(tab_index_for_pane "$current_pane_id" 2>/dev/null)"; then
    printf '현재 상태 · #[fg=#3B82F6,bold]%s %s#[default]\n' "$((tab_index + 1))" "${tab_names[$tab_index]}"
    return
  fi

  printf '현재 상태 · #[fg=#f9e2af]탭 없음#[default]\n'
}

pane_assignment_label() {
  local pane_id="$1"
  local -n tab_names_ref="$2"
  local -n tab_panes_ref="$3"

  local idx
  for idx in "${!tab_panes_ref[@]}"; do
    if [ "${tab_panes_ref[$idx]}" = "$pane_id" ]; then
      printf '탭 %s %s\n' "$((idx + 1))" "${tab_names_ref[$idx]}"
      return
    fi
  done

  printf '미지정\n'
}

pane_picker_label() {
  local index="$1"
  local row="$2"
  local pane_id="$3"
  local current_marker="$4"
  local -n picker_tab_names_ref="$5"
  local -n picker_tab_panes_ref="$6"

  local descriptor assignment
  descriptor="$(truncate_label "$(pane_descriptor_from_row "$row")" 28)"
  assignment="$(truncate_label "$(pane_assignment_label "$pane_id" picker_tab_names_ref picker_tab_panes_ref)" 18)"
  printf '%s %s · %s%s\n' "$index" "$descriptor" "$assignment" "$current_marker"
}

tab_picker_title() {
  local mode="$1"
  case "$mode" in
  attach-current)
    printf '기존 탭에 붙이기\n'
    ;;
  attach-existing-tab)
    printf '붙일 탭 선택\n'
    ;;
  reorder)
    printf '순서 바꿀 탭 선택\n'
    ;;
  rename)
    printf '이름 바꿀 탭 선택\n'
    ;;
  delete)
    printf '삭제할 탭 선택\n'
    ;;
  *)
    printf '탭 선택\n'
    ;;
  esac
}

resume_menu() {
  local mode="${1:-main}"
  local client_target="${2:-}"
  local primary="${3:-}"
  [ -n "$client_target" ] || return

  case "$mode" in
  pane)
    show_pane_actions "$client_target"
    ;;
  manage)
    show_manage_menu "$client_target"
    ;;
  reorder)
    show_reorder_menu "$primary" "$client_target"
    ;;
  tab)
    show_tab_menu "$primary" "$client_target"
    ;;
  *)
    show_main_menu "$client_target"
    ;;
  esac
}

show_main_menu() {
  local client_target
  client_target="$(resolve_client_target "${1:-}" "${2:-}")"

  local cmd=(
    tmux
    display-menu
    -T "Tabjump"
  )
  add_menu_position cmd
  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi
  cmd+=(--)

  cmd+=(
    "현재 pane 작업" "p" "run-shell '$CURRENT_DIR/pane-menu.sh show-pane-actions \"$client_target\"'"
    "탭 관리" "t" "run-shell '$CURRENT_DIR/pane-menu.sh show-manage-menu \"$client_target\"'"
    "단축키 보기" "?" "run-shell '$CURRENT_DIR/pane-menu.sh show-shortcuts \"$client_target\"'"
  )

  "${cmd[@]}"
}

show_shortcuts_menu() {
  local client_target
  client_target="$(resolve_client_target "${1:-}" "${2:-}")"

  local cmd=(
    tmux
    display-menu
    -T "단축키"
  )
  add_menu_position cmd
  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi
  cmd+=(--)

  cmd+=(
    "Option+1..9: 해당 탭으로 이동" "" ""
    'Option+`: 이전 탭으로 이동' "" ""
    "prefix + m: 현재 pane 작업 열기" "" ""
    "" "" ""
    "메뉴 안 Enter: 선택한 탭으로 이동/실행" "" ""
    "메뉴 안 b: 뒤로가기" "" ""
    "" "" ""
    "← 메인 메뉴" "b" "run-shell '$CURRENT_DIR/pane-menu.sh show \"$client_target\"'"
  )

  "${cmd[@]}"
}

show_pane_actions() {
  local client_target
  client_target="$(resolve_client_target "${1:-}" "${2:-}")"
  local current_pane_id
  current_pane_id="$(tmux display-message -p '#{pane_id}')"

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local cmd=(
    tmux
    display-menu
    -T "현재 pane 작업"
  )
  add_menu_position cmd
  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi
  cmd+=(--)

  cmd+=("$(current_pane_summary_label "$current_pane_id")" "" "")

  if [ "${#tab_names[@]}" -gt 0 ]; then
    cmd+=("⇄ 기존 탭에 붙이기" "a" "run-shell '$CURRENT_DIR/pane-menu.sh show-tab-picker attach-current $current_pane_id \"$client_target\"'")
  else
    cmd+=("-(탭이 없습니다)" "" "")
  fi

  cmd+=("＋ 새 탭에 붙이기" "n" "command-prompt -p 'Tab name' \"run-shell '$CURRENT_DIR/pane-menu.sh create-current \\\"%%\\\" $current_pane_id \\\"$client_target\\\" pane'\"")

  if tab_index_for_pane "$current_pane_id" >/dev/null 2>&1; then
    cmd+=("⊘ 현재 탭에서 해제" "u" "run-shell '$CURRENT_DIR/pane-menu.sh detach-pane $current_pane_id \"$client_target\" pane'")
  fi

  cmd+=("" "" "" "← 메인 메뉴" "b" "run-shell '$CURRENT_DIR/pane-menu.sh show \"$client_target\"'")
  "${cmd[@]}"
}

show_manage_menu() {
  local client_target
  client_target="$(resolve_client_target "${1:-}" "${2:-}")"

  local cmd=(
    tmux
    display-menu
    -T "탭 관리"
  )
  add_menu_position cmd
  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi
  cmd+=(--)

  cmd+=(
    "다른 pane 붙이기" "" ""
    "⇄ 다른 pane을 기존 탭에 붙이기" "a" "run-shell '$CURRENT_DIR/pane-menu.sh show-tab-picker attach-existing-tab \"\" \"$client_target\"'"
    "＋ 다른 pane으로 새 탭 만들기" "n" "command-prompt -p 'Tab name' \"run-shell '$CURRENT_DIR/pane-menu.sh show-pane-picker create-selected \\\"%%\\\" \\\"$client_target\\\"'\""
    "" "" ""
    "탭 구조 관리" "" ""
    "⇅ 순서 변경" "o" "run-shell '$CURRENT_DIR/pane-menu.sh show-tab-picker reorder \"\" \"$client_target\"'"
    "✎ 이름 변경" "r" "run-shell '$CURRENT_DIR/pane-menu.sh show-tab-picker rename \"\" \"$client_target\"'"
    "✕ 삭제" "d" "run-shell '$CURRENT_DIR/pane-menu.sh show-tab-picker delete \"\" \"$client_target\"'"
    "↺ dead/empty 정리" "x" "run-shell '$CURRENT_DIR/pane-menu.sh show-prune-confirm \"$client_target\" manage'"
    "" "" ""
    "← 메인 메뉴" "b" "run-shell '$CURRENT_DIR/pane-menu.sh show \"$client_target\"'"
  )

  "${cmd[@]}"
}

show_delete_confirm_menu() {
  local tab_number="$1"
  local client_target="${2:-}"
  local origin_mode="${3:-main}"

  if ! [[ "$tab_number" =~ ^[1-9][0-9]*$ ]]; then
    tmux display-message "invalid tab number"
    exit 0
  fi

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local tab_index=$((tab_number - 1))
  [ "$tab_index" -lt "${#tab_names[@]}" ] || { tmux display-message "tab ${tab_number} does not exist"; exit 0; }

  local current_pane_id
  current_pane_id="$(tmux display-message -p '#{pane_id}')"
  local delete_return_mode="$origin_mode"
  local back_command

  if [ "$delete_return_mode" = "tab" ]; then
    delete_return_mode="main"
  fi

  case "$origin_mode" in
  manage)
    back_command="run-shell '$CURRENT_DIR/pane-menu.sh show-manage-menu \"$client_target\"'"
    ;;
  tab)
    back_command="run-shell '$CURRENT_DIR/pane-menu.sh show-tab $tab_number \"$client_target\"'"
    ;;
  *)
    back_command="run-shell '$CURRENT_DIR/pane-menu.sh show \"$client_target\"'"
    ;;
  esac

  local cmd=(
    tmux
    display-menu
    -T "삭제 확인 · ${tab_names[$tab_index]}"
  )
  add_menu_position cmd
  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi
  cmd+=(--)

  cmd+=(
    "$(tab_menu_label "$tab_number" "${tab_names[$tab_index]}" "${tab_panes[$tab_index]}" "$current_pane_id")" "" ""
    "정말 삭제할까요?" "" ""
    "✕ 삭제" "d" "run-shell '$CURRENT_DIR/pane-menu.sh delete $tab_number \"$client_target\" $delete_return_mode'"
    "" "" ""
    "← 돌아가기" "b" "$back_command"
  )

  "${cmd[@]}"
}

show_prune_confirm_menu() {
  local client_target="${1:-}"
  local return_mode="${2:-main}"
  local back_command

  case "$return_mode" in
  manage)
    back_command="run-shell '$CURRENT_DIR/pane-menu.sh show-manage-menu \"$client_target\"'"
    ;;
  *)
    back_command="run-shell '$CURRENT_DIR/pane-menu.sh show \"$client_target\"'"
    ;;
  esac

  local cmd=(
    tmux
    display-menu
    -T "정리 확인"
  )
  add_menu_position cmd
  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi
  cmd+=(--)

  cmd+=(
    "dead/empty 탭을 정리할까요?" "" ""
    "비어 있거나 연결이 끊긴 탭이 삭제됩니다." "" ""
    "↺ 정리" "x" "run-shell '$CURRENT_DIR/pane-menu.sh prune \"$client_target\" $return_mode'"
    "" "" ""
    "← 돌아가기" "b" "$back_command"
  )

  "${cmd[@]}"
}

show_reorder_menu() {
  local tab_number="$1"
  local client_target
  client_target="$(resolve_client_target "${2:-}" "${3:-}")"

  if ! [[ "$tab_number" =~ ^[1-9][0-9]*$ ]]; then
    tmux display-message "invalid tab number"
    exit 0
  fi

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local tab_index=$((tab_number - 1))
  [ "$tab_index" -lt "${#tab_names[@]}" ] || { tmux display-message "tab ${tab_number} does not exist"; exit 0; }

  local current_pane_id
  current_pane_id="$(tmux display-message -p '#{pane_id}')"

  local cmd=(
    tmux
    display-menu
    -T "순서 변경 · ${tab_names[$tab_index]}"
  )
  add_menu_position cmd
  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi
  cmd+=(--)

  cmd+=("$(tab_menu_label "$tab_number" "${tab_names[$tab_index]}" "${tab_panes[$tab_index]}" "$current_pane_id")" "" "")

  if [ "$tab_index" -gt 0 ]; then
    cmd+=("↑ 위로 이동" "k" "run-shell '$CURRENT_DIR/pane-menu.sh move-tab $tab_number up \"$client_target\"'")
  else
    cmd+=("-(이미 첫 번째 탭입니다)" "" "")
  fi

  if [ "$tab_index" -lt $((${#tab_names[@]} - 1)) ]; then
    cmd+=("↓ 아래로 이동" "j" "run-shell '$CURRENT_DIR/pane-menu.sh move-tab $tab_number down \"$client_target\"'")
  else
    cmd+=("-(이미 마지막 탭입니다)" "" "")
  fi

  cmd+=("" "" "" "← 탭 관리" "b" "run-shell '$CURRENT_DIR/pane-menu.sh show-manage-menu \"$client_target\"'")
  "${cmd[@]}"
}

show_tab_menu() {
  local tab_number="$1"
  local client_target
  client_target="$(resolve_client_target "${2:-}" "${3:-}")"

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
  local current_pane_id
  current_pane_id="$(tmux display-message -p '#{pane_id}')"
  local status_label
  status_label="$(tab_status_row_label "$pane_id" "$current_pane_id")"

  local cmd=(
    tmux
    display-menu
    -T "Tab ${tab_number} · ${tab_name}"
  )
  add_menu_position cmd
  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi
  cmd+=(--)

  cmd+=("$status_label" "" "")

  if [ -n "$pane_id" ] && tab_has_live_pane "$pane_id"; then
    cmd+=("→ 이동" "g" "run-shell '$CURRENT_DIR/pane-menu.sh focus $tab_number \"$client_target\"'")
  fi

  if [ "$current_pane_id" != "$pane_id" ]; then
    cmd+=("⇄ 현재 pane 붙이기" "c" "run-shell '$CURRENT_DIR/pane-menu.sh attach-pane $tab_number $current_pane_id \"$client_target\"'")
  fi

  cmd+=(
    "⇄ 다른 pane 선택" "a" "run-shell '$CURRENT_DIR/pane-menu.sh show-pane-picker attach $tab_number \"$client_target\"'"
    "✎ 이름 변경" "r" "command-prompt -I \"$tab_name\" -p 'Rename tab' \"run-shell '$CURRENT_DIR/pane-menu.sh rename $tab_number \\\"%%\\\" \\\"$client_target\\\"'\""
  )

  if [ -n "$pane_id" ]; then
    cmd+=("⊘ pane 해제" "u" "run-shell '$CURRENT_DIR/pane-menu.sh detach-tab $tab_number \"$client_target\"'")
  fi

  cmd+=(
    "✕ 탭 삭제" "d" "run-shell '$CURRENT_DIR/pane-menu.sh show-delete-confirm $tab_number \"$client_target\" tab'"
    "" "" ""
    "← 메인 메뉴" "b" "run-shell '$CURRENT_DIR/pane-menu.sh show \"$client_target\"'"
  )

  "${cmd[@]}"
}

show_pane_picker() {
  local mode="$1"
  local target="$2"
  local client_target
  client_target="$(resolve_client_target "${3:-}" "${4:-}")"

  local pane_rows=()
  load_pane_rows pane_rows
  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local title
  if [ "$mode" = "attach" ]; then
    title="Tab ${target}에 붙일 pane 선택"
  else
    title="새 탭 '${target}'에 붙일 pane 선택"
  fi

  local cmd=(
    tmux
    display-menu
    -T "$title"
  )
  add_menu_position cmd
  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi
  cmd+=(--)

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

      label="$(pane_picker_label "$((idx + 1))" "$row" "$pane_id" "$current_marker" tab_names tab_panes)"
      if [ "$mode" = "attach" ]; then
        cmd+=("$label" "$key" "run-shell '$CURRENT_DIR/pane-menu.sh attach-pane $target $pane_id \"$client_target\"'")
      else
        cmd+=("$label" "$key" "run-shell '$CURRENT_DIR/pane-menu.sh create-selected \"$target\" $pane_id \"$client_target\"'")
      fi
    done
  fi

  if [ "$mode" = "attach" ]; then
    cmd+=("" "" "" "← 돌아가기" "b" "run-shell '$CURRENT_DIR/pane-menu.sh show-tab $target \"$client_target\"'")
  else
    cmd+=("" "" "" "← 돌아가기" "b" "run-shell '$CURRENT_DIR/pane-menu.sh show \"$client_target\"'")
  fi
  "${cmd[@]}"
}

show_tab_picker() {
  local mode="$1"
  local pane_id="$2"
  local client_target
  client_target="$(resolve_client_target "${3:-}" "${4:-}")"
  local current_pane_id
  current_pane_id="$(tmux display-message -p '#{pane_id}')"

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local cmd=(
    tmux
    display-menu
    -T "$(tab_picker_title "$mode")"
  )
  add_menu_position cmd
  if [ -n "$client_target" ]; then
    cmd+=(-c "$client_target")
  fi
  cmd+=(--)

  if [ "${#tab_names[@]}" -eq 0 ]; then
    cmd+=("(탭이 없습니다)" "" "")
  else
    local idx key label
    for idx in "${!tab_names[@]}"; do
      key=""
      if [ $((idx + 1)) -le 9 ]; then
        key="$((idx + 1))"
      fi

      label="$(tab_menu_label "$((idx + 1))" "${tab_names[$idx]}" "${tab_panes[$idx]}" "$current_pane_id")"
      case "$mode" in
      attach-current)
        cmd+=("$label" "$key" "run-shell '$CURRENT_DIR/pane-menu.sh attach-pane $((idx + 1)) $pane_id \"$client_target\" pane'")
        ;;
      attach-existing-tab)
        cmd+=("$label" "$key" "run-shell '$CURRENT_DIR/pane-menu.sh show-pane-picker attach $((idx + 1)) \"$client_target\"'")
        ;;
      reorder)
        cmd+=("$label" "$key" "run-shell '$CURRENT_DIR/pane-menu.sh show-reorder $((idx + 1)) \"$client_target\"'")
        ;;
      rename)
        cmd+=("$label" "$key" "command-prompt -I \"${tab_names[$idx]}\" -p 'Rename tab' \"run-shell '$CURRENT_DIR/pane-menu.sh rename $((idx + 1)) \\\"%%\\\" \\\"$client_target\\\" manage'\"")
        ;;
      delete)
        cmd+=("$label" "$key" "run-shell '$CURRENT_DIR/pane-menu.sh show-delete-confirm $((idx + 1)) \"$client_target\" manage'")
        ;;
      *)
        cmd+=("$label" "$key" "run-shell '$CURRENT_DIR/pane-menu.sh attach-pane $((idx + 1)) $pane_id \"$client_target\" tab'")
        ;;
      esac
    done
  fi

  case "$mode" in
  attach-current)
    cmd+=("" "" "" "← 돌아가기" "b" "run-shell '$CURRENT_DIR/pane-menu.sh show-pane-actions \"$client_target\"'")
    ;;
  attach-existing-tab | reorder | rename | delete)
    cmd+=("" "" "" "← 돌아가기" "b" "run-shell '$CURRENT_DIR/pane-menu.sh show-manage-menu \"$client_target\"'")
    ;;
  *)
    cmd+=("" "" "" "← 돌아가기" "b" "run-shell '$CURRENT_DIR/pane-menu.sh show \"$client_target\"'")
    ;;
  esac
  "${cmd[@]}"
}

create_tab() {
  local tab_name="$1"
  local pane_id="$2"
  local client_target="${3:-}"
  local return_mode="${4:-main}"
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

  resume_menu "$return_mode" "$client_target"
}

attach_pane_to_tab() {
  local tab_number="$1"
  local pane_id="$2"
  local client_target="${3:-}"
  local return_mode="${4:-tab}"

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

  resume_menu "$return_mode" "$client_target" "$tab_number"
}

rename_tab() {
  local tab_number="$1"
  local new_name="$2"
  local client_target="${3:-}"
  local return_mode="${4:-tab}"
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

  resume_menu "$return_mode" "$client_target" "$tab_number"
}

detach_tab() {
  local tab_number="$1"
  local client_target="${2:-}"
  local return_mode="${3:-tab}"

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes
  local tab_index=$((tab_number - 1))
  [ "$tab_index" -lt "${#tab_names[@]}" ] || { tmux display-message "tab ${tab_number} does not exist"; exit 0; }

  tab_panes[$tab_index]=""
  save_tabs tab_names tab_panes
  persist_tabs_file
  refresh_view

  resume_menu "$return_mode" "$client_target" "$tab_number"
}

detach_current_pane() {
  local pane_id="$1"
  local client_target="${2:-}"
  local return_mode="${3:-main}"
  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes
  remove_pane_from_tabs "$pane_id" tab_panes
  save_tabs tab_names tab_panes
  persist_tabs_file
  refresh_view

  resume_menu "$return_mode" "$client_target"
}

delete_tab() {
  local tab_number="$1"
  local client_target="${2:-}"
  local return_mode="${3:-main}"

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

  resume_menu "$return_mode" "$client_target"
}

prune_dead_tabs() {
  local client_target="${1:-}"
  local return_mode="${2:-main}"
  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local next_names=()
  local next_panes=()
  local idx pane_id
  for idx in "${!tab_names[@]}"; do
    pane_id="${tab_panes[$idx]}"
    if [ -z "$pane_id" ] || ([ -n "$pane_id" ] && ! tab_has_live_pane "$pane_id"); then
      continue
    fi
    next_names+=("${tab_names[$idx]}")
    next_panes+=("$pane_id")
  done

  save_tabs next_names next_panes
  persist_tabs_file
  refresh_view

  resume_menu "$return_mode" "$client_target"
}

move_tab() {
  local tab_number="$1"
  local direction="$2"
  local client_target="${3:-}"

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local tab_index=$((tab_number - 1))
  [ "$tab_index" -lt "${#tab_names[@]}" ] || { tmux display-message "tab ${tab_number} does not exist"; exit 0; }

  local swap_index="$tab_index"
  case "$direction" in
  up)
    [ "$tab_index" -gt 0 ] || { resume_menu "reorder" "$client_target" "$tab_number"; return; }
    swap_index=$((tab_index - 1))
    ;;
  down)
    [ "$tab_index" -lt $((${#tab_names[@]} - 1)) ] || { resume_menu "reorder" "$client_target" "$tab_number"; return; }
    swap_index=$((tab_index + 1))
    ;;
  *)
    tmux display-message "invalid move direction"
    exit 0
    ;;
  esac

  local tmp_name="${tab_names[$tab_index]}"
  local tmp_pane="${tab_panes[$tab_index]}"
  tab_names[$tab_index]="${tab_names[$swap_index]}"
  tab_panes[$tab_index]="${tab_panes[$swap_index]}"
  tab_names[$swap_index]="$tmp_name"
  tab_panes[$swap_index]="$tmp_pane"

  save_tabs tab_names tab_panes
  persist_tabs_file
  refresh_view
  resume_menu "reorder" "$client_target" "$((swap_index + 1))"
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
  show_main_menu "$arg1" "$arg2"
  ;;
show-shortcuts)
  show_shortcuts_menu "$arg1" "$arg2"
  ;;
show-pane-actions)
  show_pane_actions "$arg1" "$arg2"
  ;;
show-manage-menu)
  show_manage_menu "$arg1" "$arg2"
  ;;
show-tab)
  show_tab_menu "$arg1" "$arg2" "$arg3"
  ;;
show-pane-picker)
  show_pane_picker "$arg1" "$arg2" "$arg3" "$arg4"
  ;;
show-tab-picker)
  show_tab_picker "$arg1" "$arg2" "$arg3" "$arg4"
  ;;
show-reorder)
  show_reorder_menu "$arg1" "$arg2" "$arg3"
  ;;
show-delete-confirm)
  show_delete_confirm_menu "$arg1" "$arg2" "$arg3" "$arg4"
  ;;
show-prune-confirm)
  show_prune_confirm_menu "$arg1" "$arg2"
  ;;
create-current)
  create_tab "$arg1" "$arg2" "$arg3" "$arg4"
  ;;
create-selected)
  create_tab "$arg1" "$arg2" "$arg3" "$arg4"
  ;;
attach-pane)
  attach_pane_to_tab "$arg1" "$arg2" "$arg3" "$arg4"
  ;;
rename)
  rename_tab "$arg1" "$arg2" "$arg3" "$arg4"
  ;;
detach-tab)
  detach_tab "$arg1" "$arg2" "$arg3"
  ;;
detach-pane)
  detach_current_pane "$arg1" "$arg2" "$arg3"
  ;;
delete)
  delete_tab "$arg1" "$arg2" "$arg3"
  ;;
prune)
  prune_dead_tabs "$arg1" "$arg2"
  ;;
move-tab)
  move_tab "$arg1" "$arg2" "$arg3"
  ;;
focus)
  focus_tab "$arg1" "$arg2"
  ;;
esac
