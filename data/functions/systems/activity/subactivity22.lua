--特惠礼包
module("subactivity22", package.seeall)

local subType = 22

--记录数据
local function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	local count = #config
    LDataPack.writeShort(npack, count)
    for i=1, count do
		LDataPack.writeShort(npack, record and record.data and record.data.rewardsRecord and record.data.rewardsRecord[i] or 0)
	end
end

--检测能否领取奖励
local function checkLevelReward(actor, config, index, record)
	if config[index] == nil then
		return false
	end

	if index < 0 or index > 32 then
		print("config is err , index is invalid.."..index)
		return false
	end

	if (record.data.rewardsRecord[index] or 0) >= config[index].count then --购买次数超
		return false
	end
	if not actoritem.checkEquipBagSpaceJob(actor, config[index].rewards) then
		return false
	end
	if not actoritem.checkItem(actor, config[index].currencyType, config[index].price) then
		return false
	end
	return true
end

--领取奖励
local function onGetReward(actor, config, id, index, record)
	local config = config[id]
	if record.data == nil then record.data = {} end
	if record.data.rewardsRecord == nil then record.data.rewardsRecord = {} end
	
	local ret = checkLevelReward(actor, config, index, record)
	if ret then
		record.data.rewardsRecord[index] = (record.data.rewardsRecord[index] or 0) + 1
		actoritem.reduceItem(actor, config[index].currencyType, config[index].price, "activity type22 buy")
		actoritem.addItemsByMail(actor, config[index].rewards, "activity type22 rewards")
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, index)
	LDataPack.writeInt(npack, record.data.rewardsRecord[index] or 0)
	LDataPack.flush(npack)
end

subactivitymgr.actorLoginFuncs[subType] = function(actor, type, id)
	if activitymgr.activityTimeIsOver(id) then return end
end

subactivitymgr.regWriteRecordFunc(subType, writeRecord)
subactivitymgr.regGetRewardFunc(subType, onGetReward)
