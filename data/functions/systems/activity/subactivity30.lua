--跨服个人排行
module("subactivity30", package.seeall)

local subType = 30
local rankNum = 30

minType = {
    yuanbaodraw = 1, --钻石夺宝
}

local function getGlobalData(id)
    local var = activitymgr.getGlobalVar(id)
    if not var then return end
    if not var.rank or not var.rankcount then
        var.rank = {}
        var.rankcount = #ActivityType30Config[id]
        for i = 1, var.rankcount do
            var.rank[i] = {}
            var.rank[i].score = ActivityType30Config[id][i].score
            var.rank[i].name = ""
        end
    end
    if not var.updateTime then var.updateTime = 0 end
    if not var.minRankcount then var.minRankcount = #ActivityType30Config[id] end
    return var
end

function getSelfRankByType(minType)
    for id, v in pairs(ActivityType30Config) do
        if v[1].subType == minType then
            return getGlobalData(id)
        end
    end
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
                if not gvar.rank[i].actorid then
                    gvar.rank[i].score = 0
                end
                gvar.rank[i], gvar.rank[j] = gvar.rank[j], gvar.rank[i]
            elseif gvar.rank[i].score == gvar.rank[j].score and not gvar.rank[i].actorid and gvar.rank[j].actorid then
                gvar.rank[i].score = 0
                gvar.rank[i], gvar.rank[j] = gvar.rank[j], gvar.rank[i]
            end
        end
    end
    for i = minrank, 1, -1 do
        if not gvar.rank[i].actorid then
            gvar.rank[i].score = ActivityType30Config[id][i].score
        end
    end
end

function updateActorScore(type, actorid, actorname, selfaddscore, serverid)
    for id, v in pairs(ActivityType30Config) do
        if type == v[1].subType then --and not activitymgr.activityTimeIsEnd(id) then
            local index
            local gvar = getGlobalData(id)
            for k, v in pairs(gvar.rank) do
                if v.actorid and v.actorid == actorid then
                    v.score = v.score + selfaddscore
                    index = k
                    break
                end
            end
            if not index then
                gvar.rankcount = gvar.rankcount + 1
                gvar.rank[gvar.rankcount] = {}
                gvar.rank[gvar.rankcount].actorid = actorid
                gvar.rank[gvar.rankcount].score = selfaddscore
                gvar.rank[gvar.rankcount].serverid = serverid
                gvar.rank[gvar.rankcount].name = actorname
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
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCYuanbaoDrawCmd_GetSelfRank)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

--跨服收到请求排行数据
function onGetSelflRank(sId, sType, cpack)
    print("... onGetSelflRank")
    if System.isCommSrv() then return end
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local gvar = getGlobalData(id)
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCYuanbaoDrawCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCYuanbaoDrawCmd_SendSelfRank)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, actorid)
    local myrank = 0
    local myscore = 0
    for i = 1, gvar.rankcount do
        if gvar.rank[i].actorid and gvar.rank[i].actorid == actorid then
            myrank = i
            myscore = gvar.rank[i].score
        end
    end
    local count = math.min(rankNum, gvar.rankcount)
    LDataPack.writeChar(npack, count)
    for i = 1, count do
        LDataPack.writeString(npack, gvar.rank[i].name)
        LDataPack.writeInt(npack, gvar.rank[i].score)
    end
    LDataPack.writeChar(npack, myrank)
    LDataPack.writeInt(npack, myscore)
    System.sendPacketToAllGameClient(npack, sId)
end

--普通服收到排行数据
function onSendSelfRank(sId, sType, cpack)
    print("... onSendSelfRank")
    if System.isBattleSrv() then return end
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_YuanbaoDrawSelfRank)
    if npack == nil then return end
    local count = LDataPack.readChar(cpack)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, count)
    for i = 1, count do
        local name = LDataPack.readString(cpack)
        LDataPack.writeString(npack, name)
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    end
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.flush(npack)
end

function onActivityFinish(minType)
    print("...  onActivityFinish self")
    if System.isCommSrv() then return end
    local id
    for k, v in pairs(ActivityType30Config) do
        if v[1].subType == minType then
            id = k
            break
        end
    end
    if not id then return end
    
    local gvar = getGlobalData(id)
    local count = math.min(gvar.rankcount, #ActivityType30Config[id])
    print ("subactivity30 rankReward actId: ", id)
    for i = 1, count do
        print ("rank: ", i, " actorid: ", gvar.rank[i].actorid, " serverid: ", gvar.rank[i].serverid)
        if gvar.rank[i].actorid then
            local npack = LDataPack.allocPacket()
            LDataPack.writeByte(npack, CrossSrvCmd.SCYuanbaoDrawCmd)
            LDataPack.writeByte(npack, CrossSrvSubCmd.SCYuanbaoDrawCmd_ActivitySelfFinish)
            LDataPack.writeInt(npack, id)
            LDataPack.writeChar(npack, i)
            LDataPack.writeInt(npack, gvar.rank[i].actorid)
            System.sendPacketToAllGameClient(npack, gvar.rank[i].serverid)
        end
    end
    print ("subactivity30 rankReward count: ", count)
end

function onGetActivityFinish(sId, sType, cpack)
    print("... onGetActivityFinish")
    if System.isBattleSrv() then return end
    local id = LDataPack.readInt(cpack)
    local rank = LDataPack.readChar(cpack)
    local actorid = LDataPack.readInt(cpack)
    local conf = ActivityType30Config[id][rank]
    if not conf then return end
    local mailData = {head = conf.head, context = conf.context, tAwardList = conf.consume}
    mailsystem.sendMailById(actorid, mailData)
end

function onChangeName(actorid, name)
    for id, v in pairs(ActivityType30Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local gvar = getGlobalData(id)
            for k, v in pairs(gvar.rank) do
                if v.actorid and v.actorid == actorid then
                    v.name = name
                    break
                end
            end
        end
    end
end

function On24Hour()
    for id, v in pairs(ActivityType30Config) do
        if activitymgr.activityTimeIsOver(id) then
            local gvar = getGlobalData(id)
            gvar.rank = nil
            gvar.rankcount = nil
        end
    end
end

function init()
    if System.isLianFuSrv() then return end
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_YuanbaoDrawSelfRank, getRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCYuanbaoDrawCmd, CrossSrvSubCmd.SCYuanbaoDrawCmd_GetSelfRank, onGetSelflRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCYuanbaoDrawCmd, CrossSrvSubCmd.SCYuanbaoDrawCmd_SendSelfRank, onSendSelfRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCYuanbaoDrawCmd, CrossSrvSubCmd.SCYuanbaoDrawCmd_ActivitySelfFinish, onGetActivityFinish)
end

table.insert(InitFnTable, init)



