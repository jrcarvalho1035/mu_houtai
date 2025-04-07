--跨服个人排行
module("subactivity33", package.seeall)

local subType = 33
local rankNum = 50

minType = {
    consume = 1, --Consumo
    consumeDiamond = 2, -- Consumir pontos
    xunbaoScore = 3, --caça ao tesouro
    sendGift = 4, --dar presentes
    consume2 = 5, --O consumo 2 é igual ao consumo 1
    consumeDiamond2 = 6, --Consumir pontos 2, que é o mesmo que consumir pontos
}

local function getGlobalData(id)
    local var = activitymgr.getGlobalVar(id)
    if not var then return end
    if not var.rank or not var.rankcount then
        var.rank = {}
        var.rankcount = #ActivityType33Config[id]
        for i = 1, var.rankcount do
            var.rank[i] = {}
            var.rank[i].score = ActivityType33Config[id][i].need
            var.rank[i].name = ""
        end
    end
    if not var.updateTime then var.updateTime = 0 end
    return var
end

function getSelfRankByType(minType)
    for id, v in pairs(ActivityType33Config) do
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
    local minrank = #ActivityType33Config[id]
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
                    gvar.rank[j].score = ActivityType33Config[id][j].need
                end
            elseif gvar.rank[i].score == gvar.rank[j].score and not gvar.rank[i].actorid and gvar.rank[j].actorid then
                gvar.rank[i], gvar.rank[j] = gvar.rank[j], gvar.rank[i]
                if not gvar.rank[j].actorid then
                    gvar.rank[j].score = ActivityType33Config[id][j].need
                end
            end
        end
    end
end

local function updateRankValue(actor, subType1, count, useactorid, usename, useserverid)
    if System.isCommSrv() then
        for id, v in pairs(ActivityType33Config) do
            if v[1].subType == subType1 and not activitymgr.activityTimeIsEnd(id) then
                local npack = LDataPack.allocPacket()
                LDataPack.writeByte(npack, CrossSrvCmd.SCComsumeCmd)
                LDataPack.writeByte(npack, CrossSrvSubCmd.SCComsumeCmd_Comsume)
                LDataPack.writeInt(npack, id)
                LDataPack.writeInt(npack, LActor.getActorId(actor))
                LDataPack.writeString(npack, LActor.getName(actor))                
                LDataPack.writeInt(npack, count)
                LDataPack.writeChar(npack, LActor.getJob(actor))
                System.sendPacketToAllGameClient(npack, 0)
            end
        end
    else
        for id, v in pairs(ActivityType33Config) do
            if v[1].subType == subType1 and not activitymgr.activityTimeIsEnd(id) then
                local actorid = useactorid or LActor.getActorId(actor)
                local name = usename or LActor.getName(actor)
                local serverid = useserverid or LActor.getServerId(actor)
                local job = LActor.getJob(actor)
                
                local index
                local gvar = getGlobalData(id)
                for k, v in pairs(gvar.rank) do
                    if v.actorid and v.actorid == actorid then
                        v.score = v.score + count
                        index = k
                        break
                    end
                end
                if not index then
                    gvar.rankcount = gvar.rankcount + 1
                    gvar.rank[gvar.rankcount] = {}
                    gvar.rank[gvar.rankcount].actorid = actorid
                    gvar.rank[gvar.rankcount].score = count
                    gvar.rank[gvar.rankcount].serverid = serverid
                    gvar.rank[gvar.rankcount].name = name
                    gvar.rank[gvar.rankcount].job = job
                    index = gvar.rankcount
                end
                sortRank(id, index)
            end
        end       
    end
end

function onConsumeYuanbao(actor, count, log)
    if log == "diral draw" then return end
    updateRankValue(actor, minType.consume, count)
    updateRankValue(actor, minType.consume2, count)
end

local function onConsumeDiamond(actor, count, log)
    --if System.isBattleSrv() then return end
    print('onConsumeDiamond count=', count, 'log=', log)
    updateRankValue(actor, minType.consumeDiamond, count)
    updateRankValue(actor, minType.consumeDiamond2, count)
end

function addXunbaoScore(actor, count, log)
    if System.isBattleSrv() then return end
    print('addXunbaoScore count=', count)
    updateRankValue(actor, minType.xunbaoScore, count)
end

function addSendGiftScore(actor, count, actorid, name, serverid)
    if not System.isBattleSrv() then return end
    print('addSendGiftScore count=', count)
    updateRankValue(actor, minType.sendGift, count, actorid, name, serverid)
end

function onUpdateComsume(sId, sType, cpack)
    print("... onUpdateComsume")
    if System.isCommSrv() then return end
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local name = LDataPack.readString(cpack)
    local count = LDataPack.readInt(cpack)
    local job = LDataPack.readChar(cpack)
    
    local index
    local gvar = getGlobalData(id)
    for k, v in pairs(gvar.rank) do
        if v.actorid and v.actorid == actorid then
            v.score = v.score + count
            index = k
            break
        end
    end
    if not index then
        gvar.rankcount = gvar.rankcount + 1
        gvar.rank[gvar.rankcount] = {}
        gvar.rank[gvar.rankcount].actorid = actorid
        gvar.rank[gvar.rankcount].score = count
        gvar.rank[gvar.rankcount].serverid = sId
        gvar.rank[gvar.rankcount].name = name
        gvar.rank[gvar.rankcount].job = job
        index = gvar.rankcount
    end
    sortRank(id, index)
end

function getRank(actor, pack)
    local id = LDataPack.readInt(pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCComsumeCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCComsumeCmd_RankDataRequest)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

--跨服收到请求排行数据
function onGetRank(sId, sType, cpack)
    print("... onGetRank")
    if System.isCommSrv() then return end
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local gvar = getGlobalData(id)
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCComsumeCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCComsumeCmd_RankDataSync)
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
    LDataPack.writeShort(npack, count)
    for i = 1, count do
        LDataPack.writeString(npack, gvar.rank[i].name)
        LDataPack.writeDouble(npack, gvar.rank[i].score)
        LDataPack.writeChar(npack, gvar.rank[i].job or 0)
    end
    LDataPack.writeShort(npack, myrank)
    LDataPack.writeDouble(npack, myscore)
    System.sendPacketToAllGameClient(npack, sId)
end

--普通服收到排行数据
function onSendRank(sId, sType, cpack)
    print("... onSendRank")
    if System.isBattleSrv() then return end
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_SendComsumeRank)
    if npack == nil then return end
    local count = LDataPack.readShort(cpack)
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, count)
    for i = 1, count do
        local name = LDataPack.readString(cpack)
        LDataPack.writeString(npack, name)
        LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    end
    LDataPack.writeShort(npack, LDataPack.readShort(cpack))
    LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
    LDataPack.flush(npack)
end

function onActivityFinish(id)
    if System.isCommSrv() then return end
    local gvar = getGlobalData(id)
    local count = math.min(gvar.rankcount, #ActivityType33Config[id])
    print ("subactivity33 rankReward actId: ", id)
    for i = 1, count do
        print ("rank: ", i, " actorid: ", gvar.rank[i].actorid, " serverid: ", gvar.rank[i].serverid)
        if gvar.rank[i].actorid then
            local npack = LDataPack.allocPacket()
            LDataPack.writeByte(npack, CrossSrvCmd.SCComsumeCmd)
            LDataPack.writeByte(npack, CrossSrvSubCmd.SCComsumeCmd_ActivityFinish)
            LDataPack.writeInt(npack, id)
            LDataPack.writeChar(npack, i)
            LDataPack.writeInt(npack, gvar.rank[i].actorid)
            System.sendPacketToAllGameClient(npack, gvar.rank[i].serverid)
        end
    end
    print ("subactivity33 rankReward count: ", count)
    gvar.updateTime = System.getNowTime()
end

function onGetActivityFinish(sId, sType, cpack)
    print("... onGetActivityFinish")
    if System.isBattleSrv() then return end
    local id = LDataPack.readInt(cpack)
    local rank = LDataPack.readChar(cpack)
    local actorid = LDataPack.readInt(cpack)
    local conf = ActivityType33Config[id][rank]
    if not conf then return end
    local mailData = {head = conf.head, context = conf.context, tAwardList = conf.rewards}
    mailsystem.sendMailById(actorid, mailData)
end

function onChangeName(actorid, name)
    for id, v in pairs(ActivityType33Config) do
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

function checkEndTime()
    for id, v in pairs(ActivityType33Config) do
        local now = System.getNowTime()
        local et = activitymgr.getEndTime(id)
        local gvar = getGlobalData(id)
        if et ~= 0 and now - et > 0 and gvar.updateTime < et then --onActivityFinish
            onActivityFinish(id)
        end
    end
end

function On24Hour()
    for id in pairs(ActivityType33Config) do
        if activitymgr.activityTimeIsOver(id) then
            local gvar = getGlobalData(id)
            if gvar then
                gvar.rank = nil
                gvar.rankcount = nil
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

function act33GmAdd(actorid, name, sId, count)
    print("onact33GmAdd start")
    print("actorid =",actorid,"name =",name,"sId =",sId,"count =",count)
    if System.isCommSrv() then
        print("onact33GmAdd server is comsrv") 
        return 
    end
    local id = 1159
    if activitymgr.activityTimeIsEnd(id) then 
        print("onact33GmAdd act is end, id =", id) 
        return 
    end
    
    local gvar = getGlobalData(id)
    if not gvar then 
        print("onact33GmAdd gvar is nil")
        return 
    end

    local index
    for k, v in pairs(gvar.rank) do
        if v.actorid and v.actorid == actorid then
            v.score = v.score + count
            index = k
            break
        end
    end
    if not index then
        gvar.rankcount = gvar.rankcount + 1
        gvar.rank[gvar.rankcount] = {}
        gvar.rank[gvar.rankcount].actorid = actorid
        gvar.rank[gvar.rankcount].score = count
        gvar.rank[gvar.rankcount].serverid = sId
        gvar.rank[gvar.rankcount].name = name
        index = gvar.rankcount
    end
    sortRank(id, index)
    print("onact33GmAdd end")
end

function init()
    if System.isLianFuSrv() then return end
    csbase.RegConnected(onConnected)
    subactivitymgr.regActivityFinish(subType, onActivityFinish)
    actorevent.reg(aeConsumeYuanbao, onConsumeYuanbao)
    actorevent.reg(aeConsumeDiamond, onConsumeDiamond)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_GetComsumeRank, getRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCComsumeCmd, CrossSrvSubCmd.SCComsumeCmd_RankDataRequest, onGetRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCComsumeCmd, CrossSrvSubCmd.SCComsumeCmd_RankDataSync, onSendRank)
    --csmsgdispatcher.Reg(CrossSrvCmd.SCComsumeCmd, CrossSrvSubCmd.SCComsumeCmd_UpdateRankInfo, onUpdateRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCComsumeCmd, CrossSrvSubCmd.SCComsumeCmd_Comsume, onUpdateComsume)
    csmsgdispatcher.Reg(CrossSrvCmd.SCComsumeCmd, CrossSrvSubCmd.SCComsumeCmd_ActivityFinish, onGetActivityFinish)
    
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.act33Rsf = function (actor, args)
    local actorid = LActor.getActorId(actor)
    local name = LActor.getName(actor)
    local id = 1159
    local count = tonumber(args[1])

    local gvar = getGlobalData(id)
    if not gvar then 
        print("onact33GmAdd gvar is nil")
        return 
    end

    local index
    for k, v in pairs(gvar.rank) do
        if v.actorid and v.actorid == actorid then
            v.score = v.score + count
            index = k
            break
        end
    end
    if not index then
        gvar.rankcount = gvar.rankcount + 1
        gvar.rank[gvar.rankcount] = {}
        gvar.rank[gvar.rankcount].actorid = actorid
        gvar.rank[gvar.rankcount].score = count
        gvar.rank[gvar.rankcount].serverid = LActor.getServerId(actor)
        gvar.rank[gvar.rankcount].name = name
        index = gvar.rankcount
    end
    sortRank(id, index)
    print("onact33GmAdd end")
    return true
end

