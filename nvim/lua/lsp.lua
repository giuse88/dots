-- Language servers: configs come from nvim-lspconfig, completion from blink.cmp
-- pyright: npm install -g pyright (uses the `python` on PATH, so activate conda first)
-- clangd: ships with Xcode Command Line Tools (reads compile_commands.json if present)
vim.lsp.enable({ "pyright", "clangd" })

vim.diagnostic.config({ virtual_text = true })

-- ── Code navigation ───────────────────────────────────────────────
-- built in: K docs, grr references, gri implementation, grt type definition,
-- grn rename, gra code action, gO outline, [d / ]d diagnostics, <C-o> jump back
vim.api.nvim_create_autocmd("LspAttach", {
    desc = "LSP navigation keymaps",
    callback = function(args)
        local builtin = require("telescope.builtin")
        local map = function(lhs, fn, desc) vim.keymap.set("n", lhs, fn, { buffer = args.buf, desc = desc }) end
        map("gd", vim.lsp.buf.definition, "Go to definition")
        map("gD", vim.lsp.buf.declaration, "Go to declaration")
        map("<leader>fr", builtin.lsp_references, "Find references")
        map("<leader>fs", builtin.lsp_document_symbols, "Symbols in this file")
        map("<leader>fS", builtin.lsp_dynamic_workspace_symbols, "Symbols in the project")
        map("<leader>fd", builtin.diagnostics, "Diagnostics")
    end,
})

-- ── blink.cmp: completion menu as you type ────────────────────────
-- only for these filetypes; everything else (markdown, text, ...) gets none
local cmp_filetypes = { lua = true, c = true, python = true }
require("blink.cmp").setup({
    enabled = function() return cmp_filetypes[vim.bo.filetype] == true and vim.bo.buftype ~= "prompt" end,
    keymap = {
        preset = "default", -- <C-y> accept, <C-e> close, <C-space> open/docs
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
    },
    completion = {
        list = { selection = { preselect = false } }, -- like completeopt=noselect: <Tab> picks
        documentation = { auto_show = true, auto_show_delay_ms = 300 },
    },
    signature = { enabled = true },
    sources = { default = { "lsp", "path", "snippets", "buffer" } },
    fuzzy = { implementation = "prefer_rust_with_warning" },
})
