-- 
module("guildcommon", package.seeall)

local systemId = Protocol.CMD_Guild
GUILD_BASIC_INFO = GUILD_BASIC_INFO or {} --帮会基础信息

GUILD_CHANGE_FUND = 1

function getActorVar(actor)
	local actorVar = LActor.getStaticVar(actor)
	if actorVar.guild == nil then
		actorVar.guild = {}
	end
	return actorVar.guild
end


function getRoleVar(actor)
	local actorVar = LActor.getStaticVar(actor)

	local actorGuildVar = actorVar.guildrole
	if actorGuildVar == nil then
		actorVar.guildrole = {}
		actorGuildVar = actorVar.guildrole
	end

	return actorGuildVar
end

function sendBasicInfo(actor)
	local actorGuildVar = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_BasicInfo)
    LDataPack.writeDouble(pack, actorGuildVar.contrib or 0)
    LDataPack.writeInt(pack, actorGuildVar.totalgx or 0)
    LDataPack.writeByte(pack, LActor.getGuildPos(actor))
    LDataPack.flush(pack)
end

function sendMemBasicInfo(sId, actorid)
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendMemberBasicInfo)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeInt(npack, LGuild.getTotalGx(actorid))
	System.sendPacketToAllGameClient(npack, sId)
end

local function onSendMemberBasicInfo(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorid)
	if not actor then return end

	local actorGuildVar = getActorVar(actor)
	actorGuildVar.totalgx = LDataPack.readInt(cpack)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_BasicInfo)
    LDataPack.writeDouble(pack, actorGuildVar.contrib or 0)
    LDataPack.writeInt(pack, actorGuildVar.totalgx or 0)
    LDataPack.writeByte(pack, LActor.getGuildPos(actor))
    LDataPack.flush(pack)
end

-- 增加公会贡献
function changeContrib(actor, value, log)
	if value == 0 then return end

	local actorGuildVar = getActorVar(actor)
	local newValue = (actorGuildVar.contrib or 0) + value
	if newValue < 0 then
		newValue = 0
	end
	actorGuildVar.contrib = newValue


	-- LActor.log(actor, "guildcommon.changeContrib", "make1", actorGuildVar.contrib)
	if System.isCommSrv() then
		if value > 0 then
			actorGuildVar.totalgx = (actorGuildVar.totalgx or 0) + value
			if actorGuildVar.totalgx < 0 then
				actorGuildVar.totalgx = 0
			end
			local npack = LDataPack.allocPacket()
			LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
			LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_ChangeMemberGx)
			LDataPack.writeInt(npack, LActor.getActorId(actor))
			LDataPack.writeInt(npack, value)
			System.sendPacketToAllGameClient(npack, 0)
		else
			sendBasicInfo(actor)
		end
	end

	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "guild", tostring(value), tostring(newValue), "contrib", log or "")
end

local function onChangeMemberGx(sId, sType, cpack)
	if not System.isBattleSrv() then return end
	local actorid = LDataPack.readInt(cpack)
	local value = LDataPack.readInt(cpack)
	LGuild.changeTotalGx(actorid, value)
	sendMemBasicInfo(sId, actorid)
end

function getContrib(actor)
	local actorGuildVar = getActorVar(actor)
	return actorGuildVar.contrib or 0
end

-- 重置玩家的公会贡献
function resetContrib(actor)
	local actorGuildVar = getActorVar(actor)
	actorGuildVar.contrib = 0
	-- LActor.setTotalGx(actor, 0)
end

-- 修改公会资金
function changeGuildFund(guildId, value, actor, log)
	if value == 0 then return end
	if guildId == 0 then return end

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_ChangeGuildFund)
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeInt(npack, value)
	System.sendPacketToAllGameClient(npack, 0)
end

local function onChangeGuildFund(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)
	local value = LDataPack.readInt(cpack)
	crossChangeGuildFund(actorid, guildId, value)
	--local guildId = LGuild.getGuildId(guild)
	--System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "guild", tostring(value), "", "guildfund", log or "", tostring(guildId))
end

function crossChangeGuildFund(actorid, guildId, value)
	local guild = LGuild.getGuildById(guildId)
	if not guild then
		return
	end
	local guildVar = LGuild.getStaticVar(guild, true)
	local newValue = (guildVar.fund or 0) + value
	if newValue < 0 then
		newValue = 0
	end
	guildVar.fund = newValue

	sendGuildBasicInfo(actorid, GUILD_CHANGE_FUND)
end

function getGuildFundById(guildId)
	if GUILD_BASIC_INFO[guildId] then
		return GUILD_BASIC_INFO[guildId].fund
	end
	return 0
end

function getGuildFund(guild)
	local guildVar = LGuild.getStaticVar(guild, true)
	return guildVar.fund
end

function initGuild(guild, buildingLevels)
	local guildVar = LGuild.getStaticVar(guild, true)
	guildVar.building = {}
	guildVar.buildinglevelup = {}

	local buildingVar = guildVar.building
	local levelupVar = guildVar.buildinglevelup
	local nowtime = System.getNowTime()
	for i=1,#buildingLevels do
		buildingVar[i] = buildingLevels[i] or 1
		levelupVar[i] = nowtime
		System.log("guildcommon", "initGuild", "mark1", LGuild.getGuildId(guild), buildingVar[i], nowtime)
	end

	LGuild.setGuildLevel(guild, buildingVar[1], nowtime)
	LGuild.updateGuildRank(guild)
end

function getBuildingLevel(guild, index)
	local guildVar = LGuild.getStaticVar(guild)
	local building = guildVar.building
	if building == nil then return 0 end
	return building[index] or 0
end

function getBuildingLevelById(guildId, index)
	if GUILD_BASIC_INFO[guildId] then
		return GUILD_BASIC_INFO[guildId].building[index] or 0
	end
	return 0
end

function updateBuildingLevel(guild, index, level)
	local guildVar = LGuild.getStaticVar(guild, true)

	if guildVar.building == nil then guildVar.building = {} end
	if guildVar.buildinglevelup == nil then guildVar.buildinglevelup = {} end

	local building = guildVar.building
	local levelup = guildVar.buildinglevelup

	building[index] = level
	levelup[index] = System.getNowTime()

	System.log("guildcommon", "updateBuildingLevel", "mark1", LGuild.getGuildId(guild), building[index], levelup[index], index)
	if index == 1 then
		LGuild.setGuildLevel(guild, level, levelup[index])
		LGuild.updateGuildRank(guild)
	end
	sendGuildBasicInfo()
end

function getGuildLevel(guild)
	return getBuildingLevel(guild, 1)
end

function initBuildingLevel(guild,buildingLevels)
	local guildVar = LGuild.getStaticVar(guild)

	--这个是后加的
	if not guildVar.buildinglevelup then guildVar.buildinglevelup = {} end
	if not guildVar.building then guildVar.building = {} end
	local buildingVar = guildVar.building
	local levelupVar = guildVar.buildinglevelup

	for i=1,#buildingLevels do
		buildingVar[i] = buildingVar[i] or buildingLevels[i] or 1
		levelupVar[i] = levelupVar[i] or 0
	end
	System.log("guildcommon", "initBuildingLevel", "mark1", LGuild.getGuildId(guild), buildingVar[1], levelupVar[1], buildingLevels)
	LGuild.setGuildLevel(guild, buildingVar[1] or 1, levelupVar[1] or 0)
	LGuild.updateGuildRank(guild)
end

function gmRefreshGuildLevelUpTime(guild, time)
	local guildVar = LGuild.getStaticVar(guild, true)

	if guildVar.building == nil then guildVar.building = {} end
	if guildVar.buildinglevelup == nil then guildVar.buildinglevelup = {} end

	local building = guildVar.building
	local levelup = guildVar.buildinglevelup

	levelup[1] = time
	local level = building[1] or 1
	LGuild.setGuildLevel(guild, level, time)
	LGuild.updateGuildRank(guild)
end

function getGuilNameById(guildId)
	return GUILD_BASIC_INFO[guildId] and GUILD_BASIC_INFO[guildId].name or ""
end

local function onSendBasicInfo(sId, sType, cpack)
	local count = LDataPack.readShort(cpack)
	GUILD_BASIC_INFO = {}
	for i=1, count do
		local guildId = LDataPack.readInt(cpack)
		GUILD_BASIC_INFO[guildId] = {}
		GUILD_BASIC_INFO[guildId].name = LDataPack.readString(cpack)
		GUILD_BASIC_INFO[guildId].fund = LDataPack.readInt(cpack)
		GUILD_BASIC_INFO[guildId].building = {}
		for j=1, #GuildLevelConfig do					
			GUILD_BASIC_INFO[guildId].building[j] = LDataPack.readByte(cpack)
		end
	end
	local actorid = LDataPack.readInt(cpack)
	if actorid == 0 then return end
	local actor = LActor.getActorById(actorid)
	if actor then
		local args = LDataPack.readByte(cpack)
		if args == GUILD_CHANGE_FUND then
			local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_FundChanged)
			LDataPack.writeInt(pack, GUILD_BASIC_INFO[LActor.getGuildId(actor)] and GUILD_BASIC_INFO[LActor.getGuildId(actor)].fund or 0)
			LDataPack.flush(pack)
		end
	end
end

function sendGuildBasicInfo(actorid, args)
	local guildList = LGuild.getGuildList()
	if guildList == nil then return end

	local count = 0
	for i=1,#guildList do
		local guild = guildList[i]
		if guild then 
			count = count + 1
		end
	end
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendBasicInfo)
	LDataPack.writeShort(npack, count)
	for i=1,#guildList do
		local guild = guildList[i]
		if guild then 
			LDataPack.writeInt(npack, LGuild.getGuildId(guild))
			LDataPack.writeString(npack, LGuild.getGuildName(guild))
			local guildVar = LGuild.getStaticVar(guild)
			LDataPack.writeInt(npack, guildVar.fund or 0)			
			local building = guildVar.building
			for i=1, #GuildLevelConfig do
				LDataPack.writeByte(npack, building and building[i] or 0)
			end
		end
	end
	LDataPack.writeInt(npack, actorid or 0)
	LDataPack.writeByte(npack, args or 0)
	System.sendPacketToAllGameClient(npack, 0)
end

function onConnected(sId, sType)
    if not System.isBattleSrv() then return end
	sendGuildBasicInfo(sId)
end



csbase.RegConnected(onConnected)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendBasicInfo, onSendBasicInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendMemberBasicInfo, onSendMemberBasicInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_ChangeMemberGx, onChangeMemberGx)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_ChangeGuildFund, onChangeGuildFund)
