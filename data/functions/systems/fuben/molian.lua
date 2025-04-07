-- @system  魔炼之地

module("molian", package.seeall)
require("scene.molianfuben")
require("scene.moliancommon")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end

	if not var.moliandata then
		var.moliandata = {
			curId = 1, --Nível atual
			resetCount = 0, --Redefinir tempos
			isreward = 0, --Você reivindicou o prêmio?
			firstId = 1, --O id usado no primeiro nível
			finish = 0,	--Acabou?
			isfail = 0,	--Falhou
			bloods = 10000, --A saúde restante dos três personagens
			isFirst = 1, --É o primeiro desafio?
		}
	end
	return var.moliandata	
end

--Redefinir cópia
function molianFubenReset(actor)
	local var = getActorVar(actor)
	if var.finish == 1 then --Após completar 15 níveis, a dificuldade da cópia aumenta.
		local firstId = var.firstId + MolianCommonConfig.jump --Salte 5 níveis
		if firstId <= #MolianFubenConfig - MolianCommonConfig.gate + 1 then
			var.firstId = firstId
			s2cMolianConfig(actor)
		end
	end
	var.curId = 1
	var.isreward = 0
	var.finish = 0
	var.isfail = 0
	var.bloods = 10000
end

--------------------------------------------------------------------------------------------------
function s2cMolianInfo(actor, islogin)
	local var = getActorVar(actor)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_MolianInfo)
	if pack == nil then return end
	LDataPack.writeShort(pack, var.firstId + var.curId - 1) 		--挑战到哪关
	LDataPack.writeChar(pack, var.resetCount)	--今天已重置次数
	local blood = (not islogin and var.isfail == 1) and 0 or (var.bloods or 10000)--血量万分比，失败就是0
	LDataPack.writeShort(pack, blood)
	LDataPack.writeByte(pack, var.finish)		--是否打完
	LDataPack.writeByte(pack, var.isreward)		--是否已领奖
	LDataPack.writeByte(pack, var.isFirst)
	LDataPack.flush(pack)
end

--魔炼之地挑战
function c2sMolianFight(actor, packet)
	local var = getActorVar(actor)
	if not var then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.molian) then
		return
	end
	if var.finish == 1 then return end
	if var.isfail == 1 then return end
	var.isFirst = 0
	local idx = var.firstId + var.curId - 1
	local config = MolianFubenConfig[idx]
	if not config then return end	
	if not utils.checkFuben(actor, config.fbid) then return end
	local hfuben = instancesystem.createFuBen(config.fbid)
	if hfuben == 0 then return end
	local x, y = utils.getSceneEnterCoor(config.fbid)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
end

--魔炼之地重置
function c2sMolianReset(actor, packet)
	local var = getActorVar(actor)

	local svip = LActor.getSVipLevel(actor)
	if var.resetCount >= SVipConfig[svip].molianReset then
		return
	end
	local price = MolianCommonConfig.resetPrice[var.resetCount+1]
	if not price then return end
	if not actoritem.checkItem(actor, NumericType_YuanBao, price) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, price, "molian reset")
	var.resetCount = var.resetCount + 1
	molianFubenReset(actor)
	s2cMolianInfo(actor)
	actorevent.onEvent(actor, aeMoLianRest)
end

--魔炼之地奖励
function c2sMolianReward(actor, packet)
	local var = getActorVar(actor)
	if var.finish == 0 then return end
	if var.curId < MolianCommonConfig.gate then return end
	if var.isreward == 1 then return end --已领取
	local conf = MolianFubenConfig[var.firstId]
	var.isreward = 1
	actoritem.addItems(actor, conf.passRewards, "molian passreward")
	s2cMolianInfo(actor)
end

--魔炼配置内容
function s2cMolianConfig(actor)
	local var = getActorVar(actor)
	if not var then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_MolianConfig)
	if pack == nil then return end
	LDataPack.writeChar(pack, MolianCommonConfig.gate) 
	for i=1, MolianCommonConfig.gate do
		local id = var.firstId + i - 1
		local conf = MolianFubenConfig[id]
		LDataPack.writeShort(pack, id)
		LDataPack.writeString(pack, conf.name)
		LDataPack.writeShort(pack, MonstersConfig[conf.monsterid].avatar[1])

		LDataPack.writeChar(pack, #conf.rewards)
		for k, v in ipairs(conf.rewards) do
			LDataPack.writeInt(pack, v.type)
			LDataPack.writeInt(pack, v.id)
			LDataPack.writeInt(pack, v.count)
		end
	end
	LDataPack.writeChar(pack, #MolianFubenConfig[var.firstId].passRewards)
	for k, v in ipairs(MolianFubenConfig[var.firstId].passRewards) do --通关奖励
		LDataPack.writeInt(pack, v.type)
		LDataPack.writeInt(pack, v.id)
		LDataPack.writeInt(pack, v.count)
	end
	LDataPack.flush(pack)
end

--魔炼结算
function s2cMolianResult(actor, rewards)
	local var = getActorVar(actor)
	if not var then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.cFubenCmd_MolianResult)
	if pack == nil then return end
	LDataPack.writeChar(pack, var.curId - 1)
	LDataPack.writeShort(pack, var.bloods)
	LDataPack.writeShort(pack, #rewards)
	for k, v in ipairs(rewards) do
		LDataPack.writeInt(pack, v.type)
		LDataPack.writeInt(pack, v.id)
		LDataPack.writeDouble(pack, v.count)
	end
	LDataPack.flush(pack)
end
--------------------------------------------------------------------------------------------------------------

function onFbWin(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then return end
	local var = getActorVar(actor)
	if not var then return end
	var.isfail = 0
	local id = var.firstId + var.curId - 1
	if var.curId >= MolianCommonConfig.gate then
		var.finish = 1
		noticesystem.broadCastNotice(noticesystem.NTP.molian, LActor.getName(actor), math.ceil(var.firstId/5))
	end
	var.curId = var.curId + 1

	--记录血量
	local role = LActor.getRole(actor)
	local hp = LActor.getHp(role)
	local maxHp = LActor.getHpMax(role)
	var.bloods = math.ceil(hp/maxHp*10000)
	local conf = MolianFubenConfig[id]
	instancesystem.setInsRewards(ins, actor, conf.rewards)
	s2cMolianResult(actor, conf.rewards)
	s2cMolianInfo(actor)
end

local function exit(actor, ins)
	LActor.exitFuben(actor)
end

function onFbLose(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then return end
	local var = getActorVar(actor)
	if not var then return end
	ins:notifyRewards(actor, true)
	--instancesystem.DelayExit(actor)
	s2cMolianInfo(actor)
end

function onEnterFb(ins, actor)
	if ins.is_end then --已失败的副本，再进会退出
		ins:notifyRewards(actor, true)
		LActor.postScriptEventLite(actor, 1000, exit, ins)
	end
	local var = getActorVar(actor)
	if not var then return end
	var.isfail = 1 --进入副本时就默认失败，胜利后再设回来

	local role = LActor.getRole(actor)
	local rate = var.bloods
	local maxHp = LActor.getHpMax(role)
	local damage = math.ceil(maxHp * (10000-rate) / 10000) --受到的伤害
	LActor.changeHp(role, -damage)
end

function onEnterBefore(ins, actor, islogin)
	if islogin then
		s2cMolianInfo(actor, islogin)
	end
end
function onExitFb(ins, actor)
	s2cMolianInfo(actor)
end

function onOffline(ins, actor)
	--记录血量
	local var = getActorVar(actor)
	if not var then return end
	local role = LActor.getRole(actor)
	local hp = LActor.getHp(role)
	local maxHp = LActor.getHpMax(role)
	var.bloods = math.ceil(hp/maxHp*10000)
end

function onLogin(actor)
	s2cMolianConfig(actor)
	local fbid = LActor.getFubenId(actor)
	if FubenConfig[fbid].group ~= 10026 then
		s2cMolianInfo(actor)		
	end
end

function onNewDay(actor, login)
	local var = getActorVar(actor)
	if not var then return end
	var.resetCount = 0
	if not login then
		s2cMolianInfo(actor)
	end
end

local function initGlobalData()
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)
	
	if System.isCrossWarSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_MolianFight, c2sMolianFight)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_MolianReset, c2sMolianReset)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_MolianReward, c2sMolianReward)

	--注册相关回调
	for _, config in pairs(MolianFubenConfig) do
		insevent.registerInstanceWin(config.fbid, onFbWin)
		insevent.registerInstanceLose(config.fbid, onFbLose)
		insevent.registerInstanceEnter(config.fbid, onEnterFb)
		insevent.registerInstanceExit(config.fbid, onExitFb)
		insevent.registerInstanceOffline(config.fbid, onOffline)
		insevent.registerInstanceEnterBefore(config.fbid, onEnterBefore)
	end
end
table.insert(InitFnTable, initGlobalData)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.molianfight = function (actor, args)
	c2sMolianFight(actor)
end

gmCmdHandlers.molianreset = function (actor, args)
	c2sMolianReset(actor)
end

gmCmdHandlers.molianreward = function (actor, args)
	c2sMolianReward(actor)
end

gmCmdHandlers.molianfirstId = function(actor, args)
	local var = getActorVar(actor)
	var.firstId = tonumber(args[1])
	s2cMolianInfo(actor)
end

gmCmdHandlers.molianpass = function (actor, args)
	local var = getActorVar(actor)
	var.curId = tonumber(args[1])
	if var.curId > MolianCommonConfig.gate then
		var.finish = 1
	end
	s2cMolianInfo(actor)
end

gmCmdHandlers.Molianfight = function (actor,args)
	local Num = tonumber(args[1]) or 1
	local var = getActorVar(actor)
	for i=1,Num do
		var.resetCount = 0
		c2sMolianFight(actor)
		print ("Molianfight_count: "..i)
		LActor.exitFuben(actor)
		c2sMolianReset(actor)
	end
	return true
end

gmCmdHandlers.MolianSetBlood = function (actor,args)
	--记录血量
	local var = getActorVar(actor)
	if not var then return end

	local role = LActor.getRole(actor)
	var.bloods = 0
	--s2cMolianInfo(actor)
end
