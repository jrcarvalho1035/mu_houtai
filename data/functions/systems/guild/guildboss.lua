module("guildboss", package.seeall)
require("guild.guildboss")
require("guild.guildbosscommon")

local ACTIVE_BUILDING_INDEX = 4
g_guildbossHf = g_guildbossHf or {}
GUILD_BOSS_INFO = GUILD_BOSS_INFO or {}
local function getGlobalData()
	local var = System.getStaticVar()
	if not var then return end
	if not var.guildbossWeek then var.guildbossWeek = {} end
	if not var.guildbossWeek.weekDay then var.guildbossWeek.weekDay = 0 end
	if not var.guildbossWeek.updateTime then var.guildbossWeek.updateTime = 0 end
	return var.guildbossWeek
end

local function getGuildVar(guild)
	local var = LGuild.getStaticVar(guild, true)
	if not var.bossData then
		var.bossData = {
			idx = 1,
            hpPercent = 10000,
            updateTime = 0,
		}
	end
	return var.bossData
end

local function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.guildbossData then
		var.guildbossData = {
			count = 0, 			--今天挑战次数
			rewardsRecord = 0, 	--领奖记录
		}
	end
	if not var.guildbossData.weekDay then var.guildbossData.weekDay = 0 end
	if not var.guildbossData.canget then var.guildbossData.canget = 0 end --当前能否领取奖励
	return var.guildbossData
end

function checkFightCount(actor)
	local var = getActorVar(actor)
	if not var then return end
	return var.count < GuildBossCommonConfig.count
end

function getFightCount(actor)
	local var = getActorVar(actor)
	if not var then return end
	return var.count
end

function RefreshGuildBoss(guild, idx)
	local gvar = getGuildVar(guild)
	local conf = GuildBossConfig[idx]
	if not conf then return end
	local hfuben = instancesystem.createFuBen(conf.fbId)
	gvar.idx = idx
	gvar.bossId = conf.bossId
	g_guildbossHf[guild] = hfuben

	--把boss的血量设为上次保存好的血量
	local ins = instancesystem.getInsByHdl(hfuben)
	local handle = ins.scene_list[1]
	local scene = Fuben.getScenePtr(handle)
	local monster = Fuben.getSceneMonsterById(scene, conf.bossId)
	local hp = math.ceil(LActor.getHpMax(monster) * gvar.hpPercent / 10000)
	LActor.setHp(monster, hp)
end

--计算下一次刷新的时间
function getEndTime()
	local week = os.date("%w")
	local t = (7 - week) * 24 * 3600 --到下周日的时间
	local now = os.time()
	local ndate = os.date("*t", now + t)
	local et = os.time({year=ndate.year, month=ndate.month, day=ndate.day, hour=24})--到周日24点的时间戳
	return et - now
end

--强制退出副本
local function forceExitFuben(actor, ins)
	if LActor.isInFuben(actor) then
		local value = bossinfo.getBossDamage(actor, ins)
		ins:setExtraData3(LActor.getActorId(actor), value)
		ins:notifyRewards(actor, true, true)
		LActor.exitFuben(actor)
	end
end

-- --意外处理战盟BOSS未打完但血量为0的情况
-- function dealGuildBossHp0(guild)
-- 	if not guild then return end
-- 	local gvar = getGuildVar(guild)
-- 	if not gvar then return end
-- 	if gvar.hpPercent > 0 then return end
-- 	gvar.idx = gvar.idx + 1 --打完所有boss后idx会比最高位多1
-- 	if GuildBossConfig[gvar.idx] then
-- 		gvar.hpPercent = 10000
-- 	end
-- 	g_guildbossHf[guild] = nil
-- end

---------------------------------------------------------------------------------------------------
--查看战盟BOSS信息
function c2sGuildBossInfo(actor, packet)
	s2cGuildBossInfo(actor)
end

function s2cGuildBossInfo(actor)
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end
	if not GUILD_BOSS_INFO[guildId] then return end
	local var = getActorVar(actor)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildActity, Protocol.sGuildActivityCmd_BossInfo)
	if pack == nil then return end
	LDataPack.writeShort(pack, GUILD_BOSS_INFO[guildId].idx)
	LDataPack.writeShort(pack, var.count)
	LDataPack.writeShort(pack, GUILD_BOSS_INFO[guildId].hpPercent)
	LDataPack.writeInt(pack, var.rewardsRecord)
	LDataPack.writeInt(pack, getEndTime())
	LDataPack.flush(pack)
end

--战盟BOSS领取奖励
function c2sGuildBossReward(actor, packet)
	local idx = LDataPack.readShort(packet)
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end
	if not GUILD_BOSS_INFO[guildId] then return end
	local var = getActorVar(actor)
	if not var then return end

	local conf = GuildBossConfig[idx]
	if not conf then return end
	if idx >= GUILD_BOSS_INFO[guildId].idx then return end
	if idx == GUILD_BOSS_INFO[guildId].idx and GUILD_BOSS_INFO[guildId].hpPercent > 0 then return end
	if System.bitOPMask(var.rewardsRecord, idx) then --已领取
		return
	end
	var.rewardsRecord = System.bitOpSetMask(var.rewardsRecord, idx, true)
	actoritem.addItems(actor, conf.passRewards, "guild boss pass")
	s2cGuildBossReward(actor, GUILD_BOSS_INFO[guildId].idx, var.rewardsRecord)
end

function s2cGuildBossReward(actor, idx, record)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildActity, Protocol.sGuildActivityCmd_BossReward)
	if pack == nil then return end
	LDataPack.writeShort(pack, idx)
	LDataPack.writeInt(pack, record)
	LDataPack.flush(pack)
end

--战盟BOSS挑战
function c2sGuildBossFight(actor, packet)
	if not actorlogin.checkCanEnterCross(actor) then return end
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then
		print("guildboss not guildId")
		return
	end
	if System.isCommSrv() then
		if not GUILD_BOSS_INFO[guildId] then return end
		local var = getActorVar(actor)
		if not var then return end
		-- if GuildBossConfig[gvar.idx] and gvar.hpPercent <= 0 then --处理未知的BOSS血量为0的情况
		-- 	dealGuildBossHp0(guild)
		-- end
		local conf = GuildBossConfig[GUILD_BOSS_INFO[guildId].idx]
		if not conf then 
			print("guildboss not config")
			return 
		end --表示boss已打完
		if var.count >= GuildBossCommonConfig.count then --次数不够不能主动挑战
			print("guildboss count not enough")
			return
		end
		local hfuben = GUILD_BOSS_INFO[guildId].hfuben
		-- if (not hfuben) or (not instancesystem.getInsByHdl(hfuben)) then --副本可能出错被毁
		-- 	RefreshGuildBoss(guild, gvar.idx)
		-- end
		if not hfuben or hfuben <= 0 then
			print("guildboss not hfuben")
			return
		end
		local blv = guildcommon.getBuildingLevelById(guildId, ACTIVE_BUILDING_INDEX)
		if blv < GuildBossConfig[GUILD_BOSS_INFO[guildId].idx].level then --等级不足
			print("guildboss blv is not enough")
			return
		end

		local actorId = LActor.getActorId(actor)
		if guildbossteam.isTeamMember(actorId) then --作为队员不能主动进副本
			print("guildboss isTeamMember")
			return
		end

		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetReadyEnter)
		LDataPack.writeInt(npack, actorId)
		LDataPack.writeInt(npack, guildId)
		System.sendPacketToAllGameClient(npack, 0)
	else
		local guild = LGuild.getGuildById(guildId)
		local gvar = getGuildVar(guild)
		if not gvar then return end
		local conf = GuildBossConfig[gvar.idx]
		if not conf then return end --表示boss已打完
		enterfb(actor, conf, g_guildbossHf[guild])
	end
end

local function onGetReadyEnter(sId, sType, cpack)
	local actorId = LDataPack.readInt(cpack)
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendReadyEnter)
	LDataPack.writeInt(npack, actorId)
	LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	System.sendPacketToAllGameClient(npack, 0)
	guildbossteam.breakTeam(actorId) --进入副本后队伍解散
end

local function onSendReadyEnter(sId, sType, cpack)
	local actorId = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)
	if not GUILD_BOSS_INFO[guildId] then return end
	local mcount = guildbossteam.getTeamMemberCount(actorId)
	for k, v in pairs(guildbossteam.getTeam(actorId)) do
		local tor = LActor.getActorById(v)
		if tor then
			fightGuildboss(tor, mcount, GuildBossConfig[GUILD_BOSS_INFO[guildId].idx], GUILD_BOSS_INFO[guildId].hfuben, actorId)
		end
	end
	guildbossteam.breakTeam(actorId) --进入副本后队伍解散
end

--挑战战盟BOSS
function fightGuildboss(actor, mcount, conf, hfuben, teamId)
	local var = getActorVar(actor)
	var.canget = 0
	if var.count < GuildBossCommonConfig.count then --如果还有挑战次数，挑战时会得到奖励
		var.count = var.count + 1
		var.canget = 1
	end
	var.mcount = mcount

	local x, y = utils.getSceneEnterCoor(conf.fbId)
	actorcommon.setTeamId(actor, teamId)
	enterfb(actor, conf.fbId, hfuben)
	s2cGuildBossInfo(actor)
end

function enterfb(actor, fbId, hfuben)
	if hfuben == 0 then return end

	if LActor.isDeath(actor) then return end

	local x,y = utils.getSceneEnterCoor(fbId)
	if System.isCommSrv() then
		--actorevent.onEvent(actor, aeEnterFuben, fbId, false)
		local crossId = csbase.getCrossServerId()
		LActor.loginOtherServer(actor, crossId, hfuben, 0, x, y, "cross")
	elseif System.isBattleSrv() then
		local ret = LActor.enterFuBen(actor, hfuben, 0, x, y)
		if not ret then
			utils.printInfo("fight guild boss fail", ret, hfuben)
		end
	end
	print("guild boss enterfb end")
	return true
end

--战盟进入挑战
function s2cGuildBossFight(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildActity, Protocol.sGuildActivityCmd_BossFight)
	if pack == nil then return end
	LDataPack.writeInt(pack, 0)
	LDataPack.flush(pack)
end

function checkBossDestroy(guildId)
	local guild = LGuild.getGuildById(guildId)
	local hfuben = g_guildbossHf[guild]
	local gvar = getGuildVar(guild)
	if not gvar then return end
	if (not hfuben) or (not instancesystem.getInsByHdl(hfuben)) then --副本可能出错被毁             
		RefreshGuildBoss(guild, gvar.idx)
		updateGuildBossInfo(guild)
	elseif gvar.hpPercent <=0 and GuildBossConfig[gvar.idx+1] then
		gvar.idx = gvar.idx+1
		gvar.hpPercent = 10000
		RefreshGuildBoss(guild, gvar.idx)
		updateGuildBossInfo(guild)
	end
end

local function onBossDie(ins)
	local actors = ins:getActorList()
	for i = 1, #actors do
		local actor = actors[i]
		local value = bossinfo.getBossDamage(actor, ins)
		ins:setExtraData3(LActor.getActorId(actor), value)
		subactivity1.onKillBoss(actor)
	end
	ins:win()
	local guildId = LActor.getGuildId(actors[1])
	if guildId == 0 then return end
	local guild = LGuild.getGuildById(guildId)
	local gvar = getGuildVar(guild)
	if not gvar then return end
	gvar.idx = gvar.idx + 1 --打完所有boss后idx会比最高位多1
	print("Guild Boss onBossDie", guildId, gvar.idx)
	gvar.hpPercent = 10000
	g_guildbossHf[guild] = nil
	RefreshGuildBoss(guild, gvar.idx)
	updateGuildBossInfo(guild)
end

local function onBossDamage(ins, monster, value, attacker)
	local actor = LActor.getActor(attacker)
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end
	local guild = LGuild.getGuildById(guildId)
	if not guild then return end
	local gvar = getGuildVar(guild)
	if not gvar then return end
	local monid = Fuben.getMonsterId(monster)
	if monid ~= gvar.bossId then return end

	--更新boss血量信息
	local oldhp = LActor.getHp(monster)
	if oldhp <= 0 then return end
	local hp = oldhp - value
	if hp < 0 then hp = 0 end
	hp = hp / LActor.getHpMax(monster) * 10000
	gvar.hpPercent = math.ceil(hp)

	if (gvar.timer or 0) > System.getNowTime() then return end
	gvar.timer = System.getNowTime() + 5
	updateGuildBossInfo(guild)
end

function onEnterFb(ins, actor)
	local var = getActorVar(actor)
	if not var then return end
	local guildId = LActor.getGuildId(actor)
	if not guildId == 0 then return end
	local guild = LGuild.getGuildById(guildId)
	if not guild then return end

	if var.canget == 1 then --如果还有挑战次数，挑战时会得到奖励
		local gvar = getGuildVar(guild)
		local mcount = var.mcount or 1
		local number = math.ceil(GuildBossConfig[gvar.idx].fightRewards * GuildBossCommonConfig.extra[math.max(mcount, 1)]) --挑战所得
		local reward = {{type=0, id=NumericType_GuildContrib, count=number}}
		instancesystem.setInsRewards(ins, actor, reward) --进入即得到挑战奖励
	end

	var.eid = LActor.postScriptEventLite(actor, GuildBossCommonConfig.fightTime * 1000, forceExitFuben, ins)
	insdisplay.fubenDaotime(actor, ins.id, GuildBossCommonConfig.fightTime)
	s2cGuildBossFight(actor)
end

function onExitFb(ins, actor)
	actorcommon.setTeamId(actor, 0)
	local var = getActorVar(actor)
	if var.eid then
		LActor.cancelScriptEvent(actor, var.eid)
		var.eid = nil
	end
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
	onExitFb(ins, actor)
end

local function onActorDie(ins, actor, killHdl)
	local value = bossinfo.getBossDamage(actor, ins)
	ins:setExtraData3(LActor.getActorId(actor), value)
	ins:notifyRewards(actor, true, true) --死亡时发送结算，不能用ins:lose()，因为这函数会触发副本setEnd
	instancesystem.DelayExit(actor)
end

--每周重置战盟boss
function flushGuildBoss()
	if not System.isBattleSrv() then return end
	local data = getGlobalData()
	data.weekDay = data.weekDay + 1 --每过一周，这个值就加1
	data.updateTime = System.getNowTime()

	local guildList = LGuild.getGuildList()
	if not guildList then return end
	for i=1, #guildList do
		local guild = guildList[i]
		local gvar = getGuildVar(guild)
		if gvar then
			gvar.idx = 1
			gvar.hpPercent = 10000
			RefreshGuildBoss(guild, gvar.idx)
		end
	end
	updateGuildBossInfo()
end
_G.flushGuildBoss = flushGuildBoss

--每天更新
local function onNewDay(actor, login)
	local var = getActorVar(actor)
	var.count = 0
	local now = System.getNowTime()
	if not System.isSameWeek(now, var.weekDay) then --判断是不是新的一轮
		var.rewardsRecord = 0 --恢复领奖状态
		var.weekDay = now
	end
	if not login then
		s2cGuildBossInfo(actor)
	end
end

local function onLogin(actor)
	s2cGuildBossInfo(actor)
end

function updateGuildBossInfo(guild, sId)
	local guildList = {}
	if not guild then
		guildList = LGuild.getGuildList()
		if not guildList then return end
	else
		guildList[1] = guild
	end

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_UpdateBossInfo)
    local data = getGlobalData()
	LDataPack.writeInt(npack, data.updateTime)
	LDataPack.writeInt(npack, data.weekDay)
	local count = #guildList
	LDataPack.writeShort(npack, count)
	for i=1, count do
		local guild = guildList[i]
		LDataPack.writeInt(npack, LGuild.getGuildId(guild))
		local gvar = getGuildVar(guild)
		if gvar then
			LDataPack.writeByte(npack, gvar.idx)
			LDataPack.writeShort(npack, gvar.hpPercent)
		else
			LDataPack.writeByte(npack, 0)
			LDataPack.writeShort(npack, 0)
		end
		LDataPack.writeInt64(npack, g_guildbossHf[guild] or 0)
	end
    System.sendPacketToAllGameClient(npack, sId or 0)
end


function onUpdateBossInfo(sId, sType, cpack)
	GUILD_BOSS_INFO.updateTime = LDataPack.readInt(cpack)
	GUILD_BOSS_INFO.weekDay = LDataPack.readInt(cpack)
	local count = LDataPack.readShort(cpack)
	for i=1, count do
		local guildId = LDataPack.readInt(cpack)
		GUILD_BOSS_INFO[guildId] = {}
		GUILD_BOSS_INFO[guildId].idx = LDataPack.readByte(cpack)
		GUILD_BOSS_INFO[guildId].hpPercent = LDataPack.readShort(cpack)
		GUILD_BOSS_INFO[guildId].hfuben = LDataPack.readInt64(cpack)
	end
end

function onConnected(sId, sType)
    updateGuildBossInfo(nil, sId)
end

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_UpdateBossInfo, onUpdateBossInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetReadyEnter, onGetReadyEnter)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendReadyEnter, onSendReadyEnter)


local isResetBoss = false
local function initGlobalData()
	actorevent.reg(aeNewDayArrive, onNewDay)
	if System.isLianFuSrv() then return end
	if System.isCommSrv() then
        actorevent.reg(aeUserLogin, onLogin)
        netmsgdispatcher.reg(Protocol.CMD_GuildActity, Protocol.cGuildActivityCmd_BossInfo, c2sGuildBossInfo)
        netmsgdispatcher.reg(Protocol.CMD_GuildActity, Protocol.cGuildActivityCmd_BossReward, c2sGuildBossReward)
        netmsgdispatcher.reg(Protocol.CMD_GuildActity, Protocol.cGuildActivityCmd_BossFight, c2sGuildBossFight)
	else
		csbase.RegConnected(onConnected)
        local data = getGlobalData()
        local now = System.getNowTime()
        if data.updateTime < now - 7*24*3600 then --长达七天没刷新时执行，避免服务器在周一0点时不开服导致flushGuildBoss不触发
            data.weekDay = data.weekDay + 1 --每过一周，这个值就加1
            data.updateTime = now
			isResetBoss = true
        end
	end
	for _, conf in pairs(GuildBossConfig) do
		insevent.registerInstanceWin(conf.fbId, onBossDie)
		insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceExit(conf.fbId, onExitFb)
		-- insevent.registerInstanceOffline(conf.fbId, onOffline)
		insevent.registerInstanceActorDie(conf.fbId, onActorDie)
	end
end
table.insert(InitFnTable, initGlobalData)

function initGuildBoss(guild, isSend)
	local gvar = getGuildVar(guild)
	if not gvar then return end
	--因为在启动游戏时LGuild.getGuildList()的值为空，所以重置boss数据在这里做而不在flushGuildBoss里做
	if isResetBoss then
		gvar.idx = 1
		gvar.hpPercent = 10000
		g_guildbossHf[guild] = nil
	end
	RefreshGuildBoss(guild, gvar.idx)
	if isSend then
		updateGuildBossInfo(guild)
	end
end


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.guildbossInfo = function (actor, args)
	local ins = instancesystem.getActorIns(actor)
	onBossDie(ins)
	s2cGuildBossInfo(actor)
end

gmCmdHandlers.guildbossGive = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeShort(pack, args[1] or 1)
	LDataPack.setPosition(pack, 0)
	c2sGuildBossReward(actor, pack)
end

gmCmdHandlers.guildbossFight = function (actor, args)
	c2sGuildBossFight(actor)
end

gmCmdHandlers.guildbossFlush = function (actor, args)
	flushGuildBoss()
end

gmCmdHandlers.guildbossRefresh = function(actor, args)
	local var = getActorVar(actor)
	var.count = 0
	s2cGuildBossInfo(actor)

	local guildId = LActor.getGuildId(actor)
	local guild = LGuild.getGuildById(guildId)
	local gvar = getGuildVar(guild)
	if not gvar then return end
	gvar.idx = gvar.idx
	gvar.hpPercent = 10000
	RefreshGuildBoss(guild, gvar.idx)
	updateGuildBossInfo(guild)
	return true
end
