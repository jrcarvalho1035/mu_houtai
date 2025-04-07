-- @system  真红boss任务

module("zhenhongtask", package.seeall)

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.zhTask then
        var.zhTask = {}
    end
    return var.zhTask
end

local function initZHTask(actor, conf)
    local var = getActorVar(actor)
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
function updateTaskValue(actor, taskType, param, value)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zhfb) then return end
    local var = getActorVar(actor)
    if not var then return end
    for id, conf in ipairs(ZhenHongTaskConfig) do
        repeat
            if taskType ~= conf.type then break end
            if conf.param[1] ~= -1 and not utils.checkTableValue(conf.param, param) then break end
            local data = var[id]
            if data.status ~= taskcommon.statusType.emDoing then break end
            if taskcommon.getHandleType(taskType) == taskcommon.eAddType then
                data.curValue = data.curValue + value
            elseif taskcommon.getHandleType(taskType) == taskcommon.eCoverType then
                data.curValue = value
            end
            if data.curValue >= conf.target then
                data.status = taskcommon.statusType.emCanAward
            end
            s2cZHTaskUpdate(actor, id)
        until(true)
    end
end

----------------------------------------------------------------------------------
--事件处理
local function onLogin(actor)
    s2cZHTaskInfo(actor)
end

local function onSystemOpen(actor)
    s2cZHTaskInfo(actor)
end

----------------------------------------------------------------------------------
--协议处理
--85-97 真红boss任务-任务信息
function s2cZHTaskInfo(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zhfb) then return end
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.s2cZHBOSS_TaskInfo)
    if pack == nil then return end
    LDataPack.writeInt(pack, #ZhenHongTaskConfig)
    for id, config in ipairs(ZhenHongTaskConfig) do
        local data = var[id]
        if not data then data = initZHTask(actor, config) end
        LDataPack.writeInt(pack, id)
        LDataPack.writeInt(pack, data.curValue)
        LDataPack.writeChar(pack, data.status)
    end
    LDataPack.flush(pack)
end

--85-98 真红boss任务-领奖
local function c2sZHTaskReward(actor, packet)
    local id = LDataPack.readInt(packet)
    local conf = ZhenHongTaskConfig[id]
    if not conf then return end
    
    local var = getActorVar(actor)
    if not var[id] then return end
    
    if var[id].status ~= taskcommon.statusType.emCanAward then return end
    var[id].status = taskcommon.statusType.emHaveAward
    actoritem.addItems(actor, conf.rewards, "zhtask reward")
    
    s2cZHTaskUpdate(actor, id)
end

--85-98 真红boss任务-更新单个任务
function s2cZHTaskUpdate(actor, id)
    local var = getActorVar(actor)
    if not var then return end
    local data = var[id]
    if not data then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.s2cZHBOSS_UpdateTask)
    if pack == nil then return end
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, data.curValue)
    LDataPack.writeChar(pack, data.status)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    if System.isCrossWarSrv() then return end
    actorevent.reg(aeUserLogin, onLogin)
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.zhfb, onSystemOpen)
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.c2sZHBOSS_UpdateTask, c2sZHTaskReward)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.zhTaskClear = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.zhTask = nil
    s2cZHTaskInfo(actor)
end
