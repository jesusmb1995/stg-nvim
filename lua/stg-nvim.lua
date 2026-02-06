local M = {}

-- Default configuration
local config = {
  stg_path = nil, -- Will auto-detect if not set
}

-- Helper function to find stg command
local function get_stg_command()
  -- If user specified a path, use it
  if config.stg_path then
    local check_result = vim.fn.system("which " .. vim.fn.shellescape(config.stg_path) .. " 2>/dev/null")
    if vim.v.shell_error == 0 then
      return config.stg_path
    else
      vim.notify("Configured stg path not found: " .. config.stg_path, vim.log.levels.ERROR)
      return nil
    end
  end

  -- Auto-detect stg in common locations
  local stg_paths = {
    "/home/linuxbrew/.linuxbrew/bin/stg",
    "stg",
    "/usr/local/bin/stg",
    "/usr/bin/stg"
  }

  for _, path in ipairs(stg_paths) do
    local check_result = vim.fn.system("which " .. vim.fn.shellescape(path) .. " 2>/dev/null")
    if vim.v.shell_error == 0 then
      return path
    end
  end

  return nil
end

-- Helper function to get current branch name
local function get_current_branch()
  local result = vim.fn.system("git branch --show-current")
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    vim.notify("Failed to get current branch name", vim.log.levels.ERROR)
    return nil
  end

  return result:gsub("%s+$", "") -- Remove trailing whitespace
end

-- Helper function to generate suggested branch name
local function generate_branch_name(base_name)
  -- Check if base_name already ends with a number
  local name, number = base_name:match("(.*[a-zA-Z_%-])(%d+)")
  
  if name and number then
    -- Base name ends with a number, increment it
    local next_number = tonumber(number) + 1
    return name .. tostring(next_number)
  else
    -- Base name doesn't end with a number, add 2
    return base_name .. "2"
  end
end

-- Helper function to get stg series patches with status
local function get_stg_patches_with_status()
  local stg_cmd = get_stg_command()
  if not stg_cmd then
    vim.notify("stg command not found in any of the expected locations", vim.log.levels.ERROR)
    return {}
  end

  local cmd = stg_cmd .. " series"
  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    local error_msg = string.format("Failed to get stg series patches (exit code: %d)", exit_code)
    if result and result ~= "" then
      error_msg = error_msg .. string.format("\nCommand output: %s", result)
    end
    vim.notify(error_msg, vim.log.levels.ERROR)

    return {}
  end

  local patches = {}
  for line in result:gmatch("[^\r\n]+") do
    -- Extract status indicator and patch name
    local status, patch_name = line:match("^%s*([+>-]?)%s*([^%s]+)")
    if patch_name and patch_name ~= "" then
      table.insert(patches, {
        name = patch_name,
        status = status or "",
        display = line:gsub("^%s+", ""):gsub("%s+$", "") -- Keep original formatting
      })
    end
  end
  return patches
end

-- Helper function to get stg series patches (backward compatibility)
local function get_stg_patches()
  local patches_with_status = get_stg_patches_with_status()
  local patches = {}
  for _, patch in ipairs(patches_with_status) do
    table.insert(patches, patch.name)
  end
  return patches
end

-- Helper function to show enhanced selection UI with numbers and search
local function select_patch_enhanced(title, callback)
  local patches_with_status = get_stg_patches_with_status()
  if #patches_with_status == 0 then
    vim.notify("No patches found in stg series", vim.log.levels.WARN)
    return
  end

  -- Create display items with numbers
  local display_items = {}
  for i, patch in ipairs(patches_with_status) do
    local number_str = string.format("%2d", i)
    local display_text = string.format("[%s] %s", number_str, patch.display)
    table.insert(display_items, {
      index = i,
      patch = patch,
      display = display_text
    })
  end

  vim.ui.select(display_items, {
    prompt = title .. " (type to search, numbers to select): ",
    format_item = function(item)
      return item.display
    end,
    finder = function(prompt, items, callback)
      -- If prompt is a number, filter by index
      local num = tonumber(prompt)
      if num and num >= 1 and num <= #items then
        callback({items[num]})
        return
      end
      
      -- Otherwise, filter by search text
      local filtered = {}
      local search_lower = prompt:lower()
      for _, item in ipairs(items) do
        if item.patch.name:lower():find(search_lower, 1, true) or
           item.patch.display:lower():find(search_lower, 1, true) then
          table.insert(filtered, item)
        end
      end
      callback(filtered)
    end,
  }, function(choice)
    if choice then
      callback(choice.patch.name)
    end
  end)
end

-- Helper function to show selection UI using vim.ui.select (backward compatibility)
local function select_patch(title, callback)
  local patches = get_stg_patches()
  if #patches == 0 then
    vim.notify("No patches found in stg series", vim.log.levels.WARN)
    return
  end

  vim.ui.select(patches, {
    prompt = title,
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if choice then
      callback(choice)
    end
  end)
end

function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*/)") or "./"
end

-- Helper function to get the path to stg-aliases.bash
local function get_stg_aliases_path()
  local plugin_root = script_path():gsub("lua/", "")
  local local_script_path = plugin_root .. "/stg-aliases.bash"
  return local_script_path
end

-- Function to jump to a specific patch
local function stg_goto(patch_name)
  if not patch_name or patch_name == "" then
    select_patch_enhanced("Select patch to goto:", function(choice)
      stg_goto(choice)
    end)
    return
  end

  local stg_cmd = get_stg_command()
  if not stg_cmd then
    vim.notify("stg command not found", vim.log.levels.ERROR)
    return
  end

  local cmd = string.format("%s goto %s", stg_cmd, vim.fn.shellescape(patch_name))
  vim.fn.jobstart(cmd, {
    shell = true,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify(string.format("Successfully went to patch: %s", patch_name), vim.log.levels.INFO)
      else
        vim.notify(string.format("Failed to goto patch: %s", patch_name), vim.log.levels.ERROR)
      end
    end
  })
end

-- Function to refresh current patch
local function stg_refresh()
  local stg_cmd = get_stg_command()
  if not stg_cmd then
    vim.notify("stg command not found", vim.log.levels.ERROR)
    return
  end

  vim.fn.jobstart(stg_cmd .. " refresh --index", {
    shell = true,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("Successfully refreshed current patch", vim.log.levels.INFO)
      else
        vim.notify("Failed to refresh current patch", vim.log.levels.ERROR)
      end
    end
  })
end

-- Function to apply current changes to another patch
local function _stg_apply_to(patch_name, command)
  if not patch_name or patch_name == "" then
    select_patch_enhanced("Select patch to apply changes to:", function(choice)
      _stg_apply_to(choice, command)
    end)
    return
  end

  local stg_cmd = get_stg_command()
  if not stg_cmd then
    vim.notify("stg command not found", vim.log.levels.ERROR)
    return
  end

  local script_path = get_stg_aliases_path()
  local cmd = string.format("export PATH=\"$(dirname '%s'):$PATH\" && source %s && %s %s", stg_cmd, vim.fn.shellescape(script_path), command, vim.fn.shellescape(patch_name))

  vim.fn.jobstart(cmd, {
    shell = true,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify(string.format("Successfully applied changes to patch: %s", patch_name), vim.log.levels.INFO)
      else
        vim.notify(string.format("Failed to apply changes to patch: %s. Command: %s. Output: %s", patch_name, cmd, vim.fn.system(cmd)), vim.log.levels.ERROR)
      end
    end
  })
end

local function stg_apply_to(patch_name)
  _stg_apply_to(patch_name, "stg-apply-to")
end

local function stg_staged_apply_to(patch_name)
  _stg_apply_to(patch_name, "stg-apply-staged-to")
end

-- Function to spill current patch
local function stg_spill()
  local script_path = get_stg_aliases_path()
  local stg_cmd = get_stg_command()
  if not stg_cmd then
    vim.notify("stg command not found", vim.log.levels.ERROR)
    return
  end

  local cmd = string.format("export PATH=\"$(dirname '%s'):$PATH\" && source %s && stg-spill", stg_cmd, vim.fn.shellescape(script_path))

  vim.fn.jobstart(cmd, {
    shell = true,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("Successfully spilled current patch", vim.log.levels.INFO)
      else
        vim.notify(string.format("Failed to spill current patch. Output: %s", vim.fn.system(cmd)), vim.log.levels.ERROR)
      end
    end
  })
end

-- Function to resolve conflict-s
local function stg_resolve()
  local script_path = get_stg_aliases_path()
  local stg_cmd = get_stg_command()
  if not stg_cmd then
    vim.notify("stg command not found", vim.log.levels.ERROR)
    return
  end

  local cmd = string.format("export PATH=\"$(dirname '%s'):$PATH\" && source %s && stg-resolve", stg_cmd, vim.fn.shellescape(script_path))

  vim.fn.jobstart(cmd, {
    shell = true,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("Successfully resolved conflicts", vim.log.levels.INFO)
      else
        vim.notify("Failed to resolve conflicts", vim.log.levels.ERROR)
      end
    end
  })
end

-- Function to clone current branch
local function stg_branch_clone(branch_name)
  if not branch_name or branch_name == "" then
    -- Get current branch name and generate suggestion
    local current_branch = get_current_branch()
    if not current_branch then
      return
    end
    
    local suggested_name = generate_branch_name(current_branch)
    
    -- Use vim.ui.input to get user input with default value
    vim.ui.input({
      prompt = "Enter new branch name: ",
      default = suggested_name,
    }, function(input)
      if input and input ~= "" then
        stg_branch_clone(input)
      end
    end)
    return
  end

  local stg_cmd = get_stg_command()
  if not stg_cmd then
    vim.notify("stg command not found", vim.log.levels.ERROR)
    return
  end

  local cmd = string.format("%s branch --clone %s", stg_cmd, vim.fn.shellescape(branch_name))
  
  vim.fn.jobstart(cmd, {
    shell = true,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify(string.format("Successfully cloned branch to: %s", branch_name), vim.log.levels.INFO)
      else
        vim.notify(string.format("Failed to clone branch to: %s", branch_name), vim.log.levels.ERROR)
      end
    end
  })
end

-- Function to create a new patch
local function stg_new_patch(patch_name)
  if not patch_name or patch_name == "" then
    -- Get current patches and generate suggestion
    local patches = get_stg_patches()
    local patch_count = #patches
    local suggested_name = string.format("patch%d", patch_count + 1)
    
    -- Use vim.ui.input to get user input with default value
    vim.ui.input({
      prompt = "Enter new patch name: ",
      default = suggested_name,
    }, function(input)
      if input and input ~= "" then
        stg_new_patch(input)
      end
    end)
    return
  end

  local stg_cmd = get_stg_command()
  if not stg_cmd then
    vim.notify("stg command not found", vim.log.levels.ERROR)
    return
  end

  local script_path = get_stg_aliases_path()
  local cmd = string.format("export PATH=\"$(dirname '%s'):$PATH\" && source %s && stg-new %s", stg_cmd, vim.fn.shellescape(script_path), vim.fn.shellescape(patch_name))

  vim.fn.jobstart(cmd, {
    shell = true,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify(string.format("Successfully created new patch: %s", patch_name), vim.log.levels.INFO)
      else
        vim.notify(string.format("Failed to create new patch: %s", patch_name), vim.log.levels.ERROR)
      end
    end
  })
end

-- Function to edit current patch
local function stg_edit()
  local stg_cmd = get_stg_command()
  if not stg_cmd then
    vim.notify("stg command not found", vim.log.levels.ERROR)
    return
  end
 
  -- Open the buffer in a split window and create terminal
  vim.api.nvim_command("split")
  vim.api.nvim_command(string.format("terminal GIT_EDITOR='vim' %s edit", stg_cmd))
   
  -- Enter terminal mode
  vim.api.nvim_command("startinsert")
end

-- Function to start interactive rebase
local function stg_rebase()
  local stg_cmd = get_stg_command()
  if not stg_cmd then
    vim.notify("stg command not found", vim.log.levels.ERROR)
    return
  end
  
  -- Open the buffer in a split window and create terminal
  vim.api.nvim_command("split")
  vim.api.nvim_command(string.format("terminal GIT_EDITOR='vim' %s rebase -i", stg_cmd))

  -- Enter terminal mode
  vim.api.nvim_command("startinsert")
end

-- Function to show current series with position indicator
local function stg_series_show()
  local stg_cmd = get_stg_command()
  if not stg_cmd then
    vim.notify("stg command not found", vim.log.levels.ERROR)
    return
  end

  local cmd = stg_cmd .. " series"
  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    local error_msg = string.format("Failed to get stg series (exit code: %d)", exit_code)
    if result and result ~= "" then
      error_msg = error_msg .. string.format("\nCommand output: %s", result)
    end
    vim.notify(error_msg, vim.log.levels.ERROR)
    return
  end

  -- Split the result into lines and filter out empty lines
  local lines = {}
  for line in result:gmatch("[^\r\n]+") do
    if line:match("%S") then -- Only add non-empty lines
      -- Extract patch name (remove any markers like >, +, -)
      local patch_name = line:gsub("^%s*[+>-]%s*", ""):gsub("%s+$", "")
      
      -- Get commit hash for this patch
      local hash_cmd = string.format("%s show --stat %s", stg_cmd, vim.fn.shellescape(patch_name))
      local hash_result = vim.fn.system(hash_cmd)
      local hash = ""
      
      if vim.v.shell_error == 0 then
        -- Extract commit hash from the first line (format: commit <hash>)
        local commit_line = hash_result:match("[^\r\n]+")
        if commit_line then
          local extracted_hash = commit_line:match("commit%s+([a-f0-9]+)")
          if extracted_hash then
            hash = extracted_hash:sub(1, 8) -- Show first 8 characters
          end
        end
      end
      
      -- Add hash and patch name
      if hash ~= "" then
        table.insert(lines, hash .. " " .. line)
      else
        table.insert(lines, line)
      end
    end
  end

  -- Create a floating window to display the series
  local width = 60
  local height = math.min(#lines + 2, 20)
  
  -- Calculate window position (center of screen)
  local win_width = vim.api.nvim_win_get_width(0)
  local win_height = vim.api.nvim_win_get_height(0)
  local col = math.floor((win_width - width) / 2)
  local row = math.floor((win_height - height) / 2)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer content
  local header = "StG Series"
  local separator = string.rep("─", width)
  local content = {header, separator}
  
  for _, line in ipairs(lines) do
    table.insert(content, line)
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'stg-series')
  
  -- Create window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded'
  })
  
  -- Set window options
  vim.api.nvim_win_set_option(win, 'wrap', false)
  vim.api.nvim_win_set_option(win, 'cursorline', false)
  
  -- Add keymaps to close window
  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set('n', 'q', '<cmd>close<CR>', opts)
  vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', opts)
  vim.keymap.set('n', '<CR>', '<cmd>close<CR>', opts)
end

-- Setup function to define the stg commands
function M.setup(user_config)
  -- Merge user configuration with defaults
  if user_config then
    config = vim.tbl_deep_extend("force", config, user_config)
  end

  vim.api.nvim_create_user_command("StgGoto", function(opts)
    stg_goto(opts.args)
  end, {
    nargs = "?", -- Optional argument
    complete = function(_, _, _)
      return get_stg_patches()
    end,
  })

  vim.api.nvim_create_user_command("StgRefresh", function()
    stg_refresh()
  end, {
    nargs = 0,
  })

  vim.api.nvim_create_user_command("StgStagedApplyTo", function(opts)
    stg_staged_apply_to(opts.args)
  end, {
    nargs = "?", -- Optional argument
    complete = function(_, _, _)
      return get_stg_patches()
    end,
  })

  vim.api.nvim_create_user_command("StgApplyTo", function(opts)
    stg_apply_to(opts.args)
  end, {
    nargs = "?", -- Optional argument
    complete = function(_, _, _)
      return get_stg_patches()
    end,
  })

  vim.api.nvim_create_user_command("StgSpill", function()
    stg_spill()
  end, {
    nargs = 0,
  })

  vim.api.nvim_create_user_command("StgResolve", function()
    stg_resolve()
  end, {
    nargs = 0,
  })

  vim.api.nvim_create_user_command("StgBranchClone", function(opts)
    stg_branch_clone(opts.args)
  end, {
    nargs = "?", -- Optional argument
  })

  vim.api.nvim_create_user_command("StgSeries", function()
    stg_series_show()
  end, {
    nargs = 0,
  })

  vim.api.nvim_create_user_command("StgNew", function(opts)
    stg_new_patch(opts.args)
  end, {
    nargs = "?", -- Optional argument
  })

  vim.api.nvim_create_user_command("StgEdit", function()
    stg_edit()
  end, {
    nargs = 0,
  })

  vim.api.nvim_create_user_command("StgRebase", function()
    stg_rebase()
  end, {
    nargs = 0,
  })
end

-- Auto-setup when the module is loaded
M.setup()

return M
