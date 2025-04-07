--卓越擂台赛

module("contestrank", package.seeall)

CTRank_type = {
    SCRank = 1,
    CTRank = 2,
}

local function getSystemVar()
    local var = System.getStaticVar()
    if not var then return end
    if not var.contestRank then
        var.contestRank = {
            scRank = {},
            ctRank = {},
        }
    end
    return var.contestRank
end

function clearContestRankVar()
    local var = System.getStaticVar()
    var.contestRank = nil
end

local function sortSCRank(a, b)
    if a.score > b.score then
        return true
    elseif a.score < b.score then
        return false
    else
        return a.updateTime < b.updateTime
    end
end

function addSCRankScore(actorid, serverid, name, value)
    local data = getSystemVar()
    local rank = data.scRank
    
    local now = System.getNowTime()
    local isHave
    for idx, item in ipairs(rank) do
        if item.actorid == actorid then
            item.score = item.score + value
            item.updateTime = now
            isHave = true
            break
        end
    end
    
    if not isHave then
        rank[#rank + 1] = {
            actorid = actorid,
            serverid = serverid,
            name = name,
            score = value,
            updateTime = now,
        }
    end
    table.sort(rank, sortSCRank)
end

local function sortCTRank(a, b)
    if a.kills > b.kills then
        return true
    elseif a.kills < b.kills then
        return false
    else
        return a.power > b.power
    end
end

function addCTRankScore(actorid, serverid, name, power, round, killCount)
    local data = getSystemVar()
    local rank = data.ctRank
    
    local now = System.getNowTime()
    local isHave
    for idx, item in ipairs(rank) do
        if item.actorid == actorid then
            item.round = item.round + round
            item.kills = item.kills + killCount
            isHave = true
            break
        end
    end
    
    if not isHave then
        rank[#rank + 1] = {
            actorid = actorid,
            serverid = serverid,
            name = name,
            round = round,
            kills = killCount,
            power = power,
        }
    end
    table.sort(rank, sortCTRank)
end

function getContests(count)
    local data = getSystemVar()
    local rank = data.scRank
    
    local contests = {}
    for i = 1, count do
        if rank[i] then
            table.insert(contests, rank[i].actorid)
        else
            break
        end
    end
    return contests
end

function getChallengers(round)
    local data = getSystemVar()
    local rank = data.scRank
    local config = ContestFubenConfig[round]
    
    local temp = {}
    local challengers = {}
    for i = config.matchRank[1], config.matchRank[2] do
        if rank[i] then
            local aid = rank[i].actorid
            local power = contest.getActorPower(aid)
            table.insert(temp, {actorid = aid, power = power})
        end
    end
    table.sort(temp, function (a, b) return a.power < b.power end)
    local count = #temp
    if count > 0 then
        for i = 1, config.challengerCount do
            if temp[i] then
                table.insert(challengers, temp[i].actorid)
            else
                table.insert(challengers, temp[1].actorid)
            end
        end
    end
    return challengers
end

function sendSCRankReward()
    print("on sendSCRankReward")
    local data = getSystemVar()
    local rank = data.scRank
    
    for idx, conf in ipairs(ContestScoreRankConfig) do
        for i = conf.min, conf.max do
            local info = rank[i]
            if not info then break end
            print("rank = ", i, "actorid = ", info.actorid, "score = ", info.score)
            local mailData = {
                head = conf.mailTitle,
                context = string.format(conf.mailContent, info.score, i),
                tAwardList = conf.rewards,
            }
            mailsystem.sendMailById(info.actorid, mailData, info.serverid)
        end
    end
    print("sendSCRankReward end")
    snedSCRankInfo(nil, CTRank_type.SCRank)
end

function sendCTRankReward()
    print("on sendCTRankReward")
    local data = getSystemVar()
    local rank = data.ctRank
    
    for i, conf in ipairs(ContestChallengerRankConfig) do
        local info = rank[i]
        if not info then break end
        print("rank = ", i, "actorid = ", info.actorid, "round = ", info.round, "killCount =", info.kills)
        local mailData = {
            head = conf.mailTitle,
            context = string.format(conf.mailContent, info.round),
            tAwardList = conf.rewards,
        }
        mailsystem.sendMailById(info.actorid, mailData, info.serverid)
    end
    print("sendCTRankReward end")
    snedSCRankInfo(nil, CTRank_type.CTRank)
end

----------------------------------------------------------------------------------
--协议处理

--92-7 请求积分排行榜
local function c2sReqSCRankInfo(actor, packet)
    s2cSCRankInfo(actor)
end

--92-7 返回积分排行榜
function s2cSCRankInfo(actor)
    local data = getSystemVar()
    local rank = data.scRank
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sContestCmd_ReqSCRank)
    if pack == nil then return end
    
    local count = ContestScoreRankConfig[#ContestScoreRankConfig].max
    LDataPack.writeShort(pack, count)
    local myrank = 0
    local myscore = 0
    local actorid = LActor.getActorId(actor)
    
    for i, info in ipairs(rank) do
        if info.actorid == actorid then
            myrank = i
            myscore = info.score
            break
        end
    end
    
    for i = 1, count do
        local info = rank[i]
        if info then
            LDataPack.writeString(pack, info.name)
            LDataPack.writeDouble(pack, info.score)
        else
            LDataPack.writeString(pack, "")
            LDataPack.writeDouble(pack, 0)
        end
    end
    LDataPack.writeShort(pack, myrank)
    LDataPack.writeDouble(pack, myscore)
    
    LDataPack.flush(pack)
end

--92-8 请求守擂排行榜
local function c2sReqCTRankInfo(actor, packet)
    s2cCTRankInfo(actor)
end

--92-8 返回守擂排行榜
function s2cCTRankInfo(actor)
    local data = getSystemVar()
    local rank = data.ctRank
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sContestCmd_ReqCTRank)
    if pack == nil then return end
    
    local count = #ContestChallengerRankConfig
    LDataPack.writeByte(pack, count)
    local myrank = 0
    local myround = 0
    local mykills = 0
    local actorid = LActor.getActorId(actor)
    
    for i = 1, count do
        local info = rank[i]
        if info then
            if info.actorid == actorid then
                myrank = i
                myround = info.round
                mykills = info.kills
            end
            LDataPack.writeString(pack, info.name)
            LDataPack.writeByte(pack, info.round)
            LDataPack.writeByte(pack, info.kills)
        else
            LDataPack.writeString(pack, "")
            LDataPack.writeByte(pack, 0)
            LDataPack.writeByte(pack, 0)
        end
    end
    
    LDataPack.writeByte(pack, myrank)
    LDataPack.writeByte(pack, myround)
    LDataPack.writeByte(pack, mykills)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--跨服协议

--战区同步数据到普通服
function snedSCRankInfo(serverid, rankType)
    if not System.isLianFuSrv() then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCContestCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCContestCmd_SyncRankInfo)
    
    local data = getSystemVar()
    if rankType == CTRank_type.SCRank then
        LDataPack.writeByte(pack, rankType)
        local dataUd = bson.encode(data.scRank)
        LDataPack.writeUserData(pack, dataUd)
    elseif rankType == CTRank_type.CTRank then
        LDataPack.writeByte(pack, rankType)
        local dataUd = bson.encode(data.ctRank)
        LDataPack.writeUserData(pack, dataUd)
    end
    System.sendPacketToAllGameClient(pack, serverid or 0)
end

--普通服收到战区同步数据
local function onSCRankInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local rankType = LDataPack.readByte(dp)
    local dataUd = LDataPack.readUserData(dp)
    
    local rank = bson.decode(dataUd)
    local data = getSystemVar()
    if rankType == CTRank_type.SCRank then
        data.scRank = rank
    elseif rankType == CTRank_type.CTRank then
        data.ctRank = rank
    end
end

--连接跨服事件
local function onCTConnected(serverId, serverType)
    snedSCRankInfo(serverId, CTRank_type.SCRank)
    snedSCRankInfo(serverId, CTRank_type.CTRank)
end

----------------------------------------------------------------------------------
--初始化

local function init()
    --if System.isCommSrv() then return end
    if System.isBattleSrv() then return end
    --if System.isLianFuSrv() then return end
    
    csbase.RegConnected(onCTConnected)
    csmsgdispatcher.Reg(CrossSrvCmd.SCContestCmd, CrossSrvSubCmd.SCContestCmd_SyncRankInfo, onSCRankInfo)
    
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cContestCmd_ReqSCRank, c2sReqSCRankInfo)
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cContestCmd_ReqCTRank, c2sReqCTRankInfo)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.printCTRank = function (actor, args)
    if System.isBattleSrv() then return end
    local var = getSystemVar()
    print("*******RankInfo*******")
    utils.printTable(var)
    print("************************")
    if System.isCommSrv() then
        SCTransferGM("printCTRank", args, true)
    end
end

gmCmdHandlers.clearCTRank = function (actor, args)
    if System.isBattleSrv() then return end
    local var = System.getStaticVar()
    var.ctRank = nil
    if System.isCommSrv() then
        SCTransferGM("clearCTRank", args, true)
    end
end

