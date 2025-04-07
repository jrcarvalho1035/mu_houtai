-- @version 1.0
-- @author  qianmeng
-- @date    2017-1-6 21:14:25.
-- @system  ShenShou

module("shenshousystem", package.seeall)

--精灵数据获取
function getShenShouStaticVar(actor)
    local actorVar = LActor.getStaticVar(actor)
    if not actorVar.m_ShenShou then
        actorVar.m_ShenShou = {}
        actorVar.m_ShenShou.freeTimes = 1 --次数
        actorVar.m_ShenShou.freeTime = 0 --上次使用时间
        actorVar.m_ShenShou.ShenShous = {}--激活的精灵信息
        actorVar.m_ShenShou.ShenShouBag = {}
        actorVar.m_ShenShou.bagCount = 0
        actorVar.m_ShenShou.ShenShouShop = {}
    end
    local var = actorVar.m_ShenShou
    if not var.drawTime then --抽奖的次数
        var.drawTime = {}
        var.drawTime[1] = 0
        var.drawTime[2] = 0
    end
    return var
end
----------------------------------------------------------------------------------------------------------------------

--生成一个精灵
local function createShenShou(actor, ShenShouData, id)
    local type = 2
    if not ShenShouData.ShenShouBag[id] then
        ShenShouData.ShenShouBag[id] = {}
        ShenShouData.ShenShouBag[id].cnt = 0
        type = 1
    end
    if ShenShouData.ShenShouBag[id].cnt == 0 then type = 1 end
    ShenShouData.ShenShouBag[id].cnt = ShenShouData.ShenShouBag[id].cnt + 1
    s2cShenShouCreate(actor, id)
    --actorevent.onEvent(actor, aeShenShouCnt, ShenShouConfig[id].quality)
    return ShenShouData.ShenShouBag[id], type
end

--外部生成精灵接口
function addShenShou(actor, id, number)
    if not ShenShouConfig[id] then return end
    local ShenShouData = getShenShouStaticVar(actor)
    for i = 1, number do
        local ShenShou, type = createShenShou(actor, ShenShouData, id)
        if ShenShou then
            s2cShenShouUpdate(actor, ShenShou, id, type)
        end
    end
end

--计算精灵的属性
function calcAttr(actor, calc)
    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShous = ShenShouData.ShenShous
    local addAttrs = {}
    local baseAttrs = {}
    --精灵升级属性
    for id, conf in pairs(ShenShouConfig) do
        local level = ShenShous[id] and ShenShous[id].level or 0
        if level > 0 then
            --基础属性
            for __, v in ipairs(conf.baseAttrs) do
                baseAttrs[v.type] = (baseAttrs[v.type] or 0) + v.value * level
            end
            --特殊属性
            for __, v in ipairs(conf.specialAttrs) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
            end
            --精灵力量丹属性
            for __, v in ipairs(ShenShouCommonConfig.atPower[conf.quality].attr) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * (ShenShous[id].atPowerPill or 0)
            end
            --精灵防御丹属性
            for __, v in ipairs(ShenShouCommonConfig.def[conf.quality].attr) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * (ShenShous[id].defPill or 0)
            end
        end
    end
    
    --精灵组合
    for __, v in ipairs(ShenShouFormationConfig) do
        if #v.arg3 > 0 then
            local isActive = true
            for i = 1, #v.arg3 do
                if not ShenShous[v.arg3[i]] or ShenShous[v.arg3[i]].level == 0 then
                    isActive = false
                    break
                end
            end
            if isActive then
                for __, tmpAttr in ipairs(v.attr) do
                    addAttrs[tmpAttr.type] = (addAttrs[tmpAttr.type] or 0) + tmpAttr.value
                end
            end
        end
    end
    --精灵印记
    for id in pairs(ShenShouConfig) do
        if ShenShous[id] and ShenShous[id].signetLv or 0 > 0 then
            for __, v in ipairs(ShenShouSignetConfig[ShenShous[id].signetLv].baseAttrs) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
            end
        end
    end   
    local attrPer = addAttrs[Attribute.atShenShouTotalPer] or 0
    for k, v in pairs(baseAttrs) do
        addAttrs[k] = (addAttrs[k] or 0) + v * (1 + attrPer / 10000)
    end

    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_ShenShou)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    if calc then
        LActor.reCalcAttr(actor)
    end
end

--随机精灵奖励
local function getRankdShenShou(rewards)
    local weight = 0 --总权值
    for k, v in pairs(rewards) do
        weight = weight + v[2]
    end
    
    local num = math.random(1, weight)
    local count = 0
    for k, v in ipairs(rewards) do
        count = count + v[2]
        if count >= num then
            return v[1]
        end
    end
    return 0
end

--定时恢复免费抽奖次数
function setFreeTimes(actor)
    local ShenShouData = getShenShouStaticVar(actor)
    if ShenShouData.freeTimes > 0 then
        return
    end
    local nextTime = ShenShouData.freeTime - System.getNowTime()
    if nextTime > 0 then
        LActor.postScriptEventLite(actor, nextTime * 1000, function() setFreeTimes(actor) end)
    else
        ShenShouData.freeTimes = 1
    end
end

local function onLogin(actor)
    checkShenShouData(actor)
    s2cShenShouData(actor)
    s2cShenShouBag(actor)
end

local function onInit(actor)
    calcAttr(actor, false)
    setFreeTimes(actor)
end

function getShenShouEquipCount(actor)
    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShous = ShenShouData.ShenShous
    local count = 0
    for i = 1, 4 do
        local ShenShou = ShenShouData.ShenShouBag[ShenShous[i]]
        if ShenShou then
            count = count + 1
        end
    end
    return count
end

function getShenShouTotalLevel(actor)
    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShous = ShenShouData.ShenShous
    local allLevel = 0
    for id in pairs(ShenShouConfig) do
        local level = ShenShous[id] and ShenShous[id].level or 0
        allLevel = allLevel + level
    end
    return allLevel
end

function getShenShouActive(actor)
    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShous = ShenShouData.ShenShous
    local count = 0
    for id in pairs(ShenShouConfig) do
        local level = ShenShous[id] and ShenShous[id].level or 0
        if level > 0 then
            count = count + 1
        end
    end
    return count
end

--对精灵背包数据进行检测，把不存在的精灵id变成存在的id
function checkShenShouData(actor)
    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShouBag = ShenShouData.ShenShouBag
    for i = 0, ShenShouData.bagCount - 1 do
        if not ShenShouConfig[ShenShouBag[i].id] then
            ShenShouBag[i].id = next(ShenShouConfig)
        end
    end
end

--求取下一次出传说精灵的次数
local function getNextDrawCount(actor, tp)
    local ret = 200 --100次为循环最高值，可能会溢出最高值
    local ShenShouData = getShenShouStaticVar(actor)
    local times = ShenShouData.drawTime[tp]
    for k, v in pairs(ShenShouLotteryConfig[tp].times1) do
        if v == 2 or v == 3 or v == 4 then --能出传说精灵的奖池
            if k >= times + 1 and k < ret then
                ret = k
            end
            if k + 100 < ret then --在这循环里后面已无传说精灵的奖池
                ret = k + 100
            end
        end
    end
    return ret - times - 1
end

function checkUsePowerPill(id, level, count)
    local config = ShenShouLevelConfig[id]
    if not config then return false end

    local atPowerCnt = 0
    for _, conf in ipairs(config) do
        if conf.level <= level then 
            atPowerCnt = conf.atPowerCnt
        else
            break
        end
    end
    return count < atPowerCnt
end

function checkUseDefPill(id, level, count)
    local config = ShenShouLevelConfig[id]
    if not config then return false end

    local defCnt = 0
    for _, conf in ipairs(config) do
        if conf.level <= level then 
            defCnt = conf.defCnt
        else
            break
        end
    end
    return count < defCnt
end
------------------------------------------------------------------------------------------
--获得精灵通知
function s2cShenShouCreate(actor, id)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_Create)
    LDataPack.writeInt(pack, id)
    LDataPack.flush(pack)
end

--发送精灵数据
function s2cShenShouData(actor)
    local ShenShouData = getShenShouStaticVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_Data)
    local ShenShous = ShenShouData.ShenShous
    local cnt = 0
    for id, __ in pairs(ShenShouConfig) do
        cnt = cnt + 1
    end
    LDataPack.writeShort(pack, cnt)
    for id, __ in pairs(ShenShouConfig) do
        LDataPack.writeInt(pack, id)
        LDataPack.writeInt(pack, ShenShous[id] and ShenShous[id].level or 0)
        LDataPack.writeShort(pack, ShenShous[id] and ShenShous[id].signetLv or 0)
        LDataPack.writeInt(pack, ShenShous[id] and ShenShous[id].atPowerPill or 0)
        LDataPack.writeInt(pack, ShenShous[id] and ShenShous[id].defPill or 0)
    end
    
    local surTime = 0 --剩余时间
    if ShenShouData.freeTimes <= 0 then
        surTime = ShenShouData.freeTime - System.getNowTime()
    end
    LDataPack.writeShort(pack, ShenShouData.freeTimes)
    LDataPack.writeInt(pack, surTime)
    LDataPack.writeShort(pack, getNextDrawCount(actor, 1)) --代券抽奖离传说精灵次数
    LDataPack.writeShort(pack, getNextDrawCount(actor, 2)) --钻石抽奖离传说精灵次数
    --LDataPack.writeInt(pack, ShenShouData.fightId or 0)
    LDataPack.flush(pack)
end

--发送精灵背包
function s2cShenShouBag(actor)
    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShouBag = ShenShouData.ShenShouBag
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_Bag)
    local count = 0
    local pos = LDataPack.getPosition(pack)
    LDataPack.writeInt(pack, count)
    for id, __ in pairs(ShenShouConfig) do
        if ShenShouBag[id] and ShenShouBag[id].cnt ~= 0 then
            LDataPack.writeInt(pack, id)
            LDataPack.writeUInt(pack, ShenShouBag[id].cnt)
            count = count + 1
        end
    end
    local npos = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, pos)
    LDataPack.writeInt(pack, count)
    LDataPack.setPosition(pack, npos)
    LDataPack.flush(pack)
end

--精灵抽奖
function c2sShenShouDraw(actor, pack)
    local tp = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenshou) then return end
    local config = ShenShouLotteryConfig[tp]
    local ShenShouData = getShenShouStaticVar(actor)
    
    local flag = config.cdTime > 0 and ShenShouData.freeTimes > 0 --可以免费抽
    if not flag and actoritem.checkItems(actor, config.cost) == false then
        return
    end
    
    if flag then
        ShenShouData.freeTimes = ShenShouData.freeTimes - 1
        ShenShouData.freeTime = System.getNowTime() + config.cdTime
        setFreeTimes(actor) --设置某时间后恢复免费次数
    else
        actoritem.reduceItems(actor, config.cost, "ShenShou draw")
        actoritem.addItem(actor, NumericType_Debris, config.score, "ShenShou draw") --增加积分
    end
    
    --对使用哪个抽奖池进行计算
    local rewards = config.rewards --普通抽奖池
    ShenShouData.drawTime[tp] = ShenShouData.drawTime[tp] + 1
    local num = config.times1[ShenShouData.drawTime[tp]]
    if num then --更换抽奖池
        rewards = config["rewards"..num]
    end
    if ShenShouData.drawTime[tp] == 100 then
        ShenShouData.drawTime[tp] = 0 --从头轮起
    end
    
    local id = getRankdShenShou(rewards)
    local ShenShouBag = ShenShouData.ShenShouBag
    local ShenShou, type = createShenShou(actor, ShenShouData, id)
    if not ShenShou then return end
    
    s2cShenShouUpdate(actor, ShenShou, id, type)--回包
    s2cShenShouData(actor)
    
    --actorevent.onEvent(actor, aeShenShouDraw)
    if ShenShouConfig[id].quality >= 4 then
        noticesystem.broadCastNotice(noticesystem.NTP.ShenShou, LActor.getName(actor), ShenShouConfig[id].name)
    end
    utils.logCounter(actor, "othersystem", ShenShou.id, "", "ShenShou", "draw")
    actorevent.onEvent(actor, aeShenShouDraw, 1)
end

--精灵升级
function c2sShenShouLevel(actor, pack)
    local id = LDataPack.readInt(pack)
    local config = ShenShouConfig[id]
    if not config then return end

    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShouBag = ShenShouData.ShenShouBag
    if not ShenShouBag[id] or ShenShouBag[id].cnt < config.needCount then
        return
    end

    local ShenShous = ShenShouData.ShenShous
    if not ShenShous[id] then
        ShenShous[id] = {}
        ShenShous[id].level = 0
        ShenShous[id].signetLv = 0
    end
    local ShenShou = ShenShous[id]
    if ShenShou.level >= config.maxLevel then return end
	
	
	--função para chamar ID e contar a quantidade de itens
	count = ShenShouBag[id].cnt
	
	if count + (ShenShou.level or 0) >= config.maxLevel then
		count = config.maxLevel - (ShenShou.level or 0)
	end
	
	---

    ShenShouBag[id].cnt = ShenShouBag[id].cnt - count
    
    ShenShou.level = ShenShou.level + count

    if ShenShou.level == 1 then
        actorevent.onEvent(actor, aeShenShouActive, 1)
    end
    actorevent.onEvent(actor, aeShenShouLevelUp, 1)
    calcAttr(actor, true)
    local type = 2
    if ShenShouBag[id].cnt == 0 then
        type = 3
    end
    s2cShenShouUpdate(actor, ShenShouData.ShenShouBag[id], id, type)
    s2cShenShouBag(actor)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_Level)
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, ShenShou.level)
    LDataPack.flush(pack)
    
    --actorevent.onEvent(actor, aeShenShouLevel, ShenShou.level)
    utils.logCounter(actor, "ShenShou level", id, ShenShou.id, ShenShou.level)
end

--返回精灵商店数据
function s2cShenShouShop(actor)
    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShouShop = ShenShouData.ShenShouShop
    local count = utils.getTableCount(ShenShouShopConfig)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_Shop)
    LDataPack.writeShort(pack, count)
    for id, config in pairs(ShenShouShopConfig) do
        LDataPack.writeInt(pack, id)
        LDataPack.writeShort(pack, ShenShouShop[id] or 0)
    end
    LDataPack.flush(pack)
end

--查看精灵商店
function c2sShenShouShop(actor, pack)
    s2cShenShouShop(actor)
end

--购买精灵
function c2sShenShouBuy(actor, pack)
    local id = LDataPack.readInt(pack)
    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShouShop = ShenShouData.ShenShouShop
    local config = ShenShouShopConfig[id]
    if not config then
        return
    end
    
    local times = ShenShouShop[id] or 0
    if config.limit ~= 0 and times >= config.limit then
        return
    end
    if not actoritem.checkItem(actor, NumericType_Debris, config.integral) then --验证积分是否足够
        return
    end
    
    ShenShouShop[id] = times + 1
    actoritem.reduceItem(actor, NumericType_Debris, config.integral, "ShenShou buy")
    local ShenShou, type = createShenShou(actor, ShenShouData, id)
    if not ShenShou then return end
    
    s2cShenShouUpdate(actor, ShenShou, id, type)
    s2cShenShouShop(actor)
    utils.logCounter(actor, "ShenShou buy", id, config.integral)
end

-- --精灵出战
-- function c2sShenShouFight(actor, pack)
--     local id = LDataPack.readInt(pack)
--     ShenShouFight(actor, id)
-- end

-- function ShenShouFight(actor, id)
--     if not ShenShouConfig[id] then return end
--     local ShenShouData = getShenShouStaticVar(actor)
--     LActor.setShenShouId(actor, id, 1, ShenShouConfig[id].MvSpeed)
--     ShenShouData.fightId = id
--     s2cShenShouFight(actor, id)
--     actorevent.onEvent(actor, aeShenShouFight, 1)
-- end

--精灵出站返回
function s2cShenShouFight(actor, id)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_Fight)
    LDataPack.writeInt(pack, id)
    LDataPack.flush(pack)
end

function s2cShenShouUpdate(actor, ShenShou, id, type)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_Update)
    LDataPack.writeInt(pack, id)
    LDataPack.writeUInt(pack, ShenShou.cnt)
    LDataPack.writeChar(pack, type)
    LDataPack.flush(pack)
end

-- function WriteShenShouData(actor, pack)
--     local ShenShouData = getShenShouStaticVar(actor)
--     local cnt = 0
--     for id, __ in pairs(ShenShouConfig) do
--         cnt = cnt + 1
--     end
--     LDataPack.writeShort(pack, cnt)
--     for id, __ in pairs(ShenShouConfig) do
--         LDataPack.writeInt(pack, id)
--         LDataPack.writeShort(pack, ShenShous[id] and ShenShous[id].level or 0)
--     end
--     LDataPack.writeInt(pack, ShenShouData.fightId or 0)
-- end

--足迹丹使用信息
function sendPillUseInfo(actor, ShenShouId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_PillInfo)
    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShou = ShenShouData.ShenShous[ShenShouId]
    LDataPack.writeInt(pack, ShenShouId)
    LDataPack.writeInt(pack, ShenShou and ShenShou.atPowerPill or 0)
    LDataPack.writeInt(pack, ShenShou and ShenShou.defPill or 0)
    LDataPack.flush(pack)
end

--精灵印记升级返回
function sendSignetUpInfo(actor, ShenShouId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_SignetInfo)
    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShou = ShenShouData.ShenShous[ShenShouId]
    LDataPack.writeInt(pack, ShenShouId)
    LDataPack.writeShort(pack, ShenShou.signetLv)
    LDataPack.flush(pack)
end

--精灵印记升级
function c2sShenShouSignetUp(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenshou) then return end
    local ShenShouId = LDataPack.readInt(pack)
    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShou = ShenShouData.ShenShous[ShenShouId]
    if not ShenShou then return end
    ShenShou.signetLv = ShenShou.signetLv or 0
    if not ShenShouSignetConfig[ShenShou.signetLv + 1] then return end
    local conf = ShenShouSignetConfig[ShenShou.signetLv]
    if not actoritem.checkItems(actor, conf.costItems) then
        return false
    end
    actoritem.reduceItems(actor, conf.costItems, "ShenShou signet up")
    ShenShou.signetLv = ShenShou.signetLv + 1
    sendSignetUpInfo(actor, ShenShouId)
    calcAttr(actor, true)
end

--精灵属性丹使用
function c2sShenShouPillUse(actor, pack)
    local ShenShouId = LDataPack.readInt(pack)
    local type = LDataPack.readChar(pack)
    local ShenShouData = getShenShouStaticVar(actor)
    local ShenShou = ShenShouData.ShenShous[ShenShouId]
    ShenShou.atPowerPill = ShenShou.atPowerPill or 0
    ShenShou.defPill = ShenShou.defPill or 0
    if type == 0 then
        id = ShenShouCommonConfig.atPower[ShenShouConfig[ShenShouId].quality].id
        if not checkUsePowerPill(ShenShouId, ShenShou.level, ShenShou.atPowerPill) then return end
    else
        id = ShenShouCommonConfig.def[ShenShouConfig[ShenShouId].quality].id
        if not checkUseDefPill(ShenShouId, ShenShou.level, ShenShou.defPill) then return end
    end
    
    local costItems = {{id = id, count = 1}}
	
	countz = actoritem.getItemCount(actor, id)
	
	if countz >= 99999 then
		countz = 99999
	end
	
	
	--FALTA LIMITAR PARA NÃO ULTRAPASSAR O LEVEL MÁXIMO
	
	
	--if countz + (var.pilluse[pillindex] or 0) >= max then
		--countz = max - (var.pilluse[pillindex] or 0)
	--end
	
	
    if not actoritem.checkItems(actor, costItems) then
        return false
    end
	
	---------
	
	actoritem.reduceItem(actor, id, countz, "ShenShou pill use")
	---------
    --actoritem.reduceItems(actor, costItems, "ShenShou pill use")
    
    if type == 0 then
        ShenShou.atPowerPill = ShenShou.atPowerPill + countz
    else
        ShenShou.defPill = ShenShou.defPill + countz
    end
    
    sendPillUseInfo(actor, ShenShouId)
    calcAttr(actor, true)
end

--_G.addShenShou = addShenShou
--_G.WriteShenShouData = WriteShenShouData

local function regEvent()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_Draw, c2sShenShouDraw)
    netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_Level, c2sShenShouLevel)
    netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_Shop, c2sShenShouShop)
    netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_Buy, c2sShenShouBuy)
    netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_SignetUp, c2sShenShouSignetUp)
    --netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_Fight, c2sShenShouFight)
    netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_PillUse, c2sShenShouPillUse)
end

table.insert(InitFnTable, regEvent)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.ShenShouFreeTimes = function (actor, args)
    local ShenShouData = getShenShouStaticVar(actor)
    ShenShouData.freeTimes = 1
    return true
end

gmCmdHandlers.ShenShouCreate = function (actor, args)
    local ShenShouData = getShenShouStaticVar(actor)
    local id = tonumber(args[1])
    local cnt = tonumber(args[2])
    for i = 1, cnt do
        local ShenShou, type = createShenShou(actor, ShenShouData, id)
        if not ShenShou then return end
        s2cShenShouUpdate(actor, ShenShou, id, type)
    end
    return true
end

gmCmdHandlers.ShenShouClean = function (actor, args)
    local actorVar = LActor.getStaticVar(actor)
    actorVar.m_ShenShou = nil
    return true
end

gmCmdHandlers.ShenShouDrawTest = function (actor, args)
    local tp = tonumber(args[1])
    if not tp or type(tp) ~= "number" then return end
    for i = 1, 10000 do
        local pack = LDataPack.allocPacket()
        LDataPack.writeChar(pack, args[1])
        LDataPack.setPosition(pack, 0)
        c2sShenShouDraw(actor, pack)
    end
end

gmCmdHandlers.ShenShouDrawTest1 = function (actor, args)
    local tp = tonumber(args[1]) or 2
    local config = subactivity10.getLotteryConfig()[tp]
    local DConfig = ShenShouConfig
    local ShenShous = {}
    local drawTime = 0
    if not config then return end
    repeat
        local rewards = config.rewards --普通抽奖池
        drawTime = drawTime + 1
        local num = config.times1[drawTime]
        if num then --更换抽奖池
            rewards = config["rewards"..num]
        end
        if drawTime == 100 then drawTime = 0 end
        local id = getRankdShenShou(rewards)
        if id == 0 then
            print ("未抽取到精灵,奖池编号： "..num)
        end
        ShenShous["num"] = (ShenShous["num"] or 0) + 1
        ShenShous[id] = (ShenShous[id] or 0) + 1
        --if id == 500020 then break end
        if ShenShous["num"] >= 10000 then break end
    until (false)
    for k, v in pairs(ShenShous) do
        if type (k) == "number" then
            local name = DConfig[k] and DConfig[k].name or "未知"
            utils.printInfo(name, v)
        end
    end
    print ("总计抽取： "..ShenShous["num"])
    return true
end

gmCmdHandlers.shenshouAll = function (actor, args)
    local var = getShenShouStaticVar(actor)
    local ShenShous = var.ShenShous
    for id, conf in pairs(ShenShouConfig) do
        local config = ShenShouLevelConfig[id]
        ShenShous[id] = {
            level = conf.maxLevel,
            signetLv = #ShenShouSignetConfig,
            atPowerPill = config[#config].atPowerCnt,
            defPill = config[#config].defCnt,
        }
    end
    calcAttr(actor, true)
    s2cShenShouData(actor)
    return true
end

