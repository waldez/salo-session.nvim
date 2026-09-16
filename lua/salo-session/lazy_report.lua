-- Pure helpers over lazy.nvim state: what to update, how to fetch without
-- racing lazy's own checker, and how to report the outcome as renderable lines.
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

-- One notification for every failure of a run, or nil when nothing failed. A
-- notification per failure is a hit-enter prompt per failure, and a start
-- without network fails for every plugin at once. Shared with the Mason report.
function M.error_summary(what, noun, errors)
   if #errors == 0 then return nil end
   local parts = { ('salo-session: %s failed for %s'):format(what, plural(#errors, noun)) }
   for _, e in ipairs(errors) do
      table.insert(parts, '\n' .. e.name .. ':\n' .. e.msg)
   end
   return table.concat(parts, '\n')
end

-- Turns an update state into { text, highlight } pairs ready for virt_lines.
-- Phases: 'checking', 'updating', 'done', 'crashed'. A 'done' state with
-- stage = 'check' reports errors from the network check rather than an update.
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
      -- The same task errors come from either stage; say which one failed.
      local what = state.stage == 'check' and 'Checking for plugin updates' or 'Plugin update'
      table.insert(out, { what .. ' FAILED for ' .. plural(#errors, 'plugin') .. ':', 'ErrorMsg' })
      for _, e in ipairs(errors) do
         table.insert(out, { '  ' .. e.name .. ':', 'ErrorMsg' })
         for _, line in ipairs(vim.split(e.msg, '\n', { plain = true })) do
            table.insert(out, { '    ' .. line, 'ErrorMsg' })
         end
      end
   end

   return out
end

-- How to discover updates without racing lazy.nvim's own checker. Two git
-- fetches in one repository race on the ref lock ("cannot lock ref ... is at X
-- but expected Y"), so we must never fetch while the checker is fetching.
--
--   'claim'    the checker's fetch is due right now; do it ourselves and record
--              it as the checker's, so the checker stands down instead of
--              fetching alongside us
--   'offline'  the checker fetched recently and will not fetch now; act on the
--              refs it already fetched
--   'own'      nothing else is fetching; go ask the remotes ourselves
--
-- Claiming beats waiting for the checker: its progress can stall behind its
-- own "Plugin Updates" hit-enter prompt, and anything that stopped waiting
-- before that prompt was dismissed would race it all over again.
--
-- Options: enabled, last_check, frequency, now, has_errors, force.
function M.plan(o)
   -- The checker skips its fetch entirely while any plugin has errors, so there
   -- is nothing to claim.
   if o.force or not o.enabled or o.has_errors then return 'own' end

   -- Mirrors lazy's own scheduling: it defers the check by
   -- last_check + frequency - now seconds, clamped to zero.
   if (o.last_check or 0) + o.frequency - o.now <= 0 then return 'claim' end

   return 'offline'
end

return M
