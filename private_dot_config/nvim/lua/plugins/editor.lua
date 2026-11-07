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

  -- Seamless <C-h/j/k/l> between nvim splits and tmux panes. The tmux half is
  -- the TPM plugin declared in dot_tmux.conf; this one replaces LazyVim's plain
  -- window mappings with versions that hand off to tmux at the edge. Keys are
  -- lazy triggers, so nothing loads until the first <C-h>.
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
      "TmuxNavigatorProcessList",
    },
    keys = {
      { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
      { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
      { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
      { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
      { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
    },
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
