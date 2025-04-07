--大师系统
module("dashisystem", package.seeall)

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.dashi then
        var.dashi = {
            level = 1,
            taskProgress = 1,
            stage = 0,
            tasks = {},
            fightStatus = 0,
        }
        initDSTask(actor)
    end
    return var.dashi
end

local function calcAttr(actor, calc)
    local var = getActorVar(actor)
    local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_dashi)
    attrs:Reset()
    
    local baseAttr = {}
    local power = 0
    
    for _, v in ipairs(DaShiStageConfig[var.stage].attrs) do
        baseAttr[v.type] = (baseAttr[v.type] or 0) + v.value
    end
    
    for k, v in pairs(baseAttr) do
        attrs:Set(k, v)
    end
    
    if power > 0 then
        attrs:SetExtraPower(power)
    end
    if calc then
        LActor.reCalcAttr(actor)
    end
end

local function getDSTaskId(actor, index)
    local var = getActorVar(actor)
    if not var then return end
    local taskConfig = DaShiTaskGroupConfig[DaShiLevelConfig[var.level].taskGroup[var.taskProgress]]
    return taskConfig.taskIds[index]
end

local function getDSFbIndex(actor)
    local var = getActorVar(actor)
    if not var then return end
    local taskGroupConfig = DaShiTaskGroupConfig[DaShiLevelConfig[var.level].taskGroup[var.taskProgress]]
    return taskGroupConfig and taskGroupConfig.fbIndex
end

local function checkDSFightStatus(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local taskGroupConfig = DaShiTaskGroupConfig[DaShiLevelConfig[var.level].taskGroup[var.taskProgress]]
    if not taskGroupConfig then return end
    for index in ipairs(taskGroupConfig) do
        local task = var.tasks[index]
        if not task then return end
        if task.status ~= taskcommon.statusType.emHaveAward then return end
    end
    return true
end

function initDSTask(actor)
    local var = getActorVar(actor)
    local taskGroupConfig = DaShiTaskGroupConfig[DaShiLevelConfig[var.level].taskGroup[var.taskProgress]]
    if not taskGroupConfig then return end
    for index, taskId in ipairs(taskGroupConfig.taskIds) do
        if not var.tasks[index] then
            var.tasks[index] = {
                status = 0,
                value = 0,
            }
            
            local task = var.tasks[index]
            local taskconf = DashiTaskConfig[taskId]
            if taskcommon.getHandleType(taskconf.type) == taskcommon.eCoverType then
                local record = taskevent.getRecord(actor)
                if taskevent.needParam(taskconf.type) then
                    if record[taskconf.type] == nil then
                        task.value = 0
                    else
                        local value = 0
                        for _, v in pairs(taskconf.param) do
                            if record[taskconf.type][v] then
                                value = math.max(record[taskconf.type][v], value)
                            end
                        end
                        task.value = value
                    end
                else
                    task.value = record[taskconf.type] or taskevent.initRecord(taskconf.type, actor)
                end
                
                if task.value >= taskconf.target then
                    task.status = taskcommon.statusType.emCanAward
                end
            end
        end
    end
end

--更新任务进度
function updateTaskValue(actor, taskType, param, value)
    local var = getActorVar(actor)
    if not var then return end
    
    local taskGroupConfig = DaShiTaskGroupConfig[DaShiLevelConfig[var.level].taskGroup[var.taskProgress]]
    if not taskGroupConfig then return end
    for idx, taskId in ipairs(taskGroupConfig.taskIds) do
        repeat
            local taskconf = DashiTaskConfig[taskId]
            if not taskconf then break end
            if taskType ~= taskconf.type then break end
            if (taskconf.param[1] ~= -1) and (not utils.checkTableValue(taskconf.param, param)) then
                break
            end
            
            local task = var.tasks[idx]
            if task.status ~= taskcommon.statusType.emDoing then break end
            
            if taskcommon.getHandleType(taskType) == taskcommon.eAddType then
                task.value = task.value + value
            elseif taskcommon.getHandleType(taskType) == taskcommon.eCoverType then
                if task.value >= value then break end
                task.value = value
            end
            
            if task.value >= taskconf.target then
                task.status = taskcommon.statusType.emCanAward
            end
            s2cDSTaskInfo(actor, idx, task.status, task.value)
        until(true)
    end
end

--大师系统-领取任务奖励
function dsGetTaskReward(actor, index)
    local var = getActorVar(actor)
    if not var then return end
    
    local task = var.tasks[index]
    if not task then return end
    
    if task.status ~= taskcommon.statusType.emCanAward then return end
    
    local taskId = getDSTaskId(actor, index)
    if not taskId then return end
    
    local config = DashiTaskConfig[taskId]
    if not config then return end
    
    task.status = taskcommon.statusType.emHaveAward
    actoritem.addItems(actor, config.rewards, "dashi task rewards")
    s2cDSTaskInfo(actor, index, task.status, task.value)
end

--大师系统-挑战副本
function dsFight(actor, fightType)
    if not checkDSFightStatus(actor) then return end
    if not staticfuben.canEnterFuben(actor) then return end
    local fbIndex = getDSFbIndex(actor)
    if not fbIndex then return end
    local fbConfig = DaShiFubenConfig[fbIndex]
    local fbId = fbConfig.fbIds[fightType]
    if not fbId then return end
    
    if fightType == 2 then
        if not actoritem.checkItems(actor, fbConfig.needItems) then
            return
        end
        actoritem.reduceItems(actor, fbConfig.needItems, "dashi fuben")
    end
    
    local hfuben = instancesystem.createFuBen(fbId)
    if hfuben == 0 then return end
    local x, y = utils.getSceneEnterCoor(fbId)
    LActor.enterFuBen(actor, hfuben, 0, x, y)
end

--大师系统-请求飞升
function dsLevelUp(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    if var.fightStatus ~= 1 then return end
    
    local maxTaskProgress = #DaShiLevelConfig[var.level].taskGroup
    local taskProgress = var.taskProgress + 1
    
    if taskProgress > maxTaskProgress then
        if not DaShiLevelConfig[var.level] then return end
        var.level = var.level + 1
        var.taskProgress = 1
    else
        var.taskProgress = taskProgress
    end
    var.tasks = {}
    var.fightStatus = 0
    var.stage = var.stage + 1
    initDSTask(actor)
    calcAttr(actor, true)
    s2cDSLevelUp(actor)
    s2cDashiInfo(actor)
end

----------------------------------------------------------------------------------
--协议处理

--84-70 大师系统-基础信息
function s2cDashiInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local taskGroupConfig = DaShiTaskGroupConfig[DaShiLevelConfig[var.level].taskGroup[var.taskProgress]]
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sDashi_Info)
    if not pack then return end
    
    LDataPack.writeChar(pack, var.level)
    LDataPack.writeChar(pack, var.taskProgress)
    LDataPack.writeInt(pack, var.stage)
    
    if taskGroupConfig then
        LDataPack.writeChar(pack, #taskGroupConfig.taskIds)
        for idx, taskId in ipairs(taskGroupConfig.taskIds) do
            LDataPack.writeChar(pack, idx)
            LDataPack.writeChar(pack, var.tasks[idx].status)
            LDataPack.writeInt(pack, var.tasks[idx].value)
        end
    else
        LDataPack.writeChar(pack, 0)
    end
    LDataPack.writeChar(pack, var.fightStatus)
    LDataPack.flush(pack)
end

--84-71 大师系统-领取任务奖励
local function c2sDSGetTaskReward(actor, pack)
    local index = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.dashi) then return end
    dsGetTaskReward(actor, index)
end

--84-71 大师系统-更新任务状态
function s2cDSTaskInfo(actor, index, status, value)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sDashi_UpdateTaskInfo)
    if not pack then return end
    LDataPack.writeChar(pack, index)
    LDataPack.writeChar(pack, status)
    LDataPack.writeInt(pack, value)
    LDataPack.flush(pack)
end

--84-72 大师系统-挑战副本
local function c2sDSFight(actor, pack)
    local fightType = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.dashi) then return end
    dsFight(actor, fightType)
end

--84-72 大师系统-更新副本挑战状态
function s2cDSFight(actor)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sDashi_Fight)
    if not pack then return end
    
    LDataPack.writeChar(pack, var.fightStatus)
    LDataPack.flush(pack)
end

--84-73 大师系统-请求飞升
local function c2sDSLevelUp(actor, pack)
    local fightType = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.dashi) then return end
    dsLevelUp(actor)
end

--84-73 大师系统-返回飞升
function s2cDSLevelUp(actor)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sDashi_LevelUp)
    if not pack then return end
    
    LDataPack.writeChar(pack, var.level)
    LDataPack.writeChar(pack, var.taskProgress)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function onSystemOpen(actor)
    s2cDashiInfo(actor)
end

local function onInit(actor)
    local var = getActorVar(actor)
    if var.level > 0 then
        LActor.setDashi(actor, var.level)
    end
    
    initDSTask(actor)
    calcAttr(actor, false)
end

local function onLogin(actor)
    s2cDashiInfo(actor)
end

local function onFbWin(ins)
    local actor = ins:getActorList()[1]
    if actor == nil then return end
    local var = getActorVar(actor)
    if not var then return end
    
    local fbIndex = getDSFbIndex(actor)
    local fbConfig = DaShiFubenConfig[fbIndex]
    if not fbConfig then return end
    
    var.fightStatus = 1
    instancesystem.setInsRewards(ins, actor, fbConfig.rewards)
    s2cDSFight(actor)
end

local function onFbLose(ins)
    local actor = ins:getActorList()[1]
    if actor == nil then return end
end

----------------------------------------------------------------------------------
--初始化
local function init()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin, 1)
    
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.dashi, onSystemOpen)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cDashi_GetTaskReward, c2sDSGetTaskReward)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cDashi_Fight, c2sDSFight)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cDashi_LevelUp, c2sDSLevelUp)
    
    for _, fbConfig in pairs(DaShiFubenConfig) do
        for __, fbId in ipairs(fbConfig.fbIds) do
            insevent.registerInstanceWin(fbId, onFbWin)
            --insevent.registerInstanceLose(fbId, onFbLose)
        end
    end
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.gmDSLevelUp = function(actor, args)
    dsLevelUp(actor)
    return true
end

gmCmdHandlers.gmDSFight = function(actor, args)
    local fightType = tonumber(args[1])
    if not fightType then return end
    dsFight(actor, fightType)
    return true
end

gmCmdHandlers.gmDSGet = function(actor, args)
    local index = tonumber(args[1])
    if not index then return end
    dsGetTaskReward(actor, index)
    return true
end

gmCmdHandlers.gmDSFinish = function(actor, args)
    local var = getActorVar(actor)
    for i = 1, 2 do
        if var.tasks[i] then
            var.tasks[i].status = 1
        end
    end
    s2cDashiInfo(actor)
    return true
end


gmCmdHandlers.gmDSClearVar = function(actor, args)
    local var = LActor.getStaticVar(actor)
    var.dashi = nil
    s2cDashiInfo(actor)
    return true
end

gmCmdHandlers.gmDSClearTask = function(actor, args)
    local var = getActorVar(actor)
    var.tasks = {}
    var.fightStatus = 0
    initDSTask(actor)
    s2cDashiInfo(actor)
    return true
end

gmCmdHandlers.gmDSPrint = function(actor, args)
    local var = getActorVar(actor)
    print("**********************************")
    print("var.level =", var.level)
    print("var.taskProgress =", var.taskProgress)
    print("var.fightStatus =", var.fightStatus)
    print("var.stage =", var.stage)
    for i = 1, 2 do
        print("index = ", i)
        print("status = ", var.tasks[i] and var.tasks[i].status or 0)
        print("value = ", var.tasks[i] and var.tasks[i].value or 0)
        print("------------")
    end
    print("**********************************")
    return true
end

