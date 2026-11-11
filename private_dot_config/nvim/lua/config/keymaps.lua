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

-- Aerial symbol outline on <leader>a (the editor.aerial extra's <leader>cs
-- also works). <leader>a cannot be a which-key group prefix, so the AI keys
-- live under <leader>A instead.
vim.keymap.set("n", "<leader>a", "<cmd>AerialToggle<CR>", { desc = "Aerial toggle" })

-- crates.nvim: upgrade every outdated crate in Cargo.toml
vim.keymap.set("n", "<leader>rcu", function()
  require("crates").upgrade_all_crates()
end, { desc = "Update all crates" })
