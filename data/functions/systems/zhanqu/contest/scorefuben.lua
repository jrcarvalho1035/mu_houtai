--卓越积分赛
module("scorefuben", package.seeall)

local fbResult = {
    fbDraw = 0,
    fbLose = 1,
    fbWin = 2,
}

local function checkActorResult(ins)
    if ins.is_end then return end
    local leaveList = ins.data.leaveList
    if #leaveList == 1 then
        onResultByLoser(ins, leaveList[1])
    end
end

function setActorLose(ins, actorid)
    if not ins then return end
    local actorList = ins.data.actorList
    if not actorList then return end
    local info = actorList[actorid]
    if not info then return end
    
    info.result = fbResult.fbLose
    onActorResult(actorid, info)
end

function onResultByLoser(ins, actorid)
    if ins.is_end then return end
    local actorList = ins.data.actorList
    for aid, info in pairs(actorList) do
        if aid == actorid then
            info.result = fbResult.fbLose
        else
            info.result = fbResult.fbWin
        end
        onActorResult(aid, info)
    end
    ins:win()
end

function onResultByDraw(ins)
    local actorList = ins.data.actorList
    for aid, info in pairs(actorList) do
        info.result = fbResult.fbDraw
        onActorResult(aid, info)
    end
end

--玩家结算事件
function onActorResult(actorid, info)
    local oldScore, addScore, rewards = contest.addCTScore(actorid, info.result)
    local actor = LActor.getActorById(actorid)
    if actor and LActor.getFubenId(actor) == ContestCommonConfig.scoreFbId then
        actoritem.addItems(actor, rewards, "contest match rewards")
        s2cCTFubenResult(actor, info.result, oldScore, addScore, rewards)
    else
        local mailData = {
            head = ContestCommonConfig.scoreMailTitle,
            context = ContestCommonConfig.scoreMailContent,
            tAwardList = rewards,
        }
        mailsystem.sendMailById(actorid, mailData, info.serverid)
    end
    local extra = string.format("result =%d,oldScore =%d,addScore =%d", info.result, oldScore, addScore)
    utils.logCounter(actor, "contest", "", extra, "contest", "scorefuben")
    --print("onActorResult ", "result =", info.result, "oldScore =", oldScore, "addScore =", addScore)
end

----------------------------------------------------------------------------------
--协议处理

--92-4 积分赛战斗结果
function s2cCTFubenResult(actor, result, oldScore, addScore, rewards)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sContestCmd_ScoreResult)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, result)
    LDataPack.writeInt(pack, oldScore)
    LDataPack.writeInt(pack, addScore)
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
    local actorList = ins.data.actorList
    local actorid = LActor.getActorId(actor)
    local idx = actorList[actorid].idx
    
    if idx == 1 then
        local rolePos = ContestCommonConfig.myPos[1]
        local role = LActor.getRole(actor)
        LActor.setEntityScenePos(role, rolePos.x, rolePos.y)
        
        local yongbingPos = ContestCommonConfig.myPos[2]
        local yongbing = LActor.getYongbing(actor)
        if yongbing then
            LActor.setEntityScenePos(yongbing, yongbingPos.x, yongbingPos.y)
        end
    else
        local rolePos = ContestCommonConfig.tarPos[1]
        local role = LActor.getRole(actor)
        LActor.setEntityScenePos(role, rolePos.x, rolePos.y)
        
        local yongbingPos = ContestCommonConfig.tarPos[2]
        local yongbing = LActor.getYongbing(actor)
        if yongbing then
            LActor.setEntityScenePos(yongbing, yongbingPos.x, yongbingPos.y)
        end
    end
    
    LActor.addSkillEffect(actor, JjcConstConfig.bindEffectId)
    LActor.setCamp(actor, idx)
    instancesystem.s2cFightCountDown(actor, 5)
end

local function onExitFb(ins, actor)
    local actorid = LActor.getActorId(actor)
    onResultByLoser(ins, actorid)
    LActor.clearSkillEffect(actor)
    
    contest.setCTStatusAwait(actorid)
end

local function onOffline(ins, actor)
    LActor.exitFuben(actor)
end

local function onActorDie(ins, actor)
    local actorid = LActor.getActorId(actor)
    onResultByLoser(ins, actorid)
end

--战斗超时
local function onLose(ins)
    onResultByDraw(ins)
end

----------------------------------------------------------------------------------
--初始化
function init()
    --if System.isCommSrv() then return end
    --if System.isBattleSrv() then return end
    if not System.isLianFuSrv() then return end
    
    local fbId = ContestCommonConfig.scoreFbId
    insevent.regCustomFunc(fbId, checkActorResult, "checkActorResult")
    insevent.registerInstanceEnter(fbId, onEnterFb)
    insevent.registerInstanceExit(fbId, onExitFb)
    insevent.registerInstanceOffline(fbId, onOffline)
    insevent.registerInstanceActorDie(fbId, onActorDie)
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
