-- Autocommands.
local augroup = vim.api.nvim_create_augroup("dotfiles", { clear = true })

-- Format Rust on save (previously rust.vim's rustfmt_autosave). Guarded: a
-- machine without rustfmt should not fail on every write.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  pattern = "*.rs",
  callback = function()
    if vim.fn.executable("rustfmt") == 1 then
      vim.cmd("silent! RustFmt")
    end
  end,
})
