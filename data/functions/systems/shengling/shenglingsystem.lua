module('shenglingsystem', package.seeall)

local function fixInitData(actor, var)
    -- if not var.dashi then var.dashi = 0 end -- 大师等级
    if not var.choose then var.choose = 0 end -- 幻化激活
    if not var.shengling then var.shengling = {} end
    if not var.tag then var.tag = {} end
    for idx, conf in ipairs(ShengLingConfig) do
        if not var.shengling[idx] then
            var.shengling[idx] = {}
        end
        local sl = var.shengling[idx]
        if not sl.level then sl.level = 0 end
        if not sl.stage then sl.stage = 0 end
        if not sl.dashi then sl.dashi = 0 end -- 大师等级
        if not sl.tagSuit then sl.tagSuit = 0 end -- 印记套装等级
    end
    for tagidx, tagConf in pairs(ShengLingTagConfig) do
        if not var.tag[tagidx] then
            var.tag[tagidx] = 0
        end
    end
end

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.shengling then
        var.shengling = {} ----命名空间
        fixInitData(actor, var.shengling)
    end
    return var.shengling
end

local function getShengLingVar(actor, idx, var)
    if not var then
        var = getActorVar(actor)
    end

    if not var.shengling[idx] then
        fixInitData(actor, var)
    end

    return var.shengling[idx]
end

function getShengLingStage(actor)
    local stage = 0
    if not actor then return stage end
    for idx in ipairs(ShengLingConfig) do
        local sl = getShengLingVar(actor, idx)
        stage = stage + sl.stage
    end
    return stage
end

local function updateAttr(actor, isCalc, var)
    if not var then
        var = getActorVar(actor)
    end

    local baseAttr = {}
    local finalAttr = {}
    local power = 0
    for idx, conf in ipairs(ShengLingConfig) do
        local sl = getShengLingVar(actor, idx, var)

        -- 大师属性
        local dashiRate = ShengLingDashiConfig[idx][sl.dashi].attrPer / 10000
        -- 等级属性
        for k, v in ipairs(ShengLingLevelConfig[sl.level].attr) do
            baseAttr[v.type] = (baseAttr[v.type] or 0) + math.floor(v.value * (1 + dashiRate))
        end

        -- 阶级属性
        if sl.stage > 0 then
            for k, v in ipairs(ShengLingStageConfig[idx].attr) do
                finalAttr[v.type] = (finalAttr[v.type] or 0) + v.value * sl.stage
            end
        end

        -- 印记套装
        local suitRate = 0
        local suitConf = ShengLingSuitConfig[idx]
        for i=1, sl.tagSuit do
            local v = suitConf[i].addattr
            if v.type == Attribute.atShengLingTotalPer then
                suitRate = suitRate + v.value
            else
                finalAttr[v.type] = (finalAttr[v.type] or 0) + v.value
            end
            power = power + suitConf[i].addPower
        end

        -- 印记属性
        for k, tagidx in ipairs(conf.tag) do
            local tagLv = var.tag[tagidx]
            if tagLv > 0 then
                for k, v in ipairs(ShengLingTagConfig[tagidx].attr) do
                    finalAttr[v.type] = (finalAttr[v.type] or 0) + math.floor(v.value * tagLv * (1 + suitRate / 10000))
                end
            end
        end

        -- 被动技能
        local skillid = ShengLingConfig[idx].skill
        local skillLv = passiveskill.getSkillLv(actor, skillid)
        local skillConf = SkillPassiveConfig[skillid][skillLv]
        for k, v in ipairs(skillConf.addattr) do
            finalAttr[v.type] = (finalAttr[v.type] or 0) + v.value
        end
        power = power + skillConf.power
    end

    -- 圣灵属性加成
    for k,v in pairs(baseAttr) do
        -- 额外加成
        if k == Attribute.atAtk then
            finalAttr[k] = (finalAttr[k] or 0) + math.floor((finalAttr[Attribute.atShengLingAtkPer] or 0) / 10000 * v)
        elseif k == Attribute.atHpMax then
            finalAttr[k] = (finalAttr[k] or 0) + math.floor((finalAttr[Attribute.atShengLingHpPer] or 0) / 10000 * v)
        end
        finalAttr[k] = (finalAttr[k] or 0) + v
    end

    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_ShengLing)
    attr:Reset()
    for k, v in pairs(finalAttr) do
        if v ~= 0 then
            attr:Set(k, v)
        end
    end
    attr:SetExtraPower(power)
    if isCalc then
        LActor.reCalcAttr(actor)
    end
end

local function sendInfo(actor, var)
    if not var then
        var = getActorVar(actor)
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShengLing_Info)
    local tagCount = 0
    LDataPack.writeByte(npack, #ShengLingConfig)
    for idx, conf in ipairs(ShengLingConfig) do
        local sl = getShengLingVar(actor, idx, var)
        tagCount = tagCount + #conf.tag
        LDataPack.writeByte(npack, idx)
        LDataPack.writeShort(npack, sl.stage)
        LDataPack.writeShort(npack, sl.level)
        LDataPack.writeShort(npack, sl.tagSuit)
        LDataPack.writeShort(npack, sl.dashi)
    end
    LDataPack.writeByte(npack, tagCount)
    for idx, conf in ipairs(ShengLingConfig) do
        for _, tagidx in ipairs(conf.tag) do
            LDataPack.writeInt(npack, tagidx)
            LDataPack.writeShort(npack, var.tag[tagidx])
        end
    end
    LDataPack.writeByte(npack, var.choose)
    LDataPack.flush(npack)
end

local function levelUp(actor, idx, var)
    if not var then
        var = getActorVar(actor)
    end

    local sl = getShengLingVar(actor, idx, var)
    local slConf = ShengLingConfig[idx]
    if sl.level == 0 then
        -- 激活
        if slConf.needId and slConf.needId > 0 and slConf.needId ~= idx then
            local needsl = getShengLingVar(actor, slConf.needId, var)
            if needsl.level < slConf.needLevel then
                return
            end
        end
    end

    if slConf.maxLevel <= sl.level then
        -- 已满级
        print('shengling levelUp level max lv=', sl.level)
        return
    end

    local conf = ShengLingLevelConfig[sl.level]

    if not actoritem.checkItems(actor, conf.cost) then
        print('levelUp no item')
        return
    end

    actoritem.reduceItems(actor, conf.cost, 'shengling level up')

    sl.level = sl.level + 1

    updateAttr(actor, true, var)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShengLing_LevelUp)
    LDataPack.writeByte(npack, idx)
    LDataPack.writeShort(npack, sl.level)
    LDataPack.flush(npack)

    actorevent.onEvent(actor, aeShenlingLevel, 1)
end

local function choose(actor, idx, var)
    if not var then
        var = getActorVar(actor)
    end

    -- 激活所有印记
    for k, tagidx in ipairs(ShengLingConfig[idx].tag) do
        if not var.tag[tagidx] or var.tag[tagidx] == 0 then
            return
        end
    end
    var.choose = idx
    actorevent.onEvent(actor, aeNotifyFacade)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShengLing_Huanhua)
    LDataPack.writeByte(npack, var.choose)
    LDataPack.flush(npack)
end

local function tagLevelUp(actor, tagidx, var)
    if not var then
        var = getActorVar(actor)
    end

    local conf = ShengLingTagConfig[tagidx]
    if conf == nil then
        print('shenglingsystem.tagLevelUp conf==nil tagidx=', tagidx)
        return
    end

    local tagLv = var.tag[tagidx] or 0
    if conf.maxLevel <= tagLv then
        -- 满阶
        print('shengling tagLevelUp level max lv=', tagLv)
        return
    end

    if not actoritem.checkItems(actor, conf.needItem) then
        return
    end

    actoritem.reduceItems(actor, conf.needItem, 'shengling tag level up')

    var.tag[tagidx] = tagLv + 1

    if tagLv == 0 then
        local activeAll = true
        -- 激活所有印记
        for k, tagidx in ipairs(ShengLingConfig[conf.shengLingId].tag) do
            if not var.tag[tagidx] or var.tag[tagidx] == 0 then
                activeAll = false
            end
        end
        
        if activeAll then
            noticesystem.broadCastCrossContent(noticesystem.NTP.shenglingTagAll, LActor.getName(actor), ShengLingConfig[conf.shengLingId].name)
        end
        choose(actor, conf.shengLingId, var)
    end

    updateAttr(actor, true, var)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShengLing_TagLevelUp)
    LDataPack.writeInt(npack, tagidx)
    LDataPack.writeShort(npack, var.tag[tagidx])
    LDataPack.flush(npack)
end

local function stageUp(actor, idx, var)
    if not var then
        var = getActorVar(actor)
    end

    local slConf = ShengLingConfig[idx]
    if slConf == nil then
        print('shenglingsystem.stageUp slConf==nil idx=', idx)
        return
    end

    local sl = getShengLingVar(actor, idx, var)
    local conf = ShengLingStageConfig[idx]
    if conf == nil then
        print('shenglingsystem.stageUp conf==nil idx=', idx)
        return
    end

    local nextStage = sl.stage + 1
    if  slConf.maxStage <= sl.stage then
        -- 满了
        print('stageUp stage max')
        return
    end

    if not actoritem.checkItems(actor, conf.needItem) then
        print('stageUp item not enough')
        return
    end

    actoritem.reduceItems(actor, conf.needItem, 'shengling stage up')

    sl.stage = nextStage

    local skillid = slConf.skill
    local skilllv = passiveskill.getSkillLv(actor, skillid)
    if skilllv < sl.stage then
        -- 正常情况下，被动技能等级就等于圣灵阶级
        passiveskill.levelUp(actor, skillid)
    end

    actorevent.onEvent(actor, aeShenlingSatge, idx, 1)
    updateAttr(actor, true, var)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShengLing_StageUp)
    LDataPack.writeByte(npack, idx)
    LDataPack.writeShort(npack, sl.stage)
    LDataPack.flush(npack)
end

local function dashiUp(actor, idx, var)
    if not var then
        var = getActorVar(actor)
    end
    local sl = getShengLingVar(actor, idx, var)

    local nextDashi = sl.dashi + 1
    if not ShengLingDashiConfig[idx][nextDashi] then
        -- 已满
        return
    end

    local stage = math.max(math.ceil(sl.level/10), 1)

    local conf = ShengLingDashiConfig[idx][sl.dashi]
    if stage < conf.needLevel then
        print('dashi up failed stage=', stage, 'need=', conf.needLevel)
        return
    end

    sl.dashi = nextDashi
    updateAttr(actor, true, var)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShengLing_DashiUp)
    LDataPack.writeByte(npack, idx)
    LDataPack.writeShort(npack, sl.dashi)
    LDataPack.flush(npack)
end

local function activeTagSuit(actor, idx, var)
    if not var then
        var = getActorVar(actor)
    end

    local sl = getShengLingVar(actor, idx, var)

    if not ShengLingSuitConfig[idx][sl.tagSuit+1] then
        -- 已满
        return
    end

    local mintag = 99999
    -- print('activeTagSuit idx=', idx)
    for _, tagidx in ipairs(ShengLingConfig[idx].tag) do
        -- print('activeTagSuit tagidx=', tagidx, 'tag=', var.tag[tagidx])
        if var.tag[tagidx] < mintag then
            mintag = var.tag[tagidx]
        end
    end

    local suitLevel = sl.tagSuit
    for i = 1, 100 do
        local c = ShengLingSuitConfig[idx][suitLevel]

        if mintag < c.needLevel then
            print('activeTagSuit failed mintag=', mintag, 'need=', c.needLevel)
            break
        end

        if not ShengLingSuitConfig[idx][suitLevel + 1] then
            break
        end
        suitLevel = suitLevel + 1
    end

    if suitLevel == sl.tagSuit then
        -- 没有升级
        return
    end

    sl.tagSuit = suitLevel

    updateAttr(actor, true, var)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShengLing_ActiveTagSuit)
    LDataPack.writeByte(npack, idx)
    LDataPack.writeShort(npack, sl.tagSuit)
    LDataPack.flush(npack)
end


local function c2sLevelUp(actor, reader)
    local idx = LDataPack.readByte(reader)
    return levelUp(actor, idx)
end

local function c2sTagLevelUp(actor, reader)
    local tagidx = LDataPack.readInt(reader)
    return tagLevelUp(actor, tagidx)
end

local function c2sStageUp(actor, reader)
    local idx = LDataPack.readByte(reader)
    return stageUp(actor, idx)
end

local function c2sDashiUp(actor, reader)
    local idx = LDataPack.readByte(reader)
    return dashiUp(actor, idx)
end

local function c2sActiveTagSuit(actor, reader)
    local idx = LDataPack.readByte(reader)
    return activeTagSuit(actor, idx)
end

local function c2sChoose(actor, reader)
    local idx = LDataPack.readByte(reader)
    return choose(actor, idx)
end

local function checkOpen(actor)
    return actorexp.checkLevelCondition(actor, actorexp.LimitTp.shengling)
end

local function onLogin(actor)
    local var = getActorVar(actor)
    fixInitData(actor, var)
    sendInfo(actor, var)
end

local function onCustomChange(actor, custom, oldcustom)
    local var = getActorVar(actor)
    if checkOpen(actor) then
        updateAttr(actor, true, var)
    end
end

local function onInit(actor)
    local var = getActorVar(actor)
    if checkOpen(actor) then
        updateAttr(actor, false, var)
    end
end

local function onLevelUp(actor, level, oldLevel)
	local var = getActorVar(actor)
    if checkOpen(actor) then
        updateAttr(actor, true, var)
    end
end

function getShengLingId(actor)
    local var = getActorVar(actor)
    return var.choose
end
_G.getShengLingId = getShengLingId

local function initGlobalData()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeCustomChange, onCustomChange)
    actorevent.reg(aeInit, onInit)
	actorevent.reg(aeLevel, onLevelUp)

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShengLing_LevelUp, c2sLevelUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShengLing_TagLevelUp, c2sTagLevelUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShengLing_StageUp, c2sStageUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShengLing_DashiUp, c2sDashiUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShengLing_ActiveTagSuit, c2sActiveTagSuit)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShengLing_Huanhua, c2sChoose)
end

table.insert(InitFnTable, initGlobalData)

local gmCmdHandlers = gmsystem.gmCmdHandlers

function gmCmdHandlers.slClear(actor, args)
    local var = LActor.getStaticVar(actor)
    var.shengling = nil
    sendInfo(actor)
    return true
end

function gmCmdHandlers.slInfo(actor, args)
    local var = getActorVar(actor)
    print('-----------------shengling info----------------------')
    print('shengling choose=', var.choose)
    print('shengling list:')
    for idx, conf in ipairs(ShengLingConfig) do
        local sl = getShengLingVar(actor, idx, var)
        print('\tshengling idx=', idx, 'stage=', sl.stage, 'level=', sl.level, 'tagSuit=', sl.tagSuit, 'dashi=', sl.dashi)
    end
    print('tag list:')
    for tagidx, tagConf in pairs(ShengLingTagConfig) do
        print('\ttag idx=', tagidx, 'level=', var.tag[tagidx])
    end
    return true
end

function gmCmdHandlers.slLvUp(actor, args)
    local var = getActorVar(actor)
    local idx = tonumber(args[1]) or 1
    levelUp(actor, idx, var)
    return true
end

function gmCmdHandlers.slTagLvUp(actor, args)
    local var = getActorVar(actor)
    local tagidx = tonumber(args[1]) or 1
    tagLevelUp(actor, tagidx, var)
    return true
end

function gmCmdHandlers.slStageUp(actor, args)
    local var = getActorVar(actor)
    local idx = tonumber(args[1]) or 1
    stageUp(actor, idx,  var)
    return true
end

function gmCmdHandlers.slDashiUp(actor, args)
    local var = getActorVar(actor)
    local idx = tonumber(args[1]) or 1
    dashiUp(actor, idx, var)
    return true
end

function gmCmdHandlers.slSuit(actor, args)
    local var = getActorVar(actor)
    local idx = tonumber(args[1]) or 1
    activeTagSuit(actor, idx, var)
    return true
end

function gmCmdHandlers.shenglingAll(actor, args)
    local var = getActorVar(actor)
    var.choose = 1

    for idx, conf in ipairs(ShengLingConfig) do
        if not var.shengling[idx] then
            var.shengling[idx] = {}
        end
        local sl = var.shengling[idx]
        sl.level = conf.maxLevel
        sl.stage = conf.maxStage
        sl.tagSuit = conf.maxSuitLv
        sl.dashi = #ShengLingDashiConfig[idx]
    end
    for tagidx, tagConf in pairs(ShengLingTagConfig) do
        var.tag[tagidx] = tagConf.maxLevel
    end
    updateAttr(actor, true, var)
    sendInfo(actor, var)
    return true
end
