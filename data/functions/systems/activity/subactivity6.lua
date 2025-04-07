--冲榜夺宝
module("subactivity6", package.seeall)

ACT6_RECORD = ACT6_RECORD or {}
ACT6_SELF_RECORD = ACT6_SELF_RECORD or {}
local MAX_RECORD = 10
local subType = 6

function c2sDraw(actor, pack)
	local id = LDataPack.readInt(pack)
	local times = LDataPack.readChar(pack)
	if activitymgr.activityTimeIsEnd(id) then return end
	if not ActivityType6Config[id] then
		return
	end
	local index = 0
	local config = ActivityType6Config[id][1]
	for i=1, #config.drawcount do
		if config.drawcount[i][1] == times then
			index = i
			break
		end
	end
	if index == 0 then
		return
	end
	
	if not actoritem.checkItem(actor, NumericType_YuanBao, config.drawcount[index][2]) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, config.drawcount[index][2], "activity type6 cost")
	local items = {}
	local total = 0
	for i=1, times do
		local rand = System.getRandomNumber(10000) + 1
		total = 0
		for k,v in ipairs(config.rewards) do
			total = total + v.per
			if rand <= total then
				items[#items + 1] = config.rewards[k]
				index = k
				--记录数据
				local actorid = LActor.getActorId(actor)
				if not ACT6_SELF_RECORD[id] then ACT6_SELF_RECORD[id] = {} end
				if not ACT6_SELF_RECORD[id][actorid] then ACT6_SELF_RECORD[id][actorid] = {} end
				table.insert(ACT6_SELF_RECORD[id][actorid], 1, {name = LActor.getName(actor), id = config.rewards[k].id, count = config.rewards[k].count})
				if #ACT6_SELF_RECORD[id][actorid] > MAX_RECORD then
					table.remove(ACT6_SELF_RECORD[id][actorid])
				end
				if config.isbro[k] == 1 then --如果要加入记录
					if not ACT6_RECORD[id] then ACT6_RECORD[id] = {} end
					table.insert(ACT6_RECORD[id], 1, {name = LActor.getName(actor), id = config.rewards[k].id, count = config.rewards[k].count})
					if #ACT6_RECORD[id] > MAX_RECORD then
						table.remove(ACT6_RECORD[id])
					end
				end
				break
			end
		end
	end

	actoritem.addItems(actor, items, "activity type6 rewards")
	actorevent.onEvent(actor, aeDuobaoScore, config.score * times, config.actId)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_DuobaoDraw)
	LDataPack.writeInt(npack, id)
	LDataPack.writeChar(npack, #items)
	for k,v in ipairs(items) do
		LDataPack.writeInt(npack, v.id)
		LDataPack.writeInt(npack, v.count)
	end
	LDataPack.writeChar(npack, index)
	LDataPack.flush(npack)
	s2cRecordInfo(actor, id, 2)
end

function c2sRecord(actor, pack)
	local id = LDataPack.readInt(pack)
	local type = LDataPack.readChar(pack)
	if not ActivityType6Config[id] then
		return
	end
	s2cRecordInfo(actor, id, type)
end

function s2cRecordInfo(actor, id, type)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_DuobaoRecord)
	LDataPack.writeInt(npack, id)
	LDataPack.writeChar(npack, type)
	if type == 1 then
		local actorid = LActor.getActorId(actor)
		if not ACT6_SELF_RECORD[id] then ACT6_SELF_RECORD[id] = {} end
		if not ACT6_SELF_RECORD[id][actorid] then ACT6_SELF_RECORD[id][actorid] = {} end
		LDataPack.writeChar(npack, #ACT6_SELF_RECORD[id][actorid])
		for k,v in ipairs(ACT6_SELF_RECORD[id][actorid]) do
			LDataPack.writeString(npack, v.name)
			LDataPack.writeInt(npack, v.id)
			LDataPack.writeInt(npack, v.count)
		end
	else
		if not ACT6_RECORD[id] then ACT6_RECORD[id] = {} end
		LDataPack.writeChar(npack, #ACT6_RECORD[id])
		for k,v in ipairs(ACT6_RECORD[id]) do
			LDataPack.writeString(npack, v.name)
			LDataPack.writeInt(npack, v.id)
			LDataPack.writeInt(npack, v.count)
		end
	end
	LDataPack.flush(npack)
end

local function init()
    if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_DuobaoDraw, c2sDraw)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_DuobaoRecord, c2sRecord)
end

table.insert(InitFnTable, init)

function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	local v = record and record.data and record.data.rewardsRecord or 0
	LDataPack.writeInt(npack, v)
end
subactivitymgr.regWriteRecordFunc(subType, writeRecord)

