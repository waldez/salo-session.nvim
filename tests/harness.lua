-- Minimal assertion harness. Run a spec with:  nvim -l tests/<name>_spec.lua
local H = { failures = 0, total = 0 }

function H.test(name, fn)
   H.total = H.total + 1
   local ok, err = pcall(fn)
   if ok then
      io.write('  ok   ' .. name .. '\n')
   else
      H.failures = H.failures + 1
      io.write('  FAIL ' .. name .. '\n       ' .. tostring(err) .. '\n')
   end
end

function H.eq(expected, actual)
   if not vim.deep_equal(expected, actual) then
      error('expected ' .. vim.inspect(expected) .. '\n       got      ' .. vim.inspect(actual), 2)
   end
end

function H.done()
   io.write(string.format('\n%d test(s), %d failure(s)\n', H.total, H.failures))
   os.exit(H.failures == 0 and 0 or 1)
end

return H
