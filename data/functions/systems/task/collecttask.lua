-- @version 1.0
-- @author  qianmeng
-- @date    2018-3-19 18:24:02.
-- @system  装备收集系统

module("collecttask", package.seeall)
require("task.collect")
require("task.collecttype")

local function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end
	if (var.collectData == nil) then
		var.collectData = {}
	end
	return var.collectData
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

		if var.curValue >= conf.target then --收集完成
			var.status = taskcommon.statusType.emCanAward
		end
	end
	return var
end

local function collectInit(actor)
	local data = getActorVar(actor)
	for tp, config in pairs(CollectTaskConfig) do
		if not data[tp] then data[tp] = {} end
		for id, conf in pairs(config) do
			if not data[tp][id] then
				data[tp][id] = initTask(actor, conf)
			end
		end
	end
end

--检测这一类型的收集是否全激活
function checkActive(data, tp)
	if not data[tp] then return false end
	for id,conf in pairs(CollectTaskConfig[tp]) do
		if not data[tp][id] then return false end
		if data[tp][id].status ~= taskcommon.statusType.emHaveAward then
			return false
		end
	end
	return true
end

local function updateCurValue(taskType, taskVar, value)
	if (taskcommon.getHandleType(taskType) == taskcommon.eAddType) then
		--这是叠加类型的
		taskVar.curValue = taskVar.curValue + value
		return true
	elseif (taskcommon.getHandleType(taskType) == taskcommon.eCoverType) then
		--这是覆盖类型的
		taskVar.curValue = value
		return true
	end
	return false
end

--外部接口
function updateTaskValue(actor, taskType, param, value)
	if taskcommon.taskTypeHandleType[taskType] ~= taskcommon.eCoverType then
		return
	end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.collect) then return end
	local data = getActorVar(actor) 
	if not data then return end --触发时玩家不在线
	for tp, config in pairs(CollectTaskConfig) do 
		local isUpdate = false
		for id, conf in pairs(config) do
			repeat
				local var = data[tp] and data[tp][id]
				if not var then break end
				if taskType ~= conf.type or var.status ~= taskcommon.statusType.emDoing then break end
				if conf.param[1] ~= -1 and  not utils.checkTableValue(conf.param, param) then break end
				updateCurValue(taskType, var, value)
				if var.curValue < conf.target then 
					s2cCollectUpdate(actor, tp, id)
					break 
				end
				var.status = taskcommon.statusType.emCanAward
				s2cCollectUpdate(actor, tp, id)
				isUpdate = true
			until(true)
		end
		if isUpdate then break end
	end
end

--属性更新
function updateAttr(actor, calc)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.collect) then return end
	-- local addAttrs = {}
	-- local data = getActorVar(actor)
	-- for tp, conf in pairs(CollectTypeConfig) do
	-- 	if checkActive(data, tp) then
	-- 		for k, v in pairs(conf.attrs) do
	-- 			addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
	-- 		end
	-- 	end
	-- end

	-- --刷新角色属性
	-- local attr = LActor.getActorSystemAttrs(actor, AttrActorSysId_Collect)
	-- attr:Reset()
	-- for k, v in pairs(addAttrs) do
	-- 	attr:Set(k, v)
	-- end
	-- if calc then
	-- 	LActor.reCalcAttr(actor)
	-- end
end

function onInit(actor)
	--updateAttr(actor, false)
	local lv = actorexp.getLimitLevel(actor,actorexp.LimitTp.collect)
	if LActor.getLevel(actor) >= lv then
		collectInit(actor)
	end
end

function onLogin(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.collect) then return end
	s2cCollectInfo(actor)
end

function onLevelUp(actor, level, oldLevel)
	local lv = actorexp.getLimitLevel(actor,actorexp.LimitTp.collect)
	if lv > oldLevel and lv <= level then
		collectInit(actor)
		s2cCollectInfo(actor)
	end
end
---------------------------------------------------------------------------------
--收集信息
function s2cCollectInfo(actor)
	local data = getActorVar(actor)
	if not data then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sTaskCmd_CollectInfo)
	if pack == nil then return end
	LDataPack.writeChar(pack, #CollectTaskConfig)
	for tp, config in ipairs(CollectTaskConfig) do
		LDataPack.writeChar(pack, tp)
		LDataPack.writeShort(pack, #config)
		for id, conf in ipairs(config) do
			local var = data[tp] and data[tp][id]
			LDataPack.writeShort(pack, id)
			LDataPack.writeDouble(pack, var and var.curValue or 0)
			LDataPack.writeChar(pack, var and var.status or 0)
		end
	end
	LDataPack.flush(pack)
end

--单个收集更新
function s2cCollectUpdate(actor, tp, id)
	local data = getActorVar(actor)
	if not data then return end
	local var = data[tp][id]
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sTaskCmd_CollectUpdate)
	if pack == nil then return end
	LDataPack.writeChar(pack, tp)
	LDataPack.writeShort(pack, id)
	LDataPack.writeDouble(pack, var.curValue)
	LDataPack.writeChar(pack, var.status)
	LDataPack.flush(pack)
end

--收集领奖
function c2sCollectReward(actor, packet)
	local tp = LDataPack.readChar(packet)
	local id = LDataPack.readShort(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.collect) then return end
	local conf = CollectTaskConfig[tp] and CollectTaskConfig[tp][id]
	if not conf then return	end
	local data = getActorVar(actor)
	local var = data[tp] and data[tp][id]
	if not var then return end

	if var.status ~= taskcommon.statusType.emCanAward then
		return
	end
	var.status = taskcommon.statusType.emHaveAward
	actoritem.addItems(actor, conf.rewards, "collect eward "..id)

	s2cCollectUpdate(actor, tp, id)
	updateAttr(actor, true)
end


actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeLevel, onLevelUp)
netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cTaskCmd_CollectReward, c2sCollectReward)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.collectreward = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeShort(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sCollectReward(actor)
	return true
end

gmCmdHandlers.collectfinish = function (actor, args)
	local tp = tonumber(args[1])
	local data = getActorVar(actor)
	if args[2] then
		local id = tonumber(args[2])
		local var = data[tp] and data[tp][id]
		var.status = taskcommon.statusType.emCanAward
		s2cCollectUpdate(actor, tp, id)
	else
		for id, v in pairs(CollectTaskConfig[tp]) do
			local var = data[tp] and data[tp][id]
			if var then
				var.status = taskcommon.statusType.emCanAward
				s2cCollectUpdate(actor, tp, id)
			end
		end
	end
	return true
end

gmCmdHandlers.collectclean = function (actor, args)
	local data = getActorVar(actor)
	for k, v in pairs(CollectTaskConfig) do
		data[k] = nil
	end
	collectInit(actor)
	s2cCollectInfo(actor)
	return true
end

gmCmdHandlers.collectclean1 = function (actor, args)
	local data = getActorVar(actor)
	for tp, config in ipairs(CollectTaskConfig) do
		for id, conf in ipairs(config) do
			if data[tp] and data[tp][id] then
				data[tp][id].curValue = 0
				data[tp][id].status = taskcommon.statusType.emDoing
			end
		end
	end
	s2cCollectInfo(actor)
	return true
end
