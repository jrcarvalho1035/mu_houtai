--装备系统，熔炼装备
module("equipsystem", package.seeall)

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.equip then
        var.equip = {}
        for i = 0, EquipType_Max - 1 do
            var.equip[i] = 0
        end
    end
    return var.equip
end

function getLianjinActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.lianjin then
        var.lianjin = {}
        var.lianjin.level = 0
        var.lianjin.exp = 0
    end
    return var.lianjin
end

function getHufuActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.hufu then
        var.hufu = {}
        var.hufu.level = 0
    end
    return var.hufu
end

--返回装备品质为quality以上的装备数量
function getEquipCountQuality(actor, quality)
    local var = getActorVar(actor)
    local count = 0
    for i = 0, EquipType_Max - 1 do
        if var[i] ~= 0 and ItemConfig[var[i]].quality >= quality then
            count = count + 1
        end
    end
    return count
end

--返回装备品阶为rank以上的装备数量
function getEquipCountRank(actor, rank)
    local var = getActorVar(actor)
    local count = 0
    for i = 0, EquipType_Max - 1 do
        if var[i] ~= 0 and ItemConfig[var[i]].rank >= rank then
            count = count + 1
        end
    end
    return count
end

--返回所有角色N阶以上与紫色以上的装备数量
function getGoodEquipCount(actor, value)
    local sum = 0
    local var = getActorVar(actor)
    for i = 0, EquipSlotType_Max - 1 do
        if ItemConfig[var[i]] and ItemConfig[var[i]].rank >= value and ItemConfig[var[i]].quality >= 3 then
            sum = sum + 1
        end
    end
    
    return sum
end

--返回全身X星以上的装备个数
function getEquipCountStar(actor, star)
    local var = getActorVar(actor)
    local count = 0
    for i = 0, EquipType_Max - 1 do
        if var[i] ~= 0 and ItemConfig[var[i]].star >= star then
            count = count + 1
        end
    end
    return count
end

--返回装备部位的阶数
function getEquipRank(actor, roleId, slot)
    local var = getActorVar(actor)
    if ItemConfig[var[i]] then
        return ItemConfig[var[i]].rank
    end
    return 0
end

--返回装备部位的品质
function getEquipQuality(actor, slot)
    local var = getActorVar(actor)
    if ItemConfig[var[slot]] then
        return ItemConfig[var[slot]].quality
    end
    return 0
end

calculateEquip = utils.memoize(calculateEquip)

function checkPutEquip(actor, slot)
    local var = getActorVar(actor)
    return var[slot] ~= 0
end

function getPutEquipId(actor, slot)
    local var = getActorVar(actor)
    return var[slot]
end

function getPutEquipAttr(actor, slot)
    local var = getActorVar(actor)
    if ItemConfig[var[slot]] then
        return ItemConfig[var[slot]].pattr
    end
    return {}
end

function getHufuLevel(actor)
    if not actor then return 0 end
    local var = getHufuActorVar(actor)
    return var.level
end

--更新属性
function updateAttr(actor, calc)
    local addAttrs = {}
    local var = getActorVar(actor)
    local power = 0
    for i = 0, EquipType_Max - 1 do
        if var[i] ~= 0 then
            for k, attr in pairs(ItemConfig[var[i]].pattr) do
                addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
            end
            for k, attr in pairs(ItemConfig[var[i]].exattr) do
                addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
            end
            power = power + ItemConfig[var[i]].equippower
        end
    end
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Equip)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    attr:SetExtraPower(power)
    if calc then
        LActor.reCalcAttr(actor)
    end
    if System.isCommSrv() then
        local rankpower = utils.getAttrPower0(addAttrs) + power
        utils.rankfunc.updateRankingList(actor, rankpower, RankingType_Equip)
    end
end
--炼金阵属性
function updateLianjinAttr(actor, calc)
    local addAttrs = {}
    local var = getLianjinActorVar(actor)
    
    for k, attr in pairs(LianjinConfig[var.level].addattr) do
        addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
    end
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Lianjin)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    if calc then
        LActor.reCalcAttr(actor)
    end
end

function updateHufuAttr(actor, calc)
    local addAttrs = {}
    local var = getHufuActorVar(actor)
    for _, v in ipairs(TalismanConfig[var.level].attr) do
        addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
    end
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Hufu)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    if calc then
        LActor.reCalcAttr(actor)
    end
end

function c2sPutOn(actor, pack)
    local bagequipid = LDataPack.readInt(pack)
    local conf = ItemConfig[bagequipid]
    if not conf then return end
    if LActor.getLevel(actor) < conf.level then return end
    if not actoritem.checkItem(actor, bagequipid, 1) then return end
    local var = getActorVar(actor)
    local beforeid = var[conf.subType]
    if not zhuansheng.checkZSLevel(actor, conf.zslevel) then
        return
    end
    if beforeid ~= 0 then --替换装备
        var[conf.subType] = bagequipid
        actoritem.reduceItem(actor, bagequipid, 1, "equip put on")
        actoritem.addItem(actor, beforeid, 1, "equip put on", 1)
        
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_EquipChange)
        if pack == nil then return end
        LDataPack.writeShort(pack, conf.subType)
        LDataPack.writeInt(pack, bagequipid)
        LDataPack.flush(pack)
    else --穿装备
        var[conf.subType] = bagequipid
        actoritem.reduceItem(actor, bagequipid, 1, "equip put on")
        
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_EquipPutOn)
        if pack == nil then return end
        LDataPack.writeShort(pack, conf.subType)
        LDataPack.writeInt(pack, bagequipid)
        LDataPack.flush(pack)
    end
    updateAttr(actor, true)
    
    actorevent.onEvent(actor, aePutEquip, beforeid, bagequipid)
end

function c2sPutOneKey(actor, pack)
    local len = LDataPack.readChar(pack)
    if len < 0 then return end
    local equips = {}
    local var = getActorVar(actor)
    for i = 1, len do
        equips[i] = LDataPack.readInt(pack)
        local conf = ItemConfig[equips[i]]
        if not conf then return end
        if LActor.getLevel(actor) < conf.level then return end
        if not actoritem.checkItem(actor, equips[i], 1) then return end
        if not zhuansheng.checkZSLevel(actor, conf.zslevel) then
            return
        end
    end
    for i = 1, len do
        local conf = ItemConfig[equips[i]]
        local beforeid = var[conf.subType]
        var[conf.subType] = equips[i]
        actoritem.reduceItem(actor, equips[i], 1, "equip put on")
        if beforeid ~= 0 then
            actoritem.addItem(actor, beforeid, 1, "equip put on", 1)
        end
        actorevent.onEvent(actor, aePutEquip, beforeid, equips[i])
    end
    updateAttr(actor, true)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_OneKey)
    if pack == nil then return end
    LDataPack.writeChar(pack, EquipType_Max)
    for i = 0, EquipType_Max - 1 do
        LDataPack.writeInt(pack, var[i])
    end
    LDataPack.flush(pack)
end

function sendEquipList(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_EquipList)
    if pack == nil then return end
    LDataPack.writeChar(pack, EquipType_Max)
    for i = 0, EquipType_Max - 1 do
        LDataPack.writeInt(pack, var[i])
    end
    LDataPack.flush(pack)
end

function sendLianjinInfo(actor)
    local var = getLianjinActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_LianjinLevel)
    LDataPack.writeInt(pack, var.level)
    LDataPack.writeInt(pack, var.exp)
    LDataPack.flush(pack)
end

function addSmetlItem(additems, additem)
    for i = 1, #additem do
        local ishave = false
        for k, v in ipairs(additems) do
            if v.id == additem[i].id then
                v.count = v.count + additem[i].count
                ishave = true
                break
            end
        end
        if not ishave then
            additems[#additems + 1] = {}
            additems[#additems].id = additem[i].id
            additems[#additems].count = additem[i].count
        end
    end
end

function smelt(actor, pack)
    local len = LDataPack.readShort(pack)
    if len < 0 then return end
    local additems = {}
    local equips = {}
    local addexp = 0
    if len == 0 then
        LActor.smeltAllEquip(actor)
        actorevent.onEvent(actor, aeSmeltEquip, 1)
    else
        for i = 1, len do
            local equipuid = LDataPack.readDouble(pack)
            local equipid = LActor.getItemIdByUid(actor, equipuid, BagType_Equip)
            local conf = ItemConfig[equipid]
            if not conf then return end
            if not actoritem.checkItem(actor, equipid, 1) then return end
            if not SmeltConfig[conf.rank] or not SmeltConfig[conf.rank][conf.quality] then return end
            equips[#equips + 1] = {id = equipid, count = 1}
            addSmetlItem(additems, SmeltConfig[conf.rank][conf.quality].additem)
            -- for k, v in ipairs(SmeltConfig[conf.rank][conf.quality].additem) do
            --     if v.id == NumericType_LianjinExp then
            --         addexp = addexp + v.count
            --     end
            -- end
            --addexp = addexp + SmeltConfig[conf.rank][conf.quality].addexp
        end
        actoritem.reduceItems(actor, equips)
        actoritem.addItems(actor, additems, "equip smelt")
        addSmeltExp(actor, 0, additems)
        actorevent.onEvent(actor, aeSmeltEquip, len)
    end
end

function addSmeltExp(actor, exp, additems)
    local var = getLianjinActorVar(actor)
    var.exp = var.exp + exp
    local before = var.level
    while(LianjinConfig[var.level + 1] and var.exp >= LianjinConfig[var.level].needexp) do
        var.exp = var.exp - LianjinConfig[var.level].needexp
        var.level = var.level + 1
    end
    if var.level > before then
        updateLianjinAttr(actor, true)
    end
    s2cSmeltEquip(actor, additems or {})
end

function s2cSmeltEquip(actor, additems)
    local var = getLianjinActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_EquipSmelt)
    LDataPack.writeChar(pack, #additems)
    for k, v in ipairs(additems) do
        LDataPack.writeInt(pack, v.id)
        LDataPack.writeInt(pack, v.count)
    end
    LDataPack.writeInt(pack, var.level)
    LDataPack.writeInt(pack, var.exp)
    LDataPack.flush(pack)
end

function c2shufuLeveUp(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.hufu) then return end
    local var = getHufuActorVar(actor)
    local old = var.level
    if not TalismanConfig[old + 1] then return end
    local needcount = TalismanConfig[old].essence
    if not actoritem.checkItem(actor, NumericType_Essence, needcount) then return end
    actoritem.reduceItem(actor, NumericType_Essence, needcount, "hufu level up")
    local new = old + 1
    var.level = new
    updateHufuAttr(actor, true)
    
    actorevent.onEvent(actor, aeTalismanUpLevel, new)

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_hufuLevelUp)
    LDataPack.writeShort(pack, new)
    LDataPack.flush(pack)
    
    utils.logCounter(actor, "othersystem", new, "", "hufu", "levelUp")
end

function sendHufuInfo(actor)
    local var = getHufuActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_hufuInfo)
    LDataPack.writeShort(pack, var.level)
    LDataPack.flush(pack)
end

local function onLogin(actor)
    sendEquipList(actor)
    sendLianjinInfo(actor)
    sendHufuInfo(actor)
end
local function onInit(actor)
    updateAttr(actor, false)
    updateLianjinAttr(actor, false)
    updateHufuAttr(actor, false)
end

local function init()
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Equip, Protocol.cEquipCmd_EquipPutOn, c2sPutOn)
    netmsgdispatcher.reg(Protocol.CMD_Equip, Protocol.cEquipCmd_ReqEquipSmelt, smelt)
    netmsgdispatcher.reg(Protocol.CMD_Equip, Protocol.cEquipCmd_Onekey, c2sPutOneKey)
    netmsgdispatcher.reg(Protocol.CMD_Equip, Protocol.cEquipCmd_hufuLevelUp, c2shufuLeveUp)
end
table.insert(InitFnTable, init)

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.setEquipId = function (actor, args)
    local rank = tonumber(args[1]) or 16
    local quality = tonumber(args[2]) or 9
    local job = 1--LActor.getJob(actor)
    local var = getActorVar(actor)
    for slot = 0, 9 do
        local equipid = 100000 + slot * 10000 + job * 1000 + quality * 100 + rank
        if ItemConfig[equipid] then
            local beforeid = var[slot]
            var[slot] = equipid
            actorevent.onEvent(actor, aePutEquip, beforeid, equipid)
        end
    end
    updateAttr(actor, true)
    onLogin(actor)
    return true
end

gmCmdHandlers.equipAll = function (actor, args)
    gmCmdHandlers.setEquipId(actor, {16, 9})
end

gmCmdHandlers.lianjinAll = function (actor, args)
    local var = getLianjinActorVar(actor)
    var.level = #LianjinConfig
    updateLianjinAttr(actor, true)
    sendLianjinInfo(actor)
end

gmCmdHandlers.hufuAll = function (actor, args)
    local var = getHufuActorVar(actor)
    var.level = #TalismanConfig
    updateHufuAttr(actor, true)
    sendHufuInfo(actor)
end
