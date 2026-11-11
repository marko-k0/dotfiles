-- Custom keymaps (on top of LazyVim's defaults).
--
-- <leader>e opens the file explorer, <leader>db toggles a DAP breakpoint and
-- <leader>du opens the DAP UI: those come from LazyVim itself, so they are not
-- repeated here.
vim.keymap.set("n", "<leader>Z", function()
  require("maximize").toggle()
end, { desc = "Maximize panel" })

vim.keymap.set("n", "<leader>fW", function()
  require("telescope.builtin").grep_string()
end, { desc = "Grep word under cursor" })

-- Aerial symbol outline: <leader>cs comes from the editor.aerial extra; no
-- local mapping here, so that <leader>a can stay the LazyVim AI prefix.

-- crates.nvim: upgrade every outdated crate in Cargo.toml
vim.keymap.set("n", "<leader>rcu", function()
  require("crates").upgrade_all_crates()
end, { desc = "Update all crates" })
