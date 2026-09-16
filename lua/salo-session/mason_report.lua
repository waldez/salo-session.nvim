-- Pure helpers over Mason package state: what is outdated, and how to report
-- a check or an update as renderable lines.
-- Kept free of nvim API calls so it can be tested headlessly.
local M = {}

local function plural(n, word)
   return n .. ' ' .. word .. (n == 1 and '' or 's')
end

-- Packages whose installed version differs from the registry's latest, sorted
-- by name. Mason's own UI treats any difference as outdated too. Packages that
-- cannot be compared -- no install receipt, or a registry entry too malformed
-- to name a version -- are left out rather than guessed at.
--
-- Each entry is { name = ..., installed = ..., latest = ... }.
function M.outdated(pkgs)
   local out = {}
   for _, p in ipairs(pkgs) do
      if p.installed and p.latest and p.installed ~= p.latest then
         table.insert(out, { name = p.name, from = p.installed, to = p.latest })
      end
   end
   table.sort(out, function(a, b) return a.name < b.name end)
   return out
end

-- The last `max_lines` lines of installer output, noting how many came before.
-- The end of the output is where installers explain why they failed.
function M.tail(text, max_lines)
   text = (text or ''):gsub('%s+$', '')
   if text == '' then return '' end

   local lines = vim.split(text, '\n', { plain = true })
   if #lines <= max_lines then return text end

   local omitted = #lines - max_lines
   return ('... (%s omitted)\n'):format(plural(omitted, 'earlier line'))
      .. table.concat(lines, '\n', omitted + 1)
end

-- The message for a failed install. Mason writes its own error into the
-- installer's stderr as well, so when the captured output already carries it
-- the output is shown alone; otherwise the error comes first, so it is never
-- lost -- not even when truncation dropped it from the output.
function M.failure_message(result, output, max_lines)
   local err = result == nil and '' or vim.trim(tostring(result))
   local tail = M.tail(output, max_lines)

   if tail == '' then
      return err ~= '' and err or '(Mason gave no error details)'
   end
   if err == '' or tail:find(err, 1, true) then return tail end
   return err .. '\n' .. tail
end

local function add_versions(out, list)
   for _, u in ipairs(list) do
      table.insert(out, { '  ' .. u.name .. '  ' .. u.from .. ' -> ' .. u.to, 'Comment' })
   end
end

local function add_names(out, names)
   for _, name in ipairs(names) do
      table.insert(out, { '  - ' .. name, 'Comment' })
   end
end

-- Turns a Mason state into { text, highlight } pairs ready for virt_lines.
-- Phases: 'checking', 'outdated', 'updating', 'done', 'crashed'.
function M.lines(state)
   local out = {}
   local phase = state.phase

   if phase == 'checking' then
      table.insert(out, { 'Checking Mason packages...', 'Comment' })

   elseif phase == 'outdated' then
      local outdated = state.outdated or {}
      if #outdated > 0 then
         table.insert(out, { 'Mason: ' .. plural(#outdated, 'package') .. ' outdated, press M to update:',
            'DiagnosticInfo' })
         add_versions(out, outdated)
      end

   elseif phase == 'updating' then
      local pending = state.pending or {}
      table.insert(out, { 'Updating ' .. plural(#pending, 'Mason package') .. '...', 'DiagnosticInfo' })
      add_names(out, pending)

   elseif phase == 'crashed' then
      table.insert(out, { 'Mason CRASHED:', 'ErrorMsg' })
      for _, line in ipairs(vim.split(tostring(state.error), '\n', { plain = true })) do
         table.insert(out, { '  ' .. line, 'ErrorMsg' })
      end

   elseif phase == 'done' then
      local updated = state.updated or {}
      if #updated > 0 then
         table.insert(out, { 'Updated ' .. plural(#updated, 'Mason package') .. ':', 'DiagnosticOk' })
         add_versions(out, updated)
      end

      local skipped = state.skipped or {}
      if #skipped > 0 then
         table.insert(out, { 'Skipped ' .. plural(#skipped, 'Mason package') .. ', already being installed:',
            'Comment' })
         add_names(out, skipped)
      end

      local errors = state.errors or {}
      if #errors > 0 then
         table.insert(out, { 'Mason update FAILED for ' .. plural(#errors, 'package') .. ':', 'ErrorMsg' })
         for _, e in ipairs(errors) do
            table.insert(out, { '  ' .. e.name .. ':', 'ErrorMsg' })
            for _, line in ipairs(vim.split(e.msg, '\n', { plain = true })) do
               table.insert(out, { '    ' .. line, 'ErrorMsg' })
            end
         end
      end
   end

   return out
end

return M
