--超级转盘
module("subactivity35", package.seeall)

ACT35_RECORD = ACT35_RECORD or {}
ACT35_SELF_RECORD = ACT35_SELF_RECORD or {}
local MAX_RECORD = 20
local subType = 35

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.recharge then var.recharge = 0 end --充值钻石数，用于记录
    if not var.rechargeCount then var.rechargeCount = 0 end --充值次数，用于抽奖
    if not var.drawCount then var.drawCount = 0 end --抽奖次数，用于记录
    return var
end

function getIndexByCount(var, config, count)
    for idx, conf in ipairs(config) do
        if count >= conf.min and count <= conf.max then
            return idx
        end
    end
    --如果找不到奖池则从头开始(循环)
    var.drawCount = 1
    return 1
end

function drawRecord(actor, id, item, isRecord)
    local actorid = LActor.getActorId(actor)
    if not ACT35_SELF_RECORD[id] then ACT35_SELF_RECORD[id] = {} end
    if not ACT35_SELF_RECORD[id][actorid] then ACT35_SELF_RECORD[id][actorid] = {} end
    table.insert(ACT35_SELF_RECORD[id][actorid], 1, {name = LActor.getName(actor), id = item.id, count = item.count})
    if #ACT35_SELF_RECORD[id][actorid] > MAX_RECORD then
        table.remove(ACT35_SELF_RECORD[id][actorid])
    end
    if isRecord then --大奖则加入全服记录
        if not ACT35_RECORD[id] then ACT35_RECORD[id] = {} end
        table.insert(ACT35_RECORD[id], 1, {name = LActor.getName(actor), id = item.id, count = item.count})
        if #ACT35_RECORD[id] > MAX_RECORD then
            table.remove(ACT35_RECORD[id])
        end
    end
end

local function c2sDraw(actor, pack)
    local id = LDataPack.readInt(pack)
    local times = LDataPack.readChar(pack)

    if activitymgr.activityTimeIsEnd(id) then return end
    if not ActivityType35Config[id] then return end

    if times <= 0 then return end

    local var = getActorVar(actor, id)
    if times > var.rechargeCount then return end
    
    local items = {}
    local order = 0
    for i = 1, times do
        var.rechargeCount = var.rechargeCount - 1
        var.drawCount = var.drawCount + 1
        local rand = System.getRandomNumber(10000) + 1
        local index = getIndexByCount(var, ActivityType35Config[id], var.drawCount)
        local config = ActivityType35Config[id][index]
        for idx, item in ipairs(config.reward) do
            if rand <= item.rate then
                order = idx
                table.insert(items, {type = item.type, id = item.id, count = item.count})
                local isRecord = order == config.good or order == config.super
                drawRecord(actor, id, item, isRecord)
                print("times: ",i ,"index: ", index, "darw order: ",order, "rechargeCount: ",var.rechargeCount, "drawCount: ",var.drawCount)
                break
            else
                rand = rand - item.rate
            end
        end
    end
    actoritem.addItems(actor, items, "activity type35 rewards", 1)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Draw35)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, order)
    LDataPack.writeInt(npack, var.rechargeCount)
    LDataPack.writeChar(npack, #items)
    for k, v in ipairs(items) do
        LDataPack.writeInt(npack, v.id)
        LDataPack.writeInt(npack, v.count)
    end
    LDataPack.flush(npack)
    actorevent.onEvent(actor, aeAct35Draw, times)
end

local function c2sRecord(actor, pack)
    local id = LDataPack.readInt(pack)
    local record_type = LDataPack.readChar(pack)
    if not ActivityType35Config[id] then return end
    s2cRecordInfo(actor, id, record_type)
end

function s2cRecordInfo(actor, id, record_type)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Record35)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, record_type)
    if record_type == 1 then
        local actorid = LActor.getActorId(actor)
        if not ACT35_SELF_RECORD[id] then ACT35_SELF_RECORD[id] = {} end
        if not ACT35_SELF_RECORD[id][actorid] then ACT35_SELF_RECORD[id][actorid] = {} end
        LDataPack.writeChar(npack, #ACT35_SELF_RECORD[id][actorid])
        for _, list in ipairs(ACT35_SELF_RECORD[id][actorid]) do
            LDataPack.writeString(npack, list.name)
            LDataPack.writeInt(npack, list.id)
            LDataPack.writeInt(npack, list.count)
        end
    else
        if not ACT35_RECORD[id] then ACT35_RECORD[id] = {} end
        LDataPack.writeChar(npack, #ACT35_RECORD[id])
        for _, list in ipairs(ACT35_RECORD[id]) do
            LDataPack.writeString(npack, list.name)
            LDataPack.writeInt(npack, list.id)
            LDataPack.writeInt(npack, list.count)
        end
    end
    LDataPack.flush(npack)
end

local function onRecharge(actor, count)
    for id, config in pairs(ActivityType35Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local var = getActorVar(actor, id)
            var.recharge = var.recharge + count
            local num = math.floor(var.recharge / ActivityCommonConfig.act35Recharge)
            var.recharge = var.recharge - num * ActivityCommonConfig.act35Recharge
            var.rechargeCount = var.rechargeCount + num
            s2cDrawCountInfo(actor, id)
        end
    end
end

function s2cDrawCountInfo(actor, id)
    local var = getActorVar(actor, id)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Info35)
    if not pack then return end
    LDataPack.writeInt(pack, id)
    LDataPack.writeShort(pack, var.rechargeCount)
    LDataPack.flush(pack)
end

local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local var = getActorVar(actor, id)
    LDataPack.writeInt(npack, var.rechargeCount)
end

local function onActivityFinish(id)
    ACT35_RECORD[id] = {}
    ACT35_SELF_RECORD[id] = {}
end

local function init()
    if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Draw35, c2sDraw)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Record35, c2sRecord)
end

table.insert(InitFnTable, init)
actorevent.reg(aeRecharge, onRecharge)
subactivitymgr.regWriteRecordFunc(subType, writeRecord)
subactivitymgr.regActivityFinish(subType, onActivityFinish)


