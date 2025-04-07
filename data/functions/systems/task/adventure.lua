-- 奇遇
module('adventure', package.seeall)
--[[
{
    -- 奇遇点，货币
    open = 0, -- 是否开启标记
    value = 0, -- 运力值
    valtime = 0, -- 运力值更新时间
    evtime = 0, -- 事件触发时间
    serial = 0, -- 下一次触发事件序列号，从1开始
    event = {
        [1] = {
            id = 1
            type = 1
            award = 1 -- 可以领取奖励
            rewardLen = 1, -- 奖励长度
            reward = {
                {type=1,id=1,count=1},
            }
        }
        [2] = {
            type = 2
            task = {
                [1] = {
                    id = 0 -- 任务id
                    state = 0 -- 任务状态：0进行中，1可领奖，2已领奖
                }
            }
        }
        [3] = {
            type = 6
            et = 0 可以领取奖励的时间点
        }
        [4] = {
            type = 3/4
            kBuff = 0 -- 多倍复仇
        }
    }
    remind = { -- 兑换提醒
        [id] = 1
    }
}
]]
local VALUE_MAX = 20 -- 运力值上限
local EVENT_MAX = 4 -- 事件上限
local EVENT_DELTA = 600 -- 事件触发间隔
local EVENT_SAME_MAX = 2 -- 同类型上限
local TASK_MAX = 5 -- 任务上限

local EVENT_1 = 1 -- 小赌怡情/石头剪刀布
local EVENT_2 = 2 -- 仙女的考验，5个任务
local EVENT_3 = 3 -- 洞府遗迹，2分钟内清怪，直接结算获取奖励
local EVENT_4 = 4 -- 突袭·血魔，单人BOSS，直接结算获取奖励
EVENT_5 = 5 -- 邀战·散仙，竞技场，直接结算获取奖励
local EVENT_6 = 6 -- 封印的乾坤袋，倒计时2分钟
local openCustom = 0
local taskTotalRate = 0 -- 仙女考验所有任务的权重之和
local taskRandomList = {} -- 仙女事件随机任务
local eventTotalRate = 0 -- 所有事件的权重之和
local event_2_id = 1 -- 仙女考验在配置表中的id
local eventStatusType = {
    esWaiting = 0, -- 未开始
    esDoing = 1, -- 进行中
    esCanAward = 2 -- 已完成
}

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if var.adventureData == nil then
        var.adventureData = {}
    end
    return var.adventureData
end

local function clearActorVar(actor)
    local var = LActor.getStaticVar(actor)
    var.adventureData = nil
end

local function getSerial(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    return var.serial or 1
end

local function setSerial(actor, serial, var)
    if not var then
        var = getActorVar(actor)
    end
    var.serial = serial
end

local function isOpen(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    return var.open ~= nil
end

local function setOpen(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    var.open = 1
end

local function getEventList(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    
    local list = {}
    if var.event then
        for i = 1, EVENT_MAX do
            local ev = var.event[i]
            if ev then
                local t = {}
                t.id = ev.id
                local evConf = AdventureEventConfig[ev.id]
                local ev_type = ev.type
                t.type = ev_type
                if ev_type == EVENT_1 then
                    t.award = ev.award
                    t.win = ev.win
                    t.rewardLen = ev.rewardLen or 0
                    t.reward = {}
                    for i = 1, t.rewardLen do
                        local r = ev.reward[i]
                        local tb = {
                            type = r.type,
                            id = r.id,
                            count = r.count
                        }
                        t.reward[i] = tb
                    end
                elseif ev_type == EVENT_2 then
                    t.task = {}
                    t.step = ev.step
                    t.award = ev.award
                    t.state = ev.state
                    for i = 1, TASK_MAX do
                        local task = ev.task[i]
                        local ntask = {id = task.id, state = task.state, value = task.value}
                        ntask.reward = {}
                        if task.rewardLen and task.rewardLen > 0 then
                            for j = 1, task.rewardLen do
                                local r = task.reward[j]
                                table.insert(ntask.reward, {type = r.type, id = r.id, count = r.count})
                            end
                        end
                        table.insert(t.task, ntask)
                    end
                elseif ev_type == EVENT_3 or ev_type == EVENT_4 then
                    t.award = ev.award
                    t.kBuff = ev.kBuff
                elseif ev_type == EVENT_5 then
                    t.award = ev.award
                elseif ev_type == EVENT_6 then
                    t.et = ev.et
                    t.award = ev.award
                    t.rewardLen = ev.rewardLen or 0
                    t.reward = {}
                    for i = 1, t.rewardLen do
                        local r = ev.reward[i]
                        local tb = {
                            type = r.type,
                            id = r.id,
                            count = r.count
                        }
                        t.reward[i] = tb
                    end
                end
                table.insert(list, t)
            else
                break
            end
        end
    end
    
    return list
end

local function getEvent2List(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    
    local list = {}
    if var.event then
        for i = 1, EVENT_MAX do
            local ev = var.event[i]
            if ev and ev.type == EVENT_2 and ev.state == eventStatusType.esDoing then
                for j = 1, TASK_MAX do
                    if ev.task[j].state == taskcommon.statusType.emDoing then
                        list[i] = ev.task[j].id
                        break
                    end
                end
            end
        end
    end
    return list
end

local function setEventList(actor, list, var)
    if not var then
        var = getActorVar(actor)
    end
    
    var.event = {}
    
    for k, t in ipairs(list) do
        var.event[k] = {}
        local ev = var.event[k]
        ev.id = t.id
        ev.type = t.type
        local ev_type = t.type
        if ev_type == EVENT_1 then
            ev.award = t.award
            ev.rewardLen = t.rewardLen
            ev.reward = {}
            for i = 1, t.rewardLen do
                ev.reward[i] = {}
                local tb = t.reward[i]
                ev.reward[i].type = tb.type
                ev.reward[i].id = tb.id
                ev.reward[i].count = tb.count
            end
        elseif ev_type == EVENT_2 then
            ev.task = {}
            ev.step = t.step
            ev.award = t.award
            ev.state = t.state
            for i = 1, TASK_MAX do
                ev.task[i] = {}
                local task = t.task[i]
                ev.task[i].id = task.id
                ev.task[i].state = task.state
                ev.task[i].value = task.value
                if task.reward then
                    ev.task[i].rewardLen = #task.reward
                    ev.task[i].reward = {}
                    local tr = ev.task[i].reward
                    for j = 1, ev.task[i].rewardLen do
                        tr[j] = {}
                        tr[j].type = task.reward[j].type
                        tr[j].id = task.reward[j].id
                        tr[j].count = task.reward[j].count
                    end
                else
                    ev.task[i].rewardLen = 0
                end
            end
        elseif ev_type == EVENT_3 or ev_type == EVENT_4 then
            ev.award = t.award
            ev.kBuff = t.kBuff
        elseif ev_type == EVENT_5 then
            ev.award = t.award
        elseif ev_type == EVENT_6 then
            ev.et = t.et
            ev.award = t.award
            ev.rewardLen = t.rewardLen
            ev.reward = {}
            for i = 1, t.rewardLen do
                ev.reward[i] = {}
                local tb = t.reward[i]
                ev.reward[i].type = tb.type
                ev.reward[i].id = tb.id
                ev.reward[i].count = tb.count
            end
        end
    end
end

local function getEvent(actor, idx, var)
    if not var then
        var = getActorVar(actor)
    end
    
    if not var.event then
        var.event = {}
    end
    
    local ev = var.event[idx]
    if ev == nil then
        var.event[idx] = {}
        ev = var.event[idx]
    end
    return ev
end

local function getValue(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    return var.value or 0
end

function addValue(actor, val, var)
    if not var then
        var = getActorVar(actor)
    end
    local old = var.value or 0
    local new = old + val
    if new < 0 then
        new = 0
    end
    if VALUE_MAX < new then
        new = VALUE_MAX
    end
    var.value = new
    utils.logCounter(actor, "adventure value", val, new, old)
end

local function setRemindData(actor, id, var)
    if not var then
        var = getActorVar(actor)
    end
    
    if not var.remind then
        var.remind = {}
    end
    
    if var.remind[id] then
        var.remind[id] = nil
    else
        var.remind[id] = 1
    end
end

local function sendRemindData(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    
    local remind = var.remind or {}
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sAdventure_UpRemind)
    if pack then
        LDataPack.writeByte(pack, #AdventureExchangeConfig)
        for id in ipairs(AdventureExchangeConfig) do
            LDataPack.writeByte(pack, id)
            LDataPack.writeByte(pack, remind[id] or 0)
        end
        LDataPack.flush(pack)
    end
end

local function sendData(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    
    local list = getEventList(actor, var)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sAdventure_Data)
    if pack then
        LDataPack.writeInt(pack, var.value or 0)
        LDataPack.writeByte(pack, #list)
        for k, t in ipairs(list) do
            local ev_type = t.type
            LDataPack.writeByte(pack, k)
            LDataPack.writeByte(pack, t.id)
            if ev_type == EVENT_1 then
                LDataPack.writeByte(pack, t.award or 0)
                local len = t.rewardLen or 0
                LDataPack.writeByte(pack, len)
                for i = 1, len do
                    local r = t.reward[i]
                    LDataPack.writeInt(pack, r.type)
                    LDataPack.writeInt(pack, r.id)
                    LDataPack.writeInt(pack, r.count)
                end
            elseif ev_type == EVENT_2 then
                LDataPack.writeByte(pack, t.state or eventStatusType.esWaiting)
                LDataPack.writeByte(pack, TASK_MAX)
                local ctask
                for i = 1, TASK_MAX do
                    local task = t.task[i]
                    if not ctask and task.state ~= 2 then
                        ctask = task
                    end
                    LDataPack.writeInt(pack, task.id)
                    LDataPack.writeByte(pack, task.state or 0)
                    LDataPack.writeShort(pack, task.value or 0)
                end
                if not ctask.reward then
                    LDataPack.writeByte(pack, 0)
                else
                    LDataPack.writeByte(pack, #ctask.reward)
                    for _, reward in ipairs(ctask.reward) do
                        LDataPack.writeInt(pack, reward.type)
                        LDataPack.writeInt(pack, reward.id)
                        LDataPack.writeInt(pack, reward.count)
                    end
                end
            elseif ev_type == EVENT_3 or ev_type == EVENT_4 then
                LDataPack.writeByte(pack, t.award or 0)
                local kBuff = t.kBuff or 1
                if 0 < kBuff then
                    kBuff = kBuff - 1 -- 发送0/1/2/3
                end
                LDataPack.writeInt(pack, kBuff)
            elseif ev_type == EVENT_5 then
                LDataPack.writeByte(pack, t.award or 0)
                local n = touxiansystem.getTouxianStage(actor)
                if n == 0 then -- 发送客户端默认1
                    LDataPack.writeByte(pack, 1)
                else
                    LDataPack.writeByte(pack, n)
                end
            elseif ev_type == EVENT_6 then
                LDataPack.writeInt(pack, t.et or 0)
                LDataPack.writeByte(pack, t.award or 0)
                local len = t.rewardLen or 0
                LDataPack.writeByte(pack, len)
                for i = 1, len do
                    local r = t.reward[i]
                    LDataPack.writeInt(pack, r.type)
                    LDataPack.writeInt(pack, r.id)
                    LDataPack.writeInt(pack, r.count)
                end
            end
        end
        LDataPack.flush(pack)
    end
end

local function removeEvent(actor, list, idx, ev_type, var)
    if not var then
        var = getActorVar(actor)
    end
    
    local ev = list[idx]
    if ev and ev.type == ev_type then
        table.remove(list, idx)
        setEventList(actor, list, var)
    end
end

--接任务,taskId是任务id
local function onInitTask(actor, task)
    local idx = task.id
    local config = AdventureTaskConfig[idx]
    if not config then
        return
    end
    task.state = taskcommon.statusType.emDoing
    task.value = 0
    local taskConf = AdventureTaskConfig[task.id]
    local reward = drop.dropGroup(taskConf.dropId)
    if not reward then
        task.reward = {}
        task.rewardLen = 0
    else
        task.rewardLen = #reward
        task.reward = {}
        local tr = task.reward
        for i, r in ipairs(reward) do
            tr[i] = {}
            tr[i].type = r.type
            tr[i].id = r.id
            tr[i].count = r.count
        end
    end
    
    local tp = config.type
    local taskHandleType = taskcommon.getHandleType(tp)
    if taskHandleType == taskcommon.eCoverType then
        local record = taskevent.getRecord(actor)
        local value = 0
        if taskevent.needParam(tp) then
            if record[tp] == nil then
                record[tp] = {}
            end
            value = 0
            for k, v in pairs(config.param) do
                if record[tp][v] then
                    value = record[tp][v]
                    break
                end
            end
        else
            value = record[tp] or taskevent.initRecord(tp, actor)
        end
        task.value = value
        --对获取历史数据的任务,这里做简单任务进度检测
        if task.value >= config.target then
            if tp == taskcommon.taskType.emZhuanshengLevel then
                task.value = 1
            end
            task.state = taskcommon.statusType.emCanAward
        else
            if tp == taskcommon.taskType.emZhuanshengLevel then
                task.value = 0
            end
        end
    end
end

-- 刷新任务
local function rsfTask(actor, ev)
    local lv = LActor.getLevel(actor)
    ev.task = {}
    ev.step = 1
    local AdventureTaskConfig = AdventureTaskConfig
    local len = #AdventureTaskConfig
    local idList = {}
    local n = 0
    local taskRndConf
    for _, conf in ipairs(taskRandomList) do
        if lv <= conf.lv2 then
            taskRndConf = conf
            break
        end
    end
    if not taskRndConf or #taskRndConf.list < 5 then
        print('rsfTask invalid task config for lv=' .. lv)
        return
    end
    
    for i = 1, 100 do
        -- local id = System.getRandomNumber(len) + 1
        local rate = System.getRandomNumber(taskRndConf.totalRate) + 1
        for _, taskid in ipairs(taskRndConf.list) do
            local taskConf = AdventureTaskConfig[taskid]
            rate = rate - taskConf.rate
            if rate <= 0 then
                if not idList[taskConf.id] then
                    idList[taskConf.id] = true
                    n = n + 1
                    ev.task[n] = {}
                    ev.task[n].id = taskConf.id
                end
                break
            end
        end
        -- if not idList[id] then
        --     idList[id] = true
        --     n = n + 1
        --     ev.task[n] = {}
        --     ev.task[n].id = id
        -- end
        
        if TASK_MAX <= n then
            -- init task
            onInitTask(actor, ev.task[1])
            return
        end
    end
    
    if n < TASK_MAX then
        for id in pairs(taskRndConf.list) do
            if not idList[id] then
                idList[id] = true
                n = n + 1
                ev.task[n] = {}
                ev.task[n].id = id
            end
            
            if TASK_MAX <= n then
                -- init task
                onInitTask(actor, ev.task[1])
                return
            end
        end
    end
end

local function rsfNotify(actor, idx, new_id)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sAdventure_Notify)
    if pack then
        LDataPack.writeByte(pack, idx)
        LDataPack.writeByte(pack, new_id)
        LDataPack.flush(pack)
    end
end

local function setEvRewardList(ev, rewardList)
    ev.rewardLen = #rewardList
    ev.reward = {}
    for i, t in ipairs(rewardList) do
        ev.reward[i] = {}
        local r = ev.reward[i]
        for k, v in pairs(t) do
            r[k] = v
        end
    end
end

-- 刷新事件
local function rsfEvent(actor, list, all, var)
    if not var then
        var = getActorVar(actor)
    end
    
    if not list then
        list = getEventList(actor, var)
    end
    
    if EVENT_MAX <= #list then
        return
    end
    
    local idList = {}
    local typeList = {}
    for _, t in ipairs(list) do
        local ev_type = t.type
        local old = typeList[ev_type] or 0
        typeList[ev_type] = old + 1
        idList[t.id] = true
    end
    
    local AdventureEventConfig = AdventureEventConfig
    local newList = {}
    local len = #AdventureEventConfig
    local serial = getSerial(actor, var)
    local rndEvent = true
    
    local loop = 1
    if all then
        loop = 100
    end
    
    for it = 1, loop do
        if 0 == math.fmod(serial, 6) then
            -- 逢6出一次仙女
            rndEvent = false
            local evConf = AdventureEventConfig[event_2_id]
            local n = typeList[evConf.type] or 0
            if n < EVENT_SAME_MAX then
                typeList[evConf.type] = n + 1
                table.insert(newList, evConf.id)
                idList[evConf.id] = true
                serial = serial + 1
            else
                rndEvent = true
            end
        end
        if rndEvent then
            -- local id = System.getRandomNumber(len) + 1
            local r = System.getRandomNumber(eventTotalRate) + 1
            for i, evConf in ipairs(AdventureEventConfig) do
                r = r - evConf.rate
                if r <= 0 then
                    local id = evConf.id
                    if not idList[id] then
                        idList[id] = true
                        local n = typeList[evConf.type] or 0
                        if n < EVENT_SAME_MAX then
                            typeList[evConf.type] = n + 1
                            table.insert(newList, id)
                            serial = serial + 1
                            break
                        end
                    end
                end
            end
        end
        
        if EVENT_MAX <= #list + #newList then
            break
        end
    end
    -- 更新序列号
    setSerial(actor, serial, var)
    
    local idx = #list
    local new_id = 0
    for _, id in ipairs(newList) do
        new_id = id
        idx = idx + 1
        local ev = getEvent(actor, idx, var)
        local evConf = AdventureEventConfig[id]
        
        local ev_type = evConf.type
        ev.id = id
        ev.type = ev_type
        
        if ev_type == EVENT_1 then -- 提前随机奖励
            local dropId = getEvent1DropId(actor)
            local rewardList = drop.dropGroup(dropId)
            setEvRewardList(ev, rewardList)
        end
        
        if ev_type == EVENT_2 then
            ev.state = eventStatusType.esWaiting
            rsfTask(actor, ev)
        end
        
        if ev_type == EVENT_6 then -- 提前随机奖励
            local dropId = getEvent6DropId(actor)
            local rewardList = drop.dropGroup(dropId)
            setEvRewardList(ev, rewardList)
        end
        
        if evConf.buffRate and 0 < #evConf.buffRate then
            local k = utils.getRound10000(evConf.buffRate)
            ev.kBuff = k
        end
    end
    
    rsfNotify(actor, idx, new_id)
end

local function onEndEvent(actor, idx, win, skipPoint)
    local var = getActorVar(actor)
    local ev = getEvent(actor, idx, var)
    local evConf = AdventureEventConfig[ev.id]
    local ev_type = evConf.type
    if ev_type == EVENT_4 or ev_type == EVENT_5 then
        addValue(actor, -evConf.need, var)
    end
    if not skipPoint then
        -- 奇遇点奖励
        local point = 0
        if win then
            point = evConf.winPoint
        else
            point = evConf.losePoint
        end
        actoritem.addItem(actor, NumericType_Adventure, point, 'adventure')
    end
end

local function onEventTimerImpl(actor)
    local var = getActorVar(actor)
    local list = getEventList(actor, var)
    if #list < EVENT_MAX then
        rsfEvent(actor, list, false, var)
        var.evtime = System.getNowTime()
        sendData(actor, var)
    end
end

local function onEventTimer(actor)
    onEventTimerImpl(actor)
end

-- 设置事件定时器
local function eventTimer(actor, dt)
    if dt == EVENT_DELTA then
        LActor.postScriptEventEx(actor, dt * 1000, onEventTimer, dt * 1000, -1)
    else
        LActor.postScriptEventLite(actor, dt * 1000, onEventTimer)
        LActor.postScriptEventEx(actor, (dt + EVENT_DELTA) * 1000, onEventTimer, EVENT_DELTA * 1000, -1)
    end
end

local function onLogin(actor, isFirst, offTime, logoutTime, isCross)
    local var = getActorVar(actor)
    if isOpen(actor, var) then
        local nowTime = System.getNowTime()
        
        local list = getEventList(actor, var)
        if #list < EVENT_MAX then
            local evtime = var.evtime or 0
            local dt = nowTime - evtime
            if 0 < dt then
                local n = math.floor(dt / EVENT_DELTA)
                if 0 < n then
                    if EVENT_MAX <= #list + n then
                        rsfEvent(actor, list, true, var)
                    else
                        n = EVENT_MAX - #list
                        for i = 1, n do
                            rsfEvent(actor, list, false, var)
                        end
                    end
                end
                local r = dt % EVENT_DELTA
                var.evtime = nowTime - r
                eventTimer(actor, EVENT_DELTA - r)
            else
                eventTimer(actor, EVENT_DELTA)
            end
        else
            eventTimer(actor, EVENT_DELTA)
        end
        
        for k, t in ipairs(list) do
            if t.type == EVENT_6 then
                if t.et then
                    if t.et <= nowTime then
                        local ev = getEvent(actor, k, var)
                        ev.award = 1
                    else
                        local dt = t.et - nowTime
                        etTimer(actor, dt, t.et)
                    end
                end
            end
        end
    else
        tryOpen(actor, guajifuben.getCustom(actor), true) -- 旧号开启
    end
    
    sendData(actor, var)
    sendRemindData(actor, var)
end

local function onNewDayHour(actor, isLogin)
    local var = getActorVar(actor)
    addValue(actor, VALUE_MAX)
    -- var.value = VALUE_MAX
    var.valtime = System.getNowTime()
    if not isLogin then
        sendData(actor, var)
    end
end

function getEvent1DropId(actor)
    local lv = LActor.getLevel(actor)
    local conf
    for _, t in pairs(AdventureEvent1Config) do
        if t.lv <= lv and lv <= t.lv2 then
            conf = t
            break
        end
    end
    
    if not conf then
        conf = AdventureEvent1Config[1]
    end
    
    if not conf then
        return 0
    end
    
    return conf.dropId or 0
end

local function getEvent6Conf(actor)
    local lv = LActor.getLevel(actor)
    local conf
    for _, t in pairs(AdventureEvent6Config) do
        if t.lv <= lv and lv <= t.lv2 then
            return t
        end
    end
end

function getEvent6DropId(actor)
    local lv = LActor.getLevel(actor)
    local conf
    for _, t in pairs(AdventureEvent6Config) do
        if t.lv <= lv and lv <= t.lv2 then
            conf = t
            break
        end
    end
    
    if not conf then
        conf = AdventureEvent6Config[1]
    end
    
    if not conf then
        return 0
    end
    
    return conf.dropId or 0
end

local function getReward(actor, idx)
    local var = getActorVar(actor)
    
    local list = getEventList(actor, var)
    local t = list[idx]
    if t == nil then
        print('adventure.getReward t==nil idx=' .. idx)
        return
    end
    local evConf = AdventureEventConfig[t.id]
    -- 判断体力是否足够
    if t.type ~= EVENT_2 and t.type ~= EVENT_6 then
        if var.value < evConf.need then
            print('adventure.getReward yunli not enough')
            return
        end
    end
    
    local ev_type = t.type
    if ev_type == EVENT_6 then
        local nowTime = System.getNowTime()
        local et = t.et or 0
        if et == 0 or nowTime < et then
            print('adventure.getReward bad et=' .. utils.formatTime(et) .. ' nowTime=' .. utils.formatTime(nowTime))
            return
        end
    elseif ev_type == EVENT_2 then
        -- 任务奖励单独配置
        -- 需要修改进度
        local ev = getEvent(actor, idx)
        -- 子任务奖励,前4个任务给任务奖励，最后一个任务给事件奖励（大奖）
        local task = ev.task[ev.step]
        if task.state == taskcommon.statusType.emCanAward then
            -- 发任务奖励
            task.state = taskcommon.statusType.emHaveAward
            if task.rewardLen > 0 then
                local reward = {}
                for i = 1, task.rewardLen do
                    table.insert(
                        reward,
                    {type = task.reward[i].type, id = task.reward[i].id, count = task.reward[i].count})
                end
                actoritem.addItems(actor, reward, 'adventure')
            end
        elseif task.state == taskcommon.statusType.emDoing then
            -- 任务进行中
            print('adventure.getReward task is emDoing')
            return
        end
        -- 下一步
        if ev.step < TASK_MAX then
            ev.step = ev.step + 1
            onInitTask(actor, ev.task[ev.step])
        end
        if ev.award == 1 then
            actorevent.onEvent(actor, aeAdventure)
            onEndEvent(actor, idx, true)
            -- 任务完成，完成事件
            removeEvent(actor, list, idx, EVENT_2, var)
        end
        sendData(actor)
        return
    else
        if t.award ~= 1 then
            -- print('adventure.getReward bad t.award=' .. tostring(t.award))
            return
        end
    end
    
    local win = true
    local dropId = 0
    if ev_type == EVENT_6 then
        local rewards = {}
        local len = t.rewardLen or 0
        for i = 1, len do
            table.insert(rewards, t.reward[i])
        end
        
        -- 活动掉落
        local conf = getEvent6Conf(actor)
        if conf then
            subactivity12.dropList(AdventureCommonConfig.actRewards, rewards)
        end
        
        actoritem.addItems(actor, rewards, 'adventure')
    end
    actorevent.onEvent(actor, aeAdventure)
    onEndEvent(actor, idx, win)
    removeEvent(actor, list, idx, ev_type, var)
    if 0 < dropId then
        local rewards = drop.dropGroup(dropId)
        actoritem.addItems(actor, rewards, 'adventure')
    end
    sendData(actor)
end

-- 领取事件奖励
local function c2sGetReward(actor, reader)
    local idx = LDataPack.readByte(reader)
    return getReward(actor, idx)
end

local function onEtTimer(actor, et)
    local var = getActorVar(actor)
    local list = getEventList(actor, var)
    for k, t in ipairs(list) do
        if t.type == EVENT_6 and t.et == et then
            local ev = getEvent(actor, k, var)
            ev.award = 1
        end
    end
    
    sendData(actor, var)
end

function etTimer(actor, delay, et)
    LActor.postScriptEventLite(actor, delay * 1000 - 500, onEtTimer, et)
end

local function sendFightResult1(actor, idx, res)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sAdventure_FightRes)
    if pack then
        LDataPack.writeByte(pack, idx)
        LDataPack.writeByte(pack, res)
        LDataPack.flush(pack)
    end
end

local function fightEvent1(actor, idx, list, evConf, t)
    local lv = LActor.getLevel(actor)
    local conf
    for _, c in pairs(AdventureEvent1Config) do
        if c.lv <= lv and lv <= c.lv2 then
            conf = c
            break
        end
    end
    
    if not conf then
        conf = AdventureEvent1Config[1]
    end
    if not conf then
        print('adventure.fightEvent1 conf==nil lv=' .. lv)
        return
    end
    
    local res = 0 -- 0负，1赢，2和
    local k = utils.getRound10000(conf.rate)
    if k == 1 then -- 赢
        res = 1
    elseif k == 2 then -- 负
        res = 0
    else -- 和
        res = 2
    end
    
    sendFightResult1(actor, idx, res)
    -- bug:7169 改为马上发奖励
    if res == 0 or res == 1 then
        if res == 1 then
            actoritem.addItem(actor, NumericType_Adventure, evConf.winPoint, 'adventure')
        else
            actoritem.addItem(actor, NumericType_Adventure, evConf.losePoint, 'adventure')
        end
        
        local rewards = {}
        local len = t.rewardLen or 0
        for i = 1, len do
            table.insert(rewards, t.reward[i])
        end
        
        -- 活动掉落
        subactivity12.dropList(AdventureCommonConfig.actRewards, rewards)
        
        if 0 < #rewards then
            actoritem.addItems(actor, rewards, 'adventure')
        end
        
        table.remove(list, idx)
        local var = getActorVar(actor)
        setEventList(actor, list, var)
        sendData(actor, var)
        actorevent.onEvent(actor, aeAdventure)
    end
end

local function fightEvent2(actor, idx)
    local ev = getEvent(actor, idx)
    ev.state = eventStatusType.esDoing
end

local function fightFb(actor, t, monConf, idx)
    local hdl = instancesystem.createFuBen(monConf.fbid)
    local ins = instancesystem.getInsByHdl(hdl)
    ins.data.idx = idx
    ins.data.actRewards = AdventureCommonConfig.actRewards
    LActor.enterFuBen(actor, hdl)
end

-- 清小怪
local function fightEvent3(actor, t, idx)
    local lv = LActor.getLevel(actor)
    local monConf
    for _, conf in pairs(AdventureMonConfig) do
        if conf.lv <= lv and lv <= conf.lv2 then
            monConf = conf
            break
        end
    end
    
    if monConf == nil then
        monConf = AdventureMonConfig[1]
    end
    
    if monConf then
        fightFb(actor, t, monConf, idx)
    else
        print('adventure.fightEvent3 monConf==nil lv=' .. lv)
    end
end

-- 打boss
local function fightEvent4(actor, t)
    local k = t.kBuff or 1
    local kConf = AdventureBossConfig[k]
    local lv = LActor.getLevel(actor)
    local bossConf
    for _, conf in pairs(kConf) do
        if conf.lv <= lv and lv <= conf.lv2 then
            bossConf = conf
            break
        end
    end
    
    if bossConf == nil then
        bossConf = AdventureBossConfig[1]
    end
    
    if bossConf then
        local hdl = instancesystem.createFuBen(bossConf.fbid)
        local ins = instancesystem.getInsByHdl(hdl)
        ins.data.dropId = bossConf.dropId
        ins.data.actRewards = AdventureCommonConfig.actRewards
        LActor.enterFuBen(actor, hdl)
    else
        print('adventure.fightEvent4 bossConf==nil lv=' .. lv)
    end
end

local function fightEvent6(actor, idx, evConf)
    local ev = getEvent(actor, idx)
    if ev.et then -- 已打开
        return
    end
    
    local nowTime = System.getNowTime()
    ev.et = nowTime + evConf.time
    etTimer(actor, evConf.time, ev.et)
end

local function fight(actor, idx)
    local var = getActorVar(actor)
    local list = getEventList(actor, var)
    local t = list[idx]
    if t == nil then
        print('adventure.fight t==nil idx=' .. idx)
        return
    end
    
    if t.award == 1 then
        print('adventure.fight t.award==1')
        return
    end
    
    local evConf = AdventureEventConfig[t.id]
    if evConf == nil then
        print('adventure.fight evConf==nil t.id=' .. tostring(t.id))
        return
    end
    if getValue(actor, var) < evConf.need then
        return
    end
    local ev_type = t.type
    if ev_type == EVENT_1 then
        addValue(actor, -evConf.need, var)
        
        fightEvent1(actor, idx, list, evConf, t)
    elseif ev_type == EVENT_2 then
        -- task event
        addValue(actor, -evConf.need, var)
        fightEvent2(actor, idx)
    elseif ev_type == EVENT_3 then
        addValue(actor, -evConf.need, var)
        
        fightEvent3(actor, t, idx)
    elseif ev_type == EVENT_4 then
        -- 没有体力不让进，进的时候不消耗
        fightEvent4(actor, t)
    elseif ev_type == EVENT_5 then
        -- 没有体力不让进，进的时候不消耗
        -- jjc
        adventurepk.fight(actor, evConf)
    elseif ev_type == EVENT_6 then
        addValue(actor, -evConf.need, var)
        
        fightEvent6(actor, idx, evConf)
    end
    
    sendData(actor, var)
end

-- 挑战事件
local function c2sFight(actor, reader)
    local idx = LDataPack.readByte(reader)
    return fight(actor, idx)
end

-- EVENT_2
function updateTaskValue(actor, taskType, param, value)
    local var = getActorVar(actor)
    local list = getEvent2List(actor, var)
    local send = false
    if not next(list) then return end
    for k, taskid in pairs(list) do
        repeat
            local taskConf = AdventureTaskConfig[taskid]
            if taskType ~= taskConf.type then break end
            local ev = getEvent(actor, k, var)
            for i = 1, TASK_MAX do
                local task = ev.task[i]
                if task.state == taskcommon.statusType.emDoing then
                    if (taskConf.param[1] ~= -1) and (not utils.checkTableValue(taskConf.param, param)) then --有-1时不对参数做验证
                        break
                    end
                    
                    local change = false
                    if taskcommon.getHandleType(taskType) == taskcommon.eAddType then
                        task.value = (task.value or 0) + value
                        change = true
                    elseif taskcommon.getHandleType(taskType) == taskcommon.eCoverType then
                        if value > (task.value or 0) then
                            task.value = value
                            change = true
                        end
                    end
                    send = change -- 数据变化要更新
                    
                    if change then
                        if task.value >= taskConf.target then
                            if taskType == taskcommon.taskType.emZhuanshengLevel then
                                task.value = 1
                            end
                            task.state = taskcommon.statusType.emCanAward -- 任务完成
                            if i == TASK_MAX then
                                ev.award = 1 -- 事件完成
                            end
                            send = true
                        else
                            if taskType == taskcommon.taskType.emZhuanshengLevel then
                                task.value = 0
                            end
                        end
                    else
                        if taskType == taskcommon.taskType.emZhuanshengLevel then
                            task.value = 0
                        end
                    end
                    break -- 一个一个进行
                end
            end
        until true
    end
    
    if send then
        sendData(actor, var)
    end
end

-- EVENT_5
function onJjcResult(actor, win)
    local rewardList = {}
    local var = getActorVar(actor)
    local list = getEventList(actor, var)
    local tmp = {}
    for k, t in ipairs(list) do
        if t.type == EVENT_5 then
            table.insert(tmp, k)
            if win then
                local evConf = AdventureEventConfig[t.id]
                if evConf.need <= getValue(actor, var) then
                    addValue(actor, -evConf.need, var)
                    for _, tb in ipairs(evConf.reward) do
                        table.insert(rewardList, tb)
                    end
                end
            end
        end
    end
    
    for i = #tmp, 1, -1 do
        local k = tmp[i]
        table.remove(list, k)
    end
    
    if 0 < #tmp then
        setEventList(actor, list, var)
        sendData(actor, var)
    end
    
    return rewardList
end

function tryOpen(actor, custom, isLogin)
    if openCustom <= custom then
        local var = getActorVar(actor)
        if not isOpen(actor, var) then
            setOpen(actor, var)
            rsfEvent(actor, nil, true, var)
            var.evtime = System.getNowTime()
            eventTimer(actor, EVENT_DELTA)
            onNewDayHour(actor, isLogin) -- send data
        end
    end
end

local function exchange(actor, id, count)
    local conf = AdventureExchangeConfig[id]
    if conf == nil then
        print('adventure.exchange conf==nil id=' .. id)
        return
    end
    
    if not actoritem.checkItem(actor, NumericType_Adventure, conf.need * count) then
        print('adventure.exchange check item fail id=' .. id)
        return
    end
    
    actoritem.reduceItem(actor, NumericType_Adventure, conf.need * count, 'adventure exchange')
    local rewardList = {}
    for _, t in ipairs(conf.reward) do
        local reward = {}
        for k, v in pairs(t) do
            if k == 'count' then
                reward.count = v * count
            else
                reward[k] = v
            end
        end
        
        table.insert(rewardList, reward)
    end
    actoritem.addItems(actor, rewardList, 'adventure exchange')
end

-- 兑换
local function c2sExchange(actor, reader)
    local id = LDataPack.readByte(reader)
    local count = LDataPack.readShort(reader)
    return exchange(actor, id, count)
end

local function setRemind(actor, id)
    local conf = AdventureExchangeConfig[id]
    if conf == nil then
        print('adventure.setRemind conf==nil id=' .. id)
        return
    end
    
    local var = getActorVar(actor)
    setRemindData(actor, id, var)
    sendRemindData(actor, var)
end

-- 设置提醒
local function c2sSetRemind(actor, reader)
    local id = LDataPack.readByte(reader)
    return setRemind(actor, id)
end

function onFbResult(ins, ev_type, win)
    local actor = ins:getActorList()[1]
    if actor == nil then
        return
    end
    
    local var = getActorVar(actor)
    local list = getEventList(actor, var)
    local idx
    for k, t in ipairs(list) do
        if t.type == ev_type then
            local rewards = {}
            idx = k
            local ev = getEvent(actor, idx, var)
            local evConf = AdventureEventConfig[ev.id]
            
            if win then
                if ins.data.dropId then
                    local rewardlist = drop.dropGroup(ins.data.dropId)
                    for _, r in ipairs(rewardlist) do
                        table.insert(rewards, r)
                    end
                end
                table.insert(rewards, {type = AwardType_Numeric, id = NumericType_Adventure, count = evConf.winPoint})
            else
                table.insert(rewards, {type = AwardType_Numeric, id = NumericType_Adventure, count = evConf.losePoint})
            end
            
            -- 活动掉落
            subactivity12.dropList(ins.data.actRewards, rewards)
            
            onEndEvent(actor, k, win, true)
            instancesystem.setInsRewards(ins, actor, rewards)
            break -- 一个副本完成一个事件
        end
    end
    
    if idx then
        actorevent.onEvent(actor, aeAdventure)
        removeEvent(actor, list, idx, ev_type, var)
        sendData(actor, var)
    end
end

local function onKillMonsterWin(ins)
    onFbResult(ins, EVENT_3, true)
end

local function onKillMonsterLose(ins)
    onFbResult(ins, EVENT_3, true) -- 不会失败
end

local function onKillMonsterExit(ins, actor)
    local var = getActorVar(actor)
    local list = getEventList(actor, var)
    local idx = ins.data.idx
    removeEvent(actor, list, idx, EVENT_3, var)
    
    sendData(actor, var)
end

local function onKillBossWin(ins)
    onFbResult(ins, EVENT_4, true)
end

local function onKillBossLose(ins)
    onFbResult(ins, EVENT_4, false)
end

local function onPickItem(ins, actor)
    local var = getActorVar(actor)
    local now = System.getNowTime()
    if (var.pickTime or 0) > now then return end
    var.pickTime = now + 1 --限制1秒后才发送下一次
    
    local actorId = LActor.getActorId(actor)
    local picks = ins:getActorPicks(actorId)
    local items = {}
    local itemcount = 0
    if picks then
        for k, v in ipairs(picks) do
            if not items[v.id] then itemcount = itemcount + 1 end
            items[v.id] = (items[v.id] or 0) + v.count
        end
    end
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sAdventure_ShowRewards)
    if npack == nil then return end
    LDataPack.writeChar(npack, itemcount)
    for k, v in pairs(items) do
        LDataPack.writeInt(npack, k)
        LDataPack.writeInt(npack, v)
    end
    LDataPack.flush(npack)
end

local function onCustomChange(actor, custom, oldcustom)
    tryOpen(actor, custom, false)
end

function useItem(actor, count)
    local var = getActorVar(actor)
    addValue(actor, count, var)
    sendData(actor, var)
end

local function initGlobalData()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDayHour)
    actorevent.reg(aeCustomChange, onCustomChange)
    
    for _, evConf in pairs(AdventureEventConfig) do
        if evConf.type == EVENT_2 then
            event_2_id = evConf.id
        end
        eventTotalRate = eventTotalRate + evConf.rate
    end
    
    for _, kConf in pairs(AdventureBossConfig) do
        for _, bossConf in pairs(kConf) do
            local fbid = bossConf.fbid
            insevent.registerInstanceWin(fbid, onKillBossWin)
            insevent.registerInstanceLose(fbid, onKillBossLose)
        end
    end
    
    for _, monConf in pairs(AdventureMonConfig) do
        local fbid = monConf.fbid
        insevent.registerInstanceWin(fbid, onKillMonsterWin)
        insevent.registerInstanceLose(fbid, onKillMonsterLose)
        insevent.registerInstanceExit(fbid, onKillMonsterExit)
        insevent.registerInstancePickItem(fbid, onPickItem)
    end
    
    local tmp = {}
    for _, taskConf in pairs(AdventureTaskConfig) do
        tmp[taskConf.lv] = tmp[taskConf.lv] or {totalRate = 0}
        local lvList = tmp[taskConf.lv]
        lvList.totalRate = lvList.totalRate + taskConf.rate
        lvList.lv = taskConf.lv
        lvList.lv2 = taskConf.lv2
        lvList.list = lvList.list or {}
        table.insert(lvList.list, taskConf.id)
    end
    for _, conf in pairs(tmp) do
        table.insert(taskRandomList, conf)
    end
    table.sort(taskRandomList, function(a, b) return a.lv <= b.lv end)
    
    openCustom = LimitConfig[actorexp.LimitTp.adventure].custom

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cAdventure_GetReward, c2sGetReward)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cAdventure_FightFb, c2sFight)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cAdventure_Exchange, c2sExchange)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cAdventure_SetRemind, c2sSetRemind)
end
table.insert(InitFnTable, initGlobalData)

local gmCmdHandlers = gmsystem.gmCmdHandlers
function gmCmdHandlers.advFight(actor, args)
    local idx = tonumber(args[1]) or 1
    local param = tonumber(args[2]) or 0
    fight(actor, idx, param)
    gmCmdHandlers.advEventList(actor, args)
    return true
end

function gmCmdHandlers.advFight1(actor, args)
    local idx = tonumber(args[1]) or 1
    local param = tonumber(args[2]) or 1
    clearActorVar(actor)
    gmCmdHandlers.advValue(actor, args)
    rsfEvent(actor)
    local ev = getEvent(actor, idx)
    ev.id = 1
    ev.type = EVENT_1
    fight(actor, idx, param)
    gmCmdHandlers.advEventList(actor, args)
    return true
end

function gmCmdHandlers.advReward(actor, args)
    local idx = tonumber(args[1]) or 1
    getReward(actor, idx)
    return true
end

function gmCmdHandlers.advValue(actor, args)
    local v = tonumber(args[1]) or VALUE_MAX
    addValue(actor, v)
    sendData(actor)
    return true
end

-- function gmCmdHandlers.advFinishTask(actor, args)
--     local idx = tonumber(args[1]) or 1
--     local ev = getEvent(actor, idx)
--     if ev.type ~= EVENT_2 then
--         return false
--     end
--     print("arg="..idx .. " type=" .. ev.type .. " id=" .. ev.id .. ' step=' .. ev.step)
    
--     local task = ev.task[ev.step]
--     task.state = taskcommon.statusType.emCanAward
--     if ev.step == TASK_MAX then
--         print('event finish')
--         ev.award = 1
--     end
--     sendData(actor)
    
--     return true
-- end

function gmCmdHandlers.advRsf(actor, args)
    local clr = args[1]
    if clr then
        clearActorVar(actor)
    end
    local all = args[2]
    if all then
        rsfEvent(actor, nil, true)
    else
        rsfEvent(actor)
    end
    local var = getActorVar(actor)
    var.evtime = System.getNowTime()
    setOpen(actor, var)
    gmCmdHandlers.advEventList(actor, args)
    sendData(actor)
    return true
end

function gmCmdHandlers.advOpen(actor, args)
    setOpen(actor)
    onLogin(actor)
    return true
end

function gmCmdHandlers.advEventList(actor, args)
    local var = getActorVar(actor)
    local list = getEventList(actor, var)
    local qiyu_point = actoritem.getItemCount(actor, NumericType_Adventure)
    print('list len=' .. #list .. ' advPoint=' .. qiyu_point)
    for k, t in ipairs(list) do
        print('event list k=' .. k .. ' t.id=' .. tostring(t.id))
        if t.type == EVENT_1 then
            print('  event1 len=' .. t.rewardLen)
            for i = 1, t.rewardLen do
                local r = t.reward[i]
                print('  event1 i=' .. i .. ' type=' .. r.type .. ' id=' .. r.id .. ' count=' .. r.count)
            end
        end
        if t.type == EVENT_2 then
            print('  event idx='..k .. ' is task event')
            if t.task == nil then
                print('  task is nil')
            else
                print('  task len=' .. #t.task.. ' step='..t.step)
                for i, task in ipairs(t.task) do
                    print('  task i='..i..' id='..task.id..' state=' .. (task.state or 0))
                    if not task.reward then
                        print(' task reward==nil')
                    else
                        print(' task reward len=' .. #task.reward)
                    end
                end
            end
        end
    end
    return true
end

function gmCmdHandlers.advDelEvent(actor, args)
    local idx = tonumber(args[1]) or 1
    local var = getActorVar(actor)
    local list = getEventList(actor, var)
    local ev = list[idx]
    print('list=' .. #list)
    removeEvent(actor, list, idx, ev.type, var)
    
    list = getEventList(actor, var)
    for k, t in ipairs(list) do
        print('event list k=' .. k .. ' t.id=' .. tostring(t.id) .. ' t.type=' .. tostring(t.type))
    end
    gmCmdHandlers.advEventList(actor, args)
    return true
end

function gmCmdHandlers.advClear(actor, args)
    local var = getActorVar(actor)
    var.event = {}
    var.evtime = System.getNowTime()
    gmCmdHandlers.advEventList(actor, args)
    sendData(actor, var)
    return true
end

function gmCmdHandlers.advPoint(actor, args)
    local count = tonumber(args[1]) or 1000
    actoritem.addItem(actor, NumericType_Adventure, count, 'test')
    return true
end

function gmCmdHandlers.advTestRsf(actor, args)
    local var = getActorVar(actor)
    for i = 1, 10000 do
        clearActorVar(actor)
        rsfEvent(actor)
        
        local list = getEventList(actor, var)
        local idList = {}
        for k, t in ipairs(list) do
            if not idList[t.id] then
                idList[t.id] = true
            else
                gmCmdHandlers.advEventList(actor, args)
                assert(false)
            end
        end
    end
    return true
end

function gmCmdHandlers.advFinishTask(actor, args)
    local var = getActorVar(actor)
    local list = getEventList(actor, var)
    for k, t in ipairs(list) do
        if t.type == EVENT_2 then
            local ev = getEvent(actor, k, var)
            for i = 1, TASK_MAX do
                local task = ev.task[i]
                print('i=' .. i .. ' task.state=' .. task.state)
                if task.state == taskcommon.statusType.emDoing then -- 进行中
                    task.state = taskcommon.statusType.emCanAward -- 任务完成
                    if i == TASK_MAX then
                        ev.award = 1 -- 事件完成
                    end
                end
            end
        end
    end
    gmCmdHandlers.advEventList(actor, args)
    return true
end
