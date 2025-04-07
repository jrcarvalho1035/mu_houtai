-- @version 1.0
-- @author  qianmeng
-- @date    2017-3-8 15:02:55.
-- @system  成就系统

module("achieve", package.seeall)
require("task.achievementtask")
require("task.ghostlevel")
require("task.ghostrank")

local AchieveTypeCount = 0

local function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end
	if (var.achieveData == nil) then
		var.achieveData = {}
	end
	if not var.achieveData.totalmark then var.achieveData.totalmark = 0 end
	return var.achieveData
end

local function getGhostVar(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end
	if (var.ghostData == nil) then
		var.ghostData = {
			level = 0,
			rank = 0,
			exp = 0,
		}
	end
	return var.ghostData
end

local function initTask(actor, conf)
	local var = {}
	var.taskId = conf.id
	var.taskType = conf.type
	var.curValue = 0
	var.status = taskcommon.statusType.emDoing

	local taskHandleType = taskcommon.getHandleType(conf.type)
	if taskHandleType == taskcommon.eCoverType then
		local record = taskevent.getRecord(actor)
		if taskevent.needParam(conf.type) then
			if record[conf.type] == nil then
				record[conf.type] = {}
			end
			var.curValue = 0
			for k, v in pairs(conf.param) do 
				if record[conf.type][v] then var.curValue = record[conf.type][v] break end 
			end		
		else
			var.curValue = record[conf.type] or taskevent.initRecord(conf.type, actor)
		end
		if var.curValue >= conf.target then --成就完成
			var.status = taskcommon.statusType.emCanAward
		end
	end

	return var
end

local function achieveInit(actor)
	local data = getActorVar(actor)
	for id, conf in pairs(AchievementTaskConfig) do 
		if conf.head == 1 then
			if not data[conf.aType] then
				data[conf.aType] = initTask(actor, conf)
			end
		end
	end
end


local function updateTaskValue(taskType, taskVar, value)
	if (taskcommon.getHandleType(taskType) == taskcommon.eAddType) then
		--这是叠加类型的
		taskVar.curValue = taskVar.curValue + value
		return true
	elseif (taskcommon.getHandleType(taskType) == taskcommon.eCoverType) then
		--这是覆盖类型的
		if (value > taskVar.curValue) then
			taskVar.curValue = value
			return true
		end
	end
	return false
end

--外部接口
function updateAchieveTask(actor, taskType, param, value)
	if taskcommon.taskTypeHandleType[taskType] ~= taskcommon.eCoverType then
		return
	end
	local data = getActorVar(actor) 
	if not data then return end --触发时玩家不在线
	for i=1, AchieveTypeCount do
		repeat
			local var = data[i]
			if not var then break end
			local config = AchievementTaskConfig[var.taskId]
			if not config or taskType ~= config.type or var.status ~= taskcommon.statusType.emDoing then break end
			if config.param[1] ~= -1 and  not utils.checkTableValue(config.param, param) then break end
			updateTaskValue(taskType, var, value)
			if var.curValue < config.target then 
				s2cAchieveUpdate(actor, i)
				break 
			end
			var.status = taskcommon.statusType.emCanAward
			s2cAchieveUpdate(actor, i)
		until(true)
	end
end

--属性更新
function updateAttr(actor, calc)
	local addAttrs = {}
	local var = getGhostVar(actor)
	local conf = GhostLevelConfig[var.level]
	for k, v in pairs(conf.attr) do
		addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
	end
	for k, v in pairs(GhostRankConfig[conf.rank].attr) do
		addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
	end

	--刷新角色属性
	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Ghost)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

function addGhostExp(actor, addexp)
	local var = getGhostVar(actor)
	local old = var.level
	var.exp = var.exp + addexp
	while var.exp >= GhostLevelConfig[var.level].exp and GhostLevelConfig[var.level].exp > 0 do
		var.exp = var.exp - GhostLevelConfig[var.level].exp
		var.level = var.level + 1
		actorevent.onEvent(actor, emGhostLv, var.level)
	end
	if old ~= var.level then
		if GhostRankConfig[var.rank+1] then
			if var.level >= GhostRankConfig[var.rank + 1].level then
				var.rank = var.rank + 1
			end
		end

		updateAttr(actor, true)
	end
	s2cGhostInfo(actor)
end

--从奖励里取出成就积分值
local function getMarkByItems(items)
	if items[2].id == NumericType_Mark then --一般这个items第二位就是成就，这里特殊处理
		return items[2].count
	else
		for k, v in ipairs(items) do
			if v.id == NumericType_Mark then
				return v.count
			end
		end
	end
	return 0
end

--计算总成就积分
function countTotalPoint(actor)
	local data = getActorVar(actor)
	local sum = 0
	for id, conf in pairs(AchievementTaskConfig) do 
		local var = data[conf.aType]
		if var then
			if conf.id < var.taskId then
				sum = sum + getMarkByItems(conf.awardList)
			elseif conf.id == var.taskId and var.status == taskcommon.statusType.emHaveAward then
				sum = sum + getMarkByItems(conf.awardList)
			end
		end
	end
	return sum
end

--外部接口，取总成就点
function getTotalPoint(actor)
	local data = getActorVar(actor)
	return data.totalmark
end

function onInit(actor)
	achieveInit(actor)
	updateAttr(actor, false)
end

function onLogin(actor)
	--处理成就id被更换的情况
	local data = getActorVar(actor)
	for i = 1, AchieveTypeCount do
		repeat
			if not data[i] then break end
			if AchievementTaskConfig[data[i].taskId] then break end
			for id, conf in pairs(AchievementTaskConfig) do 
				if conf.aType == i and conf.head == 1 then
					data[i] = initTask(actor, conf)
					break
				end
			end
		until(true)
	end
	data.totalmark = countTotalPoint(actor) --计算总成就点
	--if actorexp.checkLevelCondition(actor, actorexp.LimitTp.achieve) then
		s2cAchieveInfo(actor)
	--end
	s2cGhostInfo(actor)
end

---------------------------------------------------------------------------------
--成就信息
function s2cAchieveInfo(actor)
	local data = getActorVar(actor)
	if not data then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sTaskCmd_AchieveInfo)
	if pack == nil then return end

	local count = 0
	local countPos = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, count)
	for i = 1, AchieveTypeCount do
		local var = data[i]
		if var then
			LDataPack.writeInt(pack, i)
			LDataPack.writeInt(pack, var.taskId)
			LDataPack.writeInt(pack, var.status)
			LDataPack.writeDouble(pack, var.curValue)
			count = count + 1
		end
	end
	local newpos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, countPos)
	LDataPack.writeInt(pack, count)
	LDataPack.setPosition(pack, newpos)
	LDataPack.writeInt(pack, data.totalmark)
	LDataPack.flush(pack)
end

--单个成就更新
function s2cAchieveUpdate(actor, tp)
	local data = getActorVar(actor)
	if not data then return end
	local var = data[tp]
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sTaskCmd_AchieveUpdate)
	if pack == nil then return end
	LDataPack.writeInt(pack, tp)
	LDataPack.writeInt(pack, var.taskId)
	LDataPack.writeInt(pack, var.status)
	LDataPack.writeDouble(pack, var.curValue)
	--LDataPack.writeInt(pack, data.achieveScore or 0)
	LDataPack.flush(pack)
end

--成就领奖
function c2sAchieveReward(actor, packet)
	local id = LDataPack.readInt(packet)
	local conf = AchievementTaskConfig[id]
	if not conf then return	end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.achieve) then return end
	local data = getActorVar(actor)
	local achieveVar = data[conf.aType]
	if not achieveVar then return end

	if achieveVar.taskId ~= id then return end
	if achieveVar.status ~= taskcommon.statusType.emCanAward then
		return
	end

	achieveVar.status = taskcommon.statusType.emHaveAward
	actoritem.addItems(actor, conf.awardList, "achieve task eward "..id)
	data.totalmark = data.totalmark + getMarkByItems(conf.awardList)

	if AchievementTaskConfig[conf.next] then
		data[conf.aType] = initTask(actor, AchievementTaskConfig[conf.next])
	end
	s2cAchieveUpdate(actor, conf.aType)
end

--一键领取成就奖励
function c2sAchieveOnekey(actor, packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.achieve) then return end
	local data = getActorVar(actor)
	if not data then return end

	for i = 1, AchieveTypeCount do
		while (data[i] and data[i].status == taskcommon.statusType.emCanAward) do
			local conf = AchievementTaskConfig[data[i].taskId]
			data[i].status = taskcommon.statusType.emHaveAward
			actoritem.addItems(actor, conf.awardList, "achieve task eward "..data[i].taskId)
			data.totalmark = data.totalmark + getMarkByItems(conf.awardList)
			if AchievementTaskConfig[conf.next] then
				data[i] = initTask(actor, AchievementTaskConfig[conf.next])
			end
		end
	end
	s2cAchieveInfo(actor)
end

--圣灵信息
function s2cGhostInfo(actor)
	local var = getGhostVar(actor)
	local data = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sTaskCmd_GhostInfo)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.level)
	LDataPack.writeInt(pack, var.exp)
	LDataPack.writeInt(pack, var.rank)
	--LDataPack.writeInt(pack, data.achieveScore or 0)
	LDataPack.flush(pack)
end

--圣灵升级
function c2sGhostUpLevel(actor, packet)
	local var = getGhostVar(actor)
	local data = getActorVar(actor)
	local conf = GhostLevelConfig[var.level]
	if not conf then return end
	if conf.exp == 0 then
		return
	end

	if not actoritem.checkItem(actor, NumericType_Mark, conf.point) then
		return
	end
	actoritem.reduceItem(actor, NumericType_Mark, conf.point, "ghost up level "..conf.point)

	addGhostExp(actor, conf.addexp)

	s2cGhostInfo(actor)
end


actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cTaskCmd_AchieveReward, c2sAchieveReward)
netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cTaskCmd_AchieveOnekey, c2sAchieveOnekey)
netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cTaskCmd_GhostUpLevel, c2sGhostUpLevel)

for id, conf in pairs(AchievementTaskConfig) do
	if AchieveTypeCount < conf.aType then
		AchieveTypeCount = conf.aType
	end
end

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.addGhostExp = function (actor, args)
	addGhostExp(actor, args[1])
	return true
end

gmCmdHandlers.setAchievement = function (actor, args)
	local id = tonumber(args[1])
	local conf = AchievementTaskConfig[id]
	local data = getActorVar(actor)
	data[conf.aType] = initTask(actor, conf)
	s2cAchieveUpdate(actor, conf.aType)
	return true
end

gmCmdHandlers.achieveonekey = function (actor, args)
	c2sAchieveOnekey(actor, packet)
	return true
end

gmCmdHandlers.achievefinish = function (actor, args)
	local data = getActorVar(actor)
	for id, conf in pairs(AchievementTaskConfig) do 
		local var = data[conf.aType]
		if var then
			if conf.id > var.taskId then
				var.taskId = conf.id
			end
			var.status = taskcommon.statusType.emHaveAward
		end
	end
	data.totalmark = countTotalPoint(actor)
	s2cAchieveInfo(actor)
end

