-- 神魔圣战排行榜(阵营战)

module("campbattlerank", package.seeall)

CBRank_type = {
    allRank = 0,
    godRank = 1,
    devilRank = 2,
}

local function getRankConfig(rank_type)
    if rank_type == CBRank_type.allRank then
        return CampBattleSelfRankConfig
    elseif rank_type == CBRank_type.godRank then
        return CampBattleGodRankConfig
    elseif rank_type == CBRank_type.devilRank then
        return CampBattleDevilRankConfig
    end
end

local function getSystemVar()
    local var = System.getStaticCampBattleVar()
    if not var then return end
    if not var.cbRank then
        var.cbRank = {
            allRank = {},
            godRank = {},
            devilRank = {},
        }
        for rank_type = CBRank_type.allRank, CBRank_type.devilRank do
            local rank = getCBRank(rank_type)
            local rankConfig = getRankConfig(rank_type)
            
            for idx, conf in ipairs(rankConfig) do
                for i = conf.min, conf.max do
                    rank[i] = {
                        actorid = -1,
                        name = "",
                        score = conf.needScore,
                        camp = 0,
                    }
                end
            end
        end
    end
    return var.cbRank
end

function getCBRank(rank_type)
    local var = getSystemVar()
    if rank_type == CBRank_type.allRank then
        return var.allRank
    elseif rank_type == CBRank_type.godRank then
        return var.godRank
    elseif rank_type == CBRank_type.devilRank then
        return var.devilRank
    end
end

local function getCBRankMax(rank_type)
    if rank_type == CBRank_type.allRank then
        return CampBattleSelfRankConfig[#CampBattleSelfRankConfig].max
    elseif rank_type == CBRank_type.godRank then
        return CampBattleGodRankConfig[#CampBattleGodRankConfig].max
    elseif rank_type == CBRank_type.devilRank then
        return CampBattleDevilRankConfig[#CampBattleDevilRankConfig].max
    end
end

function clearCampBattleRankVar()
    local var = System.getStaticCampBattleVar()
    var.cbRank = nil
end

local function sortRank(rank_type, rank, index)
    local minrank = getCBRankMax(rank_type)
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
    
    for _, conf in ipairs(rankConfig) do
        for i = conf.min, conf.max do
            if rank[i].actorid == -1 then
                rank[i].score = conf.needScore
            end
        end
    end
end

function setCBRankScore(rank_type, actorid, serverid, name, value, camp, power)
    if rank_type == CBRank_type.godRank or rank_type == CBRank_type.devilRank then
        setCBRankScore(CBRank_type.allRank, actorid, serverid, name, value, camp, power)
    end
    
    local rank = getCBRank(rank_type)
    local oldFirstId = rank[1] and rank[1].actorid
    local index
    for idx, item in ipairs(rank) do
        if item.actorid == actorid then
            item.score = value
            item.power = power
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
            camp = camp,
            power = power,
        }
        index = #rank
    end
    sortRank(rank_type, rank, index)
    
    local firstId = rank[1] and rank[1].actorid
    if firstId and firstId ~= oldFirstId then
        SCGetRankFirstCache(rank[1].actorid, rank[1].serverid, rank_type)
    end
end

function sendCBRankReward()
    for rank_type = CBRank_type.allRank, CBRank_type.devilRank do
        print("sendCBRankReward rank_type =", rank_type)
        local rank = getCBRank(rank_type)
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
        print("sendCBRankReward end")
    end
end

----------------------------------------------------------------------------------
--协议处理

--89-17 请求排行榜
local function c2sReqCBRankInfo(actor, packet)
    local rank_type = LDataPack.readChar(packet)
    if System.isBattleSrv() then
        s2cCBRankInfo(actor, rank_type)
    else
        SCReqRankInfo(actor, rank_type)
    end
end

--89-17 返回排行榜
function s2cCBRankInfo(actor, rank_type, rank)
    if not rank then
        rank = getCBRank(rank_type)
        if not rank then return end
    end
    local count = getCBRankMax(rank_type)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_ResCBRankInfo)
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
            LDataPack.writeChar(pack, info.camp)
        end
    end
    LDataPack.writeShort(pack, myrank)
    LDataPack.writeInt(pack, myscore)
    
    if not rank.firstCache then
        rank.firstCache = {}
    end
    local firstCache = rank.firstCache
    LDataPack.writeByte(pack, firstCache.job or 0)
    LDataPack.writeInt(pack, firstCache.shenzhuangid or 0)
    LDataPack.writeInt(pack, firstCache.shenqiid or 0)
    LDataPack.writeInt(pack, firstCache.wingid or 0)
    LDataPack.writeInt(pack, firstCache.touxian or 0)
    LDataPack.writeInt(pack, firstCache.title or 0)
    LDataPack.writeInt(pack, firstCache.mozhenid or 0)
    LDataPack.writeInt(pack, firstCache.damonid or 0)
    LDataPack.writeInt(pack, firstCache.meilinid or 0)
    
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--跨服协议

--普通服请求排行榜数据
function SCReqRankInfo(actor, rank_type)
    if System.isCrossWarSrv() then return end
    local actorid = LActor.getActorId(actor)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCCampBattle)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_ReqRankInfo)
    LDataPack.writeInt(pack, actorid)
    LDataPack.writeChar(pack, rank_type)
    System.sendPacketToAllGameClient(pack, 0)
end

--跨服收到普通服请求排行榜
local function onSCReqRankInfo(sId, sType, dp)
    if not System.isBattleSrv() then return end
    local actorid = LDataPack.readInt(dp)
    local rank_type = LDataPack.readChar(dp)
    
    local rank = getCBRank(rank_type)
    if not rank then return end
    local count = #rank
    
    --跨服给普通服发送排行榜数据
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCCampBattle)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_SendRankInfo)
    LDataPack.writeInt(pack, actorid)
    LDataPack.writeChar(pack, rank_type)
    LDataPack.writeShort(pack, count)
    
    for i = 1, count do
        LDataPack.writeInt(pack, rank[i].actorid)
        LDataPack.writeString(pack, rank[i].name)
        LDataPack.writeInt(pack, rank[i].score)
        LDataPack.writeChar(pack, rank[i].camp)
    end
    
    if not rank.firstCache then
        rank.firstCache = {}
    end
    local firstCache = rank.firstCache
    if firstCache then
        LDataPack.writeChar(pack, firstCache.job or 0)
        LDataPack.writeInt(pack, firstCache.shenzhuangid or 0)
        LDataPack.writeInt(pack, firstCache.shenqiid or 0)
        LDataPack.writeInt(pack, firstCache.wingid or 0)
        LDataPack.writeInt(pack, firstCache.touxian or 0)
        LDataPack.writeInt(pack, firstCache.title or 0)
        LDataPack.writeInt(pack, firstCache.mozhenid or 0)
        LDataPack.writeInt(pack, firstCache.damonid or 0)
        LDataPack.writeInt(pack, firstCache.meilinid or 0)
    end
    
    System.sendPacketToAllGameClient(pack, sId)
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
    
    rank.firstCache = {
        job = LDataPack.readChar(dp),
        shenzhuangid = LDataPack.readInt(dp),
        shenqiid = LDataPack.readInt(dp),
        wingid = LDataPack.readInt(dp),
        touxian = LDataPack.readInt(dp),
        title = LDataPack.readInt(dp),
        mozhenid = LDataPack.readInt(dp),
        damonid = LDataPack.readInt(dp),
        meilinid = LDataPack.readInt(dp),
    }
    local actor = LActor.getActorById(actorid)
    if actor then
        s2cCBRankInfo(actor, rank_type, rank)
    end
end

--跨服请求普通服第一名数据缓存
function SCGetRankFirstCache(actorid, serverid, rank_type)
    if not System.isBattleSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCCampBattle)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_GetRankFirstCache)
    LDataPack.writeInt(pack, actorid)
    LDataPack.writeChar(pack, rank_type)
    System.sendPacketToAllGameClient(pack, serverid)
end

--普通服收到跨服请求第一名数据缓存
local function onSCGetRankFirstCache(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local actorid = LDataPack.readInt(dp)
    local rank_type = LDataPack.readChar(dp)
    local actorData = offlinedatamgr.GetDataByOffLineDataType(actorid, offlinedatamgr.EOffLineDataType.EBasic)
    if not actorData then return end
    
    --跨服给普通服发送排行榜第一名数据缓存
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCCampBattle)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_SendRankFirstCache)
    LDataPack.writeInt(pack, actorid)
    LDataPack.writeChar(pack, rank_type)
    
    LDataPack.writeByte(pack, actorData.job)
    LDataPack.writeInt(pack, actorData.shenzhuangchoose)
    LDataPack.writeInt(pack, actorData.shenqichoose)
    LDataPack.writeInt(pack, actorData.wingchoose)
    LDataPack.writeInt(pack, actorData.touxian)
    LDataPack.writeInt(pack, actorData.title or 0)
    LDataPack.writeInt(pack, actorData.mozhen or 0)
    LDataPack.writeInt(pack, actorData.damonchoose)
    LDataPack.writeInt(pack, actorData.meilinchoose)
    
    System.sendPacketToAllGameClient(pack, 0)
end

--跨服收到普通服第一名数据缓存
local function onSCSendRankFirstCache(sId, sType, dp)
    if not System.isBattleSrv() then return end
    actorid = LDataPack.readInt(dp)
    rank_type = LDataPack.readChar(dp)
    local rank = getCBRank(rank_type)
    if not rank.firstCache then
        rank.firstCache = {}
    end
    local firstCache = rank.firstCache
    firstCache.job = LDataPack.readByte(dp)
    firstCache.shenzhuangid = LDataPack.readInt(dp)
    firstCache.shenqiid = LDataPack.readInt(dp)
    firstCache.wingid = LDataPack.readInt(dp)
    firstCache.touxian = LDataPack.readInt(dp)
    firstCache.title = LDataPack.readInt(dp)
    firstCache.mozhenid = LDataPack.readInt(dp)
    firstCache.damonid = LDataPack.readInt(dp)
    firstCache.meilinid = LDataPack.readInt(dp)
end

----------------------------------------------------------------------------------
--初始化

local function init()
    --if System.isCommSrv() then return end
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
    csmsgdispatcher.Reg(CrossSrvCmd.SCCampBattle, CrossSrvSubCmd.SCCBCmd_ReqRankInfo, onSCReqRankInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCCampBattle, CrossSrvSubCmd.SCCBCmd_SendRankInfo, onSCSendRankInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCCampBattle, CrossSrvSubCmd.SCCBCmd_GetRankFirstCache, onSCGetRankFirstCache)
    csmsgdispatcher.Reg(CrossSrvCmd.SCCampBattle, CrossSrvSubCmd.SCCBCmd_SendRankFirstCache, onSCSendRankFirstCache)
    
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_ReqCBRankInfo, c2sReqCBRankInfo)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.printRank = function (actor, args)
    local var = getSystemVar()
    print("*******RankInfo*******")
    utils.printTable(var)
    print("************************")
end

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.clearRank = function (actor, args)
    local var = System.getStaticCampBattleVar()
    var.cbRank = nil
end
