-- 公会技能

module("guildskill", package.seeall)

local LActor = LActor
local System = System
local LDataPack = LDataPack
local systemId = Protocol.CMD_Guild
local common = guildcommon
local SKILL_BUILDING_INDEX = 2 -- 练功房的建筑索引

local function updataAttrs(actor, calc)
	local attrs = LActor.getGuildSkillAttrs(actor)
	if attrs == nil then return end

	local roleVar = common.getRoleVar(actor)

	attrs:Reset()
	
	local commonSkills = roleVar.commonSkills
	if commonSkills ~= nil then
		for skillIdx=1,#GuildCommonSkillConfig do
			local skillConfig = GuildCommonSkillConfig[skillIdx]
			local level = commonSkills[skillIdx] or 0
			local levelConfig = skillConfig[level]
			if levelConfig ~= nil then
				local attrsConfig = levelConfig.attrs
				for attrIdx=1,#attrsConfig do
					local attrConfig = attrsConfig[attrIdx]
					attrs:Add(attrConfig.type, attrConfig.value)
				end
			end
		end
	end

	local practiceSkills = roleVar.practiceSkills
	if practiceSkills ~= nil then
		for skillIdx=1,#GuildPracticeSkillConfig do
			local skillConfig = GuildPracticeSkillConfig[skillIdx]
			local practiceVar = practiceSkills[skillIdx]
			if practiceVar ~= nil then
				local level = practiceVar.level or 0
				local levelConfig = skillConfig[level]
				if levelConfig ~= nil then
					local attrsConfig = levelConfig.attrs
					for attrIdx=1,#attrsConfig do
						local attrConfig = attrsConfig[attrIdx]
						attrs:Add(attrConfig.type, attrConfig.value)
					end
				end
			end
		end
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

-- 升级技能
function updateSkill(actor, index)

	local skillConfig = GuildCommonSkillConfig[index]
	if skillConfig == nil then
		print("upgrade common skill index error:"..index)
		return 
	end 

	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then
		print("guild is nil")
		return 
	end

	local buildingLevel = common.getBuildingLevelById(guildId, SKILL_BUILDING_INDEX)
	local roleVar = common.getRoleVar(actor)
	if roleVar == nil then print("roleVar is nil") return end
	local commonSkills = roleVar.commonSkills
	if commonSkills == nil then
		roleVar.commonSkills = {}
		commonSkills = roleVar.commonSkills
	end

	-- 判断技能是否达到当前公会上限
	local levelLimit = GuildConfig.commonSkillLevels[buildingLevel] or 0
	local level = commonSkills[index] or 0 
	if level >= levelLimit then
		utils.printInfo("level limit", buildingLevel, level, levelLimit)
		return 
	end

	local nextLevel = level + 1
	if nextLevel > #skillConfig then
		print("level limit2")
		return 
	end

	local nextLevelConfig = skillConfig[nextLevel]
	if not actoritem.checkItem(actor, NumericType_Gold, nextLevelConfig.money) then
		print("not gold")
		return
	end
	if not actoritem.checkItem(actor, NumericType_GuildContrib, nextLevelConfig.contribute) then
		print("not contribute")
		return
	end

	actoritem.reduceItem(actor, NumericType_Gold, nextLevelConfig.money, "upgrade guild skill")
	actoritem.reduceItem(actor, NumericType_GuildContrib, nextLevelConfig.contribute, "UpgradeSkill")

	--普通技能升级
	commonSkills[index] = nextLevel
	updataAttrs(actor, true)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_UpgradeSkill)
	LDataPack.writeShort(pack, 0)
	LDataPack.writeByte(pack, index)
	LDataPack.writeInt(pack, nextLevel)
	LDataPack.flush(pack)
end

-- 修炼技能
function updatePracticeSkill(actor, index)
	local skillConfig = GuildPracticeSkillConfig[index]

	if skillConfig == nil then
		print("upgrade guild pracetice index error:"..index)
		return 
	end 

	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then
		print("guild is nil")
		return 
	end

	local buildingLevel = common.getBuildingLevelById(guildId, SKILL_BUILDING_INDEX)

	local roleVar = common.getRoleVar(actor)
	if roleVar == nil then print("roleVar is nil") return end
	local practiceSkills = roleVar.practiceSkills
	if practiceSkills == nil then
		roleVar.practiceSkills = {}
		practiceSkills = roleVar.practiceSkills
	end

	-- 判断技能是否达到当前公会上限
	local levelLimit = GuildConfig.practiceSkillLevels[buildingLevel] or 0
	local skillVar = practiceSkills[index]
	if skillVar == nil then
		practiceSkills[index] = {}
		skillVar = practiceSkills[index]
	end
	local level = skillVar.level or 0
	if level >= levelLimit then
		print("level limit")
		return 
	end

	local nextLevel = level + 1
	if nextLevel > #skillConfig then
		print("level limit2")
		return 
	end

	local nextLevelConfig = skillConfig[nextLevel]
	if not actoritem.checkItem(actor, NumericType_Gold, nextLevelConfig.money) then
		return
	end
	if not actoritem.checkItem(actor, NumericType_GuildContrib, nextLevelConfig.contribute) then
		return
	end

	actoritem.reduceItem(actor, NumericType_Gold, nextLevelConfig.money, "upgrade practice skill")
	actoritem.reduceItem(actor, NumericType_GuildContrib, nextLevelConfig.contribute, "PracticeSkill")

	--修炼技能升级
	local exp = skillVar.exp or 0
	exp = exp + nextLevelConfig.exp
	if exp >= nextLevelConfig.upExp then
		skillVar.level = level + 1
		exp = exp - nextLevelConfig.upExp
	end
	skillVar.exp = exp
	updataAttrs(actor, true)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_PracticeBuilding)
	LDataPack.writeShort(pack, 0)
	LDataPack.writeByte(pack, index)
	LDataPack.writeInt(pack, skillVar.level or 0)
	LDataPack.writeInt(pack, exp)
	LDataPack.writeInt(pack, nextLevelConfig.exp)
	LDataPack.flush(pack)
end

-------------------------------------------------------------------------------------------------------
-- 获取公会技能信息
function handleSkillInfo(actor, packet)
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_SkillInfo)
	LDataPack.writeByte(pack, 1)
	local roleVar = common.getRoleVar(actor)
	LDataPack.writeByte(pack, GuildConfig.commonSkillCount)
	local commonSkills = roleVar.commonSkills or {}
	for skillIdx=1,GuildConfig.commonSkillCount do
		LDataPack.writeInt(pack, commonSkills[skillIdx] or 0)
	end

	LDataPack.writeByte(pack, GuildConfig.practiceSkillCount)
	local practiceSkills = roleVar.practiceSkills or {}
	for skillIdx=1,GuildConfig.practiceSkillCount do
		local practiceVar = practiceSkills[skillIdx] or {}
		LDataPack.writeInt(pack, practiceVar.level or 0)
		LDataPack.writeInt(pack, practiceVar.exp or 0)
	end
	LDataPack.flush(pack)
end

--升级普通技能
function handleUpgradeSkill(actor, packet)
	local roleId = LDataPack.readShort(packet) -- 角色ID
	local index = LDataPack.readByte(packet) -- 第几个技能，从1开始
	updateSkill(actor, index)
end

--升级修炼技能
function handlePracticeSkill(actor, packet)
	local roleId = LDataPack.readShort(packet) -- 角色ID
	local index = LDataPack.readByte(packet) -- 第几个技能，从1开始
	updatePracticeSkill(actor, index)
end

function onLogin(actor)
	handleSkillInfo(actor)
end

function onInit(actor)
	updataAttrs(actor, false)
end

function onJoinGuild(actor)
	handleSkillInfo(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeJoinGuild, onJoinGuild)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.guildskillinfo = function (actor, args)
	handleSkillInfo(actor)
end

gmCmdHandlers.guildskillupdate = function (actor, args)
	local roleId = tonumber(args[1])
	local index = tonumber(args[2])

	local pack = LDataPack.allocPacket()
	LDataPack.writeShort(pack, roleId)
	LDataPack.writeByte(pack, index)
	LDataPack.setPosition(pack, 0)
	handleUpgradeSkill(actor, pack)

	--updateSkill(actor, roleId, index)
end

gmCmdHandlers.guildskillpractice = function (actor, args)
	local roleId = tonumber(args[1])
	local index = tonumber(args[2])
	local expadd = tonumber(args[3])

	local roleVar = common.getRoleVar(actor)
	if not roleVar.practiceSkills then
		roleVar.practiceSkills = {}
	end
	local practiceSkills = roleVar.practiceSkills
	local skillVar = practiceSkills[index]
	if skillVar == nil then
		practiceSkills[index] = {}
		skillVar = practiceSkills[index]
	end
	local skillConfig = GuildPracticeSkillConfig[index]
	local nextLevelConfig = skillConfig[(skillVar.level or 0)+1]
	local exp = (skillVar.exp or 0 )+ expadd
	if exp >= nextLevelConfig.upExp then
		skillVar.level = (skillVar.level or 0) + 1
		exp = exp - nextLevelConfig.upExp
	end
	skillVar.exp = exp
	updataAttrs(actor, true)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_PracticeBuilding)
	LDataPack.writeShort(pack, 0)
    LDataPack.writeByte(pack, index)
    LDataPack.writeInt(pack, skillVar.level or 0)
    LDataPack.writeInt(pack, exp)
    LDataPack.writeInt(pack, nextLevelConfig.exp)
    LDataPack.flush(pack)
end

gmCmdHandlers.guildskillAll = function (actor, args)
	local roleId = 0
	local roleVar = common.getRoleVar(actor)
	if roleVar.commonSkills == nil then
		roleVar.commonSkills = {}
	end
	local commonSkills = roleVar.commonSkills
	for index,conf in pairs(GuildCommonSkillConfig) do
		local maxlevel = #conf
		commonSkills[index] = maxlevel
	end

	if roleVar.practiceSkills == nil then
		roleVar.practiceSkills = {}
	end
	local practiceSkills = roleVar.practiceSkills
	for index,conf in pairs(GuildPracticeSkillConfig) do
		local maxlevel = #conf
		if practiceSkills[index] == nil then
			practiceSkills[index] = {}
		end
		local skillVar = practiceSkills[index]
		skillVar.level = maxlevel
	end
	updataAttrs(actor, true)	
	onLogin(actor)
end
