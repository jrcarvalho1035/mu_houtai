-- @version	1.0
-- @author	qianmeng
-- @date	2017-11-10 10:57:07.
-- @system	勇者圣殿

module("brave", package.seeall)
require("scene.bravecommon")
require("scene.bravefuben")
require("scene.bravelevel")

local function getGlobalData()
	local var = System.getStaticVar()
	if not var then return end
	if not var.braveSet then 
		var.braveSet = {}
	end
	return var.braveSet;
end

--返回勇者战场副本
g_braveData = g_braveData or {}
local function getBraveData()
	return g_braveData
end

local function getStaticData(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.bravefuben then
		var.bravefuben = {}
		var.bravefuben.reminds = {}
	end
	local bravefuben = var.bravefuben
	if not bravefuben.challengeCd then bravefuben.challengeCd = 0 end
	if not bravefuben.curBraveId then bravefuben.curBraveId = 0 end --上一个挑战的Boss
	if not bravefuben.fightcount then bravefuben.fightcount = 0 end--玩家已挑战次数
	if not bravefuben.buycount then bravefuben.buycount = 0 end--玩家已挑战次数
	if not bravefuben.matchId then bravefuben.matchId = 1 end --等级段匹配id，默认第一个
	return bravefuben
end

local function getBossData(id)
	return g_braveData[id]
end

--求下一个护盾
local function getNextShield(id, hp)
	if nil == hp then hp = 101 end

	local conf = BraveFubenConfig[id]
	if nil == conf then return nil end
	for i, s in ipairs(conf.shield) do
		if s.hp < hp then return s end
	end
	return nil
end

--发送击杀boss的公告
local function setNoticeKillboss(actorId, config)
	noticesystem.broadCastNotice(noticesystem.NTP.braveKill,LActor.getActorName(actorId), utils.getMonsterName(config.bossId))
end

--清空归属者
local function clearBelongInfo(ins, actor)
	local bossData = getBossData(ins.data.pbraveid)
	if not bossData then print("clearBelongInfo:bossData is null, id:"..ins.data.pbraveid) return end

	if actor == bossData.belong then
		instancesystem.s2cBelongListClear(bossData.hfuben)
		bossData.belong = nil
		onBelongChange(bossData, actor, bossData.belong)
	end
end

--归属者改变处理
function onBelongChange(bossData, oldBelong, newBelong)
	if oldBelong then
		LActor.setCamp(oldBelong, CampType_Normal)
	end
	if newBelong then
		LActor.setCamp(newBelong, CampType_Belong)
	end
	local actors = Fuben.getAllActor(bossData.hfuben)
	if actors ~= nil then
		for i = 1,#actors do 
			if LActor.getActor(actors[i]) ~= newBelong then 
				LActor.setCamp(actors[i], CampType_Normal)
			end
		end
	end
	--广播归属者信息
	instancesystem.s2cBelongData(false, oldBelong, newBelong, bossData.hfuben)
end

--重置副本，如果boss死了就创建新副本，如果没死就满血
local function refreshBoss(_, id)
	local bossData = getBossData(id)
	local hfuben = instancesystem.createFuBen(BraveFubenConfig[id].fbId)
	bossData.hpPercent = 100
	bossData.damageList = {}
	bossData.hfuben = hfuben

	local ins = instancesystem.getInsByHdl(hfuben)
	if ins ~= nil then
		ins.data.pbraveid = id
	end

	bossData.nextShield = getNextShield(id)
	bossData.curShield = nil
	bossData.shield = 0
	if bossData.shieldEid then
		LActor.cancelScriptEvent(nil, bossData.shieldEid)
		bossData.shieldEid = nil
	end
	s2cBraveUpdate(id, bossData.bossId)
end

--护盾结束
function finishShield(_, bossData)
	bossData.shield = 0
	LActor.setInvincible(bossData.monster, false)
	instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, bossData.curShield.shield)
end
-------------------------------------------------------------------------------------------------------
function c2sBraveInfo(actor, packet)
	s2cBraveInfo(actor)
end

--勇者战场个人信息
function s2cBraveInfo(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.brave) then return end
	local var = getStaticData(actor)
	local now = System.getNowTime()

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_BraveInfo)
	if npack == nil then return end
	LDataPack.writeInt(npack, math.max(var.challengeCd-now, 0))
	LDataPack.writeChar(npack, var.fightcount)
	LDataPack.writeChar(npack, var.buycount)
	LDataPack.flush(npack)
end

--勇者战场列表查看
function c2sBraveList(actor, pactet)
	s2cBraveList(actor)
end

--勇者战场列表
function s2cBraveList(actor)
	local bossDatas = getBraveData()
	local var = getStaticData(actor)
	local now = System.getNowTime()
	local data = getGlobalData()
	local config = BraveLevelConfig[var.matchId]
	if not config then return end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_BraveList)
	if npack == nil then return end
	LDataPack.writeShort(npack, #config.fold)
	for k, id in ipairs(config.fold) do
		local boss = bossDatas[id]
		local ins = instancesystem.getInsByHdl(boss.hfuben)
		local count = ins and ins.actor_list_count or 0 		--挑战者数量
		local isRemind = var.reminds and var.reminds[id] or 1 	--是否提醒
		local found = false										--正在是否挑战这boss
		if (var.curBraveId == id) and boss.damageList[LActor.getActorId(actor)] then
			found = true
		end
		local name = data[id] and data[id].name or "" --上次属者名

		local mconf = MonstersConfig[boss.bossId]
		LDataPack.writeInt(npack, id)
		LDataPack.writeString(npack, mconf.name)
		LDataPack.writeString(npack, mconf.head)
		LDataPack.writeShort(npack, mconf.avatar)
		LDataPack.writeShort(npack, boss.hpPercent)
		LDataPack.writeShort(npack, count)
		LDataPack.writeInt(npack, boss.reliveTime - now)
		LDataPack.writeByte(npack, found and 1 or 0)
		LDataPack.writeByte(npack, isRemind)
		LDataPack.writeString(npack, name)
	end
	LDataPack.flush(npack)
end

--勇者战场提醒设置
function c2sBraveSetup(actor, pack)
	local id = LDataPack.readShort(pack)
	local isRemind = LDataPack.readByte(pack)
	local data = getStaticData(actor)
	if not data.reminds then
		data.reminds = {}
	end
	data.reminds[id] = isRemind
end

--勇者战场挑战
function c2sBraveFight(actor, pack)
	local braveId = LDataPack.readInt(pack)
	local conf = BraveFubenConfig[braveId]
	if not conf then return end

	local var = getStaticData(actor)
	if not utils.checkTableValue(BraveLevelConfig[var.matchId].fold, braveId) then
		return
	end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.brave) then return end

	local bossData = getBossData(braveId)
	if bossData.hpPercent == 0 or bossData.hfuben == 0 then
		return
	end

	if var.curBraveId == braveId then
		if System.getNowTime() < (var.challengeCd or 0) then --检查cd
			return
		end
	end
	if var.fightcount >= BraveCommonConfig.maxCount + var.buycount then
	 	return 
	end

	if not utils.checkFuben(actor, conf.fbId) then return end
	--处理进入
	var.curBraveId = braveId
	local x,y = utils.getSceneEnterCoor(conf.fbId)
	local ret = LActor.enterFuBen(actor, bossData.hfuben, 0, x, y)
	if not ret then
		print("Error brave enterFuben failed.. aid:"..LActor.getActorId(actor))
	end
	var.fightcount = var.fightcount + 1
	s2cBraveInfo(actor)
end

--勇者战场单个信息更新
function s2cBraveUpdate(id, bossId)
	local bossData = getBossData(id)
	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
	LDataPack.writeByte(npack, Protocol.sFubenCmd_BraveUpdate)

	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, bossData.hpPercent)
	LDataPack.writeInt(npack, bossData.reliveTime - System.getNowTime())

	System.broadcastData(npack) --向所有人广播信息
end

--勇者战场奖励
function s2cBraveReward(isBelong, actorId, config, rewards, bName, bJob)
	local actor = LActor.getActorById(actorId)
	if actor and LActor.getFubenId(actor) == config.fbId then --玩家在线且在副本里， 发送结束协议
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_BraveResult)
		if npack == nil then return end
		LDataPack.writeByte(npack, isBelong and 1 or 0)
		LDataPack.writeString(npack, bName)
		LDataPack.writeByte(npack, bJob)
		LDataPack.writeShort(npack, #rewards)
		for _, v in ipairs(rewards) do
			LDataPack.writeInt(npack, v.type or 0)
			LDataPack.writeInt(npack, v.id or 0)
			LDataPack.writeInt(npack, v.count or 0)
		end
		LDataPack.flush(npack)
	end

	--发送奖励
	if actor and actoritem.checkEquipBagSpace(actor, rewards) then
		actoritem.addItems(actor, rewards, "brave rewards")
	else
		local mailData = {head=config.mailTitle, context=config.mailContent, tAwardList=rewards}
		mailsystem.sendMailById(actorId, mailData)
	end
end

--购买次数
function c2sBraveBuy(actor, pactet)
	local var = getStaticData(actor)
	local vip = LActor.getVipLevel(actor)
	if var.buycount >= VipConfig[vip].brave then return end 
	if not actoritem.checkItem(actor, NumericType_YuanBao, BraveCommonConfig.price) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, BraveCommonConfig.price, "brave buy")

	var.buycount = var.buycount + 1
	s2cBraveInfo(actor)
end

-------------------------------------------------------------------------------------------
--登录事件
local function onLogin(actor)
	s2cBraveInfo(actor)
	s2cBraveList(actor)
end

local function onNewDay(actor, login)
	local var = getStaticData(actor)
	var.fightcount = 0
	var.buycount = 0
	local level = LActor.getLevel(actor)
	for k, v in ipairs(BraveLevelConfig) do
		if level >= v.level then
			var.matchId = k
		end
	end
	if not login then
		s2cBraveInfo(actor)
		s2cBraveList(actor)
	end
end

function onLevelUp(actor, level, oldLevel)
	local lv = actorexp.getLimitLevel(nil, actorexp.LimitTp.brave)
	if lv > oldLevel and lv <= level then
		s2cBraveInfo(actor)
		s2cBraveList(actor)
	end
end

local function onBossDie(ins)
	local braveId = ins.data.pbraveid
	local bossData = getBossData(braveId)
	local belongId = LActor.getActorId(bossData.belong) 
	local bName = LActor.getActorName(belongId)
	local bJob = LActor.getJob(bossData.belong)
	local config = BraveFubenConfig[braveId]
	if not config then return end

	for actorId, v in pairs(bossData.damageList) do
		if actorId == belongId then --归属者
			local rewards = drop.dropGroup(config.belongDrop)
			s2cBraveReward(true, actorId, config, rewards, bName, bJob)
			setNoticeKillboss(actorId, config)
		else
			local rewards = drop.dropGroup(config.joinDrop)
			s2cBraveReward(false, actorId, config, rewards, bName, bJob)
		end
	end
	local data = getGlobalData() --记录归属者
	data[braveId] = {name=bName}

	--boss信息重置
	bossData.hpPercent = 0
	bossData.hfuben = 0
	bossData.damageList = {}
	bossData.reliveTime = config.refreshTime  + System.getNowTime()
	LActor.postScriptEventLite(nil, config.refreshTime * 1000, refreshBoss, braveId)
	s2cBraveUpdate(braveId, bossData.bossId)
end

local function onEnterFb(ins, actor)
	local bossData = getBossData(ins.data.pbraveid)
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

	instancesystem.s2cBelongData(actor, false, bossData.belong, bossData.hfuben) --归属者信息
	LActor.setCamp(actor, CampType_Normal)--设置阵营为普通模式
end

local function onBossDamage(ins, monster, value, attacker, res)
	local braveId = ins.data.pbraveid
	local monid = Fuben.getMonsterId(monster)
	if monid ~= BraveFubenConfig[braveId].bossId then
		return
	end
	local bossData = getBossData(braveId)

	--第一下攻击者为boss归属者
	if nil == bossData.belong and bossData.hfuben == LActor.getFubenHandle(attacker) then 
		local actor = LActor.getActor(attacker)
		if actor and LActor.isDeath(actor) == false then 
			local oldBelong = bossData.belong
			bossData.belong = actor
			onBelongChange(bossData, oldBelong, actor)
			--使怪物攻击归属者
			LActor.setAITarget(monster, LActor.getBattleLiveByOrder(actor))
		end		
	end

	--更新boss血量信息
	local oldhp = LActor.getHp(monster)
	if oldhp <= 0 then return end

	local hp = oldhp - value
	if hp < 0 then hp = 0 end

	hp = hp / LActor.getHpMax(monster) * 100
	bossData.hpPercent = math.ceil(hp)

	bossData.monster = monster --记录BOSS实体

	--护盾判断
	if 0 == bossData.shield then --现在没有护盾
		if bossData.nextShield and 0 ~= bossData.nextShield.hp and hp < bossData.nextShield.hp then --从预备护盾里取护盾
			bossData.curShield = bossData.nextShield
			bossData.nextShield = getNextShield(ins.data.pbraveid, bossData.curShield.hp) --再取下一个预备护盾
			
			res.ret = math.floor(LActor.getHpMax(monster) * bossData.curShield.hp / 100) --避免一招秒而不触发护盾，这里要恢复血量
			bossData.hpPercent = bossData.curShield.hp --要把血量设置回原值
			LActor.setInvincible(monster, true) --设无敌状态
			bossData.shield = bossData.curShield.shield + System.getNowTime()
			instancesystem.s2cShieldInfo(bossData.hfuben, 1, bossData.curShield.shield, bossData.curShield.shield)
			--注册护盾结束定时器
			bossData.shieldEid = LActor.postScriptEventLite(nil, bossData.curShield.shield*1000, finishShield, bossData)
			noticesystem.fubenCastNotice(bossData.hfuben, noticesystem.NTP.homeShield)
		end
	end
end

local function onExitFb(ins, actor)
	local data = getStaticData(actor)
	if not ins.is_win then --胜利的副本不加CD
		data.challengeCd = System.getNowTime() + BraveCommonConfig.cdTime 
	end
	LActor.setCamp(actor, CampType_Normal) --退出变回正常阵营，此行影响s2cAttackList里的攻击者数量
	clearBelongInfo(ins, actor) --清除归属者
end

local function onOffline(ins, actor)
	clearBelongInfo(ins, actor) --清除归属者
end

local function onActorDie(ins, actor, killHdl)
	local data = getStaticData(actor)
	local now = System.getNowTime()

	local et = LActor.getEntity(killHdl)
	if not et then return end
	local attacker = LActor.getEntityType(et)

	local bossData = getBossData(ins.data.pbraveid)
	if nil == bossData then return end

	if actor == bossData.belong then
		instancesystem.s2cBelongListClear(bossData.hfuben)
		--归属者被玩家打死，该玩家是新归属者
		if EntityType_Actor == attacker or EntityType_Role == attacker or EntityType_RoleSuper == attacker then 
			bossData.belong = LActor.getActor(et)
			--怪物攻击新的归属者
			local handle = ins.scene_list[1]
			local scene = Fuben.getScenePtr(handle)
			local monster = Fuben.getSceneMonsterById(scene, bossData.bossId)
			if not monster then
				utils.printInfo("Error monster in actor belong die", bossData.bossId)
			end
			LActor.setAITarget(monster, et)
			noticesystem.fubenCastNotice(bossData.hfuben, noticesystem.NTP.homeBelong, LActor.getName(bossData.belong), LActor.getName(actor))
		elseif EntityType_Monster == attacker then --归属者被怪物打死，怪物无归属
			bossData.belong = nil
		end

		--广播归属者信息
		onBelongChange(bossData, actor, bossData.belong)
	else
		--不是归属者,死亡时候切换回正常阵营
		if LActor.getCamp(actor) == CampType_Attack then
			LActor.setCamp(actor, CampType_Normal)
		end
	end
end

onChangeName = function(actor, res, name, rawName, way)
	local data = getGlobalData()
	for id in ipairs(BraveFubenConfig) do		
		if data[id] and data[id].name and data[id].name == rawName then
			data[id].name = name
		end
	end
end


local function initGlobalData()
	if System.isBattleSrv() then return end
	--注册事件	
	actorevent.reg(aeChangeName, onChangeName)
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeLevel, onLevelUp)
	for _, conf in pairs(BraveFubenConfig) do
		insevent.registerInstanceWin(conf.fbId, onBossDie)
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
		insevent.registerInstanceExit(conf.fbId, onExitFb)
		insevent.registerInstanceOffline(conf.fbId, onOffline)
		insevent.registerInstanceActorDie(conf.fbId, onActorDie)
	end

	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_BraveInfo, c2sBraveInfo)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_BraveList, c2sBraveList)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_BraveSetup, c2sBraveSetup)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_BraveFight, c2sBraveFight)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_BraveBuy, c2sBraveBuy)
	
	if next(g_braveData) then return end

	for id, conf in pairs(BraveFubenConfig) do
		if not g_braveData[id] then
			local hfuben = instancesystem.createFuBen(conf.fbId)
			g_braveData[id] = {
				id = conf.id,
				hpPercent = 100,
				hfuben = hfuben,
				shield = 0,
				curShield = nil,
				nextShield = getNextShield(conf.id),
				belong = nil,
				damageList = {},
				bossId = conf.bossId,
				reliveTime = System.getNowTime(), 	--下一次复活时间
			}
			local ins = instancesystem.getInsByHdl(hfuben)
			if ins then
				ins.data.pbraveid = id
				ins.data.bossid = conf.bossId
			end
		end
	end
	
end
table.insert(InitFnTable, initGlobalData)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.flushbrave = function (actor, args)
	local id = tonumber(args[1])
	local bossData = getBossData(id)
	bossData.reliveTime = System.getNowTime()
	refreshBoss(nil, id)
end

gmCmdHandlers.bravefight = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sBraveFight(actor, pack)
end

gmCmdHandlers.bravelist = function (actor)
	c2sBraveList(actor)
end

gmCmdHandlers.braveclearCD = function (actor)
	local var = getStaticData(actor)
	var.challengeCd = 0
	s2cBraveInfo(actor)
end

