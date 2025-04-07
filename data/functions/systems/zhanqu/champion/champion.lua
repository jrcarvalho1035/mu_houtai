-- 战队冠军赛
module("champion", package.seeall)

STAGE_TIME = {} --各阶段开始的时间戳

STAGE_TYPE = {
    Default = 0, -- 初始化
    BossBegin = 1, -- 首领战开始
    BossEnd = 2, -- 首领战结束
    TeamGroup = 3, -- 系统分组
    RoundOneReady = 4, -- 晋级赛第1轮准备
    RoundOneStart = 5, -- 晋级赛第1轮开始
    RoundTwoReady = 6, -- 晋级赛第2轮准备
    RoundTwoStart = 7, -- 晋级赛第2轮开始
    ChampReady = 8, -- 冠军赛准备
    ChampStart = 9, -- 冠军赛开始
    Finish = 10 -- 活动结束
}

ERROR_CODE = {
    noErr = 0,  --成功
    sameName = 1, --和原来的名字一样
    wrongName = 2, --名字不合法
}

TEAM_POSITION = {
    noTeam = 0,  --非战队成员
    captain = 1, --战队队长
    member = 2, --战队成员
}

local function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.champion then
        var.champion = {
            bossFightTime = 0, -- 首领战挑战时间
            bossFightDamage = 0, -- 首领战造成伤害
            bossFightRewardStatus = {}, -- 首领战伤害达标
            championCount = 0, --获得冠军战队的次数
            worshipCount = 0, --膜拜次数
        }
    end
    return var.champion
end

local function getSystemVar()
    local var = System.getStaticVar()
    if not var then return end
    if not var.champion then
        var.champion = {
            idx = 1, -- 记录活动进行的序号
            nextTime = 0, -- 下次活动开启时间
            stage = 0, -- 当前阶段
            bossDamageRank = {}, -- 首领战伤害排行
            actorList = {},-- 参与玩家列表
            teamList = {}, -- 战队列表
            gameList = {}, -- 比赛列表
            winTeamId = 0, --获得冠军队伍
            worshipInfo = {}, --冠军队伍信息
            finalBetList = {}, --冠亚季军竞猜
        }

        local data = var.champion
        local weekTime = System.getWeekFistTime()
        for idx, conf in ipairs(ChampionStageConfig) do
            local d, h, m =  string.match(conf.startTime, "(%d+)-(%d+):(%d+)")
            if conf.stage == STAGE_TYPE.Default then
                data.nextTime = weekTime + d * 24 * 3600 + h * 3600 + m * 60 + 604800
            end
            STAGE_TIME[conf.stage] = weekTime + d * 24 * 3600 + h * 3600 + m * 60
        end

        local gameList = data.gameList
        for idx, conf in ipairs(ChampionGameConfig) do
            gameList[idx] = {
                id = idx,
                stage = conf.stage,
                group = conf.group,
                fightList = {},
                betList = {},
                winTeamId = 0
            }
        end
    end
    return var.champion
end

local function reSetCHActor(actor)
    local var = LActor.getStaticVar(actor)
    var.champion = nil
end

local function checkCHStage(stage)
    local data = getSystemVar()
    return data.stage == stage
end

local function getCHActorList()
    local data = getSystemVar()
    return data.actorList
end

local function getCHGameList()
    local data = getSystemVar()
    return data.gameList
end

local function getCHTeamList()
    local data = getSystemVar()
    return data.teamList
end

local function getActorInfo(actorid, isInit)
    local actorList = getCHActorList()
    if not actorList[actorid] and isInit then
        actorList[actorid] = {
            actorId = actorid,
            name = "",
            job = 0,
            serverId = 0,
            teamId = 0,
            teamPos = 0,
            championCount = 0,
            power = 0,
        }
    end
    return actorList[actorid]
end

local function getGameInfo(id)
    local gameList = getCHGameList()
    return gameList[id]
end

local function getTeamInfo(id)
    local teamList = getCHTeamList()
    return teamList[id]
end

local function initCHTeam(id)
    local team = {
        id = id,
        captainId = 0,
        group = 0,
        name = '',
        icon = 0,
        memberList = {},
        power = 0,
        rank = 0,
    }
    return team
end

function getCHTeamByActorId(actorid)
    local aInfo = getActorInfo(actorid)
    if not aInfo then return end

    return getTeamInfo(aInfo.teamId)
end

function sendCHMailByTeam(id, mailData)
    local team = getTeamInfo(id)
    if not team then return end
    for _, actorid in ipairs(team.memberList) do
        print("sendCHMailByTeam actorid= ", actorid)
        local info = getActorInfo(actorid)
        mailsystem.sendMailById(info.actorId, mailData, info.serverId)
    end
end

function CHTeamGroup()
    local data = getSystemVar()
    local temp_rank = utils.table_clone(data.bossDamageRank)
    local count = #temp_rank
    if count < ChampionCommonConfig.needCount then
        data.stage = STAGE_TYPE.Finish
        return
    end

    -- 指定人数超过配置最大人数则删除后面的排名
    if count > ChampionCommonConfig.maxCount then
        for i = ChampionCommonConfig.maxCount, count do
            table.remove(temp_rank)
        end
    end

    -- 创建指定数量的战队
    local maxTeamCount = math.min(count / 5, ChampionCommonConfig.maxTeamCount)
    for i = 1, maxTeamCount do
        local team = initCHTeam(i)
        table.insert(data.teamList, team)
    end

    -- 按排名顺序分配战队长
    for id, team in ipairs(data.teamList) do
        local actorid = temp_rank[1].actorid
        local actorInfo = getActorInfo(actorid)
        team.captainId = actorid
        team.name = string.format(ChampionCommonConfig.teamName, actorInfo.name)
        team.power = team.power + actorInfo.power
        actorInfo.teamId = team.id
        actorInfo.teamPos = TEAM_POSITION.captain
        table.insert(team.memberList, actorid)
        table.remove(temp_rank, 1)
    end

    -- 按排名倒序分配队员
    while temp_rank[1] do
        for i = #data.teamList, 1, -1 do
            local team = data.teamList[i]
            local actorid = temp_rank[1].actorid
            local actorInfo = getActorInfo(actorid)
            team.power = team.power + actorInfo.power
            actorInfo.teamId = team.id
            actorInfo.teamPos = TEAM_POSITION.member
            table.insert(team.memberList, actorid)
            table.remove(temp_rank, 1)
            if not temp_rank[1] then break end
        end
    end

    -- 分配战队到赛区
    local teamRank = {}
    for id, team in ipairs(data.teamList) do
        table.insert(teamRank,{id=team.id,power=team.power})
    end
    table.sort(teamRank,function (a,b) return a.power > b.power end)

    for idx, conf in ipairs(ChampionGameConfig) do
        if conf.stage == STAGE_TYPE.RoundOneStart then
            local gameInfo = getGameInfo(idx)
            for _, v in ipairs(conf.teams) do
                if teamRank[v] then
                    local teamId = teamRank[v].id
                    local teamInfo = getTeamInfo(teamId)
                    if teamInfo then
                        teamInfo.group = conf.group
                        teamInfo.icon = conf.group
                        table.insert(gameInfo.fightList, teamId)
                        gameInfo.betList[teamId] = {}
                    end
                end
            end
        end
    end
end

function CHTeamFight()
    local data = getSystemVar()
    local championFbId = ChampionCommonConfig.championFbId
    local matchFbId = ChampionCommonConfig.matchFbId

    for idx, conf in ipairs(ChampionGameConfig) do
        local tempPower = 0
        repeat
            if conf.stage ~= data.stage  then break end

            local gameInfo = getGameInfo(idx)
            if #gameInfo.fightList == 0 then break end

            local hfuben = instancesystem.createFuBen(championFbId)
            if hfuben == 0 then break end

            local ins = instancesystem.getInsByHdl(hfuben)
            ins.data.gameIndex = idx
            local actorList = ins.data.actorList
            local teamList = ins.data.teamList
            for camp, teamId in ipairs(gameInfo.fightList) do
                local teamInfo = getTeamInfo(teamId)
                teamList[camp] = {
                    camp = camp,
                    teamId = teamId,
                    name = teamInfo.name,
                    icon = teamInfo.icon,
                    power = teamInfo.power,
                    score = 0,
                    buffLevel = 0,
                    isWin = 0,
                    mvp = {
                        actorId = 0,
                        job = 0,
                        name = '',
                        score = 0,
                    },
                }

                if tempPower == 0 then
                    ins.data.winCamp = camp
                    tempPower = teamInfo.power
                elseif teamInfo.power > tempPower then
                    ins.data.winCamp = camp
                    tempPower = teamInfo.power
                end

                for _, actorid in ipairs(teamInfo.memberList) do
                    local aInfo = getActorInfo(actorid)
                    actorList[actorid] = {
                        actorId = actorid,
                        serverid = aInfo.serverId,
                        camp = camp,
                        teamId = teamId,
                        name = aInfo.name,
                        job = aInfo.job,
                        score = 0,
                        totalScore = 0,
                        isLeave = 0,
                    }
                end
            end

            --先把数据写入ins.data中，否则进入副本时的数据还不完整
            for actorid, info in pairs(actorList) do
                local actor = LActor.getActorById(actorid)
                if actor and LActor.getFubenId(actor) == matchFbId then
                    local x,y = utils.getSceneEnterByIndex(championFbId, info.camp)
                    actorcommon.setTeamId(actor, info.camp)
                    LActor.enterFuBen(actor, hfuben, 0, x, y)
                    LActor.setCamp(actor, info.camp)
                else
                    info.isLeave = 1
                end
            end
        until true
    end
end

function CHFinish()
    local data = getSystemVar()
    local winTeam = getTeamInfo(data.winTeamId)
    if not winTeam then return end
    local actorid = winTeam.captainId
    local actor = LActor.getActorById(actorid)
    if actor then--先暴力处理
        offlinedatamgr.CallEhLogout(actor) --保存离线数据
    end
    local actorData = offlinedatamgr.GetDataByOffLineDataType(actorid, offlinedatamgr.EOffLineDataType.EBasic)
    if not actorData == nil then return end
    local worshipInfo = data.worshipInfo
    worshipInfo.name = actorData.actor_name
    worshipInfo.job = actorData.job
    worshipInfo.shenzhuang = actorData.shenzhuangchoose
    worshipInfo.shenqi = actorData.shenqichoose
    worshipInfo.wing = actorData.wingchoose
    worshipInfo.shengling = actorData.shengling_id
    worshipInfo.meilin = actorData.meilinchoose
end

function CHTeamCalcPower(id)
    local teamInfo = getTeamInfo(id)
    local oldpower = teamInfo.power
    local newPower = 0
    for _,actorid in ipairs(teamInfo.memberList) do
        local actorInfo = getActorInfo(actorid)
        newPower = newPower + actorInfo.power
    end
    teamInfo.power = newPower
    print("CHTeamCalcPower teamId =",id,"oldpower =",oldpower,"newPower =",newPower)
end

function CHTeamWin(idx, teamId)
    print("CHTeamWin idx =",idx,"teamId =", teamId)
    local config = ChampionGameConfig[idx]
    if not config then return end
    local teamInfo = getTeamInfo(teamId)
    if not teamInfo then return end
    local gameInfo = getGameInfo(idx)
    if not gameInfo then return end

    --记录队伍胜利场次(每胜利1场+1)
    teamInfo.rank = teamInfo.rank + 1
    gameInfo.winTeamId = teamId

    if config.stage == STAGE_TYPE.ChampStart then
        local data = getSystemVar()
        data.winTeamId = teamId
        data.topTeams = championrank.getCHTopTeams()
    else
        local gInfo = getGameInfo(config.nextwin)
        if not gInfo then return end
        table.insert(gInfo.fightList, teamId)
        gInfo.betList[teamId] = {}
    end
    sendCHBetMail(idx)
end

function sendCHBetMail(idx)
    local gameInfo = getGameInfo(idx)
    if not gameInfo then return end

    local betConfig = ChampionBetConfig[ChampionGameConfig[idx].betType]
    if not betConfig then return end

    if betConfig.stage == STAGE_TYPE.ChampReady then
        sendCHFinalBetMail(betConfig)
    else
        local winTeamId = gameInfo.winTeamId
        for teamId, bInfo in pairs(gameInfo.betList) do
            local mailData = {}
            if teamId == winTeamId then
                mailData.head = betConfig.mailTitle
                mailData.context = betConfig.betWinMailContent
                mailData.tAwardList = betConfig.betWinReward
            else
                mailData.head = betConfig.mailTitle
                mailData.context = betConfig.betWinMailContent
                mailData.tAwardList = betConfig.betWinReward
            end 
            for aid, sid in pairs(bInfo) do
                mailsystem.sendMailById(aid, mailData, sid)
            end
        end
    end
end

function sendCHFinalBetMail(betConfig)
    local data = getSystemVar()
    local finalBetList = data.finalBetList
    local topTeams = data.topTeams

    for actorid, bInfo in pairs(finalBetList) do
        local ret = true
        for i = 1, 3 do
            local betTeamId = bInfo[i]
            if betTeamId then
                if topTeams[i] == betTeamId then
                    local mailData = {
                        head = betConfig.mailTitle,
                        context = betConfig.betWinMailContent,
                        tAwardList = betConfig.betWinReward,
                    }
                    mailsystem.sendMailById(actorid, mailData, bInfo.serverId)
                else
                    local mailData = {
                        head = betConfig.mailTitle,
                        context = betConfig.betLostMailContent,
                        tAwardList = betConfig.betLostReward,
                    }
                    mailsystem.sendMailById(actorid, mailData, bInfo.serverId)
                    ret = false
                end 
            else
                ret = false
            end
        end
        if ret then
            local mailData = {
                head = betConfig.mailTitle,
                context = betConfig.betWinExtraContent,
                tAwardList = betConfig.betWinExtraReward,
            }
            mailsystem.sendMailById(actorid, mailData, bInfo.serverId)
        end
    end
end

function addCHBossDamageRank(actorid, name, value)
    local data = getSystemVar()
    local rank = data.bossDamageRank

    local isHave
    for idx, item in ipairs(rank) do
        if item.actorid == actorid then
            item.score = value
            isHave = true
            break
        end
    end

    if not isHave then
        rank[#rank + 1] = {
            actorid = actorid,
            name = name,
            score = value
        }
    end
    table.sort(rank, function (a,b) return a.score > b.score end)
end

--冠军赛-挑战boss
function CHBossFight(actor)
    if not checkCHStage(STAGE_TYPE.BossBegin) then return end
    if LActor.getFubenId(actor) ~= ChampionCommonConfig.matchFbId then return end
    local var = getActorVar(actor)
    if not var then return end
    local keepTime = ChampionCommonConfig.bossChallengeTime - var.bossFightTime
    if keepTime <= 0 then return end

    local hfuben = instancesystem.createFuBen(ChampionCommonConfig.bossFbId)
    if hfuben == 0 then return end
    local ins = instancesystem.getInsByHdl(hfuben)
    if not ins then return end

    local actorInfo = getActorInfo(LActor.getActorId(actor), true)
    actorInfo.championCount = var.championCount
    actorInfo.power = LActor.getPower(actor)
    actorInfo.name = LActor.getName(actor)
    actorInfo.job = LActor.getJob(actor)
    actorInfo.serverId = LActor.getServerId(actor)

    ins:setEndTime(System.getNowTime() + keepTime)
    local x, y = utils.getSceneEnterCoor(ChampionCommonConfig.bossFbId)
    LActor.enterFuBen(actor, hfuben, 0, x, y)
end

--冠军赛-修改战队信息
function CHTeamChangeInfo(actor, index, name)
    print("CHTeamChangeInfo index =", index, "name =", name)
    local ret = 0

    local icon = ChampionCommonConfig.teamIcons[index]
    if not icon then return print("not icon") end

    local actorid = LActor.getActorId(actor)
    local teamInfo = getCHTeamByActorId(actorid)
    if not teamInfo then return print("not teamInfo") end
    if teamInfo.captainId ~= actorid then return print("teamInfo.captainId ~= actorid") end
    if teamInfo.isChange then return print("teamInfo.isChange not nil") end
    if not actoritem.checkItems(actor, ChampionCommonConfig.changeCostItem) then return print("not actoritem.checkItems(actor, ChampionCommonConfig.changeCostItem)") end

    local oldName = teamInfo.name
    name = LActorMgr.lowerCaseNameStr(name)
    local nameLen = System.getStrLenUtf8(name)
    if oldName == name then
        ret = ERROR_CODE.sameName
    elseif nameLen <= 1 or nameLen > 6 or not LActorMgr.checkNameStr(name) then
        ret = ERROR_CODE.wrongName
    end

    if ret == ERROR_CODE.noErr then
        actoritem.reduceItems(actor, ChampionCommonConfig.changeCostItem, "champion team change")
        teamInfo.icon = index
        teamInfo.name = name
        teamInfo.isChange = true
        s2cCHTeamInfo(actor, teamInfo.id)
    end
    s2cCHTeamChangeInfo(actor, ret)
    print("CHTeamChangeInfo ret =", ret)
end

--冠军赛-领取boss达标奖励
function CHGetBossReward(actor, index)
    local conf = ChampionDamgeRewardConfig[index]
    if not conf then return end

    local var = getActorVar(actor)
    if not var then return end
    if var.bossFightDamage < conf.damage then return end

    local status = var.bossFightRewardStatus[index] or 0
    if status == 1 then return end

    status = 1
    var.bossFightRewardStatus[index] = status
    actoritem.addItems(actor, conf.rewards, "champion boss damage reward")

    s2cCHGetBossReward(actor, index, status)
end

--冠军赛-膜拜
function CHWorship(actor)
    local var = getActorVar(actor)
    if not var then return end
    local count = var.worshipCount
    if count >= ChampionCommonConfig.worshiptimes then return end

    local data = getSystemVar()
    local totalCount = (data.worshipInfo.count or 0) + 1
    data.worshipInfo.count = totalCount

    count = count + 1
    var.worshipCount = count
    actoritem.addItems(actor, ChampionCommonConfig.worshipRewards, "champion worship reward")

    s2cCHWorship(actor, count, totalCount)
end

--冠军赛-投注(晋级赛)
function CHBetGame(actor, idx, teamid)
    local gameInfo = getGameInfo(idx)
    if not gameInfo then return end

    local betConfig = ChampionBetConfig[ChampionGameConfig[idx].betType]
    if not betConfig then return end

    if not checkCHStage(betConfig.stage) then return end

    local betList = gameInfo.betList
    if not betList[teamid] then return end

    local actorid = LActor.getActorId(actor)
    if betList[teamid][actorid] then return end 

    if not actoritem.checkItem(actor, NumericType_YuanBao, betConfig.betCount) then
        return
    end

    actoritem.reduceItem(actor, NumericType_YuanBao, betConfig.betCount, "champion bet")
    betList[teamid][actorid] = LActor.getServerId(actor)
    s2cCHBetGame(actor, idx, teamid)
end

--冠军赛-投注(冠军赛)
function CHFinalBetGame(actor, rank, teamid)
    if rank < 1 or rank > 3 then return end
    if not checkCHStage(STAGE_TYPE.ChampReady) then return end
    local betConfig = ChampionBetConfig[3]
    if not betConfig then return end

    local data = getSystemVar()
    local finalBetList = data.finalBetList
    local topTeams = data.topTeams

    if not utils.checkTableValue(topTeams, teamid) then return end
    if not actoritem.checkItem(actor, NumericType_YuanBao, betConfig.betCount) then return end

    local actorid = LActor.getActorId(actor)
    if not finalBetList[actorid] then 
        finalBetList[actorid] = {
            serverId = LActor.getServerId(actor)
        } 
    end
    local bInfo = finalBetList[actorid]
    if bInfo[rank] then return end

    actoritem.reduceItem(actor, NumericType_YuanBao, betConfig.betCount, "champion bet")
    bInfo[rank] = teamid

    local teamInfo = getTeamInfo(teamid)
    s2cCHFinalBetGame(actor, rank, teamid, teamInfo.name)
end

----------------------------------------------------------------------------------
-- 检查活动时间
function checkChampionTime()
    local data = getSystemVar()
    local now = System.getNowTime()
    local weekTime = System.getWeekFistTime()

    if (data.nextTime or 0) <= now then
        resetChampion()
        data = getSystemVar()
    end

    for idx, conf in ipairs(ChampionStageConfig) do
        if data.idx < idx then
            local d, h, m = string.match(conf.startTime, "(%d+)-(%d+):(%d+)")
            local startTime = weekTime + d * 24 * 3600 + h * 3600 + m * 60
            if startTime <= now then
                updateChampionStage()
            end
        end
    end
end

-- 重置活动数据
function resetChampion()
    local var = System.getStaticVar()
    var.champion = nil
end

-- 阶段变更
function updateChampionStage()
    if not System.isLianFuSrv() then return end
    if checkCHStage(STAGE_TYPE.Finish) then return end

    local data = getSystemVar()
    data.idx = data.idx + 1

    local stage = data.stage + 1
    data.stage = stage

    if stage == STAGE_TYPE.TeamGroup then
        CHTeamGroup()
    elseif stage == STAGE_TYPE.RoundOneStart 
        or stage == STAGE_TYPE.RoundTwoStart 
        or stage == STAGE_TYPE.ChampStart 
        then
        CHTeamFight()
    elseif stage == STAGE_TYPE.Finish then
        championrank.sendCHActorRankReward()
        championrank.sendCHTeamRankReward()
        CHFinish()
    end
end

----------------------------------------------------------------------------------
--协议处理
--92-40 冠军赛-活动信息
function s2cChampionInfo(actor)
    local var = getActorVar(actor)
    if not var then return end

    local data = getSystemVar()
    local actorid = LActor.getActorId(actor)
    local team = getCHTeamByActorId(actorid)

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_Info)
    if pack == nil then return end

    LDataPack.writeChar(pack, data.stage)

    for stage = STAGE_TYPE.Default, STAGE_TYPE.Finish do
        LDataPack.writeInt(pack, STAGE_TIME[stage] or 0)
    end

    LDataPack.writeChar(pack, team and team.id or 0)

    LDataPack.writeDouble(pack, var.bossFightDamage)
    LDataPack.writeChar(pack, #ChampionDamgeRewardConfig)
    for index in ipairs(ChampionDamgeRewardConfig) do
        LDataPack.writeChar(pack, index)
        LDataPack.writeChar(pack, var.bossFightRewardStatus[index] or 0)
    end

    LDataPack.writeChar(pack, #data.gameList)
    for index, gameInfo in ipairs(data.gameList) do
        LDataPack.writeChar(pack, gameInfo.id)
        LDataPack.writeChar(pack, gameInfo.stage)
        LDataPack.writeChar(pack, gameInfo.group)

        LDataPack.writeChar(pack, #gameInfo.fightList)
        for _, teamId in ipairs(gameInfo.fightList) do
            local teamInfo = getTeamInfo(teamId)
            LDataPack.writeChar(pack, teamInfo.id)
            LDataPack.writeString(pack, teamInfo.name)
            LDataPack.writeChar(pack, teamInfo.icon)
            LDataPack.writeChar(pack, teamInfo.rank)
        end
    end

    local worshipInfo = data.worshipInfo
    LDataPack.writeChar(pack, var.worshipCount)
    LDataPack.writeInt(pack, worshipInfo.count or 0) --被膜拜次数
    LDataPack.writeString(pack, worshipInfo.name or "") --雕像名字
    LDataPack.writeChar(pack, worshipInfo.job or 0)--雕像职业
    LDataPack.writeInt(pack, worshipInfo.shenzhuang or 0)--雕像神装
    LDataPack.writeInt(pack, worshipInfo.shenqi or 0)--雕像神器
    LDataPack.writeInt(pack, worshipInfo.wing or 0)--雕像翅膀
    LDataPack.writeInt(pack, worshipInfo.shengling or 0)--雕像圣灵
    LDataPack.writeInt(pack, worshipInfo.meilin or 0)--雕像梅林
    LDataPack.flush(pack)
end

--92-41 冠军赛-请求查看战队
local function c2sCHTeamInfo(actor, packet)
    local id = LDataPack.readChar(packet)
    s2cCHTeamInfo(actor, id)
end

--92-41 冠军赛-返回查看战队
function s2cCHTeamInfo(actor, teamId)
    local teamInfo = getTeamInfo(teamId)
    if not teamInfo then return end
    local captain = getActorInfo(teamInfo.captainId)
    
    local actorid = LActor.getActorId(actor)
    local actorInfo = getActorInfo(actorid)
    local myPos = actorInfo and actorInfo.pos or 0

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_TeamInfo)
    if pack == nil then return end
    LDataPack.writeChar(pack, teamInfo.id)
    LDataPack.writeChar(pack, teamInfo.group)
    LDataPack.writeString(pack, teamInfo.name)
    LDataPack.writeChar(pack, teamInfo.icon)
    LDataPack.writeString(pack, captain.name)
    LDataPack.writeDouble(pack, teamInfo.power)
    LDataPack.writeChar(pack, myPos)
    LDataPack.writeChar(pack, teamInfo.isChange and 1 or 0)
    LDataPack.writeChar(pack, #teamInfo.memberList)
    for _, aid in ipairs(teamInfo.memberList) do
        local aInfo = getActorInfo(aid)
        LDataPack.writeString(pack, aInfo.name)
        LDataPack.writeDouble(pack, aInfo.power)
        LDataPack.writeInt(pack, aInfo.championCount)
    end
    LDataPack.flush(pack)
end

--92-42 冠军赛-请求修改战队信息
local function c2sCHTeamChangeInfo(actor, packet)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end

    local index = LDataPack.readChar(packet)
    local name = LDataPack.readString(packet)
    CHTeamChangeInfo(actor, index, name)
end

--92-42 冠军赛-返回战队修改结果
function s2cCHTeamChangeInfo(actor, ret)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_TeamChangeInfo)
    if pack == nil then return end
    LDataPack.writeChar(pack, ret)
    LDataPack.flush(pack)
end

--92-43 冠军赛-挑战boss
local function c2sCHBossFight(actor)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end

    CHBossFight(actor)
end

--92-43 冠军赛-更新boss伤害
function s2cCHBossFight(actor, damage)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_BossFight)
    if pack == nil then return end
    LDataPack.writeDouble(pack, damage)
    LDataPack.flush(pack)
end

--92-44 冠军赛-请求领取boss达标奖励
local function c2sCHGetBossReward(actor, packet)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end

    local index = LDataPack.readChar(packet)
    CHGetBossReward(actor, index)
end

--92-44 冠军赛-返回领取boss达标奖励
function s2cCHGetBossReward(actor, index, status)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_GetBossReward)
    if pack == nil then return end
    LDataPack.writeChar(pack, index)
    LDataPack.writeChar(pack, status)
    LDataPack.flush(pack)
end

--92-45 冠军赛-请求Boss伤害榜
local function c2sCHGetBossRank(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end

    s2cCHGetBossRank(actor)
end

--92-45 冠军赛-返回Boss伤害榜
function s2cCHGetBossRank(actor)
    local data = getSystemVar()
    local rank = data.bossDamageRank

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_GetBossRank)
    if pack == nil then return end

    LDataPack.writeInt(pack, count)
    local myrank = 0
    local myscore = 0
    local actorid = LActor.getActorId(actor)
    
    for i, info in ipairs(rank) do
        if info.actorid == actorid then
            myrank = i
            myscore = info.score
            break
        end
        LDataPack.writeString(pack, info.name)
        LDataPack.writeDouble(pack, info.score)
    end
    
    LDataPack.writeInt(pack, myrank)
    LDataPack.writeDouble(pack, myscore)
    LDataPack.flush(pack)
end

--92-53 冠军赛-请求膜拜
local function c2sCHWorship(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end

    CHWorship(actor)
end

--92-53 冠军赛-返回膜拜
function s2cCHWorship(actor, count, totalCount)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_Worship)
    if pack == nil then return end

    LDataPack.writeChar(pack, count)
    LDataPack.writeInt(pack, totalCount)
    LDataPack.flush(pack)
end

--92-58 冠军赛-请求查看投注信息
local function c2sCHBetInfo(actor, packet)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end

    local gameIndexs = {}
    local count = LDataPack.readChar(packet)
    for i = 1,count do
        local index = LDataPack.readChar(packet)
        if not ChampionGameConfig[index] then return end
        gameIndexs[i] = index
    end
    s2cCHBetInfo(actor, gameIndexs)
end

--92-58 冠军赛-返回查看投注信息
function s2cCHBetInfo(actor, gameIndexs)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_ResBetInfo)
    if pack == nil then return end

    local actorid = LActor.getActorId(actor)
    LDataPack.writeChar(pack, #gameIndexs)
    for _, idx in ipairs(gameIndexs) do
        local gameInfo = getGameInfo(idx)
        local bInfo = gameInfo.betList[actorid]
        local myBetTeamId = bInfo and bInfo[1] or 0
        LDataPack.writeChar(pack, gameInfo.winTeamId)
        LDataPack.writeChar(pack, myBetTeamId)
        for __, teamId in ipairs(gameInfo.fightList) do
            local teamInfo = getTeamInfo(teamId)
            LDataPack.writeChar(pack, teamId)
            LDataPack.writeString(pack, teamInfo.name)
            LDataPack.writeChar(pack, teamInfo.icon)
        end
    end
    LDataPack.flush(pack)
end

--92-59 冠军赛-请求投注
local function c2sCHBetGame(actor, packet)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end

    local idx = LDataPack.readChar(packet)
    local teamid = LDataPack.readChar(packet)
    CHBetGame(actor, idx, teamid)
end

--92-59 冠军赛-返回投注
function s2cCHBetGame(actor, idx, teamid)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_BetGame)
    if pack == nil then return end

    LDataPack.writeChar(pack, idx)
    LDataPack.writeChar(pack, teamid)
    LDataPack.flush(pack)
end

--92-60 冠军赛-请求查看投注信息(冠军赛)
local function c2sCHFinalBetInfo(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end

    s2cCHFinalBetInfo(actor)
end

--92-60 冠军赛-返回查看投注信息(冠军赛)
function s2cCHFinalBetInfo(actor)
    local data = getSystemVar()
    local finalBetList = data.finalBetList
    local topTeams = data.topTeams

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_ReqFinalBetInfo)
    if pack == nil then return end

    local actorid = LActor.getActorId(actor)
    local bInfo = finalBetList[actorid]
    LDataPack.writeChar(pack, #topTeams)
    for rank, teamId in ipairs(topTeams) do
        local teamInfo = getTeamInfo(teamId)
        local betTeamId = bInfo and bInfo[rank] or 0
        local betTeamInfo = getTeamInfo(betTeamId)
        LDataPack.writeChar(pack, rank)
        LDataPack.writeChar(pack, teamId)
        LDataPack.writeString(pack, teamInfo.name)
        LDataPack.writeChar(pack, teamInfo.icon)
        LDataPack.writeChar(pack, betTeamId)
        LDataPack.writeString(pack, betTeamInfo and betTeamInfo.name or "")
    end
    LDataPack.flush(pack)
end

--92-61 冠军赛-请求投注(冠军赛)
local function c2sCHFinalBetGame(actor, packet)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end

    local rank = LDataPack.readChar(packet)
    local teamid = LDataPack.readChar(packet)
    CHFinalBetGame(actor, rank, teamid)
end

--92-61 冠军赛-返回投注(冠军赛)
function s2cCHFinalBetGame(actor, rank, teamid, name)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_BetGame)
    if pack == nil then return end

    LDataPack.writeChar(pack, rank)
    LDataPack.writeChar(pack, teamid)
    LDataPack.writeString(pack, name)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--跨服协议

----------------------------------------------------------------------------------
--事件处理
--玩家事件
local function onLogin(actor)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.champion) then return end
    s2cChampionInfo(actor)
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    reSetCHActor(actor)
    if not login then
        s2cChampionInfo(actor)
    end
end

--副本事件
local function onEnterFb(ins, actor)

end

local function onExitFb(ins, actor)
    --if ins.is_end then return end
    local var = getActorVar(actor)
    local actorid = LActor.getActorId(actor)
    local actorinfo = ins.actor_list[actorid]
    local costTime = System.getNowTime() - actorinfo.enter_time

    var.bossFightTime = var.bossFightTime + costTime
    addCHBossDamageRank(actorid, LActor.getName(actor), var.bossFightDamage)
end

local function onLose(ins)
    -- print("onLose actor =", actor)
    -- local var = getActorVar(actor)
    -- local actorid = LActor.getActorId(actor)
    -- var.bossFightTime = ChampionCommonConfig.bossChallengeTime
    -- addCHBossDamageRank(actorid, var.bossFightDamage)
end

local function onOffline(ins, actor)
    LActor.exitFuben(actor)
end

local function onShieldOutput(ins, monster, value, attacker)
    
    local actor = LActor.getActor(attacker)
    if not actor then return end

    local var = getActorVar(actor)
    if not var then return end

    local damage = var.bossFightDamage
    damage = damage + value
    var.bossFightDamage = damage
    s2cCHBossFight(actor, damage)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    if System.isBattleSrv() then return end
    --if System.isLianFuSrv() then return end

    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cChampionCmd_TeamInfo, c2sCHTeamInfo)
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cChampionCmd_GetBossReward, c2sCHGetBossReward)
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cChampionCmd_GetBossRank, c2sCHGetBossRank)

    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)

    if System.isCommSrv() then return end

    checkChampionTime()
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cChampionCmd_BossFight, c2sCHBossFight)
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cChampionCmd_TeamChangeInfo, c2sCHTeamChangeInfo)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cChampionCmd_Worship, c2sCHWorship)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cChampionCmd_ReqBetInfo, c2sCHBetInfo)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cChampionCmd_BetGame, c2sCHBetGame)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cChampionCmd_ReqFinalBetInfo, c2sCHFinalBetInfo)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cChampionCmd_BetFinalGame, c2sCHFinalBetGame)

    local bossFbId = ChampionCommonConfig.bossFbId
    insevent.registerInstanceEnter(bossFbId, onEnterFb)
    insevent.registerInstanceExit(bossFbId, onExitFb)
    insevent.registerInstanceLose(bossFbId, onLose)
    insevent.registerInstanceOffline(bossFbId, onOffline)
    insevent.registerInstanceShieldOutput(bossFbId, onShieldOutput)

end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.printCHSysVar = function (actor, args)
    local data = getSystemVar()
    print("*******championVar*******")
    utils.printTable(data)
    print("************************")
    if System.isCommSrv() then
        SCTransferGM("printCHSysVar", args, true)
    end
    return true
end

gmCmdHandlers.printCHActorVar = function (actor, args)
    local var = getActorVar(actor)
    print("*******actorVar*******")
    print("var.bossFightDamage =",var.bossFightDamage)
    print("var.bossFightTime =",var.bossFightTime)
    print("************************")
    return true
end

gmCmdHandlers.chClear = function (actor, args)
    if System.isBattleSrv() then return end
    if System.isCommSrv() then
        SCTransferGM("chClear", args, true)
    end
    local data = System.getStaticVar()
    data.champion = nil
    data.championrank = nil
    local actors = System.getOnlineActorList()
    if actors then
        for _, v in ipairs(actors) do
            reSetCHActor(v)
        end
    end
    return true
end

gmCmdHandlers.chUpdate = function (actor, args)
    if System.isBattleSrv() then return end
    if System.isCommSrv() then
        SCTransferGM("chUpdate", args, true)
        return true
    end
    updateChampionStage()
    return true
end

gmCmdHandlers.chFight = function (actor, args)
    if not System.isLianFuSrv() then return end
    CHBossFight(actor)
    return true
end

gmCmdHandlers.chAllFight = function (actor, args)
    if not System.isLianFuSrv() then return end
    local actors = System.getOnlineActorList()
    if actors then
        for _, v in ipairs(actors) do
            if v ~= actor then
                CHBossFight(v)
                if LActor.getFubenId(v) == ChampionCommonConfig.bossFbId then
                    LActor.exitFuben(v)
                end
            end
        end
    end
    return true
end

gmCmdHandlers.chChange = function (actor, args)
    if not System.isLianFuSrv() then return end
    local index = tonumber(args[1])
    local name = args[2]

    CHTeamChangeInfo(actor, index, name)
    return true
end

gmCmdHandlers.chReward = function (actor, args)
    local index = tonumber(args[1])
    CHGetBossReward(actor, index)
    return true
end

