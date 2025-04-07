-- @version	1.0
-- @author	qianmeng
-- @date	2017-11-11 15:10:30.
-- @system	昆顿之门

module("quainton", package.seeall)
require("scene.quaintonboss")
require("scene.quaintonfuben")

g_quaintonData = g_quaintonData or {}

local function getGlobalData()
	local var = System.getStaticVar()
	if not var then return end
	if not var.quaintonSet then 
		var.quaintonSet = {
			bossLv = 1, --boss等级
			appearTime = 0, --出现时间
			isOpen = 0,	--活动是否开启
			anger = 0, --怒气
		}
	end
	return var.quaintonSet;
end

local function getBossData()
	return g_quaintonData
end

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.quaintondata then 
		var.quaintondata = {
			killCount = 0, --击杀次数
	} 
	end
	return var.quaintondata
end

function getAnger()
	local data = getGlobalData()
	return data.anger
end

function getMaxAnger()
	local data = getGlobalData()
	return QuaintonBossConfig[data.bossLv].maxAnger
end

--昆顿之门加怒气
function addAnger(anger, actorid, kalimaBossLv, bossId)
	local data = getGlobalData()
	if data.isOpen == 1 then --昆顿之门开启后不再加怒
		return
	end
	data.anger = data.anger + anger
	local maxAnger = QuaintonBossConfig[data.bossLv].maxAnger

	if actorid and data.anger >= maxAnger/2 then
		local lv, zhuansheng = zhuanshengsystem.getZhuanSheng(kalimaBossLv)
		noticesystem.broadCastNotice(noticesystem.NTP.quaintonpro,LActor.getActorName(actorid), lv, zhuansheng, MonstersConfig[bossId].name, math.min(100, math.floor(data.anger/maxAnger * 100)))
	end
	if data.anger >= maxAnger then
		data.anger = maxAnger
		openQuainton()
	end
	notifyQuintonInfo()
end

function openQuainton()
	if System.isBattleSrv() then return end
	local data = getGlobalData()
	data.appearTime = System.getNowTime() + KalimaCommonConfig.quintonTiming
	data.isOpen = 1

	LActor.postScriptEventLite(nil, KalimaCommonConfig.quintonTiming * 1000, createHfuben)
	s2cQuintonAppear()

	noticesystem.broadCastNotice(noticesystem.NTP.kalimaAnger, math.floor(KalimaCommonConfig.quintonTiming/60))
end

function closeQuainton()
	local data = getGlobalData()
	if data.isOpen == 0 then --打死BOSS和副本时间结束都会触发，防止重复执行
		return
	end
	data.isOpen = 0
	data.anger = 0
	s2cQuintonAppear()
	notifyQuintonInfo()
end

--求下一个护盾
local function getNextShield(hp)
	if nil == hp then hp = 101 end
	local data = getGlobalData()
	local conf = QuaintonBossConfig[data.bossLv]
	if nil == conf then return nil end
	for i, s in ipairs(conf.shield) do
		if s.hp < hp then return s end
	end
	return nil
end

--护盾结束
function finishShield(_, bossData)
	bossData.shield = 0
	LActor.setInvincible(bossData.monster, false)
	instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, bossData.curShield.shield)
end

function createHfuben()
	local data = getGlobalData()
	local conf = QuaintonFubenConfig[1]
	local hfuben = instancesystem.createFuBen(conf.fbId)
	local bossId = QuaintonBossConfig[data.bossLv].monsterID

	local bossData = getBossData()
	if bossData.shieldEid then
		LActor.cancelScriptEvent(nil, bossData.shieldEid)
		bossData.shieldEid = nil
	end
	g_quaintonData = {
		damageList = {},
		hfuben = hfuben,
		bossId = bossId,
		monster = nil,
		shield = 0,
		curShield = nil,
		nextShield = getNextShield(),
		growTime = System.getNowTime() + KalimaCommonConfig.quintonGrow
	}
	local ins = instancesystem.getInsByHdl(hfuben)
	if ins then
		ins.data.pbossid = bossId
		local monster = Fuben.createMonster(ins.scene_list[1], bossId, conf.pos[1], conf.pos[2])
		g_quaintonData.monster = monster
	end
	s2cQuintonAppear()

	data.eid = LActor.postScriptEventLite(nil, KalimaCommonConfig.quintonWartTime * 1000, finishQuinton, ins)
	noticesystem.broadCastNotice(noticesystem.NTP.kalimaAppera)
end

local function updateRank()
	local bossData = getBossData()

	local damageList = bossData.damageList
	if damageList == nil then return end

	local rank = {}
	for actorId, damage in pairs(damageList) do
		table.insert(rank, {aid=actorId,dmg=damage})
	end
	table.sort(rank, function(a,b) return a.dmg>b.dmg end )
	return rank
end

--副本到时结束
function finishQuinton(_, ins)
	local rank = updateRank()
	local config = QuaintonFubenConfig[1]
	if rank and rank[1] then
		for i=1, #rank do
			local aid = rank[i].aid
			local dmg = rank[i].dmg
			local reward = false
			if config.rankDrop[i] then
				reward = drop.dropGroup(config.rankDrop[i]) --第一名奖
			else
				reward = drop.dropGroup(config.joinDrop) --参与奖
			end
			s2cQuintonReward(false, config, aid, "", i, {}, reward, ins, dmg)
		end
	end
	closeQuainton()
end
------------------------------------------------------------------------------------------
--昆顿之门出现
function s2cQuintonAppear(actor)
	local data = getGlobalData()
	local npack = nil
	if actor then
		npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_QuintonAppear)    
	else
		npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
		LDataPack.writeByte(npack, Protocol.sFubenCmd_QuintonAppear)
	end
	if npack == nil then return end

	local delay = data.appearTime - System.getNowTime()
	local flag = data.isOpen==1 and delay <= 0 --能否打
	LDataPack.writeInt(npack, delay)
	LDataPack.writeByte(npack, flag and 1 or 0)
	if actor then
		LDataPack.flush(npack)
	else
		System.broadcastData(npack)
	end
end

function notifyQuintonInfo()
	local actors = System.getOnlineActorList()
	if not actors then return end
	for i = 1, #actors do
		local actor = actors[i]
		s2cQuintonInfo(actor)
	end
end

--昆顿之门查看信息
function s2cQuintonInfo(actor)
	local data = getGlobalData()
	local mId = QuaintonBossConfig[data.bossLv].monsterID
	local mconf = MonstersConfig[mId]
	local var = getActorVar(actor)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_QuintonInfo)
	if npack == nil then return end
	LDataPack.writeString(npack, mconf.name)
	LDataPack.writeString(npack, mconf.head)
	LDataPack.writeShort(npack, mconf.avatar)
	LDataPack.writeInt(npack, data.anger)
	LDataPack.writeInt(npack, getMaxAnger())
	LDataPack.writeInt(npack, var.killCount)
	LDataPack.flush(npack)
end

--昆顿之门挑战
function c2sQuintonFight(actor, packet)
	local data = getGlobalData()
	if not data.isOpen then return end
	local conf = QuaintonFubenConfig[1]
	if not conf then return end
	if LActor.getLevel(actor) < conf.level then
		return
	end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.kalima) then return end
	if not utils.checkFuben(actor, conf.fbId) then return end

	--处理进入
	local bossData = getBossData()
	if (bossData.hfuben or 0) == 0 then return end

	local monIdList = {QuaintonBossConfig[data.bossLv].monsterID}
	slim.s2cMonsterConfig(actor, monIdList) --进入副本前先发送里面BOSS的信息

	local x,y = utils.getSceneEnterCoor(conf.fbId)
	local ret = LActor.enterFuBen(actor, bossData.hfuben, 0, x, y)
	if not ret then
		print("Error quinton enterFuben failed.. aid:"..LActor.getActorId(actor))
	end

	noticesystem.broadCastNotice(noticesystem.NTP.quaintonenter, LActor.getName(actor), MonstersConfig[QuaintonBossConfig[data.bossLv].monsterID].name)
end

--昆顿之门奖励
function s2cQuintonReward(isWin, config, aid, name, rank, extraReward, reward, ins, damage)
	local actor = LActor.getActorById(aid)
	if actor and LActor.getFubenId(actor) == config.fbId then --玩家在线且在当前副本
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_QuintonReward)
		if npack == nil then return end
		LDataPack.writeByte(npack, isWin and 1 or 0)
		LDataPack.writeDouble(npack, damage)
		LDataPack.writeShort(npack, rank)
		LDataPack.writeString(npack, name)
		LDataPack.writeShort(npack, #extraReward)
		for _, v in ipairs(extraReward) do
			LDataPack.writeInt(npack, v.type or 0)
			LDataPack.writeInt(npack, v.id or 0)
			LDataPack.writeInt(npack, v.count or 0)
		end
		LDataPack.writeShort(npack, #reward)
		for _, v in ipairs(reward) do
			LDataPack.writeInt(npack, v.type or 0)
			LDataPack.writeInt(npack, v.id or 0)
			LDataPack.writeInt(npack, v.count or 0)
		end
		LDataPack.flush(npack)
	end

	--发奖励
	local items = actoritem.mergeItems(reward, extraReward)
	if actor and actoritem.checkEquipBagSpace(actor, items) then --在线或背包够位
		actoritem.addItems(actor, items, "quainton reward")
	else
		local content = string.format(config.mailContent, rank)
		local mailData = {head=config.mailTitle, context=content, tAwardList=items}
		mailsystem.sendMailById(aid, mailData)
	end
end
---------------------------------------------------------------------------------------
local function onLogin(actor)
	s2cQuintonAppear(actor)
	s2cQuintonInfo(actor)
end

local function onEnterFb(ins, actor)
	local bossData = getBossData()
	local damageList = bossData.damageList
	local actorId = LActor.getActorId(actor)
	damageList[actorId] = damageList[actorId] or 0 --进入副本的人计进boss伤害表，以便有奖励
	--护盾信息
	if bossData.curShield then
		nowShield = bossData.shield
		if (bossData.curShield.type or 0) == 1 then
			nowShield = nowShield - System.getNowTime()
			if nowShield < 0 then nowShield = 0 end
		end
		instancesystem.s2cShieldInfo(ins.handle, bossData.curShield.type, nowShield, bossData.curShield.shield)
	end
end

local function onExitFb(ins, actor)
end

local function onOffline(ins, actor)
end

local function onActorDie(ins, actor, killHdl)
	ins:notifyRewards(actor, true)
	instancesystem.DelayExit(actor)
end

local function onMonsterDie(ins, mon, killer_hdl)
	local data = getGlobalData()
	local bossId = ins.data.pbossid
	local bossData = getBossData()
	local config = QuaintonFubenConfig[1]
	if not config then return end
	--计算最终伤害排名，发奖励 
	local rank = updateRank()

	local et = LActor.getEntity(killer_hdl)
	local killer_actor = LActor.getActor(et) --最后一击玩家
	local name = LActor.getName(killer_actor)

	if rank and rank[1] then
		for i=1, #rank do
			local aid = rank[i].aid
			local dmg = rank[i].dmg
			local reward = false
			local exReward = {}
			if config.rankDrop[i] then
				reward = drop.dropGroup(config.rankDrop[i]) --第一名奖
			else
				reward = drop.dropGroup(config.joinDrop) --参与奖
			end
			if aid == LActor.getActorId(killer_actor) then --最后一击附加奖
				exReward = drop.dropGroup(config.extraDrop)
				--击杀次数满足将获得称号
				local var = getActorVar(killer_actor)
				var.killCount = var.killCount + 1
				if var.killCount >= KalimaCommonConfig.killCount then
					titlesystem.addTitle(killer_actor, KalimaCommonConfig.quintonTitle)
				end
			end
			s2cQuintonReward(true, config, aid, name, i, exReward, reward, ins, dmg)
		end
	end

	--昆顿的怪如果在成长限期内杀掉，昆顿就会成长
	if System.getNowTime() <= bossData.growTime then
		if QuaintonBossConfig[data.bossLv+1] then
			data.bossLv = data.bossLv + 1
		end
		s2cQuintonInfo(actor)
		print("quinton grow "..data.bossLv)
	end

	--boss信息重置
	bossData.hfuben = 0
	bossData.damageList = {}
	closeQuainton()

	if data.eid then --避免触发finishQuinton
		LActor.cancelScriptEvent(nil, data.eid) 
		data.eid = nil
	end

	noticesystem.broadCastNotice(noticesystem.NTP.quaintonClose, name)
end

local function onBossDamage(ins, monster, value, attacker, res)
	local bossData = getBossData()
	local monid = Fuben.getMonsterId(monster)
	if monid ~= bossData.bossId then
		return
	end

	--更新boss血量信息
	local oldhp = LActor.getHp(monster)
	if oldhp <= 0 then return end

	local hp = oldhp - value
	if hp < 0 then hp = 0 end
	hp = hp / LActor.getHpMax(monster) * 100

	--护盾判断
	if 0 == bossData.shield then --现在没有护盾
		if bossData.nextShield and 0 ~= bossData.nextShield.hp and hp < bossData.nextShield.hp then --从预备护盾里取护盾
			bossData.curShield = bossData.nextShield
			bossData.nextShield = getNextShield(bossData.curShield.hp) --再取下一个预备护盾
			
			res.ret = math.floor(LActor.getHpMax(monster) * bossData.curShield.hp / 100) --避免一招秒而不触发护盾，这里要恢复血量
			LActor.setInvincible(monster, true) --设无敌状态
			bossData.shield = bossData.curShield.shield + System.getNowTime()
			instancesystem.s2cShieldInfo(bossData.hfuben, 1, bossData.curShield.shield, bossData.curShield.shield)
			--注册护盾结束定时器
			bossData.shieldEid = LActor.postScriptEventLite(nil, bossData.curShield.shield*1000, finishShield, bossData)
			noticesystem.fubenCastNotice(bossData.hfuben, noticesystem.NTP.homeShield)
		end
	end

	local actor = LActor.getActor(attacker)
	if actor == nil then return end
	local damageList = bossData.damageList
	local actorId = LActor.getActorId(actor)
	damageList[actorId] = (damageList[actorId] or 0) + value
end

--玩家在护盾期间的输出
local function onShieldOutput(ins, monster, value, attacker)
	local bossData = getBossData()
	local actor = LActor.getActor(attacker)
	if actor == nil then return end
	local damageList = bossData.damageList
	local actorId = LActor.getActorId(actor)
	damageList[actorId] = (damageList[actorId] or 0) + value
end


local function fuBenInit()
	if System.isBattleSrv() then return end
	local data = getGlobalData()
	data.isOpen = 0 --昆顿之门判断是否打开
	if data.anger >= QuaintonBossConfig[data.bossLv].maxAnger then
		openQuainton()
	end
	local fubenId = QuaintonFubenConfig[1].fbId
	insevent.registerInstanceEnter(fubenId, onEnterFb)
	insevent.registerInstanceExit(fubenId, onExitFb)
	insevent.registerInstanceOffline(fubenId, onOffline)
	insevent.registerInstanceActorDie(fubenId, onActorDie)
	insevent.registerInstanceMonsterDie(fubenId, onMonsterDie)
	insevent.registerInstanceMonsterDamage(fubenId, onBossDamage)
	insevent.registerInstanceShieldOutput(fubenId, onShieldOutput)

	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_QuintonFight, c2sQuintonFight)
	actorevent.reg(aeUserLogin, onLogin)
end
table.insert(InitFnTable, fuBenInit)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.quaintonfight = function (actor, args)
	c2sQuintonFight(actor)
end

gmCmdHandlers.quaintonanger = function (actor, args)
	local anger = tonumber(args[1])
	addAnger(anger)
end

gmCmdHandlers.quaintonclose = function (actor, args)
	closeQuainton()
end

gmCmdHandlers.quaintoncreate = function (actor, args)
	local data = getGlobalData()
	data.appearTime = System.getNowTime()
	addAnger(getMaxAnger())
	data.isOpen = 1
	data.appearTime = System.getNowTime()
	createHfuben()
	s2cQuintonAppear()
end

gmCmdHandlers.quaintonlevel = function (actor, args)
	local lv = tonumber(args[1])
	local data = getGlobalData()
	data.bossLv = lv
	s2cQuintonInfo(actor)
end

gmCmdHandlers.quaintonfinish = function (actor, args)
	local ins = instancesystem.getActorIns(actor)
	finishQuinton(nil, ins)
end
