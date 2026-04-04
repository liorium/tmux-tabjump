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
  python3 - "$state_file" "$option" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
option = sys.argv[2]
value = ""
if path.exists():
    for line in path.read_text().splitlines():
        if not line:
            continue
        key, _, raw = line.partition("=")
        if key == option:
            value = raw
print(value)
PY
}

write_value() {
  local option="$1"
  local value="$2"
  python3 - "$state_file" "$option" "$value" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
option = sys.argv[2]
value = sys.argv[3]
entries = {}
if path.exists():
    for line in path.read_text().splitlines():
        if not line:
            continue
        key, _, raw = line.partition("=")
        entries[key] = raw
entries[option] = value
path.write_text("".join(f"{key}={entries[key]}\n" for key in sorted(entries)))
PY
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

set_plugin_opt "status-line" "3"
assert_eq "3" "$(get_plugin_opt "status-line" "fallback")" "tabjump option should override default"

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

printf 'PASS: tests/common_test.sh\n'
