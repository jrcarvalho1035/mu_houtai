-- @version	1.0
-- @author	qianmeng
-- @date	2018-2-5 11:51:13.
-- @system	饰品系统

module( "jewelsystem", package.seeall )
require("jewel.jewel")
require("jewel.jewellevel")
require("jewel.jewellock")
require("jewel.jewelgroup")
require("jewel.jewelcommon")

-----------------------------------------------------------------------------------------------------------------------
function isOpen(actor)
	return actorexp.checkLevelCondition(actor,actorexp.LimitTp.jewel)
end

function updateAttr(actor, roleId, calc)
	local attrList = {}
	local eIds = {0,0,0,0,0}
	local eLvs = {0,0,0,0,0}
	eIds[1],eIds[2],eIds[3],eIds[4],eIds[5] = LActor.getJewelAdornId(actor, roleId)
	eLvs[1],eLvs[2],eLvs[3],eLvs[4],eLvs[5]  = LActor.getJewelAdornLevel(actor, roleId)
	for i=1, JewelSlot_Max do
		local id = eIds[i]
		local lv = eLvs[i]
		local conf = JewelLevelConfig[id] and JewelLevelConfig[id][lv]
		if conf then
			for k, v in pairs(conf.attr) do
				attrList[v.type] = (attrList[v.type] or 0) + v.value
			end
		end
	end
	--判断组合属性
	for k, conf in ipairs(JewelGroupConfig) do
		local flag = true
		for k1, v1 in ipairs(conf.group) do
			if not utils.checkTableValue(eIds, v1) then
				flag = false --组合不完全
				break
			end
		end
		if flag then
			for k, v in pairs(conf.attr) do
				attrList[v.type] = (attrList[v.type] or 0) + v.value
			end
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Jewel)
	attr:Reset()
	for k, v in pairs(attrList) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

--饰品佩戴处理，设置饰品总数量
local function onJewelAdorn(actor)
	--actorevent.onEvent(actor, aeJewelEquip)
end

------------------------------------------------------------------------------------------------------
--饰品佩戴
function c2sJewelAdorn(actor, packet)
	if not isOpen(actor) then return end
	local uid = LDataPack.readInt64(packet)
	local roleId = LDataPack.readShort(packet)
	local slot = LDataPack.readShort(packet)
	if not utils.checkRoleId(actor, roleId) then return end
	if not JewelLockConfig[slot] then return end
	if LActor.getLevel(actor) < JewelLockConfig[slot].lockLevel then --等级不足
		return
	end
	local role = LActor.getRole(actor, roleId)

	--不能佩戴同一类型的饰品
	local id = LActor.getJewelId(actor, uid)
	if not JewelConfig[id] then return end
	local newTp = JewelConfig[id].type
	local eIds = {0,0,0,0,0}
	eIds[1],eIds[2],eIds[3],eIds[4],eIds[5] = LActor.getJewelAdornId(actor, roleId)
	for k, v in ipairs(eIds) do
		if JewelConfig[v] and JewelConfig[v].type == newTp and (k-1)~=slot then
			return
		end
	end

	LActor.adornJewel(role, uid, slot)
	updateAttr(actor, roleId, true)
	onJewelAdorn(actor) 
end

--饰品升级
function c2sJewelUp(actor, packet)
	if not isOpen(actor) then return end
	local roleId = LDataPack.readShort(packet)
	local slot = LDataPack.readShort(packet)
	local role = LActor.getRole(actor, roleId)
	if not role then return end

	local eIds = {0,0,0,0,0}
	local eLvs = {0,0,0,0,0}
	eIds[1],eIds[2],eIds[3],eIds[4],eIds[5] = LActor.getJewelAdornId(actor, roleId)
	eLvs[1],eLvs[2],eLvs[3],eLvs[4],eLvs[5]  = LActor.getJewelAdornLevel(actor, roleId)

	local id = eIds[slot+1]
	local lv = eLvs[slot+1]

	local config = JewelLevelConfig[id]
	if not config then return end
	if not config[lv+1] then return end --满级
	if not actoritem.checkItem(actor, JewelCommonConfig.itemId, config[lv].consume) then return end
	actoritem.reduceItem(actor, JewelCommonConfig.itemId, config[lv].consume, "jewel up level:"..lv)

	LActor.setJewelLevel(role, slot, lv+1)
	updateAttr(actor, roleId, true)
end

--饰品分解
function c2sJewelBreak(actor, packet)
	local foods = {}  --被分解的饰品
	local count = LDataPack.readInt(packet)
	for i=1, count do
		local fuid = LDataPack.readInt64(packet)
		table.insert(foods, fuid)
	end 
	local sum = 0 --吞噬的饰品所提供的精华
	for k, fuid in ipairs(foods) do
		local id = LActor.getJewelId(actor, fuid)
		local lv = LActor.getJewelLevel(actor, fuid)
		local conf = JewelLevelConfig[id] and JewelLevelConfig[id][lv]
		if conf then
			sum = sum + conf.recovery
		end
	end 
	for k, fuid in ipairs(foods) do --删除被吞噬饰品
		LActor.costItemByUid(actor, fuid, 1, "break jewel")
	end
	actoritem.addItem(actor, JewelCommonConfig.itemId, sum, "jewel devour")
end

function c2sJewelUnadorn(actor, packet)
	if not isOpen(actor) then return end
	local roleId = LDataPack.readShort(packet)
	local slot = LDataPack.readShort(packet)
	local role = LActor.getRole(actor, roleId)
	if not role then return end
	local eIds = {0,0,0,0,0}
	eIds[1],eIds[2],eIds[3],eIds[4],eIds[5] = LActor.getJewelAdornId(actor, roleId)
	if eIds[slot+1] == 0 then
		return
	end
	LActor.unadornJewel(role, slot)
	updateAttr(actor, roleId, true)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Jewel, Protocol.sJewelCmd_Unadorn)
	if not pack then return end
	LDataPack.writeShort(pack, roleId)
	LDataPack.writeShort(pack, slot)
	LDataPack.writeInt(pack, eIds[slot+1])
	LDataPack.flush(pack)
	onJewelAdorn(actor)
end
-----------------------------------------------------------------------------------------------------

function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId, false)
	end
end

function onLogin(actor)
end

function onLevelUp(actor, level, oldLevel)
end

netmsgdispatcher.reg(Protocol.CMD_Jewel, Protocol.cJewelCmd_Adorn, c2sJewelAdorn)
netmsgdispatcher.reg(Protocol.CMD_Jewel, Protocol.cJewelCmd_Up, c2sJewelUp)
netmsgdispatcher.reg(Protocol.CMD_Jewel, Protocol.cJewelCmd_Break, c2sJewelBreak)
netmsgdispatcher.reg(Protocol.CMD_Jewel, Protocol.cJewelCmd_Unadorn, c2sJewelUnadorn)

actorevent.reg(aeInit, onInit)
actorevent.reg(aeLevel, onLevelUp)
actorevent.reg(aeUserLogin, onLogin)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.jeweladorn = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt64(pack, args[1])
	LDataPack.writeShort(pack, args[2])
	LDataPack.writeShort(pack, args[3])
	LDataPack.setPosition(pack, 0)
	c2sJewelAdorn(actor, pack)
	return true
end

gmCmdHandlers.jewelup = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeShort(pack, args[1])
	LDataPack.writeShort(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sJewelUp(actor, pack)
	return true
end

gmCmdHandlers.jewelbreak = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, 1)
	LDataPack.writeInt64(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sJewelBreak(actor, pack)
	return true
end

gmCmdHandlers.jewelunadorn = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeShort(pack, args[1])
	LDataPack.writeShort(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sJewelUnadorn(actor, pack)
	return true
end
