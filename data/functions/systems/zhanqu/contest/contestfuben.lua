--卓越擂台赛
module("contestfuben", package.seeall)

function setCTRavil(sceneHandle, actorid, rolePos, yongbingPos)
    local roleCloneData, actorData, roleSuperData = actorcommon.getCloneData(actorid)
    
    if roleSuperData then
        roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
        roleSuperData.aiId = FubenConstConfig.roleSuperAi
    end
    
    local actorClone = LActor.createActorCloneWithData(actorid, sceneHandle, rolePos.x, rolePos.y, actorData, roleCloneData, roleSuperData)
    
    local roleClone = LActor.getRole(actorClone)
    local roleHandle = LActor.getRealHandle(roleClone)
    if roleClone then
        LActor.setEntityScenePos(roleClone, rolePos.x, rolePos.y)
    end
    local yongbing = LActor.getYongbing(actorClone)
    if yongbing then
        LActor.setEntityScenePos(yongbing, yongbingPos.x, yongbingPos.y)
    end
    return roleHandle
end

function checkCloneInfo(ins)
    for _, info in ipairs(ins.data.cloneInfo) do
        local roleClone = LActor.getEntity(info.roleHandle)
        if roleClone then
            info.hp = LActor.getHp(roleClone)
        else
            info.hp = 0
        end
    end
end

----------------------------------------------------------------------------------
--协议处理

--92-4 积分赛战斗结果
function s2cSCFubenResult(actor, result, fightTime, killCount, cloneInfo, rewards)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.cContestCmd_ContestResult)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, result)
    LDataPack.writeByte(pack, fightTime)
    LDataPack.writeChar(pack, killCount)
    LDataPack.writeChar(pack, #cloneInfo)
    for i, info in ipairs(cloneInfo) do
        LDataPack.writeChar(pack, info.hp)
    end
    LDataPack.writeChar(pack, #rewards)
    for i, conf in ipairs(rewards) do
        LDataPack.writeInt(pack, conf.id)
        LDataPack.writeInt(pack, conf.count)
    end
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
--进入副本时,设置坐标为等待区
local function onEnterFb(ins, actor)
    local round = ins.data.round
    local sceneHandle = ins.scene_list[1]
    local challengeList = ins.data.challengeList
    local cloneInfo = ins.data.cloneInfo
    local config = ContestFubenConfig[round]
    
    for idx, info in ipairs(challengeList) do
        local rolePos = config.roleFightPos[idx]
        local yongbingPos = config.yongbingFightPos[idx]
        if not (rolePos and yongbingPos) then break end
        local roleHandle = setCTRavil(sceneHandle, info.actorid, rolePos, yongbingPos)
        table.insert(cloneInfo, {roleHandle = roleHandle, hp = 100})
    end
    
    for _, effectId in ipairs(ContestCommonConfig.addEffects) do
        LActor.addSkillEffect(actor, effectId)
    end
end

local function onExitFb(ins, actor)
    ins:lose()
    for _, effectId in ipairs(ContestCommonConfig.addEffects) do
        LActor.delSkillEffect(actor, effectId)
    end
end

local function onOffline(ins, actor)
    LActor.exitFuben(actor)
end

local function onActorDie(ins, actor)
    ins:lose()
end

local function onActorCloneDie(ins, killerHdl, actorClone)
    local challengeList = ins.data.challengeList
    local challengeCount = ins.data.challengeCount
    challengeCount = challengeCount - 1
    ins.data.challengeCount = challengeCount
    ins.data.killCount = ins.data.killCount + 1
    if challengeCount <= 0 then
        ins:win()
    end
end

local function onWin(ins)
    local actor = ins:getActorList()[1]
    if not actor then return end
    
    local rewards = ContestFubenConfig[ins.data.round].winFightReward
    actoritem.addItems(actor, rewards, "contest win rewards")
    contest.fightContestResult(actor, ins.data.round, ins.data.idx, ins.data.killCount, true)
    
    checkCloneInfo(ins)
    local fightTime = System.getNowTime() - ins.start_time[0]
    s2cSCFubenResult(actor, 1, fightTime, ins.data.killCount, ins.data.cloneInfo, rewards)
end

local function onLose(ins)
    local actor = ins:getActorList()[1]
    if not actor then return end
    
    local rewards = ContestFubenConfig[ins.data.round].loseFightReward
    actoritem.addItems(actor, rewards, "contest lose rewards")
    contest.fightContestResult(actor, ins.data.round, ins.data.idx, ins.data.killCount, false)
    
    checkCloneInfo(ins)
    local fightTime = System.getNowTime() - ins.start_time[0]
    s2cSCFubenResult(actor, 0, fightTime, ins.data.killCount, ins.data.cloneInfo, rewards)
end

----------------------------------------------------------------------------------
--初始化
function init()
    --if System.isCommSrv() then return end
    --if System.isBattleSrv() then return end
    if not System.isLianFuSrv() then return end
    
    local fbId = ContestCommonConfig.contestFbId
    insevent.registerInstanceEnter(fbId, onEnterFb)
    insevent.registerInstanceExit(fbId, onExitFb)
    insevent.registerInstanceOffline(fbId, onOffline)
    insevent.registerInstanceActorDie(fbId, onActorDie)
    insevent.regActorCloneDie(fbId, onActorCloneDie)
    insevent.registerInstanceWin(fbId, onWin)
    insevent.registerInstanceLose(fbId, onLose)
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
