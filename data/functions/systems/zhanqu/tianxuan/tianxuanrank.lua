--天选之战(排行榜)

module("tianxuanrank", package.seeall)
local rankingListMaxSize = 50

local function getSystemVar()
    local var = System.getStaticVar()
    if not var then return end
    if not var.tiaxnuanRank then
        var.tiaxnuanRank = {
            rank = {},
        }
    end
    return var.tiaxnuanRank
end

function clearTianXuanRankVar()
    local data = System.getStaticVar()
    data.tiaxnuanRank = nil
end

function getTXRank()
    local data = getSystemVar()
    return data.rank
end

function addTXRankScore(actorid, serverid, name, value)
    local data = getSystemVar()
    local rank = data.rank
    
    local now = System.getNowTime()
    local isHave
    for idx, item in ipairs(rank) do
        if item.actorid == actorid then
            item.score = item.score + value
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
        }
    end
    table.sort(rank, function (a, b) return a.score > b.score end)
end

function sendTXRankReward()
    print("on sendTXRankReward")
    local data = getSystemVar()
    local rank = data.rank
    
    for _, conf in ipairs(TianXuanRankConfig) do
        for idx = conf.min, conf.max do
            local info = rank[idx]
            if not info then break end
            print("rank = ", idx, "actorid = ", info.actorid, "score = ", info.score)
            local mailData = {
                head = TianXuanCommonConfig.rankMailTitle,
                context = string.format(TianXuanCommonConfig.rankMailContent, info.score, idx),
                tAwardList = conf.rewards,
            }
            mailsystem.sendMailById(info.actorid, mailData, info.serverid)
        end
    end
    print("sendTXRankReward end")
    sendTXRankInfo()
end

----------------------------------------------------------------------------------
--协议处理

--92-21 请求排行榜
local function c2sTXRankInfo(actor)
    s2cTXRankInfo(actor)
end

--92-21 返回排行榜
function s2cTXRankInfo(actor)
    local data = getSystemVar()
    local rank = data.rank
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sTianxuanCmd_Rank)
    if pack == nil then return end
    
    local count = math.min(#rank, rankingListMaxSize)
    LDataPack.writeShort(pack, count)
    local myrank = 0
    local myscore = 0
    
    local actorid = LActor.getActorId(actor)
    for idx, info in ipairs(rank) do
        if idx <= rankingListMaxSize then
            LDataPack.writeInt(pack, info.actorid)
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
----------------------------------------------------------------------------------
--跨服协议

--战区同步数据到普通服
function sendTXRankInfo(serverid)
    if not System.isLianFuSrv() then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCTianXuanCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianXuanCmd_SyncRankInfo)
    
    local data = getSystemVar()
    local dataUd = bson.encode(data.rank)
    LDataPack.writeUserData(pack, dataUd)
    System.sendPacketToAllGameClient(pack, serverid or 0)
end

--普通服收到战区同步数据
local function onSCTXRankInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local dataUd = LDataPack.readUserData(dp)
    local rank = bson.decode(dataUd)
    local data = getSystemVar()
    data.rank = rank
end

--连接跨服事件
local function onTXConnected(serverId, serverType)
    sendTXRankInfo(serverId)
end

----------------------------------------------------------------------------------
--初始化

local function init()
    --if System.isCommSrv() then return end
    if System.isBattleSrv() then return end
    --if System.isLianFuSrv() then return end
    
    csbase.RegConnected(onTXConnected)
    csmsgdispatcher.Reg(CrossSrvCmd.SCTianXuanCmd, CrossSrvSubCmd.SCTianXuanCmd_SyncRankInfo, onSCTXRankInfo)
    
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cTianxuanCmd_Rank, c2sTXRankInfo)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.printTXRank = function (actor, args)
    if System.isBattleSrv() then return end
    local data = getSystemVar()
    print("*******RankInfo*******")
    utils.printTable(data)
    print("************************")
    if System.isCommSrv() then
        SCTransferGM("printTXRank", args, true)
    end
end

gmCmdHandlers.clearTXRank = function (actor, args)
    if System.isBattleSrv() then return end
    clearTianXuanRankVar()
    if System.isCommSrv() then
        SCTransferGM("clearTXRank", args, true)
    end
end

