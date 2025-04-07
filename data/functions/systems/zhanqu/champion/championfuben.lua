-- 战队冠军赛
module("championfuben", package.seeall)

CHANGE_SCORE_TYPE = {
    default = 0,
    monsterDie = 1,
    actorKill = 2,
    gatherPlunder = 3,
}

--更新属性
local function updateAttr(actor, ins)
    local actorid = LActor.getActorId(actor)
    local info = ins.data.actorList[actorid]
    if not info then return end
    local team = ins.data.teamList[info.camp]
    if not team then return end

    local attrsConf = ChampionBuffConfig[team.buffLevel]
    if not attrsConf then return end

    local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Fuben)
    attrs:Reset()
    for _, attr in ipairs(attrsConf.attrs) do
        attrs:Set(attr.type, attr.value)
    end
    LActor.reCalcAttr(actor)
end

--战队快捷聊天
function CHQuickChat(ins, actorid, id)
    local info = ins.data.actorList[actorid]
    if not info then return end

    local camp = info.camp
    for actorid, aInfo in pairs(ins.data.actorList) do
        if aInfo.isLeave == 0 and aInfo.camp == camp then
            s2cCHQuickChat(LActor.getActorById(actorid), id)
        end
    end
end

--怪物刷新
function refreshCHMonster(_, hfuben, monsterId)
    local ins = instancesystem.getInsByHdl(hfuben)
    if not ins then return end
    if ins.is_end then return end

    local refreshConfig = ChampionMonsterConfig[monsterId]
    if not refreshConfig then return end
    Fuben.createMonster(ins.scene_list[1], monsterId, refreshConfig.position.x, refreshConfig.position.y)
    boardCHBossInfo(monsterId, ins)
end

--变更玩家火晶
function changeCHActorScore(actor, ins, value, changeType)
    local actorid = LActor.getActorId(actor)
    local info = ins.data.actorList[actorid]
    if not info then return end

    info.score = info.score + value
    if value > 0 then
        info.totalScore = info.totalScore + value
    end

    local team = ins.data.teamList[info.camp]
    if not team then return end

    local mvp = team.mvp
    if mvp.score < info.totalScore then
        mvp.actorId = actorid
        mvp.name = info.name
        mvp.job = info.job
        mvp.score = info.totalScore
    end

    local rate = ChampionCommonConfig.exRates[changeType]
    if rate then
        local exValue = math.ceil(info.score * rate / 10000)
        info.score = info.score - exValue
        changeCHTeamScore(team, ins, exValue, changeType)
    end
    s2cCHUpdateActorScore(actor, ins)
end

--变更队伍火晶
function changeCHTeamScore(team, ins, value, reason)
    if not team then return end

    local score = team.score + value
    team.score = score

    if score >= ChampionCommonConfig.winScore then
        ins.data.winCamp = team.teamId
        ins:win()
    else
        local winCamp = ins.data.winCamp
        if winCamp > 0 then
            local winTeam = ins.data.teamList[winCamp]
            if score > winTeam.score then
                ins.data.winCamp = team.camp
            end
        else
            ins.data.winCamp = team.camp
        end
    end

    --计算队伍增益
    local isChange = false
    for index, conf in ipairs(ChampionBuffConfig) do
        if team.buffLevel < index and score >= conf.condition then
            team.buffLevel = index
            isChange = true
        end
    end
    if isChange then
        for actorid, info in ipairs(ins.data.actorList) do
            local actor = LActor.getActorById(actorid)
            if actor and info.isLeave == 0 and info.teamId == team.teamId then
                updateAttr(actor, ins)
            end
        end
    end
    boardCHTeamScore(team, ins)
end

--存储火晶
function onCHStore(camp, actor, ins)
    local team = ins.data.teamList[camp]
    if not team then return end
    local actorid = LActor.getActorId(actor)
    local info = ins.data.actorList[actorid]
    if not info then return end

    local value = info.score
    changeCHActorScore(actor, ins, -value, 0)
    changeCHTeamScore(team, ins, value)
end

--掠夺火晶
function onCHPlunder(camp, actor, ins)
    local team = ins.data.teamList[camp]
    if not team then return end

    local value = math.ceil(team.score * ChampionCommonConfig.plunderRate / 10000)
    changeCHTeamScore(team, ins, -value)
    changeCHActorScore(actor, ins, value, CHANGE_SCORE_TYPE.gatherPlunder)
end

--副本结算
function onCHTeamResult(ins)
    for actorid, info in pairs(ins.data.actorList) do
        if info.isLeave == 0 then
            s2cCHResult(LActor.getActorById(actorid), ins)
        end
    end
end

--广播队伍基地火晶数量
function boardCHTeamScore(team, ins)
    for actorid, info in pairs(ins.data.actorList) do
        if info.isLeave == 0 and info.camp == team.camp then
            s2cCHUpdateTeamScore(LActor.getActorById(actorid), team.score)
        end
    end
end

----------------------------------------------------------------------------------
--协议处理
--92-46 冠军赛-分配队伍颜色(废弃)
function s2cCHCampInfo(actor, ins)
    local actorid = LActor.getActorId(actor)
    local info = ins.data.actorList[actorid]
    if not info then return end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_FBCampInfo)
    if pack == nil then return end
    LDataPack.writeChar(pack, info.camp)

    LDataPack.writeChar(pack, #ins.data.teamList)
    for _, teamInfo in ipairs(ins.data.teamList) do
        LDataPack.writeChar(pack, teamInfo.camp)
        LDataPack.writeString(pack, teamInfo.name)
    end
    LDataPack.flush(pack)
end

--92-47 冠军赛-副本信息
function s2cCHFBAllInfo(actor, ins)
    local actorid = LActor.getActorId(actor)
    local info = ins.data.actorList[actorid]
    if not info then return end
    local team = ins.data.teamList[info.camp]
    if not team then return end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_FBAllInfo)
    if pack == nil then return end
    LDataPack.writeChar(pack, info.camp)
    LDataPack.writeChar(pack, team.buffLevel)
    LDataPack.writeInt(pack, info.score)
    LDataPack.writeInt(pack, team.score)

    LDataPack.writeChar(pack, #ins.data.teamList)
    for _, teamInfo in ipairs(ins.data.teamList) do
        LDataPack.writeChar(pack, teamInfo.camp)
        LDataPack.writeString(pack, teamInfo.name)
        LDataPack.writeInt(pack, teamInfo.score)
    end

    for monsterId, bInfo in pairs(ins.data.bossInfo) do
        LDataPack.writeInt(pack, monsterId)
        LDataPack.writeChar(pack, bInfo.hpPercent)
        LDataPack.writeInt(pack, bInfo.refreshtime)
    end
    LDataPack.flush(pack)
end

--92-48 冠军赛-更新玩家火晶
function s2cCHUpdateActorScore(actor, ins)
    local actorid = LActor.getActorId(actor)
    local info = ins.data.actorList[actorid]
    if not info then return end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_FBUpdateActorScore)
    if pack == nil then return end
    LDataPack.writeInt(pack, info.score)
    LDataPack.flush(pack)
end

--92-49 冠军赛-更新基地火晶
function s2cCHUpdateTeamScore(actor, value)
    if not actor then return end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_FBUpdateTeamScore)
    if pack == nil then return end
    LDataPack.writeInt(pack, value)
    LDataPack.flush(pack)
end

--92-50 冠军赛-更新怪物信息
function boardCHBossInfo(monsterId, ins)
    local bInfo = ins.data.bossInfo[monsterId]
    if not bInfo then return end

    local pack = LDataPack.allocPacket()
    if pack == nil then return end

    LDataPack.writeByte(pack, Protocol.CMD_ZhanQu)
    LDataPack.writeByte(pack, Protocol.sChampionCmd_FBUpdateBossInfo)

    LDataPack.writeInt(pack, monsterId)
    LDataPack.writeChar(pack, bInfo.hpPercent)
    LDataPack.writeInt(pack, bInfo.refreshtime)
    Fuben.sendData(ins.handle, pack)
end

--92-51 冠军赛-发送战队聊天
local function c2sCHQuickChat(actor, packet)
    local id = LDataPack.readChar(packet)
    local actorid = LActor.getActorId(actor)
    CHQuickChat(actorid, id)
end

--92-51 冠军赛-广播战队聊天
function s2cCHQuickChat(actor, id)
    if not actor or not id then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_FBQuickChat)
    if pack == nil then return end
    LDataPack.writeChar(pack, id)
    LDataPack.flush(pack)
end

--92-52 冠军赛-更新怪物信息
function s2cCHResult(actor, ins)
    if not actor then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sChampionCmd_FBResult)
    if pack == nil then return end
    LDataPack.writeChar(pack, ins.data.winCamp)
    LDataPack.writeChar(pack, #ins.data.teamList)
    for camp, teamInfo in ipairs(ins.data.teamList) do
        LDataPack.writeChar(pack, camp)
        LDataPack.writeString(pack, teamInfo.name)
        LDataPack.writeChar(pack, teamInfo.icon)
        LDataPack.writeInt(pack, teamInfo.score)
        local mvp = teamInfo.mvp
        LDataPack.writeChar(pack, mvp.job)
        LDataPack.writeString(pack, mvp.name)
        LDataPack.writeInt(pack, mvp.score)
    end
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
--副本初始化
local function onInitFuben(ins)
    ins.data.gameIndex = 0
    ins.data.winCamp = 0
    ins.data.actorList = {}
    ins.data.teamList = {}
    ins.data.bossInfo = {}
    local bossInfo = ins.data.bossInfo
    for monsterId, conf in pairs(ChampionMonsterConfig) do
        Fuben.createMonster(ins.scene_list[1], monsterId, conf.position.x, conf.position.y)
        if conf.camp == 0 then
            bossInfo[monsterId] = {
                hpPercent = 100,
                refreshtime = 0,
            }
        end
    end
end

--定时检测
local function onTimeCheck(ins)

end

local function onEnterBefore(ins, actor)
    if not actor then return end
    local monIdList = {}
    for id, conf in pairs(ChampionMonsterConfig) do
        table.insert(monIdList, id)
    end
    slim.s2cMonsterConfig(actor, monIdList)
    s2cCHFBAllInfo(actor, ins)
end

local function onEnterFb(ins, actor)
    updateAttr(actor, ins)
end

local function onExitFb(ins, actor)
    --if ins.is_end then return end
    local actorid = LActor.getActorId(actor)
    local info = ins.data.actorList[actorid]
    if info then
        info.isLeave = 1
    end
    updateAttr(actor, ins)
end

--副本内杀怪
local function onMonsterDie(ins, monster, killer_hdl)
    if ins.is_end then return end

    local et = LActor.getEntity(killer_hdl)
    local killer_actor = LActor.getActor(et)
    local monsterId = Fuben.getMonsterId(monster)

    --提前注册复活事件,避免因为报错导致怪物不再复活
    local refreshConfig = ChampionMonsterConfig[monsterId]
    if not refreshConfig then return end

    LActor.postScriptEventLite(nil, refreshConfig.refreshTime * 1000, refreshCHMonster, ins.handle, monsterId)

    changeCHActorScore(killer_actor, ins, refreshConfig.score, CHANGE_SCORE_TYPE.monsterDie)

    local bossInfo = ins.data.bossInfo[monsterId]
    if bossInfo then
        bossInfo.hpPercent = 0
        bossInfo.refreshtime = System.getNowTime() + refreshConfig.refreshTime
    end
    boardCHBossInfo(monsterId, ins)
end

--玩家死亡
local function onActorDie(ins, actor, killHdl)
    if ins.is_end then return end
    local et = LActor.getEntity(killHdl)
    local killer_actor = LActor.getActor(et)
    local actorid = LActor.getActorId(actor)
    local info = ins.data.actorList[actorid]

    --被击杀者扣除火晶
    local value = math.ceil(info.score * ChampionCommonConfig.killRate / 10000)
    changeCHActorScore(actor, ins, -value, 0)

    --杀人者获得掠夺的积分
    if killer_actor then
        changeCHActorScore(killer_actor, ins, value, CHANGE_SCORE_TYPE.actorKill)
    end
end

--采集更新
local function onGatherMonsterUpdate(ins, monster, actor)
    if ins.is_end then return end
    local status, gather_time, wait_time = LActor.getGatherMonsterInfo(monster)
    if status == GatherStatusType_Finish then
        local monsterid = Fuben.getMonsterId(monster)
        local monsterConfig = TianXuanMonsterConfig[monsterid]
        if not monsterConfig then return end
        local camp = LActor.getCamp(actor)
        if camp == 0 then return end
        if camp == monsterConfig.camp then
            onCHStore(camp, actor, ins)
        else
            onCHPlunder(monsterConfig.camp, actor, ins)
        end
        Fuben.resetGather(monster)
    end
end

local function onWin(ins)
    local winCamp = ins.data.winCamp
    local actorList = ins.data.actorList
    local teamList = ins.data.teamList

    local winTeam = teamList[winCamp]
    if winTeam then
        winTeam.isWin = 1
    end

    for actorid, info in pairs(actorList) do
        championrank.addCHActorRankScore(actorid, info.serverid, info.name, info.totalScore)
    end

    for _, team in ipairs(teamList) do
        championrank.addCHTeamRankScore(team.teamId, team.name, team.power, team.isWin, team.score)
    end

    champion.CHTeamWin(ins.data.gameIndex, winTeam.teamId)

    onCHTeamResult(ins)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    if not System.isLianFuSrv() then return end

    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cChampionCmd_FBQuickChat, c2sCHQuickChat)

    local championFbId = ChampionCommonConfig.championFbId
    insevent.registerInstanceInit(championFbId, onInitFuben)
    insevent.regCustomFunc(championFbId, onTimeCheck, "onTimeCheck")
    insevent.registerInstanceEnterBefore(championFbId, onEnterBefore)
    insevent.registerInstanceEnter(championFbId, onEnterFb)
    insevent.registerInstanceExit(championFbId, onExitFb)
    insevent.registerInstanceMonsterDie(championFbId, onMonsterDie)
    insevent.registerInstanceActorDie(championFbId, onActorDie)
    insevent.registerInstanceGatherMonsterUpdate(championFbId, onGatherMonsterUpdate)
    insevent.registerInstanceWin(championFbId, onWin)
    insevent.registerInstanceLose(championFbId, onWin)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.chfbprint = function (actor, args)
    if not System.isLianFuSrv() then return end
    print("now =", System.getNowTime())
    local fbhl = LActor.getFubenHandle(actor)
    local ins = instancesystem.getInsByHdl(fbhl)
    if ins then
        utils.printTable(ins.data)
    end
    return true
end

