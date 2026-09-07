package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local H = require('tests.harness')
local S = require('salo-session.session_state')

local function buf(name, opts)
   opts = opts or {}
   return {
      name = name,
      listed = opts.listed ~= false,
      buftype = opts.buftype or '',
   }
end

H.test('worth_saving: no buffers at all', function()
   H.eq(false, S.worth_saving({}))
end)

H.test('worth_saving: only the splash buffer', function()
   -- Quitting straight from the welcome screen. This is the case that used to
   -- write a session restoring nothing.
   H.eq(false, S.worth_saving({ buf('minintro', { buftype = 'nofile', listed = false }) }))
end)

H.test('worth_saving: only an unnamed scratch buffer', function()
   H.eq(false, S.worth_saving({ buf('') }))
end)

H.test('worth_saving: only a terminal', function()
   H.eq(false, S.worth_saving({ buf('term://zsh', { buftype = 'terminal' }) }))
end)

H.test('worth_saving: only an unlisted help buffer', function()
   H.eq(false, S.worth_saving({ buf('/usr/share/nvim/doc/help.txt', { buftype = 'help', listed = false }) }))
end)

H.test('worth_saving: a real file', function()
   H.eq(true, S.worth_saving({ buf('/home/waldez/work/x/init.lua') }))
end)

H.test('worth_saving: a real file alongside the splash', function()
   H.eq(true, S.worth_saving({
      buf('minintro', { buftype = 'nofile', listed = false }),
      buf('/home/waldez/work/x/init.lua'),
   }))
end)

H.done()
