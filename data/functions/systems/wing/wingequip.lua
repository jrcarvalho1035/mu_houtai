
module( "wingequip", package.seeall)

function getActorVar(actor, roleId)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
    if not var.wingequip then var.wingequip = {} end
    if not var.wingequip[roleId] then var.wingequip[roleId] = {} end
    if not var.wingequip[roleId].equips then var.wingequip[roleId].equips = {} end
	return var.wingequip[roleId]
end

local function tableAddMulit(t, attrs, n)
    for _, v in ipairs(attrs) do
        t[v.type] = (t[v.type] or 0) + (v.value * n)
    end
end

function calcAttr(actor, roleId, calc)
	local var = getActorVar(actor, roleId)
    local totalAttrs = {}
    local power = 0
    local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_WingEquip)
    attr:Reset()
    local currank = {}
    for i=0,5 do
        if var.equips[i] and var.equips[i] > 0 then
            currank[#currank + 1] = ItemConfig[var.equips[i]].rank
            tableAddMulit(totalAttrs, WingEquipAttConfig[var.equips[i]].attr, 1)
        end
    end

    table.sort(currank, function(a,b) return a > b end)
    local count = math.floor(#currank/2) * 2
    --套装属性
    for i=2, count, 2 do        
        for j=#WingEquipAddConfig, 1, -1 do
            if i == WingEquipAddConfig[j].number and currank[i] >= WingEquipAddConfig[j].rank then
                tableAddMulit(totalAttrs, WingEquipAddConfig[j].attr, 1)
                power = power + WingEquipAddConfig[j].power
                break
            end
        end
    end

    for k, v in pairs(totalAttrs) do
        attr:Set(k, v)
    end
    if power > 0 then
        attr:SetExtraPower(power)
    end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
	end	
end



function sendWingEquipInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingEquip_Info)
    local rolecount = LActor.getRoleCount(actor)
    LDataPack.writeChar(pack, rolecount)
    for i=0, rolecount - 1 do
        local var = getActorVar(actor, i)        
        LDataPack.writeChar(pack, 6)
        for j=0, 5 do
            LDataPack.writeInt(pack, var.equips[j] or 0)
        end
    end

    LDataPack.flush(pack)
end

function c2sPutOn(actor, pack)
    local roleId = LDataPack.readChar(pack)
    local equipid = LDataPack.readInt(pack)
    local var = getActorVar(actor, roleId)

    if not ItemConfig[equipid] or ItemConfig[equipid].type ~= 49 then
        return
    end

    local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
    if ItemConfig[equipid].rank > WingLevelConfig[level].maxequip then
        return
    end 

    if not actoritem.checkItem(actor, equipid, 1) then
        return
    end
    actoritem.reduceItem(actor, equipid, 1, "wingequip level up")

    local beforeid = var.equips[ItemConfig[equipid].subType] or 0
    var.equips[ItemConfig[equipid].subType] = equipid
    if beforeid ~= 0 then
        actoritem.addItem(actor, beforeid, 1, "wingequip put on equip")
    end
    

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingEquip_PutOn)
    LDataPack.writeChar(pack, roleId)
    LDataPack.writeInt(pack, equipid)
    LDataPack.flush(pack)

    calcAttr(actor, roleId, true)
    --sendWingEquipInfo(actor)
end

function c2sStageUp(actor, pack)
    local puttype = LDataPack.readChar(pack)
    local roleId = LDataPack.readChar(pack)
    local targetid = LDataPack.readInt(pack)

    if not ItemConfig[targetid] then return end

    local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
    if ItemConfig[targetid].rank > WingLevelConfig[level].maxequip or ItemConfig[targetid].rank <= 1 then
        return
    end
    local var = nil
    if puttype == 1 then
        var = getActorVar(actor, roleId)
        local beforeid = (var.equips[ItemConfig[targetid].subType] or 0)
        if beforeid == 0 then
            return
        end
        
        if ItemConfig[targetid].rank - ItemConfig[beforeid].rank ~= 1 then
            return
        end
    end

    local conf = WingEquipUpConfig[targetid]
    if not conf then return end
    local count = (puttype == 1) and conf.mainitem.count - 1 or conf.mainitem.count
    if not actoritem.checkItem(actor, conf.mainitem.id, count) then
        return
    end
    if not actoritem.checkItems(actor, conf.needitem) then
        return
    end

    actoritem.reduceItem(actor, conf.mainitem.id, count, "wingequip stage up")
    actoritem.reduceItems(actor, conf.needitem, "wingequip stage up")

    if puttype == 1 then        
        var.equips[ItemConfig[targetid].subType] = targetid
        calcAttr(actor, roleId, true)
    else
        actoritem.addItem(actor, targetid, 1, "wingequip stage up")
    end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingEquip_StageUp)
    LDataPack.writeChar(pack, roleId)
    LDataPack.writeInt(pack, targetid)
    LDataPack.writeChar(pack, puttype)
    LDataPack.flush(pack)
    --sendWingEquipInfo(actor)
end

function c2sChange(actor, pack)
    local srcid = LDataPack.readInt(pack)
    local targetid = LDataPack.readInt(pack)

    if not ItemConfig[srcid] or ItemConfig[srcid].type ~= 49 then
        return
    end
    if not ItemConfig[targetid] or ItemConfig[targetid].type ~= 49 then
        return
    end
    if not actoritem.checkItem(actor, srcid, 1) then
        return
    end

    if ItemConfig[srcid].rank ~= ItemConfig[targetid].rank then
        return
    end

    if not actoritem.checkItem(actor, NumericType_YuanBao, WingEquipChangeConfig[ItemConfig[srcid].rank].needyuanbao) then
        return
    end
    actoritem.reduceItem(actor, NumericType_YuanBao, WingEquipChangeConfig[ItemConfig[srcid].rank].needyuanbao, "wingequip change")
    actoritem.reduceItem(actor, srcid, 1, "wingequip change")
    actoritem.addItem(actor, targetid, 1, "wingequip change")

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingEquip_Change)
    LDataPack.writeChar(pack, 1)
    LDataPack.writeInt(pack, targetid)
    LDataPack.flush(pack)
    --sendWingEquipInfo(actor)
end


function onLogin(actor)
    sendWingEquipInfo(actor)
end
   
function onCreateRole(actor)
    sendWingEquipInfo(actor)
end


local function onInit(actor)
	local roleCnt = LActor.getRoleCount(actor)
	for roleId = 0, roleCnt - 1 do
		calcAttr(actor, roleId, false)
	end
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeCreateRole, onCreateRole)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingEquip_PutOn, c2sPutOn)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingEquip_StageUp, c2sStageUp)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingEquip_Change, c2sChange)
