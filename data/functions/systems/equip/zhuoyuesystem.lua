module( "zhuoyuesystem", package.seeall)

--更新属性
function updateAttr(actor, roleId, calc)
	local addAttrs = {}

	for slot, conf in pairs(ZhuoyueConfig) do
		local level = LActor.getZhuoyueLevel(actor, roleId, slot)
		if level > 0 and conf[level] and conf[level].attr then
			for k, v in pairs(conf[level].attr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
			end
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Zhuoyue)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
	end
end


function sendZhuoyueInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_ZhuoyueInfo)
    if pack == nil then return end
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count)
	for roleId = 0, count-1 do
		LDataPack.writeChar(pack, roleId)
		LDataPack.writeChar(pack, EquipType_Max)
		for i=0, EquipType_Max - 1 do
			local level = LActor.getZhuoyueLevel(actor, roleId, i)
			LDataPack.writeChar(pack, level)
		end
	end
	LDataPack.flush(pack)
end

function sendResult(actor, roleId, slot, level)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_ZhuoyueAdd)
	if pack == nil then return end
    LDataPack.writeChar(pack, roleId)
    LDataPack.writeChar(pack, slot)
	LDataPack.writeChar(pack, level)
	LDataPack.flush(pack)
end

function checkAllAdd(actor, roleId)
	for slot, v in pairs(ZhuoyueConfig) do
        if (LActor.getZhuoyueLevel(actor, roleId, slot) or 0) == 0 then
            return false
        end        
    end
    return true
end

function append(actor, pack)
    local roleId = LDataPack.readChar(pack)
    local slot = LDataPack.readChar(pack)
    local role = LActor.getRole(actor, roleId)
    if LActor.getEquipId(role, slot) == 0 then
        return
    end
    local level = LActor.getZhuoyueLevel(actor, roleId, slot)
    if level > 0 and not checkAllAdd(actor, roleId) then
        return
    end
	if not ZhuoyueConfig[slot] or not ZhuoyueConfig[slot][level + 1] then
		return
	end
	local conf = ZhuoyueConfig[slot][level]
    if not actoritem.checkItems(actor, conf.needitem) then
		return
	end
    actoritem.reduceItems(actor, conf.needitem, "zhuoyue up:"..level)    
    LActor.setZhuoyueLevel(actor, roleId, slot, level + 1)
	updateAttr(actor, roleId, true)
    sendResult(actor, roleId, slot, level + 1)
end

local function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId, false)
	end
end

local function onLogin(actor)
	sendZhuoyueInfo(actor)
end 

function onOpenRole(actor, roleId)
	sendZhuoyueInfo(actor)
end


actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_ZhuoyueAdd, append)

