module("guildbossteam", package.seeall)

local TEAM_MAX = #GuildBossCommonConfig.extra --组队人数
g_guildteam = g_guildteam or {} --每支队伍的信息，{[队长id]={}}
g_guildmember = g_guildmember or {} --每个玩家对应的队伍，{[自己id]=队长id}

Team_Err_guild008 = 1
Team_Err_guild010 = 2
Team_Err_guild011 = 3
Team_Err_guild012 = 4

local function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.guildteamData then
		var.guildteamData = {}
	end
	return var.guildteamData 
end

local function sendTipmsg(sId, actorId, errid)	    
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendTeamTipMsg)    
   
    LDataPack.writeInt(npack, actorId)
    LDataPack.writeByte(npack, errid)
    System.sendPacketToAllGameClient(npack, sId)
end

local function onSendTeamTipMsg(sId, sType, cpack)
	local actorId = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorId)
	if not actor then return end
	local errid = LDataPack.readByte(cpack)
	if errid == Team_Err_guild008 then
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild008), ttScreenCenter)
	elseif errid == Team_Err_guild010 then
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild010), ttScreenCenter)
	elseif errid == Team_Err_guild011 then
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild011), ttScreenCenter)
	elseif errid == Team_Err_guild012 then
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild012), ttScreenCenter)
	end

end

--队伍人数，没队伍就返回1
function getTeamMemberCount(captainId)
	local count = 0
	local team = g_guildteam[captainId]
	if team then
		for k, v in pairs(team) do
			count = count + 1
		end
	else
		count = 1
	end
	return count
end

--有队伍并且是队员
function isTeamMember(actorId)
	if g_guildmember[actorId] and actorId ~= g_guildmember[actorId] then
		return true
	end
	return false
end

--队伍里所以队员，如果没队伍就返回自己
function getTeam(actorId)
	local mem = {}
	if g_guildteam[actorId] then
		for k, v in pairs(g_guildteam[actorId]) do
			table.insert(mem, k)
		end
	else
		table.insert(mem, actorId)
	end
	return mem
end

--加入队伍
function addTeam(captainId, name)
	local team = g_guildteam[captainId]
	for k, v in pairs(team) do
		local tor = LActor.getActorById(k)
		if tor then
			LActor.sendTipmsg(tor, string.format(ScriptTips.guild003, name), ttScreenCenter)
		end
	end
	notifyTeamInfo(captainId) --更新队伍信息
end

--退出队伍(包括主动与被动)
function quitTeam(actorId, captainId)
	local team = g_guildteam[captainId]
	if not team then return end
	team[actorId] = nil
	g_guildmember[actorId] = nil
	notifyTeamInfo(captainId) --发送队伍更新信息
end

--解散队伍
function breakTeam(captainId)
	local team = g_guildteam[captainId]
	if not team then return end
	for k, v in pairs(team) do
		g_guildmember[k] = nil
		local tor = LActor.getActorById(k)
		if tor then
			s2cGuildTeamBreak(tor) --通知队员解散信息
		end
	end
	g_guildteam[captainId] = nil
end

--向队伍中的人发送组队信息
function notifyTeamInfo(captainId)
	local team = g_guildteam[captainId]
	for k, v in pairs(team) do
		local tor = LActor.getActorById(k)
		if tor then
			s2cGuildTeamInfo(tor, captainId)
		end
	end
end

function exitTeam(actor)
	local actorId = LActor.getActorId(actor)
	local captainId = g_guildmember[actorId]
	if not captainId then return end --没有队伍
	if actorId == captainId then
		breakTeam(captainId)
	else
		quitTeam(actorId, captainId)
	end

    local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetTeamBreak)
	LDataPack.writeInt(npack, actorId)
	System.sendPacketToAllGameClient(npack, 0)
end

local function onGetTeamBreak(sId, sType, cpack)
	local actorId = LDataPack.readInt(cpack)
	local captainId = g_guildmember[actorId]
	if not captainId then return end --没有队伍

	if actorId == captainId then
		breakTeam(captainId)
	else
		quitTeam(actorId, captainId)
	end

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendTeamBreak)
	LDataPack.writeInt(npack, actorId)
	System.sendPacketToAllGameClient(npack, 0)
end

local function onSendTeamBreak(sId, sType, cpack)
	local actorId = LDataPack.readInt(cpack)
	local captainId = g_guildmember[actorId]
	if not captainId then return end --没有队伍
	if actorId == captainId then
		breakTeam(captainId)
	else
		quitTeam(actorId, captainId)
	end
end
---------------------------------------------------------------------------------------------------
--队伍信息
function s2cGuildTeamInfo(actor, captainId)
	local team = g_guildteam[captainId]
	if not team then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildActity, Protocol.sGuildActivityCmd_TeamInfo)
	if pack == nil then return end
	local pos = LDataPack.getPosition(pack)
	local count = 0
	LDataPack.writeChar(pack, count)
	for k, v in pairs(team) do
		LDataPack.writeInt(pack, k)
		LDataPack.writeString(pack, v.name)
		LDataPack.writeInt(pack, v.level)
		LDataPack.writeDouble(pack, v.power)
		LDataPack.writeChar(pack, v.job)
		LDataPack.writeByte(pack, captainId==k and 1 or 0)
		LDataPack.writeShort(pack, v.count)
		LDataPack.writeInt(pack, v.shenqiid)
		LDataPack.writeInt(pack, v.shenzhuangid)
		LDataPack.writeInt(pack, v.wingid)
		count = count + 1
	end

	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeChar(pack, count)
	LDataPack.setPosition(pack, npos)
	LDataPack.flush(pack)
end

function writeBasicData(actor, npack)
	local basic_data = LActor.getActorData(actor)
	LDataPack.writeString(npack, basic_data.actor_name)
	LDataPack.writeInt(npack, basic_data.level)
	LDataPack.writeDouble(npack, basic_data.total_power)
	LDataPack.writeChar(npack, LActor.getJob(actor))			
	LDataPack.writeShort(npack, guildboss.getFightCount(actor))
	LDataPack.writeInt(npack, shenqisystem.getShenqiId(actor))
	LDataPack.writeInt(npack, shenzhuangsystem.getShenzhuangId(actor))
	LDataPack.writeInt(npack, wingsystem.getWingId(actor))
end

function readBasicData(cpack)
	return LDataPack.readString(cpack), LDataPack.readInt(cpack)
	,LDataPack.readDouble(cpack), LDataPack.readChar(cpack), LDataPack.readShort(cpack)
	,LDataPack.readInt(cpack), LDataPack.readInt(cpack), LDataPack.readInt(cpack)
end

function writeBasic(npack, name, level, power, job, count, shenqiid, shenzhuangid, wingid)
	LDataPack.writeString(npack, name)
	LDataPack.writeInt(npack, level)
	LDataPack.writeDouble(npack, power)
	LDataPack.writeChar(npack, job)
	LDataPack.writeShort(npack, count)
	LDataPack.writeInt(npack, shenqiid)
	LDataPack.writeInt(npack, shenzhuangid)
	LDataPack.writeInt(npack, wingid)
end

--组队邀请
function c2sGuildTeamInvite(actor, packet)
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then 
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild004), ttScreenCenter)
		return
	end
	if not guildboss.checkFightCount(actor) then
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild005), ttScreenCenter)
		return
	end

	local now = System.getNowTime()
	local var = getActorVar(actor)
	if (var.InviteTime or 0) > now then
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild007, var.InviteTime - now), ttScreenCenter)
		return
    end
    
    local actorId = LActor.getActorId(actor)
    local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetTeamInvite)
	LDataPack.writeInt(npack, actorId)
	writeBasicData(actor, npack)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeChar(npack, LActor.getVipLevel(actor))
	LDataPack.writeChar(npack, LActor.getSVipLevel(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

local function onGetTeamInvite(sId, sType, cpack)
	local actorId = LDataPack.readInt(cpack)
	local name, level, power, job, count, shenqiid, shenzhuangid, wingid = readBasicData(cpack)
	if getTeamMemberCount(actorId) >= TEAM_MAX then
		--LActor.sendTipmsg(actor, string.format(ScriptTips.guild006), ttScreenCenter)
		return
    end
    if not g_guildmember[actorId] then --没有队伍时就自己创建一支队
		g_guildteam[actorId] = {
			[actorId] = {name=name, level=level,power=power,job=job,count=count,shenqiid=shenqiid,shenzhuangid=shenzhuangid,wingid=wingid}
		}
		g_guildmember[actorId] = actorId
		--s2cGuildTeamInfo(actor, actorId)
	end
	local captainId = g_guildmember[actorId] --队长id

    local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendTeamInvite)
	LDataPack.writeInt(npack, actorId)    
	LDataPack.writeInt(npack, captainId)
	writeBasic(npack, name, level, power, job, count, shenqiid, shenzhuangid, wingid)
	LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	LDataPack.writeChar(npack, LDataPack.readChar(cpack))
	LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    System.sendPacketToAllGameClient(npack, 0)    
end

local function onSendTeamInvite(sId, sType, cpack)
	local actorId = LDataPack.readInt(cpack)
	
	local captainId = LDataPack.readInt(cpack)
	local name, level, power, job, count, shenqiid, shenzhuangid, wingid = readBasicData(cpack)
    local guildId = LDataPack.readInt(cpack)
	if not g_guildmember[actorId] then --没有队伍时就自己创建一支队
		g_guildteam[actorId] = {[actorId] = {name=name, level=level,power=power,job=job,count=count,shenqiid=shenqiid,shenzhuangid=shenzhuangid,wingid=wingid}}
		g_guildmember[actorId] = actorId
	else
		if not g_guildteam[captainId] then 
			return
		end
		g_guildteam[captainId][actorId] = {name=name, level=level,power=power,job=job,count=count,shenqiid=shenqiid,shenzhuangid=shenzhuangid,wingid=wingid}
	end
	
	local pack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildActity, Protocol.sGuildActivityCmd_TeamInvite)
	LDataPack.writeInt(pack, captainId) --队长的id
	LDataPack.writeString(pack, name)
	LDataPack.writeChar(pack, LDataPack.readChar(cpack))
	LDataPack.writeChar(pack, LDataPack.readChar(cpack))
	LGuild.broadcastData(guildId, pack)

	local actor = LActor.getActorById(actorId)
	if not actor then return end
    local var = getActorVar(actor)
	var.InviteTime = System.getNowTime() + GuildBossCommonConfig.inviteCd
    LActor.sendTipmsg(actor, string.format(ScriptTips.guild021), ttScreenCenter)
end

--组队申请
function c2sGuildTeamApply(actor, packet)
    local id = LDataPack.readInt(packet)

    local fbId = LActor.getFubenId(actor)
	if not staticfuben.isStaticFuben(fbId) then
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild009), ttScreenCenter)
		return
    end

    local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetTeamApply)
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	LDataPack.writeInt(npack, id)
	writeBasicData(actor, npack)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onGetTeamApply(sId, sType, cpack)
    local actorId = LDataPack.readInt(cpack)
	local id = LDataPack.readInt(cpack)
	
	if g_guildmember[actorId] then
		sendTipmsg(sId, actorId, Team_Err_guild008)
		return
	end

	if getTeamMemberCount(id) >= TEAM_MAX then
		sendTipmsg(sId, actorId, Team_Err_guild010)
		return
	end
	if not g_guildteam[id] then
		sendTipmsg(sId, actorId, Team_Err_guild012)
		return
	end
	if LGuild.getGuildIdByActorId(actorId) ~= LGuild.getGuildIdByActorId(id) then
		sendTipmsg(sId, actorId, Team_Err_guild011)
		return
	end
	local name, level, power, job, count, shenqiid, shenzhuangid, wingid = readBasicData(cpack)

	g_guildteam[id][actorId] = {name=name, level=level,power=power,job=job,count=count,shenqiid=shenqiid,shenzhuangid=shenzhuangid,wingid=wingid}
	g_guildmember[actorId] = id

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendTeamApply)
	LDataPack.writeInt(npack, actorId)
	LDataPack.writeInt(npack, id)
	writeBasic(npack, name, level, power, job, count, shenqiid, shenzhuangid, wingid)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onSendTeamApply(sId, sType, cpack)
	local actorId = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorId)

	local captainId = LDataPack.readInt(cpack)	
	local name, level, power, job, count, shenqiid, shenzhuangid, wingid = readBasicData(cpack)
	
	if not g_guildmember[captainId] then --没有队伍时就自己创建一支队
		g_guildteam[captainId] = {[actorId] = {name=name, level=level,power=power,job=job,count=count,shenqiid=shenqiid,shenzhuangid=shenzhuangid,wingid=wingid}}
		g_guildmember[actorId] = captainId
	else
		g_guildteam[captainId][actorId] = {name=name, level=level,power=power,job=job,count=count,shenqiid=shenqiid,shenzhuangid=shenzhuangid,wingid=wingid}
		g_guildmember[actorId] = captainId
	end
	
	addTeam(captainId, name)
	if not actor then return end
	LActor.sendTipmsg(actor, string.format(ScriptTips.guild013), ttScreenCenter)
end

--踢走队员
function c2sGuildTeamSpurn(actor, packet)
	local id = LDataPack.readInt(packet)
	local actorId = LActor.getActorId(actor)
	if not g_guildteam[actorId] then --不是队长
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild014), ttScreenCenter)
		return
	end
	if actorId == id then --不能踢自己
		return
	end
	if not g_guildteam[actorId][id] then --没有这队员
		return
	end

	quitTeam(id, actorId)
	s2cGuildTeamSpurn(LActor.getActorById(id))

	local actorId = LActor.getActorId(actor)
    local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetTeamSpurn)
	LDataPack.writeInt(npack, id)
	LDataPack.writeInt(npack, actorId)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onGetTeamSpurn(sId, sType, cpack)
	local id = LDataPack.readInt(cpack)
	local actorId = LDataPack.readInt(cpack)

	if not g_guildteam[actorId][id] then --没有这队员
		return
	end
	quitTeam(id, actorId)

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendTeamSpurn)
	LDataPack.writeInt(npack, id)
	LDataPack.writeInt(npack, actorId)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onSendTeamSpurn(sId, sType, cpack)
	local id = LDataPack.readInt(cpack)
	local actorId = LDataPack.readInt(cpack)

	if not g_guildteam[actorId][id] then --没有这队员
		return
	end
	quitTeam(id, actorId)
	s2cGuildTeamSpurn(LActor.getActorById(id))
end

function s2cGuildTeamSpurn(actor)
	if not actor then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildActity, Protocol.sGuildActivityCmd_TeamSpurn)
	if pack == nil then return end
	LDataPack.flush(pack)
end

--退出或解散队伍
function c2sGuildTeamBreak(actor, packet)
	exitTeam(actor)
end

--队伍被解散
function s2cGuildTeamBreak(actor, packet)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildActity, Protocol.sGuildActivityCmd_TeamBreak)
	if pack == nil then return end
	LDataPack.flush(pack)
end

--此协议打开组队界面
function c2sGuildTeamReady(actor, packet)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildActity, Protocol.sGuildActivityCmd_TeamInfo)
	if pack == nil then return end
	local basic_data = LActor.getActorData(actor) 

	LDataPack.writeChar(pack, 1) --队员人数1
	LDataPack.writeInt(pack, LActor.getActorId(actor))
	LDataPack.writeString(pack, basic_data.actor_name)
	LDataPack.writeInt(pack, basic_data.level)
	LDataPack.writeDouble(pack, basic_data.total_power)
	LDataPack.writeChar(pack, LActor.getJob(actor))
	LDataPack.writeByte(pack, 1) --是组长
	LDataPack.writeShort(pack, guildboss.getFightCount(actor))
	LDataPack.writeInt(pack, shenqisystem.getShenqiId(actor))
	LDataPack.writeInt(pack, shenzhuangsystem.getShenzhuangId(actor))
	LDataPack.writeInt(pack, wingsystem.getWingId(actor))
	LDataPack.flush(pack)
end

--退出登录，就退出队伍或解散队伍
function onActorLogout(actor)
	exitTeam(actor)
end

local function initGlobalData()
	if System.isCrossWarSrv() then return end
	actorevent.reg(aeUserLogout, onActorLogout)
	netmsgdispatcher.reg(Protocol.CMD_GuildActity, Protocol.cGuildActivityCmd_TeamInvite, c2sGuildTeamInvite)
	netmsgdispatcher.reg(Protocol.CMD_GuildActity, Protocol.cGuildActivityCmd_TeamApply, c2sGuildTeamApply)
	netmsgdispatcher.reg(Protocol.CMD_GuildActity, Protocol.cGuildActivityCmd_TeamSpurn, c2sGuildTeamSpurn)
	netmsgdispatcher.reg(Protocol.CMD_GuildActity, Protocol.cGuildActivityCmd_TeamBreak, c2sGuildTeamBreak)
	netmsgdispatcher.reg(Protocol.CMD_GuildActity, Protocol.cGuildActivityCmd_TeamReady, c2sGuildTeamReady)
end
table.insert(InitFnTable, initGlobalData)

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetTeamInvite, onGetTeamInvite)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendTeamInvite, onSendTeamInvite)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetTeamApply, onGetTeamApply)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendTeamApply, onSendTeamApply)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetTeamSpurn, onGetTeamSpurn)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendTeamSpurn, onSendTeamSpurn)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetTeamBreak, onGetTeamBreak)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendTeamBreak, onSendTeamBreak)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendTeamTipMsg, onSendTeamTipMsg)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.guildteamInfo = function (actor, args)
	utils.printTable(g_guildteam)
	utils.printTable(g_guildmember)
	local actorId = LActor.getActorId(actor)
	if g_guildmember[actorId] then
		s2cGuildTeamInfo(actor, g_guildmember[actorId])
	end
end

gmCmdHandlers.guildteamInvite = function (actor, args)
	c2sGuildTeamInvite(actor)
end

gmCmdHandlers.guildteamApply = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, tonumber(args[1]))
	LDataPack.setPosition(pack, 0)
	c2sGuildTeamApply(actor, pack)
end

gmCmdHandlers.guildteamSpurn = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, tonumber(args[1]))
	LDataPack.setPosition(pack, 0)
	c2sGuildTeamSpurn(actor, pack)
end

gmCmdHandlers.guildteamBreak = function (actor, args)
	c2sGuildTeamBreak(actor)
end

gmCmdHandlers.guildteamReady = function (actor, args)
	c2sGuildTeamReady(actor)
end
