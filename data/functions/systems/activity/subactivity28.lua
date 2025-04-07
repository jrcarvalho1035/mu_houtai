-- 集字兑换
module("subactivity28", package.seeall)

local subType = 28

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)

    if not var.buy then
		var.buy = {}
    end

    if not var.remind then
		var.remind = {}
    end

    return var
end

local function buy(actor, config, id, idx, param2)
	if activitymgr.activityTimeIsEnd(id) then return end
    local actor_id = LActor.getActorId(actor)
	local list = ActivityType28Config[id]
	if list == nil then
		print('subactivity28.buy list==nil id=', id, 'actor_id=', actor_id)
		return
	end

	local conf = list[idx]
	if conf == nil then
		print('subactivity28.buy conf==nil id=', id, 'idx=', idx, 'actor_id=', actor_id)
		return
	end

	if not actoritem.checkBagSpaceByItem(actor, conf.item, conf.count) then
		return
	end

	local var = getActorVar(actor, id)
	local old = var.buy[idx] or 0
	if conf.limit <= old then
		print('subactivity28.buy bad old=', old, 'conf.limit=', conf.limit, 'id=', id, 'idx=', idx, 'actor_id=', actor_id)
		return
	end

	if not actoritem.checkItems(actor, conf.consume) then
		print('subactivity28.buy checkItem fail id=', id, 'idx=', idx, 'actor_id=', actor_id)
		return
	end

	if not actoritem.reduceItems(actor, conf.consume, 'type28') then
		print('subactivity28.buy reduceItem fail id=', id, 'idx=', idx, 'actor_id=', actor_id)
		return
	end

	local new = old + 1
	var.buy[idx] = new

	actoritem.addItem(actor, conf.item, conf.count, 'type28')

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	if pack then
		LDataPack.writeByte(pack, 1) -- 成功
		LDataPack.writeInt(pack, id)
		LDataPack.writeShort(pack, idx)
		LDataPack.writeShort(pack, 0) -- 购买
		LDataPack.writeShort(pack, new)
		LDataPack.flush(pack)
	end
end

local function setRemind(actor, config, id, idx, flag)
	local var = getActorVar(actor, id)
	var.remind[idx] = flag

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	if pack then
		LDataPack.writeByte(pack, 1) -- 成功
		LDataPack.writeInt(pack, id)
		LDataPack.writeShort(pack, idx)
		LDataPack.writeShort(pack, 1) -- 提醒
		LDataPack.writeShort(pack, flag)
		LDataPack.flush(pack)
	end
end

local function getReward(actor, config, id, idx, record, reader)
    local param1 = LDataPack.readShort(reader)
	local param2 = LDataPack.readShort(reader)

	if param1 == 0 then -- 购买
		buy(actor, config, id, idx, param2)
	else -- 提醒
		setRemind(actor, config, id, idx, param2)
	end
end

local function writeRecord(npack, record, config, id, actor)
    local var = getActorVar(actor, id)
	LDataPack.writeByte(npack, #config)
    for k, conf in ipairs(config) do
        LDataPack.writeShort(npack, k)
		LDataPack.writeShort(npack, var.buy[k] or 0)
		LDataPack.writeByte(npack, var.remind[k] or conf.isRmind)
    end
end

local function initGlobalData()
	subactivitymgr.regGetRewardFunc(subType, getReward)
	subactivitymgr.regWriteRecordFunc(subType, writeRecord)
end
table.insert(InitFnTable, initGlobalData)
