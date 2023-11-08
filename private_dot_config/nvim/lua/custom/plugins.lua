local cmp = require "cmp"

local plugins = {
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "rust-analyzer",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "plugins.configs.lspconfig"
      require "custom.configs.lspconfig"
    end,
  },
  {
    "simrat39/rust-tools.nvim",
    ft = "rust",
    dependencies = "neovim/nvim-lspconfig",
    opts = function ()
      return require "custom.configs.rust-tools"
    end,
    config = function(_, opts)
      require('rust-tools').setup(opts)
    end
  },
  {
    "mfussenegger/nvim-dap",
    init = function()
      require("core.utils").load_mappings("dap")
    end
  },
  {
    "saecki/crates.nvim",
    ft = {"toml"},
    config = function(_, opts)
      local crates  = require("crates")
      crates.setup(opts)
      require('cmp').setup.buffer({
        sources = { { name = "crates" }}
      })
      crates.show()
      require("core.utils").load_mappings("crates")
    end,
  },
  {
    "rust-lang/rust.vim",
    ft = "rust",
    init = function ()
      vim.g.rustfmt_autosave = 1
    end
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    lazy = false,
    config = function(_, opts)
      require("nvim-dap-virtual-text").setup()
    end
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      {
        "zbirenbaum/copilot-cmp",
        config = function()
          require("copilot_cmp").setup()
        end,
      },
    },
    opts = function()
      local M = require "plugins.configs.cmp"
      M.completion.completeopt = "menu,menuone,noselect"
      M.mapping["<CR>"] = cmp.mapping.confirm {
        behavior = cmp.ConfirmBehavior.Insert,
        select = false,
      }
      table.insert(M.sources, {name = "crates"})
      table.insert(M.sources, 1, {name = "copilot", group_index = 2 })
      return M
    end,
  },
  {
    "ray-x/go.nvim",
    dependencies = {  -- optional packages
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("go").setup()
    end,
    event = {"CmdlineEnter"},
    ft = {"go", 'gomod'},
    build = ':lua require("go.install").update_all_sync()' -- if you need to install/update all binaries
  },
  {
    "declancm/maximize.nvim",
    config = function()
      require('maximize').setup()
    end,
  },
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = { enabled = false },
        panel = { enabled = false },
      })
    end,
  },
  {
    "jackMort/ChatGPT.nvim",
      event = "VeryLazy",
      config = function()
        require("chatgpt").setup({
          api_key_cmd = "cat /home/marko/openaikey.txt"
      })
      end,
      dependencies = {
        "MunifTanjim/nui.nvim",
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim"
      }
  },
  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      view = {
        centralize_selection = true,
      },
      actions = {
        open_file = {
          quit_on_open = true,
        },
      },
    },
  },
  {
    'stevearc/aerial.nvim',
    opts = {},
    lazy = false,
    config = function()
      require("aerial").setup({
        close_on_select = true,
        on_attach = function(bufnr)
          -- Jump forwards/backwards with '{' and '}'
          vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
          vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
        end,
      })
    end,
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons"
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    config = function()
      require('telescope').setup{
        pickers = {
          find_files = {
            theme = "ivy",
          },
          git_files = {
            theme = "ivy",
          },
          grep_string = {
            theme = "ivy",
          },
          live_grep = {
            theme = "ivy",
          },
          buffers = {
            theme = "ivy",
            mappings = {
              n = {
                ["d"] = "delete_buffer",
              }
            }
          },
          oldfiles = {
            theme = "ivy",
          },
          current_buffer_fuzzy_find = {
            theme = "ivy",
          },
          man_pages = {
            theme = "ivy",
          },
          help_tags = {
            theme = "ivy",
          },
          resume = {
            theme = "ivy",
          },
          marks = {
            theme = "ivy",
          },
        },
      }
    end,
  },
}
return plugins
