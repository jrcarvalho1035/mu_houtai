module("msfbcountrestore", package.seeall)
--副本次数恢复逻辑
--这个功能的添加，保能是重启的，不能热更
--如果是修改的话，是可以热更的
local globalConf = MonSiegeConf
local langScript = ScriptTips

function actorInit(actor)
	local var = monstersiegesys.getActorVar(actor)
	if var.fbCount == nil then
		var.fbCount = globalConf.fbCount
	end
	-- if var.fbCount < globalConf.fbCountMax then
	-- 	starRestore(actor)
	-- end
end

function changeFBCount(actor, val)
	local var = monstersiegesys.getActorVar(actor)
	local lastCount = var.fbCount
	var.fbCount = var.fbCount + val
	if var.fbCount < 0 then
		var.fbCount = 0
	end

	sendFBCount(actor)
	if lastCount >= globalConf.fbCountMax and var.fbCount < globalConf.fbCountMax then
		starRestore(actor)
	end
end

function getFBCount(actor)
	local var = monstersiegesys.getActorVar(actor)
	if var.fbCount == nil then
		var.fbCount = globalConf.fbCount
	end
	return var.fbCount
end

function starRestore(actor)
	local var = monstersiegesys.getActorVar(actor)
	local now_t = System.getNowTime()
	var.restoreFlag = now_t

	sendRestoreFlag(actor)
end

function onLogin(actor)
	if System.isBattleSrv() then return end
	actorInit(actor)
	updateRestoreCount(actor)
	sendFBCount(actor)
end

function reqCheckRestore(actor, pack)
	updateRestoreCount(actor)
	sendFBCount(actor)
end

function updateRestoreCount(actor)
	local var = monstersiegesys.getActorVar(actor)
	if var.fbCount >= globalConf.fbCountMax then
		-- print("副本次数已满")
		-- LActor.sendTipmsg(actor, langScript.mssys006, ttMessage)
		return
	end
	local now_t = System.getNowTime()
	local oTime = now_t - var.restoreFlag
	for i=1, globalConf.fbCountMax do
		if oTime < globalConf.challengeRestore then
			break
		end
		var.fbCount = var.fbCount + 1
		oTime = oTime - globalConf.challengeRestore
		if var.fbCount >= globalConf.fbCountMax then
			var.fbCount = globalConf.fbCountMax
			break
		end
	end

	var.restoreFlag = now_t - oTime
	sendRestoreFlag(actor)
end

function sendRestoreFlag(actor)
	--更新前端的倒计时信息
	local var = monstersiegesys.getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_UpdateRestoreFlag)
	if npack == nil then return end
	LDataPack.writeUInt(npack, var.restoreFlag)
	LDataPack.flush(npack)
end

function sendFBCount(actor)
	local var = monstersiegesys.getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_UpdateFBCount)
	if npack == nil then return end
	LDataPack.writeShort(npack, var.fbCount)
	LDataPack.flush(npack)
end

actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_ReqCheckRestore, reqCheckRestore)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.msfbcount = function (actor, args)
	local count = tonumber(args[1])
	if not count then return end
	local var = monstersiegesys.getActorVar(actor)
	var.fbCount = count
	sendFBCount(actor)
	return true
end

