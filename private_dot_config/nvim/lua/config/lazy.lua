-- lazy.nvim bootstrap + LazyVim spec.
--
-- This file replaces the upstream `LazyVim/starter` template: the config is
-- fully managed by chezmoi instead of being cloned into ~/.config/nvim, so
-- there is nothing to pull or keep in sync by hand.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", repo, lazypath })
  if vim.v.shell_error ~= 0 then
    -- Only wait for a keypress when someone is watching: getchar() blocks
    -- forever under `nvim --headless`, which is how the chezmoi plugin hook
    -- runs, so a failed clone would hang `chezmoi apply` instead of failing.
    local interactive = #vim.api.nvim_list_uis() > 0
    local lines = {
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
    }
    if interactive then
      table.insert(lines, { "\nPress any key to exit..." })
    end
    vim.api.nvim_echo(lines, true, {})
    if interactive then
      vim.fn.getchar()
    end
    os.exit(1)
  end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- LazyVim extras: curated bundles for the languages/tools used here.
    { import = "lazyvim.plugins.extras.lang.go" },
    { import = "lazyvim.plugins.extras.lang.rust" },
    -- Docker, Kubernetes YAML and Helm charts are part of the daily toolchain
    -- (kubectl/kind/helm/cilium are mise-managed), so validate them in-editor.
    { import = "lazyvim.plugins.extras.lang.docker" },
    { import = "lazyvim.plugins.extras.lang.yaml" },
    { import = "lazyvim.plugins.extras.lang.helm" },
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.ai.copilot" },
    { import = "lazyvim.plugins.extras.dap.core" },
    { import = "lazyvim.plugins.extras.editor.aerial" },
    -- Quality of life.
    { import = "lazyvim.plugins.extras.coding.mini-surround" }, -- gs* surround
    { import = "lazyvim.plugins.extras.editor.inc-rename" },    -- live rename preview
    { import = "lazyvim.plugins.extras.editor.illuminate" },    -- highlight references
    { import = "lazyvim.plugins.extras.ui.treesitter-context" }, -- sticky context

    -- Local overrides and extra plugins (this repo).
    { import = "plugins" },
  },
  defaults = {
    lazy = false,
    version = false, -- always use the latest git commit
  },
  install = { colorscheme = { "gruvbox-material", "habamax" } },
  checker = { enabled = false }, -- no update prompts; ./update.sh does this
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
