--战队冠军赛(排行榜)

module("championrank", package.seeall)

local function getSystemVar()
    local var = System.getStaticVar()
    if not var then return end
    if not var.championrank then
        var.championrank = {
            actorRank = {},
            teamRank = {},
        }
    end
    return var.championrank
end

function clearChampionRankVar()
    local data = System.getStaticVar()
    data.championrank = nil
end

function getCHActorRank()
    local data = getSystemVar()
    return data.actorRank
end

function getCHTeamRank()
    local data = getSystemVar()
    return data.teamRank
end

function getCHTopTeams()
    local rank = getCHTeamRank()
    local topTeams = {}
    for i = 1, 3 do
        local item = rank[i]
        if item then
            topTeams[i] = item.teamId
        end
    end
    return topTeams
end

function addCHActorRankScore(actorid, serverid, name, value)
    local rank = getCHActorRank()
    
    local now = System.getNowTime()
    local isHave
    for idx, item in ipairs(rank) do
        if item.actorId == actorid then
            item.score = item.score + value
            isHave = true
            break
        end
    end
    
    if not isHave then
        rank[#rank + 1] = {
            actorId = actorid,
            serverId = serverid,
            name = name,
            score = value,
        }
    end
    table.sort(rank, function (a, b) return a.score > b.score end)
end

local function sortFunc(a, b)
    if a.round == b.round then
        if a.score == b.score then
            return a.power > b.power
        else
            return a.score > b.score
        end
    else
        return a.round > b.round
    end
end

function addCHTeamRankScore(teamid, name, power, value1, value2)
    local rank = getCHTeamRank()
    
    local now = System.getNowTime()
    local isHave
    for idx, item in ipairs(rank) do
        if item.teamId == teamid then
            item.round = item.round + value1
            item.score = item.score + value2
            isHave = true
            break
        end
    end
    
    if not isHave then
        rank[#rank + 1] = {
            teamId = teamid,
            name = name,
            power = power,
            round = value1,
            score = value2,
        }
    end
    table.sort(rank, sortFunc)
end

function sendCHActorRankReward()
    print("on sendCHActorRankReward")
    local rank = getCHActorRank()
    
    for idx, conf in ipairs(ChampionScoreRankConfig) do
        local info = rank[idx]
        if not info then break end
        print("rank = ", idx, "actorid = ", info.actorid, "score = ", info.score)
        local mailData = {
            head = conf.mailTitle,
            context = conf.mailContent,
            tAwardList = conf.rewards,
        }
        mailsystem.sendMailById(info.actorId, mailData, info.serverId)
    end
    print("sendCHActorRankReward end")
end

function sendCHTeamRankReward()
    print("on sendCHTeamRankReward")
    local rank = getCHTeamRank()
    
    for idx, conf in ipairs(ChampionTeamRankConfig) do
        local info = rank[idx]
        if not info then break end
        print("rank = ", idx, "teamId = ", info.teamId, "round = ", info.round, "score = ", info.score)
        local mailData = {
            head = conf.mailTitle,
            context = conf.mailContent,
            tAwardList = conf.rewards,
        }
        champion.sendCHMailByTeam(info.teamId, mailData)
    end
    print("sendCHTeamRankReward end")
end

----------------------------------------------------------------------------------
--协议处理

--92-54 冠军赛-请求个人排行榜
local function c2sCHActorRank(actor)
    s2cCHActorRank(actor)
end

--92-54 冠军赛-返回个人排行榜
function s2cCHActorRank(actor)
    local rank = getCHActorRank()
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_ResActorRank)
    if pack == nil then return end
    
    local count = math.min(#rank, #ChampionScoreRankConfig)
    LDataPack.writeShort(pack, count)
    local myrank = 0
    local myscore = 0
    
    local actorid = LActor.getActorId(actor)
    for idx, info in ipairs(rank) do
        if idx <= count then
            LDataPack.writeString(pack, info.name)
            LDataPack.writeInt(pack, info.score)
        end
        if info.actorid == actorid then
            myrank = idx
            myscore = info.score
        end
    end
    
    LDataPack.writeShort(pack, myrank)
    LDataPack.writeInt(pack, myscore)
    
    LDataPack.flush(pack)
end

--92-55 冠军赛-请求战队排行榜
local function c2sCHTeamRank(actor)
    s2cCHTeamRank(actor)
end

--92-55 冠军赛-返回战队排行榜
function s2cCHTeamRank(actor)
    local rank = getCHTeamRank()
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_ResTeamRank)
    if pack == nil then return end
    
    LDataPack.writeShort(pack, #rank)
    local myrank = 0
    local myscore = 0
    
    local actorid = LActor.getActorId(actor)
    local team = champion.getCHTeamByActorId(actorid)
    local teamId = team and team.teamId or 0
    for idx, info in ipairs(rank) do
        LDataPack.writeString(pack, info.name)
        LDataPack.writeInt(pack, info.score)

        if info.teamId == teamId then
            myrank = idx
            myscore = info.score
        end
    end
    
    LDataPack.writeShort(pack, myrank)
    LDataPack.writeInt(pack, myscore)
    
    LDataPack.flush(pack)
end
----------------------------------------------------------------------------------
--跨服协议

--战区同步数据到普通服
-- function sendCHRankInfo(serverid)
--     if not System.isLianFuSrv() then return end
    
--     local pack = LDataPack.allocPacket()
--     LDataPack.writeByte(pack, CrossSrvCmd.SCChampionCmd)
--     LDataPack.writeByte(pack, CrossSrvSubCmd.SCChampionCmd_SyncRankInfo)
    
--     local data = getSystemVar()
--     local dataUd = bson.encode(data.rank)
--     LDataPack.writeUserData(pack, dataUd)
--     System.sendPacketToAllGameClient(pack, serverid or 0)
-- end

--普通服收到战区同步数据
-- local function onSCCHRankInfo(sId, sType, dp)
--     if System.isCrossWarSrv() then return end
--     local dataUd = LDataPack.readUserData(dp)
--     local rank = bson.decode(dataUd)
--     local data = getSystemVar()
--     data.rank = rank
-- end

--连接跨服事件
-- local function onCHConnected(serverId, serverType)
--     sendCHRankInfo(serverId)
-- end

----------------------------------------------------------------------------------
--初始化
local function init()
    --if System.isCommSrv() then return end
    if System.isBattleSrv() then return end
    --if System.isLianFuSrv() then return end
    
    -- csbase.RegConnected(onCHConnected)
    -- csmsgdispatcher.Reg(CrossSrvCmd.SCChampionCmd, CrossSrvSubCmd.SCChampionCmd_SyncRankInfo, onSCCHRankInfo)
    
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cChampionCmd_ReqActorRank, c2sCHActorRank)
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cChampionCmd_ReqTeamRank, c2sCHTeamRank)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.printCHRank = function (actor, args)
    if System.isBattleSrv() then return end
    local data = getSystemVar()
    print("*******RankInfo*******")
    utils.printTable(data)
    print("************************")
    if System.isCommSrv() then
        SCTransferGM("printCHRank", args, true)
    end
end

gmCmdHandlers.clearCHRank = function (actor, args)
    if System.isBattleSrv() then return end
    clearChampionRankVar()
    if System.isCommSrv() then
        SCTransferGM("clearCTRank", args, true)
    end
end

gmCmdHandlers.sendCHRank = function (actor, args)
    if not System.isLianFuSrv() then return end
    sendCHActorRankReward()
    sendCHTeamRankReward()
end

