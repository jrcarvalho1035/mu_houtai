--元素系统
module("yuansusystem", package.seeall)

local YSDAZAO_NEED_EQUIP_LENGTH = 5 --打造装备需要几件装备
local YSEQUIP_MAXSTAR = 6 --元素装备最高星级
local YSEQUIP_MINSTAR = 1 --元素装备最低星级

local function getActorVar(actor, id)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.yuansu then
        var.yuansu = {}
    end
    for id in pairs(YuanSuConfig) do
        if not var.yuansu[id] then
            var.yuansu[id] = {
                level = 0,
                stage = 0,
                dan = 0,
                equips = {},
                shengqilv = 0,
            }
        end
    end
    return var.yuansu[id]
end

function getYSEquipStar(actor)
    local star = 0
    if not actor then return star end
    for id, conf in ipairs(YuanSuConfig) do
        local var = getActorVar(actor, id)
        for _, slot in ipairs(conf.equipIndex) do
            local equipId = var.equips[slot] and var.equips[slot].equipId
            local equipStar = ItemConfig[equipId] and ItemConfig[equipId].star or 0
            star = star + equipStar
        end
    end
    print("getYSEquipStar star =", star)
    return star
end

local function calcAttr(actor, calc)
    local var = getActorVar(actor)
    local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_yuansu)
    attrs:Reset()
    
    local baseAttr = {}
    local power = 0
    for id, conf in ipairs(YuanSuConfig) do
        --炼神属性
        local var = getActorVar(actor, id)
        local attrPer = 1 + YuanSuStageConfig[id][var.stage].attrPer / 10000
        for _, attr in ipairs(YuanSuLevelConfig[id][var.level].attrs) do
            baseAttr[attr.type] = (baseAttr[attr.type] or 0) + math.floor(attr.value * attrPer)
        end
        
        for _, attr in ipairs(YuanSuConfig[id].danAttrs) do
            baseAttr[attr.type] = (baseAttr[attr.type] or 0) + attr.value * var.dan
        end

        --圣器属性
        local shengqilv = var.shengqilv or 0
        if shengqilv > 0 then
            for _, attr in ipairs(conf.shengqiAttrs) do
                baseAttr[attr.type] = (baseAttr[attr.type] or 0) + attr.value * shengqilv
            end
            power = power + conf.shengqiPower * shengqilv
        end
        
        --圣器技能属性
        local shengqiSkillId = conf.shengqiSkillId
        local level = passiveskill.getSkillLv(actor, shengqiSkillId)
        local sconf = SkillPassiveConfig[shengqiSkillId][level]
        if sconf.type == 1 then
            for _, attr in ipairs(sconf.addattr) do
                baseAttr[attr.type] = (baseAttr[attr.type] or 0) + attr.value
            end
        end
        power = power + sconf.power
        
        --装备及附灵属性
        local stars = {}
        local equips = var.equips
        for _, slot in ipairs(conf.equipIndex) do
            local equipId = equips[slot] and equips[slot].equipId
            if equipId then
                local config = ItemConfig[equipId]
                for _, attr in ipairs(config.pattr) do
                    baseAttr[attr.type] = (baseAttr[attr.type] or 0) + attr.value
                end
                for _, attr in ipairs(config.exattr) do
                    baseAttr[attr.type] = (baseAttr[attr.type] or 0) + attr.value
                end
                power = power + config.equippower
                table.insert(stars, config.star)
                
                local fulings = equips[slot].fulings
                for pos in ipairs(YSFuLingSlotConfig) do
                    local scrollId = fulings[pos]
                    if scrollId > 0 then
                        for _, attr in ipairs(YSFuLingConfig[scrollId].attrs) do
                            baseAttr[attr.type] = (baseAttr[attr.type] or 0) + attr.value
                        end
                        power = power + YSFuLingConfig[scrollId].power
                    end
                end
            end
        end
        
        --装备组合属性
        table.sort(stars, function(a, b) return a > b end)
        for count, Econf in pairs(YSEquipSuitConfig[id]) do
            local star = stars[count]
            if star and Econf[star] then
                for _, attr in ipairs(Econf[star].attrs) do
                    baseAttr[attr.type] = (baseAttr[attr.type] or 0) + attr.value
                end
            end
        end
        
        --神技技能属性
        local skillLevels = {}
        for _, skillId in ipairs(conf.skillIndex) do
            local level = passiveskill.getSkillLv(actor, skillId)
            local sconf = SkillPassiveConfig[skillId][level]
            if sconf.type == 1 then
                for _, attr in ipairs(sconf.addattr) do
                    baseAttr[attr.type] = (baseAttr[attr.type] or 0) + attr.value
                end
            end
            power = power + sconf.power
            table.insert(skillLevels, level)
        end
        
        --技能组合属性
        table.sort(skillLevels, function(a, b) return a > b end)
        for count, sconf in pairs(YSSkillGroupConfig[id]) do
            local lv = skillLevels[count]
            for i = #sconf, 1, -1 do
                if sconf[i].level <= lv then
                    for _, attr in ipairs(sconf[i].attrs) do
                        baseAttr[attr.type] = (baseAttr[attr.type] or 0) + attr.value
                    end
                    power = power + sconf[i].power
                    break
                end
            end
        end
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

function checkYSOpen(actor, id)
    local config = YuanSuConfig[id]
    if not config then return false end
    local beforeId = config.condition.id
    local var = getActorVar(actor, beforeId)
    if not var then return false end
    if var.level < config.condition.level then return false end
    return true
end

--外部接口，获取元素的等级
function getYSLevel(actor, id)
    local var = getActorVar(actor, id)
    if not var then return 0 end
    return var.level
end

--外部接口，获取元素圣器的等级
function getYSShengqiLevel(actor, id)
    local var = getActorVar(actor, id)
    if not var then return 0 end
    return var.shengqilv or 0
end

--外部接口，更新元素属性
function updateYSAttr(actor, calc)
    calcAttr(actor, calc)
end

--元素系统-炼神培养
function ysLevelUp(actor, id)
    if not checkYSOpen(actor, id) then return end
    local var = getActorVar(actor, id)
    if not var then return end
    local level = var.level
    if not YuanSuLevelConfig[id][level + 1] then return end
    local config = YuanSuLevelConfig[id][level]
    if not config then return end
    if not actoritem.checkItems(actor, config.items) then
        return
    end
    actoritem.reduceItems(actor, config.items, "ysLevelUp")
    level = level + 1
    var.level = level
    
    actorevent.onEvent(actor, aeYuanSuLevelUp, id, 1)
    calcAttr(actor, true)
    s2cYSLevelUp(actor, id, level)
end

--元素系统-不灭元神培养
function ysStageUp(actor, id)
    if not checkYSOpen(actor, id) then return end
    local var = getActorVar(actor, id)
    if not var then return end
    local level = var.stage
    if not YuanSuStageConfig[id][level + 1] then return end
    local config = YuanSuStageConfig[id][level]
    if not config then return end
    if var.level < config.needLevel then return end
    level = level + 1
    var.stage = level
    calcAttr(actor, true)
    s2cYSStageUp(actor, id, level)
end

--元素系统-淬神培养
function ysDanUp(actor, id)
    if not checkYSOpen(actor, id) then return end
    local var = getActorVar(actor, id)
    if not var then return end
    local level = var.dan
    local maxCount = YuanSuLevelConfig[id][var.level].maxCount
    if maxCount <= level then return end
    
    if not actoritem.checkItem(actor, YuanSuConfig[id].danId, 1) then
        return
    end
    actoritem.reduceItem(actor, YuanSuConfig[id].danId, 1, "ysDanUp")
    level = level + 1
    var.dan = level
    calcAttr(actor, true)
    s2cYSDanUp(actor, id, level)
end

--元素系统-打造装备
function ysEquipDaZao(actor, tarId)
    local config = DazaoYsEquipCostConfig[tarId]
    if not config then return end
    
    local needItems = {}
    for _, v in ipairs(config.needItem) do
        table.insert(needItems, v)
    end
    for _, v in ipairs(config.costItem) do
        table.insert(needItems, v)
    end
    if not actoritem.checkItems(actor, needItems) then return end
    
    actoritem.reduceItems(actor, needItems, "ysEquipDaZao")
    
    actoritem.addItem(actor, tarId, 1, "ysEquipDaZao")
    s2cYSEquipDaZao(actor, tarId)
end

--元素系统-一键穿戴或更换装备
function ysEquipOneKey(actor, id)
    if not YSEquipConfig[id] then return end
    local var = getActorVar(actor, id)
    if not var then return end
    
    local isChange = false
    local equips = var.equips
    for slot, config in pairs(YSEquipConfig[id]) do
        local equipId = equips[slot] and equips[slot].equipId
        local star = equipId and ItemConfig[equipId].star or 0
        for nStar = YSEQUIP_MAXSTAR, YSEQUIP_MINSTAR, -1 do
            if nStar > star then
                local conf = config[nStar]
                if actoritem.getItemCount(actor, conf.equipId) > 0 then
                    if not equipId then
                        equips[slot] = {
                            equipId = 0,
                            fulings = {},
                        }
                        local fulings = equips[slot].fulings
                        for pos, conf in ipairs(YSFuLingSlotConfig) do
                            fulings[pos] = 0
                        end
                    end
                    actoritem.reduceItem(actor, conf.equipId, 1, "ysEquipOneKey")
                    equips[slot].equipId = conf.equipId
                    if equipId then
                        actoritem.addItem(actor, equipId, 1, "ysEquipOneKey Replace")
                    end
                    isChange = true
                    break
                end
            else
                break
            end
        end
    end
    
    if isChange then
        actorevent.onEvent(actor, aeYSEquipPutUp)
        calcAttr(actor, true)
        s2cYSEquipInfo(actor, id)
    end
end

--元素系统-装备附灵
function ysEquipFuLing(actor, id, slot, pos, scrollId)
    if not checkYSOpen(actor, id) then return end
    
    local needItems = {YuanSuConfig[id].needItems}
    table.insert(needItems, {type = 1, id = scrollId, count = 1})
    if not actoritem.checkItems(actor, needItems) then
        return
    end
    
    local config = YSFuLingConfig[scrollId]
    if not config then return end
    if config.ysId ~= id then return end
    local var = getActorVar(actor, id)
    if not var then return end
    
    local equipId = var.equips[slot].equipId
    if not equipId then return end
    if ItemConfig[equipId].star < YSFuLingSlotConfig[pos].needStar then return end
    
    local fulings = var.equips[slot].fulings
    for npos in ipairs(YSFuLingSlotConfig) do
        if npos ~= pos then
            local nFLid = fulings[npos]
            if nFLid > 0 and YSFuLingConfig[nFLid].type == config.type then
                return
            end
        end
    end
    
    actoritem.reduceItems(actor, needItems, "ysEquipFuLing")
    
    local oldScrollId = fulings[pos]
    fulings[pos] = scrollId
    calcAttr(actor, true)
    s2cYSEquipFuLing(actor, id, slot, pos, scrollId)
    if oldScrollId ~= 0 then
        actoritem.addItem(actor, oldScrollId, 1, "ysEquipFuLing Replace")
    end
    return true
end

--元素系统-装备一键附灵
function ysEquipFLOneKey(actor, id, slot)
    if not checkYSOpen(actor, id) then return end
    
    local flItems = LActor.getFuLingItems(actor)
    local count = #flItems
    if count == 0 then return end
    table.sort(flItems, function(a, b) return ItemConfig[a].rank > ItemConfig[b].rank end)
    
    local var = getActorVar(actor, id)
    if not var then return end
    if not var.equips[slot] then return end
    local equipId = var.equips[slot].equipId
    
    local ItemConfig = ItemConfig
    local star = ItemConfig[equipId].star
    local fulings = var.equips[slot].fulings
    --先镶嵌
    local temPos = {}
    for pos, config in ipairs(YSFuLingSlotConfig) do
        if star >= config.needStar then
            local FLid = fulings[pos]
            if FLid == 0 then
                for i, scrollId in ipairs(flItems) do
                    if ysEquipFuLing(actor, id, slot, pos, scrollId) then
                        table.remove(flItems, i)
                        count = count - 1
                        break
                    end
                end
            end
        else
            break
        end
        local nFLid = fulings[pos]
        if ItemConfig[nFLid] then
            table.insert(temPos, {pos = pos, FLid = nFLid})
        end
        if count == 0 then return end
    end
    
    --再替换
    table.sort(temPos, function(a, b) return ItemConfig[a.FLid].rank < ItemConfig[b.FLid].rank end)
    for _, v in ipairs(temPos) do
        local pos = v.pos
        local FLid = v.FLid
        for i, scrollId in ipairs(flItems) do
            if ItemConfig[FLid].rank < ItemConfig[scrollId].rank then
                if ysEquipFuLing(actor, id, slot, pos, scrollId) then
                    table.remove(flItems, i)
                    count = count - 1
                    break
                end
            end
        end
        if count == 0 then return end
    end
end

function ysShengqiLevelUp(actor, id)
    if not checkYSOpen(actor, id) then return end
    local config = YuanSuConfig[id]
    if not config then return end
    local var = getActorVar(actor, id)
    if not var then return end
    local level = var.shengqilv or 0
    if level >= config.shengqiMaxLevel then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = YuanSuConfig[id].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (level or 0) >= config.shengqiMaxLevel then
		count = config.shengqiMaxLevel - (level or 0)
	end
	
	---
	
    if not actoritem.checkItems(actor, config.shengqiItems) then
        return
    end
	
    actoritem.reduceItem(actor, idz, count, "ysShengqiLevelUp")
    level = level + count
    var.shengqilv = level
    
    calcAttr(actor, true)
    s2cYSShengqiLevelUp(actor, id, level)
end

----------------------------------------------------------------------------------
--协议处理

--84-34 元素系统-炼神信息
function s2cYSInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sYuanSu_Info)
    if not pack then return end
    LDataPack.writeChar(pack, #YuanSuConfig)
    for id, conf in ipairs(YuanSuConfig) do
        local var = getActorVar(actor, id)
        LDataPack.writeChar(pack, id)
        LDataPack.writeInt(pack, var.level)
        LDataPack.writeShort(pack, var.stage)
        LDataPack.writeShort(pack, var.dan)
        LDataPack.writeShort(pack, var.shengqilv or 0)
        LDataPack.writeChar(pack, #conf.equipIndex)
        local equips = var.equips
        for _, slot in ipairs(conf.equipIndex) do
            LDataPack.writeChar(pack, slot)
            if equips[slot] then
                LDataPack.writeInt(pack, equips[slot].equipId)
                LDataPack.writeChar(pack, #YSFuLingSlotConfig)
                local fulings = equips[slot].fulings
                for pos in ipairs(YSFuLingSlotConfig) do
                    LDataPack.writeChar(pack, pos)
                    LDataPack.writeInt(pack, fulings[pos])
                end
            else
                LDataPack.writeInt(pack, 0)
                LDataPack.writeChar(pack, #YSFuLingSlotConfig)
                for pos in ipairs(YSFuLingSlotConfig) do
                    LDataPack.writeChar(pack, pos)
                    LDataPack.writeInt(pack, 0)
                end
            end
        end
    end
    LDataPack.flush(pack)
end

--84-35 元素系统-炼神培养
local function c2sYSLevelUp(actor, pack)
    local id = LDataPack.readChar(pack)
    ysLevelUp(actor, id)
end

--84-35 元素系统-炼神培养
function s2cYSLevelUp(actor, id, level)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sYuanSu_LevelUp)
    if not pack then return end
    LDataPack.writeChar(pack, id)
    LDataPack.writeInt(pack, level)
    LDataPack.flush(pack)
end

--84-36 元素系统-不灭元神培养
local function c2sYSStageUp(actor, pack)
    local id = LDataPack.readChar(pack)
    ysStageUp(actor, id)
end

--84-36 元素系统-不灭元神培养
function s2cYSStageUp(actor, id, level)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sYuanSu_StageUp)
    if not pack then return end
    LDataPack.writeChar(pack, id)
    LDataPack.writeShort(pack, level)
    LDataPack.flush(pack)
end

--84-37 元素系统-淬神培养
local function c2sYSDanUp(actor, pack)
    local id = LDataPack.readChar(pack)
    ysDanUp(actor, id)
end

--84-37 元素系统-淬神培养
function s2cYSDanUp(actor, id, level)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sYuanSu_DaneUp)
    if not pack then return end
    LDataPack.writeChar(pack, id)
    LDataPack.writeShort(pack, level)
    LDataPack.flush(pack)
end

--84-38 元素系统-更新单个元素的装备
function s2cYSEquipInfo(actor, id)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sYuanSu_EquipInfo)
    if not pack then return end
    local conf = YuanSuConfig[id]
    if not conf then return end
    local var = getActorVar(actor, id)
    LDataPack.writeChar(pack, id)
    LDataPack.writeChar(pack, #conf.equipIndex)
    local equips = var.equips
    for _, slot in ipairs(conf.equipIndex) do
        LDataPack.writeChar(pack, slot)
        if equips[slot] then
            LDataPack.writeInt(pack, equips[slot].equipId)
            LDataPack.writeChar(pack, #YSFuLingSlotConfig)
            local fulings = equips[slot].fulings
            for pos in ipairs(YSFuLingSlotConfig) do
                LDataPack.writeChar(pack, pos)
                LDataPack.writeInt(pack, fulings[pos])
            end
        else
            LDataPack.writeInt(pack, 0)
            LDataPack.writeChar(pack, #YSFuLingSlotConfig)
            for pos in ipairs(YSFuLingSlotConfig) do
                LDataPack.writeChar(pack, pos)
                LDataPack.writeInt(pack, 0)
            end
        end
    end
    LDataPack.flush(pack)
end

--84-39 元素系统-打造装备
local function c2sYSEquipDaZao(actor, pack)
    local tarId = LDataPack.readInt(pack)
    ysEquipDaZao(actor, tarId)
end

--84-39 元素系统-打造装备
function s2cYSEquipDaZao(actor, equipId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sYuanSu_EquipDaZao)
    if not pack then return end
    LDataPack.writeInt(pack, equipId)
    LDataPack.flush(pack)
end

--84-40 元素系统-一键穿戴或更换装备
local function c2sYSEquipOneKey(actor, pack)
    local id = LDataPack.readChar(pack)
    ysEquipOneKey(actor, id)
end

--84-41 元素系统-装备附灵
local function c2sYSEquipFuLing(actor, pack)
    local id = LDataPack.readChar(pack)
    local slot = LDataPack.readChar(pack)
    local pos = LDataPack.readChar(pack)
    local scrollId = LDataPack.readInt(pack)
    ysEquipFuLing(actor, id, slot, pos, scrollId)
end

--84-41 元素系统-装备附灵
function s2cYSEquipFuLing(actor, id, slot, pos, scrollId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sYuanSu_EquipFuLing)
    if not pack then return end
    LDataPack.writeChar(pack, id)
    LDataPack.writeChar(pack, slot)
    LDataPack.writeChar(pack, pos)
    LDataPack.writeInt(pack, scrollId)
    LDataPack.flush(pack)
end

--84-43 元素系统-装备一键附灵
local function c2sYSEquipFLOneKey(actor, pack)
    local id = LDataPack.readChar(pack)
    local slot = LDataPack.readChar(pack)
    ysEquipFLOneKey(actor, id, slot)
end

--84-43 元素系统-圣器升级
local function c2sYSShengqiLevelUp(actor, pack)
    local id = LDataPack.readChar(pack)
    ysShengqiLevelUp(actor, id)
end

--84-44 元素系统-圣器升级
function s2cYSShengqiLevelUp(actor, id, level)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sYuanSu_ShengqiLevelUp)
    if not pack then return end
    LDataPack.writeChar(pack, id)
    LDataPack.writeShort(pack, level)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function onInit(actor)
    calcAttr(actor, false)
end

local function onLogin(actor)
    s2cYSInfo(actor)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cYuanSu_LevelUp, c2sYSLevelUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cYuanSu_StageUp, c2sYSStageUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cYuanSu_DanUp, c2sYSDanUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cYuanSu_EquipDaZao, c2sYSEquipDaZao)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cYuanSu_EquipOneKey, c2sYSEquipOneKey)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cYuanSu_EquipFuLing, c2sYSEquipFuLing)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cYuanSu_EquipFLOneKey, c2sYSEquipFLOneKey)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cYuanSu_ShengqiLevelUp, c2sYSShengqiLevelUp)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.gmYSLevelUp = function(actor, args)
    local id = tonumber(args[1])
    if not id then return end
    ysLevelUp(actor, id)
    return true
end

gmCmdHandlers.gmYSStageUp = function(actor, args)
    local id = tonumber(args[1])
    if not id then return end
    ysStageUp(actor, id)
    return true
end

gmCmdHandlers.gmYSDanUp = function(actor, args)
    local id = tonumber(args[1])
    if not id then return end
    ysDanUp(actor, id)
    return true
end

gmCmdHandlers.gmYSEquipDaZao = function(actor, args)
    local tarId = tonumber(args[1])
    if not tarId then return end
    srcEquips = {tonumber(args[2]), tonumber(args[3]), tonumber(args[4]), tonumber(args[5]), tonumber(args[6])}
    ysEquipDaZao(actor, tarId, srcEquips)
    return true
end

gmCmdHandlers.gmYSEquipOneKey = function(actor, args)
    local id = tonumber(args[1])
    if not id then return end
    ysEquipOneKey(actor, id)
    return true
end

gmCmdHandlers.gmYSEquipFuLing = function(actor, args)
    local id = tonumber(args[1])
    local slot = tonumber(args[2])
    local pos = tonumber(args[3])
    local scrollId = tonumber(args[4])
    if not id or not slot or not pos or not scrollId then return end
    ysEquipFuLing(actor, id, slot, pos, scrollId)
    return true
end

gmCmdHandlers.gmYSEquipFLOneKey = function(actor, args)
    local id = tonumber(args[1])
    local slot = tonumber(args[2])
    if not id or not slot then return end
    ysEquipFLOneKey(actor, id, slot)
    return true
end

gmCmdHandlers.gmYSInfo = function(actor, args)
    local id = tonumber(args[1])
    if not id then
        for id, conf in ipairs(YuanSuConfig) do
            local var = getActorVar(actor, id)
            if not var then break end
            print("id = ", id)
            print("  var.level =", var.level)
            print("  var.stage =", var.stage)
            print("  var.dan =", var.dan)
            
            local equips = var.equips
            for _, slot in ipairs(conf.equipIndex) do
                if equips[slot] then
                    print("    slot = ", slot, "equipId =", equips[slot].equipId)
                    local fulings = equips[slot].fulings
                    for pos in ipairs(YSFuLingSlotConfig) do
                        print("      pos = ", pos, "scrollId =", fulings[pos])
                    end
                else
                    print("  slot = ", slot, "equipId =", 0)
                    for pos in ipairs(YSFuLingSlotConfig) do
                        print("      pos = ", pos, "scrollId =", 0)
                    end
                end
            end
        end
    else
        local var = getActorVar(actor, id)
        if not var then return end
        print("id = ", id)
        print("  var.level =", var.level)
        print("  var.stage =", var.stage)
        print("  var.dan =", var.dan)
        
        local equips = var.equips
        local conf = YuanSuConfig[id]
        for _, slot in ipairs(conf.equipIndex) do
            if equips[slot] then
                print("    slot = ", slot, "equipId =", equips[slot].equipId)
                local fulings = equips[slot].fulings
                for pos in ipairs(YSFuLingSlotConfig) do
                    print("      pos = ", pos, "scrollId =", fulings[pos])
                end
            else
                print("  slot = ", slot, "equipId =", 0)
                for pos in ipairs(YSFuLingSlotConfig) do
                    print("      pos = ", pos, "scrollId =", 0)
                end
            end
        end
    end
    return true
end

gmCmdHandlers.yuansuAll = function (actor, args)
    for id, conf in ipairs(YuanSuConfig) do
        local var = getActorVar(actor, id)
        var.level = #YuanSuLevelConfig[id]
        var.stage = #YuanSuStageConfig[id]
        var.dan = YuanSuLevelConfig[id][var.level].maxCount
        for slot, eConf in pairs(YSEquipConfig[id]) do
            var.equips[slot] = {
                equipId = eConf[YSEQUIP_MAXSTAR].equipId,
                fulings = {},
            }
            local fulings = var.equips[slot].fulings
            for pos, pConf in pairs(YSFuLingSlotConfig) do
                fulings[pos] = 710020 + id * 1000 + pos * 100
            end
        end
    end
    calcAttr(actor, true)
    s2cYSInfo(actor)
end

