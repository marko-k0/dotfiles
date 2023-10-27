local M = {}

M.general = {
  n = {
    -- ["<leader>fG"] = { "<cmd>lua require('telescope.builtin').grep_string()<CR>", "Grep Cword" },
    ["<leader>Z"] = { "<Cmd>lua require('maximize').toggle()<CR>", "Maximize Panel" },
    ["<leader>a"] = { "<Cmd>AerialToggle!<CR>", "Aerial Toggle" },
  }
}

M.dap = {
  plugin = true,
  n = {
    ["<leader>db"] = { "<cmd> DapToggleBreakpoint <CR>" },
    ["<leader>dus"] = {
      function ()
        local widgets = require('dap.ui.widgets');
        local sidebar = widgets.sidebar(widgets.scopes);
        sidebar.open();
      end,
      "Open debugging sidebar"
    }
  }
}

M.crates = {
  plugin = true,
  n = {
    ["<leader>rcu"] = {
      function ()
        require('crates').upgrade_all_crates()
      end,
      "update crates"
    }
  }
}

M.telescope = {
  plugin = true,

  n = {
    -- find
    ["<leader>fr"] = { "<cmd> Telescope resume <CR>", "Resume previous" },
    ["<leader>fp"] = { "<cmd> Telescope man_pages <CR>", "Man pages" },
  },
}

return M
