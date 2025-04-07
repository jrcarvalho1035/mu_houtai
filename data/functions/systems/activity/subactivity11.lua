module("subactivity11", package.seeall)
--直购礼包
local subType = 11
local act11Pays = {}

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.buyInfo then
        var.buyInfo = {}
    end
    for index in ipairs(ActivityType11Config[id]) do
        if not var.buyInfo[index] then
            var.buyInfo[index] = {}
            var.buyInfo[index].haveBuy = 0 --已经购买的次数
            var.buyInfo[index].status = 0 --领取状态 0-不可领，1-可领取，2-已领取
        end
    end
    return var.buyInfo
end

function initPay()
    for id, config in pairs(ActivityType11Config) do
        for index, conf in ipairs(config) do
            act11Pays[conf.pay] = 1
        end
    end
end

--登录协议回调
function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local var = getActorVar(actor, id)
    LDataPack.writeChar(npack, #ActivityType11Config[id])
    for idx in ipairs(config) do
        LDataPack.writeChar(npack, var[idx].haveBuy)
        LDataPack.writeChar(npack, var[idx].status)
    end
end

function onGetReward(actor, config, id, idx, record)
    local var = getActorVar(actor, id)
    local num = var[idx].haveBuy
    if var[idx].status ~= 1 then
        print("can't GetReward status:", var[idx].status)
        return
    end
    
    local act11Config = config[id][idx]
    if not actoritem.checkEquipBagSpaceJob(actor, act11Config.reward) then
        return
    end

    if act11Config.daycount.count <= num then
        var[idx].status = 2
    else
        var[idx].status = 0
    end
    local extra = string.format("act11 reward id:%d,index:%d,time:%d", id, idx, num)
    actoritem.addItems(actor, act11Config.reward, extra)---获得奖励
    updateInfo(actor, id, idx)
end

function Act11Buy(actor, count)
    local id = -1
    local index = -1
    for actId, config in pairs(ActivityType11Config) do
        if not activitymgr.activityTimeIsEnd(actId) then
            for idx, conf in ipairs(config) do
                if count == conf.pay then
                    id = actId
                    index = idx
                    break
                end
            end
        end
    end
    if index == -1 or id == -1 then
        print("act11.Act11Buy: not find act, item =", count)
        return
    end
    
    local config = ActivityType11Config[id][index]
    local var = getActorVar(actor, id)
    var = var[index]
    local num = var.haveBuy
    
    if config.daycount.count <= num then
        print("act11.Act11Buy: have no count, haveBuy =", num, "count =", config.daycount.count)
        return
    end
    
    if var.status == 1 then --领奖状态不可以充值
        print("act11.Act11Buy: can't buy, because status = emCanAward")
        return
    end
    
    num = num + 1
    var.haveBuy = num
    var.status = 1
    
    rechargesystem.addVipExp(actor, count)
    updateInfo(actor, id, index)
    print(string.format("subactivity11.Act11Buy: actId = %d index = %d haveBuy = %d", id, index, num))
end

function updateInfo(actor, id, index)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Update11)
    local var = getActorVar(actor, id)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, index)
    LDataPack.writeChar(npack, var[index].haveBuy)
    LDataPack.writeChar(npack, var[index].status)
    LDataPack.flush(npack)
end

function isActivity11(count)
    --return act11Pays[count] ~= nil
    for id, config in pairs(ActivityType11Config) do
        for index, conf in ipairs(config) do
            if conf.pay == count then
                return true
            end
        end
    end
    return false
end

function buy(actorid, count)
    local actor = LActor.getActorById(actorid)
    if actor then
        Act11Buy(actor, count)
    else
        local npack = LDataPack.allocPacket()
        LDataPack.writeInt(npack, count)
        System.sendOffMsg(actorid, 0, OffMsgType_Activity11, npack)
    end
end

function OffMsgAct11Buy(actor, offmsg)
    local count = LDataPack.readInt(offmsg)
    print(string.format("OffMsgAct11Buy actorid:%d count:%d", LActor.getActorId(actor), count))
    Act11Buy(actor, count)
end

function onBeforeNewDay(actor)
    for id, config in pairs(ActivityType11Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local var = getActorVar(actor, id)
            for idx, conf in ipairs(config) do
                if conf.daycount.type == 1 then
                    var[idx].haveBuy = 0
                    var[idx].status = 0
                end
            end
        end
    end
end

function onTimeOut(id, config, actor, record)
    local act11Config = config[id]
    local var = getActorVar(actor, id)
    local actorid = LActor.getActorId(actor)
    for index, conf in ipairs(act11Config) do
        if var[index].status == 1 then
            local mailData = {head = conf.head, context = conf.text, tAwardList = conf.reward}
            mailsystem.sendMailById(actorid, mailData)
            var[index].status = 2
        end
    end
end

function init()
    if System.isCrossWarSrv() then return end
    initPay()
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    --subactivitymgr.regLoginFunc(subType, onLogin)
    subactivitymgr.regNewDayFunc(subType, onBeforeNewDay)
    subactivitymgr.regTimeOut(subType, onTimeOut)
    subactivitymgr.regGetRewardFunc(subType, onGetReward)
    msgsystem.regHandle(OffMsgType_Activity11, OffMsgAct11Buy)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.act11Reward = function (actor, args)
    local id = tonumber(args[1])
    local index = tonumber(args[2])
    if not id or not index then return end
    print("act11Reward id =", id, "index =", index)
    
    if not activitymgr.activityTimeIsEnd(id) then
        onGetReward(actor, ActivityType11Config, id, index, nil)
    else
        print('activity is over id:', id)
    end
    return true
end

gmCmdHandlers.act11Clear = function (actor, args)
    local id = tonumber(args[1])
    local index = tonumber(args[2])
    if not id or not index then return end
    print("act11Reward id =", id, "index =", index)
    
    local var = activitymgr.getSubVar(actor, id)
    var.data.buyInfo = nil
    return true
end
