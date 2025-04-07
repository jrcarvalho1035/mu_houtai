--狂欢派对

module("subactivity39", package.seeall)

local subType = 39

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.status then var.status = 0 end
    if not var.tasks then var.tasks = {} end
    if not var.progress then var.progress = 0 end
    if not var.recharge then var.recharge = 0 end
    if not var.progressPoint then var.progressPoint = 0 end
    if not var.progressRewards then var.progressRewards = {} end
    return var
end

function isActivity39(count)
    for _, config in pairs(ActivityType39Config) do
        if config.itemId == count then
            return true
        end
    end
    return false
end

function buy(actorid, count)
    local actor = LActor.getActorById(actorid)
    if actor then
        Act39Buy(actor, count)
    else
        local npack = LDataPack.allocPacket()
        LDataPack.writeInt(npack, count)
        System.sendOffMsg(actorid, 0, OffMsgType_Activity39, npack)
    end
end

function Act39Buy(actor, count)
    for actId, config in pairs(ActivityType39Config) do
        repeat
            if activitymgr.activityTimeIsEnd(actId) then break end
            if config.itemId ~= count then break end
            
            local var = getActorVar(actor, actId)
            if not var then break end
            
            if var.status ~= 0 then
                print("act39.Act39Buy: can't buy actId =", actId, "status = ", var.status)
                break
            end
            
            rechargesystem.addVipExp(actor, count)
            var.status = 1
            print("subactivity39.Act39Buy: actId =", actId)
            s2cAct39UpdateInfo(actor, actId)
        until true
    end
end

--更新任务进度
function updateTaskValue(actor, taskType, param, value)
    if taskcommon.taskTypeHandleType[taskType] ~= taskcommon.eAddType then return end
    for actid, config in pairs(ActivityType39TaskConfig) do
        if not activitymgr.activityTimeIsEnd(actid) then
            local var = getActorVar(actor, actid)
            if var.status == 0 then break end
            for index, conf in ipairs(config) do
                local taskconfig = Act39TaskConfig[conf.taskid]
                repeat
                    if taskconfig.type ~= taskType then break end
                    if (taskconfig.param[1] ~= -1) and (not utils.checkTableValue(taskconfig.param, param)) then --有-1时不对参数做验证
                        break
                    end
                    
                    if not var.tasks[index] then
                        var.tasks[index] = {
                            status = 0,
                            value = 0,
                        }
                    end
                    local task = var.tasks[index]
                    if task.status ~= taskcommon.statusType.emDoing then break end
                    task.value = task.value + value
                    if task.value >= taskconfig.target then
                        task.status = taskcommon.statusType.emCanAward
                    end
                    s2cUpdateAct39TaskInfo(actor, actid, index)
                until(true)
            end
        end
    end
end

----------------------------------------------------------------------------------
--协议处理
--71-100 活动数据
function s2cAct39Info(actor, id)
    local var = getActorVar(actor, id)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Act39Info)
    if not pack then return end
    
    LDataPack.writeInt(pack, id)
    LDataPack.writeChar(pack, var.status)
    LDataPack.writeInt(pack, var.progressPoint)
    LDataPack.writeChar(pack, var.progress)
    LDataPack.writeChar(pack, #ActivityType39EXConfig[id])
    for idx in ipairs(ActivityType39EXConfig[id]) do
        LDataPack.writeChar(pack, var.progressRewards[idx] or 0)
    end
    LDataPack.writeChar(pack, #ActivityType39TaskConfig[id])
    for idx in ipairs(ActivityType39TaskConfig[id]) do
        local task = var.tasks[idx]
        local status = task and task.status or 0
        local value = task and task.value or 0
        LDataPack.writeChar(pack, status)
        LDataPack.writeInt(pack, value)
    end
    LDataPack.flush(pack)
end

--71-101 派对大奖领取
local function c2sAct39GetReward(actor, pack)
    local id = LDataPack.readInt(pack)
    if activitymgr.activityTimeIsEnd(id) then return end

    local config = ActivityType39Config[id]
    if not config then return end
    
    local var = getActorVar(actor, id)
    if not var then return end
    
    local status = var.status
    if status ~= 1 then return end
    
    if not actoritem.checkEquipBagSpaceJob(actor, config.rewards) then
        return
    end
    
    for index in ipairs(ActivityType39TaskConfig[id]) do
        local task = var.tasks[index]
        if not task then return end
        if task.status == taskcommon.statusType.emDoing then return end
    end
    
    status = 2
    var.status = status
    actoritem.addItems(actor, config.rewards, "activity type39 rewards")
    s2cAct39GetReward(actor, id, status)
end

--71-101 派对大奖领取返回
function s2cAct39GetReward(actor, id, status)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Act39GetReward)
    if not pack then return end
    
    LDataPack.writeInt(pack, id)
    LDataPack.writeChar(pack, status)
    LDataPack.flush(pack)
end

--71-102 任务奖励领取
local function c2sAct39GetTaskReward(actor, pack)
    local id = LDataPack.readInt(pack)
    local index = LDataPack.readChar(pack)
    if activitymgr.activityTimeIsEnd(id) then return end

    local config = ActivityType39TaskConfig[id] and ActivityType39TaskConfig[id][index]
    if not config then return end
    
    local var = getActorVar(actor, id)
    if not var then return end
    
    local task = var.tasks[index]
    if not task then return end
    
    if task.status ~= taskcommon.statusType.emCanAward then return end
    if not actoritem.checkEquipBagSpaceJob(actor, config.rewards) then
        return
    end
    
    var.progress = var.progress + 1
    task.status = taskcommon.statusType.emHaveAward
    actoritem.addItems(actor, config.rewards, "activity type39 task rewards")
    s2cUpdateAct39TaskInfo(actor, id, index)
    s2cAct39UpdateInfo(actor, id)
end

--71-102 更新任务状态
function s2cUpdateAct39TaskInfo(actor, id, index)
    local var = getActorVar(actor, id)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Act39UpdateTaskInfo)
    if not pack then return end
    
    local task = var.tasks[index]
    local status = task and task.status or 0
    local value = task and task.value or 0
    
    LDataPack.writeInt(pack, id)
    LDataPack.writeChar(pack, index)
    LDataPack.writeChar(pack, status)
    LDataPack.writeInt(pack, value)
    LDataPack.flush(pack)
end

--71-103 阶段奖励领取
local function c2sAct39GetProgressReward(actor, pack)
    local id = LDataPack.readInt(pack)
    local index = LDataPack.readChar(pack)
    if activitymgr.activityTimeIsEnd(id) then return end
    
    local config = ActivityType39EXConfig[id] and ActivityType39EXConfig[id][index]
    if not config then return end
    
    local var = getActorVar(actor, id)
    if not var then return end
    if var.progressRewards[index] == 1 then return end
    if var.progress < config.progress then return end
    
    if not actoritem.checkEquipBagSpaceJob(actor, config.rewards) then
        return
    end
    
    var.progressRewards[index] = 1
    actoritem.addItems(actor, config.rewards, "activity type39 progress rewards")
    s2cAct39GetProgressReward(actor, id, index, 1)
end

--71-103 阶段奖励领取返回
function s2cAct39GetProgressReward(actor, id, index, status)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Act39GetProgressReward)
    if not pack then return end
    
    LDataPack.writeInt(pack, id)
    LDataPack.writeChar(pack, index)
    LDataPack.writeChar(pack, status)
    LDataPack.flush(pack)
end

--71-104 立即完成任务
local function c2sAct39FinishTask(actor, pack)
    local id = LDataPack.readInt(pack)
    local index = LDataPack.readChar(pack)
    
    local config = ActivityType39TaskConfig[id] and ActivityType39TaskConfig[id][index]
    if not config then return end
    
    local var = getActorVar(actor, id)
    if not var then return end
    
    if var.progressPoint <= 0 then return end
    
    local status = var.tasks[index] and var.tasks[index].status or 0
    if status ~= taskcommon.statusType.emDoing then return end
    
    var.progressPoint = var.progressPoint - 1
    local taskConfig = Act39TaskConfig[config.taskid]
    var.tasks[index] = {
        status = taskcommon.statusType.emCanAward,
        value = taskConfig.target,
    }
    
    s2cUpdateAct39TaskInfo(actor, id, index)
    s2cAct39UpdateInfo(actor, id)
end

--71-104 更新活动数据
function s2cAct39UpdateInfo(actor, id)
    local var = getActorVar(actor, id)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Act39UpdateInfo)
    if not pack then return end
    
    LDataPack.writeInt(pack, id)
    LDataPack.writeChar(pack, var.status)
    LDataPack.writeInt(pack, var.progressPoint)
    LDataPack.writeChar(pack, var.progress)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理

local function onLogin(actor, type, id)
    if activitymgr.activityTimeIsOver(id) then return end
    s2cAct39Info(actor, id)
end

local function onAfterNewDay(actor, id)
    if activitymgr.activityTimeIsOver(id) then return end
    s2cAct39Info(actor, id)
end

local function OffMsgAct39Buy(actor, offmsg)
    local count = LDataPack.readInt(offmsg)
    print(string.format("OffMsgAct39Buy actorid:%d count:%d", LActor.getActorId(actor), count))
    Act39Buy(actor, count)
end

local function onRecharge(actor, count)
    for id, config in pairs(ActivityType39Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local var = getActorVar(actor, id)
            if var.status ~= 0 then
                local recharge = var.recharge + count
                local num = math.floor(recharge / config.pay)
                var.recharge = recharge - num * config.pay
                var.progressPoint = var.progressPoint + num
                s2cAct39UpdateInfo(actor, id)
            end
        end
    end
end

local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local v = record and record.data and record.data.rewardsRecord or 0
    LDataPack.writeInt(npack, v)
end

----------------------------------------------------------------------------------
--初始化
function init()
    if System.isLianFuSrv() then return end
    subactivitymgr.regNewDayAfterFunc(subType, onAfterNewDay)
    subactivitymgr.regLoginFunc(subType, onLogin)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    
    msgsystem.regHandle(OffMsgType_Activity39, OffMsgAct39Buy)
    
    actorevent.reg(aeRecharge, onRecharge)
    
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Act39GetReward, c2sAct39GetReward)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Act39GetTaskReward, c2sAct39GetTaskReward)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Act39GetProgressReward, c2sAct39GetProgressReward)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Act39FinishTask, c2sAct39FinishTask)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
-- gmCmdHandlers.act15all = function (actor)
--     for actid, conf in pairs(ActivityType15Config) do
--         if not activitymgr.activityTimeIsEnd(actid) then
--             local var = getActorVar(actor, actid)
--             for k, v in ipairs(conf) do
--                 var.status[k] = 1
--             end
--             sendTaskInfo(actor, actid)
--         end
--     end
--     return true
-- end
