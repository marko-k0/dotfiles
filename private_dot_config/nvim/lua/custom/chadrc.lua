---@type ChadrcConfig 
local M = {}
M.ui = {
  theme = 'gruvbox',
  theme_toggle = { "gruvbox", "onedark" },
  transparency = true,
  telescope = {
    style = "bordered"
  }
}
M.plugins = 'custom.plugins'
M.mappings = require "custom.mappings"
return M
