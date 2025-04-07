--神迹之魂
module("sjzhsystem", package.seeall)

--神迹之魂技能升级条件([升级类型]=魔灵id)
SJZHLevelType = {
    [122] = 1,
    [123] = 2,
    [124] = 3,
    [125] = 4,
    [126] = 5,
    [127] = 6,
    [128] = 7,
}

local function getActorVar(actor, id)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.sjzh then var.sjzh = {} end
    if not var.sjzh[id] then
        var.sjzh[id] = {
            stage = 0,
            equips = {},
        }
    end
    return var.sjzh[id]
end

local function calcAttr(actor, calc)
    local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_shenjizhihun)
    attrs:Reset()
    
    local baseAttr = {}
    local power = 0
    for id, conf in ipairs(ShenJiZhiHunConfig) do
        --道具属性
        local var = getActorVar(actor, id)
        local equips = var.equips
        local attrPer = 1 + SJZHStageConfig[id][var.stage].attrPer / 10000
        for slot in ipairs(conf.slotIndex) do
            local equipId = equips[slot] or 0
            local config = ItemConfig[equipId]
            if equipId > 0 and config then
                for _, attr in ipairs(config.pattr) do
                    baseAttr[attr.type] = (baseAttr[attr.type] or 0) + math.floor(attr.value * attrPer)
                end
                power = power + config.equippower
            end
        end
        
        --技能属性
        local skillId = conf.skillId
        local level = passiveskill.getSkillLv(actor, skillId)
        local sconf = SkillPassiveConfig[skillId][level]
        if sconf.type == 1 then
            for _, attr in ipairs(sconf.addattr) do
                baseAttr[attr.type] = (baseAttr[attr.type] or 0) + attr.value
            end
        end
        power = power + sconf.power
    end
    
    for k, v in pairs(baseAttr) do
        attrs:Set(k, v)
    end
    
    if power > 0 then
        attrs:SetExtraPower(power)
    end
    if calc then
        LActor.reCalcAttr(actor)
    end
end

--外部接口, 被动技能升级条件判断
function checkSJZHStar(actor, typeUp, needStar)
    local id = SJZHLevelType[typeUp]
    if not id then return end
    local config = ShenJiZhiHunConfig[id]
    if not config then return end
    local var = getActorVar(actor, id)
    if not var then return end
    for slot in ipairs(config.slotIndex) do
        local equipId = var.equips[slot]
        local itemConfig = ItemConfig[equipId]
        if not itemConfig then return end
        if itemConfig.star < needStar then return end
    end
    return true
end

--外部接口，更新神迹之魂属性
function updateSJZHAttr(actor, calc)
    calcAttr(actor, calc)
end

--检查神迹之魂是否满足开启条件
function checkSJZHOpen(actor, id)
    local config = ShenJiZhiHunConfig[id]
    if not config then return false end
    return getSJZHTotalStar(actor, config.condition.id) >= config.condition.star
end

--获取神技之魂最低星级
function getSJZHMinStar(actor, id)
    local star
    local config = ShenJiZhiHunConfig[id]
    if not config then return 0 end
    local var = getActorVar(actor, id)
    if not var then return 0 end
    for slot in ipairs(config.slotIndex) do
        local equipId = var.equips[slot]
        local itemConfig = ItemConfig[equipId]
        if not itemConfig then return 0 end
        if not star or star > itemConfig.star then star = itemConfig.star end
    end
    return star
end

--获取神迹之魂总星数
function getSJZHTotalStar(actor, id)
    local star = 0
    local config = ShenJiZhiHunConfig[id]
    if not config then return star end
    local var = getActorVar(actor, id)
    if not var then return star end
    
    for slot in ipairs(config.slotIndex) do
        local equipId = var.equips[slot]
        local itemConfig = ItemConfig[equipId]
        if itemConfig then
            star = star + itemConfig.star
        end
    end
    return star
end

--神迹之魂-部位升星
function sjzhEquipStarUp(actor, id, slot)
    if not checkSJZHOpen(actor, id) then return end
    local var = getActorVar(actor, id)
    if not var then return end
    local equipId = var.equips[slot]
    local config = SJZHSlotCostConfig[equipId]
    if not config then return end
    
    if not actoritem.checkItem(actor, equipId, config.needCount) then return end
    if not actoritem.checkItems(actor, config.costItem) then return end
    actoritem.reduceItem(actor, equipId, config.needCount, "sjzh Equip Star Up")
    actoritem.reduceItems(actor, config.costItem, "sjzh Equip Star Up")
    
    var.equips[slot] = config.targetId
    calcAttr(actor, true)
    s2cSJZHEquipStarUp(actor, id, slot, config.targetId)
end

--神迹之魂-大师升级
function sjzhDashiUp(actor, id)
    local var = getActorVar(actor, id)
    if not var then return end
    local stageConfig = SJZHStageConfig[id]
    if not stageConfig then return end
    local stage = var.stage
    if not stageConfig[stage + 1] then return end
    local config = stageConfig[stage]
    if not config then return end
    local star = getSJZHMinStar(actor, id)
    if star < config.needStar then return end
    
    stage = stage + 1
    var.stage = stage
    calcAttr(actor, true)
    s2cSJZHDashiUp(actor, id, stage)
end

--神迹之魂-请求打造
function sjzhEquipDazao(actor, targetId)
    local config = DazaoSJZHEquipCostConfig[targetId]
    if not config then return end
    
    local needItems = {}
    for _, v in ipairs(config.needItem) do
        table.insert(needItems, v)
    end
    for _, v in ipairs(config.costItem) do
        table.insert(needItems, v)
    end
    if not actoritem.checkItems(actor, needItems) then return end
    
    actoritem.reduceItems(actor, needItems, "sjzh Equip Dazao")
    actoritem.addItem(actor, targetId, 1, "sjzh Equip Dazao")
    
    s2cSJZHEquipDazao(actor, targetId)
end

--神迹之魂-转换道具
function sjzhEquipExchange(actor, srcId, tarId, count)
    if count <= 0 then return end
    local srcItemConfig = ItemConfig[srcId]
    local tarItemConfig = ItemConfig[tarId]
    if not srcItemConfig or not tarItemConfig then return end
    local config = SJZHExchangeCostConfig[srcId]
    if not config then return end
    if not utils.checkTableValue(config.targetIds, tarId) then return end
    if not actoritem.checkItem(actor, srcId, count) then return end
    if not actoritem.checkItem(actor, NumericType_YuanBao, config.needCount * count) then return end
    actoritem.reduceItem(actor, srcId, count, "sjzh Equip Exchange")
    actoritem.reduceItem(actor, NumericType_YuanBao, config.needCount * count, "sjzh Equip Exchange")
    
    actoritem.addItem(actor, tarId, count, "sjzh Equip Exchange")
    s2cSJZHEquipExchange(actor, tarId)
end

--神迹之魂-请求穿戴
function sjzhEquipPutOn(actor, id, slot, equipId)
    if not checkSJZHOpen(actor, id) then return end
    local config = ShenJiZhiHunConfig[id]
    if not config then return end
    local var = getActorVar(actor, id)
    if not var then return end
    local beforeId = var.equips[slot]
    local srcId = beforeId or config.slotIndex[slot]
    local srcItemConfig = ItemConfig[srcId]
    if not srcItemConfig then return end
    local tarItemConfig = ItemConfig[equipId]
    if not tarItemConfig then return end
    if srcItemConfig.type ~= tarItemConfig.type then return end
    if srcItemConfig.subType ~= tarItemConfig.subType then return end
    if srcItemConfig.star > tarItemConfig.star then return end
    if not actoritem.checkItem(actor, equipId, 1) then return end
    actoritem.reduceItem(actor, equipId, 1, "sjzh Equip PutOn")
    
    var.equips[slot] = equipId
    if beforeId then
        actoritem.addItem(actor, beforeId, 1, "sjzh Equip PutOn")
    end
    calcAttr(actor, true)
    s2cSJZHEquipPutOn(actor, id, slot, equipId)
end

----------------------------------------------------------------------------------
--协议处理

--84-90 神迹之魂-基础信息
function s2cSJZHInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenjizhihun_Info)
    if not pack then return end
    LDataPack.writeChar(pack, #ShenJiZhiHunConfig)
    for id, conf in ipairs(ShenJiZhiHunConfig) do
        local var = getActorVar(actor, id)
        LDataPack.writeInt(pack, id)
        LDataPack.writeInt(pack, var.stage)
        LDataPack.writeChar(pack, #conf.slotIndex)
        local equips = var.equips
        for slot in ipairs(conf.slotIndex) do
            LDataPack.writeChar(pack, slot)
            LDataPack.writeInt(pack, equips[slot] or 0)
        end
    end
    LDataPack.flush(pack)
end

--84-91 神迹之魂-请求便捷打造
local function c2sSJZHEquipStarUp(actor, pack)
    local id = LDataPack.readInt(pack)
    local slot = LDataPack.readChar(pack)
    sjzhEquipStarUp(actor, id, slot)
end

--84-91 神迹之魂-返回便捷打造
function s2cSJZHEquipStarUp(actor, id, slot, equipId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenjizhihun_EquipStarUp)
    if not pack then return end
    LDataPack.writeInt(pack, id)
    LDataPack.writeChar(pack, slot)
    LDataPack.writeInt(pack, equipId)
    LDataPack.flush(pack)
end

--84-92 神迹之魂-请求大师升级
local function c2sSJZHDashiUp(actor, pack)
    local id = LDataPack.readInt(pack)
    sjzhDashiUp(actor, id)
end

--84-92 神迹之魂-返回大师升级
function s2cSJZHDashiUp(actor, id, stage)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenjizhihun_DashiUp)
    if not pack then return end
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, stage)
    LDataPack.flush(pack)
end

--84-93 神迹之魂-请求打造
local function c2sSJZHEquipDazao(actor, pack)
    local targetId = LDataPack.readInt(pack)
    sjzhEquipDazao(actor, targetId)
end

--84-93 神迹之魂-返回打造
function s2cSJZHEquipDazao(actor, id)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenjizhihun_EquipDazao)
    if not pack then return end
    LDataPack.writeInt(pack, id)
    LDataPack.flush(pack)
end

--84-94 神迹之魂-请求转换
local function c2sSJZHEquipExchange(actor, pack)
    local srcId = LDataPack.readInt(pack)
    local tarId = LDataPack.readInt(pack)
    local count = LDataPack.readInt(pack)
    sjzhEquipExchange(actor, srcId, tarId, count)
end

--84-94 神迹之魂-返回转换
function s2cSJZHEquipExchange(actor, equipId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenjizhihun_EquipExchange)
    if not pack then return end
    LDataPack.writeInt(pack, equipId)
    LDataPack.flush(pack)
end

--84-95 神迹之魂-请求穿戴
local function c2sSJZHEquipPutOn(actor, pack)
    local id = LDataPack.readInt(pack)
    local slot = LDataPack.readChar(pack)
    local equipId = LDataPack.readInt(pack)
    sjzhEquipPutOn(actor, id, slot, equipId)
end

--84-95 神迹之魂-返回穿戴
function s2cSJZHEquipPutOn(actor, id, slot, equipId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenjizhihun_EquipPutOn)
    if not pack then return end
    LDataPack.writeInt(pack, id)
    LDataPack.writeChar(pack, slot)
    LDataPack.writeInt(pack, equipId)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function onInit(actor)
    calcAttr(actor, false)
end

local function onLogin(actor)
    s2cSJZHInfo(actor)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShenjizhihun_EquipStarUp, c2sSJZHEquipStarUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShenjizhihun_DashiUp, c2sSJZHDashiUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShenjizhihun_EquipDazao, c2sSJZHEquipDazao)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShenjizhihun_EquipExchange, c2sSJZHEquipExchange)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShenjizhihun_EquipPutOn, c2sSJZHEquipPutOn)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.gmSJZHEquipStarUp = function(actor, args)
    local id = tonumber(args[1])
    local slot = tonumber(args[2])
    if not id or not slot then return end
    sjzhEquipStarUp(actor, id, slot)
    return true
end

gmCmdHandlers.gmSJZHsjzhDashiUp = function(actor, args)
    local id = tonumber(args[1])
    if not id then return end
    sjzhDashiUp(actor, id)
    return true
end

gmCmdHandlers.gmSJZHEquipDazao = function(actor, args)
    local targetId = tonumber(args[1])
    if not targetId then return end
    sjzhEquipDazao(actor, targetId)
    return true
end

gmCmdHandlers.gmSJZHEquipExchange = function(actor, args)
    local srcId = tonumber(args[1])
    local tarId = tonumber(args[2])
    if not srcId or not tarId then return end
    sjzhEquipExchange(actor, srcId, tarId)
    return true
end

gmCmdHandlers.gmSJZHEquipPutOn = function(actor, args)
    local id = tonumber(args[1])
    local slot = tonumber(args[2])
    local equipId = tonumber(args[3])
    if not id or not slot or not equipId then return end
    sjzhEquipPutOn(actor, id, slot, equipId)
    return true
end

gmCmdHandlers.gmSJZHInfo = function(actor, args)
    local id = tonumber(args[1])
    if not id then
        for id, conf in ipairs(ShenJiZhiHunConfig) do
            local var = getActorVar(actor, id)
            if not var then break end
            print("id = ", id)
            print("  var.stage =", var.stage)
            
            local equips = var.equips
            for slot in ipairs(conf.slotIndex) do
                print("    slot = ", slot, "equipId =", equips[slot] or 0)
            end
        end
    else
        local var = getActorVar(actor, id)
        if not var then return end
        print("id = ", id)
        print("  var.stage =", var.stage)
        
        local equips = var.equips
        local conf = ShenJiZhiHunConfig[id]
        for _, slot in ipairs(conf.equipIndex) do
            print("    slot = ", slot, "equipId =", equips[slot] or 0)
        end
    end
    return true
end

