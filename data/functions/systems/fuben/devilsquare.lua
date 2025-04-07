-- @version1.0
-- @authorqianmeng
-- @date2017-1-16 18:29:00.
-- @system恶魔广场

module("devilsquare", package.seeall)
require("scene.devilfuben")
require("scene.devilinspire")
require("scene.devilcommon")

function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.devilsquarefuben then
        var.devilsquarefuben = {
            inDev = 0, --在副本内
            idx = 0,
            curDeId = 0, --当前挑战的恶魔id
            intimes = 0, --进入次数
            buyTimes = 0, --购买次数
            score = 0, --恶魔积分
            hpAdd = 0, --血量加成
            attAdd = 0, --攻击加成
            nextTime = 0, --下一场恶魔广场的开启时间
            downTime = 0, --副本出怪的时间
            exitTime = 0, --副本结束时间
            scoreTime = 0, --更新数据CD时间
        }
    end
    if not var.devilsquarefuben.highExp then var.devilsquarefuben.highExp = 0 end
    if not var.devilsquarefuben.intotimes then var.devilsquarefuben.intotimes = 0 end --进入次数
    if not var.devilsquarefuben.inspiretimes then var.devilsquarefuben.inspiretimes = 0 end --鼓舞次数
    if not var.devilsquarefuben.isfirst then var.devilsquarefuben.isfirst = 0 end --第一次进入不扣次数，进入指定本
    return var.devilsquarefuben
end

function getHighExp(actor)
    local var = getActorVar(actor)
    return var.highExp or 0
end

--更新属性
function updateAttr(actor)
    local var = getActorVar(actor)
    if not var then return end
    local addAttrs = {}
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Fuben)
    attr:Reset()
    
    if var.inDev > 0 then
        addAttrs[Attribute.atHpPer] = (addAttrs[Attribute.atHpPer] or 0) + var.hpAdd
        addAttrs[Attribute.atAtkPer] = (addAttrs[Attribute.atAtkPer] or 0) + var.attAdd
        
        for k, v in pairs(addAttrs) do
            attr:Set(k, v)
        end
    end
    
    LActor.reCalcAttr(actor)
end

--进入副本处理
local function onEnterFb(ins, actor, isLogin)
    ins.exhibit.id = NumericType_Exp
    ins.data.exRate = neigua.getNeiguaFightCount(actor, ins.config.group)
    local var = getActorVar(actor)
    local now = System.getNowTime()
    var.inDev = 1
    
    --假若断线重连，判断要不要立刻刷怪
    if (not ins.postponeOn) and (var.downTime <= now) then
        ins:postponeStart()
    else
        LActor.postScriptEventLite(actor, (var.downTime - now) * 1000, startFight, ins) --延迟刷怪
    end
    
    --假若断线重连，判断要不要立刻结束
    if var.exitTime <= now then
        finishFuben(actor, ins, var.idx)
    else
        LActor.postScriptEventLite(actor, (var.exitTime - now) * 1000, finishFuben, ins, var.idx) --延迟结束
        updateAttr(actor)
        s2cDevilsquareInfo(actor) --断线重连时自动进入，客户端要知道副本id
        s2cDevilsquareDao(actor)
        s2cDevilsquareScore(actor)
    end
    s2cDevilsquareInspire(actor, 0, 1)
    
end

function checkHaveFuben(id)
    for k, v in pairs(DevilfbConfig) do
        if v.fbId == id then
            return true
        end
    end
    return false
end

local function onExitFbOffline(ins, actor)
    local var = getActorVar(actor)
    var.inDev = 0
    updateAttr(actor)
    var.nextTime = System.getNowTime() + DevilCommonConfig[1].secRound
    s2cDevilsquareInfo(actor)
end

--退出副本处理
local function onExitFb(ins, actor)
    onExitFbOffline(ins, actor)
    subactivity1.onGetDevilExp(actor, getHighExp(actor))
end

--杀怪处理, 增加积分（之后要处理收获奖励）
local function onMonsterDie(ins, mon, killer_hdl)
    local et = LActor.getEntity(killer_hdl)
    local killer_et = LActor.getActor(et)
    local var = getActorVar(killer_et)
    if not var then return end
    var.score = var.score + 1 --杀怪数量
    setScoreTimer(killer_et)
    --杀怪数量超过一定值就结束副本
    local actor = ins:getActorList()[1]
    local conf = DevilfbConfig[var.curDeId]
    if not conf then return end
    if var.score >= conf.number then
        finishFuben(actor, ins, var.idx)
    end
end

--玩家死亡，发送结算协议并退出副本
function onActorDie(ins, actor, killHdl)
    local var = getActorVar(actor)
    finishFuben(actor, ins, var.idx, true)
end

--恶魔广场战斗开始
function startFight(actor, ins)
    if ins.postponeOn then return end
    if ins.is_end then return end
    local var = getActorVar(actor)
    if not var then return end
    ins:postponeStart()
    s2cDevilsquareDao(actor)
end

local function getRate(score, conf)
    local rate = 1
    for k, v in ipairs(conf.rate) do
        if score >= v then
            rate = k
        else
            break
        end
    end
    return rate
end

--副本结束
function finishFuben(actor, ins, idx, isLose)
    if ins.is_end then return end
    local var = getActorVar(actor)
    if not var then return end
    if var.idx ~= idx or var.inDev == 0 then return end
    local actorId = LActor.getActorId(actor)
    
    local conf = DevilfbConfig[var.curDeId]
    if not conf then return end
    local rate = getRate(var.score, conf)
    local exRate = ins.data.exRate or 1
    
    if var.isfirst == 0 then
        var.isfirst = 1
    end
    --经验
    local exp = ins.actor_list[actorId].exp or 0
    local expExtra = math.ceil(exp * conf.coefficient[rate]) --额外增加经验
    local expTotal = (expExtra + exp) * exRate - exp --挂机助手X倍经验
    if expTotal > 0 then
        LActor.addExp(actor, expTotal, "devil extra exp", false, true, 1)
        ins:addPickExp(actorId, expTotal)
    end
    
    local items = {}
    local picks = ins.actor_list[actorId].picks
    if exRate > 1 and picks then --多次的时候额外增加次数减1次的掉落
        for k, v in ipairs(picks) do
            table.insert(items, {type = v.type, id = v.id, count = v.count * (exRate - 1)})
        end
    end
    
    local count, pos = actoritem.getValueByItems(items, NumericType_Gold)
    local moneyExtra = math.ceil(count * conf.coefficient[rate]) --额外增加金币
    if moneyExtra > 0 then
        actoritem.addItem(actor, NumericType_Gold, moneyExtra, "devil extra money")
        ins:addPickItem(actorId, 0, NumericType_Gold, moneyExtra)
    end
    
    local isopen, dropindexs = subactivity12.checkIsStart()
    if isopen then
        for j = 1, #dropindexs do
            for _ = 1, exRate do
                local rewards = drop.dropGroup(conf.actRewards[dropindexs[j]])
                for i = 1, #rewards do
                    table.insert(items, {type = rewards[i].type, id = rewards[i].id, count = rewards[i].count})
                end
            end
        end
    end
    instancesystem.setInsRewards(ins, actor, items)
    
    ins:setExtraData1(actorId, rate)
    ins:setExtraData2(actorId, var.highExp)
    if exp + expExtra > var.highExp then
        var.highExp = exp + expExtra
    end
    var.inspiretimes = 0
    s2cDevilsquareScore(actor)
    if isLose then
        ins:lose()
    else
        ins:win()
    end
    local extra = string.format("exp=%s,expExtra=%s,highExp=%s", exp, expExtra, var.highExp)
    utils.logCounter(actor, "othersystem", rate, extra, "devil", "rate")
end

function getConfigId(actor)
    local id = 0
    local level = LActor.getLevel(actor)
    for k, v in ipairs(DevilfbConfig) do
        if level >= v.level and zhuansheng.checkZSLevel(actor, v.zslevel) then
            id = k
        else
            break
        end
    end
    return id
end

function setScoreTimer(actor)
    local var = getActorVar(actor)
    local now = System.getNowTime()
    if var.scoreTime > now then return end
    var.scoreTime = now + 1 --限制1秒后才发送下一次
    
    s2cDevilsquareScore(actor)
end

--每天刷新处理
local function onNewDay(actor, login)
    local var = getActorVar(actor)
    if not var then return end
    
    var.intimes = 0
    var.buyTimes = 0
    var.idx = 0
    if not login then
        s2cDevilsquareInfo(actor)
    end
end

local function onLogin(actor)
    s2cDevilsquareInfo(actor)
end
-------------------------------------------------------------------------------------------------------

--恶魔广场信息
function c2sDevilsquareInfo(actor, pack)
    s2cDevilsquareInfo(actor)
end

--恶魔广场信息回包
function s2cDevilsquareInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    local now = System.getNowTime()
    local second = math.max(0, var.nextTime - now) --倒计时秒数
    --匹配合适的副本
    local id = getConfigId(actor)
    local able = 0 --能否进入
    local rtimes = 0--replevy.GetReplevyTimes(actor, replevy.RTP.devil) --追回次数
    if second == 0 and id > 0 and var.intimes < (DevilCommonConfig[1].count + var.buyTimes + rtimes) then
        able = 1
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DevilsquareInfo)
    if pack == nil then return end
    LDataPack.writeByte(pack, able)
    LDataPack.writeInt(pack, second)
    LDataPack.writeShort(pack, var.intimes) --已用次数
    LDataPack.writeShort(pack, var.buyTimes) --已买次数
    LDataPack.writeInt(pack, math.max(id, 1)) --客户端最小要1
    LDataPack.writeChar(pack, rtimes)
    LDataPack.writeInt(pack, var.intotimes)
    LDataPack.flush(pack)
end

--恶魔广场战斗
function c2sDevilsquareFight(actor, pack)
    local var = getActorVar(actor)
    if not var then return end
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.devil) then return end
    local now = System.getNowTime()
    if var.nextTime > now then return end --CD时间
    
    local id = getConfigId(actor) --找出适合等级的副本
    if id == 0 then return end
    local conf = DevilfbConfig[id]
    if not utils.checkFuben(actor, conf.fbId) then return end
    
    local fightTimes = neigua.checkOpenNeigua(actor, FubenConfig[conf.fbId].group, DevilCommonConfig[1].count + var.buyTimes - var.intimes)
    if fightTimes <= 0 then return end
    if not actoritem.checkItem(actor, conf.items[1].id, conf.items[1].count * fightTimes) then return end
    
    actoritem.reduceItem(actor, conf.items[1].id, conf.items[1].count * fightTimes, "xuese fuben in")
    local hfuben = instancesystem.createFuBen(conf.fbId) --getDevilsquareFuben(id)
    if hfuben == 0 then return end
    
    var.downTime = now + DevilCommonConfig[1].secReady
    var.exitTime = now + DevilCommonConfig[1].secFight + DevilCommonConfig[1].secReady
    var.curDeId = id
    var.intimes = var.intimes + fightTimes
    var.score = 0
    var.hpAdd = 0
    var.attAdd = 0
    var.idx = var.idx + fightTimes
    var.intotimes = var.intotimes + fightTimes
    var.inspiretimes = 0
    
    actorevent.onEvent(actor, aeEnterDevil, fightTimes)
    
    local pos = DevilCommonConfig[1].pos[1]
    LActor.enterFuBen(actor, hfuben, 0, pos.x, pos.y)
    s2cDevilsquareScore(actor)
end

--恶魔广场倒计时
function s2cDevilsquareDao(actor)
    local var = getActorVar(actor)
    local now = System.getNowTime()
    local second = var.downTime - now
    local tp = 1
    if second <= 0 then
        second = var.exitTime - now
        tp = 2
    end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DevilsquareDao)
    if pack == nil then return end
    LDataPack.writeShort(pack, tp)
    LDataPack.writeShort(pack, second) --倒计时
    
    LDataPack.flush(pack)
end

--恶魔广场人数
-- function s2cDevilsquareNumber(actor, ins)
-- local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DevilsquareNum)
-- if pack == nil then return end
-- LDataPack.writeShort(pack, ins.actor_list_count) --入场人数
-- LDataPack.flush(pack)
-- end

--恶魔广场积分
function s2cDevilsquareScore(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DevilsquareScore)
    if pack == nil then return end
    LDataPack.writeInt(pack, var.score) --个人积分
    LDataPack.flush(pack)
end

--恶魔广场鼓舞
function c2sDevilsquareInspire(actor, pack)
    local tp = LDataPack.readShort(pack)
    local conf = DevilInspireConfig[tp]
    if not conf then return end
    local var = getActorVar(actor)
    
    local temp = {} --参与增加的属性
    for k, v in pairs(conf.attrs) do
        if v.type == Attribute.atHpPer and var.hpAdd < conf.hpMax then
            table.insert(temp, v)
        end
        if v.type == Attribute.atAtkPer and var.attAdd < conf.attMax then
            table.insert(temp, v)
        end
    end
    if #temp <= 0 then return false end --已加成到最大值
    
    --鼓舞消耗
    if not DevilfbConfig[var.curDeId] then return end
    local items = tp == 1 and DevilfbConfig[var.curDeId].goldSp or DevilfbConfig[var.curDeId].diamondSp
    if not actoritem.checkItems(actor, items) then
        return
    end
    actoritem.reduceItems(actor, items, "devils inspire in")
    
    local success = 1
    local pro = math.random(1, 10000)
    if pro > conf.pro then --概率失败
        success = 0
    end
    
    if success == 1 then
        --加成属性
        local v = temp[math.random(1, #temp)]
        if v.type == Attribute.atHpPer then
            var.hpAdd = var.hpAdd + v.value
        elseif v.type == Attribute.atAtkPer then
            var.attAdd = var.attAdd + v.value
        end
        var.inspiretimes = var.inspiretimes + 1
        updateAttr(actor)
    end
    
    s2cDevilsquareInspire(actor, success, tp)
end

--恶魔广场鼓舞信息
function s2cDevilsquareInspire(actor, success, tp)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DevilsquareInspire)
    if pack == nil then return end
    LDataPack.writeInt(pack, var.hpAdd)
    LDataPack.writeInt(pack, var.attAdd)
    LDataPack.writeByte(pack, success)
    LDataPack.writeChar(pack, tp)
    LDataPack.writeInt(pack, var.intotimes)
    LDataPack.writeByte(pack, var.inspiretimes)
    LDataPack.flush(pack)
end

--恶魔广场通知客户端清鼓舞
function s2cDevilsquareInspireClear(actor, intotimes)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DevilsquareInspire)
    if pack == nil then return end
    LDataPack.writeInt(pack, 0)
    LDataPack.writeInt(pack, 0)
    LDataPack.writeByte(pack, 0)
    LDataPack.writeChar(pack, 1)
    LDataPack.writeInt(pack, intotimes)
    LDataPack.writeByte(pack, 0)
    LDataPack.flush(pack)
end

function c2sDevilsquareBuy(actor, pack)
    local var = getActorVar(actor)
    local vip = LActor.getSVipLevel(actor)
    if var.buyTimes >= SVipConfig[vip].devilsbuy then
        return
    end
    
    --购买次数消耗
    local items = DevilCommonConfig[1].cost
    if not actoritem.checkItems(actor, items) then
        return
    end
    actoritem.reduceItems(actor, items, "devils buy in")
    
    var.buyTimes = var.buyTimes + 1
    s2cDevilsquareInfo(actor)
end

-------------------------------------------------------------------------------------------------------
local function delayStartFight(_, ins)
    ins:postponeStart()
end

--延迟一会后刷出boss，做预警
function DevilDeferEarly(ins)
    if ins.data.isEarly then return end --因为在delayStartFight刷出boss前这里又会被触发一次，所以要做限制
    ins.data.isEarly = true
    ins:postponeStop()
    ins:notifyBossWarn()
    LActor.postScriptEventLite(nil, 2 * 1000, delayStartFight, ins)
end

--杀死BOSS继续刷怪
function DevilstartCreate(ins)
    ins:postponeStart()
end

--出现BOSS停止刷怪
function DevilstopCreate(ins)
    ins:postponeStop()
    ins.data.isEarly = false --解除预警的限制
end
-------------------------------------------------------------------------------------------------------
local function init()
    actorevent.reg(aeNewDayArrive, onNewDay)
    if System.isCrossWarSrv() then return end
    actorevent.reg(aeUserLogin, onLogin)
    
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_DevilsquareInfo, c2sDevilsquareInfo)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_DevilsquareFight, c2sDevilsquareFight)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_DevilsquareInspire, c2sDevilsquareInspire)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_DevilsquareBuy, c2sDevilsquareBuy)
    
    --注册相关回调
    for _, conf in pairs(DevilfbConfig) do
        insevent.registerInstanceEnter(conf.fbId, onEnterFb)
        insevent.registerInstanceExit(conf.fbId, onExitFb)
        insevent.registerInstanceOffline(conf.fbId, onExitFbOffline)
        insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
        insevent.regCustomFunc(conf.fbId, DevilstopCreate, "DevilstopCreate")
        insevent.regCustomFunc(conf.fbId, DevilstartCreate, "DevilstartCreate")
        insevent.regCustomFunc(conf.fbId, DevilDeferEarly, "DevilDeferEarly")
        insevent.registerInstanceActorDie(conf.fbId, onActorDie)
    end
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.devisquareInfo = function (actor)
    c2sDevilsquareInfo(actor, false)
    return true
end

gmCmdHandlers.devisquareFight = function (actor)
    local var = getActorVar(actor)
    local id = getConfigId(actor)
    if id == 0 then return end
    actoritem.addItems(actor, DevilfbConfig[id].items, "devils fuben gm")
    var.intimes = 0
    var.nextTime = System.getNowTime()
    c2sDevilsquareFight(actor)
    return true
end

gmCmdHandlers.devisquareEnd = function (actor)
    local ins = instancesystem.getActorIns(actor)
    local var = getActorVar(actor)
    finishFuben(actor, ins, var.idx)
end

gmCmdHandlers.devisquareFlush = function (actor)
    local var = getActorVar(actor)
    var.nextTime = System.getNowTime()
    c2sDevilsquareInfo(actor, false)
end

