-- @version	1.0
-- @author	qianmeng
-- @date	2017-1-16 17:47:58.
-- @system	guzhanchang

--古战场副本
module("guzhanchang", package.seeall)
require("scene.guzhanchang")

g_guzhanchang_open = g_guzhanchang_open or false

--返回一个古战场副本
local function getGuzhanchanFuben()
	local var = System.getDyanmicVar()

	if not var.g_guzhanchangData then 
		var.g_guzhanchangData = {} --古战场的所有副本handle
	end

	--副本少于5人就直接进入
	for k, hf in pairs(var.g_guzhanchangData) do
		if Fuben.getFubenPtr(hf) then
			local ins = instancesystem.getInsByHdl(hf)
			if ins and ins.actor_list_count < GuzhanchangConfig.people then
				return hf
			end
		end
	end

	--没有空位置了，就重新建一个新的主城副本
	local hfuben = instancesystem.createFuBen(GuzhanchangConfig.fbId)
	if hfuben == 0 then return end
	table.insert(var.g_guzhanchangData, hfuben)

	local ins = instancesystem.getInsByHdl(hfuben)
	guzhanchangrefresh.init(ins)
	return hfuben
end

function getActorVar(actor)
	if not actor then return end

	local var = LActor.getStaticVar(actor)
	if not var then return end

	if not var.guzhanchangfuben then
		var.guzhanchangfuben = {}
	end
	var = var.guzhanchangfuben
	if not var.cdTime then var.cdTime = 0 end
	if not var.frag then var.frag = 0 end --杀敌数量
	if not var.isBuy then var.isBuy = 0 end --是否有购买额外奖励
	if not var.isGet then var.isGet = 0 end
	return var	
end

function getDyanmicVar(actor)
	local var = LActor.getGlobalDyanmicVar(actor)
	if not var.guzhanchangfuben then
		var.guzhanchangfuben = {
			rewards0 = {},
		}
	end
	return var.guzhanchangfuben
end

--是否在双倍掉落时间内
function isDoubleTime(actor)
	if actor and LActor.getFubenId(actor) == GuzhanchangConfig.fbId then
		return g_guzhanchang_open
	end
	return false
end

local function exit(actor, ins)
	LActor.exitFuben(actor)
end

local function onEnterBefore(ins, actor)
	local monIdList = {}
	for k, v in pairs(GuzhanchangMonsterConfig) do
		table.insert(monIdList, k)
	end
	slim.s2cMonsterConfig(actor, monIdList)
end

-------------------------------------------------------------------------------------------------------
--古战场信息
function s2cGuzhanchangInfo(actor)
	local var = getActorVar(actor)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_GuzhanchangInfo)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.cdTime - System.getNowTime())
	LDataPack.writeInt(pack, var.frag)
	LDataPack.writeByte(pack, var.isBuy)
	LDataPack.writeByte(pack, g_guzhanchang_open and 1 or 0)
	LDataPack.flush(pack)
end

--古战场战斗
function c2sGuzhanchangFight(actor, packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.guzhanchang) then return end

	local var = getActorVar(actor)
	if not var then return end
	if var.cdTime > System.getNowTime() then --检查cd
		return
	end
	local conf = GuzhanchangConfig
	if var.frag >= conf.maxKill then return end
	if not utils.checkFuben(actor, conf.fbId) then return end
	local hfuben = getGuzhanchanFuben()
	if not hfuben then return end

	local x, y = utils.getSceneEnterCoor(conf.fbId)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
	noticesystem.broadCastNotice(noticesystem.NTP.guzhanchang, LActor.getName(actor))
end

--更新杀怪数量
function s2cGuzhanchangFrag(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_GuzhanchangFrag)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.frag)
	LDataPack.flush(pack)
end

--查看本日奖励记录
function c2sGuzhanchangRecord(actor, packet)
	local dvar = getDyanmicVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_GuzhanchangRecord)
	if pack == nil then return end
	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeShort(pack, count)
	for id, v in pairs(dvar.rewards0) do
		local tp = id < 1000 and 0 or 1
		LDataPack.writeInt(pack, tp)
		LDataPack.writeInt(pack, id)
		LDataPack.writeInt(pack, v)
		count = count + 1
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeShort(pack, count)
	LDataPack.setPosition(pack, npos)
	LDataPack.flush(pack)
end

--购买额外奖励
function c2sGuzhanchangBuy(actor, packet)
	local conf = GuzhanchangConfig
	local var = getActorVar(actor)
	if not var then return end
	if var.frag < conf.maxKill then return end
	if var.isBuy == 1 then return end
	if not actoritem.checkItem(actor, NumericType_YuanBao, conf.price) then 
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, conf.price, "buy guzhanchang")

	var.isBuy = 1
	actoritem.addItems(actor, conf.extraReward, "buy guzhanchang")
	s2cGuzhanchangInfo(actor)
end

--奖励结算
function s2cGuzhanchangResult(actor)
	local var = getActorVar(actor)
	local dvar = getDyanmicVar(actor)
	if not var then return end
	local conf = GuzhanchangConfig
	if var.isGet == 0 then
		var.isGet = 1
		actoritem.addItems(actor, conf.dayReward, "guzhanchang dayReward")
	end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_GuzhanchangResult)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.frag)
	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeShort(pack, count)
	for id, v in pairs(dvar.rewards0) do
		local tp = id < 1000 and 0 or 1
		LDataPack.writeInt(pack, tp)
		LDataPack.writeInt(pack, id)
		LDataPack.writeInt(pack, v)
		count = count + 1
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeShort(pack, count)
	LDataPack.setPosition(pack, npos)
	-- LDataPack.writeShort(pack, #conf.dayReward)
	-- for k, v in pairs(conf.dayReward) do
	-- 	LDataPack.writeInt(pack, v.type)
	-- 	LDataPack.writeInt(pack, v.id)
	-- 	LDataPack.writeInt(pack, v.count)
	-- end
	LDataPack.flush(pack)
end


--每天刷新处理
local function onNewDay(actor, login)
	if System.isBattleSrv() then return end
	local var = getActorVar(actor)
	if not var then return end
	var.frag = 0
	var.isBuy = 0
	var.isGet = 0
	local dvar = getDyanmicVar(actor)
	dvar.rewards0 = {}
	if not login then
		s2cGuzhanchangInfo(actor)
	end
end

local function onLogin(actor)
	if System.isBattleSrv() then return end
	s2cGuzhanchangInfo(actor)
end


--进入副本处理
local function onEnter(ins, actor)
	-- local var = getActorVar(actor)
	-- if not var then return end
	-- s2cGuzhanchangInfo(actor)
end

--退出副本处理
local function onExit(ins, actor)
	local var = getActorVar(actor)
	if not var then return end
	var.cdTime = System.getNowTime() + GuzhanchangConfig.cdTime 
	s2cGuzhanchangInfo(actor)
	ins:giveFubenReward(actor)
end

local function onOffline(ins, actor)
	--LActor.exitFuben(actor) --离线后，退出副本
end

--玩家死亡
local function onActorDie(ins, actor, killHdl)
	local et = LActor.getEntity(killHdl)
	local killer_actor = LActor.getActor(et)
	--杀人者处理
	local var = getActorVar(killer_actor)
	if not var then return end
	local dvar = getDyanmicVar(killer_actor)


	local rewards = drop.dropGroup(GuzhanchangConfig.pkDrop)
	if g_guzhanchang_open then --掉落物变双倍
		for k, v in pairs(rewards) do
			v.count = v.count * 2
		end
	end
	local posX, posY = LActor.getEntityScenePoint(actor)
	ins:addDropBagItem(killer_actor, rewards, 100, posX, posY)
	var.frag = var.frag + 1
	s2cGuzhanchangFrag(killer_actor)
	if var.frag >= GuzhanchangConfig.maxKill then
		var.frag = GuzhanchangConfig.maxKill
		LActor.exitFuben(killer_actor)
		s2cGuzhanchangResult(killer_actor)
	end
end

local function onMonsterDie(ins, mon, killHdl)
	local et = LActor.getEntity(killHdl)
	local killer_actor = LActor.getActor(et)
	local var = getActorVar(killer_actor)
	if not var then return end
	var.frag = var.frag + 1
	s2cGuzhanchangFrag(killer_actor)
	if var.frag >= GuzhanchangConfig.maxKill then
		var.frag = GuzhanchangConfig.maxKill
		LActor.exitFuben(killer_actor)
		s2cGuzhanchangResult(killer_actor)
	end
	guzhanchangrefresh.onMonsterDie(ins, mon, killHdl)
end

local function onPickItem(ins, actor, tp, id, count)
	local dvar = getDyanmicVar(actor)
	dvar.rewards0[id] = (dvar.rewards0[id] or 0) + count
end

--双倍掉落开启
function GuzhanchangStart()
	g_guzhanchang_open = true
	local actors = System.getOnlineActorList()
	if actors ~= nil then
		for i =1,#actors do
			s2cGuzhanchangInfo(actors[i])
		end
	end
end

--双倍掉落结束
function GuzhanchangStop()
	g_guzhanchang_open = false
	local actors = System.getOnlineActorList()
	if actors ~= nil then
		for i =1,#actors do
			s2cGuzhanchangInfo(actors[i])
		end
	end
end

function flushStartGuzhanchang1()
	if System.isBattleSrv() then return end
	GuzhanchangStart()
end
_G.flushStartGuzhanchang1 = flushStartGuzhanchang1

function flushStopGuzhanchang1()
	if System.isBattleSrv() then return end
	GuzhanchangStop()
end
_G.flushStopGuzhanchang1 = flushStopGuzhanchang1
_G.flushStartGuzhanchang2 = flushStartGuzhanchang1
_G.flushStopGuzhanchang2 = flushStopGuzhanchang1

local function checkCanStart()
	local t = os.time()
	local hour = utils.getHours(t)
	local minute = utils.getMin(t)
	for k, v in pairs(TimerConfig) do
		if v.func == "flushStartGuzhanchang1" or v.func == "flushStartGuzhanchang2" then
			if hour == v.hour and minute >= v.minute then
				flushStartGuzhanchang1()
			end
		end
	end
end

--避免双倍经验时间里重启服务器不会开启双倍经验
local function initGlobalData()
	if System.isBattleSrv() then return end
	
	checkCanStart()
	
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeUserLogin, onLogin)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_GuzhanchangFight, c2sGuzhanchangFight)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_GuzhanchangRecord, c2sGuzhanchangRecord)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_GuzhanchangBuy, c2sGuzhanchangBuy)

	--注册相关回调
	local conf = GuzhanchangConfig
	insevent.registerInstanceEnter(conf.fbId, onEnter)
	insevent.registerInstanceEnterBefore(conf.fbId, onEnterBefore)
	insevent.registerInstanceExit(conf.fbId, onExit)	
	-- insevent.registerInstanceOffline(conf.fbId, onOffline)
	insevent.registerInstanceActorDie(conf.fbId, onActorDie)
	insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
	insevent.registerInstancePickItem(conf.fbId, onPickItem)
end
table.insert(InitFnTable, initGlobalData)


--local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.guzhanchangenter = function (actor, args)
	local hfuben = getGuzhanchanFuben()
	if not hfuben then return end
	local monIdList = {}
	for k, v in pairs(GuzhanchangMonsterConfig) do
		table.insert(monIdList, k)
	end
	slim.s2cMonsterConfig(actor, monIdList)
	local x, y = utils.getSceneEnterCoor(conf.fbId)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
	return true
end

gmCmdHandlers.guzhanchangfight = function (actor, args)
	c2sGuzhanchangFight(actor)
	return true
end

gmCmdHandlers.guzhanchangrecord = function (actor)
	c2sGuzhanchangRecord(actor)
	return true	
end

gmCmdHandlers.guzhanchangbuy = function (actor)
	c2sGuzhanchangBuy(actor)
	return true	
end

gmCmdHandlers.guzhanchangstart = function (actor, args)
	if tonumber(args[1]) == 2 then
		flushStartGuzhanchang1()
	else
		flushStartGuzhanchang1()
	end
	return true
end

gmCmdHandlers.guzhanchangstop = function (actor, args)
	if tonumber(args[1]) == 2 then
		flushStopGuzhanchang1()
	else
		flushStopGuzhanchang1()
	end
	return true
end
