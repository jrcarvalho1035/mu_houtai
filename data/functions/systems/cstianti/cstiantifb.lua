--跨服天梯副本逻辑
module("cstiantifb" , package.seeall)

local P = Protocol
local RankMgr = nil
local CSShop = nil
local cmd = CrossSrvCmd
local subCmd = CrossSrvSubCmd

local g_matchRivals = g_matchRivals or {} --玩家id为下标，对应匹配到的对手

function initCSTianTiVar(cvar)
	cvar.cstianti = {}
	local data = cvar.cstianti
	data.dailyWinPoint = 0					--每日胜点
	data.winning_streak = 0					--连胜次数
	data.preDan = 1							--上一级段位
	data.winPoint = 0						--赛季胜点
end

function initActorVar(data)
	data.buyCount = 0						--购买的次数
	data.fightNum = 0						--挑战次数
end

function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var.cstianti then
		var.cstianti = {}
		initActorVar(var.cstianti)
		var.cstianti.preWinPoint = 0		--上一届胜点
		var.cstianti.nowSeason = 0			--当前届
		var.cstianti.calcSeason = 0			--结算届
		var.cstianti.record1 = 0			--是否已经领取排名奖励
		var.cstianti.record2 = 0			--是否已经领取达标奖励
	end
	return var.cstianti
end

function getActorCrossVar(actor)
	local cvar = LActor.getCrossVar(actor)
	if not cvar.cstianti then
		initCSTianTiVar(cvar)
	end
	return cvar.cstianti
end

function getSystemVar()
	local var
	if not System.isCommSrv() then
		var = System.getStaticVar()
	else
		var = System.getDyanmicVar()
	end

	if not var.cstianti then
		var.cstianti = {}
		local data = var.cstianti
		data.topThreeCache = {} --排行榜前三数据缓存
		data.preSeason = 0 --上一届届数
		data.isSyncData = 0 --是否已收到赛季信息
	end
	return var.cstianti
end

function getSystemDVar()
	local var = System.getDyanmicVar()
	if not var.csttDvar then
		var.csttDvar = {}
		var.csttDvar.tRankSec = 0			--总榜同步时间
		var.csttDvar.tDailyRankSec = 0		--每日排行榜同步时间
	end
	return var.csttDvar
end

function setRivalId(actorId, rivalId)
	g_matchRivals[actorId] = rivalId
end

function getRivalId(actorId)
	return g_matchRivals[actorId]
end

function canChallenge(actor)
	if not cstianticontrol.checkCommSrvSysIsOpen() then return false end --开服日期
	if not cstianticontrol.checkIsDailyOpenTime() then return false end --是否在今天的10~22点内
	local var = getActorVar(actor)
	if var.fightNum > var.buyCount + CsttComConfig.freeNum then
		return false
	end
	return true
end

--改变挑战次数
function changeChallengeNum(actor)
	local var = getActorVar(actor)
	var.fightNum = var.fightNum + 1
	s2cCSTianTiInfo(actor)
end

--创建副本实例
function createBattlefield()
	local fbId = CsttComConfig.fuBenIds[1]
	local hfuben = instancesystem.createFuBen(fbId)
	if hfuben == 0 then return end
	local ins = instancesystem.getInsByHdl(hfuben)
	return ins
end

local function challengeResult(actor, isWin)
	local var = cstiantisys.getVar(actor)
	local cvar = getActorCrossVar(actor)

	local conf = CsttDanConfig[var.dan]

	local dropId
	local addWinPoint = 0
	local addScore = 0
	local extraScore = 0
	local extraHonour = 0

	if isWin then
		dropId = conf.winAward
		addWinPoint = conf.vicWinpoint
		cvar.winning_streak = cvar.winning_streak + 1
		addScore = conf.sVictory
		cstiantitask.csTianTiTaskUpdate(actor, cstiantitask.lianshengCount, 1)
	else
		dropId = conf.loseAward
		addWinPoint = conf.loseWinpoint
		cvar.winning_streak = 0
		addScore = -conf.sLose
	end

	if cvar.winning_streak >= CsttComConfig.straight then --连胜数超过3，有额外积分荣耀奖励
		extraHonour = conf.extraHonour
		extraScore = conf.extraScore
	end

	local awards = drop.dropGroup(dropId)

	local log = ""
	if isWin then
		log = "cstiantifb_win"
	else
		log = "cstiantifb_lose"
	end

	cvar.preDan = var.dan
	cstiantisys.changeScore(actor, addScore + extraScore)
	cvar.dailyWinPoint = cvar.dailyWinPoint + addWinPoint
	cvar.winPoint = cvar.winPoint + addWinPoint
	cstiantitask.csTianTiTaskUpdate(actor, cstiantitask.gwinPoint, addWinPoint)
	actoritem.addItems(actor, awards, log)
	if extraHonour > 0 then
		actoritem.addItem(actor, NumericType_CSTTHonour, extraHonour, log)
	end

	s2cChallengeResult(actor, isWin, var.dan, addScore, awards, extraHonour, extraScore, addWinPoint)

	RankMgr.updateWinpointRank(actor)
	RankMgr.updateDailyRank(actor, cvar.dailyWinPoint)

	if cvar.winning_streak > 0 and cvar.winning_streak % 10 == 0 then
		local logData = {sId=0,name=0,wins=0}
		logData.sId = LActor.getServerId(actor)
		logData.name = LActor.getName(actor)
		logData.wins = cvar.winning_streak
		cstiantilog.addSysLog(csTianTi.logType1, logData)
		cstiantisegment.sendCsttNotice(csTianTi.bcType1, logData.sId, logData.name, logData.wins)
	end
	s2cCSTianTiInfo(actor)
end

local function onFbResult(ins, isWin, actor)
	if not System.isBattleSrv() then return end
	if not actor then
		actor = ins:getActorList()[1]
	end
	if not actor then return end
	challengeResult(actor, isWin)
end

function enterFb(actor, hdl)
	LActor.loginOtherServer(actor, csbase.getCrossServerId(), hdl, 0, 0, 0, "csttfight")
	return true
end

--赛季开始重置数据
function updateActorVar(actor, season, needSync)
	if not actor then return end
	local var = getActorVar(actor)
	if var.nowSeason == season then return end
	var.nowSeason = season
	local cvar = LActor.getCrossVar(actor)
	initActorVar(var)
	initCSTianTiVar(cvar)
	local data = compatmoney.getCSTTVar(actor)
	data.winPoint = 0
	if needSync then
		s2cCSTianTiInfo(actor)
	end
	local isLogin = true
	if needSync then isLogin = false end
	cstiantitask.newday(actor, isLogin, season ~= 1)
end

--开始天梯
function beginTianTi()
	local svar = getSystemVar()
	svar.topThreeCache = {}
	a2sActorVar()
end

--结算天梯
function calcTianTi()
	if not System.isBattleSrv() then return end

	local sysVar = cstiantisys.getSysStaticVar()
	local svar = getSystemVar()
	svar.preSeason = sysVar.session
	RankMgr.saveRankingList()
end

function setCloneData(roleCloneDatas, damonData, roleSuperData)
	if not roleCloneDatas then return end
	for i = 1, #roleCloneDatas do
		local roleCloneData = roleCloneDatas[i]
		roleCloneData.ai = FubenConstConfig.jobAi[roleCloneData.job]
	end
	if damonData then
		damonData.ai = FubenConstConfig.damonAi
		local damonConf = DamonConfig[damonData.id]
		if damonConf then
			damonData.speed = damonConf.MvSpeed
		end
	end
	if roleSuperData then 
		roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1] + 5,FubenConstConfig.randChangeTime[2] + 5)
		roleSuperData.aiId = FubenConstConfig.roleSuperAi
	end
end

function fubenCreateClone(rivalId, ins, roleCloneDatas, damonData, roleSuperData)
	local tarPos = CsttComConfig.tarPos
	local actorid = rivalId
	local sceneHandle = ins.scene_list[1]
	local x = tarPos[1][1]
	local y = tarPos[1][2]

	local actorClone = LActor.createActorCloneWithData(actorid, sceneHandle, x, y, roleCloneDatas, damonData, roleSuperData) 

	local roleCloneCount = LActor.getRoleCount(actorClone)
	if roleCloneCount <= 0 then return end
	local mainRolePos = nil
	for i = 0, roleCloneCount - 1 do
		local roleClone = LActor.getRole(actorClone,i)
		if roleClone then
			local pos = tarPos[roleCloneDatas[i+1].job]
			LActor.setEntityScenePos(roleClone, pos[1], pos[2])
			if mainRolePos == nil then
				mainRolePos = pos
			end
		end
	end

	ins.data.actorClone = actorClone

	--额外效果
	-- local extraEffectId = CsttComConfig.extraEffectIds[3] --默认打到跨服天梯的已有三个角色
	-- LActor.addSkillEffect(actorClone, extraEffectId) --加成buf
	-- LActor.addSkillEffect(actorClone, CsttComConfig.bindEffectId) --定身
end


local function onLogin(actor)
	if not System.isCommSrv() then return end
	s2cCSTianTiInfo(actor)
end

function onNewDay(actor)
	if not System.isCommSrv() then return end
	if not cstianticontrol.checkCommSrvSysIsOpen() then return false end

	local cvar = getActorCrossVar(actor)
	cvar.dailyWinPoint = 0

	local var = getActorVar(actor)
	var.buyCount = 0
	var.fightNum = 0

	s2cCSTianTiInfo(actor)
end

function onInit(actor)
	if not System.isCommSrv() then return end
	RankMgr.resetActorData(actor)
	local dvar = getSystemVar()
	local isSyncData = dvar.isSyncData
	local preSeason = dvar.preSeason
	local var = getActorVar(actor)
	if (var.gmCalc or 0) == 1 then
		if isSyncData == 1 and var.calcSeason ~= preSeason then
			var.calcSeason = preSeason
		end
		var.gmCalc = 0
	else
		if isSyncData == 1 and var.calcSeason ~= preSeason then --新的结处届下发奖励标识
			RankMgr.s2cActorRecord(actor, preSeason)
		end
	end

	local sysVar = cstiantisys.getSysStaticVar()
	local season = sysVar.session
	if (var.gmSeason or 0) == 1 then
		if isSyncData == 1 and var.nowSeason ~= season then
			var.nowSeason = season
		end
		var.gmSeason = 0
	else
		if isSyncData == 1 and var.nowSeason ~= season then --新的一届进行更新
			updateActorVar(actor, season)
			CSShop.clearActorVar(actor)
		end
	end
end
----------------------------------------------------------------------------------
--跨服向普通服发送赛季重新开始
function a2sActorVar()
	local sysVar = cstiantisys.getSysStaticVar()
	local pack = LDataPack.allocPacket()
	if not pack then return end

	LDataPack.writeByte(pack, cmd.SCTianTiCmd)
	LDataPack.writeByte(pack, subCmd.SCTianTiCmd_UpdateActorVar)
	LDataPack.writeInt(pack, sysVar.session)
	System.sendPacketToAllGameClient(pack, 0)
end

--普通服收到跨服发的赛季重新开始
function a4sUpdateActorVar(sid, sType, dp)
	local season = LDataPack.readInt(dp)
	local actors = System.getOnlineActorList()
	if actors ~= nil then
		for i = 1, #actors do
			local actor = actors[i]
			updateActorVar(actor, season, true)
			CSShop.clearActorVar(actor, true)
		end
	end
end
-------------------------------------------------------------------------------------
--跨服天梯个人数据
function s2cCSTianTiInfo(actor)
	local cvar = getActorCrossVar(actor)
	local sysVar = cstiantisys.getVar(actor)
	local var = getActorVar(actor)
	local winPoint = cvar.winPoint
	local pack = LDataPack.allocPacket(actor, P.CMD_Cross, P.sCsTianti_ActorInfo)
	if not pack then return end

	LDataPack.writeInt(pack, sysVar.dan)
	LDataPack.writeInt(pack, sysVar.score)
	LDataPack.writeInt(pack, winPoint)
	LDataPack.writeByte(pack, var.fightNum)
	LDataPack.writeByte(pack, var.buyCount)
	LDataPack.writeInt(pack, cvar.winning_streak) --连胜次数
	LDataPack.writeByte(pack, var.record1)
	LDataPack.writeByte(pack, var.record2)
	LDataPack.flush(pack)
	-- utils.printInfo("#### ccst info", sysVar.dan, sysVar.score, winPoint, var.record1, var.record2)
end

--购买挑战次数
function c2sBuyChallenge(actor)
	if not System.isCommSrv() then return end
	local var = getActorVar(actor)
	local buyCount = var.buyCount
	local needRmb = CsttComConfig.buyPrice[buyCount + 1]
	if not needRmb then return end

	if var.buyCount > CsttComConfig.totalNum then
		return
	end
	if not actoritem.checkItem(actor, NumericType_YuanBao, needRmb) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, needRmb, "cstiantifb_buyChallenge")
	var.buyCount = var.buyCount + 1

	local pack = LDataPack.allocPacket(actor, P.CMD_Cross, P.sCsTianti_BuyCount)
	if not pack then return end
	LDataPack.writeChar(pack, var.buyCount)
	LDataPack.flush(pack)
end

--挑战结果
function s2cChallengeResult(actor, isWin, dan, addScore, awards, extraHonour, extraScore, winPoint)
	local pack = LDataPack.allocPacket(actor, P.CMD_Cross, P.sCsTianti_Result)
	if not pack then return end

	LDataPack.writeByte(pack, isWin and 1 or 0)
	LDataPack.writeInt(pack, dan)
	LDataPack.writeInt(pack, math.abs(addScore)) --客户端要求发绝对值
	LDataPack.writeWord(pack, #awards)
	for _, t in ipairs(awards) do
		LDataPack.writeInt(pack, t.type)
		LDataPack.writeInt(pack, t.id)
		LDataPack.writeInt(pack, t.count)
	end
	LDataPack.writeInt(pack, extraHonour)
	LDataPack.writeInt(pack, extraScore)
	LDataPack.writeShort(pack, winPoint)
	LDataPack.flush(pack)
end

local function onFbWin(ins)
	onFbResult(ins, true)
end

local function onFbLose(ins)
	onFbResult(ins, false)
end

local function onActorDie(ins)
	ins:lose()
end

--在跨服离开副本不触发离开事件，只触发离线事件
local function onExit(ins, actor)
	if not ins.is_end then
		ins:lose()
	end
end

--在跨服离开副本不触发离开事件，只触发离线事件
local function onOffline(ins, actor)
	onExit(ins, actor)
end

local function onEnter(ins, actor)
	cstiantitask.csTianTiTaskUpdate(actor, cstiantitask.pipeiCount, 1)

	--设置角色位置
	local myPos = CsttComConfig.myPos
	local mainRolePos = nil
	local roleCount = LActor.getRoleCount(actor)
	for i = 0, roleCount - 1 do
		local role = LActor.getRole(actor, i)
		local pos = myPos[LActor.getJob(role)]
		LActor.setEntityScenePos(role, pos[1], pos[2])
		if mainRolePos == nil then
			mainRolePos = pos
		end
	end
	local damon = LActor.getDamon(actor)
	if damon then
		LActor.setEntityScenePos(damon, mainRolePos[1], mainRolePos[2])
	end
	LActor.ClearCD(actor)

	if not ins.data.actorClone then
		local roleCloneDatas, damonData, roleSuperData = actorcommon.createRobotClone(CSTianTiRobotConfig, 1)
		setCloneData(roleCloneDatas, damonData, roleSuperData)
		fubenCreateClone(1, ins, roleCloneDatas, damonData, roleSuperData)
	end

	-- local rivalId = getRivalId(LActor.getActorId(actor))
	-- fightActorClone(actor, ins, rivalId)
	local extraEffectId = CsttComConfig.extraEffectIds[3] --默认打到跨服天梯的已有三个角色
	LActor.addSkillEffect(actor, extraEffectId) --加成buf
	LActor.addSkillEffect(ins.data.actorClone, extraEffectId) --加成buf
	
	LActor.addSkillEffect(actor, CsttComConfig.bindEffectId) --定身
	LActor.addSkillEffect(ins.data.actorClone, CsttComConfig.bindEffectId) --定身
	instancesystem.s2cFightCountDown(actor, 5)
end

local function onActorCloneDie(ins)
	ins:win()
end

function fuBenInit()
	RankMgr = cstiantirankmgr
	CSShop = cstiantishop
	for _, fbId in ipairs(CsttComConfig.fuBenIds) do
		insevent.registerInstanceWin(fbId, onFbWin)
		insevent.registerInstanceLose(fbId, onFbLose)
		insevent.registerInstanceEnter(fbId, onEnter)
		insevent.registerInstanceExit(fbId, onExit)
		insevent.registerInstanceOffline(fbId, onOffline)
		insevent.registerInstanceActorDie(fbId, onActorDie)
		insevent.regActorCloneDie(fbId, onActorCloneDie)
	end
end

table.insert(InitFnTable, fuBenInit)

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)

csmsgdispatcher.Reg(cmd.SCTianTiCmd, subCmd.SCTianTiCmd_UpdateActorVar, a4sUpdateActorVar)

netmsgdispatcher.reg(P.CMD_Cross, P.cCsTianti_BuyCount, c2sBuyChallenge)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.csttbuy = function (actor, args)
	c2sBuyChallenge(actor)
	return true
end

gmCmdHandlers.csttres = function(actor, args)
	local result = tonumber(args[1]) == 1 and true or false
	challengeResult(actor, result)
	return true
end
