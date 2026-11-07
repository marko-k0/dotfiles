-- Editor plugins and overrides on top of LazyVim.
return {
  -- Telescope: ivy-style layout (kept from the previous config)
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      require("telescope").setup({
        defaults = require("telescope.themes").get_ivy(),
        pickers = {
          buffers = {
            mappings = { n = { ["d"] = "delete_buffer" } },
          },
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
