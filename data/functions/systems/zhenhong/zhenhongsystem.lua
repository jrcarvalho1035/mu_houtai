--真红圣装系统
module("zhenhongsystem", package.seeall)

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.zhenhong then
        var.zhenhong = {
            equips = {},
            stages = {},
            suits = {},
            zhyjLevel = 0,
            zhbtLevel = 0,
            giftStatus = 0,
            giftEndTime = 0,
            giftBuys = {},
        }
    end
    return var.zhenhong
end

function getZhenHongSuit(actor)
    local stage = 0
    if not actor then return stage end
    local var = getActorVar(actor)
    for slot, config in pairs(ZHSuitLevelConfig) do
        stage = stage + (var.suits[slot] or 0)
    end
    return stage
end

function getZhenHongActive(actor)
    local count = 0
    if not actor then return count end
    local var = getActorVar(actor)
    for slot in pairs(ZHSuitLevelConfig) do
        if (var.suits[slot] or 0) > 0 then
            count = count + 1
        end
    end
    return count
end

local function getZHPosLevelVar(var, slot, pos)
    if not var then return 0 end
    var = var.equips
    if not var[slot] then
        var[slot] = {}
    end
    return var[slot][pos] or 0
end

local function calcAttr(actor, calc)
    local var = getActorVar(actor)
    local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_zhenhong)
    attrs:Reset()
    
    local baseAttr = {}
    local allAttr = {}
    local power = 0
    
    --淬炼属性
    for slot, config in pairs(ZHLevelConfig) do
        for pos, conf in pairs(config) do
            local level = getZHPosLevelVar(var, slot, pos)
            if level > 0 then
                for _, v in ipairs(conf[level].attrs) do
                    allAttr[v.type] = (allAttr[v.type] or 0) + v.value
                end
            end
        end
        --原力属性
        local stage = var.stages[slot] or 0
        if stage > 0 then
            for _, v in ipairs(ZHStageConfig[slot][stage].attrs) do
                allAttr[v.type] = (allAttr[v.type] or 0) + v.value
            end
        end
    end
    
    --套装部位属性
    local temSuit = {}
    for slot, config in pairs(ZHSuitLevelConfig) do
        local level = var.suits[slot] or 0
        if level > 0 then
            for _, v in ipairs(config.attrs) do
                baseAttr[v.type] = (baseAttr[v.type] or 0) + v.value * level
            end
            for _, v in ipairs(config.exAttrs) do
                allAttr[v.type] = (allAttr[v.type] or 0) + v.value
            end
            power = power + config.power
        end
        if slot == EquipType_Helmet
            or slot == EquipType_Hant
            or slot == EquipType_Pant
            or slot == EquipType_Shoe
            or slot == EquipType_Necklace
            or slot == EquipType_Ring then
            table.insert(temSuit, level)
        end
    end
    
    --套装效果1属性
    table.sort(temSuit, function(a, b) return a > b end)
    
    local maxSuitLevel = 1
    for level, conf in ipairs(ZHSuitAttrConfig[6]) do
        if (temSuit[6] or 0) >= conf.needLevel then
            maxSuitLevel = level + 1
        else
            break
        end
    end
    for count, config in pairs(ZHSuitAttrConfig) do
        local level = temSuit[count] or 0
        for i = #config, 1, -1 do
            if i <= maxSuitLevel and level >= config[i].needLevel then
                for _, v in ipairs(config[i].attrs) do
                    allAttr[v.type] = (allAttr[v.type] or 0) + v.value
                end
                power = power + config[i].power
                break
            end
        end
    end
    
    --套装效果2
    local level = var.zhyjLevel or 0
    local zhyjskill = ZHCommonConfig.zhyjskill
    local zhyjconf = SkillPassiveConfig[zhyjskill] and SkillPassiveConfig[zhyjskill][level]
    if zhyjconf then
        power = power + zhyjconf.power
    end
    
    --套装效果3
    local level = var.zhbtLevel or 0
    local zhbtskill = ZHCommonConfig.zhbtskill
    local zhbtconf = SkillPassiveConfig[zhbtskill] and SkillPassiveConfig[zhbtskill][level]
    if zhbtconf then
        power = power + zhbtconf.power
    end
    
    --套装部位属性加成
    local zhSuitPer = (allAttr[Attribute.atZHSuitPer] or 0) / 10000 + 1
    for k, v in pairs(baseAttr) do
        allAttr[k] = (allAttr[k] or 0) + v * zhSuitPer
    end
    
    for k, v in pairs(allAttr) do
        attrs:Set(k, v)
    end
    
    if power > 0 then
        attrs:SetExtraPower(power)
    end
    if calc then
        LActor.reCalcAttr(actor)
    end
end

local function getZHPosLevel(actor, slot, pos)
    local var = getActorVar(actor)
    var = var.equips
    if not var[slot] then
        var[slot] = {}
    end
    return var[slot][pos] or 0
end

local function getZHSlotLevel(actor, slot)
    local level = 0
    for pos in ipairs(ZHSlotConfig) do
        level = level + getZHPosLevel(actor, slot, pos)
    end
    return level
end

local function setZHPosLevel(actor, slot, pos, level)
    local var = getActorVar(actor)
    var = var.equips
    if not var[slot] then
        var[slot] = {}
    end
    var[slot][pos] = level
end

local function checkZHPosOpen(actor, slot, pos)
    local config = ZHSlotConfig[pos]
    if not config then return end
    local level = getZHPosLevel(actor, slot, config.condition.pos)
    return level >= config.condition.level
end

local function getZHSuitLevel(actor, slot)
    local var = getActorVar(actor)
    return var.suits[slot] or 0
end

local function setZHSuitLevel(actor, slot, level)
    local var = getActorVar(actor)
    var.suits[slot] = level
end

function getZHYJLevel(actor)
    local var = getActorVar(actor)
    local wLevel = var.suits[EquipType_Weapon] or 0
    local cLevel = var.suits[EquipType_Coat] or 0
    return math.min(wLevel, cLevel)
end

function getZHBTLevel(actor)
    local var = getActorVar(actor)
    local tLevel = var.suits[EquipType_Talisman] or 0
    local eLevel = var.suits[EquipType_Emblem] or 0
    return math.min(tLevel, eLevel)
end

function checkZHXGOpen(actor)
    local var = getActorVar(actor)
    return var.giftStatus == 1
end

function zhGiftCheckTime(actor)
    local var = getActorVar(actor)
    if var.giftStatus == 1 then
        local keepTime = var.giftEndTime - System.getNowTime()
        if keepTime > 0 then
            LActor.postScriptEventLite(actor, keepTime * 1000, zhGiftEnd)
        else
            var.giftStatus = 2
        end
    end
    s2cZHXGUpdateTime(actor)
end

function zhGiftStart(actor)
    local var = getActorVar(actor)
    var.giftStatus = 1
    var.giftEndTime = System.getNowTime() + ZHCommonConfig.keepTime
    LActor.postScriptEventLite(actor, ZHCommonConfig.keepTime * 1000, zhGiftEnd)
    s2cZHXGUpdateTime(actor)
end

function zhGiftEnd(actor)
    local var = getActorVar(actor)
    var.giftStatus = 2
    s2cZHXGUpdateTime(actor)
end

function isZHXG(count)
    for id, config in pairs(ZHLimitGiftConfig) do
        if config.pay == count then
            return true
        end
    end
    return false
end

function zhxgBuy(actor, count)
    if not checkZHXGOpen(actor) then
        print("zhxgBuy not open")
        return
    end
    
    local index = 0
    for i, conf in ipairs(ZHLimitGiftConfig) do
        if conf.pay == count then
            index = i
        end
    end
    if index == 0 then
        print("zhxgBuy not find index =", index)
        return
    end
    
    local var = getActorVar(actor)
    local status = var.giftBuys[index]
    if status == 1 or status == 2 then
        print("zhxgBuy repeat recharge index =", index, "status =", status)
        return
    end
    status = 1
    var.giftBuys[index] = status
    rechargesystem.addVipExp(actor, count)
    s2cZHRewardUpdate(actor, index, status)
    utils.logCounter(actor, "zhenhongsystem", "zhxgBuy ok", index, "zhxgBuy")
end

function buy(actorid, count)
    local actor = LActor.getActorById(actorid)
    if actor then
        zhxgBuy(actor, count)
    else
        local npack = LDataPack.allocPacket()
        LDataPack.writeInt(npack, count)
        System.sendOffMsg(actorid, 0, OffMsgType_ZHXG, npack)
    end
end

local function OffMsgZHXGBuy(actor, offmsg)
    local count = LDataPack.readInt(offmsg)
    print(string.format("OffMsgZHXGBuy actorid:%d count:%d", LActor.getActorId(actor), count))
    zhxgBuy(actor, count)
end

--真红系统-淬炼升级
function zhLevelUp(actor, slot, pos)
    if not checkZHPosOpen(actor, slot, pos) then return end
    
    local config = ZHLevelConfig[slot] and ZHLevelConfig[slot][pos]
    if not config then return end
    local level = getZHPosLevel(actor, slot, pos)
    if not config[level + 1] then return end
    config = config[level]
    if not actoritem.checkItems(actor, config.items) then
        return
    end
    actoritem.reduceItems(actor, config.items, "zhLevelUp")
    
    level = level + 1
    setZHPosLevel(actor, slot, pos, level)
    s2cZHLevelUp(actor, slot, pos, level)
    calcAttr(actor, true)
    utils.logCounter(actor, "zhenhongsystem", slot, pos, level, "zhLevelUp")
end

--真红系统-套装升阶
function zhSuitUp(actor, slot)
    local config = ZHSuitLevelConfig[slot]
    if not config then return end
    
    local level = getZHSuitLevel(actor, slot)
    if level >= config.maxLevel then return end
    
    if not actoritem.checkItems(actor, config.items) then
        return
    end
	
	
	--função para chamar ID e contar a quantidade de itens
	local idz = ZHSuitLevelConfig[slot].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (level or 0) >= config.maxLevel then
		count = config.maxLevel - (level or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "zhSuitUp")
	
    
    level = level + count
    setZHSuitLevel(actor, slot, level)
    
    local var = getActorVar(actor)
    local zhyjlevel = getZHYJLevel(actor)
    for lv = #ZHBTSuitConfig, 1, -1 do
        if zhyjlevel >= ZHBTSuitConfig[lv].needLevel then
            if lv > var.zhyjLevel then
                var.zhyjLevel = lv
                LActor.setPassiveLevel(actor, ZHCommonConfig.zhyjskill, lv)
                passiveskill.updatePassiveSkill(actor, ZHCommonConfig.zhyjskill, lv)
            end
            break
        end
    end
    
    local zhbtlevel = getZHBTLevel(actor)
    for lv = #ZHYJSuitConfig, 1, -1 do
        if zhbtlevel >= ZHYJSuitConfig[lv].needLevel then
            if lv > var.zhbtLevel then
                var.zhbtLevel = lv
                LActor.setPassiveLevel(actor, ZHCommonConfig.zhbtskill, lv)
                passiveskill.updatePassiveSkill(actor, ZHCommonConfig.zhbtskill, lv)
            end
            break
        end
    end
    
    actorevent.onEvent(actor, aeZhenHongStageUp, 1)
    if level == 1 then
        actorevent.onEvent(actor, aeZhenHongActive)
    end
    calcAttr(actor, true)
    s2cZHSuitUp(actor, slot, level)
    utils.logCounter(actor, "zhenhongsystem", slot, level, "", "zhSuitUp")
end

function zhGetReward(actor, index)
    if not checkZHXGOpen(actor) then return end
    local config = ZHLimitGiftConfig[index]
    if not config then return end
    local var = getActorVar(actor)
    local status = var.giftBuys[index]
    if status ~= 1 then return end
    
    status = 2
    var.giftBuys[index] = status
    actoritem.addItems(actor, config.rewards, "zhGetReward")
    rechargesystem.addDiamond(actor, config.pay, "zhGetReward")
    s2cZHRewardUpdate(actor, index, status)
end

function zhStageUp(actor, slot)
    if not ZHStageConfig[slot] then return end
    
    local var = getActorVar(actor)
    local stage = var.stages[slot] or 0
    if not ZHStageConfig[slot][stage + 1] then return end
    
    local config = ZHStageConfig[slot][stage]
    if not config then return end
    
    local slotLevel = getZHSlotLevel(actor, slot)
    if slotLevel < config.needLevel then return end
    
    stage = stage + 1
    var.stages[slot] = stage
    calcAttr(actor, true)
    s2cZHStageUp(actor, slot, stage)
    utils.logCounter(actor, "zhenhongsystem", slot, stage, "", "zhStageUp")
end

----------------------------------------------------------------------------------
--协议处理

--84-50 真红系统-基础信息
function s2cZHInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sZhenHong_Info)
    if not pack then return end
    LDataPack.writeChar(pack, EquipSlotType_Max)
    for slot = 0, EquipSlotType_Max - 1 do
        LDataPack.writeChar(pack, slot)
        LDataPack.writeShort(pack, var.stages[slot] or 0)
        LDataPack.writeShort(pack, var.suits[slot] or 0)
        
        LDataPack.writeChar(pack, #ZHSlotConfig)
        for pos in ipairs(ZHSlotConfig) do
            LDataPack.writeChar(pack, pos)
            local level = getZHPosLevelVar(var, slot, pos)
            LDataPack.writeShort(pack, level)
        end
    end
    
    LDataPack.writeChar(pack, #ZHLimitGiftConfig)
    for index in ipairs(ZHLimitGiftConfig) do
        LDataPack.writeChar(pack, var.giftBuys[index] or 0)
    end
    LDataPack.flush(pack)
end

--84-51 真红系统-套装升阶
local function c2sZHLevelUp(actor, pack)
    local slot = LDataPack.readChar(pack)
    local pos = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zhsz) then return end
    zhLevelUp(actor, slot, pos)
end

--84-51 真红系统-套装升阶
function s2cZHLevelUp(actor, slot, pos, level)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sZhenHong_LevelUp)
    if not pack then return end
    LDataPack.writeChar(pack, slot)
    LDataPack.writeChar(pack, pos)
    LDataPack.writeShort(pack, level)
    LDataPack.flush(pack)
end

--84-52 真红系统-套装升级
local function c2sZHSuitUp(actor, pack)
    local slot = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zhsz) then return end
    zhSuitUp(actor, slot)
end

--84-52 真红系统-套装升级
function s2cZHSuitUp(actor, slot, level)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sZhenHong_SuitUp)
    if not pack then return end
    LDataPack.writeChar(pack, slot)
    LDataPack.writeShort(pack, level)
    LDataPack.flush(pack)
end

--84-53 真红系统-礼包领取
local function c2sZHGetReward(actor, pack)
    local index = LDataPack.readChar(pack)
    zhGetReward(actor, index)
end

--84-53 真红系统-领取返回
function s2cZHRewardUpdate(actor, index, status)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sZhenHong_GetReward)
    if not pack then return end
    LDataPack.writeChar(pack, index)
    LDataPack.writeChar(pack, status)
    LDataPack.flush(pack)
end

--84-54 真红系统-礼包剩余时间
function s2cZHXGUpdateTime(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sZhenHong_LastTime)
    if not pack then return end
    LDataPack.writeChar(pack, var.giftStatus or 0)
    LDataPack.writeInt(pack, var.giftEndTime or 0)
    LDataPack.flush(pack)
end

--84-55 真红系统-原力升级
local function c2sZHStageUp(actor, pack)
    local slot = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zhsz) then return end
    zhStageUp(actor, slot)
end

--84-55 真红系统-原力升级
function s2cZHStageUp(actor, slot, stage)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sZhenHong_StageUp)
    if not pack then return end
    LDataPack.writeChar(pack, slot)
    LDataPack.writeShort(pack, stage)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function onInit(actor)
    calcAttr(actor, false)
end

local function onLogin(actor)
    s2cZHInfo(actor)
    zhGiftCheckTime(actor)
end

local function onSystemOpen(actor)
    zhGiftStart(actor)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
    
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.zhxg, onSystemOpen)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cZhenHong_LevelUp, c2sZHLevelUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cZhenHong_SuitUp, c2sZHSuitUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cZhenHong_GetReward, c2sZHGetReward)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cZhenHong_StageUp, c2sZHStageUp)
    
    msgsystem.regHandle(OffMsgType_ZHXG, OffMsgZHXGBuy)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.gmZHLevelUp = function(actor, args)
    local slot = tonumber(args[1])
    local pos = tonumber(args[2])
    if not (slot and pos) then return end
    zhLevelUp(actor, slot, pos)
    return true
end

gmCmdHandlers.gmZHStageUp = function(actor, args)
    local slot = tonumber(args[1])
    if not slot then return end
    zhStageUp(actor, slot)
    return true
end

gmCmdHandlers.gmZHSuitUp = function(actor, args)
    local slot = tonumber(args[1])
    if not slot then return end
    zhSuitUp(actor, slot)
    return true
end

gmCmdHandlers.gmZHClearVar = function(actor, args)
    local var = LActor.getStaticVar(actor)
    var.zhenhong = nil
    s2cZHInfo(actor)
    return true
end

gmCmdHandlers.zhenhongAll = function (actor, args)
    for slot, config in pairs(ZHLevelConfig) do
        for pos, conf in pairs(config) do
            setZHPosLevel(actor, slot, pos, #conf)
        end
    end
    for slot, conf in pairs(ZHSuitLevelConfig) do
        setZHSuitLevel(actor, slot, conf.maxLevel)
    end
    
    local var = getActorVar(actor)
    for slot, conf in pairs(ZHStageConfig) do
        var.stages[slot] = #conf
    end
    
    var.zhyjLevel = #ZHYJSuitConfig
    LActor.setPassiveLevel(actor, ZHCommonConfig.zhyjskill, #ZHYJSuitConfig)
    passiveskill.updatePassiveSkill(actor, ZHCommonConfig.zhyjskill, #ZHYJSuitConfig)
    
    var.zhbtLevel = #ZHBTSuitConfig
    LActor.setPassiveLevel(actor, ZHCommonConfig.zhbtskill, #ZHBTSuitConfig)
    passiveskill.updatePassiveSkill(actor, ZHCommonConfig.zhbtskill, #ZHBTSuitConfig)
    
    calcAttr(actor, true)
    s2cZHInfo(actor)
end

