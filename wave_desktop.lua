-- wave_desktop.lua
-- Windows 10風デスクトップ: タスクバー・スタートメニュー・時計・通知センター

os.loadAPI("wave_data")
os.loadAPI("wave_notify")

local username = ...
if not username then
    local settings = wave_data.getSettings()
    username = settings.owner or "User"
end

local w, h = term.getSize()
local running = true
local startMenuOpen = false
local notifyOpen = false

-- 設定読み込み
local settings = wave_data.getSettings()
local wallpaperColor = settings.wallpaper_color or colors.blue
local taskbarColor   = settings.taskbar_color   or colors.black

-- ========================
-- DRAW HELPERS
-- ========================
local function drawWallpaper()
    paintutils.drawFilledBox(1, 1, w, h - 1, wallpaperColor)
    -- 光沢ライン
    paintutils.drawLine(1, math.floor(h * 0.3), w, math.floor(h * 0.3), colors.cyan)
    -- ウォーターマーク
    term.setCursorPos(w - 8, 2)
    term.setTextColor(colors.lightBlue)
    term.setBackgroundColor(wallpaperColor)
    term.write("WaveOS")
end

local function drawTaskbar()
    paintutils.drawLine(1, h, w, h, taskbarColor)

    -- Startボタン
    paintutils.drawLine(1, h, 10, h, colors.lightBlue)
    term.setCursorPos(2, h)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.lightBlue)
    term.write(" Start ")

    -- 時計 (右端)
    local t = os.time()
    local clock = textutils.formatTime(t, false)
    term.setCursorPos(w - #clock - 1, h)
    term.setTextColor(colors.white)
    term.setBackgroundColor(taskbarColor)
    term.write(clock)

    -- 通知アイコン
    local unread = wave_notify.getUnreadCount()
    local notifyIcon = "[ ]"
    if unread > 0 then notifyIcon = "[" .. unread .. "]" end
    term.setCursorPos(w - #clock - #notifyIcon - 3, h)
    term.setTextColor(unread > 0 and colors.yellow or colors.lightGray)
    term.setBackgroundColor(taskbarColor)
    term.write(notifyIcon)

    -- アプリトレイ
    term.setCursorPos(12, h)
    term.setTextColor(colors.lightGray)
    term.setBackgroundColor(taskbarColor)
    term.write(username)
end

-- ========================
-- ICONS (デスクトップ上)
-- ========================
local iconList = {
    { name = "Terminal",  x = 3,  y = 3,  action = function() shell.run("shell") end },
    { name = "AppStore",  x = 3,  y = 6,  action = function() shell.run("wave_apps") end },
    { name = "Settings",  x = 3,  y = 9,  action = function() shell.run("wave_settings", username) end },
    { name = "Files",     x = 3,  y = 12, action = function() shell.run("list") end },
}

-- アプリリストからアイコン追加
local function loadAppIcons()
    local apps = wave_data.getApps()
    local startX, startY = 3, 16
    for name, info in pairs(apps) do
        table.insert(iconList, {
            name   = name,
            x      = startX,
            y      = startY,
            action = function() shell.run(info.file) end,
        })
        startY = startY + 3
    end
end

local function drawIcons()
    for _, icon in ipairs(iconList) do
        -- アイコンボックス
        paintutils.drawPixel(icon.x, icon.y, colors.white)
        paintutils.drawPixel(icon.x + 1, icon.y, colors.lightGray)
        term.setCursorPos(icon.x, icon.y + 1)
        term.setTextColor(colors.white)
        term.setBackgroundColor(wallpaperColor)
        local label = icon.name
        if #label > 8 then label = label:sub(1, 7) .. "." end
        term.write(label)
    end
end

-- ========================
-- START MENU
-- ========================
local startMenuItems = {
    { label = "Terminal",  action = function() shell.run("shell") end },
    { label = "AppStore",  action = function() shell.run("wave_apps") end },
    { label = "Settings",  action = function() shell.run("wave_settings", username) end },
    { label = "Files",     action = function() shell.run("list") end },
    { label = "Reboot",    action = function() os.reboot() end },
    { label = "Shutdown",  action = function() os.shutdown() end },
}

local function drawStartMenu()
    local mw = 22
    local mh = #startMenuItems + 4
    local mx = 1
    local my = h - mh - 1

    paintutils.drawFilledBox(mx, my, mx + mw - 1, my + mh - 1, colors.gray)
    paintutils.drawLine(mx, my, mx + mw - 1, my, colors.lightBlue)

    term.setCursorPos(mx + 1, my)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.lightBlue)
    term.write(" WaveOS  ")

    term.setCursorPos(mx + 1, my + 1)
    term.setTextColor(colors.lightGray)
    term.setBackgroundColor(colors.gray)
    term.write("User: " .. username)

    paintutils.drawLine(mx, my + 2, mx + mw - 1, my + 2, colors.black)

    for i, item in ipairs(startMenuItems) do
        local iy = my + 2 + i
        if item.label == "Reboot" or item.label == "Shutdown" then
            paintutils.drawLine(mx, iy - 1, mx + mw - 1, iy - 1, colors.black)
        end
        term.setCursorPos(mx + 2, iy)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.gray)
        term.write(item.label)
    end

    return mx, my, mw, mh
end

-- ========================
-- MAIN LOOP
-- ========================
loadAppIcons()

local function redraw()
    drawWallpaper()
    drawIcons()
    drawTaskbar()
end

redraw()
wave_notify.push("WaveOS", "Desktop ready. Welcome " .. username, "info")

-- タイマー (時計更新用)
local clockTimer = os.startTimer(20)

while running do
    local e, p1, p2, p3 = os.pullEvent()

    if e == "timer" and p1 == clockTimer then
        -- 時計更新
        drawTaskbar()
        clockTimer = os.startTimer(20)

    elseif e == "mouse_click" then
        local btn, x, y = p1, p2, p3

        -- タスクバー: Start
        if y == h and x >= 1 and x <= 10 then
            startMenuOpen = not startMenuOpen
            notifyOpen = false
            redraw()
            if startMenuOpen then
                local mx, my, mw, mh = drawStartMenu()
                -- スタートメニュークリック待ち
                local clicked = false
                while not clicked do
                    local e2, b2, sx, sy = os.pullEvent("mouse_click")
                    if sx >= mx and sx <= mx + mw - 1 and sy > my + 2 then
                        local idx = sy - my - 2
                        if startMenuItems[idx] then
                            startMenuOpen = false
                            redraw()
                            startMenuItems[idx].action()
                            redraw()
                            clicked = true
                        end
                    else
                        startMenuOpen = false
                        redraw()
                        clicked = true
                    end
                end
            end

        -- タスクバー: 通知アイコン
        elseif y == h then
            local t = os.time()
            local clock = textutils.formatTime(t, false)
            local unread = wave_notify.getUnreadCount()
            local notifyIcon = "[" .. (unread > 0 and tostring(unread) or " ") .. "]"
            local notifyX = w - #clock - #notifyIcon - 3
            if x >= notifyX and x <= notifyX + #notifyIcon - 1 then
                redraw()
                wave_notify.showPanel(w, h)
                redraw()
            end

        -- デスクトップアイコンのダブルクリック風 (シングルクリック)
        elseif y < h then
            for _, icon in ipairs(iconList) do
                if (y == icon.y or y == icon.y + 1) and (x >= icon.x and x <= icon.x + 7) then
                    icon.action()
                    redraw()
                    break
                end
            end
        end

    elseif e == "terminate" then
        running = false
    end
end

term.clear()
term.setCursorPos(1, 1)
print("WaveOS session ended.")
