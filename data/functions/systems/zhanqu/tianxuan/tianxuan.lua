--天选之战
module("tianxuan", package.seeall)

MATCH_POOL = MATCH_POOL or {} --等待匹配池
MATCH_NEED_COUNT = 2 --匹配的人数
MATCH_CAN_COUNT = MATCH_NEED_COUNT --达到此人数开始匹配
MATCH_SUCCESS_WAIT = 3 --匹配成功后等待进入副本时间(秒)
TEAM_MAX_MEMBER = 1 -- 队伍最大玩家数量

txTeamType = {
    home = 1, --主队
    away = 2, --客队
}

txStatusType = {
    default = 0,
    start = 1,
    stop = 2,
    settlement = 3,
    close = 4,
}

matchStatusType = {
    Await = 0, --未匹配
    Match = 1, --匹配中
    Fight = 2, --战斗中
}

local function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.tianxuan then
        var.tianxuan = {
            --score = 0,
            matchCount = 0,
            matchStatus = 0,
            rewardsRecord = {},
        }
    end
    return var.tianxuan
end

local function getSystemVar()
    local var = System.getStaticVar()
    if not var then return end
    if not var.tianxuan then
        local weekTime = System.getWeekFistTime()
        local sd, sh, sm = string.match(TianXuanCommonConfig.startTime, "(%d+)-(%d+):(%d+)")
        local startTime = weekTime + sd * 24 * 3600 + sh * 3600 + sm * 60
        local ed, eh, em = string.match(TianXuanCommonConfig.endTime, "(%d+)-(%d+):(%d+)")
        local endTime = weekTime + ed * 24 * 3600 + eh * 3600 + em * 60
        local cd, ch, cm = string.match(TianXuanCommonConfig.closeTime, "(%d+)-(%d+):(%d+)")
        local closeTime = weekTime + cd * 24 * 3600 + ch * 3600 + cm * 60
        var.tianxuan = {
            status = 0,
            nextTime = weekTime + sd * 24 * 3600 + 604800,
            startTime = startTime,
            endTime = endTime,
            closeTime = closeTime,
            actorScore = {},
        }
    end
    return var.tianxuan
end

local function getTXScoreByActorId(actorId)
    local data = getSystemVar()
    return data.actorScore[actorId] or 0
end

local function reSetTXActor(actor)
    local var = LActor.getStaticVar(actor)
    var.tianxuan = nil
end

local function checkTXOpen()
    local data = getSystemVar()
    return data.status == txStatusType.start
end

local function checkTXMatchStatus(actor, statusType)
    local var = getActorVar(actor)
    if not var then return false end
    if var.matchStatus ~= statusType then return false end
    return true
end

local function canTXMatch(actor)
    local var = getActorVar(actor)
    if not var then return false end
    if var.matchStatus ~= matchStatusType.Match then return false end
    return true
end

local function checkTXStatusAwait(actor)
    return checkTXMatchStatus(actor, matchStatusType.Await)
end

local function checkTXStatusMatch(actor)
    return checkTXMatchStatus(actor, matchStatusType.Match)
end

local function checkTXStatusFight(actor)
    return checkTXMatchStatus(actor, matchStatusType.Fight)
end

--外部接口，增加天选积分
function addTXActorScore(actorId, value)
    local data = getSystemVar()
    data.actorScore[actorId] = (data.actorScore[actorId] or 0) + value
end

function checkTXMatchPool()
    if #MATCH_POOL < MATCH_CAN_COUNT then return end
    
    --从匹配池选取足够数量的玩家
    local matchList = {}
    for _, actor in ipairs(MATCH_POOL) do
        if canTXMatch(actor) then
            table.insert(matchList, actor)
        end
        if #matchList >= MATCH_NEED_COUNT then break end
    end
    createTXFuben(matchList)
end

function setTXStatusAwait(actor)
    local var = getActorVar(actor)
    if not var then return end
    var.matchStatus = matchStatusType.Await
    removeTXMatchPoolByActor(actor)
    s2cTXMatch(actor)
end

function setTXStatusMatch(actor)
    local var = getActorVar(actor)
    if not var then return end
    var.matchStatus = matchStatusType.Match
    table.insert(MATCH_POOL, actor)
    s2cTXMatch(actor)
end

function setTXStatusFight(actor, myTeam, rivalTeam)
    local var = getActorVar(actor)
    if not var then return end
    var.matchStatus = matchStatusType.Fight
    var.matchCount = var.matchCount + 1
    removeTXMatchPoolByActor(actor)
    s2cTXMatch(actor, true, myTeam, rivalTeam)
end

function cancelTXMatch(actor)
    setTXStatusAwait(actor)
end

function removeTXMatchPoolByActor(actor)
    for idx, nactor in ipairs(MATCH_POOL) do
        if nactor == actor then
            table.remove(MATCH_POOL, idx)
            break
        end
    end
end

function createTXFuben(matchList)
    --初始化队伍数据
    local teamList = {
        [txTeamType.home] = {
            teamId = txTeamType.home,
            rivalId = txTeamType.away,
            memberList = {},
            point = 0,
            mvp = {actorid = 0, score = 0},
            result = 0,
            notices = {},
        },
        [txTeamType.away] = {
            teamId = txTeamType.away,
            rivalId = txTeamType.home,
            memberList = {},
            point = 0,
            mvp = {actorid = 0, score = 0},
            result = 0,
            notices = {},
        },
    }
    
    --按照配置规则分配队员
    local powers = {}
    for _, actor in ipairs(matchList) do
        local power = LActor.getPower(actor)
        table.insert(powers, {actor = actor, power = power})
    end
    table.sort(powers, function(a, b) return a.power > b.power end)
    
    local homeTeamId = txTeamType.home
    local awayTeamId = txTeamType.away
    
    local homeTeam = teamList[homeTeamId]
    for i, idx in ipairs(TianXuanTeamConfig[homeTeamId].matchMember) do
        local actor = powers[idx].actor
        local var = getActorVar(actor)
        local actorid = LActor.getActorId(actor)
        local aInfo = {
            idx = idx,
            teamId = homeTeamId,
            rivalId = awayTeamId,
            actorid = actorid,
            serverid = LActor.getServerId(actor),
            name = LActor.getName(actor),
            job = LActor.getJob(actor),
            power = powers[idx].power,
            score = getTXScoreByActorId(actorid),
            isLeave = 0,
        }
        table.insert(homeTeam.memberList, aInfo)
    end
    
    local awayTeam = teamList[awayTeamId]
    for i, idx in ipairs(TianXuanTeamConfig[awayTeamId].matchMember) do
        local actor = powers[idx].actor
        local var = getActorVar(actor)
        local actorid = LActor.getActorId(actor)
        local aInfo = {
            idx = idx,
            teamId = awayTeamId,
            rivalId = homeTeamId,
            actorid = actorid,
            serverid = LActor.getServerId(actor),
            name = LActor.getName(actor),
            job = LActor.getJob(actor),
            power = powers[idx].power,
            score = getTXScoreByActorId(actorid),
            isLeave = 0,
        }
        table.insert(awayTeam.memberList, aInfo)
    end
    
    --将玩家设置为匹配成功状态
    for _, aInfo in ipairs(homeTeam.memberList) do
        local actor = powers[aInfo.idx].actor
        setTXStatusFight(actor, homeTeam, awayTeam)
    end
    for _, aInfo in ipairs(awayTeam.memberList) do
        local actor = powers[aInfo.idx].actor
        setTXStatusFight(actor, awayTeam, homeTeam)
    end
    
    --注册定时器等待进入副本
    LActor.postScriptEventLite(nil, MATCH_SUCCESS_WAIT * 1000, enterTXFuben, teamList)
end

function enterTXFuben(_, teamList)
    local fbHandle = instancesystem.createFuBen(TianXuanCommonConfig.fightFbId)
    if not fbHandle or fbHandle == 0 then return end
    
    local ins = instancesystem.getInsByHdl(fbHandle)
    if not ins then return end
    ins.data.actorList = {}
    ins.data.teamList = teamList
    
    --先创建数据结构
    local actorList = ins.data.actorList
    for _, team in ipairs(teamList) do
        local teamId = team.teamId
        for i, info in ipairs(team.memberList) do
            local actorid = info.actorid
            actorList[actorid] = {
                teamId = teamId,
                actorid = actorid,
                killCount = 0,
                gatherCount = 0,
                dieCount = 0,
                addScore = 0,
                baseScore = 0,
                MVPScore = 0,
                exScore = 0,
                addPoint = 0,
                serialDie = 0,
            }
            
            local actor = LActor.getActorById(actorid)
            if not (actor and LActor.getFubenId(actor) == TianXuanCommonConfig.matchFbId) then
                info.isLeave = 1
            end
        end
    end
    
    --再拉玩家进入副本
    for _, team in ipairs(teamList) do
        local teamId = team.teamId
        local teamConfig = TianXuanTeamConfig[teamId]
        for i, info in ipairs(team.memberList) do
            if info.isLeave == 0 then
                local actor = LActor.getActorById(info.actorid)
                local pos = teamConfig.pos[i]
                actorcommon.setTeamId(actor, teamId)
                LActor.enterFuBen(actor, fbHandle, 0, pos.x, pos.y)
                LActor.setCamp(actor, teamId)
            end
        end
    end
end

--领取每日奖励
function txGetDailyReward(actor, index)
    local conf = TianXuanDailyRewardConfig[index]
    if not conf then return end
    local var = getActorVar(actor)
    if not var then return end
    if var.matchCount < conf.count then return end
    local status = var.rewardsRecord[index] or 0
    if status ~= 0 then return end
    
    status = 1
    var.rewardsRecord[index] = status
    actoritem.addItems(actor, conf.rewards, "tianxuan Dailyreward")
    s2cTXGetDailyReward(actor, index, status)
end

--匹配对手
function txMatchRival(actor)
    if not checkTXOpen() then return end
    if not checkTXStatusAwait(actor) then return end
    if not LActor.getFubenId(actor) == TianXuanCommonConfig.matchFbId then return end
    local var = getActorVar(actor)
    if not var then return end
    if var.matchCount >= TianXuanCommonConfig.maxMatchCount then return end
    
    setTXStatusMatch(actor)
    checkTXMatchPool()
end

--取消匹配
function txCancelMatch(actor)
    if not checkTXStatusMatch(actor) then return end
    if not LActor.getFubenId(actor) == TianXuanCommonConfig.matchFbId then return end
    
    setTXStatusAwait(actor)
end

--发送表情
function txEmoji(actor, index)
    if not LActor.getFubenId(actor) == TianXuanCommonConfig.fightFbId then return end
    local ins = instancesystem.getActorIns(actor)
    if not ins then return end
    
    local actorid = LActor.getActorId(actor)
    local masterHandle = LActor.getHandle(actor)
    local teamId = ins.data.actorList[actorid].teamId
    local team = ins.data.teamList[teamId]
    for _, info in ipairs(team.memberList) do
        local nactor = LActor.getActorById(info.actorid)
        if nactor and LActor.getFubenId(nactor) == TianXuanCommonConfig.fightFbId then
            s2cTXEmoji(nactor, masterHandle, index)
        end
    end
end

----------------------------------------------------------------------------------
--活动时间事件
--检测活动时间
local function checkTXTime()
    local now = System.getNowTime()
    local data = getSystemVar()
    if data.status < txStatusType.start and now >= data.startTime and now < data.endTime then
        tianxuanStart()
    end
    if data.status < txStatusType.stop and now >= data.endTime then
        tianxuanStop()
    end
    if data.status < txStatusType.close and now >= data.closeTime then
        tianxuanClose()
    end
    if now >= data.nextTime then
        resetTianXuan()
    end
end

--重置活动数据
function resetTianXuan()
    local var = System.getStaticVar()
    var.tianxuan = nil
    tianxuanrank.clearTianXuanRankVar()
    checkTXTime()
end

--活动开启
function tianxuanStart()
    if not System.isLianFuSrv() then return end
    local data = getSystemVar()
    data.status = txStatusType.start
    
    sendSCTianxuanInfo()
    broadTianxuanInfo()
end

--活动结束
function tianxuanStop()
    if not System.isLianFuSrv() then return end
    local data = getSystemVar()
    data.status = txStatusType.stop
    
    sendSCTianxuanInfo()
    broadTianxuanInfo()
end

--活动发奖
function tianxuanSettle()
    if not System.isLianFuSrv() then return end
    local data = getSystemVar()
    data.status = txStatusType.settlement
    tianxuanrank.sendTXRankReward()
    broadTianxuanInfo()
end

--活动关闭
function tianxuanClose()
    if not System.isLianFuSrv() then return end
    tianxuanSettle()--先结算活动

    local data = getSystemVar()
    data.status = txStatusType.close

    sendSCTianxuanInfo()
    broadTianxuanInfo()
end

----------------------------------------------------------------------------------
--协议处理
function broadTianxuanInfo()
    local actors = System.getOnlineActorList()
    if actors then
        for i = 1, #actors do
            local actor = actors[i]
            if actor then
                s2cTianxuanInfo(actor)
            end
        end
    end
end

--92-30 下发个人信息
function s2cTianxuanInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sTianxuanCmd_Info)
    if pack == nil then return end
    
    local data = getSystemVar()
    LDataPack.writeChar(pack, data.status)
    LDataPack.writeInt(pack, data.startTime)
    LDataPack.writeInt(pack, data.endTime)
    LDataPack.writeInt(pack, data.closeTime)
    LDataPack.writeChar(pack, var.matchCount)
    LDataPack.writeChar(pack, #TianXuanDailyRewardConfig)
    for idx in ipairs(TianXuanDailyRewardConfig) do
        LDataPack.writeChar(pack, idx)
        LDataPack.writeChar(pack, var.rewardsRecord[idx] or 0)
    end
    LDataPack.flush(pack)
end

--92-31 请求领取每日奖励
local function c2sTXGetDailyReward(actor, pack)
    local index = LDataPack.readChar(pack)
    txGetDailyReward(actor, index)
end

--92-31 返回领取每日奖励
function s2cTXGetDailyReward(actor, index, status)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sTianxuanCmd_GetDailyReward)
    if pack == nil then return end
    LDataPack.writeChar(pack, index)
    LDataPack.writeChar(pack, status)
    LDataPack.flush(pack)
end

--92-32 请求匹配/取消匹配
local function c2sTXMatch(actor, pack)
    local mtype = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.tianxuan) then return end
    if mtype == 1 then
        txMatchRival(actor)
    elseif mtype == 2 then
        txCancelMatch(actor)
    end
end

--92-32 更新匹配信息
function s2cTXMatch(actor, isSuccess, myTeam, rivalTeam)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sTianxuanCmd_ResMatch)
    if pack == nil then return end
    
    local actorid = LActor.getActorId(actor)
    LDataPack.writeChar(pack, var.matchStatus)
    if isSuccess == true then
        LDataPack.writeChar(pack, MATCH_SUCCESS_WAIT)
        
        LDataPack.writeChar(pack, myTeam.teamId)
        LDataPack.writeChar(pack, TEAM_MAX_MEMBER)
        for i = 1, TEAM_MAX_MEMBER do
            local aInfo = myTeam.memberList[i]
            LDataPack.writeInt(pack, aInfo.actorid)
            LDataPack.writeString(pack, aInfo.name)
            LDataPack.writeChar(pack, aInfo.job)
            LDataPack.writeInt(pack, aInfo.score)
        end
        
        LDataPack.writeChar(pack, rivalTeam.teamId)
        LDataPack.writeChar(pack, TEAM_MAX_MEMBER)
        for i = 1, TEAM_MAX_MEMBER do
            local aInfo = rivalTeam.memberList[i]
            LDataPack.writeInt(pack, aInfo.actorid)
            LDataPack.writeString(pack, aInfo.name)
            LDataPack.writeChar(pack, aInfo.job)
            LDataPack.writeInt(pack, aInfo.score)
        end
    else
        LDataPack.writeChar(pack, 0)
        LDataPack.writeChar(pack, 0)
        
        LDataPack.writeChar(pack, TEAM_MAX_MEMBER)
        for i = 1, TEAM_MAX_MEMBER do
            if i == 1 then --前端要求没有匹配成功,第一个位置也下发自己的数据
                LDataPack.writeInt(pack, LActor.getActorId(actor))
                LDataPack.writeString(pack, LActor.getName(actor))
                LDataPack.writeChar(pack, LActor.getJob(actor))
                LDataPack.writeInt(pack, getTXScoreByActorId(actorid))
            else
                LDataPack.writeInt(pack, 0)
                LDataPack.writeString(pack, "")
                LDataPack.writeChar(pack, 0)
                LDataPack.writeInt(pack, 0)
            end
        end
        
        LDataPack.writeChar(pack, 0)
        LDataPack.writeChar(pack, TEAM_MAX_MEMBER)
        for i = 1, TEAM_MAX_MEMBER do
            LDataPack.writeInt(pack, 0)
            LDataPack.writeString(pack, "")
            LDataPack.writeChar(pack, 0)
            LDataPack.writeInt(pack, 0)
            LDataPack.writeDouble(pack, 0)
        end
    end
    LDataPack.flush(pack)
end

--92-34 请求发送表情
local function c2sTXEmoji(actor, pack)
    local index = LDataPack.readChar(pack)
    txEmoji(actor, index)
end

--92-34 返回发送表情
function s2cTXEmoji(actor, masterHandle, index)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sTianxuanCmd_ResEmoji)
    if pack == nil then return end
    
    LDataPack.writeDouble(pack, masterHandle)
    LDataPack.writeChar(pack, index)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--跨服协议

--战区同步数据到普通服
function sendSCTianxuanInfo(serverid)
    if not System.isLianFuSrv() then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCTianXuanCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianXuanCmd_SyncInfo)
    
    local data = getSystemVar()
    LDataPack.writeChar(pack, data.status)
    LDataPack.writeInt(pack, data.startTime)
    LDataPack.writeInt(pack, data.endTime)
    LDataPack.writeInt(pack, data.closeTime)
    
    System.sendPacketToAllGameClient(pack, serverid or 0)
end

--普通服收到战区同步数据
local function onSCTianxuanInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    
    local data = getSystemVar()
    data.status = LDataPack.readChar(dp)
    data.startTime = LDataPack.readInt(dp)
    data.endTime = LDataPack.readInt(dp)
    data.closeTime = LDataPack.readInt(dp)
    broadTianxuanInfo()
end
----------------------------------------------------------------------------------
--事件处理

local function onEnterFb(ins, actor)
    if not actor then return end
    if not checkTXStatusAwait(actor) then
        setTXStatusAwait(actor)
    end
    LActor.setCamp(actor, CampType_Normal)
    actorcommon.setTeamId(actor, 0)
    s2cTianxuanInfo(actor)
end

local function onExitFb(ins, actor)
    if not actor then return end
    if not checkTXStatusAwait(actor) then
        setTXStatusAwait(actor)
    end
end

local function onLogin(actor)
    s2cTianxuanInfo(actor)
end

local function onActorLogout(actor)
    if not checkTXStatusAwait(actor) then
        setTXStatusAwait(actor)
    end
end

local function onNewDay(actor, login)
    reSetTXActor(actor)
    if not login then
        s2cTianxuanInfo(actor)
    end
end

--连接跨服事件
local function onTXConnected(serverId, serverType)
    sendSCTianxuanInfo(serverId)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    if System.isBattleSrv() then return end
    --if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cTianxuanCmd_GetDailyReward, c2sTXGetDailyReward)
    
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    csbase.RegConnected(onTXConnected)
    csmsgdispatcher.Reg(CrossSrvCmd.SCTianXuanCmd, CrossSrvSubCmd.SCTianXuanCmd_SyncInfo, onSCTianxuanInfo)
    
    if System.isCommSrv() then return end
    
    insevent.registerInstanceEnter(TianXuanCommonConfig.matchFbId, onEnterFb)
    insevent.registerInstanceEnter(TianXuanCommonConfig.matchFbId, onExitFb)
    
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cTianxuanCmd_ReqMatch, c2sTXMatch)
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cTianxuanCmd_ReqEmoji, c2sTXEmoji)
    
    actorevent.reg(aeUserLogout, onActorLogout)
    
    engineevent.regGameStartEvent(checkTXTime)
end
table.insert(InitFnTable, init)

_G.ResetTianxuan = resetTianXuan
_G.TianxuanStart = tianxuanStart
_G.TianxuanStop = tianxuanStop
_G.TianxuanClose = tianxuanClose
----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.txmatch = function (actor, args)
    if not System.isLianFuSrv() then return end
    txMatchRival(actor)
    return true
end

gmCmdHandlers.txcancel = function (actor, args)
    if not System.isLianFuSrv() then return end
    txCancelMatch(actor)
    return true
end

gmCmdHandlers.txstart = function (actor, args)
    if System.isBattleSrv() then return end
    if System.isCommSrv() then
        SCTransferGM("txstart", args, true)
        return
    end
    local data = getSystemVar()
    if data.status ~= txStatusType.start then
        tianxuanStart()
    end
    return true
end

gmCmdHandlers.txstop = function (actor, args)
    if System.isBattleSrv() then return end
    if System.isCommSrv() then
        SCTransferGM("txstop", args, true)
        return
    end
    local data = getSystemVar()
    if data.status ~= txStatusType.stop then
        tianxuanStop()
    end
    return true
end

gmCmdHandlers.txclose = function (actor, args)
    if System.isBattleSrv() then return end
    if System.isCommSrv() then
        SCTransferGM("txclose", args, true)
        return
    end
    local data = getSystemVar()
    if data.status < txStatusType.close then
        tianxuanClose()
    end
    return true
end

gmCmdHandlers.txreset = function (actor, args)
    if System.isBattleSrv() then return end
    if System.isCommSrv() then
        SCTransferGM("txreset", args, true)
    end
    resetTianXuan()
    broadTianxuanInfo()
    return true
end

gmCmdHandlers.txprint = function (actor, args)
    local actorid = LActor.getActorId(actor)
    local var = getActorVar(actor)
    if var then
        print("********actor********")
        print("score =", getTXScoreByActorId(actorid))
        print("matchCount =", var.matchCount)
        print("matchStatus =", var.matchStatus)
    end
    
    local data = getSystemVar()
    print("********data********")
    utils.printTable(data)
    print("********MATCH_POOL********")
    utils.printTable(MATCH_POOL)
    if System.isCommSrv() then
        SCTransferGM("txprint", args, true)
    end
    return true
end

gmCmdHandlers.txclear = function (actor, args)
    if System.isBattleSrv() then return end
    if System.isCommSrv() then
        SCTransferGM("txclear", args, true)
        return
    end
    MATCH_POOL = {}
    local actors = System.getOnlineActorList()
    if actors then
        for i = 1, #actors do
            local actor = actors[i]
            if actor then
                reSetTXActor(actor)
            end
        end
    end
    return true
end

gmCmdHandlers.txallmatch = function (actor, args)
    if not System.isLianFuSrv() then return end
    local actors = System.getOnlineActorList()
    if actors then
        for _, actor in ipairs(actors) do
            txMatchRival(actor)
        end
    end
    return true
end

