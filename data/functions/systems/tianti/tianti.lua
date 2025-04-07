module("tianti", package.seeall)
require("tianti.tianticonst")
require("tianti.tiantidan")
require("tianti.tiantirobot")

local day_sec = 24 * (60 * 60)
local week_sec = 7 * day_sec
local refresh_time = (22 * (60 * 60)) + (30 * 60)
local begin_week = 1
local begin_time = 10 * (60 * 60)
local end_week = 7
local end_time = (22 * (60 * 60))
tianti_openg = false

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then return nil end
    if var.tianti == nil then var.tianti = {} end
    return var.tianti
end

local function isOpenTime(t)
    local week = utils.getWeek(t)
    local after_sec = (t + System.getTimeZone()) % day_sec
    if week == end_week and after_sec >= end_time then return false end
    if week == begin_week and after_sec < begin_time then return false end
    return true
end

local function isOpen(actor)
    return actorexp.checkLevelCondition(actor, actorexp.LimitTp.tianti)
end

local function isDiamond(actor)
    local var = getActorVar(actor)
    local conf = TianTiConstConfig.diamond
    return conf.level == var.level and conf.id == var.id
end

local function OpenTianti()
    --if System.isBattleSrv() then return end
    tianti_openg = true
    local actors = System.getOnlineActorList()
    if actors ~= nil then 
        for i = 1, #actors do 
            s2cTiantiData(actors[i]) 
        end 
    end
    -- 公告
    if System.isBattleSrv() then
        tianticross.getLastWeekFirstActorName(1) -- 上周第一名
    end
end

function onStartNotice(last)
    if last ~= "" then
        noticesystem.broadCastNotice(TianTiConstConfig.openBroadcastNotice[1], last)
    else
        noticesystem.broadCastNotice(TianTiConstConfig.openBroadcastNotice[2])
    end
end

local function CloseTianti()
    if System.isBattleSrv() then 
        tiantirank.refreshWeek()
        tianticross.getLastWeekFirstActorName(0) -- 天梯王者
    end    
    LActor.tiantiRefreshWeek()
    local actors = System.getOnlineActorList()
    if actors ~= nil then
        for i = 1, #actors do
            refreshWeek(actors[i])
            getDanAwardMail(actors[i])
            s2cTiantiData(actors[i])
        end
    end
    tianti_openg = false
end

function onEndotice(last)
    if last and last ~= "" then
        noticesystem.broadCastNotice(TianTiConstConfig.closeBroadcastNotice[1], last)
    else
        noticesystem.broadCastNotice(TianTiConstConfig.closeBroadcastNotice[2])
    end
end

local function StopTianti()
    if System.isCrossWarSrv() then return end
    tianti_openg = false
    local actors = System.getOnlineActorList() or {}
    for i = 1, #actors do 
        s2cTiantiData(actors[i]) 
    end
end

_G.OpenTianti = OpenTianti
_G.CloseTianti = CloseTianti
_G.StopTianti = StopTianti

-- 更新天梯信息
local function updateBasicData(actor)
    local basic_data = LActor.getActorData(actor)
    local var = getActorVar(actor)
    basic_data.tianti_level = var.level
    basic_data.tianti_dan = TianTiDanConfig[var.level][var.id].showDan
    basic_data.tianti_win_count = var.win_count
    basic_data.tianti_week_refres = var.week_time
end

local function initData(actor)
    if isOpen(actor) == false then return end
    local var = getActorVar(actor)
    if var.level == nil then var.level = 1 end
    if var.id == nil then var.id = 0 end
    if var.last_level == nil then var.last_level = 0 end
    if var.last_id == nil then var.last_id = 0 end
    if var.challenges_count == nil then -- 挑战次数
        var.challenges_count = TianTiConstConfig.maxRestoreChallengesCount
    end
    if var.last_time == nil then -- 挑战CD的开始时间
        var.last_time = 0
    end
    -- if var.challenges_count_cd_time == nil then -- 挑战次数的cd的开始时间
    -- 	var.challenges_count_cd_time = os.time()
    -- end
    -- if var.challenges_count_cd == nil then -- 挑战次数的cd  
    -- 	var.challenges_count_cd = 0
    -- end
    if var.win_count == nil then -- 本周净胜场 
        var.win_count = 0
    end
    if var.last_win_count == nil then -- 上周净胜场
        var.last_win_count = 0
    end
    if var.winning_streak == nil then -- 连胜次数
        var.winning_streak = 0
    end
    if var.buy_challenges_count == nil then -- 购买挑战次数的次数
        var.buy_challenges_count = 0
    end
    if var.differ_week == nil then -- 跟开始时间相差多少周(结计算领取奖励用的)
        var.differ_week = 0
    end
    if var.get_last_week_award == nil then -- 是否得到上周奖励
        var.get_last_week_award = 0
    end
    if var.time == nil then var.time = os.time() end
    if var.week_time == nil then var.week_time = 0 end

    while (TianTiDanConfig[var.level][var.id] == nil) do var.id = var.id - 1 end

    if var.last_level ~= 0 then
        while (TianTiDanConfig[var.last_level][var.last_id] == nil) do var.last_id = var.last_id - 1 end
    end
    if var.enter_fuben == nil then var.enter_fuben = 0 end
    updateBasicData(actor)
end

local function refreshDay(actor)
    if isOpen(actor) == false then return end
    local var = getActorVar(actor)
    local curr_time = os.time()
    if utils.getDay(var.time) == utils.getDay(curr_time) then return end
    var.buy_challenges_count = 0
    var.time = curr_time
end

function refreshWeek(actor)
    if isOpen(actor) == false then return end
    local var = getActorVar(actor)
    local curr_time = os.time()
    if curr_time < var.week_time then return end
    var.differ_week = math.floor((curr_time - var.week_time) / week_sec) == 0 and 1 or 0
    if var.week_time == 0 then
        var.differ_week = 0
        var.level = 0
        var.id = 0
    end
    var.buy_challenges_count = 0
    var.last_level = var.level
    var.last_id = var.id
    var.last_win_count = var.win_count
    var.level = 1
    var.id = 0
    var.winning_streak = 0
    var.win_count = 0
    var.get_last_week_award = 0
    local time = utils.getWeeks(curr_time) * week_sec -- 取整周的秒数
    time = time + ((end_week - 1) * day_sec) + refresh_time -- 算出刷新时间
    time = time - (System.getTimeZone() + (3 * day_sec)) -- 时差
    if var.week_time == time then time = time + week_sec end
    var.week_time = time
    updateBasicData(actor)
    s2cTiantiData(actor)
end

function gmResetTianti(actor)
    System.getStaticVar().tianti_gm = System.getStaticVar().tianti_gm or {}
    local sysvar = System.getStaticVar().tianti_gm
    local var = getActorVar(actor)
    if sysvar.gm_reset_time ~= nil and (var.gm_reset_time == nil or var.gm_reset_time ~= sysvar.gm_reset_time) then
        var.gm_reset_time = sysvar.gm_reset_time
        var.win_count = 0
        var.level = 1
        var.id = 0
        updateBasicData(actor)
        s2cTiantiData(actor)
        print(LActor.getActorId(actor) .. " gmResetTianti")
    end
end

-- 天梯升星
local function addId(actor, size)
    local var = getActorVar(actor)
    if size == 0 then return 0 end
    if size > 0 then
        if TianTiDanConfig[var.level][var.id + 1] == nil and var.id ~= 0 then
            if TianTiDanConfig[var.level + 1] ~= nil then
                var.level = var.level + 1
                var.id = 0
                local conf = TianTiDanConfig[var.level][var.id]
                noticesystem.broadCastNotice(conf.notice, actorcommon.getVipShow(actor), LActor.getName(actor))
            end
        elseif TianTiDanConfig[var.level][var.id + 1] ~= nil then
            var.id = var.id + 1
            local conf = TianTiDanConfig[var.level][var.id]
            noticesystem.broadCastNotice(conf.notice, actorcommon.getVipShow(actor), LActor.getName(actor))
        else
            return 0
        end
        return addId(actor, size - 1) + 1
    else -- 掉星处理
        if TianTiDanConfig[var.level][var.id].isDropStar == 1 and var.id ~= 0 then
            var.id = var.id - 1
            return addId(actor, size + 1) - 1
        else
            return 0
        end
    end
end

function getDanAwardMail(actor)
    if not isOpen(actor) then return end
    local var = getActorVar(actor)
    print("getDanAwardMail", var.differ_week, var.get_last_week_award, var.last_level)
    if var.differ_week == 1 and var.get_last_week_award == 0 and var.last_level ~= 0 then
        local danAward = TianTiDanConfig[var.last_level][var.last_id].danAward
        local mailData = {
            head = TianTiConstConfig.danMailHead,
            context = TianTiConstConfig.danMailContext,
            tAwardList = danAward
        }
        mailsystem.sendMailById(LActor.getActorId(actor), mailData, LActor.getServerId(actor))
        var.get_last_week_award = 1
    end
end

local function setChallengesCountCdTimer(actor, notShow)
    if not isOpen(actor) then return end
    local var = getActorVar(actor)
    local now = System.getNowTime()
    local cd = TianTiConstConfig.challengesCountCd
    local flag = false
    while (var.last_time + cd <= now) do
        var.last_time = var.last_time + cd
        var.challenges_count = var.challenges_count + 1
        if var.challenges_count >= TianTiConstConfig.maxRestoreChallengesCount then
            var.challenges_count = TianTiConstConfig.maxRestoreChallengesCount
            var.last_time = 0
            flag = true
            break
        end
    end
    if not notShow then s2cTiantiData(actor) end
    local leftTime = var.last_time + cd - now
    if leftTime > 0 then
        LActor.postScriptEventLite(actor, leftTime * 1000, setChallengesCountCdTimer)
    end
end

function setClone(actorid, cloneActor_name, offlinedata, sceneHandle)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end
    print("xxxxxxxx tianti setClone ", actorid, offlinedata.actor_name)
    local roleCloneData, actorCloneData, roleSuperData = actorcommon.getCloneDataByOffLineData(offlinedata)
    if not roleCloneData or not actorCloneData or not roleSuperData then
        local id = math.random(1, #TianTiRobotConfig)
        roleCloneData, actorCloneData, roleSuperData = actorcommon.createRobotClone(TianTiRobotConfig, id)
        roleCloneData.name = cloneActor_name
    end
    local var = getActorVar(actor)
    if roleSuperData then
        roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
        roleSuperData.aiId = FubenConstConfig.roleSuperAi
    end
    local tarPos = TianTiDanConfig[var.level][var.id].tarPos
    local x = tarPos[1][1]
    local y = tarPos[1][2]
    local actorClone = LActor.createActorCloneWithData(var.rivalId, sceneHandle, x, y, actorCloneData, roleCloneData, roleSuperData)
    local roleClone = LActor.getRole(actorClone)
    if roleClone then
        local pos = tarPos[1]
        LActor.setEntityScenePos(roleClone, pos[1], pos[2])
    end
    local yongbing = LActor.getYongbing(actorClone)
	if yongbing then
		local pos = tarPos[2]
		LActor.setEntityScenePos(yongbing, pos[1], pos[2])
	end

    -- 额外效果
    local extraEffectId = TianTiConstConfig.extraEffectIds[1]
    if extraEffectId then
        LActor.addSkillEffect(actor, extraEffectId)
        LActor.addSkillEffect(actorClone, extraEffectId)
    end

    -- 定身
    LActor.addSkillEffect(actorClone, TianTiConstConfig.bindEffectId)
    LActor.addSkillEffect(actor, TianTiConstConfig.bindEffectId)
    var.enter_fuben = 1
    var.rivalId = nil
    var.rivalserverid = nil
end

function checkHaveClone(actor, ins)
    local count = Fuben.getRoleCloneCount(ins.scene_list[1])
    if count <= 1 then return end
    local roleCloneData = {}
    local actorCloneData = nil
    local roleSuperData = nil
    local var = getActorVar(actor)

    roleCloneData, actorCloneData, roleSuperData = actorcommon.createRobotClone(TianTiRobotConfig, 1)
    if roleSuperData then
        roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
        roleSuperData.aiId = FubenConstConfig.roleSuperAi
    end
    local tarPos = TianTiDanConfig[var.level][var.id].tarPos
    local x = tarPos[1][1]
    local y = tarPos[1][2]
    local actorClone = LActor.createActorCloneWithData(1, ins.scene_list[1], x, y, actorCloneData, roleCloneData, roleSuperData)
    local roleClone = LActor.getRole(actorClone)
    if roleClone then
        local pos = tarPos[1]
        LActor.setEntityScenePos(roleClone, pos[1], pos[2])
    end
    local yongbing = LActor.getYongbing(actorClone)
	if yongbing then
		local pos = tarPos[2]
		LActor.setEntityScenePos(yongbing, pos[1], pos[2])
	end

    -- 额外效果
    local extraEffectId = TianTiConstConfig.extraEffectIds[1]
    if extraEffectId then
        LActor.addSkillEffect(actor, extraEffectId)
        LActor.addSkillEffect(actorClone, extraEffectId)
    end

    -- 定身
    LActor.addSkillEffect(actorClone, TianTiConstConfig.bindEffectId)
    LActor.addSkillEffect(actor, TianTiConstConfig.bindEffectId)
    var.enter_fuben = 1
    var.rivalId = nil
    var.rivalserverid = nil
end

-- 进入副本战斗
function fightActorClone(actor, ins, rivalId)
    local roleCloneData = {}
    local actorCloneData = nil
    local roleSuperData = nil
    local var = getActorVar(actor)
    if not var.rivalserverid then
        print("fightActorClone get rivalId", var.rivalId)
        var.rivalId = nil
        var.rivalserverid = nil
        return 
    end
    --如果是匹配到的跨服机器人
    if var.rivalserverid ~= LActor.getServerId(actor) then
        tianticross.reqCloneInfo(LActor.getActorId(actor), var.rivalId, var.rivalserverid, ins.scene_list[1], LActor.getServerId(actor))
        return
    end
    local rconf = TianTiRobotConfig[rivalId]
    if rconf then -- 对手是机器人
        roleCloneData, actorCloneData, roleSuperData = actorcommon.createRobotClone(TianTiRobotConfig, rivalId)
    else -- 对手是玩家
        roleCloneData, actorCloneData, roleSuperData = actorcommon.getCloneData(rivalId)
        if not roleCloneData or not actorCloneData then
            roleCloneData, actorCloneData, roleSuperData = actorcommon.createRobotClone(TianTiRobotConfig, 1)
        end
    end
    if roleSuperData then
        roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
        roleSuperData.aiId = FubenConstConfig.roleSuperAi
    end
    local tarPos = TianTiDanConfig[var.level][var.id].tarPos
    local x = tarPos[1][1]
    local y = tarPos[1][2]
    local actorClone = LActor.createActorCloneWithData(var.rivalId, ins.scene_list[1], x, y, actorCloneData, roleCloneData, roleSuperData)
    local roleClone = LActor.getRole(actorClone)
    if roleClone then
        local pos = tarPos[1]
        LActor.setEntityScenePos(roleClone, pos[1], pos[2])
    end
    local yongbing = LActor.getYongbing(actorClone)
	if yongbing then
		local pos = tarPos[2]
		LActor.setEntityScenePos(yongbing, pos[1], pos[2])
	end

    -- 额外效果
    local extraEffectId = TianTiConstConfig.extraEffectIds[1]
    if extraEffectId then
        LActor.addSkillEffect(actor, extraEffectId)
        LActor.addSkillEffect(actorClone, extraEffectId)
    end

    -- 定身
    LActor.addSkillEffect(actorClone, TianTiConstConfig.bindEffectId)
    LActor.addSkillEffect(actor, TianTiConstConfig.bindEffectId)
    var.enter_fuben = 1
    var.rivalId = nil
    var.rivalserverid = nil
end

local function onInit(actor)
    if System.isCrossWarSrv() then return end
    initData(actor)
    refreshWeek(actor)
    refreshDay(actor)
end

local function onLogin(actor)
    if System.isCrossWarSrv() then return end
    local var = getActorVar(actor)
    var.rivalId = nil
    var.rivalserverid = nil
    getDanAwardMail(actor)
    setChallengesCountCdTimer(actor, true)
    s2cTiantiData(actor)
    s2cbuyChallengesCount(actor)
end

local function onLevelUp(actor, level, oldLevel)
    if System.isCrossWarSrv() then return end
    initData(actor)
    refreshWeek(actor)
    refreshDay(actor)
    s2cbuyChallengesCount(actor)
    s2cTiantiData(actor)
end

local function onNewDay(actor, login)
    if System.isCrossWarSrv() then return end
    initData(actor)
    refreshWeek(actor)
    refreshDay(actor)
    if not login then
        s2cTiantiData(actor)
        s2cbuyChallengesCount(actor)
    end
end

local function onCustomChange(actor, custom, oldcustom)
    if System.isCrossWarSrv() then return end
    initData(actor)
    refreshWeek(actor)
    refreshDay(actor)
    s2cbuyChallengesCount(actor)
    s2cTiantiData(actor)
end

-------------------------------------------------------------------------------------------------------
-- 天梯信息
function s2cTiantiData(actor)
    if isOpen(actor) == false then return end
    local var = getActorVar(actor)
    local leftTime = 0 -- 恢复时间剩余时间
    local now = System.getNowTime()
    if (var.last_time or 0) > 0 then
        leftTime = math.max(0,TianTiConstConfig.challengesCountCd - (now - var.last_time))
    end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tianti, Protocol.sTiantiCmd_TianData)
    if npack == nil then return end
    LDataPack.writeByte(npack, tianti_openg and 1 or 0)
    LDataPack.writeInt(npack, var.level)
    LDataPack.writeInt(npack, var.id)
    LDataPack.writeInt(npack, var.challenges_count) -- 挑战次数
    LDataPack.writeInt(npack, leftTime) -- 挑战次数cd
    LDataPack.writeInt(npack, var.win_count) -- 净胜次数
    LDataPack.writeUInt(npack, var.winning_streak) -- 是否连胜
    LDataPack.writeByte(npack, var.differ_week) -- 上周有没有参加天梯
    LDataPack.writeByte(npack, var.get_last_week_award) -- 是否能领奖
    LDataPack.writeInt(npack, var.last_level) -- 上周天梯级别
    LDataPack.writeInt(npack, var.last_id) -- 上周天梯id
    LDataPack.writeInt(npack, var.last_win_count) -- 上周净胜
    LDataPack.flush(npack)
end

function matchRobot(actor)
    local var = getActorVar(actor)
    if var.rivalId then
        return
    end
    local conf = TianTiDanConfig[var.level][var.id]
    if conf and conf.MatchingRobot == 1 then
        local id = math.random(1, #TianTiRobotConfig)
        local rconf = TianTiRobotConfig[id]
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tianti, Protocol.sTiantiCmd_MatchingActor)
        LDataPack.writeInt(npack, 1)
        LDataPack.writeInt(npack, id)
        LDataPack.writeString(npack, LActor.getServerName(actor).."."..rconf.name)
        LDataPack.writeChar(npack, rconf.job)
        LDataPack.writeInt(npack, rconf.TianTiLevel)
        LDataPack.writeInt(npack, rconf.TianTiDan)
        LDataPack.flush(npack)
        var.rivalId = id
        var.rivalserverid = LActor.getServerId(actor)
        var.challenges_count = var.challenges_count - 1 -- 挑战次数开始恢复
        if var.challenges_count < TianTiConstConfig.maxRestoreChallengesCount and var.last_time == 0 then
            var.last_time = System.getNowTime()
            setChallengesCountCdTimer(actor)
        end
        s2cTiantiData(actor)
    else
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tianti, Protocol.sTiantiCmd_MatchingActor)
        LDataPack.writeInt(npack, 1)
        LDataPack.writeInt(npack, 0)
        LDataPack.writeString(npack, "")
        LDataPack.writeChar(npack, 0)
        LDataPack.writeInt(npack, 0)
        LDataPack.writeInt(npack, 0)
        LDataPack.writeString(npack, "")
        LDataPack.flush(npack)
    end
end

-- 请求匹配玩家 
function c2sMatchingActor(actor, packet)
    if isOpen(actor) == false then
        print("actor not open")
        return
    end
    if tianti_openg == false then
        print("tianti not open")
        return
    end
    local var = getActorVar(actor)
    if (var.challenges_count - 1) < 0 then return end

    local actor_id = tianticross.matchingActor(actor, var)
    if actor_id == 0 then
        if var.level == 1 then --青铜只匹配到机器人
            matchRobot(actor)
        else
            --定时匹配机器人
            LActor.postScriptEventLite(actor, 2000, matchRobot)
        end                
        return
    end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tianti, Protocol.sTiantiCmd_MatchingActor)
    if npack == nil then return end

    LDataPack.writeInt(npack, 0)
    LDataPack.writeInt(npack, actor_id)
    local basic_data = LActor.getActorDataById(actor_id)
    LDataPack.writeString(npack, basic_data.actor_name)
    LDataPack.writeChar(npack, basic_data.job)
    LDataPack.writeInt(npack, basic_data.tianti_level)
    LDataPack.writeInt(npack, basic_data.tianti_dan)
    LDataPack.writeString(npack, LActor.getServerName(actor))
    LDataPack.flush(npack)
    var.challenges_count = var.challenges_count - 1 -- 挑战次数开始恢复
    if var.challenges_count < TianTiConstConfig.maxRestoreChallengesCount and var.last_time == 0 then
        var.last_time = System.getNowTime()
        setChallengesCountCdTimer(actor)
    end
    var.rivalId = actor_id
    var.rivalserverid = LActor.getServerId(actor)
    s2cTiantiData(actor)
end

function onCrossMatch(actorid, findActorid, serverid, name, job, level, dan)
    local actor = LActor.getActorById(actorid)
    if not actor then return end    
    local var = getActorVar(actor)
    if var.rivalId then
        return
    end
    if findActorid == 0 then
        var.rivalId = math.random(1, #TianTiRobotConfig)
        name = LActor.getServerName(actor)..".".. TianTiRobotConfig[var.rivalId].name
        job = TianTiRobotConfig[var.rivalId].job
        level = TianTiRobotConfig[var.rivalId].TianTiLevel
        dan = TianTiRobotConfig[var.rivalId].TianTiDan
        var.rivalserverid = LActor.getServerId(actor)
    else
        var.rivalId = findActorid
        var.rivalserverid = serverid
    end
    

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tianti, Protocol.sTiantiCmd_MatchingActor)
    LDataPack.writeInt(npack, 1)
    LDataPack.writeInt(npack, var.rivalId)
    LDataPack.writeString(npack, name)
    LDataPack.writeChar(npack, job)
    LDataPack.writeInt(npack, level)
    LDataPack.writeInt(npack, dan)
    LDataPack.flush(npack)

    var.challenges_count = var.challenges_count - 1 -- 挑战次数开始恢复
    if var.challenges_count < TianTiConstConfig.maxRestoreChallengesCount and var.last_time == 0 then
        var.last_time = System.getNowTime()
        setChallengesCountCdTimer(actor)
    end
    s2cTiantiData(actor)
end

-- 开始挑战
function c2sBeginChallenges(actor, packet)
    local tp = LDataPack.readInt(packet)
    local actor_id = LDataPack.readInt(packet)

    if isOpen(actor) == false then return false end
    if tianti_openg == false then return false end
    local var = getActorVar(actor)
    if not var.rivalId then return false end -- 没匹配对手
    local conf = TianTiDanConfig[var.level][var.id]

    local hfuben = instancesystem.createFuBen(conf.fbId)
    if hfuben == 0 then return end
    local ins = instancesystem.getInsByHdl(hfuben)
    if ins == nil then return end
    local x, y = utils.getSceneEnterCoor(ins.id)
    LActor.enterFuBen(actor, hfuben, 0, x, y)
end

-- 挑战结果
function s2cChallengesResult(actor, win)
    local var = getActorVar(actor)
    local rewards
    if win then
        var.win_count = var.win_count + 1
        rewards = drop.dropGroup(TianTiDanConfig[var.level][var.id].winAward)
    else
        var.win_count = var.win_count - 1
        rewards = drop.dropGroup(TianTiDanConfig[var.level][var.id].loseAward)
    end
    if var.win_count < 0 then var.win_count = 0 end
    local last_id = var.id
    local last_level = var.level
    local add = 0
    actoritem.addItems(actor, rewards, "tianti win award")
    if win then
        if var.winning_streak >= 2 then
            local WinningStreakAdd = TianTiDanConfig[var.level][var.id].WinningStreak -- 连胜加星
            add = addId(actor, WinningStreakAdd)
        else
            add = addId(actor, 1)
        end
        var.winning_streak = var.winning_streak + 1
    else
        var.winning_streak = 0
        add = addId(actor, -1)
    end
    updateBasicData(actor)
    tianticross.updateRankingList(actor, var.win_count)
    s2cTiantiData(actor)

    local npack = LDataPack.allocPacket(
        actor,
        Protocol.CMD_Tianti,
        Protocol.sTiantiCmd_EndChallenges
    )
    if npack == nil then return end
    LDataPack.writeByte(npack, win and 1 or 0)
    LDataPack.writeShort(npack, #rewards)
    for i, v in pairs(rewards) do
        LDataPack.writeInt(npack, v.type)
        LDataPack.writeInt(npack, v.id)
        LDataPack.writeInt(npack, v.count)
    end
    LDataPack.writeInt(npack, last_level)
    LDataPack.writeInt(npack, last_id)
    LDataPack.writeInt(npack, math.abs(add)) -- 加了多少星
    LDataPack.flush(npack)
end

-- 领取上周奖励
-- function c2sGetLastWeekAward(actor,packet)
-- 	if not isOpen(actor) then return end
-- 	local var = getActorVar(actor)
-- 	if var.differ_week == 1 and var.get_last_week_award == 0 then 
-- 		local danAward = TianTiDanConfig[var.last_level][var.last_id].danAward
-- 		actoritem.addItems(actor,danAward,"tianti dan award")
-- 		var.get_last_week_award = 1
-- 	end
-- 	s2cTiantiData(actor)
-- end

-- 请求排行榜数据
function c2sRankData(actor, packet)
    tianticross.getRankList(actor)
end

-- 购买挑战次数
function c2sbuyChallengesCount(actor, packet)
    if isOpen(actor) == false then return false end
    local var = getActorVar(actor)
    local vip = LActor.getSVipLevel(actor)
    if var.buy_challenges_count >= SVipConfig[vip].tianti then return end
    if var.challenges_count >= TianTiConstConfig.maxRestoreChallengesCount then return end
    if not actoritem.checkItem(actor, NumericType_YuanBao, TianTiConstConfig.buyChallengesCountYuanBao) then return end
    actoritem.reduceItem(actor, NumericType_YuanBao, TianTiConstConfig.buyChallengesCountYuanBao, "tianti buy")

    var.buy_challenges_count = var.buy_challenges_count + 1
    var.challenges_count = var.challenges_count + 1
    if var.challenges_count >= TianTiConstConfig.maxRestoreChallengesCount then var.last_time = 0 end

    s2cbuyChallengesCount(actor)
    s2cTiantiData(actor)
end

-- 挑战次数回包
function s2cbuyChallengesCount(actor)
    if isOpen(actor) == false then return false end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tianti, Protocol.sTiantiCmd_BuyChallengesCount)
    if npack == nil then return end
    local var = getActorVar(actor)
    LDataPack.writeInt(npack, var.buy_challenges_count)
    LDataPack.flush(npack)
end

function getLevel(actor)
    if isOpen(actor) == false then return 0 end
    local var = getActorVar(actor)
    return var.level
end

function getId(actor)
    if isOpen(actor) == false then return 0 end
    local var = getActorVar(actor)
    return var.id
end

function getWinCount(actor)
    if isOpen(actor) == false then return 0 end
    local var = getActorVar(actor)
    return var.win_count
end

function getOpenLevel()
    return actorexp.getLimitLevel(nil, actorexp.LimitTp.tianti)
end

function getBeginLevel() return TianTiConstConfig.beginLevel end

function setTianti(actor, level, id)
    local var = getActorVar(actor)
    var.level = level
    var.id = id
    updateBasicData(actor)
    s2cTiantiData(actor)
end

function getBeginShowDan() return TianTiConstConfig.beginShowDan end

function getLastTiantiLevel(actor)
    if isOpen(actor) == false then return 0 end
    local var = getActorVar(actor)
    return var.last_level
end

_G.getTiantiBeginLevel = getBeginLevel
_G.getTiantiBeginShowDan = getBeginShowDan
_G.getTiantiOpenLevel = getOpenLevel
_G.tiantiRefreshWeek = refreshWeek

local function onWin(ins, actor)
    if not actor then actor = ins:getActorList()[1] end
    if not actor then return end
    s2cChallengesResult(actor, true)
end

local function onLose(ins, actor)
    if not actor then actor = ins:getActorList()[1] end
    if not actor then return end
    s2cChallengesResult(actor, false)
end

local function onActorCloneDie(ins) ins:win() end

local function onActorDie(ins, actor) ins:lose() end

local function onEnterFuBen(ins, actor)
    -- 设置角色位置
    local var = getActorVar(actor)
    local myPos = TianTiDanConfig[var.level][var.id].myPos
	local role = LActor.getRole(actor)
	LActor.setEntityScenePos(role, myPos[1][1], myPos[1][2])
	local yongbing = LActor.getYongbing(actor)
	if yongbing then
		LActor.setEntityScenePos(yongbing, myPos[2][1], myPos[2][2])
    end
    
    LActor.ClearCD(actor)
    fightActorClone(actor, ins, var.rivalId)
    instancesystem.s2cFightCountDown(actor, 5)
    LActor.postScriptEventLite(actor, 5000, checkHaveClone, ins)
end

local function onExitFb(ins, actor)
    if not ins.is_end then -- 主动退出，以失败处理
        onLose(ins, actor)
    end
end

local function onOffline(ins, actor) LActor.exitFuben(actor) end

-- net end
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeLevel, onLevelUp)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeCustomChange, onCustomChange)



local function fuBenInit()
    for k,v in pairs(TianTiDanConfig) do
        local fbId = v[0].fbId
        insevent.registerInstanceEnter(fbId, onEnterFuBen)
        insevent.registerInstanceWin(fbId, onWin)
        insevent.registerInstanceLose(fbId, onLose)
        insevent.registerInstanceActorDie(fbId, onActorDie)
        insevent.registerInstanceExit(fbId, onExitFb)
        insevent.registerInstanceOffline(fbId, onOffline)
        insevent.regActorCloneDie(fbId, onActorCloneDie)
    end
    tianti_openg = isOpenTime(os.time())

    if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Tianti, Protocol.cTiantiCmd_MatchingActor, c2sMatchingActor)
    netmsgdispatcher.reg(Protocol.CMD_Tianti, Protocol.cTiantiCmd_BeginChallenges, c2sBeginChallenges)
    -- netmsgdispatcher.reg(Protocol.CMD_Tianti, Protocol.cTinatiCmd_GetLastWeekAward, c2sGetLastWeekAward)
    netmsgdispatcher.reg(Protocol.CMD_Tianti, Protocol.cTiantiCmd_RankData, c2sRankData)
    netmsgdispatcher.reg(Protocol.CMD_Tianti, Protocol.cTiantiCmd_BuyChallengesCount, c2sbuyChallengesCount)
end
table.insert(InitFnTable, fuBenInit)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.tiantiopen = function(actor, args)
    OpenTianti()
    return true
end

gmCmdHandlers.tianticlose = function(actor, args)
    CloseTianti()
    return true
end

gmCmdHandlers.tiantimatch = function(actor, args)
    c2sMatchingActor(actor)
    return true
end

gmCmdHandlers.tiantichallenge = function(actor, args)
    local pack = LDataPack.allocPacket()
    LDataPack.writeInt(pack, args[1])
    LDataPack.writeInt(pack, args[2])
    LDataPack.setPosition(pack, 0)
    c2sBeginChallenges(actor)
    return true
end

gmCmdHandlers.tiantibuy = function(actor, args)
    c2sbuyChallengesCount(actor)
    return true
end

gmCmdHandlers.tiantiadd = function(actor, args)
    local count = tonumber(args[1])
    addId(actor, count)
    -- updateBasicData(actor)
    -- tiantirank.updateRankingList(actor, count)
    -- s2cTiantiData(actor)
    return true
end

gmCmdHandlers.tiantirank = function(actor, args)
    c2sRankData(actor)
    return true
end

gmCmdHandlers.tiantireset = function(actor)
    local var = getActorVar(actor)
    var.challenges_count = TianTiConstConfig.maxRestoreChallengesCount
    var.last_time = 0
    s2cTiantiData(actor)
    return true
end

gmCmdHandlers.tiantitest = function(actor)
    local curr_time = os.time()
    local time = utils.getWeeks(curr_time) * week_sec -- 取整周的秒数
    time = time + ((end_week - 1) * day_sec) + refresh_time -- 算出刷新时间
    time = time - (System.getTimeZone() + (3 * day_sec)) -- 时差
    utils.printInfo(time, curr_time, curr_time - time)
end

gmCmdHandlers.ttclone = function (actor, args)
    local rivalId = tonumber(args[1])
    local var = getActorVar(actor)
    var.rivalId = rivalId or LActor.getActorId(actor)
    var.rivalserverid = LActor.getServerId(actor)
    c2sBeginChallenges(actor)
    return true
end


gmCmdHandlers.ttwin = function(actor, args)
    s2cChallengesResult(actor, true)
end
