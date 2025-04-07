-- @version	1.0
-- @author	qianmeng
-- @date	2017-5-2 16:40:34.
-- @system	装备加成系统

module( "addsystem", package.seeall )

require("equip.enhanceadd")
require("equip.excellentadd")


local function getAppendConfig(posId, level)
	if AppendAttrConfig[posId] then
		return AppendAttrConfig[posId][level]
	end
	return false
end

--强化加成属性id
function getEnhanceAttr(actor, roleId)
	local info = LActor.getEnhanceInfo(actor, roleId)
	if (not info) then
		return 0
	end
	local id = 0
	for k, v in ipairs(EnhanceAddConfig) do
		local count = 0 --统计满足条件的装备数量
		for posId, level in pairs(info) do
			if posId ~= EquipSlotType_Talisman then
				if level >= v.level then
					count = count + 1
					if count >= v.number then
						id = k
						break
					end
				end
			end
		end
	end
	return id
end

--卓越加成属性id
function getExcellentAttr(actor, roleId)
	local number = equipsystem.getAllEquipExcellent(actor, roleId)
	for i = #ExcellentAddConfig, 1, -1 do
		if number >= ExcellentAddConfig[i].number then
			return i
		end
	end
	return 0
end

--更新属性
function updateAttr(actor, roleId, calc)
	local addAttrs = {}
	
	local id = getEnhanceAttr(actor, roleId)
	if EnhanceAddConfig[id] then
		for k, v in pairs(EnhanceAddConfig[id].attr) do
			addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
		end
	end

	local id = getExcellentAttr(actor, roleId)
	if ExcellentAddConfig[id] then
		for k, v in pairs(ExcellentAddConfig[id].attr) do
			addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_EquipAdd)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
	end
end

-------------------------------协议---------------------------------------------
function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId, false)
	end
end

function onEquipEnhanceUpLevel(actor, roleId, slot, level)
	updateAttr(actor, roleId, true)
end

function onEquip(actor, roleId, slot)
	updateAttr(actor, roleId, true)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeEnhanceEquip, onEquipEnhanceUpLevel)
actorevent.reg(aeAddEquiment, onEquip)

local gmCmdHandlers = gmsystem.gmCmdHandlers

