-- 道具兑换
module("subactivity26", package.seeall)

local subType = 26

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    
    if not var.buy then
        var.buy = {}
    end
    
    if not var.remind then
        var.remind = {}
    end
    
    return var
end

local function onNewDay(actor, record, config, id, login)
    local var = getActorVar(actor, id)
    local now = System.getNowTime()
    local isSameWeek = System.isSameWeek(now, var.refresh_week_time or 0)
    local now_time = System.getNowTime()
    
    local list = config[id]
    for k, conf in pairs(list) do
        local dtype = conf.daycount.type
        if dtype == 1 then
            var.buy[k] = nil
        elseif dtype == 2 and not isSameWeek then
            var.buy[k] = nil
            var.refresh_week_time = now_time
        end
    end
    
    activitymgr.sendActivityInfo(actor, id, login)
end

local function writeRecord(npack, record, config, id, actor)
    local var = getActorVar(actor, id)
    LDataPack.writeByte(npack, #config)
    for k, conf in ipairs(config) do
        LDataPack.writeByte(npack, k)
        LDataPack.writeShort(npack, var.buy[k] or 0)
        LDataPack.writeByte(npack, var.remind[k] or conf.select) -- 默认提醒
    end
end

local function buy(actor, config, id, idx, count)
    local actor_id = LActor.getActorId(actor)
    local list = ActivityType26Config[id]
    if list == nil then
        print('subactivity26.buy list==nil id=', id, 'actor_id=', actor_id)
        return
    end
    
    local conf = list[idx]
    if conf == nil then
        print('subactivity26.buy conf==nil id=', id, 'idx=', idx, 'actor_id=', actor_id)
        return
    end
    
    if not actoritem.checkBagSpaceByItem(actor, conf.itemid, conf.count * count) then
        return
    end
    
    local var = getActorVar(actor, id)
    local dcount = conf.daycount.count
    local old = var.buy[idx] or 0
    if dcount < old + count then
        print('subactivity26.buy bad old=', old, 'count=', count, 'dcount=', dcount, 'id=', id, 'idx=', idx, 'actor_id=', actor_id)
        return
    end
    
    if not actoritem.checkItem(actor, conf.needitem, conf.needcount * count) then
        print('subactivity26.buy checkItem fail id=', id, 'idx=', idx, 'actor_id=', actor_id)
        return
    end
    
    if not actoritem.reduceItem(actor, conf.needitem, conf.needcount * count, 'type26') then
        print('subactivity26.buy reduceItem fail id=', id, 'idx=', idx, 'actor_id=', actor_id)
        return
    end
    
    local new = old + count
    var.buy[idx] = new
    
    actoritem.addItem(actor, conf.itemid, conf.count * count, 'type26buy')
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
    if pack then
        LDataPack.writeByte(pack, 1) -- 成功
        LDataPack.writeInt(pack, id)
        LDataPack.writeShort(pack, idx)
        LDataPack.writeShort(pack, 0) -- 购买
        LDataPack.writeShort(pack, new)
        LDataPack.flush(pack)
    end
end

local function setRemind(actor, config, id, idx, flag)
    local var = getActorVar(actor, id)
    var.remind[idx] = flag
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
    if pack then
        LDataPack.writeByte(pack, 1) -- 成功
        LDataPack.writeInt(pack, id)
        LDataPack.writeShort(pack, idx)
        LDataPack.writeShort(pack, 1) -- 提醒
        LDataPack.writeShort(pack, flag)
        LDataPack.flush(pack)
    end
end

local function getReward(actor, config, id, idx, record, reader)
    local param1 = LDataPack.readShort(reader)
    local param2 = LDataPack.readShort(reader)
    
    if param1 == 0 then -- 购买
        buy(actor, config, id, idx, param2)
    else -- 提醒
        setRemind(actor, config, id, idx, param2)
    end
end

local function initGlobalData()
    subactivitymgr.regNewDayFunc(subType, onNewDay)
    subactivitymgr.regGetRewardFunc(subType, getReward)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
end
table.insert(InitFnTable, initGlobalData)
