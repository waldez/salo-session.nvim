-- Pure helpers that turn lazy.nvim plugin state into renderable report lines.
-- Kept free of nvim API calls so it can be tested headlessly.
local M = {}

-- Names of plugins the checker found pending updates for. Local dev plugins
-- and pinned plugins are excluded: checking those out would fight the work in
-- their worktree, and lazy marks local plugins as outdated whenever they are
-- merely ahead of upstream.
function M.pending(plugins)
   local names = {}
   for _, plugin in pairs(plugins) do
      if plugin._ and plugin._.updates and not plugin._.is_local and not plugin.pin then
         table.insert(names, plugin.name)
      end
   end
   table.sort(names)
   return names
end

-- Plugins whose checked-out commit actually moved during an update.
function M.updated(plugins)
   local moved = {}
   for _, plugin in pairs(plugins) do
      local u = plugin._ and plugin._.updated
      if u and u.from and u.to and u.from ~= u.to then
         table.insert(moved, {
            name = plugin.name,
            from = u.from:sub(1, 7),
            to = u.to:sub(1, 7),
         })
      end
   end
   table.sort(moved, function(a, b) return a.name < b.name end)
   return moved
end

-- Full error output of every failing task, grouped per plugin. Tasks are
-- duck-typed: anything answering has_errors()/output() works.
function M.errors(plugins)
   local failed = {}
   for _, plugin in pairs(plugins) do
      local msgs = {}
      for _, t in ipairs(plugin._ and plugin._.tasks or {}) do
         if t:has_errors() then
            local out = vim.trim(t:output(vim.log.levels.ERROR) or '')
            if out ~= '' then table.insert(msgs, out) end
         end
      end
      if #msgs > 0 then
         table.insert(failed, { name = plugin.name, msg = table.concat(msgs, '\n') })
      end
   end
   table.sort(failed, function(a, b) return a.name < b.name end)
   return failed
end

local function plural(n, word)
   return n .. ' ' .. word .. (n == 1 and '' or 's')
end

-- Turns an update state into { text, highlight } pairs ready for virt_lines.
-- Phases: 'checking', 'updating', 'done', 'crashed'.
function M.lines(state)
   local out = {}

   if state.phase == 'checking' then
      table.insert(out, { 'Checking for plugin updates...', 'Comment' })
      return out
   end

   if state.phase == 'updating' then
      local pending = state.pending or {}
      table.insert(out, { 'Updating ' .. plural(#pending, 'plugin') .. '...', 'DiagnosticInfo' })
      for _, name in ipairs(pending) do
         table.insert(out, { '  - ' .. name, 'Comment' })
      end
      return out
   end

   if state.phase == 'crashed' then
      table.insert(out, { 'Plugin update CRASHED:', 'ErrorMsg' })
      for _, line in ipairs(vim.split(tostring(state.error), '\n', { plain = true })) do
         table.insert(out, { '  ' .. line, 'ErrorMsg' })
      end
      return out
   end

   local updated = state.updated or {}
   if #updated > 0 then
      table.insert(out, { 'Updated ' .. plural(#updated, 'plugin') .. ':', 'DiagnosticOk' })
      for _, u in ipairs(updated) do
         table.insert(out, { '  ' .. u.name .. '  ' .. u.from .. ' -> ' .. u.to, 'Comment' })
      end
   end

   local errors = state.errors or {}
   if #errors > 0 then
      table.insert(out, { 'Plugin update FAILED for ' .. plural(#errors, 'plugin') .. ':', 'ErrorMsg' })
      for _, e in ipairs(errors) do
         table.insert(out, { '  ' .. e.name .. ':', 'ErrorMsg' })
         for _, line in ipairs(vim.split(e.msg, '\n', { plain = true })) do
            table.insert(out, { '    ' .. line, 'ErrorMsg' })
         end
      end
   end

   return out
end

return M
