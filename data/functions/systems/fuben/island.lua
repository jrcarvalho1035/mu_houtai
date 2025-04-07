-- @version	1.0
-- @author	qianmeng
-- @date	2018-2-10 17:35:13
-- @system	恶魔岛

module("island", package.seeall)
require "scene.island"
require "scene.islandcommon"

g_islandOpen = false

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.islandData then var.islandData = {} end
	local var = var.islandData
	if not var.curId then var.curId = 0 end
	if not var.helpcount then var.helpcount = 0 end
	if not var.week then var.week = 0 end
	if not var.ishelp then var.ishelp = 0 end --0不是协助，1是协助
	if not var.isRewarded then var.isRewarded = 0 end --是否已领上周结算奖励
	return var
end
----------------------------------------------排行榜数据-------------------------------------------------------
local rankingListName      = "islandrank"
local rankingListFile      = "islandrank.rank"
local rankingListMaxSize   = 5
local rankingListBoardSize = 5
local rankingListColumns   = {"name"}

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
			worship.updateDynamicFirstCache(Ranking.getId(prank), RankingType_Island)
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
function updateRankingList(actor, value)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local actorId = LActor.getActorId(actor)

	local item = false
	local oldrank = Ranking.getItemIndexFromId(rank, actorId)
	if oldrank >= 0 then
		item = Ranking.setItem(rank, actorId, value)
	else
		item = Ranking.tryAddItem(rank, actorId, value)--只增不降的用tryAddItem，会降的用addItem
	end
	if not item then return false end

	--创建榜单
	Ranking.setSub(item, 0, LActor.getName(actor))
	updateDynamicFirstCache(LActor.getActorId(actor))
end

function getrank(actor)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return 0 end

	return Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
end

function releaseRankingList()
	utils.rankfunc.releaseRank(rankingListName, rankingListFile)
end

engineevent.regGameStartEvent(initRankingList)
engineevent.regGameStopEvent(releaseRankingList)


--发送排行榜
function s2cRankingList(actor)
	local rank = Ranking.getRanking(rankingListName)
	if not rank then return end
	local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_ResRankingData)
	if not npack then return end

	if rankTbl == nil then rankTbl = {} end
	LDataPack.writeShort(npack, RankingType_Island)
	LDataPack.writeShort(npack, #rankTbl)

	if rankTbl and #rankTbl > 0 then
		for i = 1, #rankTbl do
			local prank = rankTbl[i]
			local value = Ranking.getPoint(prank)
			LDataPack.writeShort(npack, i)
			LDataPack.writeInt(npack, Ranking.getId(prank))
			LDataPack.writeString(npack, Ranking.getSub(prank, 0))
			LDataPack.writeDouble(npack, value)
		end
	end
	LDataPack.writeShort(npack, Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1)
	LDataPack.flush(npack)
end

function onReqRanking(actor)
	s2cRankingList(actor)
end
_G.onReqIslandRanking = onReqRanking

-----------------------------------------------------------------------------------------------------------------------

local function isOpenTime()
	local t = os.time()
	local week = utils.getWeek(t)
	local after_sec = (t + System.getTimeZone()) % (24 * (60 * 60))
	if week == 7 and after_sec >= (22 * 60 * 60) then  --周日十点后系统不开启
		return false
	end
	return true
end

function getId(actorId)
	local actor = LActor.getActorById(actorId)
	if not actor then return 0 end
	local var = getActorVar(actor)
	return var.curId
end

local function fightIsland(actor, hfuben, teamId, x, y)
	actorcommon.setTeamId(actor, teamId)
	local ret = LActor.enterFuBen(actor, hfuben, 0, x, y)
	if not ret then
		utils.printInfo("fight island fail", ret, hfuben)
	end
end

function givePassReward(actor)
	local var = getActorVar(actor)
	var.isRewarded = 1
	if var.curId >= 10 then
		local items = IslandCommonConfig.reward10
		local context = string.format(IslandCommonConfig.context2, 10)
		local mailData = {head=IslandCommonConfig.head2, context=context, tAwardList=items}
		mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	elseif var.curId >= 5 then
		local items = IslandCommonConfig.reward5
		local context = string.format(IslandCommonConfig.context2, 5)
		local mailData = {head=IslandCommonConfig.head2, context=context, tAwardList=items}
		mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	end
end

--每周刷新
function refreshWeek(actor)
	local var = getActorVar(actor)
	local curWeek = utils.getWeeks(os.time())
	if var.week < curWeek then --新的一周
		if var.isRewarded == 0 then --奖励未领
			givePassReward(actor)
		end

		var.week = curWeek
		var.curId = 0
		var.helpcount = 0
		var.isRewarded = 0
	end
end
---------------------------------------------------------------------------------------------
function s2cIslandInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_IslandInfo)
	LDataPack.writeChar(pack, var.curId)
	LDataPack.writeChar(pack, var.helpcount)
	LDataPack.writeChar(pack, g_islandOpen and 1 or 0)
	LDataPack.flush(pack)
end

--挑战恶魔岛
function c2sIslandFight(actor, packet)
	if not g_islandOpen then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.island) then return end
	local var = getActorVar(actor)
	local idx = var.curId + 1
	local conf = IslandFubenConfig[idx]
	if not conf then return end
	if not utils.checkFuben(actor, conf.fbId) then return end
	local hfuben = instancesystem.createFuBen(conf.fbId)
	if not hfuben or hfuben == 0 then utils.showTip(actor, "hfuben") return end
	local ins = instancesystem.getInsByHdl(hfuben)
	ins.data.islandid = idx
	local x, y = utils.getSceneEnterCoor(conf.fbId)
	local actorId = LActor.getActorId(actor)
	if islandteam.isTeamMember(actorId) then --作为队员不能主动进副本
		return
	end
	for k, v in pairs(islandteam.getTeam(actorId)) do
		local tor = LActor.getActorById(v)
		if tor then
			fightIsland(tor, hfuben, actorId, x, y)
		end
	end
	local team = islandteam.getTeam(actorId)
	for k,v in ipairs(team) do
		local tor = LActor.getActorById(v)
		if v ~= actorId and tor then
			local data = getActorVar(tor)
			data.ishelp = 1
		end
	end
	islandteam.breakTeam(actorId) --进入副本后队伍解散
end


--恶魔岛进入挑战
function s2cIslandFight(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_IslandFight)
	if pack == nil then return end
	LDataPack.flush(pack)
end

----------------------------------------------------------------------------------------
--挑战通关
function onFbWin(ins)
	local idx = ins.data.islandid
	local conf = IslandFubenConfig[idx]
	if not conf then return end
	local actors = ins:getActorList()
	for k, tor in pairs(actors) do
		local var = getActorVar(tor)
		local actorId = LActor.getActorId(tor)
		if var.ishelp == 1 then --是助战
			var.helpcount = var.helpcount + 1
			if var.helpcount <= IslandCommonConfig.count then
				instancesystem.setInsRewards(ins, tor, conf.helpRewards)	
			end
			var.ishelp = 0	
		end
		if var.curId < idx then --第一次通关
			var.curId = idx
			instancesystem.setInsRewards(ins, tor, conf.passRewards)
			updateRankingList(tor, idx)			
		end
		s2cIslandInfo(tor)
	end
end

function onEnterFb(ins, actor, isLogin)
	s2cIslandFight(actor)
	if not isLogin then --登录重进副本不刷新
		ins:postponeStart()
	end
end

function onExitFb(ins, actor)
	actorcommon.setTeamId(actor, 0)
end

function onOffline(ins, actor)
	LActor.exitFuben(actor)
	onExitFb(ins, actor)
end

local function onLogin(actor)
	if System.isBattleSrv() then return end
	s2cIslandInfo(actor)
end

local function onNewDay(actor)
	if System.isBattleSrv() then return end
	refreshWeek(actor)
end


local function delayStartFight(_, ins)
	ins:postponeStart()
end

--延迟刷boss
function IslandDeferEarly(ins, actor)
	ins:postponeStop()
	ins:notifyBossWarn()
	LActor.postScriptEventLite(nil, 2*1000, delayStartFight, ins)
end

--恶魔岛开始
function flushStartIsland()
	if System.isBattleSrv() then return end
	if not actorexp.checkLevelCondition1(actorexp.LimitTp.island) then return end
	g_islandOpen = true
	local actors = System.getOnlineActorList()
	if actors then
		for i = 1, #actors do
			s2cIslandInfo(actors[i])
		end
	end
end
_G.flushStartIsland = flushStartIsland

--停止玩家进入
function flushStopIsland()
	if System.isBattleSrv() then return end
	if not actorexp.checkLevelCondition1(actorexp.LimitTp.island) then return end
	g_islandOpen = false
	local actors = System.getOnlineActorList()
	if actors then
		for i = 1, #actors do
			s2cIslandInfo(actors[i])
		end
	end
end
_G.flushStopIsland = flushStopIsland

--恶魔岛结算
-- function flushSettleIsland()
-- 	local rank = Ranking.getRanking(rankingListName)
-- 	if not rank then return end
-- 	local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)

-- 	if rankTbl == nil then return end
-- 	for i = 1, #rankTbl do
-- 		local prank = rankTbl[i]
-- 		local actorId = Ranking.getId(prank)

-- 		local conf = IslandRankConfig[i]
-- 		if conf then
-- 			local context = string.format(IslandCommonConfig.context1, i)
-- 			local mailData = {head=IslandCommonConfig.head1, context=context, tAwardList=conf.rewards}
-- 			mailsystem.sendMailById(actorId, mail_data)
-- 		end

-- 		local tor = LActor.getActorById(actorId)
-- 		if tor then --让在线玩家获得通关奖励
-- 			givePassReward(tor)
-- 		end
-- 	end
-- end
-- _G.flushSettleIsland = flushSettleIsland


local function fuBenInit()
	if System.isBattleSrv() then return end
	for _, conf in pairs(IslandFubenConfig) do
		insevent.registerInstanceWin(conf.fbId, onFbWin)
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceEnter(conf.fbId, onExitFb)
		insevent.registerInstanceOffline(conf.fbId, onOffline)
		insevent.regCustomFunc(conf.fbId, IslandDeferEarly, "IslandDeferEarly")
	end
	g_islandOpen = isOpenTime()
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_IslandFight, c2sIslandFight)
end
table.insert(InitFnTable, fuBenInit)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.islandfight = function (actor, args)
	c2sIslandFight(actor)
end

gmCmdHandlers.islandstart = function (actor, args)
	flushStartIsland()
end

gmCmdHandlers.islandstop = function (actor, args)
	flushStopIsland()
end
