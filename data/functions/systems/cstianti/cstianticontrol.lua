--跨服天梯时间控制器
module("cstianticontrol" , package.seeall)



local cConf = CsttControlConfig
local gConf = CsttComConfig

local stateLogic = {}

function checkCommSrvSysIsOpen()
	local sysVar = cstiantisys.getSysStaticVar()
	if sysVar.isCSOpen == 1 then		
		if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.cstt) then
			return true
		end
	end
	return false
end

function checkIsDailyOpenTime()
	local now = System.getNowTime()
	local year, month, day, _, _, _ = System.timeDecode(now)
	local dt = gConf.dsTime
	local sTime = System.timeEncode(year, month, day, dt[1], dt[2], dt[3])
	dt = gConf.deTime
	local eTime = System.timeEncode(year, month, day, dt[1], dt[2], dt[3])
	if now >= sTime and now < eTime then
		return true
	end
	return false
end

function gmSetSysState(state)
	if not System.isBattleSrv() then return end
	local sysVar = cstiantisys.getSysStaticVar()
	local oldState = sysVar.isCSOpen
	sysVar.isCSOpen = state
	if oldState ~= sysVar.isCSOpen and sysVar.isCSOpen == 1 then
		gameStar()
	end
end

--错过了开启时间强制开启跨服天梯，并且只能够开启第一届
function gmForceOpenTianTi()
	if not System.isBattleSrv() then return end
	local sysVar = cstiantisys.getSysStaticVar()
	if sysVar.isCSOpen ~= 0 or sysVar.stage ~= 0 then return end
	gameForceStar()
end

function gameForceStar()
	local idx = 0
	local now_t = System.getNowTime()

	for i=(#cConf), 1, -1 do
		local t = cConf[i].time
		local t = System.timeEncode(t[1], t[2], t[3], t[4], t[5], 0)
		if now_t >= t then
			idx = i
			break
		end
	end

	if idx == 0 then return end
	
	local sysVar = cstiantisys.getSysStaticVar()
	sysVar.isCSOpen = 1
	updateStage(idx)
end
-------------------------------------------------------------------------

function updateStage(idx)
	utils.printInfo("#### updateStage", idx)
	local conf = cConf[idx]
	if stateLogic[conf.type] and stateLogic[conf.type](idx) then
		local sysVar = cstiantisys.getSysStaticVar()
		sysVar.stage = idx
		a2sSysStateInfo(0)
	end
end

--开始
stateLogic[csTianTi.csStar] = function(idx)
	cstiantirankmgr.clearScoreRank()
	local sysVar = cstiantisys.getSysStaticVar()
	sysVar.session = sysVar.session + 1
	cstiantisegment.clearDanList()
	cstiantisys.resetSysData()
	cstiantifb.beginTianTi()
	return true
end

--结算
stateLogic[csTianTi.csSettlement] = function(idx)
	cstiantifb.calcTianTi()
	return true
end

--结束
stateLogic[csTianTi.csEnd] = function(idx)
	return true
end

--跨服变更天梯阶段，id为时间控制表的下标
_G.csTianTiContralCB = function(t, id)
	local sysVar = cstiantisys.getSysStaticVar()
	if sysVar.isCSOpen ~= 1 then return end
	updateStage(id)
end

--10点开启跨服天梯
_G.OpenCSTiantiCB = function (t)
	local sysVar = cstiantisys.getSysStaticVar()
	if sysVar.isCSOpen ~= 1 then return end
	s2cCSTiantiStatus(1)
end

--22点关闭跨服天梯
_G.CloseCSTiantiCB = function (t)
	local sysVar = cstiantisys.getSysStaticVar()
	if sysVar.isCSOpen ~= 1 then return end
	s2cCSTiantiStatus(0)
end

function init()
	local supertimer = base.scripttimer.supertimer
	if System.isBattleSrv() then --跨服
		for k,v in ipairs(cConf) do
			local t = v.time
			local tbl = {year=t[1], month=t[2], day=t[3], hour=t[4], minute=t[5], func="csTianTiContralCB", params={k}}
			supertimer.reg(tbl)
		end
	else --普通服
		local dt = gConf.dsTime
		supertimer.reg({hour=dt[1],minute=dt[2],func= "OpenCSTiantiCB"})
		dt = gConf.deTime
		supertimer.reg({hour=dt[1],minute=dt[2],func= "CloseCSTiantiCB"})
	end
end

function gameStar()
	if not System.isBattleSrv() then return end

	--根据现在时间找出现在进行到的阶段
	local sysVar = cstiantisys.getSysStaticVar()
	if sysVar.isCSOpen == 1 then
		local idx = 0
		local now_t = System.getNowTime()

		for i=(#cConf), 1, -1 do
			local t = cConf[i].time
			local t = System.timeEncode(t[1], t[2], t[3], t[4], t[5], 0)
			if now_t >= t then
				idx = i
				break
			end
		end
		local sysVar = cstiantisys.getSysStaticVar()
		if sysVar.stage ~= idx and sysVar.stage ~= 0 then
			for i=sysVar.stage, idx do --依次变更阶段
				updateStage(i)
			end
		end
	end
	a2sSysStateInfo(0)
end

function OnConnToCrossServer(serverId, serverType)
	if not System.isBattleSrv() then return end
	a2sSysStateInfo(serverId)
end

---------------------------------------------------------------------------
--跨服发送同步系统控制信息
function a2sSysStateInfo(sId)
	local sysVar = cstiantisys.getSysStaticVar()
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_SyncControlInfo)

	LDataPack.writeInt(pack, sysVar.isCSOpen)
	LDataPack.writeInt(pack, sysVar.stage) --跨服天梯阶段, CsttControlConfig的索引
	LDataPack.writeInt(pack, sysVar.session)
	System.sendPacketToAllGameClient(pack, sId)

	cstiantirankmgr.sendWinpointRank(sId)
	cstiantirankmgr.sendDailyWinpointRank(sId)
	cstiantirankmgr.a2sTopThreeData(sId)
	cstiantirankmgr.a2sSeasonData(sId)
end

--普通服收到系统控制信息
function a4sSyncControlInfo(sId, sType, dp)
	if not System.isCommSrv() then return end

	local sysVar = cstiantisys.getSysStaticVar()
	local isCSOpen = LDataPack.readInt(dp)
	local newStage = LDataPack.readInt(dp)
	local newSession = LDataPack.readInt(dp)
	if sysVar.session ~= newSession then
		cstiantisys.resetSysData()
	end
	sysVar = cstiantisys.getSysStaticVar()
	sysVar.isCSOpen = isCSOpen
	sysVar.stage = newStage
	sysVar.session = newSession
end
----------------------------------------------------------------------------------------
--下发天梯是否开启
function s2cCSTiantiStatus(isOpen)
	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_Cross)
	LDataPack.writeByte(npack, Protocol.sCsTianti_Onoff)
	LDataPack.writeByte(npack, isOpen)
	System.broadcastData(npack) --向所有人广播信息
end

function s2cCsttActorStatus(actor, isOpen)
	if not System.isCommSrv() then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsTianti_Onoff)
	if npack == nil then return end
	LDataPack.writeByte(npack, isOpen)
	LDataPack.flush(npack)
end

csbase.RegConnected(OnConnToCrossServer)
engineevent.regGameStartEvent(gameStar)
table.insert(InitFnTable, init)

csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_SyncControlInfo, a4sSyncControlInfo)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.csttopen = function (actor, args)
	gmForceOpenTianTi()
	return true
end

gmCmdHandlers.csttstage = function (actor, args)
	updateStage(tonumber(args[1]))
	return true
end
