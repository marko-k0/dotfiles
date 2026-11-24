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

-- OSC 52 clipboard fallback, used only where no real system clipboard exists:
-- over ssh/mosh (no X or Wayland socket) or on a local box without a usable
-- wl-copy/xclip. There it is the only route to the local clipboard. Neovim
-- 0.10+ ships the encoders as a module; the previous guard
-- (`vim.ui.clipboard and vim.ui.clipboard.osc52`) never matched, because
-- `vim.ui.clipboard` is nil and only `vim.ui.clipboard.osc52` exists.
--
-- It must NOT replace the provider locally: LazyVim sets
-- 'clipboard=unnamedplus' when not in ssh, so p/P and y all go through this
-- table, and its paste half cannot work (tmux does not forward OSC 52 read
-- queries, and this repo's kitty config grants writes only), which made local
-- yank/paste fail while remote kept working. See the "Clipboard" section of the
-- README.
local has_osc52, osc52 = pcall(require, "vim.ui.clipboard.osc52")
local remote = vim.env.SSH_CONNECTION ~= nil or vim.env.MOSH_IP ~= nil
-- Mirrors Neovim's own provider detection: a tool that exists but has no
-- display to talk to (e.g. xsel on a headless server) is not usable.
local has_system_clipboard = (vim.env.WAYLAND_DISPLAY ~= nil and vim.fn.executable("wl-copy") == 1)
  or (vim.env.DISPLAY ~= nil and (vim.fn.executable("xclip") == 1 or vim.fn.executable("xsel") == 1))
  or (vim.fn.has("mac") == 1 and vim.fn.executable("pbcopy") == 1)
  or (vim.fn.has("win32") == 1 and vim.fn.executable("win32yank.exe") == 1)

if has_osc52 and (remote or not has_system_clipboard) then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    -- Paste needs a terminal that answers OSC 52 read queries. tmux does not
    -- forward them in any mode (verified on 3.4), and this repo's kitty config
    -- denies reads, in which case nvim waits 1s + 9s and then warns. Leaving it
    -- empty makes "+p fail fast, so the supported path is the terminal's own
    -- paste (Ctrl+Shift+V in kitty).
    paste = {},
  }

  -- Without a system clipboard LazyVim would still set clipboard=unnamedplus
  -- locally, routing p/P through the empty provider above. Keep p/P on
  -- Neovim's own registers instead (remote already gets clipboard empty).
  if not remote then
    opt.clipboard = ""
  end

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
