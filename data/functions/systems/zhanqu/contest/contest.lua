--卓越擂台赛(积分赛匹配)
module("contest", package.seeall)

MATCH_POOL = MATCH_POOL or {} --等待匹配池

ctResult = {
    ctDefault = 0,
    ctWin = 1,
    ctLose = 2,
}

STAGE_TYPE = {
    Default = 0, --初始化
    Enrolling = 1, --报名中
    Enrolldone = 2, --报名截止
    ScoreStart = 3, --积分赛
    ScoreEnd = 4, --积分赛结束
    Contest = 5, --擂台赛
    Finish = 6, --活动结束
}

STATUS_TYPE = {
    Await = 0, --未匹配
    Match = 1, --匹配中
    Fight = 2, --战斗中
}

BET_TYPE = {
    Contest = 1, --擂主
    Challenger = 2, --挑战者
}

local function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.contest then
        var.contest = {
            status = 0, --报名状态
            matchCount = 0, --积分匹配场数
            roundInfo = {}, --每轮擂台赛的信息({0,1,2 ...} 胜负状态 0-默认,1-胜利,2-失败)
            betCounts = {}, --每轮擂台赛的投注信息({[轮数] = 已投注次数})
            resetTime = 0, --活动数据重置时间
        }
    end
    return var.contest
end

local function getSystemVar()
    local var = System.getStaticVar()
    if not var then return end
    if not var.contest then
        var.contest = {
            idx = 1, --记录活动进行的序号
            nextTime = 0, --下次活动开启时间
            stage = 0, --当前阶段
            round = 0, --当前回合
            enrollCount = 0, --当前报名人数
            memberList = {}, --记录报名玩家数据({[玩家id] = initCTActor()})
            roundList = {}, --擂台赛总数据({[第几轮] = {{战斗准备时间戳,战斗持续时间戳}}})
            contestList = {}, --当前擂台赛数据({[第几场] = {{擂主数据}}})
            challengeList = {}, --当前擂台赛数据({[{{挑战者数据}}})
        }
        
        local data = var.contest
        local roundList = data.roundList
        local weekTime = System.getWeekFistTime()
        for idx, conf in ipairs(ContestStageConfig) do
            if conf.stage == STAGE_TYPE.Default then
                local d, h, m = string.match(conf.startTime, "(%d+)-(%d+):(%d+)")
                data.nextTime = weekTime + d * 24 * 3600 + h * 3600 + m * 60 + 604800
            elseif conf.stage == STAGE_TYPE.Contest then
                local round = conf.round
                if round > 0 then
                    local d, h, m = string.match(conf.startTime, "(%d+)-(%d+):(%d+)")
                    if not roundList[round] then
                        roundList[round] = {}
                    end
                    if conf.isBet == 1 then
                        roundList[round].readyTime = weekTime + d * 24 * 3600 + h * 3600 + m * 60
                    else
                        roundList[round].fightTime = weekTime + d * 24 * 3600 + h * 3600 + m * 60
                    end
                end
            end
        end
    end
    return var.contest
end

local function reSetCTActor(actor)
    local var = LActor.getStaticVar(actor)
    var.contest = nil
end

local function getCTMemberList()
    local data = getSystemVar()
    return data.memberList
end

local function getActorInfo(actorid)
    local memberList = getCTMemberList()
    return memberList[actorid]
end

local function initCTActor(actorid, serverid, job, name, power)
    local memberList = getCTMemberList()
    if memberList[actorid] then return end
    memberList[actorid] = {
        actorid = actorid, --玩家id
        serverid = serverid, --玩家所属服务器id
        isContest = 0, --是否晋级擂主
        matchStatus = 0, --匹配状态
        rivalid = 0, --匹配对手id
        waitTime = 0, --匹配成功后等待进入战斗时间戳
        job = job,
        name = name, --玩家名字
        power = power, --玩家战斗力
        score = 0, --积分赛获得的积分
    }
    return memberList[actorid]
end

local function initContestGame(actorid)
    local data = getSystemVar()
    local contestList = data.contestList
    local info = getActorInfo(actorid)
    local contest = {
        actorid = actorid,
        name = info.name,
        result = 0,
        betInfo = {
            [BET_TYPE.Contest] = {},
            [BET_TYPE.Challenger] = {},
        },
    }
    table.insert(contestList, contest)
    return true
end

local function checkCTStage(stage)
    local data = getSystemVar()
    return data.stage == stage
end

local function checkCTMatchStatus(actor, statusType)
    local actorid = LActor.getActorId(actor)
    local info = getActorInfo(actorid)
    if not info then return false end
    if info.matchStatus ~= statusType then return false end
    return true
end

local function canCTMatch(actorid)
    local info = getActorInfo(actorid)
    if info.matchStatus ~= STATUS_TYPE.Match then return false end
    return true
end

local function checkCTStatusAwait(actor)
    return checkCTMatchStatus(actor, STATUS_TYPE.Await)
end

local function checkCTStatusMatch(actor)
    return checkCTMatchStatus(actor, STATUS_TYPE.Match)
end

local function checkCTStatusFight(actor)
    return checkCTMatchStatus(actor, STATUS_TYPE.Fight)
end

local function getCTRivalByMatchPool()
    for _, actorid in ipairs(MATCH_POOL) do
        if canCTMatch(actorid) then
            return actorid
        end
    end
end

function getActorPower(actorid)
    local info = getActorInfo(actorid)
    if not info then return 0 end
    return info.power or 0
end

function setCTStatusAwait(actorid)
    local info = getActorInfo(actorid)
    if not info then return end
    info.matchStatus = STATUS_TYPE.Await
    info.rivalid = 0
    removeCTMatchPoolByActorId(actorid)
    s2cCTMatch(actorid)
end

function setCTStatusMatch(actorid)
    local info = getActorInfo(actorid)
    info.matchStatus = STATUS_TYPE.Match
    table.insert(MATCH_POOL, actorid)
    s2cCTMatch(actorid)
end

function setCTStatusFight(actorid, rivalid)
    local aInfo = getActorInfo(actorid)
    local rInfo = getActorInfo(rivalid)
    local waitTime = System.getNowTime() + ContestCommonConfig.delayTime
    aInfo.matchStatus = STATUS_TYPE.Fight
    rInfo.matchStatus = STATUS_TYPE.Fight
    aInfo.rivalid = rivalid
    rInfo.rivalid = actorid
    aInfo.waitTime = waitTime
    rInfo.waitTime = waitTime
    
    local rival = LActor.getActorById(rivalid)
    local var = getActorVar(rival)
    var.matchCount = var.matchCount + 1
    if var.eid then
        LActor.cancelScriptEvent(rival, var.eid)
        var.eid = nil
    end
    
    removeCTMatchPoolByActorId(rivalid)
    createCTScoreFuben(actorid, rivalid)
    
    s2cCTMatch(actorid)
    s2cCTMatch(rivalid)
end

function cancelCTMatch(actor)
    local actorid = LActor.getActorId(actor)
    local var = getActorVar(actor)
    
    setCTStatusAwait(actorid)
end

function removeCTMatchPoolByActorId(actorid)
    for idx, aid in ipairs(MATCH_POOL) do
        if aid == actorid then
            table.remove(MATCH_POOL, idx)
            break
        end
    end
end

function createCTScoreFuben(actorid, rivalid)
    local fbHandle = instancesystem.createFuBen(ContestCommonConfig.scoreFbId)
    if not fbHandle or fbHandle == 0 then return end
    local ins = instancesystem.getInsByHdl(fbHandle)
    local aInfo = getActorInfo(actorid)
    local rInfo = getActorInfo(rivalid)
    ins.data.actorList = {
        [actorid] = {idx = 1, serverid = aInfo.serverid},
        [rivalid] = {idx = 2, serverid = rInfo.serverid},
    }
    ins.data.leaveList = {}
    LActor.postScriptEventLite(nil, ContestCommonConfig.delayTime * 1000, enterCTScoreFuben, fbHandle)
end

function enterCTScoreFuben(_, fbHandle)
    local ins = instancesystem.getInsByHdl(fbHandle)
    if not ins then return end
    
    local leaveList = ins.data.leaveList
    local actorList = ins.data.actorList
    for actorid, info in pairs(actorList) do
        local actor = LActor.getActorById(actorid)
        if actor and LActor.getFubenId(actor) == ContestCommonConfig.matchFbId then
            local pos = ContestCommonConfig.myPos
            if info.idx == 2 then
                pos = ContestCommonConfig.tarPos
            end
            LActor.enterFuBen(actor, fbHandle, 0, pos[1].x, pos[1].y)
        else
            table.insert(leaveList, actorid)
        end
    end
    if #leaveList >= 2 then
        for _, actorid in ipairs(leaveList) do
            scorefuben.setActorLose(ins, actorid)
        end
        ins:win()
    end
end

function addCTScore(actorid, result)
    local info = getActorInfo(actorid)
    local config = ScoreFubenConfig[result]
    local oldScore = info.score
    local addScore = math.ceil(math.max(info.power / config.scoreParam.power, config.scoreParam.minScore) * config.resultParam)
    local rewards = config.rewards
    if checkCTStage(STAGE_TYPE.ScoreStart) then
        info.score = oldScore + addScore
        contestrank.addSCRankScore(actorid, info.serverid, info.name, addScore)
    end
    return oldScore, addScore, rewards
end

function ctEnroll(actorid, serverid, job, name, power)
    if not checkCTStage(STAGE_TYPE.Enrolling) then return end
    initCTActor(actorid, serverid, job, name, power)
    local data = getSystemVar()
    data.enrollCount = data.enrollCount + 1
end

function ctMatchRival(actor)
    if not checkCTStage(STAGE_TYPE.ScoreStart) then return end
    if not checkCTStatusAwait(actor) then return end
    if not LActor.getFubenId(actor) == ContestCommonConfig.matchFbId then return end
    local var = getActorVar(actor)
    if not var then return end
    if var.status ~= 1 then return end
    if var.matchCount >= ContestCommonConfig.maxMatchCount then return end
    
    local actorid = LActor.getActorId(actor)
    local rivalid = getCTRivalByMatchPool()
    if not rivalid then
        setCTStatusMatch(actorid)
        var.eid = LActor.postScriptEventLite(actor, ContestCommonConfig.mathTime * 1000, cancelCTMatch)
    else
        var.matchCount = var.matchCount + 1
        setCTStatusFight(actorid, rivalid)
    end
end

function ctBetGame(actor, round, idx, betType)
    local config = ContestFubenConfig[round]
    if not config then return end
    
    local var = getActorVar(actor)
    local count = var.betCounts[round] or 0
    if count >= config.maxBetGame then return end
    
    if not actoritem.checkItem(actor, NumericType_YuanBao, config.betCount) then
        return false
    end
    
    local data = getSystemVar()
    local roundList = data.roundList
    if roundList[round].canBet ~= 1 then return end
    
    local betInfo = data.contestList[idx].betInfo[betType]
    if not betInfo then return end
    
    local actorid = LActor.getActorId(actor)
    if betInfo[actorid] then return end
    
    actoritem.reduceItem(actor, NumericType_YuanBao, config.betCount, "contest betGame")
    
    count = count + 1
    var.betCounts[round] = count
    betInfo[actorid] = LActor.getServerId(actor)
    
    local people = betInfo.count or 0
    people = people + 1
    betInfo.count = people
    s2cCTBetGame(actor, round, idx, betType, 1, count, people)
end

----------------------------------------------------------------------------------
--擂台赛相关
--检查活动时间

function checkContestTime()
    local data = getSystemVar()
    local now = System.getNowTime()
    local weekTime = System.getWeekFistTime()
    
    if (data.nextTime or 0) <= now then
        resetContest()
        data = getSystemVar()
    end
    
    for idx, conf in ipairs(ContestStageConfig) do
        if data.idx < idx then
            local d, h, m = string.match(conf.startTime, "(%d+)-(%d+):(%d+)")
            local startTime = weekTime + d * 24 * 3600 + h * 3600 + m * 60
            if startTime <= now then
                updateContestFunc(conf.funcType)
            end
        end
    end
end

--重置活动数据
function resetContest()
    local var = System.getStaticVar()
    var.contest = nil
    contestrank.clearContestRankVar()
end

function updateContestFunc(funcType)
    if funcType == 1 then
        updateContestStage()
    elseif funcType == 2 then
        updateContestRound()
    elseif funcType == 3 then
        fightContestRound()
    else
        print("contest.updateContestFunc error funcType =", funcType)
    end
end

--阶段变更
function updateContestStage()
    if not System.isLianFuSrv() then return end
    if checkCTStage(STAGE_TYPE.Finish) then return end
    
    local data = getSystemVar()
    data.idx = data.idx + 1
    
    local stage = data.stage + 1
    data.stage = stage
    
    if stage == STAGE_TYPE.Enrolldone then
        if data.enrollCount < ContestCommonConfig.needEnrollCount then
            local mailData = {
                head = ContestCommonConfig.mailTitle,
                context = ContestCommonConfig.mailContent,
                tAwardList = {},
            }
            for _, info in pairs(data.memberList) do
                mailsystem.sendMailById(info.actorid, mailData, info.serverid)
            end
            for idx, conf in ipairs(ContestStageConfig) do
                if data.idx < idx then
                    updateContestFunc(conf.funcType)
                end
            end
        end
    elseif stage == STAGE_TYPE.Finish then
        sendCTBetEmail(data.round)--由于竞猜邮件在下一轮开始前发放,所以最后一轮只能放在活动结束的时候发放
        contestrank.sendSCRankReward()
        contestrank.sendCTRankReward()
    end
    
    --切换阶段时，由于前端无法处理round=0的情况，所以这种情况不通知前端
    if stage ~= STAGE_TYPE.Contest then
        sendSCContestInfo()
        broadContestInfo()
    end
end

--擂台赛轮数切换
function updateContestRound()
    if not System.isLianFuSrv() then return end
    if checkCTStage(STAGE_TYPE.Finish) then return end
    local data = getSystemVar()
    data.idx = data.idx + 1
    
    local round = data.round + 1
    data.round = round
    
    local contestList = data.contestList
    local challengeList = data.challengeList
    local roundList = data.roundList
    roundList[round].canBet = 1
    
    if round == 1 then
        local param = ContestCommonConfig.contestRankParam
        local count = math.min(math.max(param.a, math.floor(data.enrollCount * param.b)), param.c)
        local contests = contestrank.getContests(count)
        for i, aid in ipairs(contests) do
            local info = getActorInfo(aid)
            info.isContest = 1
            initContestGame(aid)
        end
    else
        sendCTBetEmail(data.round - 1) --先发送上一轮竞猜奖励
        local contests = {}
        for idx, info in ipairs(contestList) do
            if info.result == 1 then
                table.insert(contests, info.actorid)
            end
        end
        data.contestList = {}
        for _, aid in ipairs(contests) do
            initContestGame(aid)
        end
    end
    local challengers = contestrank.getChallengers(round)
    for i, aid in ipairs(challengers) do
        local info = getActorInfo(aid)
        challengeList[i] = {
            actorid = aid,
            power = info.power,
        }
    end
    
    --没有擂主了就直接跳过剩下的阶段
    if #data.contestList == 0 then
        for idx, conf in ipairs(ContestStageConfig) do
            if data.idx < idx then
                updateContestFunc(conf.funcType)
            end
        end
    end
    sendSCContestInfo()
    broadContestInfo()
    broadContestFight()
end

--擂台赛进入战斗
function fightContestRound()
    if not System.isLianFuSrv() then return end
    if checkCTStage(STAGE_TYPE.Finish) then return end
    
    local data = getSystemVar()
    data.idx = data.idx + 1
    
    local roundList = data.roundList
    roundList[data.round].canBet = 0
    
    local now = System.getNowTime()
    for idx, info in ipairs(data.contestList) do
        local actor = LActor.getActorById(info.actorid)
        if actor and LActor.getFubenId(actor) == ContestCommonConfig.matchFbId then
            local fbHandle = instancesystem.createFuBen(ContestCommonConfig.contestFbId)
            if not fbHandle or fbHandle == 0 then break end
            local ins = instancesystem.getInsByHdl(fbHandle)
            ins.data.round = data.round
            ins.data.idx = idx
            ins.data.actorid = info.actorid
            ins.data.challengeList = data.challengeList
            ins.data.cloneInfo = {}
            ins.data.challengeCount = #data.challengeList
            ins.data.killCount = 0
            local x, y = utils.getSceneEnterCoor(ContestCommonConfig.contestFbId)
            LActor.enterFuBen(actor, fbHandle, 0, x, y)
        else
            local data = getSystemVar()
            local cInfo = data.contestList[idx]
            cInfo.result = ctResult.ctLose
            local aInfo = getActorInfo(info.actorid)
            contestrank.addCTRankScore(aInfo.actorid, aInfo.serverid, aInfo.name, aInfo.power, 0, 0)
        end
    end
    broadContestInfo()
end

--擂台赛战斗结果
function fightContestResult(actor, round, idx, killCount, iswin)
    local data = getSystemVar()
    if data.round ~= round then
        print("contest.fightContestResult error round =", round, "data.round =", data.round)
        return
    end
    
    local contestList = data.contestList
    local info = contestList[idx]
    if not info then
        print("contest.fightContestResult not found contestInfo idx =", idx)
        return
    end
    
    local var = getActorVar(actor)
    local roundInfo = var.roundInfo
    roundInfo[round] = iswin and ctResult.ctWin or ctResult.ctLose
    
    contestrank.addCTRankScore(LActor.getActorId(actor), LActor.getServerId(actor), LActor.getName(actor), LActor.getPower(actor), iswin and 1 or 0, killCount)
    
    info.result = iswin and ctResult.ctWin or ctResult.ctLose
    broadContestInfo()
    
    local extra = string.format("result =%d,round =%d,killCount =%d", info.result, round, killCount)
    utils.logCounter(actor, "contest", "", extra, "contest", "contestfuben")
end

--擂台赛发放投注邮件
function sendCTBetEmail(lastRound)
    local data = getSystemVar()
    if #data.contestList == 0 then return end
    
    local config = ContestFubenConfig[lastRound]
    if not config then
        print("contest.sendCTBetEmail not config round =", lastRound)
        return
    end
    
    local temBetInfo = {}
    for idx, info in ipairs(data.contestList) do
        for aid, sid in pairs(info.betInfo[BET_TYPE.Contest]) do
            if type(aid) == "number" then
                if not temBetInfo[aid] then
                    temBetInfo[aid] = {
                        winCount = 0,
                        loseCount = 0,
                        serverid = sid,
                    }
                end
                if info.result == ctResult.ctWin then
                    temBetInfo[aid].winCount = temBetInfo[aid].winCount + 1
                elseif info.result == ctResult.ctLose then
                    temBetInfo[aid].loseCount = temBetInfo[aid].loseCount + 1
                end
            end
        end
        
        for aid, sid in pairs(info.betInfo[BET_TYPE.Challenger]) do
            if type(aid) == "number" then
                if not temBetInfo[aid] then
                    temBetInfo[aid] = {
                        winCount = 0,
                        loseCount = 0,
                        serverid = sid,
                    }
                end
                if info.result == ctResult.ctLose then
                    temBetInfo[aid].winCount = temBetInfo[aid].winCount + 1
                elseif info.result == ctResult.ctWin then
                    temBetInfo[aid].loseCount = temBetInfo[aid].loseCount + 1
                end
            end
        end
    end
    
    for aid, bInfo in pairs(temBetInfo) do
        local rewards = {}
        table.insert(rewards, {type = 0, id = NumericType_YuanBao, count = config.betCount * bInfo.winCount * 2 + config.betCount * bInfo.loseCount})
        table.insert(rewards, {type = 0, id = NumericType_ZhanQuBi, count = config.winBetCount * bInfo.winCount + config.loseBetCount * bInfo.loseCount})
        local mailData = {}
        mailData.head = ContestCommonConfig.betMailTitle
        mailData.context = string.format(ContestCommonConfig.betMailContent, lastRound, bInfo.winCount, bInfo.loseCount)
        mailData.tAwardList = rewards
        mailsystem.sendMailById(aid, mailData, bInfo.serverid)
    end
end

----------------------------------------------------------------------------------
--协议处理
function broadContestInfo()
    local actors = System.getOnlineActorList()
    if actors then
        for i = 1, #actors do
            local actor = actors[i]
            if actor then
                s2cContestInfo(actor)
            end
        end
    end
end

function broadContestFight()
    local data = getSystemVar()
    for _, contestInfo in ipairs(data.contestList) do
        local actorid = contestInfo.actorid
        local actor = LActor.getActorById(actorid)
        if actor then
            s2cContestFight(actor)
        else
            local info = getActorInfo(actorid)
            sendSCContestFight(actorid, info.serverid)
        end
    end
end

--92-1 请求下发个人信息
local function c2sCTActorInfo(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.contest) then return end
    s2cContestInfo(actor)
end

--92-1 下发个人信息
function s2cContestInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local isContest = 0
    local actorid = LActor.getActorId(actor)
    local info = getActorInfo(actorid)
    if info then
        isContest = info.isContest
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sContestCmd_ActorInfo)
    if pack == nil then return end
    
    local data = getSystemVar()
    local roundList = data.roundList
    local contestList = data.contestList
    local challengeList = data.challengeList
    
    LDataPack.writeChar(pack, var.status)
    LDataPack.writeChar(pack, data.stage)
    LDataPack.writeChar(pack, var.matchCount)
    LDataPack.writeChar(pack, isContest)
    LDataPack.writeShort(pack, data.enrollCount)
    LDataPack.writeChar(pack, #ContestFubenConfig)
    for i, conf in ipairs(ContestFubenConfig) do
        LDataPack.writeChar(pack, var.roundInfo[i] or 0)
        LDataPack.writeChar(pack, var.betCounts[i] or 0)
        LDataPack.writeInt(pack, roundList[i].readyTime)
        LDataPack.writeInt(pack, roundList[i].fightTime)
    end
    LDataPack.writeChar(pack, data.round)
    LDataPack.writeChar(pack, #contestList)
    for idx, ctInfo in ipairs(contestList) do
        local contesterInfo = getActorInfo(ctInfo.actorid)
        LDataPack.writeChar(pack, idx)
        LDataPack.writeChar(pack, ctInfo.result)
        LDataPack.writeInt(pack, ctInfo.actorid)
        LDataPack.writeChar(pack, contesterInfo.job)
        LDataPack.writeString(pack, contesterInfo.name)
        for _, bInfo in ipairs(ctInfo.betInfo) do
            LDataPack.writeChar(pack, bInfo[actorid] and 1 or 0)
            LDataPack.writeShort(pack, bInfo.count or 0)
        end
    end
    LDataPack.writeChar(pack, #challengeList)
    for idx, clInfo in ipairs(challengeList) do
        local challengerInfo = getActorInfo(clInfo.actorid)
        LDataPack.writeDouble(pack, challengerInfo.power)
    end
    LDataPack.flush(pack)
end

--92-2 请求报名
local function c2sCTEnroll(actor, pack)
    if not csbase.checkLianFuConnected() then return end
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.contest) then return end
    if not checkCTStage(STAGE_TYPE.Enrolling) then return end
    if System.isCommSrv() then
        sendSCContestEnroll(actor)
    elseif System.isLianFuSrv() then
        local var = getActorVar(actor)
        if var.status == 1 then return end
        var.status = 1
        initCTActor(LActor.getActorId(actor), LActor.getServerId(actor), LActor.getJob(actor), LActor.getName(actor), LActor.getPower(actor))
        s2cCTEnroll(actor)
    end
end

--92-2 返回报名状态
function s2cCTEnroll(actor)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sContestCmd_ResEnroll)
    if pack == nil then return end
    LDataPack.writeChar(pack, var.status)
    LDataPack.flush(pack)
end

--92-3 请求积分赛匹配
local function c2sCTMatch(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.contest) then return end
    ctMatchRival(actor)
end

--92-3 更新积分赛匹配状态
function s2cCTMatch(actorid)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    
    local info = getActorInfo(actorid)
    if not info then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sContestCmd_UpdateMatchStatus)
    if pack == nil then return end
    
    local matchStatus = 0
    local rivalid = 0
    local name = ""
    local job = 0
    local waitTime = 0
    matchStatus = info.matchStatus
    if matchStatus == STATUS_TYPE.Fight then
        rivalid = info.rivalid
        local rInfo = getActorInfo(rivalid)
        name = rInfo.name
        job = rInfo.job
        waitTime = info.waitTime
    end
    LDataPack.writeChar(pack, matchStatus)
    LDataPack.writeInt(pack, rivalid)
    LDataPack.writeString(pack, name)
    LDataPack.writeByte(pack, job)
    LDataPack.writeInt(pack, waitTime)
    LDataPack.flush(pack)
end

--92-5 请求投注
local function c2sCTBetGame(actor, pack)
    local round = LDataPack.readChar(pack)
    local idx = LDataPack.readChar(pack)
    local betType = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.contest) then return end
    ctBetGame(actor, round, idx, betType)
end

--92-5 返回投注
function s2cCTBetGame(actor, round, idx, betType, ret, betCount, people)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sContestCmd_ResBetGame)
    if pack == nil then return end
    LDataPack.writeChar(pack, round)
    LDataPack.writeChar(pack, idx)
    LDataPack.writeChar(pack, betType)
    LDataPack.writeChar(pack, ret)
    LDataPack.writeChar(pack, betCount)
    LDataPack.writeShort(pack, people)
    LDataPack.flush(pack)
end

--92-9 通知擂主进入战区
function s2cContestFight(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sContestCmd_ContestFight)
    if pack == nil then return end
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--跨服协议

--普通服请求战区擂台赛报名
function sendSCContestEnroll(actor)
    if System.isCrossWarSrv() then return end
    local var = getActorVar(actor)
    if not var then return end
    if var.status == 1 then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCContestCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCContestCmd_Enroll)
    
    LDataPack.writeInt(pack, LActor.getActorId(actor))
    LDataPack.writeByte(pack, LActor.getJob(actor))
    LDataPack.writeString(pack, LActor.getName(actor))
    LDataPack.writeDouble(pack, LActor.getPower(actor))
    
    System.sendPacketToAllGameClient(pack, csbase.getLianfuServerId())
    
    var.status = 1
    s2cCTEnroll(actor)
end

--战区收到普通服擂台赛报名
local function onSCContestEnroll(sId, sType, dp)
    if not System.isLianFuSrv() then return end
    
    local actorid = LDataPack.readInt(dp)
    local job = LDataPack.readByte(dp)
    local name = LDataPack.readString(dp)
    local power = LDataPack.readDouble(dp)
    ctEnroll(actorid, sId, job, name, power)
end

--战区同步数据到普通服
function sendSCContestInfo(serverid)
    if not System.isLianFuSrv() then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCContestCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCContestCmd_SyncContestInfo)
    
    local data = getSystemVar()
    LDataPack.writeByte(pack, data.idx)
    LDataPack.writeByte(pack, data.stage)
    LDataPack.writeByte(pack, data.round)
    LDataPack.writeShort(pack, data.enrollCount)
    --local dataUd = bson.encode(data.memberList)
    --LDataPack.writeUserData(pack, dataUd)
    
    System.sendPacketToAllGameClient(pack, serverid or 0)
end

--普通服收到战区同步数据
local function onSCContestInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    
    local data = getSystemVar()
    data.idx = LDataPack.readByte(dp)
    data.stage = LDataPack.readByte(dp)
    data.round = LDataPack.readByte(dp)
    data.enrollCount = LDataPack.readShort(dp)
    --local dataUd = LDataPack.readUserData(dp)
    --data.memberList = bson.decode(dataUd)
    broadContestInfo()
end

--战区通知普通服的擂主进入战区
function sendSCContestFight(actorid, serverid)
    if not System.isLianFuSrv() then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCContestCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCContestCmd_ContestFight)
    
    LDataPack.writeInt(pack, actorid)
    
    System.sendPacketToAllGameClient(pack, serverid)
end

--普通服收到战区同步数据
local function onSCContestFight(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    
    local actorid = LDataPack.readInt(dp)
    local actor = LActor.getActorById(actorid)
    if actor then
        s2cContestFight(actor)
    end
end

----------------------------------------------------------------------------------
--事件处理

local function onEnterFb(ins, actor)
    if not actor then return end
    if not checkCTStatusAwait(actor) then
        local actorid = LActor.getActorId(actor)
        setCTStatusAwait(actorid)
    end
end

local function onExitFb(ins, actor)
    if not actor then return end
    if not checkCTStatusAwait(actor) then
        local actorid = LActor.getActorId(actor)
        setCTStatusAwait(actorid)
    end
end

local function onLogin(actor)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.contest) then return end
    s2cContestInfo(actor)
    if System.isLianFuSrv() then
        if checkCTStage(STAGE_TYPE.ScoreStart) then
            local actorid = LActor.getActorId(actor)
            local info = getActorInfo(actorid)
            if info then
                info.power = LActor.getPower(actor)
            end
        end
    end
end

local function onActorLogout(actor)
    if not checkCTStatusAwait(actor) then
        local actorid = LActor.getActorId(actor)
        setCTStatusAwait(actorid)
    end
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    reSetCTActor(actor)
    if not login then
        s2cContestInfo(actor)
    end
end

--连接跨服事件
local function onCTConnected(serverId, serverType)
    sendSCContestInfo(serverId)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    if System.isBattleSrv() then return end
    --if System.isLianFuSrv() then return end
    
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cContestCmd_ActorInfo, c2sCTActorInfo)
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cContestCmd_ReqEnroll, c2sCTEnroll)
    
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    csbase.RegConnected(onCTConnected)
    csmsgdispatcher.Reg(CrossSrvCmd.SCContestCmd, CrossSrvSubCmd.SCContestCmd_Enroll, onSCContestEnroll)
    csmsgdispatcher.Reg(CrossSrvCmd.SCContestCmd, CrossSrvSubCmd.SCContestCmd_ContestFight, onSCContestFight)
    csmsgdispatcher.Reg(CrossSrvCmd.SCContestCmd, CrossSrvSubCmd.SCContestCmd_SyncContestInfo, onSCContestInfo)
    
    if System.isCommSrv() then return end
    
    checkContestTime()
    
    insevent.registerInstanceEnter(ContestCommonConfig.matchFbId, onEnterFb)
    insevent.registerInstanceExit(ContestCommonConfig.matchFbId, onExitFb)
    
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cContestCmd_ReqMatch, c2sCTMatch)
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cContestCmd_ReqBetGame, c2sCTBetGame)
    
    actorevent.reg(aeUserLogout, onActorLogout)
end
table.insert(InitFnTable, init)

_G.ResetContest = resetContest
_G.UpdateContestStage = updateContestStage
_G.UpdateContestRound = updateContestRound
_G.FightContestRound = fightContestRound
----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.ctenroll = function (actor, args)
    if not System.isCommSrv() then return end
    sendSCContestEnroll(actor)
    return true
end

gmCmdHandlers.ctmatch = function (actor, args)
    if not System.isLianFuSrv() then return end
    ctMatchRival(actor)
    return true
end

gmCmdHandlers.ctbetgame = function (actor, args)
    if not System.isLianFuSrv() then return end
    local round = tonumber(args[1])
    local idx = tonumber(args[1])
    local isContest = tonumber(args[1]) == 1
    ctBetGame(actor, round, idx, isContest)
    return true
end

gmCmdHandlers.ctUpdate = function (actor, args)
    if System.isBattleSrv() then return end
    local data = getSystemVar()
    for idx, conf in ipairs(ContestStageConfig) do
        if data.idx < idx then
            updateContestFunc(conf.funcType)
            break
        end
    end
    if System.isCommSrv() then
        SCTransferGM("ctUpdate", args, true)
    end
    return true
end

gmCmdHandlers.ctStage = function (actor, args)
    if System.isBattleSrv() then return end
    updateContestStage()
    if System.isCommSrv() then
        SCTransferGM("ctStage", args, true)
    end
    return true
end

gmCmdHandlers.ctRound = function (actor, args)
    if System.isBattleSrv() then return end
    updateContestRound()
    if System.isCommSrv() then
        SCTransferGM("ctRound", args, true)
    end
    return true
end

gmCmdHandlers.ctFight = function (actor, args)
    if System.isBattleSrv() then return end
    fightContestRound()
    if System.isCommSrv() then
        SCTransferGM("ctFight", args, true)
    end
    return true
end

gmCmdHandlers.printCTVar = function (actor, args)
    local var = getSystemVar()
    print("*******contestVar*******")
    utils.printTable(var)
    print("************************")
    if System.isCommSrv() then
        SCTransferGM("printCTVar", args, true)
    end
    return true
end

gmCmdHandlers.resetContest = function (actor, args)
    if System.isBattleSrv() then return end
    resetContest()
    if System.isCommSrv() then
        SCTransferGM("resetContest", args, true)
    end
    return true
end

gmCmdHandlers.clearCTActorVar = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.contest = nil
    return true
end

gmCmdHandlers.setCTEnrollCount = function (actor, args)
    if System.isBattleSrv() then return end
    if System.isCommSrv() then
        SCTransferGM("setCTEnrollCount", args, true)
    else
        local count = tonumber(args[1])
        if not count then return end
        local data = getSystemVar()
        data.enrollCount = count
    end
    return true
end

