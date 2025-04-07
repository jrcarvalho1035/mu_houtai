
module("jjcrank", package.seeall)

--需要改
local rankingListName      = "jjcrank"
local rankingListFile      = "jjcrank.rank"
local rankingListMaxSize   = JjcConstConfig.maxRankCount
local rankingListBoardSize = 20
local rankingListColumns   = {"name", "vip", "svip"}

local function getGlobalData()
	local var = System.getStaticVar()
	if not var then return end
	if not var.jjcrankData then 
		var.jjcrankData = {}
	end
	if not var.jjcrankData.updateTime then var.jjcrankData.updateTime = 0 end
	return var.jjcrankData;
end

function getRankTbl(size)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local rankTbl = Ranking.getRankingItemList(rank, size)
	return rankTbl
end

--机器人插入排行榜
function initRobotRankingList()
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	for i = 1, rankingListMaxSize do
		local conf = JjcRobotConfig[i]
		local item = Ranking.addItem(rank, conf.id, 0)
		Ranking.setSub(item, 0, conf.name)
		Ranking.setSubInt(item, 1, 0) --vip
		Ranking.setSubInt(item, 2, 0) --svip
	end
end

--更新排行榜比分数值，需要改
-- function updateRankingList(actorId, score)
-- 	score = 0
-- 	local rank = Ranking.getRanking(rankingListName)
-- 	if rank == nil then return end
-- 	local item = Ranking.getItemPtrFromId(rank, actorId)
-- 	if item ~= nil then
-- 		local p = Ranking.getPoint(item)
-- 		Ranking.setItem(rank, actorId, score)
-- 	else
-- 		--只增不降的用tryAddItem
-- 		--会降的用addItem
-- 		item = Ranking.addItem(rank, actorId, score)
-- 		if item == nil then return end
-- 	end
-- 	--创建榜单
-- 	if actorId > 0 then
-- 		local basic_data = LActor.getActorDataById(actorId)
-- 		Ranking.setSub(item, 0, basic_data.actor_name)
-- 		Ranking.setSubInt(item, 1, basic_data.level)
-- 		Ranking.setSubInt(item, 2, basic_data.vip_level)
-- 		Ranking.setSubInt(item, 3, basic_data.monthcard)
-- 		Ranking.setSubInt(item, 4, basic_data.job) --职业
-- 		Ranking.setSubInt(item, 5, basic_data.guild_id_) --公会
-- 		Ranking.setSubInt(item, 6, 0) --是否机器人
-- 	else
-- 		local conf = JjcRobotConfig[-actorId][0]
-- 		Ranking.setSub(item, 0, conf.name)
-- 		Ranking.setSubInt(item, 1, conf.level)
-- 		Ranking.setSubInt(item, 2, 0) --vip
-- 		Ranking.setSubInt(item, 3, 0) --月卡
-- 		Ranking.setSubInt(item, 4, conf.job) --职业
-- 		Ranking.setSubInt(item, 5, 0) --公会
-- 		Ranking.setSubInt(item, 6, 1) --是否机器人
-- 	end
-- 	updateDynamicFirstCache(LActor.getActorId(actor))
-- end

--玩家设置榜单的数据
function setRankItem(item, actorId)
	local basic_data = LActor.getActorDataById(actorId)
	if not basic_data then return end
	Ranking.setSub(item, 0, basic_data.actor_name)
	Ranking.setSubInt(item, 1, basic_data.vip)
	Ranking.setSubInt(item, 2, basic_data.vip_level)
end

--交换排名
function swapRankingItem(id1, id2)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return 0 end
	local item1 = Ranking.getItemPtrFromId(rank, id1)
	local item2 = Ranking.getItemPtrFromId(rank, id2)
	if not item1 then
		item1 = Ranking.addItem(rank, id1, 0) --只增不降的用tryAddItem,会降的用addItem
	end
	if not item2 then
		item2 = Ranking.addItem(rank, id2, 0) --只增不降的用tryAddItem,会降的用addItem
	end
	if not (item1 and item2) then
		return
	end
	setRankItem(item1, id1)
	setRankItem(item2, id2)

	Ranking.swapEqualItem(rank, item1, item2)
	updateDynamicFirstCache()
end

--第一次创建排行榜
function updateDynamicFirstCache(actor_id)
	local rank = Ranking.getRanking(rankingListName)
	local rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then 
		rankTbl = {} 
	end
	if #rankTbl == 0 then 
		initRobotRankingList()
	end

	if #rankTbl ~= 0 then 
		local prank = rankTbl[1]		
		if actor_id == nil or actor_id == Ranking.getId(prank) then  
			worship.updateDynamicFirstCache(Ranking.getId(prank), RankingType_Jjc)
		end
	else
		worship.updateDynamicFirstCache(1, RankingType_Jjc)
	end
end


--初始化排行榜，不需要改
function initRankingList()
	local rank = utils.rankfunc.InitRank(rankingListName, rankingListFile, rankingListMaxSize, rankingListColumns, true)
	Ranking.addRef(rank)
	updateDynamicFirstCache()
end

--释放排行榜，不需要改
function releaseRankingList()
	utils.rankfunc.releaseRank(rankingListName, rankingListFile)
end

--获得排名，不需要改
function getrank(actor)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return 0 end
	local idx = Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
	if idx <= 0 then
		return JjcConstConfig.maxRankCount + 1
	end
	if idx > JjcConstConfig.maxRankCount + 1 then
		return JjcConstConfig.maxRankCount + 1
	end
	return idx
end

--根据actorId获得排名
function getrankById(actorId)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return 0 end
	local idx = Ranking.getItemIndexFromId(rank, actorId) + 1
	if idx <= 0 then
		return JjcConstConfig.maxRankCount + 1
	end
	return idx
end

--发送排行榜
function onReqRanking(actor)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then 
		return 
	end
	local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_ResRankingData)
	if npack == nil then 
		return 
	end

	if rankTbl == nil then rankTbl = {} end
	LDataPack.writeShort(npack, RankingType_Jjc)
	LDataPack.writeShort(npack, #rankTbl)
	if rankTbl and #rankTbl > 0 then
		for i = 1, #rankTbl do
			local prank = rankTbl[i]
			LDataPack.writeShort(npack, i)
			local actor_id = Ranking.getId(prank)
			local gName = ""
			local power = 0
			local name = Ranking.getSub(prank, 0)
			if JjcRobotConfig[actor_id] then
				power = JjcRobotConfig[actor_id].power
				if string.sub(name, 1, 1) ~= "S" then
					name = chatcommon.getServerNameBySId(System.getServerId()).."."..name
				end
			else
				local basic_data = LActor.getActorDataById(actor_id)
				if basic_data then
					gName = guildcommon.getGuilNameById(basic_data.guild_id_)
					power = basic_data.total_power
				end
			end
			LDataPack.writeInt(npack, actor_id)
			LDataPack.writeString(npack, name)--名字			
			LDataPack.writeChar(npack, Ranking.getSub(prank,1)) --VIP等级
			LDataPack.writeChar(npack, Ranking.getSub(prank,2)) --SVIP等级
			LDataPack.writeDouble(npack, power)
			LDataPack.writeString(npack, gName) --公会名
		end
	end
	LDataPack.writeShort(npack, Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1)
	LDataPack.flush(npack)
end

--21点时发放竞技场奖励
function flushGrantJjcReward()
	if System.isCrossWarSrv() then return end
	local data = getGlobalData()
	data.updateTime = System.getNowTime()

	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then rankTbl = {} end
	for i = 1, #rankTbl do
		local prank = rankTbl[i]
		local actor_id = Ranking.getId(prank)
		if not JjcRobotConfig[actor_id] then
			local id = jjc.getRankAwardSection(i)
			local conf = JjcRewardConfig[id]
			if conf ~= nil then 
				local mail_data = {}
				mail_data.head = JjcConstConfig.rankMailHead
				mail_data.context = string.format(JjcConstConfig.rankMailContext, i)
				mail_data.tAwardList = conf.dailyReward
				mailsystem.sendMailById(actor_id,mail_data)
			end
		end
	end
end
_G.flushGrantJjcReward = flushGrantJjcReward

local function initGlobalData()
	if System.isCrossWarSrv() then return end
	local data = getGlobalData()
	local now = System.getNowTime()
	if data.updateTime < now - 24*3600 then --预防关服期跨过flushGrantJjcReward
		flushGrantJjcReward()
	end	
end
table.insert(InitFnTable, initGlobalData)
engineevent.regGameStartEvent(initRankingList)
engineevent.regGameStopEvent(releaseRankingList)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.jjcrank = function (actor, args)
	-- s2cRankingList(actor)
	return true
end

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.sendjjc = function (actor, args)
	flushGrantJjcReward()
	return true
end
