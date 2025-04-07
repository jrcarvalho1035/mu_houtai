-- 真红boss排行榜

module("zhenhongrank", package.seeall)

ZHRank_type = {
    summon = 1, --召唤榜
    kill = 2, --击杀榜
}

local function getRankConfig(rank_type)
    if rank_type == ZHRank_type.summon then
        return ZHSummonRankConfig
    elseif rank_type == ZHRank_type.kill then
        return ZHKillRankConfig
    end
end

local function getSystemVar()
    local var = System.getStaticVar()
    if not var then return end
    if not var.zhRank then
        var.zhRank = {
            summonRank = {},
            killRank = {},
            updateTime = getZHNextTime(),
        }
        for rank_type = ZHRank_type.summon, ZHRank_type.kill do
            local rank = getZHRank(rank_type)
            local rankConfig = getRankConfig(rank_type)
            
            for idx, conf in ipairs(rankConfig) do
                for i = conf.min, conf.max do
                    rank[i] = {
                        actorid = -1,
                        name = "",
                        score = conf.needScore,
                    }
                end
            end
        end
    end
    return var.zhRank
end

function getZHRank(rank_type)
    local var = getSystemVar()
    if rank_type == ZHRank_type.summon then
        return var.summonRank
    elseif rank_type == ZHRank_type.kill then
        return var.killRank
    end
end

local function getZHRankMax(rank_type)
    if rank_type == ZHRank_type.summon then
        return ZHSummonRankConfig[#ZHSummonRankConfig].max
    elseif rank_type == ZHRank_type.kill then
        return ZHKillRankConfig[#ZHKillRankConfig].max
    end
end

local function getScoreByRank(rank, rankConfig)
    for _, conf in ipairs(rankConfig) do
        for i = conf.min, conf.max do
            if rank == i then
                return conf.needScore
            end
        end
    end
end

local function sortRank(rank_type, rank, index)
    local minrank = getZHRankMax(rank_type)
    local rankConfig = getRankConfig(rank_type)
    local change = false
    if index <= minrank then
        change = true
    else
        if rank[index].score >= rank[minrank].score then
            rank[minrank], rank[index] = rank[index], rank[minrank]
            change = true
        end
    end
    if not change then return end
    for i = 1, minrank do
        for j = i + 1, minrank do
            if rank[i].score < rank[j].score then
                rank[i], rank[j] = rank[j], rank[i]
                if rank[j].actorid == -1 then
                    rank[j].score = getScoreByRank(j, rankConfig)
                end
            elseif rank[i].score == rank[j].score then
                if rank[i].actorid == -1 and rank[j].actorid ~= -1 then
                    rank[i], rank[j] = rank[j], rank[i]
                    if rank[j].actorid == -1 then
                        rank[j].score = getScoreByRank(j, rankConfig)
                    end
                end
            end
        end
    end
end

function setZHRankScore(rank_type, actorid, serverid, name, value)
    local rank = getZHRank(rank_type)
    local index
    for idx, item in ipairs(rank) do
        if item.actorid == actorid then
            item.score = item.score + value
            index = idx
            break
        end
    end
    
    if not index then
        rank[#rank + 1] = {
            actorid = actorid,
            serverid = serverid,
            name = name,
            score = value,
        }
        index = #rank
    end
    sortRank(rank_type, rank, index)
end

function sendzhRankReward()
    for rank_type = ZHRank_type.summon, ZHRank_type.kill do
        print("sendzhRankReward rank_type =", rank_type)
        local rank = getZHRank(rank_type)
        local rankConfig = getRankConfig(rank_type)
        
        for idx, conf in ipairs(rankConfig) do
            for i = conf.min, conf.max do
                local info = rank[i]
                if not info then break end
                print("rank = ", i, "actorid = ", info.actorid, "score = ", info.score)
                local mailData = {
                    head = conf.mailTitle,
                    context = string.format(conf.mailContent, i),
                    tAwardList = conf.rewards,
                }
                mailsystem.sendMailById(info.actorid, mailData, info.serverid)
            end
        end
        print("sendzhRankReward end")
    end
end

function flushZHRankReward()
    if not System.isBattleSrv() then return end
    sendzhRankReward()
    local var = System.getStaticVar()
    var.zhRank = nil
end

function checkZHRank()
    if not System.isBattleSrv() then return end
    local var = getSystemVar()
    local now = System.getNowTime()
    if var.updateTime <= now then
        flushZHRankReward()
    end
end

function getZHNextTime()
    local day = 6
    local hour = 22
    local minute = 30
    local now = System.getNowTime()
    local weekTime = System.getWeekFistTime()
    local nextTime = weekTime + day * 86400 + hour * 3600 + minute * 60
    if nextTime <= now then
        nextTime = nextTime + 604800
    end
    return nextTime
end

----------------------------------------------------------------------------------
--协议处理

--89-17 请求排行榜
local function c2sReqZHRankInfo(actor, packet)
    local rank_type = LDataPack.readChar(packet)
    SCReqZHRankInfo(actor, rank_type)
end

--89-17 返回排行榜
function s2cZHRankInfo(actor, rank_type, rank)
    if not rank then return end
    local count = getZHRankMax(rank_type)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.s2cZHBOSS_GetRank)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, rank_type)
    LDataPack.writeShort(pack, count)
    local myrank = 0
    local myscore = 0
    local actorid = LActor.getActorId(actor)
    
    for idx, info in ipairs(rank) do
        if info.actorid == actorid then
            myrank = count >= idx and idx or 0
            myscore = info.score
        end
        if idx <= count then
            LDataPack.writeString(pack, info.name)
            LDataPack.writeInt(pack, info.score)
        end
    end
    LDataPack.writeShort(pack, myrank)
    LDataPack.writeInt(pack, myscore)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--跨服协议

--普通服请求排行榜数据
function SCReqZHRankInfo(actor, rank_type)
    if System.isCrossWarSrv() then return end
    local actorid = LActor.getActorId(actor)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCZhenHongCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_ReqZHRankInfo)
    LDataPack.writeInt(pack, actorid)
    LDataPack.writeChar(pack, rank_type)
    System.sendPacketToAllGameClient(pack, 0)
end

--跨服收到普通服请求排行榜
local function onSCReqZHRankInfo(sId, sType, dp)
    if not System.isBattleSrv() then return end
    local actorid = LDataPack.readInt(dp)
    local rank_type = LDataPack.readChar(dp)
    
    local rank = getZHRank(rank_type)
    if not rank then return end
    local count = #rank
    
    --跨服给普通服发送排行榜数据
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCZhenHongCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_SendZHRankInfo)
    LDataPack.writeInt(pack, actorid)
    LDataPack.writeChar(pack, rank_type)
    LDataPack.writeShort(pack, count)
    
    for i = 1, count do
        LDataPack.writeInt(pack, rank[i].actorid)
        LDataPack.writeString(pack, rank[i].name)
        LDataPack.writeInt(pack, rank[i].score)
    end
    System.sendPacketToAllGameClient(pack, sId)
end

--普通服收到跨服排行榜数据
local function onSCSendZHRankInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local actorid = LDataPack.readInt(dp)
    local rank_type = LDataPack.readChar(dp)
    
    local rank = {}
    local count = LDataPack.readShort(dp)
    for i = 1, count do
        rank[i] = {
            actorid = LDataPack.readInt(dp),
            name = LDataPack.readString(dp),
            score = LDataPack.readInt(dp),
        }
    end
    local actor = LActor.getActorById(actorid)
    if actor then
        s2cZHRankInfo(actor, rank_type, rank)
    end
end

----------------------------------------------------------------------------------
--初始化
local function init()
    if System.isLianFuSrv() then return end
    checkZHRank()
    
    csmsgdispatcher.Reg(CrossSrvCmd.SCZhenHongCmd, CrossSrvSubCmd.SCCBCmd_ReqZHRankInfo, onSCReqZHRankInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCZhenHongCmd, CrossSrvSubCmd.SCCBCmd_SendZHRankInfo, onSCSendZHRankInfo)
    
    if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.c2sZHBOSS_GetRank, c2sReqZHRankInfo)
end
table.insert(InitFnTable, init)
_G.flushZHRankReward = flushZHRankReward

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.printZHRank = function (actor, args)
    local var = getSystemVar()
    print("*******RankInfo*******")
    utils.printTable(var)
    print("************************")
    if System.isCommSrv() then
        SCTransferGM("printZHRank")
    end
end

gmCmdHandlers.clearZHRank = function (actor, args)
    local var = System.getStaticVar()
    var.zhRank = nil
end

gmCmdHandlers.zhRankInfo = function (actor, args)
    local rank_type = tonumber(args[1])
    if not rank_type then return end
    SCReqZHRankInfo(actor, rank_type)
end

gmCmdHandlers.zhRankScore = function (actor, args)
    if System.isCommSrv() then
        local rank_type = tonumber(args[1])
        local score = tonumber(args[2])
        if not rank_type or not score then return end
        local actorid = LActor.getActorId(actor)
        local serverid = LActor.getServerId(actor)
        local name = LActor.getName(actor)
        SCTransferGM("zhRankScore", {rank_type, actorid, serverid, name, score})
    else
        if actor then
            local rank_type = tonumber(args[1])
            local score = tonumber(args[2])
            if not rank_type or not score then return end
            local actorid = LActor.getActorId(actor)
            local serverid = LActor.getServerId(actor)
            local name = LActor.getName(actor)
            setZHRankScore(rank_type, actorid, serverid, name, score)
        else
            local rank_type = tonumber(args[1])
            local actorid = tonumber(args[2])
            local serverid = tonumber(args[3])
            local name = args[4]
            local score = tonumber(args[5])
            setZHRankScore(rank_type, actorid, serverid, name, score)
        end
    end
end

