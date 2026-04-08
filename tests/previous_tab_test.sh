#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
STATE_FILE="$TMP_DIR/tmux-state"
LOG_FILE="$TMP_DIR/tmux.log"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

export TMUX_STATE_FILE="$STATE_FILE"
export TMUX_LOG_FILE="$LOG_FILE"

cat >"$TMP_DIR/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

state_file="${TMUX_STATE_FILE:?}"
log_file="${TMUX_LOG_FILE:?}"
touch "$state_file" "$log_file"

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
display-message)
  target=""
  args=("$@")
  idx=0
  while [ "$idx" -lt "${#args[@]}" ]; do
    if [ "${args[$idx]}" = "-t" ]; then
      idx=$((idx + 1))
      target="${args[$idx]}"
    fi
    idx=$((idx + 1))
  done
  format="${args[${#args[@]}-1]}"
  case "$format" in
  '#{pane_id}')
    read_value current_pane
    ;;
  '#{session_name}')
    printf 'dev\n'
    ;;
  '#{session_name}:#{window_index}')
    case "$target" in
    %1) printf 'dev:1\n' ;;
    %2) printf 'dev:2\n' ;;
    *) printf 'dev:1\n' ;;
    esac
    ;;
  '#{w:@tabjump-internal-width-probe}')
    read_value "@tabjump-internal-width-probe" | wc -L | tr -d '[:space:]'
    ;;
  *)
    printf '%s %s\n' "$cmd" "$*" >>"$log_file"
    ;;
  esac
  ;;
list-panes)
  format="${*: -1}"
  case "$format" in
  '#{pane_id}')
    printf '%%1\n%%2\n'
    ;;
  *)
    echo "unsupported list-panes format: $format" >&2
    exit 1
    ;;
  esac
  ;;
switch-client|select-window)
  printf '%s %s\n' "$cmd" "$*" >>"$log_file"
  ;;
select-pane)
  printf '%s %s\n' "$cmd" "$*" >>"$log_file"
  target="${*: -1}"
  write_value current_pane "$target"
  ;;
refresh-client|display-message*)
  printf '%s %s\n' "$cmd" "$*" >>"$log_file"
  ;;
*)
  echo "unsupported tmux command: $cmd $*" >&2
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

assert_contains() {
  local needle="$1"
  local message="$2"

  if ! grep -Fq -- "$needle" "$LOG_FILE"; then
    printf 'FAIL: %s\nmissing: %s\nlog:\n' "$message" "$needle" >&2
    cat "$LOG_FILE" >&2 || true
    exit 1
  fi
}

set_opt current_pane "%1"
tab_names=("alpha" "beta")
tab_panes=("%1" "%2")
save_tabs tab_names tab_panes

sync_active_tab_history
assert_eq "1" "$(tmux show-option -gqv @tabjump-current-tab)" "sync should set the current tab"
assert_eq "" "$(tmux show-option -gqv @tabjump-last-tab)" "first sync should not invent a previous tab"

set_opt current_pane "%2"
sync_active_tab_history
assert_eq "2" "$(tmux show-option -gqv @tabjump-current-tab)" "sync should update the current tab after focus changes"
assert_eq "1" "$(tmux show-option -gqv @tabjump-last-tab)" "sync should remember the previous tab"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/jump-last-tab.sh"
assert_contains "select-pane -t %1" "jump-last-tab should focus the previously active tab pane"
assert_eq "%1" "$(tmux show-option -gqv current_pane)" "jump-last-tab should move focus back to the previous pane"

sync_active_tab_history
assert_eq "1" "$(tmux show-option -gqv @tabjump-current-tab)" "sync after jumping back should update current tab"
assert_eq "2" "$(tmux show-option -gqv @tabjump-last-tab)" "sync after jumping back should enable toggling"

set_plugin_opt "language" "ko"
set_opt current_pane "%1"
set_plugin_opt "last-tab" ""
: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/jump-last-tab.sh"
assert_contains "display-message 이전 탭이 없습니다" "jump-last-tab should translate the no-previous-tab message"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/jump-visible-pane.sh" 9
assert_contains "display-message 탭 9 를 사용할 수 없습니다" "jump-visible-pane should translate unavailable-tab errors"

tab_names=("alpha" "beta")
tab_panes=("" "%2")
save_tabs tab_names tab_panes
: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/jump-visible-pane.sh" 1
assert_contains "display-message 탭 alpha 가 비어 있습니다" "jump-visible-pane should translate empty-tab errors"

tab_names=("alpha" "beta")
tab_panes=("%9" "%2")
save_tabs tab_names tab_panes
: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/jump-visible-pane.sh" 1
assert_contains "display-message 탭 alpha 가 끊어진 pane을 가리킵니다" "jump-visible-pane should translate dead-pane errors"

printf 'PASS: tests/previous_tab_test.sh\n'
