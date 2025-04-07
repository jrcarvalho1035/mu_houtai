-- @version1.0
-- @authorqianmeng
-- @date2017-1-16 18:29:00.
-- @system血色城堡

module("xuese", package.seeall)
require("scene.xuesefuben")
require("scene.xueseinspire")
require("scene.xuesecommon")

function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.xuesefuben then
        var.xuesefuben = {
            curDeId = 0, --当前挑战的血色id
            idx = 0,
            intimes = 0, --进入次数
            buyTimes = 0, --购买次数
            hpAdd = 0, --血量加成
            attAdd = 0, --攻击加成
            inDev = 0, --在副本内
            downTime = 0, --副本出怪的时间
            exitTime = 0, --副本结束时间
            taskState = 0, --血色任务状态
        }
    end
    if not var.xuesefuben.highExp then var.xuesefuben.highExp = 0 end
    if not var.xuesefuben.intotimes then var.xuesefuben.intotimes = 0 end --进入次数
    if not var.xuesefuben.inspiretimes then var.xuesefuben.inspiretimes = 0 end --鼓舞次数
    if not var.xuesefuben.isfirst then var.xuesefuben.isfirst = 0 end --第一次进入不扣次数，进入指定本
    return var.xuesefuben
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
    if var.downTime > now then
        LActor.postScriptEventLite(actor, (var.downTime - now) * 1000, startFight, ins) --延迟刷怪
    elseif (not ins.postponeOn) then
        ins:postponeStart()
    end
    
    --假若断线重连，判断要不要立刻结束
    if var.exitTime <= now then
        finishFuben(actor, ins, var.idx, true)
    else
        LActor.postScriptEventLite(actor, (var.exitTime - now) * 1000, finishFuben, ins, var.idx, true) --延迟结束
        updateAttr(actor)
        s2cXueseInfo(actor) --断线重连时自动进入，客户端要知道副本id
        s2cXueseDao(actor)
        s2cXueseTask(actor)
    end
    s2cXueseInspire(actor, 0, 1)
end

--退出副本处理
local function onExitFb(ins, actor)
    local var = getActorVar(actor)
    var.inDev = 0
    updateAttr(actor)
    s2cXueseInfo(actor)
    
    if var.isfirst == 0 and not ins.is_end then
        local idx = ins.refresh_monster_idx
        if ins.refresh_monster_idx == 0 then
            idx = 1
        end
        local totalexp = 0
        for i = idx, #XueseCommonConfig.waveexp do
            totalexp = totalexp + XueseCommonConfig.waveexp[i]
        end
        totalexp = totalexp + XueseCommonConfig.finallyexp
        LActor.addExp(actor, totalexp, "xuese finalyexp", false, true, 1)
        
        var.isfirst = 1
        ins:win()
    end
    local shenqivar = shenqisystem.getActorVar(actor)
    shenqivar.tmpchoose = 0
    actorevent.onEvent(actor, aeNotifyFacade, -1)
end

--杀怪处理, 增加积分（之后要处理收获奖励）
local function onMonsterDie(ins, mon, killer_hdl)
    local et = LActor.getEntity(killer_hdl)
    local killer_et = LActor.getActor(et)
    local var = getActorVar(killer_et)
    if not var then return end
    local conf = XuesefbConfig[var.curDeId]
    if not conf then
        print("error xuese dei config", var.curDeId)
        return
    end
    -- local monId = LActor.getId(mon)
    -- if monId == conf.boss then
    
    -- --sendTip(killer_et, 4)
    -- end
    if LActor.isBoss(mon) then
        sendTip(killer_et, 3)
    end
end

--引导副本每波怪物增加额外经验
function onMonsterAllDie(ins)
    local actors = Fuben.getAllActor(ins.handle)
    local var = getActorVar(actors[1])
    if var.isfirst == 1 then return end
    if ins.refresh_monster_idx > 0 and ins.refresh_monster_idx <= #XueseCommonConfig.waveexp then
        LActor.addExp(actors[1], XueseCommonConfig.waveexp[ins.refresh_monster_idx], "xuese wave exp", false, true, 1)
        ins:addPickExp(LActor.getActorId(actors[1]), XueseCommonConfig.waveexp[ins.refresh_monster_idx])
    end
end

function onMonsterCreate(ins, mon)
    local monId = LActor.getId(mon)
    local actors = Fuben.getAllActor(ins.handle)
    if not actors then return end
    local var = getActorVar(actors[1])
    if not var then return end
    local conf = XuesefbConfig[var.curDeId]
    if not conf then return end
    if monId == conf.boss then
        sendTip(actors[1], 5)
    end
    if LActor.isBoss(mon) then
        sendTip(actors[1], 2)
    end
end

--玩家死亡，发送结算协议并退出副本
function onActorDie(ins, actor, killHdl)
    local var = getActorVar(actor)
    finishFuben(actor, ins, var.idx, true)
end

--战斗开始
function startFight(actor, ins)
    local var = getActorVar(actor)
    if not var then return end
    if ins.is_end then return end
    sendTip(actor, 1)
    ins:postponeStart()
    s2cXueseDao(actor)
end

local function getRate(score, conf)
    local rate = 1
    for k, v in ipairs(conf.rate) do
        if score <= v then
            rate = k
        else
            break
        end
    end
    return rate
end

--副本结束
function finishFuben(actor, ins, idx, isLose)
    local var = getActorVar(actor)
    if not var then return end
    if var.idx ~= idx or var.inDev == 0 then return end
    local actorId = LActor.getActorId(actor)
    
    local conf = XuesefbConfig[var.curDeId]
    local rate = getRate(XueseCommonConfig.secFight - (var.exitTime - System.getNowTime()), conf)
    local exRate = ins.data.exRate or 1
    
    local exp = (ins.actor_list[actorId].exp or 0)
    --经验
    local expExtra = 0
    if var.isfirst == 0 then
        LActor.addExp(actor, XueseCommonConfig.finallyexp, "xuese juqing finalyexp", false, true, 1)
        ins:addPickExp(actorId, XueseCommonConfig.finallyexp)
    else
        expExtra = math.ceil(exp * conf.coefficient[rate]) * exRate + exp * (exRate - 1) --额外增加经验
        if expExtra > 0 then
            LActor.addExp(actor, expExtra, "xuese extra exp", false, true, 1)
            ins:addPickExp(actorId, expExtra)
        end
    end
    
    --金币
    local items = utils.table_clone(conf.rewards)
    for k, v in ipairs(items) do
        v.count = v.count * exRate
    end
    
    local picks = ins.actor_list[actorId].picks
    if exRate > 1 and picks then
        for i, v in ipairs(picks) do
            table.insert(items, {type = v.type, id = v.id, count = v.count * (exRate - 1)})
        end
    end
    
    local count, pos = actoritem.getValueByItems(items, NumericType_Gold)
    if pos then
        local moneyExtra = math.ceil(count * conf.coefficient[rate]) --额外增加金币
        items[pos].count = count + moneyExtra
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
    if var.isfirst == 0 then
        var.isfirst = 1
    end
    setState(actor, 0)
    if isLose then
        ins:lose()
    else
        ins:win()
    end
    utils.logCounter(actor, "othersystem", rate, "", "xuese", "rate")
end

--任务状态设置
function setState(actor, tp)
    local var = getActorVar(actor)
    if not var then return end
    var.taskState = tp
end

function getConfigId(actor)
    local id = 0
    local level = LActor.getLevel(actor)
    for k, v in ipairs(XuesefbConfig) do
        if level >= v.level and zhuansheng.checkZSLevel(actor, v.zslevel) then
            id = k
        else
            break
        end
    end
    return id
end

--每天刷新处理
local function onNewDay(actor, login)
    local var = getActorVar(actor)
    if not var then return end
    
    var.intimes = 0
    var.buyTimes = 0
    if not login then
        s2cXueseInfo(actor)
    end
end

local function onLogin(actor)
    s2cXueseInfo(actor)
end

-------------------------------------------------------------------------------------------------------

function sendTip(actor, id)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_XueseTips)
    LDataPack.writeChar(pack, id)
    LDataPack.flush(pack)
end

--血色城堡信息
function c2sXueseInfo(actor, pack)
    s2cXueseInfo(actor)
end

--血色城堡信息回包
function s2cXueseInfo(actor)
    --local data = getXueseData()
    local var = getActorVar(actor)
    if not var then return end
    local now = System.getNowTime()
    local second = 0
    --匹配合适的副本
    local id = getConfigId(actor)
    local able = 0 --能否进入
    local rtimes = 0--replevy.GetReplevyTimes(actor, replevy.RTP.xuese) --追回次数
    if second == 0 and id > 0 and var.intimes < XueseCommonConfig.count + var.buyTimes then
        able = 1
    end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_XueseInfo)
    if pack == nil then return end
    LDataPack.writeByte(pack, able)
    LDataPack.writeInt(pack, second)
    LDataPack.writeShort(pack, var.intimes) --已用次数
    LDataPack.writeShort(pack, var.buyTimes) --已买次数
    LDataPack.writeInt(pack, math.max(id, 1))
    LDataPack.writeChar(pack, rtimes)
    LDataPack.writeInt(pack, var.intotimes)
    LDataPack.flush(pack)
end

function checkHaveFuben(id)
    for k, v in pairs(XuesefbConfig) do
        if v.fbId == id then
            return true
        end
    end
    return false
end

--血色城堡战斗
function c2sXueseFight(actor, pack)
    local var = getActorVar(actor)
    if not var then return end
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.xuese) then return end
    
    local id = getConfigId(actor) --找出适合等级的副本
    if id == 0 then return end
    local conf = XuesefbConfig[id]
    if not utils.checkFuben(actor, conf.fbId) then return end
    
    local fightTimes = 1
    if var.isfirst == 0 then
        id = XueseCommonConfig.juqingid
    else
        fightTimes = neigua.checkOpenNeigua(actor, FubenConfig[conf.fbId].group, XueseCommonConfig.count + var.buyTimes - var.intimes)
    end
    if fightTimes <= 0 then return end
    if not actoritem.checkItem(actor, conf.items[1].id, conf.items[1].count * fightTimes) then return end
    
    actoritem.reduceItem(actor, conf.items[1].id, conf.items[1].count * fightTimes, "xuese fuben in")
    setState(actor, 0)
    local hfuben = instancesystem.createFuBen(conf.fbId) --getXueseFuben(id)
    if hfuben == 0 then return end
    
    local now = System.getNowTime()
    var.downTime = now + XueseCommonConfig.secReady
    var.exitTime = now + XueseCommonConfig.secFight + XueseCommonConfig.secReady
    var.curDeId = id
    if var.isfirst ~= 0 then
        var.intimes = var.intimes + fightTimes
        actorevent.onEvent(actor, aeEnterXuese, fightTimes)
    end
    var.hpAdd = 0
    var.attAdd = 0
    var.idx = var.idx + 1
    var.intotimes = var.intotimes + fightTimes
    var.inspiretimes = 0
    
    local x, y = utils.getSceneEnterCoor(conf.fbId)
    LActor.enterFuBen(actor, hfuben, 0, x, y)
end

--血色城堡倒计时
function s2cXueseDao(actor)
    local var = getActorVar(actor)
    local now = System.getNowTime()
    local second = var.downTime - now
    local tp = 1
    if second <= 0 then
        second = var.exitTime - now
        tp = 2
    end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_XueseDao)
    if pack == nil then return end
    LDataPack.writeShort(pack, tp)
    LDataPack.writeShort(pack, second) --倒计时
    LDataPack.flush(pack)
end

--血色城堡鼓舞
function c2sXueseInspire(actor, pack)
    local tp = LDataPack.readShort(pack)
    local conf = XueseInspireConfig[tp]
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
    if not (tp == 1 and var.intotimes <= 1) then --在第一次进入时金币鼓舞不消耗
        local items = tp == 1 and XuesefbConfig[var.curDeId].goldSp or XuesefbConfig[var.curDeId].diamondSp
        if not actoritem.checkItems(actor, items) then
            return
        end
        actoritem.reduceItems(actor, items, "xuese inspire in")
    end
    
    local success = 1
    if math.random(1, 10000) > conf.pro then --概率失败
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
    
    s2cXueseInspire(actor, success, tp)
end

--血色城堡鼓舞信息
function s2cXueseInspire(actor, success, tp)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_XueseInspire)
    if pack == nil then return end
    LDataPack.writeInt(pack, var.hpAdd)
    LDataPack.writeInt(pack, var.attAdd)
    LDataPack.writeByte(pack, success)
    LDataPack.writeChar(pack, tp)
    LDataPack.writeInt(pack, var.intotimes)
    LDataPack.writeByte(pack, var.inspiretimes)
    LDataPack.flush(pack)
end

--血色城堡通知客户端清鼓舞信息
function s2cXueseInspireClear(actor, intotimes)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_XueseInspire)
    if pack == nil then return end
    LDataPack.writeInt(pack, 0)
    LDataPack.writeInt(pack, 0)
    LDataPack.writeByte(pack, 0)
    LDataPack.writeChar(pack, 1)
    LDataPack.writeInt(pack, intotimes)
    LDataPack.writeByte(pack, 0)
    LDataPack.flush(pack)
end

function c2sXueseBuy(actor, pack)
    local var = getActorVar(actor)
    local vip = LActor.getSVipLevel(actor)
    if var.buyTimes >= SVipConfig[vip].xuesebuy then
        return
    end
    
    --购买次数消耗
    local items = XueseCommonConfig.cost
    if not actoritem.checkItems(actor, items) then
        return
    end
    actoritem.reduceItems(actor, items, "xuese buy in")
    
    var.buyTimes = var.buyTimes + 1
    s2cXueseInfo(actor)
end

--提示血色任务状态
function s2cXueseTask(actor)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_XueseTask)
    if pack == nil then return end
    LDataPack.writeInt(pack, var.taskState or 0)
    LDataPack.flush(pack)
end

--提交血色任务，副本完结
function c2sXueseSubmit(actor, packet)
    local var = getActorVar(actor)
    if not var then return end
    print("var.taskState =", var.taskState)
    if (var.taskState or 0) ~= 1 then
        return
    end
    local fuben = LActor.getFubenPrt(actor)
    local hf = Fuben.getFubenHandle(fuben)
    local ins = instancesystem.getInsByHdl(hf)
    finishFuben(actor, ins, var.idx)
end

----------------------------------------副本相关----------------------------------------------
--城门可以打了
local function SetGateSuffer(ins)
    ins:postponeStop()--停止刷怪
end

--城门被破
local function OnGateBroken(ins)
    ins:postponeStart()--重新刷怪
end

function getDyanmicVar(actor)
    local var = LActor.getGlobalDyanmicVar(actor)
    if not var.xuese then
        var.xuese = {}
    end
    return var.xuese
end

--杀水晶灵柩后任务完成
local function OnComplete(ins)
    --s2cXueseTask(actor)
end

function onPickItem(actor)
    setState(actor, 1)
    s2cXueseTask(actor)
    local var = shenqisystem.getActorVar(actor)
    var.tmpchoose = XueseCommonConfig.shenqiid
    actorevent.onEvent(actor, aeNotifyFacade, -1)
end
----------------------------------------------------------------------------------------------|
local function init()
    actorevent.reg(aeNewDayArrive, onNewDay)
    if System.isCrossWarSrv() then return end
    actorevent.reg(aeUserLogin, onLogin)
    
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_XueseInfo, c2sXueseInfo)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_XueseFight, c2sXueseFight)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_XueseInspire, c2sXueseInspire)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_XueseBuy, c2sXueseBuy)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_XueseSubmit, c2sXueseSubmit)
    
    --注册相关回调
    for _, conf in pairs(XuesefbConfig) do
        insevent.registerInstanceEnter(conf.fbId, onEnterFb)
        insevent.registerInstanceExit(conf.fbId, onExitFb)
        insevent.registerInstanceOffline(conf.fbId, onExitFb)
        insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
        insevent.regCustomFunc(conf.fbId, SetGateSuffer, "SetGateSuffer")
        insevent.regCustomFunc(conf.fbId, OnGateBroken, "OnGateBroken")
        insevent.regCustomFunc(conf.fbId, OnComplete, "OnComplete")
        insevent.registerInstanceActorDie(conf.fbId, onActorDie)
        insevent.registerInstanceMonsterAllDie(conf.fbId, onMonsterAllDie)
        insevent.registerInstanceMonsterCreate(conf.fbId, onMonsterCreate)
    end
end
table.insert(InitFnTable, init)

--local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.xueseInfo = function (actor)
    local var = getActorVar(actor)
    var.isfirst = 0
    c2sXueseInfo(actor, false)
    return true
end

gmCmdHandlers.xueseFight = function (actor)
    local var = getActorVar(actor)
    local id = getConfigId(actor)
    if id == 0 then return end
    actoritem.addItems(actor, XuesefbConfig[id].items, "xuese fuben gm")
    var.intimes = 0
    c2sXueseFight(actor)
    return true
end

gmCmdHandlers.xueseEnd = function (actor)
    local ins = instancesystem.getActorIns(actor)
    local var = getActorVar(actor)
    finishFuben(actor, ins, var.idx)
end

gmCmdHandlers.xueseFlush = function (actor)
    local var = getActorVar(actor)
    var.intotimes = 0
    var.inspiretimes = 0
    
    c2sXueseInfo(actor, false)
end

