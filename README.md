# stg-nvim

Some stacked git (stg) commands for neovim. See https://stacked-git.github.io/

## Installation

### Lazy.nvim

Add a new file `lua/plugins/stg-nvim.lua` to your neovim config folder:

```lua
return {
  {
    url = "https://github.com/jesusmb1995/stg-nvim",
    lazy = true,
    cmd = { "StgGoto", "StgRefresh", "StgApplyTo", "StgUnstage", "StgResolve" },
    keys = {
      { "<leader>gkg", "<cmd>StgGoto<cr>", desc = "Go to patch" },
      { "<leader>gkr", "<cmd>StgRefresh<cr>", desc = "Refresh current patch" },
      { "<leader>gka", "<cmd>StgApplyTo<cr>", desc = "Apply changes to patch" },
      { "<leader>gku", "<cmd>StgUnstage<cr>", desc = "Unstage patch" },
      { "<leader>gkc", "<cmd>StgResolve<cr>", desc = "Resolve conflicts" },
    },
    config = function()
      require('stg-nvim').setup({
        -- Optional: specify stg path
        stg_path = "/home/linuxbrew/.linuxbrew/bin/stg" 
      })
    end
  }
}
```

## Available Commands

- `:StgGoto [patch_name]` - Navigate to a specific patch (opens selection UI if no patch specified)
- `:StgRefresh` - Refresh the current patch
- `:StgApplyTo [patch_name]` - Apply current changes to another patch
- `:StgUnstage [patch_name]` - Unstage a patch
- `:StgResolve` - Resolve (refresh) conflicts

## Requirements

- [stg (Stacked Git)](https://github.com/ctmarinas/stgit)
- The `stg-aliases.bash` script from this repository must be available
