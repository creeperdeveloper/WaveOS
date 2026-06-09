-- wave_login.lua
-- Windows10風ログイン画面

os.loadAPI("wave_data")
os.loadAPI("wave_notify")

local w, h = term.getSize()
local MAX_ATTEMPTS = 5

local function drawBackground()
    -- 背景グラデーション風 (上: darkBlue, 下: blue)
    for y = 1, math.floor(h * 0.6) do
        paintutils.drawLine(1, y, w, y, colors.blue)
    end
    for y = math.floor(h * 0.6) + 1, h do
        paintutils.drawLine(1, y, w, y, colors.lightBlue)
    end
    -- 光の反射っぽいライン
    paintutils.drawLine(1, math.floor(h * 0.5), w, math.floor(h * 0.5), colors.cyan)
end

local function drawClock()
    local t = os.time()
    local formatted = textutils.formatTime(t, false)
    term.setCursorPos(math.floor((w - #formatted) / 2), math.floor(h * 0.2))
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.blue)
    term.write(formatted)
    -- 日付ラベル
    local dayLabel = "In-game time"
    term.setCursorPos(math.floor((w - #dayLabel) / 2), math.floor(h * 0.2) + 1)
    term.setTextColor(colors.lightGray)
    term.write(dayLabel)
end

local function drawUserIcon(cx, cy)
    -- ユーザーアイコン (paintutils)
    paintutils.drawPixel(cx,     cy - 1, colors.white)
    paintutils.drawLine(cx - 1,  cy,     cx + 1, cy,  colors.white)
    paintutils.drawLine(cx - 2,  cy + 1, cx + 2, cy + 1, colors.lightGray)
    paintutils.drawLine(cx - 2,  cy + 2, cx + 2, cy + 2, colors.lightGray)
end

local function drawLoginCard(username)
    local cw = 26
    local ch = 12
    local cx = math.floor((w - cw) / 2)
    local cy = math.floor(h * 0.38)

    -- カード背景
    paintutils.drawFilledBox(cx, cy, cx + cw - 1, cy + ch - 1, colors.black)
    -- 上部ライン (lightBlue)
    paintutils.drawLine(cx, cy, cx + cw - 1, cy, colors.lightBlue)

    -- ユーザーアイコン
    drawUserIcon(math.floor(cx + cw / 2), cy + 2)

    -- ユーザー名
    term.setCursorPos(math.floor(cx + (cw - #username) / 2), cy + 4)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.write(username)

    -- パスワードフィールド
    local fieldX = cx + 2
    local fieldY = cy + 6
    local fieldW = cw - 4
    paintutils.drawLine(fieldX, fieldY, fieldX + fieldW - 1, fieldY, colors.gray)
    term.setCursorPos(fieldX, fieldY)
    term.setTextColor(colors.lightGray)
    term.setBackgroundColor(colors.gray)
    term.write(string.rep(" ", fieldW))
    term.setCursorPos(fieldX, fieldY)
    term.write("Password")

    -- Enterボタン
    local btnX = cx + cw - 8
    local btnY = cy + ch - 2
    paintutils.drawLine(btnX, btnY, btnX + 6, btnY, colors.lightBlue)
    term.setCursorPos(btnX + 1, btnY)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.lightBlue)
    term.write("Login")

    return fieldX, fieldY, fieldW, btnX, btnY
end

local function getPassword(fieldX, fieldY, fieldW)
    paintutils.drawLine(fieldX, fieldY, fieldX + fieldW - 1, fieldY, colors.gray)
    term.setCursorPos(fieldX, fieldY)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    local result = ""
    while true do
        term.setCursorPos(fieldX, fieldY)
        paintutils.drawLine(fieldX, fieldY, fieldX + fieldW - 1, fieldY, colors.gray)
        term.setCursorPos(fieldX, fieldY)
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
end

local function showError(cy, msg)
    term.setCursorPos(math.floor((w - #msg) / 2), cy + 14)
    term.setTextColor(colors.red)
    term.setBackgroundColor(colors.black)
    term.write(msg)
    sleep(1.5)
end

local function getUserList()
    local users = wave_data.getUsers()
    local list = {}
    for k, _ in pairs(users) do
        table.insert(list, k)
    end
    return list
end

-- === メイン ===
local userList = getUserList()
if #userList == 0 then
    -- ユーザーが存在しない → セットアップへ
    shell.run("wave_setup")
    return
end

-- 先頭ユーザー or ownerをデフォルトに
local settings = wave_data.getSettings()
local currentUser = settings.owner or userList[1]

local attempts = 0
local loggedIn = false

while not loggedIn do
    drawBackground()
    drawClock()

    local cy = math.floor(h * 0.38)
    local fieldX, fieldY, fieldW, btnX, btnY = drawLoginCard(currentUser)

    -- イベントループ
    local pw = ""
    local waiting = true
    while waiting do
        local e, p1, p2, p3 = os.pullEvent()
        if e == "mouse_click" then
            -- パスワードフィールドをクリック
            if p3 == fieldY and p2 >= fieldX and p2 <= fieldX + fieldW - 1 then
                pw = getPassword(fieldX, fieldY, fieldW)
                -- そのままログイン試行
                waiting = false
            -- Loginボタン
            elseif p3 == btnY and p2 >= btnX and p2 <= btnX + 6 then
                pw = getPassword(fieldX, fieldY, fieldW)
                waiting = false
            end
        elseif e == "key" then
            if p1 == keys.enter then
                pw = getPassword(fieldX, fieldY, fieldW)
                waiting = false
            end
        end
    end

    local hash = wave_data.hashPassword(pw)
    if wave_data.verifyUser(currentUser, hash) then
        loggedIn = true
    else
        attempts = attempts + 1
        if attempts >= MAX_ATTEMPTS then
            -- ロックアウト
            drawBackground()
            term.setCursorPos(math.floor((w - 30) / 2), math.floor(h / 2))
            term.setTextColor(colors.red)
            term.setBackgroundColor(colors.blue)
            term.write("Too many attempts. Rebooting...")
            sleep(3)
            os.reboot()
        else
            showError(cy, "Wrong password! (" .. attempts .. "/" .. MAX_ATTEMPTS .. ")")
        end
    end
end

wave_notify.push("Login", "Welcome back, " .. currentUser, "info")
shell.run("wave_desktop", currentUser)
