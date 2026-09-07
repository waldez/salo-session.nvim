-- Pure helpers for placing text on the splash. Kept free of nvim API calls so
-- it can be tested headlessly.
local M = {}

-- ASCII on purpose: byte length equals display width, so callers can measure
-- with # and centre the result without a strdisplaywidth round trip.
local ELLIPSIS = '...'

-- Shorten a path so it occupies at most `width` columns, keeping the tail --
-- the project and file name matter, the leading directories do not.
--
-- Returning a shortened path rather than bailing out is the point: the prompt
-- used to disappear entirely on a narrow window, with nothing to explain why.
function M.fit(path, width)
   if width <= 0 then return '' end
   if #path <= width then return path end

   local tail = path:sub(#path - width + 1)
   if width <= #ELLIPSIS then return tail end

   -- The ellipsis only earns its three columns if it can sit on a separator,
   -- where it reads as "the path continues to the left". Anywhere else it just
   -- costs three characters of the filename, so show the bare tail instead.
   local keep = width - #ELLIPSIS
   local kept = path:sub(#path - keep + 1)
   local slash = kept:find('/', 1, true)
   if slash and slash > 1 and (#kept - slash) >= math.floor(keep / 2) then
      return ELLIPSIS .. kept:sub(slash)
   end

   return tail
end

-- Left column that centres a block of `block_width` columns, clamped to the
-- left edge so an oversized block starts on screen instead of off it.
function M.center_col(screen_width, block_width)
   return math.max(0, math.floor((screen_width - block_width) / 2))
end

return M
