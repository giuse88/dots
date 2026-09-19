-- Send selected Python lines to an IPython terminal split (no plugins)
local M = {}

local term = { buf = nil, chan = nil }

local function is_running()
    return term.chan ~= nil
        and term.buf ~= nil
        and vim.api.nvim_buf_is_valid(term.buf)
        and vim.fn.jobwait({ term.chan }, 0)[1] == -1
end

-- Terminal windows inherit list/number from options.lua, which looks wrong on a REPL
local function style_win(win)
    for opt, val in pairs({ number = false, relativenumber = false, list = false, signcolumn = "no", scrolloff = 0, winfixwidth = true }) do
        vim.api.nvim_set_option_value(opt, val, { win = win, scope = "local" })
    end
    vim.api.nvim_win_set_width(win, math.floor(vim.o.columns * 0.4))
end

local function setup_term_buf(buf)
    -- single <Esc> still belongs to IPython (history search, vi mode); <Esc><Esc> hands control back to nvim
    vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { buffer = buf, desc = "Back to normal mode" })
    vim.keymap.set("t", "jj", [[<C-\><C-n>]], { buffer = buf, desc = "Back to normal mode" })
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, desc = "Hide IPython (session keeps running)" })
    -- entering the pane lands in normal mode: scroll/search/yank output, press i to type in IPython
    vim.api.nvim_create_autocmd("TermClose", {
        buffer = buf,
        desc = "Clean up after IPython exits",
        callback = function()
            term.chan, term.buf = nil, nil
            local win = vim.fn.bufwinid(buf)
            if win ~= -1 and #vim.api.nvim_list_wins() > 1 then
                vim.api.nvim_win_close(win, true)
            end
            vim.schedule(function()
                if vim.api.nvim_buf_is_valid(buf) then
                    vim.api.nvim_buf_delete(buf, { force = true })
                end
            end)
        end,
    })
end

-- Opens IPython in a right split (or re-shows it if its window was closed)
function M.open()
    local src_win = vim.api.nvim_get_current_win()
    if is_running() then
        if vim.fn.bufwinid(term.buf) == -1 then
            vim.cmd("vertical rightbelow sbuffer " .. term.buf)
            style_win(vim.api.nvim_get_current_win())
            vim.api.nvim_set_current_win(src_win)
        end
        return true
    end
    if vim.fn.executable("ipython") == 0 then
        vim.notify("ipython not found on PATH (activate your conda env first)", vim.log.levels.ERROR)
        return false
    end
    vim.cmd("vertical rightbelow new")
    term.chan = vim.fn.jobstart({ "ipython" }, { term = true })
    term.buf = vim.api.nvim_get_current_buf()
    style_win(vim.api.nvim_get_current_win())
    setup_term_buf(term.buf)
    vim.api.nvim_set_current_win(src_win)
    -- wait for the first prompt, otherwise code sent now is echoed raw before IPython starts
    vim.wait(10000, function()
        for _, line in ipairs(vim.api.nvim_buf_get_lines(term.buf, 0, -1, false)) do
            if line:match("^In %[") then return true end
        end
        return false
    end, 50)
    return true
end

-- Removes the indentation shared by all non-blank lines
local function dedent(lines)
    local min
    for _, line in ipairs(lines) do
        if line:match("%S") then
            local n = #line:match("^%s*")
            min = min and math.min(min, n) or n
        end
    end
    if not min or min == 0 then return lines end
    local out = {}
    for i, line in ipairs(lines) do
        out[i] = line:sub(min + 1)
    end
    return out
end

function M.send_lines(lines)
    if not M.open() then return end
    lines = dedent(lines)
    local text = table.concat(lines, "\n")
    if #lines > 1 then
        text = text .. "\n" -- blank line so IPython runs indented blocks
    end
    -- bracketed paste stops IPython from auto-indenting the pasted code
    vim.api.nvim_chan_send(term.chan, "\27[200~" .. text .. "\27[201~\r")
    local win = vim.fn.bufwinid(term.buf)
    if win ~= -1 then
        vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(term.buf), 0 })
    end
end

function M.send_selection()
    local first, last = vim.fn.line("v"), vim.fn.line(".")
    if first > last then first, last = last, first end
    local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    M.send_lines(lines)
end

-- Runs the current line, then moves down one line (like Shift-Enter in Jupyter)
function M.send_line_and_advance()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    M.send_lines({ vim.api.nvim_get_current_line() })
    vim.api.nvim_win_set_cursor(0, { math.min(row + 1, vim.api.nvim_buf_line_count(0)), 0 })
end

vim.api.nvim_create_user_command("IPython", function() M.open() end, { desc = "Open IPython in a right split" })

vim.api.nvim_create_autocmd("FileType", {
    pattern = "python",
    desc = "IPython send keymap",
    callback = function(args)
        vim.keymap.set("x", "<leader>r", M.send_selection, { buffer = args.buf, desc = "Run selected lines in IPython" })
        vim.keymap.set("x", "<leader><CR>", M.send_selection, { buffer = args.buf, desc = "Run selected lines in IPython" })
        for _, lhs in ipairs({ "<leader><CR>", "<leader><leader>" }) do
            vim.keymap.set("n", lhs, M.send_line_and_advance, { buffer = args.buf, desc = "Run line in IPython, go to next line" })
        end
    end,
})

return M
