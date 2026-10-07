-- Plugins, managed by Neovim's built-in vim.pack
vim.pack.add({
    { src = "https://github.com/nvim-lua/plenary.nvim" }, -- telescope dependency
    { src = "https://github.com/nvim-telescope/telescope.nvim" },
    { src = "https://github.com/nvim-telescope/telescope-file-browser.nvim" },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
    { src = "https://github.com/neovim/nvim-lspconfig" }, -- language server configs (pyright, ...)
    -- release tags ship a prebuilt fuzzy matcher, so stay on 1.x tags
    { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.*") },
})

-- ── Telescope: find and manage files ──────────────────────────────
local telescope = require("telescope")
telescope.setup({
    defaults = {
        layout_strategy = "flex",
        file_ignore_patterns = { "%.git/", "%.claude/file%-history/", "node_modules/", "%.venv/", "__pycache__/", "%.zsh_sessions/" },
    },
    pickers = { find_files = { hidden = true } }, -- dotfiles matter in ~/.config
    extensions = { file_browser = { grouped = true, hidden = true } },
})
telescope.load_extension("file_browser")

local builtin = require("telescope.builtin")
local map = function(lhs, fn, desc) vim.keymap.set("n", lhs, fn, { desc = desc }) end
map("<leader>ff", builtin.find_files, "Find files")
map("<leader>fg", builtin.live_grep, "Grep in files")
map("<leader>fb", builtin.buffers, "Open buffers")
map("<leader>fo", builtin.oldfiles, "Recent files")
map("<leader>fh", builtin.help_tags, "Search help")
map("<leader>fe", function()
    telescope.extensions.file_browser.file_browser({ path = "%:p:h", select_buffer = true })
end, "Manage files (create/rename/delete)")

-- ── Treesitter: syntax highlighting ───────────────────────────────
-- nvim ships c/lua parsers; python comes from nvim-treesitter
local ts_filetypes = { "python", "lua", "c" }
require("nvim-treesitter").install(ts_filetypes)
vim.api.nvim_create_autocmd("FileType", {
    pattern = ts_filetypes,
    desc = "Treesitter highlighting",
    callback = function() pcall(vim.treesitter.start) end,
})
