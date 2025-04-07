-- @version1.0
-- @authorqianmeng
-- @date2017-3-3 17:28:14.
-- @systemrelic

module("relic", package.seeall)
require("scene.relicfuben")
require("scene.reliccommon")
require("scene.relicshop")
require("scene.relicreward")
require("scene.relicreboxward")


local FubenState = {
    notActived = 0, --未出现
    actived = 1, --未击败
    finish = 2, --已击败
}

function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.relicdata then
        var.relicdata = {
            curId = 1,
            createTime = 0, --部队出现时间
            state = FubenState.notActived,
            isEvent = 0,
            eventTime = 0, --遗迹消失时间
            shop = {},
            curFighting = 0,
        }
    end
    if not var.relicdata.boxLevel then var.relicdata.boxLevel = 1 end
    if not var.relicdata.boxProgress then var.relicdata.boxProgress = 0 end
    return var.relicdata
end

function isAllFinish(actor)
    local var = getActorVar(actor)
    local conf = RelicfbConfig[var.boxLevel]
    if not conf then return false end
    if var.curId == #conf and var.state == FubenState.finish then
        return true
    end
    return false
end

--黄金部队创建
function relicFubenCreate(actor)
    local var = getActorVar(actor)
    if var.state == FubenState.notActived then
        var.state = FubenState.actived
    end
end

--黄金部队开始计时
function relicFubenInit(actor, isNewday)
    local var = getActorVar(actor)
    if isNewday then var.curId = 1 end
    if not RelicfbConfig[var.boxLevel] then return end
    local conf = RelicfbConfig[var.boxLevel][var.curId]
    if not conf then return end
    
    var.createTime = System.getNowTime() + conf.delay
    var.state = FubenState.notActived
    setCreatetimer(actor)
    --LActor.postScriptEventLite(actor, time * 1000, relicFubenCreate, idx)
end

--黄金遗迹消失
function relicEventFinish(actor)
    local var = getActorVar(actor)
    var.isEvent = 0
    var.shop = {}
end

--黄金遗迹创建
function relicEventCreate(actor)
    local var = getActorVar(actor)
    local conf = RelicfbConfig[var.boxLevel][var.curId]
    if not conf then return end
    
    local openDay = System.getOpenServerDay() + 1
    local events = {}
    for k, v in ipairs(conf.events) do
        if openDay < RelicCommonConfig[1].noreward or v.tp ~= 2 then --开服3天或以后不会再有免费奖励的遗迹
            table.insert(events, v)
        end
    end
    
    local sum = 0
    for k, v in ipairs(events) do
        sum = sum + v.weight
    end
    
    --找出随机到的事件
    local digit = math.random(1, sum)
    local count = 0
    for k, v in ipairs(events) do
        count = count + v.weight
        if count >= digit then
            var.etp = v.tp
            var.eid = v.id
            break
        end
    end
    
    local eventConf
    if var.etp == 1 then
        eventConf = RelicShopConfig[var.eid]
    elseif var.etp == 2 then
        eventConf = RelicRewardConfig[var.eid]
    end
    if not eventConf then return end
    var.isEvent = 1
    var.eventTime = System.getNowTime() + RelicCommonConfig[1].exist
    var.shop = {}
    var.curFighting = LActor.getActorPower(LActor.getActorId(actor))
    --LActor.postScriptEventLite(actor, RelicCommonConfig[1].exist * 1000, relicEventFinish)
    s2cRelicEvent(actor)
    setEventtimer(actor)
end

--副本胜利
function onRelicWin(ins)
    local actor = ins:getActorList()[1]
    local var = getActorVar(actor)
    if not var then print("err var", actor) return end
    
    var.state = FubenState.finish
    var.boxProgress = var.boxProgress + 1
    
    local items = RelicfbConfig[var.boxLevel][var.curId].rewards
    if items ~= nil then
        instancesystem.setInsRewards(ins, actor, items)
    end

    relicEventCreate(actor) --生成遗迹
    actorevent.onEvent(actor, aeBeatRelicCount, var.curId)
    
    --生成下一个部队
    if var.curId < #RelicfbConfig[var.boxLevel] then
        var.curId = var.curId + 1
        relicFubenInit(actor)
    end
    s2cRelicTiming(actor)
    s2cRelicInfo(actor)
    s2cRelicEvent(actor)
end

function setCreatetimer(actor)
    local var = getActorVar(actor)
    local t = var.createTime - System.getNowTime()
    if t > 0 then
        LActor.postScriptEventLite(actor, t * 1000, setCreatetimer)
    else
        relicFubenCreate(actor) --黄金部队可以打了
        s2cRelicTiming(actor)
        s2cRelicInfo(actor)
    end
end

function setEventtimer(actor)
    local var = getActorVar(actor)
    local t = var.eventTime - System.getNowTime()
    if t > 0 then
        LActor.postScriptEventLite(actor, t * 1000, setEventtimer)
    else
        if var.isEvent == 1 then
            relicEventFinish(actor)
            s2cRelicInfo(actor)
        end
    end
end

function onNewDay(actor, login)
    relicFubenInit(actor, true)
    if not login then
        s2cRelicTiming(actor)
        s2cRelicInfo(actor)
    end
end

function onLogin(actor)
    s2cRelicTiming(actor)
    s2cRelicInfo(actor)
    setCreatetimer(actor)
    setEventtimer(actor)
    s2cRelicEvent(actor)
end

---------------------------------------------------------------------------------------------
--黄金部队出现剩余时间
function s2cRelicTiming(actor)
    local now = System.getNowTime()
    local var = getActorVar(actor)
    local time = var.createTime > now and (var.createTime - now) or 0 --剩余出现秒数
    
    local isFinish = 0 --是否完结
    if isAllFinish(actor) then
        isFinish = 1
    end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.cFubenCmd_RelicTiming)
    if pack == nil then return end
    LDataPack.writeInt(pack, time)
    LDataPack.writeByte(pack, isFinish)
    LDataPack.writeShort(pack, var.curId)
    LDataPack.flush(pack)
end

--黄金部队信息
function c2sRelicInfo(actor, packet)
    s2cRelicInfo(actor)
end

function s2cRelicInfo(actor)
    local var = getActorVar(actor)
    local config = RelicfbConfig[var.boxLevel]
    if not config then return end
    
    local now = System.getNowTime()
    local curId = var.curId
    if isAllFinish(actor) then
        curId = var.curId + 1
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_RelicInfo)
    if pack == nil then return end
    LDataPack.writeShort(pack, var.boxLevel)
    LDataPack.writeShort(pack, var.boxProgress)
    LDataPack.writeShort(pack, #config)
    for idx, conf in ipairs(config) do
        local state = FubenState.notActived
        if idx < var.curId then
            state = FubenState.finish
        elseif idx == var.curId then
            if var.createTime <= now and var.state == FubenState.notActived then
                var.state = FubenState.actived
            end
            state = var.state
        end
        LDataPack.writeShort(pack, idx)
        LDataPack.writeInt(pack, conf.fbId)
        LDataPack.writeShort(pack, state)
        LDataPack.writeInt(pack, conf.monsterId)
        local mconf = MonstersConfig[conf.monsterId]
        LDataPack.writeString(pack, mconf.name)
        LDataPack.writeString(pack, mconf.head)
        LDataPack.writeShort(pack, mconf.avatar[1])
    end
    LDataPack.writeByte(pack, var.isEvent)
    LDataPack.writeShort(pack, curId)
    local time = var.eventTime > now and var.eventTime - now or 0
    LDataPack.writeInt(pack, time) --剩余秒数
    LDataPack.flush(pack)
end

--黄金遗迹
function c2sRelicEvent(actor, packet)
    s2cRelicEvent(actor)
end

function s2cRelicEvent(actor)
    local var = getActorVar(actor)
    local now = System.getNowTime()
    if var.isEvent == 0 then
        return
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_RelicEvent)
    if pack == nil then return end
    LDataPack.writeShort(pack, var.etp)
    LDataPack.writeShort(pack, var.eid)
    if var.etp == 1 then
        local eventConf = RelicShopConfig[var.eid]
        LDataPack.writeShort(pack, var.shop[1] or 0)
    elseif var.etp == 2 then
        local flag = 0 --是否能拿奖励
        local eventConf = RelicRewardConfig[var.eid]
        if eventConf.tp == 1 then
            local power = LActor.getActorPower(LActor.getActorId(actor))
            if (power - var.curFighting) >= eventConf.arg1 then --新增的战斗力达到指定值
                flag = 1
            end
        end
        if eventConf.tp == 2 then
            flag = 1
        end
        LDataPack.writeByte(pack, flag)
        LDataPack.writeDouble(pack, var.curFighting + eventConf.arg1)
    end
    local time = var.eventTime > now and var.eventTime - now or 0
    LDataPack.writeInt(pack, time) --剩余秒数
    LDataPack.flush(pack)
end

--挑战
function c2sRelicFight(actor, packet)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.relic) then return end
    local var = getActorVar(actor)
    if not RelicfbConfig[var.boxLevel] then
        print("false relic finght curId", var.boxLevel)
        return
    end
    if var.state ~= FubenState.actived then
        print("false relic finght state", var.state)
        return
    end
    
    local conf = RelicfbConfig[var.boxLevel][var.curId]
    if not conf then return end
    
    local boxConf = RelicBoxRewardConfig[var.boxLevel]
    if not boxConf then return end
    if boxConf.progress ~= 0 and var.boxProgress >= boxConf.progress then
        print("false relic finght progress =", var.boxProgress, "boxConf.progress =", boxConf.progress)
        return
    end
    
    if not utils.checkFuben(actor, conf.fbId) then return end
    local fbHandle = instancesystem.createFuBen(conf.fbId)
    if not fbHandle or fbHandle == 0 then return end
    local x, y = utils.getSceneEnterCoor(conf.fbId)
    LActor.enterFuBen(actor, fbHandle, 0, x, y)
end

--购买黄金部队
function c2sRelicBuy(actor, packet)
    local count = LDataPack.readInt(packet) --购买数量
    local var = getActorVar(actor)
    if var.etp ~= 1 then
        return
    end
    if var.isEvent == 0 then
        return
    end
    
    local eventConf = RelicShopConfig[var.eid]
    
    if (var.shop[1] or 0) + count > eventConf.number then
        return
    end
    if not actoritem.checkItem(actor, eventConf.cost.id, eventConf.cost.count * count) then
        return
    end
    actoritem.reduceItem(actor, eventConf.cost.id, eventConf.cost.count * count, "buy relic cost")
    actoritem.addItem(actor, eventConf.item.id, eventConf.item.count * count, "buy relic")
    var.shop[1] = (var.shop[1] or 0) + count
    if var.shop[1] >= eventConf.number then
        var.isEvent = 0
    end
    
    s2cRelicEvent(actor)
    s2cRelicInfo(actor)
end

--领取免费奖励
function c2sRelicEventReward(actor, packet)
    local var = getActorVar(actor)
    if var.etp ~= 2 then
        return
    end
    if var.isEvent == 0 then
        return
    end
    local flag = false
    local eventConf = RelicRewardConfig[var.eid]
    if eventConf.tp == 1 then
        local power = LActor.getActorPower(LActor.getActorId(actor))
        if (power - var.curFighting) >= eventConf.arg1 then --新增的战斗力达到指定值
            flag = true
        end
    end
    if eventConf.tp == 2 then
        flag = true
    end
    if not flag then return end
    actoritem.addItems(actor, eventConf.rewards, "relic get rewards")
    var.isEvent = 0
    
    s2cRelicInfo(actor)
end

function c2sRelicBoxReward(actor)
    local var = getActorVar(actor)
    local old = var.boxLevel
    if not RelicBoxRewardConfig[old + 1] then 
        print("not find RelicBoxRewardConfig max")
        return 
    end
    if not RelicfbConfig[old + 1] then 
        print("not find RelicfbConfig max")
        return 
    end

    local conf = RelicBoxRewardConfig[old]
    if var.boxProgress < conf.progress then return end
    if not actoritem.checkEquipBagSpaceJob(actor, conf.rewards) then return end
    
    var.boxLevel = old + 1
    var.boxProgress = 0
    actoritem.addItems(actor, conf.rewards, "relic box rewards")
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_RelicBoxReward)
    if not pack then return end
    LDataPack.writeShort(pack, old)
    LDataPack.flush(pack)
    s2cRelicInfo(actor)
end

function onSystemOpen(actor)
    s2cRelicInfo(actor)
end

local function init()
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.relic, onSystemOpen)
    
    actorevent.reg(aeNewDayArrive, onNewDay)
    actorevent.reg(aeUserLogin, onLogin)
    
    if System.isCrossWarSrv() then return end
    for id, v in ipairs(RelicfbConfig) do
        for _, conf in ipairs(v) do
            insevent.registerInstanceWin(conf.fbId, onRelicWin)
        end
    end
    
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_RelicInfo, c2sRelicInfo)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_RelicEvent, c2sRelicEvent)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_RelicFight, c2sRelicFight)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_RelicBuy, c2sRelicBuy)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_RelicEventReward, c2sRelicEventReward)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_RelicBoxReward, c2sRelicBoxReward)
    
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.relicAddpro = function (actor, args)
    local count = tonumber(args[1]) or 1
    local var = getActorVar(actor)
    var.boxProgress = var.boxProgress + count
    s2cRelicInfo(actor)
    return true
end

gmCmdHandlers.relicFight = function (actor)
    c2sRelicFight(actor)
    return true
end

gmCmdHandlers.relicCreate = function (actor)
    local var = getActorVar(actor)
    var.createTime = System.getNowTime()
    relicFubenCreate(actor)
    s2cRelicTiming(actor)
    s2cRelicInfo(actor)
    return true
end

gmCmdHandlers.Relicfight = function (actor, args)
    local Num = tonumber(args[1]) or 1
    local var = getActorVar(actor)
    for i = 1, Num do
        if isAllFinish(actor) then onNewDay(actor) end
        if var.state == FubenState.notActived then
            var.createTime = System.getNowTime()
            relicFubenCreate(actor)
        end
        c2sRelicFight(actor)
        local ins = instancesystem.getActorIns(actor)
        local fbid = ins:getFid()
        local fbgroup = FubenConfig[fbid].group
        if fbgroup == 10011 then
            ins:win()
            print ("Relicfight_count: "..i)
            LActor.exitFuben(actor)
        else
            print ("this fb is not Relic! fbgroup --> "..fbgroup)
            return false
        end
    end
    return true
end
