-- @system	历练系统

module("liliansystem", package.seeall)

function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.liliantask then
		var.liliantask = {
			level = 0,
			exp = 0,
			rewardindex = 0,
			dailyrenown = 0,
			tasks = {}
		}
	end
	for k,v in ipairs(LilianTaskConfig) do
		if not var.liliantask.tasks[k] then 
			var.liliantask.tasks[k] = {} 
			var.liliantask.tasks[k].status = 0
			var.liliantask.tasks[k].progress = 0
		end
	end
	return var.liliantask
end

function updateTaskValue(actor, taskType, param, value)
	--if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.lilian) then return end
	if taskcommon.taskTypeHandleType[taskType] ~= taskcommon.eAddType then
		return
	end
	local var = getActorVar(actor)
	if not var then return end

	for id, conf in pairs(LilianTaskConfig) do 
		repeat			
			if (conf.type ~= taskType) then break end
			if (conf.param[1] ~= -1) and not utils.checkTableValue(conf.param, param) then --有-1时不对参数做验证
				break 
			end 
			if (var.tasks[id].status or 0) == taskcommon.statusType.emHaveAward then break end --任务奖励已领取完
			var.tasks[id].progress = (var.tasks[id].progress or 0) + value
			if var.tasks[id].progress >= conf.target then
				var.tasks[id].status = taskcommon.statusType.emCanAward
			end
			s2cLilianTask(actor, id,var.tasks[id].progress, var.tasks[id].status)
			break
		until(true)
	end
end

function updateAttr(actor, isCalc)
    local var = getActorVar(actor)
    local addAttrs = {}

	if var.level > 0 then
		for k,v in pairs(JunxianLevelConfig[var.level].attr) do                
			addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value        
		end
	end
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Lilian)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    if isCalc then
		LActor.reCalcAttr(actor)
	end	
end

----------------------------------------------------------------------------------------
function s2cLilianTaskInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sLilianTask_Info)
	if pack == nil then return end
	LDataPack.writeShort(pack, var.level)
	LDataPack.writeInt(pack, var.exp)
	LDataPack.writeChar(pack, var.rewardindex)
	LDataPack.writeShort(pack, var.dailyrenown)
	local count = 0
	local countPos = LDataPack.getPosition(pack)
	LDataPack.writeChar(pack, count)
	local custom = guajifuben.getCustom(actor) 
	for k,v in ipairs(LilianTaskConfig) do		
		if custom >= v.custom then
			LDataPack.writeChar(pack, k)
			LDataPack.writeChar(pack, var.tasks[k].status)
			LDataPack.writeDouble(pack, var.tasks[k].progress)
			count = count + 1
		end
	end
	local newpos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, countPos)
	LDataPack.writeChar(pack, count)
    LDataPack.setPosition(pack, newpos)
	LDataPack.flush(pack)
end

function s2cLilianTask(actor, id, progress, status)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sLilianTask_UpdateTask)
	if pack == nil then return end
	LDataPack.writeChar(pack, id)
	LDataPack.writeChar(pack, status)
	LDataPack.writeDouble(pack, progress)
	LDataPack.flush(pack)
end

--领取每日奖励
function c2sGetDailyReward(actor, packet)
	--if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.dailytask) then return end
	local var = getActorVar(actor)
	local conf = JunxianDailyConfig[JunxianLevelConfig[var.level].junxian]
	if not conf then return end
	if not conf.dialyrenown[var.rewardindex + 1]  then return end
	if var.dailyrenown < conf.dialyrenown[var.rewardindex + 1] then return end
	var.rewardindex = var.rewardindex + 1

	actoritem.addItems(actor, conf.dailyreward[var.rewardindex], "lilian daily reward")

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sLilianTask_GetDailyReward)
	if pack == nil then return end
	LDataPack.writeChar(pack, var.rewardindex)
	LDataPack.flush(pack)
end

--领取声望任务奖励
function c2sGetTaskReward(actor, packet)
	local id = LDataPack.readChar(packet)
	local conf = LilianTaskConfig[id]
	if not conf then return end
	local var = getActorVar(actor)
	if not JunxianLevelConfig[var.level + 1] then return end
	if var.tasks[id].status ~= taskcommon.statusType.emCanAward then return end
	var.tasks[id].status = taskcommon.statusType.emHaveAward
	var.id = id
	actoritem.addItem(actor, NumericType_Renown, conf.renown, "liian task rewards")
	actorevent.onEvent(actor, aeLilianTaskFinish)
end

function addRenown(actor, count)
	if count <= 0 then return end
	local var = getActorVar(actor)
	var.exp = var.exp + count
	var.dailyrenown = var.dailyrenown + count
	--功能未开启只加经验不作升级判定
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.lilian) then return end
	local change = false
	while var.exp >= JunxianLevelConfig[var.level].renown do
		if not JunxianLevelConfig[var.level + 1] then break end
		var.exp = var.exp - JunxianLevelConfig[var.level].renown
		local before = var.level
		var.level = var.level + 1
		if JunxianLevelConfig[before].junxian < JunxianLevelConfig[var.level].junxian then
			LActor.setJunxian(actor, JunxianLevelConfig[var.level].junxian)
		end
		actoritem.addItems(actor, JunxianLevelConfig[var.level].rewards, "liian level up reward")
		local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sLilianTask_JunxianUpdate)
		if pack == nil then return end
		LDataPack.writeShort(pack, var.level)
		LDataPack.flush(pack)
		change = true
	end

	if change then
		actorevent.onEvent(actor, aeJunxianLevel, var.level)
        utils.rankfunc.updateRankingList(actor, var.level, RankingType_Lilian)
		updateAttr(actor, true)
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sLilianTask_GetTaskReward)
	if pack == nil then return end
	LDataPack.writeChar(pack, var.id or 1)
	LDataPack.writeChar(pack, var.tasks[var.id or 1].status)
	LDataPack.writeInt(pack, var.exp)
	LDataPack.writeShort(pack, var.dailyrenown)
	LDataPack.flush(pack)
end

function getRenown(actor)
	local var = getActorVar(actor)
	return var.dailyrenown
end

--------------------------------------------------------------------------------
function onLogin(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.lilian) then return end
	s2cLilianTaskInfo(actor)
	local var = getActorVar(actor)
	utils.rankfunc.updateRankingList(actor, var.level, RankingType_Lilian)
end

--新的一天，重置声望任务
function onNewDay(actor, login)
	local var = getActorVar(actor)
	if not var then return end
	var.rewardindex = 0
	var.dailyrenown = 0
	var.tasks = {}
	for k,v in ipairs(LilianTaskConfig) do
		var.tasks[k] = {} 
		var.tasks[k].status = 0
		var.tasks[k].progress = 0
	end
	if not login then
		s2cLilianTaskInfo(actor)
	end
end

function getJunxianStage(actor)
    local var = getActorVar(actor)
    return JunxianLevelConfig[var.level] and JunxianLevelConfig[var.level].junxian or 0
end

function getJunxianLevel(actor)
    local var = getActorVar(actor)
    return var.level
end

function onInit(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.lilian) then return end
	updateAttr(actor)
	local var = getActorVar(actor)
	if var.level == 0 then
		var.level = 1
	end
	LActor.setJunxian(actor, JunxianLevelConfig[var.level].junxian)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin,onLogin)
actorevent.reg(aeNewDayArrive,onNewDay)

function onCustomChange(actor, custom, oldcustom)
	local var = getActorVar(actor)
	local change = false
	if LimitConfig[actorexp.LimitTp.lilian].custom > oldcustom and LimitConfig[actorexp.LimitTp.lilian].custom <= custom then
		var.level = 1
		change = true
		updateAttr(actor, true)
	end
	for k,v in ipairs(LilianTaskConfig) do		
		if custom >= v.custom and oldcustom < v.custom then			
			change = true
			break
		end
	end
	if change then
		s2cLilianTaskInfo(actor)
	end
end

local function init()
	if System.isCrossWarSrv() then return end
    actorevent.reg(aeCustomChange, onCustomChange)
	netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cLilianTask_GetTaskReward, c2sGetTaskReward)
	netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cLilianTask_GetDailyReward, c2sGetDailyReward)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.liliantask = function (actor, args)
	local var = getActorVar(actor)
	for k,v in ipairs(LilianTaskConfig) do
		var.tasks[k].status = 1
	end
	s2cLilianTaskInfo(actor)
	return true
end

gmCmdHandlers.lilianexp = function (actor, args)
	local var = getActorVar(actor)
	var.exp = tonumber(args[1])
	s2cLilianTaskInfo(actor)
	return true
end

gmCmdHandlers.lilianlevel = function (actor, args)
	local var = getActorVar(actor)
	var.level = tonumber(args[1])
	utils.rankfunc.updateRankingList(actor, var.level, RankingType_Lilian)
	s2cLilianTaskInfo(actor)
end

gmCmdHandlers.lilianAll = function (actor, args)
	local var = getActorVar(actor)
	var.level = #JunxianLevelConfig
	LActor.setJunxian(actor, JunxianLevelConfig[var.level].junxian)
	actorevent.onEvent(actor, aeJunxianLevel, var.level)
	utils.rankfunc.updateRankingList(actor, var.level, RankingType_Lilian)
	s2cLilianTaskInfo(actor)
	updateAttr(actor, true)
end

