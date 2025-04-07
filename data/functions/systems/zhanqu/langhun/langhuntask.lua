-- @system  狼魂要塞任务

module("langhuntask", package.seeall)

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.lhTask then
        var.lhTask = {
            dbTasks = {},
            cjTasks = {},
            updateTime = System.getNowTime(),
        }
    end
    return var.lhTask
end

local function initLHTask(actor, var, conf)
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

--外部接口
function updateDBTaskValue(actor, taskType, param, value)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.langhun) then return end
    if taskcommon.taskTypeHandleType[taskType] ~= taskcommon.eAddType then return end
    local var = getActorVar(actor)
    if not var then return end
    for id, conf in ipairs(LangHunDBTaskConfig) do
        repeat
            if taskType ~= conf.type then break end
            if conf.param[1] ~= -1 and not utils.checkTableValue(conf.param, param) then break end
            local data = var.dbTasks[id]
            if data.status ~= taskcommon.statusType.emDoing then break end
            if taskcommon.getHandleType(taskType) == taskcommon.eAddType then
                data.curValue = data.curValue + value
            elseif taskcommon.getHandleType(taskType) == taskcommon.eCoverType then
                data.curValue = value
            end
            if data.curValue >= conf.target then
                data.status = taskcommon.statusType.emCanAward
            end
            s2cLHDBTaskUpdate(actor, id)
        until(true)
    end
end

function updateCJTaskValue(actor, taskType, param, value)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.langhun) then return end
    local var = getActorVar(actor)
    if not var then return end
    for id, conf in ipairs(LangHunCJTaskConfig) do
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
            s2cLHCJTaskUpdate(actor, id)
        until(true)
    end
end

--重置玩家数据
function reSetLHTask(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local dbTasks = var.dbTasks
    for id, conf in ipairs(LangHunCJTaskConfig) do
        dbTasks[id] = {
            taskId = conf.id,
            taskType = conf.type,
            curValue = 0,
            status = taskcommon.statusType.emDoing,
        }
    end
    var.updateTime = System.getNowTime()
end

----------------------------------------------------------------------------------
--事件处理

local function onInit(actor)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.langhun) then return end
    local var = getActorVar(actor)
    if not var then return end
    
    local dbTasks = var.dbTasks
    for id, config in ipairs(LangHunDBTaskConfig) do
        if not dbTasks[id] then
            initLHTask(actor, dbTasks, config)
        end
    end
    
    local cjTasks = var.cjTasks
    for id, config in ipairs(LangHunCJTaskConfig) do
        if not cjTasks[id] then
            initLHTask(actor, cjTasks, config)
        end
    end
end

local function onLogin(actor)
    s2cLHDBTaskInfo(actor)
    s2cLHCJTaskInfo(actor)
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    if not System.isSameWeek(System.getNowTime(), var.updateTime) then
        reSetLHTask(actor)
    end
    if not login then
        s2cLHDBTaskInfo(actor)
        s2cLHCJTaskInfo(actor)
    end
end

local function onSystemOpen(actor)
    onInit(actor)
    s2cLHDBTaskInfo(actor)
    s2cLHCJTaskInfo(actor)
end

----------------------------------------------------------------------------------
--协议处理
--92-22 狼魂要塞达标任务-任务信息
function s2cLHDBTaskInfo(actor)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.langhun) then return end
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sLanghunCmd_DBTaskInfo)
    if pack == nil then return end
    
    LDataPack.writeInt(pack, #LangHunDBTaskConfig)
    for id, config in ipairs(LangHunDBTaskConfig) do
        local dbTask = var.dbTasks[id]
        LDataPack.writeInt(pack, id)
        LDataPack.writeInt(pack, dbTask.curValue)
        LDataPack.writeChar(pack, dbTask.status)
    end
    LDataPack.flush(pack)
end

--92-23 狼魂要塞达标任务-领奖
local function c2sLHDBTaskReward(actor, packet)
    local id = LDataPack.readInt(packet)
    local conf = LangHunDBTaskConfig[id]
    if not conf then return end
    
    local var = getActorVar(actor)
    if not var then return end
    
    local dbTask = var.dbTasks[id]
    if not dbTask then return end
    
    if dbTask.status ~= taskcommon.statusType.emCanAward then return end
    dbTask.status = taskcommon.statusType.emHaveAward
    actoritem.addItems(actor, conf.rewards, "langhun dabiao Task reward")
    
    s2cLHDBTaskUpdate(actor, id)
end

--92-23 狼魂要塞达标任务-更新单个任务
function s2cLHDBTaskUpdate(actor, id)
    local var = getActorVar(actor)
    if not var then return end
    
    local dbTask = var.dbTasks[id]
    if not dbTask then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sLanghunCmd_UpdateDBTask)
    if pack == nil then return end
    
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, dbTask.curValue)
    LDataPack.writeChar(pack, dbTask.status)
    LDataPack.flush(pack)
end

--92-24 狼魂要塞成就任务-任务信息
function s2cLHCJTaskInfo(actor)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.langhun) then return end
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sLanghunCmd_CJTaskInfo)
    if pack == nil then return end
    
    LDataPack.writeInt(pack, #LangHunCJTaskConfig)
    for id, config in ipairs(LangHunCJTaskConfig) do
        local cjTask = var.cjTasks[id]
        LDataPack.writeInt(pack, id)
        LDataPack.writeInt(pack, cjTask.curValue)
        LDataPack.writeChar(pack, cjTask.status)
    end
    LDataPack.flush(pack)
end

--92-25 狼魂要塞成就任务-领奖
local function c2sLHCJTaskReward(actor, packet)
    local id = LDataPack.readInt(packet)
    local conf = LangHunCJTaskConfig[id]
    if not conf then return end
    
    local var = getActorVar(actor)
    if not var then return end
    
    local cjTask = var.cjTasks[id]
    if not cjTask then return end
    
    if cjTask.status ~= taskcommon.statusType.emCanAward then return end
    cjTask.status = taskcommon.statusType.emHaveAward
    actoritem.addItems(actor, conf.rewards, "langhun chengjiu task reward")
    
    s2cLHCJTaskUpdate(actor, id)
end

--92-25 狼魂要塞成就任务-更新单个任务
function s2cLHCJTaskUpdate(actor, id)
    local var = getActorVar(actor)
    if not var then return end
    
    local cjTask = var.cjTasks[id]
    if not cjTask then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sLanghunCmd_UpdateCJTask)
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
    actorevent.reg(aeNewDayArrive, onNewDay)
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.langhun, onSystemOpen)
    
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cLanghunCmd_DBTaskReward, c2sLHDBTaskReward)
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cLanghunCmd_CJTaskReward, c2sLHCJTaskReward)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.lhTaskClear = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.lhTask = nil
    onInit(actor)
    s2cLHDBTaskInfo(actor)
    s2cLHCJTaskInfo(actor)
end
