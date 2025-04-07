-- 神魔圣战副本相关(阵营战)
module("campbattlefuben", package.seeall)

local TEAM_MEMBER_MAXCOUNT = CampBattleCommonConfig.maxMember --CampBattleCommonConfig.maxMember --组队人数
local TEAM_MAXCOUNT = 2 --CampBattleCommonConfig.maxMember --副本最大队伍数量

--[[
    ins.data.round = 0      当前回合
    ins.data.maxRound = 4   最大回合
 
    玩家列表
    ins.data.actorList = {
        actorid = 0,            玩家id
        round = 0,              出战位置
        teamid = 0,             所属队伍id
        camp = 0,               所属阵营
        isInvite = 0,           是否助战
        job = 0,                职业
        level = 0,              等级
        power = 0,              战斗力
        name = 0,               名字
        isRobot = 0,            是否机器人
        actorCloneHandle = 0,   机器人的抽象实体
    }
    回合信息
    ins.data.roundInfo = {
        {
            players = {
                [camp] = actorid    所属阵营 = 玩家id
            },
            winCamp = 0             战斗结果 0-平局，1-神阵营胜利，2-魔阵营胜利     
            },
            actorHandles = {
                [camp] = 0          所属阵营 = 抽象实体handle
            }
        }
    }
    队伍信息
    ins.data.teamInfo = {
        round = 0,          队伍已经到了第几轮,用于判断回合是否一致
        winPoint = 0,       队伍获得的胜点
        result = 0,          队伍是否获得最终的胜利
        ravilid = teamId,   对手的队伍id
        camp = 0            队伍所属阵营
    }
    事件
    ins.data.event = {
        [round] = {
            status = 0,             回合状态 1-备战, 2-战斗, 3-结束
            readyTime = 0,          备战结束时间戳
            onReadyTime = false,    备战事件触发标记
            keepTime = 0,           战斗结束时间戳
            onKeepTime = false,     战斗事件触发标记
        }
    }
 
    战斗逻辑:
    1.onRoundCheck 检测各个阶段触发事件
    2.roundFight 开始战斗
    3-1.如果双方均不在场景内则触发 roundResultDraw
    3-2.如果有退出、离线、死亡则触发 roundResultByLoser
    3-3.如果超时则触发 roundTimeOver
    4.循环操作3,并设置下一次事件 setNextEvent
    5.当回合超过最大回合数后，触发 fightFinish
    6.进入结算 onTeamResult
]]
local fbResult = {
    fbDraw = 0,
    fbLose = 1,
    fbWin = 2,
}

local roundStatus = {
    rReady = 1,
    rFight = 2,
    rFinish = 3,
}

--设置实体出战或备战位置
local function setActorPos(actor, round, idx, isFight, isClone)
    if not actor then return end
    local conf = CampBattleFubenConfig[round]
    if not conf then return end
    local rolePos
    local yongbingPos
    local cd = 0
    local effectIds
    if isFight then
        rolePos = conf.roleFightPos[idx]
        yongbingPos = conf.yongbingFightPos[idx]
        cd = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
        effectIds = CampBattleCommonConfig.fightEffectId
    else
        rolePos = conf.roleWaitPos[idx]
        yongbingPos = conf.yongbingWaitPos[idx]
        cd = 99999
        effectIds = CampBattleCommonConfig.waitEffectId
    end
    LActor.clearSuper(actor)
    local role = LActor.getRole(actor)
    
    local yongbing = LActor.getYongbing(actor)
    if yongbing then
        LActor.setEntityScenePos(yongbing, yongbingPos.x, yongbingPos.y)
    end
    
    for _, effectId in ipairs(effectIds) do
        LActor.addSkillEffect(actor, effectId)
    end
    LActor.setEntityScenePos(role, rolePos.x, rolePos.y)
    
    if isClone then
        LActor.clearAITarget(role)
        LActor.setSuperCloneChangeCD(actor, cd)
    else
        shenmosystem.setShenmoCd(actor, cd)
    end
end

--获取当前实体血量
local function getActorHp(info)
    if not info then return 0 end
    local hp = 0
    if info.isRobot == 0 then
        local actor = LActor.getActorById(info.actorid)
        if actor and LActor.getFubenId(actor) == CampBattleCommonConfig.fightFbId then
            local role = LActor.getRole(actor)
            hp = LActor.getHp(role)
        end
    else
        local actorCloneHandle = info.actorCloneHandle
        local actorClone = LActor.getEntity(actorCloneHandle)
        if actorClone then
            local role = LActor.getRole(actorClone)
            hp = LActor.getHp(role)
        end
    end
    return hp
end

--回合战斗开始
function roundFight(ins)
    local round = ins.data.round
    local actorList = ins.data.actorList
    local roundInfo = ins.data.roundInfo
    local leavelActorCount = 0
    local leavelActorId = -1
    for idx, actorid in ipairs(roundInfo[round].players) do
        local info = actorList[actorid]
        if info.isRobot == 0 then
            local actor = LActor.getActorById(actorid)
            if actor and info.isLeave ~= 1 then
                setActorPos(actor, round, idx, true)
            else
                leavelActorId = actorid
                leavelActorCount = leavelActorCount + 1
            end
        else
            local actorCloneHandle = info.actorCloneHandle
            local actorClone = LActor.getEntity(actorCloneHandle)
            if actorClone then
                setActorPos(actorClone, round, idx, true, true)
            end
        end
    end
    if leavelActorCount >= #roundInfo[round].players then
        roundResultDraw(ins, round)
    elseif leavelActorId ~= -1 then
        roundResultByLoser(ins, leavelActorId)
    end
end

--回合战斗结果为平局
function roundResultDraw(ins, round)
    local teamInfo = ins.data.teamInfo
    local roundInfo = ins.data.roundInfo
    for _, team in pairs(teamInfo) do
        team.round = team.round + 1
        team.result = fbResult.fbDraw
    end
    roundInfo[round].winInfo[round] = fbResult.fbDraw
    roundFinish(ins, round)
end

--回合战斗结果分出胜负
function roundResultByLoser(ins, actorid)
    local round = ins.data.round
    local actorList = ins.data.actorList
    local info = actorList[actorid]
    if not info then return end
    if info.round ~= round then return end
    
    local teamInfo = ins.data.teamInfo
    local config = CampBattleFubenConfig[round]
    local team = teamInfo[info.teamid]
    local ravil = teamInfo[team.ravilid]
    if team.round >= round or ravil.round >= round then return end --由于退出和离线会触发两次退出副本事件
    
    team.round = team.round + 1
    ravil.round = ravil.round + 1
    ravil.winPoint = ravil.winPoint + config.winPoint
    
    local roundInfo = ins.data.roundInfo
    roundInfo[round].winCamp = ravil.camp
    
    if team.winPoint > ravil.winPoint then
        team.result = fbResult.fbWin
        ravil.result = fbResult.fbLose
    elseif team.winPoint < ravil.winPoint then
        team.result = fbResult.fbLose
        ravil.result = fbResult.fbWin
    else
        team.result = fbResult.fbDraw
        ravil.result = fbResult.fbDraw
    end
    
    reSetActorPosition(ins, round)
    roundFinish(ins, round)
end

--回合战斗超时
function roundTimeOver(ins, round)
    if round > 0 then
        local roundInfo = ins.data.roundInfo
        local actorList = ins.data.actorList
        local teamInfo = ins.data.teamInfo
        
        local actorid = roundInfo[round].players[1]
        local ravilid = roundInfo[round].players[2]
        
        local hp = getActorHp(actorList[actorid])
        local ravilhp = getActorHp(actorList[ravilid])
        if hp >= ravilhp then
            roundResultByLoser(ins, ravilid)
        else
            roundResultByLoser(ins, actorid)
        end
    else
        BroadcastCBFubenInfo(ins)
        roundFinish(ins, round)
    end
end

--将出战实体设为备战位置
function reSetActorPosition(ins, round)
    local roundInfo = ins.data.roundInfo
    local actorList = ins.data.actorList
    for idx, actorid in ipairs(roundInfo[round].players) do
        local info = actorList[actorid]
        if info.isRobot == 0 then
            local actor = LActor.getActorById(actorid)
            if actor and info.isLeave ~= 1 then
                setActorPos(actor, round, idx, false)
            end
        else
            local actorCloneHandle = info.actorCloneHandle
            local actorClone = LActor.getEntity(actorCloneHandle)
            if actorClone then
                setActorPos(actorClone, round, idx, false, true)
            end
        end
    end
end

--设置下一场战斗事件
function setNextEvent(ins)
    local event = ins.data.event
    local round = ins.data.round
    local now = System.getNowTime()
    if round >= ins.data.maxRound then
        event[round].status = roundStatus.rFinish
        fightFinish(ins)
    else
        round = round + 1
        local config = CampBattleFubenConfig[round]
        event[round] = {
            status = roundStatus.rReady,
            readyTime = now + config.readyTime,
            onReadyTime = false,
            keepTime = now + config.readyTime + config.keepTime,
            onKeepTime = false,
        }
        ins.data.round = round
    end
end

--回合结束
function roundFinish(ins, round)
    setNextEvent(ins)
    if round < ins.data.maxRound then
        roundFight(ins)
    end
    BroadcastCBFubenRoundInfo(ins)
end

--对战结束
function fightFinish(ins)
    BroadcastCBFubenRoundInfo(ins)
    local actorList = ins.data.actorList
    local teamInfo = ins.data.teamInfo
    for teamId, info in pairs(teamInfo) do
        onTeamResult(ins, teamId, info.result)
    end
    ins:setEndTime(System.getNowTime() + 5)
end

----------------------------------------------------------------------------------
--协议处理

function BroadcastCBFubenInfo(ins)
    local actors = Fuben.getAllActor(ins.handle)
    if actors then
        for _, actor in ipairs(actors) do
            s2cSendCBFubenInfo(ins, actor)
        end
    end
end

--89-25 更新队伍信息
function s2cSendCBFubenInfo(ins, actor)
    if not actor or not ins then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_FubenInfo)
    if pack == nil then return end
    
    local teamInfo = ins.data.teamInfo
    local actorList = ins.data.actorList
    LDataPack.writeChar(pack, TEAM_MAXCOUNT)
    for _, tInfo in pairs(teamInfo) do
        local camp = tInfo.camp
        LDataPack.writeChar(pack, camp)
        LDataPack.writeChar(pack, TEAM_MEMBER_MAXCOUNT)
        for _, aInfo in pairs(actorList) do
            if aInfo.camp == camp then
                LDataPack.writeChar(pack, aInfo.round)
                LDataPack.writeInt(pack, aInfo.actorid)
                LDataPack.writeString(pack, aInfo.name)
                LDataPack.writeInt(pack, aInfo.level)
                LDataPack.writeDouble(pack, aInfo.power)
                LDataPack.writeChar(pack, aInfo.job)
                LDataPack.writeChar(pack, aInfo.isInvite)
                LDataPack.writeChar(pack, aInfo.isLeave)
            end
        end
    end
    LDataPack.flush(pack)
end
--89-26 请求发表情
local function c2sCBReqEmoji(actor, packet)
    local emojiId = LDataPack.readChar(packet)
    BroadcastCBFubenEmoji(actor, emojiId)
end

--89-26 广播发表情
function BroadcastCBFubenEmoji(actor, emojiId)
    local ins = instancesystem.getActorIns(actor)
    if not ins then return end
    if ins.id ~= CampBattleCommonConfig.fightFbId then return end
    
    local hfuben = ins.handle
    local actorList = ins.data.actorList
    local actorid = LActor.getActorId(actor)
    local info = actorList[actorid]
    
    local pack = LDataPack.allocPacket()
    if pack == nil then return end
    LDataPack.writeByte(pack, Protocol.CMD_CampBattle)
    LDataPack.writeByte(pack, Protocol.sCampBattleCmd_FubenBroadcastEmoji)
    LDataPack.writeChar(pack, info.camp)
    LDataPack.writeChar(pack, info.round)
    LDataPack.writeChar(pack, emojiId)
    Fuben.sendData(hfuben, pack)
end

--89-27 广播回合信息
function BroadcastCBFubenRoundInfo(ins)
    local round = ins.data.round
    local hfuben = ins.handle
    local event = ins.data.event
    local roundInfo = ins.data.roundInfo
    local teamInfo = ins.data.teamInfo
    local status = event[round].status
    local timestamp = 0
    if status == roundStatus.rReady then
        timestamp = event[round].readyTime
    elseif status == roundStatus.rFight then
        timestamp = event[round].keepTime
    end
    
    local pack = LDataPack.allocPacket()
    if pack == nil then return end
    LDataPack.writeByte(pack, Protocol.CMD_CampBattle)
    LDataPack.writeByte(pack, Protocol.sCampBattleCmd_FubenBroadRoundInfo)
    LDataPack.writeChar(pack, round)
    LDataPack.writeChar(pack, status)
    LDataPack.writeInt(pack, timestamp)
    LDataPack.writeDouble(pack, round == 0 and 0 or roundInfo[round].actorHandles[1])
    LDataPack.writeDouble(pack, round == 0 and 0 or roundInfo[round].actorHandles[2])
    
    LDataPack.writeChar(pack, #roundInfo)
    for _, rInfo in ipairs(roundInfo) do
        LDataPack.writeChar(pack, rInfo.winCamp or 0)
    end
    
    local godWinPoint = 0
    local devilWinPoint = 0
    for _, tInfo in pairs(teamInfo) do
        if campbattle.checkCampGod(tInfo.camp) then
            godWinPoint = tInfo.winPoint
        elseif campbattle.checkCampDevil(tInfo.camp) then
            devilWinPoint = tInfo.winPoint
        end
    end
    LDataPack.writeChar(pack, godWinPoint)
    LDataPack.writeChar(pack, devilWinPoint)
    Fuben.sendData(hfuben, pack)
end

--89-28 个人战斗结算
local function s2cCBFubenResult(actor, oldCampScore, oldScore, addScore, rewards, result, isInvite, isMultiple)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_FubenBroadResult)
    if pack == nil then return end
    LDataPack.writeChar(pack, result)
    LDataPack.writeInt(pack, oldCampScore)
    LDataPack.writeInt(pack, addScore)
    LDataPack.writeInt(pack, oldScore)
    LDataPack.writeInt(pack, addScore)
    LDataPack.writeChar(pack, isInvite)
    LDataPack.writeChar(pack, #rewards)
    for i, conf in ipairs(rewards) do
        LDataPack.writeInt(pack, conf.id)
        LDataPack.writeInt(pack, conf.count)
    end
    LDataPack.writeChar(pack, isMultiple and 1 or 0)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理

--队伍结算事件
function onTeamResult(ins, teamId, result)
    local actorList = ins.data.actorList
    for actorid, info in pairs(actorList) do
        if info.noReward ~= 1 and info.teamid == teamId and info.isRobot == 0 then
            onActorResult(actorid, result, info)
        end
    end
end

--玩家结算事件
function onActorResult(actorid, result, info)
    local oldCampScore, oldScore, addScore, addCamp, multiple, rewards = campbattle.addCBScore(actorid, result == fbResult.fbWin, info.isInvite)
    if addScore > 0 then
        campbattlerank.setCBRankScore(info.camp, actorid, info.serverid, info.name, oldScore + addScore, info.camp, info.power)
    end
    local actor = LActor.getActorById(actorid)
    if actor and info.isLeave ~= 1 then
        actoritem.addItems(actor, rewards, "campbattle fight rewards")
        s2cCBFubenResult(actor, oldCampScore, oldScore, addScore, rewards, result, info.isInvite, multiple > 1)
    else
        if addCamp > 0 then
            local head = result == fbResult.fbWin and CampBattleCommonConfig.winMailTitle or CampBattleCommonConfig.loseMailTitle
            local context = result == fbResult.fbWin and CampBattleCommonConfig.winMailContent or CampBattleCommonConfig.loseMailContent
            local mailData = {
                head = head,
                context = string.format(context, addScore, addScore),
                tAwardList = rewards,
            }
            mailsystem.sendMailById(actorid, mailData, info.serverid)
        end
    end
    campbattle.updateCBCampScore()
    campbattle.updateActorCBInfo(actor)
end

--初始化副本事件
local function onInitFuben(ins)
    ins.data.event = {}
    ins.data.round = -1
    ins.data.maxRound = #CampBattleFubenConfig
    ins.data.onStart = false
    
    local now = System.getNowTime()
    local endTime = 0
    for _, conf in pairs(CampBattleFubenConfig) do
        endTime = endTime + conf.readyTime + conf.keepTime
    end
    ins:setEndTime(System.getNowTime() + endTime + 5)
    setNextEvent(ins)
end

--副本回合战况检测
local function onRoundCheck(ins)
    local round = ins.data.round
    local event = ins.data.event
    local onStart = ins.data.onStart
    local now = System.getNowTime()
    local eventInfo = event[round]
    if eventInfo.status == roundStatus.rFinish then return end
    if eventInfo.onReadyTime == false and eventInfo.readyTime <= now then
        eventInfo.status = roundStatus.rFight
        eventInfo.onReadyTime = true
        BroadcastCBFubenRoundInfo(ins)
    elseif eventInfo.onKeepTime == false and eventInfo.keepTime <= now then
        eventInfo.status = roundStatus.rReady
        roundTimeOver(ins, round)
        eventInfo.onKeepTime = true
        BroadcastCBFubenRoundInfo(ins)
    end
end

--进入副本时,设置坐标为等待区
local function onEnterFb(ins, actor)
    local actorList = ins.data.actorList
    local actorid = LActor.getActorId(actor)
    local info = actorList[actorid]
    
    local rolePos = CampBattleFubenConfig[info.round].roleWaitPos[info.camp]
    local role = LActor.getRole(actor)
    LActor.setEntityScenePos(role, rolePos.x, rolePos.y)
    
    local yongbingPos = CampBattleFubenConfig[info.round].yongbingWaitPos[info.camp]
    local yongbing = LActor.getYongbing(actor)
    if yongbing then
        LActor.setEntityScenePos(yongbing, yongbingPos.x, yongbingPos.y)
    end
    for _, effectId in ipairs(CampBattleCommonConfig.waitEffectId) do
        LActor.addSkillEffect(actor, effectId)
    end
    LActor.setCamp(actor, info.camp)
    campbattle.setActorInviteOut(actor)
    s2cSendCBFubenInfo(ins, actor)
    BroadcastCBFubenRoundInfo(ins)
end

local function onExitFb(ins, actor)
    local actorid = LActor.getActorId(actor)
    local info = ins.data.actorList and ins.data.actorList[actorid]
    if not info then return end
    roundResultByLoser(ins, actorid)
    info.isLeave = 1
    BroadcastCBFubenInfo(ins)
    campbattle.setActorInviteIn(actor)
    LActor.clearSkillEffect(actor)
end

local function onOffline(ins, actor)
    LActor.exitFuben(actor)
end

local function onActorDie(ins, actor)
    local actorid = LActor.getActorId(actor)
    roundResultByLoser(ins, actorid)
end

local function onActorCloneDie(ins, killerHdl, actorClone)
    local cloneActorid = LActor.getActorIdClone(actorClone)
    roundResultByLoser(ins, cloneActorid)
end

----------------------------------------------------------------------------------
--初始化
function init()
    if not System.isBattleSrv() then return end
    --if System.isBattleSrv() then return end
    
    local fbId = CampBattleCommonConfig.fightFbId
    insevent.regCustomFunc(fbId, onRoundCheck, "onRoundCheck")
    insevent.registerInstanceInit(fbId, onInitFuben)
    insevent.registerInstanceEnter(fbId, onEnterFb)
    insevent.registerInstanceExit(fbId, onExitFb)
    insevent.registerInstanceOffline(fbId, onOffline)
    insevent.registerInstanceActorDie(fbId, onActorDie)
    insevent.regActorCloneDie(fbId, onActorCloneDie)
    
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_FubenReqEmoji, c2sCBReqEmoji)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
--local gmCmdHandlers = gmsystem.gmCmdHandlers
-- gmCmdHandlers.wxShare = function (actor, args)
--     local value = tonumber(args[1]) or 1
--     local actorid = tonumber(args[2]) or LActor.getActorId(actor)
--     wxCmdMsg(actorid, 1, 0, value)
-- end
