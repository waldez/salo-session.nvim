-- Pure predicates over buffer and window state: which buffers represent real
-- work, and which one is throwaway enough for the splash to replace.
-- Kept free of nvim API calls so it can be tested headlessly.
local M = {}

-- True only if at least one buffer is backed by a real file on disk.
--
-- Quitting straight from the welcome screen otherwise writes a session that
-- restores nothing: sourcing it leaves you on the splash, with the restore
-- prompt still on screen, inviting a second <Enter> onto a file the first
-- <Enter> has already deleted.
function M.worth_saving(buffers)
   for _, b in ipairs(buffers) do
      if b.listed and b.buftype == '' and b.name ~= '' then
         return true
      end
   end
   return false
end

-- The window the welcome screen may take over, or nil if there is none.
--
-- Deliberately not just "the current window": while a plugin is installing,
-- lazy.nvim's popup is focused at VimEnter. That popup buffer is unnamed, so
-- checking the name alone mistook it for the buffer nvim starts with -- the
-- splash then took over the popup's window and nvim wiped the popup buffer
-- (bufhidden=wipe) out from under the delete that followed.
--
-- Each entry is { win = id, name = ..., buftype = ..., isdir = ... }.
function M.splash_target(windows)
   for _, w in ipairs(windows) do
      if w.name == '' then
         -- Unnamed and ordinary: the buffer nvim starts with. Unnamed with a
         -- buftype is some plugin's scratch window, and not ours to claim.
         if w.buftype == '' then return w.win end
      elseif w.isdir then
         -- `nvim .` lands on a directory listing, which the splash replaces.
         return w.win
      end
   end
   return nil
end

return M
