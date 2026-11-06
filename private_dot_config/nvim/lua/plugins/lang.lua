-- Language tweaks.
--
-- LazyVim's lang.go and lang.rust extras already provide gopls, goimports,
-- gofumpt, delve/DAP, neotest, rustaceanvim and crates.nvim, so only the local
-- differences are declared here.
return {
  -- gopls: build with the wire injection tag used in this codebase
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
          settings = {
            gopls = {
              buildFlags = { "-tags=wireinject" },
            },
          },
        },
      },
    },
  },

  -- rustaceanvim: do not inherit rust-analyzer settings from VS Code
  {
    "mrcjkb/rustaceanvim",
    opts = {
      server = {
        load_vscode_settings = false,
      },
    },
  },
}
