vim.api.nvim_create_user_command("TermRight", function()
    vim.cmd("vertical rightbelow terminal")
    vim.wo.winfixwidth = true
    vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * 0.4))
end, { desc = "Open terminal in a right split (40% width)" })
