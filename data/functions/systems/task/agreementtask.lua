-- @system  契约系统

module("agreementtask", package.seeall)

local function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end
	if (var.agreementData == nil) then
		var.agreementData = {}
	end
	return var.agreementData
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
		if conf.type == taskcommon.taskType.emJJCRank then			
			var.curValue = jjcrank.getrank(actor)
		elseif taskevent.needParam(conf.type) then
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

		if conf.type == taskcommon.taskType.emJJCRank then
			if var.curValue ~= 0 and var.curValue <= conf.target then
				var.status = taskcommon.statusType.emCanAward
			end
		elseif var.curValue >= conf.target then --契约完成
			var.status = taskcommon.statusType.emCanAward
		end
	end
	return var
end

local function agreementInit(actor)
	local data = getActorVar(actor)
	for tp, config in pairs(AgreementConfig) do 
		if AgreementTypeConfig[tp].last == 0 then
			if not data[tp] then data[tp] = {} end
			for id, conf in pairs(config) do
				if not data[tp][id] then
					data[tp][id] = initTask(actor, conf)
				end
			end
		end
	end
end

--检测这一类型的契约是否全激活
function checkActive(data, tp)
	if not data[tp] then return false end
	for id,conf in pairs(AgreementConfig[tp]) do
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
	--if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.agreement) then return end
	local data = getActorVar(actor) 
	if not data then return end --触发时玩家不在线
	for tp, config in pairs(AgreementConfig) do 
		local isUpdate = false
		for id, conf in pairs(config) do
			repeat
				local var = data[tp] and data[tp][id]
				if not var then break end
				if taskType ~= conf.type or var.status ~= taskcommon.statusType.emDoing then break end
				if conf.param[1] ~= -1 and not utils.checkTableValue(conf.param, param) then break end
				updateCurValue(taskType, var, value)
				if taskType == taskcommon.taskType.emJJCRank then
					if var.curValue > conf.target then
						s2cAgreementUpdate(actor, tp, id)
						break
					end
				elseif var.curValue < conf.target then 
					s2cAgreementUpdate(actor, tp, id)
					break 
				end
				var.status = taskcommon.statusType.emCanAward
				s2cAgreementUpdate(actor, tp, id)
				isUpdate = true
			until(true)
		end
		if isUpdate then break end
	end
end

function onInit(actor)
	agreementInit(actor)
end

function onLogin(actor)
	--if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.agreement) then return end
	s2cAgreementInfo(actor)
end


function onCustomChange(actor, custom, oldcustom)
	if LimitConfig[actorexp.LimitTp.agreement].custom > oldcustom and LimitConfig[actorexp.LimitTp.agreement].custom <= custom then
		s2cAgreementInfo(actor)
	end
end
---------------------------------------------------------------------------------
--契约信息
function s2cAgreementInfo(actor)
	local data = getActorVar(actor)
	if not data then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sTaskCmd_AgreementInfo)
	if pack == nil then return end
	LDataPack.writeChar(pack, #AgreementConfig)
	for tp, config in ipairs(AgreementConfig) do
		LDataPack.writeChar(pack, tp)
		LDataPack.writeShort(pack, #config)
		for id, conf in ipairs(config) do
			local var = data[tp] and data[tp][id] or {}

			--对老玩家的特殊处理，新任务类型，再读一次数据
			if var.status == taskcommon.statusType.emDoing then
				if conf.type == taskcommon.taskType.emRecharge then
					local actordata = LActor.getActorData(actor)
					var.curValue = actordata.recharge
				elseif conf.type == taskcommon.taskType.emDamonGroup then
					var.curValue = damonsystem.getGruopCount(actor)
				end
				if conf.type == taskcommon.taskType.emJJCRank then
					if var.curValue and var.curValue ~= 0 and var.curValue <= conf.target then
						var.status = taskcommon.statusType.emCanAward
					end
				elseif (var.curValue or 0) >= conf.target then
					var.status = taskcommon.statusType.emCanAward
				end
			end

			LDataPack.writeShort(pack, id)
			LDataPack.writeDouble(pack, var.curValue or 0)
			LDataPack.writeChar(pack, var.status or 0)
		end
	end
	LDataPack.flush(pack)
end

--单个契约更新
function s2cAgreementUpdate(actor, tp, id)
	local data = getActorVar(actor)
	if not data then return end
	local var = data[tp][id]
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sTaskCmd_AgreementUpdate)
	if pack == nil then return end
	LDataPack.writeChar(pack, tp)
	LDataPack.writeShort(pack, id)
	LDataPack.writeDouble(pack, var.curValue)
	LDataPack.writeChar(pack, var.status)
	LDataPack.flush(pack)
end

--契约领奖
function c2sAgreementReward(actor, packet)
	local tp = LDataPack.readChar(packet)
	local id = LDataPack.readShort(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.agreement) then return end
	local conf = AgreementConfig[tp] and AgreementConfig[tp][id]
	if not conf then return	end
	local data = getActorVar(actor)
	local var = data[tp] and data[tp][id]
	if not var then return end

	if var.status ~= taskcommon.statusType.emCanAward then
		return
	end
	var.status = taskcommon.statusType.emHaveAward
	actoritem.addItems(actor, conf.rewards, "agreement one reward")

	s2cAgreementUpdate(actor, tp, id)

	--新任务类型创建
	if checkActive(data, tp) then
		--noticesystem.broadCastNotice(noticesystem.NTP.agreement, LActor.getName(actor), AgreementTypeConfig[tp].name)
		local newTp = AgreementTypeConfig[tp].next
		if newTp > 0 then
			if not data[newTp] then data[newTp] = {} end
			for k, v in pairs(AgreementConfig[newTp]) do
				if not data[newTp][k] then
					data[newTp][k] = initTask(actor, v)
				end
			end
			s2cAgreementInfo(actor)
		end
		actoritem.addItems(actor, AgreementTypeConfig[tp].items, "agreement all reward")
	end
	actorevent.onEvent(actor, aeAgreementTask)
end

actorevent.reg(aeCustomChange, onCustomChange, 1)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cTaskCmd_AgreementReward, c2sAgreementReward)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.agreereward = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeShort(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sAgreementReward(actor)
	return true
end

gmCmdHandlers.agreefinish = function (actor, args)
	local tp = tonumber(args[1])
	local data = getActorVar(actor)
	if args[2] then
		local id = tonumber(args[2])
		local var = data[tp] and data[tp][id]
		var.status = taskcommon.statusType.emCanAward
		s2cAgreementUpdate(actor, tp, id)
	else
		for id, v in pairs(AgreementConfig[tp]) do
			local var = data[tp] and data[tp][id]
			if var then
				var.status = taskcommon.statusType.emCanAward
				s2cAgreementUpdate(actor, tp, id)
			end
		end
	end
	return true
end

gmCmdHandlers.agreeclean = function (actor, args)
	local data = getActorVar(actor)
	for k, v in pairs(AgreementConfig) do
		data[k] = nil
	end
	agreementInit(actor)
	s2cAgreementInfo(actor)
	return true
end

gmCmdHandlers.agreeclean1 = function (actor, args)
	local data = getActorVar(actor)
	for tp, config in ipairs(AgreementConfig) do
		for id, conf in ipairs(config) do
			if data[tp] and data[tp][id] then
				data[tp][id].curValue = 0
				data[tp][id].status = taskcommon.statusType.emDoing
			end
		end
	end
	s2cAgreementInfo(actor)
	return true
end
