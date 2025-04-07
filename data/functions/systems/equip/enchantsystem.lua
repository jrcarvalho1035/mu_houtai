-- @version2.0
-- @authorqianmeng
-- @date2017-11-15 17:25:58.
-- @system附魔系统

module("enchantsystem", package.seeall)

require("equip.enchantattr")
require("equip.enchantchange")

function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.enchantdata then var.enchantdata = {} end
    return var.enchantdata
end

--更新属性
function updateAttr(actor, calc)
    local addAttrs = {}
    local var = getActorVar(actor)
    
    for slot, v in pairs(EnchantAttrConfig) do
        for hold, v1 in pairs(v) do
            local level = getVarEnchant(var, slot, hold)
            if level > 0 and v1[level] then
                for k, attr in pairs(v1[level].attr) do
                    addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
                end
            end
        end
    end
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Enchant)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    if calc then
        LActor.reCalcRoleAttr(actor)
    end
end

function setEnchant(actor, slot, hold, level)
    local var = getActorVar(actor)
    if not var then return end
    if not var[slot] then
        var[slot] = {}
    end
    var[slot][hold] = level
    updateAttr(actor, true)
end

function getEnchant(actor, slot, hold)
    local var = getActorVar(actor)
    if var and var[slot] and var[slot][hold] then
        return var[slot][hold]
    end
    return 0
end

function getVarEnchant(var, slot, hold)
    if var and var[slot] and var[slot][hold] then
        return var[slot][hold]
    end
    return 0
end

-------------------------------------------------------------------------------------
--附魔信息
function s2cEnchantInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_EnchantInfo)
    if pack == nil then return end
    local var = getActorVar(actor)
    local slotcount = 0
    local slotpos = LDataPack.getPosition(pack)
    LDataPack.writeChar(pack, slotcount) --部位数量
    for slot, v in pairs(EnchantAttrConfig) do
        local flag = false
        local holdcount = 0
        local holdpos = 0
        for hold, v1 in pairs(v) do
            local lv = getVarEnchant(var, slot, hold)
            if lv > 0 then
                if not flag then --循环内只发第一次
                    LDataPack.writeChar(pack, slot) --部位
                    holdpos = LDataPack.getPosition(pack)
                    LDataPack.writeChar(pack, holdcount) --附魔槽数量
                    flag = true
                end
                holdcount = holdcount + 1
                LDataPack.writeChar(pack, hold) --槽位置
                LDataPack.writeShort(pack, lv)--等级
            end
        end
        if holdcount > 0 then
            local npos = LDataPack.getPosition(pack)
            LDataPack.setPosition(pack, holdpos)
            LDataPack.writeChar(pack, holdcount)
            LDataPack.setPosition(pack, npos)
        end
        
        if flag then
            slotcount = slotcount + 1
        end
        
    end
    if slotcount > 0 then
        local npos = LDataPack.getPosition(pack)
        LDataPack.setPosition(pack, slotpos)
        LDataPack.writeChar(pack, slotcount)
        LDataPack.setPosition(pack, npos)
    end
    LDataPack.flush(pack)
end

--附魔升级
function c2sEnchantLevel(actor, packet)
    local slot = LDataPack.readChar(packet)
    local hold = LDataPack.readChar(packet)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.enchant) then return end
    local lv = getEnchant(actor, slot, hold)
    local conf = EnchantAttrConfig[slot] and EnchantAttrConfig[slot][hold] and EnchantAttrConfig[slot][hold][lv]
    if not (EnchantAttrConfig[slot] and EnchantAttrConfig[slot][hold] and EnchantAttrConfig[slot][hold][lv + 1]) then return end --下一级的信息不存在（达到最高级）
    if not actoritem.checkItems(actor, conf.items) then
        utils.printTable(conf.items)
        return
    end
    actoritem.reduceItems(actor, conf.items, "enchant level")
    local ret = math.random(1, 10000) <= conf.rate --是否成功
    if ret then
        lv = lv + 1
        setEnchant(actor, slot, hold, lv)
    end
    s2cEnchantUpdate(actor, ret, slot, hold, lv)
    
    if ret and hold == 4 and ScriptTips.enchantname[slot + 1] then
        if lv == 1 then
            noticesystem.broadCastNotice(noticesystem.NTP.enchantActive, LActor.getName(actor), ScriptTips.enchantname[slot + 1])
        elseif lv == 6 or lv == 8 or lv == 10 then
            noticesystem.broadCastNotice(noticesystem.NTP.enchantLevel, LActor.getName(actor), ScriptTips.enchantname[slot + 1], lv)
        end
    end
    
    local extra = string.format("slot:%d,hold:%d,lv:%d", slot, hold, lv)
    utils.logCounter(actor, "othersystem", "", extra, "enchant", "uplevel")
end

--附魔更新
function s2cEnchantUpdate(actor, isSuc, slot, hold, newLv)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_EnchantUp)
    if pack == nil then return end
    LDataPack.writeByte(pack, isSuc and 1 or 0)
    LDataPack.writeChar(pack, slot)
    LDataPack.writeChar(pack, hold)
    LDataPack.writeShort(pack, newLv)
    LDataPack.flush(pack)
end

--附魔石分解为附魔券
function c2sEnchantChange(actor, packet)
    local id = LDataPack.readInt(packet)
    local number = LDataPack.readInt(packet)
    local conf = EnchantChangeConfig[id]
    if not conf then return end
    local var = getActorVar(actor)
    if not actoritem.checkItem(actor, id, number) then
        return
    end
    actoritem.reduceItem(actor, id, number, "enchant change")
    local items = {}
    for k, v in pairs(EnchantChangeConfig[id].items) do
        table.insert(items, {type = v.type, id = v.id, count = v.count * number})
    end
    
    actoritem.addItems(actor, items, "enchant change")
end
---------------------------------------------------------------------------

local function onInit(actor)
    updateAttr(actor, false)
end

local function onLogin(actor)
    s2cEnchantInfo(actor)
end

function init()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_EnchantUp, c2sEnchantLevel)
    netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_EnchantChange, c2sEnchantChange)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.enchantlevel = function (actor, args)
    local pack = LDataPack.allocPacket()
    LDataPack.writeChar(pack, args[1])
    LDataPack.writeChar(pack, args[2])
    LDataPack.writeChar(pack, args[3])
    LDataPack.setPosition(pack, 0)
    c2sEnchantLevel(actor, pack)
end

gmCmdHandlers.enchantchange = function (actor, args)
    local pack = LDataPack.allocPacket()
    LDataPack.writeInt(pack, args[1])
    LDataPack.setPosition(pack, 0)
    c2sEnchantChange(actor, pack)
end

gmCmdHandlers.enchantclean = function (actor, args)
    local var = getActorVar(actor)
    var[0] = {}
    var[1] = {}
    var[2] = {}
    s2cEnchantInfo(actor)
end

gmCmdHandlers.enchantAll = function (actor, args)
    local var = getActorVar(actor)
    for slot, config in pairs(EnchantAttrConfig) do
        var[slot] = {}
        for hold, conf in pairs(config) do
            var[slot][hold] = #conf
        end
    end
    updateAttr(actor, true)
    s2cEnchantInfo(actor)
    return true
end
