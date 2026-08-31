# Known issues

## Session file is detected, but restoring it errors

**Status:** open, not yet reproduced. Parked until the real error text is captured.

**Symptom:** on the welcome screen, salo-session reports that a session file was
found and offers `<Enter>` to restore it. Pressing `<Enter>` sometimes produces
errors instead of a restored session. Intermittent.

### Ruled out (2026-08-31)

- **Stale cursor position.** The theory was that `keepjumps <line>` in the
  generated session would throw `E16: Invalid range` when the recorded line no
  longer exists (file deleted or shortened). Neovim 0.12.4 clamps the motion
  instead of erroring — verified with a 1-line buffer and `keepjumps 6`, which
  leaves `v:errmsg` empty and exits 0.
- **The current session file being malformed.** `~/.config/wim/.vim/session.vim`
  sources cleanly in `nvim --clean --headless`, including after rewriting its
  `edit`/`badd` paths to point at files that do not exist.

### Live suspects

1. **Swap-file collision (`E325`).** The session `edit`s files that a second
   nvim instance already has open, so the restore stops on the ATTENTION
   prompt. Fits the intermittency: it depends on what else is running.
2. **The splash buffer is wiped mid-`source`.** The `<Enter>` mapping runs
   `vim.cmd('source ...')` from a Lua callback owned by the minintro buffer,
   which is created with `bufhidden = 'wipe'`. The session's `silent only` /
   `silent tabonly` / `edit <file>` destroy that buffer while the callback is
   still on the stack, which can surface as `E5108`.
3. **Degenerate sessions.** `save_session` runs unconditionally on
   `VimLeavePre`, so quitting straight from the welcome screen writes a session
   with no meaningful buffers. `filereadable()` then reports a session exists on
   the next start, and restoring it does nothing useful.

Also worth fixing regardless of the root cause: the restore path deletes the
session with `vim.cmd('silent! !rm ' .. session_file)`, which spawns a shell and
breaks on paths containing spaces. `vim.fn.delete()` is the correct call.

### What to capture next time it happens

- `:messages` immediately after the failed restore (before anything else).
- A copy of the offending `.vim/session.vim`.
- Whether another nvim had any of those files open at the time.
