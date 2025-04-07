-- @version2.0
-- @authorqianmeng
-- @date2017-12-22 12:05:59.
-- @system天魔斗神系统

module("tianmosystem", package.seeall)

require("equip.tianmoattr")
require("equip.tianmorank")

function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.tianmodata then var.tianmodata = {} end
    return var.tianmodata
end

function setTianmoStar(actor, slot, star)
    local var = getActorVar(actor)
    if not var then return end
    if not var[slot] then
        var[slot] = {}
    end
    var[slot].star = star
    updateAttr(actor, true)
end

--未激活以-1显示
function getTianmoStar(actor, slot)
    local var = getActorVar(actor)
    if var and var[slot] then
        return var[slot].star or -1
    end
    return -1
end

function getVarTianmoStar(var, slot)
    if var and var[slot] then
        return var[slot].star or -1
    end
    return -1
end

function setTianmoRank(actor, slot, rank)
    local var = getActorVar(actor)
    if not var then return end
    if not var[slot] then
        var[slot] = {}
    end
    var[slot].rank = rank
    updateAttr(actor, true)
end

function getTianmoRank(actor, slot)
    local var = getActorVar(actor)
    if var and var[slot] then
        return var[slot].rank or 0
    end
    return 0
end

function getVarTianmoRank(var, slot)
    if var and var[slot] then
        return var[slot].rank or 0
    end
    return 0
end

--更新属性
function updateAttr(actor, calc)
    local addAttrs = {}
    local var = getActorVar(actor)
    
    for slot, v in pairs(TianMoAttrConfig) do
        local star = getVarTianmoStar(var, slot)
        if star >= 0 and v[star] then
            for k, attr in pairs(v[star].attr) do
                addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
            end
        end
        local rank = getVarTianmoRank(var, slot)
        local conf = TianMoRankConfig[slot] and TianMoRankConfig[slot][rank]
        if rank >= 0 and conf then
            for k, attr in pairs(conf.attr) do
                addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
            end
        end
    end
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Tianmo)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    if calc then
        LActor.reCalcRoleAttr(actor)
    end
end

-------------------------------------------------------------------------------------
--天魔斗神信息
function s2cTianmoInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_TianMoInfo)
    if pack == nil then return end
    local var = getActorVar(actor)
    local slotcount = 0
    local slotpos = LDataPack.getPosition(pack)
    LDataPack.writeChar(pack, slotcount) --装备部位数量
    for slot, config in pairs(TianMoAttrConfig) do
        local star = getVarTianmoStar(var, slot)
        local rank = getVarTianmoRank(var, slot)
        if star >= 0 then
            LDataPack.writeChar(pack, slot) --装备部位
            LDataPack.writeShort(pack, star)--星级
            LDataPack.writeShort(pack, rank)--星级
            LDataPack.writeByte(pack, 1) --是否激活
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

--天魔斗神升级
function c2sTianmoLevel(actor, packet)
    local slot = LDataPack.readChar(packet)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.tianmo) then return end
    
    local star = getTianmoStar(actor, slot)
    local conf = TianMoAttrConfig[slot] and TianMoAttrConfig[slot][star]
    if not (TianMoAttrConfig[slot] and TianMoAttrConfig[slot][star + 1]) then return end --下一级的信息不存在（达到最高级）
    if LActor.getZhuansheng(actor) < conf.zslevel then return end --等级不足
    if not actoritem.checkItems(actor, conf.items) then
        return
    end
    actoritem.reduceItems(actor, conf.items, "tianmo star")
    
    local ret = math.random(1, 10000) <= conf.rate --是否成功
    if ret then
        star = star + 1
        setTianmoStar(actor, slot, star)
    end
    s2cTianmoUpdate(actor, ret, slot, star)
    
    if star == 0 then --进行了激活
        noticesystem.broadCastNotice(noticesystem.NTP.tianmo, LActor.getName(actor), utils.getEquipSlotName(slot))
    end
    
    local extra = string.format("slot:%d,star:%d", slot, star)
    utils.logCounter(actor, "othersystem", "", extra, "tianmo", "uplevel")
end

--天魔斗神更新
function s2cTianmoUpdate(actor, ret, slot, newStar)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_TianMoUp)
    if pack == nil then return end
    LDataPack.writeByte(pack, ret and 1 or 0)
    LDataPack.writeChar(pack, slot)
    LDataPack.writeShort(pack, newStar)
    LDataPack.flush(pack)
end

--天魔进阶
function c2sTianmoRank(actor, packet)
    local slot = LDataPack.readChar(packet)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.tianmo) then return end
    
    local star = getTianmoStar(actor, slot)
    local rank = getTianmoRank(actor, slot)
    local conf = TianMoRankConfig[slot] and TianMoRankConfig[slot][rank]
    if not (TianMoRankConfig[slot] and TianMoRankConfig[slot][rank + 1]) then return end --下一级的信息不存在（达到最高级）
    if star < conf.starlimit then return end --星级不足
    if not actoritem.checkItems(actor, conf.items) then
        return
    end
    actoritem.reduceItems(actor, conf.items, "tianmo rank")
    rank = rank + 1
    setTianmoRank(actor, slot, rank)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_TianMoRank)
    if pack == nil then return end
    LDataPack.writeChar(pack, slot)
    LDataPack.writeShort(pack, rank)
    LDataPack.flush(pack)
    
    local extra = string.format("slot:%d,rank:%d", slot, rank)
    utils.logCounter(actor, "othersystem", "", extra, "tianmo", "upRank")
end
---------------------------------------------------------------------------

local function onInit(actor)
    updateAttr(actor, false)
end

local function onLogin(actor)
    s2cTianmoInfo(actor)
end

function init()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_TianMoUp, c2sTianmoLevel)
    netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_TianMoRank, c2sTianmoRank)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.tianmoAll = function (actor, args)
    local var = getActorVar(actor)
    for slot, conf in pairs(TianMoAttrConfig) do
        if not var[slot] then var[slot] = {} end
        var[slot].star = #conf
    end

    for slot, conf in pairs(TianMoRankConfig) do
        if not var[slot] then var[slot] = {} end
        var[slot].rank = #conf
    end
    
    updateAttr(actor, true)
    s2cTianmoInfo(actor)
    return true
end
