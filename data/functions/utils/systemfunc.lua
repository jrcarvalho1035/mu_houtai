module("systemfunc", package.seeall)

local pTimer = require("base.scripttimer.postscripttimer")

local SAVE_VAR_TIME = 3600 * 1000 * 2 -- 保存系统数据的时间间隔

staticVarMap = staticVarMap or {}

--为加快索引速度添加的临时变量
local staticSystemVar = nil
local staticChatVar = nil
local staticMineVar = nil

--启动后临时动态数据
local systemDyanmicVar = _G.systemDyanmicVar or {}
local function getDyanmicVar()
    return systemDyanmicVar
end

--保存类型
local saveType =
{
    one = 1, --1:起服后，每隔SAVE_VAR_TIME，保存数据
    two = 2, --2:起服后，第一次隔SAVE_VAR_TIME + interval, 保存数据，之后每隔SAVE_VAR_TIME，保存数据
    three = 3, --3:起服后，由系统自己保存数据
}
local staticDataConfig =
{
    ["MINE_VAR"] = {varName = "MINE_VAR", fileName = "runtime/system_mine_%d.bin", saveType = saveType.two, interval = 60 * 1000},
    ["CHAT_VAR"] = {varName = "CHAT_VAR", fileName = "runtime/system_chat_%d.bin", saveType = saveType.one},
    ["SYSTEM_VAR"] = {varName = "SYSTEM_VAR", fileName = "runtime/system_var_%d.bin", saveType = saveType.one},
    ["DART_VAR"] = {varName = "DART_VAR", fileName = "runtime/system_dart_%d.bin", saveType = saveType.two, interval = 60 * 2000},
    ["BATTLE_VAR"] = {varName = "BATTLE_VAR", fileName = "runtime/system_battle_%d.bin", saveType = saveType.two, interval = 60 * 3000},
    ["CAMPBATTLE_VAR"] = {varName = "CAMPBATTLE_VAR", fileName = "runtime/system_campbattle_%d.bin", saveType = saveType.two, interval = 60 * 4000},
    ["HEFUCUP_VAR"] = {varName = "HEFUCUP_VAR", fileName = "runtime/system_hefucup_%d.bin", saveType = saveType.two, interval = 60 * 5000},
}

-- 加载数据
local function loadData(fileName)
    local file = io.open(fileName, "r")
    if file ~= nil then
        local s = file:read("*a")
        local data, err = utils.unserialize(s)
        file:close()
        print(string.format("load %s over", fileName))
        return data, err
    end
    print(string.format("file %s not exist", fileName))
    return {}
end

-- 保存数据
local function saveData(fileName, data, stop)
    if not data then
        print(string.format("save %s err data is nil", fileName))
        return
    end
    local bt = 0
    local et = 0
    bt = os.clock()
    if stop then
        local tmpName = fileName .. '.stop'
        local s = utils.serialize(data)
        local file = io.open(tmpName, "w")
        file:write(s)
        file:close()

        os.remove(fileName)
        local ret, msg = os.rename(tmpName, fileName)
        if ret == nil then
            print('rename fail msg=', msg)
        end
    else
        System.saveFileVar(fileName, data) -- ge -> actormgr
    end
    et = os.clock()
    
    print(string.format("save %s over, cost time:%f", fileName, (et - bt)))
end

function loadStaticVarByName(varName)
    local conf = staticDataConfig[varName]
    if not conf then
        print("lloadStaticVarByName no conf:" .. varName)
        return nil
    end
    
    if staticVarMap[varName] then
        return staticVarMap[varName]
    end
    
    local fileName = string.format(conf.fileName, System.getServerId())
    local loadedData, err = loadData(fileName)
    if loadedData == nil or err then
        print("lloadStaticVarByName fileName:" .. fileName .. " err:" .. err)
        assert(false)
    end
    staticVarMap[varName] = loadedData or {}
    
    return staticVarMap[varName]
end

function saveStaticVarByName(varName, stop)
    local conf = staticDataConfig[varName]
    if not conf then
        print("save varName err no conf:" .. varName)
        return
    end
    
    local staticVar = staticVarMap[varName]
    if not staticVar then
        print("save varName err not load:" .. varName)
    end
    
    local fileName = string.format(conf.fileName, System.getServerId())
    saveData(fileName, staticVar, stop)
end

local function loadAll()
    for varName, conf in pairs(staticDataConfig) do
        loadStaticVarByName(varName)
    end
end

function saveAll()
    for varName, conf in pairs(staticDataConfig) do
        saveStaticVarByName(varName)
    end
end

function saveDart()
    saveStaticVarByName("DART_VAR")
end

local function saveByTypes(...)
    local types = {...}
    for varName, conf in pairs(staticDataConfig) do
        for i = 1, #types do
            if conf.saveType == types[i] then
                saveStaticVarByName(varName, 'stop')
            end
        end
    end
end

local function onIntervalCallBack(varName)
    --print("systemfunc.onIntervalCallBack: varname:" .. varName)
    pTimer.postScriptEvent(nil, SAVE_VAR_TIME, function(...) saveStaticVarByName(varName) end, SAVE_VAR_TIME, -1)
end

local function saveTimer()
    for varName, conf in pairs(staticDataConfig) do
        if conf.saveType == 2 then
            pTimer.postOnceScriptEvent(nil, conf.interval, function(...) onIntervalCallBack(varName) end)
        end
    end
    pTimer.postScriptEvent(nil, SAVE_VAR_TIME, function(...) saveByTypes(saveType.one) end, SAVE_VAR_TIME, -1)
end

local function getStaticVarByName(varName)
    if not staticDataConfig[varName] then
        print("get no conf var:" .. varName)
        return nil
    end
    
    return staticVarMap[varName]
end

local function onGameStart()
    saveTimer()
end

-- 程序退出的时候保存数据
_G.SaveOnGameStop = function()
    saveByTypes(saveType.one, saveType.two)
end

System.getDyanmicVar = getDyanmicVar
System.getStaticVarByName = getStaticVarByName
System.saveStaticVarByName = saveStaticVarByName

System.getStaticVar = function()
    return staticSystemVar
end

System.getStaticChatVar = function()
    return staticChatVar
end

System.getStaticMineVar = function()
    return staticMineVar
end

System.getStaticDartVar = function()
    return staticDartVar
end

System.getStaticGuildBattleVar = function()
    return staticGuildBattleVar
end

System.getStaticCampBattleVar = function()
    return staticCampBattleVar
end

System.getStaticHefuCupVar = function()
    return staticHefuCupVar
end

System.saveStaticDart = function()
    saveDart()
end

System.saveStaticBattle = function()
    saveStaticVarByName("BATTLE_VAR")
end

System.saveStaticCampBattle = function()
    saveStaticVarByName("CAMPBATTLE_VAR")
end

System.saveStaticHefuCup = function()
    saveStaticVarByName("HEFUCUP_VAR")
end

engineevent.regGameStartEvent(onGameStart)

--加载文件时就加载数据
--不少模块和系统都是这样的处理，若通过GameStartEvent处理，需要大量修改
loadAll()
staticSystemVar = staticVarMap["SYSTEM_VAR"]
staticChatVar = staticVarMap["CHAT_VAR"]
staticMineVar = staticVarMap["MINE_VAR"]
staticDartVar = staticVarMap["DART_VAR"]
staticGuildBattleVar = staticVarMap["BATTLE_VAR"]
staticCampBattleVar = staticVarMap["CAMPBATTLE_VAR"]
staticHefuCupVar = staticVarMap["HEFUCUP_VAR"]

