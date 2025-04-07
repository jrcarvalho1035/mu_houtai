--排行榜活动奖励
module("subactivity34", package.seeall)

local subType = 34
local rankNum = 20

minType = {
    shenmo = 1, --神魔
    yongbing = 2, --佣兵
    shenqi = 3, --神器
    wing = 4, --翅膀
    damon = 5, --精灵
    shenzhuang = 6, --神装
    meilin = 7, --梅林
}

local needRank1 = {} -- id -> true
local needRank3 = {}
local minRankList = {}

ACT34LastDayInfo = ACT34LastDayInfo or {}

local function getMinRank(id)
    local n = minRankList[id]
    if n then
        return n
    end
    
    n = ActivityType34Config[id][#ActivityType34Config[id]].ranking[2]
    minRankList[id] = n
    return n
end

local function getIndex(id, rank)
    for k, v in ipairs(ActivityType34Config[id]) do
        if v.ranking[1] <= rank and v.ranking[2] >= rank then
            return k
        end
    end
    return 0
end

local function initValue(id)
    local conf = ActivityType34Config[id]
    if not conf then return 0 end
    if conf[1].subType == 4 then return 1 end
    return 0
end

local function getGlobalData(id)
    local var = activitymgr.getGlobalVar(id)
    if not var then return end
    if not var.updateTime then
        var.updateTime = 0
    end
    if not var.rank then
        var.rank = {}
        var.rankcount = getMinRank(id)
        var.minRankcount = getMinRank(id)
        for i = 1, var.rankcount do
            var.rank[i] = {}
            var.rank[i].score = ActivityType34Config[id][getIndex(id, i)].value
            var.rank[i].name = ""
        end
    end
    
    return var
end

local function clearGlobalData(id)
    activitymgr.clearGlobalVar(id)
end

--发送排名奖励邮件
function sendRankRewards(id, config)
    local gvar = getGlobalData(id)
    print ("subactivity34 rankReward actId: ", id)
    for i = 1, gvar.minRankcount do
        local actor_id = gvar.rank[i].actorid
        print ("rank: ", i, " actorid: ", actor_id, " serverid: ", gvar.rank[i].serverid)
        for k, v in ipairs(config) do
            if actor_id and i >= v.ranking[1] and i <= v.ranking[2] then
                local conf = config[k]
                local mailData = {head = conf.head, context = string.format(conf.context, i), tAwardList = conf.rewards}
                mailsystem.sendMailById(actor_id, mailData, gvar.rank[i].serverid)
                break
            end
        end
        ACT34LastDayInfo[id] = ACT34LastDayInfo[id] or {}
        ACT34LastDayInfo[id][i] = {actorid = actor_id, name = gvar.rank[i].name}
    end
    print ("subactivity34 rankReward count: ", gvar.minRankcount)
    sendFinishInfoAll(id)
end

function On24Hour()
    for id in pairs(ActivityType34Config) do
        if activitymgr.activityTimeIsOver(id) then
            local gvar = getGlobalData(id)
            if gvar then
                gvar.rank = nil
                gvar.rankcount = nil
                gvar.rank1data = nil
            end
        end
    end
end

function onAfterNewDay(actor, id)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.rankopen) then return end
    local now = System.getNowTime()
    local et = activitymgr.getEndTime(id)
    if now - et >= 0 and now - et < 86400 then
        time = et
    else
        return
    end
    if id == 0 then return end
    if ActivityType34Config[id][1].subType ~= 1 then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCAcitivity34Cmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCAcitivity34Cmd_ReqFinishInfo)
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(pack, 0)
    return true
end

local function onReqFinishInfo(sId, sType, cpack)
    if System.isCommSrv() then return end
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    ACT34LastDayInfo[id] = ACT34LastDayInfo[id] or {}
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAcitivity34Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAcitivity34Cmd_SendFinishInfo)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, 10)
    for i = 1, 10 do
        if ACT34LastDayInfo[id][i] and ACT34LastDayInfo[id][i].name ~= "" then
            LDataPack.writeInt(npack, ACT34LastDayInfo[id][i].actorid or 0)
            LDataPack.writeString(npack, ACT34LastDayInfo[id][i].name or "")
        else
            LDataPack.writeInt(npack, 0)
            LDataPack.writeString(npack, ScriptTips.act001)
        end
    end
    LDataPack.writeInt(npack, activitymgr.getEndTime(id))
    System.sendPacketToAllGameClient(npack, sId)
end

function sendFinishInfoAll(id)
    if System.isCommSrv() then return end
    
    ACT34LastDayInfo[id] = ACT34LastDayInfo[id] or {}
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAcitivity34Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAcitivity34Cmd_SendFinishInfoAll)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, 10)
    for i = 1, 10 do
        if ACT34LastDayInfo[id][i] and ACT34LastDayInfo[id][i].name ~= "" then
            LDataPack.writeInt(npack, ACT34LastDayInfo[id][i].actorid or 0)
            LDataPack.writeString(npack, ACT34LastDayInfo[id][i].name or "")
        else
            LDataPack.writeInt(npack, 0)
            LDataPack.writeString(npack, ScriptTips.act001)
        end
    end
    LDataPack.writeInt(npack, activitymgr.getEndTime(id))
    System.sendPacketToAllGameClient(npack, 0)
end

local function onSendFinishInfoAll(sId, sType, cpack)
    if System.isBattleSrv() then return end
    local id = LDataPack.readInt(cpack)
    
    local npack = LDataPack.allocPacket()
    if npack == nil then return end
    LDataPack.writeByte(npack, Protocol.CMD_Activity)
    LDataPack.writeByte(npack, Protocol.sActivityCmd_RankFinish34)
    LDataPack.writeInt(npack, id)
    local count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count)
    for i = 1, count do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
    end
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    System.broadcastData(npack)
end

local function onSendFinishInfo(sId, sType, cpack)
    if System.isBattleSrv() then return end
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_RankFinish34)
    LDataPack.writeInt(npack, id)
    local count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count)
    for i = 1, count do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
    end
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.flush(npack)
end

function onActivityFinish(id)
    if System.isBattleSrv() then
        sendRankRewards(id, ActivityType34Config[id])
    end
    
    local data = getGlobalData(id)
    data.updateTime = System.getNowTime()
end

function sortRank(id, index)
    local gvar = getGlobalData(id)
    local minrank = gvar.minRankcount
    local change = false
    if index <= minrank then
        change = true
    else
        if gvar.rank[index].score >= gvar.rank[minrank].score then
            gvar.rank[minrank], gvar.rank[index] = gvar.rank[index], gvar.rank[minrank]
            change = true
        end
    end
    if not change then return end
    for i = 1, minrank do
        for j = i + 1, minrank do
            if gvar.rank[i].score < gvar.rank[j].score then
                gvar.rank[i], gvar.rank[j] = gvar.rank[j], gvar.rank[i]
                if not gvar.rank[j].actorid then
                    gvar.rank[j].score = ActivityType34Config[id][getIndex(id, j)].value
                end
            elseif gvar.rank[i].score == gvar.rank[j].score and not gvar.rank[i].actorid and gvar.rank[j].actorid then
                gvar.rank[i], gvar.rank[j] = gvar.rank[j], gvar.rank[i]
                if not gvar.rank[j].actorid then
                    gvar.rank[j].score = ActivityType34Config[id][getIndex(id, j)].value
                end
            end
        end
    end
end

function c2sGetRank(actor, pack)
    local id = LDataPack.readInt(pack)
    local actorid = LActor.getActorId(actor)
    if not ActivityType34Config[id] then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCAcitivity34Cmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCAcitivity34Cmd_ReqRank)
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, actorid)
    System.sendPacketToAllGameClient(pack, 0)
end

function onReqRank(sId, sType, cpack)
    if System.isCommSrv() then return end
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    sendRankToCommSrv(id, actorid, sId)
end

function sendRankToCommSrv(id, actorid, sId)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAcitivity34Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAcitivity34Cmd_SendRank)
    if npack == nil then return end
    local myrank = 0
    local myscore = initValue(id)
    local gvar = getGlobalData(id)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeShort(npack, gvar.minRankcount)
    for i = 1, gvar.rankcount do
        local data = gvar.rank[i]
        if gvar.minRankcount >= i then
            LDataPack.writeString(npack, data.name)
            LDataPack.writeDouble(npack, data.score)
        end
        if data.actorid and data.actorid == actorid then
            myrank = gvar.minRankcount >= i and i or 0
            myscore = data.score
        end
    end
    LDataPack.writeShort(npack, myrank)
    LDataPack.writeDouble(npack, myscore)
    System.sendPacketToAllGameClient(npack, sId)
end

function onSendRank(sId, sType, cpack)
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Info34)
    if npack == nil then return end
    local myrank = 0
    local myscore = 0
    LDataPack.writeInt(npack, id)
    local count = LDataPack.readShort(cpack)
    LDataPack.writeShort(npack, count)
    for i = 1, count do
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
    end
    LDataPack.writeShort(npack, LDataPack.readShort(cpack))
    LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
    
    LDataPack.flush(npack)
end

local function onCostItem(actor, itemid, count)
    if System.isBattleSrv() then
        for id, v in pairs(ActivityType34Config) do
            if not activitymgr.activityTimeIsEnd(id) and v[1].itemid == itemid then
                updateScore(id, LActor.getActorId(actor), 10 * count, LActor.getServerId(actor), LActor.getName(actor))
            end
        end
    else
        for id, v in pairs(ActivityType34Config) do
            if not activitymgr.activityTimeIsEnd(id) and v[1].itemid == itemid then
                local pack = LDataPack.allocPacket()
                LDataPack.writeByte(pack, CrossSrvCmd.SCAcitivity34Cmd)
                LDataPack.writeByte(pack, CrossSrvSubCmd.SCAcitivity34Cmd_UpdateScore)
                LDataPack.writeInt(pack, id)
                LDataPack.writeInt(pack, LActor.getActorId(actor))
                LDataPack.writeInt(pack, 10 * count)
                LDataPack.writeInt(pack, LActor.getServerId(actor))
                LDataPack.writeString(pack, LActor.getName(actor))
                System.sendPacketToAllGameClient(pack, 0)
                break
            end
        end
    end
end

function addValue(actor, addVal, subType)
    if subType == nil then
        subType = 1 -- 飞升
    end
    
    if System.isBattleSrv() then
        for id, conf in pairs(ActivityType34Config) do
            if conf[1].subType == subType and (not activitymgr.activityTimeIsEnd(id)) then
                updateScore(id, LActor.getActorId(actor), addVal, LActor.getServerId(actor), LActor.getName(actor))
            end
        end
    else
        for id, conf in pairs(ActivityType34Config) do
            if conf[1].subType == subType and (not activitymgr.activityTimeIsEnd(id)) then
                local pack = LDataPack.allocPacket()
                LDataPack.writeByte(pack, CrossSrvCmd.SCAcitivity34Cmd)
                LDataPack.writeByte(pack, CrossSrvSubCmd.SCAcitivity34Cmd_UpdateScore)
                LDataPack.writeInt(pack, id)
                LDataPack.writeInt(pack, LActor.getActorId(actor))
                LDataPack.writeInt(pack, addVal)
                LDataPack.writeInt(pack, LActor.getServerId(actor))
                LDataPack.writeString(pack, LActor.getName(actor))
                System.sendPacketToAllGameClient(pack, 0)
            end
        end
    end
end

function onRecvUpdate(sId, sType, cpack)
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local score = LDataPack.readInt(cpack)
    local serverid = LDataPack.readInt(cpack)
    local name = LDataPack.readString(cpack)
    local fromId = LDataPack.readInt(cpack)
    updateScore(id, actorid, score, serverid, name)
end

function updateScore(id, actorid, score, serverid, actorName)
    if System.isCommSrv() then return end
    local gvar = getGlobalData(id)
    local index
    for k, v in pairs(gvar.rank) do
        if v.actorid and v.actorid == actorid then
            v.score = v.score + score
            index = k
            break
        end
    end
    
    if not index then
        gvar.rankcount = gvar.rankcount + 1
        gvar.rank[gvar.rankcount] = {
            actorid = actorid,
            score = initValue(id) + score,
            name = actorName,
            serverid = serverid
        }
        index = gvar.rankcount
    end
    local actor_old = getRank1ActorId(id)
    sortRank(id, index)
    sendRankToCommSrv(id, actorid, serverid)
    
    if needRank1[id] then
        local actor_new = getRank1ActorId(id)
        if actor_old ~= actor_new then
            newRank1Data(id)
            sendServerNeedRank1(getRank1ServerId(id), id, actor_new)
        end
    end
    
    if needRank3[id] then
        sendServerRank3(id)
    end
end

function sendServerRank3(id)
    local list = {}
    local gvar = getGlobalData(id)
    for i = 1, 3 do
        local actorid = gvar.rank[i].actorid
        if actorid then
            table.insert(list, {actorid, i})
        end
    end
    
    if #list <= 0 then
        return
    end
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAcitivity34Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAcitivity34Cmd_SendServerRank3)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, #list)
    for _, t in ipairs(list) do
        LDataPack.writeInt(npack, t[1])
        LDataPack.writeInt(npack, t[2])
    end
    System.sendPacketToAllGameClient(npack, 0)
end

function sendServerNeedRank1(server_id, id, actor_id)
    if server_id <= 0 then
        return
    end
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAcitivity34Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAcitivity34Cmd_SendServerNeedRank1)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, actor_id)
    System.sendPacketToAllGameClient(npack, server_id)
end

local function readRank1(pack, clear)
    local id = LDataPack.readInt(pack)
    local actor_id = LDataPack.readInt(pack)
    local rank1 = getRank1Data(id, clear)
    rank1.id = id
    rank1.actorid = actor_id
    rank1.job = LDataPack.readChar(pack)
    rank1.shenzhuangchoose = LDataPack.readInt(pack)
    rank1.shenqichoose = LDataPack.readInt(pack)
    rank1.wingchoose = LDataPack.readInt(pack)
    rank1.touxian = LDataPack.readInt(pack)
    rank1.title = LDataPack.readInt(pack)
    rank1.mozhen = LDataPack.readInt(pack)
    rank1.damonchoose = LDataPack.readInt(pack)
    rank1.meilinchoose = LDataPack.readInt(pack)
    
    return rank1
end

local function onCrossRank1(sId, sType, pack)
    readRank1(pack, 'clear')
end

local function writeRank1(npack, id, actor_id, data)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, actor_id)
    LDataPack.writeChar(npack, data.job)
    LDataPack.writeInt(npack, data.shenzhuangchoose)
    LDataPack.writeInt(npack, data.shenqichoose)
    LDataPack.writeInt(npack, data.wingchoose)
    LDataPack.writeInt(npack, data.touxian)
    LDataPack.writeInt(npack, data.title or 0)
    LDataPack.writeInt(npack, data.mozhen or 0)
    LDataPack.writeInt(npack, data.damonchoose)
    LDataPack.writeInt(npack, data.meilinchoose)
end

local function sendServerRank1(id, actor_id, rank1)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAcitivity34Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAcitivity34Cmd_SendServerRank1)
    writeRank1(npack, id, actor_id, rank1)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onServerRank1(sId, sType, pack)
    local rank1 = readRank1(pack)
    sendServerRank1(rank1.id, rank1.actorid, rank1)
end

local function sendCrossRank1(server_id, id, actor_id, actorData)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAcitivity34Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAcitivity34Cmd_SendCrossRank1)
    writeRank1(npack, id, actor_id, actorData)
    System.sendPacketToAllGameClient(npack, server_id)
end

local function onCrossNeedRank1(sId, sType, pack)
    local id = LDataPack.readInt(pack)
    local actor_id = LDataPack.readInt(pack)
    local actorData = offlinedatamgr.GetDataByOffLineDataType(actor_id, offlinedatamgr.EOffLineDataType.EBasic)
    if actorData then
        sendCrossRank1(sId, id, actor_id, actorData)
    else
        print('subactivity34.onCrossNeedRank1 actorData==nil actor_id=', actor_id)
    end
end

function newRank1Data(id)
    local gvar = getGlobalData(id)
    local data = gvar.rank[1]
    if data then
        local rank1 = getRank1Data(id)
        rank1.actorid = data.actorid
        rank1.name = data.name
        rank1.serverid = data.serverid
    end
end

function getRank1Data(id, clear)
    local gvar = getGlobalData(id)
    if (not gvar.rank1data) or clear then
        gvar.rank1data = {}
    end
    return gvar.rank1data
end

function getRank1ActorId(id)
    local gvar = getGlobalData(id)
    local data = gvar.rank[1]
    if data then
        return data.actorid
    end
    return 0
end

function getRank1ServerId(id)
    local gvar = getGlobalData(id)
    local data = gvar.rank[1]
    if data then
        return data.serverid
    end
    return 0
end

local function onCrossRank3(sId, sType, pack)
    local id = LDataPack.readInt(pack)
    local count = LDataPack.readInt(pack)
    local rank3 = getRank3Data(id, 'clear')
    for i = 1, count do
        local actor_id = LDataPack.readInt(pack)
        local k = LDataPack.readInt(pack)
        if 0 < actor_id then
            rank3[actor_id] = k
        end
    end
end

function getRank3Data(id, clear)
    local gvar = getGlobalData(id)
    if (not gvar.rank3data) or clear then
        gvar.rank3data = {}
    end
    return gvar.rank3data
end

function isRank3(id, actor_id)
    local rank3 = getRank3Data(id)
    return rank3[actor_id] ~= nil
end

function getRank3Index(id, actor_id)
    local rank3 = getRank3Data(id)
    return rank3[actor_id]
end

function checkEndTime()
    for id in pairs(ActivityType34Config) do
        local now = System.getNowTime()
        local et = activitymgr.getEndTime(id)
        local data = getGlobalData(id)
        -- 如果配置的活动没有开启，从activitymgr.getGlobalVar为nil
        -- 则getGlobalData取出nil
        if data then
            if et ~= 0 and now - et > 0 and data.updateTime < et then
                onActivityFinish(id)
            end
        end
    end
end

function reset()
    for id in pairs(ActivityType34Config) do
        clearGlobalData(id)
    end
end

function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local v = record and record.data and record.data.rewardsRecord or 0
    LDataPack.writeInt(npack, v)
end

function onNewDay(actor, record, config, id)
    onAfterNewDay(actor, id)
end

function onChangeName(actorid, name)
    for id in pairs(ActivityType34Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local gvar = getGlobalData(id)
            for _, v in pairs(gvar.rank) do
                if v.actorid and v.actorid == actorid then
                    v.name = name
                    break
                end
            end
        end
    end
end

function onConnected(sId, sType)
    if System.isCommSrv() then return end
    if csbase.checkAllConnect() then
        checkEndTime()
    end
end

local function c2sGetRank1(actor, reader)
    local id = LDataPack.readInt(reader)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_GetRank1)
    if pack then
        LDataPack.writeInt(pack, id)
        local rank1 = getRank1Data(id)
        if rank1.actorid then
            LDataPack.writeByte(pack, 1)
            
            LDataPack.writeChar(pack, rank1.job)
            LDataPack.writeInt(pack, rank1.shenzhuangchoose)
            LDataPack.writeInt(pack, rank1.shenqichoose)
            LDataPack.writeInt(pack, rank1.wingchoose)
            LDataPack.writeInt(pack, rank1.touxian)
            LDataPack.writeInt(pack, rank1.title or 0)
            LDataPack.writeInt(pack, rank1.mozhen or 0)
            LDataPack.writeInt(pack, rank1.damonchoose)
            LDataPack.writeInt(pack, rank1.meilinchoose)
        else
            LDataPack.writeByte(pack, 0) -- no data
        end
        LDataPack.flush(pack)
    end
end

subactivitymgr.regWriteRecordFunc(subType, writeRecord)
subactivitymgr.regActivityFinish(subType, onActivityFinish)
subactivitymgr.regNewDayFunc(subType, onNewDay)

local function init()
    if System.isLianFuSrv() then return end
    needRank1 = {}
    needRank3 = {}
    for id, conf in pairs(ActivityType34Config) do
        local need = conf[1].rank1 or 0
        if need ~= 0 then
            needRank1[id] = true
        end
        
        need = conf[1].rank3 or 0
        if need ~= 0 then
            needRank3[id] = true
        end
    end
    
    csbase.RegConnected(onConnected)
    actorevent.reg(aeCostItem, onCostItem)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Info34, c2sGetRank)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_GetRank1, c2sGetRank1)
    csmsgdispatcher.Reg(CrossSrvCmd.SCAcitivity34Cmd, CrossSrvSubCmd.SCAcitivity34Cmd_ReqFinishInfo, onReqFinishInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCAcitivity34Cmd, CrossSrvSubCmd.SCAcitivity34Cmd_SendFinishInfo, onSendFinishInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCAcitivity34Cmd, CrossSrvSubCmd.SCAcitivity34Cmd_SendFinishInfoAll, onSendFinishInfoAll)
    csmsgdispatcher.Reg(CrossSrvCmd.SCAcitivity34Cmd, CrossSrvSubCmd.SCAcitivity34Cmd_SendRank, onSendRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCAcitivity34Cmd, CrossSrvSubCmd.SCAcitivity34Cmd_ReqRank, onReqRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCAcitivity34Cmd, CrossSrvSubCmd.SCAcitivity34Cmd_UpdateScore, onRecvUpdate)
    csmsgdispatcher.Reg(CrossSrvCmd.SCAcitivity34Cmd, CrossSrvSubCmd.SCAcitivity34Cmd_SendCrossRank1, onServerRank1)
    if System.isCommSrv() then
        csmsgdispatcher.Reg(CrossSrvCmd.SCAcitivity34Cmd, CrossSrvSubCmd.SCAcitivity34Cmd_SendServerNeedRank1, onCrossNeedRank1)
        csmsgdispatcher.Reg(CrossSrvCmd.SCAcitivity34Cmd, CrossSrvSubCmd.SCAcitivity34Cmd_SendServerRank1, onCrossRank1)
        csmsgdispatcher.Reg(CrossSrvCmd.SCAcitivity34Cmd, CrossSrvSubCmd.SCAcitivity34Cmd_SendServerRank3, onCrossRank3)
    end
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.sendact34Rewards = function (actor, args)
    sendRankRewards(602, ActivityType34Config[1004])
end

gmCmdHandlers.act34UseItem = function(actor, args)
    local count = tonumber(args[1])
    onCostItem(actor, 1071001, count)
    return true
end

gmCmdHandlers.act34Update = function(actor, args)
    local actId = tonumber(args[1])
    local addVal = tonumber(args[2])
    if not actId then return end
    if not addVal then return end
    updateScore(actId, LActor.getActorId(actor), addVal, LActor.getServerId(actor), LActor.getName(actor))
    return true
end

