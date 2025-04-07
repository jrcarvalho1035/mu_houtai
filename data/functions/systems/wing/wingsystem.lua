-- @version	1.0
-- @author	qianmeng
-- @date	2016-12-20 18:23:12.
-- @system	wing

module( "wingsystem", package.seeall )


local rankingListName      = "wingstarrank"
local rankingListFile      = "wingstarrank.rank"
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
			worship.updateDynamicFirstCache(Ranking.getId(prank), RankingType_WingStar)
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
	LDataPack.writeShort(npack, RankingType_WingStar)
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
_G.onReqWingStarRanking = onReqRanking
-------------------------------------------rank ------------------------------------

local normalType = 0
local specialType = 1

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.wingdata then var.wingdata = {} end
	if not var.wingdata.powers then var.wingdata.powers = {} end
	return var.wingdata
end

--最大翅膀星级
local function isWingMaxStar(star)
	if (star >= WingCommonConfig[1].starMax) then
		return true
	end
	return false
end

--这星级是否属于要升阶的
local function isEndLevel(star)
	if star == WingCommonConfig[1].starMax then
		return false
	end
	return WingStarConfig[star].exp == 0
end

--升级经验倍数
local function getWingExpTimes(trainType, level)
	local config = WingLevelConfig[level]
	if (not config) then
		return 1
	end

	local timesConfig = {}
	if (trainType == normalType) then
		timesConfig = config.normalRate
	else
		timesConfig = config.specialRate
	end

	local nCurRate = math.random(1,100)
	local nRate = 0
	for _,tb in ipairs(timesConfig) do
		nRate = nRate + tb.rate
		if (nRate >= nCurRate) then
			return tb.times
		end
	end
	return 1
end

--升级经验基数
local function getWingBaseExp(trainType, level)
	local config = WingLevelConfig[level]
	if (config) then
		if (trainType == normalType) then
			return config.normalBaseExp
		else
			return config.specialBaseExp
		end
	end	
	return 0
end

--增加经验接口
function addWingExp(actor, roleId, idx, addExp, times)
	times = times or 1
	addExp = addExp * times
	local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)

	local conf = WingStarConfig[star]
	local exStar = star --旧星级
	exp = exp + addExp
	while exp >= conf.exp do
		if (isWingMaxStar(star)) then break end
		if isEndLevel(star) then --星级需要升阶
			break;
		end
		exp = exp - conf.exp
		star = star + 1
		conf = WingStarConfig[star]
	end

	LActor.setWingExp(actor, roleId, idx, exp) --经验改变
	if (exStar ~= star) then --星级改变
		LActor.setWingStar(actor, roleId, idx, star)
		updateAttr(actor, roleId)
		actorevent.onEvent(actor, aeWingStarUp, roleId , star - exStar, star)
	end
	s2cWingStar(actor, roleId, idx, addExp, times) --升星回包
end

--翅膀升阶接口
function addWingLevel(actor, roleId, idx, level, star)
	LActor.setWingStar(actor, roleId, idx, star)
	LActor.setWingExp(actor, roleId, idx, 0) 
	LActor.setWingLevel(actor, roleId, idx, level)
	-- System.logCounter(LActor.getActorId(actor),
	-- 	LActor.getAccountName(actor),
	-- 	tostring(LActor.getLevel(actor)),
	-- 	"wing level up", 
	-- 	tostring(level),
	-- 	tostring(roleId), 
	-- 	tostring(idx), "", "", "")
	LActor.log(actor, "wingsystem.addWingLevel", "call", level)
	updateAttr(actor, roleId)
	actorevent.onEvent(actor, aeWingLevelUp, roleId, level)
	actorevent.onEvent(actor, aeWingStarUp, roleId , 1, star)
	s2cWingLevel(actor, roleId, idx)--升阶回包
	local extra = string.format("role:%d,level:%d", roleId, level)
	utils.logCounter(actor, "othersystem", "", extra, "wing", "uplevel")
end

--属性更新
function updateAttr(actor, roleId, slot, wingeid)
	--先清空翅膀系统的属性
	LActor.clearWingAttr(actor, roleId)

	addWingAttr(actor, roleId)

	plumesystem.updateAttr(actor, roleId)--注灵有可能加成翅膀属性

	--feathersystem.updatefeatherslevelinfo(actor, roleId, slot, wingeid)
	--feathersystem.updateAttr(actor, roleId)--翎羽有可能加成翅膀属性
	
	--刷新角色属性
	LActor.reCalcRoleAttr(actor, roleId)
end
_G.updateWingAttr = updateAttr

--翅膀属性初始化
function wingAttrInit(actor, roleId)
	--先清空翅膀系统的属性
	LActor.clearWingAttr(actor, roleId)

	addWingAttr(actor, roleId)
end
_G.wingAttrInit = wingAttrInit

function addWingAttr(actor, roleId)
	local attrList = {}
	local power = 0
	for idx=0, 1 do 
		local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
		if level and star and status then
			local starConfig = WingStarConfig[star]
			if (not starConfig) then
				return 
			end
			for _,tb in pairs(starConfig.attr) do
				attrList[tb.type] = attrList[tb.type] or 0
				attrList[tb.type] = attrList[tb.type] + tb.value
			end
		end
		for i=1, #WingSkillConfig do
			if level >= WingSkillConfig[i].stage then
				for k,v in ipairs(WingSkillConfig[i].attr) do
					attrList[v.type] = attrList[v.type] or 0
					attrList[v.type] = attrList[v.type] + v.value
				end
				power = power + WingSkillConfig[i].power
			end
		end		
	end
	--汇总后统一加
	for type,value in pairs(attrList) do
		LActor.addWingAttr(actor, roleId, type, value)
	end
	--翅膀装备属性
	LActor.addWingEquipAttr(actor, roleId)
	LActor.setWingExtraPower(actor, roleId, power)
	local var = getActorVar(actor)
	var.powers[roleId] = utils.getAttrPower0(attrList)
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

function getTotalStarLv(actor)
	local var = getActorVar(actor)
	if not var then return 0 end
	local lv = 0
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		local role = LActor.getRole(actor,roleId)
		local jobId = LActor.getJob(role)
		local idx = getWingIdxByJob(jobId)
		local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
		if star == 0 then level = 1 end
		lv = lv + (star - level + 1)
	end
	return lv
end

local function getRoleIdByJob(actor, jobId)
	if jobId > 3 then
		jobId = jobId - 3
	end
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		local role = LActor.getRole(actor,roleId)
		if jobId == LActor.getJob(role) then
			return roleId
		end
	end
	return -1
end

function getWingIdxByJob(jobId)
	if jobId <= 3 then
		return 0
	else
		return 1
	end
end

local function getWingJobByJob(jobId, idx)
	if jobId <= 3 then
		if idx == 0 then
			return jobId
		else
			return jobId + 3
		end
	else
		if idx == 0 then
			return jobId - 3
		else
			return jobId
		end
	end
end

--所有角色最高的翅膀阶级
function roleWingLevel(actor)
	local lv = 0
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		local level = LActor.getWingInfo(actor, roleId, 0)
		lv = math.max(lv, level)
	end
	return lv
end

-----------------------------------------------------------------------------------------
--翅膀数据
function s2cWingData(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingCmd_Data)
	local count = LActor.getRoleCount(actor)

	LDataPack.writeShort(pack, count)
	for roleId = 0, count-1 do
		LDataPack.writeShort(pack, roleId)
		local role = LActor.getRole(actor,roleId)
		local jobId = LActor.getJob(role)
		LDataPack.writeShort(pack, 2)
		for idx = 0, 1 do
			local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
			local job = getWingJobByJob(jobId, idx)
			LDataPack.writeShort(pack, job)
			LDataPack.writeInt(pack, level)
			LDataPack.writeInt(pack, star)
			LDataPack.writeUInt(pack, exp)
			LDataPack.writeInt(pack, status)
		end
	end
	LDataPack.flush(pack)
end

--翅膀升星回包
function s2cWingStar(actor, roleId, idx, expAdd, times)
	local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingCmd_Star)
	if pack == nil then return end
	local role = LActor.getRole(actor,roleId)
	LDataPack.writeShort(pack, LActor.getJob(role))
	LDataPack.writeInt(pack, star)
	LDataPack.writeUInt(pack, exp)
	LDataPack.writeShort(pack, times)
	LDataPack.writeInt(pack, expAdd)
	LDataPack.writeInt(pack, level)
	LDataPack.flush(pack)
end

--翅膀升星
function c2sWingStar(actor, pack)
	local jobId = LDataPack.readShort(pack)
	local trainType = LDataPack.readShort(pack) --0金钱，1羽毛
	local feedtimes = LDataPack.readShort(pack)
	local roleId = getRoleIdByJob(actor, jobId)
	if not utils.checkRoleId(actor, roleId) then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.wing) then return end
	local idx = getWingIdxByJob(jobId)
	local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
	if level == 0 then --设置翅膀等阶初始1级，兼容过去代码
		LActor.setWingLevel(actor, roleId, idx, 1)
		level = 1
	end
	if (not level) then utils.printInfo("getWingInfo not level", roleId, level) return end
	if (status == 0) then utils.printInfo("wing not active", roleId, status) return end
	local levelConfig = WingLevelConfig[level]
	if (not levelConfig) then return end
	if (not WingStarConfig[star]) then return end
	if (isWingMaxStar(star)) then return end --是不是最大星级了
	if isEndLevel(star) then return end --要进阶

	if trainType == normalType then
		if not actoritem.checkItem(actor, NumericType_Gold, levelConfig.normalCost * feedtimes) then
			return
		end
		actoritem.reduceItem(actor, NumericType_Gold, levelConfig.normalCost * feedtimes, "wing gold train:"..level..':'..star)
	elseif trainType == specialType then
		if not actoritem.checkItem(actor, WingCommonConfig[1].feather, levelConfig.itemNum * feedtimes) then
			return
		end
		actoritem.reduceItem(actor, WingCommonConfig[1].feather, levelConfig.itemNum * feedtimes, "wing special train:"..level..':'..star)
	else
		utils.printInfo("error wing trainType", trainType)
		return
	end
	local baseExp = getWingBaseExp(trainType, level) * feedtimes
	--获取经验的倍数和经验基数，然后加经验
	local times = getWingExpTimes(trainType, level)
	addWingExp(actor, roleId, idx, baseExp, times)
	updateRankingList(actor, getTotalStarLv(actor))
	actorevent.onEvent(actor, aeWingTrain, feedtimes)
end

--翅膀升阶回包
function s2cWingLevel(actor, roleId, idx)
	local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingCmd_Level)
	if pack == nil then return end
	local role = LActor.getRole(actor,roleId)
	LDataPack.writeShort(pack, LActor.getJob(role))
	LDataPack.writeInt(pack, star)
	LDataPack.writeUInt(pack, exp)
	LDataPack.writeInt(pack, level)
	LDataPack.flush(pack)
end

--翅膀升阶
function c2sWingLevel(actor, pack)
	local jobId = LDataPack.readShort(pack)
	local roleId = getRoleIdByJob(actor, jobId)
	if not utils.checkRoleId(actor, roleId) then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.wing) then return end
	local idx = getWingIdxByJob(jobId)
	local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
	if (not level) then return end
	if level >= WingCommonConfig[1].lvMax then return end --最高阶
	if (status == 0) then return end
	if not isEndLevel(star) then return end --不需要升阶
	
	addWingLevel(actor, roleId, idx, level+1, star+1)
	updateRankingList(actor, getTotalStarLv(actor))
	actorevent.onEvent(actor, aeWingTrain, 1)
	noticesystem.broadCastNotice(noticesystem.NTP.wing,LActor.getName(actor), WingLevelConfig[level+1].name[jobId])
end

--翅膀激活
function c2sWingActive(actor, pack)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.wing) then return end

	local jobId = LDataPack.readShort(pack)
	local roleId = getRoleIdByJob(actor, jobId)
	if roleId < 0 then
		return
	end

	local idx = getWingIdxByJob(jobId)
	local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
	if (not level) then
		return
	end	

	--翅膀状态，激活了的就不再激活了
	if (status == 1) then
		return
	end	

	LActor.setWingStatus(actor, roleId, idx, 1)
	LActor.setWingLevel(actor, roleId, idx, 1) --初始一阶
	status = 1
	
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingCmd_Active)
	if pack == nil then return end
	LDataPack.writeShort(pack, jobId)
	LDataPack.writeInt(pack, status)
	LDataPack.flush(pack)

	actorevent.onEvent(actor, aeActiveWing, roleId)
end

function getWingIdByLevel(actor, job, level)
	local config = WingLevelConfig[level]
	if not config then
		return WingLevelConfig[1].wingId[job]
	else
		return config.wingId[job]
	end
end


_G.getWingIdByLevel = getWingIdByLevel

--直升丹客户端回包
-- function s2cWingPill(actor, code, type, roleId, idx, jobId)
-- 	local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingCmd_Pill)
-- 	if not pack then return end
-- 	LDataPack.writeInt(pack, code)
-- 	LDataPack.writeInt(pack, jobId)
-- 	LDataPack.writeInt(pack, type)
-- 	LDataPack.writeInt(pack, star)
-- 	LDataPack.flush(pack)
-- end

--翅膀直升丹
function c2sWingPill(actor, pack)
	local jobId = LDataPack.readInt(pack)
	local roleId = getRoleIdByJob(actor, jobId)
	if roleId < 0 then return end
	local idx = getWingIdxByJob(jobId)
	local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
	if (not level) then return end	
	if (status == 0) then return end
	if (not WingLevelConfig[level]) then return end
	if (not WingStarConfig[star]) then return end
	if (isWingMaxStar(star)) then return end --是不是最大星级了
	if isEndLevel(star) then return end --要进阶时不能用直升丹
	local levelItemid = WingCommonConfig[1].levelItemid
	if not actoritem.checkItem(actor, levelItemid, 1) then
		return false
	end
	actoritem.reduceItem(actor, levelItemid, 1, "wing pill:"..level..':'..star)

	--local tp = 0
	if level <= WingCommonConfig[1].levelItemidStage then --4阶以下可直升1阶
		local nextLv = level+1
		local nextStar = level * WingCommonConfig[1].starPerLevel --新星级为下一阶的起始星级
		LActor.setWingStar(actor, roleId, idx, nextStar) --升星
		LActor.setWingLevel(actor, roleId, idx, nextLv) --升阶
		LActor.setWingExp(actor, roleId, idx, 0) --经验置0
		updateRankingList(actor, getTotalStarLv(actor))
		actorevent.onEvent(actor, aeWingTrain, 1)
		actorevent.onEvent(actor, aeWingStarUp, roleId , WingCommonConfig[1].starPerLevel, nextStar)
		actorevent.onEvent(actor, aeWingLevelUp, roleId, nextLv)
		updateAttr(actor, roleId)
		s2cWingStar(actor, roleId, idx, 0, 0)
	
		-- System.logCounter(LActor.getActorId(actor),
		-- 	LActor.getAccountName(actor),
		-- 	tostring(LActor.getLevel(actor)),
		-- 	"wing level one",
		-- 	tostring(level),
		-- 	"","","", "", "")
		LActor.log(actor, "wingsystem.c2sWingPill", "call", nextLv)
		local extra = string.format("role:%d,level:%d", roleId, nextLv)
		utils.logCounter(actor, "othersystem", "", extra, "wing", "uplevel")
	else --4阶及以上加6000经验
		addWingExp(actor, roleId, idx, WingCommonConfig[1].levelExpChange, 1) --不能升阶
		--tp = 1
	end
	--s2cWingPill(actor, 0, tp, roleId, idx, jobId)
end

--玩家登陆回调
function onLogin(actor)
	s2cWingData(actor) --发送翅膀数据
end

function onCreateRole(actor, roleId)
	s2cWingData(actor) --发送翅膀数据
end


actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeCreateRole,onCreateRole)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingCmd_Star, c2sWingStar)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingCmd_Level, c2sWingLevel)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingCmd_Active, c2sWingActive)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingCmd_Pill, c2sWingPill)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.addwingexp = function (actor, args)
	local roleId = tonumber(args[1])
	local idx = 0
	local exp = tonumber(args[2])
	addWingExp(actor, roleId, idx, exp, 1)
	return true
end

gmCmdHandlers.setWingstar = function (actor, args)
	local star = tonumber(args[1])
	local roleId = tonumber(args[2] or 0)
	local idx = tonumber(args[3] or 0)
	local level = math.floor(star / WingCommonConfig[1].starPerLevel) + 1
	LActor.setWingStar(actor, roleId, idx, star)
	LActor.setWingLevel(actor, roleId, idx, level)
	updateAttr(actor, roleId)
	actorevent.onEvent(actor, aeWingStarUp, roleId , 1, star)
	s2cWingStar(actor, roleId, idx, 0, 1) --升星回包
	return true
end

gmCmdHandlers.wingTest = function (actor, args)
end
