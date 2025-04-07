-- 合服巅峰赛排行榜

module("hefucuprank", package.seeall)

local function getSystemVar()
    local var = System.getStaticHefuCupVar()
    if not var then return end
    if not var.hfRank then
        var.hfRank = {
            fansRank = {},
        }
        local fansRank = var.hfRank.fansRank
        for idx, conf in ipairs(HefuCupRankConfig) do
            for i = conf.min, conf.max do
                fansRank[i] = {
                    actorid = -1,
                    name = "",
                    score = conf.needScore,
                }
            end
        end
    end
    return var.hfRank
end

local function getHFCupRankMax()
    return HefuCupRankConfig[#HefuCupRankConfig].max
end

function clearHFCupRankVar()
    local var = System.getStaticHefuCupVar()
    var.hfRank = nil
end

--榜单排序
local function sortRank(rank, index)
    local minrank = getHFCupRankMax()
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
                if rank[i].actorid == -1 then
                    rank[i].score = 0
                end
                rank[i], rank[j] = rank[j], rank[i]
            elseif rank[i].score == rank[j].score then--策划要求积分相同的两个玩家，战力高的在前
                if rank[i].actorid == -1 and rank[j].actorid ~= -1 then
                    rank[i].score = 0
                    rank[i], rank[j] = rank[j], rank[i]
                elseif rank[i].actorid ~= -1 and rank[j].actorid ~= -1 and (rank[i].power or 0) < (rank[j].power or 0) then
                    rank[i], rank[j] = rank[j], rank[i]
                end
            end
        end
    end
    
    for _, conf in ipairs(HefuCupRankConfig) do
        for i = conf.min, conf.max do
            if rank[i].actorid == -1 then
                rank[i].score = conf.needScore
            end
        end
    end
end

--记录榜单
function setFansRankScore(actorid, serverid, name, value)
    local data = getSystemVar()
    local rank = data.fansRank
    local oldFirstId = rank[1] and rank[1].actorid
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
    sortRank(rank, index)
end

--人气榜发奖
function sendfansRankReward()
    print("sendfansRankReward")
    local data = getSystemVar()
    local rank = data.fansRank
    for idx, conf in ipairs(HefuCupRankConfig) do
        for i = conf.min, conf.max do
            local info = rank[i]
            if not info then break end
            print("rank = ", i, "actorid = ", info.actorid, "score = ", info.score)
            local mailData = {
                head = string.format(conf.mailTitle, i),
                context = string.format(conf.mailContent, i),
                tAwardList = conf.rewards,
            }
            mailsystem.sendMailById(info.actorid, mailData, info.serverid)
        end
    end
    print("sendfansRankReward end")
end

----------------------------------------------------------------------------------
--协议处理

--91-5 请求人气排行榜
local function c2sReqFansRank(actor)
    s2cResFansRank(actor)
end

--91-5 返回人气排行榜
function s2cResFansRank(actor)
    if System.isBattleSrv() then
        local data = getSystemVar()
        local rank = data.fansRank
        local count = getHFCupRankMax()
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_ResFansRank)
        if pack == nil then return end
        
        LDataPack.writeInt(pack, count)
        local myrank = 0
        local myscore = 0
        local actorid = LActor.getActorId(actor)
        
        for idx, info in ipairs(rank) do
            if info.actorid == actorid then
                myrank = count >= idx and idx or 0
                myscore = info.score
            end
            if idx <= count then
                LDataPack.writeInt(pack, info.actorid)
                LDataPack.writeString(pack, info.name)
                LDataPack.writeInt(pack, info.score)
            end
        end
        LDataPack.writeInt(pack, myrank)
        LDataPack.writeInt(pack, myscore)
        LDataPack.flush(pack)
    else
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_FansRank)
        LDataPack.writeInt(pack, LActor.getActorId(actor))
        System.sendPacketToAllGameClient(pack, 0)
    end
end

----------------------------------------------------------------------------------
--跨服协议

--普通服收到跨服人气排行
local function onSCHFCupFansRank(sId, sType, dp)
    if System.isBattleSrv() then
        local actorid = LDataPack.readInt(dp)
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_FansRank)
        LDataPack.writeInt(pack, actorid)
        
        local data = getSystemVar()
        local rank = data.fansRank
        local count = getHFCupRankMax()
        LDataPack.writeInt(pack, count)
        local myrank = 0
        local myscore = 0
        
        for idx, info in ipairs(rank) do
            if info.actorid == actorid then
                myrank = count >= idx and idx or 0
                myscore = info.score
            end
            if idx <= count then
                LDataPack.writeInt(pack, info.actorid)
                LDataPack.writeString(pack, info.name)
                LDataPack.writeInt(pack, info.score)
            end
        end
        LDataPack.writeInt(pack, myrank)
        LDataPack.writeInt(pack, myscore)
        System.sendPacketToAllGameClient(pack, 0)
    else
        local actorid = LDataPack.readInt(dp)
        local actor = LActor.getActorById(actorid)
        if not actor then return end
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_ResFansRank)
        if pack == nil then return end
        
        local count = LDataPack.readInt(dp)
        LDataPack.writeInt(pack, count)
        for i = 1, count do
            LDataPack.writeInt(pack, LDataPack.readInt(dp))
            LDataPack.writeString(pack, LDataPack.readString(dp))
            LDataPack.writeInt(pack, LDataPack.readInt(dp))
        end
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.flush(pack)
    end
end

--普通服收到跨服排行榜数据
local function onSCSendRankInfo(sId, sType, dp)
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
            camp = LDataPack.readChar(dp),
        }
    end
    local actor = LActor.getActorById(actorid)
    if actor then
        s2cResFansRank(actor)
    end
end

----------------------------------------------------------------------------------
--初始化

local function init()
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cHFCupCmd_ReqFansRank, c2sReqFansRank)
    
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_FansRank, onSCHFCupFansRank)
    --csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_getFirstCache, onSCGetFirstCache)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.printHFCupRank = function (actor, args)
    local var = getSystemVar()
    print("*******RankInfo*******")
    utils.printTable(var)
    print("************************")
end

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.clearHFCupRank = function (actor, args)
    local var = System.getStaticHefuCupVar()
    var.hfRank = nil
end

gmCmdHandlers.gmFansScore = function (actor, args)
    local actorid = LActor.getActorId(actor)
    local serverid = LActor.getServerId(actor)
    local name = LActor.getName(actor)
    local value = tonumber(args[1]) or 1
    setFansRankScore(actorid, serverid, name, value)
end

