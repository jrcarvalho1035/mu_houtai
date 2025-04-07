-- @version	1.0
-- @author	youquan
-- @date	2018-5-21
-- @system	铸造系统

module( "zhuzaosystem", package.seeall )
require("equip.zhuzaoattr")
require("equip.zhuzaocost")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.zhuzaosysdata then
		var.zhuzaosysdata = {}
	end
	return var.zhuzaosysdata	
end

function setzhuzaoLevel(actor, roleId, slot, level)
	local var = getActorVar(actor)
	if not var then return end
	if not var[roleId] then
		var[roleId] = {}
	end
	var[roleId][slot] = level
end

function getzhuzaoLevel(actor, roleId, slot)
	local level = 0
	local var = getActorVar(actor)
	if var[roleId] then
		level = var[roleId][slot] or 0
	end
	return level
end

--更新属性
function updateAttr(actor, roleId, calc)
	local addAttrs = {}

	for slot, conf in pairs(ZhuzaoAttrConfig) do
		local level = getzhuzaoLevel(actor, roleId, slot)
		if level > 0 and conf[level] and conf[level].attr then
			for k, v in pairs(conf[level].attr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
			end
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Zhuzao)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
	end
end


function s2cZhuzaoInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_ZhuzaoInfo)
	if pack == nil then return end
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count)
	for roleId = 0, count-1 do
		local ec = 0
		LDataPack.writeChar(pack, roleId)
		local pos = LDataPack.getPosition(pack)
		LDataPack.writeChar(pack, ec)
		for slot, v in pairs(ZhuzaoAttrConfig) do
			local level = getzhuzaoLevel(actor, roleId, slot)
			LDataPack.writeChar(pack, slot)
			LDataPack.writeShort(pack, level)
			ec = ec + 1
		end
		local npos = LDataPack.getPosition(pack)
		LDataPack.setPosition(pack, pos)
		LDataPack.writeChar(pack, ec)
		LDataPack.setPosition(pack, npos)
	end
	LDataPack.flush(pack)
end

--升级
function c2sEquipZhuzaoUp(actor, pack)
	local roleId = LDataPack.readChar(pack)
	local slot = LDataPack.readChar(pack)

	if not utils.checkRoleId(actor, roleId) then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zhuzaosys) then return end
	if not ZhuzaoAttrConfig[slot] then return end

	local level = getzhuzaoLevel(actor, roleId, slot)
	local conf = ZhuzaoCostConfig[level]
	if not conf then return end
	if not actoritem.checkItems(actor, conf.items) then
		return 
	end

	actoritem.reduceItems(actor, conf.items, "zhuzao up:"..level)

	local nextLevel = level + 1
	setzhuzaoLevel(actor, roleId, slot, nextLevel) --升级
	
	updateAttr(actor, roleId, true) --更新属性

	--给前端回包
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_ZhuzaoUp)
	if pack == nil then return end
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, slot)
	LDataPack.writeShort(pack, nextLevel)
	LDataPack.flush(pack)

	local extra = string.format("role:%d,slot:%d,level:%d", roleId, slot, nextLevel)
	utils.logCounter(actor, "othersystem", "", extra, "zhuzaosys", "up")
end

local function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId, false)
	end
end

local function onLogin(actor)
	s2cZhuzaoInfo(actor)
end 

function onOpenRole(actor, roleId)
	s2cZhuzaoInfo(actor)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_ZhuzaoUp, c2sEquipZhuzaoUp)


