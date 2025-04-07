-- @version	1.0
-- @author	qianmeng
-- @date	2017-8-28 15:02:37.
-- @system	梅林之书

module( "booksystem", package.seeall )

require("merlin.bookstar")
require("merlin.bookrank")
require("merlin.bookcommon")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.bookdata then var.bookdata = {} end
	if not var.bookdata.powers then var.bookdata.powers = {} end
	return var.bookdata
end

----------------------------------------------排行榜数据-------------------------------------------------------
local rankingListName      = "merlinrank"
local rankingListFile      = "merlinrank.rank"
local rankingListMaxSize   = 20
local rankingListBoardSize = 20
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
			worship.updateDynamicFirstCache(Ranking.getId(prank), RankingType_Merlin)
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
function updateRankingList(actor, power)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local actorId = LActor.getActorId(actor)

	local item = false
	local oldrank = Ranking.getItemIndexFromId(rank, actorId)
	if oldrank >= 0 then
		item = Ranking.setItem(rank, actorId, power)
	else
		item = Ranking.addItem(rank, actorId, power)--只增不降的用tryAddItem，会降的用addItem
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
	LDataPack.writeShort(npack, RankingType_Merlin)
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
_G.onReqMerlinRanking = onReqRanking
-----------------------------------------------------------------------------------------------------------------------

function activeBook(actor, roleId)
	local var = getActorVar(actor)
	if not var then return end
	if not var[roleId] then	var[roleId] = {} end
	var[roleId].rank = 1
	var[roleId].star = 0
	var[roleId].exp = 0
	s2cBookActive(actor, roleId)
	return var[roleId]
end

function getBookInfo(actor, roleId)
	local var = getActorVar(actor)
	local data = var[roleId]
	if data then
		return data.star, data.rank, data.exp, 1
	end
	return 0, 0, 0, 0
end

--梅林之书总等阶
function getBookTotalStageLv(actor)
	local lv = 0
	local var = getActorVar(actor)
	for roleid=0, LActor.getRoleCount(actor) - 1 do		
		local data = var[roleid]
		lv = lv + (data and data.rank or 0)
	end
	return lv
end

function updateAttr(actor, roleId, calc)
	local star = getBookInfo(actor, roleId)
	if star <= 0 then return end
	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Merlin)
	attr:Reset()
	for k, v in pairs(BookStarConfig[star].attr) do
		attr:Set(v.type, v.value)
	end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
		local var = getActorVar(actor)
		var.powers[roleId] = utils.getAttrPower(BookStarConfig[star].attr)
		updateRankingList(actor, getPower(actor) + secretsystem.getPower(actor)) --记入排行榜
	end
end

function getPower(actor)
	local var = getActorVar(actor)
	if not var then return 0 end
	local power = 0
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		power = power + (var.powers[roleId] or 0)
	end
	return power
end

local function isOpenSystem(actor)
	if actorexp.checkLevelCondition(actor, actorexp.LimitTp.merlin) then 
		return true
	end
	return false
end

local function getCritTimes(rank)
	local conf = BookRankConfig[rank]
	local nCurRate = math.random(1,100)
	local nRate = 0
	for _,tb in ipairs(conf.critRate) do
		nRate = nRate + tb.rate
		if (nRate >= nCurRate) then
			return tb.times
		end
	end
	return 1
end

function addBookExp(actor, roleId, addexp, times)
	addexp = addexp * times
	local var = getActorVar(actor)
	local data = var[roleId]
	if not data then return end
	local star = data.star
	local exp = data.exp
	exp = exp + addexp
	local conf = BookStarConfig[data.star]
	local isUp = false
	while exp >= conf.exp do
		if star >= BookCommonConfig[1].starMax then
			break
		end
		if star >= data.rank*BookCommonConfig[1].ladder-1 then --等阶限制
			break
		end
		exp = exp - conf.exp
		star = star + 1
		conf = BookStarConfig[star]
		isUp = true
	end
	data.star = star
	data.exp = exp
	if isUp then
		updateAttr(actor, roleId, true)
		actorevent.onEvent(actor, aeMerlinBookUp)
	end
	s2cBookUpdate(actor, roleId, data.star, data.rank, data.exp, times, addexp)
end

function addBookRank(actor, roleId, rank, star)
	local var = getActorVar(actor)
	local data = var[roleId]
	if not data then return end
	data.rank = rank
	data.star = star
	data.exp = 0
	updateAttr(actor, roleId, true)
	actorevent.onEvent(actor, aeMerlinBookUp)
	s2cBookUprank(actor, roleId, data.star, data.rank, data.exp)
end
---------------------------------------------------------------------------------
--梅林之书信息
function s2cBookInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Merlin, Protocol.sBook_Info)
	if pack == nil then return end
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count)
	for roleId = 0, count-1 do
		local star, rank, exp, active = getBookInfo(actor, roleId)
		LDataPack.writeChar(pack, roleId)
		LDataPack.writeInt(pack, star)
		LDataPack.writeInt(pack, rank)
		LDataPack.writeInt(pack, exp)
		LDataPack.writeByte(pack, active)
	end
	LDataPack.flush(pack)
end

--梅林之书提升
function c2sBookUpdate(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local var = getActorVar(actor)
	local data = var[roleId]
	if not data then return end
	local conf = BookRankConfig[data.rank]
	if not conf then return end
	if not actoritem.checkItem(actor, BookCommonConfig[1].itemId, conf.itemNum) then return end
	actoritem.reduceItem(actor, BookCommonConfig[1].itemId, conf.itemNum, "book update")
	local times = getCritTimes(data.rank)
	addBookExp(actor, roleId, conf.exp, times)
end

--梅林之书提升回包
function s2cBookUpdate(actor, roleId, star, rank, exp, times, addexp)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Merlin, Protocol.sBook_Update)
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeInt(pack, star)
	LDataPack.writeInt(pack, rank)
	LDataPack.writeInt(pack, exp)
	LDataPack.writeChar(pack, times)
	LDataPack.writeInt(pack, addexp)
	LDataPack.flush(pack)
end

--梅林之书升阶
function c2sBookUprank(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local var = getActorVar(actor)
	local data = var[roleId]
	if not data then return end
	if data.rank >= BookCommonConfig[1].rankMax then return end --最高阶

	if data.star < data.rank*BookCommonConfig[1].ladder-1 then --星级未满限制
		return
	end
	if not actoritem.checkItems(actor, BookRankConfig[data.rank].cost) then
		return
	end
	actoritem.reduceItems(actor, BookRankConfig[data.rank].cost, "book up")

	addBookRank(actor, roleId, data.rank+1, data.star+1)
end

--梅林之书升阶回包
function s2cBookUprank(actor, roleId, star, rank, exp)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Merlin, Protocol.sBook_Uprank)
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeInt(pack, star)
	LDataPack.writeInt(pack, rank)
	LDataPack.writeInt(pack, exp)
	LDataPack.flush(pack)
end

--梅林之书激活
function c2sBookActive(actor, packet)
	if not isOpenSystem(actor) then return end
	local roleId = LDataPack.readChar(packet)
	local var = getActorVar(actor)
	if var[roleId] then return end --已激活
	activeBook(actor, roleId)
	secretsystem.s2cSecretInfo(actor)
	actorevent.onEvent(actor, aeMerlinBookUp)
end

--梅林之书激活回包
function s2cBookActive(actor, roleId)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Merlin, Protocol.sBook_Active)
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeByte(pack, 1)
	LDataPack.writeInt(pack, 0) --星级
	LDataPack.writeInt(pack, 1) --等阶
	LDataPack.writeInt(pack, 0) --经验
	LDataPack.flush(pack)
end

local function onLogin(actor)
	if isOpenSystem(actor) then
		s2cBookInfo(actor)
	end
end

local function onCreateRole(actor, roleId)
	if isOpenSystem(actor) then
		s2cBookInfo(actor)
	end
end

local function onLevelUp(actor, level, oldLevel)
	local lv = actorexp.getLimitLevel(actor,actorexp.LimitTp.merlin)
	if lv > oldLevel and lv <= level then
		s2cBookInfo(actor)
	end
end

local function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId, false)
	end
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeCreateRole,onCreateRole)
actorevent.reg(aeLevel, onLevelUp)
netmsgdispatcher.reg(Protocol.CMD_Merlin, Protocol.cBook_Update, c2sBookUpdate)
netmsgdispatcher.reg(Protocol.CMD_Merlin, Protocol.cBook_Uprank, c2sBookUprank)
netmsgdispatcher.reg(Protocol.CMD_Merlin, Protocol.cBook_Active, c2sBookActive)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.bookactive = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sBookActive(actor, pack)

	-- local roleId = tonumber(args[1])
	-- activeBook(actor, roleId)
end

gmCmdHandlers.bookupdate = function (actor, args)
	local roleId = tonumber(args[1])
	local exp = tonumber(args[2])
	addBookExp(actor, roleId, exp, 1)
end

gmCmdHandlers.booksetrank = function (actor, args)
	-- local pack = LDataPack.allocPacket()
	-- LDataPack.writeChar(pack, args[1])
	-- LDataPack.setPosition(pack, 0)
	-- c2sBookUprank(actor, pack)

	addBookRank(actor, tonumber(args[1]), tonumber(args[2]), tonumber(args[3]))
end

gmCmdHandlers.bookinfo = function (actor, args)
	s2cBookInfo(actor)
end
