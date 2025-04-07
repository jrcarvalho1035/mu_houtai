-- 神魔圣战数据处理(阵营战)
module("campbattle", package.seeall)

local CAMP_NONE = 0 --无阵营
local CAMP_GOD = 1 --神阵营
local CAMP_DEVIL = 2 --魔阵营
CAMP_COUNT = 2 --阵营数量
local Fight_type = {--是否为助战
    none = 0, --无任何奖励
    invite = 1, --挑战奖励
    help = 2, --助战奖励
}
MATCH_POOL_GOD = MATCH_POOL_GOD or {} --神阵营等待匹配池
MATCH_POOL_DEVIL = MATCH_POOL_DEVIL or {} --魔阵营等待匹配池

local function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.campbattle then
        var.campbattle = {}
        var.campbattle.rewardCount = 0 --每日奖励次数
        var.campbattle.joinCount = 0 --每日助战次数
        var.campbattle.rewardsBoxRecord = 0 --每日场次状态
        var.campbattle.scoreRewards = {} --阵营达标领奖状态
        var.campbattle.lastWeekTime = 0 --记录上周领奖状态时间
        var.campbattle.inviteCd = 0 --记录上次收到邀请信息的时间
    end
    return var.campbattle
end

local function getSystemVar()
    local var = System.getStaticCampBattleVar()
    if not var then return end
    if not var.campbattle then
        var.campbattle = {
            memberList = {
            },
            campScore = {
                [CAMP_GOD] = 0,
                [CAMP_DEVIL] = 0,
            },
            joinCamp = getRandomCamp(),
        }
    end
    return var.campbattle
end

local function getActorCampInfo(actor, actorid)
    local campList = getCampList()
    actorid = actorid or LActor.getActorId(actor)
    if not campList[actorid] then
        initActorCamp(actor)
    end
    return campList[actorid]
end

local function getCampScore()
    local var = getSystemVar()
    return var.campScore
end

function checkCBInviteCD(actor)
    local now = System.getNowTime()
    local var = getActorVar(actor)
    return now > (var.inviteCd or 0)
end

function setCBInviteCD(actor)
    local now = System.getNowTime()
    local var = getActorVar(actor)
    var.inviteCd = now + CampBattleCommonConfig.inviteCd
end

function clearCampBattleVar()
    local var = System.getStaticCampBattleVar()
    var.campbattle = nil
end

function checkCampGod(camp)
    return camp == CAMP_GOD
end

function checkCampDevil(camp)
    return camp == CAMP_DEVIL
end

function getRandomCamp()
    return math.random(CAMP_GOD, CAMP_DEVIL)
end

function getActorCamp(actor)
    local info = getActorCampInfo(actor)
    return info and info.camp or CAMP_NONE
end

function getRewardCount(actor)
    local var = getActorVar(actor)
    return var.rewardCount
end

function getJoinCount(actor)
    local var = getActorVar(actor)
    return var.joinCount
end

function getCBFightType(actor)
    local var = getActorVar(actor)
    if var.rewardCount < CampBattleCommonConfig.rewardCount then
        return Fight_type.invite
    elseif var.joinCount < CampBattleCommonConfig.joinCount then
        return Fight_type.help
    else
        return Fight_type.none
    end
end

--检查玩家是否有阵营
function checkActorCamp(actor)
    local info = getActorCampInfo(actor)
    if not info then return false end
    if info.camp == CAMP_NONE then return false end
    return true
end

function addCBScore(actorid, isWin, isInvite)
    local info = getActorCampInfo(nil, actorid)
    if not info then return end
    
    local wDay = System.getDayOfWeek()
    local multiple = CampBattleSeasonConfig[wDay].multiple
    local campScore = getCampScore()
    local camp = info.camp
    
    local oldCampScore = campScore[camp]
    local oldScore = info.score
    local addScore = 0
    local addCamp = 0
    local rewards = {}
    if Fight_type.invite == isInvite then
        local config = CampBattleCommonConfig.loseParam
        if isWin then
            config = CampBattleCommonConfig.winParam
        end
        local a, b, c = config.a, config.b, config.c
        addScore = math.min(math.floor((oldScore * a + b + c) + 0.5), CampBattleCommonConfig.maxScore) * multiple
        campScore[camp] = oldCampScore + addScore
        info.score = oldScore + addScore
        addCamp = addScore
        rewards = {{type = 0, id = NumericType_ContributionCamp, count = addCamp}}
    elseif Fight_type.help == isInvite then
        addCamp = CampBattleCommonConfig.campCount
        rewards = {{type = 0, id = NumericType_ContributionCamp, count = addCamp}}
    end
    print("addCBScore:", "actorid =", actorid, "camp =", camp, "Fight_type =", isInvite, "isWin =", isWin, "oldScore =", oldScore, "addScore =", addScore, "addCamp =", addCamp, "multiple =", multiple)
    return oldCampScore, oldScore, addScore, addCamp, multiple, rewards
end

function getCampList()
    local var = getSystemVar()
    return var.memberList
end

function initActorCamp(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.campbattle) then return end
    if not campbattlesystem.isCBCampOpen() then return end
    
    local actorid = LActor.getActorId(actor)
    local basic_data = LActor.getActorData(actor)
    if System.isCommSrv() then
        local info = {
            job = basic_data.job,
            power = basic_data.total_power,
            name = basic_data.actor_name,
        }
        SCSendInitActorCampInfo(actorid, info)
        return
    end
    local sysVar = getSystemVar()
    local campList = getCampList()
    
    local info = campList[actorid]
    if info then return end
    
    campList[actorid] = {
        actorid = actorid,
        serverid = basic_data.server_index,
        job = basic_data.job,
        power = basic_data.total_power,
        name = basic_data.actor_name,
        score = CampBattleCommonConfig.initScore, --个人积分
        isShow = 0,
        camp = CAMP_NONE,
    }
    
    local actorCampList = campbattlesystem.getActorCampList()
    local camp = CAMP_NONE
    if actorCampList[actorid] then
        camp = actorCampList[actorid]
    else
        camp = sysVar.joinCamp
        sysVar.joinCamp = sysVar.joinCamp % CAMP_COUNT + 1
    end
    campList[actorid].camp = camp
    SCSendActorInfo(actorid)
    System.saveStaticCampBattle()
    print("initActorCamp actorid =", actorid, "camp =", camp)
end

function sendCBBoxReward(actor)
    if System.isBattleSrv() then return end
    local var = getActorVar(actor)
    local rewards = {}
    for index, conf in ipairs(CampBattleDailyRewardConfig) do
        if not System.bitOPMask(var.rewardsBoxRecord, index) and var.rewardCount >= conf.count then
            for _, item in ipairs(conf.rewards) do
                table.insert(rewards, item)
            end
        end
    end
    if next(rewards) then
        local mailData = {
            head = CampBattleCommonConfig.dayMailTitle,
            context = CampBattleCommonConfig.dayMailContent,
            tAwardList = rewards,
        }
        mailsystem.sendMailById(LActor.getActorId(actor), mailData)
    end
end

function reSetTeamMatch(team)
    team.status = campbattleteam.statusType.tNoMatch
    team.ravilid = 0
    team.readyTime = 0
    team.fightTime = 0
    team.matchTime = 0
    if team.eid then
        LActor.cancelScriptEvent(nil, team.eid)
        team.eid = nil
    end
end

function setTeamMatchNone(team, isCancel)
    team.status = campbattleteam.statusType.tNoMatch
    team.ravilid = 0
    team.readyTime = 0
    team.fightTime = 0
    team.matchTime = 0
    if team.eid then
        LActor.cancelScriptEvent(nil, team.eid)
        team.eid = nil
    end
    removeMatchPool(team)
    campbattleteam.sendCancelMatch(team.teamid, isCancel)
end

function setTeamMatchIn(team)
    team.status = campbattleteam.statusType.tInMatch
    team.ravilid = 0
    team.readyTime = 0
    team.fightTime = 0
    team.matchTime = System.getNowTime() + CampBattleCommonConfig.matchTime
    if not team.eid then
        team.eid = LActor.postScriptEventLite(nil, CampBattleCommonConfig.matchTime * 1000, matchCloneRavil, team.teamid)
    end
    campbattleteam.sendMatchInfo(team.teamid)
end

function setTeamMatchHave(team, ravil)
    if team.eid then
        LActor.cancelScriptEvent(nil, team.eid)
        team.eid = nil
    end
    
    if ravil.eid then
        LActor.cancelScriptEvent(nil, ravil.eid)
        ravil.eid = nil
    end
    local readyTime = System.getNowTime() + CampBattleCommonConfig.readyTime
    local fightTime = readyTime + CampBattleCommonConfig.fightTime
    
    team.status = campbattleteam.statusType.tHaveMatch
    team.ravilid = ravil.teamid
    team.readyTime = readyTime
    team.fightTime = fightTime
    campbattleteam.sendMatchInfo(team.teamid)
    
    ravil.status = campbattleteam.statusType.tHaveMatch
    ravil.ravilid = team.teamid
    ravil.readyTime = readyTime
    ravil.fightTime = fightTime
    campbattleteam.sendMatchInfo(ravil.teamid)
end

function setTeamStart(team)
    team.status = campbattleteam.statusType.tMatchReady
end

function isTeamMatchNone(team)
    if not team then return false end
    return team.status == campbattleteam.statusType.tNoMatch
end

function isTeamMatchIn(team)
    if not team then return false end
    return team.status == campbattleteam.statusType.tInMatch
end

function isTeamMatchHave(team)
    if not team then return false end
    return team.status == campbattleteam.statusType.tHaveMatch
end

function isTeamMatchReady(team)
    if not team then return false end
    return team.status == campbattleteam.statusType.tMatchReady
end

function isTeamLock(team)
    if not team then return false end
    return team.status > campbattleteam.statusType.tNoMatch
end

function matchCancelCBRival(teamId)
    local team = campbattleteam.getCBTeamById(teamId)
    if not team then return end
    if not isTeamMatchIn(team) then return end
    setTeamMatchNone(team, true)
end

function matchCBRival(team)
    if not isTeamMatchNone(team) then return end
    if team.camp == CAMP_GOD then
        mathDevilCamp(team)
    elseif team.camp == CAMP_DEVIL then
        mathGodCamp(team)
    end
    return true
end

function mathGodCamp(team)
    local isMatch = false
    for idx, godTeam in ipairs(MATCH_POOL_GOD) do
        if isTeamMatchIn(godTeam) then
            setTeamMatchHave(team, godTeam)
            matchSuccess(team, godTeam)
            table.remove(MATCH_POOL_GOD, idx)
            isMatch = true
            break
        end
    end
    
    if not isMatch then
        table.insert(MATCH_POOL_DEVIL, team)
        setTeamMatchIn(team)
    end
end

function mathDevilCamp(team)
    local isMatch = false
    for idx, devilTeam in ipairs(MATCH_POOL_DEVIL) do
        if isTeamMatchIn(devilTeam) then
            setTeamMatchHave(team, devilTeam)
            matchSuccess(team, devilTeam)
            table.remove(MATCH_POOL_DEVIL, idx)
            isMatch = true
            break
        end
    end
    
    if not isMatch then
        table.insert(MATCH_POOL_GOD, team)
        setTeamMatchIn(team)
    end
end

function matchSuccess(team, ravil)
    --注册副本开始定时器
    -- for actorid, info in pairs(team.members) do
    --     local actor = LActor.getActorById(actorid)
    --     if actor then
    --         local var = getActorVar(actor)
    --         if info.isInvite == Fight_type.invite then
    --             var.rewardCount = var.rewardCount + 1
    --         elseif info.isInvite == Fight_type.help then
    --             var.joinCount = var.joinCount + 1
    --         end
    --         s2cCampBattleInfo(actor)
    --     else
    --         info.noReward = 1
    --     end
    -- end
    
    -- for actorid, info in pairs(ravil.members) do
    --     local actor = LActor.getActorById(actorid)
    --     if actor then
    --         local var = getActorVar(actor)
    --         if info.isInvite == Fight_type.invite then
    --             var.rewardCount = var.rewardCount + 1
    --         else
    --             var.joinCount = var.joinCount + 1
    --         end
    --         s2cCampBattleInfo(actor)
    --     else
    --         info.noReward = 1
    --     end
    -- end
    
    local now = System.getNowTime()
    LActor.postScriptEventLite(nil, (team.readyTime - now) * 1000, beforeEnter, team.teamid)
    LActor.postScriptEventLite(nil, (ravil.readyTime - now) * 1000, beforeEnter, ravil.teamid)
    
    LActor.postScriptEventLite(nil, (team.fightTime - now) * 1000, enterFuben, team.teamid)
end

local function randomClonePos(team)
    local memberPos = team.memberPos
    local count = #memberPos
    for idx = 1, count do
        local rand = math.random(1, count)
        if rand ~= idx then
            memberPos[idx], memberPos[rand] = memberPos[rand], memberPos[idx]
        end
    end
end

--复制队伍数据,生成一支克隆队伍
function matchCloneRavil(_, teamId)
    local team = campbattleteam.getCBTeamById(teamId)
    if not team then return end
    local ravil = campbattleteam.creatCloneCBTeam(team)
    if ravil then
        setTeamMatchHave(team, ravil)
        matchSuccess(team, ravil)
        randomClonePos(ravil)
        removeMatchPool(team)
    else
        setTeamMatchNone(team)
        setTeamMatchIn(team)
    end
end

--将队伍移出匹配等待区
function removeMatchPool(team)
    if team.camp == CAMP_GOD then
        for idx, godTeam in ipairs(MATCH_POOL_GOD) do
            if godTeam == team then
                table.remove(MATCH_POOL_GOD, idx)
                break
            end
        end
    elseif team.camp == CAMP_DEVIL then
        for idx, devilTeam in ipairs(MATCH_POOL_DEVIL) do
            if devilTeam == team then
                table.remove(MATCH_POOL_DEVIL, idx)
                break
            end
        end
    end
end

function beforeEnter(_, teamId)
    local team = campbattleteam.getCBTeamById(teamId)
    setTeamStart(team)
    campbattleteam.sendMatchInfo(teamId)
    campbattleteam.notifyCBTeamInfo(teamId)
end

function enterFuben(_, teamId)
    local team = campbattleteam.getCBTeamById(teamId)
    if not team then return end
    
    local ravil = campbattleteam.getCBTeamById(team.ravilid)
    if not ravil then return end
    
    local fbHandle = instancesystem.createFuBen(CampBattleCommonConfig.fightFbId)
    if not fbHandle or fbHandle == 0 then return end
    
    local ins = instancesystem.getInsByHdl(fbHandle)
    ins.data.actorList = {}
    ins.data.roundInfo = {}
    ins.data.teamInfo = {
        [teamId] = {
            round = 0,
            winPoint = 0,
            isWin = 0,
            ravilid = ravil.teamid,
            camp = team.camp
        },
        [team.ravilid] = {
            round = 0,
            winPoint = 0,
            isWin = 0,
            ravilid = teamId,
            camp = ravil.camp
        },
    }
    
    local actorList = ins.data.actorList
    local roundInfo = ins.data.roundInfo
    
    --主场队伍
    for idx, actorid in ipairs(team.memberPos) do
        if not roundInfo[idx] then
            roundInfo[idx] = {
                players = {},
                winInfo = {},
                actorHandles = {},
            }
        end
        roundInfo[idx].players[team.camp] = actorid
        local info = team.members[actorid]
        actorList[actorid] = {
            round = idx,
            teamid = team.teamid,
            camp = team.camp,
            actorid = info.actorid,
            serverid = info.serverid,
            isInvite = info.isInvite,
            job = info.job,
            level = info.level,
            power = info.power,
            name = info.name,
            isRobot = info.isRobot,
            noReward = 0,
            isLeave = 0,
            actorCloneHandle = 0,
        }
    end
    
    --客场队伍
    for idx, actorid in ipairs(ravil.memberPos) do
        roundInfo[idx].players[ravil.camp] = actorid
        local info = ravil.members[actorid]
        actorList[actorid] = {
            round = idx,
            teamid = ravil.teamid,
            camp = ravil.camp,
            actorid = info.actorid,
            serverid = info.serverid,
            isInvite = info.isInvite,
            job = info.job,
            level = info.level,
            power = info.power,
            name = info.name,
            isRobot = info.isRobot,
            noReward = 0,
            isLeave = 0,
            actorCloneHandle = 0,
        }
    end
    reSetTeamMatch(team)
    reSetTeamMatch(ravil)
    --一定要把两支队伍的数据都存到ins里面，再处理玩家进入副本
    --否则玩家进入副本时，数据是不全的
    ----------------------------------------------------------
    local leaveList = {}
    --主场队伍
    for idx, actorid in ipairs(team.memberPos) do
        local info = team.members[actorid]
        local pos = CampBattleCommonConfig.pos[team.camp][idx]
        if info.isRobot == 0 then
            local actor = LActor.getActorById(actorid)
            roundInfo[idx].actorHandles[team.camp] = LActor.getHandle(actor)
            if actor and LActor.getFubenId(actor) == CampBattleCommonConfig.matchFbId then
                local var = getActorVar(actor)
                if info.isInvite == Fight_type.invite then
                    var.rewardCount = var.rewardCount + 1
                elseif info.isInvite == Fight_type.help then
                    var.joinCount = var.joinCount + 1
                end
                info.isInvite = campbattle.getCBFightType(actor)
                s2cCampBattleInfo(actor)
                LActor.enterFuBen(actor, fbHandle, 0, pos.x, pos.y)
            else
                actorList[actorid].noReward = 1
                actorList[actorid].isLeave = 1
                table.insert(leaveList, actorid)
            end
        else
            local actorClone = setCBRobot(fbHandle, actorid, pos, info.cloneActorid, info.name)
            local actorCloneHandle = LActor.getRealHandle(actorClone)
            actorList[actorid].actorCloneHandle = actorCloneHandle
            roundInfo[idx].actorHandles[team.camp] = LActor.getHandle(actorClone)
            for _, effectId in ipairs(CampBattleCommonConfig.waitEffectId) do
                LActor.addSkillEffect(actorClone, effectId)
            end
            LActor.setSuperCloneChangeCD(actorClone, 99999)
            LActor.setCamp(actorClone, team.camp)
        end
    end
    
    --客场队伍
    for idx, actorid in ipairs(ravil.memberPos) do
        local info = ravil.members[actorid]
        local pos = CampBattleCommonConfig.pos[ravil.camp][idx]
        if info.isRobot == 0 then
            local actor = LActor.getActorById(actorid)
            roundInfo[idx].actorHandles[ravil.camp] = LActor.getHandle(actor)
            if actor and LActor.getFubenId(actor) == CampBattleCommonConfig.matchFbId then
                local var = getActorVar(actor)
                if info.isInvite == Fight_type.invite then
                    var.rewardCount = var.rewardCount + 1
                elseif info.isInvite == Fight_type.help then
                    var.joinCount = var.joinCount + 1
                end
                info.isInvite = campbattle.getCBFightType(actor)
                s2cCampBattleInfo(actor)
                LActor.enterFuBen(actor, fbHandle, 0, pos.x, pos.y)
            else
                actorList[actorid].noReward = 1
                actorList[actorid].isLeave = 1
                table.insert(leaveList, actorid)
            end
        else
            local actorClone = setCBRobot(fbHandle, actorid, pos, info.cloneActorid, info.name)
            local actorCloneHandle = LActor.getRealHandle(actorClone)
            actorList[actorid].actorCloneHandle = actorCloneHandle
            roundInfo[idx].actorHandles[ravil.camp] = LActor.getHandle(actorClone)
            for _, effectId in ipairs(CampBattleCommonConfig.waitEffectId) do
                LActor.addSkillEffect(actorClone, effectId)
            end
            LActor.setSuperCloneChangeCD(actorClone, 99999)
            LActor.setCamp(actorClone, ravil.camp)
        end
    end
    
    for i, actorid in ipairs(leaveList) do
        campbattleteam.exitCBTeam(nil, actorid)
    end
    
    -- 9225 【神魔圣战】战斗结束后，保留队伍
    --campbattleteam.breakTeam(team.teamid)
    if ravil.isClone == 1 then
        campbattleteam.breakTeam(ravil.teamid)
    end
end

function setCBRobot(fbHandle, robotid, pos, cloneActorid, cloneName)
    local roleCloneData = nil
    local actorData = nil
    local roleSuperData = nil
    roleCloneData, actorData, roleSuperData = actorcommon.createRobotClone(CampBattleRobotConfig, robotid, "", cloneName)
    if not (roleCloneData and actorData and roleSuperData) then return end
    if roleSuperData then
        roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
        roleSuperData.aiId = CampBattleRobotConfig[robotid].superAi
    end
    
    if cloneActorid then
        local attrRand = CampBattleRobotConfig[robotid].attrRand
        local attrPer = math.random(attrRand[1] or 100, attrRand[2] or 100) / 100
        
        local actor = LActor.getActorById(cloneActorid)
        if actor then
            local roleAttr = LActor.getRoleAttrsBasic(actor)
            roleCloneData.attrs:Reset()
            for attrType = Attribute.atHp, Attribute.atCount - 1 do
                if attrType ~= Attribute.atMvSpeed then
                    roleCloneData.attrs:Set(attrType, roleAttr[attrType] * attrPer)
                else
                    roleCloneData.attrs:Set(attrType, roleAttr[attrType])
                end
            end
        else
            local robotConfig = CampBattleRobotConfig[cloneActorid]
            if robotConfig then
                roleCloneData.attrs:Reset()
                for _, attr in ipairs(robotConfig.attrs) do
                    if attr.type ~= Attribute.atMvSpeed then
                        roleCloneData.attrs:Set(attr.type, attr.value * attrPer)
                    else
                        roleCloneData.attrs:Set(attr.type, attr.value)
                    end
                end
            end
        end
    end
    
    local ins = instancesystem.getInsByHdl(fbHandle)
    local sceneHandle = ins.scene_list[1]
    return LActor.createActorCloneWithData(robotid, sceneHandle, pos.x, pos.y, actorData, roleCloneData, roleSuperData)
end

function setActorInviteIn(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.campbattle) then return end
    local info = getActorCampInfo(actor)
    if not info then return end
    info.isShow = 1
    info.name = LActor.getName(actor)
end

function setActorInviteOut(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.campbattle) then return end
    local info = getActorCampInfo(actor)
    if not info then return end
    info.isShow = 0
end

function updateActorCBInfo(actor)
    s2cCampBattleInfo(actor)
end

function updateCBCampScore()
    SCUpdateCampScore()
end

----------------------------------------------------------------------------------
--协议处理

--89-15 下发个人信息
function s2cCampBattleInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    local info = getActorCampInfo(actor)
    local campScore = getCampScore()
    local camp = CAMP_NONE
    if info then
        camp = info.camp
    end
    local seasonStartTime, seasonEndTime, dayStartTime, dayEndTime = campbattlesystem.getCBOpenTime()
    local seasonOpen, dayOpen = campbattlesystem.getCBOpenStatus()
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_CampBattleInfo)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, seasonOpen and 1 or 0)
    LDataPack.writeInt(pack, seasonStartTime)--赛季开始时间戳(秒)
    LDataPack.writeInt(pack, seasonEndTime)--赛季结束时间戳(秒)
    LDataPack.writeChar(pack, dayOpen and 1 or 0)
    LDataPack.writeInt(pack, dayStartTime)--每日比赛开始时间戳(秒)
    LDataPack.writeInt(pack, dayEndTime)--每日比赛结束时间戳(秒)
    LDataPack.writeChar(pack, var.rewardCount)
    LDataPack.writeChar(pack, var.joinCount)
    LDataPack.writeInt(pack, campScore[CAMP_GOD])
    LDataPack.writeInt(pack, campScore[CAMP_DEVIL])
    LDataPack.writeChar(pack, camp)
    LDataPack.writeInt(pack, var.rewardsBoxRecord)
    LDataPack.flush(pack)
end

--89-16 请求领奖-宝箱
local function c2sCBBoxReward(actor, packet)
    local index = LDataPack.readChar(packet)
    local config = CampBattleDailyRewardConfig[index]
    if not config then return end
    if not actoritem.checkEquipBagSpaceJob(actor, config.rewards) then return end
    local var = getActorVar(actor)
    if not var then return end
    if var.rewardCount < config.count then return end
    if System.bitOPMask(var.rewardsBoxRecord, index) then return end
    
    var.rewardsBoxRecord = System.bitOpSetMask(var.rewardsBoxRecord, index, true)
    actoritem.addItems(actor, config.rewards, "campbattle box rewards")
    
    --89-16 返回领奖-宝箱
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_CBBoxReward)
    if pack == nil then return end
    
    LDataPack.writeInt(pack, var.rewardsBoxRecord)
    LDataPack.flush(pack)
end

--89-18 请求领奖-积分达标
local function c2sCBScoreReward(actor, packet)
    local index = LDataPack.readChar(packet)
    local config = CampBattleScoreRewardConfig[index]
    if not config then return end
    if not actoritem.checkEquipBagSpaceJob(actor, config.rewards) then return end
    local info = getActorCampInfo(actor)
    local var = getActorVar(actor)
    if not info then return end
    if info.camp == CAMP_NONE then return end
    local campScore = getCampScore()
    if campScore[info.camp] < config.score then return end
    if var.scoreRewards[index] == 1 then return end
    
    var.scoreRewards[index] = 1
    actoritem.addItems(actor, config.rewards, "campbattle score rewards")
    s2cCBScoreReward(actor)
end

--89-18 返回领奖-积分达标
function s2cCBScoreReward(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_CBScoreReward)
    if pack == nil then return end
    LDataPack.writeChar(pack, #CampBattleScoreRewardConfig)
    for index in ipairs(CampBattleScoreRewardConfig) do
        LDataPack.writeChar(pack, index)
        LDataPack.writeChar(pack, var.scoreRewards[index] or 0)
    end
    LDataPack.flush(pack)
end

--89-19 请求阵营积分
local function c2sCBReqCampScore(actor)
    s2cCBResCampScore(actor)
end

--89-19 返回阵营积分
function s2cCBResCampScore(actor)
    local campScore = getCampScore()
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_CBResCampScore)
    if pack == nil then return end
    LDataPack.writeInt(pack, campScore[CAMP_GOD])
    LDataPack.writeInt(pack, campScore[CAMP_DEVIL])
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--跨服协议
--同步跨服玩家数据给本服
function SCSendActorInfo(actorid, serverid)--actorid = 0表示全部同步
    if not System.isBattleSrv() then return end
    local campList = getCampList()
    if actorid == 0 then
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCCampBattle)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_UpdateActorInfo)
        local pos1 = LDataPack.getPosition(pack)
        local count = 0
        LDataPack.writeShort(pack, count)
        for _, info in pairs(campList) do
            LDataPack.writeInt(pack, info.actorid)
            LDataPack.writeInt(pack, info.serverid)
            LDataPack.writeByte(pack, info.job)
            LDataPack.writeDouble(pack, info.power)
            LDataPack.writeString(pack, info.name)
            LDataPack.writeInt(pack, info.score)
            LDataPack.writeChar(pack, info.camp)
            count = count + 1
        end
        local pos2 = LDataPack.getPosition(pack)
        LDataPack.setPosition(pack, pos1)
        LDataPack.writeShort(pack, count)
        LDataPack.setPosition(pack, pos2)
        System.sendPacketToAllGameClient(pack, serverid or 0)
    else
        local info = campList[actorid]
        if not info then return end
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCCampBattle)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_UpdateActorInfo)
        LDataPack.writeShort(pack, 1)
        LDataPack.writeInt(pack, info.actorid)
        LDataPack.writeInt(pack, info.serverid)
        LDataPack.writeByte(pack, info.job)
        LDataPack.writeDouble(pack, info.power)
        LDataPack.writeString(pack, info.name)
        LDataPack.writeInt(pack, info.score)
        LDataPack.writeChar(pack, info.camp)
        System.sendPacketToAllGameClient(pack, serverid or 0)
    end
end

--普通服收到跨服的玩家数据
local function onSCUpdateActorInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local var = getSystemVar()
    local campList = var.memberList
    local count = LDataPack.readShort(dp)
    if count ~= 1 then
        var.memberList = {}
        campList = var.memberList
    end
    if count == 1 then
        local actorid = LDataPack.readInt(dp)
        campList[actorid] = {
            actorid = actorid,
            serverid = LDataPack.readInt(dp),
            job = LDataPack.readByte(dp),
            power = LDataPack.readDouble(dp),
            name = LDataPack.readString(dp),
            score = LDataPack.readInt(dp),
            isShow = 0,
            camp = LDataPack.readChar(dp),
        }
        local actor = LActor.getActorById(actorid)
        if actor then
            s2cCampBattleInfo(actor)
        end
    else
        for i = 1, count do
            local actorid = LDataPack.readInt(dp)
            campList[actorid] = {
                actorid = actorid,
                serverid = LDataPack.readInt(dp),
                job = LDataPack.readByte(dp),
                power = LDataPack.readDouble(dp),
                name = LDataPack.readString(dp),
                score = LDataPack.readInt(dp),
                isShow = 0,
                camp = LDataPack.readChar(dp),
            }
        end
    end
    System.saveStaticCampBattle()
end

--普通服请求给玩家划分阵营
function SCSendInitActorCampInfo(actorid, info)
    if System.isCrossWarSrv() then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCCampBattle)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_InitActorCampInfo)
    LDataPack.writeInt(pack, actorid)
    
    LDataPack.writeByte(pack, info.job)
    LDataPack.writeDouble(pack, info.power)
    LDataPack.writeString(pack, info.name)
    System.sendPacketToAllGameClient(pack, 0)
end

--跨服收到请求给玩家划分阵营
local function onSCInitActorCampInfo(sId, sType, dp)
    if not System.isBattleSrv() then return end
    
    local actorid = LDataPack.readInt(dp)
    local job = LDataPack.readByte(dp)
    local power = LDataPack.readDouble(dp)
    local name = LDataPack.readString(dp)
    
    local sysVar = getSystemVar()
    local campList = getCampList()
    local info = campList[actorid]
    if info then return end
    
    --local basic_data = LActor.getActorData(actor)
    campList[actorid] = {
        actorid = actorid,
        serverid = sId,
        job = job,
        power = power,
        name = name,
        score = CampBattleCommonConfig.initScore, --个人积分
        isShow = 0,
        camp = CAMP_NONE,
    }
    
    local actorCampList = campbattlesystem.getActorCampList()
    local camp = CAMP_NONE
    if actorCampList[actorid] then
        camp = actorCampList[actorid]
    else
        camp = sysVar.joinCamp
        sysVar.joinCamp = sysVar.joinCamp % CAMP_COUNT + 1
    end
    campList[actorid].camp = camp
    SCSendActorInfo(actorid)
    System.saveStaticCampBattle()
end

--同步阵营积分数据给普通服
function SCUpdateCampScore()
    if not System.isBattleSrv() then return end
    local campScore = getCampScore()
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCCampBattle)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_UpdateCampScore)
    LDataPack.writeInt(pack, campScore[CAMP_GOD])
    LDataPack.writeInt(pack, campScore[CAMP_DEVIL])
    System.sendPacketToAllGameClient(pack, 0)
end

--普通服收到跨服的阵营积分数据
local function onSCUpdateCampScore(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local campScore = getCampScore()
    
    campScore[CAMP_GOD] = LDataPack.readInt(dp)
    campScore[CAMP_DEVIL] = LDataPack.readInt(dp)
end

--当连上跨服时,同步本服玩家数据给跨服
local function OnCBConnected(serverId, serverType)
    if not System.isBattleSrv() then return end
    SCSendActorInfo(0, serverId)
    updateCBCampScore()
end

----------------------------------------------------------------------------------
--事件处理

local function onSystemOpen(actor)
    s2cCampBattleInfo(actor)
    s2cCBScoreReward(actor)
    
    if not System.isBattleSrv() then return end
    if LActor.getFubenId(actor) == CampBattleCommonConfig.matchFbId then
        setActorInviteIn(actor)
    end
end

local function onLogin(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.campbattle) then return end
    s2cCampBattleInfo(actor)
    s2cCBScoreReward(actor)
end

--登出后,将玩家从阵营列表中屏蔽,不再出现在邀请列表中
local function onActorLogout(actor)
    setActorInviteOut(actor)
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    if System.isCommSrv() then
        sendCBBoxReward(actor)
    end
    var.rewardCount = 0 --每日奖励次数
    var.joinCount = 0 --每日助战次数
    var.rewardCount = 0 --每日挑战次数
    var.rewardsBoxRecord = 0 --领奖状态
    local now = System.getNowTime()
    if not System.isSameWeek(var.lastWeekTime, now) then
        var.lastWeekTime = now
        var.scoreRewards = {}
    end
    if not login then
        s2cCampBattleInfo(actor)
        s2cCBScoreReward(actor)
    end
end

----------------------------------------------------------------------------------
--初始化
local function init()
    --if System.isCommSrv() then return end
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
    csbase.RegConnected(OnCBConnected)
    csmsgdispatcher.Reg(CrossSrvCmd.SCCampBattle, CrossSrvSubCmd.SCCBCmd_UpdateActorInfo, onSCUpdateActorInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCCampBattle, CrossSrvSubCmd.SCCBCmd_InitActorCampInfo, onSCInitActorCampInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCCampBattle, CrossSrvSubCmd.SCCBCmd_UpdateCampScore, onSCUpdateCampScore)
    
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_CBBoxReward, c2sCBBoxReward)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_CBScoreReward, c2sCBScoreReward)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_CBReqCampScore, c2sCBReqCampScore)
    
    actorevent.reg(aeNewDayArrive, onNewDay)
    actorevent.reg(aeUserLogin, onLogin)
    
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.campbattle, onSystemOpen)
    
    if not System.isBattleSrv() then return end
    actorevent.reg(aeUserLogout, onActorLogout)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.saveCampBattleVar = function (actor, args)
    System.saveStaticCampBattle()
    if System.isCommSrv() then
        SCTransferGM("saveCampBattleVar")
    end
end

gmCmdHandlers.clearCampBattleVar = function (actor, args)
    local var = System.getStaticCampBattleVar()
    var.campbattle = nil
    if System.isCommSrv() then
        SCTransferGM("clearCampBattleVar")
    end
end

gmCmdHandlers.clearCBActorVar = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.campbattle = nil
    s2cCampBattleInfo(actor)
end

gmCmdHandlers.campList = function (actor, args)
    local var = getSystemVar()
    print("*******allCampList*******")
    utils.printTable(var)
    print("**********************")
end

gmCmdHandlers.matchList = function (actor, args)
    local var = getSystemVar()
    print("*******GodList*******")
    utils.printTable(MATCH_POOL_GOD)
    print("**********************")
    print("*******DevilList*******")
    utils.printTable(MATCH_POOL_DEVIL)
    print("**********************")
end

gmCmdHandlers.setCBCamp = function (actor, args)
    local camp = tonumber(args[1]) or 0
    if camp ~= CAMP_NONE and
        camp ~= CAMP_GOD and
        camp ~= CAMP_DEVIL then
        return
    end
    local info = getActorCampInfo(actor)
    if not info then return end
    info.camp = camp
    s2cCampBattleInfo(actor)
    if System.isCommSrv() then
        SCTransferGM("setCBCamp", args)
    end
end

gmCmdHandlers.addCBScore = function (actor, args)
    if System.isCommSrv() then
        SCTransferGM("addCBScore", args)
        return
    end
    local camp = getActorCamp(actor)
    if camp == CAMP_NONE then return end
    local count = tonumber(args[1]) or 0
    local campScore = getCampScore()
    campScore[camp] = campScore[camp] + count
    SCUpdateCampScore()
    s2cCampBattleInfo(actor)
end

gmCmdHandlers.addCBActorScore = function (actor, args)
    if System.isCommSrv() then
        SCTransferGM("addCBActorScore", args)
        return
    end
    local camp = getActorCamp(actor)
    if camp == CAMP_NONE then return end
    local count = tonumber(args[1]) or 0
    local info = getActorCampInfo(actor)
    local campScore = getCampScore()
    info.score = info.score + count
    campScore[camp] = campScore[camp] + count
    SCUpdateCampScore()
    s2cCampBattleInfo(actor)
end

gmCmdHandlers.addCBBox = function (actor, args)
    local count = tonumber(args[1]) or 1
    local var = getActorVar(actor)
    var.rewardCount = var.rewardCount + count
    s2cCampBattleInfo(actor)
end

gmCmdHandlers.getBoxRewards = function (actor, args)
    local index = tonumber(args[1]) or 1
    local packet = LDataPack.allocPacket()
    LDataPack.writeChar(packet, index)
    LDataPack.setPosition(packet, 0)
    c2sCBBoxReward(actor, packet)
end

gmCmdHandlers.getScoreRewards = function (actor, args)
    local index = tonumber(args[1]) or 1
    local packet = LDataPack.allocPacket()
    LDataPack.writeChar(packet, index)
    LDataPack.setPosition(packet, 0)
    c2sCBScoreReward(actor, packet)
end
