-- 摇摇乐
module("subactivity42", package.seeall)

local subType = 42
local SpecialActivityId = 2048

--消费元宝
local ybCostConfig = ActivityType42Config[SpecialActivityId][0].ybCost
--充值元宝
local ybRechargeConfig = ActivityType42Config[SpecialActivityId][0].ybRecharge
--奖励
local rewardConfig = ActivityType42Config[SpecialActivityId][0].reward
--是否每天重置
local isReset = ActivityType42Config[SpecialActivityId][0].isReset or 0
local loginGift = ActivityType42Config[SpecialActivityId][0].loginGift or 0
local rollConfig = ActivityType42Config[SpecialActivityId]

local rewardList = {}

local function sendBaseInfo(actor, id)
    local record = activitymgr.getSubVar(actor, id)
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_UpdateYoYoInfo)
    LDataPack.writeInt(npack, id)

    LDataPack.writeShort(npack, record.rollCount or 0)
    LDataPack.writeShort(npack, record.totalCount or 0)
    LDataPack.writeInt(npack, record.totalConsume or 0)
    LDataPack.writeInt(npack, record.totalRecharge or 0)

    LDataPack.flush(npack)
end

local function sendRewardLogs(actor, list)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_SendYoYoRewardLogList)
    local count = #(list or {})
    if count > 100 then count = 100 end
    LDataPack.writeShort(npack, count)
    for i = 1, count do
        -- { account, dicePoint, rewardCfg.type, rewardCfg.id, rewardCfg.count }
        LDataPack.writeString(npack, list[i][1])
        LDataPack.writeShort(npack, list[i][2])
        LDataPack.writeShort(npack, list[i][3])
        LDataPack.writeInt(npack, list[i][4])
        LDataPack.writeInt(npack, list[i][5])
        -- print(string.format("activity26: account: %s, dicePoint: %d, type: %d, id: %d, count: %d", list[i][1], list[i][2], list[i][3], list[i][4], list[i][5]))
    end

    LDataPack.flush(npack)
end

local function clearRewardLog()
    local size = #rewardList
    if size > 100 then
        size = size - 100
        while (size > 0) do
            table.remove(rewardList, 1)
            size = size - 1
        end
    end
end

--请求领取奖励
local function onGetReward(id, typeconfig, actor, record, packet)
    -- local record = activitymgr.getSubVar(actor, id)
    if record.rollCount == nil then record.rollCount = 0 end
    if record.totalCount == nil then record.totalCount = 0 end
    if record.rollCount >= record.totalCount then return end

    local account = LActor.getActorName(LActor.getActorId(actor))
    local rollCount = record.rollCount + 1
    local index = 1
    local diceCount = 0
    for i = 1, #rollConfig do
        local countLimit = rollConfig[i] and rollConfig[i].count or 0
        if countLimit <= rollCount then
            index = i
        end
    end
    local sum = 0
    local weights = {}
    local count = 0
    for i, value in ipairs(rollConfig[index].rate) do
        sum = sum + value
        weights[i] = value
        -- print(string.format("activity26 giveaward: account: %s, rollCount: %d, index: %d, sum: %d, weights: %d", account, rollCount, index, sum, weights[i]))
    end
    local compareWeight = math.random(1, sum)
    local weightIndex = 1
    while sum > 0 do
        sum = sum - weights[weightIndex]
        if sum < compareWeight then
            diceCount = weightIndex
            sum = 0
        end
        weightIndex = weightIndex + 1
    end
    print(string.format("activity26 giveaward: diceCount: %d, account: %s, rollCount: %d, compareWeight: %d", diceCount, account, rollCount, compareWeight))

    local newRewardLog = {}
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_GetYoYoRewardResult)
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, diceCount)
    local rewards = {}
    for i = 1, diceCount do
        local dicePoint = math.random(1, 6)
        LDataPack.writeShort(npack, dicePoint)
        local rewardCfg = rewardConfig[i][dicePoint]
        rewards[i] = {type = rewardCfg.type, id = rewardCfg.id, count = rewardCfg.count}

        local log = { account, dicePoint, rewardCfg.type, rewardCfg.id, rewardCfg.count }
        table.insert(newRewardLog, log)
        table.insert(rewardList, log)
        print(string.format("activity26 giveaward: diceCount: %d, account: %s, dicePoint: %d, type: %d, id: %d, count: %d", diceCount, account, dicePoint, rewardCfg.type, rewardCfg.id, rewardCfg.count))
    end

    LDataPack.flush(npack)
    
    record.rollCount = rollCount

    LActor.postScriptEventLite(actor, 3 * 1000, function()
        LActor.giveAwards(actor, rewards, "activity26 reward")
        sendRewardLogs(actor, newRewardLog)
    end)
end

--查询摇摇乐信息
local function onReqInfo(id, typeconfig, actor, record, packet)
    sendBaseInfo(actor, id)
end

local function writeRecord(npack, record, conf, id, actor)
    if nil == record then record = {} end
    LDataPack.writeShort(npack, record.rollCount or 0)
    LDataPack.writeShort(npack, record.totalCount or 0)
    LDataPack.writeInt(npack, record.totalConsume or 0)
    LDataPack.writeInt(npack, record.totalRecharge or 0)
end

-- 每日重置
local function onNewDay(id, conf)
    return function(actor)
        local record = activitymgr.getSubVar(actor, id)
        if isReset == 1 then
            record.rollCount = 0
            record.totalCount = loginGift
            record.rechargeIndex = nil
            record.totalRecharge = nil
            record.consumeIndex = nil
            record.totalConsume = nil
            record.lastLoginTime = System.getToday()
        end
        sendBaseInfo(actor, id)
    end
end

--充值
local function onReCharge(id, conf)
    return function(actor, val)
        if activitymgr.activityTimeIsEnd(id) then return end
        local var = activitymgr.getSubVar(actor, id)
        local count = 0
        local newTotal = (var.totalRecharge or 0) + val
        for index = (var.rechargeIndex or 0) + 1, #ybRechargeConfig do
            local value = ybRechargeConfig[index] or 0
            if value <= newTotal then
                count = count + 1
                var.rechargeIndex = index
            end
        end
        var.totalCount = (var.totalCount or 0) + count
        var.totalRecharge = newTotal         --最新的充值金额

        sendBaseInfo(actor, id)
    end
end

local function onConsumeYuanbao(id, conf)
    return function(actor, val)
        if activitymgr.activityTimeIsEnd(id) then return end
        local var = activitymgr.getSubVar(actor, id)
        local count = 0
        local newTotal = (var.totalConsume or 0) + val
        for index = (var.consumeIndex or 0) + 1, #ybCostConfig do
            local value = ybCostConfig[index] or 0
            if value <= newTotal then
                count = count + 1
                var.consumeIndex = index
            end
        end
        var.totalCount = (var.totalCount or 0) + count
        var.totalConsume = newTotal         --最新的消费金额
        sendBaseInfo(actor, id)
    end
end

subactivitymgr.actorLoginFuncs[subType] = function(actor, type, id)
    if activitymgr.activityTimeIsEnd(id) then return end
    sendBaseInfo(actor, id)
    sendRewardLogs(actor, rewardList)
end

local function initFunc(id, conf)
    actorevent.reg(aeNewDayArrive, onNewDay(id, conf))
    actorevent.reg(aeRecharge, onReCharge(id, conf))
    actorevent.reg(aeConsumeYuanbao, onConsumeYuanbao(id, conf))

    LActor.postScriptEventLite(nil, 5 * 60 * 1000, clearRewardLog)
end

subactivitymgr.regConf(subType, ActivityType42Config)
subactivitymgr.regInitFunc(subType, initFunc)
subactivitymgr.regGetRewardFunc(subType, onGetReward)
subactivitymgr.regReqInfoFunc(subType, onReqInfo)
subactivitymgr.regWriteRecordFunc(subType, writeRecord)

---[[
-- 测试