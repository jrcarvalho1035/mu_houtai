-- @version	1.0
-- @author	rancho
-- @date	2017-10-18
-- @system	神装系统

module( "godequipsystem", package.seeall )
require("equip.godequipattr")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.godEquipData then
		var.godEquipData = {}
	end
	if not var.godEquipData.activecount then var.godEquipData.activecount = 0 end
	return var.godEquipData	
end

--创建一个神装数据结构
function setGodEquipLevel(actor, slot, level)
	local var = getActorVar(actor)
	var[slot] = level --神装等级
end

--返回神装等级
function getGodEquipLevel(actor, slot)
	local var = getActorVar(actor)
	return var[slot] or 0
end

--返回神装激活数量
function getGodEquipActiveCnt(actor)
	local count = 0
	local var = getActorVar(actor)
	for slot in pairs(GodEquipAttrConfig) do
		if (var[slot] or 0) > 0 then
			count = count + 1
		end
	end
	return count
end

--更新属性
function updateAttr(actor, calc)
	local addAttrs = {}

	for slot, conf in pairs(GodEquipAttrConfig) do
		local level = getGodEquipLevel(actor, slot)
		if level > 0 then
			for k,v in ipairs(conf.activeAttr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
			end
			for k, v in ipairs(conf.attr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * level
			end
		end
	end
	local var = getActorVar(actor)
	--觉醒数量加成
	if var.activecount > 0 then
		local conf = GodWakeAddConfig[var.activecount]
		for k, v in pairs(addAttrs) do
			if k == Attribute.atHpMax then
				addAttrs[k] = addAttrs[k] * (1+ conf.addhp/10000)
			elseif k == Attribute.atAtk then
				addAttrs[k] = addAttrs[k] * (1+ conf.addatk/10000)
			end
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_GodEquip)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcRoleAttr(actor)
	end
end

-------------------------------协议---------------------------------------------

function upDashi(actor)
	local count = getGodEquipActiveCnt(actor)	
	local var = getActorVar(actor)
	local activecount = (var.activecount or 0) + 1
	local conf = GodWakeAddConfig[activecount]
	if not conf then return end
	if count < conf.number then return end
	var.activecount = activecount
	extra = string.format(",type:%d,level:%d", 1, activecount)
	updateAttr(actor, true)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_GodEquipDaShi)
    if pack == nil then return end
    LDataPack.writeChar(pack, activecount)
	LDataPack.flush(pack)
	utils.logCounter(actor, "othersystem", "", extra, "godequip", "dashiUp")
end

--神装信息
function s2cGodEquipInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_GodEquipInfo)
	if pack == nil then return end
	local ec = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeChar(pack, ec)
	for slot, v in pairs(GodEquipAttrConfig) do
		local level = getGodEquipLevel(actor, slot)
		LDataPack.writeChar(pack, slot)
		LDataPack.writeShort(pack, level)
		ec = ec + 1
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeChar(pack, ec)
	LDataPack.setPosition(pack, npos)
	LDataPack.writeChar(pack, var.activecount)
	LDataPack.flush(pack)
end

--神装升级
function c2sGodEquipUp(actor, pack)
	local slot = LDataPack.readChar(pack)
	--if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.godequip) then return end
	local conf = GodEquipAttrConfig[slot]
	if not conf then return end

	local level = getGodEquipLevel(actor, slot)
	if level >= conf.maxLevel then return end

	if not actoritem.checkItems(actor, conf.items) then
		return 
	end
	actoritem.reduceItems(actor, conf.items, "god equip up:"..level)

	local nextLevel = level + 1
	setGodEquipLevel(actor, slot, nextLevel) --升级
	
	updateAttr(actor, true) --更新属性

	--给前端回包
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_GodEquipUpdate)
	if pack == nil then return end
	LDataPack.writeChar(pack, slot)
	LDataPack.writeShort(pack, nextLevel)
	LDataPack.flush(pack)
	if level == 0 then
		noticesystem.broadCastNotice(noticesystem.NTP.godequip,LActor.getName(actor), ItemConfig[conf.items[1].id].name[1])
		actorevent.onEvent(actor, aeGodEquipCnt, 0)
	end

	local extra = string.format("slot:%d,level:%d", slot, nextLevel)
	utils.logCounter(actor, "othersystem", "", extra, "god equip", "up")
end

local function onInit(actor)
	--if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.godequip) then return end
	updateAttr(actor, false)
end

local function onLogin(actor)
	s2cGodEquipInfo(actor)
end 

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_GodEquipUp, c2sGodEquipUp)
netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_GodEquipDaShi, upDashi)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.godequipup = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeChar(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sGodEquipUp(actor, pack)
end

gmCmdHandlers.godequipset = function (actor, args)
	local slot = tonumber(args[1])
	local level = tonumber(args[2])
	setGodEquipLevel(actor, slot, level)
end

