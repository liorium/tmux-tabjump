#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
LOG_FILE="$TMP_DIR/log"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

export LOG_FILE

cat >"$TMP_DIR/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
refresh-client)
  printf 'tmux %s\n' "$*" >>"${LOG_FILE:?}"
  ;;
*)
  echo "unsupported tmux command: $*" >&2
  exit 1
  ;;
esac
EOF
chmod +x "$TMP_DIR/tmux"

cat >"$TMP_DIR/pane-menu.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'pane-menu %s\n' "$*" >>"${LOG_FILE:?}"
EOF
chmod +x "$TMP_DIR/pane-menu.sh"

cat >"$TMP_DIR/jump-visible-pane.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'jump %s\n' "$*" >>"${LOG_FILE:?}"
EOF
chmod +x "$TMP_DIR/jump-visible-pane.sh"

PATH="$TMP_DIR:$PATH"
export PATH
export TABJUMP_PANE_MENU_SCRIPT="$TMP_DIR/pane-menu.sh"
export TABJUMP_JUMP_SCRIPT="$TMP_DIR/jump-visible-pane.sh"

assert_contains() {
  local needle="$1"
  local message="$2"

  if ! grep -Fqx "$needle" "$LOG_FILE"; then
    printf 'FAIL: %s\nmissing: %s\nlog:\n' "$message" "$needle" >&2
    cat "$LOG_FILE" >&2 || true
    exit 1
  fi
}

assert_not_contains() {
  local needle="$1"
  local message="$2"

  if grep -Fqx "$needle" "$LOG_FILE"; then
    printf 'FAIL: %s\nunexpected: %s\nlog:\n' "$message" "$needle" >&2
    cat "$LOG_FILE" >&2 || true
    exit 1
  fi
}

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/status-click.sh" menu down /dev/pts/1
assert_not_contains "pane-menu show  /dev/pts/1" "menu should not open on mouse down"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/status-click.sh" menu up /dev/pts/1
assert_contains "pane-menu show  /dev/pts/1" "menu should open on mouse up"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/status-click.sh" tab:3 down
assert_contains "jump 3" "tab clicks should still jump on mouse down"
assert_contains "tmux refresh-client -S" "tab jump should refresh the client"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/status-click.sh" tab:3 up
assert_not_contains "jump 3" "tab clicks should not fire on mouse up"

printf 'PASS: tests/status_click_test.sh\n'
