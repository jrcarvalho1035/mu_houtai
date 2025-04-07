--排行榜相关函数
module("utils.rankfunc", package.seeall)

local function getSystemVar()
    local var = System.getStaticVar()
    if var.angelrank == nil then
        var.angelrank = {}        
	end
	if not var.angelrank.updatetime then var.angelrank.updatetime = 0 end

    return var.angelrank
end


-- 初始化排行榜
function InitRank(rankName, rankFile, maxNum, coloumns, initSave)
	local rank = Ranking.getRanking(rankName)
	if rank == nil then
		rank = Ranking.add(rankName, maxNum, 0)
		if rank == nil then
			print("can not add rank:"..rankName..","..rankFile)
			return 
		end
		if Ranking.load(rank, rankFile) == false and coloumns then
			-- 创建排行榜
			for i=1, #coloumns do
				Ranking.addColumn( rank, coloumns[i] )
			end
		end
	end

	if coloumns then 
		local col = Ranking.getColumnCount(rank)
		for i=col+1,#coloumns do
			Ranking.addColumn(rank, coloumns[i])
		end
	end
	Ranking.addRef(rank)

	if initSave then
		Ranking.save(rank, rankFile)
	end
	
	return rank
end

--释放排行榜
function releaseRank(rankName, rankFile)
	local rank = Ranking.getRanking(rankName)
	Ranking.save(rank, rankFile)
	Ranking.release(rank)
end

function getRankIndex(rankItem)
	if not rankItem then return -1 end
	return Ranking.getIndexFromPtr(rankItem) + 1
end

function setRank(rank, id, point, ...)
	if not rank then return nil end
	local item = Ranking.getItemPtrFromId(rank, id)
	if item then
		Ranking.setItem(rank, id, point)
	else
		item = Ranking.addItem(rank, id, point)
	end

	for i,v in ipairs(arg) do
		Ranking.setSub(item, i-1, v)
	end
	return item
end

function onGameStart( ... )
	if System.isCrossWarSrv() then return end
	initRankingList()
	local data = getSystemVar()
	if data.updatetime == 0 then
		local openday = System.getOpenServerDay() + 1
		if openday > RankCommonConfig.endtime and openday < 6 then
			angelRankFinish()
		end
	end
	--Ranking.updateStaticRank()
end

function onGameEnd(...)
	releaseRankingList()
end

function updateStaticFirstCache()
	Ranking.updateStaticFirstCache()
end

local rankingListName = {[0]="powerrank", [1] = "levelrank", [2] = "customrank", [3] = "wanmorank", [4] = "heianrank",[5] = "jjcrank", [6] = "guildrank",
[7] = "damonrank",[8]="yongbingrank", [9] = "shenqirank", [10] = "wingrank", [11] = "shenzhuangrank", [12] = "meilinrank",[13] = "hunqirank", [14] = "lilianrank",
[15] = "touxianrank", [16] = "equiprank", [17] = "shenmorank", [18] = "tiantirank", [19] = "fortrank", [20] = "warrior", [21] = "mage", [22] = "archer"}
local rankingListFile = {}
for i=RankingType_Power, RankingType_Archer do
	rankingListFile[i] = rankingListName[i]..".rank"
end

local rankingListMaxSize   = 20
local rankingListBoardSize = 20
local rankingListColumns   = {"name", "vip", "svip"}

--第一次创建排行榜表
function updateFirstCache(actor_id, rank_type)
	local rank = Ranking.getRanking(rankingListName[rank_type])
	local rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then 
		rankTbl = {} 
	end
	if #rankTbl ~= 0 then 
		local prank = rankTbl[1]
		if actor_id == nil or actor_id == Ranking.getId(prank) then
			worship.updateDynamicFirstCache(Ranking.getId(prank), rank_type)
		end
	end
end

--初始化排行榜
function initRankingList()
	for i=RankingType_Power, RankingType_Archer do
		local rank = InitRank(rankingListName[i], rankingListFile[i], rankingListMaxSize, rankingListColumns, true)
		Ranking.addRef(rank)
		if i ~= RankingType_Guild and i ~= RankingType_Jjc and i ~= RankingType_TianTi and i ~= RankingType_Fort then
			updateFirstCache(nil, i)
		end
	end
end

function getRankById(rank_type)
	return Ranking.getRanking(rankingListName[rank_type])
end

--
function getrank(actor, rank_type)
	local rank = Ranking.getRanking(rankingListName[rank_type])
	if rank == nil then return 0 end

	return Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
end

--更新排行榜比分数值
function updateRankingList(actor, value, rank_type)
	local rank = Ranking.getRanking(rankingListName[rank_type])
	if rank == nil then return end
	local actorId = LActor.getActorId(actor)

	local item = false
	local oldrank = Ranking.getItemIndexFromId(rank, actorId)
	if oldrank >= 0 then
		item = Ranking.setItem(rank, actorId, value)
	else
		item = Ranking.addItem(rank, actorId, value)--只增不降的用tryAddItem，会降的用addItem
	end
	if not item then return false end

	--创建榜单
	Ranking.setSub(item, 0, LActor.getName(actor))
	Ranking.setSub(item, 1, LActor.getVipLevel(actor))
	Ranking.setSubInt(item, 2, LActor.getSVipLevel(actor))
	updateFirstCache(LActor.getActorId(actor), rank_type)
end

function releaseRankingList()
	for i=RankingType_Power,RankingType_Archer do
		if i~= RankingType_Jjc then
			releaseRank(rankingListName[i], rankingListFile[i])
		end
	end
end

function onReqRanking(actor, rank_type)
	if rank_type == RankingType_Jjc then
		jjcrank.onReqRanking(actor)
	elseif rank_type == RankingType_Fort then
		fort.onReqRanking(actor)
	elseif rank_type == RankingType_TianTi then
		tiantirank.onReqRanking(actor)
	else
		local rank = Ranking.getRanking(rankingListName[rank_type])
		if not rank then return end
		local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_ResRankingData)
		if not npack then return end
		if rankTbl == nil then rankTbl = {} end
		LDataPack.writeShort(npack, rank_type)
		LDataPack.writeShort(npack, #rankTbl)
		if rankTbl and #rankTbl > 0 then
			for i = 1, #rankTbl do
				local prank = rankTbl[i]
				local value = Ranking.getPoint(prank)
				LDataPack.writeShort(npack, i)
				LDataPack.writeInt(npack, Ranking.getId(prank))
				LDataPack.writeString(npack, Ranking.getSub(prank, 0))
				LDataPack.writeChar(npack, Ranking.getSub(prank, 1))
				LDataPack.writeChar(npack, Ranking.getSub(prank, 2))
				LDataPack.writeDouble(npack, value)
			end
		end
		LDataPack.writeShort(npack, Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1)
		LDataPack.flush(npack)
	end
end

_G.onReqRanking = onReqRanking


function angelRankFinish()
	for rank_type = RankingType_Warrior, RankingType_Archer do
		repeat
			local rank = Ranking.getRanking(rankingListName[rank_type])
			if not rank then break end
			local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
			if rankTbl == nil then rankTbl = {} end
			if rankTbl and #rankTbl > 0 then
				local prank = rankTbl[1]
				local actorid = Ranking.getId(prank)
				local mailData = {head = RankCommonConfig.firsthead, context = RankCommonConfig.firstcontent, tAwardList=RankCommonConfig[rankingListName[rank_type]]}
				mailsystem.sendMailById(actorid, mailData)
				break	
			end
		until true		
	end
	local data = getSystemVar()
	data.updatetime = System.getNowTime()
end

function angelEquipFinish()
	print("angelEquipFinish")
	local openday = System.getOpenServerDay() + 1
	if openday ~= RankCommonConfig.endtime + 1 then
		return
	end
	angelRankFinish()
end
_G.angelEquipFinish = angelEquipFinish

engineevent.regGameStartEvent(onGameStart)
engineevent.regGameStopEvent(onGameEnd)

function flushSetTitle()
	for i=RankingType_Power, RankingType_Shenmo do
		addtitlelogic.dRankUpdate(rankingListName[i])
	end
end
_G.flushSetTitle = flushSetTitle

onChangeName = function(actor, res, name, rawName, way)
	--动态排行榜修改
	for i=RankingType_Power, RankingType_Fort do
		local rank = Ranking.getRanking(rankingListName[i])
		if rank then
			local actorId = LActor.getActorId(actor)
			local item = Ranking.getItemPtrFromId(rank, actorId)
			if item then
				Ranking.setSub(item, 0, name)
			end
		end
	end
	
	--静态排行榜修改
	Ranking.updateStaticRank()
end

actorevent.reg(aeChangeName, onChangeName)


