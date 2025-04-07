--BOSS首杀
module("subactivity21", package.seeall)

local subType = 21

local function getSystemVar(id)
    local var = activitymgr.getGlobalVar(id)
    if not var then return end
    for k in pairs(ActivityType21Config[id]) do
        if var[k] == nil then
            var[k] = {}
            var[k].name = ""
            var[k].commontype = 0
        end
    end
    return var
end


local function getStaticVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    for k in pairs(ActivityType21Config[id]) do
        if var[k] == nil then
            var[k] = {}
            var[k].selftype = 0
            var[k].commontype = 0
        end
    end
    return var
end

function c2sSendInfo(actor, pack)
    local activityid = LDataPack.readShort(pack)
    sendInfo(actor, activityid)
end

function getCommonType(data, selfdata, index)
    if data[index].commontype == 1 and selfdata[index].commontype == 2 then
        return selfdata[index].commontype
    end
    return data[index].commontype
end

--发送boss首杀信息
function sendInfo(actor, activityid)
    local data = getSystemVar(activityid)
    local selfdata = getStaticVar(actor, activityid)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Update21)
    LDataPack.writeShort(pack, activityid)
    local pos = LDataPack.getPosition(pack)
    LDataPack.writeShort(pack, 0)
    local count = 0
    for k in pairs(ActivityType21Config[activityid]) do
        count = count + 1
        LDataPack.writeShort(pack, k)
        LDataPack.writeString(pack, data[k].name)
        LDataPack.writeChar(pack, getCommonType(data, selfdata, k))
        LDataPack.writeChar(pack, selfdata[k].selftype)
        LDataPack.writeString(pack, MonstersConfig[DespairBossConfig[k].bossId].name)
        LDataPack.writeString(pack, MonstersConfig[DespairBossConfig[k].bossId].head)
    end
    local pos1 = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, pos)
    LDataPack.writeShort(pack, count)
    LDataPack.setPosition(pack, pos1)
    LDataPack.flush(pack)
end

--更新单个boss首杀信息
function updateInfo(actor, activityid, index)    
    if activitymgr.activityTimeIsEnd(activityid) then return end
    local data = getSystemVar(activityid)
    local selfdata = getStaticVar(actor, activityid)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_UpdateBossInfo)
    LDataPack.writeShort(pack, activityid)
    LDataPack.writeShort(pack, index)
    LDataPack.writeString(pack, data[index].name)
    LDataPack.writeChar(pack, getCommonType(data, selfdata, index))
    LDataPack.writeChar(pack, selfdata[index].selftype)
    LDataPack.flush(pack)
end

--更新伤害第一名
function updateFirstName(firstName, firstActor, bossindex)
    for k,v in pairs(ActivityType21Config) do
        if activitymgr.globalData.activities[k] then            
            for index, conf in pairs(v) do
                if index == bossindex then                    
                    local data = getSystemVar(k)
                    if data[index].name == "" and data[index].commontype == 0 then
                        data[index].name = firstName
                        data[index].commontype = 1
                    end
                    if firstActor then
                        local selfdata = getStaticVar(firstActor, k)                                                
                        if selfdata[index].selftype == 0 then
                            selfdata[index].selftype = 1                            
                        end 
                        updateInfo(firstActor, k, index)                       
                    end
                end
            end
        end
    end
end

--领取奖励
function getReward(actor, pack)
    local activityid = LDataPack.readShort(pack)
    local index = LDataPack.readShort(pack)
    local type = LDataPack.readChar(pack)
    if not activitymgr.globalData.activities[activityid] then return end
    if not ActivityType21Config[activityid] or not ActivityType21Config[activityid][index] then return end
    if type == 0 then
        local name = LActor.getName(actor)
        local data = getSystemVar(activityid)
        local selfdata = getStaticVar(actor, activityid)
        if data[index].commontype ~= 1 or selfdata[index].commontype == 2 then return end
        
        actoritem.addItems(actor, ActivityType21Config[activityid][index].allreward, "first kill despairboss reward")
        selfdata[index].commontype = 2
        updateInfo(actor, activityid, index)
    else
        local selfdata = getStaticVar(actor, activityid)
        if selfdata[index].selftype ~= 1 then return end
        actoritem.addItems(actor, ActivityType21Config[activityid][index].firstreward, "first rank despairboss reward")
        selfdata[index].selftype = 2
        updateInfo(actor, activityid, index)
    end
end

subactivitymgr.actorLoginFuncs[subType] = function(actor, type, activityid)
	if activitymgr.activityTimeIsOver(activityid) then return end
	sendInfo(actor, activityid)
end

--登录协议回调(为免客户端读错，每个活动类型都有)
function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	local v = record and record.data and record.data.rewardsRecord or 0
	LDataPack.writeInt(npack, v)
end

function onInitFnTable()
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Update21, c2sSendInfo)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_GetReward, getReward)
end

onChangeName = function(actor, res, name, rawName, way)
    for k,v in pairs(ActivityType21Config) do
        if activitymgr.globalData.activities[k] then
            for index,conf in pairs(DespairBossConfig) do
                local data = getSystemVar(k)
                if data[index] and data[index].name == rawName then 
                    data[index].name = name
                end
            end
        end
    end
end

function init()
	if System.isCrossWarSrv() then return end
    subactivitymgr.regTimeOut(subType, onTimeOut)
    actorevent.reg(aeChangeName, onChangeName)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    table.insert(InitFnTable, onInitFnTable)
end

table.insert(InitFnTable, init)

