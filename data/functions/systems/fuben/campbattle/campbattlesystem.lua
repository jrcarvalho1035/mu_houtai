-- 神魔圣战赛季管理系统(阵营战)

module("campbattlesystem", package.seeall)

--[[
camp001 = "当前不在活动时间内"
camp002 = "队伍已解散"
camp003 = "队伍已满员"
camp004 = "你已被请离队伍"
camp005 = "匹配中不能请离队员"
camp006 = "你不是队长，无法进行此操作"
camp007 = "该玩家已加入其他队伍"
camp008 = "该玩家不属于队伍的阵营"
camp009 = "当前不在匹配场景，无法进行组队操作"
camp010 = "当前不在赛季活动时间"
camp011 = "队伍已取消匹配"
camp012 = "队伍正在匹配中"
camp013 = ""匹配成功"
camp014 = "申请成功，等待队长审核"
camp015 = "已经在申请列表中"
camp016 = "预留"
camp017 = "预留"
camp018 = "预留"
camp019 = "预留"
camp020 = "预留"
camp021 = "预留"
camp022 = "预留"
camp023 = "预留"
camp024 = "预留"
camp025 = "预留"
camp026 = "预留"
camp027 = "预留"
camp028 = "预留"
camp029 = "预留"
camp030 = "预留"
]]

local CAMP_COUNT
local week_sec = 604800
local seasonOpen = false
local dayOpen = false

CBSeasonData = CBSeasonData or {}
--[[
    seasonCampTime = 0, --划分阵营的时间(取跨服组中每个服战力榜前X名进行划分)
    seasonStartTime = 0, --赛季开始时间，即赛季重置
    seasonEndTime = 0, --赛季结束时间，即赛季结算
    nextSeasonTime = 0, --下次赛季开始时间,即循环
    dateTime = {}, --用来存放每日的活动时间
]]

local function getCBSeasonData()
    return CBSeasonData
end

local function getSystemVar()
    local var = System.getStaticCampBattleVar()
    if not var then return end
    if not var.cbseason then
        var.cbseason = {
            season = 0, --第X赛季
            seasonCampTime = 0, --划分阵营的时间(取跨服组中每个服战力榜前X名进行划分)
            seasonStartTime = 0, --赛季开始时间，即赛季重置
            seasonEndTime = 0, --赛季结束时间，即赛季结算
            nextSeasonTime = 0, --下次赛季开始时间,即循环
            serverCampList = {}, --用来存放从普通服收集的战力榜数据
            actorCampList = {}, --用来存放从排序好的数据,
        }
    end
    return var.cbseason
end

local function checkCBSeasonOpen()
    local var = getSystemVar()
    return var.isOpen == 1
end

local function loadCBTime()
    if System.isLianFuSrv() then return end
    local data = getCBSeasonData()
    
    data.dateTime = {}
    local weektime = System.getWeekFistTime()
    
    local d, h, m = string.match(CampBattleCommonConfig.campTime, "(%d+)-(%d+):(%d+)")
    data.seasonCampTime = weektime + d * 86400 + h * 3600 + m * 60
    
    d, h, m = string.match(CampBattleCommonConfig.startTime, "(%d+)-(%d+):(%d+)")
    data.seasonStartTime = weektime + d * 86400 + h * 3600 + m * 60
    
    d, h, m = string.match(CampBattleCommonConfig.endTime, "(%d+)-(%d+):(%d+)")
    data.seasonEndTime = weektime + d * 86400 + h * 3600 + m * 60
    
    for week, conf in pairs(CampBattleSeasonConfig) do
        local sD, sH, sM = string.match(conf.dayStartTime, "(%d+)-(%d+):(%d+)")
        local eD, eH, eM = string.match(conf.dayEndTime, "(%d+)-(%d+):(%d+)")
        data.dateTime[week] = {
            dayStartTime = weektime + sD * 86400 + sH * 3600 + sM * 60,
            dayEndTime = weektime + eD * 86400 + eH * 3600 + eM * 60,
        }
    end
    
    local now = System.getNowTime()
    local wDay = System.getDayOfWeek()
    
    if now >= data.seasonStartTime and now < data.seasonEndTime then
        seasonOpen = true
    end
    if now >= data.dateTime[wDay].dayStartTime and now < data.dateTime[wDay].dayEndTime then
        dayOpen = true
    end
end

local function reSetCBSeason()
    if System.isLianFuSrv() then return end
    local var = getSystemVar()
    var.season = var.season + 1
    var.serverCampList = {}
    var.actorCampList = {}
    campbattle.clearCampBattleVar()
    campbattlerank.clearCampBattleRankVar()
    
    local data = getCBSeasonData()
    var.nextSeasonTime = System.getWeekFistTime() + week_sec
end

local function checkCampTime()
    if not System.isBattleSrv() then return end
    SCReqUpdateRankPower()
    
    local var = getSystemVar()
    local data = getCBSeasonData()
    if System.getNowTime() < data.seasonCampTime then
        var.seasonCampTime = data.seasonCampTime
    else
        var.seasonCampTime = data.seasonCampTime + week_sec
    end
end

local function seasonCBBegin()
    if System.isLianFuSrv() then return end
    seasonOpen = true
    if System.isCommSrv() then return end
    local var = getSystemVar()
    local list = {}
    for sId, serverList in pairs(var.serverCampList) do
        for actorid, info in pairs(serverList) do
            table.insert(list, {actorid = info.actorid, power = info.power})
        end
    end
    table.sort(list, function (a, b) return a.power > b.power end)
    
    local camp = campbattle.getRandomCamp()
    var.actorCampList = {}
    for _, info in ipairs(list) do
        var.actorCampList[info.actorid] = camp
        camp = camp % CAMP_COUNT + 1
    end
    
    local data = getCBSeasonData()
    if System.getNowTime() < data.seasonStartTime then
        var.seasonStartTime = data.seasonStartTime
    else
        var.seasonStartTime = data.seasonStartTime + week_sec
    end
    System.saveStaticCampBattle()
    
    local actors = System.getOnlineActorList()
    if actors then
        for _, actor in ipairs(actors) do
            campbattle.updateActorCBInfo(actor)
        end
    end
end

local function seasonCBFinish()
    if System.isLianFuSrv() then return end
    seasonOpen = false
    local actors = System.getOnlineActorList()
    if actors then
        for _, actor in ipairs(actors) do
            campbattle.updateActorCBInfo(actor)
        end
    end
    if System.isCommSrv() then return end
    campbattlerank.sendCBRankReward()
    
    local var = getSystemVar()
    local data = getCBSeasonData()
    if System.getNowTime() < data.seasonEndTime then
        var.seasonEndTime = data.seasonEndTime
    else
        var.seasonEndTime = data.seasonEndTime + week_sec
    end
    System.saveStaticCampBattle()
end

local function dayCBStart()
    if System.isLianFuSrv() then return end
    dayOpen = true
    local actors = System.getOnlineActorList()
    if actors then
        for _, actor in ipairs(actors) do
            campbattle.updateActorCBInfo(actor)
        end
    end
end

local function dayCBEnd()
    if System.isLianFuSrv() then return end
    dayOpen = false
    local actors = System.getOnlineActorList()
    if actors then
        for _, actor in ipairs(actors) do
            campbattle.updateActorCBInfo(actor)
        end
    end
end

--外部接口,获取当前赛季活动时间
function getCBOpenTime()
    local data = getCBSeasonData()
    local wDay = System.getDayOfWeek()
    local seasonStartTime = data.seasonStartTime
    local seasonEndTime = data.seasonEndTime
    local dayStartTime = data.dateTime[wDay].dayStartTime
    local dayEndTime = data.dateTime[wDay].dayEndTime
    return seasonStartTime, seasonEndTime, dayStartTime, dayEndTime
end

function getCBOpenStatus()
    return seasonOpen, dayOpen
end

--每日活动是否开启
function isCBDayOpen()
    -- local now = System.getNowTime()
    -- local wDay = System.getDayOfWeek()
    -- local data = getCBSeasonData()
    -- if now >= data.dateTime[wDay].dayStartTime and now < data.dateTime[wDay].dayEndTime then
    --     return true
    -- end
    return dayOpen
end

--阵营划分是否开启
function isCBCampOpen()
    -- local now = System.getNowTime()
    -- local data = getCBSeasonData()
    -- if now >= data.seasonStartTime and now < data.seasonEndTime then
    --     return true
    -- end
    return seasonOpen
end

function getActorCampList()
    local var = getSystemVar()
    return var.actorCampList
end

----------------------------------------------------------------------------------
--事件处理

--检查赛季是否重置
function checkCBSeason()
    if System.isLianFuSrv() then return end
    loadCBTime()
    if System.isCommSrv() then return end
    
    local var = getSystemVar()
    local data = getCBSeasonData()
    local now = System.getNowTime()
    
    if var.seasonEndTime < now then
        seasonCBFinish()
    end
    
    if var.nextSeasonTime < now then
        reSetCBSeason()
    end
    
    --如果是上周的时间，就不用马上再划分一次了
    if var.seasonCampTime < now and data.seasonCampTime < now then
        checkCampTime()
    end
    
    --如果是上周的时间，就不用马上再划分一次了
    if var.seasonStartTime < now and data.seasonStartTime < now then
        seasonCBBegin()
    end
    
    System.saveStaticCampBattle()
end

_G.loadCBTime = loadCBTime
_G.reSetCBSeason = reSetCBSeason
_G.checkCampTime = checkCampTime
_G.seasonCBBegin = seasonCBBegin
_G.seasonCBFinish = seasonCBFinish
_G.dayCBStart = dayCBStart
_G.dayCBEnd = dayCBEnd
----------------------------------------------------------------------------------
--跨服协议

--跨服通知普通服发送战力榜数据
function SCReqUpdateRankPower(severid)
    if not System.isBattleSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCCampBattle)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_ReqUpdateRankPower)
    System.sendPacketToAllGameClient(pack, severid or 0)
end

--跨服收到普通服战力榜排名数据
local function onSCReqUpdateRankPower(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local rank = Ranking.getRanking("powerrank")
    if not rank then return end
    local rankTbl = Ranking.getRankingItemList(rank, CampBattleCommonConfig.topCount)
    if rankTbl == nil then return end
    
    --普通服给跨服发送战力榜数据
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCCampBattle)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_ResUpdateRankPower)
    LDataPack.writeByte(pack, #rankTbl)
    if rankTbl and #rankTbl > 0 then
        for i = 1, #rankTbl do
            local prank = rankTbl[i]
            local value = Ranking.getPoint(prank)
            LDataPack.writeInt(pack, Ranking.getId(prank))
            LDataPack.writeDouble(pack, value)
        end
    end
    System.sendPacketToAllGameClient(pack, 0)
end

--跨服收到普通服战力榜排名数据
local function onSCResUpdateRankPower(sId, sType, dp)
    if not System.isBattleSrv() then return end
    
    local var = getSystemVar()
    serverCampList = var.serverCampList
    if not serverCampList[sId] then
        serverCampList[sId] = {}
    else
        return
    end
    local list = serverCampList[sId]
    local count = LDataPack.readByte(dp)
    for i = 1, count do
        local actorid = LDataPack.readInt(dp)
        list[actorid] = {
            actorid = actorid,
            power = LDataPack.readDouble(dp),
        }
    end
end

-- function OnCBConnected(sId, sType)
--     if System.isCommSrv() then return end
--     local var = getSystemVar()
--     if var.serverCampList[sId] then return end
--     SCReqUpdateRankPower(sId)
-- end

----------------------------------------------------------------------------------
--初始化

local function init()
    --csbase.RegConnected(OnCBConnected)
    CAMP_COUNT = campbattle.CAMP_COUNT
    if System.isLianFuSrv() then return end
    checkCBSeason()
    
    csmsgdispatcher.Reg(CrossSrvCmd.SCCampBattle, CrossSrvSubCmd.SCCBCmd_ReqUpdateRankPower, onSCReqUpdateRankPower)
    csmsgdispatcher.Reg(CrossSrvCmd.SCCampBattle, CrossSrvSubCmd.SCCBCmd_ResUpdateRankPower, onSCResUpdateRankPower)
    
    --if System.isCommSrv() then return end
    --if System.isBattleSrv() then return end
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.printSeason = function (actor, args)
    local var = getSystemVar()
    print("*******SeasonInfo*******")
    utils.printTable(var)
    print("************************")
end

gmCmdHandlers.clearSeason = function (actor, args)
    local var = System.getStaticCampBattleVar()
    var.cbseason = nil
    checkCBSeason()
end

gmCmdHandlers.campSeason = function (actor, args)
    SCReqUpdateRankPower()
end

gmCmdHandlers.printSeasonData = function (actor, args)
    local data = getCBSeasonData()
    print("*******SeasonInfo*******")
    utils.printTable(data)
    print("************************")
end

gmCmdHandlers.cbSeasonOpen = function (actor, args)
    seasonOpen = true
    campbattle.updateActorCBInfo(actor)
    if System.isCommSrv() then
        SCTransferGM("cbSeasonOpen")
    end
end

gmCmdHandlers.cbSeasonClose = function (actor, args)
    seasonOpen = false
    campbattle.updateActorCBInfo(actor)
    if System.isCommSrv() then
        SCTransferGM("cbSeasonClose")
    end
end

gmCmdHandlers.cbDayOpen = function (actor, args)
    dayOpen = true
    campbattle.updateActorCBInfo(actor)
    if System.isCommSrv() then
        SCTransferGM("cbDayOpen")
    end
end

gmCmdHandlers.cbDayClose = function (actor, args)
    dayOpen = false
    campbattle.updateActorCBInfo(actor)
    if System.isCommSrv() then
        SCTransferGM("cbDayClose")
    end
end

