local term = require("term")

vim.api.nvim_create_user_command("TermRight", function(args)
    local name = args.args ~= "" and args.args or term.next_name("shell")
    term.create(name, { vim.o.shell }, { kind = "shell" })
end, { nargs = "?", desc = "New shell session in the right pane (40% width)" })

-- rename the session showing in the pane: :TermRename experiment
vim.api.nvim_create_user_command("TermRename", function(args)
    term.rename(term.visible(), args.args)
end, { nargs = 1, desc = "Rename the visible terminal session" })
