module("tiantirank", package.seeall)
require("tianti.tiantirankaward")

--需要改
local rankingListName      = "tiantirank"
local rankingListFile      = "tiantirank.rank"
local rankingListMaxSize   = TianTiConstConfig.maxRankCount
local rankingListBoardSize = TianTiConstConfig.showRankCount
local rankingListColumns   = {"name","tianti_level", "tianti_id", "win_count", "actor_id", "actor_level", "vip_level", "serverid"}



local function getData()
	local var = System.getStaticVar()
	if not var then return end
	if not var.tiantirank then 
		var.tiantirank = {}
	end
	return var.tiantirank
end

local function initData()
	local var = getData()
	if var.last_week_data == nil then 
		var.last_week_data = {}
	end
	if var.last_week_data_len == nil then 
		var.last_week_data_len = 0
	end
end

--第一次创建排行榜
function updateDynamicFirstCache(actor_id)
	local rank = Ranking.getRanking(rankingListName)
	local rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then 
		rankTbl = {} 
	end
	if #rankTbl ~= 0 then 
		local prank = rankTbl[1]
		if actor_id == nil or actor_id == Ranking.getId(prank) then
			worship.updateDynamicFirstCache(Ranking.getId(prank), RankingType_TianTi)
		end
	end
end


--不需要改
function initRankingList()
	if not System.isBattleSrv() then return end
	local rank = utils.rankfunc.InitRank(rankingListName, rankingListFile, rankingListMaxSize, rankingListColumns, true)
	Ranking.addRef(rank)
	initData()
	updateDynamicFirstCache()
end

--需要改
function updateRankingList(actorid, tiantilevel, tiantiid, name, wincount, level, svip, serverid)
	if not System.isBattleSrv() then return end
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local item = Ranking.getItemPtrFromId(rank, actorid)
	if item ~= nil then
		local p = Ranking.getPoint(item)
		Ranking.setItem(rank, actorid, (tiantilevel * 100000000)  + (tiantiid * 10000) +  wincount)
	else
		item = Ranking.addItem(rank, actorid, (tiantilevel * 100000000)  + (tiantiid * 10000) +  wincount)
		if item == nil then return end
		--创建榜单
	end
	Ranking.setSub(item, 0, name)
	Ranking.setSub(item, 1, tiantilevel)
	Ranking.setSub(item, 2, tiantiid)
	Ranking.setSub(item, 3, wincount)
	Ranking.setSub(item, 4, actorid)
	Ranking.setSub(item, 5, level)
	Ranking.setSub(item, 6, svip)
	Ranking.setSub(item, 7, serverid)
	updateDynamicFirstCache(actorid)
end

--不需要改
function getrank(actor)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return 0 end

	return Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
end

function setPacket(npack, cpack)
	LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	local count = LDataPack.readShort(cpack)
	LDataPack.writeShort(npack, count)
	for i = 1, count do
		LDataPack.writeInt(npack, LDataPack.readInt(cpack))
		LDataPack.writeString(npack, LDataPack.readString(cpack)) -- name
		LDataPack.writeInt(npack, LDataPack.readInt(cpack)) -- level
		LDataPack.writeInt(npack, LDataPack.readInt(cpack)) -- id
		LDataPack.writeInt(npack, LDataPack.readInt(cpack)) -- win_count
	end
	
	count = LDataPack.readShort(cpack)
	LDataPack.writeShort(npack, count)
	for i=1, count do
		LDataPack.writeInt(npack, LDataPack.readInt(cpack))
		LDataPack.writeString(npack, LDataPack.readString(cpack))
		LDataPack.writeInt(npack, LDataPack.readInt(cpack))
		LDataPack.writeInt(npack, LDataPack.readInt(cpack))
		LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	end
end
--需要改
function getRankingList(actorid, npack)
	if not System.isBattleSrv() then return end
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
	if npack == nil then return end
	if rankTbl == nil then rankTbl = {} end
	LDataPack.writeInt(npack, Ranking.getItemIndexFromId(rank, actorid) + 1)
	LDataPack.writeShort(npack, #rankTbl)
	for i = 1, #rankTbl do
		local prank = rankTbl[i]
		LDataPack.writeInt(npack,Ranking.getId(prank))		
		LDataPack.writeString(npack,Ranking.getSub(prank,0)) -- name
		LDataPack.writeInt(npack,Ranking.getSub(prank,1)) -- level
		LDataPack.writeInt(npack,Ranking.getSub(prank,2)) -- id
		LDataPack.writeInt(npack,Ranking.getSub(prank, 3)) -- win_count
	end
	local var = getData() 
	local count = math.min(rankingListBoardSize, var.last_week_data_len)
	LDataPack.writeShort(npack, count)
	local i = 1
	while (i <= count) do
		local tbl = var.last_week_data[i]
		LDataPack.writeInt(npack,tbl.actor_id)
		LDataPack.writeString(npack,tbl.name)
		LDataPack.writeInt(npack,tbl.tianti_level)
		LDataPack.writeInt(npack,tbl.tianti_id)
		LDataPack.writeInt(npack,tbl.win_count)
		i = i + 1
	end
end


function onReqRanking(actor)
	if not System.isBattleSrv() then return end
	local rank = Ranking.getRanking(rankingListName)
	if not rank then return end
	local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_ResRankingData)
	if not npack then return end
	if rankTbl == nil then rankTbl = {} end
	LDataPack.writeShort(npack, RankingType_TianTi)
	LDataPack.writeShort(npack, #rankTbl)

	if rankTbl and #rankTbl > 0 then
		for i = 1, #rankTbl do
			local prank = rankTbl[i]
			local value = Ranking.getPoint(prank)
			LDataPack.writeShort(npack, i)
			LDataPack.writeInt(npack,Ranking.getSub(prank, 4)) -- actor_id
			LDataPack.writeString(npack,Ranking.getSub(prank,0)) -- name
			LDataPack.writeInt(npack,Ranking.getSub(prank, 5)) -- actor_level			
			LDataPack.writeInt(npack,Ranking.getSub(prank,2)) -- id			
			LDataPack.writeInt(npack,Ranking.getSub(prank, 1)) -- tianti_level						
			LDataPack.writeInt(npack,Ranking.getSub(prank, 3)) -- win_count		
			LDataPack.writeShort(npack,Ranking.getSub(prank, 6)) -- win_count					
		end
	end
	LDataPack.writeShort(npack, Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1)
	LDataPack.flush(npack)
end

--需要改
function resetRankingList()
	if not System.isBattleSrv() then return end
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	Ranking.clearRanking(rank, RankingType_TianTi)
end

--不需要改
function releaseRankingList()
	if not System.isBattleSrv() then return end
	utils.rankfunc.releaseRank(rankingListName, rankingListFile)
end

function refreshWeek()
	if not System.isBattleSrv() then return end
	local var = getData()
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	--dRankUpdateBefore(rankingListName) --动态排行榜更新
	local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then rankTbl = {} end

	var.last_week_data = {}
	var.last_week_data_len = 1
	for i = 1,#rankTbl do
		local prank      = rankTbl[i]
		local tbl        = {}
		tbl.actor_id     = Ranking.getId(prank)
		tbl.name         = Ranking.getSub(prank,0) -- name
		tbl.tianti_level = Ranking.getSub(prank,1) -- level
		tbl.tianti_id    = Ranking.getSub(prank,2) -- id
		tbl.win_count    = Ranking.getSub( prank,3) -- win_count

		local d = TianTiConstConfig.diamond

		if d.level == tonumber(tbl.tianti_level) and d.id == tonumber(tbl.tianti_id) then 
			local conf = TianTiRankAwardConfig[var.last_week_data_len]
			var.last_week_data[var.last_week_data_len] = tbl
			var.last_week_data_len = var.last_week_data_len + 1
			if conf ~= nil then 
				local mail_data      = {}
				mail_data.head       = TianTiConstConfig.rankMailHead
				mail_data.context    = string.format(TianTiConstConfig.rankMailContext,i)
				mail_data.tAwardList = conf.award
				local serverid = Ranking.getSub(prank,7)
				mailsystem.sendMailById(tbl.actor_id, mail_data, serverid)
			end
		else 
		end
	end
	if var.last_week_data_len == 1 then 
		var.last_week_data_len = 0
	else 
		var.last_week_data_len = var.last_week_data_len - 1
	end
	resetRankingList()
	--dRankUpdateAfter(rankingListName)
end

function getLastWeekFirstActorName()
	local var = getData()
	if var.last_week_data_len ~= 0 then 
		return var.last_week_data[1].name
	end
	return ""
end

function isLastWeekFirst(actor)
	local var = getData()
	if var.last_week_data_len ~= 0 then
		return var.last_week_data[1].actor_id == LActor.getActorId(actor)
	end
	return false
end


engineevent.regGameStartEvent(initRankingList)
engineevent.regGameStopEvent(releaseRankingList)

function gmSendTTEmail()
	local var = getData()
	for i = 1, var.last_week_data_len do
		local rank = var.last_week_data[i]
		local conf = TianTiRankAwardConfig[i]
		if conf ~= nil then 
			local mail_data      = {}
			mail_data.head       = TianTiConstConfig.rankMailHead
			mail_data.context    = string.format(TianTiConstConfig.rankMailContext,i)
			mail_data.tAwardList = conf.award
			mailsystem.sendMailById(rank.actor_id, mail_data, 0)
		end
	end
end


