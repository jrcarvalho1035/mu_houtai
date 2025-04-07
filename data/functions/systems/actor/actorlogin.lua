module("actorlogin" , package.seeall)

local itempill_eff = {
	[330001] = 40001,
	[330002] = 40002,
	[330003] = 40003,
}

local function getDoubleTimeData(actor)
	local var = LActor.getStaticVar(actor)
	local data = var.doubleExp
	if data then 
		return data.time or 0, data.delay or 0, data.coe or 0, data.id or 0
	end
	return 0, 0, 0, 0
end

function getActorVar(actor)
	if not actor then return end

	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.buffers then var.buffers = {} end
	if not var.buffers.buffers then var.buffers.buffers = {} end
	if not var.buffers.buffercount then var.buffers.buffercount = 0 end
	return var.buffers	
end

function addEffect(actor, bufferid)
	local conf = EffectsConfig[bufferid]
	if not conf then return end
	if conf.duration > 0 then
		local now = System.getNowTime() * 1000
		local var = getActorVar(actor)
		local index = 0
		for i=1, var.buffercount do
			if var.buffers[i].bufferid == bufferid then
				if var.buffers[i].endtime - now > 0 then
					var.buffers[i].endtime = var.buffers[i].endtime + conf.duration
				else
					var.buffers[i].endtime = now + conf.duration
				end
				index = i
				break
			end
		end
		if index == 0 then
			var.buffercount = var.buffercount + 1
			var.buffers[var.buffercount] = {}
			var.buffers[var.buffercount].endtime = now + conf.duration
			var.buffers[var.buffercount].bufferid = bufferid
			index = var.buffercount
		end
		LActor.addSkillEffect(actor, bufferid, (var.buffers[index].endtime - now)/1000)
	else
		LActor.addSkillEffect(actor, bufferid)
	end
end

function s2cDoubleExpTime(actor)
	local time, delay, coe, id = getDoubleTimeData(actor)
	local remainTime = math.max(0, time + delay - System.getNowTime())
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_DoubleExpTime)
	LDataPack.writeInt(npack, remainTime)
	LDataPack.writeDouble(npack, coe)
	LDataPack.writeInt(npack, id)
	LDataPack.flush(npack)

	if itempill_eff[id] and remainTime > 0 then
		LActor.addSkillEffect(actor, itempill_eff[id], remainTime) --加入经验药水buf
	end
end

--双倍经验预先发送
function s2cDoubleExpTrailer(actor, delay, coe, id)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_DoubleExpTime)
	LDataPack.writeInt(npack, delay)
	LDataPack.writeDouble(npack, coe)
	LDataPack.writeInt(npack, id)
	LDataPack.flush(npack)
	if itempill_eff[id] then
		LActor.addSkillEffect(actor, itempill_eff[id], delay) --加入经验药水buf
	end
end

local function onLogin(actor)
	-- local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_ServerOpenDay)
	-- LDataPack.writeInt(npack, System.getOpenServerDay())
	-- LDataPack.flush(npack)
	s2cDoubleExpTime(actor)
	local var = getActorVar(actor)
	local now = System.getNowTime() * 1000
	for i=1, var.buffercount do
		if var.buffers[i].endtime - now > 0 then
			LActor.addSkillEffect(actor, var.buffers[i].bufferid, (var.buffers[i].endtime - now)/1000)
		end
	end	
end

local function onNewDay(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_ServerOpenDay)
	LDataPack.writeInt(npack, System.getOpenServerDay())
	LDataPack.writeInt(npack, System.getOpenServerDateTime())
	LDataPack.flush(npack)
end

function kickAllActor()
	if System.isCommSrv() then return end
	local actors = System.getOnlineActorList()
    if not actors then return end
	for i=1, #actors do
		local actor = actors[i]
		local serverId = LActor.getServerId(actor)
		local actorId = LActor.getActorId(actor)
		local mailData = {head = ScriptContents.crosstiphead, context = ScriptContents.crosstipcontext, tAwardList={}}
		mailsystem.sendMailById(actorId, mailData, serverId)
		if LActor.getFubenId(actor) == 81002 then
			LActor.exitFuben(actor)
		end
		LActor.exitFuben(actor)
    end    
end

function offlineAllActor()
	if System.isCommSrv() then return end
	local actors = System.getOnlineActorList()
    if not actors then return end
	for i=1, #actors do
		local actor = actors[i]
		local serverId = LActor.getServerId(actor)
		local actorId = LActor.getActorId(actor)
		local mailData = {head = ScriptContents.crosstiphead, context = ScriptContents.crosstipcontext, tAwardList={}}
		mailsystem.sendMailById(actorId, mailData, serverId)
		System.closeActor(actor)
    end   
end

function checkCanEnterCross(actor)
	local hour, min, sce = System.getTime()
	if (hour == 23 and min >= 50) or hour == 0 and min == 0 then
		--chatcommon.sendSystemTips(actor, 1, 2, ScriptContents.crossentertip)
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_NotEnterCross)
		LDataPack.writeChar(npack, 0)
		LDataPack.flush(npack)
		return false
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_NotEnterCross)
	LDataPack.writeChar(npack, 1)
	LDataPack.flush(npack)
	return true
end

function broCrossClose()
	if System.isCommSrv() then
		noticesystem.broadCastNotice(noticesystem.NTP.csclose)
	else
		noticesystem.broadCastCrossNotice(noticesystem.NTP.csclose)
	end
end

_G.broCrossClose = broCrossClose
_G.kickAllActor = kickAllActor
_G.offlineAllActor = offlineAllActor

actorevent.reg(aeUserLogin,onLogin)
actorevent.reg(aeNewDayArrive,onNewDay)
actorevent.reg(aeCreateRole, s2cDoubleExpTime)
