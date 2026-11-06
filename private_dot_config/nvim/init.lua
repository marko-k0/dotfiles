-- LazyVim entry point.
--
-- Everything under ~/.config/nvim is managed by chezmoi. Neovim itself is
-- version-managed by mise (see .chezmoidata/software.yaml); lazy.nvim and all
-- plugins are installed by the run_once_after_20_nvim_plugins hook on the first
-- apply, and updated with `./update.sh`.
--
-- Add plugins in lua/plugins/*.lua, options/keymaps in lua/config/*.lua.
require("config.lazy")
