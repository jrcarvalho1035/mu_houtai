-- 神魔圣战组队(阵营战)
module("campbattleteam", package.seeall)

local TEAM_MEMBER_MAXCOUNT = CampBattleCommonConfig.maxMember --CampBattleCommonConfig.maxMember --组队人数
local TEAM_MAX_INVITECOUNT = CampBattleCommonConfig.maxInviteMember --邀请列表最大成员数量
local CAMP_COUNT
statusType = {
    tNoMatch = 0, --普通状态
    tInMatch = 1, --匹配状态
    tHaveMatch = 2, --匹配成功(也表示处于布阵状态)
    tMatchReady = 3, --布阵结束,等待进入副本状态
}

TEAMINFO = TEAMINFO or {}
--每支队伍的信息
--队长的actorid作为队伍的id
--[[
    {[队伍id]=
        {
            teamid = 0,         队伍id
            captainid = 0,      队长id
            members = {},       队员和人信息
            memberPos = {},     队员位置索引
            applyList = {},     申请列表
            ravilid = 0,        对手队伍id
            matchTime = 0,      匹配结束时间戳
            readyTime = 0,      布阵结束时间戳
            fightTime = 0,      进入战斗副本时间戳
            camp = 0,           队伍所属阵营
            isClone = 0,        是否为克隆队伍
            status = 0,         队伍状态参考 statusType
            autoApply = 1,      是否自动批准入队
            autoPower = 200000, 批准入队所需战斗力
        }
    }
 
    --members hash
    {
        [玩家id] = {
            actorid = 0,        玩家id
            cloneActorid = 0,   克隆玩家的id,只有克隆队伍才会有
            name = "",          名字
            level = 0,          等级
            isInvite = 0,       奖励状态参考 Fight_type
            power = 0,          战斗力
            job = 0,            职业
            shenqiid = 0,       武器幻化id
            shenzhuangid = 0,   衣服幻化id
            wingid = 0,         翅膀幻化id
            isRobot = 0,        是否为机器人0-不是,1-是
        }
    }
 
    --memberPos array
    {玩家id, 玩家id, 玩家id, 玩家id} 主要用于调整队员在队伍中的位置
 
    --applyList array
    {
        {
            actorid = 0,
            Svip = 0,       
            job = 0,
            power = 0,
            name = "",
        },
    }
]]

TEAMMEMBER = TEAMMEMBER or {}
--玩家的个人信息,方便快速找到自己的队伍
--退出队伍时,这里也需要清除
--[[
    {
        [自己id]={
            teamid = 0,     所在队伍的id
            ismember = 0,   是否为成员，0-队长,1-队员
        }
    }
]]

--返回队伍信息
function getCBTeamData()
    return TEAMINFO
end

--返回单个队伍信息,队长直接返回队伍,如果没有再尝试以队员身份查找队伍
function getCBTeamById(teamId)
    if not TEAMINFO[teamId] then
    end
    return TEAMINFO[teamId]
end

function getCBTeamByActorId(actorId)
    local info = TEAMMEMBER[actorId]
    if not info then return end
    return TEAMINFO[info.teamid]
end

--返回队伍id
local function getCBTeamId(memberId)
    if not TEAMMEMBER[memberId] then return end
    return TEAMMEMBER[memberId].teamid
end

--队伍人数，没队伍就返回最大人数
local function getTeamMemberCount(team)
    if not team then return TEAM_MEMBER_MAXCOUNT end
    return #team.memberPos
end

--队伍人数，没队伍就返回最大人数
local function isTeamFull(team)
    return getTeamMemberCount(team) >= TEAM_MEMBER_MAXCOUNT
end

--已经有队伍
local function isHaveTeam(actorId)
    local info = TEAMMEMBER[actorId]
    if not info then return false end
    return true
end

--有队伍并且是队长
local function isTeamCaptain(actorId)
    local info = TEAMMEMBER[actorId]
    if not info then return false end
    if info.ismember == 1 then return false end
    return true
end

--有队伍并且是队员
local function isTeamMember(actorId)
    local info = TEAMMEMBER[actorId]
    if not info then return false end
    if info.ismember == 0 then return false end
    return true
end

--是不是队友
local function isTeamMate(captainId, memberId)
    local team = getCBTeamByActorId(captainId)
    if not team then return false end
    return team.members[memberId] ~= nil
end

--是不是同阵营
local function isSameCamp(actor, team)
    if not team then return false end
    return team.camp == campbattle.getActorCamp(actor)
end

--是不是机器人
local function isRobotMember(memberId)
    return CampBattleRobotConfig[memberId] ~= nil
end

local function checkMemeberInMatchScene(team)
    local flag = true
    local list = {}
    for actorid, info in pairs(team.members) do
        if info.isRobot == 0 then
            local actor = LActor.getActorById(actorid)
            if actor == nil or LActor.getFubenId(actor) ~= CampBattleCommonConfig.matchFbId then
                table.insert(list, info.name)
                flag = false
            end
        end
    end
    return flag, table.concat(list, "、")
end

--队伍结构数据
local function structCBTeam()
    local team = {
        teamid = 0,
        captainid = 0,
        members = {},
        memberPos = {},
        applyList = {},
        ravilid = 0,
        matchTime = 0,
        readyTime = 0,
        fightTime = 0,
        camp = 0,
        isClone = 0,
        status = statusType.tNoMatch,
        autoApply = 1,
        autoPower = 200000,
    }
    return team
end

local function getCloneName(actorname, confName)
    local config = CampBattleCommonConfig.robotName
    if #config == 0 then return confName end
    local rand = math.random(1, #config)
    local robotName = config[rand]
    local serverName = string.match(actorname, "(%w+).")
    if serverName then
        return serverName.."."..robotName
    else
        return robotName
    end
end

--创建一支克隆队伍
function creatCloneCBTeam(team)
    local camp = team.camp % CAMP_COUNT + 1
    local teamid = -team.teamid
    local cloneTeam = structCBTeam()
    cloneTeam.teamid = teamid
    cloneTeam.isClone = 1
    cloneTeam.camp = camp
    
    local pos = 1
    local captainInfo = team.members[team.captainid]
    for robotId, conf in ipairs(CampBattleRobotConfig) do
        local aInfo = team.members[team.memberPos[pos]]
        if conf.camp == camp then
            cloneTeam.members[robotId] = {
                actorid = robotId,
                cloneActorid = conf.isInvite == 0 and captainInfo.actorid or nil,
                name = conf.isInvite == 1 and conf.name or getCloneName(captainInfo.name, conf.name),
                level = conf.level,
                isInvite = 0,
                power = conf.isInvite == 1 and conf.power or captainInfo.power,
                job = conf.job,
                shenqiid = conf.shenqi,
                shenzhuangid = conf.shenzhuang,
                wingid = conf.wing,
                isRobot = 1,
            }
            table.insert(cloneTeam.memberPos, robotId)
            pos = pos + 1
        end
    end
    TEAMINFO[teamid] = cloneTeam
    return cloneTeam
end

--创建队伍
function creatCBTeam(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.campbattle) then return end
    if not campbattlesystem.isCBCampOpen() then
        LActor.sendTipmsg(actor, ScriptTips.camp010, ttScreenCenter)
        return
    end
    if not campbattlesystem.isCBDayOpen() then
        LActor.sendTipmsg(actor, ScriptTips.camp001, ttScreenCenter)
        return
    end
    if LActor.getFubenId(actor) ~= CampBattleCommonConfig.matchFbId then
        LActor.sendTipmsg(actor, ScriptTips.camp009, ttScreenCenter)
        return
    end
    if not campbattle.checkActorCamp(actor) then return end
    if LActor.getFubenId(actor) ~= CampBattleCommonConfig.matchFbId then
        LActor.sendTipmsg(actor, ScriptTips.camp009, ttScreenCenter)
        return
    end
    local actorid = LActor.getActorId(actor)
    if isHaveTeam(actorid) then
        notifyCBTeamInfo(actorid)
        LActor.sendTipmsg(actor, ScriptTips.camp007, ttScreenCenter)
        return
    end
    
    local teamid = actorid
    local team = structCBTeam()
    team.teamid = teamid
    team.captainid = actorid
    team.camp = campbattle.getActorCamp(actor)
    
    local basic_data = LActor.getActorData(actor)
    team.members[actorid] = {
        actorid = actorid,
        serverid = basic_data.server_index,
        name = basic_data.actor_name,
        level = basic_data.level,
        isInvite = campbattle.getCBFightType(actor),
        power = basic_data.total_power,
        job = basic_data.job,
        shenqiid = shenqisystem.getShenqiId(actor),
        shenzhuangid = shenzhuangsystem.getShenzhuangId(actor),
        wingid = wingsystem.getWingId(actor),
        isRobot = 0,
    }
    table.insert(team.memberPos, actorid)
    
    TEAMINFO[teamid] = team
    TEAMMEMBER[actorid] = {
        teamid = teamid,
        ismember = 0,
    }
    
    notifyCBTeamInfo(teamid) --更新队伍信息
end

--加入队伍
function addCBTeam(team, memberId)
    local actor = LActor.getActorById(memberId)
    if not actor then return end
    if LActor.getFubenId(actor) ~= CampBattleCommonConfig.matchFbId then
        LActor.sendTipmsg(actor, ScriptTips.camp009, ttScreenCenter)
        return
    end
    if isHaveTeam(memberId) then
        local captain_actor = LActor.getActorById(team.captainid)
        LActor.sendTipmsg(captain_actor, ScriptTips.camp007, ttScreenCenter)
        return
    end
    if isTeamFull(team) then
        local captain_actor = LActor.getActorById(team.captainid)
        LActor.sendTipmsg(captain_actor, ScriptTips.camp003, ttScreenCenter)
        return
    end
    if not isSameCamp(actor, team) then
        local captain_actor = LActor.getActorById(team.captainid)
        LActor.sendTipmsg(captain_actor, ScriptTips.camp008, ttScreenCenter)
        return
    end
    
    local basic_data = LActor.getActorData(actor)
    team.members[memberId] = {
        actorid = memberId,
        serverid = basic_data.server_index,
        name = basic_data.actor_name,
        level = basic_data.level,
        isInvite = campbattle.getCBFightType(actor),
        power = basic_data.total_power,
        job = basic_data.job,
        shenqiid = shenqisystem.getShenqiId(actor),
        shenzhuangid = shenzhuangsystem.getShenzhuangId(actor),
        wingid = wingsystem.getWingId(actor),
        isRobot = 0,
    }
    table.insert(team.memberPos, memberId)
    
    local teamId = team.teamid
    TEAMMEMBER[memberId] = {
        teamid = teamId,
        ismember = 1,
    }
    notifyCBTeamInfo(teamId) --更新队伍信息

    local joinName = basic_data.actor_name
    for actorid in pairs(team.members) do
        local actor = LActor.getActorById(actorid)
        LActor.sendTipmsg(actor, string.format(ScriptTips.camp021, joinName), ttScreenCenter)
    end
    return true
end

--添加机器人
function addRobotTeam(team, robotId)
    if not team then return end
    local robotConfig = CampBattleRobotConfig[robotId]
    if not robotConfig then return end
    if robotConfig.isInvite == 0 then return end
    if team.camp ~= robotConfig.camp then return end
    if team.members[robotId] then return end
    if isTeamFull(team) then return end
    
    team.members[robotId] = {
        actorid = robotId,
        name = robotConfig.name,
        level = robotConfig.level,
        isInvite = 0,
        power = robotConfig.power,
        job = robotConfig.job,
        shenqiid = robotConfig.shenqi,
        shenzhuangid = robotConfig.shenzhuang,
        wingid = robotConfig.wing,
        isRobot = 1,
    }
    table.insert(team.memberPos, robotId)
    notifyCBTeamInfo(team.teamid)
end

--申请队伍
function applyTeam(actor, teamId, isInvite)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.campbattle) then return end
    local team = getCBTeamById(teamId)
    if not team then
        LActor.sendTipmsg(actor, ScriptTips.camp002, ttScreenCenter)
        return
    end
    if isTeamFull(team) then
        LActor.sendTipmsg(actor, ScriptTips.camp003, ttScreenCenter)
        return
    end
    local actorid = LActor.getActorId(actor)
    if isHaveTeam(actorid) then
        LActor.sendTipmsg(actor, ScriptTips.camp018, ttScreenCenter)
        return
    end
    if not isSameCamp(actor, team) then
        LActor.sendTipmsg(actor, ScriptTips.camp008, ttScreenCenter)
        return
    end
    
    local basic_data = LActor.getActorData(actor)
    local actorPower = basic_data.total_power
    if isInvite == 1 then
        addCBTeam(team, actorid)
    elseif team.autoApply == 1 and actorPower >= team.autoPower then
        addCBTeam(team, actorid)
    else
        local applyList = team.applyList
        for _, info in ipairs(applyList) do
            if info.actorid == actorid then
                LActor.sendTipmsg(actor, ScriptTips.camp015, ttScreenCenter)
                return
            end
        end
        local info = {
            actorid = actorid,
            svipLevel = LActor.getSVipLevel(actor),
            job = basic_data.job,
            power = basic_data.total_power,
            name = basic_data.actor_name,
        }
        table.insert(applyList, 1, info)
        local captain_actor = LActor.getActorById(team.captainid)
        s2cCBTeamApplyJoin(captain_actor, #applyList)
        LActor.sendTipmsg(actor, ScriptTips.camp014, ttScreenCenter)
    end
end

--处理申请队伍
function respondApplyTeam(actor, memberId, ret)
    local actorid = LActor.getActorId(actor)
    if not isTeamCaptain(actorid) then
        LActor.sendTipmsg(actor, ScriptTips.camp006, ttScreenCenter)
        return
    end
    local team = getCBTeamByActorId(actorid)
    if not team then return end
    local applyList = team.applyList
    local index = 0
    for idx, info in ipairs(applyList) do
        if info.actorid == memberId then
            index = idx
        end
    end
    if index == 0 then return end
    local memName = LActor.getActorName(memberId)
    if ret == 1 then
        if addCBTeam(team, memberId) then
            table.remove(applyList, index)
            --LActor.sendTipmsg(actor, string.format(ScriptTips.camp016, memName), ttScreenCenter)
        end
    else
        table.remove(applyList, index)
        LActor.sendTipmsg(actor, string.format(ScriptTips.camp017, memName), ttScreenCenter)
    end
end

--退出队伍(包括主动与被动)
function quitCBTeam(actorId, isKick)
    local team = getCBTeamByActorId(actorId)
    if not team then return end
    
    TEAMMEMBER[actorId] = nil
    team.members[actorId] = nil
    for index, memberId in ipairs(team.memberPos) do
        if memberId == actorId then
            table.remove(team.memberPos, index)
            break
        end
    end
    
    notifyCBTeamInfo(team.teamid) --发送队伍更新信息
    
    if isKick then
        local actor = LActor.getActorById(actorId)
        s2cCBTeamSpurn(actor)
        LActor.sendTipmsg(actor, ScriptTips.camp004, ttScreenCenter)
    end
end

--将机器人踢出队伍
function quitRobotTeam(team, robotId)
    team.members[robotId] = nil
    for index, memberId in ipairs(team.memberPos) do
        if memberId == robotId then
            table.remove(team.memberPos, index)
        end
    end
    notifyCBTeamInfo(team.teamid) --发送队伍更新信息
end

--解散队伍,队长id也是队伍id
function breakTeam(actorid)
    local teamid = getCBTeamId(actorid) or actorid
    local team = TEAMINFO[teamid]
    if not team then return end
    for actorid in pairs(team.members) do
        TEAMMEMBER[actorid] = nil
        local actor = LActor.getActorById(actorid)
        if actor then
            s2cCBTeamBreak(actor)
        end
    end
    TEAMINFO[teamid] = nil
end

--主动退出队伍
function exitCBTeam(actor, actorid)
    local actorid = actorid or LActor.getActorId(actor)
    local team = getCBTeamByActorId(actorid)
    if campbattle.isTeamLock(team) then
        --LActor.sendTipmsg(actor, ScriptTips.camp004, ttScreenCenter)
        return
    end
    if not isHaveTeam(actorid) then return end
    if isTeamCaptain(actorid) then
        breakTeam(actorid)
    elseif isTeamMember(actorid) then
        quitCBTeam(actorid)
    end
end

--向队伍中的人发送组队信息
function notifyCBTeamInfo(teamId)
    local team = getCBTeamById(teamId)
    if not team then return end
    for actorid in pairs(team.members) do
        local actor = LActor.getActorById(actorid)
        if actor and LActor.getFubenId(actor) == CampBattleCommonConfig.matchFbId then
            s2cCBTeamInfo(actor, teamId)
        end
    end
end

--队长给其他玩家发送组队邀请
function sendCBTeamInvite(teamId, name, vipLevel, svipLevel, actorid)
    local team = getCBTeamById(teamId)
    if not team then return end
    if isTeamFull(team) then return end
    local actor = LActor.getActorById(actorid)
    if actor and campbattle.checkCBInviteCD(actor) then
        campbattle.setCBInviteCD(actor)
        s2cCBTeamInviteInfo(actor, teamId, name, vipLevel, svipLevel)
    end
end

--发送邀请列表给队长
function sendInviteList(actor)
    local actorid = LActor.getActorId(actor)
    if not isTeamCaptain(actorid) then return end
    local team = getCBTeamByActorId(actorid)
    if not team then return end
    local camp = campbattle.getActorCamp(actor)
    local campList = campbattle.getCampList()
    local sendList = {}
    local count = 0
    for actorid, info in pairs(campList) do
        repeat
            if isHaveTeam(actorid) then break end
            if info.isShow ~= 1 then break end
            if info.camp ~= camp then break end
            table.insert(sendList, info)
            count = count + 1
            if count >= TEAM_MAX_INVITECOUNT then
                break
            end
        until true
    end
    
    --将机器人加入邀请列表
    local members = team.members
    for robotId, conf in ipairs(CampBattleRobotConfig) do
        if conf.isInvite == 1 and conf.camp == camp and members[conf.id] == nil then
            local info = {
                actorid = conf.id,
                job = conf.job,
                power = conf.power,
                name = conf.name,
                isRobot = 1,
            }
            table.insert(sendList, info)
        end
    end
    s2cCBTeamInviteList(actor, sendList)
end

function sendMatchInfo(teamId)
    local team = getCBTeamById(teamId)
    if not team then return end
    for actorid in pairs(team.members) do
        local actor = LActor.getActorById(actorid)
        if actor then
            s2cCBTeamMatch(actor, team)
        end
    end
end

function sendCancelMatch(teamId, isCancel)
    local team = getCBTeamById(teamId)
    if not team then return end
    for actorid in pairs(team.members) do
        local actor = LActor.getActorById(actorid)
        if actor then
            s2cCBTeamCancelMatch(actor, team)
            if isCancel then
                LActor.sendTipmsg(actor, ScriptTips.camp011, ttScreenCenter)
            else
                LActor.sendTipmsg(actor, ScriptTips.camp019, ttScreenCenter)
            end
        end
    end
end

function changePos(actor, pos1, pos2)
    local actorid = LActor.getActorId(actor)
    if not isTeamCaptain(actorid) then return end
    local team = getCBTeamByActorId(actorid)
    if not team then return end
    if not (team.memberPos[pos1] and team.memberPos[pos2]) then return end
    if not campbattle.isTeamMatchHave(team) then return end
    if campbattle.isTeamMatchReady(team) then return end
    team.memberPos[pos1], team.memberPos[pos2] = team.memberPos[pos2], team.memberPos[pos1]
    s2cCBTeamInfo(actor, team.teamid)
end

function setAutoApply(actor, ret, power)
    if power < 0 then return end
    local actorid = LActor.getActorId(actor)
    if not isTeamCaptain(actorid) then return end
    local team = getCBTeamByActorId(actorid)
    if not team then return end
    team.autoApply = ret
    team.autoPower = power
    notifyCBTeamInfo(team.teamid)
end

----------------------------------------------------------------------------------
--协议处理
local function writeTeamInfo(pack, info)
    if info then
        LDataPack.writeInt(pack, info.actorid)
        LDataPack.writeString(pack, info.name)
        LDataPack.writeInt(pack, info.level)
        LDataPack.writeDouble(pack, info.power)
        LDataPack.writeChar(pack, info.job)
        LDataPack.writeByte(pack, isTeamCaptain(info.actorid) and 1 or 0)
        LDataPack.writeChar(pack, info.isInvite)
        LDataPack.writeInt(pack, info.shenqiid)
        LDataPack.writeInt(pack, info.shenzhuangid)
        LDataPack.writeInt(pack, info.wingid)
    else
        LDataPack.writeInt(pack, 0)
        LDataPack.writeString(pack, "")
        LDataPack.writeInt(pack, 0)
        LDataPack.writeDouble(pack, 0)
        LDataPack.writeChar(pack, 0)
        LDataPack.writeByte(pack, 0)
        LDataPack.writeChar(pack, 0)
        LDataPack.writeInt(pack, 0)
        LDataPack.writeInt(pack, 0)
        LDataPack.writeInt(pack, 0)
    end
end

--89-1 创建一支队伍
local function c2sCBCreateTeam(actor)
    creatCBTeam(actor)
end

--89-1 更新队伍信息
function s2cCBTeamInfo(actor, teamId)
    local team = getCBTeamById(teamId)
    if not team then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_TeamInfo)
    if pack == nil then return end
    LDataPack.writeInt(pack, team.teamid)
    LDataPack.writeChar(pack, team.autoApply)
    LDataPack.writeDouble(pack, team.autoPower)
    LDataPack.writeChar(pack, TEAM_MEMBER_MAXCOUNT)
    for idx = 1, TEAM_MEMBER_MAXCOUNT do
        local memberId = team.memberPos[idx]
        local info = team.members[memberId]
        writeTeamInfo(pack, info)
    end
    LDataPack.flush(pack)
end

--89-2 组队邀请
local function c2sCBTeamInvite(actor, packet)
    local count = LDataPack.readChar(packet)
    local list = {}
    for i = 1, count do
        local aid = LDataPack.readInt(packet)
        table.insert(list, aid)
    end
    
    local actorid = LActor.getActorId(actor)
    if not isTeamCaptain(actorid) then return end
    
    local name = LActor.getName(actor)
    local vipLevel = LActor.getVipLevel(actor)
    local svipLevel = LActor.getSVipLevel(actor)
    local team = getCBTeamByActorId(actorid)
    for _, aid in ipairs(list) do
        if isRobotMember(aid) then
            addRobotTeam(team, aid)
        else
            sendCBTeamInvite(team.teamid, name, vipLevel, svipLevel, aid)
        end
    end
end

--89-2 给被邀请人发送组队邀请
function s2cCBTeamInviteInfo(actor, teamId, name, vipLevel, svipLevel)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_TeamInvite)
    if not pack then return end
    LDataPack.writeInt(pack, teamId) --队长的id
    LDataPack.writeString(pack, name)
    LDataPack.writeChar(pack, vipLevel)
    LDataPack.writeChar(pack, svipLevel)
    LDataPack.flush(pack)
end

--89-3 请求邀请列表
local function c2sCBTeamInviteList(actor)
    sendInviteList(actor)
end

--89-3 返回邀请列表
function s2cCBTeamInviteList(actor, list)
    if not actor then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_TeamInviteList)
    if not pack then return end
    LDataPack.writeChar(pack, #list)
    for i, info in ipairs(list) do
        LDataPack.writeInt(pack, info.actorid)
        --LDataPack.writeInt(pack, info.svipLevel)
        LDataPack.writeByte(pack, info.job)
        LDataPack.writeDouble(pack, info.power)
        LDataPack.writeString(pack, info.name)
        LDataPack.writeChar(pack, info.isRobot and 1 or 0)
    end
    LDataPack.flush(pack)
end

--89-4 请求申请入队
local function c2sCBTeamApplyJoin(actor, packet)
    local teamId = LDataPack.readInt(packet)
    local ret = LDataPack.readChar(packet)
    applyTeam(actor, teamId, ret)
end

--89-4 通知队长有新的组队申请
function s2cCBTeamApplyJoin(actor, count)
    if not actor then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_TeamApplyJoin)
    if not pack then return end
    LDataPack.flush(pack)
    s2cCBTeamReqApplyList(actor)
end

--89-5 处理组队申请
local function c2sCBTeamRespondJoin(actor, packet)
    local joinList = {}
    local count = LDataPack.readChar(packet)
    for i = 1, count do
        local memberId = LDataPack.readInt(packet)
        local ret = LDataPack.readChar(packet)
        respondApplyTeam(actor, memberId, ret)
    end
    s2cCBTeamReqApplyList(actor)
end

--89-6 请求申请列表
local function c2sCBTeamReqApplyList(actor)
    local actorid = LActor.getActorId(actor)
    if not isTeamCaptain(actorid) then return end
    s2cCBTeamReqApplyList(actor)
end

--89-6 返回申请列表
function s2cCBTeamReqApplyList(actor)
    local actorid = LActor.getActorId(actor)
    local team = getCBTeamByActorId(actorid)
    if not team then return end
    local applyList = team.applyList
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_TeamReqApplyList)
    if pack == nil then return end
    
    LDataPack.writeInt(pack, #applyList)
    for i, info in ipairs(applyList) do
        LDataPack.writeInt(pack, info.actorid)
        LDataPack.writeInt(pack, info.svipLevel)
        LDataPack.writeByte(pack, info.job)
        LDataPack.writeDouble(pack, info.power)
        LDataPack.writeString(pack, info.name)
    end
    LDataPack.flush(pack)
end

--89-7 踢走队员
local function c2sCBTeamSpurn(actor, packet)
    local memberId = LDataPack.readInt(packet)
    local actorid = LActor.getActorId(actor)
    if actorid == memberId then return end
    if not isTeamCaptain(actorid) then return end
    if not isTeamMate(actorid, memberId) then return end
    
    local team = getCBTeamByActorId(actorid)
    if not campbattle.isTeamMatchNone(team) then
        LActor.sendTipmsg(actor, ScriptTips.camp005, ttScreenCenter)
        return
    end
    if team.members[memberId].isRobot == 0 then
        quitCBTeam(memberId, true)
    else
        quitRobotTeam(team, memberId)
    end
end

--89-7 踢走队员（其他人通过89-1返回）
function s2cCBTeamSpurn(actor)
    if not actor then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_TeamSpurn)
    if pack == nil then return end
    LDataPack.flush(pack)
end

--89-8 退出或解散队伍
local function c2sCBTeamBreak(actor)
    exitCBTeam(actor)
end

--89-8 队伍被解散
function s2cCBTeamBreak(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_TeamBreak)
    if pack == nil then return end
    LDataPack.flush(pack)
end

--89-9 请求调整出战顺序
local function c2sCBChangePos(actor, packet)
    local pos1 = LDataPack.readChar(packet)
    local pos2 = LDataPack.readChar(packet)
    changePos(actor, pos1, pos2)
end

--89-10 进入匹配
local function c2sCBTeamMatch(actor)
    if not campbattlesystem.isCBCampOpen() then
        LActor.sendTipmsg(actor, ScriptTips.camp010, ttScreenCenter)
        return
    end
    if not campbattlesystem.isCBDayOpen() then
        LActor.sendTipmsg(actor, ScriptTips.camp001, ttScreenCenter)
        return
    end
    local actorid = LActor.getActorId(actor)
    if not isTeamCaptain(actorid) then return end
    local team = getCBTeamByActorId(actorid)
    if not team then return end
    if not isTeamFull(team) then return end
    
    local ret, actorNames = checkMemeberInMatchScene(team)
    if not ret then
        LActor.sendTipmsg(actor, string.format(ScriptTips.camp020, actorNames), ttScreenCenter)
        return
    end
    campbattle.matchCBRival(team)
end

--89-10 返回匹配信息
function s2cCBTeamMatch(actor, team)
    local nextTime = 0
    local memberCount = TEAM_MEMBER_MAXCOUNT
    
    -- local actorid = LActor.getActorId(actor)
    -- local team = getCBTeamByActorId(actorid)
    -- if not team then return end
    local ravil
    
    if campbattle.isTeamMatchIn(team) then
        nextTime = team.matchTime
    elseif campbattle.isTeamMatchHave(team) then
        ravil = getCBTeamById(team.ravilid)
        nextTime = team.readyTime
    elseif campbattle.isTeamMatchReady(team) then
        ravil = getCBTeamById(team.ravilid)
        nextTime = team.fightTime
    else
        return
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_TeamMatch)
    if pack == nil then return end
    LDataPack.writeChar(pack, team.status)
    LDataPack.writeInt(pack, nextTime)
    LDataPack.writeChar(pack, memberCount)
    for idx = 1, memberCount do
        local memberId = ravil and ravil.memberPos[idx]
        local info = ravil and ravil.members[memberId]
        writeTeamInfo(pack, info)
    end
    LDataPack.flush(pack)
end

--89-11 取消匹配
local function c2sCBTeamCancelMatch(actor)
    local actorid = LActor.getActorId(actor)
    if not isTeamCaptain(actorid) then return end
    campbattle.matchCancelCBRival(actorid)
end

--89-11 返回匹配状态
function s2cCBTeamCancelMatch(actor, team)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_TeamCancelMatch)
    if pack == nil then return end
    LDataPack.writeChar(pack, team.status)
    LDataPack.flush(pack)
end

--89-12 请求队伍列表
local function c2sCBTeamList(actor)
    s2cCBTeamList(actor)
end

--89-12 返回队伍列表
function s2cCBTeamList(actor)
    local camp = campbattle.getActorCamp(actor)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_TeamList)
    if pack == nil then return end
    local count = 0
    local pos = LDataPack.getPosition(pack)
    LDataPack.writeInt(pack, count) -- 长度
    local teamData = getCBTeamData()
    for teamId, team in pairs(teamData) do
        repeat
            if camp ~= team.camp then break end
            if isTeamFull(team) then break end
            
            LDataPack.writeInt(pack, team.teamid)
            LDataPack.writeChar(pack, TEAM_MEMBER_MAXCOUNT)
            for idx = 1, TEAM_MEMBER_MAXCOUNT do
                local memberId = team.memberPos[idx]
                local info = team.members[memberId]
                if info then
                    LDataPack.writeInt(pack, memberId)
                    LDataPack.writeChar(pack, info.job)
                    LDataPack.writeDouble(pack, info.power)
                    LDataPack.writeString(pack, info.name)
                    LDataPack.writeByte(pack, isTeamCaptain(memberId) and 1 or 0)
                else
                    LDataPack.writeInt(pack, 0)
                    LDataPack.writeChar(pack, 0)
                    LDataPack.writeDouble(pack, 0)
                    LDataPack.writeString(pack, "")
                    LDataPack.writeByte(pack, 0)
                end
            end
            count = count + 1
        until true
    end
    
    local pos2 = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, pos)
    LDataPack.writeInt(pack, count)
    LDataPack.setPosition(pack, pos2)
    LDataPack.flush(pack)
end

--89-13 设置自动同意申请
local function c2sCBTeamAutoApply(actor, packet)
    local ret = LDataPack.readChar(packet)
    local power = LDataPack.readDouble(packet)
    setAutoApply(actor, ret, power)
end

----------------------------------------------------------------------------------
--事件处理

--退出登录，就退出队伍或解散队伍
local function onActorLogout(actor)
    local actorid = LActor.getActorId(actor)
    local team = getCBTeamByActorId(actorid)
    if not team then return end
    if campbattle.isTeamMatchIn(team) then
        campbattle.setTeamMatchNone(team)
    end
    exitCBTeam(actor)
end

local function onEnterFb(ins, actor)
    campbattle.setActorInviteIn(actor)
    
    local actorid = LActor.getActorId(actor)
    local team = getCBTeamByActorId(actorid)
    if not team then return end
    s2cCBTeamInfo(actor, team.teamid)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    CAMP_COUNT = campbattle.CAMP_COUNT
    if not System.isBattleSrv() then return end
    --if System.isBattleSrv() then return end
    
    actorevent.reg(aeUserLogout, onActorLogout)
    
    insevent.registerInstanceEnter(CampBattleCommonConfig.matchFbId, onEnterFb)
    
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_CreateTeam, c2sCBCreateTeam)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_TeamInvite, c2sCBTeamInvite)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_TeamInviteList, c2sCBTeamInviteList)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_TeamApplyJoin, c2sCBTeamApplyJoin)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_TeamRespondJoin, c2sCBTeamRespondJoin)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_TeamReqApplyList, c2sCBTeamReqApplyList)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_TeamSpurn, c2sCBTeamSpurn)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_TeamBreak, c2sCBTeamBreak)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_TeamChangePos, c2sCBChangePos)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_TeamMatch, c2sCBTeamMatch)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_TeamCancelMatch, c2sCBTeamCancelMatch)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_TeamList, c2sCBTeamList)
    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_TeamAutoApply, c2sCBTeamAutoApply)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------

function gmBreakCBteam(actorid)
    print("on gmBreakCBteam")
    local teamid = getCBTeamId(actorid) or actorid
    local team = TEAMINFO[teamid]
    if not team then return end
    for actorid in pairs(team.members) do
        TEAMMEMBER[actorid] = nil
        local actor = LActor.getActorById(actorid)
        if actor then
            s2cCBTeamBreak(actor)
        end
    end
    TEAMINFO[teamid] = nil
end

--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.teamInfo = function (actor, args)
    print("*******TEAMINFO*******")
    utils.printTable(TEAMINFO)
    print("**********************")
    
    print("*******TEAMMEMBER*******")
    utils.printTable(TEAMMEMBER)
    print("************************")
end

gmCmdHandlers.clearTeam = function (actor, args)
    TEAMINFO = {}
    TEAMMEMBER = {}
end

gmCmdHandlers.creatTeam = function (actor, args)
    creatCBTeam(actor)
end

gmCmdHandlers.addTeam = function (actor, args)
    local teamId = tonumber(args[1]) or 0
    addCBTeam(actor, teamId)
end

gmCmdHandlers.quitTeam = function (actor, args)
    exitCBTeam(actor)
end

gmCmdHandlers.kickTeamer = function (actor, args)
    local memberId = tonumber(args[1]) or 0
    quitCBTeam(memberId, true)
end

