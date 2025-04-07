module("subactivity14", package.seeall)
--登录豪礼
local subType = 14

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.loginday then var.loginday = 0 end --登录天数
    if not var.reward then var.reward = 0 end --领取奖励按位
	return var
end

--登录协议回调
function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local var = getActorVar(actor, id)
    --防止因为newday不成功导致登录天数为0
    if var.loginday == 0 then var.loginday = 1 end
    LDataPack.writeInt(npack, var.reward)
    LDataPack.writeInt(npack, var.loginday)
end

local function checkLevelReward(actor, config, id, index, record)
    if config[index] == nil then
        return false
    end

    if index < 0 or index > 32 then
        print("act14 config is err , index is invalid.."..index)
        return false
    end
    if LActor.getSVipLevel(actor) < config[index].sviplevel then --vip等级不足
        return false
    end
    local var = getActorVar(actor, id)
    if System.bitOPMask(var.reward, index) then --已领取奖励
        return false
    end
    if not actoritem.checkEquipBagSpaceJob(actor, config[index].rewards) then --背包空间不足
        return false
    end
    return true
end

--领取奖励
local function onGetReward(actor, config, id, index, record)
    local var = getActorVar(actor, id)
    if var.loginday == 0 then var.loginday = 1 end --防止因为newday不成功导致登录天数为0
    local ret = checkLevelReward(actor, config[id][var.loginday], id, index, record)
    local conf = config[id][var.loginday][index]

    if ret then
        var.reward = System.bitOpSetMask(var.reward, index, true)
        actoritem.addItems(actor, conf.rewards, "activity type14 rewards")
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
    LDataPack.writeByte(npack, ret and 1 or 0)
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, index)
    LDataPack.writeInt(npack, var.reward)
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
    end
end

subactivitymgr.regNewDayFunc(subType, onBeforeNewDay)
subactivitymgr.regGetRewardFunc(subType, onGetReward)
subactivitymgr.regWriteRecordFunc(subType, writeRecord)

