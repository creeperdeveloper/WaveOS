-- WaveOS startup.lua
-- エントリポイント: setupチェック → login → desktop

os.loadAPI("wave_data")
os.loadAPI("wave_notify")

local SETUP_FLAG = "wave_setup_done"

local function checkSetup()
    local f = fs.open(SETUP_FLAG, "r")
    if f then
        f.close()
        return true
    end
    return false
end

local function rewriteStartup()
    local f = fs.open("startup", "w")
    f.writeLine('-- WaveOS startup.lua')
    f.writeLine('os.loadAPI("wave_data")')
    f.writeLine('os.loadAPI("wave_notify")')
    f.writeLine('local ok, err = pcall(function()')
    f.writeLine('    if not fs.exists("wave_setup_done") then')
    f.writeLine('        shell.run("wave_setup")')
    f.writeLine('    else')
    f.writeLine('        shell.run("wave_login")')
    f.writeLine('    end')
    f.writeLine('end)')
    f.writeLine('if not ok then')
    f.writeLine('    printError("WaveOS crash: " .. tostring(err))')
    f.writeLine('    sleep(3)')
    f.writeLine('    os.reboot()')
    f.writeLine('end')
    f.close()
end

-- startup.lua自身を書き換えて次回起動から正規版にする
rewriteStartup()

local ok, err = pcall(function()
    if not checkSetup() then
        shell.run("wave_setup")
    else
        shell.run("wave_login")
    end
end)

if not ok then
    printError("WaveOS crash: " .. tostring(err))
    sleep(3)
    os.reboot()
end
