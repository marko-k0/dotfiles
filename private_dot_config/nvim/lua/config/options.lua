-- Editor options, applied after LazyVim's defaults (lua/config/options.lua is
-- loaded after LazyVim's own config).
local opt = vim.opt

opt.relativenumber = true
opt.scrolloff = 8

-- OSC 52 clipboard: copy/paste over ssh and inside tmux without xclip/xsel or
-- X forwarding. Neovim 0.10+ provides the encoders.
if vim.ui.clipboard and vim.ui.clipboard.osc52 then
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      ["+"] = osc52.paste("+"),
      ["*"] = osc52.paste("*"),
    },
  }
end
