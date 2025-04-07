--天选之战(副本逻辑)
module("tianxuanfuben", package.seeall)

--
-- ins.data.teamList = {
--     [txTeamType.home] = {
--         teamId = txTeamType.home,
--         memberList = {},
--         point = 0,
--         mvp = {actorid = 0, score = 0},
--         result = 0,
--         notices = {},
--     },
--     [txTeamType.away] = {
--         teamId = txTeamType.away,
--         memberList = {},
--         point = 0,
--         mvp = {actorid = 0, score = 0},
--         result = 0,
--         notices = {},
--     },
-- }

-- teamList.memberList = {
--     {
--         idx = idx,
--         teamId = homeTeamId,
--         rivalId = awayTeamId,
--         actorid = actorid,
--         name = LActor.getName(actor),
--         job = LActor.getJob(actor),
--         score = var.score,
--         isLeave = var.isLeave,
--     },
-- }

-- ins.data.actorList[actorid] = {
--     teamId = 0,
--     actorid = 0,
--     killCount = 0,
--     gatherCount = 0,
--     dieCount = 0,
--     addScore = 0,
--     addPoint = 0,
--     serialDie = 0,
-- }

local fbResult = {
    fbDraw = 0,
    fbWin = 1,
    fbLose = 2,
}

--更新属性
local function updateAttr(actor, ins)
    local actorList = ins and ins.data.actorList
    if not actorList then return end
    local actorid = LActor.getActorId(actor)
    local aInfo = actorList[actorid]
    if not aInfo then return end
    
    local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Fuben)
    attrs:Reset()
    
    local serialDie = math.min(aInfo.serialDie, #TianXuanDieConfig)
    if serialDie > 0 then
        local attrsConf = TianXuanDieConfig[serialDie]
        if not attrsConf then return end
        
        for _, attr in ipairs(attrsConf.attrs) do
            attrs:Set(attr.type, attr.value)
        end
    end
    LActor.reCalcAttr(actor)
end

function checkTXFubenResult(ins)
    local teamList = ins and ins.data.teamList
    if not teamList then return end
    local homeTeam = teamList[tianxuan.txTeamType.home]
    local awayTeam = teamList[tianxuan.txTeamType.away]
    
    local flag = false
    if homeTeam.point >= TianXuanCommonConfig.winPoint then
        homeTeam.result = fbResult.fbWin
        awayTeam.result = fbResult.fbLose
        flag = true
    elseif awayTeam.point >= TianXuanCommonConfig.winPoint then
        homeTeam.result = fbResult.fbLose
        awayTeam.result = fbResult.fbWin
        flag = true
    elseif ins.is_end then
        if homeTeam.point > awayTeam.point then
            homeTeam.result = fbResult.fbWin
            awayTeam.result = fbResult.fbLose
        elseif awayTeam.point > homeTeam.point then
            homeTeam.result = fbResult.fbLose
            awayTeam.result = fbResult.fbWin
        end
        flag = true
    end
    if flag then
        onTXTeamResult(ins)
        ins:win()
    end
end

function boardTXNoticeByTeam(team, id, ...)
    for _, info in ipairs(team.memberList) do
        local actor = LActor.getActorById(info.actorid)
        if actor and LActor.getFubenId(actor) == TianXuanCommonConfig.fightFbId then
            noticesystem.s2cCrossNotice(actor, id, ...)
        end
    end
end

----------------------------------------------------------------------------------
--协议处理

function boardTXFubenResult(teamList, actorList)
    for _, team in ipairs(teamList) do
        local fubenConfig = TianXuanFubenConfig[team.result]
        local rival = teamList[team.rivalId]
        local rewards = fubenConfig.rewards
        local result = team.result
        local mvp = team.mvp
        for _, info in ipairs(team.memberList) do
            local actor = LActor.getActorById(info.actorid)
            if actor and LActor.getFubenId(actor) == TianXuanCommonConfig.fightFbId then
                s2cTXFubenResult(actor, actorList, result, team, rival, rewards)
            end
        end
    end
end

--92-33 副本信息
function s2cTXFubenInfo(actor, ins)
    if not ins then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sTianxuanCmd_FubenInfo)
    if pack == nil then return end
    
    local actorid = LActor.getActorId(actor)
    local aInfo = ins.data.actorList[actorid]
    local myTeam = ins.data.teamList[aInfo.teamId]
    local rivalTeam = ins.data.teamList[myTeam.rivalId]
    
    LDataPack.writeInt(pack, aInfo.killCount)
    LDataPack.writeInt(pack, aInfo.gatherCount)
    LDataPack.writeInt(pack, aInfo.dieCount)
    LDataPack.writeInt(pack, aInfo.addScore)
    LDataPack.writeInt(pack, aInfo.addPoint)
    LDataPack.writeInt(pack, aInfo.serialDie)
    LDataPack.writeInt(pack, myTeam.point)
    LDataPack.writeInt(pack, rivalTeam.point)
    LDataPack.flush(pack)
end

--92-35 战斗结算
function s2cTXFubenResult(actor, actorList, ret, myTeam, rivalTeam, rewards)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sTianxuanCmd_Result)
    if pack == nil then return end
    LDataPack.writeChar(pack, ret)
    
    LDataPack.writeChar(pack, myTeam.teamId)
    LDataPack.writeInt(pack, myTeam.point)
    LDataPack.writeInt(pack, myTeam.mvp.actorid)
    LDataPack.writeChar(pack, #myTeam.memberList)
    for _, info in ipairs(myTeam.memberList) do
        local aInfo = actorList[info.actorid]
        LDataPack.writeInt(pack, info.actorid)
        LDataPack.writeString(pack, info.name)
        LDataPack.writeChar(pack, info.job)
        LDataPack.writeInt(pack, info.score)
        LDataPack.writeInt(pack, aInfo.addScore)
        LDataPack.writeInt(pack, aInfo.baseScore)
        LDataPack.writeInt(pack, aInfo.MVPScore)
        LDataPack.writeInt(pack, aInfo.exScore)
        LDataPack.writeInt(pack, aInfo.killCount)
        LDataPack.writeInt(pack, aInfo.gatherCount)
    end
    
    LDataPack.writeChar(pack, rivalTeam.teamId)
    LDataPack.writeInt(pack, rivalTeam.point)
    LDataPack.writeInt(pack, rivalTeam.mvp.actorid)
    LDataPack.writeChar(pack, #rivalTeam.memberList)
    for _, info in ipairs(rivalTeam.memberList) do
        local aInfo = actorList[info.actorid]
        LDataPack.writeInt(pack, info.actorid)
        LDataPack.writeString(pack, info.name)
        LDataPack.writeChar(pack, info.job)
        LDataPack.writeInt(pack, info.score)
        LDataPack.writeInt(pack, aInfo.addScore)
        LDataPack.writeInt(pack, aInfo.baseScore)
        LDataPack.writeInt(pack, aInfo.MVPScore)
        LDataPack.writeInt(pack, aInfo.exScore)
        LDataPack.writeInt(pack, aInfo.killCount)
        LDataPack.writeInt(pack, aInfo.gatherCount)
    end
    
    LDataPack.writeChar(pack, #rewards)
    for _, v in ipairs(rewards) do
        LDataPack.writeInt(pack, v.id)
        LDataPack.writeInt(pack, v.count)
    end
    
    LDataPack.flush(pack)
end

--92-37 战场信息
function s2cTXActorInfo(actor, ins)
    if not ins then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sTianxuanCmd_ActorInfo)
    if pack == nil then return end
    
    local actorid = LActor.getActorId(actor)
    local aInfo = ins.data.actorList[actorid]
    local myTeam = ins.data.teamList[aInfo.teamId]
    local rivalTeam = ins.data.teamList[myTeam.rivalId]
    
    LDataPack.writeChar(pack, myTeam.teamId)
    LDataPack.writeChar(pack, #myTeam.memberList)
    for _, aInfo in ipairs(myTeam.memberList) do
        local actor = LActor.getActorById(aInfo.actorid)
        local masterHandle = 0
        if actor then
            masterHandle = LActor.getHandle(actor)
        end
        LDataPack.writeDouble(pack, masterHandle)
        LDataPack.writeString(pack, aInfo.name)
        LDataPack.writeChar(pack, aInfo.job)
        LDataPack.writeChar(pack, aInfo.isLeave)
    end
    
    LDataPack.writeChar(pack, rivalTeam.teamId)
    LDataPack.writeChar(pack, #rivalTeam.memberList)
    for _, aInfo in ipairs(rivalTeam.memberList) do
        local actor = LActor.getActorById(aInfo.actorid)
        local masterHandle = 0
        if actor then
            masterHandle = LActor.getHandle(actor)
        end
        LDataPack.writeDouble(pack, masterHandle)
        LDataPack.writeString(pack, aInfo.name)
        LDataPack.writeChar(pack, aInfo.job)
        LDataPack.writeChar(pack, aInfo.isLeave)
    end
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理

--采集怪复活
function refreshTXMonster(_, hfuben, monsterId)
    local ins = instancesystem.getInsByHdl(hfuben)
    if not ins then return end
    if ins.is_end then return end
    
    local monsterConfig = TianXuanMonsterConfig[monsterId]
    if not monsterConfig then return end
    
    local x = (monsterConfig.position.x - 64 / 2) / 64
    local y = (monsterConfig.position.y - 64 / 2) / 64
    local monster = Fuben.createMonster(ins.scene_list[1], monsterId, x, y)
    LActor.setEntityScenePoint(monster, monsterConfig.position.x, monsterConfig.position.y)
end

function onTXAddPoint(teamList)
    local homeTeam = teamList[tianxuan.txTeamType.home]
    local awayTeam = teamList[tianxuan.txTeamType.away]
    
    local precent = 0
    local leadTeam
    local behindTeam
    if homeTeam.point > awayTeam.point then
        precent = math.floor(homeTeam.point / TianXuanCommonConfig.winPoint * 100)
        leadTeam = homeTeam
        behindTeam = awayTeam
    elseif homeTeam.point < awayTeam.point then
        precent = math.floor(awayTeam.point / TianXuanCommonConfig.winPoint * 100)
        leadTeam = awayTeam
        behindTeam = homeTeam
    end
    
    local idx = 0
    for i, conf in ipairs(TianXuanNoticeConfig) do
        if conf.precent <= precent then
            idx = i
        else
            break
        end
    end
    
    if idx > 0 and not leadTeam.notices[idx] then
        leadTeam.notices[idx] = 1
        behindTeam.notices[idx] = 1
        boardTXNoticeByTeam(leadTeam, TianXuanNoticeConfig[idx].leadNotice)
        boardTXNoticeByTeam(behindTeam, TianXuanNoticeConfig[idx].behindNotice)
    end
end

--处理击杀事件
function onTXActorKill(ins, actor, killname)
    local actorList = ins and ins.data.actorList
    local teamList = ins and ins.data.teamList
    if not actorList or not teamList then return end
    
    local actorid = LActor.getActorId(actor)
    local aInfo = actorList[actorid]
    if not aInfo then return end
    
    local score = TianXuanCommonConfig.killScore
    local point = TianXuanCommonConfig.killPoint
    aInfo.killCount = aInfo.killCount + 1
    aInfo.addScore = aInfo.addScore + score
    aInfo.addPoint = aInfo.addPoint + point
    aInfo.serialDie = 0
    
    local myTeam = teamList[aInfo.teamId]
    local rivalTeam = teamList[myTeam.rivalId]
    if not myTeam then return end
    myTeam.point = myTeam.point + point
    
    local mvp = myTeam.mvp
    if aInfo.addScore > mvp.score then
        mvp.score = aInfo.addScore
        mvp.actorid = actorid
    end
    
    checkTXFubenResult(ins)
    updateAttr(actor, ins)
    if not myTeam.isFirstKill then
        myTeam.isFirstKill = 1
        rivalTeam.isFirstKill = 1
        local actorName = LActor.getName(actor)
        boardTXNoticeByTeam(myTeam, TianXuanCommonConfig.firstKillNotice1, actorName, killname)
        boardTXNoticeByTeam(rivalTeam, TianXuanCommonConfig.firstKillNotice2, actorName, killname)
    end
    onTXAddPoint(teamList)
    LActor.sendTipmsg(actor, string.format(ScriptTips.tianxuan002, point))
end

--处理死亡事件
function onTXActorDie(ins, actor)
    local actorList = ins and ins.data.actorList
    if not actorList then return end
    
    local actorid = LActor.getActorId(actor)
    local aInfo = actorList[actorid]
    if not aInfo then return end
    
    aInfo.serialDie = aInfo.serialDie + 1
    aInfo.dieCount = aInfo.dieCount + 1
    updateAttr(actor, ins)
end

--处理采集事件
function onTXGather(ins, monster, actor)
    if ins.is_end then return end
    local monsterid = Fuben.getMonsterId(monster)
    local monsterConfig = TianXuanMonsterConfig[monsterid]
    if not monsterConfig then return end
    
    local actorList = ins and ins.data.actorList
    local teamList = ins and ins.data.teamList
    if not actorList or not teamList then return end
    
    local actorid = LActor.getActorId(actor)
    local aInfo = actorList[actorid]
    if not aInfo then return end
    
    local score = monsterConfig.score
    local point = monsterConfig.point
    aInfo.gatherCount = aInfo.gatherCount + 1
    aInfo.addScore = aInfo.addScore + score
    aInfo.addPoint = aInfo.addPoint + point
    
    local myTeam = teamList[aInfo.teamId]
    local rivalTeam = teamList[myTeam.rivalId]
    if not myTeam then return end
    myTeam.point = myTeam.point + point
    
    local mvp = myTeam.mvp
    if aInfo.addScore > mvp.score then
        mvp.score = aInfo.addScore
        mvp.actorid = actorid
    end
    
    checkTXFubenResult(ins)
    
    if not myTeam.isFirstGather then
        myTeam.isFirstGather = 1
        rivalTeam.isFirstGather = 1
        local actorName = LActor.getName(actor)
        boardTXNoticeByTeam(myTeam, TianXuanCommonConfig.firstGatherNotice1, actorName)
        boardTXNoticeByTeam(rivalTeam, TianXuanCommonConfig.firstGatherNotice2, actorName)
    end
    onTXAddPoint(teamList)
    LActor.sendTipmsg(actor, string.format(ScriptTips.tianxuan001, point))
end

--队伍结算事件
function onTXTeamResult(ins)
    local actorList = ins and ins.data.actorList
    local teamList = ins and ins.data.teamList
    if not actorList or not teamList then return end
    
    for _, team in ipairs(teamList) do
        local fubenConfig = TianXuanFubenConfig[team.result]
        local rival = teamList[team.rivalId]
        local rewards = fubenConfig.rewards
        local result = team.result
        local mvp = team.mvp
        for _, info in ipairs(team.memberList) do
            local actorid = info.actorid
            local aInfo = actorList[actorid]
            
            aInfo.baseScore = fubenConfig.baseScore
            aInfo.exScore = 0
            if actorid == mvp.actorid then
                aInfo.MVPScore = fubenConfig.MVPScore
            end
            local allScore = aInfo.addScore + aInfo.baseScore + aInfo.MVPScore + aInfo.exScore
            tianxuan.addTXActorScore(actorid, allScore)
            
            local actor = LActor.getActorById(actorid)
            if actor and LActor.getFubenId(actor) == TianXuanCommonConfig.fightFbId then
                actoritem.addItems(actor, rewards, "tianxuan fight rewards")
                s2cTXFubenInfo(actor, ins)
            else
                local head = fubenConfig.mailTitle
                local context = fubenConfig.mailContent
                local mailData = {
                    head = head,
                    context = string.format(context, allScore),
                    tAwardList = rewards,
                }
                mailsystem.sendMailById(actorid, mailData, info.serverid)
            end
            tianxuanrank.addTXRankScore(actorid, info.serverid, info.name, allScore)
            print("onTXTeamResult actorid =", actorid, " result =", result, "oldScore =", info.score, "addScore =", aInfo.addScore, "baseScore =", aInfo.baseScore, "exScore =", aInfo.exScore, "MVPScore =", aInfo.MVPScore)
        end
    end
    boardTXFubenResult(teamList, actorList)
end

--以下为副本回调事件
--定时检测
local function onTimeCheck(ins)
    local actors = ins:getActorList()
    for _, actor in ipairs(actors) do
        s2cTXFubenInfo(actor, ins)
    end
    --人数不足1人则结束副本
    if #actors < 1 then
        ins:lose()
    end
end

--副本初始化事件
local function onInitFuben(ins)
    for monsterId, conf in pairs(TianXuanMonsterConfig) do
        local x = (conf.position.x - 64 / 2) / 64
        local y = (conf.position.y - 64 / 2) / 64
        local monster = Fuben.createMonster(ins.scene_list[1], monsterId, x, y)
        LActor.setEntityScenePoint(monster, conf.position.x, conf.position.y)
    end
end

local function onEnterBefore(ins, actor)
    if not actor then return end
    local monIdList = {}
    for id in pairs(TianXuanMonsterConfig) do
        table.insert(monIdList, id)
    end
    slim.s2cMonsterConfig(actor, monIdList)
    s2cTXActorInfo(actor, ins)
end

local function onEnterFb(ins, actor)
    for _, buffId in ipairs(TianXuanCommonConfig.addEffects) do
        LActor.addSkillEffect(actor, buffId)
    end
    instancesystem.s2cFightCountDown(actor, 3)
    s2cTXFubenInfo(actor, ins)
end

local function onExitFb(ins, actor)
    -- local actorList = ins and ins.data.actorList
    -- if not actorList then return end
    
    -- local actorid = LActor.getActorId(actor)
    -- local aInfo = actorList[actorid]
    -- if not aInfo then return end
    -- aInfo.serialDie = 0
    -- updateAttr(actor, ins)
    if ins.actor_list_count <= 0 then
        ins:lose()
    end
end

local function onOffline(ins, actor)
    LActor.exitFuben(actor)
end

local function onActorDie(ins, actor, killHdl)
    if ins.is_end then return end
    local et = LActor.getEntity(killHdl)
    local kill_actor = LActor.getActor(et)
    if kill_actor then
        onTXActorKill(ins, kill_actor, LActor.getName(actor))
    end
    onTXActorDie(ins, actor)
end

local function onGatherMonsterUpdate(ins, monster, actor)
    local status, gather_time, wait_time = LActor.getGatherMonsterInfo(monster)
    if status == GatherStatusType_Finish then
        local monsterid = Fuben.getMonsterId(monster)
        local monsterConfig = TianXuanMonsterConfig[monsterid]
        if not monsterConfig then return end
        LActor.postScriptEventLite(nil, monsterConfig.refreshTime * 1000, refreshTXMonster, ins.handle, monsterid)
        if actor then
            onTXGather(ins, monster, actor)
        end
    end
end

local function onLose(ins)
    checkTXFubenResult(ins)
end

----------------------------------------------------------------------------------
--初始化
function init()
    --if System.isCommSrv() then return end
    --if System.isBattleSrv() then return end
    if not System.isLianFuSrv() then return end
    
    local fbId = TianXuanCommonConfig.fightFbId
    
    insevent.regCustomFunc(fbId, onTimeCheck, "onTimeCheck")
    insevent.registerInstanceInit(fbId, onInitFuben)
    insevent.registerInstanceEnterBefore(fbId, onEnterBefore)
    insevent.registerInstanceEnter(fbId, onEnterFb)
    insevent.registerInstanceExit(fbId, onExitFb)
    insevent.registerInstanceOffline(fbId, onOffline)
    insevent.registerInstanceActorDie(fbId, onActorDie)
    insevent.registerInstanceGatherMonsterUpdate(fbId, onGatherMonsterUpdate)
    insevent.registerInstanceLose(fbId, onLose)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.txfbprint = function (actor, args)
    if not System.isLianFuSrv() then return end
    local fbhl = LActor.getFubenHandle(actor)
    local ins = instancesystem.getInsByHdl(fbhl)
    if ins then
        utils.printTable(ins.data)
    end
    return true
end

