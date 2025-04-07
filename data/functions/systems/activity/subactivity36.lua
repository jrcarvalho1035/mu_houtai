--超级转盘
module("subactivity36", package.seeall)

ACT36_RECV_RECORD = ACT36_RECV_RECORD or {}
ACT36_SEND_RECORD = ACT36_SEND_RECORD or {}
local MAX_RECORD = 10
local subType = 36
local TOP_FIND = 20 --从前多少名查找玩家

ACT36_BRO_SELF = ACT36_BRO_SELF or {}


local function getGlobalData(id)
    local gvar = activitymgr.getGlobalVar(id)
    if not gvar then return end
    if not gvar.rank or not gvar.rankcount then
        gvar.rank = {}
        gvar.rankcount = #ActivityType36Config[id]
        for i = 1, gvar.rankcount do
            gvar.rank[i] = {}
            gvar.rank[i].score = ActivityType36Config[id][i].need
            gvar.rank[i].name = ""
            gvar.rank[i].helplist = {}
        end
    end
    if not gvar.first then
        gvar.first = {}
        gvar.first.job = 0
        gvar.first.shenzhuang = 0
        gvar.first.shenqi = 0
        gvar.first.wing = 0
        gvar.first.shengling = 0
        gvar.first.meilin = 0
    end
    if not gvar.updateTime then gvar.updateTime = 0 end
    return gvar
end

--换一批玩家
local function changeActors(actor, pack)
    local id = LDataPack.readInt(pack)
    if not ActivityType37Config[id] then return end
    if not ActivityType36Config[ActivityType37Config[id][1].actid] then return end
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_ReqActors)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeInt(npack, LActor.getServerId(actor))
    System.sendPacketToAllGameClient(npack, 0)    
end

local function addDataToPack(npack, gvar, index, adds)    
    if index ~= 0 and gvar.rank[index] then
        for i=1, #adds do
            if adds[i] == index then
                return false
            end
        end
        LDataPack.writeChar(npack, gvar.rank[index].job or 0)
        LDataPack.writeString(npack, gvar.rank[index].name or "")
        LDataPack.writeInt(npack, gvar.rank[index].actorid or 0)
        LDataPack.writeInt(npack, gvar.rank[index].serverid or 0)
        LDataPack.writeInt(npack, gvar.rank[index].zhuansheng or 0)
        LDataPack.writeDouble(npack, gvar.rank[index].power or 0)
        LDataPack.writeString(npack, gvar.rank[index].guildName or "")
        return true
    end
    return false
end

local function randTable(array)
    for i=1, #array do
        local index = math.random(i, #array)
        array[i],array[index] = array[index],array[i]
    end
end

local function onReqActors(sId, sType, cpack)
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local serverid = LDataPack.readInt(cpack)
    if not ActivityType37Config[id] then return end --发过来的是前端界面显示id
    local actid = ActivityType37Config[id][1].actid --对应的送礼活动id

    local gvar = getGlobalData(actid)
    --local myrank = 0
    local myscore = 0
    local adds = {}
    local ranks = {}
    local serverranks = {}
    for i=1, #gvar.rank do
        if gvar.rank[i].actorid == actorid then
            myscore = gvar.rank[i].score
        end
        if gvar.rank[i].name ~= "" then
            if #ranks < 10 then
                table.insert(ranks, i)
            end
            if gvar.rank[i].serverid == serverid then
                if #serverranks < 30 then
                    table.insert(serverranks, i)
                end
            end
        end
    end
    randTable(ranks)
    randTable(serverranks)
    local rank1 = 0
    local rank2 = 0
    local diff = 999999999
    for i=1, TOP_FIND - 1 do
        if gvar.rank[i].name ~= "" then
            for j=i+1, TOP_FIND do
                if gvar.rank[j].name ~= "" and math.abs(gvar.rank[i].score - gvar.rank[j].score) <= diff then
                    rank1 = i
                    rank2 = j
                    diff = math.abs(gvar.rank[i].score - gvar.rank[j].score)
                end
            end
        end
    end
    -- if gvar.rank[rank1] and gvar.rank[rank1].name ~= "" then
    --     for i=1, TOP_FIND do
    --         if rank2 == 0 and rank1 + 1 < TOP_FIND and gvar.rank[rank1 + 1] and gvar.rank[rank1 + 1].name ~= "" then
    --             rank2 = rank1+1
    --         end
    --         if rank2 == 0 and rank1 - 1 > 0 and gvar.rank[rank1 - 1] and gvar.rank[rank1 - 1].name ~= "" then
    --             rank2 = rank1-1
    --         end
    --     end
    -- end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_SendActors)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, (rank1 == 0 and 0 or 1) + (rank2 == 0 and 0 or 1))
    if rank1 ~= 0 then
        addDataToPack(npack, gvar, rank1, adds)
    end
    if rank2 ~= 0 then
        addDataToPack(npack, gvar, rank2, adds)
    end
    table.insert(adds, rank1)
    table.insert(adds, rank2)
    local count = 0
    local pos1 = LDataPack.getPosition(npack)
    LDataPack.writeChar(npack, count)
    if #ranks > 0 then
        for i=1, #ranks do
            if addDataToPack(npack, gvar, ranks[i], adds) then
                table.insert(adds, ranks[i])
                count = count + 1
            end
            if count >= 3 then
                break
            end
        end
        local pos2 = LDataPack.getPosition(npack)
        LDataPack.setPosition(npack, pos1)
        LDataPack.writeChar(npack, count)
        LDataPack.setPosition(npack, pos2)
    end
    count  = 0
    pos1 = LDataPack.getPosition(npack)
    LDataPack.writeChar(npack, count)
    if #serverranks > 0 then
        for i=1, #serverranks do            
            if addDataToPack(npack, gvar, serverranks[i], adds) then
                count = count + 1
            end
            if count >= 3 then
                break
            end
        end
        local pos2 = LDataPack.getPosition(npack)
        LDataPack.setPosition(npack, pos1)
        LDataPack.writeChar(npack, count)
        LDataPack.setPosition(npack, pos2)
    end
    local guildId = LGuild.getGuildIdByActorId(actorid)
    LDataPack.writeString(npack, LGuild.getGuilNameById(guildId))
    System.sendPacketToAllGameClient(npack, 0)
end

local function readDataToPack(npack, cpack)    
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    LDataPack.writeString(npack, LDataPack.readString(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
    LDataPack.writeString(npack, LDataPack.readString(cpack))
end

local function onSendActors(sId, sType, cpack)
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Change36Actors)
    LDataPack.writeInt(npack, id)
    local count1 = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count1)
    for i=1, count1 do
        readDataToPack(npack, cpack)
    end
    local count2 = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count2)
    for i=1, count2 do
        readDataToPack(npack, cpack)
    end
    local count3 = LDataPack.readChar(cpack)
    local pos1 = LDataPack.getPosition(npack)
    LDataPack.writeChar(npack, count3)
    for i=1, count3 do
        readDataToPack(npack, cpack)
    end
    -- local pos2 = LDataPack.getPosition(npack)
    -- LDataPack.setPosition(npack, pos1)
    -- LDataPack.writeChar(npack, count)
    -- LDataPack.setPosition(npack, pos2)
    if count1 + count2 + count3 == 0 then
        LDataPack.setPosition(npack, pos1)
        LDataPack.writeChar(npack, 1)
        LDataPack.writeChar(npack, LActor.getJob(actor))
        LDataPack.writeString(npack, LActor.getName(actor))
        LDataPack.writeInt(npack, LActor.getActorId(actor))
        LDataPack.writeInt(npack, LActor.getServerId(actor))
        LDataPack.writeInt(npack, LActor.getZhuansheng(actor))
        LDataPack.writeDouble(npack, LActor.getActorData(actor).total_power)
        LDataPack.writeString(npack, LDataPack.readString(cpack))
    end

    LDataPack.writeInt(npack, subactivity1.getSendScore(actor))
    LDataPack.flush(npack)
end


local function getRecord(actor, pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_GetRecord)
    LDataPack.writeInt(npack, LDataPack.readInt(pack))
    LDataPack.writeChar(npack, LDataPack.readChar(pack))
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)    
end

local function onGetRecord(sId, sType, cpack)
    local id = LDataPack.readInt(cpack)
    local type = LDataPack.readChar(cpack)
    local actorid = LDataPack.readInt(cpack)

    if not ActivityType37Config[id] then return end --发过来的是前端界面显示id
    local actid = ActivityType37Config[id][1].actid --对应的送礼活动id

    local gvar = getGlobalData(actid)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_SendRecord)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, type)
    LDataPack.writeInt(npack, actorid)
    if type == 1 then
        if not ACT36_SEND_RECORD[actid] then ACT36_SEND_RECORD[actid] = {} end        
        if not ACT36_SEND_RECORD[actid][actorid] then ACT36_SEND_RECORD[actid][actorid] = {} end
        local records = ACT36_SEND_RECORD[actid][actorid]
        local count = #records
        LDataPack.writeChar(npack, count)
        for i=1, count do
            LDataPack.writeInt(npack, records[i].time)
            LDataPack.writeString(npack, records[i].name)
            LDataPack.writeInt(npack, records[i].itemid)
            LDataPack.writeInt(npack, records[i].count)
        end
    else
        if not ACT36_RECV_RECORD[actid] then ACT36_RECV_RECORD[actid] = {} end
        if not ACT36_RECV_RECORD[actid][actorid] then ACT36_RECV_RECORD[actid][actorid] = {} end
        local records = ACT36_RECV_RECORD[actid][actorid]
        local count = #records
        LDataPack.writeChar(npack, count)
        for i=1, count do
            LDataPack.writeInt(npack, records[i].time)
            LDataPack.writeString(npack, records[i].name)
            LDataPack.writeInt(npack, records[i].itemid)
            LDataPack.writeInt(npack, records[i].count)
        end
    end
    
    System.sendPacketToAllGameClient(npack, 0)    
end

local function onSendRecord(sId, sType, cpack)
    local id = LDataPack.readInt(cpack)
    local type = LDataPack.readChar(cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Send36Record)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, type)
    local count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    end
    LDataPack.flush(npack)
end

local function getRankActor(actor, pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_GetRankInfo)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeInt(npack, LDataPack.readInt(pack)) --活动37的id
    LDataPack.writeInt(npack, LDataPack.readInt(pack)) --请求的玩家actorid
    System.sendPacketToAllGameClient(npack, 0)
end

local function onGetRankInfo(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local id = LDataPack.readInt(cpack)
    local reqActorId = LDataPack.readInt(cpack)
    if not ActivityType37Config[id] then return end --发过来的是前端界面显示id
    local actid = ActivityType37Config[id][1].actid --对应的送礼活动id
    if not ActivityType36Config[actid] then return end


    local gvar = getGlobalData(actid)
    local myrank = 0
    local myscore = 0

    for k,v in ipairs(gvar.rank) do    
        if v.actorid == reqActorId then
            local npack = LDataPack.allocPacket()
            LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
            LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_SendRankInfo)
            LDataPack.writeInt(npack, actorid)
            LDataPack.writeInt(npack, id)            
            LDataPack.writeInt(npack, v.serverid)
            LDataPack.writeInt(npack, reqActorId)
            LDataPack.writeString(npack, v.name)
            LDataPack.writeDouble(npack, v.power)
            LDataPack.writeInt(npack, v.zhuansheng)
            LDataPack.writeString(npack, v.guildName)
            LDataPack.writeChar(npack, v.job)
            System.sendPacketToAllGameClient(npack, 0)
            break
        end
    end
end

local function onSendRankInfo(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local id = LDataPack.readInt(cpack)    
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Send36RankActor)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))    
    LDataPack.writeString(npack, LDataPack.readString(cpack))
    LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))    
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))    
    LDataPack.writeString(npack, LDataPack.readString(cpack))
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    LDataPack.flush(npack)

end

--请求排行
local function getRank(actor, pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_GetRank)
    LDataPack.writeInt(npack, LDataPack.readInt(pack))
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)    
end

local function onGetRank(sId, sType, cpack)
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local gvar = getGlobalData(id)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_SendRank)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, actorid)

    local myrank = 0
    local myscore = 0
    LDataPack.writeShort(npack, #ActivityType36Config[id])
    for k,v in ipairs(gvar.rank) do    
        if k <= #ActivityType36Config[id] then
            LDataPack.writeInt(npack, v.actorid or 0)
            LDataPack.writeString(npack, v.name)
            LDataPack.writeChar(npack, v.job or 0)
            LDataPack.writeInt(npack, v.score)
            LDataPack.writeShort(npack, #v.helplist)
            local helpcount = 0
            for i=1, 2 do
                if v.helplist[i] and v.helplist[i].score >= ActivityType36Config[id][k].shouhuneed then
                    helpcount = helpcount + 1
                end
            end
            LDataPack.writeChar(npack, helpcount)
            for i=1, helpcount do
                LDataPack.writeString(npack, v.helplist[i].name)
                LDataPack.writeChar(npack, v.helplist[i].job)
                LDataPack.writeInt(npack, v.helplist[i].score)            
            end
        end
        if actorid == v.actorid then
            myrank = k
            myscore = v.score
        end
    end
    LDataPack.writeShort(npack, myrank)
    LDataPack.writeInt(npack, myscore)

    LDataPack.writeChar(npack, gvar.first.job)
    LDataPack.writeInt(npack, gvar.first.shenzhuang)
    LDataPack.writeInt(npack, gvar.first.shenqi)
    LDataPack.writeInt(npack, gvar.first.wing)
    LDataPack.writeInt(npack, gvar.first.shengling)
    LDataPack.writeInt(npack, gvar.first.meilin)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onSendRank(sId, sType, cpack)
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Send36Rank)
    local count = LDataPack.readShort(cpack)
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, count)
    for i=1, count do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))        
        LDataPack.writeShort(npack, LDataPack.readShort(cpack))
        local helpcount = LDataPack.readChar(cpack)
        LDataPack.writeChar(npack, helpcount)
        for j=1, helpcount do
            LDataPack.writeString(npack, LDataPack.readString(cpack))
            LDataPack.writeChar(npack, LDataPack.readChar(cpack))
            LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        end
    end
    LDataPack.writeShort(npack, LDataPack.readShort(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))

    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))

    LDataPack.flush(npack)
end

--发送广播
local function broSelf(actor, pack)
    local id = LDataPack.readInt(pack)
    local type = LDataPack.readChar(pack)
    if not ActivityType37Config[id] or activitymgr.activityTimeIsEnd(id) then return end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_BroSelf)
    LDataPack.writeChar(npack, type)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, LActor.getServerId(actor))
    LDataPack.writeInt(npack, LActor.getActorId(actor))    
    LDataPack.writeString(npack, LActor.getName(actor))
    local basicData = LActor.getActorData(actor) 
    LDataPack.writeDouble(npack, basicData.total_power)
    LDataPack.writeInt(npack, basicData.zhuansheng)
    LDataPack.writeInt(npack, LActor.getGuildId(actor))
    LDataPack.writeChar(npack, LActor.getJob(actor))
    LDataPack.writeChar(npack, LActor.getVipLevel(actor))
    LDataPack.writeChar(npack, LActor.getSVipLevel(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

local function onBroSelf(sId, sType, cpack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_RecvBroSelf)
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))    
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))    
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeString(npack, LDataPack.readString(cpack))
    LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    local guildId = LDataPack.readInt(cpack)
    LDataPack.writeInt(npack, guildId)
    LDataPack.writeString(npack, LGuild.getGuilNameById(guildId))
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))    
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))    
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))    
    System.sendPacketToAllGameClient(npack, 0)
end

local function onRecvBroSelf(sId, sType, cpack)
    local type = LDataPack.readChar(cpack)
    local id = LDataPack.readInt(cpack)
    local serverid = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local name = LDataPack.readString(cpack)
    local power = LDataPack.readDouble(cpack)
    local zhuansheng = LDataPack.readInt(cpack)
    local guildId = LDataPack.readInt(cpack)
    local guildName = LDataPack.readString(cpack)
    local job = LDataPack.readChar(cpack)
    local vip = LDataPack.readChar(cpack)
    local svip = LDataPack.readChar(cpack)

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_Activity)
    LDataPack.writeByte(npack, Protocol.sActivityCmd_Send36GiftBro)
    LDataPack.writeChar(npack, 1)
    LDataPack.writeChar(npack, type)
    LDataPack.writeInt(npack, id)    
    LDataPack.writeInt(npack, serverid)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeString(npack, name)
    LDataPack.writeDouble(npack, power)
    LDataPack.writeInt(npack, zhuansheng)
    LDataPack.writeString(npack, guildName)
    LDataPack.writeChar(npack, job)
    LDataPack.writeChar(npack, vip)
    LDataPack.writeChar(npack, svip)
    if type == 2 then --战盟广播
        LGuild.broadcastData(guildId, npack)
    else --全服广播
        if #ACT36_BRO_SELF >= 3 then
            table.remove(ACT36_BRO_SELF, 1)
        end
        table.insert(ACT36_BRO_SELF, {id=id,serverid=serverid,actorid=actorid,name=name,power =power,
            zhuansheng=zhuansheng,guildName=guildName,job=job,vip=vip,svip=svip})
        System.broadcastData(npack)
    end
end

function onlogin(actor)
    LActor.postScriptEventLite(actor, 2 * 1000, sendLogin)
end

function sendLogin(actor)
    for id,v in pairs(ActivityType37Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Send36GiftBro)
            LDataPack.writeChar(npack, #ACT36_BRO_SELF)
            for k,v in ipairs(ACT36_BRO_SELF) do        
                LDataPack.writeChar(npack, 1)
                LDataPack.writeInt(npack, v.id)
                LDataPack.writeInt(npack, v.serverid)
                LDataPack.writeInt(npack, v.actorid)
                LDataPack.writeString(npack, v.name)
                LDataPack.writeDouble(npack, v.power)
                LDataPack.writeInt(npack, v.zhuansheng)
                LDataPack.writeString(npack, v.guildName)
                LDataPack.writeChar(npack, v.job)
                LDataPack.writeChar(npack, v.vip)
                LDataPack.writeChar(npack, v.svip)
            end
            LDataPack.flush(npack)
            break
        end
    end
end

--送礼
function sendGift(actor, pack)    
    local id = LDataPack.readInt(pack)
    local sendActorId = LDataPack.readInt(pack)
    local sendServerId = LDataPack.readInt(pack)
    local sendActorName = LDataPack.readString(pack)
    local power = LDataPack.readDouble(pack)
    local zhuansheng = LDataPack.readInt(pack)
    local guildName = LDataPack.readString(pack)
    local job = LDataPack.readChar(pack)    

    local itemindex = LDataPack.readChar(pack)
    local count = LDataPack.readInt(pack)

    if not ActivityType37Config[id] then return end --发过来的是前端界面显示id
    if not ActivityType37Config[id][1].items[itemindex] then return end
    local actid = ActivityType37Config[id][1].actid --对应的送礼活动id
    if not ActivityType36Config[actid] then return end
    if activitymgr.activityTimeIsEnd(id) or activitymgr.activityTimeIsEnd(actid) then return end

    local havecount = actoritem.getItemCount(actor, ActivityType37Config[id][1].items[itemindex])
    count = math.min(havecount, count)
    if not actoritem.checkItem(actor, ActivityType37Config[id][1].items[itemindex], count) then
        return
    end
    actoritem.reduceItem(actor, ActivityType37Config[id][1].items[itemindex], count, "act36 cost")

    local addscore = count * ActivityType37Config[id][1].scores[itemindex]
    subactivity1.addSendGiftScore(actor, addscore)

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_SendGift)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeInt(npack, LActor.getServerId(actor))
    LDataPack.writeString(npack, LActor.getName(actor))    
    LDataPack.writeChar(npack, LActor.getJob(actor))

    LDataPack.writeInt(npack, sendActorId)
    LDataPack.writeInt(npack, sendServerId)
    LDataPack.writeString(npack, sendActorName)
    LDataPack.writeChar(npack, job)
    LDataPack.writeDouble(npack, power)
    LDataPack.writeInt(npack, zhuansheng)
    LDataPack.writeString(npack, guildName)
    LDataPack.writeChar(npack, itemindex)
    LDataPack.writeInt(npack, count)

    System.sendPacketToAllGameClient(npack, 0)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Send36GiftRet)
    LDataPack.flush(npack)
end

local function onSendGift(sId, sType, cpack)
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local serverid = LDataPack.readInt(cpack)
    local name = LDataPack.readString(cpack)
    local job = LDataPack.readChar(cpack)

    local sendActorId = LDataPack.readInt(cpack)
    local sendServerId = LDataPack.readInt(cpack)
    local sendName = LDataPack.readString(cpack)
    local sendJob = LDataPack.readChar(cpack)
    local power = LDataPack.readDouble(cpack)
    local zhuansheng = LDataPack.readInt(cpack)    
    local guildName = LDataPack.readString(cpack)
    local itemindex = LDataPack.readChar(cpack)
    local count = LDataPack.readInt(cpack)    
    local addscore = count * ActivityType37Config[id][1].scores[itemindex]
    --local gvar = getGlobalData(ActivityType37Config[id].actid)
    --subactivity34.updateScore(id, actorid, addscore, serverid, name)
    subactivity33.addSendGiftScore(nil, addscore, actorid, name, serverid)
    addSendGiftScore(ActivityType37Config[id][1].actid, sendActorId, addscore, sendName, sendServerId, power, zhuansheng, sendJob, guildName, actorid, name, job, serverid)
    addSendGiftRecord(id, actorid, sendActorId, itemindex, count, name, sendName)
end

function addSendGiftRecord(id, actorid, sendActorId, itemindex, count, name, sendName)
    local actid = ActivityType37Config[id][1].actid
    if not ACT36_RECV_RECORD[actid] then ACT36_RECV_RECORD[actid] = {} end
    if not ACT36_RECV_RECORD[actid][sendActorId] then ACT36_RECV_RECORD[actid][sendActorId] = {} end
    local now = System.getNowTime()
    table.insert(ACT36_RECV_RECORD[actid][sendActorId], 1, {time = now, name = name, itemid = ActivityType37Config[id][1].items[itemindex], count = count})
    if #ACT36_RECV_RECORD[actid][sendActorId] > MAX_RECORD then
        table.remove(ACT36_RECV_RECORD[actid][sendActorId])
    end

    if not ACT36_SEND_RECORD[actid] then ACT36_SEND_RECORD[actid] = {} end
    if not ACT36_SEND_RECORD[actid][actorid] then ACT36_SEND_RECORD[actid][actorid] = {} end
    table.insert(ACT36_SEND_RECORD[actid][actorid], 1, {time = now, name = sendName, itemid = ActivityType37Config[id][1].items[itemindex], count = count})
    if #ACT36_SEND_RECORD[actid][actorid] > MAX_RECORD then
        table.remove(ACT36_SEND_RECORD[actid][actorid])
    end
end

local function addHelpList(gvar, index, actorid, name, job, serverid, score)
    if not gvar.rank[index].helplist then gvar.rank[index].helplist = {} end
    local ishave = false
    for i=1, #gvar.rank[index].helplist do
        if gvar.rank[index].helplist[i].actorid == actorid then
            gvar.rank[index].helplist[i].name = name
            gvar.rank[index].helplist[i].job = job
            gvar.rank[index].helplist[i].score = gvar.rank[index].helplist[i].score + score
            gvar.rank[index].helplist[i].serverid = serverid
            ishave = true
            break
        end
    end
    if not ishave then
        local count = #gvar.rank[index].helplist
        gvar.rank[index].helplist[count+1] = {}
        gvar.rank[index].helplist[count+1].actorid = actorid
        gvar.rank[index].helplist[count+1].name = name
        gvar.rank[index].helplist[count+1].job = job
        gvar.rank[index].helplist[count+1].score = score
        gvar.rank[index].helplist[count+1].serverid = serverid
    end
    table.sort(gvar.rank[index].helplist, function(a,b) return a.score > b.score end)
end

function addSendGiftScore(id, actorid, addscore, name, serverid, power, zhuansheng, job, guildName,  sactorid, sname, sjob, sserverid)
    if not activitymgr.activityTimeIsEnd(id) then        
        local index
        local gvar = getGlobalData(id)
        for k, v in pairs(gvar.rank) do
            if v.actorid and v.actorid == actorid then
                v.score = (v.score or 0) + addscore
                index = k
                break
            end
        end
        if not index then
            gvar.rankcount = gvar.rankcount + 1
            gvar.rank[gvar.rankcount] = {}
            gvar.rank[gvar.rankcount].actorid = actorid
            gvar.rank[gvar.rankcount].score = addscore
            gvar.rank[gvar.rankcount].serverid = serverid
            gvar.rank[gvar.rankcount].name = name
            gvar.rank[gvar.rankcount].power = power
            gvar.rank[gvar.rankcount].zhuansheng = zhuansheng
            gvar.rank[gvar.rankcount].guildName = guildName
            gvar.rank[gvar.rankcount].job = job
            index = gvar.rankcount
        end
        addHelpList(gvar, index, sactorid, sname, sjob, sserverid, addscore)
        sortRank(id, index)
    end
end

function sortRank(id, index)
    local gvar = getGlobalData(id)
    local minrank = #ActivityType36Config[id]
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
    local firstrankid = gvar.rank[1].actorid
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
            gvar.rank[i].score = ActivityType36Config[id][i].need
        end
    end
    if firstrankid ~= gvar.rank[1].actorid then
        getFirstRankInfo(id, gvar.rank[1].actorid, gvar.rank[1].serverid)
    end
end

function getFirstRankInfo(id, actorid, serverid)
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_GetFirstInfo)
    LDataPack.writeInt(npack, id)
	LDataPack.writeInt(npack, actorid)
    System.sendPacketToAllGameClient(npack, serverid)
end

local function onGetFirstInfo(sId, sType, cpack)
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local actorData = offlinedatamgr.GetDataByOffLineDataType(actorid, offlinedatamgr.EOffLineDataType.EBasic)
	if actorData==nil then
		return
    end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCAct36)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCAct36Cmd_SendFirstInfo)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, actorData.job)
    LDataPack.writeInt(npack, actorData.shenzhuangchoose)
    LDataPack.writeInt(npack, actorData.shenqichoose)
    LDataPack.writeInt(npack, actorData.wingchoose)
    LDataPack.writeInt(npack, actorData.shengling_id)
    LDataPack.writeInt(npack, actorData.meilinchoose)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onSendFirstInfo(sId, sType, cpack)
    if not System.isBattleSrv() then return end
    local id = LDataPack.readInt(cpack)
    local gvar = getGlobalData(id)
    gvar.first.job = LDataPack.readChar(cpack)
    gvar.first.shenzhuang = LDataPack.readInt(cpack)
    gvar.first.shenqi = LDataPack.readInt(cpack)
    gvar.first.wing = LDataPack.readInt(cpack)
    gvar.first.shengling = LDataPack.readInt(cpack)
    gvar.first.meilin = LDataPack.readInt(cpack)
end


local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    LDataPack.writeInt(npack, 0)
end

function onChangeName(actorid, name)
    for id, v in pairs(ActivityType36Config) do
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


function onActivityFinish(id)
    if System.isCommSrv() then return end
    local gvar = getGlobalData(id)
    local count = math.min(gvar.rankcount, #ActivityType36Config[id])
    print ("subactivity36 rankReward actId: ", id)
    for i = 1, count do
        print ("rank: ", i, " actorid: ", gvar.rank[i].actorid, " serverid: ", gvar.rank[i].serverid)
        if gvar.rank[i].actorid then
            local conf = ActivityType36Config[id][i]
            if not conf then return end
            local mailData = {head = conf.head, context = conf.context, tAwardList = conf.rewards}
            mailsystem.sendMailById(gvar.rank[i].actorid, mailData, gvar.rank[i].serverid)
            for j=1,2 do
                if gvar.rank[i].helplist[j] and gvar.rank[i].helplist[j].score >= conf.shouhuneed then
                    local mailData1 = {head = conf.sendhead, context = conf.sendcontext, tAwardList = conf.sendRewards}
                    mailsystem.sendMailById(gvar.rank[i].helplist[j].actorid, mailData1, gvar.rank[i].helplist[j].serverid)
                end
            end
        end
    end
    print ("subactivity36 rankReward count: ", count)
    gvar.updateTime = System.getNowTime()
    ACT36_BRO_SELF = {}
end

function checkEndTime()
    for id, v in pairs(ActivityType36Config) do
        local now = System.getNowTime()
        local et = activitymgr.getEndTime(id)
        local gvar = getGlobalData(id)
        if et ~= 0 and now - et > 0 and gvar.updateTime < et then --onActivityFinish
            onActivityFinish(id)
        end
    end
end

function onConnected(sId, sType)
    if System.isCommSrv() then return end
    if csbase.checkAllConnect() then
        checkEndTime()
    end
end

local function init()
    csbase.RegConnected(onConnected)
    if System.isCrossWarSrv() then return end
    actorevent.reg(aeUserLogin, onlogin)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Send36GiftBro, broSelf)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Change36Actors, changeActors)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Get36Rank, getRank)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Send36Gift, sendGift)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Get36Record, getRecord)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Get36RankActor, getRankActor)    
end

csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_BroSelf, onBroSelf)
csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_RecvBroSelf, onRecvBroSelf)
csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_GetRank, onGetRank)
csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_SendRank, onSendRank)
csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_SendGift, onSendGift)
-- csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_SendGiftRet, onSendGiftRet)
csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_GetRecord, onGetRecord)
csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_SendRecord, onSendRecord)
csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_ReqActors, onReqActors)
csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_SendActors, onSendActors)
csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_GetFirstInfo, onGetFirstInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_SendFirstInfo, onSendFirstInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_GetRankInfo, onGetRankInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCAct36, CrossSrvSubCmd.SCAct36Cmd_SendRankInfo, onSendRankInfo)







table.insert(InitFnTable, init)
subactivitymgr.regWriteRecordFunc(subType, writeRecord)
subactivitymgr.regActivityFinish(subType, onActivityFinish)


