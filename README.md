# Emacs Configuration

*Note:* This configuration has been tested exclusively on *Emacs 30.2.* Compatibility with older versions is not guaranteed.

A fast, minimal, Evil-first Emacs setup built for power users who want Vim muscle memory, zero friction, and deep integration across coding, knowledge management, PDFs, and terminal workflows.

This config is deliberately opinionated:
- Evil + Evil Collection as the foundation.
- A custom SQLite-powered speed-dial/workspace system (the most unique part).
- Native performance focus (native compilation, aggressive GC tuning, minimal UI).
- Vim-like behaviors everywhere (auto-save/swap handling, EOF navigation, scrolling, recovery).
- First-class support for Org-roam, C/C++ (Linux kernel style), PDFs, Eshell, and Arabic/RTL.

## Quick Start

1. Place `init.el` in `~/.emacs.d/` (or your `user-emacs-directory`).
2. Create the `lisp/` subdirectory and place `my-speed-dial.el` inside it.
3. (Optional but recommended) Create `local-theme.el` in the same directory and load any `ef-theme` you prefer.
4. Start Emacs. It will automatically:
   - Bootstrap `use-package` and MELPA.
   - Install all required packages on first run.
   - Create the SQLite database for speed-dial (`speed-dial.sqlite`).
5. Restart once after the first run to enable native compilation.

Fonts required (install via your package manager):
- `CMU Typewriter Text` (primary monospace)
- `Scheherazade New` (Arabic)
- Any Nerd Font / JetBrains Mono / Hack (for symbols and powerline-style glyphs)

## Core Philosophy & Performance

- **Startup speed**: GC threshold raised to 100 MB, `native-comp` warnings silenced, `load-prefer-newer`, no unnecessary startup screen.
- **Minimal UI**: No menu bar, tool bar, scroll bar, or mode line. Full-screen by default. Custom position ruler in the echo area (shows "Line X of Y --Z%--").
- **Vim-first**: Evil is loaded early. Leader key is `SPC`. ESC works everywhere (minibuffer, chords, etc.).
- **Clipboard**: `xclip` integration for seamless terminal + GUI copy/paste.
- **Auto-save**: Behaves exactly like Neovim/Vim swap files (centralized in `~/.local/state/emacs/recovery/`, instant creation, cursor position preserved, quiet recovery prompt).
- **EOF handling**: `j`/`G` never enter the empty POSIX newline. Visual selections are rescued from the void. `dd`/`p` on the last line behave like Vim.

## Keyboard Shortcuts (Leader = SPC)

| Prefix          | Binding                  | Action |
|-----------------|--------------------------|--------|
| `SPC f f`       | find-file                | Open file |
| `SPC h r r`     | my/reload-config         | Reload `init.el` |
| `SPC h c c`     | my/compile-config        | Native-compile or byte-compile all config files |
| `SPC a`         | hydra-speed-dial/body    | Open Speed Dial HUD / menu |
| `SPC b l`       | bookmark-bmenu-list      | List bookmarks |
| `SPC b s`       | bookmark-set             | Set bookmark |
| `SPC b j`       | bookmark-jump            | Jump to bookmark |
| `SPC b p`       | my/project-bookmark-jump | Jump to any bookmark in current workspace |
| `SPC b m`       | my/bookmark-set-absolute | Set absolute bookmark |
| `SPC b t`       | my/bookmark-tag-current-file | Tag current file into speed-dial |
| `SPC e w`       | my/eshell-workspace      | Eshell in workspace root |
| `SPC e f`       | my/eshell-current-file-dir | Eshell in current file's directory |
| `SPC n l`       | org-roam-buffer-toggle   | Toggle Org-roam sidebar |
| `SPC n f`       | org-roam-node-find       | Find Org-roam node |
| `SPC n i`       | org-roam-node-insert     | Insert Org-roam link |
| `SPC n s`       | org-roam-db-sync         | Sync Org-roam database |
| `SPC n g`       | org-roam-ui-mode         | Start Org-roam UI (web graph) |
| `SPC n t`       | org-transclusion-mode    | Toggle transclusion |
| `SPC n a`       | org-transclusion-add     | Add transclusion |
| `SPC n c`       | org-capture              | Capture to inbox |
| `SPC t t`       | ef-themes-toggle         | Toggle light/dark ef-theme |
| `SPC c o`       | imenu-list-smart-toggle  | Toggle VSCode-style outline sidebar (right) |
| `SPC s`         | my/jump-to-inline-mark   | Jump to inline mark (e.g. `mark:a`) |
| `g k`           | evil-avy-goto-char-timer | Avy jump (fast on-screen navigation) |

**Theme command**: `:colo` or `:colorscheme` (Evil Ex) — tab-completes all `ef-` themes.

**Minibuffer navigation**: `M-j` / `M-k` scrolls *Completions* window without losing selection.

## The Speed Dial System (Core Feature)

The most powerful part of this config. It is a two-handed, tag-based, SQLite-backed workspace bookmark system.

### Concepts
- **Workspace**: A directory you "lock" (`SPC a` → `p`). All speed-dial data is scoped to this directory.
- **Left hand (Global)**: 8 slots (`a s d f z x c v`) that are shared across all workspaces (or inherited from ancestor directories).
- **Right hand (Dynamic)**: 8 slots (`j k l ; m , . /`) that belong to the current tag.
- **Tags**: Named groups on the right hand (e.g. "main", "notes", "todo"). You can switch, create, rename, copy, or wipe them instantly.

### HUD Modes
- **Menu mode** (default): Press `SPC a` to open a full Hydra menu with live preview of all 16 slots.
- **Command mode**: `M-x command` (or `:command`) shows a persistent tmux-style HUD at top (right hand) + bottom (left hand). Press `M-x menu` to return to menu.

### Speed Dial Keybindings (inside Hydra)

- **Normal mode** (default): Press any slot key (`a`, `j`, etc.) to jump to that bookmark.
- `T` — Tag current file into a slot (shifts others down).
- `F` — Find any file on disk and tag it.
- `U` — Untag a slot.
- `M` — Move mode: pick a slot, then drop it somewhere else (even across hands/tags).
- `C` — Create new tag.
- `R` — Rename current tag.
- `Y` — Copy entire tag layout to a new tag.
- `W` — Wipe (delete) a tag.
- `X` — Nuke entire workspace.
- `O` — Organize (remove gaps, shift slots up).
- `A` — Anchor (switch to any previously used workspace, sorted by proximity).
- `P` — Clone another workspace into the current one.
- `I` — Inherit global slots from the nearest ancestor workspace that has them.
- `p` — Lock a new workspace directory.
- `t` — Lock/switch right-hand tag.
- `q` / `ESC` — Quit.

Eshell commands:
- `plant [dir]` — lock workspace to current or given directory.
- `anchor <tab>` — switch to any known workspace (proximity-sorted completion).

## Org Mode Ecosystem

- Org-roam + database autosync + UI (graph view).
- Org-transclusion for embedding notes.
- Org-download for images in notes.
- Org-capture → `~/org-roam/inbox.org`.
- Org-appear (auto-show emphasis markers, links, etc.).
- Evil-org + evil-org-agenda key themes.

## Terminal & Eshell

- `eat` provides full terminal emulation inside Eshell (visual commands work perfectly).
- `C-l` clears buffer instantly.
- `M-k` / `M-j` in insert mode for history navigation.
- Directory-aware completion that does **not** add a trailing space after directories.
- Custom aliases: `vi <file>` opens in Emacs.
- `my/eshell-workspace` and `my/eshell-current-file-dir` bound to leader.

## PDF Tools

- Full `pdf-tools` integration with `pdf-view-midnight-minor-mode`.
- Colors automatically update when you change themes.
- `O` — Open PDF outline.
- `P` — Show full chapter breadcrumb path in echo area (dynamic outline navigation).
- Spacebar works as Evil leader (no more conflict).
- `gg` / `G` / `C-o` completely disabled inside PDFs to prevent accidental jumps.

## C / C++ Development

- Eglot + clangd (with experimental C++ modules support).
- Linux kernel indentation style (8-column tabs, real tabs, `BreakBeforeBraces: Linux`).
- Corfu completion (manual trigger with `C-n`, `TAB`/`C-l` to accept, `C-j`/`C-k` to cycle, `RET` cycles down).
- YASnippet enabled globally.
- No semantic tokens or inlay hints (clean, comment-only syntax coloring).
- `.cppm` files treated as C++.

## Other Highlights

- **ef-themes**: Beautiful, high-contrast themes with instant toggle and custom `:colo` command.
- **Elfeed**: RSS reader with `v` to play YouTube links in mpv.
- **Imenu-list**: VSCode-style symbol outline on the right.
- **Avy**: `g k` for lightning-fast on-screen jumps.
- **Camouflage**: Invisible fix for the "chopped last line" rendering artifact that survives theme changes.
- **Bookmarks**: Centralised, persistent, and fully integrated with speed-dial.
- **Relative line numbers**: Commented out by default (uncomment if desired).
- **RTL / Arabic**: Proper visual-order cursor movement + dedicated font scaling.

## Customization Points

- `custom.el` is loaded automatically (keeps your manual customizations safe).
- `local-theme.el` — load your preferred `ef-` theme here.
- `elfeed.org` — your RSS feed list (used by `elfeed-org`).
- All speed-dial data lives in `speed-dial.sqlite` (human-readable, easy to back up).

## Reload / Compile

- `SPC h r r` → instant reload of `init.el`.
- `SPC h c c` → native-compile (or byte-compile) all config files for maximum speed.

## Why This Config Feels So Fast

- Aggressive GC tuning.
- Native compilation everywhere possible.
- No unnecessary packages or minor modes.
- Everything is loaded exactly when needed (`:after`, hooks, `with-eval-after-load`).
- SQLite for speed-dial (no slow file I/O).

Enjoy the config. It is built to stay out of your way while giving you superpowers exactly where you need them.
