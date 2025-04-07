module("subactivity41", package.seeall)

--累充自选
local subType = 41

local minType = {
	yuanbao = 1, --充值元宝
	diamond = 2, --充值元宝
}

local function getActorVar(actor, id)
	local var = activitymgr.getSubVar(actor, id)
	if (var == nil) then return end
	var = var.data
    if not var.diamond then var.diamond = 0 end
	if not var.rewardsRecord then var.rewardsRecord = 0 end --领奖状态
	if not var.chooses then var.chooses = {} end --自选记录
	if not var.score then var.score = 0 end --达标进度
	return var
end

--记录数据
local function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	local var = getActorVar(actor, id)
	LDataPack.writeInt(npack, var.score)
	LDataPack.writeInt(npack, var.rewardsRecord)
	LDataPack.writeChar(npack, #ActivityType41Config[id])
	for idx, conf in ipairs(ActivityType41Config[id]) do
		LDataPack.writeChar(npack, #conf.chooseRewards)
		local chooses = var.chooses[idx] or {}
		for index in ipairs(conf.chooseRewards) do
			LDataPack.writeChar(npack, chooses[index] or 0)
		end
	end
end

local function checkLevelReward(actor, config, id, idx, var)
	if not config then 
		return 
	end

    if config[idx] == nil then
        return false
    end

    if idx < 0 or idx > 31 then
        print("act41 config is err , idx is invalid.."..idx)
        return false
    end

    if var.score < config[idx].condition then
    	return false
    end

    if System.bitOPMask(var.rewardsRecord, idx) then
    	return false
    end

    local rewards = {}
    --将自选奖励加入奖励列表中
	local chooses = var.chooses[idx] or {}
	for index, conf in ipairs(config[idx].chooseRewards) do
		local choose = chooses[index]
		if not choose then return false end
		local item = conf[choose]
		if not item then return false end
		table.insert(rewards, item)
	end
	--将固定奖励加入奖励列表中
	for _, item in ipairs(config[idx].rewards) do
		table.insert(rewards, item)
	end

    if not actoritem.checkEquipBagSpaceJob(actor, rewards) then --背包空间不足
        return false
    end
    return true, rewards
end

--领取奖励
local function onGetReward(actor, config, id, idx, record)
	local var = getActorVar(actor, id)
    local ret, rewards = checkLevelReward(actor, config[id], id, idx, var)

    if ret then
        var.rewardsRecord = System.bitOpSetMask(var.rewardsRecord, idx, true)
        actoritem.addItems(actor, rewards, "activity type41 rewards")
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
    LDataPack.writeByte(npack, ret and 1 or 0)
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, idx)
    LDataPack.writeInt(npack, var.rewardsRecord)
    LDataPack.flush(npack)
end

--71-115 累充自选-更新进度
function updateScore(actor, id, value)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Act41UpdateScore)
	LDataPack.writeInt(npack, id)
	LDataPack.writeInt(npack, value)
	LDataPack.flush(npack)
end

--71-116 累充自选-请求选择奖励
local function c2sAct41Choose(actor, packet)
    local id = LDataPack.readInt(packet)
    local idx = LDataPack.readChar(packet)--第几档
    local index = LDataPack.readChar(packet)--第几个自选格
    local choose = LDataPack.readChar(packet)--选择的序号
    if activitymgr.activityTimeIsEnd(id) then return end

    local config = ActivityType41Config[id][idx]
    if not config then return end
    if not (config.chooseRewards[index] and config.chooseRewards[index][choose]) then return end

    local var = getActorVar(actor, id)
    if not var then return end

    if System.bitOPMask(var.rewardsRecord, idx) then return end --已领取的档位不可以再选择

    if not var.chooses[idx] then
        var.chooses[idx] = {}
    end
    var.chooses[idx][index] = choose
    print("c2sAct41Choose actorid =",LActor.getActorId(actor),"id =",id,"idx =",idx,"index =",index,"choose =",choose)
    s2cAct41Choose(actor, id, idx, index, choose)
end

--71-116 累充自选-返回选择奖励
function s2cAct41Choose(actor, id, idx, index, choose)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Act41Choose)
	LDataPack.writeInt(npack, id)
	LDataPack.writeChar(npack, idx)
	LDataPack.writeChar(npack, index)
	LDataPack.writeChar(npack, choose)
	LDataPack.flush(npack)
end

----------------------------------------------------------------------------------
--事件处理
local function onRecharge(actor, count, item)
	for id, conf in pairs(ActivityType41Config) do
		if conf[1].subType == minType.yuanbao and not activitymgr.activityTimeIsEnd(id) then
			local var = getActorVar(actor, id)
			var.score = var.score + count
			updateScore(actor, id, var.score)
		end
	end
end

local function onConsumeDiamond(actor, count)
    for id, conf in pairs(ActivityType41Config) do
        if conf[1].subType == minType.diamond and not activitymgr.activityTimeIsEnd(id) then
            local var = getActorVar(actor, id)
            var.diamond = var.diamond + count
            updateScore(actor, id, var.diamond)
        end
    end
end

--local function onBeforeNewDay(actor, record, config, id, login)
local function onTimeOut(id, config, actor, record)
	local actorid = LActor.getActorId(actor)
	local var = getActorVar(actor, id)
	local score = var.score
	local rewardsRecord = var.rewardsRecord

	for idx, conf in ipairs(config[id]) do
		if conf.condition < score and not System.bitOPMask(rewardsRecord, idx) then
			rewardsRecord = System.bitOpSetMask(rewardsRecord, idx, true)
			var.rewardsRecord = rewardsRecord
			
			local rewards = {}
		    --将自选奖励加入奖励列表中
			local chooses = var.chooses[idx] or {}
			for index, chooseReward in ipairs(conf.chooseRewards) do
				local choose = chooses[index] or 1
				local item = chooseReward[choose]
				if item then
					table.insert(rewards, item)
				end
			end
			--将固定奖励加入奖励列表中
			for _, item in ipairs(conf.rewards) do
				table.insert(rewards, item)
			end
			local mailData = {head = conf.head, context = conf.context, tAwardList = rewards}
			mailsystem.sendMailById(actorid, mailData)
		end
	end
end

----------------------------------------------------------------------------------
--初始化
function init()
	if System.isCrossWarSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Act41Choose, c2sAct41Choose)

	actorevent.reg(aeRecharge, onRecharge)
	actorevent.reg(aeConsumeDiamond, onConsumeDiamond)
	--subactivitymgr.regNewDayFunc(subType, onBeforeNewDay)
	subactivitymgr.regTimeOut(subType, onTimeOut)
	subactivitymgr.regWriteRecordFunc(subType, writeRecord)
	subactivitymgr.regGetRewardFunc(subType, onGetReward)
end

table.insert(InitFnTable, init)

