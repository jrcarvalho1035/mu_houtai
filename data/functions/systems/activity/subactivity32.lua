--跨服服务器排名
module("subactivity32", package.seeall)

local subType = 32
local rankNum = 10

minType = {
    yuanbaodraw = 1, --钻石夺宝
}

local function getGlobalData(id)
    local var = activitymgr.getGlobalVar(id)
    if not var then return end
    if not var.rank or not var.rankcount then
        var.rank = {}
        var.rankcount = #ActivityType32Config[id]
        for i = 1, var.rankcount do
            var.rank[i] = {}
            var.rank[i].score = ActivityType32Config[id][i].score
        end
    end
    if not var.updateTime then var.updateTime = 0 end
    if not var.minRankcount then var.minRankcount = #ActivityType32Config[id] end
    return var
end

function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local v = record and record.data and record.data.rewardsRecord or 0
    LDataPack.writeInt(npack, v)
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
                if not gvar.rank[i].serverid then
                    gvar.rank[i].score = 0
                end
                gvar.rank[i], gvar.rank[j] = gvar.rank[j], gvar.rank[i]
            elseif gvar.rank[i].score == gvar.rank[j].score and not gvar.rank[i].serverid and gvar.rank[j].serverid then
                gvar.rank[i].score = 0
                gvar.rank[i], gvar.rank[j] = gvar.rank[j], gvar.rank[i]
            end
        end
    end
    for i = minrank, 1, -1 do
        if not gvar.rank[i].serverid then
            gvar.rank[i].score = ActivityType32Config[id][i].score
        end
    end
end

function updateServerScore(type, serverid, selfaddscore)
    for id, v in pairs(ActivityType32Config) do
        if type == v[1].subType then --and not activitymgr.activityTimeIsEnd(id) then
            local index
            local gvar = getGlobalData(id)
            for k, v in pairs(gvar.rank) do
                if v.serverid and v.serverid == serverid then
                    v.score = v.score + selfaddscore
                    index = k
                    break
                end
            end
            if not index then
                gvar.rankcount = gvar.rankcount + 1
                gvar.rank[gvar.rankcount] = {}
                gvar.rank[gvar.rankcount].serverid = serverid
                gvar.rank[gvar.rankcount].score = selfaddscore
                index = gvar.rankcount
            end
            sortRank(id, index)
            break
        end
    end
end

function getRank(actor, pack)
    local id = LDataPack.readInt(pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCYuanbaoDrawCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCYuanbaoDrawCmd_GetServerRank)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

--跨服收到请求排行数据
function onGetServerRank(sId, sType, cpack)
    print("... onGetServerRank")
    if System.isCommSrv() then return end
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    
    local gvar = getGlobalData(id)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCYuanbaoDrawCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCYuanbaoDrawCmd_SendServerRank)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, actorid)
    local myrank = 0
    local myscore = 0
    for i = 1, gvar.rankcount do
        if gvar.rank[i].serverid and gvar.rank[i].serverid == sId then
            myrank = i
            myscore = gvar.rank[i].score
        end
    end
    local count = math.min(rankNum, gvar.rankcount)
    LDataPack.writeChar(npack, count)
    for i = 1, count do
        LDataPack.writeString(npack, chatcommon.getServerNameBySId(gvar.rank[i].serverid))
        LDataPack.writeInt(npack, gvar.rank[i].score)
    end
    LDataPack.writeChar(npack, myrank)
    LDataPack.writeInt(npack, myscore)
    System.sendPacketToAllGameClient(npack, sId)
end

--普通服收到排行数据
function onSendServerRank(sId, sType, cpack)
    print("... onSendServerRank")
    if System.isBattleSrv() then return end
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_YuanbaoDrawServerRank)
    if npack == nil then return end
    local count = LDataPack.readChar(cpack)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, count)
    for i = 1, count do
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    end
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.flush(npack)
end

function onActivityFinish(id)
    if System.isCommSrv() then return end
    local config = ActivityType32Config
    local gvar = getGlobalData(id)
    local svar = subactivity30.getSelfRankByType(config[id][1].subType)
    local count = math.min(gvar.rankcount, #config[id])
    print ("subactivity32 rankReward actId: ", id)
    for i = 1, count do
        print ("rank: ", i, " serverid: ", gvar.rank[i].serverid)
        if gvar.rank[i].serverid then
            local actorcount = 0
            local actors = {}
            if svar then
                for j = 1, svar.rankcount do
                    if svar.rank[j].serverid and svar.rank[j].serverid == gvar.rank[i].serverid and svar.rank[j].actorid
                        and svar.rank[j].score >= 1000 then
                        actorcount = actorcount + 1
                        actors[actorcount] = svar.rank[j].actorid
                    end
                end
            end
            local npack = LDataPack.allocPacket()
            LDataPack.writeByte(npack, CrossSrvCmd.SCYuanbaoDrawCmd)
            LDataPack.writeByte(npack, CrossSrvSubCmd.SCYuanbaoDrawCmd_ActivityServerFinish)
            LDataPack.writeInt(npack, id)
            LDataPack.writeChar(npack, i)
            LDataPack.writeInt(npack, actorcount)
            for j = 1, actorcount do
                LDataPack.writeInt(npack, actors[j])
            end
            System.sendPacketToAllGameClient(npack, gvar.rank[i].serverid)
        end
    end
    print ("subactivity32 rankReward count: ", count)
    subactivity30.onActivityFinish(config[id][1].subType)
    gvar.updateTime = System.getNowTime()
end

function onActivityServerFinish(sId, sType, cpack)
    print("... onActivityServerFinish")
    if System.isBattleSrv() then return end
    local id = LDataPack.readInt(cpack)
    local rank = LDataPack.readChar(cpack)
    local count = LDataPack.readInt(cpack)
    
    for i = 1, count do
        local actorid = LDataPack.readInt(cpack)
        local conf = ActivityType32Config[id][rank]
        local mailData = {head = conf.head, context = conf.context, tAwardList = conf.consume}
        mailsystem.sendMailById(actorid, mailData)
    end
end

function checkEndTime()
    if System.isCommSrv() then return end
    for id, v in pairs(ActivityType32Config) do
        local now = System.getNowTime()
        local et = activitymgr.getEndTime(id)
        local gvar = getGlobalData(id)
        if et ~= 0 and now - et > 0 and gvar.updateTime < et then --onActivityFinish
            onActivityFinish(id)
        end
    end
end

function On24Hour()
    for id, v in pairs(ActivityType32Config) do
        if activitymgr.activityTimeIsOver(id) then
            local gvar = getGlobalData(id)
            gvar.rank = nil
            gvar.rankcount = nil
        end
    end
end

function onConnected(sId, sType)
    if System.isCommSrv() then return end
    if csbase.checkAllConnect() then
        checkEndTime()
    end
end

function init()
    csbase.RegConnected(onConnected)
    subactivitymgr.regActivityFinish(subType, onActivityFinish)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.sActivityCmd_YuanbaoDrawServerRank, getRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCYuanbaoDrawCmd, CrossSrvSubCmd.SCYuanbaoDrawCmd_GetServerRank, onGetServerRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCYuanbaoDrawCmd, CrossSrvSubCmd.SCYuanbaoDrawCmd_SendServerRank, onSendServerRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCYuanbaoDrawCmd, CrossSrvSubCmd.SCYuanbaoDrawCmd_ActivityServerFinish, onActivityServerFinish)
end

table.insert(InitFnTable, init)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.crossend = function (actor, args)
    onActivityFinish(tonumber(args[1]))
    return true
end


