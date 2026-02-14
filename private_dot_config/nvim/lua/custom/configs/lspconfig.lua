vim.lsp.config("gopls", {
  settings = {
    gopls = {
      buildFlags = { "-tags=wireinject" },
    },
  },
})

vim.lsp.enable("gopls")
