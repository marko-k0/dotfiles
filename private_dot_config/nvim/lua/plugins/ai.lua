-- AI: Copilot comes from the ai.copilot extra; codecompanion is added here.
--
-- CodeCompanion talks to any OpenAI-compatible endpoint. The defaults target
-- the local litellm gateway, which needs no provider API key. Point it
-- elsewhere with env vars (e.g. in ~/.config/fish/secrets.fish):
--
--   LLM_URL      root URL, no /v1 suffix (default http://127.0.0.1:4000)
--   LLM_API_KEY  bearer token (default sk-litellm-local, the local master key)
--   LLM_MODEL    model id (default OpenRouter/DeepSeek-V4.1-Flash)
--
-- Direct OpenRouter, for example:
--
--   LLM_URL=https://openrouter.ai/api
--   LLM_API_KEY=sk-or-v1-...
--   LLM_MODEL=deepseek/deepseek-v4.1-flash-1017
--
-- Note that model ids are endpoint-specific: the litellm alias
-- "OpenRouter/DeepSeek-V4.1-Flash" is not a valid OpenRouter model.
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
      -- <leader>a is LazyVim's AI prefix (avante/claudecode/copilot-chat all use
      -- it). <leader>c is LazyVim's code prefix: buffer-local LSP maps own
      -- <leader>ca (Code Action) and <leader>cc (Run Codelens) once a server
      -- attaches, and those override a global mapping, so AI keys must not
      -- live there.
      { "<leader>a", "", desc = "+ai", mode = { "n", "v" } },
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<CR>", desc = "CodeCompanion chat" },
      { "<leader>ae", "<cmd>CodeCompanion<CR>", mode = { "n", "v" }, desc = "CodeCompanion inline" },
      { "<leader>aa", "<cmd>CodeCompanionActions<CR>", mode = { "n", "v" }, desc = "CodeCompanion actions" },
    },
    opts = {
      -- v20 spells this `interactions`; `strategies` still works as an alias.
      interactions = {
        chat = { adapter = "llm" },
        inline = { adapter = "llm" },
      },
      adapters = {
        -- Custom adapters must be nested under `http` (or `acp`): a flat
        -- `adapters = { llm = ... }` is stored but never resolved.
        http = {
          llm = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              formatted_name = "OpenAI-compatible",
              env = {
                -- Root URL only: the adapter appends /v1/chat/completions and
                -- /v1/models, so "http://127.0.0.1:4000/v1" or
                -- "https://openrouter.ai/api/v1" would 404.
                url = function()
                  return vim.env.LLM_URL or "http://127.0.0.1:4000"
                end,
                -- A placeholder is not enough: the proxy answers
                -- 401 "must start with sk-", so the local master key is the
                -- default and a real key replaces it.
                api_key = function()
                  return vim.env.LLM_API_KEY or "sk-litellm-local"
                end,
              },
              schema = {
                -- Litellm model id, case sensitive ("V4.1" not "v4.1"). Other
                -- endpoints use their own ids; override with LLM_MODEL.
                model = { default = vim.env.LLM_MODEL or "OpenRouter/DeepSeek-V4.1-Flash" },
              },
            })
          end,
        },
      },
    },
  },
}
