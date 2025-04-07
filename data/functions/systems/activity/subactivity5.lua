module("subactivity5", package.seeall)

--星石返利
local subType = 5

local minType = {
	item = 1, --星石返利
}

local function getActorVar(actor, id)
	local var = activitymgr.getSubVar(actor, id)
	if (var == nil) then return end
	var = var.data
	if not var.cantimes then var.cantimes = {} end --可领取次数
	if not var.havetimes then var.havetimes = {} end --已领取次数
	return var
end

--记录数据
local function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	local var = getActorVar(actor, id)
	LDataPack.writeChar(npack, #ActivityType5Config[id])
	for i=1, #ActivityType5Config[id] do
		LDataPack.writeChar(npack, var.cantimes[i] or 0)
		LDataPack.writeChar(npack, var.havetimes[i] or 0)
	end
end

--领取奖励
local function onGetReward(actor, config, id, idx, record)
	local config = config[id]
	local var = getActorVar(actor, id)
	if (var.havetimes[idx] or 0) >= (var.cantimes[idx] or 0) then
		return
	end
	
	var.havetimes[idx] = (var.havetimes[idx] or 0) + 1
	local rewardPer = rechargesystem.getRewardPerByPf(actor, config[idx].yuanbao)
	local rewards = utils.table_clone(config[idx].rewards)
	for i,v in ipairs(rewards) do
		if v.id == NumericType_YuanBao then
			v.count = math.ceil(v.count * rewardPer / 100) * 100
		else
			v.count = math.ceil(v.count * rewardPer)
		end
	end
	actoritem.addItems(actor, rewards, "activity type5 rewards")
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	LDataPack.writeByte(npack, 1)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, idx)
	LDataPack.writeChar(npack, var.cantimes[idx] or 0)
	LDataPack.writeChar(npack, var.havetimes[idx])
	LDataPack.flush(npack)
end

function updateInfo(actor, id)
	local var = getActorVar(actor, id)
	local config = ActivityType5Config[id]
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_StarStoneInfo)
	LDataPack.writeInt(npack, id)
	LDataPack.writeChar(npack, #config)
	for i=1, #config do
		LDataPack.writeChar(npack, var.cantimes[i] or 0)
		LDataPack.writeChar(npack, var.havetimes[i] or 0)
	end
	LDataPack.flush(npack)
end

local function onRecharge(actor, count, item)	
	for id, conf in pairs(ActivityType5Config) do
		local var = getActorVar(actor, id)
		for i=1, #conf do
			if item == conf[i].yuanbao and not activitymgr.activityTimeIsEnd(id) and (var.cantimes[i] or 0) < conf[i].times then
				local var = getActorVar(actor, id)
				var.cantimes[i] = (var.cantimes[i] or 0) + 1
				updateInfo(actor, id)
			end
		end
	end
end

function onTimeOut(id, config, actor)
	local config = config[id]
	local var = getActorVar(actor, id)
	local send = false
	for idx, v in ipairs(config) do
		if (var.havetimes[idx] or 0) < (var.cantimes[idx] or 0) then
			local rewardPer = rechargesystem.getRewardPerByPf(actor, v.yuanbao)
			local rewards = utils.table_clone(v.rewards)
			for _, conf in ipairs(rewards) do
				if conf.id == NumericType_YuanBao then
					conf.count = math.ceil(conf.count * rewardPer / 100) * 100
				else
					conf.count = math.ceil(conf.count * rewardPer)
				end
			end
			for i=1, (var.cantimes[idx] or 0) - (var.havetimes[idx] or 0) do
				local mailData = {head = v.head, context = v.text, tAwardList= rewards}
				mailsystem.sendMailById(LActor.getActorId(actor), mailData)
				var.havetimes[idx] = (var.havetimes[idx] or 0) + 1
				send = true
			end			
		end
	end
	--var = LActor.getEmptyStaticVar()
	if send then
		updateInfo(actor, id)
	end	
end

function onActivityFinish(id)
	local config = ActivityType5Config
	local actors = System.getOnlineActorList()
	if actors then
		for i = 1, #actors do
			local actor = actors[i]
			onTimeOut(id, config, actor)
		end
	end
end

function init()
	if System.isCrossWarSrv() then return end
	actorevent.reg(aeRecharge, onRecharge)
	subactivitymgr.regActivityFinish(subType, onActivityFinish)
	subactivitymgr.regTimeOut(subType, onTimeOut)
	subactivitymgr.regWriteRecordFunc(subType, writeRecord)
	subactivitymgr.regGetRewardFunc(subType, onGetReward)
end

table.insert(InitFnTable, init)