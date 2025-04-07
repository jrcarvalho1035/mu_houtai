--排行榜称号
module("addtitlelogic", package.seeall)
require("title.ranktitle")

local rtConf = RankTitleConfig
local rankTitleTbl = {}
local titleRankTbl = {}

function init()
	local tbl
	local name
	local rTbl
	for i=1, #rtConf do
		tbl = rtConf[i]
		name = nil
		if tbl.rId ~= -1 then
			name = tbl.rId
		elseif tbl.rName ~= "" then
			name = tbl.rName
		end
		if name ~= nil then
			if rankTitleTbl[name] == nil then rankTitleTbl[name] = {} end
			rTbl = rankTitleTbl[name]
			rTbl[#rTbl + 1] = tbl

			if titleRankTbl[tbl.tId] == nil then titleRankTbl[tbl.tId] = {} end
			rTbl = titleRankTbl[tbl.tId]
			rTbl[#rTbl + 1] = tbl
		end
	end
end

function dRankUpdate(rName)
	local rank = Ranking.getRanking(rName)
	if rank == nil then return end
	local rtTbl = rankTitleTbl[rName]
	if rtTbl == nil then return end
	local tbl
	local item
	local id
	local actor
	local d_var = System.getDyanmicVar()
	if d_var.dRankTitle == nil then d_var.dRankTitle = {} end
	local rtVar = d_var.dRankTitle
	local idx = 0
	local adds = {}
	local dels = {}
	local tempIdx = 0
	for i=1, #rtTbl do
		tbl = rtTbl[i]
		idx = tbl.rIdx - 1
		item = Ranking.getItemFromIndex(rank, idx)
		if item then
			id = Ranking.getId(item)
			
			--新的称号获得者
			if not rtVar[tbl.Id] or (rtVar[tbl.Id] and rtVar[tbl.Id].id ~= id) then
				tempIdx = #adds + 1
				adds[tempIdx] = {}
				adds[tempIdx].aId = id
				adds[tempIdx].Id = tbl.Id
				adds[tempIdx].tId = tbl.tId
				--print(string.format("addtitlelogic.dRankUpdate: addTitle rName:%s,aId:%d,tId:%d", rName, id, tbl.tId))
			end

			--上次的拥有者删除称号
			if rtVar[tbl.Id] and rtVar[tbl.Id].id ~= id then
				tempIdx = #dels + 1
				dels[tempIdx] = {}
				dels[tempIdx].aId = rtVar[tbl.Id].id
				dels[tempIdx].tId = tbl.tId
				--print(string.format("addtitlelogic.dRankUpdate: delTitle rName:%s,aId:%d,tId:%d", rName, rtVar[idx].id, tbl.tId))
			end
		end
	end
	for i=1, #dels do
		actor = LActor.getActorById(dels[i].aId)
		if actor then
			titlesystem.delitle(actor, dels[i].tId, true)
		end
	end
	for i=1, #adds do
		actor = LActor.getActorById(adds[i].aId)
		if actor then
			titlesystem.addTitle(actor, adds[i].tId, true)
		end
		if not d_var.dRankTitle[adds[i].Id] then d_var.dRankTitle[adds[i].Id] = {} end
		d_var.dRankTitle[adds[i].Id].id = adds[i].aId
	end

	--d_var.dRankTitle = {}
end

-- --刷新排行榜之前要清掉之前的人的称号
-- function dRankUpdateBefore(rName)
-- 	local rank = Ranking.getRanking(rName)
-- 	if rank == nil then return end
-- 	local rtTbl = rankTitleTbl[rName]
-- 	if rtTbl == nil then return end

-- 	local tbl
-- 	local item
-- 	local id
-- 	local d_var = System.getDyanmicVar()
-- 	if d_var.dRankTitle == nil then d_var.dRankTitle = {} end
-- 	local rtVar = d_var.dRankTitle
-- 	local idx = 0

-- 	for i=1, #rtTbl do
-- 		tbl = rtTbl[i]
-- 		idx = tbl.rIdx - 1
-- 		item = Ranking.getItemFromIndex(rank, idx)
-- 		if item then
-- 			id = Ranking.getId(item)
-- 			if id > 0 then
-- 				rtVar[idx] = {}
-- 				rtVar[idx].id = id
-- 			end
-- 		end
-- 	end
-- end

function ehInit(actor)
	if System.isCrossWarSrv() then return end
	local tbl
	local id
	local rank
	local isAdd = false
	local item
	local aId = LActor.getActorId(actor)
	local d_var = System.getDyanmicVar()
	if not d_var.dRankTitle then d_var.dRankTitle = {} end
	for k,v in pairs(titleRankTbl) do
		isAdd = false
		for i=1, #v do
			tbl = v[i]
			if d_var.dRankTitle[tbl.Id] and d_var.dRankTitle[tbl.Id].id == aId then 
				isAdd = true
			end
		end

		if isAdd then
			titlesystem.addTitle(actor, k, true)
		else
			titlesystem.delitle(actor, k, false, true)
		end
	end
end


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.ranktitle = function (actor, args)
	utils.rankfunc.flushSetTitle()
	return true
end


actorevent.reg(aeInit, ehInit)
table.insert(InitFnTable, init)