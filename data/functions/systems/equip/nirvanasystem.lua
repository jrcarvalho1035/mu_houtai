-- @version	2.0
-- @author	qianmeng
-- @date	2018-4-23 17:20:55.
-- @system	重生装备系统

module("nirvanasystem", package.seeall )

require("equip.nirvanalevel")
require("equip.nirvanaextra")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.nirvanadata then var.nirvanadata = {} end
	return var.nirvanadata
end

function getActorCrossVar(actor)
	local cvar = LActor.getCrossVar(actor)
	if not cvar.nirvanacross then
		cvar.nirvanacross = {
			weap = 0,
			coat = 0,
		}
	end
	return cvar.nirvanacross
end

function setCrossNWeap(actor, level)
	local cvar = getActorCrossVar(actor)
	cvar.weap = level
end

function setCrossNCoat(actor, level)
	local cvar = getActorCrossVar(actor)
	cvar.coat = level
end

function getCrossNWeap(actor, level)
	local cvar = getActorCrossVar(actor)
	return cvar.weap
end

function getCrossNCoat(actor, level)
	local cvar = getActorCrossVar(actor)
	return cvar.coat
end

function setNirvana(actor, roleId, slot, level)
	local var = getActorVar(actor)
	if not var then return end
	if not var[roleId] then	
		var[roleId] = {}
	end
	var[roleId][slot] = level
	if roleId == 0 then
		if slot == EquipSlotType_Weapon then
			setCrossNWeap(actor, level)
		elseif slot == EquipSlotType_Coat then
			setCrossNCoat(actor, level)
		end
	end
	updateAttr(actor, roleId, true)
end

function getNirvana(actor, roleId, slot)
	local var = getActorVar(actor)
	if var and var[roleId] and var[roleId][slot] then
		return var[roleId][slot]
	end
	return 0
end

function getVarNirvana(var, roleId, slot)
	if var and var[roleId] and var[roleId][slot] then
		return var[roleId][slot]
	end
	return 0
end

--更新属性
function updateAttr(actor, roleId, calc)
	local addAttrs = {}
	local role = LActor.getRole(actor,roleId)
	local var = getActorVar(actor)

	local role = LActor.getRole(actor,roleId)
	local job = LActor.getJob(role)
	local sum = 0 --重生属性数量
	for slot, v in pairs(NirvanaLevelConfig[job]) do
		local lv = getVarNirvana(var, roleId, slot)
		if lv > 0 and v[lv] then
			for k1, attr in pairs(v[lv].attr) do
				addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
			end
			for k1, attr in pairs(v[lv].attr2) do
				addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
				sum = sum + 1
			end
		end
	end
	--计算附加属性
	local extra
	for k, v in pairs(NirvanaExtraConfig) do
		if sum >= v.count then
			extra = v.attr
		end
	end
	if extra then
		for k, attr in pairs(extra) do
			addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Nirvana)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
	end
end

function getNirvanaWeap(actor, roleId)
	return getNirvana(actor, roleId, EquipSlotType_Weapon)
end
_G.getNirvanaWeap = getNirvanaWeap

function getNirvanaCoat(actor, roleId)
	return getNirvana(actor, roleId, EquipSlotType_Coat)
end
_G.getNirvanaCoat = getNirvanaCoat
-------------------------------------------------------------------------------------
--重生装备信息
function s2cNirvanaInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_NirvanaInfo)
	if pack == nil then return end
	local var = getActorVar(actor)
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count) --角色数量
	for roleId = 0, count-1 do
		local role = LActor.getRole(actor,roleId)
		local job = LActor.getJob(role)
		LDataPack.writeChar(pack, roleId) --角色id
		LDataPack.writeChar(pack, job)
		local slotcount = 0
		local slotpos = LDataPack.getPosition(pack)
		LDataPack.writeChar(pack, slotcount) --装备部位数量
		for slot, config in pairs(NirvanaLevelConfig[job]) do
			local level = getVarNirvana(var, roleId, slot)
			if level > 0 then
				LDataPack.writeChar(pack, slot) 	--装备部位
				LDataPack.writeChar(pack, level)	--重生装备等级
				slotcount = slotcount + 1
			end
		end
		if slotcount > 0 then
			local npos = LDataPack.getPosition(pack)
			LDataPack.setPosition(pack, slotpos)
			LDataPack.writeChar(pack, slotcount)
			LDataPack.setPosition(pack, npos)
		end
	end
	LDataPack.flush(pack)
end

--重生装备升级
function c2sNirvanaLevel(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local slot = LDataPack.readChar(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.nirvana) then return end
	local role = LActor.getRole(actor,roleId)
	local job = LActor.getJob(role)

	local level = getNirvana(actor, roleId, slot)
	local nextLevel = level + 1
	local config = NirvanaLevelConfig[job][slot]
	if config[level]==nil or config[nextLevel]==nil then
		return
	end
	local conf = config[level]
	if not actoritem.checkItems(actor, conf.items) then
		return
	end
	actoritem.reduceItems(actor, conf.items, "nirvana level")
	
	setNirvana(actor, roleId, slot, nextLevel)
	s2cNirvanaUpdate(actor, roleId, job, slot, nextLevel)
	actorevent.onEvent(actor, aeNotifyFacade, roleId)
	local extra = string.format("role:%d,slot:%d,level:%d",  roleId, slot, nextLevel)
	utils.logCounter(actor, "othersystem", "", extra, "nirvana", "uplevel")
end

--重生装备更新
function s2cNirvanaUpdate(actor, roleId, job, slot, nextLevel)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_NirvanaUp)
	if pack == nil then return end
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, job)
	LDataPack.writeChar(pack, slot)
	LDataPack.writeChar(pack, nextLevel)
	LDataPack.flush(pack)
end
---------------------------------------------------------------------------

local function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId, false)
	end
end

local function onLogin(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.nirvana) then return end
	s2cNirvanaInfo(actor)
end 

local function onOpenRole(actor, roleId)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.nirvana) then return end
	s2cNirvanaInfo(actor)
end

--客户端要求等级更新时不要下发数据，会报错，其将使用默认数据
-- function onLevelUp(actor, level, oldLevel)
-- 	local lv = actorexp.getLimitLevel(actor,actorexp.LimitTp.nirvana)
-- 	if lv > oldLevel and lv <= level then
-- 		s2cNirvanaInfo(actor)
-- 	end
-- end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
--actorevent.reg(aeLevel, onLevelUp)
netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_NirvanaUp, c2sNirvanaLevel)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.nirvanalevel = function (actor, args)
	local roleId = tonumber(args[1])
	local slot = tonumber(args[2])
	local level = tonumber(args[3])
	setNirvana(actor, roleId, slot, level)
end

gmCmdHandlers.nirvanaclean = function (actor, args)
	local var = getActorVar(actor)
	var[0] = {}
	var[1] = {}
	var[2] = {}
	s2cNirvanaInfo(actor)
end
