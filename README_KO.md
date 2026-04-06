# tmux-tabjump

[English README](README.md)

로컬 커스텀 버전입니다.
이 플러그인은 **수동 탭 바 + 탭 자동 저장**으로 동작합니다.

## 핵심 동작

- 상태줄
  - 내가 만든 탭만 하단에 보여주고
  - 클릭하면 연결된 pane으로 전환합니다.
- `M-1..9`
  - 탭 1~9로 바로 이동합니다.
- `prefix + m`
  - 탭 관리 메뉴를 엽니다.
  - 새 탭 생성 / 탭 삭제 / 이름 변경 / pane 연결 / pane 해제 / 죽은 탭 정리

이 플러그인은 자체 polling에 의존하지 않고,
탭 변경/클릭 및 tmux 구조 변경 hook으로 상태줄을 새로고칩니다.

## Install

`~/.tmux.conf`:

```tmux
set -g @plugin 'liorium/tmux-tabjump'
```

TPM reload:

```bash
tmux run-shell ~/.tmux/plugins/tmux-tabjump/tabjump.tmux
```

## Usage

하단 바에서:

- `menu` 클릭 → 탭 관리 메뉴 열기
- 각 탭 배지 클릭 → 해당 pane으로 전환

`prefix + m` 메뉴에서:

- 새 탭 만들기
  - 현재 pane으로 바로 만들기
  - pane 선택 후 만들기
- 탭 관리에서
  - 기존 pane을 기존 탭에 붙이기
  - 기존 pane을 새 탭에 붙이기
- 기존 탭 상세 메뉴
  - 이동
  - pane 붙이기
  - pane 해제
  - 이름 변경
  - 삭제
- 죽은 탭 정리

필요하면 tmux 전역 redraw 주기는 별도로 직접 정하세요:

```tmux
set -g status-interval 0
```

## 저장 위치

탭은 자동으로 파일에 저장됩니다.

기본 저장 파일:

```bash
~/.local/state/tmux-tabjump/tabs.tsv
```

## Options

```tmux
set -g @tabjump-status-line '1'
set -g @tabjump-tabs-file '~/.local/state/tmux-tabjump/tabs.tsv'
set -g @tabjump-pane-menu-key 'm'
set -g @tabjump-direct-jump 'on'
```

## Notes

- 상태줄은 **수동 탭 목록**을 기준으로 그립니다.
- 탭은 이름과 연결된 pane_id를 tmux option에 저장합니다.
- 탭 상태는 파일에도 자동 저장됩니다.
- 탭은 비어 있을 수 있고, 연결된 pane이 사라지면 `dead` 표시가 납니다.
- 새 tmux 서버에서 플러그인이 로드되면 저장된 탭 이름을 다시 읽고,
  현재 live pane과 맞으면 자동으로 다시 연결합니다.
- 탭 저장 파일은 tab 이름과 pane 위치 메타데이터만 저장합니다.

## License

[MIT](LICENSE)
