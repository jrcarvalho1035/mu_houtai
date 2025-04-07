--开服活动任务活动

module("subactivity3", package.seeall)

local subType = 3

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.status then var.status = {} end --任务进度
    if not var.values then var.values = {} end
    if not var.jifen then var.jifen = 0 end
    if not var.jifenstatus then var.jifenstatus = 0 end
    return var
end

--记录数据
local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    LDataPack.writeChar(npack, #ActivityType3Config[id])
    local var = getActorVar(actor, id)
    for i = 1, #config do
        LDataPack.writeChar(npack, var.values[i] or 0)
        LDataPack.writeChar(npack, var.status[i] or 0)
    end
    LDataPack.writeShort(npack, var.jifen)
    LDataPack.writeInt(npack, var.jifenstatus)
end

function getLimitReward(actor, pack)
    local actid = LDataPack.readInt(pack)
    local index = LDataPack.readChar(pack)

    if activitymgr.activityTimeIsEnd(actid) then return end   
    local config = ActivityType3exConfig[actid] and ActivityType3exConfig[actid][index]
    if not config then return end
    
    local var = getActorVar(actor, actid)
    if var.jifen < config.jifen then return end
    if System.bitOPMask(var.jifenstatus, index) then return end
    if not actoritem.checkEquipBagSpaceJob(actor, config.rewards) then return end
    
    var.jifenstatus = System.bitOpSetMask(var.jifenstatus, index, true)
    actoritem.addItems(actor, config.rewards, "activity type3 rewards")
    updateXSSJInfo(actor, actid)
end

function updateXSSJInfo(actor, id)
    local var = getActorVar(actor, id)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_LimitLevelInfo)
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, var.jifenstatus)
    LDataPack.flush(pack)
end

--领取奖励
local function onGetReward(actor, config, id, index, record)
    local config = config[id]
    if config[index] == nil then
        return
    end
    
    local var = getActorVar(actor, id)
    if not var.status[index] or var.status[index] ~= taskcommon.statusType.emCanAward then
        return
    end
    if not actoritem.checkEquipBagSpaceJob(actor, config[index].rewards) then
        return
    end
    var.status[index] = taskcommon.statusType.emHaveAward
    var.jifen = var.jifen + config[index].jifen
    actoritem.addItems(actor, config[index].rewards, "activity type3 rewards")
    updateInfo(actor, id)
end

function updateInfo(actor, id)
    local var = getActorVar(actor, id)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Update3)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, #ActivityType3Config[id])
    for k, v in ipairs(ActivityType3Config[id]) do
        LDataPack.writeChar(npack, var.values[k] or 0)
        LDataPack.writeChar(npack, var.status[k] or 0)
    end
    LDataPack.writeShort(npack, var.jifen)
    LDataPack.flush(npack)
end

--更新任务进度
function updateTaskValue(actor, taskType, param, value)
    --if System.isBattleSrv() then return end
    for actid in pairs(ActivityType3Config) do
        if not activitymgr.activityTimeIsEnd(actid) then
            local var = getActorVar(actor, actid)
            for k, v in pairs(ActivityType3Config[actid]) do
                local taskconfig = GuildConveneTaskConfig[v.taskid]
                repeat
                    if taskconfig.type ~= taskType then break end
                    if (taskconfig.param[1] ~= -1) and (not utils.checkTableValue(taskconfig.param, param)) then --有-1时不对参数做验证
                        break
                    end
                    if (var.status[k] or 0) >= taskcommon.statusType.emCanAward then break end
                    
                    local change = false
                    if taskcommon.getHandleType(taskType) == taskcommon.eAddType then
                        var.values[k] = (var.values[k] or 0) + value
                        change = true
                    elseif taskcommon.getHandleType(taskType) == taskcommon.eCoverType then
                        if value > (var.values[k] or 0) then
                            var.values[k] = value
                            change = true
                        end
                    end
                    
                    if change then
                        if var.values[k] >= taskconfig.target then
                            var.status[k] = taskcommon.statusType.emCanAward
                        end
                        updateInfo(actor, actid)
                    end
                until(true)
            end
        end
    end
end

--登录
subactivitymgr.actorLoginFuncs[subType] = function(actor, type, id)
    if activitymgr.activityTimeIsOver(id) then return end
    local var = getActorVar(actor, id)
    for k, v in pairs(ActivityType3Config[id]) do
        local taskconfig = GuildConveneTaskConfig[v.taskid]
        repeat
            local tp = taskconfig.type
            if taskcommon.getHandleType(tp) ~= taskcommon.eCoverType then
                break
            end
            if (var.status[k] or 0) ~= taskcommon.statusType.emDoing then
                break
            end
            local record = taskevent.getRecord(actor)
            local value = 0
            if taskevent.needParam(tp) then
                if record[tp] == nil then record[tp] = {} end
                value = 0
                for k, v in pairs(taskconfig.param) do
                    if record[tp][v] then value = record[tp][v]break end
                end
            else
                value = record[tp] or taskevent.initRecord(tp, actor)
            end
            if value == 0 then
                break
            end
            var.values[k] = value
            if var.values[k] >= taskconfig.target then
                var.status[k] = taskcommon.statusType.emCanAward
            end
            updateInfo(actor, id)
        until(true)
    end
    if ActivityType3Config[id][1].jifen ~= 0 then
        updateXSSJInfo(actor, id)
    end
end

function onAfterNewDay(actor)
    for id, v in pairs(ActivityType3Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            updateInfo(actor, id)
        end
    end
end

function onTimeOut(id, config, actor, record)
    local var = getActorVar(actor, id)
    var = LActor.getEmptyStaticVar()
end

function onActivityFinish(id)
    local config = ActivityType3Config
    local actors = System.getOnlineActorList()
    if actors then
        for i = 1, #actors do
            local actor = actors[i]
            local var = activitymgr.getStaticData(actor)
            local record = var.records[id]
            onTimeOut(id, config, actor, record)
        end
    end
end

subactivitymgr.regWriteRecordFunc(subType, writeRecord)
subactivitymgr.regGetRewardFunc(subType, onGetReward)
subactivitymgr.regNewDayAfterFunc(subType, onAfterNewDay)
--subactivitymgr.regActivityFinish(subType, onActivityFinish)
subactivitymgr.regTimeOut(subType, onTimeOut)

netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_GetLimitLevel, getLimitReward)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.jifen3 = function (actor, args)
    local count = tonumber(args[1]) or 0
    for actid in pairs(ActivityType3Config) do
        if not activitymgr.activityTimeIsEnd(actid) then
            local var = getActorVar(actor, actid)
            var.jifen = var.jifen + count
            updateInfo(actor, actid)
        end
    end
    return true
end

