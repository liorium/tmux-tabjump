#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
STATE_FILE="$TMP_DIR/tmux-state"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

export TMUX_STATE_FILE="$STATE_FILE"

cat >"$TMP_DIR/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

state_file="${TMUX_STATE_FILE:?}"
touch "$state_file"

read_value() {
  local option="$1"
  local line key raw value=""
  if [ -f "$state_file" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      key="${line%%=*}"
      raw="${line#*=}"
      if [ "$key" = "$option" ]; then
        value="$raw"
      fi
    done <"$state_file"
  fi
  printf '%s\n' "$value"
}

write_value() {
  local option="$1"
  local value="$2"
  local tmp_file="${state_file}.tmp"
  local line key
  : >"$tmp_file"

  if [ -f "$state_file" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      key="${line%%=*}"
      if [ "$key" = "$option" ]; then
        continue
      fi
      printf '%s\n' "$line" >>"$tmp_file"
    done <"$state_file"
  fi

  printf '%s=%s\n' "$option" "$value" >>"$tmp_file"
  mv "$tmp_file" "$state_file"
}

cmd="${1:-}"
shift || true

case "$cmd" in
show-option)
  option="${*: -1}"
  read_value "$option"
  ;;
set-option)
  option="${*: -2:1}"
  value="${*: -1}"
  write_value "$option" "$value"
  ;;
display-message)
  format="${*: -1}"
  case "$format" in
  '#{w:@tabjump-internal-width-probe}')
    read_value "@tabjump-internal-width-probe" | wc -L | tr -d '[:space:]'
    ;;
  *)
    echo "unsupported display-message format: $format" >&2
    exit 1
    ;;
  esac
  ;;
*)
  echo "unsupported tmux command: $cmd" >&2
  exit 1
  ;;
esac
EOF
chmod +x "$TMP_DIR/tmux"

PATH="$TMP_DIR:$PATH"
export PATH

# shellcheck source=../scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [ "$expected" != "$actual" ]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_tab_array() {
  local -n expected_names_ref="$1"
  local -n expected_panes_ref="$2"
  local -n actual_names_ref="$3"
  local -n actual_panes_ref="$4"
  local message="$5"

  assert_eq "${#expected_names_ref[@]}" "${#actual_names_ref[@]}" "${message} (name count)"
  assert_eq "${#expected_panes_ref[@]}" "${#actual_panes_ref[@]}" "${message} (pane count)"

  local idx
  for idx in "${!expected_names_ref[@]}"; do
    assert_eq "${expected_names_ref[$idx]}" "${actual_names_ref[$idx]}" "${message} (name $idx)"
    assert_eq "${expected_panes_ref[$idx]}" "${actual_panes_ref[$idx]}" "${message} (pane $idx)"
  done
}

assert_eq "fallback" "$(get_plugin_opt "status-line" "fallback")" "unset plugin option should use default"
assert_eq "en" "$(tabjump_language)" "language should default to english"

set_plugin_opt "status-line" "3"
assert_eq "3" "$(get_plugin_opt "status-line" "fallback")" "tabjump option should override default"
set_plugin_opt "language" "ko"
assert_eq "ko" "$(tabjump_language)" "language should read persisted korean setting"
set_plugin_opt "language" "fr"
assert_eq "en" "$(tabjump_language)" "language should fall back to english for unsupported values"
assert_eq "Settings" "$(t menu.main.settings)" "english translations should come from translation keys"
set_plugin_opt "language" "ko"
assert_eq "설정" "$(t menu.main.settings)" "korean translations should come from translation keys"
set_tabjump_language en
assert_eq "en" "$(get_plugin_opt "language" "ko")" "set_tabjump_language should persist english"

expected_default="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-tabjump/tabs.tsv"
assert_eq "$expected_default" "$(tabs_file)" "tabs_file should use tabjump default path"

set_plugin_opt "tabs-file" "/tmp/custom-tabs.tsv"
assert_eq "/tmp/custom-tabs.tsv" "$(tabs_file)" "tabs_file should use custom tabjump path"

tab_names=("alpha" "beta tab")
tab_panes=("%1" "")
save_tabs tab_names tab_panes

raw_state="$(tab_state_raw)"
expected_raw="YWxwaGE=,%1|YmV0YSB0YWI=,"
assert_eq "$expected_raw" "$raw_state" "save_tabs should encode tab names into @tabjump-tabs"

loaded_names=()
loaded_panes=()
load_tabs loaded_names loaded_panes

expected_names=("alpha" "beta tab")
expected_panes=("%1" "")
assert_tab_array expected_names expected_panes loaded_names loaded_panes "load_tabs should decode saved tab state"

set_plugin_opt "tabs" ""
set_plugin_opt "tabs-file" "$TMP_DIR/tabs.tsv"
cat >"$TMP_DIR/tabs.tsv" <<'EOF'
cmVzdG9yZWQ=	dev	1	ZWRpdG9y	0
EOF

restore_tabs_from_file_if_needed

restored_names=()
restored_panes=()
load_tabs restored_names restored_panes

expected_restored_names=("restored")
expected_restored_panes=("")
assert_tab_array expected_restored_names expected_restored_panes restored_names restored_panes "restore_tabs_from_file_if_needed should preserve saved tabs and normalize missing panes to empty"

assert_eq "한글A" "$(truncate_label "한글A" 5)" "truncate_label should keep labels that exactly fit the display width"
assert_eq "한…" "$(truncate_label "한글A" 4)" "truncate_label should use terminal display width for wide unicode labels"
assert_eq "a#}…" "$(truncate_label "a#}bc" 4)" "truncate_label should escape tmux format delimiters safely"
assert_eq "a,b…" "$(truncate_label "a,bcd" 4)" "truncate_label should escape tmux commas safely"

mkdir -p "$TMP_DIR/no-python-bin"
ln -sf "$(command -v env)" "$TMP_DIR/no-python-bin/env"
ln -sf "$(command -v bash)" "$TMP_DIR/no-python-bin/bash"
ln -sf "$(command -v touch)" "$TMP_DIR/no-python-bin/touch"
ln -sf "$(command -v wc)" "$TMP_DIR/no-python-bin/wc"
ln -sf "$(command -v tr)" "$TMP_DIR/no-python-bin/tr"
ln -sf "$(command -v mv)" "$TMP_DIR/no-python-bin/mv"
ln -sf "$(command -v rm)" "$TMP_DIR/no-python-bin/rm"
saved_path="$PATH"
PATH="$TMP_DIR:$TMP_DIR/no-python-bin"
assert_eq "한…" "$(truncate_label "한글A" 4)" "truncate_label should keep wide-character behavior even without python3"
PATH="$saved_path"

printf 'PASS: tests/common_test.sh\n'
