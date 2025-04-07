-- @version1.0
-- @authorqianmeng
-- @date2016-12-20 10:30:00
-- @system神羽系统

module("shenyusystem", package.seeall)

require "wing.shenyulevel"
require "wing.shenyurank"
require "wing.shenyucommon"

require "wing.wingequipchange"
require "wing.wingequipup"
require "wing.wingequipadd"
require "wing.wingequipattr"

require "wing.plume"
require "wing.plumeadd"

local function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.shenyuSys then
        var.shenyuSys = {
            level = 0,
            dslevel = 0,
            shenyu = {},
            equips = {},
        }
    end
    return var.shenyuSys
end

--创建一个神羽数据结构
local function createShenyu(actor, tp)
    local var = getActorVar(actor)
    if not var then return end
    
    if not var.shenyu[tp] then
        var.shenyu[tp] = {
            rank = 0,
            level = 0,
        }
    end
    return var.shenyu[tp]
end

--返回神羽的等级与阶级
local function getShenyuInfo(actor, tp)
    local rank = 0
    local level = 0
    local var = getActorVar(actor)
    if var and var.shenyu[tp] then
        rank = var.shenyu[tp].rank
        level = var.shenyu[tp].level
    end
    return level, rank
end

local function tableAddMulit(t, attrs, n)
    for _, v in ipairs(attrs) do
        t[v.type] = (t[v.type] or 0) + (v.value * n)
    end
end

--更新属性
function updateAttr(actor, calc)
    local baseAttrs = {}
    local addAttrs = {}
    local totalRank = 0
    local power = 0
    
    local var = getActorVar(actor)
    local level = var.level

    if level > 0 then
        local conf = PlumeConfig[level]
        for k, attr in pairs(conf.attr) do
            baseAttrs[attr.type] = (baseAttrs[attr.type] or 0) + attr.value
        end
        
        local rconf = PlumeAddConfig[var.dslevel]
        if rconf then
            for k, v in pairs(rconf.attr) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
            end
        end
    end

    local currank = {}
    for i = 0, 5 do
        if var.equips[i] and var.equips[i] > 0 then
            currank[#currank + 1] = ItemConfig[var.equips[i]].rank
            tableAddMulit(addAttrs, WingEquipAttConfig[var.equips[i]].attr, 1)
        end
    end
    
    table.sort(currank, function(a, b) return a > b end)
    local count = math.floor(#currank / 2) * 2
    --套装属性
    for i = 2, count, 2 do
        for j = #WingEquipAddConfig, 1, -1 do
            if i == WingEquipAddConfig[j].number and currank[i] >= WingEquipAddConfig[j].rank then
                tableAddMulit(addAttrs, WingEquipAddConfig[j].attr, 1)
                power = power + WingEquipAddConfig[j].power
                break
            end
        end
    end

    --等级属性
    for tp = 1, ShenyuCommonConfig.maxTp do
        local level, rank = getShenyuInfo(actor, tp)
        if level > 0 then
            totalRank = totalRank + rank
            local conf = ShenyuLevelConfig[level]
            for k, v in pairs(conf.attrs[tp]) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
            end
        end
    end

    --总阶级附加属性
    local rankAttr
    for k, v in ipairs(ShenyuRankConfig) do
        if totalRank >= v.rank then
            rankAttr = v.attr
        else
            break
        end
    end
    if rankAttr then
        for k, v in pairs(rankAttr) do
            addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
        end
    end

    local attrPer = addAttrs[Attribute.atShenYuTotalPer] or 0
    for k, v in pairs(baseAttrs) do
        addAttrs[k] = (addAttrs[k] or 0) + v * (1 + attrPer / 10000)
    end

    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Shenyu)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    if power > 0 then
        attr:SetExtraPower(power)
    end
    if calc then
        LActor.reCalcAttr(actor)
    end
end

--设置神羽的等级
function setShenyuLevel(actor, tp, level)
    local shenyu = createShenyu(actor, tp)
    if not ShenyuLevelConfig[level] then return end
    shenyu.level = level
    local rank = math.floor(shenyu.level / ShenyuCommonConfig.stage)
    if rank > shenyu.rank then
        shenyu.rank = rank
    end
    updateAttr(actor, true)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sShenyuCmd_Update)
    if pack == nil then return end
    LDataPack.writeChar(pack, tp)
    LDataPack.writeInt(pack, shenyu.rank)
    LDataPack.writeInt(pack, shenyu.level)
    LDataPack.flush(pack)
    
    utils.logCounter(actor, "shenyu", tp, level)
end

---------------------------------------------------------------------------------------------------
--神羽信息
function s2cShenyuInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sShenyuCmd_Info)
    if pack == nil then return end
    LDataPack.writeChar(pack, ShenyuCommonConfig.maxTp)
    for tp = 1, ShenyuCommonConfig.maxTp do
        local level, rank = getShenyuInfo(actor, tp)
        LDataPack.writeChar(pack, tp)
        LDataPack.writeInt(pack, rank)
        LDataPack.writeInt(pack, level)
    end
    LDataPack.flush(pack)
end

--神羽升级
function c2sShenyuUpdate(actor, packet)
    local tp = LDataPack.readChar(packet)
    if tp < 0 or tp > ShenyuCommonConfig.maxTp then return end
    
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenyu) then return end --等级不足
    
    local level, rank = getShenyuInfo(actor, tp)
    local conf = ShenyuLevelConfig[level]
    if not ShenyuLevelConfig[level + 1] then return end
    if not actoritem.checkItems(actor, conf.items[tp]) then
        return
    end
    actoritem.reduceItems(actor, conf.items[tp], "shenyu up level:"..level..':'..rank)
    
    setShenyuLevel(actor, tp, level + 1)
end

--注灵信息
function s2cPlumeInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sPlumeCmd_Info)
    if pack == nil then return end
    local var = getActorVar(actor)
    LDataPack.writeShort(pack, var.level)
    LDataPack.writeShort(pack, var.dslevel or 0)
    LDataPack.flush(pack)
end

--注灵升级
function c2sPlumeLevel(actor, packet)
    local var = getActorVar(actor)
    local level = var.level
    local newLv = level + 1
    if not PlumeConfig[newLv] then return end
    local conf = PlumeConfig[level]
    if not conf then return end
    if not actoritem.checkItems(actor, conf.item) then return end
    actoritem.reduceItems(actor, conf.item, "plume level")
    var.level = newLv
    updateAttr(actor, true)
    s2cPlumeUpdate(actor, newLv)
    utils.logCounter(actor, "othersystem", "", newLv, "plume", "uplevel")

    actorevent.onEvent(actor, aeShenyuLevel, 1)
end

--注灵大师升级
local function c2sDashiUp(actor, pack)
    local var = getActorVar(actor)
    local dslevel = var.dslevel or 0
    if not PlumeAddConfig[dslevel + 1] then return end
    dslevel = dslevel + 1
    if PlumeConfig[var.level].rank < PlumeAddConfig[dslevel].rank then return end
    var.dslevel = dslevel
    updateAttr(actor, true)
    s2cPlumeDashiUpdate(actor, dslevel)
    utils.logCounter(actor, "othersystem", "", dslevel, "plume", "DashiUp")
end

--注灵大师更新
function s2cPlumeDashiUpdate(actor, level)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sPlumeCmd_DashiUp)
    if pack == nil then return end
    LDataPack.writeShort(pack, level)
    LDataPack.flush(pack)
end

--注灵更新
function s2cPlumeUpdate(actor, level)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sPlumeCmd_Up)
    if pack == nil then return end
    LDataPack.writeShort(pack, level)
    LDataPack.flush(pack)
end

--翅膀装备
function sendWingEquipInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sWingEquip_Info)
    local var = getActorVar(actor)
    LDataPack.writeChar(pack, 6)
    for i = 0, 5 do
        LDataPack.writeInt(pack, var.equips[i] or 0)
    end
    LDataPack.flush(pack)
end

--翅膀装备
function c2sPutOn(actor, pack)
    local equipid = LDataPack.readInt(pack)
    local var = getActorVar(actor)
    
    if not ItemConfig[equipid] or ItemConfig[equipid].type ~= 136 then
        return
    end
    
    if ItemConfig[equipid].rank > PlumeConfig[var.level].rank then
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
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sWingEquip_PutOn)
    LDataPack.writeInt(pack, equipid)
    LDataPack.flush(pack)
    
    updateAttr(actor, true)
end

--翅膀装备
function c2sStageUp(actor, pack)
    local puttype = LDataPack.readChar(pack)
    local targetid = LDataPack.readInt(pack)
    
    if not ItemConfig[targetid] then return end
    
    local var = getActorVar(actor)
    if ItemConfig[targetid].rank > PlumeConfig[var.level].rank or ItemConfig[targetid].rank <= 1 then
        return
    end
    
    if puttype == 1 then
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
        updateAttr(actor, true)
    else
        actoritem.addItem(actor, targetid, 1, "wingequip stage up")
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sWingEquip_StageUp)
    LDataPack.writeInt(pack, targetid)
    LDataPack.writeChar(pack, puttype)
    LDataPack.flush(pack)
end

--翅膀装备
function c2sChange(actor, pack)
    local srcid = LDataPack.readInt(pack)
    local targetid = LDataPack.readInt(pack)
    
    if not ItemConfig[srcid] or ItemConfig[srcid].type ~= 136 then
        return
    end
    if not ItemConfig[targetid] or ItemConfig[targetid].type ~= 136 then
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
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sWingEquip_Change)
    LDataPack.writeChar(pack, 1)
    LDataPack.writeInt(pack, targetid)
    LDataPack.flush(pack)
end

---------------------------------------------------------------------------------------------------
--事件

local function onInit(actor)
    updateAttr(actor, false)
end

local function onLogin(actor)
    s2cPlumeInfo(actor)
    s2cShenyuInfo(actor)
    sendWingEquipInfo(actor)
end

local function init()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Old, Protocol.cShenyuCmd_Update, c2sShenyuUpdate)
    netmsgdispatcher.reg(Protocol.CMD_Old, Protocol.cPlumeCmd_Up, c2sPlumeLevel)
    netmsgdispatcher.reg(Protocol.CMD_Old, Protocol.cPlumeCmd_DashiUp, c2sDashiUp)
    netmsgdispatcher.reg(Protocol.CMD_Old, Protocol.cWingEquip_PutOn, c2sPutOn)
    netmsgdispatcher.reg(Protocol.CMD_Old, Protocol.cWingEquip_StageUp, c2sStageUp)
    netmsgdispatcher.reg(Protocol.CMD_Old, Protocol.cWingEquip_Change, c2sChange)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.shenyuAll = function (actor, args)
    local var = getActorVar(actor)
    var.level = #PlumeConfig
    var.dslevel = #PlumeAddConfig
    local maxlevel = #ShenyuLevelConfig
    for tp = 1, ShenyuCommonConfig.maxTp do
        var.shenyu[tp] = {
            rank = math.floor(maxlevel / ShenyuCommonConfig.stage),
            level = maxlevel,
        }
    end
    var.equips[0] = 611001
    var.equips[1] = 611002
    var.equips[2] = 611003
    var.equips[3] = 611004
    var.equips[4] = 611005
    var.equips[5] = 611006
    updateAttr(actor, true)
    s2cPlumeInfo(actor)
    s2cShenyuInfo(actor)
    sendWingEquipInfo(actor)
    return true
end

gmCmdHandlers.shenyuclear = function (actor, args)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    var.shenyuSys = nil
    return true
end

