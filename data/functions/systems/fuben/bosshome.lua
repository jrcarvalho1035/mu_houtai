-- @version	1.0
-- @author	qianmeng
-- @date	2017-10-30 10:57:07.
-- @system	boss之家

module("bosshome", package.seeall)
require("scene.bosshomecommon")
require("scene.bosshomefuben")

g_bosshomeData = g_bosshomeData or {}
local function getBosshomeData()
	return g_bosshomeData
end

local function getStaticData(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.bosshomefuben then
		var.bosshomefuben = {}
		var.bosshomefuben.reminds = {}
	end
	local bosshomefuben = var.bosshomefuben
	if not bosshomefuben.challengeCd then bosshomefuben.challengeCd = 0 end
	if not bosshomefuben.curHomeId then bosshomefuben.curHomeId = 0 end --上一个挑战的Boss
	if not bosshomefuben.rebornCd then bosshomefuben.rebornCd = 0 end
	return bosshomefuben
end

local function getBossData(id)
	return g_bosshomeData[id]
end

--求下一次刷新的时间
function getNextRefreshTime()
	local timedata = false
	for k, v in pairs(TimerConfig) do
		if v.func == "flushBossHome" then
			timedata = v
			break
		end
	end
	if not timedata then return 0 end

	local zeroTime = System.getToday()
	local now = System.getNowTime()
	local delay = 0
	for k, v in ipairs(timedata.hour) do
		local tz = zeroTime + v*3600 + timedata.minute*60
		if tz > now then
			delay = tz - now
			break
		end
	end
	if delay == 0 then
		delay = zeroTime + (timedata.hour[1]+24)*3600 + timedata.minute*60 - now
	end
	return delay
end

--求下一个护盾
local function getNextShield(id, hp)
	if nil == hp then hp = 101 end

	local conf = BosshomeFubenConfig[id]
	if nil == conf then return nil end
	for i, s in ipairs(conf.shield) do
		if s.hp < hp then return s end
	end
	return nil
end


local function getMonsterName(bossId)
	if MonstersConfig[bossId] then
		return tostring(MonstersConfig[bossId].name)
	end
	return "nil"
end

--发送击杀boss的公告
local function setNoticeKillboss(actorId, config)
	noticesystem.broadCastNotice(noticesystem.NTP.homeKill, actorcommon.getVipShow(LActor.getActorById(actorId)), LActor.getActorName(actorId), getMonsterName(config.bossId))
end

--清空归属者
local function clearBelongInfo(ins, actor)
	local bossData = getBossData(ins.data.phomeid)
	if not bossData then print("clearBelongInfo:bossData is null, id:"..ins.data.phomeid) return end

	if LActor.getActorId(actor) == bossData.belongId then
		s2cBelongListClear(bossData)
		bossData.belongId = 0
		onBelongChange(bossData, actor, nil)
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
	s2cBelongData(bossData.id, nil, oldBelong)
end

--重置副本，如果boss死了就创建新副本，如果没死就满血
local function refreshBoss(id)
	local bossData = getBossData(id)
	local ins = instancesystem.getInsByHdl(bossData.hfuben)
	if ins then --boss还没死
		local handle = ins.scene_list[1]
		local scene = Fuben.getScenePtr(handle)
		local monster = Fuben.getSceneMonsterById(scene, bossData.bossId)
		LActor.setHp(monster, LActor.getHpMax(monster))
		bossData.hpPercent = 100
		--LActor.setInvincible(monster, false)--去除无敌状态
	else --boss已死，副本被毁
		local hfuben = instancesystem.createFuBen(BosshomeFubenConfig[id].fbId)
		bossData.hpPercent = 100
		bossData.damageList = {}
		bossData.hfuben = hfuben
		local ins = instancesystem.getInsByHdl(hfuben)
		if ins then
			ins.data.phomeid = id
		end
	end
	bossData.nextShield = getNextShield(id)
	bossData.curShield = nil
	bossData.shield = 0
	if bossData.shieldEid then
		LActor.cancelScriptEvent(nil, bossData.shieldEid)
		bossData.shieldEid = nil
	end
	s2cBosshomeUpdate(id, bossData.bossId)
end

-- --角色复活
-- function reborn(actor, now)
-- 	local var = getStaticData(actor)
-- 	if var.deathMark ~= now then print(LActor.getActorId(actor).." reborn:data.deathMark ~= now") return end

-- 	s2cRebornTime(actor)

-- 	local conf = BosshomeFubenConfig[var.curHomeId]
-- 	local x,y = utils.getSceneEnterCoor(conf.fbId)
-- 	LActor.reborn(actor, x, y)
-- end

--护盾结束
function finishShield(_, bossData)
	bossData.shield = 0
	--LActor.setInvincible(bossData.monster, false)
	instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, bossData.curShield.shield)
end

-------------------------------------------------------------------------------------------------------
--BOSS之家个人信息
function c2sBosshomeInfo(actor, pactet)
	s2cBosshomeInfo(actor)
end

--BOSS之家个人信息
function s2cBosshomeInfo(actor)
	local var = getStaticData(actor)
	local now = System.getNowTime()

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_HomeInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, math.max(var.challengeCd-now, 0))
	LDataPack.flush(npack)
end

--BOSS之家列表查看
function c2sBosshomeList(actor, pactet)
	s2cBosshomeList(actor)
end

--BOSS之家列表
function s2cBosshomeList(actor)
	local bossDatas = getBosshomeData()
	local var = getStaticData(actor)
	local refreshDelay = getNextRefreshTime()

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_HomeList)
	if npack == nil then return end
	LDataPack.writeShort(npack, #BosshomeFubenConfig)
	for id, boss in pairs(bossDatas) do
		local ins = instancesystem.getInsByHdl(boss.hfuben)
		local count = ins and ins.actor_list_count or 0 		--挑战者数量
		local isRemind = var.reminds and var.reminds[id] or 1 	--是否提醒
		local found = false										--正在是否挑战这boss
		if (var.curHomeId == id) and boss.damageList[LActor.getActorId(actor)] then
			found = true
		end

		LDataPack.writeInt(npack, id)
		LDataPack.writeString(npack, MonstersConfig[boss.bossId].name)
		LDataPack.writeString(npack, MonstersConfig[boss.bossId].head)
		LDataPack.writeShort(npack, MonstersConfig[boss.bossId].avatar[1])
		LDataPack.writeShort(npack, boss.hpPercent)
		LDataPack.writeShort(npack, count)
		LDataPack.writeByte(npack, found and 1 or 0)
		LDataPack.writeByte(npack, isRemind)
	end
	LDataPack.writeInt(npack, refreshDelay)
	LDataPack.flush(npack)
end

--BOSS之家提醒设置
function c2sBosshomeSetup(actor, pack)
	local id = LDataPack.readShort(pack)
	local isRemind = LDataPack.readByte(pack)
	local data = getStaticData(actor)
	if not data.reminds then
		data.reminds = {}
	end
	data.reminds[id] = isRemind
end

--BOSS之家挑战
function c2sBosshomeFight(actor, pack)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.home) then return end
	if not staticfuben.canEnterFuben(actor) then return end
	
	local homeId = LDataPack.readInt(pack)
	local conf = BosshomeFubenConfig[homeId]
	if not conf then return end
	if LActor.getLevel(actor) < conf.level then
		return
	end
	if not zhuansheng.checkZSLevel(actor, conf.zslevel) then
		return
	end
	local vip = LActor.getSVipLevel(actor)
	if vip < BosshomeCommonConfig.vip then
		if not actoritem.checkItem(actor,BosshomeCommonConfig.needitem, 1) then
			if not actoritem.checkItem(actor, NumericType_YuanBao, BosshomeCommonConfig.needYuanbao) then
				return
			end
			actoritem.reduceItem(actor, NumericType_YuanBao, BosshomeCommonConfig.needYuanbao, "boss home enter")
		else
			actoritem.reduceItem(actor, BosshomeCommonConfig.needitem, 1,  "boss home enter")
		end
	end


	local bossData = getBossData(homeId)
	if bossData.hpPercent == 0 or bossData.hfuben == 0 then
		return
	end

	local var = getStaticData(actor)
	if var.curHomeId == homeId then
		if System.getNowTime() < (var.challengeCd or 0) then --检查cd
			return
		end
	end
	if not utils.checkFuben(actor, conf.fbId) then return end

	--处理进入
	var.curHomeId = homeId
	local x,y = utils.getSceneEnterCoor(conf.fbId)
	local ret = LActor.enterFuBen(actor, bossData.hfuben, 0, x, y)
	if not ret then
		print("Error bosshome enterFuben failed.. aid:"..LActor.getActorId(actor))
	end
	-- local lv, zhuansheng = zhuansheng.getZhuanSheng( MonstersConfig[conf.bossId].level)
	-- noticesystem.broadCastNotice(noticesystem.NTP.bosshome, LActor.getName(actor), lv, zhuansheng, MonstersConfig[conf.bossId].name)
end

--BOSS之家奖励
function s2cBosshomeReward(isBelong, actorId, config, rewards, bName, bJob)
	local actor = LActor.getActorById(actorId)
	if actor and LActor.getFubenId(actor) == config.fbId then --玩家在线且在副本里， 发送结束协议
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_HomeReward)
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
	if actor and actoritem.checkEquipBagSpaceJob(actor, rewards) then
		actoritem.addItems(actor, rewards, "bosshome rewards")
	else
		local mailData = {head=config.mailTitle, context=config.content, tAwardList=rewards}
		mailsystem.sendMailById(actorId, mailData)
	end

	if actor then
		subactivity1.onKillBoss(actor)
	end
end

--BOSS之家单个信息更新
function s2cBosshomeUpdate(id, bossId)
	local bossData = getBossData(id)
	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
	LDataPack.writeByte(npack, Protocol.sFubenCmd_HomeUpdate)

	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, bossData.hpPercent)

	System.broadcastData(npack) --向所有人广播信息
end

--发送归属者信息
function s2cBelongData(id, actor, oldBelong)
	local bossData = getBossData(id)
	if not bossData then return end
	instancesystem.s2cBelongData(actor, oldBelong, LActor.getActorById(bossData.belongId), bossData.hfuben) ---归属者信息
end

--为副本内的攻击者清除归属者列表
function s2cBelongListClear(bossData)
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
	LDataPack.writeByte(npack, Protocol.sFubenCmd_InsAttackList)
	if nil == npack then return end
	LDataPack.writeUInt(npack, 0)
	Fuben.sendData(bossData.hfuben, npack)
end
-------------------------------------------------------------------------------------------

--登录事件
local function onLogin(actor)
	if System.isCrossWarSrv() then return end
	s2cBosshomeInfo(actor)
	s2cBosshomeList(actor)
end

local function onBossDie(ins)
	local homeId = ins.data.phomeid
	local bossData = getBossData(homeId)
	local belong = LActor.getActorById(bossData.belongId)
	if not belong then return end
	local bName = LActor.getActorName(bossData.belongId)
	local bJob = LActor.getJob(belong)
	local config = BosshomeFubenConfig[homeId]
	if not config then return end

	for actorId, v in pairs(bossData.damageList) do
		if actorId == bossData.belongId then --归属者
			local rewards = drop.dropGroup(config.belongDrop)
			local isopen, dropindexs = subactivity12.checkIsStart()
			if isopen then
				for j=1, #dropindexs do
					local rewards1 = drop.dropGroup(config.actRewards[dropindexs[j]])
					for i=1, #rewards1 do
						table.insert(rewards, {type = rewards1[i].type, id = rewards1[i].id, count = rewards1[i].count})
					end
				end
			end
			s2cBosshomeReward(true, actorId, config, rewards, bName, bJob)
			setNoticeKillboss(actorId, config)
		else
			local rewards = drop.dropGroup(config.joinDrop)
			local isopen, dropindexs = subactivity12.checkIsStart()
			if isopen then
				for j=1, #dropindexs do
					local rewards1 = drop.dropGroup(config.actRewards[dropindexs[j]])
					for i=1, #rewards1 do
						table.insert(rewards, {type = rewards1[i].type, id = rewards1[i].id, count = rewards1[i].count})
					end
				end
			end
			s2cBosshomeReward(false, actorId, config, rewards, bName, bJob)
		end
	end

	--boss信息重置
	bossData.hpPercent = 0
	bossData.hfuben = 0
	bossData.damageList = {}
	s2cBosshomeUpdate(homeId, bossData.bossId)
end

local function onEnterFb(ins, actor)
	local bossData = getBossData(ins.data.phomeid)
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

	s2cBelongData(bossData.id, actor) --归属者信息
	LActor.setCamp(actor, CampType_Normal)--设置阵营为普通模式
end

local function onBossDamage(ins, monster, value, attacker, res)
	local homeId = ins.data.phomeid
	local monid = Fuben.getMonsterId(monster)
	if monid ~= BosshomeFubenConfig[homeId].bossId then
		return
	end
	local bossData = getBossData(homeId)

	--第一下攻击者为boss归属者
	if 0 == bossData.belongId and bossData.hfuben == LActor.getFubenHandle(attacker) then
		local actor = LActor.getActor(attacker)
		if actor and LActor.isDeath(actor) == false then
			local oldBelong = LActor.getActorById(bossData.belongId)
			bossData.belongId = LActor.getActorId(actor)
			onBelongChange(bossData, oldBelong, actor)
			--使怪物攻击归属者
			LActor.setAITarget(monster, LActor.getRole(actor))
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
			bossData.nextShield = getNextShield(ins.data.phomeid, bossData.curShield.hp) --再取下一个预备护盾

			res.ret = math.floor(LActor.getHpMax(monster) * bossData.curShield.hp / 100) --避免一招秒而不触发护盾，这里要恢复血量
			bossData.hpPercent = bossData.curShield.hp --要把血量设置回原值
			LActor.setInvincible(monster, bossData.curShield.shield*1000) --设无敌状态
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
		data.challengeCd = System.getNowTime() + BosshomeCommonConfig.cdTime
	end

	-- --删除复活定时器
	-- data.deathMark = nil
	-- if data.eid then
	-- 	LActor.cancelScriptEvent(actor, data.eid)
	-- 	data.eid = nil
	-- end
	LActor.setCamp(actor, CampType_Normal) --退出变回正常阵营，此行影响s2cAttackList里的攻击者数量
	clearBelongInfo(ins, actor) --清除归属者
end

local function onOffline(ins, actor)
	clearBelongInfo(ins, actor) --清除归属者
end

local function onActorDie(ins, actor, killHdl)
	local data = getStaticData(actor)
	--local now = System.getNowTime()
	--data.rebornCd = now + BosshomeCommonConfig.rebornCd

	local et = LActor.getEntity(killHdl)
	if not et then return end
	local attacker = LActor.getEntityType(et)

	local bossData = getBossData(ins.data.phomeid)
	if nil == bossData then return end

	if LActor.getActorId(actor) == bossData.belongId then
		s2cBelongListClear(bossData)
		--归属者被玩家打死，该玩家是新归属者
		if actorcommon.isActor(attacker) then
			local belong = LActor.getActor(et)
			bossData.belongId = LActor.getActorId(belong)
			--怪物攻击新的归属者
			local handle = ins.scene_list[1]
			local scene = Fuben.getScenePtr(handle)
			local monster = Fuben.getSceneMonsterById(scene, bossData.bossId)
			if not monster then
				print("Error monster in actor belongId die")
			end
			LActor.setAITarget(monster, et)
			noticesystem.fubenCastNotice(bossData.hfuben, noticesystem.NTP.homeBelong, LActor.getName(belong), LActor.getName(actor))
		elseif EntityType_Monster == attacker then --归属者被怪物打死，怪物无归属
			bossData.belongId = 0
		end
		--广播归属者信息
		onBelongChange(bossData, actor, LActor.getActorById(bossData.belongId))
	else
		--不是归属者,死亡时候切换回正常阵营
		if LActor.getCamp(actor) == CampType_Attack then
			LActor.setCamp(actor, CampType_Normal)
		end
	end
end


local function initGlobalData()
	if System.isCrossWarSrv() then return end
	--注册事件
	actorevent.reg(aeUserLogin, onLogin)
	for _, conf in pairs(BosshomeFubenConfig) do
		insevent.registerInstanceWin(conf.fbId, onBossDie)
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
		insevent.registerInstanceExit(conf.fbId, onExitFb)
		insevent.registerInstanceOffline(conf.fbId, onOffline)
		insevent.registerInstanceActorDie(conf.fbId, onActorDie)
	end


	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_HomeInfo, c2sBosshomeInfo)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_HomeList, c2sBosshomeList)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_HomeSetup, c2sBosshomeSetup)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_HomeFight, c2sBosshomeFight)
	if next(g_bosshomeData) then return end

	for id, conf in pairs(BosshomeFubenConfig) do
		if not g_bosshomeData[id] then
			local hfuben = instancesystem.createFuBen(conf.fbId)
			g_bosshomeData[id] = {
				id = conf.id,
				hpPercent = 100,
				hfuben = hfuben,
				shield = 0,
				curShield = nil,
				nextShield = getNextShield(conf.id),
				belongId = 0,
				damageList = {},
				bossId = conf.bossId
			}
			local ins = instancesystem.getInsByHdl(hfuben)
			if ins then
				ins.data.phomeid = id
				ins.data.bossid = conf.bossId
			end
		end
	end
end
table.insert(InitFnTable, initGlobalData)

--boss刷新
function flushBossHome()
	if System.isCrossWarSrv() then return end
	for id, conf in pairs(BosshomeFubenConfig) do
		refreshBoss(id)
	end
	noticesystem.broadCastNotice(noticesystem.NTP.homeResh)
end
_G.flushBossHome = flushBossHome


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.flushbosshome = function (actor)
	flushBossHome()
end

gmCmdHandlers.bosshomefight = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sBosshomeFight(actor, pack)
end

gmCmdHandlers.bosshomereborn = function (actor)
	-- c2sBosshomeReborn(actor)
end

gmCmdHandlers.bosshomelist = function (actor)
	c2sBosshomeList(actor)
end

gmCmdHandlers.bosshomeclearCD = function (actor)
	local var = getStaticData(actor)
	var.challengeCd = 0
	s2cBosshomeInfo(actor)
end
