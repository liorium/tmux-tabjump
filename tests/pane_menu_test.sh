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
  format="${*: -1}"
  case "$format" in
  '#{pane_id}')
    printf '%%2\n'
    ;;
  '#{w:@tabjump-internal-width-probe}')
    read_value "@tabjump-internal-width-probe" | wc -L | tr -d '[:space:]'
    ;;
  *)
    echo "unsupported display-message format: $format" >&2
    exit 1
    ;;
  esac
  ;;
list-panes)
  format="${*: -1}"
  case "$format" in
  '#{pane_id}')
    printf '%%1\n%%2\n%%3\n%%4\n'
    ;;
  '#{session_name}	#{window_index}	#{window_name}	#{pane_index}	#{pane_id}	#{pane_current_path}')
    printf 'dev\t1\teditor\t0\t%%1\t/home/wl/work\n'
    printf 'dev\t2\tlogs\t0\t%%2\t/home/wl/logs\n'
    printf 'dev\t3\tshell\t0\t%%3\t/home/wl/tmp\n'
    printf 'development-team\t7\tsuper-long-editor-window-name\t1\t%%4\t/home/wl/workspace/projects/customer-alpha/releases/2026/sprint-12/archive\n'
    ;;
  *)
    echo "unsupported list-panes format: $format" >&2
    exit 1
    ;;
  esac
  ;;
display-menu)
  {
    printf 'display-menu'
    for arg in "$@"; do
      printf ' %s' "$arg"
    done
    printf '\n'
  } >>"$log_file"
  ;;
refresh-client)
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

assert_contains() {
  local needle="$1"
  local message="$2"

  if ! grep -Fq -- "$needle" "$LOG_FILE"; then
    printf 'FAIL: %s\nmissing: %s\nlog:\n' "$message" "$needle" >&2
    cat "$LOG_FILE" >&2 || true
    exit 1
  fi
}

assert_not_contains() {
  local needle="$1"
  local message="$2"

  if grep -Fq -- "$needle" "$LOG_FILE"; then
    printf 'FAIL: %s\nunexpected: %s\nlog:\n' "$message" "$needle" >&2
    cat "$LOG_FILE" >&2 || true
    exit 1
  fi
}

tab_names=("work" "notes" "current" "graveyard" "project-alpha-super-long-tab-name")
tab_panes=("%1" "" "%2" "%99" "%4")
save_tabs tab_names tab_panes

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/pane-menu.sh" show /dev/pts/1
assert_contains "display-menu -T Tabjump -x C -y C" "main menu should open centered on the client"
assert_contains "-c /dev/pts/1" "main menu should target the current client"
assert_contains "현재 pane 작업" "main menu should split pane actions from tab management"
assert_contains "탭 관리" "main menu should expose tab management as a separate branch"
assert_contains "단축키 보기" "main menu should expose a shortcuts entry"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/pane-menu.sh" show-shortcuts /dev/pts/1
assert_contains "display-menu -T 단축키 -x C -y C" "shortcuts menu should use the centered anchor position"
assert_contains "Option+1..9: 해당 탭으로 이동" "shortcuts menu should list the numeric tab jump binding"
assert_contains 'Option+`: 이전 탭으로 이동' "shortcuts menu should list the previous-tab binding"
assert_contains "prefix + m: 현재 pane 작업 열기" "shortcuts menu should describe the new default menu entrypoint"
assert_contains "← 메인 메뉴" "shortcuts menu should provide a way back to the main menu"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/pane-menu.sh" show-pane-actions /dev/pts/1
assert_contains "display-menu -T 현재 pane 작업 -x C -y C" "pane actions menu should use the centered anchor position"
assert_contains "현재 상태 · #[fg=#3B82F6,bold]3 current#[default]" "pane actions should summarize the current pane's attached tab"
assert_contains "⇄ 기존 탭에 붙이기" "pane actions should make attaching to an existing tab the top action"
assert_contains "＋ 새 탭에 붙이기" "pane actions should make creating a new attached tab the second action"
assert_contains "⊘ 현재 탭에서 해제" "pane actions should still allow detaching the current pane"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/pane-menu.sh" show-manage-menu /dev/pts/1
assert_contains "display-menu -T 탭 관리 -x C -y C" "tab management menu should use the centered anchor position"
assert_contains "다른 pane 붙이기" "tab management should group attach actions separately"
assert_contains "⇄ 다른 pane을 기존 탭에 붙이기" "tab management should allow attaching another pane to an existing tab"
assert_contains "＋ 다른 pane으로 새 탭 만들기" "tab management should allow creating a new tab from another pane"
assert_contains "탭 구조 관리" "tab management should group structural actions separately"
assert_contains "⇅ 순서 변경" "tab management should prioritize reorder first"
assert_contains "✎ 이름 변경" "tab management should prioritize rename second"
assert_contains "✕ 삭제" "tab management should prioritize delete third"
assert_contains "↺ dead/empty 정리" "tab management should offer explicit dead/empty cleanup"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/pane-menu.sh" show-tab-picker attach-current %2 /dev/pts/1
assert_contains "display-menu -T 기존 탭에 붙이기 -x C -y C" "attach-current flow should open the dedicated tab picker"
assert_contains "#[fg=#cdd6f4]1 work · 연결됨#[default]" "attach picker should color connected tabs with the default menu text color"
assert_contains "#[fg=#f9e2af]2 notes · 비어 있음#[default]" "attach picker should color empty tabs with the empty-tab accent"
assert_contains "#[fg=#3B82F6,bold]3 current · 현재 pane#[default]" "attach picker should color the current tab with the active accent"
assert_contains "#[fg=#f38ba8]4 graveyard · 죽은 pane#[default]" "attach picker should color dead tabs with the dead-tab accent"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/pane-menu.sh" show-tab-picker reorder "" /dev/pts/1
assert_contains "display-menu -T 순서 바꿀 탭 선택 -x C -y C" "reorder flow should start from a dedicated tab picker"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/pane-menu.sh" show-tab-picker attach-existing-tab "" /dev/pts/1
assert_contains "display-menu -T 붙일 탭 선택 -x C -y C" "attach-existing-tab flow should use a clearer tab picker title"
assert_contains "run-shell '$ROOT_DIR/scripts/pane-menu.sh show-pane-picker attach 1 \"/dev/pts/1\"'" "attach-existing-tab should route tab 1 to pane picker"
assert_contains "run-shell '$ROOT_DIR/scripts/pane-menu.sh show-pane-picker attach 2 \"/dev/pts/1\"'" "attach-existing-tab should route tab 2 to pane picker"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/pane-menu.sh" show-pane-picker create-selected "work-copy" /dev/pts/1
assert_contains "display-menu -T 새 탭 'work-copy'에 붙일 pane 선택 -x C -y C" "create-selected pane picker should show a clearer target title"
assert_contains "1 dev:editor.0 · ~/work · 탭 1 work" "pane picker should show the pane's current tab assignment"
assert_contains "2 dev:logs.0 · ~/logs · 탭 3 current ← current" "pane picker should show the current pane assignment and marker together"
assert_contains "3 dev:shell.0 · ~/tmp · 미지정" "pane picker should show unassigned panes explicitly"
assert_contains "4 " "pane picker should include the long-label pane"
assert_contains "…" "pane picker should truncate long pane labels with an ellipsis"
assert_not_contains "development-team:super-long-editor-window-name.1 · ~/…/sprint-12/archive · 탭 5 project-alpha-super-long-tab-name" "pane picker should not render the full long descriptor inline"
assert_contains "run-shell '$ROOT_DIR/scripts/pane-menu.sh create-selected \"work-copy\" %1 \"/dev/pts/1\"'" "create-selected should attach selected pane into the named new tab"
assert_contains "run-shell '$ROOT_DIR/scripts/pane-menu.sh create-selected \"work-copy\" %2 \"/dev/pts/1\"'" "create-selected should offer all panes in picker"
assert_contains "run-shell '$ROOT_DIR/scripts/pane-menu.sh create-selected \"work-copy\" %3 \"/dev/pts/1\"'" "create-selected should offer unassigned panes too"
assert_contains "run-shell '$ROOT_DIR/scripts/pane-menu.sh create-selected \"work-copy\" %4 \"/dev/pts/1\"'" "create-selected should offer long-label panes too"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/pane-menu.sh" show-reorder 2 /dev/pts/1
assert_contains "display-menu -T 순서 변경 · notes -x C -y C" "reorder detail should use the centered anchor position"
assert_contains "↑ 위로 이동" "reorder detail should offer moving a tab upward"
assert_contains "↓ 아래로 이동" "reorder detail should offer moving a tab downward"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/pane-menu.sh" show-delete-confirm 2 /dev/pts/1 manage
assert_contains "display-menu -T 삭제 확인 · notes -x C -y C" "delete confirm should show the target tab name"
assert_contains "정말 삭제할까요?" "delete confirm should require an explicit confirmation step"
assert_contains "run-shell '$ROOT_DIR/scripts/pane-menu.sh delete 2 \"/dev/pts/1\" manage'" "delete confirm should preserve the manage return path"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/pane-menu.sh" show-prune-confirm /dev/pts/1 manage
assert_contains "display-menu -T 정리 확인 -x C -y C" "prune confirm should use a dedicated confirmation menu"
assert_contains "dead/empty 탭을 정리할까요?" "prune confirm should explain the destructive action"
assert_contains "run-shell '$ROOT_DIR/scripts/pane-menu.sh prune \"/dev/pts/1\" manage'" "prune confirm should keep the manage return path"

: >"$LOG_FILE"
bash "$ROOT_DIR/scripts/pane-menu.sh" prune /dev/pts/1 manage
assert_contains "display-menu -T 탭 관리 -x C -y C" "cleanup should return to the tab management menu"

post_prune_names=()
post_prune_panes=()
load_tabs post_prune_names post_prune_panes
if [ "${#post_prune_names[@]}" -ne 3 ]; then
  printf 'FAIL: prune should keep connected tabs including long-label assignments\n' >&2
  exit 1
fi
if [ "${post_prune_names[0]}" != "work" ] || [ "${post_prune_names[1]}" != "current" ] || [ "${post_prune_names[2]}" != "project-alpha-super-long-tab-name" ]; then
  printf 'FAIL: prune should keep only connected/current tabs\n' >&2
  exit 1
fi

printf 'PASS: tests/pane_menu_test.sh\n'
