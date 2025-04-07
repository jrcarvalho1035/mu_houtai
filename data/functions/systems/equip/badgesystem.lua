-- @version	2.0
-- @author	qianmeng
-- @date	2018-3-20 11:56:59.
-- @system	圣徽系统

module("badgesystem", package.seeall )

require("equip.badgetype")
require("equip.badgechip")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.badgedata then var.badgedata = {} end
	return var.badgedata
end

function setBadge(actor, id, slot)
	local var = getActorVar(actor)
	if not var then return end
	if not var[id] then	
		var[id] = {}
	end
	var[id][slot] = 1
	updateAttr(actor, true)
end

function getBadge(actor, id, slot)
	local var = getActorVar(actor)
	if var and var[id] and var[id][slot] then
		return var[id][slot]
	end
	return 0
end

function getVarBadge(var, id, slot)
	if var and var[id] and var[id][slot] then
		return var[id][slot]
	end
	return 0
end

--检测这一类型的圣徽是否全激活
function checkActive(data, id)
	if not data[id] then return false end
	for posId, conf in pairs(BadgeTypeConfig[id]) do
		if (data[id][posId] or 0) == 0 then 
			return false 
		end
	end
	return true
end

--更新属性
function updateAttr(actor, calc)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.badge) then return end
	local addAttrs = {}
	local data = getActorVar(actor)
	for id, config in pairs(BadgeChipConfig) do
		local flag = true --是否全激活
		for posId, conf in pairs(config) do
			if getVarBadge(data, id, posId) > 0 then --已激活的碎片
				for k, v in pairs(conf.attr) do
					addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
				end
			else
				flag = false
			end
		end

		if flag then
			for k, v in pairs(BadgeTypeConfig[id].attr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
			end
		end
	end

	local attr = LActor.getActorSystemAttrs(actor, AttrActorSysId_Badge)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

-------------------------------------------------------------------------------------
--圣徽信息
function s2cBadgeInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_BadgeInfo)
	if pack == nil then return end
	local var = getActorVar(actor)
	LDataPack.writeChar(pack, #BadgeChipConfig) 
	for id, config in pairs(BadgeChipConfig) do
		LDataPack.writeChar(pack, id)
		LDataPack.writeChar(pack, #config)
		for posId, conf in pairs(config) do
			LDataPack.writeChar(pack, posId)
			LDataPack.writeByte(pack, getVarBadge(var, id, posId))
		end
	end
	LDataPack.flush(pack)
end

--圣徽升级
function c2sBadgeLevel(actor, packet)
	local id = LDataPack.readChar(packet)
	local posId = LDataPack.readChar(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.badge) then return end
	local var = getActorVar(actor)
	local conf = BadgeChipConfig[id] and BadgeChipConfig[id][posId]
	if not conf then return end
	if getVarBadge(var, id, posId) > 0 then return end

	if not actoritem.checkItems(actor, conf.items) then
		return
	end
	actoritem.reduceItems(actor, conf.items, "badge level")
	setBadge(actor, id, posId)
	s2cBadgeUpdate(actor, id, posId)
	if checkActive(var, id) then --发公告
		noticesystem.broadCastNotice(noticesystem.NTP.badge, LActor.getName(actor), BadgeTypeConfig[id].name)
	end
end

--圣徽更新
function s2cBadgeUpdate(actor, id, posId)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_BadgeUp)
	if pack == nil then return end
	LDataPack.writeChar(pack, id)
	LDataPack.writeChar(pack, posId)
	LDataPack.flush(pack)
end
---------------------------------------------------------------------------

local function onInit(actor)
	updateAttr(actor, false)
end

local function onLogin(actor)
	s2cBadgeInfo(actor)
end 

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_BadgeUp, c2sBadgeLevel)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.badgelevel = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeChar(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sBadgeLevel(actor, pack)
	return true
end


gmCmdHandlers.badgeclean = function (actor, args)
	local var = getActorVar(actor)
	var[1] = {}
	var[2] = {}
	var[3] = {}
	var[4] = {}
	var[5] = {}
	var[6] = {}
	s2cBadgeInfo(actor)
	return true 
end
