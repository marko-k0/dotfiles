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

-- Aerial symbol outline (also available as <leader>cs from the aerial extra)
vim.keymap.set("n", "<leader>a", "<cmd>AerialToggle<CR>", { desc = "Aerial toggle" })

-- crates.nvim: upgrade every outdated crate in Cargo.toml
vim.keymap.set("n", "<leader>rcu", function()
  require("crates").upgrade_all_crates()
end, { desc = "Update all crates" })
