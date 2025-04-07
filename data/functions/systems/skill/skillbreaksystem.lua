--技能突破系统
--@rancho 20180116
module("skillbreaksystem", package.seeall)


local function getActorData( actor )
	local var =  LActor.getStaticVar(actor)
	if not var.skillBreak then var.skillBreak = {} end
	local skillBreak = var.skillBreak
	
	skillBreak.isInit = 0
	
	if not skillBreak.roleDatas then skillBreak.roleDatas = {} end
	local roleDatas = skillBreak.roleDatas
	for i = 1, MAX_ROLE do
		if not roleDatas[i] then roleDatas[i] = {} end
	end
	
	return skillBreak
end

local function getRoleData( actor, roleId )
	local skillBreak = getActorData(actor)
	return skillBreak.roleDatas[roleId + 1]
end

local function isOpen( actor )
	return actorexp.checkLevelCondition(actor, actorexp.LimitTp.element)
end

local function refreshSkillParam(actor)
	local skillBreak = getActorData(actor)
	local roleDatas = skillBreak.roleDatas
	local roleCount = LActor.getRoleCount(actor)
	for i = 1, roleCount do
		local roleId = i - 1
		local oneRoleData = roleDatas[i]
		local power = 0
		for j = 1, #oneRoleData do
			repeat
				local oneSkillData = oneRoleData[j]
				if oneSkillData.level <= 0 then break end
				local config = SkillBreakConfig[oneSkillData.skillId]
				if not config then break end
				local levelConfig = config[oneSkillData.level]
				if not levelConfig then break end
				local skillPlus = levelConfig.skillPlus
				actorcommon.refreshSkillParam(actor, roleId, oneSkillData.skillId, SkillParamSysId_Break, skillPlus)
				power = power + levelConfig.score
			until(true)
		end
		local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_SkillBreak)
		attr:Reset()
		attr:SetExtraPower(power)
	end
	LActor.refreshSkillParam(actor)
end

local function refreshOneRoleOneSkillParam(actor, roleId, skillId)
	local role = LActor.getRole(actor, roleId)
	local oneRoleData = getRoleData(actor, roleId)
	local power = 0
	for j = 1, #oneRoleData do
		repeat
			local oneSkillData = oneRoleData[j]
			if oneSkillData.level <= 0 then break end
			local config = SkillBreakConfig[oneSkillData.skillId]
			if not config then break end
			local levelConfig = config[oneSkillData.level]
			if not levelConfig then break end
			power = power + levelConfig.score
			if oneSkillData.skillId ~= skillId then break end
			local skillPlus = levelConfig.skillPlus
			actorcommon.refreshSkillParam(actor, roleId, oneSkillData.skillId, SkillParamSysId_Break, skillPlus)
		until(true)
	end

	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_SkillBreak)
	attr:Reset()
	attr:SetExtraPower(power)

	LActor.refreshOneRoleOneSkillParam(actor, roleId, skillId)
	LActor.reCalcRoleAttr(actor, roleId)
end

local function sendData( actor )
	local skillBreak = getActorData(actor)
	local roleDatas = skillBreak.roleDatas
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_SkillBreakData)
	if not pack then return end
	local roleCount = LActor.getRoleCount(actor)
	LDataPack.writeByte(pack, roleCount)
	for i = 1, roleCount do
		LDataPack.writeByte(pack, i - 1)
		local oneRoleData = roleDatas[i]
		local skillCount = #oneRoleData
		LDataPack.writeByte(pack, skillCount)
		for j = 1, skillCount do
			local oneSkillData = oneRoleData[j]
			LDataPack.writeInt(pack, oneSkillData.skillId)
			LDataPack.writeByte(pack, oneSkillData.level)
		end
	end
	LDataPack.flush(pack)
end

local function sendUpdateData( actor, roleId, skillId, level )
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_SkillBreakUpdate)
	if not pack then return end
	LDataPack.writeByte(pack, roleId)
	LDataPack.writeInt(pack, skillId)
	LDataPack.writeByte(pack, level)
	LDataPack.flush(pack)
end

local function reqSkillBreak( actor, pack )
	if not isOpen(actor) then return end

	local roleId = LDataPack.readByte(pack)
	local skillId = LDataPack.readInt(pack)

	local oneRoleData = getRoleData(actor, roleId)
	if oneRoleData == nil then return end
	local oneSkillData = nil
	for i = 1, #oneRoleData do
		if skillId == oneRoleData[i].skillId then
			oneSkillData = oneRoleData[i]
			break
		end
	end
	if oneSkillData == nil then return end

	local config = SkillBreakConfig[skillId]
	if config == nil then return end
	if oneSkillData.level >= #config then return end

	local levelConfig = config[oneSkillData.level]

	if not actoritem.checkItems(actor, levelConfig.costItems) then
		log_print(LActor.getActorId(actor) .. " skillbreaksystem.reqSkillBreak: not enough items")
		return
	end
	actoritem.reduceItems(actor, levelConfig.costItems, "skill break")

	oneSkillData.level = oneSkillData.level + 1

	sendUpdateData(actor, roleId, skillId, oneSkillData.level)

	refreshOneRoleOneSkillParam(actor, roleId, skillId)
end

local function skillLearn( actor, roleId, skillId )
	local oneRoleData = getRoleData(actor, roleId)
	for i = 1, #oneRoleData do
		if skillId == oneRoleData[i].skillId then
			return
		end
	end

	local index = #oneRoleData + 1
	oneRoleData[index] = {}
	oneRoleData[index].skillId = skillId
	oneRoleData[index].level = 0
end

local function onInit( actor )
	local skillBreak = getActorData(actor)
	if skillBreak.isInit == 0 then
		local roleCount = LActor.getRoleCount(actor)
		for i = 0, roleCount - 1 do
			local roleData = LActor.getRoleData(actor, i)
			local skillsData = roleData.skills.skill_level
			for j = 1, SkillsLen_Max do
				repeat
					if skillsData[j - 1] <= 0 then break end
					local skillId = actorcommon.getSkillId(roleData.job, j)
					if not SkillBreakConfig[skillId] then break end
					skillLearn(actor, i, skillId)	
				until(true)	
			end
		end
		skillBreak.isInit = 1
	end

	refreshSkillParam(actor)
end

local function onLogin( actor )
	sendData(actor)
end

local function onSkillLearn(actor, roleId, index, skillId )
	skillLearn(actor, roleId, skillId)
	sendUpdateData(actor, roleId, skillId, 0)
end

local function onCreateRole(actor, roleId)
	local roleData = LActor.getRoleData(actor, roleId)
	local skillsData = roleData.skills.skill_level
	for j = 1, SkillsLen_Max do
		repeat
			if skillsData[j - 1] <= 0 then break end
			local skillId = actorcommon.getSkillId(roleData.job, j)
			if not SkillBreakConfig[skillId] then break end
			skillLearn(actor, roleId, skillId)	
		until(true)	
	end
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeSkillLevelup, onSkillLearn)
actorevent.reg(aeCreateRole, onCreateRole)

netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_ReqSkillBreak, reqSkillBreak)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.setbreaklevel = function (actor, args)
	local level = tonumber(args[1])
	local skillBreak = getActorData(actor)
	local roleDatas = skillBreak.roleDatas
	for i = 1, #roleDatas do
		for j = 1, #roleDatas[i] do
			roleDatas[i][j].level = level
		end
	end
	refreshSkillParam(actor)
	sendData(actor)
	return true
end

gmCmdHandlers.clearbreak = function ( actor, args )
	local var =  LActor.getStaticVar(actor)
	var.skillBreak = {}
	onInit(actor)
end 

