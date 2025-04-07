--冲榜特惠
module("subactivity9", package.seeall)

local ACT6_RECORD = ACT6_RECORD or {}
local MAX_RECORD = 10
local subType = 9

--记录数据
local function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	local v = record and record.data and record.data.rewardsRecord or 0

	LDataPack.writeInt(npack, v)
end

--领取奖励
local function onGetReward(actor, config, id, idx, record)
	local buycount = record.data.rewardsRecord or 0
	local level = LActor.getSVipLevel(actor)
	if buycount >= SVipConfig[level].cbthcount then
		return
	end
	local config = config[id]
	local zhekou = 10
	for i=#config[1].buycount , 1 , -1 do
		if buycount >= config[1].buycount[i][1] then
			zhekou = config[1].buycount[i][2]
			break
		end
	end
	if zhekou == 10 then
		zhekou = config[1].buycount[#config[1].buycount][2]
	end

	if not actoritem.checkItem(actor, NumericType_YuanBao,  math.floor(config[1].money * zhekou/10)) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, math.floor(config[1].money * zhekou/10), "activity type9 cost")

	record.data.rewardsRecord = (record.data.rewardsRecord or 0) + 1
	actoritem.addItems(actor, config[1].rewards, "activity type9 rewards")

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	LDataPack.writeByte(npack, 1)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, 1)
	LDataPack.writeInt(npack, record.data.rewardsRecord or 0)
	LDataPack.flush(npack)
end

subactivitymgr.regWriteRecordFunc(subType, writeRecord)
subactivitymgr.regGetRewardFunc(subType, onGetReward)
