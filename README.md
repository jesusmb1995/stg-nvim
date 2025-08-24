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
    cmd = { "StgNew", "StgSeries", "StgGoto", "StgRefresh", "StgStagedApplyTo", "StgApplyTo", "StgSpill", "StgResolve", "StgBranchClone", "StgEdit", "StgRebase" },
    keys = {
      { "<leader>gkn", "<cmd>StgNew<cr>",           desc = "Create new patch" },
      { "<leader>gks", "<cmd>StgSeries<cr>",        desc = "Show patches" },
      { "<leader>gkg", "<cmd>StgGoto<cr>",          desc = "Go to patch" },
      { "<leader>gkr", "<cmd>StgRefresh<cr>",       desc = "Refresh current patch" },
      { "<leader>gka", "<cmd>StgStagedApplyTo<cr>", desc = "Apply current staged changes to another patch but stay on current patch" },
      { "<leader>gkA", "<cmd>StgApplyTo<cr>",       desc = "Apply current changes to another patch but stay on current patch" },
      { "<leader>gku", "<cmd>StgSpill<cr>",         desc = "Empty current patch but keep changes locally" },
      { "<leader>gkc", "<cmd>StgBranchClone<cr>",   desc = "Clone current branch" },
      { "<leader>gkC", "<cmd>StgResolve<cr>",       desc = "Resolve conflicts" },
      { "<leader>gke", "<cmd>StgEdit<cr>",          desc = "Edit current patch" },
      { "<leader>gkR", "<cmd>StgRebase<cr>",        desc = "Interactive rebase" },
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

- `:StgSeries` - Show the current patch series in a floating window
- `:StgGoto [patch_name]` - Navigate to a specific patch (opens selection UI if no patch specified)
- `:StgRefresh` - Refresh the current patch
- `:Stg(Staged)ApplyTo [patch_name]` - Apply current changes to another patch but stay on current patch
- `:StgUnstage` - Move current patch to stage region
- `:StgResolve` - Resolve (refresh) conflicts
- `:StgBranchClone [branch_name]` - Clone current branch (prompts for name if not specified)
- `:StgNew [patch_name]` - Create a new patch (prompts for name if not specified)
- `:StgEdit` - Edit the current patch (opens editor buffer)
- `:StgRebase` - Start interactive rebase (opens rebase buffer)

## Requirements

- [stg (Stacked Git)](https://github.com/ctmarinas/stgit)
- The `stg-aliases.bash` script from this repository must be available
