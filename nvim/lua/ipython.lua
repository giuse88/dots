-- Run Python in named IPython sessions sharing the right-hand pane (no plugins)
local term = require("term")
local M = {}

M.last = nil -- name of the session code went to most recently

local function wait_for_prompt(session)
    vim.wait(10000, function()
        for _, line in ipairs(vim.api.nvim_buf_get_lines(session.buf, 0, -1, false)) do
            if line:match("^In %[") then return true end
        end
        return false
    end, 50)
end

-- start a new IPython session; name defaults to ipython1, ipython2, ...
function M.new(name)
    if vim.fn.executable("ipython") == 0 then
        vim.notify("ipython not found on PATH (activate your conda env first)", vim.log.levels.ERROR)
        return nil
    end
    local session = term.create(name or term.next_name("ipython"), { "ipython" }, { kind = "ipython" })
    wait_for_prompt(session)
    M.last = session.name
    return session
end

-- which session receives code: the one on screen, else the last one used, else the first
local function target()
    local visible = term.visible()
    if visible and visible.kind == "ipython" then
        return visible
    end
    if M.last and term.get(M.last) then
        return term.get(M.last)
    end
    return term.list("ipython")[1]
end

-- :IPython [name] shows that session (creating it if needed)
function M.open(name)
    if name and name ~= "" then
        local session = term.get(name)
        return session and term.show(session) and session or M.new(name)
    end
    local session = target()
    if session then
        term.show(session)
        return session
    end
    return M.new()
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
    local session = target() or M.new()
    if not session then return end
    term.show(session)
    M.last = session.name
    lines = dedent(lines)
    local text = table.concat(lines, "\n")
    if #lines > 1 then
        text = text .. "\n" -- blank line so IPython runs indented blocks
    end
    -- bracketed paste stops IPython from auto-indenting the pasted code
    vim.api.nvim_chan_send(session.chan, "\27[200~" .. text .. "\27[201~\r")
    local win = vim.fn.bufwinid(session.buf)
    if win ~= -1 then
        vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(session.buf), 0 })
    end
end

-- charwise (v) sends exactly what is highlighted; linewise (V) and block send whole lines
function M.send_selection()
    local charwise = vim.fn.mode() == "v"
    local s, e = vim.fn.getpos("v"), vim.fn.getpos(".")
    local srow, scol, erow, ecol = s[2], s[3], e[2], e[3]
    if srow > erow or (srow == erow and scol > ecol) then
        srow, scol, erow, ecol = erow, ecol, srow, scol
    end
    local lines
    if charwise then
        local last_len = #vim.fn.getline(erow)
        lines = vim.api.nvim_buf_get_text(0, srow - 1, scol - 1, erow - 1, math.min(ecol, last_len), {})
    else
        lines = vim.api.nvim_buf_get_lines(0, srow - 1, erow, false)
    end
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    M.send_lines(lines)
end

-- Runs the current line, then moves down one line (like Shift-Enter in Jupyter)
function M.send_line_and_advance()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    M.send_lines({ vim.api.nvim_get_current_line() })
    vim.api.nvim_win_set_cursor(0, { math.min(row + 1, vim.api.nvim_buf_line_count(0)), 0 })
end

vim.api.nvim_create_user_command("IPython", function(args) M.open(args.args) end,
    { nargs = "?", desc = "Show an IPython session (by name), or open one" })
vim.api.nvim_create_user_command("IPythonNew", function(args) M.new(args.args ~= "" and args.args or nil) end,
    { nargs = "?", desc = "Start another IPython session" })

vim.api.nvim_create_autocmd("FileType", {
    pattern = "python",
    desc = "IPython send keymap",
    callback = function(args)
        for _, lhs in ipairs({ "<leader><CR>", "<leader>r" }) do
            vim.keymap.set("x", lhs, M.send_selection, { buffer = args.buf, desc = "Run selection in IPython" })
        end
        vim.keymap.set("n", "<leader><CR>", M.send_line_and_advance, { buffer = args.buf, desc = "Run line in IPython, go to next line" })
    end,
})

return M
