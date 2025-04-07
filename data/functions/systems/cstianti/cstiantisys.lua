module("cstiantisys" , package.seeall)

--跨服天梯系统
local danConf = CsttDanConfig
local gConf = CsttComConfig
local cConf = CsttControlConfig
local BroadSec = 300 --上届第一广播间隔


--跨服天梯def
_G.csTianTi = {
	--匹配状态 satr
	msWaitImage = 1, --等待镜象上线
	msWaitActor = 2, --等待玩家上线
	--匹配状态 end

	logType1 = 1, --连胜
	logType2 = 2, --达到级别，玩家升到此段位都加日志，每个玩家都写的日志
	logType3 = 3, --首个第一

	csStar = 1,			--开始
	csSettlement = 2,	--结算
	csEnd = 3,			--结束

	--公告类型定义 star
	bcType1=1, --xxx[xx服]在跨服天梯联赛中大杀四方达到n连胜，成就霸绝天下！
	bcType2=2, --[xx服]xxx在跨服天梯联赛中达到XXXXXX，问鼎巅峰独孤求败！
	bcType3=3, --xxx[xx服]在跨服天梯联赛中首个达XXXX，全服排名第1，试问谁能超越！
	bcType4=4, --xxx[xx服]在跨服天梯联赛击败强敌夺下全服第1，试问谁能超越！
	bcType5=5, --天梯联赛巅峰王者xxx[xx服]上线了，全民顶礼膜拜!

	rankingListMaxSize = 1000,
	totalRankingBroadSize = 100,
	dailyRankingBroadSize = 100,
	winpointRankColumns = {"serverId", "name", "power"},		--赛季总排行榜列
	winpointRankName = "cstianti_winpointrank%d_%d",			--赛季总排行榜名字
	winpointRankFile = "cstianti_winpointrank%d_%d.rank",		--赛季总排行榜文件
	dailyWinpointRankName = "cstianti_dailyrank_%d",	--每日胜点排行榜名字
	dailyWinpointRankFile = "cstianti_dailyrank_%d.rank",--每日胜点排行榜文件

	srName = "csttScore",		--积分排行榜名字
	srFile = "csttScore.rank",	--积分排行榜文件
	srMaxSize = 20000,
	srColumns = {"dan"},		--赛季总排行榜列
}


function getSysStaticVar()
	local var = System.getStaticVar()
	if var.csTianTi == nil then
		var.csTianTi = {}
		var.csTianTi.stage = 0
		var.csTianTi.isCSOpen = 0
		
		var.csTianTi.session = 0 --届

		--段位列表
		var.csTianTi.danData = {} --段位匹配表
		var.csTianTi.serverActors = {} --记录每个连接上的服每个玩家的段位
		var.csTianTi.danCountTbl = {} --记录段位匹配表有多少条某玩家记录

		var.csTianTi.annoData = {} --记录首个达到段位值的玩家
		var.csTianTi.newAnnoData = {} --记录段位达标的玩家
		var.csTianTi.log = {}
		var.csTianTi.logNum = 0

		var.csTianTi.broadSec = 0
	end
	return var.csTianTi
end

--重置数据
function resetSysData()
	local sysVar = getSysStaticVar()
	local oldSession = sysVar.session
	local csOpen = sysVar.isCSOpen
	sysVar = System.getStaticVar()
	sysVar.csTianTi = nil

	sysVar = getSysStaticVar()
	sysVar.session = oldSession
	sysVar.isCSOpen = csOpen
end

function getVar(actor)
	local var = LActor.getCrossVar(actor)
	if var.tianti == nil then
		var.tianti = {}
		var.tianti.score = 0 --积分
		var.tianti.dan = 1 --段位
		var.tianti.session = 0
		var.tianti.log = {}
		var.tianti.logNum = 0
	end
	return var.tianti
end

function resetActorData(actor)
	local var = LActor.getCrossVar(actor)
	var.tianti = nil
end

function gertDVar(actor)
	local var = LActor.getDynamicVar(actor)
	if var.tianti == nil then
		var.tianti = {}
		var.tianti.mInfo = {}
		var.tianti.mInfo.tId = 0
		var.tianti.mInfo.hfb = 0
		var.tianti.mInfo.state = 0

		var.tianti.starPk = 0
	end
	return var.tianti
end

function getTarget(actor)
	local dVar = gertDVar(actor)
	return dVar.mInfo
end

--通过积分获得段位
function getDanByScore(score)
	if score >= danConf[#danConf].scoreRange then
		return danConf[#danConf].id
	end
	for k,v in ipairs(danConf) do
		if score < v.scoreRange then
			return k
		end
	end
	return 0
end

function checkBroadcast(conf, dan)
	for i=1, #conf do
		if conf[i] == dan then
			return true
		end
	end
	return false
end

--积分改变
function changeScore(actor, score)
	if not System.isBattleSrv() then return end
	local var = getVar(actor)
	var.score = var.score + score
	var.score = (var.score < 0) and 0 or var.score
	local oldDan = var.dan
	var.dan = getDanByScore(var.score)
	--改变分
	local aId = LActor.getActorId(actor)

	cstiantirankmgr.actorChangeScore(aId, var.score, var.dan)

	--段位变更
	if oldDan ~= var.dan then 
		cstiantisegment.delActorToDanList(aId, oldDan)
		local aName = LActor.getName(actor)
		local sId = LActor.getServerId(actor)
		local job = LActor.getJob(actor)
		local lvl = LActor.getLevel(actor)
		cstiantisegment.addActorToDanList(aId, aName, sId, var.dan, job, lvl)

		local conf = danConf[var.dan] or {}
		local danRange = conf.danRange or 0
		if var.dan > oldDan then
			local segmentVar = getSysStaticVar()
			--首个到达某段位值
			if not segmentVar.annoData[danRange] and gConf.fnDan[danRange] then 
				segmentVar.annoData[danRange] = {aId, aName, sId}
				cstiantisegment.sendCsttNotice(csTianTi.bcType3, sId, aName, var.dan)
				local logData = {sId=sId,name=aName,dan=var.dan}
				cstiantilog.addSysLog(csTianTi.logType3, logData) --首个第一日志
			end

			--段位值升到nnDan的，都要广播
			if not segmentVar.newAnnoData[aId] or type(segmentVar.newAnnoData[aId]) == "number" then				
				segmentVar.newAnnoData[aId] = {}
			end
			if not segmentVar.newAnnoData[aId][danRange] and checkBroadcast(gConf.nnDan, danRange) then
				segmentVar.newAnnoData[aId][danRange] = 1
				cstiantisegment.sendCsttNotice(csTianTi.bcType2, sId, aName, var.dan)
				local logData = {sId=sId, name=aName, dan=var.dan}
				cstiantilog.addSysLog(csTianTi.logType2, logData) --段位达标日志
			end
		end
		cstiantilog.logActorDanChange(actor, oldDan, var.dan) --段位变更日志
	end
end

--第一名登录时会有跨服级公告
function firstLoginBroadcast(actor)
	local sysVar = getSysStaticVar()
	local item = cstiantirankmgr.getPreRankFirstItem()
	if item then
		local now_sec = System.getNowTime()
		local id = Ranking.getId(item)
		local aId = LActor.getActorId(actor)
		if id == aId and now_sec >= sysVar.broadSec then --公告CD时间
			sysVar.broadSec = now_sec + BroadSec
			cstiantisegment.s2aCsttFirstLogin(actor)
		end
	end
end

--清除自己的数据
function resetMatchInfo(actor)
	if not System.isCommSrv() then return end
	local mInfo = getTarget(actor)
	if not mInfo or mInfo.state <= 0 then return end
	mInfo.tId = 0
	mInfo.hfb = 0
	mInfo.state = 0

	local dVar = gertDVar(actor)
	dVar.starPk = 0
	s2aDelMatch(actor)
end

---------------------------------------------------------------------------------------------
--普通服向跨服请求把自己从段位匹配表删除
function s2aDelMatch(actor)
	if not System.isCommSrv() then return end
	local dVar = gertDVar(actor)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_DelMatch)
	LDataPack.writeInt(pack, LActor.getActorId(actor))
	LDataPack.writeInt(pack, dVar.starPk) --给跨服区分是普通下线引起的还是跳转跨服引起的
	System.sendPacketToAllGameClient(pack, csbase.getCrossServerId())
end

--普通服向跨服发送自己的一般信息
function s2aSyncActorInfo(actor)
	--if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.cstt) then return end

	local aData = LActor.getActorData(actor)
	if not aData then return end
	local var = getVar(actor)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_SyncActor)
	LDataPack.writeInt(pack, LActor.getActorId(actor))
	LDataPack.writeString(pack, LActor.getName(actor) or "")
	LDataPack.writeInt(pack, var.dan)
	LDataPack.writeInt(pack, var.score)

	LDataPack.writeChar(pack, aData.job)
	LDataPack.writeInt(pack, aData.level)
	LDataPack.writeInt(pack, System.getServerId())
	System.sendPacketToAllGameClient(pack, csbase.getCrossServerId())
end

---------------------------------------------------------------------------------------------
--跨服天梯活动信息
function s2cCsTianTiInfo(actor)
	if not System.isCommSrv() then return end
	local var = getVar(actor)
	local sysVar = getSysStaticVar()
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsTianti_Info)
	if npack == nil then return end
	LDataPack.writeByte(npack, sysVar.isCSOpen)
	LDataPack.writeInt(npack, sysVar.stage)
	LDataPack.writeInt(npack, var.dan)
	LDataPack.writeInt(npack, sysVar.session)
	LDataPack.flush(npack)
end

--请求匹配对手
function c2sReqMatch(actor, packet)
	if not System.isCommSrv() then return end
	local mInfo = getTarget(actor)
	--mInfo.tId = 0
	if not cstiantifb.canChallenge(actor) then 
		cstiantisegment.s2cReqMatch(actor, 0, "", 0, 0, 0, 0)
		return 
	end

	local sysVar = cstiantisys.getSysStaticVar()
	local conf = cConf[sysVar.stage]
	if not conf or conf.type ~= csTianTi.csStar then
		cstiantisegment.s2cReqMatch(actor, 0, "", 0, 0, 0, 0)
		return
	end

	local tId = csbase.getCrossServerId()
	if not System.hasGameClient(tId) then -- 如果连接不了跨服服务器通知前端提示
		cstiantisegment.s2cReqMatch(actor, 0, "", 0, 0, 0, 0)
		return
	end

	if not mInfo or mInfo.state > 0 then 
		cstiantisegment.s2cReqMatch(actor, 0, "", 0, 0, 0, 0)
		return
	end
	mInfo.state = 1 --设置在匹配中

	local var = getVar(actor)
	cstiantisegment.s2aReqMatch(actor, tId, var.dan)
end

--请求开始PK
function c2sReqStarPK(actor, packet)
	if not System.isCommSrv() then print("#### 1") return end

	local mInfo = getTarget(actor)
	if not mInfo or mInfo.tId == 0 then print("#### 2", mInfo.tId) return end

	if cstiantifb.enterFb(actor, mInfo.hfb) then
		local dVar = gertDVar(actor)
		dVar.starPk = 1
	end
	s2aSyncActorInfo(actor) --把自己的信息发进跨服段位匹配表
end
-----------------------------------------------------------------------------------------------------------

function onLogout(actor)
	if not System.isCommSrv() then return end
	local mInfo = getTarget(actor)
	if not mInfo or mInfo.state <= 0 then return end
	resetMatchInfo(actor)
end

function onLogin(actor)
	if not System.isCommSrv() then return end
	local var = getVar(actor)
	local sysVar = getSysStaticVar()
	if sysVar.session ~= var.session then
		resetActorData(actor)
		var = getVar(actor)
		var.session = sysVar.session
	end
	firstLoginBroadcast(actor)
	s2cCsTianTiInfo(actor)
	if cstianticontrol.checkIsDailyOpenTime() then
		cstianticontrol.s2cCsttActorStatus(actor, 1)
	else
		cstianticontrol.s2cCsttActorStatus(actor, 0)
	end
end

actorevent.reg(aeUserLogout, onLogout)
actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsTianti_Matching, c2sReqMatch)
netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsTianti_Fight, c2sReqStarPK)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.csttmatch = function (actor, args)
	c2sReqMatch(actor)
	return true
end

gmCmdHandlers.csttpk = function (actor, args)
	c2sReqStarPK(actor)
	return true
end

gmCmdHandlers.csttaddscore = function (actor, args)
	local score = tonumber(args[1])
	changeScore(actor, score)
	return true
end

gmCmdHandlers.csttscore = function (actor, args)
	local var = getVar(actor)
	print(var.score)
	return true
end

gmCmdHandlers.csttaddwinpoint = function (actor, args)
	local cvar = cstiantifb.getActorCrossVar(actor)
	local addWinPoint = tonumber(args[1])
	cvar.dailyWinPoint = cvar.dailyWinPoint + addWinPoint
	cvar.winPoint = cvar.winPoint + addWinPoint
	cstiantitask.csTianTiTaskUpdate(actor, cstiantitask.gwinPoint, addWinPoint)
	cstiantirankmgr.updateWinpointRank(actor)
	cstiantirankmgr.updateDailyRank(actor, cvar.dailyWinPoint)
	return true
end

gmCmdHandlers.csttnotice = function (actor, args)
	local sId = LActor.getServerId(actor)
	local aName = LActor.getName(actor)
	local var = getVar(actor)
	print(sId)
	cstiantisegment.sendCsttNotice(tonumber(args[1]), sId, aName, var.dan)
end
