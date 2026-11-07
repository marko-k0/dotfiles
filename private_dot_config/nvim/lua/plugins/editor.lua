-- Editor plugins and overrides on top of LazyVim.
return {
  -- Telescope: ivy layout (as before). No custom navigation keys: telescope
  -- already provides <C-n>/<C-p> in insert mode and j/k in normal mode.
  --
  -- Merged into LazyVim's opts rather than calling telescope.setup() here:
  -- LazyVim's telescope extra (selected by vim.g.lazyvim_picker in
  -- lua/config/options.lua) supplies its own defaults, and a second setup()
  -- call would replace the mappings table defined below.
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, require("telescope.themes").get_ivy())
      opts.pickers = vim.tbl_deep_extend("force", opts.pickers or {}, {
        buffers = {
          mappings = { n = { ["d"] = "delete_buffer" } },
        },
      })
      return opts
    end,
  },

  -- Git UI
  {
    "NeogitOrg/neogit",
    cmd = "Neogit",
    keys = { { "<leader>gn", "<cmd>Neogit<CR>", desc = "Neogit" } },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    opts = {},
  },

  -- Maximize / restore a split (keymap lives in config/keymaps.lua)
  {
    "declancm/maximize.nvim",
    opts = {},
  },
}
