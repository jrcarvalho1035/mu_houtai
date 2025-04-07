-- @system  冠军赛任务

module("championtask", package.seeall)

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.championTask then
        var.championTask = {
            cjTasks = {},
        }
    end
    return var.championTask
end

local function initCHTask(actor, var, conf)
    var[conf.id] = {
        taskId = conf.id,
        taskType = conf.type,
        curValue = 0,
        status = taskcommon.statusType.emDoing,
    }
    local data = var[conf.id]
    
    if taskcommon.getHandleType(conf.type) == taskcommon.eCoverType then
        local record = taskevent.getRecord(actor)
        if taskevent.needParam(conf.type) then
            if record[conf.type] == nil then
                data.curValue = 0
            else
                local value = 0
                for k, v in pairs(conf.param) do
                    if record[conf.type][v] then
                        value = math.max(record[conf.type][v], value)
                    end
                end
                data.curValue = value
            end
        else
            data.curValue = record[conf.type] or taskevent.initRecord(conf.type, actor)
        end
        
        if data.curValue >= conf.target then
            data.status = taskcommon.statusType.emCanAward
        end
    end
    return data
end

function updateCJTaskValue(actor, taskType, param, value)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end
    local var = getActorVar(actor)
    if not var then return end
    for id, conf in ipairs(ChampionCJTaskConfig) do
        repeat
            if taskType ~= conf.type then break end
            if conf.param[1] ~= -1 and not utils.checkTableValue(conf.param, param) then break end
            local data = var.cjTasks[id]
            if data.status ~= taskcommon.statusType.emDoing then break end
            if taskcommon.getHandleType(taskType) == taskcommon.eAddType then
                data.curValue = data.curValue + value
            elseif taskcommon.getHandleType(taskType) == taskcommon.eCoverType then
                data.curValue = value
            end
            if data.curValue >= conf.target then
                data.status = taskcommon.statusType.emCanAward
            end
            s2cCHCJTaskUpdate(actor, id)
        until(true)
    end
end

----------------------------------------------------------------------------------
--事件处理

local function onInit(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end
    local var = getActorVar(actor)
    if not var then return end
    
    local cjTasks = var.cjTasks
    for id, config in ipairs(ChampionCJTaskConfig) do
        if not cjTasks[id] then
            initCHTask(actor, cjTasks, config)
        end
    end
end

local function onLogin(actor)
    s2cCHCJTaskInfo(actor)
end

local function onSystemOpen(actor)
    onInit(actor)
    s2cCHCJTaskInfo(actor)
end

----------------------------------------------------------------------------------
--协议处理
--92-56 冠军赛成就任务-任务信息
function s2cCHCJTaskInfo(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_CJTaskInfo)
    if pack == nil then return end
    
    LDataPack.writeInt(pack, #ChampionCJTaskConfig)
    for id, config in ipairs(ChampionCJTaskConfig) do
        local cjTask = var.cjTasks[id]
        LDataPack.writeInt(pack, id)
        LDataPack.writeInt(pack, cjTask.curValue)
        LDataPack.writeChar(pack, cjTask.status)
    end
    LDataPack.flush(pack)
end

--92-57 冠军赛成就任务-领奖
local function c2sCHCJTaskReward(actor, packet)
    local id = LDataPack.readInt(packet)
    local conf = ChampionCJTaskConfig[id]
    if not conf then return end
    
    local var = getActorVar(actor)
    if not var then return end
    
    local cjTask = var.cjTasks[id]
    if not cjTask then return end
    
    if cjTask.status ~= taskcommon.statusType.emCanAward then return end
    cjTask.status = taskcommon.statusType.emHaveAward
    actoritem.addItems(actor, conf.rewards, "champion chengjiu task reward")
    
    s2cCHCJTaskUpdate(actor, id)
end

--92-57 冠军赛成就任务-更新单个任务
function s2cCHCJTaskUpdate(actor, id)
    local var = getActorVar(actor)
    if not var then return end
    
    local cjTask = var.cjTasks[id]
    if not cjTask then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_UpdateCJTask)
    if pack == nil then return end
    
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, cjTask.curValue)
    LDataPack.writeChar(pack, cjTask.status)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    --if System.isBattleSrv() then return end
    
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.champion, onSystemOpen)
    
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cChampionCmd_CJTaskReward, c2sCHCJTaskReward)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.chTaskClear = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.championTask = nil
    onInit(actor)
    s2cCHCJTaskInfo(actor)
end
