---@type ChadrcConfig 
local M = {}
M.ui = {
  theme = 'gruvbox',
  theme_toggle = { "onedark", "solarized_dark" },
  transparency = true,
  telescope = {
    style = "bordered"
  }
}
M.plugins = 'custom.plugins'
M.mappings = require "custom.mappings"
return M
