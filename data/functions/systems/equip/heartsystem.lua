-- @version	2.0
-- @author	qianmeng
-- @date	2018-2-26 14:28:51.
-- @system	恶魔之心系统

module("heartsystem", package.seeall )

require("equip.heart")
require("equip.heartattrplus")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.heartdata then var.heartdata = {} end
	return var.heartdata
end

function setHeart(actor, roleId, level)
	local var = getActorVar(actor)
	if not var then return end
	var[roleId] = level
	updateAttr(actor, roleId, true)
end

function getHeart(actor, roleId)
	local var = getActorVar(actor)
	if var and var[roleId] then
		return var[roleId]
	end
	return -1
end

function getVarHeart(var, roleId)
	if var and var[roleId] then
		return var[roleId]
	end
	return -1
end

--更新属性
function updateAttr(actor, roleId, calc)
	local addAttrs = {}
	local var = getActorVar(actor)
	local level = getVarHeart(var, roleId)
	local conf = HeartAttrConfig[level]
	local power = 0
	if conf then
		for k, v in pairs(conf.attr) do
			addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
		end
		local id = 0
		for k, v in ipairs(HeartAttrPlusConfig) do
			if conf.stage >= v.stage then
				id = k
			else
				break
			end
		end
		for i=1, id do
			for k, v in pairs(HeartAttrPlusConfig[i].attr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
			end
			power = power + HeartAttrPlusConfig[i].power
		end
	end
	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Heart)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	attr:SetExtraPower(power)
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
	end
end

-------------------------------------------------------------------------------------
--恶心信息
function s2cHeartInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_HeartInfo)
	if pack == nil then return end
	local var = getActorVar(actor)
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count) --角色数量
	for roleId = 0, count-1 do
		LDataPack.writeChar(pack, roleId) --角色id
		local level = getVarHeart(var, roleId)
		LDataPack.writeInt(pack, level)
	end
	LDataPack.flush(pack)
end

--恶心升级
function c2sHeartLevel(actor, packet)
	local roleId = LDataPack.readChar(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.heart) then return end

	local level = getHeart(actor, roleId)
	local nextLevel = level + 1
	if not HeartAttrConfig[nextLevel] then return end --下一级的信息不存在（达到最高级）
	local conf = HeartAttrConfig[level]
	if not conf then return end
	if not actoritem.checkItems(actor, conf.items) then
		return
	end
	actoritem.reduceItems(actor, conf.items, "heart level")
	setHeart(actor, roleId, nextLevel)
	s2cHeartUpdate(actor, roleId, nextLevel)
end

--恶心更新
function s2cHeartUpdate(actor, roleId, nextLevel)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_HeartUp)
	if pack == nil then return end
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeInt(pack, nextLevel)
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
	s2cHeartInfo(actor)
end 

local function onOpenRole(actor, roleId)
	s2cHeartInfo(actor)
end

local function onEquip(actor, roleId, slot)
	updateAttr(actor, roleId, true)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
actorevent.reg(aeAddEquiment, onEquip)
netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_HeartUp, c2sHeartLevel)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.heartlevel = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sHeartLevel(actor, pack)
	return true
end


gmCmdHandlers.heartclean = function (actor, args)
	local var = getActorVar(actor)
	var[0] = {}
	var[1] = {}
	var[2] = {}
	s2cHeartInfo(actor)
	return true 
end
