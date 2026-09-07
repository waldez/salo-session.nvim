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

## Still open

- **`save_session` does not create `.vim/`.** If the directory does not already
  exist, `mksession!` fails and no session is ever written for that project.
- **The restore prompt silently disappears on narrow terminals.** `load_session`
  bails out via `if (start_col < 0 or start_row < 0) then return end`, so when
  the session path is wider than the window there is no prompt and no
  explanation. Long project paths in an 80-column terminal hit this.
