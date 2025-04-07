module("lingqisystem", package.seeall)

--灵器技能升级条件([升级类型]=灵器id)
LQLevelType = {
    [27] = 1,
    [28] = 2,
    [29] = 3,
    [30] = 4,
    [31] = 5,
    [32] = 6,
    [33] = 7,
    [34] = 8,
    [35] = 9,
    [36] = 10,
    [37] = 11,
    [38] = 12,
    [39] = 13,
    [40] = 14,
    [41] = 15,
    [42] = 16,
    [43] = 17,
    [44] = 18,
    [45] = 19,
    [46] = 20,
    [47] = 21,
    [48] = 22,
    [49] = 23,
    [50] = 24,
    [51] = 25,
    [52] = 26,
    [53] = 27,
    [54] = 28,
    [55] = 29,
    [56] = 30,
}

--灵器技能升阶条件([升级类型]=灵器id)
LQStageType = {
    [57] = 1,
    [58] = 2,
    [59] = 3,
    [60] = 4,
    [61] = 5,
    [62] = 6,
    [63] = 7,
    [64] = 8,
    [65] = 9,
    [66] = 10,
    [67] = 11,
    [68] = 12,
    [69] = 13,
    [70] = 14,
    [71] = 15,
    [72] = 16,
    [73] = 17,
    [74] = 18,
    [75] = 19,
    [76] = 20,
    [77] = 21,
    [78] = 22,
    [79] = 23,
    [80] = 24,
    [81] = 25,
    [82] = 26,
    [83] = 27,
    [84] = 28,
    [85] = 29,
    [86] = 30,
}

--X品质灵器升级属性万分比([品质] = 属性类型)
LQQualityType = {
    [3] = Attribute.atLQPurpleLevelPer,
    [4] = Attribute.atLQOrangeLevelPer,
    [5] = Attribute.atLQRedLevelPer,
}

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.lingqi then
        var.lingqi = {
            lingqis = {},
            pills = {},
        }
    end
    return var.lingqi
end

local function initLingQi(var, id)
    var.lingqis[id] = {
        level = 0,
        exp = 0,
        stage = 0,
    }
    return var.lingqis[id]
end

local function getLQLevel(actor, id)
    local var = getActorVar(actor)
    if not var.lingqis[id] then return 0 end
    return var.lingqis[id].level
end

local function getLQStage(actor, id)
    local var = getActorVar(actor)
    if not var.lingqis[id] then return 0 end
    return var.lingqis[id].stage
end

function getLingQiStage(actor)
    local stage = 0
    if not actor then return stage end
    for id in pairs(LingQiBaseConfig) do
        stage = stage + getLQStage(actor, id)
    end
    return stage
end

function getLingQiActive(actor)
    local count = 0
    if not actor then return count end
    for id in pairs(LingQiBaseConfig) do
        if getLQStage(actor, id) > 0 then
            count = count + 1
        end
    end
    return count
end

local function updateAttr(actor, isCalc)
    local var = getActorVar(actor)
    local addAttrs = {}
    local baseAttrs = {}
    local power = 0
    
    local lings = var.lingqis
    for id, conf in pairs(LingQiBaseConfig) do
        --升级属性
        local level = lings[id] and lings[id].level or 0
        local lvConf = LingQiLevelConfig[conf.quality] and LingQiLevelConfig[conf.quality][level]
        if level > 0 and lvConf then
            local quality = conf.quality
            if not baseAttrs[quality] then
                baseAttrs[quality] = {}
            end
            
            for _, v in ipairs(lvConf.attrs) do
                baseAttrs[quality][v.type] = (baseAttrs[quality][v.type] or 0) + v.value
            end
        end
        
        --进阶属性
        local stage = lings[id] and lings[id].stage or 0
        if stage > 0 then
            for _, v in ipairs(conf.stageAttrs) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * stage
            end
        end
        
        --基础技能属性
        for _, skillId in ipairs(conf.baseSkills) do
            local level = passiveskill.getSkillLv(actor, skillId)
            local conf = SkillPassiveConfig[skillId][level]
            if conf.type == 1 then
                for k, v in ipairs(conf.addattr) do
                    addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
                end
            end
            power = power + conf.power
        end
        
        --天赋技能属性
        for _, skillId in ipairs(conf.stageSkills) do
            local level = passiveskill.getSkillLv(actor, skillId)
            local conf = SkillPassiveConfig[skillId][level]
            if conf.type == 1 then
                for k, v in ipairs(conf.addattr) do
                    addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
                end
            end
            power = power + conf.power
        end
    end
    
    for id, conf in pairs(LingQiPillConfig) do
        local count = var.pills[id] or 0
        if count > 0 then
            for _, v in ipairs(conf.baseAttrs) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * count
            end
        end
    end
    
    for quality, attrs in pairs(baseAttrs) do
        local attrType = LQQualityType[quality]
        local lqLevelPer = (addAttrs[attrType] or 0) / 10000 + 1
        for k, v in pairs(attrs) do
            addAttrs[k] = (addAttrs[k] or 0) + math.floor(v * lqLevelPer)
        end
    end
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_lingqi)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    attr:SetExtraPower(power)
    if isCalc then
        LActor.reCalcAttr(actor)
    end
end

function updateLQAttr(actor, isCalc)
    updateAttr(actor, isCalc)
end

function checkLQLevel(actor, typeUp, needLv)
    local id = LQLevelType[typeUp]
    if not id then return end
    return getLQLevel(actor, id) >= needLv
end

function checkLQStage(actor, typeUp, needLv)
    local id = LQStageType[typeUp]
    if not id then return end
    return getLQStage(actor, id) >= needLv
end

--灵器升级
function lqLevelUp(actor, id, index)
    local var = getActorVar(actor)
    if not LingQiBaseConfig[id] then return end
    local itemId = LingQiBaseConfig[id].lvNeedItem[index]
    if not itemId then return end
    
    local config = LingQiConsumeConfig[itemId]
    if not config then return end
    
    local quality = LingQiBaseConfig[id].quality
    local conf = LingQiLevelConfig[quality]
    if not conf then return end
    
    local count = actoritem.getItemCount(actor, itemId)
    if count <= 0 then return end
    
    local lingqi = var.lingqis[id]
    if not lingqi then return end
    
    local level = lingqi.level
    if not conf[level + 1] then return end
    
    local exp = lingqi.exp
    local needexp = conf[level].needexp
    
    count = math.min(count, math.ceil((needexp - exp) / config.addExp))
    actoritem.reduceItem(actor, itemId, count, "lingqi level up")
    
    exp = exp + config.addExp * count
    while exp >= needexp do
        exp = exp - needexp
        level = level + 1
        if not conf[level + 1] then break end
        needexp = conf[level].needexp
    end
    
    lingqi.level = level
    lingqi.exp = exp
    
    updateAttr(actor, true)
    s2cLevelUp(actor, id, level, exp)
end

--灵器激活
function lqActive(actor, id)
    local var = getActorVar(actor)
    local config = LingQiBaseConfig[id]
    if not config then return end
    
    if not actoritem.checkItems(actor, config.activeItem) then return end
    actoritem.reduceItems(actor, config.activeItem, "lingqi active up")
    
    var.lingqis[id] = {
        level = 1,
        exp = 0,
        stage = 1
    }
    actorevent.onEvent(actor, aeLingQiActive, 1)
    actorevent.onEvent(actor, aeLingQiStageUp, 1)
    updateAttr(actor, true)
    s2cLevelUp(actor, id, 1, 0)
    s2cStageUp(actor, id, 1)
end

--灵器进阶
function lqStageUp(actor, id)
    local var = getActorVar(actor)
    local config = LingQiBaseConfig[id]
    if not config then return end
    
    local lingqi = var.lingqis[id]
    if not lingqi then
        lqActive(actor, id)
        return
    end
    
    local stage = lingqi.stage
    if stage >= config.maxStage then return end
    if not actoritem.checkItems(actor, config.needItem) then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = LingQiBaseConfig[id].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (stage or 0) >= config.maxStage then
		count = config.maxStage - (stage or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "Count: "..count.." Stage: "..stage)
    
    stage = stage + count
    lingqi.stage = stage
    
    actorevent.onEvent(actor, aeLingQiStageUp, 1)
    updateAttr(actor, true)
    s2cStageUp(actor, id, stage)
end

--获取印记最大可使用数量
local function getMaxCanUse(index, level)
    local config = LingQiPillMaxConfig[index]
    local max = 0
    for i = 1, #config do
        if config[i].level <= level then
            max = config[i].maxLevel
        else
            break
        end
    end
    return max
end

--灵器印记升级
function lqUsePill(actor, index)
    local var = getActorVar(actor)
    
    local max = getMaxCanUse(index, LActor.getLevel(actor))
    local useCount = var.pills[index] or 0
    if useCount >= max then return end
	
	--função para chamar ID e contar a quantidade de itens
	local id = LingQiPillConfig[index].itemuse[1]
	count = actoritem.getItemCount(actor, id)
	
	if count + (useCount or 0) >= max then
		count = max - (useCount or 0)
	end
	
	---
    
    if not actoritem.checkItems(actor, LingQiPillConfig[index].needitem) then return end
	
	
    actoritem.reduceItem(actor, id, count, "lingqi use pill")
    
    useCount = useCount + count
    var.pills[index] = useCount
    
    updateAttr(actor, true)
    s2cUsePill(actor, index, useCount)
end

----------------------------------------------------------------------------------
--协议处理

--84-60 灵器系统-基础信息
function s2cLingQiInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sLingQi_Info)
    if not pack then return end
    
    local lingqis = var.lingqis
    LDataPack.writeChar(pack, #LingQiBaseConfig)
    for id in ipairs(LingQiBaseConfig) do
        local level = lingqis[id] and lingqis[id].level or 0
        local exp = lingqis[id] and lingqis[id].exp or 0
        local stage = lingqis[id] and lingqis[id].stage or 0
        
        LDataPack.writeInt(pack, level)
        LDataPack.writeInt(pack, exp)
        LDataPack.writeInt(pack, stage)
    end
    
    local pills = var.pills
    LDataPack.writeChar(pack, #LingQiPillConfig)
    for index in ipairs(LingQiPillConfig) do
        LDataPack.writeInt(pack, pills[index] or 0)
    end
    LDataPack.flush(pack)
end

--84-61 灵器系统-请求升级
local function c2sLevelUp(actor, pack)
    local id = LDataPack.readChar(pack)
    local index = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.lingqi) then return end
    lqLevelUp(actor, id, index)
end

--84-61 灵器系统-返回升级
function s2cLevelUp(actor, id, level, exp)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sLingQi_LevelUp)
    if not pack then return end
    
    LDataPack.writeChar(pack, id)
    LDataPack.writeInt(pack, level)
    LDataPack.writeInt(pack, exp)
    LDataPack.flush(pack)
end

--84-62 灵器系统-请求进阶
local function c2sStageUp(actor, pack)
    local id = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.lingqi) then return end
    lqStageUp(actor, id)
end

--84-62 灵器系统-返回进阶
function s2cStageUp(actor, id, stage)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sLingQi_StageUp)
    if not pack then return end
    
    LDataPack.writeChar(pack, id)
    LDataPack.writeInt(pack, stage)
    LDataPack.flush(pack)
end

--84-63 灵器系统-请求培养
local function c2sUsePill(actor, pack)
    local index = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.lingqi) then return end
    lqUsePill(actor, index)
end

--84-63 灵器系统-返回培养
function s2cUsePill(actor, index, count)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sLingQi_UsePill)
    if not pack then return end
    
    LDataPack.writeChar(pack, index)
    LDataPack.writeInt(pack, count)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function onLogin(actor)
    s2cLingQiInfo(actor)
end

local function onInit(actor)
    updateAttr(actor, false)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeInit, onInit)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cLingQi_LevelUp, c2sLevelUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cLingQi_StageUp, c2sStageUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cLingQi_UsePill, c2sUsePill)
end

table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.lqlevel = function (actor, args)
    local id = tonumber(args[1])
    local index = tonumber(args[2])
    lqLevelUp(actor, id, index)
    return true
end

gmCmdHandlers.lqstage = function (actor, args)
    local id = tonumber(args[1])
    lqStageUp(actor, id)
    return true
end

gmCmdHandlers.lqpill = function (actor, args)
    local index = tonumber(args[1])
    lqUsePill(actor, index)
    return true
end

gmCmdHandlers.lqprint = function (actor, args)
    local var = getActorVar(actor)
    for id in ipairs(LingQiBaseConfig) do
        print("----------")
        print("id = ", id)
        local lingqi = var.lingqis[id]
        print("level = ", lingqi and lingqi.level or 0)
        print("exp = ", lingqi and lingqi.exp or 0)
        print("stage = ", lingqi and lingqi.stage or 0)
    end
    
    for id in ipairs(LingQiPillConfig) do
        print("lqpill id =", id, "count =", var.pills[id] or 0)
    end
    return true
end

gmCmdHandlers.lingqiAll = function (actor, args)
    local var = getActorVar(actor)
    for id, config in pairs(LingQiBaseConfig) do
        local conf = LingQiLevelConfig[config.quality]
        var.lingqis[id] = {
            level = #conf,
            exp = 0,
            stage = config.maxStage,
        }
    end
    for index, conf in pairs(LingQiPillMaxConfig) do
        var.pills[index] = conf[#conf].maxLevel
    end
    updateAttr(actor, true)
    s2cLingQiInfo(actor)
end

gmCmdHandlers.lqclear = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.lingqi = nil
    s2cLingQiInfo(actor)
    return true
end

