-- Editor options, applied after LazyVim's defaults (lua/config/options.lua is
-- loaded after LazyVim's own config).
local opt = vim.opt

-- Fuzzy finder: telescope, matching the ivy setup in lua/plugins/editor.lua.
-- This must be here, not in init.lua: LazyVim's own options.lua sets
-- vim.g.lazyvim_picker = "auto" and is loaded first, and this file runs before
-- the extras are resolved. v16 defaults to snacks.picker, so without this line
-- telescope is installed but never registered and every <leader>f* key would
-- open snacks instead.
vim.g.lazyvim_picker = "telescope"

opt.number = true
-- Absolute line numbers only: LazyVim enables relativenumber by default, this
-- file is loaded after it, so the override sticks.
opt.relativenumber = false
opt.scrolloff = 8

-- OSC 52 clipboard: copy over ssh, mosh and tmux without xclip/xsel or X
-- forwarding. Neovim 0.10+ ships the encoders as a module; the previous guard
-- (`vim.ui.clipboard and vim.ui.clipboard.osc52`) never matched, because
-- `vim.ui.clipboard` is nil and only `vim.ui.clipboard.osc52` exists. See the
-- "Clipboard" section of the README for what works in each environment.
local has_osc52, osc52 = pcall(require, "vim.ui.clipboard.osc52")
if has_osc52 then
  local remote = vim.env.SSH_CONNECTION ~= nil

  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    -- Paste needs a terminal that answers OSC 52 read queries. tmux does not
    -- forward them in any mode (verified on 3.4), and a terminal may deny reads
    -- (this repo's kitty config grants writes only), in which case nvim waits
    -- 1s + 9s and then warns. Leaving paste undefined makes "+p fail fast, so
    -- the supported path is the terminal's own paste (Ctrl+Shift+V in kitty).
    paste = (remote or vim.env.TMUX) and {} or {
      ["+"] = osc52.paste("+"),
      ["*"] = osc52.paste("*"),
    },
  }

  -- Copy on a normal yank too, but without 'clipboard=unnamedplus': that option
  -- also routes p/P through the clipboard (which stalls, and loses linewise
  -- pastes) and sends every delete to the local clipboard. Filtering on the
  -- operator keeps d/c/x from clobbering it.
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("dotfiles-osc52", { clear = true }),
    callback = function()
      if vim.v.event.operator ~= "y" then
        return
      end
      pcall(osc52.copy("+"), vim.fn.getreg('"', 1, true))
    end,
  })
end
