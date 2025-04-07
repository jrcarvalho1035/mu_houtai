module("smequipsystem", package.seeall)

function getVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.smequip then var.smequip = {} end
    if not var.smequip.equips then var.smequip.equips = {} end
    if not var.smequip.power then var.smequip.power = 0 end
    return var.smequip
end

local function tableAddMulit(t, attrs)
    for _, v in ipairs(attrs) do
        t[v.type] = (t[v.type] or 0) + v.value
    end
end

local function calcAttr(actor, isCalc)
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_SMEquip)
    attr:Reset()
    
    local var = getVar(actor)

    local totalAttrs = {}
    local power = 0
    local currank = {}
    for i = 0, 9 do
        if (var.equips[i] or 0) ~= 0 then
            tableAddMulit(totalAttrs, ShenmoEquipAttConfig[var.equips[i]].attr)
            currank[#currank + 1] = ItemConfig[var.equips[i]].rank
        end
    end
    
    table.sort(currank, function(a, b) return a > b end)
    local count = #currank
    for i = 1, count do
        for j = #ShenmoEquipAddConfig, 1, -1 do
            if i == ShenmoEquipAddConfig[j].number and currank[i] >= ShenmoEquipAddConfig[j].rank then
                tableAddMulit(totalAttrs, ShenmoEquipAddConfig[j].attr)
                power = power + ShenmoEquipAddConfig[j].power
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
    
    if not isCalc then
        LActor.reCalcAttr(actor)
    end
end

function getSMEquipAttrs(actor)
    local var = getVar(actor)

    local equipAttrs = {}
    for i = 0, 9 do
        if (var.equips[i] or 0) ~= 0 then
            tableAddMulit(equipAttrs, ShenmoEquipAttConfig[var.equips[i]].attr)
        end
    end

    return equipAttrs
end

function getPower(actor)
    local var = getVar(actor)
    return var.power
end

--穿戴
function onPutOn(actor, pack)
    local equipid = LDataPack.readInt(pack)
    if not ItemConfig[equipid] then return end
    local var = getVar(actor)
    local config = ItemConfig[equipid]
    if config.type ~= 54 then
        return
    end
    if not actoritem.checkItem(actor, equipid, 1) then
        return
    end
    
    if smzlsystem.getSMZLLevel(actor) < config.rank then
        return
    end
    actoritem.reduceItem(actor, equipid, 1, "shenmo equip put on")
    local beforeid = var.equips[config.subType] or 0
    var.equips[config.subType] = equipid
    if beforeid ~= 0 then
        actoritem.addItem(actor, beforeid, 1, "shenmo equip put on")
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMEquipPutOn)
    LDataPack.writeInt(pack, equipid)
    LDataPack.flush(pack)
    calcAttr(actor)
end

--脱下
function onPutOff(actor, pack)
    local equipid = LDataPack.readInt(pack)
    if not ItemConfig[equipid] then return end
    local var = getVar(actor)
    local config = ItemConfig[equipid]
    if config.type ~= 54 then
        return
    end
    if (var.equips[config.subType] or 0) == 0 then
        return
    end
    var.equips[config.subType] = 0
    actoritem.addItem(actor, equipid, 1, "shenmo equip put off")
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMEquipPutOff)
    LDataPack.writeInt(pack, equipid)
    LDataPack.flush(pack)
    calcAttr(actor)
end

--分解
function onSmelt(actor, pack)
    local equipid = LDataPack.readInt(pack)
    local count = LDataPack.readInt(pack)
    if not ItemConfig[equipid] then return end
    local var = getVar(actor)
    local config = ItemConfig[equipid]
    if config.type ~= 54 then
        return
    end
    if not actoritem.checkItem(actor, equipid, count) then
        return
    end
    actoritem.reduceItem(actor, equipid, count, "shenmo equip smelt")
    actoritem.addItem(actor, DiabloConstConfig.smeltid, ShenmoEquipConfig[equipid].addcount * count, "shenmo equip smelt")
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMEquipSmelt)
    LDataPack.writeInt(pack, equipid)
    LDataPack.flush(pack)
end

--兑换
function onExchange(actor, pack)
    local equipid = LDataPack.readInt(pack)
    if not ItemConfig[equipid] then return end
    local var = getVar(actor)
    local config = ItemConfig[equipid]
    if config.type ~= 54 then
        --return
    end
    
    if smzlsystem.getSMZLLevel(actor) < config.rank then
        return
    end
    
    if not actoritem.checkItem(actor, DiabloConstConfig.smeltid, ShenmoEquipConfig[equipid].needcount, 1) then
        return
    end
    actoritem.reduceItem(actor, DiabloConstConfig.smeltid, ShenmoEquipConfig[equipid].needcount, "shenmo equip exchange")
    actoritem.addItem(actor, equipid, 1, "shenmo equip exchange")
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMEquipExchange)
    LDataPack.writeInt(pack, equipid)
    LDataPack.flush(pack)
end

function sendSMEquipInfo(actor)
    local var = getVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMEquipInfo)
    LDataPack.writeChar(pack, 10)
    for i = 0, 9 do
        LDataPack.writeChar(pack, i)
        LDataPack.writeInt(pack, var.equips[i] or 0)
    end
    LDataPack.flush(pack)
end

function onLogin(actor)
    sendSMEquipInfo(actor)
end

local function onInit(actor)
    calcAttr(actor, true)
end

local function init()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Shenmo, Protocol.cShenmoCmd_SMEquipPutOn, onPutOn)
    netmsgdispatcher.reg(Protocol.CMD_Shenmo, Protocol.cShenmoCmd_SMEquipPutOff, onPutOff)
    netmsgdispatcher.reg(Protocol.CMD_Shenmo, Protocol.cShenmoCmd_SMEquipSmelt, onSmelt)
    netmsgdispatcher.reg(Protocol.CMD_Shenmo, Protocol.cShenmoCmd_SMEquipExchange, onExchange)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.smequipAll = function (actor, args)
    local var = getVar(actor)
    var.equips[0] = 390930
    var.equips[1] = 390931
    var.equips[2] = 390932
    var.equips[3] = 390933
    var.equips[4] = 390934
    var.equips[5] = 390935
    var.equips[6] = 390936
    var.equips[7] = 390937
    var.equips[8] = 390838
    var.equips[9] = 390939
    calcAttr(actor)
    sendSMEquipInfo(actor)
    return true
end
