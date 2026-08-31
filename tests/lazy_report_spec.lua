package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local H = dofile('tests/harness.lua')
local R = require('salo-session.lazy_report')

H.test('pending() returns nothing when no plugin has updates', function()
   H.eq({}, R.pending({ foo = { name = 'foo', _ = {} } }))
end)

H.test('pending() returns names of plugins with updates, sorted', function()
   local plugins = {
      zebra = { name = 'zebra', _ = { updates = { from = 'a', to = 'b' } } },
      alpha = { name = 'alpha', _ = { updates = { from = 'c', to = 'd' } } },
      quiet = { name = 'quiet', _ = {} },
   }
   H.eq({ 'alpha', 'zebra' }, R.pending(plugins))
end)

H.test('pending() skips local dev plugins, which must never be auto-updated', function()
   local plugins = {
      mine = { name = 'mine', _ = { is_local = true, updates = { from = 'a', to = 'b' } } },
      other = { name = 'other', _ = { updates = { from = 'c', to = 'd' } } },
   }
   H.eq({ 'other' }, R.pending(plugins))
end)

H.test('pending() skips pinned plugins', function()
   local plugins = {
      frozen = { name = 'frozen', pin = true, _ = { updates = { from = 'a', to = 'b' } } },
      other = { name = 'other', _ = { updates = { from = 'c', to = 'd' } } },
   }
   H.eq({ 'other' }, R.pending(plugins))
end)

H.test('updated() ignores plugins whose commit did not move', function()
   local plugins = {
      still = { name = 'still', _ = { updated = { from = 'aaaaaaaaaaaa', to = 'aaaaaaaaaaaa' } } },
   }
   H.eq({}, R.updated(plugins))
end)

H.test('updated() reports moved plugins with short shas, sorted by name', function()
   local plugins = {
      zebra = { name = 'zebra', _ = { updated = { from = 'deadbeefcafe', to = 'feedface1234' } } },
      alpha = { name = 'alpha', _ = { updated = { from = '0123456789ab', to = 'abcdef012345' } } },
      absent = { name = 'absent', _ = {} },
   }
   H.eq({
      { name = 'alpha', from = '0123456', to = 'abcdef0' },
      { name = 'zebra', from = 'deadbee', to = 'feedfac' },
   }, R.updated(plugins))
end)

local function task(name, failed, out)
   return {
      name = name,
      has_errors = function() return failed end,
      output = function() return out end,
   }
end

H.test('errors() returns nothing when every task succeeded', function()
   local plugins = {
      foo = { name = 'foo', _ = { tasks = { task('fetch', false, '') } } },
   }
   H.eq({}, R.errors(plugins))
end)

H.test('errors() collects failing task output per plugin, sorted by name', function()
   local plugins = {
      zebra = { name = 'zebra', _ = { tasks = { task('fetch', true, 'fatal: could not read') } } },
      alpha = { name = 'alpha', _ = { tasks = {
         task('fetch', false, 'fine'),
         task('checkout', true, 'error: local changes'),
      } } },
      quiet = { name = 'quiet', _ = { tasks = {} } },
   }
   H.eq({
      { name = 'alpha', msg = 'error: local changes' },
      { name = 'zebra', msg = 'fatal: could not read' },
   }, R.errors(plugins))
end)

H.test('errors() joins multiple failing tasks for one plugin', function()
   local plugins = {
      foo = { name = 'foo', _ = { tasks = {
         task('fetch', true, 'first failure'),
         task('build', true, 'second failure'),
      } } },
   }
   H.eq({ { name = 'foo', msg = 'first failure\nsecond failure' } }, R.errors(plugins))
end)

H.test('errors() skips failing tasks that produced no output', function()
   local plugins = {
      foo = { name = 'foo', _ = { tasks = { task('fetch', true, '   ') } } },
   }
   H.eq({}, R.errors(plugins))
end)

H.test('lines() shows a checking notice', function()
   H.eq({ { 'Checking for plugin updates...', 'Comment' } }, R.lines({ phase = 'checking' }))
end)

H.test('lines() lists what it is about to update', function()
   H.eq({
      { 'Updating 2 plugins...', 'DiagnosticInfo' },
      { '  - alpha', 'Comment' },
      { '  - zebra', 'Comment' },
   }, R.lines({ phase = 'updating', pending = { 'alpha', 'zebra' } }))
end)

H.test('lines() renders nothing when an update changed nothing', function()
   H.eq({}, R.lines({ phase = 'done', updated = {}, errors = {} }))
end)

H.test('lines() summarises what moved', function()
   H.eq({
      { 'Updated 2 plugins:', 'DiagnosticOk' },
      { '  alpha  0123456 -> abcdef0', 'Comment' },
      { '  zebra  deadbee -> feedfac', 'Comment' },
   }, R.lines({ phase = 'done', errors = {}, updated = {
      { name = 'alpha', from = '0123456', to = 'abcdef0' },
      { name = 'zebra', from = 'deadbee', to = 'feedfac' },
   } }))
end)

H.test('lines() renders every line of every error, loudly', function()
   H.eq({
      { 'Plugin update FAILED for 1 plugin:', 'ErrorMsg' },
      { '  alpha:', 'ErrorMsg' },
      { '    error: local changes', 'ErrorMsg' },
      { '    would be overwritten', 'ErrorMsg' },
   }, R.lines({ phase = 'done', updated = {}, errors = {
      { name = 'alpha', msg = 'error: local changes\nwould be overwritten' },
   } }))
end)

H.test('lines() shows both the summary and the errors when some plugins failed', function()
   H.eq({
      { 'Updated 1 plugin:', 'DiagnosticOk' },
      { '  alpha  0123456 -> abcdef0', 'Comment' },
      { 'Plugin update FAILED for 1 plugin:', 'ErrorMsg' },
      { '  zebra:', 'ErrorMsg' },
      { '    fatal: could not read', 'ErrorMsg' },
   }, R.lines({
      phase = 'done',
      updated = { { name = 'alpha', from = '0123456', to = 'abcdef0' } },
      errors = { { name = 'zebra', msg = 'fatal: could not read' } },
   }))
end)

H.test('lines() reports a crash in the update machinery itself', function()
   H.eq({
      { 'Plugin update CRASHED:', 'ErrorMsg' },
      { '  attempt to index a nil value', 'ErrorMsg' },
   }, R.lines({ phase = 'crashed', error = 'attempt to index a nil value' }))
end)

H.done()
