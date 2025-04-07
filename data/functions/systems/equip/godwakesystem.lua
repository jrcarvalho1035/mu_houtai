-- @version2.0
-- @authorqianmeng
-- @date2017-11-29 14:23:30.
-- @system神装觉醒系统

module("godwakesystem", package.seeall)

require("equip.godwake")
require("equip.godwakeadd")
require("equip.godwakestar")

function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.godwakedata then var.godwakedata = {} end
    return var.godwakedata
end

function setGodwake(actor, slot, star)
    local var = getActorVar(actor)
    if not var then return end
    var[slot] = star
    updateAttr(actor, true)
end

function getGodwake(actor, slot)
    local var = getActorVar(actor)
    return var[slot] or 0
end

function getVarGodwake(var, slot)
    return var[slot] or 0
end

--更新属性
function updateAttr(actor, calc)
    local addAttrs = {}
    local var = getActorVar(actor)
    
    local starNum = var.starNum or 0
    for slot, v in pairs(GodWakeConfig) do
        local star = getVarGodwake(var, slot)
        if star > 0 and v[star] then
            for k, attr in pairs(v[star].attr) do
                addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
            end
        end
    end
    --星级数量加成
    if starNum > 0 then
        local conf = GodWakeStarConfig[starNum]          
        for k, v in pairs(addAttrs) do
            addAttrs[k] = addAttrs[k] * (1+ conf.addattr/10000)
        end

        for _, v in pairs(conf.attrs) do
            addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
        end        
    end
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Godwake)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    if calc then
        LActor.reCalcRoleAttr(actor)
    end
end

function getStageNum(actor)
    local var = getActorVar(actor)
    local num = 0
    for slot,v in pairs(GodWakeConfig) do
        num = num + (v[var[slot] or 0].stage)
    end
    return num
end

-------------------------------------------------------------------------------------
--神醒信息
function s2cGodwakeInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_GodWakeInfo)
    if pack == nil then return end
    local var = getActorVar(actor)
    local slotcount = 0
    local slotpos = LDataPack.getPosition(pack)
    LDataPack.writeChar(pack, slotcount) --装备部位数量
    for slot, config in pairs(GodWakeConfig) do
        local star = getVarGodwake(var, slot)
        if star > 0 then
            LDataPack.writeChar(pack, slot) --装备部位
            LDataPack.writeChar(pack, star)--星级
            slotcount = slotcount + 1
        end
    end
    if slotcount > 0 then
        local npos = LDataPack.getPosition(pack)
        LDataPack.setPosition(pack, slotpos)
        LDataPack.writeChar(pack, slotcount)
        LDataPack.setPosition(pack, npos)
    end
    LDataPack.writeChar(pack, var.starNum or 0)
    LDataPack.flush(pack)
end

--神醒升级
function c2sGodwakeLevel(actor, packet)
    local slot = LDataPack.readChar(packet)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.godwake) then return end
    
    local star = getGodwake(actor, slot)
    local conf = GodWakeConfig[slot] and GodWakeConfig[slot][star]
    if not (GodWakeConfig[slot] and GodWakeConfig[slot][star + 1]) then return end --下一级的信息不存在（达到最高级）
    local gLv = godequipsystem.getGodEquipLevel(actor, slot)
    if gLv < conf.limit then return end --神装等级不足
    if not actoritem.checkItems(actor, conf.items) then
        return
    end
    actoritem.reduceItems(actor, conf.items, "godwake star")
    star = star + 1
    setGodwake(actor, slot, star)
    s2cGodwakeUpdate(actor, slot, star)
    
    if star == 1 then --是第一次觉醒
        local flag = true --是否觉醒了一套神装
        local var = getActorVar(actor)
        for slot, v in pairs(GodWakeConfig) do
            local star = getVarGodwake(var, slot)
            if star <= 0 then
                flag = false
            end
        end
        if flag then
            noticesystem.broadCastNotice(noticesystem.NTP.godwake, LActor.getName(actor))
        end
    end
    
    local extra = string.format(",slot:%d,star:%d", slot, star)
    utils.logCounter(actor, "othersystem", "", extra, "godwake", "uplevel")
end

function c2sGodWakeDaShi(actor, packet)
    local var = getActorVar(actor)
    local extra
    local nextLevel = 0
    local count = getStageNum(actor)
    local starNum = (var.starNum or 0) + 1
    local conf = GodWakeStarConfig[starNum]
    if not conf then return end
    if count < conf.number then return end
    var.starNum = starNum
    nextLevel = starNum
    extra = string.format(",type:1,level:%d", starNum)
    updateAttr(actor, true)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_GodWakeDaShi)
    if pack == nil then return end
    LDataPack.writeChar(pack, nextLevel)
    LDataPack.flush(pack)
    
    utils.logCounter(actor, "othersystem", "", extra, "godwake", "dashiUp")
end

--神醒更新
function s2cGodwakeUpdate(actor, slot, newStar)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_GodWakeUp)
    if pack == nil then return end
    LDataPack.writeChar(pack, slot)
    LDataPack.writeChar(pack, newStar)
    LDataPack.flush(pack)
end

---------------------------------------------------------------------------

local function onInit(actor)
    updateAttr(actor, false)
end

local function onLogin(actor)
    s2cGodwakeInfo(actor)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_GodWakeUp, c2sGodwakeLevel)
netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_GodWakeDaShi, c2sGodWakeDaShi)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.godwakelevel = function (actor, args)
    local pack = LDataPack.allocPacket()
    LDataPack.writeChar(pack, args[1])
    LDataPack.writeChar(pack, args[2])
    LDataPack.setPosition(pack, 0)
    c2sGodwakeLevel(actor, pack)
end

gmCmdHandlers.godwakeclean = function (actor, args)
    local var = getActorVar(actor)
    var[0] = {}
    var[1] = {}
    var[2] = {}
    s2cGodwakeInfo(actor)
end
