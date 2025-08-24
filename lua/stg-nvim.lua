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

-- Helper function to get stg series patches
local function get_stg_patches()
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
    local patch_name = line:match("^%s*[+>-]?%s*([^%s]+)")
    if patch_name and patch_name ~= "" then
      table.insert(patches, patch_name)
    end
  end
  return patches
end

-- Helper function to show selection UI using vim.ui.select
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
    select_patch("Select patch to goto:", function(choice)
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

  vim.fn.jobstart(stg_cmd .. " refresh", {
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
    select_patch("Select patch to apply changes to:", function(choice)
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
end

-- Auto-setup when the module is loaded
M.setup()

return M
