-- @version	1.0
-- @author	qianmeng
-- @date	2017-5-22 14:22:47
-- @system	旗帜系统

module("bannersystem", package.seeall)
require("banner.banner")





local rankingListName      = "bannerrank"
local rankingListFile      = "bannerrank.rank"
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
			worship.updateDynamicFirstCache(Ranking.getId(prank), RankingType_Banner)
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
function updateRankingList(actor, level)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local actorId = LActor.getActorId(actor)

	local item = false
	local oldrank = Ranking.getItemIndexFromId(rank, actorId)
	if oldrank >= 0 then
		item = Ranking.setItem(rank, actorId, level)
	else
		item = Ranking.addItem(rank, actorId, level)--只增不降的用tryAddItem，会降的用addItem
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
	LDataPack.writeShort(npack, RankingType_Banner)
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
_G.onReqBannerRanking = onReqRanking

-------------------------------------------------------------------------

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.bannerData then var.bannerData = {} 	end
	if not var.bannerData.powers then var.bannerData.powers = {} end
	return var.bannerData
end


--创建一个旗帜数据结构
function activeBanner(actor, roleId, id)
	local var = getActorVar(actor)
	if not var then return end
	if not var[roleId] then
		var[roleId] = {}
		var[roleId].power = 0
	end
	var[roleId][id] = 0 --旗帜星级	
end

--返回旗帜激活
function getBanner(actor, roleId)
	local var = getActorVar(actor)
	if not var[roleId] then
		var[roleId] = {}
		var[roleId].power = 0
	end
	return var[roleId]
end

--返回旗帜特效id，C++用
function getBannerId(actor, roleId)
	local var = getActorVar(actor)
	if var[roleId] then
		return var[roleId].curId or 0
	end
	return 0
end
_G.getBannerId = getBannerId

--更新属性
function updateAttr(actor, roleId, calc)
	local addAttrs = {}
	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Banner)
	attr:Reset()
	for i=0, LActor.getRoleCount(actor) - 1 do
		local flag = getBanner(actor, roleId)
		for id, __ in pairs(BannerConfig) do
			if flag[id] then
				for k, v in pairs(BannerStarConfig[id][flag[id]].attr) do
					addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
					attr:Add(v.type, v.value)
				end
			end
		end
	end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)		
		updateRankingList(actor, getTotalStarLv(actor))

		local var = getActorVar(actor)
		var.powers[roleId] = utils.getAttrPower0(addAttrs)
		local power = 0
		for i=0, LActor.getRoleCount(actor) - 1 do
			power = power + (var.powers[i] or 0)
		end
		bannerpowerrank.updateRankingList(actor, power)
	end
end

--旗帜总星级
function getTotalStarLv(actor)
	local lv = 0
	for roleId=0, LActor.getRoleCount(actor) - 1 do
		local flag = getBanner(actor, roleId)
		for id in pairs(BannerConfig) do
			if flag[id] then
				local stage = flag[id]
				if stage == 0 then stage = 1 end
				stage = math.floor(stage / BannerCommonConfig.radix) + 1
				lv = lv + (flag[id] - stage + 1)
			end
		end
	end
	return lv
end

--旗帜总等阶
function getBannerTotalLv(actor)
	local lv = 0
	for roleId=0, LActor.getRoleCount(actor) - 1 do
		local flag = getBanner(actor, roleId)
		for id in pairs(BannerConfig) do
			if flag[id] then
				local stage = flag[id]
				if stage == 0 then stage = 1 end
				lv = lv + (math.floor(stage / BannerCommonConfig.radix) + 1)
			end
		end
	end
	return lv
end

-------------------------------------------------------------------------------------------
--旗帜信息
function s2cBannerInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Tanmi, Protocol.sBannerCmd_Info)
	if pack == nil then return end
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count)
	for roleId = 0, count-1 do
		local ec = 0
		LDataPack.writeChar(pack, roleId)
		local pos = LDataPack.getPosition(pack)
		LDataPack.writeChar(pack, ec)
		for id, v in pairs(BannerConfig) do
			local flag = getBanner(actor, roleId)
			if flag[id] then
				LDataPack.writeChar(pack, id)
				LDataPack.writeWord(pack, flag[id])
				ec = ec + 1
			end
		end
		LDataPack.writeChar(pack, getBannerId(actor, roleId))
		local npos = LDataPack.getPosition(pack)
		LDataPack.setPosition(pack, pos)
		LDataPack.writeChar(pack, ec)
		LDataPack.setPosition(pack, npos)
	end
	LDataPack.flush(pack)
end

--旗帜激活
function c2sBannerActive(actor, pack)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.banner) then return end
	local roleId = LDataPack.readChar(pack)
	local id = LDataPack.readChar(pack)
	local var = getActorVar(actor)
	if not var then return end
	local conf = BannerConfig[id]
	if not conf then return end
	if getBanner(actor, roleId)[id] then return end --已激活
	if conf.condition == 1 then
		if LActor.getLevel(actor) < conf.param then
			return
		end
	else
		if getBanner(actor, roleId)[id - 1] < conf.param then
			return
		end
	end
	activeBanner(actor, roleId, id)
	var[roleId].curId = id
	
	updateAttr(actor, roleId, true)	

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Tanmi, Protocol.sBannerCmd_Active)
	if pack == nil then return end
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, id)
	LDataPack.flush(pack)

	s2cBannerInfo(actor)
	actorevent.onEvent(actor, aeNotifyFacade, roleId)
	actorevent.onEvent(actor, aeBannerActive, roleId)
	utils.logCounter(actor, "banner active", var.star)
end

--旗帜特效激活
function c2sBannerEffect(actor, pack)
	local roleId = LDataPack.readChar(pack)
	local id = LDataPack.readChar(pack)
	local conf = BannerConfig[id]
	if not conf then return end
	if not getBanner(actor, roleId)[id] then return end --未激活
	local var = getActorVar(actor)
	var[roleId].curId = id
	s2cBannerInfo(actor)
	actorevent.onEvent(actor, aeNotifyFacade, roleId)
end
--旗帜升星
function c2sBannerStarUp(actor, pack)
	local roleId = LDataPack.readChar(pack)
	local id = LDataPack.readChar(pack)
	local conf = BannerStarConfig[id]
	local banner = getBanner(actor, roleId)
	local star = banner[id]
	if not star then return end --未激活
	if not conf[star + 1] then return end --已满级
	if not actoritem.checkItem(actor, conf[star].itemid, conf[star].count) then 
		return 
	end
	actoritem.reduceItem(actor, conf[star].itemid, conf[star].count, "banner star up")

	banner[id] = banner[id] + 1

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Tanmi, Protocol.sBannerCmd_StarUp)
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, id)
	LDataPack.writeWord(pack, star)
	LDataPack.flush(pack)
	updateAttr(actor, roleId, true)
	actorevent.onEvent(actor, aeBannerStarUp, roleId)
	s2cBannerInfo(actor)
end

function onLogin(actor)
	s2cBannerInfo(actor)
end

function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId, false)
	end
end

function onOpenRole(actor, roleId)
	s2cBannerInfo(actor)
end

--旗帜战力
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

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
netmsgdispatcher.reg(Protocol.CMD_Tanmi, Protocol.cBannerCmd_Active, c2sBannerActive)
netmsgdispatcher.reg(Protocol.CMD_Tanmi, Protocol.cBannerCmd_Effect, c2sBannerEffect)
netmsgdispatcher.reg(Protocol.CMD_Tanmi, Protocol.cBannerCmd_StarUp, c2sBannerStarUp)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.banneractive = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeChar(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sBannerActive(actor, pack)
	return true
end
