--钻石礼包

module("subactivity7", package.seeall)

local subType = 7

function getFinishTime(actor, finishTime)
	local d,h,m = string.match(finishTime, "(%d+)-(%d+):(%d+)")
	if d== nil or h == nil or m == nil then
		return 0
	end
	local ft = LActor.getCreateTime(actor)
	ft = ft + d*24*3600 + h*3600 + m*60
	return ft
end

local function updateInfo(actor, id)
	local conf = ActivityType7Config[id]
	if not conf then return end
	local ft = getFinishTime(actor, conf[1].finishTime)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Update7)
	if npack == nil then return end

	LDataPack.writeInt(npack, id)
	LDataPack.writeInt(npack, ft)
	LDataPack.flush(npack)
end

--记录数据
local function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	LDataPack.writeInt(npack, record and record.data and record.data.rewardsRecord or 0)
end

--检测能否领取奖励
local function checkLevelReward(actor, config, index, record)
	if config[index] == nil then
		return false
	end

	if index < 0 or index > 30 then
		print("config is err , index is invalid.."..index)
		return false
	end
	if LActor.getSVipLevel(actor) < config[index].vip then --vip等级不足
		return false
	end
	if (record.data.rewardsRecord or 0) + 1 ~= index then --购买次数对不上
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
	
	local ret = checkLevelReward(actor, config, index, record)
	if ret then
		record.data.rewardsRecord = (record.data.rewardsRecord or 0) + 1
		actoritem.reduceItem(actor, config[index].currencyType, config[index].price, "activity type7 buy")
		actoritem.addItems(actor, config[index].rewards, "activity type7 rewards")
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, index)
	LDataPack.writeInt(npack, record.data.rewardsRecord or 0)
	LDataPack.flush(npack)
end

subactivitymgr.actorLoginFuncs[subType] = function(actor, type, id)
	if activitymgr.activityTimeIsOver(id) then return end
	updateInfo(actor, id)
end

subactivitymgr.regWriteRecordFunc(subType, writeRecord)
subactivitymgr.regGetRewardFunc(subType, onGetReward)
