-- Pure helper deciding whether a session is worth writing at all.
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

return M
