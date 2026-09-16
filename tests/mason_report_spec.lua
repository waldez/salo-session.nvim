package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local H = dofile('tests/harness.lua')
local R = require('salo-session.mason_report')

-- outdated()

H.test('outdated() is empty when nothing is installed', function()
   H.eq({}, R.outdated({}))
end)

H.test('outdated() skips packages already on the latest version', function()
   H.eq({}, R.outdated({ { name = 'gopls', installed = 'v0.17.0', latest = 'v0.17.0' } }))
end)

H.test('outdated() lists packages whose version differs, sorted by name', function()
   H.eq({
      { name = 'clangd', from = '18.1.3', to = '19.1.2' },
      { name = 'gopls', from = 'v0.16.1', to = 'v0.17.0' },
   }, R.outdated({
      { name = 'gopls', installed = 'v0.16.1', latest = 'v0.17.0' },
      { name = 'stylua', installed = 'v2.0.0', latest = 'v2.0.0' },
      { name = 'clangd', installed = '18.1.3', latest = '19.1.2' },
   }))
end)

H.test('outdated() skips packages whose versions cannot be compared', function()
   -- No receipt, or a registry entry too malformed to name a latest version.
   H.eq({}, R.outdated({
      { name = 'noreceipt', installed = nil, latest = 'v1.0.0' },
      { name = 'malformed', installed = 'v1.0.0', latest = nil },
   }))
end)

-- tail()

H.test('tail() of empty output is empty', function()
   H.eq('', R.tail('', 5))
   H.eq('', R.tail('  \n\n', 5))
end)

H.test('tail() keeps short output whole, without trailing blank lines', function()
   H.eq('npm ERR! code E404\nnpm ERR! 404 Not Found', R.tail('npm ERR! code E404\nnpm ERR! 404 Not Found\n\n', 5))
end)

H.test('tail() keeps the last lines and says how many were dropped', function()
   H.eq('... (3 earlier lines omitted)\nd\ne', R.tail('a\nb\nc\nd\ne\n', 2))
end)

-- failure_message()

H.test('failure_message() is the error alone when the installer printed nothing', function()
   H.eq('boom', R.failure_message('boom', '', 10))
end)

H.test('failure_message() does not repeat an error the output already carries', function()
   -- Mason writes its own error into the installer's stderr as well.
   H.eq('Downloading "x"...\nspawn: wget failed\nFailed to download "x".',
      R.failure_message('spawn: wget failed\nFailed to download "x".',
         'Downloading "x"...\nspawn: wget failed\nFailed to download "x".\n', 10))
end)

H.test('failure_message() puts the error first when the output does not contain it', function()
   H.eq('install aborted\nnpm ERR! code EACCES',
      R.failure_message('install aborted', 'npm ERR! code EACCES\n', 10))
end)

H.test('failure_message() keeps the error when truncation dropped it from the output', function()
   H.eq('boom\n... (2 earlier lines omitted)\nb\nc',
      R.failure_message('boom', 'boom\na\nb\nc\n', 2))
end)

H.test('failure_message() never comes back empty', function()
   H.eq('x', R.failure_message(nil, 'x', 10))
   H.eq('(Mason gave no error details)', R.failure_message(nil, '', 10))
end)

-- lines()

H.test('lines() is empty when there is no Mason state yet', function()
   H.eq({}, R.lines({}))
end)

H.test('lines() while checking', function()
   H.eq({ { 'Checking Mason packages...', 'Comment' } }, R.lines({ phase = 'checking' }))
end)

H.test('lines() says nothing when every package is up to date', function()
   H.eq({}, R.lines({ phase = 'outdated', outdated = {} }))
end)

H.test('lines() lists outdated packages with the key that updates them', function()
   H.eq({
      { 'Mason: 2 packages outdated, press M to update:', 'DiagnosticInfo' },
      { '  clangd  18.1.3 -> 19.1.2', 'Comment' },
      { '  gopls  v0.16.1 -> v0.17.0', 'Comment' },
   }, R.lines({ phase = 'outdated', outdated = {
      { name = 'clangd', from = '18.1.3', to = '19.1.2' },
      { name = 'gopls', from = 'v0.16.1', to = 'v0.17.0' },
   } }))
end)

H.test('lines() uses the singular for one package', function()
   H.eq('Mason: 1 package outdated, press M to update:',
      R.lines({ phase = 'outdated', outdated = { { name = 'x', from = '1', to = '2' } } })[1][1])
end)

H.test('lines() while updating', function()
   H.eq({
      { 'Updating 2 Mason packages...', 'DiagnosticInfo' },
      { '  - clangd', 'Comment' },
      { '  - gopls', 'Comment' },
   }, R.lines({ phase = 'updating', pending = { 'clangd', 'gopls' } }))
end)

H.test('lines() summarises a clean update', function()
   H.eq({
      { 'Updated 1 Mason package:', 'DiagnosticOk' },
      { '  gopls  v0.16.1 -> v0.17.0', 'Comment' },
   }, R.lines({ phase = 'done', updated = { { name = 'gopls', from = 'v0.16.1', to = 'v0.17.0' } } }))
end)

H.test('lines() reports failures verbosely, every output line included', function()
   H.eq({
      { 'Mason update FAILED for 1 package:', 'ErrorMsg' },
      { '  css-lsp:', 'ErrorMsg' },
      { '    spawn: npm failed with exit code 1', 'ErrorMsg' },
      { '    npm ERR! code EACCES', 'ErrorMsg' },
   }, R.lines({ phase = 'done', updated = {}, errors = {
      { name = 'css-lsp', msg = 'spawn: npm failed with exit code 1\nnpm ERR! code EACCES' },
   } }))
end)

H.test('lines() lists packages skipped because something else is installing them', function()
   H.eq({
      { 'Skipped 1 Mason package, already being installed:', 'Comment' },
      { '  - clangd', 'Comment' },
   }, R.lines({ phase = 'done', updated = {}, errors = {}, skipped = { 'clangd' } }))
end)

H.test('lines() shows updated, skipped and failed together, in that order', function()
   local out = R.lines({ phase = 'done',
      updated = { { name = 'gopls', from = '1', to = '2' } },
      skipped = { 'clangd' },
      errors = { { name = 'css-lsp', msg = 'boom' } },
   })
   H.eq('Updated 1 Mason package:', out[1][1])
   H.eq('Skipped 1 Mason package, already being installed:', out[3][1])
   H.eq('Mason update FAILED for 1 package:', out[5][1])
end)

H.test('lines() reports a crash with every line of the error', function()
   H.eq({
      { 'Mason CRASHED:', 'ErrorMsg' },
      { '  init.lua:1: refreshing the registry failed', 'ErrorMsg' },
      { '  stack', 'ErrorMsg' },
   }, R.lines({ phase = 'crashed', error = 'init.lua:1: refreshing the registry failed\nstack' }))
end)

H.done()
