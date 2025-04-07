-- @version	1.0
-- @author	qianmeng
-- @date	2017-1-16 17:47:58.
-- @system	guzhanchang

--古战场副本
module("guzhanchang", package.seeall)
require("scene.guzhanchang")

GUZHANCHANG_HANDLE = GUZHANCHANG_HANDLE or 0
guzhanchang_isopen = guzhanchang_isopen or 0
guzhanchang_endtime = guzhanchang_endtime or 0


local function getGlobalData()
    local data = System.getStaticVar()
    if data.guzhanchang == nil then data.guzhanchang = {} end
    if data.guzhanchang.rank == nil then data.guzhanchang.rank = {} end
    return data.guzhanchang
end

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

	--没有空位置了，就重新建一个新的副本
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
		var.guzhanchangfuben = {
			cdTime = 0,
			frag = 0,
			isBuy = 0,
			isGet = 0,
			rewardscount = 0,
			rewards = {},
			joincount = 0, --参与次数
			joinupdate = 0, --参与次数更新时间
			firstcount = 0, --第一名次数
			entertime = 0, --进入副本时间
			intime = 0, --在副本时间
			firststatus = 0, --第一名奖励是否已领取
			joinstatus = 0, --参与奖是否已领取
		}
	end
	return var.guzhanchangfuben	
end


local function onEnterBefore(ins, actor)
	local monIdList = {}
	for k, v in pairs(GuzhanchangMonsterConfig) do
		table.insert(monIdList, k)
	end
	slim.s2cMonsterConfig(actor, monIdList)
end

-------------------------------------------------------------------------------------------------------
function sendFubenHandle(sId)
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, CrossSrvCmd.SCGuzhan)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCGuzhan_SyncUpdateFbInfo)
	LDataPack.writeInt64(pack, GUZHANCHANG_HANDLE)
	System.sendPacketToAllGameClient(pack, sId or 0)
end

--古战场信息
function s2cGuzhanchangInfo(actor)
	local var = getActorVar(actor)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_GuzhanchangInfo)
	if pack == nil then return end
	LDataPack.writeChar(pack, guzhanchang_isopen)
	LDataPack.writeInt(pack, (var.cdTime or 0) - System.getNowTime())
	LDataPack.writeInt(pack, var.frag)
	LDataPack.writeByte(pack, var.isBuy)
	LDataPack.writeInt(pack, guzhanchang_endtime - System.getNowTime())
	LDataPack.flush(pack)
end

function c2sGetReward(actor, pack)
	local type = LDataPack.readChar(pack)
	local var = getActorVar(actor)
	if type == 1 then
		if var.firststatus == 1 then return end
		if var.firstcount < GuzhanchangConfig.firsttimes then
			return
		end
		var.firststatus = 1
		actoritem.addItem(actor, GuzhanchangConfig.firsttitle, 1, "guzhanchang title")
		noticesystem.broadAllServerContent(1, string.format(NoticeConfig[noticesystem.NTP.gzcfirst].content, LActor.getName(actor)))
	else
		if var.joinstatus == 1 then return end
		if var.joincount < GuzhanchangConfig.jointimes then
			return
		end
		var.joinstatus = 1
		actoritem.addItem(actor, GuzhanchangConfig.jointtitle, 1, "guzhanchang title")
		noticesystem.broadAllServerContent(1, string.format(NoticeConfig[noticesystem.NTP.gzcjoin].content, LActor.getName(actor)))
	end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_GuzhanchangGetRewardRet)
	if pack == nil then return end
	LDataPack.writeChar(pack, type)
	LDataPack.flush(pack)
end

function c2sGetRank(actor, pack)
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, CrossSrvCmd.SCGuzhan)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCGuzhan_GetRank)
	LDataPack.writeInt(pack, LActor.getActorId(actor))
	System.sendPacketToAllGameClient(pack, 0)
end

local function onGetRank(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local data = getGlobalData()
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, CrossSrvCmd.SCGuzhan)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCGuzhan_SendRank)
	LDataPack.writeInt(pack, actorid)
	LDataPack.writeShort(pack, #data.rank)
	local myrank = 0
	for k,v in ipairs(data.rank) do
		LDataPack.writeString(pack, v.name)
		LDataPack.writeString(pack, v.guildname)
		LDataPack.writeInt(pack, v.time)
		if v.actorid == actorid then
			myrank = k
		end
	end
	LDataPack.writeShort(pack, myrank)
	System.sendPacketToAllGameClient(pack, sId)
end

local function onSendRank(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorid)
	if not actor then
		return
	end
	local count = LDataPack.readShort(cpack)
	local var = getActorVar(actor)
	
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_GuzhanchangSendRank)
	if pack == nil then return end
	LDataPack.writeShort(pack, count)
	for i=1, count do
		LDataPack.writeString(pack,	LDataPack.readString(cpack))
		LDataPack.writeString(pack,	LDataPack.readString(cpack))
		LDataPack.writeInt(pack, LDataPack.readInt(cpack))
	end
	LDataPack.writeShort(pack, LDataPack.readShort(cpack))
	LDataPack.writeInt(pack, var.firstcount)
	LDataPack.writeInt(pack, var.joincount)
	LDataPack.writeChar(pack, var.firststatus)
	LDataPack.writeChar(pack, var.joinstatus)
	LDataPack.flush(pack)
end
--古战场战斗
function c2sGuzhanchangFight(actor, packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.guzhanchang) then return end
	if not actorlogin.checkCanEnterCross(actor) then return end
	local var = getActorVar(actor)
	if not var then return end
	if (var.cdTime or 0) > System.getNowTime() then --检查cd
		return
	end
	local conf = GuzhanchangConfig
	if var.frag >= conf.maxKill then return end
	-- if not utils.checkFuben(actor, conf.fbId) then return end
	-- local hfuben = getGuzhanchanFuben()
	-- if not hfuben then return end
	if GUZHANCHANG_HANDLE == 0 then return end

	local x, y = utils.getSceneEnterCoor(conf.fbId)
	local crossId = csbase.getCrossServerId()
	LActor.loginOtherServer(actor, crossId, GUZHANCHANG_HANDLE, 0, x, y, "cross")	
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
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_GuzhanchangRecord)
	if pack == nil then return end
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeShort(pack, var.rewardscount)
	for i=1, var.rewardscount do
		LDataPack.writeInt(pack, var.rewards[i].type)
		LDataPack.writeInt(pack, var.rewards[i].id)
		LDataPack.writeInt(pack, var.rewards[i].count)
	end
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
	LDataPack.writeShort(pack, var.rewardscount)
	for i=1, var.rewardscount do
		LDataPack.writeInt(pack, var.rewards[i].type)
		LDataPack.writeInt(pack, var.rewards[i].id)
		LDataPack.writeInt(pack, var.rewards[i].count)
	end
	LDataPack.writeInt(pack, var.intime)
	LDataPack.flush(pack)
end


--每天刷新处理
local function onNewDay(actor, login)
	local var = getActorVar(actor)
	if not var then return end
	var.frag = 0
	var.isBuy = 0
	var.isGet = 0
	var.rewardscount = 0
	var.entertime = 0
	var.intime = 0
	var.joinupdate = 0
	var.isexit = nil
	local Y,M,d = System.getDate()
	guzhanchang_endtime = System.timeEncode(Y, M, d, GuzhanchangConfig.starTime[2][1], GuzhanchangConfig.starTime[2][2], 0)	
	if not login then
		s2cGuzhanchangInfo(actor)
	end
end

local function onLogin(actor)
	if System.isCrossWarSrv() then return end
	s2cGuzhanchangInfo(actor)
	sendRewardInfo(actor)
end

local function onGuzhanFbInfo(sId, sType, cpack)
	GUZHANCHANG_HANDLE = LDataPack.readInt64(cpack)
end

--进入副本处理
local function onEnter(ins, actor)
	-- local var = getActorVar(actor)
	-- if not var then return end
	-- s2cGuzhanchangInfo(actor)
	local before = GUZHANCHANG_HANDLE
	GUZHANCHANG_HANDLE = getGuzhanchanFuben()
	if before ~= GUZHANCHANG_HANDLE then
		sendFubenHandle()
	end
	local var = getActorVar(actor)
	var.isexit = nil
	local now = System.getNowTime()
	if not System.isSameDay(var.joinupdate, now) then
		var.joincount = var.joincount + 1
		var.joinupdate = now
		sendRewardInfo(actor)
	end
	var.entertime = now

	noticesystem.broadCastCrossNotice(noticesystem.NTP.guzhanchang, LActor.getName(actor))
end

local function checkRank(actor, var)
	if var.frag >= GuzhanchangConfig.maxKill and var.intime > 120 then
		local actorid = LActor.getActorId(actor)
		local data = getGlobalData()
		for k,v in ipairs(data.rank) do
			if v.actorid == actorid then
				return
			end
		end
		local  guildname = ""
		local guildId = LActor.getGuildId(actor)
		if guildId ~= 0 then
			guildname = LGuild.getGuilNameById(guildId)
		end
		table.insert(data.rank, {name = LActor.getName(actor), guildname = guildname, actorid = actorid, time = var.intime, serverid = LActor.getServerId(actor)})
		table.sort(data.rank, function(a,b) return a.time < b.time end)
	end
end

--退出副本处理
local function onExit(ins, actor)
	local var = getActorVar(actor)
	if not var then return end
	if var.isexit then		
		return
	end
	var.isexit = true
	local now = System.getNowTime()
	var.cdTime = now + GuzhanchangConfig.cdTime	
	print("guzhanchang exit fuben", var.intime, var.entertime, now)
	var.intime = math.max(0, now - var.entertime) + var.intime
	checkRank(actor, var)
	s2cGuzhanchangInfo(actor)
	ins:giveFubenReward(actor)
end


local function onOffline(ins, actor)
	LActor.exitFuben(actor) --离线后，退出副本
end

--玩家死亡
local function onActorDie(ins, actor, killHdl)
	local et = LActor.getEntity(killHdl)
	local killer_actor = LActor.getActor(et)
	--杀人者处理
	local var = getActorVar(killer_actor)
	if not var then return end

	local rewards = drop.dropGroup(GuzhanchangConfig.pkDrop)
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
	local var = getActorVar(actor)
	local ishave = false
	for i=1, var.rewardscount do
		if var.rewards[i].id == id then			
			var.rewards[i].count = var.rewards[i].count + count
			ishave = true
			break
		end
	end
	if not ishave then
		var.rewardscount = var.rewardscount  + 1
		var.rewards[var.rewardscount] = {}
		var.rewards[var.rewardscount].count = count
		var.rewards[var.rewardscount].id = id
		var.rewards[var.rewardscount].type = tp
	end
end

--双倍掉落开启
function GuzhanchangStart()
	guzhanchang_isopen = 1
	if System.isBattleSrv() then
		GUZHANCHANG_HANDLE = getGuzhanchanFuben()
		sendFubenHandle()
		local data = getGlobalData()
		data.rank = {}
	else		
		local actors = System.getOnlineActorList()
		if actors ~= nil then
			for i =1,#actors do
				s2cGuzhanchangInfo(actors[i])
			end
		end
	end
end

function onConnected(sId, sType)
	if System.isBattleSrv() then
		sendFubenHandle(sId)
	end
end

local function settleRank()		
	local data = getGlobalData()
	if not data.rank or not data.rank[1] then return end
	noticesystem.broadAllServerContent(1, string.format(NoticeConfig[noticesystem.NTP.gzcfirst1].content, data.rank[1].name or ""))
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, CrossSrvCmd.SCGuzhan)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCGuzhan_SettleRank)
	LDataPack.writeInt(pack, data.rank[1].actorid or 0)
	System.sendPacketToAllGameClient(pack, data.rank[1].serverid)
end

local function onSettleRank(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorid)
	if actor then
		local var = getActorVar(actor)
		var.firstcount = var.firstcount + 1
		sendRewardInfo(actor)
	else
		local npack = LDataPack.allocPacket()
        System.sendOffMsg(actorid, 0, OffMsgType_Guzhanchang, npack)
	end
end

local function onOffMsgGuzhanchang(actor, pack)
	local var = getActorVar(actor)
	var.firstcount = var.firstcount + 1
	sendRewardInfo(actor)
end

function sendRewardInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_GuzhanchangRewardStatus)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.firstcount)
	LDataPack.writeInt(pack, var.joincount)
	LDataPack.writeChar(pack, var.firststatus)
	LDataPack.writeChar(pack, var.joinstatus)
	LDataPack.flush(pack)
end

--
function GuzhanchangStop()
	GUZHANCHANG_HANDLE = 0
	guzhanchang_isopen = 0
	if System.isBattleSrv() then 
		settleRank()

		local var = System.getDyanmicVar()
		if not var.g_guzhanchangData then 
			var.g_guzhanchangData = {} --古战场的所有副本handle
		end	
		--副本少于5人就直接进入
		for k, hf in pairs(var.g_guzhanchangData) do
			if Fuben.getFubenPtr(hf) then
				Fuben.closeFuben(hf)
			end
		end
	else
		local actors = System.getOnlineActorList()
		if actors ~= nil then
			for i=1,#actors do
				s2cGuzhanchangInfo(actors[i])
			end
		end
	end	
end

function onGuzhanGM(sId, sType, cpack)
	local type = LDataPack.readChar(cpack)
	if type == 0 then
		guzhanchang_endtime = System.getNowTime() + 20 * 60
		GuzhanchangStart()		
	else
		GuzhanchangStop()
	end
end

function calcEndTime()
	local Y,M,d = System.getDate()
	guzhanchang_endtime = System.timeEncode(Y, M, d, GuzhanchangConfig.starTime[2][1], GuzhanchangConfig.starTime[2][2], 0)	
	if not System.isBattleSrv() then return end
	local t = os.time()
	local hour = utils.getHours(t)
	local minute = utils.getMin(t)
	if GuzhanchangConfig.starTime[1][1] == hour and minute >= GuzhanchangConfig.starTime[1][2] then
		GuzhanchangStart()
	end
end


_G.startGuzhanchang = GuzhanchangStart
_G.stopGuzhanchang = GuzhanchangStop

--避免双倍经验时间里重启服务器不会开启双倍经验
local function initGlobalData()
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeUserLogin, onLogin)

	if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_GuzhanchangRecord, c2sGuzhanchangRecord)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_GuzhanchangBuy, c2sGuzhanchangBuy)
	if System.isBattleSrv() then 
		--注册相关回调
		local conf = GuzhanchangConfig
		insevent.registerInstanceEnter(conf.fbId, onEnter)
		insevent.registerInstanceEnterBefore(conf.fbId, onEnterBefore)
		insevent.registerInstanceExit(conf.fbId, onExit)	
		insevent.registerInstanceOffline(conf.fbId, onOffline)
		insevent.registerInstanceActorDie(conf.fbId, onActorDie)
		insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
		insevent.registerInstancePickItem(conf.fbId, onPickItem)		
	else
		netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_GuzhanchangFight, c2sGuzhanchangFight)
		netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_GuzhanchangGetRank, c2sGetRank)
		netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_GuzhanchangGetReward, c2sGetReward)
	end
	calcEndTime()
end
table.insert(InitFnTable, initGlobalData)


msgsystem.regHandle(OffMsgType_Guzhanchang, onOffMsgGuzhanchang)

--engineevent.regGameStartEvent(OnGameStart)
csbase.RegConnected(onConnected)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuzhan, CrossSrvSubCmd.SCGuzhan_SyncUpdateFbInfo, onGuzhanFbInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuzhan, CrossSrvSubCmd.SCGuzhan_GMStart, onGuzhanGM)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuzhan, CrossSrvSubCmd.SCGuzhan_GetRank, onGetRank)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuzhan, CrossSrvSubCmd.SCGuzhan_SendRank, onSendRank)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuzhan, CrossSrvSubCmd.SCGuzhan_SettleRank, onSettleRank)

--local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

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

gmCmdHandlers.gzcstart = function (actor, args)
	guzhanchang_endtime = System.getNowTime() + 20 * 60
	GuzhanchangStart()
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, CrossSrvCmd.SCGuzhan)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCGuzhan_GMStart)
	LDataPack.writeByte(pack, 0)
	System.sendPacketToAllGameClient(pack, 0)	
	return true
end

gmCmdHandlers.gzcstop = function (actor, args)
	GuzhanchangStop()
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, CrossSrvCmd.SCGuzhan)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCGuzhan_GMStart)
	LDataPack.writeByte(pack, 1)
	System.sendPacketToAllGameClient(pack, 0)	
	return true
end

gmCmdHandlers.gzcrankset = function (actor, args)
	local var = getActorVar(actor)
	var.joincount = tonumber(args[1])
	var.firstcount = tonumber(args[1])
	var.joinstatus = 0
	var.firststatus = 0
	sendRewardInfo(actor)
	return true	
end

gmCmdHandlers.gzcfragset = function (actor, args)
	local var = getActorVar(actor)
	var.frag = tonumber(args[1])
	if var.frag >= GuzhanchangConfig.maxKill then
		var.frag = GuzhanchangConfig.maxKill
	end
	s2cGuzhanchangFrag(actor)
end
