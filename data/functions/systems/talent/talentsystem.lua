--天赋系统

module( "talentsystem", package.seeall )

require("talent.talentbaseconfig")
require("talent.talentlevelconfig")
require("talent.talentjobconfig")

function getActorVar(actor, roleId)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var.talentData then var.talentData = {} end
	if not var.talentData[roleId] then 
		var.talentData[roleId] = {} 
		var.talentData[roleId].point = 0
		var.talentData[roleId].data = {}
		var.talentData[roleId].data.skillIndex = 1
		var.talentData[roleId].data.skillLevel = 0
		var.talentData[roleId].data.curCnt = 0
	end
	local talentData = var.talentData[roleId]
	return talentData
end

function getTalentLv(var, index)	
	local stagelv = var.data.skillLevel > 0 and (var.data.skillLevel * 5 + var.data.skillIndex - 1) or (var.data.skillIndex - 1)
	local lv = 0
	lv = lv + stagelv * TalentConstConfig.needcnt + getCurTalentLv(var, index)
	return lv
end

function getCurTalentLv(var, index)	
	local lv = 0
	if index * TalentConstConfig.needcnt <= var.data.curCnt then
		lv = TalentConstConfig.needcnt
	elseif index * TalentConstConfig.needcnt > var.data.curCnt and (index - 1) * TalentConstConfig.needcnt < var.data.curCnt then
		lv = var.data.curCnt % TalentConstConfig.needcnt
	end
	return lv
end

function addTalentAttr(actor, roleId)
	local role = LActor.getRole(actor, roleId)
	local jobId = LActor.getJob(role)
	local var = getActorVar(actor, roleId)
	if not var then	return end
	local attrs = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Talent)
	attrs:Reset()
	--天赋属性加成
	for index, id in pairs(TalentJobConfig[jobId][1].talentId) do				
		local talentlv = getTalentLv(var, index)
		local attr = TalentLevelConfig[id][talentlv].attr
		attrs:Add(attr.type, attr.value)
	end
	
	--天赋战斗力
	local power = 0 --天赋战斗力	
	for k, id in pairs(TalentJobConfig[jobId][2].talentId) do
		local stagelv = var.data.skillIndex > k and var.data.skillLevel + 1 or var.data.skillLevel
		repeat
			if stagelv <= 0 then break end
			local conf = TalentLevelConfig[id][stagelv]				
			if not conf then break end
			local skillId = TalentBaseConfig[id].skillId
			local skillPlus = conf.attr
			actorcommon.refreshSkillParam(actor, roleId, skillId, SkillParamSysId_Talent, skillPlus)
			power = power + conf.power			
		until(true)
	end
	attrs:SetExtraPower(power)
end

function updateAttr(actor, roleId, index)	
	addTalentAttr(actor, roleId)
	local role = LActor.getRole(actor, roleId)
	local jobId = LActor.getJob(role)
	local skillId = TalentBaseConfig[TalentJobConfig[jobId][2].talentId[index]].skillId
	LActor.refreshOneRoleOneSkillParam(actor, roleId, skillId)
	LActor.reCalcRoleAttr(actor, roleId)
end

--取所有角色中天赋最高为多少级
function getMaxTalentLevel(actor)
	local ret = 0
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		local role = LActor.getRole(actor, roleId)
		local jobId = LActor.getJob(role)
		local var = getActorVar(actor, roleId)
		local sum = 0
		for k, id in pairs(TalentJobConfig[jobId][1].talentId) do
			sum = sum + (var.data[id] or 0)
		end
		for k, id in pairs(TalentJobConfig[jobId][2].talentId) do
			sum = sum + (var.data[id] or 0)
		end
		ret = math.max(ret, sum)
	end
	return ret
end

--取得一个天赋类中的总等级
function getTalentTypePoint(actor, roleId, tp)
	local var = getActorVar(actor, roleId)
	local role = LActor.getRole(actor, roleId)
	local jobId = LActor.getJob(role)
	local sum = 0
	for k, id in pairs(TalentJobConfig[jobId][tp].talentId) do
		sum = sum + (var.data[id] or 0)
	end
	return sum
end

--该等级该拥有天赋点
function getPointByLevel(actor, roleId)
	local role = LActor.getRole(actor, roleId)
	local jobId = LActor.getJob(role)
	local level = LActor.getLevel(actor)
	local zhuanshengLevel = LActor.getZhuanShengLevel(actor)
	local zsPoint = 0
	for i = 1, zhuanshengLevel do
		zsPoint = zsPoint + ZhuanshengLevelConfig[i].talentPoint
	end
	local point = RoleConfig[jobId][level].talentPoint
	return point + zsPoint
end

function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		addTalentAttr(actor, roleId)
	end
end

function onLogin(actor)
	s2cTalentInfo(actor)
end

function onLevelUp(actor, level, oldLevel)
	if level <= 1 then
		return
	end
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		local role = LActor.getRole(actor, roleId)
		local jobId = LActor.getJob(role)
		if RoleConfig[jobId][level].talentPoint == 0 then --还没有天赋点
			return
		end
		local add = RoleConfig[jobId][level].talentPoint - RoleConfig[jobId][oldLevel].talentPoint
		local var = getActorVar(actor, roleId)
		var.point = var.point + add --升级时获得天赋点
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Job, Protocol.sTalentCmd_Update)
	if pack == nil then return end
	LDataPack.writeInt(pack, count)
	for roleId = 0, count-1 do
		local var = getActorVar(actor, roleId)
		LDataPack.writeInt(pack, var.point)
	end
	LDataPack.flush(pack)
end

function onZhuansheng(actor, zhuanshengLevel)
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		local role = LActor.getRole(actor, roleId)
		local jobId = LActor.getJob(role)
		local var = getActorVar(actor, roleId)
		var.point = var.point + ZhuanshengLevelConfig[zhuanshengLevel].talentPoint
	end
	if zhuanshengLevel > 4 then
		s2cTalentInfo(actor)
	end
end

function onCreateRole(actor, roleId)
	local point = getPointByLevel(actor, roleId)
	local var = getActorVar(actor, roleId)
	var.point = point
	s2cTalentInfo(actor)
end

------------------------------------------------------------------------------------
--查看天赋信息
function c2sTalentInfo(actor, packet)
	s2cTalentInfo(actor)
end

--返回天赋信息
function s2cTalentInfo(actor, packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.dashi) then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Job, Protocol.sTalentCmd_Info)
	if pack == nil then return end
	local count = LActor.getRoleCount(actor)
	LDataPack.writeInt(pack, count)
	for roleId = 0, count-1 do
		local role = LActor.getRole(actor, roleId)
		local jobId = LActor.getJob(role)
		local var = getActorVar(actor, roleId)
		LDataPack.writeShort(pack, roleId)
		LDataPack.writeInt(pack, var.point)
		LDataPack.writeByte(pack, var.data.skillIndex - 1)
		LDataPack.writeByte(pack, var.data.skillLevel)
		for i=1, SkillsLen_Max do
			local lv = getCurTalentLv(var, i)
			LDataPack.writeShort(pack, lv)
			LDataPack.writeByte(pack, var.data.skillLevel > 0 and (var.data.skillLevel * 5 + var.data.skillIndex - 1) or (var.data.skillIndex - 1))
		end
	end
	LDataPack.flush(pack)
end

--技能觉醒
function skillWakeUp(actor, roleId)
	local var = getActorVar(actor, roleId)
	local role = LActor.getRole(actor, roleId)
	local jobId = LActor.getJob(role)

	local talentId = TalentJobConfig[jobId][2].talentId[var.data.skillIndex]
	local conf = TalentLevelConfig[talentId][var.data.skillLevel]

	if not TalentLevelConfig[talentId][var.data.skillLevel + 1] then return end --等级超出
	
	if var.point < conf.upLevelConsu then --天赋点不足
		return
	end
	var.point = var.point - conf.upLevelConsu

	var.data.curCnt = 0
	local before = var.data.skillIndex
	var.data.skillIndex = var.data.skillIndex + 1
	if var.data.skillIndex > SkillsLen_Max then
		var.data.skillIndex = 1
		var.data.skillLevel = var.data.skillLevel + 1
	end

	updateAttr(actor, roleId, before)
	sendLevelUpInfo(actor, roleId)
end

--升级天赋
function c2sTalentUpLevel(actor, packet)
	local roleId = LDataPack.readShort(packet)
	local role = LActor.getRole(actor, roleId)
	local jobId = LActor.getJob(role)
	local var = getActorVar(actor, roleId)
	
	local index = math.floor(var.data.curCnt / TalentConstConfig.needcnt) + 1
	local id = 0
	if var.data.curCnt >= #TalentJobConfig[jobId][1].talentId * TalentConstConfig.needcnt then --觉醒技能
		skillWakeUp(actor, roleId)
		return
	else --升级天赋
		id = TalentJobConfig[jobId][1].talentId[index]
	end

	if not TalentLevelConfig[id] then return end
	local lv = getTalentLv(var, index)
	local conf = TalentLevelConfig[id][lv] 
	if not TalentLevelConfig[id][lv+1] then return end --等级超出
	
	if var.point < conf.upLevelConsu then --天赋点不足
		return
	end

	var.point = var.point - conf.upLevelConsu
	var.data.curCnt = var.data.curCnt + 1
	actorevent.onEvent(actor, aeTalentUp, id, lv)
	
	updateAttr(actor, roleId, index)
	sendLevelUpInfo(actor, roleId)

	utils.logCounter(actor, "talent level", roleId, id, var.data[id])
end

function sendLevelUpInfo(actor, roleId)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Job, Protocol.sTalentCmd_Uplevel)
	if pack == nil then return end
	local var = getActorVar(actor, roleId)
	LDataPack.writeShort(pack, roleId)
	LDataPack.writeInt(pack, var.point)
	LDataPack.writeInt(pack, var.data.skillIndex - 1)
	LDataPack.writeChar(pack, var.data.skillLevel)
	for i=1, SkillsLen_Max do
		local lv = getCurTalentLv(var, i)
		LDataPack.writeShort(pack, lv)
		LDataPack.writeByte(pack, var.data.skillLevel > 0 and (var.data.skillLevel * 5 + var.data.skillIndex - 1) or (var.data.skillIndex - 1))
	end
	LDataPack.flush(pack)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeLevel, onLevelUp)
actorevent.reg(aeZhuansheng, onZhuansheng)
actorevent.reg(aeCreateRole,onCreateRole)

netmsgdispatcher.reg(Protocol.CMD_Job, Protocol.cTalentCmd_Info, c2sTalentInfo)
netmsgdispatcher.reg(Protocol.CMD_Job, Protocol.cTalentCmd_Uplevel, c2sTalentUpLevel)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.checktalent = function (actor, args)
	s2cTalentInfo(actor)
	return true
end

