module("cstiantilog" , package.seeall)
local gConf = CsttComConfig

function copyActorLogTbl(raw, tar)
	if not raw then return end
	tar = tar or {}
	raw.dan = tar.dan
	raw.type = tar.type
	raw.time = tar.time
end

--个人段位变更日志
function logActorDanChange(actor, oldDan, curDan)
	local logData = nil
	local conf = CsttDanConfig[curDan] or {}
	local danRange = conf.danRange or 0

	if oldDan > curDan then --降级
		if gConf.dNeedDan[danRange] then --需要记录的段位
			logData = {}
			logData.dan = curDan
			logData.type = 0
			logData.time = System.getNowTime()
		end

	elseif oldDan < curDan then --升级
		if gConf.uNeedDan[danRange] then --需要记录的段位
			logData = {}
			logData.dan = curDan
			logData.type = 1
			logData.time = System.getNowTime()
		end
	end
	if logData then
		local var = cstiantisys.getVar(actor)
		local lNum = var.logNum
		if lNum >= gConf.actorMaxLog then
			for i=1, lNum-1 do
				var.log[i] = {}
				local curTbl = var.log[i]
				local nextTbl = var.log[i+1]
				copyActorLogTbl(curTbl, nextTbl)
			end
			var.log[lNum] = nil
			var.logNum = var.logNum - 1
		end

		var.log[var.logNum+1] = logData
		var.logNum = var.logNum + 1
	end
end

function copySysLogTbl(raw, tar)
	if not raw then return end
	tar = tar or {}
	for k,v in pairs(tar) do
		raw[k] = v
	end
end

--这个函数跨服与普通服都有可能触发
function addSysLog(logType, data)
	local sysVar = cstiantisys.getSysStaticVar()
	local log = sysVar.log
	local lNum = sysVar.logNum

	local function tempFun()
		if lNum >= gConf.sysMaxLog then --条数超出，把日志一条条往上挪
			for i=1, lNum-1 do
				sysVar.log[i] = {}
				local curTbl = sysVar.log[i]
				local nextTbl = sysVar.log[i+1]
				copySysLogTbl(curTbl, nextTbl)
			end
			sysVar.log[lNum] = nil
			sysVar.logNum = sysVar.logNum - 1
		end
	end
	tempFun()
	sysVar.logNum = sysVar.logNum + 1
	log[sysVar.logNum] = {}
	local tbl = log[sysVar.logNum]
	tbl.time = System.getNowTime()
	tbl.type = logType
	tbl.sId = data.sId
	tbl.name = data.name

	if logType == csTianTi.logType1 then  --连胜
		tbl.wins = data.wins
	elseif logType == csTianTi.logType2 then --段位达标
		tbl.dan = data.dan
	elseif logType == csTianTi.logType3 then --首个第一
		tbl.dan = data.dan
	end

	if System.isBattleSrv() then
		a2sAddCcttLog(0, tbl)
	end
end

function OnConnToCrossServer(serverId, serverType)
	if not System.isBattleSrv() then return end
	a2sSysLog(serverId)
end

--------------------------------------------------------------------------------------------------------------
--跨服发普通服日志同步
function a2sSysLog(sId)
	local sysVar = cstiantisys.getSysStaticVar()
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_SyncLog)

	LDataPack.writeShort(pack, sysVar.logNum)
	local log = sysVar.log
	for i=1, sysVar.logNum do
		local tbl = log[i]
		LDataPack.writeChar(pack, tbl.type)
		LDataPack.writeUInt(pack, tbl.time)
		LDataPack.writeInt(pack, tbl.sId)
		LDataPack.writeString(pack, tbl.name)
		if tbl.type == csTianTi.logType1 then
			LDataPack.writeInt(pack, tbl.wins)
		elseif tbl.type == csTianTi.logType2 then
			LDataPack.writeInt(pack, tbl.dan)
		elseif tbl.type == csTianTi.logType3 then
			LDataPack.writeInt(pack, tbl.dan)
		end
	end
	System.sendPacketToAllGameClient(pack, sId)
end

--普通服收到跨服的日志同步
function a4sSysLog(sId, sType, dp)
	local sysVar = cstiantisys.getSysStaticVar()
	sysVar.logNum = LDataPack.readShort(dp)
	sysVar.log = {}
	local log = sysVar.log
	for i=1, sysVar.logNum do
		log[i] = {}
		local tbl = log[i]
		tbl.type = LDataPack.readChar(dp)
		tbl.time = LDataPack.readUInt(dp)
		tbl.sId = LDataPack.readInt(dp)
		tbl.name = LDataPack.readString(dp)
		if tbl.type == csTianTi.logType1 then
			tbl.wins = LDataPack.readInt(dp)
		elseif tbl.type == csTianTi.logType2 then
			tbl.dan = LDataPack.readInt(dp)
		elseif tbl.type == csTianTi.logType3 then
			tbl.dan = LDataPack.readInt(dp)
		end
	end
end

--普通服收到跨服的添加日志
function a4sAddSysLog(sId, sType, dp)
	if not System.isCommSrv() then return end

	local data = {}
	data.type = LDataPack.readChar(dp)
	data.time = LDataPack.readUInt(dp)
	data.sId = LDataPack.readInt(dp)
	data.name = LDataPack.readString(dp)
	if data.type == csTianTi.logType1 then
		data.wins = LDataPack.readInt(dp)
	elseif data.type == csTianTi.logType2 then
		data.dan = LDataPack.readInt(dp)
	elseif data.type == csTianTi.logType3 then
		data.dan = LDataPack.readInt(dp)
	end
	addSysLog(data.type, data)
end

--跨服发普服日志添加信息
function a2sAddCcttLog(sId, data)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_AddSysLog)

	LDataPack.writeChar(pack, data.type)
	LDataPack.writeUInt(pack, data.time)
	LDataPack.writeInt(pack, data.sId)
	LDataPack.writeString(pack, data.name)
	if data.type == csTianTi.logType1 then
		LDataPack.writeInt(pack, data.wins)
	elseif data.type == csTianTi.logType2 then
		LDataPack.writeInt(pack, data.dan)
	elseif data.type == csTianTi.logType3 then
		LDataPack.writeInt(pack, data.dan)
	end

	System.sendPacketToAllGameClient(pack, sId)
end

------------------------------------------------------------------------------------------------------
function c2sGetLog(actor, packet)
	s2cGetLog(actor)
end

function s2cGetLog(actor)
	local var = cstiantisys.getVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsTianti_GetLog)
	if npack == nil then return end

	--local sysVar = cstiantisys.getSysStaticVar()

	local logNum = var.logNum
	local emptyNum = 0
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeByte(npack, logNum)
	for i=1, logNum do
		repeat
			local tbl = var.log[i]
			if #tbl == 0 then
				emptyNum = emptyNum + 1
				break
			end
			LDataPack.writeInt(npack, tbl.time) --日志时间
			LDataPack.writeChar(npack, tbl.type) --日志类型
			LDataPack.writeInt(npack, tbl.dan)	 --段位
		until(true)
	end

	--日志轮替时报错，这里要修正日志为空的数量
	local nowPos = LDataPack.getPosition(npack)
	if emptyNum > 0 then
		logNum = logNum - emptyNum
		LDataPack.setPosition(npack, pos)
		LDataPack.writeByte(npack, logNum)
		LDataPack.setPosition(npack, nowPos)
	end

	local sysVar = cstiantisys.getSysStaticVar()
	log = sysVar.log
	logNum = sysVar.logNum
	LDataPack.writeByte(npack, logNum)
	for i=1, logNum do
		local tbl = log[i]
		local value
		if tbl.type == csTianTi.logType1 then
			value = tbl.wins
		else 
			value = tbl.dan
		end
		LDataPack.writeByte(npack, tbl.type) --日志类型
		LDataPack.writeInt(npack, tbl.time) --日志时间
		LDataPack.writeInt(npack, tbl.sId)	 --服务器ID
		LDataPack.writeString(npack, tbl.name)--玩家名
		LDataPack.writeInt(npack, value) --连胜数或者段位
	end
	LDataPack.flush(npack)
end


csbase.RegConnected(OnConnToCrossServer)

csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_SyncLog, a4sSysLog)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_AddSysLog, a4sAddSysLog)

netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsTianti_GetLog, c2sGetLog)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.csttlog = function (actor, args)
	c2sGetLog(actor)
	return true
end

gmCmdHandlers.csttaddlog = function (actor, args)
	local tp = tonumber(args[1])
	local var = cstiantisys.getVar(actor)
	local logData = {sId=0,name=0,wins=0,dan=var.dan}
	logData.sId = LActor.getServerId(actor)
	logData.name = LActor.getName(actor)
	logData.wins = 0
	addSysLog(tp, logData)
	return true
end

gmCmdHandlers.csttdanlog = function (actor, args)
	local var = cstiantisys.getVar(actor)
	local curDan = tonumber(args[1])
	logActorDanChange(actor, var.dan, curDan)
end
