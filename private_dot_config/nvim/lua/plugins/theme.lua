-- Theme: gruvbox-material.
--
-- Same background and grays as gruvbox (#282828 on "medium"), but softer and
-- differently hue'd syntax colors -- keywords are a muted red rather than
-- gruvbox's bright one, identifiers olive-green rather than bright green.
--
-- Tuning knobs:
--   vim.g.gruvbox_material_background = "soft" | "medium" | "hard"
--     soft   -> #32302f  (medium is gruvbox's #282828, hard is #1d2021)
--   vim.g.gruvbox_material_transparent_background = 1   -- terminal bg shows through
--   vim.g.gruvbox_material_foreground = "material" | "mix" | "original"
return {
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "gruvbox-material" },
  },
  {
    "sainnhe/gruvbox-material",
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.gruvbox_material_background = "medium"
      vim.g.gruvbox_material_transparent_background = 1
      vim.cmd.colorscheme("gruvbox-material")
    end,
  },
}
