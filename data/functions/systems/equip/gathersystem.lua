-- @version	2.0
-- @author	qianmeng
-- @date	2017-12-23 17:55:56.
-- @system	武器聚魂

module("gathersystem", package.seeall )

require("equip.gatherlevel")
require("equip.gatherextra")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.gatherdata then var.gatherdata = {} end
	if not var.gatherdata.powers then var.gatherdata.powers = {} end
	return var.gatherdata
end

----------------------------------------------排行榜数据-------------------------------------------------------
local rankingListName      = "jusoulrank"
local rankingListFile      = "jusoulrank.rank"
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
			worship.updateDynamicFirstCache(Ranking.getId(prank), RankingType_JuSoul)
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
	LDataPack.writeShort(npack, RankingType_JuSoul)
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
_G.onReqJuSoulRanking = onReqRanking
-----------------------------------------------------------------------------------------------------------------------

--更新属性
function updateAttr(actor, roleId, calc)
	local addAttrs = {}
	local role = LActor.getRole(actor,roleId)
	local var = getActorVar(actor)

	for tp, v in pairs(GatherLevelConfig) do
		local totalLv = 1000 --所有槽的最低等级
		for hold, v1 in pairs(v) do
			local level = getVarGather(var, roleId, tp, hold)
			if level >= 0 and v1[level] then
				for k, attr in pairs(v1[level].attr) do
					addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
				end
			end
			if totalLv > level then
				totalLv = level
			end
		end
		local match = -1 --0表示激活，并且也有属性，所以要从-1开始
		for k1, v1 in pairs(GatherExtraConfig[tp] or {}) do
			if totalLv >= k1 and match < k1 then match = k1 end
		end
		local extraConf = GatherExtraConfig[tp] and GatherExtraConfig[tp][match]
		if extraConf then
			for k, attr in pairs(extraConf.attr) do
				addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
			end
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Gather)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
		var.powers[roleId] = utils.getAttrPower0(addAttrs)
		updateRankingList(actor, getPower(actor)) --记入排行榜
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

function setGather(actor, roleId, tp, hold, level)
	local var = getActorVar(actor)
	if not var then return end
	if not var[roleId] then	
		var[roleId] = {}
	end
	if not var[roleId][tp] then
		var[roleId][tp] = {}
	end
	var[roleId][tp][hold] = level
	updateAttr(actor, roleId, true)
	actorevent.onEvent(actor, aeJuSoulUp, level)
end

function getGather(actor, roleId, tp, hold)
	local var = getActorVar(actor)
	if var and var[roleId] and var[roleId][tp] and var[roleId][tp][hold] then
		return var[roleId][tp][hold]
	end
	return -1
end

function getVarGather(var, roleId, tp, hold)
	if var and var[roleId] and var[roleId][tp] and var[roleId][tp][hold] then
		return var[roleId][tp][hold]
	end
	return -1
end

--聚魂特效总个数
function getGatherEffectCount(actor)
	local count = 0
	local var = getActorVar(actor)
	for roleId=0, LActor.getRoleCount(actor) - 1 do		
		for tp in pairs(GatherLevelConfig) do
			local flag = true
			for hold, v in pairs(GatherLevelConfig[tp]) do
				local level = getVarGather(var, roleId, tp, hold)
				if level < 0 then
					flag = false
				end
			end
			if flag then
				count = count + 1
			end
		end		
	end
	return count
end

function getGatherId(actor, roleId)
	local var = getActorVar(actor)
	return var[roleId] and var[roleId].effect or 0
end
_G.getGatherId = getGatherId
-------------------------------------------------------------------------------------
--聚魂信息
function s2cGatherInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_GatherInfo)
	if pack == nil then return end
	local var = getActorVar(actor)
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count) --角色数量
	for roleId = 0, count-1 do
		LDataPack.writeChar(pack, roleId) --角色id
		local tpcount = 0 
		local tppos = LDataPack.getPosition(pack)
		LDataPack.writeChar(pack, tpcount) --类型数量
		for tp, v in pairs(GatherLevelConfig) do
			local flag = false 
			local holdcount = 0 
			local holdpos = 0
			for hold, v1 in pairs(v) do
				local lv = getVarGather(var, roleId, tp, hold)
				if lv >= 0 then
					if not flag then --循环内只发第一次
						LDataPack.writeChar(pack, tp) --类型
						holdpos = LDataPack.getPosition(pack)
						LDataPack.writeChar(pack, holdcount) --聚魂槽数量
						flag = true
					end
					holdcount = holdcount + 1
					LDataPack.writeChar(pack, hold) --槽位置
					LDataPack.writeShort(pack, lv)	--等级
				end
			end
			if holdcount > 0 then
				local npos = LDataPack.getPosition(pack)
				LDataPack.setPosition(pack, holdpos)
				LDataPack.writeChar(pack, holdcount)
				LDataPack.setPosition(pack, npos)
			end

			if flag then
				tpcount = tpcount + 1
			end
			
		end
		if tpcount > 0 then
			local npos = LDataPack.getPosition(pack)
			LDataPack.setPosition(pack, tppos)
			LDataPack.writeChar(pack, tpcount)
			LDataPack.setPosition(pack, npos)
		end
		LDataPack.writeChar(pack, var[roleId] and var[roleId].effect or 0) --使用特效
	end
	LDataPack.flush(pack)
end

--聚魂升级
function c2sGatherLevel(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local tp = LDataPack.readChar(packet)
	local hold = LDataPack.readChar(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.gather) then return end

	local lv = getGather(actor, roleId, tp, hold)
	local conf = GatherLevelConfig[tp] and GatherLevelConfig[tp][hold] and GatherLevelConfig[tp][hold][lv]
	if not (GatherLevelConfig[tp] and GatherLevelConfig[tp][hold] and GatherLevelConfig[tp][hold][lv+1]) then return end --下一级的信息不存在（达到最高级）

	if not actoritem.checkItems(actor, conf.items) then
		utils.printTable(conf.items)
		return
	end
	actoritem.reduceItems(actor, conf.items, "gather level")
	local ret = math.random(1, 10000) <= conf.rate --是否成功
	if ret then
		lv = lv + 1
		setGather(actor, roleId, tp, hold, lv)
	end
	s2cGatherUpdate(actor, ret, roleId, tp, hold, lv)

	--判断是否发送公告
	if ret and lv == 0 then
		local flag = true --是否已全部激活
		for hold, v in pairs(GatherLevelConfig[tp]) do
			local level = getVarGather(var, roleId, tp, hold)
			if level < 0 then
				flag = false
			end
		end
		if flag then
			noticesystem.broadCastNotice(noticesystem.NTP.gather, LActor.getName(actor), ScriptTips.gathername[tp]) 
		end
	end

	local extra = string.format("role:%d,tp:%d,hold:%d,lv:%d",  roleId, tp, hold, lv)
	utils.logCounter(actor, "othersystem", "", extra, "gather", "uplevel")
end

--聚魂更新
function s2cGatherUpdate(actor, isSuc, roleId, tp, hold, newLv)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_GatherUp)
	if pack == nil then return end
	LDataPack.writeByte(pack, isSuc and 1 or 0)
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, tp)
	LDataPack.writeChar(pack, hold)
	LDataPack.writeShort(pack, newLv)
	LDataPack.flush(pack)
end

--聚魂特效使用
function c2sGatherEffect(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local tp = LDataPack.readChar(packet)
	if tp ~= 0 and (not GatherLevelConfig[tp]) then
		return
	end
	local var = getActorVar(actor)
	if tp ~= 0 then
		local flag = true --是否已全部激活
		for hold, v in pairs(GatherLevelConfig[tp]) do
			local level = getVarGather(var, roleId, tp, hold)
			if level < 0 then
				flag = false
			end
		end
		if not flag then return end
	end
	var[roleId].effect = tp

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_GatherEffect)
	if pack == nil then return end
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, var[roleId].effect)
	LDataPack.flush(pack)
	
	actorevent.onEvent(actor, aeNotifyFacade, roleId)
end
---------------------------------------------------------------------------

local function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId, false)
	end
end

local function onLogin(actor)
	s2cGatherInfo(actor)
end 

local function onOpenRole(actor, roleId)
	s2cGatherInfo(actor)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_GatherUp, c2sGatherLevel)
netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_GatherEffect, c2sGatherEffect)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.gatherlevel = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeChar(pack, args[2])
	LDataPack.writeChar(pack, args[3])
	LDataPack.setPosition(pack, 0)
	c2sGatherLevel(actor, pack)
end

gmCmdHandlers.gathereffect = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeChar(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sGatherEffect(actor, pack)
end

gmCmdHandlers.gatherclean = function (actor, args)
	local var = getActorVar(actor)
	var[0] = {}
	var[1] = {}
	var[2] = {}
	s2cGatherInfo(actor)
end
