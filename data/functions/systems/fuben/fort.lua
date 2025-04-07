-- @version	1.0
-- @author	qianmeng
-- @date	2017-10-13 17:42:19.
-- @system	赤色要塞

module("fort", package.seeall)
require("scene.fortcommon")
require("scene.fortfuben")
require("scene.fortdie")
require("scene.fortkill")
require("scene.fortrank")

local version = 1
local FORT_GROUP = 10020


g_fort_ready = g_fort_ready or false
g_fort_open = g_fort_open or false
g_begin_time = g_begin_time or 0
g_end_time = g_end_time or 0
g_firstEnter = g_firstEnter or {} -- 是否第一个进入下一层
local enterTipsInterval = enterTipsInterval or 0
local exitTipsInterval = exitTipsInterval or 0
local rankRewards = {} --积分排行奖励
local rankTopFewList = {} --积分排行前几名

ScoreUpdateType = 
{
	default = 0,
	killRole = 1,
	roleDie = 2,
	area = 3,
	killMon = 4,
}

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.fortfuben or var.fortfuben.version ~= version then
		var.fortfuben = {
			version = version,
			isIn = 0,
			floor = 1,
			score = 0,
			serialKill = 0, --连杀人数
			serialDie = 0,	--连死次数
			cdTime = 0, --下一次进入的CD时间
			isreward = 0, --要发奖励
			scoreAdd = 0, --积分加成
			scoreEventId = 0, --积分事件
			getFloorReward = 0, --领取副本层数奖励
			enterTime = 0,
			isnextfloor = 0, --是否是进入下一层（判断是否是爬层还是退出副本）
		}
	end
	if not var.fortfuben.beenIn then var.fortfuben.beenIn = 0 end --活动开始后是否已经进入过
	return var.fortfuben	
end

local function getSystemVar()
	local var = System.getStaticVar()
	if not var.beforerank then 
		var.beforerank = {} 
		var.beforerank.count = 0
	end
	return var.beforerank
end

--返回一个要塞副本

local function getSystemDynamicVar()
	local dvar = System.getDyanmicVar()
	if not dvar.g_fortData then 
		dvar.g_fortData = {} 
	end
	return dvar.g_fortData
end

local function getFortFuben(floor)
	local fortInfo = getSystemDynamicVar()
	local floorInfo = fortInfo[floor]
	if not floorInfo then return end
	for k, fuben in ipairs(floorInfo) do
		local hfuben = fuben.hfuben
		if fuben.count < FortCommonConfig.people then
			return hfuben
		end
	end
end

local function checkFubenActorCount(ins)
	local fortInfo = getSystemDynamicVar()
	local floor = ins.data.floor
	if ins.actor_list_count >= FortCommonConfig.people then
		local hfuben = instancesystem.createFuBen(FortConfig[floor].fbId)
		if hfuben ~= 0 then 
			local ins = instancesystem.getInsByHdl(hfuben)
			ins.data.floor = floor
			table.insert(fortInfo[floor],{hfuben = hfuben, count = ins.actor_list_count})
		end
	end
	
	if not fortInfo[floor] then return end
	for _, fuben in ipairs(fortInfo[floor]) do
		local hfuben = fuben.hfuben
		local ins = instancesystem.getInsByHdl(hfuben)
		if ins then
			fuben.count = ins.actor_list_count
		end
	end
	updateFortFloorInfo(floor)
end

local function initGlobalData()
	local dvar = getSystemDynamicVar()
	for floor, conf in ipairs(FortConfig) do
		if not dvar[floor] then 
			dvar[floor] = {}
			local hfuben = instancesystem.createFuBen(conf.fbId)
			if hfuben ~= 0 then 
				local ins = instancesystem.getInsByHdl(hfuben)
				ins.data.floor = floor
				table.insert(dvar[floor],{hfuben = hfuben, count = ins.actor_list_count})
			end
		end
	end
end

--清除副本
function clearFortFuben()
	local dvar = System.getDyanmicVar()
	if not dvar.g_fortData then return end --一个副本都没创建
	local fortInfo = dvar.g_fortData
	for floor in pairs(fortInfo) do
		local floorInfo = fortInfo[floor]
		for _, fuben in ipairs(floorInfo) do
			local hfuben = fuben.hfuben
			if Fuben.getFubenPtr(hfuben) then
				local ins = instancesystem.getInsByHdl(hfuben)
				ins:release() --结束副本
			end
		end
	end
	dvar.g_fortData = {}
	g_firstEnter = {}
end

function updateFortFloorInfo(floor)
	if not System.isBattleSrv() then return end
	local fortInfo = getSystemDynamicVar()
	local floorInfo = fortInfo[floor]

	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCFortCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCFortCmd_SyncFloorFbInfo)

	LDataPack.writeByte(pack, floor)
	local count = 0
	local pos = LDataPack.getPosition(pack)	
	LDataPack.writeByte(pack, count)
	for _, fuben in ipairs(floorInfo) do
		LDataPack.writeInt64(pack, fuben.hfuben)
		LDataPack.writeByte(pack, fuben.count)
		count = count + 1
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeByte(pack, count)
	LDataPack.setPosition(pack, npos)
	System.sendPacketToAllGameClient(pack, 0)
end

function onUpdateFortFloorInfo(sId, sType, dp)
	if System.isCrossWarSrv() then return end
	local fortInfo = getSystemDynamicVar()
	local floor = LDataPack.readByte(dp)
	fortInfo[floor] = {}
	local num = LDataPack.readByte(dp)
	for i=1, num do
		local hfuben = LDataPack.readInt64(dp)
		local count = LDataPack.readByte(dp)
		table.insert(fortInfo[floor],{hfuben = hfuben, count = count})
	end
end

function sendAllFortInfo(serverId)
	if not System.isBattleSrv() then return end
	local fortInfo = getSystemDynamicVar()
	local pack = LDataPack.allocPacket()

	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCFortCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCFortCmd_SyncAllFbInfo)

	LDataPack.writeByte(pack, g_fort_open and 1 or 0)

	local count = 0
	local pos = LDataPack.getPosition(pack)	
	LDataPack.writeByte(pack, count)
	for floor in pairs(fortInfo) do
		LDataPack.writeByte(pack, floor)
		local num = 0
		local pos1 = LDataPack.getPosition(pack)
		LDataPack.writeByte(pack, num)
		for _,fuben in ipairs(fortInfo[floor]) do
			LDataPack.writeInt64(pack, fuben.hfuben)
			LDataPack.writeByte(pack, fuben.count)
			num = num + 1
		end
		local npos1 = LDataPack.getPosition(pack)
		LDataPack.setPosition(pack, pos1)
		LDataPack.writeByte(pack, num)
		LDataPack.setPosition(pack, npos1)
		count = count + 1
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeByte(pack, count)
	LDataPack.setPosition(pack, npos)

	System.sendPacketToAllGameClient(pack, serverId or 0)
end

function onSCAllFortInfo(sId, sType, dp)
	if System.isCrossWarSrv() then return end
	local fortInfo = getSystemDynamicVar()
	g_fort_open = LDataPack.readByte(dp) == 1

	local number = LDataPack.readByte(dp)
	for i=1, number do
		local floor = LDataPack.readByte(dp)
		fortInfo[floor] = {}
		local num = LDataPack.readByte(dp)
		for i=1, num do
			local hfuben = LDataPack.readInt64(dp)
			local count = LDataPack.readByte(dp)
			table.insert(fortInfo[floor],{hfuben = hfuben, count = count})
		end
	end
end

function sendBeforRank()
	if not System.isBattleSrv() then return end
	local var = getSystemVar()
	local pack = LDataPack.allocPacket()

	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCFortCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCFortCmd_SyncRankInfo)

	LDataPack.writeShort(pack, var.count)
	for i=1, var.count do
		LDataPack.writeInt(pack, var[i].actorid)
		LDataPack.writeShort(pack, var[i].rank)
		LDataPack.writeString(pack, var[i].name)
		LDataPack.writeInt(pack, var[i].value)
	end
	System.sendPacketToAllGameClient(pack, 0)
end

function OnReqBeforRank(sId, sType, dp)
	if System.isCrossWarSrv() then return end
	local var = System.getStaticVar()
	var.beforerank = {}
	local var = var.beforerank

	local count = LDataPack.readShort(dp)
	for i=1, count do
		local actorid = LDataPack.readInt(dp)
		local rank = LDataPack.readShort(dp)
		local name = LDataPack.readString(dp)
		local value = LDataPack.readInt(dp)
		var[i] = {actorid = actorid, rank = rank, name = name, value = value}
	end
	var.count = count
end

function sendRankRewards()
	if not System.isBattleSrv() then return end
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCFortCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCFortCmd_SyncRankRewards)
	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeShort(pack, count)
	for actorid,items in pairs(rankRewards) do
		LDataPack.writeInt(pack, actorid)
		LDataPack.writeShort(pack, #items)
		for k, v in ipairs(items) do
			LDataPack.writeInt(pack, v.type)
			LDataPack.writeInt(pack, v.id)
			LDataPack.writeDouble(pack, v.count)
		end
		count = count + 1
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeShort(pack, count)
	LDataPack.setPosition(pack, npos)
	System.sendPacketToAllGameClient(pack, 0)
end

function onRankRewards(sId, sType, dp)
	if System.isCrossWarSrv() then return end
	rankRewards = {}
	local count = LDataPack.readShort(dp)
	for i=1, count do
		local actorid = LDataPack.readInt(dp)
		rankRewards[actorid] = {}
		local num = LDataPack.readShort(dp)
		for i = 1, num do
			local type = LDataPack.readInt(dp)
			local id = LDataPack.readInt(dp)
			local count = LDataPack.readDouble(dp)
			table.insert(rankRewards[actorid], {type = type, id = id, count = count})
		end
	end
end

function sendRankTopFewList()
	if not System.isBattleSrv() then return end
	local pack = LDataPack.allocPacket()

	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCFortCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCFortCmd_SyncRankTopFewList)

	local count = #rankTopFewList
	LDataPack.writeShort(pack, #rankTopFewList)
	for i = 1, count do
		local oneTopFew = rankTopFewList[i]
		LDataPack.writeString(pack, oneTopFew.name)
		LDataPack.writeInt(pack, oneTopFew.score)
		LDataPack.writeChar(pack, oneTopFew.floor)
	end
	System.sendPacketToAllGameClient(pack, 0)
end

function onRankTopFewList(sId, sType, dp)
	if System.isCrossWarSrv() then return end
	rankTopFewList = {}
	local count = LDataPack.readShort(dp)
	for i = 1, count do
		local name = LDataPack.readString(dp)
		local score = LDataPack.readInt(dp)
		local floor = LDataPack.readChar(dp)
		rankTopFewList[i] = {name = name, score = score, floor = floor}
	end
end

-----------------------------------------排行榜-------------------------------------------
local rankingListName      = "fortrank"
local rankingListFile      = "fortrank.rank"
local rankingListMaxSize   = 3000
local rankingListBoardSize = 10
local rankingListColumns   = {"name", "floor", "score", "serverId"}

--第一次创建排行榜表
local function updateDynamicFirstCache(actor_id)
	local rank = Ranking.getRanking(rankingListName)
	local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then 
		rankTbl = {} 
	end
	if #rankTbl ~= 0 then 
		local prank = rankTbl[1]
		if actor_id == nil or actor_id == Ranking.getId(prank) then  
			worship.updateDynamicFirstCache(Ranking.getId(prank), RankingType_Fort)
		end
	end
end

--初始化排行榜
function initRankingList()
	local rank = utils.rankfunc.InitRank(rankingListName, rankingListFile, rankingListMaxSize, rankingListColumns, true)
	Ranking.addRef(rank)
	updateDynamicFirstCache()
end

--更新排行榜比分数值
function updateRankingList(actor, score, floor)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local actorId = LActor.getActorId(actor)
	local item = Ranking.getItemPtrFromId(rank, actorId)
	if item ~= nil then
		local p = Ranking.getPoint(item)
		if p < score then
			Ranking.setItem(rank, actorId, score)
		end
	else
		--只增不降的用tryAddItem
		--会降的用addItem
		item = Ranking.tryAddItem(rank, actorId, score)
		if item == nil then return end
	end
	--创建榜单
	local serverId = LActor.getServerId(actor)
	Ranking.setSub(item, 0, LActor.getName(actor))
	Ranking.setSubInt(item, 1, floor)
	Ranking.setSubInt(item, 2, serverId)
	updateDynamicFirstCache(LActor.getActorId(actor))
end

function getrank(actor)
	local var = getSystemVar()
	local actorid = LActor.getActorId(actor)
	for i=1, var.count do
		if var[i].actorid == actorid then
			return var[i].rank
		end
	end
end

function releaseRankingList()
	utils.rankfunc.releaseRank(rankingListName, rankingListFile)
end

--需要改
function resetRankingList()
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	saveRankList()
	Ranking.clearRanking(rank)
end

function saveRankList()
	local rank = Ranking.getRanking(rankingListName)
	if not rank then return end
	local rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	local count = 0
	if rankTbl then count = #rankTbl end
	local var = getSystemVar()
	var.count = count
	for i=1, count do
		var[i] = {}
		var[i].rank = i
		local prank = rankTbl[i]
		var[i].actorid = Ranking.getId(prank)
		var[i].name = Ranking.getSub(prank, 0)
		local value = Ranking.getPoint(prank)
		var[i].value = value
	end
end

function c2sGetBeforRank(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_FortBeforRank)
	local var = getSystemVar()
	local count = var.count > 100 and 100 or var.count
	local myrank = 0
	LDataPack.writeShort(pack, count)
	for i=1, var.count do
		if var[i].name == LActor.getName(actor) and myrank == 0 then
			myrank = i
		end
		if i > count then break end
		LDataPack.writeShort(pack, i)
		LDataPack.writeString(pack, var[i].name)
		LDataPack.writeInt(pack, var[i].value)
	end
	LDataPack.writeShort(pack, myrank)
	LDataPack.flush(pack)
end

engineevent.regGameStartEvent(initRankingList)
engineevent.regGameStopEvent(releaseRankingList)

--发送排行榜
function onReqRanking(actor)
	local rank = Ranking.getRanking(rankingListName)
	if not rank then return end
	local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_ResRankingData)
	if not npack then return end

	if rankTbl == nil then rankTbl = {} end
	LDataPack.writeShort(npack, RankingType_Fort)
	LDataPack.writeShort(npack, #rankTbl)

	if rankTbl and #rankTbl > 0 then
		for i = 1, #rankTbl do
			local prank = rankTbl[i]
			local value = Ranking.getPoint(prank)
			LDataPack.writeShort(npack, i)
			LDataPack.writeInt(npack, Ranking.getId(prank))
			LDataPack.writeString(npack, Ranking.getSub(prank, 0))
			LDataPack.writeShort(npack, Ranking.getSub(prank,1))
			LDataPack.writeInt(npack, value)
		end
	end
	LDataPack.writeShort(npack, Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1)
	LDataPack.flush(npack)
end
------------------------------------------------------------------------------------------------
function checkFortLimitDay()
	return System.getOpenServerDay() >= LimitConfig[actorexp.LimitTp.fort].day
end

--返回：倒计时，倒计时类型
function getTime(var)
	local now = System.getNowTime()
	if g_fort_open then --结束倒计时
		return g_end_time - now, 2
	else --普通模式倒计时
		return FortCommonConfig.fightTime - (now - var.enterTime), 2
	end
end

--返回副本id
local function getFubenId(floor)
	if FortConfig[floor] then
		return FortConfig[floor].fbId
	end
	return 0
end

function resetFortData(actor)
	local var = getActorVar(actor)
	if not g_fort_open or (System.getNowTime() - var.entertime) > FortCommonConfig.fightTime then
		var.floor = 1
		var.score = 0
	end	
	var.serialKill = 0
	var.serialDie = 0
end

--更新属性
function updateAttr(actor)
	local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Fuben)
	local var = getActorVar(actor)
	if var.isIn == 1 then
		local serialDie = var.serialDie
		local attrsConf = FortDieConfig[serialDie]
		if not attrsConf then return end

		attrs:Reset()
		for i = 1, #attrsConf do
			local attr = attrsConf[i]
			attrs:Set(attr.type, attr.value)
		end
	else
		attrs:Reset()
	end

	LActor.reCalcAttr(actor)
end

function s2cFortScore(actor, updateType)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_FortUpdateScore)
	if pack == nil then return end
	LDataPack.writeByte(pack, updateType)
	LDataPack.writeInt(pack, var.score)
	LDataPack.flush(pack)
end

function addScore(actor, score, updateType)
	--if not g_fort_open then return end
	local var = getActorVar(actor)
	local conf = FortConfig[var.floor]
	if not conf then return end
	local old = var.score
	var.score = var.score + score
	if conf.maxscore > 0 and var.score > conf.maxscore then
		var.score = conf.maxscore
	end
	if var.score > old then
		if g_fort_open then
			updateRankingList(actor, var.score, var.floor)
		end
		s2cFortScore(actor, updateType)
	end
end

function addScoreFluse(actor)
	if not g_fort_open then return end --普通模式不加泡澡积分
	if not LActor.isDeath(actor) then
		local var = getActorVar(actor)
		if not var then return end
		local conf = FortConfig[var.floor]
		if not conf then return end
		addScore(actor, conf.aisle + var.scoreAdd, ScoreUpdateType.area)
	end
end
-----------------------------------------------------------------------------------------------------------------
function s2cFortInfo(actor)
	local var = getActorVar(actor)
	if not var then return end
	local cdTime = math.max(var.cdTime - System.getNowTime(), 0)

	local time, tp = getTime(var)
	time = math.max(time, 0)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_FortInfo)
	if pack == nil then return end
	LDataPack.writeChar(pack, g_fort_open and 1 or 0) --副本模式，0普通，1竞技
	LDataPack.writeChar(pack, tp) --倒计时类型
	LDataPack.writeInt(pack, time)
	LDataPack.writeInt(pack, cdTime) --重进cd时间
	LDataPack.flush(pack)
end
function sendCanEnter(actor, result)	
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_FortFight)
	LDataPack.writeChar(pack, result)
	LDataPack.flush(pack)
end
--检查是否可进入赤色要塞
local function checkCanEnter(actor)
	local year, month, day, hour, minute, _ = System.timeDecode(System.getNowTime())
	local canEnterTime1 = System.timeEncode(year, month, day, FortCommonConfig.starTime1[1], FortCommonConfig.starTime1[2], FortCommonConfig.starTime1[3])
	if System.getNowTime() >= canEnterTime1 - FortCommonConfig.beforeTime and System.getNowTime() < canEnterTime1 then --竞技模式开启前多少时间不可以进入
		sendCanEnter(actor, 0)	
		return false
	end
	local canEnterTime2 = System.timeEncode(year, month, day, FortCommonConfig.starTime2[1], FortCommonConfig.starTime2[2], FortCommonConfig.starTime2[3])
	if System.getNowTime() >= canEnterTime2 - FortCommonConfig.beforeTime and System.getNowTime() < canEnterTime2 then --竞技模式开启前多少时间不可以进入
		sendCanEnter(actor, 0)	
		return false
	end
	return true
end

--进入要塞
function c2sFortFight(actor, packet)
	if not actorlogin.checkCanEnterCross(actor) then return end
	--if not g_fort_open then return end
	local var = getActorVar(actor)
	if not var then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.fort) then return end
	if System.getNowTime() < var.cdTime then
		return
	end
	
	if not checkCanEnter(actor) then return end

	resetFortData(actor, true)

	local floor = var.floor
	local fbId = getFubenId(floor)
	if fbId == 0 then return end
	if not utils.checkFuben(actor, fbId) then return end
	local hfuben = getFortFuben(floor)
	if not hfuben then return end

	if g_fort_open then
		if var.isreward ~= 1 then
			actorevent.onEvent(actor, aeActiveFuben, fbId, true)
		end
		var.isreward = 1
	else
		actorevent.onEvent(actor, aeActiveFuben, fbId)
	end
	var.enterTime = System.getNowTime()
	s2cFortInfo(actor)

	local x, y = utils.getSceneEnterCoor(fbId)
	if System.isCommSrv() then
		local crossId = csbase.getCrossServerId()
		LActor.loginOtherServer(actor, crossId, hfuben, 0, x, y, "cross")
	elseif System.isCrossWarSrv() then
		LActor.enterFuBen(actor, hfuben, 0, x, y)		
		
	end

	sendCanEnter(actor, 1)
	if var.beenIn == 0 then
		var.beenIn = 1		
	end
	noticesystem.broadCastNotice(noticesystem.NTP.fort, actorcommon.getVipShow(actor), LActor.getName(actor))
	--sendCsFortNotice(0, LActor.getName(actor), 0, 0 , "")
end

--爬上一层
function c2sFortUpper(actor, packet)
	if not System.isBattleSrv() then return end
	local var = getActorVar(actor)
	if var.floor < 1 then return end
	local floor = var.floor + 1
	if not FortConfig[floor] then return end
	if var.score < FortConfig[var.floor].maxscore then --积分不足
		return
	end
	if var.getFloorReward < var.floor - 1 then --不领取当前层数奖励不能进入下一层
		return
	end
	local fbId = getFubenId(floor)
	if fbId == 0 then return end
	if not utils.checkFuben(actor, fbId) then return end
	local hfuben = getFortFuben(floor)
	if not hfuben then return end
	local x, y = utils.getSceneEnterCoor(fbId)
	var.isnextfloor = 1
	var.floor = floor
	LActor.enterFuBen(actor, hfuben, 0, x, y)

	if g_fort_open and g_firstEnter[floor] == nil then --只有竞技模式下第一个进入
		noticesystem.broadCastCrossNotice(noticesystem.NTP.fort3, actorcommon.getVipShow(actor), LActor.getName(actor), floor) --第一个进入该层公告
		sendCsFortNotice(3, actor, 0, floor , "")--跨服公告
		g_firstEnter[floor] = 1
	end
end

--领取层数奖励
function c2sFortGetReward(actor, pack)	
	local var = getActorVar(actor)
	if var.score < FortConfig[var.floor].dabiaoscore then --积分不足
		return
	end
	if var.floor ~= var.getFloorReward + 1 then
		return
	end
	var.getFloorReward = var.getFloorReward + 1
	
	actoritem.addItems(actor, FortConfig[var.floor].rewards, "beta level rewards")
	fortRewardInfo(actor)
end

--领取层数奖励返回
function fortRewardInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_FortGetReward)
	LDataPack.writeByte(pack, var.getFloorReward)
	LDataPack.flush(pack)
end

--请求钻石复活
function c2sFortRevive(actor, packet)
	--if not g_fort_open then return end
end

--层信息
function s2cFortLevel(actor)
	local var = getActorVar(actor)
	if not var then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_FortScore)
	if pack == nil then return end
	LDataPack.writeByte(pack, var.floor)
	LDataPack.writeInt(pack, var.serialKill)
	LDataPack.writeInt(pack, var.serialDie)
	LDataPack.flush(pack)
end

--副本结算
function s2cFortReward(actor)
	local var = getActorVar(actor)
	if not var then return end
	local conf = FortConfig[var.floor]
	if not conf then return end
	if var.isreward == 0 then return end
	var.isreward = 0
	
	local myrank = getrank(actor)
	if not myrank then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_FortRewards)
	if pack == nil then return end
	local items = rankRewards[LActor.getActorId(actor)] or {}
	LDataPack.writeInt(pack, myrank)
	LDataPack.writeInt(pack, var.score)
	LDataPack.writeChar(pack, var.floor)
	LDataPack.writeShort(pack, #items)
	for k, v in ipairs(items) do
		LDataPack.writeInt(pack, v.type)
		LDataPack.writeInt(pack, v.id)
		LDataPack.writeDouble(pack, v.count)
	end
	--发送排名信息
	local count = #rankTopFewList
	LDataPack.writeShort(pack, #rankTopFewList)
	for i = 1, count do
		local oneTopFew = rankTopFewList[i]
		LDataPack.writeInt(pack, i)
		LDataPack.writeString(pack, oneTopFew.name)
		LDataPack.writeInt(pack, oneTopFew.score) --积分
		LDataPack.writeChar(pack, oneTopFew.floor) --层数
	end

	LDataPack.flush(pack)
end
-----------------------------------------------------------------------------------------------------------------
--在线玩家开始
local function onFortStart(actor)
	s2cFortInfo(actor)
	local var = getActorVar(actor)
	if not var then return end
	var.beenIn = 0
	resetFortData(actor)
end

--在线玩家结束
local function onFortStop(actor)
	local var = getActorVar(actor)
	if not var then return end
	var.isclear = 1
	s2cFortReward(actor)
	s2cFortInfo(actor)
end

--在线玩家准备
local function onFortReady(actor)
	s2cFortInfo(actor)
end

--进入要塞副本
local function onEnterFb(ins, actor)
	local var = getActorVar(actor)
	var.isIn = 1
	s2cFortLevel(actor)
	s2cFortScore(actor, ScoreUpdateType.default)
	local scoreEventId = LActor.postScriptEventEx(actor, FortCommonConfig.scoreInternal, 
							function(...) addScoreFluse(actor) end , FortCommonConfig.scoreInternal, -1) --每3秒计算一次积分
	var.scoreEventId = scoreEventId
	local delay = g_end_time - System.getNowTime()
	insdisplay.fubenDaotime(actor, ins.id, delay) --发送倒计时
	LActor.addSkillEffect(actor, FortCommonConfig.extraEffectId)
	fortRewardInfo(actor)
	actorevent.onEvent(actor, aeFortFloor, var.floor)
	checkFubenActorCount(ins)
end
--退出副本
local function onExitFb(ins, actor)
	local var = getActorVar(actor)
	if not var then return end
	var.cdTime = System.getNowTime() + FortCommonConfig.enterCd
	var.isIn = 0
	var.serialKill = 0
	var.serialDie = 0
	var.scoreAdd = 0
	var.isnextfloor = 0
	updateAttr(actor)
	if var.scoreEventId > 0 then
		LActor.cancelScriptEvent(actor, var.scoreEventId)
		var.scoreEventId = 0
	end
	s2cFortInfo(actor)
	LActor.delSkillEffect(actor, FortCommonConfig.extraEffectId)
	checkFubenActorCount(ins)
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
	--onExitFb(ins, actor)
end


local function checkNotice(serialKill)
	local killNotice = FortCommonConfig.killNotice
	for i = 1, #killNotice do
		if serialKill == killNotice[i] then
			return true
		end
	end
	return false
end

--角色死亡
local function onRoleDie(ins, role, killHdl )
	local et = LActor.getEntity(killHdl)
	local killer_actor = LActor.getActor(et)
	local killerName = ""
	--杀人者处理
	if killer_actor then 
		local kvar = getActorVar(killer_actor)
		kvar.serialKill = kvar.serialKill + 1
		kvar.serialDie = 0
		s2cFortLevel(killer_actor)
		updateAttr(killer_actor)
		local score = FortKillConfig[kvar.serialKill] and FortKillConfig[kvar.serialKill].score or FortKillConfig[#FortKillConfig].score
		addScore(killer_actor, score, ScoreUpdateType.killRole)
		if checkNotice(kvar.serialKill) then
			noticesystem.broadCastCrossNotice(noticesystem.NTP.fort2, actorcommon.getVipShow(killer_actor), LActor.getName(killer_actor), kvar.serialKill) --连杀公告 
			sendCsFortNotice(2, killer_actor, kvar.serialKill, 0, "")
		end
	end
	--被杀者处理
	local actor = LActor.getActor(role)
	local var = getActorVar(actor)
	addScore(actor, FortConfig[var.floor].die, ScoreUpdateType.roleDie)
end

--玩家死亡
local function onActorDie(ins, actor, killHdl)
	local et = LActor.getEntity(killHdl)
	local killer_actor = LActor.getActor(et)
	local killerName = ""
	--杀人者处理
	if killer_actor then 
		killerName = LActor.getName(killer_actor)
	end
	--被杀者处理
	local var = getActorVar(actor)
	var.serialDie = var.serialDie + 1
	updateAttr(actor)
	local serialKill = var.serialKill
	var.serialKill = 0
	s2cFortLevel(actor)
	if serialKill > FortCommonConfig.endKillNotice and killer_actor then
		noticesystem.broadCastCrossNotice(noticesystem.NTP.fort4, LActor.getName(actor), serialKill, killerName) --连杀终结公告 
		sendCsFortNotice(4, actor, serialKill, 0, killerName)
	end
end

--副本内杀怪
local function onMonsterDie(ins, mon, killer_hdl)
	local et = LActor.getEntity(killer_hdl)
	local killer_actor = LActor.getActor(et)
	local kvar = getActorVar(killer_actor)
	if kvar then
		local conf = FortConfig[kvar.floor]
		if conf then
			if g_fort_open then
				addScore(killer_actor, conf.mons, ScoreUpdateType.killMon)
			else
				addScore(killer_actor, conf.monss, ScoreUpdateType.killMon)
			end
		end
	end
end

local function onLogin(actor)
	--if System.isBattleSrv() then return end
	--if not g_fort_open then --要塞非开启的状态，设置数据可清空
	local var = getActorVar(actor)
	var.beenIn = 0
	fortRewardInfo(actor)
	s2cFortInfo(actor)
	if not g_fort_open then
		s2cFortReward(actor)
	end
	--end	
end

function sendSyncInfo(ntype)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCFortCmd)
	if ntype == 1 then
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCFortCmd_FortReady)
	elseif ntype == 2 then
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCFortCmd_FortStart)
	elseif ntype == 3 then	
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCFortCmd_FortStop)
	end
	System.sendPacketToAllGameClient(pack, 0)
end

--赤色要塞开始
function FortStart()
	if not System.isBattleSrv() then return end
	if not checkFortLimitDay() then return end	
	g_fort_open = true
	g_end_time = System.getNowTime() + FortCommonConfig.fightTime
	--noticesystem.broadCastNotice(noticesystem.NTP.fort5) 
	clearFortFuben()
	initGlobalData()
	sendAllFortInfo()
	sendSyncInfo(2)
	sendCsFortNotice(5, nil, 0, 0 , "")
end

function onSCFortStart(sId, sType, dp)
	local actors = System.getOnlineActorList() or {}
	for i =1, #actors do
		onFortStart(actors[i])
	end
end

--赤色要塞结束
function FortStop()
	if not System.isBattleSrv() then return end
	if not checkFortLimitDay() then return end
	g_fort_open = false
	g_fort_ready = false
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then rankTbl = {}  end

	local count = #FortRankConfig
	for i = 1, #rankTbl do
		local pRank = rankTbl[i]
		local actorId = Ranking.getId(pRank)
		local name = Ranking.getSub(pRank, 0)
		local floor = Ranking.getSubInt(pRank, 1)
		local serverId = Ranking.getSubInt(pRank, 2)
		local score = Ranking.getPoint(pRank)
		--前几名
		if i <= FortCommonConfig.topFewCount then
			local oneTopFew = {}
			rankTopFewList[#rankTopFewList + 1] = oneTopFew
			oneTopFew.name = name
			oneTopFew.floor = floor
			oneTopFew.score = score
		end
		local index = getRankIndex(i)
		rankRewards[actorId] = FortRankConfig[index].rewards
		local actor = LActor.getActorById(actorId)
		if actor then
			actoritem.addItemsByMail(actor, FortRankConfig[index].rewards, "fort rank rewards", 0, "fortrank") --发积分排行奖励奖
		else
			--不在线玩家发邮件
			local content = string.format(FortCommonConfig.rankMailContent, i)
			local mailData = {head=FortCommonConfig.rankMailTitle, context=content, tAwardList=FortRankConfig[index].rewards}
			mailsystem.sendMailById(actorId, mailData, serverId)	
		end
	end
	
	resetRankingList() --清排行榜
	sendBeforRank()
	sendRankRewards()
	sendRankTopFewList()

	clearFortFuben()--清空副本
	initGlobalData()
	sendAllFortInfo()
	sendSyncInfo(3)
	rankRewards = {}
	rankTopFewList = {}
end

function onSCFortStop(sId, sType, dp)
	local actors = System.getOnlineActorList() or {}
	for i =1, #actors do
		onFortStop(actors[i])
	end
end

function getRankIndex(rank)
	for i=1, #FortRankConfig do
		if rank >= FortRankConfig[i].idx[1] and rank <= FortRankConfig[i].idx[2] then
			return i
		end
	end
	return #FortRankConfig
end

--赤色要塞准备
function FortReady()
	if not System.isBattleSrv() then return end
	if not checkFortLimitDay() then return end
	g_fort_ready = true
	g_begin_time = System.getNowTime() + FortCommonConfig.readyTime
	--noticesystem.broadCastNotice(noticesystem.NTP.fort1) 
	sendAllFortInfo()
	sendSyncInfo(1)
	sendCsFortNotice(1, nil, 0, 0, "") 
end

function onSCFortReady(sId, sType, dp)
	local actors = System.getOnlineActorList() or {}
	for i =1, #actors do
		onFortReady(actors[i])
	end
end

function ExitFortScoreArea(scene, actor, exitType)
	if not g_fort_open then return end
	local var = getActorVar(actor)
	var.scoreAdd = 0
	local nowTime = System.getNowTime()
	if exitTipsInterval <= nowTime then
		exitTipsInterval = nowTime + FortCommonConfig.areaTipsInterval
		if exitType == 0 then
			LActor.sendTipmsg(actor, FortCommonConfig.exitAreaTips)
		end
	end
end
_G.ExitFortScoreArea = ExitFortScoreArea

function EnterFortScoreArea(scene, actor, scoreAdd)
	if not g_fort_open then return end
	local var = getActorVar(actor)
	var.scoreAdd = scoreAdd
	local nowTime = System.getNowTime()
	if enterTipsInterval <= nowTime then
		enterTipsInterval = nowTime + FortCommonConfig.areaTipsInterval
		if g_fort_open then
			LActor.sendTipmsg(actor, FortCommonConfig.enterAreaTips)
		end
	end
end
_G.EnterFortScoreArea = EnterFortScoreArea

function flushStartFort1()
	--if System.isBattleSrv() then return end
	if not System.isBattleSrv() then return end
	FortStart()	
end
_G.flushStartFort1 = flushStartFort1

function flushStartFort2()
	--if System.isBattleSrv() then return end
	if not System.isBattleSrv() then return end
	FortStart()	
end
_G.flushStartFort2 = flushStartFort2

function flushStopFort1()
	--if System.isBattleSrv() then return end
	if not System.isBattleSrv() then return end
	FortStop()
end
_G.flushStopFort1 = flushStopFort1

function flushStopFort2()
	--if System.isBattleSrv() then return end
	if not System.isBattleSrv() then return end
	FortStop()
end
_G.flushStopFort2 = flushStopFort2

function flushReadyFort1()
	--if System.isBattleSrv() then return end
	if not System.isBattleSrv() then return end
	FortReady()
end
_G.flushReadyFort1 = flushReadyFort1

function flushReadyFort2()
	--if System.isBattleSrv() then return end
	if not System.isBattleSrv() then return end
	FortReady()
end
_G.flushReadyFort2 = flushReadyFort2


local function onNewDayArrive(actor, login)
	local var = getActorVar(actor)
	var.getFloorReward = 0
	--跨天时如果还在副本中则退出副本
	if not login and var.isIn == 1 then
		LActor.exitFuben(actor)
	end
end

function OnFortConnected(serverId, serverType)
	if not System.isBattleSrv() then return end
	sendAllFortInfo(serverId)
end

function sendCsFortNotice(ntype, actor, kill_count, floor, sName)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCFortCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCFortCmd_FortNotice)
	LDataPack.writeByte(pack, ntype)
	LDataPack.writeString(pack, LActor.getName(actor))
	LDataPack.writeShort(pack, kill_count)
	LDataPack.writeByte(pack, floor)
	LDataPack.writeString(pack, sName)
	LDataPack.writeByte(pack, LActor.getVipLevel(actor))
	LDataPack.writeByte(pack, LActor.getSVipLevel(actor))
	System.sendPacketToAllGameClient(pack, 0)
end

function onSCFortBroadcast(sId, sType, dp)
	local ntype = LDataPack.readByte(dp)
	local aName = LDataPack.readString(dp)
	local kill_count = LDataPack.readShort(dp)
	local floor = LDataPack.readByte(dp)
	local sName = LDataPack.readString(dp)
	local vip = LDataPack.readByte(dp)
	local svip = LDataPack.readByte(dp)
	if ntype == 0 then
		noticesystem.broadCastNotice(noticesystem.NTP.fort, actorcommon.getVipShow(nil, svip, vip), aName)
	elseif ntype == 1 then
		noticesystem.broadCastNotice(noticesystem.NTP.fort1)
	elseif ntype == 2 then
		noticesystem.broadCastNotice(noticesystem.NTP.fort2, actorcommon.getVipShow(nil, svip, vip), aName, kill_count) --连杀公告
	elseif ntype == 3 then
		noticesystem.broadCastNotice(noticesystem.NTP.fort3, actorcommon.getVipShow(nil, svip, vip), aName, floor) --第一个进入该层公告
	elseif ntype == 4 then
		noticesystem.broadCastNotice(noticesystem.NTP.fort4, aName, kill_count, sName) --连杀终结公告 
	elseif ntype == 5 then
		noticesystem.broadCastNotice(noticesystem.NTP.fort5)
	end
end

function init()
	if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_FortFight, c2sFortFight)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_FortGetBefore, c2sGetBeforRank)

	csbase.RegConnected(OnFortConnected)

	csmsgdispatcher.Reg(CrossSrvCmd.SCFortCmd, CrossSrvSubCmd.SCFortCmd_SyncAllFbInfo, onSCAllFortInfo)
	csmsgdispatcher.Reg(CrossSrvCmd.SCFortCmd, CrossSrvSubCmd.SCFortCmd_SyncFloorFbInfo, onUpdateFortFloorInfo)
	csmsgdispatcher.Reg(CrossSrvCmd.SCFortCmd, CrossSrvSubCmd.SCFortCmd_SyncRankInfo, OnReqBeforRank)
	csmsgdispatcher.Reg(CrossSrvCmd.SCFortCmd, CrossSrvSubCmd.SCFortCmd_SyncRankRewards, onRankRewards)
	csmsgdispatcher.Reg(CrossSrvCmd.SCFortCmd, CrossSrvSubCmd.SCFortCmd_SyncRankTopFewList, onRankTopFewList)
	csmsgdispatcher.Reg(CrossSrvCmd.SCFortCmd, CrossSrvSubCmd.SCFortCmd_FortNotice, onSCFortBroadcast)
	csmsgdispatcher.Reg(CrossSrvCmd.SCFortCmd, CrossSrvSubCmd.SCFortCmd_FortReady, onSCFortReady)
	csmsgdispatcher.Reg(CrossSrvCmd.SCFortCmd, CrossSrvSubCmd.SCFortCmd_FortStart, onSCFortStart)
	csmsgdispatcher.Reg(CrossSrvCmd.SCFortCmd, CrossSrvSubCmd.SCFortCmd_FortStop, onSCFortStop)

	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDayArrive)

	if not System.isBattleSrv() then return end
	initGlobalData()
	for _, conf in pairs(FortConfig) do
		insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceExit(conf.fbId, onExitFb)
		insevent.registerInstanceOffline(conf.fbId, onOffline)
		insevent.regRoleDie(conf.fbId, onRoleDie)
		insevent.registerInstanceActorDie(conf.fbId, onActorDie)
	end

	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_FortRevive, c2sFortRevive)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_FortUpper, c2sFortUpper)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_FortGetReward, c2sFortGetReward)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.fortfight = function (actor, args)
	c2sFortFight(actor)
	return true
end

gmCmdHandlers.fortupper = function (actor, args)
	c2sFortUpper(actor)
	return true
end

gmCmdHandlers.addfortscore = function (actor, args)
	addScore(actor, tonumber(args[1]))
	return true
end

gmCmdHandlers.fortstart = function (actor, args)
	if tonumber(args[1]) == 2 then
		flushStartFort2()
	else
		flushStartFort1()
	end
	return true
end

gmCmdHandlers.fortstop = function (actor, args)
	if tonumber(args[1]) == 2 then
		flushStopFort2()
	else
		flushStopFort1()
	end
	return true
end

gmCmdHandlers.fortready = function (actor, args)
	if tonumber(args[1]) == 2 then
		flushReadyFort2()
	else
		flushReadyFort1()
	end
	return true
end

gmCmdHandlers.fortNotice = function (actor, args)
	local ntype = tonumber(args[1]) or 0
	sendCsFortNotice(ntype, "aName", 0, 0, "sName")
end
