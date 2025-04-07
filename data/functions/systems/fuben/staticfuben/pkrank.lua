
module("pkrank", package.seeall)
local rankingListName      = "pkrank"
local rankingListFile      = "pkrank.rank"
local rankingListMaxSize   = 3000
local rankingListBoardSize = 100
local rankingListColumns   = {"name", "level", "viplevel"}

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
			worship.updateDynamicFirstCache(Ranking.getId(prank), RankingType_PkValue)
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
function updateRankingList(actor, pkvalue)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local actorId = LActor.getActorId(actor)

	local item = false
	local oldrank = Ranking.getItemIndexFromId(rank, actorId)
	if oldrank >= 0 then
		item = Ranking.setItem(rank, actorId, pkvalue)
	else
		item = Ranking.addItem(rank, actorId, pkvalue)--只增不降的用tryAddItem，会降的用addItem
	end
	if not item then return false end

	--创建榜单
	Ranking.setSub(item, 0, LActor.getName(actor))
	Ranking.setSubInt(item, 1, LActor.getLevel(actor))
	Ranking.setSubInt(item, 2, LActor.getVipLevel(actor))
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

--发送排行榜
function s2cRankingList(actor)
	local rank = Ranking.getRanking(rankingListName)
	if not rank then return end
	local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_ResRankingData)
	if not npack then return end

	if rankTbl == nil then rankTbl = {} end
	LDataPack.writeShort(npack, RankingType_PkValue)
	LDataPack.writeShort(npack, #rankTbl)

	if rankTbl and #rankTbl > 0 then
		for i = 1, #rankTbl do
			local prank = rankTbl[i]
			local value = Ranking.getPoint(prank)
			LDataPack.writeShort(npack, i)
			LDataPack.writeInt(npack, Ranking.getId(prank))
			LDataPack.writeString(npack, Ranking.getSub(prank, 0))
			LDataPack.writeInt(npack, Ranking.getSub(prank, 1))			
			LDataPack.writeDouble(npack, math.floor(value))
			LDataPack.writeShort(npack, Ranking.getSub(prank, 2))
		end
	end
	LDataPack.writeShort(npack, Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1)
	LDataPack.flush(npack)
end

function getrank(actor)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return 0 end

	return Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
end

function onReqRanking(actor)
	s2cRankingList(actor)
end
_G.onReqPkValueRanking = onReqRanking

--获取排名奖励索引
function getRankRewardIndex(rank)
    for i=1, #PkRankConfig do
        if rank >= PkRankConfig[i].rank[1] and rank <= PkRankConfig[i].rank[2] then
            return i
        end
    end
    return #PkRankConfig
end

--0点时发放奖励
function flushPkReward()
	if System.isBattleSrv() then return end

	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then rankTbl = {} end
	for i = 1, #rankTbl do
		local prank = rankTbl[i]
		local actor_id = Ranking.getId(prank)
		if not PkRobotConfig[actor_id] then
			local index = getRankRewardIndex(i)
			local conf = PkRankConfig[index]
			if conf ~= nil then 
				local mail_data = {}
				mail_data.head = PkConstConfig.rankMailHead
				mail_data.context = string.format(PkConstConfig.rankMailContext, i)
				mail_data.tAwardList = conf.rewards
				mailsystem.sendMailById(actor_id,mail_data)
			end
		end
    end
    Ranking.clearRanking(rank, RankingType_PkValue)
end
_G.flushPkReward = flushPkReward

engineevent.regGameStartEvent(initRankingList)
engineevent.regGameStopEvent(releaseRankingList)