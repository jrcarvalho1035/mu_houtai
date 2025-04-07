-- @version	1.0
-- @author	qianmeng
-- @date	2018-2-11 10:38:51
-- @system	恶魔岛组队

module("islandteam", package.seeall)

local TEAM_MAX = IslandCommonConfig.teamNum --组队人数
g_islandteam = g_islandteam or {} --每支队伍的信息，{[队长id]={}}
g_islandmember = g_islandmember or {} --每个玩家对应的队伍，{[自己id]=队长id}

local function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.islandteamData then
		var.islandteamData = {}
	end
	return var.islandteamData 
end

--队伍人数，没队伍就返回1
function getTeamMemberCount(captainId)
	local count = 0
	local team = g_islandteam[captainId]
	if team then
		for k, v in pairs(team) do
			local tor = LActor.getActorById(k)
			if tor then
				count = count + 1
			end
		end
	else
		count = 1
	end
	return count
end

--有队伍并且是队员
function isTeamMember(actorId)
	if g_islandmember[actorId] and actorId ~= g_islandmember[actorId] then
		return true
	end
	return false
end

--返回队伍里所有队员，如果没队伍就返回自己
function getTeam(actorId)
	local mem = {}
	if g_islandteam[actorId] then
		for k, v in pairs(g_islandteam[actorId]) do
			table.insert(mem, k)
		end
	else
		table.insert(mem, actorId)
	end
	return mem
end

--创建队伍
function createTeam(actorId)
	g_islandteam[actorId] = {
		[actorId] = island.getId(actorId)
	}
	g_islandmember[actorId] = actorId
end

--加入队伍
function addTeam(actorId, captainId, name)
	local team = g_islandteam[captainId]
	for k, v in pairs(team) do
		local tor = LActor.getActorById(k)
		if tor then
			LActor.sendTipmsg(tor, string.format(ScriptTips.guild003, name), ttScreenCenter)
		end
	end
	team[actorId] = island.getId(actorId)
	g_islandmember[actorId] = captainId
	notifyTeamInfo(captainId) --更新队伍信息
end

--退出队伍(包括主动与被动)
function quitTeam(actorId, captainId)
	local team = g_islandteam[captainId]
	team[actorId] = nil
	g_islandmember[actorId] = nil
	notifyTeamInfo(captainId) --发送队伍更新信息
end

--解散队伍
function breakTeam(captainId)
	g_islandmember[captainId] = nil --防止一些BUG导致的删不干净
	local team = g_islandteam[captainId]
	if not team then return end
	for k, v in pairs(team) do
		g_islandmember[k] = nil
		local tor = LActor.getActorById(k)
		s2cIslandTeamBreak(tor, packet) --通知队员解散信息
	end
	g_islandteam[captainId] = nil
end

--向队伍中的人发送组队信息
function notifyTeamInfo(captainId)
	local team = g_islandteam[captainId]
	for k, v in pairs(team) do
		local tor = LActor.getActorById(k)
		if tor then
			s2cIslandTeamInfo(tor, captainId)
		end
	end
end

function exitTeam(actor)
	local actorId = LActor.getActorId(actor)
	local captainId = g_islandmember[actorId]
	utils.printTable(g_islandmember)
	if not captainId then return end --没有队伍
	if actorId == captainId then
		breakTeam(captainId)
	else
		quitTeam(actorId, captainId)
	end
end
---------------------------------------------------------------------------------------------------
--队伍信息
function s2cIslandTeamInfo(actor, captainId)
	local team = g_islandteam[captainId]
	if not team then return end
	local islandId = team[captainId]
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_IslandTeam)
	if pack == nil then return end
	local pos = LDataPack.getPosition(pack)
	local count = 0
	LDataPack.writeChar(pack, count)
	for actorId, curId in pairs(team) do
		local tor = LActor.getActorById(actorId)
		if tor then
			local basic_data = LActor.getActorDataById(actorId)
			LDataPack.writeInt(pack, actorId)
			LDataPack.writeString(pack, basic_data.actor_name)
			LDataPack.writeInt(pack, basic_data.level)
			LDataPack.writeInt(pack, basic_data.total_power)
			local rcount = LActor.getRoleCount(tor)
			LDataPack.writeChar(pack, rcount)
			for roleId = 0, rcount-1 do
				local role = LActor.getRole(tor, roleId)
			 	LDataPack.writeChar(pack, LActor.getJob(role))
			end
			LDataPack.writeByte(pack, captainId==actorId and 1 or 0)
			LDataPack.writeByte(pack, curId >= islandId and 1 or 0)
			LDataPack.writeDouble(pack, LActor.getHandle(tor))
			count = count + 1
		end
	end

	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeChar(pack, count)
	LDataPack.setPosition(pack, npos)
	LDataPack.flush(pack)
end

--组队邀请
function c2sIslandTeamInvite(actor, packet)
	--local guild = LActor.getGuildPtr(actor)
	-- if not guild then 
	-- 	LActor.sendTipmsg(actor, string.format(ScriptTips.guild004), ttScreenCenter)
	-- 	return
	-- end
	local actorId = LActor.getActorId(actor)
	if getTeamMemberCount(actorId) >= TEAM_MAX then --队伍已满员，无法邀请
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild006), ttScreenCenter)
		return
	end

	local now = System.getNowTime()
	local var = getActorVar(actor)
	if (var.InviteTime or 0) > now then --%d秒后才能再次发起邀请
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild007, var.InviteTime - now), ttScreenCenter)
		return
	end
	if not g_islandmember[actorId] then --没有队伍时就自己创建一支队
		createTeam(actorId)
	end
	local captainId = g_islandmember[actorId] --队长id
	
	var.InviteTime = now + IslandCommonConfig.inviteCd

	-- local members = LGuild.getMemberIdList(guild)
	-- for k, v in pairs(members) do
	-- 	local tor = LActor.getActorById(v)
	-- 	if tor then
	-- 		s2cNotifyTeamInvite(tor, actor, captainId)
	-- 	end
	-- end
	local actors = System.getOnlineActorList()
	if actors == nil then return end
	for i = 1, #actors do
		if actors[i] then
			s2cNotifyTeamInvite(actors[i], actor, captainId)
		end
	end
	LActor.sendTipmsg(actor, string.format(ScriptTips.guild021), ttScreenCenter)
end

--收到组队邀请
function s2cNotifyTeamInvite(actor, tor, captainId)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_IslandInvite)

	LDataPack.writeInt(pack, captainId) --队长的id
	LDataPack.writeString(pack, LActor.getName(tor))
	LDataPack.writeChar(pack, LActor.getVipLevel(tor))
	LDataPack.flush(pack)
end

--组队申请
function c2sIslandTeamApply(actor, packet)
	local id = LDataPack.readInt(packet)
	local actorId = LActor.getActorId(actor)
	utils.printTable(g_islandmember)
	if g_islandmember[actorId] then
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild008), ttScreenCenter)
		return
	end
	local fbId = LActor.getFubenId(actor)
	if not staticfuben.isStaticFuben(fbId) then
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild009), ttScreenCenter)
		return
	end
	if getTeamMemberCount(id) >= TEAM_MAX then
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild010), ttScreenCenter)
		return
	end
	if not g_islandteam[id] then
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild012), ttScreenCenter)
		return
	end
	-- local tor = LActor.getActorById(id)
	-- if LActor.getGuildPtr(tor) ~= LActor.getGuildPtr(actor) then
	-- 	LActor.sendTipmsg(actor, string.format(ScriptTips.guild011), ttScreenCenter)
	-- 	return
	-- end
	if island.getId(actorId) < island.getId(id) then --未开启对应副本
		LActor.sendTipmsg(actor, ScriptTips.guild022, ttScreenCenter)
		return
	end

	addTeam(actorId, id, LActor.getName(actor))
	LActor.sendTipmsg(actor, string.format(ScriptTips.guild013), ttScreenCenter)
end

--踢走队员
function c2sIslandTeamSpurn(actor, packet)
	local id = LDataPack.readInt(packet)
	local actorId = LActor.getActorId(actor)
	if not g_islandteam[actorId] then --不是队长
		LActor.sendTipmsg(actor, string.format(ScriptTips.guild014), ttScreenCenter)
		return
	end
	if actorId == id then --不能踢自己
		return
	end
	if not g_islandteam[actorId][id] then --没有这队员
		return
	end

	quitTeam(id, actorId)
	s2cIslandTeamSpurn(LActor.getActorById(id))
end

function s2cIslandTeamSpurn(actor)
	if not actor then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_IslandSpurn)
	if pack == nil then return end
	LDataPack.flush(pack)
end

--退出或解散队伍
function c2sIslandTeamBreak(actor, packet)
	exitTeam(actor)
end

--队伍被解散
function s2cIslandTeamBreak(actor, packet)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_IslandBreak)
	if pack == nil then return end
	LDataPack.flush(pack)
end

--此协议打开组队界面
function c2sIslandTeamReady(actor, packet)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_IslandTeam)
	if pack == nil then return end
	local basic_data = LActor.getActorData(actor) 

	LDataPack.writeChar(pack, 1) --队员人数1
	LDataPack.writeInt(pack, LActor.getActorId(actor))
	LDataPack.writeString(pack, basic_data.actor_name)
	LDataPack.writeInt(pack, basic_data.level)
	LDataPack.writeInt(pack, basic_data.total_power)
	local rcount = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, rcount)
	for roleId = 0, rcount-1 do
		local role = LActor.getRole(actor, roleId)
		LDataPack.writeChar(pack, LActor.getJob(role))
	end
	LDataPack.writeByte(pack, 1) --是组长
	LDataPack.writeByte(pack, 0) --未通关
	LDataPack.writeDouble(pack, LActor.getHandle(actor))
	LDataPack.flush(pack)
end

--退出登录，就退出队伍或解散队伍
function onActorLogout(actor)
	exitTeam(actor)
end

local function fuBenInit()
	if System.isBattleSrv() then return end
	actorevent.reg(aeUserLogout, onActorLogout)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_IslandInvite, c2sIslandTeamInvite)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_IslandApply, c2sIslandTeamApply)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_IslandSpurn, c2sIslandTeamSpurn)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_IslandBreak, c2sIslandTeamBreak)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_IslandReady, c2sIslandTeamReady)
end
table.insert(InitFnTable, fuBenInit)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.islandteamInfo = function (actor, args)
	utils.printTable(g_islandteam)
	utils.printTable(g_islandmember)
	local actorId = LActor.getActorId(actor)
	if g_islandmember[actorId] then
		s2cIslandTeamInfo(actor, g_islandmember[actorId])
	end
end

gmCmdHandlers.islandteamInvite = function (actor, args)
	c2sIslandTeamInvite(actor)
end

gmCmdHandlers.islandteamApply = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, tonumber(args[1]))
	LDataPack.setPosition(pack, 0)
	c2sIslandTeamApply(actor, pack)
end

gmCmdHandlers.islandteamSpurn = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, tonumber(args[1]))
	LDataPack.setPosition(pack, 0)
	c2sIslandTeamSpurn(actor, pack)
end

gmCmdHandlers.islandteamBreak = function (actor, args)
	c2sIslandTeamBreak(actor)
end

gmCmdHandlers.islandteamReady = function (actor, args)
	c2sIslandTeamReady(actor)
end
