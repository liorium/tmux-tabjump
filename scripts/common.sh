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

  if [ "${#text}" -le "$max_len" ]; then
    printf '%s\n' "$text"
    return
  fi

  if [ "$max_len" -le 1 ]; then
    printf '…\n'
    return
  fi

  printf '%s…\n' "${text:0:$((max_len - 1))}"
}
