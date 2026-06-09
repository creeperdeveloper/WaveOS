-- wave_settings.lua
-- システム設定: 壁紙・タスクバー・ユーザー管理・パスワード変更

os.loadAPI("wave_data")
os.loadAPI("wave_notify")

local username = ...
local w, h = term.getSize()

local function drawBG()
    paintutils.drawFilledBox(1, 1, w, h, colors.black)
end

local function drawHeader(title)
    paintutils.drawLine(1, 1, w, 1, colors.lightBlue)
    term.setCursorPos(2, 1)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.lightBlue)
    term.write("  Settings: " .. title)
    term.setCursorPos(w - 5, 1)
    term.write("[Exit]")
end

local function sideMenu(selected)
    local items = {
        "Personalize",
        "Users",
        "Change Password",
        "About",
    }
    local sw = 18
    paintutils.drawFilledBox(1, 2, sw, h, colors.gray)
    for i, item in ipairs(items) do
        local y = i + 2
        local bg = colors.gray
        if i == selected then bg = colors.blue end
        paintutils.drawLine(1, y, sw, y, bg)
        term.setCursorPos(2, y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(bg)
        term.write(item)
    end
    return items, sw
end

-- ========================
-- ページ: Personalize
-- ========================
local colorOptions = {
    { name = "Blue",      val = colors.blue      },
    { name = "Cyan",      val = colors.cyan      },
    { name = "Green",     val = colors.green     },
    { name = "Purple",    val = colors.purple    },
    { name = "Red",       val = colors.red       },
    { name = "Orange",    val = colors.orange    },
    { name = "Black",     val = colors.black     },
    { name = "Gray",      val = colors.gray      },
}

local function drawPersonalize(sw)
    local px = sw + 2
    local settings = wave_data.getSettings()

    term.setCursorPos(px, 3)
    term.setTextColor(colors.lightGray)
    term.setBackgroundColor(colors.black)
    term.write("Wallpaper Color:")

    local row = 4
    for i, c in ipairs(colorOptions) do
        local x = px + (i - 1) * 5
        if i > 4 then
            x = px + (i - 5) * 5
            row = 5
        end
        paintutils.drawPixel(x, row, c.val)
        paintutils.drawPixel(x + 1, row, c.val)
        if c.val == settings.wallpaper_color then
            term.setCursorPos(x, row)
            term.setBackgroundColor(c.val)
            term.setTextColor(colors.white)
            term.write("[]")
        end
    end

    term.setCursorPos(px, 7)
    term.setTextColor(colors.lightGray)
    term.setBackgroundColor(colors.black)
    term.write("Taskbar Color:")

    row = 8
    for i, c in ipairs(colorOptions) do
        local x = px + (i - 1) * 5
        if i > 4 then
            x = px + (i - 5) * 5
            row = 9
        end
        paintutils.drawPixel(x, row, c.val)
        paintutils.drawPixel(x + 1, row, c.val)
        if c.val == settings.taskbar_color then
            term.setCursorPos(x, row)
            term.setBackgroundColor(c.val)
            term.setTextColor(colors.white)
            term.write("[]")
        end
    end

    term.setCursorPos(px, 11)
    term.setTextColor(colors.lightGray)
    term.setBackgroundColor(colors.black)
    term.write("(Click a color to apply)")
end

-- ========================
-- ページ: Users
-- ========================
local function drawUsers(sw)
    local px = sw + 2
    local users = wave_data.getUsers()
    local y = 3
    term.setCursorPos(px, y)
    term.setTextColor(colors.lightGray)
    term.setBackgroundColor(colors.black)
    term.write("User accounts:")
    y = y + 1
    for name, info in pairs(users) do
        y = y + 1
        term.setCursorPos(px, y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)
        term.write(name .. " [" .. (info.role or "user") .. "]")
        if name ~= username then
            term.setCursorPos(px + 22, y)
            term.setTextColor(colors.red)
            term.write("[Del]")
        end
    end

    -- 新規ユーザー追加
    y = y + 2
    paintutils.drawLine(px, y, w - 1, y, colors.gray)
    term.setCursorPos(px, y)
    term.setTextColor(colors.lime)
    term.setBackgroundColor(colors.gray)
    term.write("[+] Add User")

    return y, users
end

-- ========================
-- ページ: Change Password
-- ========================
local function drawChangePassword(sw)
    local px = sw + 2
    term.setCursorPos(px, 3)
    term.setTextColor(colors.lightGray)
    term.setBackgroundColor(colors.black)
    term.write("Change password for: " .. username)

    local function field(y, label, masked)
        term.setCursorPos(px, y)
        term.setTextColor(colors.lightGray)
        term.setBackgroundColor(colors.black)
        term.write(label)
        term.setCursorPos(px, y + 1)
        paintutils.drawLine(px, y + 1, w - 2, y + 1, colors.gray)
        term.setCursorPos(px, y + 1)
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
        if masked then
            local result = ""
            while true do
                term.setCursorPos(px, y + 1)
                paintutils.drawLine(px, y + 1, w - 2, y + 1, colors.gray)
                term.setCursorPos(px, y + 1)
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.white)
                term.write(string.rep("*", #result))
                local e, key = os.pullEvent("key")
                if key == keys.enter then break
                elseif key == keys.backspace then
                    if #result > 0 then result = result:sub(1, -2) end
                else
                    local ch = keys.getName(key)
                    if ch and #ch == 1 then result = result .. ch end
                end
            end
            return result
        else
            return read()
        end
    end

    local old = field(5, "Current password:", true)
    local new1 = field(8, "New password:", true)
    local new2 = field(11, "Confirm new:", true)

    if wave_data.verifyUser(username, wave_data.hashPassword(old)) then
        if new1 == new2 and #new1 > 0 then
            wave_data.saveUser(username, wave_data.hashPassword(new1), wave_data.getUserRole(username))
            wave_notify.push("Settings", "Password changed successfully", "info")
            term.setCursorPos(px, 14)
            term.setTextColor(colors.lime)
            term.setBackgroundColor(colors.black)
            term.write("Password updated! Press any key.")
        else
            term.setCursorPos(px, 14)
            term.setTextColor(colors.red)
            term.setBackgroundColor(colors.black)
            term.write("Passwords don't match! Press any key.")
        end
    else
        term.setCursorPos(px, 14)
        term.setTextColor(colors.red)
        term.setBackgroundColor(colors.black)
        term.write("Wrong current password! Press any key.")
    end
    os.pullEvent("key")
end

-- ========================
-- ページ: About
-- ========================
local function drawAbout(sw)
    local px = sw + 2
    local info = {
        "WaveOS v1.0",
        "Built for CC: Tweaked",
        "",
        "Features:",
        "  Login system",
        "  Setup wizard",
        "  App installer",
        "  Notification center",
        "  Personalization",
        "  User management",
        "",
        "paintutils-powered UI",
    }
    for i, line in ipairs(info) do
        term.setCursorPos(px, 2 + i)
        term.setTextColor(i == 1 and colors.cyan or colors.white)
        term.setBackgroundColor(colors.black)
        term.write(line)
    end
end

-- ========================
-- メインループ
-- ========================
local page = 1
local running = true

drawBG()
local pageNames = {"Personalize", "Users", "Change Password", "About"}
drawHeader(pageNames[page])
local _, sw = sideMenu(page)

local function renderPage()
    -- 右ペイン消去
    paintutils.drawFilledBox(sw + 1, 2, w, h, colors.black)
    if page == 1 then drawPersonalize(sw)
    elseif page == 2 then drawUsers(sw)
    elseif page == 3 then drawChangePassword(sw)
    elseif page == 4 then drawAbout(sw)
    end
end

renderPage()

while running do
    local e, p1, p2, p3 = os.pullEvent()

    if e == "key" then
        if p1 == keys.escape then running = false end

    elseif e == "mouse_click" then
        -- Exitボタン
        if p3 == 1 and p2 >= w - 5 then
            running = false

        -- サイドメニュー
        elseif p2 >= 1 and p2 <= sw and p3 >= 3 and p3 <= 6 then
            local idx = p3 - 2
            if idx >= 1 and idx <= 4 then
                page = idx
                drawBG()
                drawHeader(pageNames[page])
                sideMenu(page)
                renderPage()
            end

        -- Personalize: カラー選択
        elseif page == 1 then
            local px = sw + 2
            -- Wallpaper row 4-5
            for i, c in ipairs(colorOptions) do
                local row = (i <= 4) and 4 or 5
                local x = px + ((i <= 4) and (i - 1) or (i - 5)) * 5
                if p3 == row and p2 >= x and p2 <= x + 1 then
                    wave_data.saveSetting("wallpaper_color", c.val)
                end
                local row2 = (i <= 4) and 8 or 9
                local x2 = px + ((i <= 4) and (i - 1) or (i - 5)) * 5
                if p3 == row2 and p2 >= x2 and p2 <= x2 + 1 then
                    wave_data.saveSetting("taskbar_color", c.val)
                end
            end
            renderPage()
        end
    end
end

term.clear()
term.setCursorPos(1, 1)
