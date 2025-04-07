-- -- @version	1.0
-- -- @author	qianmeng
-- -- @date	2018-4-27 16:54:11.
-- -- @system	重生天赋

-- module("innate" , package.seeall)
-- require("zhuansheng.innatelevel")
-- require("zhuansheng.innateskill")

-- function getActorVar(actor)
-- 	local var = LActor.getStaticVar(actor)
-- 	if not var then return end
-- 	if not var.innateData then var.innateData = {} end
-- 	if not var.innateData.points then var.innateData.points = {} end
-- 	return var.innateData
-- end

-- function setInnate(actor, roleId, slot, level)
-- 	local var = getActorVar(actor)
-- 	if not var then return end
-- 	if not var[roleId] then	
-- 		var[roleId] = {}
-- 	end
-- 	var[roleId][slot] = level
-- 	updateAttr(actor, roleId, true)
-- end

-- function getInnate(actor, roleId, slot)
-- 	local var = getActorVar(actor)
-- 	if var and var[roleId] and var[roleId][slot] then
-- 		return var[roleId][slot]
-- 	end
-- 	return 0
-- end

-- function getVarInnate(var, roleId, slot)
-- 	if var and var[roleId] and var[roleId][slot] then
-- 		return var[roleId][slot]
-- 	end
-- 	return 0
-- end

-- local function getInnateSkillId(job)
-- 	return job * 100 + 7
-- end

-- --更新属性
-- function updateAttr(actor, roleId, calc)
-- 	local addAttrs = {}
-- 	local role = LActor.getRole(actor)
-- 	local var = getActorVar(actor)

-- 	local role = LActor.getRole(actor)
-- 	local job = LActor.getJob(role)
-- 	local minLv = 1000 --最低天赋等级(先默认取最大值）
-- 	for slot, v in pairs(InnateLevelConfig[job]) do
-- 		local lv = getVarInnate(var, roleId, slot)
-- 		if lv > 0 and v[lv] then
-- 			for k1, attr in pairs(v[lv].attr) do
-- 				addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
-- 			end
-- 		end
-- 		minLv = math.min(minLv, lv)
-- 	end

-- 	local skLv = minLv > 0 and (math.floor(minLv/10) + 1) or 0--重生技能等级，全激活天赋时为1，然后每整十数时+1
-- 	local conf = InnateSkillConfig[job] and InnateSkillConfig[job][skLv]
-- 	if skLv > 0 and conf then
-- 		LActor.learnSkill(actor, roleId, getInnateSkillId(job))
-- 		actorcommon.refreshSkillParam(actor, roleId, conf.skill, SkillParamSysId_Innate, conf.skillPlus)
-- 		LActor.refreshOneRoleOneSkillParam(actor, roleId, conf.skill)
-- 	end

-- 	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Innate)
-- 	attr:Reset()
-- 	for k, v in pairs(addAttrs) do
-- 		attr:Set(k, v)
-- 	end
-- 	if calc then
-- 		LActor.reCalcAttr(actor, roleId)
-- 	end
-- end

-- function addInnatePoint(actor, point)
-- 	local var = getActorVar(actor)
-- 	for i = 0, 2 do
-- 		var.points[i] = (var.points[i] or 0) + point
-- 	end
-- 	s2cInnatePoint(actor)
-- end

-- function getTotalPoint(actor, roleId)
-- 	local var = getActorVar(actor)
-- 	local role = LActor.getRole(actor)
-- 	local job = LActor.getJob(role)
-- 	local sum = 0
-- 	for slot, config in pairs(InnateLevelConfig[job]) do
-- 		local lv = getVarInnate(var, roleId, slot)
-- 		if lv > 0 and config[lv] then
-- 			sum = sum + config[lv].usePoint
-- 		end
-- 	end
-- 	return sum
-- end

-- -----------------------------------------------------------------------------------------
-- function s2cInnateInfo(actor)
-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Other, Protocol.sInnateCmd_Info)
-- 	if pack == nil then return end
-- 	local var = getActorVar(actor)
-- 	LDataPack.writeChar(pack, 1) --角色数量
-- 	local role = LActor.getRole(actor)
-- 	local job = LActor.getJob(role)
-- 	local minLv = 1000 --最小重生天赋等级（先默认取最大值）
-- 	LDataPack.writeChar(pack, 0) --角色id
-- 	local slotcount = 0
-- 	local slotpos = LDataPack.getPosition(pack)
-- 	LDataPack.writeChar(pack, slotcount) --天赋部位数量
-- 	for slot, config in pairs(InnateLevelConfig[job]) do
-- 		local level = getVarInnate(var, 0, slot)
-- 		minLv = math.min(minLv, level)
-- 		if level > 0 then
-- 			LDataPack.writeChar(pack, slot) 	--天赋部位
-- 			LDataPack.writeShort(pack, level)	--重生天赋等级
-- 			slotcount = slotcount + 1
-- 		end
-- 	end
-- 	if slotcount > 0 then
-- 		local npos = LDataPack.getPosition(pack)
-- 		LDataPack.setPosition(pack, slotpos)
-- 		LDataPack.writeChar(pack, slotcount)
-- 		LDataPack.setPosition(pack, npos)
-- 	end
-- 	local skLv = minLv > 0 and (math.floor(minLv/10) + 1) or 0--重生技能等级，全激活天赋时为1，然后每整十数时+1
-- 	LDataPack.writeInt(pack, getInnateSkillId(job)) --重生技能id
-- 	LDataPack.writeShort(pack, skLv) --重生技能等级
-- 	LDataPack.writeInt(pack, var.points[0] or 0)
-- 	LDataPack.writeInt(pack, getTotalPoint(actor, 0))
-- 	LDataPack.flush(pack)
-- end

-- function c2sInnateUp(actor, packet)
-- 	local roleId = LDataPack.readChar(packet)
-- 	local slot = LDataPack.readChar(packet)
-- 	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.innate) then return end
-- 	local role = LActor.getRole(actor)
-- 	local job = LActor.getJob(role)
-- 	local level = getInnate(actor, roleId, slot)
-- 	local nextLevel = level + 1
-- 	local config = InnateLevelConfig[job][slot]
-- 	if config[level]==nil or config[nextLevel]==nil then
-- 		return
-- 	end
-- 	local conf = config[level]
-- 	local var = getActorVar(actor)
-- 	local total = getTotalPoint(actor, roleId)
-- 	if total < conf.total then return end
-- 	if (var.points[roleId] or 0) < conf.point then return end
-- 	var.points[roleId] = (var.points[roleId] or 0) - conf.point
	
-- 	setInnate(actor, roleId, slot, nextLevel)

-- 	local minLv = 1000 --最小重生天赋等级（先默认取最大值）
-- 	for k, v in pairs(InnateLevelConfig[job]) do
-- 		local level = getVarInnate(var, roleId, k)
-- 		minLv = math.min(minLv, level)
-- 	end
-- 	local skLv = minLv > 0 and (math.floor(minLv/10) + 1) or 0--重生技能等级，全激活天赋时为1，然后每整十数时+1
-- 	s2cInnateUpdate(actor, roleId, slot, nextLevel, var.points[roleId], skLv)
-- 	local extra = string.format("role:%d,slot:%d,level:%d",  roleId, slot, nextLevel)
-- 	utils.logCounter(actor, "othersystem", "", extra, "innate", "uplevel")
-- end

-- --重生天赋更新
-- function s2cInnateUpdate(actor, roleId, slot, nextLevel, point, skLv)
-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Other, Protocol.sInnateCmd_Up)
-- 	if pack == nil then return end
-- 	LDataPack.writeChar(pack, roleId)
-- 	LDataPack.writeChar(pack, slot)
-- 	LDataPack.writeShort(pack, nextLevel)
-- 	LDataPack.writeInt(pack, point)
-- 	LDataPack.writeInt(pack, getTotalPoint(actor, roleId))
-- 	LDataPack.writeShort(pack, skLv)
-- 	LDataPack.flush(pack)
-- end

-- --重生天赋点更新
-- function s2cInnatePoint(actor)
-- 	local var = getActorVar(actor)
-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Other, Protocol.sInnateCmd_Point)
-- 	if pack == nil then return end
-- 	LDataPack.writeChar(pack, 1)	
-- 	LDataPack.writeChar(pack, 0)
-- 	LDataPack.writeInt(pack, var.points[0])
-- 	LDataPack.writeInt(pack, getTotalPoint(actor, 0))
-- 	LDataPack.flush(pack)
-- end

-- local function onInit(actor)
-- 	updateAttr(actor, 0, false)	
-- end

-- local function onLogin(actor)
-- 	s2cInnateInfo(actor)
-- end 



-- local function onZhuansheng(actor, zhuanshengLevel)
-- 	local conf = ZhuanshengLevelConfig[zhuanshengLevel]
-- 	addInnatePoint(actor, conf.innatePoint)
-- end

-- actorevent.reg(aeInit, onInit)
-- actorevent.reg(aeUserLogin, onLogin)
-- actorevent.reg(aeZhuansheng, onZhuansheng)
-- netmsgdispatcher.reg(Protocol.CMD_Other, Protocol.cInnateCmd_Up, c2sInnateUp)

-- local gmCmdHandlers = gmsystem.gmCmdHandlers
-- gmCmdHandlers.innatelevel = function (actor, args)
-- 	local pack = LDataPack.allocPacket()
-- 	LDataPack.writeChar(pack, args[1])
-- 	LDataPack.writeChar(pack, args[2])
-- 	LDataPack.setPosition(pack, 0)
-- 	c2sInnateUp(actor, pack)
-- end

-- gmCmdHandlers.innateclean = function (actor, args)
-- 	local var = getActorVar(actor)
-- 	var[0] = {}
-- 	var[1] = {}
-- 	var[2] = {}
-- 	s2cInnateInfo(actor)
-- end

-- gmCmdHandlers.innateadd = function (actor, args)
-- 	addInnatePoint(actor, tonumber(args[1]))
-- 	return true
-- end

-- gmCmdHandlers.innateskill = function (actor, args)
-- 	LActor.learnSkill(actor, tonumber(args[1]), tonumber(args[2])-1)
-- 	return true
-- end
