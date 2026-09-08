local M = {}

local Layout = require('salo-session.layout')
local Report = require('salo-session.lazy_report')
local SessionState = require('salo-session.session_state')

local function minintro()
   local intro_logo = {
      [[            _             ]],
      [[  __      _(_)_ __ ___    ]],
      [[  \ \ /\ / / | '_ ` _ \   ]],
      [[   \ V  V /| | | | | | |  ]],
      [[    \_/\_/ |_|_| |_| |_|  ]],
      [[                          ]],
      [[   Neovim configuration   ]],
      [[  tailored by&for waldez  ]],
      [[                          ]],
      [[   --==]}  fuck  {[==--   ]],
   }

   local PLUGIN_NAME = 'minintro'
   local DEFAULT_COLOR = '#85aed4'
   local INTRO_LOGO_HEIGHT = #intro_logo
   local INTRO_LOGO_WIDTH = 26

   local autocmd_group = vim.api.nvim_create_augroup(PLUGIN_NAME, {})
   local highlight_ns_id = vim.api.nvim_create_namespace(PLUGIN_NAME)
   local minintro_buff = -1

   local function unlock_buf(buf)
      vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
   end

   local function lock_buf(buf)
      vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
   end

   local function draw_minintro(buf, logo_width, logo_height)
      local window = vim.fn.bufwinid(buf)
      local screen_width = vim.api.nvim_win_get_width(window)
      local screen_height = vim.api.nvim_win_get_height(window) - vim.opt.cmdheight:get()

      local start_col = math.floor((screen_width - logo_width) / 2)
      local start_row = math.floor((screen_height - logo_height) / 2)
      if (start_col < 0 or start_row < 0) then return end

      local top_space = {}
      for _ = 1, start_row do table.insert(top_space, '') end

      local col_offset_spaces = {}
      for _ = 1, start_col do table.insert(col_offset_spaces, ' ') end
      local col_offset = table.concat(col_offset_spaces, '')

      local adjusted_logo = {}
      for _, line in ipairs(intro_logo) do
         table.insert(adjusted_logo, col_offset .. line)
      end

      unlock_buf(buf)
      vim.api.nvim_buf_set_lines(buf, 1, 1, true, top_space)
      vim.api.nvim_buf_set_lines(buf, start_row, start_row, true, adjusted_logo)
      lock_buf(buf)

      vim.api.nvim_buf_set_extmark(buf, highlight_ns_id, start_row, start_col, {
         end_row = start_row + INTRO_LOGO_HEIGHT,
         hl_group = 'Default'
      })
   end

   local function create_and_set_minintro_buf(win, default_buff)
      local intro_buff = vim.api.nvim_create_buf('nobuflisted', 'unlisted')
      vim.api.nvim_buf_set_name(intro_buff, PLUGIN_NAME)
      vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = intro_buff })
      vim.api.nvim_set_option_value('buftype', 'nofile', { buf = intro_buff })
      vim.api.nvim_set_option_value('filetype', 'minintro', { buf = intro_buff })
      vim.api.nvim_set_option_value('swapfile', false, { buf = intro_buff })

      -- Place the splash in its own window rather than whichever one happens to
      -- be focused, so a plugin popup open at VimEnter keeps its window.
      vim.api.nvim_win_set_buf(win, intro_buff)

      -- Switching away can wipe the outgoing buffer by itself, so only delete
      -- what is still there.
      if default_buff ~= intro_buff and vim.api.nvim_buf_is_valid(default_buff) then
         vim.api.nvim_buf_delete(default_buff, { force = true })
      end

      return intro_buff
   end

   local function set_options()
      vim.opt_local.number = false         -- disable line numbers
      vim.opt_local.relativenumber = false -- disable relative line numbers
      vim.opt_local.list = false           -- disable displaying whitespace
      vim.opt_local.fillchars = { eob = ' ' } -- do not display '~' on each new line
      vim.opt_local.colorcolumn = '0'      -- disable colorcolumn
   end

   local function redraw()
      unlock_buf(minintro_buff)
      vim.api.nvim_buf_set_lines(minintro_buff, 0, -1, true, {})
      lock_buf(minintro_buff)
      draw_minintro(minintro_buff, INTRO_LOGO_WIDTH, INTRO_LOGO_HEIGHT)
   end

   -- Describe every window in the shape session_state.splash_target expects.
   local function window_summary()
      local windows = {}
      for _, win in ipairs(vim.api.nvim_list_wins()) do
         local buf = vim.api.nvim_win_get_buf(win)
         local name = vim.api.nvim_buf_get_name(buf)
         table.insert(windows, {
            win = win,
            buf = buf,
            name = name,
            buftype = vim.api.nvim_get_option_value('buftype', { buf = buf }),
            isdir = name ~= '' and vim.fn.isdirectory(name) == 1,
         })
      end
      return windows
   end

   local function display_minintro()
      local windows = window_summary()
      local win = SessionState.splash_target(windows)
      if not win then return end

      local default_buff
      for _, w in ipairs(windows) do
         if w.win == win then default_buff = w.buf end
      end

      minintro_buff = create_and_set_minintro_buf(win, default_buff)

      -- set_options uses window-local options, so run it in the splash's own
      -- window, which is not necessarily the focused one.
      vim.api.nvim_win_call(win, set_options)

      draw_minintro(minintro_buff, INTRO_LOGO_WIDTH, INTRO_LOGO_HEIGHT)

      vim.api.nvim_create_autocmd({ 'WinResized', 'VimResized' }, {
         group = autocmd_group,
         buffer = minintro_buff,
         callback = redraw
      })
   end
   local function setup(options)
      options = options or {}
      vim.api.nvim_set_hl(highlight_ns_id, 'Default', { fg = options.color or DEFAULT_COLOR })
      vim.api.nvim_set_hl_ns(highlight_ns_id)

      vim.api.nvim_create_autocmd('VimEnter', {
         group = autocmd_group,
         callback = display_minintro,
         once = true
      })
   end

   return {
      buff = function() return minintro_buff; end,
      unlock_buf = function () unlock_buf(minintro_buff); end,
      lock_buf = function () lock_buf(minintro_buff); end,
      setup = setup
   }
end

function M.setup(opts)
   opts = opts or {}

   -- TODO! make it, so it works same way that in vanilla nvim
   -- meaning: after you start typing, the splassh will go away!
   -- TODO: #2 make autocmds for sessions like in the stolen minintro!
   M.intro = minintro()
   M.intro.setup()

   -- Auto commands 
   vim.cmd([[
       " Save session on quit
       autocmd VimLeavePre * lua require('salo-session').save_session()
       " Load session on start
       autocmd VimEnter * lua require('salo-session').load_session()
   ]])
end


-- Everything mksession would care about, in the shape session_state expects.
local function buffer_summary()
   local buffers = {}
   for _, b in ipairs(vim.api.nvim_list_bufs()) do
      table.insert(buffers, {
         name = vim.api.nvim_buf_get_name(b),
         listed = vim.fn.buflisted(b) == 1,
         buftype = vim.api.nvim_get_option_value('buftype', { buf = b }),
      })
   end
   return buffers
end

-- Function to save the session
function M.save_session()
   local dir = vim.fn.getcwd()
   if dir then
      local session_file = dir .. '/.vim/session.vim'

      -- Writing a session with nothing in it is worse than writing none: the
      -- next start offers to restore it and restoring it does nothing.
      if not SessionState.worth_saving(buffer_summary()) then return end

      -- Save the current sessionoptions value
      local current_sessionoptions = vim.o.sessionoptions
      -- Set sessionoptions to save buffers and tab pages
      vim.o.sessionoptions = 'buffers,tabpages'
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

      -- Plugin updates are independent of whether a session was found, and
      -- must not be skipped by the early returns in the session block below.
      if vim.fn.argc() == 0 then
         M.auto_update()
      end

      -- Check if Neovim was started with file arguments
      if vim.fn.argc() == 0 and vim.fn.filereadable(session_file) == 1 then

         -- There may be no splash to draw on: display_minintro bails out when
         -- nvim started on a real file, or when nothing but plugin windows are
         -- open. Nothing to prompt on, so say nothing.
         local buf = M.intro.buff()
         if not buf or buf < 0 or not vim.api.nvim_buf_is_valid(buf) then return end

         local window = vim.fn.bufwinid(buf)
         if window == -1 then return end

         local screen_width = vim.api.nvim_win_get_width(window)
         local screen_height = vim.api.nvim_win_get_height(window) - vim.opt.cmdheight:get()

         local label = 'Session found, press <Enter> to restore:'

         -- Shorten rather than give up. Bailing out here used to leave a
         -- restorable session with no prompt and no explanation whenever the
         -- path was wider than the window.
         local shown_path = Layout.fit(session_file, screen_width)

         -- Centre the two lines as a block, so they stay aligned with each
         -- other even when one of them is what decides the width.
         local start_col = Layout.center_col(screen_width, math.max(#label, #shown_path))
         local start_row = math.max(0, math.floor(screen_height / 2))
         local col_offset = string.rep(' ', start_col)

         local virtualLines = {}
         table.insert(virtualLines, { { col_offset .. label, 'Title' } })
         table.insert(virtualLines, { { col_offset .. shown_path, 'Title' } })

         local prompt_ns = vim.api.nvim_create_namespace('minintro')
         local PROMPT_EXTMARK_ID = prompt_ns

         local opts = {
            id = PROMPT_EXTMARK_ID,
            hl_mode = 'combine',
            priority = 100,
            virt_lines = virtualLines,
         }

         -- Clamp so a short splash buffer (narrow or shallow window) cannot
         -- push the anchor past the last line.
         local anchor = math.min(start_row + 5, vim.api.nvim_buf_line_count(buf) - 1)
         if anchor < 0 then return end

         vim.api.nvim_buf_set_extmark(buf, prompt_ns, anchor, 0, opts)

         M.intro.unlock_buf()

         -- Take the prompt down for good. A session that restores no windows
         -- leaves us sitting on the splash with the prompt still up, and a
         -- second <Enter> would then source a file the first one deleted.
         local function retire_prompt()
            local buf = M.intro.buff()
            if not buf or buf < 0 or not vim.api.nvim_buf_is_valid(buf) then return end
            pcall(vim.api.nvim_buf_del_keymap, buf, 'n', '<enter>')
            pcall(vim.api.nvim_buf_del_extmark, buf, prompt_ns, PROMPT_EXTMARK_ID)
         end

         vim.api.nvim_buf_set_keymap(M.intro.buff(),
            'n', '<enter>', 'irrelevant',
            { noremap = true, silent = true, callback = function ()
               retire_prompt()

               if vim.fn.filereadable(session_file) ~= 1 then
                  vim.notify('salo-session: session file vanished before it could be restored\n'
                     .. session_file, vim.log.levels.ERROR)
                  return
               end

               local ok, err = pcall(vim.cmd, 'source ' .. vim.fn.fnameescape(session_file))
               if not ok then
                  vim.notify('salo-session: restoring the session failed\n' .. session_file
                     .. '\n' .. tostring(err), vim.log.levels.ERROR)
                  return
               end

               -- Delete the session file after loading it. vim.fn.delete keeps
               -- this off the shell, which mangled paths containing spaces.
               vim.fn.delete(session_file)
            end });
         M.intro.lock_buf()
      end
   end
end


local update_ns = vim.api.nvim_create_namespace('salo-session-lazy-update')
local UPDATE_EXTMARK_ID = 1

-- Draw the current update state on the splash, replacing whatever was there
-- before. Safe to call once per phase; a no-op once the splash is gone.
local function render(state)
   local buf = M.intro.buff()
   if not buf or buf < 0 or not vim.api.nvim_buf_is_valid(buf) then return end

   local lines = Report.lines(state)
   if #lines == 0 then
      pcall(vim.api.nvim_buf_del_extmark, buf, update_ns, UPDATE_EXTMARK_ID)
      return
   end

   local window = vim.fn.bufwinid(buf)
   if window == -1 then return end
   local screen_width = vim.api.nvim_win_get_width(window)

   -- Centre the block as a whole on its widest line, so the relative
   -- indentation of the summary and error lines is preserved.
   local widest = 0
   for _, line in ipairs(lines) do widest = math.max(widest, #line[1]) end
   local start_col = math.max(0, math.floor((screen_width - widest) / 2))
   local col_offset = string.rep(' ', start_col)

   local virt_lines = { { { '' } } }
   for _, line in ipairs(lines) do
      table.insert(virt_lines, { { col_offset .. line[1], line[2] } })
   end

   -- Anchor below the session prompt; clamp so we never point past the buffer.
   local anchor = math.min(math.floor(vim.api.nvim_win_get_height(window) / 2) + 7,
      vim.api.nvim_buf_line_count(buf) - 1)
   if anchor < 0 then return end

   pcall(vim.api.nvim_buf_set_extmark, buf, update_ns, anchor, 0, {
      id = UPDATE_EXTMARK_ID,
      hl_mode = 'combine',
      priority = 99,
      virt_lines = virt_lines,
   })
end

-- Report a failure both on the splash and through :messages, verbosely.
local function report_crash(err)
   local msg = tostring(err)
   render({ phase = 'crashed', error = msg })
   vim.notify('salo-session: plugin update failed\n' .. msg, vim.log.levels.ERROR)
end

-- Run the update itself, then summarise what moved and what broke.
local function run_update(pending)
   render({ phase = 'updating', pending = pending })

   local ok, err = pcall(function()
      require('lazy.manage').update({ plugins = pending, show = false }):wait(function()
         local done_ok, done_err = pcall(function()
            local plugins = require('lazy.core.config').plugins
            local errors = Report.errors(plugins)
            render({ phase = 'done', updated = Report.updated(plugins), errors = errors })
            for _, e in ipairs(errors) do
               vim.notify('salo-session: updating ' .. e.name .. ' failed\n' .. e.msg,
                  vim.log.levels.ERROR)
            end
         end)
         if not done_ok then report_crash(done_err) end
      end)
   end)
   if not ok then report_crash(err) end
end

-- Automatically bring lazy.nvim plugins up to date, without ever opening the
-- Lazy popup, and show the outcome on the welcome screen.
function M.auto_update()
   local ok, err = pcall(function()
      local buf = M.intro.buff()
      if buf and buf >= 0 and vim.api.nvim_buf_is_valid(buf) then
         -- Manual re-run, useful when the automatic pass reported an error.
         vim.api.nvim_buf_set_keymap(buf, 'n', 'u', '', {
            noremap = true, silent = true, callback = function() M.auto_update() end,
         })
      end

      local checker = require('lazy.manage.checker')
      local config = require('lazy.core.config')

      -- Cheap, offline pass over already-fetched refs. This is the same state
      -- that produces lazy's "you have updates" message at startup.
      checker.fast_check({ report = false })
      local pending = Report.pending(config.plugins)
      if #pending > 0 then
         return run_update(pending)
      end

      -- Nothing known to be pending, so go ask the remotes.
      render({ phase = 'checking' })
      require('lazy.manage').check({ show = false }):wait(function()
         local check_ok, check_err = pcall(function()
            local found = Report.pending(config.plugins)
            if #found == 0 then
               return render({ phase = 'done', updated = {}, errors = {} })
            end
            run_update(found)
         end)
         if not check_ok then report_crash(check_err) end
      end)
   end)
   if not ok then report_crash(err) end
end

return M
