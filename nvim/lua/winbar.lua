-- A small list at the top of each window: open files in code windows,
-- terminal sessions in the right-hand pane (native 'winbar', no plugin)
local M = {}

function M.file_buffers()
    local out = {}
    for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        if vim.bo[info.bufnr].buftype == "" and info.name ~= "" then
            out[#out + 1] = info.bufnr
        end
    end
    return out
end

-- mouse click on a name switches the window to it
function M.click(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_set_current_buf(bufnr)
    end
end

local function entry(index, label, bufnr, active)
    local hl = active and "%#TabLineSel#" or "%#TabLine#"
    return string.format("%%%d@v:lua.require'winbar'.click@%s %d %s %%X", bufnr, hl, index, label)
end

local function render(win)
    local current = vim.api.nvim_win_get_buf(win)
    local parts = {}
    if vim.bo[current].buftype == "terminal" then
        for i, session in ipairs(require("term").list()) do
            parts[#parts + 1] = entry(i, session.name, session.buf, session.buf == current)
        end
    else
        for i, bufnr in ipairs(M.file_buffers()) do
            local label = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
            if vim.bo[bufnr].modified then
                label = label .. " ●"
            end
            parts[#parts + 1] = entry(i, label, bufnr, bufnr == current)
        end
    end
    return table.concat(parts, "%#WinBar#") .. "%#WinBar#%="
end

function M.refresh()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        local wanted = vim.bo[buf].buftype == "terminal" or (vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= "")
        pcall(vim.api.nvim_set_option_value, "winbar", wanted and render(win) or "", { win = win, scope = "local" })
    end
end

-- cycle this window's own list: files in a code window, sessions in the pane
function M.cycle(delta)
    if vim.bo.buftype == "terminal" then
        require("term").cycle(delta)
    else
        local bufs = M.file_buffers()
        if #bufs < 2 then return end
        local current, idx = vim.api.nvim_get_current_buf(), 1
        for i, b in ipairs(bufs) do
            if b == current then idx = i end
        end
        vim.api.nvim_win_set_buf(0, bufs[(idx - 1 + delta) % #bufs + 1])
    end
    M.refresh()
end

-- jump straight to an entry by its number
function M.goto_index(n)
    if vim.bo.buftype == "terminal" then
        local session = require("term").list()[n]
        if session then require("term").show(session) end
    else
        local bufnr = M.file_buffers()[n]
        if bufnr then vim.api.nvim_win_set_buf(0, bufnr) end
    end
    M.refresh()
end

vim.api.nvim_create_autocmd(
    { "BufEnter", "BufAdd", "BufDelete", "BufWritePost", "WinEnter", "WinNew", "WinClosed", "TabEnter", "BufModifiedSet", "TermOpen" },
    { desc = "Refresh winbar lists", callback = vim.schedule_wrap(M.refresh) }
)

return M
