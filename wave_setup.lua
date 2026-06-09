-- wave_setup.lua
-- 初回セットアップウィザード (オーナー名・パスワード設定)

os.loadAPI("wave_data")
os.loadAPI("wave_notify")

local w, h = term.getSize()

local function drawBG()
    paintutils.drawFilledBox(1, 1, w, h, colors.blue)
end

local function drawHeader()
    paintutils.drawLine(1, 1, w, 1, colors.lightBlue)
    term.setCursorPos(math.floor((w - 14) / 2), 1)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.lightBlue)
    term.write("  WaveOS Setup  ")
end

local function drawCard(x, y, cw, ch, title)
    paintutils.drawFilledBox(x, y, x + cw - 1, y + ch - 1, colors.black)
    paintutils.drawLine(x, y, x + cw - 1, y, colors.lightBlue)
    term.setCursorPos(x + 2, y)
    term.setTextColor(colors.cyan)
    term.setBackgroundColor(colors.lightBlue)
    term.write(" " .. title .. " ")
end

local function centerText(y, text, fg, bg)
    term.setCursorPos(math.floor((w - #text) / 2) + 1, y)
    term.setTextColor(fg or colors.white)
    term.setBackgroundColor(bg or colors.blue)
    term.write(text)
end

local function inputField(x, y, len, masked)
    paintutils.drawLine(x, y, x + len - 1, y, colors.black)
    term.setCursorPos(x, y)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    if masked then
        -- パスワード: asterisk表示
        local result = ""
        while true do
            term.setCursorPos(x, y)
            paintutils.drawLine(x, y, x + len - 1, y, colors.black)
            term.setCursorPos(x, y)
            term.setBackgroundColor(colors.black)
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
        local r = read()
        return r
    end
end

local function step1_welcome()
    drawBG()
    drawHeader()
    local cw, ch = w - 10, 16
    local cx, cy = math.floor((w - cw) / 2), math.floor((h - ch) / 2)
    drawCard(cx, cy, cw, ch, "Welcome to WaveOS")
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    centerText(cy + 3, "Thank you for installing WaveOS.", colors.white, colors.black)
    centerText(cy + 5, "This wizard will guide you through", colors.lightGray, colors.black)
    centerText(cy + 6, "the initial configuration.", colors.lightGray, colors.black)
    centerText(cy + 8, "Version 1.0  /  CC: Tweaked", colors.gray, colors.black)

    -- Next button
    local bx = cx + cw - 14
    local by = cy + ch - 2
    paintutils.drawLine(bx, by, bx + 12, by, colors.lightBlue)
    term.setCursorPos(bx + 2, by)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.lightBlue)
    term.write("[ Next > ]")

    while true do
        local e, btn, x, y = os.pullEvent("mouse_click")
        if y == by and x >= bx and x <= bx + 12 then return end
    end
end

local function step2_owner()
    drawBG()
    drawHeader()
    local cw, ch = w - 10, 16
    local cx, cy = math.floor((w - cw) / 2), math.floor((h - ch) / 2)
    drawCard(cx, cy, cw, ch, "Owner Account")

    term.setCursorPos(cx + 3, cy + 3)
    term.setTextColor(colors.lightGray)
    term.setBackgroundColor(colors.black)
    term.write("Username:")

    local inX = cx + 3
    local inY = cy + 5
    local inLen = cw - 6

    term.setCursorPos(cx + 3, cy + 8)
    term.setTextColor(colors.lightGray)
    term.write("Password:")

    local pwY = cy + 10

    -- username
    paintutils.drawLine(inX, inY, inX + inLen - 1, inY, colors.black)
    term.setCursorPos(inX, inY)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    local username = read()

    -- password (enter to confirm)
    local pw1 = inputField(inX, pwY, inLen, true)

    term.setCursorPos(cx + 3, pwY + 2)
    term.setTextColor(colors.lightGray)
    term.write("Confirm password:")
    local pw2 = inputField(inX, pwY + 3, inLen, true)

    if pw1 ~= pw2 then
        term.setCursorPos(cx + 3, cy + ch - 3)
        term.setTextColor(colors.red)
        term.write("Passwords do not match! Press any key.")
        os.pullEvent("key")
        return step2_owner()
    end
    if #username < 1 then
        term.setCursorPos(cx + 3, cy + ch - 3)
        term.setTextColor(colors.red)
        term.write("Username cannot be empty! Press any key.")
        os.pullEvent("key")
        return step2_owner()
    end

    return username, pw1
end

local function step3_done(username)
    drawBG()
    drawHeader()
    local cw, ch = w - 10, 14
    local cx, cy = math.floor((w - cw) / 2), math.floor((h - ch) / 2)
    drawCard(cx, cy, cw, ch, "Setup Complete")

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lime)
    centerText(cy + 3, "Welcome, " .. username .. "!", colors.lime, colors.black)
    centerText(cy + 5, "WaveOS is ready to use.", colors.white, colors.black)
    centerText(cy + 7, "Press any key to login.", colors.lightGray, colors.black)

    os.pullEvent("key")
end

-- === メイン ===
step1_welcome()
local username, password = step2_owner()

-- ユーザー保存
local hash = wave_data.hashPassword(password)
wave_data.saveUser(username, hash, "admin")
wave_data.saveSetting("owner", username)

-- セットアップ完了フラグを作成
local f = fs.open("wave_setup_done", "w")
f.write(username)
f.close()

wave_notify.push("Setup complete", "Welcome, " .. username, "info")

step3_done(username)

shell.run("wave_login")
