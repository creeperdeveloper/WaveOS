-- wave_apps.lua
-- アプリインストール / アンインストール / 管理

os.loadAPI("wave_data")
os.loadAPI("wave_notify")

local w, h = term.getSize()

local function drawBG()
    paintutils.drawFilledBox(1, 1, w, h, colors.black)
end

local function drawHeader()
    paintutils.drawLine(1, 1, w, 1, colors.lightBlue)
    term.setCursorPos(2, 1)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.lightBlue)
    term.write("  WaveOS AppStore  ")
    term.setCursorPos(w - 5, 1)
    term.setTextColor(colors.white)
    term.write("[Exit]")
end

local function drawAppList(apps, scroll, selected)
    local keys = {}
    for k, _ in pairs(apps) do table.insert(keys, k) end
    table.sort(keys)

    local startY = 3
    local maxVisible = h - 4

    for i, name in ipairs(keys) do
        local idx = i - scroll
        if idx >= 1 and idx <= maxVisible then
            local app = apps[name]
            local y = startY + idx - 1
            local bg = colors.black
            if i == selected then bg = colors.blue end
            paintutils.drawLine(1, y, w, y, bg)
            term.setCursorPos(2, y)
            term.setTextColor(colors.white)
            term.setBackgroundColor(bg)
            term.write(("[%s] %s"):format(app.icon or "?", name))
            term.setCursorPos(w - 12, y)
            term.setTextColor(colors.lightGray)
            term.write(app.file or "")
        end
    end

    return keys
end

local function drawInstallForm()
    local fh = 12
    local fy = math.floor((h - fh) / 2)
    local fw = w - 6
    local fx = 4

    paintutils.drawFilledBox(fx, fy, fx + fw - 1, fy + fh - 1, colors.gray)
    paintutils.drawLine(fx, fy, fx + fw - 1, fy, colors.lightBlue)
    term.setCursorPos(fx + 2, fy)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.lightBlue)
    term.write(" Install New App ")

    local function label(y, txt)
        term.setCursorPos(fx + 2, fy + y)
        term.setTextColor(colors.lightGray)
        term.setBackgroundColor(colors.gray)
        term.write(txt)
    end
    local function field(y, len)
        term.setCursorPos(fx + 2, fy + y)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)
        paintutils.drawLine(fx + 2, fy + y, fx + 2 + len - 1, fy + y, colors.black)
        term.setCursorPos(fx + 2, fy + y)
        return read()
    end

    label(2, "App name:")
    local name = field(3, fw - 4)
    label(5, "File (e.g. myapp):")
    local file = field(6, fw - 4)
    label(8, "Icon char (1 char):")
    local icon = field(9, 3)

    return name, file, icon
end

-- === メイン ===
drawBG()
drawHeader()

local scroll = 0
local selected = 1
local apps = wave_data.getApps()

term.setCursorPos(2, 2)
term.setTextColor(colors.lightGray)
term.setBackgroundColor(colors.black)
term.write("[I]nstall  [D]elete  [R]un  [ESC] Back")

local keys_list = drawAppList(apps, scroll, selected)

while true do
    local e, p1, p2, p3 = os.pullEvent()

    if e == "key" then
        if p1 == keys.up then
            if selected > 1 then selected = selected - 1 end
        elseif p1 == keys.down then
            if selected < #keys_list then selected = selected + 1 end
        elseif p1 == keys.i then
            -- Install
            local name, file, icon = drawInstallForm()
            if name and name ~= "" and file and file ~= "" then
                wave_data.installApp(name, file, icon)
                wave_notify.push("AppStore", "Installed: " .. name, "info")
                apps = wave_data.getApps()
                keys_list = {}
                for k, _ in pairs(apps) do table.insert(keys_list, k) end
                table.sort(keys_list)
            end
            drawBG()
            drawHeader()
            term.setCursorPos(2, 2)
            term.setTextColor(colors.lightGray)
            term.setBackgroundColor(colors.black)
            term.write("[I]nstall  [D]elete  [R]un  [ESC] Back")
        elseif p1 == keys.d then
            -- Delete
            if keys_list[selected] then
                wave_data.uninstallApp(keys_list[selected])
                wave_notify.push("AppStore", "Removed: " .. keys_list[selected], "warn")
                apps = wave_data.getApps()
                keys_list = {}
                for k, _ in pairs(apps) do table.insert(keys_list, k) end
                table.sort(keys_list)
                if selected > #keys_list then selected = #keys_list end
            end
        elseif p1 == keys.r then
            -- Run
            if keys_list[selected] then
                local app = apps[keys_list[selected]]
                if app then shell.run(app.file) end
                drawBG()
                drawHeader()
                term.setCursorPos(2, 2)
                term.setTextColor(colors.lightGray)
                term.setBackgroundColor(colors.black)
                term.write("[I]nstall  [D]elete  [R]un  [ESC] Back")
            end
        elseif p1 == keys.escape then
            break
        end

    elseif e == "mouse_click" then
        -- Exit button
        if p3 == 1 and p2 >= w - 5 then break end
    end

    drawBG()
    drawHeader()
    term.setCursorPos(2, 2)
    term.setTextColor(colors.lightGray)
    term.setBackgroundColor(colors.black)
    term.write("[I]nstall  [D]elete  [R]un  [ESC] Back")
    keys_list = drawAppList(apps, scroll, selected)
end

term.clear()
term.setCursorPos(1, 1)
