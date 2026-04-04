# Contributing to tmux-tabjump

This is a tmux plugin for manual tab routing and quick pane jumps.

## Structure

```
tabjump.tmux            ← tpm entry point (shell script)
scripts/
  statusline.sh          ← statusline wrapper
  pane-menu.sh           ← tab management menu
```

## Development

```bash
# Clone
git clone https://github.com/liorium/tmux-tabjump.git
cd tmux-tabjump

# Test in tmux (source directly)
tmux source-file tabjump.tmux
```

No build step. All files are plain shell scripts.

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add tab management action
fix: keep tab metadata in sync
docs: update install instructions
```

### Types

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `chore` | Config, CI, dependencies |

## Branch Naming

```
feature/{issue-number}
```

## Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/{issue-number}`
3. Make your changes
4. Test by sourcing in tmux: `tmux source-file tabjump.tmux`
5. Commit following the conventions above
6. Open a Pull Request against `main`

### PR Guidelines

- Keep PRs focused — one change per PR
- Test tab creation/attach/detach/delete flows
- Test default and custom `@tabjump-*` options

## Reporting Bugs

Use the project issue tracker and include your tmux version plus reproduction steps.

## Questions?

Open an issue in the `tmux-tabjump` repository.
