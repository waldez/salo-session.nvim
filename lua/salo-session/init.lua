local M = {}

function M.setup(opts)
   opts = opts or {}
   -- Auto commands 
   vim.cmd([[
       " Save session on quit
       autocmd VimLeavePre * lua require('salo-session').save_session()
       " Load session on start
       autocmd VimEnter * lua require('salo-session').load_session()
   ]])
end

-- Function to save the session
function M.save_session()
   local dir = vim.fn.getcwd()
   if dir then
      local session_file = dir .. '/.vim/session.vim'
      -- Save the current sessionoptions value
      local current_sessionoptions = vim.o.sessionoptions
      -- Set sessionoptions to save buffers and tab pages
      vim.o.sessionoptions = "buffers,tabpages"
      vim.cmd('mksession! ' .. session_file)
      -- Restore sessionoptions to its previous value
      vim.o.sessionoptions = current_sessionoptions
   end
end

-- Function to load the session
function M.load_session()
   local dir = vim.fn.getcwd()
   if dir then
      local session_file = dir .. '/.vim/session.vim'
      -- Check if Neovim was started with file arguments
      if vim.fn.argc() == 0 and vim.fn.filereadable(session_file) == 1 then

         -- Ask the user if they want to load the session
         local answer = vim.fn.input("Session found. Do you want to load it? (Y/n): ")
         if answer:lower() == 'y' then
            -- Delay the sourcing of the session file by 100ms
            vim.defer_fn(function()
               vim.cmd('source ' .. session_file)
               -- Delete the session file after loading it
               vim.cmd('silent! !rm ' .. session_file)
            end, 100)
         end
      end
   end
end

return M
