--植树节任务活动

module("subactivity15", package.seeall)

local subType = 15

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.status then var.status = {} end --任务进度
    if not var.values then var.values = {} end
    return var
end

--记录数据
local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    LDataPack.writeInt(npack, 0)
end

--领取奖励
local function getZhishuTask(actor, pack)
    local id = LDataPack.readInt(pack)
    local index = LDataPack.readInt(pack)

	local config = ActivityType15Config[id]
    if config[index] == nil then
		return
    end
    
    local var = getActorVar(actor, id)
    if not var.status[index] or var.status[index] ~= 1 then
		return
    end
    
	if not actoritem.checkEquipBagSpaceJob(actor, config[index].rewards) then
		return
	end	
    var.status[index] = taskcommon.statusType.emHaveAward
    actoritem.addItems(actor, config[index].rewards, "activity type15 rewards")
    sendTaskInfo(actor, id)
end

function sendTaskInfo(actor, id)
    local var = getActorVar(actor, id)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_SendZhishuTask)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, #ActivityType15Config[id])
    for k,v in ipairs(ActivityType15Config[id]) do
        LDataPack.writeChar(npack, var.status[k] or 0)
        LDataPack.writeInt(npack, var.values[k] or 0)        
    end
	LDataPack.flush(npack)
end

function updateTaskInfo(actor, id, index)    
    local var = getActorVar(actor, id)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_UpdateZhishuTask)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, index)
    LDataPack.writeChar(npack, var.status[index] or 0)
    LDataPack.writeInt(npack, var.values[index] or 0)
	LDataPack.flush(npack)
end

--更新任务进度
function updateTaskValue(actor, taskType, param, value)
    if taskcommon.taskTypeHandleType[taskType] ~= taskcommon.eAddType then return end
    for actid in pairs(ActivityType15Config) do
        if not activitymgr.activityTimeIsEnd(actid) then
            local var = getActorVar(actor, actid)
            for k,v in pairs(ActivityType15Config[actid]) do
                local taskconfig = Act15TaskConfig[v.taskid]
                repeat
                    if taskconfig.type ~= taskType then break end
                    if (taskconfig.param[1] ~= -1) and (not utils.checkTableValue(taskconfig.param, param)) then --有-1时不对参数做验证
                        break 
                    end
                    if (var.status[k] or 0) >= taskcommon.statusType.emCanAward then break end
                    var.values[k] = (var.values[k] or 0) + value
                    if var.values[k] >= taskconfig.target then
                        var.status[k] = taskcommon.statusType.emCanAward
                    end
                    updateTaskInfo(actor, actid, k)               
                until(true)
            end
        end
    end
end

--登录
subactivitymgr.actorLoginFuncs[subType] = function(actor, type, id)
    if activitymgr.activityTimeIsOver(id) then return end
    sendTaskInfo(actor, id)
end

-- function onTimeOut(id, config, actor, record)
--     local var = getActorVar(actor, id)
--     local itemid = ActivityType15Config[id][1].rewards.id
--     actoritem.reduceItem(actor, itemid, actoritem.getItemCount(actor, itemid), "activity15 recycled:"..id)
-- end

-- function onActivityFinish(id)
-- 	local config = ActivityType15Config
-- 	local actors = System.getOnlineActorList()
-- 	if actors then
-- 		for i = 1, #actors do
-- 			local actor = actors[i]
-- 			local var = activitymgr.getStaticData(actor)
-- 			local record = var.records[id]
-- 			onTimeOut(id, config, actor, record)
-- 		end
-- 	end	
-- end

function onAfterNewDay(actor, id)
    if activitymgr.activityTimeIsOver(id) then return end
    sendTaskInfo(actor, id)
end


subactivitymgr.regWriteRecordFunc(subType, writeRecord)
subactivitymgr.regGetRewardFunc(subType, onGetReward)
--subactivitymgr.regActivityFinish(subType, onActivityFinish)
--subactivitymgr.regTimeOut(subType, onTimeOut)
subactivitymgr.regNewDayAfterFunc(subType, onAfterNewDay)

netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_GetZhishuTask, getZhishuTask)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.act15all = function (actor)
    for actid, conf in pairs(ActivityType15Config) do
        if not activitymgr.activityTimeIsEnd(actid) then
            local var = getActorVar(actor, actid)
            for k,v in ipairs(conf) do
                var.status[k] = 1
            end
            sendTaskInfo(actor, actid)
        end
    end
    return true
end

gmCmdHandlers.act15Group = function (actor, args)
    local group = tonumber(args[1])
    for actid, conf in pairs(ActivityType15Config) do
        if not activitymgr.activityTimeIsEnd(actid) then
            local var = getActorVar(actor, actid)
            for k,v in ipairs(conf) do
                if v.group == group then
                    var.status[k] = 1
                end
            end
            sendTaskInfo(actor, actid)
        end
    end
    return true
end

