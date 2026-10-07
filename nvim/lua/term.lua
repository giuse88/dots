-- Named terminal sessions (IPython consoles, shells) that share one right-hand
-- pane. Only one is visible at a time; <C-n>/<C-p> inside the pane cycles them.
local M = {}

M.width_fraction = 0.4
M.sessions = {} -- ordered list of { name, buf, chan, kind }

function M.style_win(win)
    for opt, val in pairs({ number = false, relativenumber = false, list = false, signcolumn = "no", scrolloff = 0, winfixwidth = true }) do
        vim.api.nvim_set_option_value(opt, val, { win = win, scope = "local" })
    end
    vim.api.nvim_win_set_width(win, math.floor(vim.o.columns * M.width_fraction))
end

-- jj and <Esc><Esc> leave terminal mode (a single <Esc> still goes to the program),
-- q hides the pane while the job keeps running
function M.setup_buf(buf)
    for _, lhs in ipairs({ "<Esc><Esc>", "jj" }) do
        vim.keymap.set("t", lhs, [[<C-\><C-n>]], { buffer = buf, desc = "Back to normal mode" })
    end
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, desc = "Hide terminal (keeps running)" })
end

local function alive(s)
    return s.buf ~= nil and vim.api.nvim_buf_is_valid(s.buf) and vim.fn.jobwait({ s.chan }, 0)[1] == -1
end

-- live sessions, in creation order (also prunes dead ones)
function M.list(kind)
    local live = {}
    for _, s in ipairs(M.sessions) do
        if alive(s) then
            live[#live + 1] = s
        end
    end
    M.sessions = live
    if not kind then
        return live
    end
    return vim.tbl_filter(function(s) return s.kind == kind end, live)
end

function M.get(name)
    for _, s in ipairs(M.list()) do
        if s.name == name then return s end
    end
end

function M.next_name(prefix)
    local n = 1
    while M.get(prefix .. n) do
        n = n + 1
    end
    return prefix .. n
end

-- the window in this tab showing any terminal: our shared right-hand pane
function M.pane_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "terminal" then
            return win
        end
    end
end

function M.session_of_buf(buf)
    for _, s in ipairs(M.list()) do
        if s.buf == buf then return s end
    end
end

function M.visible()
    local win = M.pane_win()
    return win and M.session_of_buf(vim.api.nvim_win_get_buf(win)) or nil
end

-- show a session in the pane (opening the pane if needed); focus stays put
function M.show(session)
    local src = vim.api.nvim_get_current_win()
    local win = M.pane_win()
    if win then
        vim.api.nvim_win_set_buf(win, session.buf)
    else
        vim.cmd("vertical rightbelow sbuffer " .. session.buf)
        win = vim.api.nvim_get_current_win()
    end
    M.style_win(win)
    if vim.api.nvim_win_is_valid(src) then
        vim.api.nvim_set_current_win(src)
    end
    return win
end

local function forget(session)
    local win = vim.fn.bufwinid(session.buf)
    M.sessions = vim.tbl_filter(function(s) return s ~= session end, M.sessions)
    local live = M.list()
    vim.schedule(function()
        if win ~= -1 and vim.api.nvim_win_is_valid(win) then
            if #live > 0 then
                vim.api.nvim_win_set_buf(win, live[1].buf) -- fall back to another session
                M.style_win(win)
            elseif #vim.api.nvim_list_wins() > 1 then
                vim.api.nvim_win_close(win, true)
            end
        end
        if vim.api.nvim_buf_is_valid(session.buf) then
            pcall(vim.api.nvim_buf_delete, session.buf, { force = true })
        end
    end)
end

-- start `cmd` as a new named session, shown in the pane
function M.create(name, cmd, opts)
    opts = opts or {}
    local src = vim.api.nvim_get_current_win()
    local win = M.pane_win()
    if win then
        vim.api.nvim_set_current_win(win)
        vim.cmd("enew")
    else
        vim.cmd("vertical rightbelow new")
        win = vim.api.nvim_get_current_win()
    end
    local chan = vim.fn.jobstart(cmd, { term = true })
    local session = { name = name, buf = vim.api.nvim_get_current_buf(), chan = chan, kind = opts.kind or "shell" }
    M.sessions[#M.sessions + 1] = session
    M.style_win(win)
    M.setup_buf(session.buf)
    vim.api.nvim_create_autocmd("TermClose", {
        buffer = session.buf,
        desc = "Forget session when its program exits",
        callback = function() forget(session) end,
    })
    if vim.api.nvim_win_is_valid(src) then
        vim.api.nvim_set_current_win(src)
    end
    return session
end

-- rename a session; names stay unique so :IPython <name> keeps working
function M.rename(session, name)
    if not session then
        vim.notify("no terminal session to rename", vim.log.levels.ERROR)
        return false
    end
    name = vim.trim(name or "")
    if name == "" then
        vim.notify("rename needs a new name", vim.log.levels.ERROR)
        return false
    end
    local taken = M.get(name)
    if taken and taken ~= session then
        vim.notify("a session named '" .. name .. "' already exists", vim.log.levels.ERROR)
        return false
    end
    session.name = name
    pcall(function() require("winbar").refresh() end)
    return true
end

-- cycle which session the pane shows
function M.cycle(delta)
    local live = M.list()
    if #live < 2 then
        return
    end
    local current = M.visible()
    local idx = 1
    for i, s in ipairs(live) do
        if s == current then idx = i end
    end
    return M.show(live[(idx - 1 + delta) % #live + 1])
end

return M
