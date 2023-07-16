vim.api.nvim_set_keymap('n', '<leader>fW', [[<cmd>lua require('telescope.builtin').grep_string()<cr>]], { silent = true, noremap = true, desc = "Grep Cword" })
