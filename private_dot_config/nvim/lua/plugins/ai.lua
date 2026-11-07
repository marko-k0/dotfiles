-- AI: Copilot comes from the ai.copilot extra; codecompanion is added here.
return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    cmd = {
      "CodeCompanion",
      "CodeCompanionCmd",
      "CodeCompanionActions",
      "CodeCompanionChat",
    },
    keys = {
      { "<leader>cc", "<cmd>CodeCompanionChat Toggle<CR>", desc = "CodeCompanion chat" },
      { "<leader>ci", "<cmd>CodeCompanion<CR>", mode = { "n", "v" }, desc = "CodeCompanion inline" },
      { "<leader>ca", "<cmd>CodeCompanionActions<CR>", mode = { "n", "v" }, desc = "CodeCompanion actions" },
    },
    opts = {
      strategies = {
        chat = { adapter = "openai" },
        inline = { adapter = "openai" },
      },
      adapters = {
        openai = function()
          return require("codecompanion.adapters").extend("openai", {
            env = { api_key = "OPENAI_API_KEY" },
          })
        end,
      },
    },
  },
}
