--宝石系统

module("stonesystem", package.seeall)

require("equip.stone")
require("equip.stoneslot")
require("equip.stonelevel")
require("equip.stoneadd")

local MaxStoneHole = 6
local STONETYPE = 5
local AUTOTIMES = 6
local StoneConfig = StoneConfig
local StoneSlotConfig = StoneSlotConfig
local StoneLevelConfig = StoneLevelConfig

function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.stonedata then var.stonedata = {} end
    if not var.stonedata.stage then var.stonedata.stage = 0 end
    if not var.stonedata.powers then var.stonedata.powers = {} end
    return var.stonedata
end

function getStoneMaxLevel(actor)
    local maxlevel = 0
    local var = getActorVar(actor)
    
    for slot, v in pairs(StoneSlotConfig) do
        for j = 1, MaxStoneHole do
            local stoneId = getVarStone(var, slot, j)
            local conf = StoneConfig[stoneId]
            if conf then
                maxlevel = maxlevel + conf.level
            end
        end
    end
    return maxlevel
end
--更新属性
function updateAttr(actor, calc)
    local addAttrs = {}
    local var = getActorVar(actor)
    
    for slot, v in pairs(StoneSlotConfig) do
        for j = 1, MaxStoneHole do
            local stoneId = getVarStone(var, slot, j)
            local conf = StoneConfig[stoneId]
            if conf then
                for k, attr in pairs(conf.attr) do
                    addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
                end
            end
        end
    end
    
    for k, v in pairs(addAttrs) do
        if k == Attribute.atAtk then
            addAttrs[k] = math.floor(addAttrs[k] * (1 + StoneAddConfig[var.stage].atkper / 10000))
        elseif k == Attribute.atHpMax then
            addAttrs[k] = math.floor(addAttrs[k] * (1 + StoneAddConfig[var.stage].hpper / 10000))
        end
    end
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Stone)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    if calc then
        LActor.reCalcAttr(actor)
        --var.powers = utils.getAttrPower0(addAttrs)
        --updateRankingList(actor, getStoneTotalLv(actor)) --记入排行榜
    end
end

function getPower(actor)
    local var = getActorVar(actor)
    if not var then return 0 end
    local power = 0
    power = power + (var.powers or 0)
    return power
end

--宝石总等级
function getStoneTotalLv(actor)
    local var = getActorVar(actor)
    local lv = 0
    for slot, v in pairs(StoneSlotConfig) do
        for j = 1, MaxStoneHole do
            local stoneId = getVarStone(var, slot, j)
            lv = lv + (StoneConfig[stoneId] and StoneConfig[stoneId].level or 0)
        end
    end
    return lv
end

function setStone(actor, slot, pos, stoneId, calc)
    local var = getActorVar(actor)
    if not var then return end
    if not var[slot] then
        var[slot] = {}
    end
    var[slot][pos] = stoneId
    actorevent.onEvent(actor, aeStoneInlay, stoneId)
    if not calc then
        updateAttr(actor, true)
    end
end

function getStone(actor, slot, pos)
    local var = getActorVar(actor)
    if var and var[slot] and var[slot][pos] then
        return var[slot][pos]
    end
    return 0
end

function getVarStone(var, slot, pos)
    if var and var[slot] and var[slot][pos] then
        return var[slot][pos]
    end
    return 0
end

-------------------------------------------------------------------------------------
--宝石信息
function s2cStoneInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_StoneInfo)
    if pack == nil then return end
    local var = getActorVar(actor)
    local slotcount = 0
    LDataPack.writeShort(pack, var.stage)
    local slotpos = LDataPack.getPosition(pack)
    LDataPack.writeChar(pack, slotcount)
    for slot, v in pairs(StoneSlotConfig) do
        LDataPack.writeChar(pack, slot)
        LDataPack.writeChar(pack, MaxStoneHole)
        for j = 1, MaxStoneHole do
            local stoneId = getVarStone(var, slot, j)
            LDataPack.writeChar(pack, j)
            LDataPack.writeInt(pack, stoneId)
        end
        slotcount = slotcount + 1
    end
    local npos = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, slotpos)
    LDataPack.writeChar(pack, slotcount)
    LDataPack.setPosition(pack, npos)
    LDataPack.flush(pack)
end

--宝石镶嵌
function c2sStoneInlay(actor, packet)
    local slot = LDataPack.readChar(packet)
    local pos = LDataPack.readChar(packet)
    local stoneId = LDataPack.readInt(packet)
    
    local slotconf = StoneSlotConfig[slot]
    if not slotconf then return end
    local conf = StoneConfig[stoneId]
    if not conf then return end
    if slotconf.type ~= conf.type then --装备的宝石类型限制
        return
    end
    if not equipsystem.checkPutEquip(actor, slot) then return end
    
    if not actoritem.checkItem(actor, stoneId, 1) then
        return
    end
    actoritem.reduceItem(actor, stoneId, 1, "stone inlay")
    
    local oldStone = getStone(actor, slot, pos) --先记录旧宝石
    
    setStone(actor, slot, pos, stoneId)
    if ItemConfig[oldStone] then
        actoritem.addItem(actor, oldStone, 1, "stone change") --遵守先扣除再获得的顺序
    end
    s2cStoneUpdate(actor, slot, pos, stoneId)
    
    local extra = string.format("slot:%d,pos:%d,id:%d", slot, pos, stoneId)
    utils.logCounter(actor, "othersystem", "", extra, "stone", "inlay")
end

--宝石摘除
function c2sStoneRemove(actor, packet)
    local slot = LDataPack.readChar(packet)
    local pos = LDataPack.readChar(packet)
    
    local stoneId = getStone(actor, slot, pos)
    if not StoneConfig[stoneId] then return end --这个位置没有宝石
    setStone(actor, slot, pos, 0)
    actoritem.addItem(actor, stoneId, 1, "stone remove")
    s2cStoneUpdate(actor, slot, pos, 0)
end

function checkStoneLevel(actor, slot, pos)
    local stoneId = getStone(actor, slot, pos)
    local newStone = stoneId + 1
    local levelconf = StoneLevelConfig[newStone]
    local flag = false --是否有足够的宝石
    local items = {}
    local left = 1
    while levelconf do
        local count = LActor.getItemCount(actor, levelconf.stone)
        local number = levelconf.number
        if levelconf.stone == stoneId then
            number = number - 1 --因为身上装着一颗，所以消耗减少1
        end
        if count >= number * left then
            table.insert(items, {type = 1, id = levelconf.stone, count = number * left})
            flag = true
            break
        else
            if count > 0 then
                table.insert(items, {type = 1, id = levelconf.stone, count = count})
            end
            left = number * left - count
            levelconf = StoneLevelConfig[levelconf.stone]
        end
    end
    
    return items, flag, newStone--低级宝石不足
end

--宝石升级
function c2sStoneLevel(actor, packet)
    local slot = LDataPack.readChar(packet)
    local pos = LDataPack.readChar(packet)
    local items, canLevelUp, newStone = checkStoneLevel(actor, slot, pos)
    
    if not canLevelUp then return end
    actoritem.reduceItems(actor, items, "stone level")
    
    setStone(actor, slot, pos, newStone)
    s2cStoneUpdate(actor, slot, pos, newStone)
    
    local extra = string.format("slot:%d,pos:%d,id:%d", slot, pos, newStone)
    utils.logCounter(actor, "othersystem", "", extra, "stone", "uplevel")
end

--宝石更新
function s2cStoneUpdate(actor, slot, pos, stoneId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_StoneUpdate)
    if pack == nil then return end
    LDataPack.writeChar(pack, slot)
    LDataPack.writeChar(pack, pos)
    LDataPack.writeInt(pack, stoneId)
    LDataPack.flush(pack)
end

--宝石大师升级
function c2sStoneDashiUp(actor)
    local var = getActorVar(actor)
    if not StoneAddConfig[var.stage + 1] then return end
    local maxlevel = getStoneMaxLevel(actor)
    if StoneAddConfig[var.stage].needstar > maxlevel then return end
    var.stage = var.stage + 1
    updateAttr(actor, true)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_StoneDashiUp)
    if pack == nil then return end
    LDataPack.writeShort(pack, var.stage)
    LDataPack.flush(pack)
end

--宝石升级消耗
function c2sStoneConsume(actor, packet)
    local slot = LDataPack.readChar(packet)
    local pos = LDataPack.readChar(packet)
    
    local stoneId = getStone(actor, slot, pos)
    local newStone = stoneId + 1
    local levelconf = StoneLevelConfig[newStone]
    local flag = false --是否有足够的宝石
    local items = {}
    local left = 1
    while levelconf do
        local count = LActor.getItemCount(actor, levelconf.stone)
        local number = levelconf.number
        if levelconf.stone == stoneId then
            number = number - 1 --因为身上装着一颗，所以消耗减少1
        end
        if count >= number * left then
            table.insert(items, {type = 1, id = levelconf.stone, count = number * left})
            flag = true
            break
        else
            if count > 0 then
                table.insert(items, {type = 1, id = levelconf.stone, count = count})
            end
            left = number * left - count
            levelconf = StoneLevelConfig[levelconf.stone]
        end
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_StoneConsume)
    if pack == nil then return end
    LDataPack.writeByte(pack, flag and 1 or 0)
    LDataPack.writeShort(pack, #items)
    for k, v in ipairs(items) do
        LDataPack.writeInt(pack, v.type)
        LDataPack.writeInt(pack, v.id)
        LDataPack.writeInt(pack, v.count)
    end
    LDataPack.writeInt(pack, stoneId)
    LDataPack.writeChar(pack, slot)
    LDataPack.writeChar(pack, pos)
    LDataPack.flush(pack)
end
---------------------------------------------------------------------------

local function onInit(actor)
    updateAttr(actor, false)
end

local function onLogin(actor)
    s2cStoneInfo(actor)
end

---------------------------------------------------------------------------------------------------
--宝石一键镶嵌
function getMaxStone(actor, stone_type, stonId)--找到可以镶嵌的最高级宝石
    local tbl = {id = 0, level = 0}
    local stone_level = StoneConfig[stonId] and StoneConfig[stonId].level or 0
    for id, conf in pairs(StoneConfig) do
        if conf.type == stone_type then
            if conf.level > tbl.level and LActor.getItemCount(actor, id) > 0 then
                tbl.id = id
                tbl.level = conf.level
            end
        end
    end
    if tbl.level > stone_level then
        return tbl.id
    end
    return 0
end

function autoInlay(actor, needReplace)
    local var = getActorVar(actor)
    local isChange = false
    for slot, conf in pairs(StoneSlotConfig) do
        repeat
            if not equipsystem.checkPutEquip(actor, slot) then break end
            for pos = 1, MaxStoneHole do
                if needReplace or getVarStone(var, slot, pos) == 0 then --需不需要替换
                    local stonId = getStone(actor, slot, pos)
                    local newStone = getMaxStone(actor, conf.type, stonId)--找到可以镶嵌的最高级宝石
                    if newStone ~= 0 then
                        actoritem.reduceItem(actor, newStone, 1, "stone inlay")
                        local oldStone = getStone(actor, slot, pos) --先记录旧宝石1
                        if ItemConfig[oldStone] then
                            actoritem.addItem(actor, oldStone, 1, "stone change") --遵守先扣除再获得的顺序
                        end
                        setStone(actor, slot, pos, newStone, true)--先不更新,最后一次性更新属性
                        s2cStoneUpdate(actor, slot, pos, newStone)
                        local extra = string.format("slot:%d,pos:%d,id:%d", slot, pos, newStone)
                        utils.logCounter(actor, "othersystem", "", extra, "stone", "inlay")
                        isChange = true
                    end
                end
            end
        until true
    end
    if isChange then
        updateAttr(actor, true)
    end
end

function c2sStoneAutoInlay(actor)
    autoInlay(actor, false)
end
---------------------------------------------------------------------------------------------------
--宝石一键升级
function getTabByStone_type(actor, Stone_type)
    local tbl = {}
    for slot, conf in pairs(StoneSlotConfig) do
        if conf.type == Stone_type then
            for pos = 1, MaxStoneHole do
                local stoneId = getStone(actor, slot, pos)
                if stoneId ~= 0 then
                    local level = StoneConfig[stoneId].level
                    table.insert(tbl, {slot = slot, pos = pos, stoneId = stoneId, level = level})
                end
            end
        end
    end
    return tbl
end

function c2sStoneAutoUp(actor)
    autoInlay(actor, true)--先把身上的宝石替换成最高级的再开始升级

    local isChange = false
    for Stone_type = 1, STONETYPE do
        local tbl = getTabByStone_type(actor, Stone_type) --获取同一类型的宝石孔位
        local times = AUTOTIMES
        repeat
            if #tbl == 0 then break end--该类型的宝石所有部位都没有镶嵌
            table.sort(tbl, function (a, b) return a.level < b.level end)
            local tem = tbl[1]
            local slot, pos = tem.slot, tem.pos
            local items, canLevelUp, newStone = checkStoneLevel(actor, slot, pos)
            if not canLevelUp then
                break
            end
            actoritem.reduceItems(actor, items, "stone level")
            setStone(actor, slot, pos, newStone, true)--先不更新,最后一次性更新属性
            s2cStoneUpdate(actor, slot, pos, newStone)
            local extra = string.format("slot:%d,pos:%d,id:%d", slot, pos, newStone)
            utils.logCounter(actor, "othersystem", "", extra, "stone", "uplevel")
            tem.stoneId = newStone
            tem.level = StoneConfig[newStone].level
            isChange = true
            times = times - 1
        until times <= 0
    end
    if isChange then
        updateAttr(actor, true)
    end
end

local function init()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_StoneInlay, c2sStoneInlay)
    netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_StoneRemove, c2sStoneRemove)
    netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_StoneLevel, c2sStoneLevel)
    netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_StoneConsume, c2sStoneConsume)
    netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_StoneDashiUp, c2sStoneDashiUp)
    netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_StoneyjDashiUp, c2sStoneAutoUp)
    netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_StoneyjInlay, c2sStoneAutoInlay)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.stoneclear = function (actor, args)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    var.stonedata = nil
    s2cStoneInfo(actor)
end

gmCmdHandlers.stoneAll = function (actor, args)
    local var = getActorVar(actor)
    local maxlevels = {}
    for stone, conf in pairs(StoneConfig) do
        if not maxlevels[conf.type] then
            maxlevels[conf.type] = {
                id = stone,
                level = conf.level
            }
        end
        if conf.level > maxlevels[conf.type].level then
            maxlevels[conf.type].id = stone
            maxlevels[conf.type].level = conf.level
        end
    end
    for slot, conf in pairs(StoneSlotConfig) do
        if not var[slot] then var[slot] = {} end
        local maxStone = maxlevels[conf.type].id
        for pos = 1, MaxStoneHole do
            var[slot][pos] = maxStone
            actorevent.onEvent(actor, aeStoneInlay, maxStone)
        end
    end
    var.stage = #StoneAddConfig
    updateAttr(actor, true)
    onLogin(actor)
end
