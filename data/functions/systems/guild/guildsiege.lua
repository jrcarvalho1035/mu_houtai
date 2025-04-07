module("guildsiege", package.seeall)
--战盟入侵

local dailyOpen = false

GUILD_SIEGE_LIST = GUILD_SIEGE_LIST or {}

local function getGlobalData()
	local var = System.getStaticVar()
	if var.guildsiege == nil then
		var.guildsiege = {}
    end
    if not var.guildsiege.eid then var.guildsiege.eid = 0 end
    if not var.guildsiege.refreshtime then var.guildsiege.refreshtime = 0 end
	return var.guildsiege
end

local function getGuildVar(guild)
	local var = LGuild.getStaticVar(guild, true)
    if not var.guildsiege then var.guildsiege = {}	end
    if not var.guildsiege.monstercount then var.guildsiege.monstercount = 0 end
    for i=1, GuildSiegeCommonConfig.mostcount do
        if not var.guildsiege[i] then var.guildsiege[i] = {} end
    end
	return var.guildsiege
end

local function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
    if not var.guildsiege then var.guildsiege = {} end
    if not var.guildsiege.fightcount then var.guildsiege.fightcount = 0 end
	return var.guildsiege
end

--进入公会入侵
function c2sEnter(actor, pack)
    if not GUILD_SIEGE_LIST.dailyOpen then return end
    local var = getActorVar(actor)
    if var.fightcount >= GuildSiegeCommonConfig.fightcount then return end
    local index = LDataPack.readByte(pack)
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then return end
    if not GUILD_SIEGE_LIST[guildId] or not GUILD_SIEGE_LIST[guildId][index] then return end
    local info = GUILD_SIEGE_LIST[guildId][index]
    if info.color == 0 then return end
    if info.status ~= 1 then return end
    info.status = 0

    local x,y = utils.getSceneEnterCoor(GuildSiegeFubenConfig[info.color].fbId)
    local hfuben = instancesystem.createFuBen(GuildSiegeFubenConfig[info.color].fbId)
    local ins = instancesystem.getInsByHdl(hfuben)
    ins.data.guildSiegeIndex = index
    LActor.enterFuBen(actor, hfuben, 0, x, y)
    updateSiegeStatus(guildId, index, info.status, info.color)
end

function updateSiegeStatus(guildId, index, status, color)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_UpdateSiegeStatus)
    LDataPack.writeInt(npack, guildId)
    LDataPack.writeByte(npack, index)
    LDataPack.writeByte(npack, status)
    LDataPack.writeByte(npack, color)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onUpdateSiegeStatus(sId, sType, cpack)
    local guildId = LDataPack.readInt(cpack)
    local index = LDataPack.readByte(cpack)
    local status = LDataPack.readByte(cpack)
    local color = LDataPack.readByte(cpack)
    local guild = LGuild.getGuildById(guildId)
    if not guild then return end
    local guildvar = getGuildVar(guild)
    guildvar[index].color = color
    guildvar[index].status = status

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendSiegeStatus)
    LDataPack.writeInt(npack, guildId)
    LDataPack.writeByte(npack, index)
    LDataPack.writeByte(npack, status)
    LDataPack.writeByte(npack, color)
    System.sendPacketToAllGameClient(npack, 0)
end


local function onRecvSiegeStatus(sId, sType, cpack)
    local guildId = LDataPack.readInt(cpack)
    local index = LDataPack.readByte(cpack)
    local status = LDataPack.readByte(cpack)
    local color = LDataPack.readByte(cpack)
    GUILD_SIEGE_LIST[guildId][index].color = color
    GUILD_SIEGE_LIST[guildId][index].status = status
    updateMonster(guildId, index)
end

--更新单个魔物信息
function updateMonster(guildId, index)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_GuildActity)
    LDataPack.writeByte(pack, Protocol.sGuildActivityCmd_UpdateMonster)
    LDataPack.writeChar(pack, index)
    LDataPack.writeChar(pack, GUILD_SIEGE_LIST[guildId][index].color)
    LDataPack.writeChar(pack, GUILD_SIEGE_LIST[guildId][index].status)
    LGuild.broadcastData(guildId, pack)
end

--发送魔物入侵展示信息
function sendSiegeInfo(actor)
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then return end
    local info = GUILD_SIEGE_LIST[guildId]
    if not info then return end
    local var = getActorVar(actor)

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildActity, Protocol.sGuildActivityCmd_SiegeInfo)
    local remain = GuildSiegeCommonConfig.refreshtime - (System.getNowTime() - GUILD_SIEGE_LIST.refreshtime)
    LDataPack.writeInt(pack, remain > 0 and remain or 0)
    LDataPack.writeChar(pack, GuildSiegeCommonConfig.fightcount - var.fightcount)
    LDataPack.writeChar(pack, GUILD_SIEGE_LIST.dailyOpen)

    local pos = LDataPack.getPosition(pack)
    LDataPack.writeChar(pack, 0)
    if GUILD_SIEGE_LIST.dailyOpen == 0 then
        LDataPack.flush(pack)
        return
    end
    local info = GUILD_SIEGE_LIST[guildId]
    local count = 0
    for i=1, info.monstercount do
        if info[i].color ~= 0 then
            local monsterid = GuildSiegeFubenConfig[info[i].color].monsterid
            LDataPack.writeString(pack, MonstersConfig[monsterid].name)
            LDataPack.writeChar(pack, info[i].color)
            LDataPack.writeChar(pack, info[i].status)
            LDataPack.writeChar(pack, i)
            LDataPack.writeInt(pack, MonstersConfig[monsterid].avatar[1])
            count = count + 1
        end
    end
    local npos = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, pos)
    LDataPack.writeChar(pack, count)
    LDataPack.setPosition(pack, npos)
    LDataPack.flush(pack)
end

--根据帮会人数刷新怪物
function refreshByCount(count, var)
    local conf = nil
    var.monstercount = 0
    for k,v in ipairs(GuildSiegeRefreshConfig) do
        if v.onlinecount[1] <= count and v.onlinecount[2] >= count then
            conf = v
            break
        end
    end
    --优先保底
    for i=1, #conf.min do
        if conf.min[i] > 0 then
            for j=1, conf.min[i] do
                var[var.monstercount + j].color = i
                var[var.monstercount + j].status = 1   --0不可挑战，1可挑战
            end
            var.monstercount = var.monstercount + conf.min[i]
        end
    end
    --随机剩余的
    for i=1, GuildSiegeCommonConfig.mostcount - var.monstercount do
        local total = 0
        for j=1, #conf.probability do
            total = total + conf.probability[j]
            if math.random(1, 100) <= total then
                var.monstercount = var.monstercount + 1
                var[var.monstercount].color = j
                var[var.monstercount].status = 1   --0不可挑战，1可挑战
                break
            end
        end
    end
end

--刷新帮会怪物
function refreshBuildMonster(guild)
    if not actorexp.checkLevelCondition1(actorexp.LimitTp.guildsiege) then return end
    if not dailyOpen then return end
    local guild_id = LGuild.getGuildId(guild)
    local guildvar = getGuildVar(guild)
    refreshByCount(LGuild.getGuildMemberCount(guild), guildvar)
end

--刷新怪物
function refreshMonster()
    if not actorexp.checkLevelCondition1(actorexp.LimitTp.guildsiege) then return end
    local globalvar = getGlobalData()
    globalvar.refreshtime = System.getNowTime()
    if globalvar.eid ~= 0 then
        LActor.cancelScriptEvent(nil, globalvar.eid)
    end
    globalvar.eid = LActor.postScriptEventLite(nil, GuildSiegeCommonConfig.refreshtime * 1000, refreshMonster)
    local guildList = LGuild.getGuildList()
    if guildList == nil then return end
    for i=1,#guildList do
        refreshBuildMonster(guildList[i])
        guildchat.sendNotice(guildList[i], NoticeConfig[noticesystem.NTP.guildsiege].content)
    end
    updateSiegeInfo(nil,nil,true)
end

--胜利
function onFbWin(ins)
    local actor = ins:getActorList()[1]
    if actor == nil then return end
    local index = ins.data.guildSiegeIndex
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then return end
    for k,v in ipairs(GuildSiegeFubenConfig) do
        if v.fbId == ins.id then
            instancesystem.setInsRewards(ins, actor, v.joinDrop)
            local var = getActorVar(actor)
            var.fightcount = var.fightcount + 1

            GUILD_SIEGE_LIST[guildId][index].color = 0
            break
        end
    end
    updateSiegeStatus(guildId, index, GUILD_SIEGE_LIST[guildId][index].status, GUILD_SIEGE_LIST[guildId][index].color)
    sendSiegeInfo(actor)
    -- subactivity1.onKillBoss(actor) -- 策划：打赢+1
end

function onFbLose(ins)
    local actor = ins:getActorList()[1]
    if actor == nil then return end
    local index = ins.data.guildSiegeIndex
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then return end
    for k,v in ipairs(GuildSiegeFubenConfig) do
        if v.fbId == ins.id then
            GUILD_SIEGE_LIST[guildId][index].status = 1
            break
        end
    end

    updateSiegeStatus(guildId, index, GUILD_SIEGE_LIST[guildId][index].status, GUILD_SIEGE_LIST[guildId][index].color)
end


local function onExitFb(ins, actor)
    if not ins.is_end then --主动退出，以失败处理
		ins:lose()
    end
end

local function onOffline(ins, actor)
    local index = ins.data.guildSiegeIndex
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then return end
    for k,v in ipairs(GuildSiegeFubenConfig) do
        if v.fbId == ins.id then
            GUILD_SIEGE_LIST[guildId][index].status = 1
            break
        end
    end

    updateSiegeStatus(guildId, index, GUILD_SIEGE_LIST[guildId][index].status, GUILD_SIEGE_LIST[guildId][index].color)
    LActor.exitFuben(actor)
end

--战盟入侵开始
function guildsiegeStart()
    if not System.isBattleSrv() then return end
    if not actorexp.checkLevelCondition1(actorexp.LimitTp.guildsiege) then return end
    local var = getGlobalData()
    dailyOpen = true
    refreshMonster()
end
_G.guildsiegeStart = guildsiegeStart

--战盟入侵结束
function guildsiegeEnd()
    if not System.isBattleSrv() then return end
    if not actorexp.checkLevelCondition1(actorexp.LimitTp.guildsiege) then return end
    local var = getGlobalData()
    LActor.cancelScriptEvent(nil, var.eid)
    dailyOpen = false
    updateSiegeInfo(nil, nil, true)
end
_G.guildsiegeEnd = guildsiegeEnd

function onConnected(sId, sType)
    if not System.isBattleSrv() then return end
    updateSiegeInfo(nil, sId)
end

function onNewDay(actor, login)
    if not actorexp.checkLevelCondition1(actorexp.LimitTp.guildsiege) then return end
    local var = getActorVar(actor)
    var.fightcount = 0
    if not login then
        sendSiegeInfo(actor)
    end
end

function onInit()
    if not actorexp.checkLevelCondition1(actorexp.LimitTp.guildsiege) then return end
    local now_t = System.getNowTime()
	local year, month, day, _, _, _ = System.timeDecode(now_t)
	local tTbl = GuildSiegeCommonConfig.startTime
	local sTime = System.timeEncode(year, month, day, tTbl[1], tTbl[2], tTbl[3])
	tTbl = GuildSiegeCommonConfig.endTime
	local eTime = System.timeEncode(year, month, day, tTbl[1], tTbl[2], tTbl[3])
	if now_t >= sTime and now_t <= eTime then
		dailyOpen = true
	else
		dailyOpen = false
	end
	local var = getGlobalData()
	local now = System.getNowTime()
    if dailyOpen then
        guildsiegeStart()
    end
end

local function onJoinGuild(actor)
    sendSiegeInfo(actor)
end

function onLogin(actor)
    sendSiegeInfo(actor)
end

function updateSiegeInfo(guild, sId, issend)
    if not System.isBattleSrv() then return end
    local guildList = LGuild.getGuildList()
    if guildList == nil then return end

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_UpdateSiegeInfo)
    local globalvar = getGlobalData()
    LDataPack.writeInt(npack, globalvar.refreshtime)
    LDataPack.writeByte(npack, dailyOpen and 1 or 0)
    local count = guild and 1 or #guildList
    LDataPack.writeShort(npack, count)
    for i=1, count do
        local tguild = guild or guildList[i]
        local guildvar = getGuildVar(tguild)
        LDataPack.writeInt(npack, LGuild.getGuildId(tguild))
        LDataPack.writeByte(npack, guildvar.monstercount)
        for i=1, guildvar.monstercount do
            LDataPack.writeByte(npack, guildvar[i].color)
            LDataPack.writeByte(npack, guildvar[i].status)
        end
    end
    LDataPack.writeByte(npack, issend and 1 or 0)
    System.sendPacketToAllGameClient(npack, sId or 0)
end

local function onRecvSiegeInfo(sId, sType, cpack)
    if System.isCrossWarSrv() then return end
    GUILD_SIEGE_LIST.refreshtime = LDataPack.readInt(cpack)
    GUILD_SIEGE_LIST.dailyOpen = LDataPack.readByte(cpack)
    local guildcount = LDataPack.readShort(cpack)
    for i=1, guildcount do
        local guildId = LDataPack.readInt(cpack)
        GUILD_SIEGE_LIST[guildId] = {}
        GUILD_SIEGE_LIST[guildId].monstercount = LDataPack.readByte(cpack)
        for j=1, GUILD_SIEGE_LIST[guildId].monstercount do
            GUILD_SIEGE_LIST[guildId][j] = {}
            GUILD_SIEGE_LIST[guildId][j].color = LDataPack.readByte(cpack)
            GUILD_SIEGE_LIST[guildId][j].status = LDataPack.readByte(cpack)
        end
    end
    local isSend = LDataPack.readByte(cpack)
    if isSend == 1 then
        local actors = System.getOnlineActorList()
        if actors then
            for i = 1, #actors do
                local guildId = LActor.getGuildId(actors[i])
                if guildId ~= 0 then
                    sendSiegeInfo(actors[i])
                end
            end
        end
    end
    print("recv siege info count = "..guildcount)
end

local function clearTimeEvent()
    local globalvar = getGlobalData()
    globalvar.eid = 0
end

local function init()
    actorevent.reg(aeNewDayArrive, onNewDay)
    if System.isLianFuSrv() then return end
    if System.isCommSrv() then
        netmsgdispatcher.reg(Protocol.CMD_GuildActity, Protocol.cGuildActivityCmd_Siege, c2sEnter)
        actorevent.reg(aeJoinGuild, onJoinGuild)
        actorevent.reg(aeUserLogin, onLogin)
        --注册相关回调
        for _, config in pairs(GuildSiegeFubenConfig) do
            insevent.registerInstanceWin(config.fbId, onFbWin)
            insevent.registerInstanceLose(config.fbId, onFbLose)
            insevent.registerInstanceOffline(config.fbId, onOffline)
            insevent.registerInstanceExit(config.fbId, onExitFb)
        end
    else
        onInit()
        engineevent.regGameStopEvent(clearTimeEvent)
    end
end
table.insert(InitFnTable, init)
csbase.RegConnected(onConnected)

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_UpdateSiegeStatus, onUpdateSiegeStatus)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_UpdateSiegeInfo, onRecvSiegeInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendSiegeStatus, onRecvSiegeStatus)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.gss = function (actor, args)
	guildsiegeStart()
	return true
end

gmCmdHandlers.gse = function (actor, args)
	guildsiegeEnd()
	return true
end

gmCmdHandlers.gsr = function (actor, args)
    refreshMonster()
    return true
end

