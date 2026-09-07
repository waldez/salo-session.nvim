package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local H = require('tests.harness')
local L = require('salo-session.layout')

local LONG = '/home/waldez/work/salo-session.nvim/.vim/session.vim'

H.test('fit: a path that already fits is untouched', function()
   H.eq(LONG, L.fit(LONG, 80))
end)

H.test('fit: a path exactly as wide as the window is untouched', function()
   H.eq(LONG, L.fit(LONG, #LONG))
end)

H.test('fit: an over-long path is shortened from the left', function()
   local got = L.fit(LONG, 40)
   H.eq(true, #got <= 40)
   H.eq('...', got:sub(1, 3))
   -- the interesting end of the path survives
   H.eq(true, got:sub(-#'/.vim/session.vim') == '/.vim/session.vim')
end)

H.test('fit: shortening starts at a path separator, not mid-component', function()
   H.eq('.../salo-session.nvim/.vim/session.vim', L.fit(LONG, 40))
end)

H.test('fit: never returns more than the width allows', function()
   for w = 1, #LONG + 5 do
      H.eq(true, #L.fit(LONG, w) <= w)
   end
end)

H.test('fit: a window too narrow even for the ellipsis keeps the tail', function()
   H.eq('.vim', L.fit(LONG, 4))
   H.eq('m', L.fit(LONG, 1))
end)

H.test('fit: a non-positive width yields nothing', function()
   H.eq('', L.fit(LONG, 0))
   H.eq('', L.fit(LONG, -10))
end)

H.test('center_col: centres a block', function()
   H.eq(35, L.center_col(80, 10))
end)

H.test('center_col: never goes negative when the block is wider', function()
   H.eq(0, L.center_col(20, 100))
end)

H.test('center_col: exact fit sits at column zero', function()
   H.eq(0, L.center_col(80, 80))
end)

H.done()
