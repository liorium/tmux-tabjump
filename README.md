# tmux-tabjump

[한국어 README](README_KO.md)

This is a local custom version.
The plugin provides a **manual tab bar + automatic tab persistence**.

## Core behavior

- Status line
  - Shows only the tabs you created on the bottom bar
  - Clicking a tab jumps to the linked pane
- `M-1..9`
  - Jump directly to tabs 1 through 9
- `prefix + m`
  - Opens the main menu first
  - Current Pane Actions / Tab Management / Settings

The plugin does not rely on its own polling loop.
Instead, it refreshes the status line on tab changes, clicks, and tmux structure-change hooks.

## Install

In `~/.tmux.conf`:

```tmux
set -g @plugin 'liorium/tmux-tabjump'
```

Reload TPM:

```bash
tmux run-shell ~/.tmux/plugins/tmux-tabjump/tabjump.tmux
```

## Usage

From the bottom bar:

- Click `menu` to open the tab management menu
- Click a tab badge to jump to its pane

From the `prefix + m` menu:

- It opens on the main menu first.
- Main menu
  - Current Pane Actions
  - Tab Management
  - Settings
- From Settings
  - Shortcuts
  - Language
  - English / 한국어
- Language is persisted in the tmux server and defaults to English.

- Create a new tab
  - Create from the current pane
  - Pick a pane first, then create
- In the tab management menu
  - Attach another pane to an existing tab
  - Create a new tab from another pane
  - Confirm before delete / dead-empty cleanup
  - Show each pane's current tab assignment in the pane picker
  - Truncate long pane / tab labels in the picker to keep menus scannable
  - Respect wide character widths (for example Korean) when truncating picker labels
- Existing tab detail menu
  - Jump
  - Attach pane
  - Detach pane
  - Rename
  - Delete
- Prune dead tabs

If needed, set the global tmux redraw interval yourself:

```tmux
set -g status-interval 0
```

## Storage location

Tabs are automatically saved to a file.

Default save file:

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

- The status line is rendered from the **manual tab list**.
- Tabs store the tab name and linked `pane_id` in tmux options.
- Tab state is also persisted to a file automatically.
- Tabs may be empty, and if a linked pane disappears it is shown as `dead`.
- When the plugin loads in a new tmux server, it reloads saved tab names and automatically reconnects them when a matching live pane exists.
- The tab save file stores only tab names and pane location metadata.

## License

[MIT](LICENSE)
