# Known issues

## Session file is detected, but restoring it errors

**Status:** fixed 2026-09-07. Root cause found and reproduced. Kept here as a
record of what the failure actually was.

**Symptom:** on the welcome screen, salo-session reports that a session file was
found and offers `<Enter>` to restore it. Pressing `<Enter>` sometimes produces
errors instead of a restored session. Intermittent.

The error, captured in `~/work/salo-session.nvim`:

```
E5108: Lua: [string "vim/_core/editor"]:355: nvim_exec2(), line 1:
Vim(source):E484: Can't open file /home/waldez/work/salo-session.nvim/.vim/session.vim
```

### Root cause

Suspects 2 and 3 below, compounding. `<Enter>` was pressed twice, and the
second press sourced a file the first press had already deleted:

1. Quitting straight from the welcome screen wrote a **degenerate session**:
   `save_session` ran unconditionally on `VimLeavePre`, and with
   `sessionoptions = 'buffers,tabpages'` a session holding only the `minintro`
   splash buffer contains no `edit`, no `badd` and no window layout. It
   restores nothing.
2. Because it restores nothing, sourcing it **leaves you on the splash** —
   buffer still valid, still current, `<Enter>` mapping still installed, restore
   prompt still drawn.
3. So the screen still said "Session found, press `<Enter>` to restore". A
   second `<Enter>` re-entered the callback and ran `source` on the file that
   the first `<Enter>` had just `rm`'d — `E484`, surfacing as `E5108` because
   the failure happened inside a Lua callback.

That also explains the leftover empty `.vim/` directory: the `rm` on the first
press succeeded.

### The fix

- `salo-session.session_state.worth_saving()` gates `save_session`: a session is
  only written when at least one buffer is listed, has an empty `buftype` and
  has a name. Quitting from the welcome screen now writes nothing.
- The `<Enter>` mapping is one-shot. It deletes its own keymap and the prompt
  extmark before doing anything else, so the prompt cannot be triggered twice.
- The restore itself is guarded: a missing file and a failing `source` are both
  reported through `vim.notify` at `ERROR` level instead of throwing.
- `vim.cmd('silent! !rm ...')` replaced with `vim.fn.delete()`, which keeps the
  deletion off the shell (the old form broke on paths containing spaces).

### Ruled out (2026-08-31)

- **Stale cursor position.** The theory was that `keepjumps <line>` in the
  generated session would throw `E16: Invalid range` when the recorded line no
  longer exists (file deleted or shortened). Neovim 0.12.4 clamps the motion
  instead of erroring — verified with a 1-line buffer and `keepjumps 6`, which
  leaves `v:errmsg` empty and exits 0.
- **The current session file being malformed.** `~/.config/wim/.vim/session.vim`
  sources cleanly in `nvim --clean --headless`, including after rewriting its
  `edit`/`badd` paths to point at files that do not exist.
- **Swap-file collision (`E325`).** Plausible in general, but not what happened
  here: the error was `E484`, a missing file, not an ATTENTION prompt.

## Restore prompt missing on narrow terminals

**Status:** fixed 2026-09-07.

`load_session` centred the prompt with
`start_col = (screen_width - #session_file) / 2` and then bailed out entirely on
`if (start_col < 0 or start_row < 0) then return end`. Whenever the session path
was wider than the window there was no prompt, no message and no way to restore
the session -- an 80-column terminal on a project path of 80+ characters was
enough.

`salo-session.layout.fit()` now shortens the path to the window instead,
keeping the tail, since the project and file name are what identify it. The
ellipsis is only used when it can sit on a `/`, where it reads as "the path
continues to the left"; anywhere else it would just cost three columns of
filename, so the bare tail is shown. Both prompt lines are centred as a block
on whichever is wider, and the extmark row is clamped to the buffer.

## Splash crashes when lazy.nvim installs a plugin at startup

**Status:** fixed 2026-09-08.

Adding a new plugin spec and starting nvim produced two errors:

```
Error in VimEnter Autocommands for "*":
Lua callback: .../salo-session/init.lua:75: Invalid buffer id: 2
        [C]: in function 'nvim_buf_delete'
Error in VimEnter Autocommands for "*":
E5108: Lua: .../salo-session/init.lua:207: Invalid window id: -1
        [C]: in function 'nvim_win_get_width'
```

`display_minintro` decided which buffer to replace by looking at the *current*
buffer and checking only its name:

```lua
if not is_dir and default_buff_name ~= '' and default_buff_filetype ~= PLUGIN_NAME then return end
```

While a plugin installs, lazy.nvim's popup is focused at `VimEnter`, and that
popup buffer is **unnamed**:

```
buf 1 name="" buftype=""       filetype=""         bufhidden=""
buf 2 name="" buftype="nofile" filetype="lazy"     bufhidden="wipe"   <- picked
```

So the splash mistook the popup for the buffer nvim starts with, took over its
window, and `nvim_set_current_buf` wiped the popup buffer (`bufhidden=wipe`)
before the `nvim_buf_delete` that followed -- hence `Invalid buffer id: 2`. The
real startup buffer was never cleaned up.

The second error is a cascade: the throw left `minintro_buff` unassigned at its
`-1` initial value, so `load_session` called `bufwinid(-1)` -> `-1` ->
`nvim_win_get_width(-1)`.

### The fix

- `session_state.splash_target()` picks the window to take over from *all*
  windows, not the focused one: an unnamed buffer only qualifies when its
  `buftype` is also empty, which excludes every plugin scratch window. A named
  buffer qualifies only when it is a directory (`nvim .`).
- The splash is placed with `nvim_win_set_buf(win, ...)` rather than
  `nvim_set_current_buf`, so a popup open at `VimEnter` keeps its window and
  its focus.
- The delete is guarded with `nvim_buf_is_valid`, since switching away can wipe
  the outgoing buffer on its own.
- `load_session` returns quietly when there is no splash buffer or it is not in
  a window, instead of throwing.

## Auto-update fails with "cannot lock ref"

**Status:** fixed 2026-09-15.

Opening nvim in a fresh directory produced:

```
salo-session: updating gitsigns.nvim failed
error: cannot lock ref 'refs/remotes/origin/diffwk': is at 08bf78e... but expected d530c81...
 ! d530c81...08bf78e diffwk     -> origin/diffwk  (unable to update local ref)
```

Git's compare-and-swap on the ref failed because **another `git fetch` in the
same repository had already moved it** -- the ref was left at exactly the value
our fetch was trying to write, and the repository was otherwise healthy. Only
branches that moved upstream can collide, which is why it was intermittent and
named one odd branch.

The other fetch was lazy.nvim's own checker (`checker = { enabled = true }` in
wim). On a start where its last check is older than `checker.frequency`:

1. `VimEnter` -> `auto_update` -> `manage.update` / `manage.check` -> `git fetch`
2. `VeryLazy` + 10ms -> `checker.start()` -> check due -> `Manage.check` -> a
   second `git fetch` in every repository, concurrently

### Why not simply wait for the checker

The first attempt waited for `User LazyCheck` before fetching. It never fired in
testing: `checker.start()` posts its multi-line "# Plugin Updates" notification
*before* scheduling the check, and that notification raises a hit-enter prompt.
Until it is dismissed the checker does not even schedule its fetch, and lazy's
in-flight git callbacks do not complete. A wait with a timeout would then start
fetching while the checker was still blocked, and dismissing the prompt later
would recreate the race.

### The fix

`lazy_report.plan()` decides how to discover updates, mirroring lazy's own
scheduling (`last_check + frequency - now`, clamped to zero):

- **claim** -- the checker's fetch is due now. salo does the full network check
  itself and first records it in lazy's `state.json`, exactly as the checker
  records its own. The checker reads that file on `VeryLazy`, which is after
  `VimEnter`, finds nothing due, and reschedules instead of fetching.
- **offline** -- the checker fetched recently and will not fetch now. Update
  whatever the already-fetched refs show as pending; no discovery fetch.
- **own** -- checker disabled, blocked by plugin errors (it skips fetching
  then), or the manual `u` re-run. Fetch as before.

Verified in an isolated lazy setup with every `git fetch` start and exit logged
per repository, and the checker's entry points traced. With a plugin one commit
behind:

- claim: salo's check fetches start at VimEnter; the checker reads the claimed
  state, reschedules ~3600s out and never enters `check()`; once lazy's prompt
  is dismissed salo's fetches complete, then the update fetch runs on its own
  and the plugin lands on its target commit.
- offline: the update fetch runs alone, the checker only runs `git log`, and
  the plugin lands on its target commit.

### Left as is

- lazy's "# Plugin Updates" notification still appears at startup, and its
  hit-enter prompt still has to be dismissed before in-flight updates finish.
  It is lazy's own `checker.notify` (default `true`), and it predates this fix.
  Setting `checker = { enabled = true, notify = false }` in wim would silence
  it, at the cost of losing it on starts with file arguments, where salo does
  not auto-update.
- Two nvim instances starting at the same moment can still fetch concurrently.

## By design, not a bug

- **`save_session` never creates `.vim/`.** Creating that directory is the
  signal that a directory is a project, and it is made deliberately, by hand.
  Auto-creating it would scatter `.vim/` across every directory nvim is ever
  opened in. Sessions are only written where `.vim/` already exists.
