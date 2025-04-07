module('shenyousystem', package.seeall)

local function fixInitData(actor, var)
    if not var.choose then var.choose = 0 end -- 幻化激活
    if not var.level then var.level = 0 end -- 等级
    if not var.slot then var.slot = 0 end -- 技能格子
    if not var.buySlot then var.buySlot = 0 end -- 购买技能格子
    if not var.huanhua then var.huanhua = {} end -- 幻化
    for i = 1, #ShenYouHuanhuaConfig do
        if not var.huanhua[i] then var.huanhua[i] = 0 end
    end
    if not var.tagLv then var.tagLv = 0 end -- 印记等级
    if not var.tagExp then var.tagExp = 0 end -- 印记经验
    if not var.tagSkill then var.tagSkill = 0 end -- 印记技能
    if not var.skill then var.skill = {} end -- 技能列表
    for i=1, #ShenYouSkillConfig do
        if not var.skill[i] then var.skill[i] = 0 end
    end
end

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.shenyou then
        var.shenyou = {} ----命名空间
        fixInitData(actor, var.shenyou)
    end
    return var.shenyou
end

function getShenYouStage(actor)
    if not actor then return 0 end
    local var = getActorVar(actor)
    return math.ceil(var.level / 10)
end

local function sendInfo(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenYou_Info)
    LDataPack.writeShort(npack, var.level)
    LDataPack.writeByte(npack, var.slot)
    LDataPack.writeByte(npack, var.choose)
    LDataPack.writeByte(npack, #ShenYouHuanhuaConfig)
    for idx, conf in ipairs(ShenYouHuanhuaConfig) do
        LDataPack.writeByte(npack, idx)
        LDataPack.writeShort(npack, var.huanhua[idx])
    end
    LDataPack.writeShort(npack, var.tagLv)
    LDataPack.writeInt(npack, var.tagExp)
    LDataPack.writeByte(npack, #ShenYouSkillConfig)
    for idx, conf in ipairs(ShenYouSkillConfig) do
        LDataPack.writeByte(npack, idx)
        LDataPack.writeShort(npack, var.skill[idx])
    end
    LDataPack.flush(npack)
end

local function updateSkillSlot(actor, sync, var)
    if not var then
        var = getActorVar(actor)
    end
    local level = var.level
    if level == 0 then
        level = 1
    end
    local stage = math.ceil(level / 10)
    local slot = 0

    for i = 1, #ShenYouStageConfig do
        local c = ShenYouStageConfig[i]
        -- print('stage=', stage, 'need=', c.stage, 'slot=', c.skillSlot)
        if stage >= c.stage then
            -- 增加技能格子
            if 0 < c.skillSlot then
                slot = slot + c.skillSlot
            end
        end
    end
    slot = slot + var.buySlot
    -- print('slot=', slot, 'var.slot=', var.slot)
    if slot ~= var.slot then
        var.slot = slot
        if sync then
            local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenYou_BuySlot)
            LDataPack.writeShort(npack, var.slot)
            LDataPack.flush(npack)
        end
    end
end

local function activeTagSkill(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    local role = LActor.getRole(actor)
    LActor.setPassiveLevel(actor, ShenYouBaseConfig.activeTagSkill, 0)
    -- LActor.setShenyouTagSkillState(role)
    var.tagSkill = 1
    actorevent.onEvent(actor, aeNotifyFacade)
end

function updateAttr(actor, isCalc, var)
    if not var then
        var = getActorVar(actor)
    end

    local baseAttr = {}
    local finalAttr = {}
    local skillAttr = {}
    local power = 0
    --等级属性
    for k, v in ipairs(ShenYouLevelConfig[var.level].attr) do
        baseAttr[v.type] = (baseAttr[v.type] or 0) + v.value
    end
    -- 升阶加成
    local stage = math.ceil(var.level / 10)
    for i = 1, #ShenYouStageConfig do
        local c = ShenYouStageConfig[i]
        if stage >= c.stage then
            for k, v in ipairs(c.attr) do
                finalAttr[v.type] = (finalAttr[v.type] or 0) + v.value
            end
            -- 被动技能
            local skillid = c.skill
            if 0 < skillid then
                local skilllv = passiveskill.getSkillLv(actor, skillid)
                local sConf = SkillPassiveConfig[skillid][skilllv]
                for k, v in ipairs(sConf.addattr) do
                    finalAttr[v.type] = (finalAttr[v.type] or 0) + v.value
                end
            end
            -- 进阶额外战力
            power = power + c.power
        end
    end
    -- 幻化属性
    local shieldPer = 0
    for idx, conf in ipairs(ShenYouHuanhuaConfig) do
        shieldPer = shieldPer + conf.shieldPer
        local lv = var.huanhua[idx]
        if 0 < lv then
            for k, v in ipairs(conf.baseAttrs) do
                finalAttr[v.type] = (finalAttr[v.type] or 0) + v.value * lv
            end
        end
    end

    --技能属性
    for idx, c in ipairs(ShenYouSkillConfig) do
        local skilllv = var.skill[idx]
        if skilllv > 0 then
            for k, v in ipairs(c.attr) do
                skillAttr[v.type] = (skillAttr[v.type] or 0) + v.value * skilllv
            end
            power = power + c.power * skilllv
        end
    end
    -- 技能属性加成， 只加成基础属性
    local skillRate = 1+ (skillAttr[Attribute.atShenYouSkillTotalPer] or 0) / 10000
    for k, v in pairs(skillAttr) do
        if AttrPowerConfig[k].ishighattr == 0 then
            finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * skillRate)
        else
            finalAttr[k] = (finalAttr[k] or 0) + v
        end
    end

    -- 印记属性
    for k, v in ipairs(ShenYouTagConfig[var.tagLv].attr) do
        finalAttr[v.type] = (finalAttr[v.type] or 0) + v.value
    end
    -- 印记技能
    for idx, skillid in ipairs(ShenYouBaseConfig.yinjiskills) do
        local skilllv = passiveskill.getSkillLv(actor, skillid)
        local sConf = SkillPassiveConfig[skillid][skilllv]
        if (idx == 1 and stage >= ShenYouBaseConfig.yinjiOpen) or idx ~= 1 then
            for k, v in ipairs(sConf.addattr) do
                finalAttr[v.type] = (finalAttr[v.type] or 0) + v.value
            end
        end
        power = power + sConf.power
    end
    -- 护盾总属性加成
    local rate = 1+ (finalAttr[Attribute.atShenYouTotalPer] or 0) / 10000
    for k, v in pairs(baseAttr) do
        finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * rate)
    end
    
    --护盾值加成属性
    for k,v in pairs(finalAttr) do
        if k == Attribute.atShenYouShieldMax then
            finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * shieldPer/10000)
        end
    end

    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_ShenYou)
    attr:Reset()
    for k, v in pairs(finalAttr) do
        attr:Set(k, v)
    end
    attr:SetExtraPower(power)
    if isCalc then
        LActor.reCalcAttr(actor)
    end
end

local function levelUp(actor, var)
    if not var then
        var = getActorVar(actor)
    end

    local nextLv = var.level + 1
    if not ShenYouLevelConfig[nextLv] then
        return
    end

    local conf = ShenYouLevelConfig[var.level]
    if not actoritem.checkItems(actor, conf.cost) then
        print('levelUp no item')
        return
    end
    actoritem.reduceItems(actor, conf.cost, 'shenyou level up')

    local oldStage = math.ceil(var.level / 10)
    var.level = nextLv
    local newStage = math.ceil(var.level / 10)
    -- 激活印记之殇
    if var.tagSkill == 0 and ShenYouBaseConfig.activeTagDmg <= newStage then
        -- 学习印记之殇技能， 确保只学一次
        activeTagSkill(actor)
    end

    if oldStage ~= newStage then
        -- stage up
        for i = 1, #ShenYouStageConfig do
            local c = ShenYouStageConfig[i]
            if newStage == c.stage then
                -- 增加技能格子
                if 0 < c.skillSlot then
                    updateSkillSlot(actor, true, var)
                end
                -- 学习被动技能
                if 0 < c.skill then
                    local skilllv = passiveskill.getSkillLv(actor, c.skill)
                    if skilllv == 0 then
                        passiveskill.levelUp(actor, c.skill)
                    end
                end
                if 0 < c.skill2 then
                    local role = LActor.getRole(actor)
                    LActor.setShenyouShieldUseSkillId(role, c.skill2)
                    var.shield_use_skill = c.skill2
                end
            end
        end
    end
    updateAttr(actor, true, var)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenYou_LevelUp)
    LDataPack.writeShort(npack, var.level)
    LDataPack.flush(npack)

    actorevent.onEvent(actor, aeShenyouLevel, newStage)
end

function getShieldUseSkill(actor)
    local var = getActorVar(actor)
    return var.shield_use_skill or 0
end

function hasSkillSlot(actor, var)
    if not var then
        var = getActorVar(actor)
    end

    local total = 0
    for idx, c in ipairs(ShenYouSkillConfig) do
        if var.skill[idx] > 0 then
            total = total + 1
        end
    end
    return var.slot > total
end

local function skillLevelUp(actor, idx, var)
    if not var then
        var = getActorVar(actor)
    end
    
    local conf = ShenYouSkillConfig[idx]
    local lv = var.skill[idx]
    if lv == 0 and not hasSkillSlot(actor, var) then
        print('hasSkillSlot no more slot')
        return
    end
    if conf.maxLevel <= lv then
        print('shenyou skillLevelUp level max')
        return
    end

    if not actoritem.checkItem(actor, conf.cost.id, conf.cost.count) then
        print('shenyou skillLevelUp no item')
        return
    end

    actoritem.reduceItem(actor, conf.cost.id, conf.cost.count, 'shenyou skillLevelUp')
    var.skill[idx] = lv + 1
    updateAttr(actor, true, var)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenYou_SkillLvUp)
    LDataPack.writeByte(npack, idx)
    LDataPack.writeShort(npack, var.skill[idx])
    LDataPack.flush(npack)
end

local function buySlot(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    local max = #ShenYouSkillConfig
    if var.slot >= max then
        print('buySlot slot=', var.slot, 'max=', max)
        return
    end

    if var.slot < ShenYouBaseConfig.buyMin then
        print('buySlot slot=', var.slot, 'min=', ShenYouBaseConfig.buyMin)
        return
    end

    local nextSlot = var.slot+1

    local cost = ShenYouBaseConfig.buyPrice[nextSlot]
    --扣除道具
    if not actoritem.checkItem(actor, NumericType_YuanBao, cost) then
        print('buySlot yuanbao not enough cost=', cost)
        return
    end
    actoritem.reduceItem(actor, NumericType_YuanBao, cost, "shenyou buy skill")

    var.buySlot = var.buySlot + 1

    updateSkillSlot(actor, true, var)
end

local function chooseHuanhua(actor, idx, var)
    if not var then
        var = getActorVar(actor)
    end

    if idx == var.choose then
        print('chooseHuanhua already choose idx=', idx, 'choose=', var.choose)
        return
    end

    if var.huanhua[idx] > 0 then
        var.choose = idx

        actorevent.onEvent(actor, aeNotifyFacade)

        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenYou_HuanHua)
        LDataPack.writeByte(npack, var.choose)
        LDataPack.flush(npack)
    end
end

local function huanhuaLvUp(actor, idx, var)
    if not var then
        var = getActorVar(actor)
    end

    local lv = var.huanhua[idx]
    local conf = ShenYouHuanhuaConfig[idx]

    if conf.maxLevel <= lv then
        print('shenyou huanhuaLvUp')
        return
    end
	
	
	--função para chamar ID e contar a quantidade de itens
	local idz = ShenYouHuanhuaConfig[idx].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (lv or 0) >= conf.maxLevel then
		count = conf.maxLevel - (lv or 0)
	end
	
	---

    local nextLv = lv + count

    --扣除道具
    if not actoritem.checkItems(actor, conf.needitem) then
        print('huanhuaLvUp item not enough')
        return
    end
	
    actoritem.reduceItem(actor, idz, count, "shenyou huanhua LvUp")

    var.huanhua[idx] = nextLv

    if lv == 0 then
        -- 激活
        chooseHuanhua(actor, idx, var)
    end

    updateAttr(actor, true, var)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenYou_HuanHuaLvUp)
    LDataPack.writeByte(npack, idx)
    LDataPack.writeShort(npack, var.huanhua[idx])
    LDataPack.flush(npack)
end

local function tagLvUp(actor, var)
    if not var then
        var = getActorVar(actor)
    end

    local nextLv = var.tagLv + 1
    if not ShenYouTagConfig[nextLv] then
        print('tagLvUp max level')
        return
    end

    local expConf
    for i = 1, #ShenYouTagExpConfig do
        local c = ShenYouTagExpConfig[i]
        if var.tagLv >= c.minLv and var.tagLv <= c.maxLv then
            expConf = c
        end
    end
    if not expConf then
        print('no expConf')
        return
    end

    local conf = ShenYouTagConfig[var.tagLv]
    local needExp = conf.exp - var.tagExp

    local needCount = math.ceil(needExp / expConf.exp)

    local count = actoritem.getItemCount(actor, expConf.itemid)
    if count == 0 then
        print('tagLvUp item count==0')
        return
    end
    if needCount <= count then
        -- 升级
        actoritem.reduceItem(actor, expConf.itemid, needCount, "shenyou tag LvUp")
        local totalExp = needCount*expConf.exp
        local lv = var.tagLv
        for i = 1, 100 do
            if totalExp < needExp or not ShenYouTagConfig[lv+1] then
                break
            end
            totalExp = totalExp - needExp
            lv = lv + 1
            needExp = ShenYouTagConfig[lv].exp
        end
        var.tagExp = totalExp
        var.tagLv = lv
    else
        -- 不升级
        actoritem.reduceItem(actor, expConf.itemid, count, "shenyou tag LvUp")
        local totalExp = count*expConf.exp
        var.tagExp = var.tagExp + totalExp
    end

    updateAttr(actor, true, var)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sShenYou_TagLvUp)
    LDataPack.writeShort(npack, var.tagLv)
    LDataPack.writeInt(npack, var.tagExp)
    LDataPack.flush(npack)
end


local function c2sLevelUp(actor, reader)
    return levelUp(actor)
end

local function c2sSkillLevelUp(actor, reader)
    local idx = LDataPack.readByte(reader)
    return skillLevelUp(actor, idx)
end

local function c2sTagLevelUp(actor, reader)
    return tagLvUp(actor)
end

local function c2sHuanhuaLvUp(actor, reader)
    local idx = LDataPack.readByte(reader)
    return huanhuaLvUp(actor, idx)
end

local function c2sHuanhua(actor, reader)
    local idx = LDataPack.readByte(reader)
    return chooseHuanhua(actor, idx)
end

local function c2sBuySlot(actor, reader)
    return buySlot(actor)
end

local function checkOpen(actor)
    return actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenyou)
end

local function onLogin(actor)
    local var = getActorVar(actor)
    fixInitData(actor, var)
    local role = LActor.getRole(actor)
    if role then
        LActor.setShenyouShieldTagInitCD(role, ShenYouBaseConfig.yinjiCD)
    end
    if checkOpen(actor) then
        updateSkillSlot(actor, false, var)
        
        if role then
            -- 盾爆技能
            if var.shield_use_skill then
                LActor.setShenyouShieldUseSkillId(role, var.shield_use_skill)
            end
        end
    end
    sendInfo(actor, var)
end

function onSystemOpen(actor)
	updateSkillSlot(actor, true)
end


local function onCustomChange(actor, custom, oldcustom)
    local var = getActorVar(actor)
    if checkOpen(actor) then
        updateAttr(actor, true, var)
    end
end

local function onInit(actor)
    local var = getActorVar(actor)
    fixInitData(actor, var)
    if checkOpen(actor) then
        updateAttr(actor, false, var)
    end
end

function getTagLevel(actor)
    local var = getActorVar(actor)
    return var.tagLv
end

local function getShenYouShieldId(actor)
    local var = getActorVar(actor)
    if math.ceil(var.level/10) < ShenYouBaseConfig.huanhuaOpen then
        return -1
    else
        return var.choose
    end
end
_G.getShenYouShieldId = getShenYouShieldId


local function onEnter(ins, actor)
    local var = getActorVar(actor)
    local role = LActor.getRole(actor)
    if math.ceil(var.level/10) < ShenYouStageConfig[2].stage then
        LActor.setAttr(role, Attribute.atShenYouShield, 0)
        return
    end

    LActor.setAttr(role, Attribute.atShenYouShield, LActor.getAttr(role, Attribute.atShenYouShieldMax))
    LActor.notifyFacade(actor)
end


local function initGlobalData()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeCustomChange, onCustomChange)
    actorevent.reg(aeInit, onInit)
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.shenyou, onSystemOpen)

    for id in pairs(FubenConfig) do
        insevent.registerInstanceEnter(id, onEnter)
    end

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShenYou_LevelUp, c2sLevelUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShenYou_BuySlot, c2sBuySlot)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShenYou_HuanHuaLvUp, c2sHuanhuaLvUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShenYou_HuanHua, c2sHuanhua)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShenYou_TagLvUp, c2sTagLevelUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cShenYou_SkillLvUp, c2sSkillLevelUp)
end
table.insert(InitFnTable, initGlobalData)

local gmCmdHandlers = gmsystem.gmCmdHandlers
function gmCmdHandlers.syClear(actor, args)
    local var = LActor.getStaticVar(actor)
    var.shenyou = nil
    return true
end

function gmCmdHandlers.syInfo(actor, args)
    local var = getActorVar(actor)
    print('-----------------shenyou info----------------------')
    print('shenyou level=', var.level, 'choose=', var.choose, 'slot=', var.slot, 'tagLv=', var.tagLv, 'tagExp=', var.tagExp, 'tagSkill=', var.tagSkill)
    print('skill list:')
    for idx, c in ipairs(ShenYouSkillConfig) do
        print('\tskill id=', idx, 'level=', var.skill[idx])
    end
    print('huanhua list:')
    for idx, conf in ipairs(ShenYouHuanhuaConfig) do
        print('\thuanhua idx=', idx, 'level=', var.huanhua[idx])
    end
    return true
end

function gmCmdHandlers.syLvUp(actor, args)
    local var = getActorVar(actor)
    local count = tonumber(args[1]) or 1
    for i = 1, count do
        levelUp(actor, var)
    end
    return true
end

function gmCmdHandlers.syHuanhuaLvUp(actor, args)
    local var = getActorVar(actor)
    local idx = tonumber(args[1]) or 1
    huanhuaLvUp(actor, idx, var)
    return true
end

function gmCmdHandlers.syHuanhua(actor, args)
    local var = getActorVar(actor)
    local idx = tonumber(args[1]) or 1
    chooseHuanhua(actor, idx, var)
    return true
end

function gmCmdHandlers.syBuy(actor, args)
    local var = getActorVar(actor)
    buySlot(actor, var)
    return true
end

function gmCmdHandlers.syTagLvUp(actor, args)
    local var = getActorVar(actor)
    tagLvUp(actor, var)
    return true
end

function gmCmdHandlers.sySkillLvUp(actor, args)
    local var = getActorVar(actor)
    local idx = tonumber(args[1]) or 1
    skillLevelUp(actor, idx, var)
    return true
end

function gmCmdHandlers.syUseSkill(actor, args)
    local skill_id = tonumber(args[1])
	if skill_id == nil then
		print('skill_id==nil')
		return
    end

    local hdl = LActor.getFubenHandle(actor)
    local list = Fuben.getAllActor(hdl)
    if list == nil then
        print('list==nil')
        return
    end

    local role = LActor.getRole(actor)
    for _, a in ipairs(list) do
        if a ~= actor then
            local r = LActor.getRole(a)
            LActor.setAITarget(role, r)
            break
        end
    end

	LActor.useSkill(role, skill_id)

    return true
end

function gmCmdHandlers.shenyouAll(actor, args)
    local role = LActor.getRole(actor)
    local var = getActorVar(actor)
    var.choose = #ShenYouHuanhuaConfig
    var.level = #ShenYouLevelConfig
    var.slot = #ShenYouSkillConfig
    var.buySlot = var.slot - ShenYouBaseConfig.buyMin
    for i, c in ipairs(ShenYouHuanhuaConfig) do
        var.huanhua[i] = c.maxLevel
    end
    for i, c in ipairs(ShenYouSkillConfig) do
        var.skill[i] = 0--c.maxLevel
    end
    var.tagLv = #ShenYouTagConfig
    var.tagExp = 0
    var.tagSkill = 1
    var.shield_use_skill = 51001
    -- LActor.setShenyouShieldSkillState(role)
    -- LActor.setShenyouTagSkillState(role)
    updateAttr(actor, true, var)
    sendInfo(actor, var)
    actorevent.onEvent(actor, aeNotifyFacade)
    return true
end

