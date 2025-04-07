module("activitymgr", package.seeall)

--子活动处理
require("activity.activity")

globalData = globalData or {} --临时数据

local getHeFuTime = hefutime.getHeFuDayStartTime
local getHeFuCount = hefutime.getHeFuCount

vt = {
    type20Pv = 1, -- 活动20个人值
    type20Cv = 2, -- 活动20全区值
    type20Gv = 3, -- 活动20先知之魂
}

function sendValue(actor, id, tp, val)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Value)
    if npack then
        LDataPack.writeInt(npack, id)
        LDataPack.writeInt(npack, tp)
        LDataPack.writeInt(npack, val)
        LDataPack.flush(npack)
    end
end

function broadcastValue(id, tp, val)
    local list = System.getOnlineActorList()
    if list then
        for _, actor in ipairs(list) do
            sendValue(actor, id, tp, val)
        end
    end
end

--个人记录数据
function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then return nil end
    if var.activityData == nil then
        var.activityData = {}
        var.activityData.records = {}
    end
    return var.activityData
end

function getSubVar(actor, id)
    local activity = globalData.activities[id]
    if activity == nil then return end
    local var = getStaticData(actor)
    if var.records[id] == nil then
        var.records[id] = {}
        var.records[id].isjoin = 0
        var.records[id].type = activity.type
        var.records[id].mark = activity.mark
        var.records[id].data = {}
    end
    return var.records[id]
end

--公共记录数据
function getGlobalVar(id)
    local activity = globalData.activities[id]
    if activity == nil then return end
    local var = System.getStaticVar()
    if var == nil then return nil end
    if var.activityData == nil then var.activityData = {} end
    if var.activityData.records == nil then var.activityData.records = {} end
    local records = var.activityData.records
    if records[id] == nil then
        records[id] = {}
        records[id].type = activity.type
        records[id].mark = activity.mark
        records[id].data = {}
    end
    return records[id].data
end

function clearGlobalVar(id)
    local activity = globalData.activities[id]
    if activity == nil then return end
    local var = System.getStaticVar()
    if var == nil then return nil end
    if var.activityData == nil then var.activityData = {} end
    if var.activityData.records == nil then var.activityData.records = {} end
    local records = var.activityData.records
    records[id] = nil
end

--检测数据库记录，有改动的活动数据清除
function checkStaticData()
    local var = System.getStaticVar()
    if var.activityData == nil then var.activityData = {} end
    if var.activityData.records == nil then var.activityData.records = {} end
    local records = var.activityData.records
    for id, activity in pairs(globalData.activities) do
        if records[id] and (records[id].type ~= activity.type or records[id].mark ~= activity.mark) then
            records[id] = nil
        end
    end
end

--检测数据库记录，有改动的活动数据清除，过期活动数据清除
function checkStaticVar(actor)
    local var = getStaticData(actor)
    if var.records then
        local now = System.getNowTime()
        for id, activity in pairs(globalData.activities) do
            local record = var.records[id]
            if record then
                if activity == nil or record.type ~= activity.type or record.mark ~= activity.mark then
                    --subactivitymgr.onTimeOut(record.type, id, actor, record)
                    var.records[id] = nil
                elseif activity.varClear == true and now > activity.endTime then
                    var.records[id] = nil
                end
            end
        end
    end
end

function roleActivityFinish(actor, tp, record, id)
    subactivitymgr.onTimeOut(tp, id, actor, record)
end

function getParamConfig(id)
    if ActivityConfig[id] == nil then
        return nil
    end
    return ActivityConfig[id].params
end

local function loadTime(conf)
    
    if conf.timeType == 1 then
        --startTime
        local d, h, m = string.match(conf.startTime, "(%d+)-(%d+):(%d+)")
        if d == nil or h == nil or m == nil then
            return 0, 0, 0
        end
        local st = System.getOpenServerStartDateTime()
        st = st + d * 24 * 3600 + h * 3600 + m * 60
        
        --endTime
        d, h, m = string.match(conf.endTime, "(%d+)-(%d+):(%d+)")
        if d == nil or h == nil or m == nil then
            return 0, 0, 0
        end
        local et = System.getOpenServerStartDateTime()
        et = et + d * 24 * 3600 + h * 3600 + m * 60
        
        --overTime
        local ot = et + conf.time * 60
        return st, et, ot
    elseif conf.timeType == 2 then
        --固定时间
        local openday = System.getOpenServerDay() + 1
        if openday <= conf.biggeropentime then --开服多少天内不开此活动
            return 0, 0, 0
        end
        --startTime
        local Y, M, d, h, m = string.match(conf.startTime, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
        if Y == nil or M == nil or d == nil or h == nil or m == nil then
            return 0, 0, 0
        end
        local st = System.timeEncode(Y, M, d, h, m, 0)
        
        --endTime
        local Y, M, d, h, m = string.match(conf.endTime, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
        if Y == nil or M == nil or d == nil or h == nil or m == nil then
            return 0, 0, 0
        end
        local et = System.timeEncode(Y, M, d, h, m, 0)
        
        --overTime
        local ot = et + conf.time * 60
        return st, et, ot
    elseif conf.timeType == 3 then
        -- 周循环活动
        --计算周一0点的时间
        local week1time = System.getWeekFistTime()
        --startTime
        local d, h, m = string.match(conf.startTime, "(%d+)-(%d+):(%d+)")
        if d == nil or h == nil or m == nil then
            return 0, 0, 0
        end
        local st = week1time + d * 24 * 3600 + h * 3600 + m * 60
        local openst = System.getOpenServerStartDateTime()
        if (st - openst) / 86400 + 1 <= conf.biggeropentime then
            return 0, 0, 0
        end
        -- endTime
        d, h, m = string.match(conf.endTime, "(%d+)-(%d+):(%d+)")
        if d == nil or h == nil or m == nil then
            return 0, 0, 0
        end
        local et = week1time + d * 24 * 3600 + h * 3600 + m * 60
        
        --overTime
        local ot = et + conf.time * 60
        return st, et, ot
    elseif conf.timeType == 4 then
        -- 月循环活动
        --计算每月一号0点的时间
        local mon1time = System.getMonFistTime()
        --startTime
        local d, h, m = string.match(conf.startTime, "(%d+)-(%d+):(%d+)")
        if d == nil or h == nil or m == nil then
            return 0, 0, 0
        end
        local st = mon1time + d * 24 * 3600 + h * 3600 + m * 60
        local openst = System.getOpenServerStartDateTime()
        if (st - openst) / 86400 + 1 <= conf.biggeropentime then
            return 0, 0, 0
        end
        -- endTime
        d, h, m = string.match(conf.endTime, "(%d+)-(%d+):(%d+)")
        if d == nil or h == nil or m == nil then
            return 0, 0, 0
        end
        local et = mon1time + d * 24 * 3600 + h * 3600 + m * 60
        
        --overTime
        local ot = et + conf.time * 60
        return st, et, ot
    elseif conf.timeType == 5 then
        -- 合服时间
        local hefutime = getHeFuTime()
        if not hefutime then
            return 0, 0, 0
        end
        
        --startTime
        local d, h, m = string.match(conf.startTime, "(%d+)-(%d+):(%d+)")
        if d == nil or h == nil or m == nil then
            return 0, 0, 0
        end
        local st = hefutime + d * 24 * 3600 + h * 3600 + m * 60
        
        -- endTime
        d, h, m = string.match(conf.endTime, "(%d+)-(%d+):(%d+)")
        if d == nil or h == nil or m == nil then
            return 0, 0, 0
        end
        local et = hefutime + d * 24 * 3600 + h * 3600 + m * 60
        
        --overTime
        local ot = et + conf.time * 60
        return st, et, ot
    else
        return 0, 0, 0
    end
end

--是否属于限制服务器
local function findId(id, conf)
    if idlist and type(conf.idLimit) == "table" then
        for _, i in ipairs(idlist) do
            if id == i then
                return true
            end
        end
    end
    local ot = System.getOpenServerDateTime()
    --该日期后开服不开
    if conf.opentimelater ~= "" then
        local Y, M, d, h, m = string.match(conf.opentimelater, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
        if Y == nil or M == nil or d == nil or h == nil or m == nil then
            assert("activity config field opentimelater is error")
        end
        if System.timeEncode(Y, M, d, h, m, 59) - ot <= 0 then
            return true
        end
    end
    
    --该日期前开服不开
    if conf.opentimebefore ~= "" then
        Y, M, d, h, m = string.match(conf.opentimebefore, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
        if Y == nil or M == nil or d == nil or h == nil or m == nil then
            assert("activity config field opentimebefore is error")
        end
        if System.timeEncode(Y, M, d, h, m, 0) - ot >= 0 then
            return true
        end
    end

    --不满足合服条件的服务器不开合服活动
    local hfcount = getHeFuCount()
    if conf.timeType == 5 and conf.hefutimes ~= hfcount then 
        return true 
    end

    return false
end

local function getMark(conf)
    if conf.timeType == 3 then
        local week1time = System.getWeekFistTime()
        return week1time..conf.startTime..conf.endTime
    elseif conf.timeType == 4 then
        local mon1time = System.getMonFistTime()
        return mon1time..conf.startTime..conf.endTime
    elseif conf.timeType == 5 then
        local hefutime = getHeFuTime()
        return hefutime..conf.startTime..conf.endTime
    else
        return conf.startTime..conf.endTime
    end
end

--读配置处理
local function loadConfig()
    local activities = {}
    local count = 0
    if System.isLianFuSrv() then 
        return activities, count
    end
    local iscross = System.isBattleSrv()
    local iscommon = System.isCommSrv()
    for id, conf in pairs(ActivityConfig) do
        local st, et, ot = loadTime(conf)
        local typeConfig = subactivitymgr.getConfig(conf.activityType)
        if typeConfig and typeConfig[id] and ((iscross and conf.iscross == 1) or iscommon) then
            local serverLimit = findId(System.getServerId(), conf) --这个服没有该活动
            if not serverLimit then
                activities[id] = {
                    id = id,
                    startTime = st, --开始时间
                    endTime = et, --结束时间
                    overTime = ot, --持续显示时间
                    type = conf.activityType, --活动类型
                    mark = getMark(conf), --时间标记
                    varClear = conf.endClear > 0 --结束后是否删数据
                }
                count = count + 1
            end
        end
    end
    return activities, count
end

function activityFinish(_, activity)
    subactivitymgr.onActivityFinish(activity.type, activity.id)
end

--读配置，生成活动数据,启服，热更，24点执行
local function onStart()
    if globalData.activities then
        for id, activity in pairs(globalData.activities) do
            if activity.end_eid then
                LActor.cancelScriptEvent(nil, activity.end_eid)
            end
        end
    end
    local activities, count = loadConfig()
    if activities == nil then
        print("load activities config failed!!!")
        assert(false)
    end
    
    globalData.activities = activities
    globalData.activityCount = count
    
    for id, activity in pairs(globalData.activities) do
        if activity.endTime - System.getNowTime() > 0 then
            activity.end_eid = LActor.postScriptEventLite(nil, (activity.endTime - System.getNowTime()) * 1000, activityFinish, activity)
        end
    end
    
    subactivity4.checkEndTime()
    --subactivity34.checkEndTime()
    
    checkStaticData() --原记录数据检测
    
    subactivity31.checkNeedInit()--需要在清空后再初始化奖池
end

--检测事件是否结束
function activityTimeIsEnd(id)
    local aInfo = globalData.activities[id]
    if aInfo then
        local now_t = System.getNowTime()
        if now_t >= aInfo.startTime and now_t < aInfo.endTime then
            return false
        end
    end
    return true
end

--检测事件是否还需要下发数据
function activityTimeIsOver(id)
    local aInfo = globalData.activities[id]
    if aInfo then
        local now_t = System.getNowTime()
        if now_t >= aInfo.startTime and now_t < aInfo.overTime then
            return false
        end
    end
    return true
end

--初始化接口
local function subInit()
    for k, v in pairs(globalData.activities) do
        local tp = ActivityConfig[k].activityType
        if subactivitymgr.getConfig(tp) then
            subactivitymgr.init(tp, k, v)
        end
    end
end

--处理登录
function callBackSubActorLogin(actor)
    for k, v in pairs(globalData.activities) do
        local tp = ActivityConfig[k].activityType
        if subactivitymgr.getConfig(tp) and subactivitymgr.actorLoginFuncs[tp] then
            subactivitymgr.actorLoginFuncs[tp](actor, tp, k)
        end
    end
end

function getBeginTime(id)
    local info = globalData.activities[id]
    if info == nil then
        return 0
    end
    return info.startTime
end

function getEndTime(id)
    local info = globalData.activities[id]
    if info == nil then
        return 0
    end
    return info.endTime
end

-- 活动已开启的天数
function getCurDay(id)
    local info = globalData.activities[id]
    if info == nil then
        return 0
    end
    local now = System.getNowTime()
    if now < info.startTime then
        return 0
    end
    return math.ceil((now - info.startTime) / 24 / 3600)
end

----------------------------------------------------------------------------------------------------------------------

--活动信息
function s2cActivityInfo(actor, notInit)
    local var = getStaticData(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Info)
    if npack == nil then return end
    LDataPack.writeChar(npack, notInit and 0 or 1)
    LDataPack.writeShort(npack, globalData.activityCount)
    for id, activity in pairs(globalData.activities) do
        LDataPack.writeInt(npack, id)
        LDataPack.writeInt(npack, activity.startTime)
        LDataPack.writeInt(npack, activity.endTime)
        LDataPack.writeShort(npack, activity.type)
        local pos = LDataPack.getPosition(npack)
        LDataPack.writeInt(npack, 0) -- 长度
        
        local record = getSubVar(actor, id)
        subactivitymgr.writeRecord(id, activity.type, npack, record, actor)
        local pos2 = LDataPack.getPosition(npack)
        LDataPack.setPosition(npack, pos)
        LDataPack.writeInt(npack, pos2 - pos - 4)
        LDataPack.setPosition(npack, pos2)
    end
    LDataPack.flush(npack)
end

function sendActivityInfo(actor, id, notInit)
    local activity = globalData.activities[id]
    if not activity then
        return
    end
    --获取静态变量
    -- local now = System.getNowTime()
    -- local data = getStaticData(actor)
    --发包给客户端
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Info)
    if npack == nil then return end
    LDataPack.writeChar(npack, notInit and 0 or 1)
    LDataPack.writeShort(npack, 1)
    
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, activity.startTime)
    LDataPack.writeInt(npack, activity.endTime)
    LDataPack.writeShort(npack, activity.type)
    local pos = LDataPack.getPosition(npack)
    LDataPack.writeInt(npack, 0) -- 长度
    
    local record = getSubVar(actor, id)
    subactivitymgr.writeRecord(id, activity.type, npack, record, actor)
    local pos2 = LDataPack.getPosition(npack)
    LDataPack.setPosition(npack, pos)
    LDataPack.writeInt(npack, pos2 - pos - 4)
    LDataPack.setPosition(npack, pos2)
    
    LDataPack.flush(npack)
end

-- 领取活动奖励
function c2sGetReward(actor, packet)
    local id = LDataPack.readInt(packet)
    local idx = LDataPack.readShort(packet)
    --活动不存在
    if globalData.activities[id] == nil then
        return
    end
    --不在活动时间
    local now = System.getNowTime()
    if globalData.activities[id].startTime > now or globalData.activities[id].endTime < now then
        subactivitymgr.onGetRewardTimeOut(id, actor, packet)
        return
    end
    
    --读取配置，获得类型
    local tp = ActivityConfig[id].activityType
    if subactivitymgr.getConfig(tp) == nil then
        return
    end
    
    local record = getSubVar(actor, id)
    
    --根据类型调用特定类型处理接口
    subactivitymgr.onGetReward(actor, tp, id, idx, record, packet)
    utils.logCounter(actor, "activity reward", tp, id, idx)
end

--更新奖励
function c2sReqInfo(actor, packet)
    local id = LDataPack.readInt(packet)
    
    --活动不存在
    if globalData.activities[id] == nil then
        return
    end
    
    --不在活动时间
    local now = System.getNowTime()
    if globalData.activities[id].startTime > now or globalData.activities[id].endTime < now then
        subactivitymgr.onReqInfoTimeOut(id, actor, packet)
        return
    end
    
    --读取配置，获得类型
    local tp = ActivityConfig[id].activityType
    if subactivitymgr.getConfig(tp) == nil then
        return
    end
    
    local record = getSubVar(actor, id)
    
    --根据类型调用特定类型处理接口
    subactivitymgr.onReqInfo(tp, id, actor, record, packet)
end

function sendHefutime(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_HefuTime)
    local hefutime = getHeFuTime() or 0
    if not npack then return end
    LDataPack.writeInt(npack, hefutime)
    LDataPack.flush(npack)
end

function onLogin(actor)
    if System.isBattleSrv() then return end
    sendHefutime(actor)
    checkStaticVar(actor)
    s2cActivityInfo(actor)
    callBackSubActorLogin(actor)
    --subactivitymgr.onLogin(actor)
end

function onNewDay(actor, login)
    if System.isBattleSrv() then return end
    for id, v in pairs(globalData.activities) do
        local tp = ActivityConfig[id].activityType
        if subactivitymgr.getConfig(tp) then
            local record = getSubVar(actor, id)
            if not activityTimeIsEnd(id) and record.mark == v.mark then
                record.isjoin = 1
            else
                if record.isjoin == 1 then
                    roleActivityFinish(actor, tp, record, id)
                end
                record.isjoin = 0
            end
            subactivitymgr.onNewDay(actor, tp, id, record, login)
        end
    end
    if not login then
        checkStaticVar(actor)
        s2cActivityInfo(actor)
        for id, v in pairs(globalData.activities) do
            local tp = ActivityConfig[id].activityType
            if subactivitymgr.getConfig(tp) then
                subactivitymgr.onNewDayAfter(actor, tp, id)
            end
        end
    end
end

--23点全服更新领奖状态
function updateActivityInfo()
    LActor.postScriptEventLite(nil, 5000,
        function(...)
            if System.isBattleSrv() then return end
            local actors = System.getOnlineActorList()
            if actors then
                for i = 1, #actors do
                    local actor = actors[i]
                    s2cActivityInfo(actor, true)
                end
            end
        end
    )
end

_G.updateActivityInfo = updateActivityInfo

--24点
function updateActivity(now)
    if System.isLianFuSrv() then return end
    local wday = System.getDayOfWeek()
    local year, month, day, hour, minute, sec = System.timeDecode(now)
    if day == 1 or wday == 1 then --周一或者每月1号重新加载配置
        onStart()
    end
    subactivity30.On24Hour()
    subactivity32.On24Hour()
    subactivity33.On24Hour()
    subactivity34.On24Hour()
end

_G.updateActivity = updateActivity

--启动初始化
local function init()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    onStart()
    subInit() --subInit放在后面，使登录与每日处理都先让活动管理器执行
    if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Reward, c2sGetReward)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Update, c2sReqInfo)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.checkActivity = function (actor, args)
    local record = getSubVar(actor, 1)
    return true
end

gmCmdHandlers.activityreward = function (actor, args)
    local pack = LDataPack.allocPacket()
    LDataPack.writeInt(pack, args[1])
    LDataPack.writeShort(pack, args[2])
    LDataPack.setPosition(pack, 0)
    c2sGetReward(actor, pack)
    return true
end
