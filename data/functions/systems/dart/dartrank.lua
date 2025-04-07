
module( "dartrank", package.seeall)

Guild_Record = Guild_Record or {}
Self_Record = Self_Record or {}
local Max_Self_Record = 20
local Max_Guild_Record = 20
local rankNum = 20

local function onGetSelfRankList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local gvar = dartcross.getGlobalData()
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_SendSelfRankList)
    LDataPack.writeInt(npack, actorid)
    local myrank = 0
    local myscore = 0
    for i=1, #gvar.selfrank do
        if gvar.selfrank[i].actorid == actorid then
            myrank = i
            myscore = gvar.selfrank[i].score
        end
    end
    local count = math.min(rankNum, #gvar.selfrank)
    LDataPack.writeShort(npack, count)
    for i=1, count do
        LDataPack.writeString(npack, gvar.selfrank[i].guildname or "")
        LDataPack.writeString(npack, gvar.selfrank[i].name)
        LDataPack.writeInt(npack, gvar.selfrank[i].score)
    end
    LDataPack.writeInt(npack, myscore)
    LDataPack.writeShort(npack, myrank)
    LDataPack.writeChar(npack, gvar.selfrank.first.job or 1)
    LDataPack.writeInt(npack, gvar.selfrank.first.shenzhuangchoose or 0)
    LDataPack.writeInt(npack, gvar.selfrank.first.shenqichoose or 0)
    LDataPack.writeInt(npack, gvar.selfrank.first.wingchoose or 0)
    LDataPack.writeInt(npack, gvar.selfrank.first.touxian or 0)
    LDataPack.writeInt(npack, gvar.selfrank.first.title or 0)
    LDataPack.writeInt(npack, gvar.selfrank.first.mozhen or 0)
    LDataPack.writeInt(npack, gvar.selfrank.first.damonchoose or 0)
    LDataPack.writeInt(npack, gvar.selfrank.first.meilinchoose or 0)
    System.sendPacketToAllGameClient(npack, sId)
end

function onChangeName(actorid, name)
    local gvar = dartcross.getGlobalData()
    for i=1, #gvar.selfrank do
        if gvar.selfrank[i].actorid == actorid then
            gvar.selfrank[i].name = name
            break
        end
    end
end

local function onGetGuildRankList(sId, sType, cpack)
    local guildId = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)

    local gvar = dartcross.getGlobalData()
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_SendGuildRankList)
    LDataPack.writeInt(npack, actorid)
    local myrank = 0
    local myscore = 0
    for i=1, #gvar.guildrank do
        if gvar.guildrank[i].guildId == guildId then
            myrank = i
            myscore = gvar.guildrank[i].score
        end
    end
    local count = math.min(rankNum, #gvar.guildrank)
    LDataPack.writeShort(npack, count)
    for i=1, count do
        LDataPack.writeString(npack, gvar.guildrank[i].guildname)
        LDataPack.writeInt(npack, gvar.guildrank[i].score)
    end
    LDataPack.writeInt(npack, myscore)
    LDataPack.writeShort(npack, myrank)    
    System.sendPacketToAllGameClient(npack, sId)
end

local function onGetGuildRecordList(sId, sType, cpack)
    local guildId = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_SendGuildRecordList)
    LDataPack.writeInt(npack, actorid)
    if not Guild_Record[guildId] then
        Guild_Record[guildId] = {}
    end
    LDataPack.writeChar(npack, #Guild_Record[guildId])
    for k,v in ipairs(Guild_Record[guildId]) do
        LDataPack.writeInt(npack, v.time or 0)
        LDataPack.writeChar(npack, v.type)
        if v.type == 1 then --出发
            LDataPack.writeChar(npack, v.carlevel)
            LDataPack.writeChar(npack, v.peoplecount)
        elseif v.type == 2 then
            LDataPack.writeChar(npack, v.carlevel)
            LDataPack.writeChar(npack, v.plundercount)
            LDataPack.writeShort(npack, v.guildscore)
            LDataPack.writeShort(npack, v.selfscore)
        else
            LDataPack.writeString(npack, v.guildname)
            LDataPack.writeString(npack, v.name)
        end
    end 
    System.sendPacketToAllGameClient(npack, sId)
end

local function onGetSelfRecordList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_SendSelfRecordList)
    LDataPack.writeInt(npack, actorid)
    if not Self_Record[actorid] then
        Self_Record[actorid] = {}
    end
    
    LDataPack.writeChar(npack, #Self_Record[actorid])
    for k,v in ipairs(Self_Record[actorid]) do
        LDataPack.writeInt(npack, v.time or 0)
        LDataPack.writeChar(npack, v.type)
        if v.type == 1 then --出发
            LDataPack.writeChar(npack, v.carlevel)
        elseif v.type == 2 then
            LDataPack.writeChar(npack, v.carlevel)
            LDataPack.writeShort(npack, v.guildscore)
            LDataPack.writeShort(npack, v.selfscore)
        else
            LDataPack.writeByte(npack, v.result)
            LDataPack.writeString(npack, v.name)
            LDataPack.writeString(npack, v.guildname)
            LDataPack.writeChar(npack, v.carlevel)
            LDataPack.writeShort(npack, v.selfscore)
            LDataPack.writeShort(npack, v.guildscore)
        end
    end 
    System.sendPacketToAllGameClient(npack, sId)
end

function sortRank(rank)
    if not rank[1] then return nil, nil end
    table.sort(rank, function(a,b) return a.score > b.score end)
    return rank[1].actorid, rank[1].serverid
end


function addGuildRank(gvar, guildId, score)
    local ishave = false
    for i=1, #gvar.guildrank do
        if gvar.guildrank[i].guildId == guildId then
            gvar.guildrank[i].score = gvar.guildrank[i].score + score
            ishave = true
        end
    end
    if not ishave then
        local count = #gvar.guildrank
        gvar.guildrank[count+1] = {}
        gvar.guildrank[count+1].score = score
        gvar.guildrank[count+1].guildId = guildId
        gvar.guildrank[count+1].guildname = LGuild.getGuilNameById(guildId)
    end

    sortRank(gvar.guildrank)
end

function addGuildRecord(guildId, type, carlevel, plundercount, guildscore, selfscore, guildname, name, peoplecount)
    --print("addGuildRecord :", guildId, type, carlevel, plundercount, guildscore, selfscore, guildname, name)
    if not Guild_Record[guildId] then Guild_Record[guildId] = {} end
    table.insert(Guild_Record[guildId], 1, {time = System.getNowTime(), type = type, carlevel = carlevel, 
        plundercount = plundercount, peoplecount = peoplecount, guildscore = guildscore, selfscore = selfscore, guildname = guildname, name = name})
    
    if #Guild_Record[guildId] > Max_Guild_Record then
        table.remove(Guild_Record[guildId])
    end
end

function addSelfRecord(actorid, type, carlevel, guildscore, selfscore, guildname, result, name)
    --print("addSelfRecord :", actorid, type, carlevel, guildscore, selfscore, guildname, result)
    if not Self_Record[actorid] then Self_Record[actorid] = {} end
    table.insert(Self_Record[actorid], 1, {time = System.getNowTime(), type = type, guildname = guildname, 
    carlevel = carlevel, selfscore = selfscore, guildscore = guildscore, result = result, name = name})
    if #Self_Record[actorid] > Max_Self_Record then
        table.remove(Self_Record[actorid])
    end
end

function addSelfRank(gvar, actorid, serverid, score, name, guildId, notSort)
    --加入排行
    local ishave = false
    for i=1, #gvar.selfrank do
        if gvar.selfrank[i].actorid == actorid then
            gvar.selfrank[i].score = gvar.selfrank[i].score + score
            ishave = true
            break
        end
    end
    if not ishave then
        local count = #gvar.selfrank
        gvar.selfrank[count+1] = {}
        gvar.selfrank[count+1].score = score
        gvar.selfrank[count+1].serverid = serverid
        gvar.selfrank[count+1].actorid = actorid
        gvar.selfrank[count+1].name = name
        gvar.selfrank[count+1].guildname = LGuild.getGuilNameById(guildId)
    end
    if not notSort then
        local firstActorId, firstServerId = sortRank(gvar.selfrank)
        if firstActorId then --排序并判断第一名是否变更
            --请求第一名数据
            local npack = LDataPack.allocPacket()
            LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
            LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_GetRankActor)
            LDataPack.writeInt(npack, firstActorId)
            System.sendPacketToAllGameClient(npack, firstServerId)
        end
    end
end

function settlementSort(gvar)
    local firstActorId, firstServerId = sortRank(gvar.selfrank)
    if firstActorId then --排序并判断第一名是否变更
        --请求第一名数据
        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
        LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_GetRankActor)
        LDataPack.writeInt(npack, firstActorId)
        System.sendPacketToAllGameClient(npack, firstServerId)
    end
end

function sendSelfMail(actorid, carlevel, serverid, score)
    --发送邮件
    local mailData = {head = DartConstConfig.finishhead, context = string.format(DartConstConfig.finishcontext, carlevel), 
        tAwardList= {{type = 0, id = NumericType_DartScore, count = score}}}
    mailsystem.sendMailById(actorid, mailData, serverid)
end

local function onGetRankActor(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)    
    local actorData = offlinedatamgr.GetDataByOffLineDataType(actorid, offlinedatamgr.EOffLineDataType.EBasic)
    if not actorData then return end

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_SendRankActor)
    LDataPack.writeChar(npack, actorData.job)
    LDataPack.writeInt(npack, actorData.shenzhuangchoose)
    LDataPack.writeInt(npack, actorData.shenqichoose)
    LDataPack.writeInt(npack, actorData.wingchoose)
    LDataPack.writeInt(npack, actorData.touxian)
    LDataPack.writeInt(npack, actorData.title or 0)
    LDataPack.writeInt(npack, actorData.mozhen or 0)
    LDataPack.writeInt(npack, actorData.damonchoose)
    LDataPack.writeInt(npack, actorData.meilinchoose)    
    System.sendPacketToAllGameClient(npack, sId)
end

local function onSendRankActor(sId, sType, cpack)
    local gvar = dartcross.getGlobalData()
    gvar.selfrank.first.job = LDataPack.readChar(cpack)
    gvar.selfrank.first.shenzhuangchoose = LDataPack.readInt(cpack)
    gvar.selfrank.first.shenqichoose = LDataPack.readInt(cpack)
    gvar.selfrank.first.wingchoose = LDataPack.readInt(cpack)
    gvar.selfrank.first.touxian = LDataPack.readInt(cpack)
    gvar.selfrank.first.title = LDataPack.readInt(cpack)
    gvar.selfrank.first.mozhen = LDataPack.readInt(cpack)
    gvar.selfrank.first.damonchoose = LDataPack.readInt(cpack)
    gvar.selfrank.first.meilinchoose = LDataPack.readInt(cpack)
end

--赛季结算
function dartSettlement()
    if not System.isBattleSrv() then return end
    local gvar = dartcross.getGlobalData()
    for i=1, #gvar.guildrank do
        local guildId = gvar.guildrank[i].guildId
        print ("dart guild rank: ",i," guildId: ",guildId)
        for k,v in ipairs(DartGuildRankConfig) do
            if i >= v.range[1] and i<= v.range[2] then
                local guild = LGuild.getGuildById(guildId)
                local actoridList = LGuild.getMemberIdList(guild)
                if actoridList then
                    local reward = {}
                    for k,v in ipairs(v.award) do
                        table.insert(reward, {type=1, id=v.id, count = math.floor(v.count/#actoridList)})
                    end
                    for k,v in ipairs(v.allaward) do
                        table.insert(reward, {type=1, id=v.id, count = v.count})
                    end
                    for j=1, #actoridList do
                        local mailData = {head = v.head, context = v.context, tAwardList=reward}
                        mailsystem.sendMailById(actoridList[j], mailData, 0)
                    end
                end
                break
            end
        end
    end
    gvar.guildrank = {}

    for i=1, #gvar.selfrank do
        local actorid = gvar.selfrank[i].actorid
        print ("dart self rank: ",i," actorid: ",actorid)
        for k,v in ipairs(DartPersonRankConfig) do
            if i >= v.range[1] and i<= v.range[2] then
                local mailData = {head = v.head, context = v.context, tAwardList=v.award}
                mailsystem.sendMailById(actorid, mailData, gvar.selfrank[i].serverid)
                break
            end
        end        
    end
    gvar.settlementtime = System.getNowTime()
    gvar.selfrank = {}
    gvar.guilddata = {}
end

function dartGmSelfSettlement()
    print("dartGmSelfSettlement start")
    local gvar = dartcross.getGlobalData()
    for i=1, #gvar.selfrank do
        local actorid = gvar.selfrank[i].actorid
        print ("dart self rank: ",i," actorid: ",actorid)
        for k,v in ipairs(DartPersonRankConfig) do
            if i >= v.range[1] and i<= v.range[2] then
                local mailData = {head = v.head, context = v.context, tAwardList=v.award}
                mailsystem.sendMailById(actorid, mailData, gvar.selfrank[i].serverid)
                break
            end
        end        
    end
    gvar.settlementtime = System.getNowTime() - 86400
    gvar.selfrank = {}
    print("dartGmSelfSettlement end")
end

function OnGameStart()
    if not System.isBattleSrv() then return end
    local gvar = dartcross.getGlobalData()
    if System.getDayOfWeek() == 0 and not (gvar.settlementtime and not System.isSameDay(gvar.settlementtime, System.getNowTime())) then
        local hour,min,sec = System.getTime()
        if hour > 22 or (hour == 22 and min > 41) then
            dartSettlement()
        end
    end
end

_G.dartSettlement = dartSettlement

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_GetSelfRankList, onGetSelfRankList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_GetGuildRankList, onGetGuildRankList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_GetSelfRecordList, onGetSelfRecordList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_GetGuildRecordList, onGetGuildRecordList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_GetRankActor, onGetRankActor)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_SendRankActor, onSendRankActor)


--engineevent.regGameStartEvent(OnGameStart)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.dartaddscore = function ( actor, args )
    if not System.isBattleSrv() then return end
    local gvar = dartcross.getGlobalData()
    local score = tonumber(args[1])
    addSelfRank(gvar, LActor.getActorId(actor), LActor.getServerId(actor), score, LActor.getName(actor), LActor.getGuildId(actor))
    return true
end


gmCmdHandlers.insertdart = function ( actor, args )
    if not System.isBattleSrv() then return end
    local num = tonumber(args[1])
    if not num then return end
    local gvar = dartcross.getGlobalData()
    gvar.selfrank = {}
    for i=1, num do
        gvar.selfrank[i] = {}
        gvar.selfrank[i].score = i*200
        gvar.selfrank[i].serverid = 65003
        gvar.selfrank[i].actorid = math.random(1,29922)
        gvar.selfrank[i].name = "xxx"..i
        gvar.selfrank[i].guildname = "guilname"..i
    end
    return true
end


