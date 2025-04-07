module("subactivity25", package.seeall)

local subType = 25

DIALRECORD = DIALRECORD or {}
MAX_DIALRECORD = 100

local function getStaticData(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.pay then var.pay = 0 end
	return var
end


--记录数据
local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local v = record and record.data and record.data.rewardsRecord or 0
    LDataPack.writeInt(npack, v)
end

function onDialDraw(actor)
    local actId = 0
    for id,v in pairs(ActivityType25Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            actId = id
            break
        end
    end
    if actId == 0 then return end

    if activitymgr.activityTimeIsEnd(actId) then return end
    local record = activitymgr.getSubVar(actor, actId)
    local var = getStaticData(actor, actId)
    if not record.data then
        record.data = {}
    end
    if not record.data.rewardsRecord then
        record.data.rewardsRecord = 0
    end
    local times = record.data.rewardsRecord
    local config = ActivityType25Config[actId][times + 1]
    if not config then return end
    if var.pay < config.pay then return end
    
    if not actoritem.checkItem(actor, NumericType_YuanBao, config.base) then
        return
    end
    --subactivity1.regainConsumeYuanbao(actor, config.base)
    --subactivity8.regainConsumeYuanbao(actor, config.base)
    --subactivity24.regainConsumeYuanbao(actor, config.base)
    actoritem.reduceItem(actor, NumericType_YuanBao, config.base, "diral draw")

    record.data.rewardsRecord = (record.data.rewardsRecord or 0) + 1
    local total = 0
    local index = 1
    local rand = math.random(1, 10000)
    for k,v in ipairs(config.multiple) do
        total = total + v[2]
        if rand < total then
            index = k
            break
        end
    end
    actoritem.addItem(actor, NumericType_YuanBao, math.floor(config.base * config.multiple[index][1]), "diral draw", 1)

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_DialDraw)
    LDataPack.writeInt(pack, actId)
    LDataPack.writeChar(pack, index)
    LDataPack.writeInt(pack, math.floor(config.base * config.multiple[index][1]))
    LDataPack.writeInt(pack, times + 1)
    LDataPack.flush(pack)

    addRecord(actor, config.multiple[index][1], math.floor(config.base * config.multiple[index][1]))
end

function addRecord(actor, multiple, yuanbao)
    local tmp = {}
    tmp.time = System.getNowTime()
    tmp.name = LActor.getName(actor)
    tmp.multiple = multiple
    tmp.yuanbao = yuanbao
    table.insert(DIALRECORD, 1, tmp)
    if #DIALRECORD > MAX_DIALRECORD then
        DIALRECORD[#DIALRECORD] = nil
    end
end

function onGetRecord(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_DialRecord)
    LDataPack.writeShort(pack, #DIALRECORD)
    for k,v in ipairs(DIALRECORD) do
        LDataPack.writeInt(pack, v.time)
        LDataPack.writeString(pack, v.name)
        LDataPack.writeDouble(pack, v.multiple)    
        LDataPack.writeInt(pack, v.yuanbao)
    end
    LDataPack.flush(pack)
end

function sendPayInfo(actor, actId)
    local var = getStaticData(actor, actId)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Update15)
	if npack == nil then return end

    LDataPack.writeInt(npack, actId)
	LDataPack.writeInt(npack, var.pay or 0)
	LDataPack.flush(npack)
end

local function onRecharge(actor, count)
    for id,v in pairs(ActivityType25Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local var = getStaticData(actor, id)
            var.pay = var.pay + count
            sendPayInfo(actor, id)
            break
        end
    end
end

function onAfterNewDay(actor)
    for id,v in pairs(ActivityType25Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            sendPayInfo(actor, id)
            break
        end
    end
end

subactivitymgr.actorLoginFuncs[subType] = function(actor, type, id)
    if activitymgr.activityTimeIsOver(id) then return end
    sendPayInfo(actor, id)
end

function init()
	if System.isCrossWarSrv() then return end
    subactivitymgr.regTimeOut(subType, onTimeOut)
    actorevent.reg(aeRecharge, onRecharge)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    subactivitymgr.regGetRewardFunc(subType, onGetReward)
    subactivitymgr.regNewDayAfterFunc(subType, onAfterNewDay)
    --subactivitymgr.regNewDayFunc(subType, onBeforeNewDay)
end

table.insert(InitFnTable, init)

netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_DialDraw, onDialDraw)
netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_GetDialRecord, onGetRecord)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.clear25 = function (actor, args)
    local actId = 0
    for id,v in pairs(ActivityType25Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            actId = id
            break
        end
    end
    if actId == 0 then return end

    if activitymgr.activityTimeIsEnd(actId) then return end
    local mgrvar = activitymgr.getStaticData(actor)
    local var = getStaticData(actor, actId)
    if not mgrvar.records[actId] then
        mgrvar.records[actId] = {}
    end
    if not mgrvar.records[actId].data then
        mgrvar.records[actId].data = {}
    end

    mgrvar.records[actId].data.rewardsRecord = 0
    activitymgr.s2cActivityInfo(actor)
	return true
end
