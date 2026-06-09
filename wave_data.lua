-- wave_data.lua
-- ユーザーデータ・設定をJSONライクなテーブルとして保存/読み込み

local DATA_FILE = "wave_users"
local SETTINGS_FILE = "wave_settings_data"
local APPS_FILE = "wave_apps_list"

-- シリアライズ (簡易)
local function serialize(t, indent)
    indent = indent or 0
    local s = "{\n"
    local pad = string.rep("  ", indent + 1)
    for k, v in pairs(t) do
        s = s .. pad
        if type(k) == "string" then
            s = s .. "[\"" .. k .. "\"] = "
        else
            s = s .. "[" .. tostring(k) .. "] = "
        end
        if type(v) == "table" then
            s = s .. serialize(v, indent + 1)
        elseif type(v) == "string" then
            s = s .. "\"" .. v:gsub("\\","\\\\"):gsub("\"","\\\"") .. "\""
        else
            s = s .. tostring(v)
        end
        s = s .. ",\n"
    end
    return s .. string.rep("  ", indent) .. "}"
end

local function saveTable(file, t)
    local f = fs.open(file, "w")
    if not f then return false end
    f.write(serialize(t))
    f.close()
    return true
end

local function loadTable(file)
    if not fs.exists(file) then return {} end
    local f = fs.open(file, "r")
    if not f then return {} end
    local content = f.readAll()
    f.close()
    local fn, err = load("return " .. content)
    if fn then return fn() end
    return {}
end

-- ユーザー管理
function getUsers()
    return loadTable(DATA_FILE)
end

function saveUser(username, passwordHash, role)
    local users = getUsers()
    users[username] = { password = passwordHash, role = role or "user" }
    return saveTable(DATA_FILE, users)
end

function deleteUser(username)
    local users = getUsers()
    users[username] = nil
    return saveTable(DATA_FILE, users)
end

function verifyUser(username, passwordHash)
    local users = getUsers()
    if not users[username] then return false end
    return users[username].password == passwordHash
end

function getUserRole(username)
    local users = getUsers()
    if not users[username] then return nil end
    return users[username].role or "user"
end

-- パスワードハッシュ (簡易チェックサム)
function hashPassword(pw)
    local h = 0
    for i = 1, #pw do
        h = (h * 31 + string.byte(pw, i)) % 0xFFFFFF
    end
    return string.format("%06x", h)
end

-- 設定管理
function getSettings()
    local defaults = {
        wallpaper_color = colors.blue,
        taskbar_color   = colors.black,
        text_color      = colors.white,
        clock_format    = "24h",
        owner           = "WaveOS User",
    }
    local saved = loadTable(SETTINGS_FILE)
    for k, v in pairs(defaults) do
        if saved[k] == nil then saved[k] = v end
    end
    return saved
end

function saveSetting(key, value)
    local s = getSettings()
    s[key] = value
    return saveTable(SETTINGS_FILE, s)
end

-- アプリ管理
function getApps()
    return loadTable(APPS_FILE)
end

function installApp(name, file, icon)
    local apps = getApps()
    apps[name] = { file = file, icon = icon or "?" }
    return saveTable(APPS_FILE, apps)
end

function uninstallApp(name)
    local apps = getApps()
    apps[name] = nil
    return saveTable(APPS_FILE, apps)
end
