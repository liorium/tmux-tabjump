#!/usr/bin/env bash
set -euo pipefail

get_opt() {
  local option="$1"
  local default="$2"
  local value
  value="$(tmux show-option -gqv "$option" 2>/dev/null || true)"
  printf '%s\n' "${value:-$default}"
}

set_opt() {
  local option="$1"
  local value="$2"
  tmux set-option -gq "$option" "$value"
}

get_plugin_opt() {
  local suffix="$1"
  local default="$2"
  local value

  value="$(tmux show-option -gqv "@tabjump-${suffix}" 2>/dev/null || true)"
  printf '%s\n' "${value:-$default}"
}

set_plugin_opt() {
  local suffix="$1"
  local value="$2"
  set_opt "@tabjump-${suffix}" "$value"
}

normalize_language() {
  case "${1:-en}" in
    ko)
      printf 'ko\n'
      ;;
    *)
      printf 'en\n'
      ;;
  esac
}

tabjump_language() {
  normalize_language "$(get_plugin_opt "language" "en")"
}

set_tabjump_language() {
  local language
  language="$(normalize_language "${1:-en}")"
  set_plugin_opt "language" "$language"
}

t() {
  local key="$1"
  case "$(tabjump_language):$key" in
    en:menu.main.title) printf 'Tabjump\n' ;;
    ko:menu.main.title) printf 'Tabjump\n' ;;
    en:menu.main.current_pane) printf 'Current Pane Actions\n' ;;
    ko:menu.main.current_pane) printf '현재 pane 작업\n' ;;
    en:menu.main.manage) printf 'Tab Management\n' ;;
    ko:menu.main.manage) printf '탭 관리\n' ;;
    en:menu.main.settings) printf 'Settings\n' ;;
    ko:menu.main.settings) printf '설정\n' ;;
    en:menu.settings.title) printf 'Settings\n' ;;
    ko:menu.settings.title) printf '설정\n' ;;
    en:menu.settings.shortcuts) printf 'Shortcuts\n' ;;
    ko:menu.settings.shortcuts) printf '단축키 보기\n' ;;
    en:menu.settings.language) printf 'Language\n' ;;
    ko:menu.settings.language) printf '언어\n' ;;
    en:menu.language.title) printf 'Language\n' ;;
    ko:menu.language.title) printf '언어\n' ;;
    en:menu.language.english) printf 'English\n' ;;
    ko:menu.language.english) printf 'English\n' ;;
    en:menu.language.korean) printf '한국어\n' ;;
    ko:menu.language.korean) printf '한국어\n' ;;
    en:menu.shortcuts.title) printf 'Shortcuts\n' ;;
    ko:menu.shortcuts.title) printf '단축키\n' ;;
    en:menu.shortcuts.jump_tabs) printf 'Option+1..9: Jump to tab\n' ;;
    ko:menu.shortcuts.jump_tabs) printf 'Option+1..9: 해당 탭으로 이동\n' ;;
    en:menu.shortcuts.previous_tab) printf 'Option+`: Jump to previous tab\n' ;;
    ko:menu.shortcuts.previous_tab) printf 'Option+`: 이전 탭으로 이동\n' ;;
    en:menu.shortcuts.open_main) printf 'prefix + m: Open main menu\n' ;;
    ko:menu.shortcuts.open_main) printf 'prefix + m: 메인 메뉴 열기\n' ;;
    en:menu.shortcuts.enter) printf 'Enter in menu: choose selected item\n' ;;
    ko:menu.shortcuts.enter) printf '메뉴 안 Enter: 선택한 항목 실행\n' ;;
    en:menu.shortcuts.back) printf 'b in menu: go back\n' ;;
    ko:menu.shortcuts.back) printf '메뉴 안 b: 뒤로가기\n' ;;
    en:menu.pane_actions.title) printf 'Current Pane Actions\n' ;;
    ko:menu.pane_actions.title) printf '현재 pane 작업\n' ;;
    en:menu.manage.title) printf 'Tab Management\n' ;;
    ko:menu.manage.title) printf '탭 관리\n' ;;
    en:menu.manage.attach_section) printf 'Attach Another Pane\n' ;;
    ko:menu.manage.attach_section) printf '다른 pane 붙이기\n' ;;
    en:menu.manage.structure_section) printf 'Manage Tabs\n' ;;
    ko:menu.manage.structure_section) printf '탭 구조 관리\n' ;;
    en:menu.tab.title_prefix) printf 'Tab\n' ;;
    ko:menu.tab.title_prefix) printf '탭\n' ;;
    en:menu.delete_confirm.title_prefix) printf 'Delete Confirm\n' ;;
    ko:menu.delete_confirm.title_prefix) printf '삭제 확인\n' ;;
    en:menu.prune_confirm.title) printf 'Prune Confirm\n' ;;
    ko:menu.prune_confirm.title) printf '정리 확인\n' ;;
    en:menu.reorder.title_prefix) printf 'Reorder\n' ;;
    ko:menu.reorder.title_prefix) printf '순서 변경\n' ;;
    en:menu.pane_picker.attach_title) printf '%s\n' 'Select Pane for Tab %s' ;;
    ko:menu.pane_picker.attach_title) printf '%s\n' 'Tab %s에 붙일 pane 선택' ;;
    en:menu.pane_picker.create_title) printf '%s\n' 'Select Pane for New Tab %s' ;;
    ko:menu.pane_picker.create_title) printf '%s\n' '새 탭 %s에 붙일 pane 선택' ;;
    en:menu.tab_picker.attach_current) printf 'Attach to Existing Tab\n' ;;
    ko:menu.tab_picker.attach_current) printf '기존 탭에 붙이기\n' ;;
    en:menu.tab_picker.attach_existing_tab) printf 'Select Tab to Attach Another Pane\n' ;;
    ko:menu.tab_picker.attach_existing_tab) printf '붙일 탭 선택\n' ;;
    en:menu.tab_picker.reorder) printf 'Select Tab to Reorder\n' ;;
    ko:menu.tab_picker.reorder) printf '순서 바꿀 탭 선택\n' ;;
    en:menu.tab_picker.rename) printf 'Select Tab to Rename\n' ;;
    ko:menu.tab_picker.rename) printf '이름 바꿀 탭 선택\n' ;;
    en:menu.tab_picker.delete) printf 'Select Tab to Delete\n' ;;
    ko:menu.tab_picker.delete) printf '삭제할 탭 선택\n' ;;
    en:menu.tab_picker.default) printf 'Select Tab\n' ;;
    ko:menu.tab_picker.default) printf '탭 선택\n' ;;
    en:label.current_status) printf 'Current Status\n' ;;
    ko:label.current_status) printf '현재 상태\n' ;;
    en:label.no_tab) printf 'No Tab\n' ;;
    ko:label.no_tab) printf '탭 없음\n' ;;
    en:label.status_prefix) printf 'Status\n' ;;
    ko:label.status_prefix) printf '상태\n' ;;
    en:label.tab_assignment) printf '%s\n' 'Tab %s %s' ;;
    ko:label.tab_assignment) printf '%s\n' '탭 %s %s' ;;
    en:label.unassigned) printf 'Unassigned\n' ;;
    ko:label.unassigned) printf '미지정\n' ;;
    en:label.current_marker) printf 'current\n' ;;
    ko:label.current_marker) printf '현재\n' ;;
    en:status.current) printf 'Current Pane\n' ;;
    ko:status.current) printf '현재 pane\n' ;;
    en:status.empty) printf 'Empty\n' ;;
    ko:status.empty) printf '비어 있음\n' ;;
    en:status.dead) printf 'Dead\n' ;;
    ko:status.dead) printf '연결 끊김\n' ;;
    en:status.connected) printf 'Connected\n' ;;
    ko:status.connected) printf '연결됨\n' ;;
    en:status.menu_badge) printf 'menu\n' ;;
    ko:status.menu_badge) printf '메뉴\n' ;;
    en:status.no_tabs) printf 'no tabs\n' ;;
    ko:status.no_tabs) printf '탭 없음\n' ;;
    en:status.empty_short) printf 'empty\n' ;;
    ko:status.empty_short) printf '비어 있음\n' ;;
    en:status.dead_short) printf 'dead\n' ;;
    ko:status.dead_short) printf '끊김\n' ;;
    en:action.attach_existing_tab) printf '⇄ Attach to Existing Tab\n' ;;
    ko:action.attach_existing_tab) printf '⇄ 기존 탭에 붙이기\n' ;;
    en:action.create_new_tab) printf '＋ Create New Tab\n' ;;
    ko:action.create_new_tab) printf '＋ 새 탭에 붙이기\n' ;;
    en:action.detach_current_pane) printf '⊘ Detach Current Pane\n' ;;
    ko:action.detach_current_pane) printf '⊘ 현재 탭에서 해제\n' ;;
    en:action.attach_other_pane_existing) printf '⇄ Attach Another Pane to Existing Tab\n' ;;
    ko:action.attach_other_pane_existing) printf '⇄ 다른 pane을 기존 탭에 붙이기\n' ;;
    en:action.attach_other_pane_new_tab) printf '＋ Create New Tab from Another Pane\n' ;;
    ko:action.attach_other_pane_new_tab) printf '＋ 다른 pane으로 새 탭 만들기\n' ;;
    en:action.reorder) printf '⇅ Reorder Tabs\n' ;;
    ko:action.reorder) printf '⇅ 순서 변경\n' ;;
    en:action.rename) printf '✎ Rename Tab\n' ;;
    ko:action.rename) printf '✎ 이름 변경\n' ;;
    en:action.delete_tab) printf '✕ Delete Tab\n' ;;
    ko:action.delete_tab) printf '✕ 삭제\n' ;;
    en:action.prune_tabs) printf '↺ Prune Dead/Empty Tabs\n' ;;
    ko:action.prune_tabs) printf '↺ 비어 있거나 끊긴 탭 정리\n' ;;
    en:action.focus_tab) printf '→ Focus\n' ;;
    ko:action.focus_tab) printf '→ 이동\n' ;;
    en:action.attach_current_pane) printf '⇄ Attach Current Pane\n' ;;
    ko:action.attach_current_pane) printf '⇄ 현재 pane 붙이기\n' ;;
    en:action.select_other_pane) printf '⇄ Select Another Pane\n' ;;
    ko:action.select_other_pane) printf '⇄ 다른 pane 선택\n' ;;
    en:action.detach_pane) printf '⊘ Detach Pane\n' ;;
    ko:action.detach_pane) printf '⊘ pane 해제\n' ;;
    en:action.move_up) printf '↑ Move Up\n' ;;
    ko:action.move_up) printf '↑ 위로 이동\n' ;;
    en:action.move_down) printf '↓ Move Down\n' ;;
    ko:action.move_down) printf '↓ 아래로 이동\n' ;;
    en:action.confirm_delete) printf '✕ Delete\n' ;;
    ko:action.confirm_delete) printf '✕ 삭제\n' ;;
    en:action.confirm_prune) printf '↺ Prune\n' ;;
    ko:action.confirm_prune) printf '↺ 정리\n' ;;
    en:disabled.no_tabs) printf -- '-(No tabs)\n' ;;
    ko:disabled.no_tabs) printf -- '-(탭이 없습니다)\n' ;;
    en:disabled.no_panes) printf '(No panes)\n' ;;
    ko:disabled.no_panes) printf '(pane이 없습니다)\n' ;;
    en:disabled.already_first) printf -- '-(Already the first tab)\n' ;;
    ko:disabled.already_first) printf -- '-(이미 첫 번째 탭입니다)\n' ;;
    en:disabled.already_last) printf -- '-(Already the last tab)\n' ;;
    ko:disabled.already_last) printf -- '-(이미 마지막 탭입니다)\n' ;;
    en:nav.back_main) printf '← Back to Main Menu\n' ;;
    ko:nav.back_main) printf '← 메인 메뉴\n' ;;
    en:nav.back_settings) printf '← Back to Settings\n' ;;
    ko:nav.back_settings) printf '← 설정으로 돌아가기\n' ;;
    en:nav.back_manage) printf '← Back to Tab Management\n' ;;
    ko:nav.back_manage) printf '← 탭 관리\n' ;;
    en:nav.back_tab) printf '← Back to Tab\n' ;;
    ko:nav.back_tab) printf '← 돌아가기\n' ;;
    en:nav.back_generic) printf '← Back\n' ;;
    ko:nav.back_generic) printf '← 돌아가기\n' ;;
    en:prompt.tab_name) printf 'Tab name\n' ;;
    ko:prompt.tab_name) printf '탭 이름\n' ;;
    en:prompt.rename_tab) printf 'Rename tab\n' ;;
    ko:prompt.rename_tab) printf '탭 이름 변경\n' ;;
    en:confirm.delete_question) printf 'Delete this tab?\n' ;;
    ko:confirm.delete_question) printf '정말 삭제할까요?\n' ;;
    en:confirm.prune_question) printf 'Prune dead/empty tabs?\n' ;;
    ko:confirm.prune_question) printf '비어 있거나 끊긴 탭을 정리할까요?\n' ;;
    en:error.tab_index_positive) printf 'tab index must be a positive number\n' ;;
    ko:error.tab_index_positive) printf '탭 번호는 1 이상의 숫자여야 합니다\n' ;;
    en:error.tab_unavailable) printf '%s\n' 'tab %s is not available' ;;
    ko:error.tab_unavailable) printf '%s\n' '탭 %s 를 사용할 수 없습니다' ;;
    en:error.tab_is_empty) printf '%s\n' 'tab %s is empty' ;;
    ko:error.tab_is_empty) printf '%s\n' '탭 %s 가 비어 있습니다' ;;
    en:error.tab_points_dead) printf '%s\n' 'tab %s points to a dead pane' ;;
    ko:error.tab_points_dead) printf '%s\n' '탭 %s 가 끊어진 pane을 가리킵니다' ;;
    en:error.no_previous_tab) printf 'no previous tab\n' ;;
    ko:error.no_previous_tab) printf '이전 탭이 없습니다\n' ;;
    en:error.already_previous_tab) printf 'already on the previous tab\n' ;;
    ko:error.already_previous_tab) printf '이미 이전 탭에 있습니다\n' ;;
    en:confirm.prune_detail) printf 'Empty tabs and tabs with missing panes will be removed.\n' ;;
    ko:confirm.prune_detail) printf '비어 있거나 연결이 끊긴 탭이 삭제됩니다.\n' ;;
    en:error.invalid_tab_number) printf 'invalid tab number\n' ;;
    ko:error.invalid_tab_number) printf '잘못된 탭 번호입니다\n' ;;
    en:error.tab_not_exists) printf '%s\n' 'tab %s does not exist' ;;
    ko:error.tab_not_exists) printf '%s\n' '탭 %s 가 없습니다' ;;
    en:error.tab_name_required) printf 'tab name is required\n' ;;
    ko:error.tab_name_required) printf '탭 이름이 필요합니다\n' ;;
    en:error.invalid_move_direction) printf 'invalid move direction\n' ;;
    ko:error.invalid_move_direction) printf '잘못된 이동 방향입니다\n' ;;
    *)
      printf '%s\n' "$key"
      ;;
  esac
}

tf() {
  local key="$1"
  shift || true
  local format
  format="$(t "$key")"
  printf "$format" "$@"
}

tabs_file() {
  local custom
  custom="$(tmux show-option -gqv "@tabjump-tabs-file" 2>/dev/null || true)"
  if [ -n "$custom" ]; then
    printf '%s\n' "$custom"
    return
  fi

  printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/tmux-tabjump/tabs.tsv"
}

ensure_tabs_dir() {
  mkdir -p "$(dirname "$(tabs_file)")"
}

join_by() {
  local separator="$1"
  shift || true

  if [ "$#" -eq 0 ]; then
    return
  fi

  printf '%s' "$1"
  shift

  local value
  for value in "$@"; do
    printf '%s%s' "$separator" "$value"
  done
}

tab_state_raw() {
  local value
  value="$(tmux show-option -gqv "@tabjump-tabs" 2>/dev/null || true)"
  printf '%s\n' "$value"
}

normalize_tab_name() {
  local name="$1"
  name="${name//$'\n'/ }"
  name="${name//$'\t'/ }"
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"
  printf '%s\n' "$name"
}

load_tabs() {
  local -n names_ref="$1"
  local -n panes_ref="$2"
  names_ref=()
  panes_ref=()

  local raw
  raw="$(tab_state_raw)"
  if [ -z "$raw" ]; then
    return 0
  fi

  local record encoded_name pane_id decoded_name
  IFS='|' read -r -a records <<<"$raw"
  for record in "${records[@]}"; do
    [ -n "$record" ] || continue
    IFS=',' read -r encoded_name pane_id <<<"$record"
    [ -n "$encoded_name" ] || continue
    decoded_name="$(printf '%s' "$encoded_name" | base64 -d 2>/dev/null || true)"
    decoded_name="$(normalize_tab_name "$decoded_name")"
    [ -n "$decoded_name" ] || decoded_name="tab"
    names_ref+=("$decoded_name")
    panes_ref+=("${pane_id:-}")
  done
}

save_tabs() {
  local -n names_ref="$1"
  local -n panes_ref="$2"

  local records=()
  local idx name encoded_name pane_id
  for idx in "${!names_ref[@]}"; do
    name="$(normalize_tab_name "${names_ref[$idx]}")"
    [ -n "$name" ] || continue
    pane_id="${panes_ref[$idx]:-}"
    encoded_name="$(printf '%s' "$name" | base64 | tr -d '\n')"
    records+=("${encoded_name},${pane_id}")
  done

  set_plugin_opt "tabs" "$(join_by '|' "${records[@]}")"
}

tab_index_for_pane() {
  local target_pane_id="$1"
  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local idx
  for idx in "${!tab_panes[@]}"; do
    if [ "${tab_panes[$idx]}" = "$target_pane_id" ]; then
      printf '%s\n' "$idx"
      return 0
    fi
  done

  return 1
}

tab_has_live_pane() {
  local pane_id="$1"
  [ -n "$pane_id" ] || return 1
  tmux list-panes -a -F '#{pane_id}' | grep -Fxq "$pane_id"
}

remove_pane_from_tabs() {
  local target_pane_id="$1"
  local -n panes_ref="$2"

  local idx
  for idx in "${!panes_ref[@]}"; do
    if [ "${panes_ref[$idx]}" = "$target_pane_id" ]; then
      panes_ref[$idx]=""
    fi
  done
}

load_pane_rows() {
  local -n output_ref="$1"
  output_ref=()

  while IFS= read -r row; do
    [ -n "$row" ] && output_ref+=("$row")
  done < <(
    tmux list-panes -a -F '#{session_name}	#{window_index}	#{window_name}	#{pane_index}	#{pane_id}	#{pane_current_path}' 2>/dev/null
  )
}

find_pane_row_by_id() {
  local target_pane_id="$1"
  local pane_rows=()
  load_pane_rows pane_rows

  local row pane_id
  for row in "${pane_rows[@]}"; do
    IFS=$'\t' read -r _ _ _ _ pane_id _ <<<"$row"
    if [ "$pane_id" = "$target_pane_id" ]; then
      printf '%s\n' "$row"
      return 0
    fi
  done

  return 1
}

resolve_saved_tab_pane() {
  local session_name="$1"
  local window_index="$2"
  local window_name="$3"
  local pane_index="$4"

  local pane_rows=()
  load_pane_rows pane_rows

  local row row_session row_window_index row_window_name row_pane_index pane_id pane_path
  for row in "${pane_rows[@]}"; do
    IFS=$'\t' read -r row_session row_window_index row_window_name row_pane_index pane_id pane_path <<<"$row"
    if [ "$row_session" = "$session_name" ] && [ "$row_window_index" = "$window_index" ] && [ "$row_pane_index" = "$pane_index" ]; then
      printf '%s\n' "$pane_id"
      return 0
    fi
  done

  for row in "${pane_rows[@]}"; do
    IFS=$'\t' read -r row_session row_window_index row_window_name row_pane_index pane_id pane_path <<<"$row"
    if [ "$row_session" = "$session_name" ] && [ "$row_window_name" = "$window_name" ] && [ "$row_pane_index" = "$pane_index" ]; then
      printf '%s\n' "$pane_id"
      return 0
    fi
  done

  return 1
}

persist_tabs_file() {
  ensure_tabs_dir

  local tab_names=()
  local tab_panes=()
  load_tabs tab_names tab_panes

  local file
  file="$(tabs_file)"
  local tmp_file
  tmp_file="$(mktemp "${file}.tmp.XXXXXX")"

  local idx tab_name pane_id encoded_tab_name pane_row
  local session_name window_index window_name pane_index encoded_window_name pane_path

  {
    for idx in "${!tab_names[@]}"; do
      tab_name="$(normalize_tab_name "${tab_names[$idx]}")"
      [ -n "$tab_name" ] || continue

      pane_id="${tab_panes[$idx]:-}"
      session_name=""
      window_index=""
      window_name=""
      pane_index=""
      encoded_window_name=""

      if [ -n "$pane_id" ] && pane_row="$(find_pane_row_by_id "$pane_id" 2>/dev/null)"; then
        IFS=$'\t' read -r session_name window_index window_name pane_index pane_id pane_path <<<"$pane_row"
        encoded_window_name="$(printf '%s' "$window_name" | base64 | tr -d '\n')"
      fi

      encoded_tab_name="$(printf '%s' "$tab_name" | base64 | tr -d '\n')"
      printf '%s\t%s\t%s\t%s\t%s\n' "$encoded_tab_name" "$session_name" "$window_index" "$encoded_window_name" "$pane_index"
    done
  } >"$tmp_file"

  mv "$tmp_file" "$file"
}

restore_tabs_from_file_if_needed() {
  if [ -n "$(tab_state_raw)" ]; then
    return 0
  fi

  local file
  file="$(tabs_file)"
  [ -f "$file" ] || return 0

  local tab_names=()
  local tab_panes=()
  local encoded_tab_name session_name window_index encoded_window_name pane_index
  local tab_name window_name pane_id

  while IFS=$'\t' read -r encoded_tab_name session_name window_index encoded_window_name pane_index; do
    [ -n "$encoded_tab_name" ] || continue
    tab_name="$(printf '%s' "$encoded_tab_name" | base64 -d 2>/dev/null || true)"
    tab_name="$(normalize_tab_name "$tab_name")"
    [ -n "$tab_name" ] || continue

    pane_id=""
    if [ -n "$session_name" ] && [ -n "$window_index" ] && [ -n "$pane_index" ]; then
      window_name="$(printf '%s' "$encoded_window_name" | base64 -d 2>/dev/null || true)"
      pane_id="$(resolve_saved_tab_pane "$session_name" "$window_index" "$window_name" "$pane_index" 2>/dev/null || true)"
    fi

    tab_names+=("$tab_name")
    tab_panes+=("$pane_id")
  done <"$file"

  save_tabs tab_names tab_panes
}

compact_path() {
  local path="$1"
  local short="$path"

  if [ -n "${HOME:-}" ] && [[ "$short" == "$HOME"* ]]; then
    short="~${short#$HOME}"
  fi

  if [ "$short" = "~" ] || [ "$short" = "~/" ]; then
    printf '~\n'
    return
  fi

  IFS='/' read -r -a parts <<<"${short#/}"

  if [[ "$short" == "~"* ]]; then
    IFS='/' read -r -a parts <<<"${short#~/}"
    if [ "${#parts[@]}" -le 2 ]; then
      printf '%s\n' "$short"
      return
    fi

    printf '~/…/%s/%s\n' "${parts[${#parts[@]}-2]}" "${parts[${#parts[@]}-1]}"
    return
  fi

  if [ "${#parts[@]}" -le 2 ]; then
    printf '%s\n' "$short"
    return
  fi

  printf '…/%s/%s\n' "${parts[${#parts[@]}-2]}" "${parts[${#parts[@]}-1]}"
}

pane_descriptor_from_row() {
  local row="$1"
  local session_name window_index window_name pane_index pane_id pane_path
  IFS=$'\t' read -r session_name window_index window_name pane_index pane_id pane_path <<<"$row"

  local short_path
  short_path="$(compact_path "$pane_path")"
  printf '%s:%s.%s · %s\n' "$session_name" "$window_name" "$pane_index" "$short_path"
}

pane_descriptor_from_id() {
  local pane_id="$1"
  local row
  if row="$(find_pane_row_by_id "$pane_id" 2>/dev/null)"; then
    pane_descriptor_from_row "$row"
  fi
}

focus_pane_by_id() {
  local pane_id="$1"

  if ! tmux list-panes -a -F '#{pane_id}' | grep -Fxq "$pane_id"; then
    return 1
  fi

  local session_name window_target
  session_name="$(tmux display-message -p -t "$pane_id" '#{session_name}')"
  window_target="$(tmux display-message -p -t "$pane_id" '#{session_name}:#{window_index}')"

  tmux switch-client -t "$session_name" >/dev/null 2>&1 || true
  tmux select-window -t "$window_target" >/dev/null 2>&1 || true
  tmux select-pane -t "$pane_id" >/dev/null 2>&1 || true
}

active_tab_number() {
  local current_pane_id
  current_pane_id="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
  [ -n "$current_pane_id" ] || return 1

  local tab_index
  tab_index="$(tab_index_for_pane "$current_pane_id" 2>/dev/null)" || return 1
  printf '%s\n' "$((tab_index + 1))"
}

sync_active_tab_history() {
  local current_tab saved_current
  current_tab="$(active_tab_number 2>/dev/null || true)"
  [ -n "$current_tab" ] || return 0

  saved_current="$(tmux show-option -gqv "@tabjump-current-tab" 2>/dev/null || true)"
  if [ "$saved_current" = "$current_tab" ]; then
    return 0
  fi

  if [ -n "$saved_current" ]; then
    set_plugin_opt "last-tab" "$saved_current"
  fi
  set_plugin_opt "current-tab" "$current_tab"
}

truncate_label() {
  local text="$1"
  local max_len="$2"
  local ellipsis="…"
  local ellipsis_width=1
  local text_width char_width budget used result char idx
  local width_probe_opt="@tabjump-internal-width-probe"

  if ! [[ "$max_len" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$text"
    return
  fi

  if [ "$max_len" -le 0 ]; then
    printf '\n'
    return
  fi

  display_width() {
    local value="$1"
    local width previous_width

    previous_width="$(tmux show-option -gqv "$width_probe_opt" 2>/dev/null || true)"
    tmux set-option -gq "$width_probe_opt" "$value" >/dev/null 2>&1 || true
    width="$(tmux display-message -p "#{w:${width_probe_opt}}" 2>/dev/null || true)"
    tmux set-option -gq "$width_probe_opt" "$previous_width" >/dev/null 2>&1 || true

    if [[ "$width" =~ ^[0-9]+$ ]]; then
      printf '%s\n' "$width"
      return
    fi

    printf '%s\n' "${#value}"
  }

  text_width="$(display_width "$text")"

  if [ "$text_width" -le "$max_len" ]; then
    printf '%s\n' "$text"
    return
  fi

  if [ "$max_len" -le "$ellipsis_width" ]; then
    printf '%s\n' "$ellipsis"
    return
  fi

  budget=$((max_len - ellipsis_width))
  used=0
  result=""

  for ((idx = 0; idx < ${#text}; idx++)); do
    char="${text:idx:1}"
    char_width="$(display_width "$char")"

    if [ $((used + char_width)) -gt "$budget" ]; then
      break
    fi

    result+="$char"
    used=$((used + char_width))
  done

  printf '%s%s\n' "$result" "$ellipsis"
}
