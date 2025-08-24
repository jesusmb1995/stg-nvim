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
    cmd = { "StgGoto", "StgRefresh", "StgStagedApplyTo", "StgApplyTo", "StgSpill", "StgResolve" },
    keys = {
      { "<leader>gkg", "<cmd>StgGoto<cr>", desc = "Go to patch" },
      { "<leader>gkr", "<cmd>StgRefresh<cr>", desc = "Refresh current patch" },
      { "<leader>gka", "<cmd>StgStagedApplyTo<cr>", desc = "Apply current staged changes to another patch but stay on current patch" },
      { "<leader>gkA", "<cmd>StgApplyTo<cr>", desc = "Apply current changes to another patch but stay on current patch" },
      { "<leader>gku", "<cmd>StgSpill<cr>", desc = "Empty current patch but keep changes locally" },
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
- `:Stg(Staged)ApplyTo [patch_name]` - Apply current changes to another patch but stay on current patch
- `:StgUnstage` - Move current patch to stage region
- `:StgResolve` - Resolve (refresh) conflicts

## Requirements

- [stg (Stacked Git)](https://github.com/ctmarinas/stgit)
- The `stg-aliases.bash` script from this repository must be available
