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
display-message)
  printf '120\n'
  ;;
list-panes)
  printf '%%1\n'
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

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'FAIL: %s\nmissing: %s\n' "$message" "$needle" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'FAIL: %s\nunexpected: %s\n' "$message" "$needle" >&2
    exit 1
  fi
}

tab_names=("active" "scratch")
tab_panes=("%1" "")
save_tabs tab_names tab_panes

rendered="$(bash "$ROOT_DIR/scripts/statusline.sh" "%1")"

assert_contains "$rendered" "#[range=user|menu]#[fg=#6c7086,bg=#1e1e2e]#[bold,fg=#11111b,bg=#6c7086]m #[fg=#cdd6f4,bg=#313244] menu #[default]#[norange]" "menu badge should use the same accent as inactive tab numbers"
assert_not_contains "$rendered" "#[range=user|menu]#[fg=#f9e2af,bg=#1e1e2e]#[bold,fg=#11111b,bg=#f9e2af] menu #[default]#[norange]" "menu badge should no longer use the full filled menu block"
assert_contains "$rendered" "#[bold,fg=#11111b,bg=#3B82F6]1 " "active tab number should restore the default text color on the active accent"
assert_contains "$rendered" "#[bold,fg=#11111b,bg=#f9e2af]2 " "empty tab number should use the restored empty accent color"
assert_contains "$rendered" "#[fg=#f9e2af,bg=#313244] scratch · empty " "empty tab label should use the restored empty label styling"

printf 'PASS: tests/statusline_test.sh\n'
