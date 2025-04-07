--国庆砸蛋
module("subactivity38", package.seeall)

local subType = 38

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.drawCounts then var.drawCounts = {} end
    return var
end

function getDropIdByCount(count, config)
    for _, conf in ipairs(config.rewardPool) do
        if count <= conf.count then
            return conf.dropId
        end
    end
    return config.rewardPool[1].dropId
end

function getMaxDrawCount(config)
    return config.rewardPool[#config.rewardPool].count
end

local function c2sDraw(actor, pack)
    local id = LDataPack.readInt(pack)
    local index = LDataPack.readChar(pack)
    local drawType = LDataPack.readChar(pack)
    
    if activitymgr.activityTimeIsEnd(id) then return end
    
    local config = ActivityType38Config[id] and ActivityType38Config[id][index]
    if not config then return end
    
    local var = getActorVar(actor, id)
    if not var then return end
    
    local conf = config.drawCount[drawType]
    if not conf then return end
    local times, needCount = conf[1], conf[2]
    if not actoritem.checkItem(actor, config.costItemId, needCount) then
        return
    end
    actoritem.reduceItem(actor, config.costItemId, needCount, "activity type38")
    actoritem.addItem(actor, config.giveItemId, config.giveItemCount * times, "activity type38")
    
    local maxDrawCount = getMaxDrawCount(config)
    local items = {}
    local drawCount = var.drawCounts[index] or 0
    for i = 1, times do
        drawCount = drawCount + 1
        local dropId = getDropIdByCount(drawCount, config)
        local rewards = drop.dropGroup(dropId)
        for _, reward in ipairs(rewards) do
            table.insert(items, reward)
        end
        if drawCount >= maxDrawCount then
            drawCount = 0
        end
    end
    var.drawCounts[index] = drawCount
    actoritem.addItems(actor, items, "activity type38 rewards")
    
    local score = (config.score or 0) * times
    subactivity1.addZaDanScore(actor, score)
    subactivity34.addValue(actor, score, 2)
    
    s2cDrawRewardInfo(actor, id, index, drawCount, items)
    --s2cDrawCountInfo(actor, id)
end

function s2cDrawRewardInfo(actor, id, index, drawCount, items)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Draw38)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, index)
    LDataPack.writeInt(npack, drawCount)
    LDataPack.writeChar(npack, #items)
    for k, v in ipairs(items) do
        LDataPack.writeInt(npack, v.id)
        LDataPack.writeInt(npack, v.count)
    end
    LDataPack.flush(npack)
end

function s2cDrawCountInfo(actor, id)
    local var = getActorVar(actor, id)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Act18Info)
    if not pack then return end
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, var.drawCount)
    LDataPack.flush(pack)
end

local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local var = getActorVar(actor, id)
    LDataPack.writeChar(npack, #config)
    for index in ipairs(config) do
        LDataPack.writeChar(npack, index)
        LDataPack.writeInt(npack, var.drawCounts[index] or 0)
    end
end

local function init()
    if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Draw38, c2sDraw)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
end
table.insert(InitFnTable, init)
