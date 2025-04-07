module("subactivity10", package.seeall)
--登录豪礼
local subType = 10

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var
    if not var.loginday then var.loginday = 0 end --登录天数
    if not var.reward then var.reward = 0 end --普通奖励按位
    if not var.svipreward then var.svipreward = 0 end --svip奖励按位
	return var
end

--登录协议回调
function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local var = getActorVar(actor, id)	
    LDataPack.writeShort(npack, var.reward)
    LDataPack.writeShort(npack, var.svipreward)
end


--领取奖励
local function onGetReward(actor, config, id, idx, record)
	local config = config[id]
    local var = getActorVar(actor, id)
    if not config[var.loginday] then return end
    if idx == 1 then
        if var.reward == 1 then --已领取
            return false
        end
    
        var.reward = 1
        actoritem.addItems(actor, config[var.loginday].rewards, "activity type10 rewards")
    else
        if LActor.getSVipLevel(actor) < config[var.loginday].needsvip then --vip等级不足
            return false
        end
        if var.svipreward == 1 then --已领取
            return false
        end
    
        var.svipreward = 1
        actoritem.addItems(actor, config[var.loginday].srewards, "activity type10 rewards")
    end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	LDataPack.writeByte(npack, 1)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, idx)
	LDataPack.writeInt(npack, idx == 1 and var.reward or var.svipreward)
	LDataPack.flush(npack)
end

function sendLoginInfo(actor, id)
    local var = getActorVar(actor, id)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Update5)
    LDataPack.writeInt(npack, id)
	LDataPack.writeInt(npack, var.loginday)
	LDataPack.flush(npack)
end

--每天在活动协议发送之前的操作
function onBeforeNewDay(actor, record, config, id)
	if not activitymgr.activityTimeIsEnd(id) then
        local var = getActorVar(actor, id)
        if var.loginday < #config[id] then
            var.loginday = var.loginday + 1
        end
        var.reward = 0
        var.svipreward = 0
    end
end

function onAfterNewDay(actor, id)
    sendLoginInfo(actor, id)
end

subactivitymgr.actorLoginFuncs[subType] = function(actor, type, id)
    if activitymgr.activityTimeIsOver(id) then return end
    sendLoginInfo(actor, id)
end
subactivitymgr.regNewDayFunc(subType, onBeforeNewDay)
subactivitymgr.regNewDayAfterFunc(subType, onAfterNewDay)
subactivitymgr.regGetRewardFunc(subType, onGetReward)
subactivitymgr.regWriteRecordFunc(subType, writeRecord)




