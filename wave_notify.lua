-- wave_notify.lua
-- 通知センター: push / show / clear

local notifications = {}
local MAX = 10

function push(title, body, level)
    level = level or "info"  -- "info" / "warn" / "error"
    table.insert(notifications, 1, {
        title = title,
        body  = body or "",
        level = level,
        time  = os.time(),
        read  = false,
    })
    if #notifications > MAX then
        table.remove(notifications, #notifications)
    end
end

function getAll()
    return notifications
end

function getUnreadCount()
    local n = 0
    for _, v in ipairs(notifications) do
        if not v.read then n = n + 1 end
    end
    return n
end

function markAllRead()
    for _, v in ipairs(notifications) do
        v.read = true
    end
end

function clear()
    notifications = {}
end

-- 通知センターウィンドウを描画
function showPanel(w, h)
    local panelW = 26
    local panelH = math.floor(h * 0.8)
    local panelX = w - panelW
    local panelY = 2

    -- 背景
    for y = panelY, panelY + panelH - 1 do
        paintutils.drawLine(panelX, y, w, y, colors.gray)
    end

    -- ヘッダ
    paintutils.drawLine(panelX, panelY, w, panelY, colors.black)
    term.setCursorPos(panelX + 1, panelY)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.write(" Notification Center")

    local list = getAll()
    local y = panelY + 2

    if #list == 0 then
        term.setCursorPos(panelX + 2, y)
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.lightGray)
        term.write("No notifications")
    else
        for i, n in ipairs(list) do
            if y >= panelY + panelH - 1 then break end

            local bg = colors.gray
            local fg = colors.white
            if n.level == "warn"  then fg = colors.yellow end
            if n.level == "error" then fg = colors.red    end
            if not n.read         then bg = colors.lightGray end

            paintutils.drawLine(panelX, y, w, y, bg)
            term.setCursorPos(panelX + 1, y)
            term.setBackgroundColor(bg)
            term.setTextColor(fg)
            local title = n.title
            if #title > panelW - 2 then title = title:sub(1, panelW - 4) .. ".." end
            term.write(" " .. title)

            if n.body ~= "" then
                y = y + 1
                if y < panelY + panelH - 1 then
                    paintutils.drawLine(panelX, y, w, y, bg)
                    term.setCursorPos(panelX + 2, y)
                    term.setTextColor(colors.lightGray)
                    local body = n.body
                    if #body > panelW - 3 then body = body:sub(1, panelW - 5) .. ".." end
                    term.write(body)
                end
            end

            y = y + 2
            n.read = true
        end
    end

    -- フッタ: [Clear]
    paintutils.drawLine(panelX, panelY + panelH - 1, w, panelY + panelH - 1, colors.black)
    term.setCursorPos(panelX + 2, panelY + panelH - 1)
    term.setTextColor(colors.lightBlue)
    term.setBackgroundColor(colors.black)
    term.write("[Clear All]")

    -- クリック待ち
    while true do
        local e, btn, x, y2 = os.pullEvent("mouse_click")
        if x >= panelX and x <= w and y2 == panelY + panelH - 1 then
            clear()
            return
        elseif x < panelX or y2 == panelY then
            return
        end
    end
end
