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


-- splash_target: which window the welcome screen may take over.

local function win(id, name, buftype, isdir)
   return { win = id, name = name, buftype = buftype, isdir = isdir or false }
end

local LAZY = function(id) return win(id, '', 'nofile') end
local STARTUP = function(id) return win(id, '', '') end

H.test('splash_target: the buffer nvim starts with', function()
   H.eq(1000, S.splash_target({ STARTUP(1000) }))
end)

H.test('splash_target: skips a plugin popup and finds the startup buffer', function()
   -- The regression: lazy.nvim's install popup is unnamed too, and used to be
   -- mistaken for the startup buffer when it was focused at VimEnter.
   H.eq(1001, S.splash_target({ LAZY(1000), STARTUP(1001) }))
end)

H.test('splash_target: a plugin popup alone is never taken over', function()
   H.eq(nil, S.splash_target({ LAZY(1000) }))
end)

H.test('splash_target: a real file is never taken over', function()
   H.eq(nil, S.splash_target({ win(1000, '/home/waldez/x/init.lua', '') }))
end)

H.test('splash_target: a real file alongside a popup stays untouched', function()
   H.eq(nil, S.splash_target({ LAZY(1000), win(1001, '/home/waldez/x/init.lua', '') }))
end)

H.test('splash_target: a directory buffer is taken over', function()
   -- `nvim .` opens netrw, which has a name and buftype=nofile.
   H.eq(1000, S.splash_target({ win(1000, '/home/waldez/work', 'nofile', true) }))
end)

H.test('splash_target: the splash itself is not taken over again', function()
   H.eq(nil, S.splash_target({ win(1000, '/home/waldez/work/minintro', 'nofile') }))
end)

H.test('splash_target: nothing at all', function()
   H.eq(nil, S.splash_target({}))
end)

H.done()
