-- @version	1.0
-- @author	qianmeng
-- @date	2017-11-10 10:57:07.
-- @system	卡利玛神庙

module("kalima", package.seeall)
require("scene.kalimacommon")
require("scene.kalimafuben")

local function getGlobalData()
	local var = System.getStaticVar()
	if not var then return end
	if not var.kalimaSet then 
		var.kalimaSet = {}
	end
	return var.kalimaSet;
end

--返回卡利玛副本
g_kalimaData = g_kalimaData or {}
local function getKalimaData()
	return g_kalimaData
end

local function getStaticData(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.kalimafuben then
		var.kalimafuben = {}
		var.kalimafuben.reminds = {}
	end
	local kalimafuben = var.kalimafuben
	if not kalimafuben.challengeCd then kalimafuben.challengeCd = 0 end
	if not kalimafuben.curKalimaId then kalimafuben.curKalimaId = 0 end --上一个挑战的Boss
	if not kalimafuben.rebornCd then kalimafuben.rebornCd = 0 end
	return kalimafuben
end

local function getBossData(id)
	return g_kalimaData[id]
end

--求下一个护盾
local function getNextShield(id, hp)
	if nil == hp then hp = 101 end

	local conf = KalimaFubenConfig[id]
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
	noticesystem.broadCastNotice(noticesystem.NTP.kalimaKill,LActor.getActorName(actorId), getMonsterName(config.bossId))
end

--清空归属者
local function clearBelongInfo(ins, actor)
	local bossData = getBossData(ins.data.pkalimaid)
	if not bossData then print("clearBelongInfo:bossData is null, id:"..ins.data.pkalimaid) return end

	if actor == bossData.belong then
		s2cBelongListClear(bossData)
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
	s2cBelongData(bossData.id, nil, oldBelong)
end

--重置副本，如果boss死了就创建新副本，如果没死就满血
local function refreshBoss(_, id)
	local bossData = getBossData(id)
	local hfuben = instancesystem.createFuBen(KalimaFubenConfig[id].fbId)
	bossData.hpPercent = 100
	bossData.damageList = {}
	bossData.hfuben = hfuben

	local ins = instancesystem.getInsByHdl(hfuben)
	if ins ~= nil then
		ins.data.pkalimaid = id
	end

	bossData.nextShield = getNextShield(id)
	bossData.curShield = nil
	bossData.shield = 0
	if bossData.shieldEid then
		LActor.cancelScriptEvent(nil, bossData.shieldEid)
		bossData.shieldEid = nil
	end
	s2cKalimaUpdate(id, bossData.bossId)
end

-- --角色复活
-- function reborn(actor, now)
-- 	local var = getStaticData(actor)
-- 	if var.deathMark ~= now then print(LActor.getActorId(actor).." reborn:data.deathMark ~= now") return end

-- 	s2cRebornTime(actor)

-- 	local conf = KalimaFubenConfig[var.curKalimaId]
-- 	local x,y = utils.getSceneEnterCoor(conf.fbId)
-- 	LActor.reborn(actor, x, y)
-- end

--护盾结束
function finishShield(_, bossData)
	bossData.shield = 0
	LActor.setInvincible(bossData.monster, false)
	instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, bossData.curShield.shield)
end

-------------------------------------------------------------------------------------------------------
--卡利玛神庙个人信息
function c2sKalimaInfo(actor, pactet)
	s2cKalimaInfo(actor)
end

--卡利玛神庙个人信息
function s2cKalimaInfo(actor)
	local var = getStaticData(actor)
	local now = System.getNowTime()

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_KalimaInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, math.max(var.challengeCd-now, 0))
	LDataPack.flush(npack)
end

--卡利玛神庙列表查看
function c2sKalimaList(actor, pactet)
	s2cKalimaList(actor)
end

--卡利玛神庙列表
function s2cKalimaList(actor)
	local bossDatas = getKalimaData()
	local var = getStaticData(actor)
	local now = System.getNowTime()
	local data = getGlobalData()

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_KalimaList)
	if npack == nil then return end
	LDataPack.writeShort(npack, #KalimaFubenConfig)
	for id, boss in pairs(bossDatas) do
		local ins = instancesystem.getInsByHdl(boss.hfuben)
		local count = ins and ins.actor_list_count or 0 		--挑战者数量
		local isRemind = var.reminds and var.reminds[id] or 1 	--是否提醒
		local found = false										--正在是否挑战这boss
		if (var.curKalimaId == id) and boss.damageList[LActor.getActorId(actor)] then
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
	LDataPack.writeInt(npack, quainton.getAnger())
	LDataPack.writeInt(npack, quainton.getMaxAnger())
	LDataPack.flush(npack)
end

--卡利玛神庙提醒设置
function c2sKalimaSetup(actor, pack)
	local id = LDataPack.readShort(pack)
	local isRemind = LDataPack.readByte(pack)
	local data = getStaticData(actor)
	if not data.reminds then
		data.reminds = {}
	end
	data.reminds[id] = isRemind
end

--卡利玛神庙挑战
function c2sKalimaFight(actor, pack)
	local kalimaId = LDataPack.readInt(pack)
	local conf = KalimaFubenConfig[kalimaId]
	if not conf then return end
	if LActor.getLevel(actor) < conf.level then
		return
	end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.kalima) then return end

	local bossData = getBossData(kalimaId)
	if bossData.hpPercent == 0 or bossData.hfuben == 0 then
		LActor.sendTipmsg(actor, ScriptTips.mssys013, ttMessage)
		return
	end

	local var = getStaticData(actor)
	if var.curKalimaId == kalimaId then
		if System.getNowTime() < (var.challengeCd or 0) then --检查cd
			return
		end
	end
	if not utils.checkFuben(actor, conf.fbId) then return end
	if not actoritem.checkItems(actor, conf.item) then 
		return
	end
	actoritem.reduceItems(actor, conf.item, "fight kalima")

	--处理进入
	var.curKalimaId = kalimaId
	local x,y = utils.getSceneEnterCoor(conf.fbId)
	local ret = LActor.enterFuBen(actor, bossData.hfuben, 0, x, y)
	if not ret then
		print("Error kalima enterFuben failed.. aid:"..LActor.getActorId(actor))
	else
		local lv, zhuansheng = zhuanshengsystem.getZhuanSheng(MonstersConfig[conf.bossId].level)
		noticesystem.broadCastNotice(noticesystem.NTP.kalima, LActor.getName(actor), lv, zhuansheng, MonstersConfig[conf.bossId].name)
	end
end

--卡利玛神庙奖励
function s2cKalimaReward(isBelong, actorId, config, rewards, bName, bJob)
	local checkActOpen = subactivity5.checkCanAddScore()
	local count = 0
	local actor = LActor.getActorById(actorId)
	if checkActOpen then
		count = isBelong and config.belongScore or config.attackScore
	end
	if actor and LActor.getFubenId(actor) == config.fbId then --玩家在线且在副本里， 发送结束协议
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_KalimaReward)
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
		if checkActOpen then
			LDataPack.writeInt(npack, count)
		else
			LDataPack.writeInt(npack, 0)
		end
		LDataPack.flush(npack)
	end

	--发送奖励
	if checkActOpen then
		subactivity5.addScore(actorId, count)
		if actor then
			chatcommon.sendSystemTips(actor, 1, 2, string.format(ScriptTips.bossScore01, count))
		end
	end
	if actor and actoritem.checkEquipBagSpace(actor, rewards) then		
		actoritem.addItems(actor, rewards, "kalima rewards")		
	else
		local text = config.mailContent
		if checkActOpen then
			text = string.format(config.actMailContent, count)
		end
		local mailData = {head=config.mailTitle, context=text, tAwardList=rewards}
		mailsystem.sendMailById(actorId, mailData)
	end
end

--卡利玛神庙单个信息更新
function s2cKalimaUpdate(id, bossId)
	local bossData = getBossData(id)
	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
	LDataPack.writeByte(npack, Protocol.sFubenCmd_KalimaUpdate)

	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, bossData.hpPercent)
	LDataPack.writeInt(npack, bossData.reliveTime - System.getNowTime())

	System.broadcastData(npack) --向所有人广播信息
end

--发送归属者信息
function s2cBelongData(id, actor, oldBelong)
	local bossData = getBossData(id)
	if not bossData then return end
	instancesystem.s2cBelongData(actor, oldBelong, bossData.belong, bossData.hfuben) ---归属者信息

	
	-- local npack = nil
	-- if actor then
	-- 	npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_InsBelong)    
	-- else
	-- 	npack = LDataPack.allocPacket()
	-- 	LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
	-- 	LDataPack.writeByte(npack, Protocol.sFubenCmd_InsBelong)
	-- end

	-- --新归属者
	-- local hdl = 0 --玩家handle
	-- local newName = ""
	-- local job = 0
	-- local hp = 0
	-- local maxHp = 0
	-- if bossData.belong then
	-- 	hdl = LActor.getHandle(bossData.belong)
	-- 	local belongId = LActor.getActorId(bossData.belong)
	-- 	newName = LActor.getActorName(belongId)
	-- 	job = LActor.getActorJob(belongId)
	-- 	local role = LActor.getRole(bossData.belong, 0)
	-- 	hp = LActor.getHp(role)
	-- 	maxHp = LActor.getHpMax(role)
	-- end
	-- LDataPack.writeDouble(npack, hdl)
	
	-- --上一任归属者
	-- local ohdl = 0
	-- local oldName = ""
	-- if oldBelong then
	-- 	ohdl = LActor.getHandle(oldBelong)
	-- 	local actorId = LActor.getActorId(oldBelong)
	-- 	oldName = LActor.getActorName(actorId)
	-- end
	-- LDataPack.writeDouble(npack, ohdl)
	-- LDataPack.writeString(npack, oldName)
	-- LDataPack.writeString(npack, newName)
	-- LDataPack.writeChar(npack, job)
	-- LDataPack.writeDouble(npack, hp)
	-- LDataPack.writeDouble(npack, maxHp)

	-- if actor then
	-- 	LDataPack.flush(npack)
	-- else
	-- 	Fuben.sendData(bossData.hfuben, npack)
	-- end
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

-- --通知玩家的复活信息
-- function s2cRebornTime(actor, killerHdl)
-- 	local var = getStaticData(actor)
-- 	local rebornCd = (var.rebornCd or 0) - System.getNowTime()
-- 	if rebornCd < 0 then rebornCd = 0 end

-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_KalimaRebornCD)
-- 	LDataPack.writeShort(npack, rebornCd)
-- 	LDataPack.writeDouble(npack, killerHdl or 0)
-- 	LDataPack.flush(npack)
-- end

-- --玩家主动复活
-- function c2sKalimaReborn(actor, packet)
-- 	local data = getStaticData(actor)

-- 	if (data.rebornCd or 0) < System.getNowTime() then --复活时间已到
-- 		return 
-- 	end
	
-- 	local conf = KalimaFubenConfig[data.curKalimaId]
-- 	if not conf then return end
-- 	--先判断有没有复活道具 
-- 	if KalimaCommonConfig.rebornItem > 0 and actoritem.checkItem(actor, KalimaCommonConfig.rebornItem, 1) then
-- 		actoritem.reduceItem(actor, KalimaCommonConfig.rebornItem, 1, "kalima boss reborn item")
-- 	elseif actoritem.checkItem(actor, NumericType_YuanBao, KalimaCommonConfig.rebornPrice) then --判断钱是否足够
-- 		actoritem.reduceItem(actor, NumericType_YuanBao, KalimaCommonConfig.rebornPrice, "kalima boss reborn item")
-- 	else
-- 		return
-- 	end
-- 	data.rebornCd = 0
-- 	s2cRebornTime(actor)

-- 	--清除死亡标志
-- 	if data.deathMark then
-- 		LActor.reborn(actor)
-- 		data.deathMark = nil
-- 		if data.eid then
-- 			LActor.cancelScriptEvent(actor, data.eid)
-- 			data.eid = nil
-- 		end
-- 	end
-- end

-- --护盾信息
-- function s2cShieldInfo(hfuben, tp, shield, maxShield)
-- 	if not hfuben then return end
-- 	local npack = LDataPack.allocPacket()
-- 	LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
-- 	LDataPack.writeByte(npack, Protocol.sFubenCmd_KalimaShield)

-- 	LDataPack.writeByte(npack, tp or 0)
-- 	LDataPack.writeInt(npack, shield)
-- 	LDataPack.writeInt(npack, maxShield)
-- 	Fuben.sendData(hfuben, npack)
-- end

-------------------------------------------------------------------------------------------

--登录事件
local function onLogin(actor)
	s2cKalimaInfo(actor)
	s2cKalimaList(actor)
end

local function onBossDie(ins)
	local kalimaId = ins.data.pkalimaid
	local bossData = getBossData(kalimaId)
	local belongId = LActor.getActorId(bossData.belong) 
	local bName = LActor.getActorName(belongId)
	local bJob = LActor.getJob(bossData.belong)
	local config = KalimaFubenConfig[kalimaId]
	if not config then return end

	for actorId, v in pairs(bossData.damageList) do
		if actorId == belongId then --归属者
			local rewards = drop.dropGroup(config.belongDrop)
			s2cKalimaReward(true, actorId, config, rewards, bName, bJob)
			setNoticeKillboss(actorId, config)
		else
			local rewards = drop.dropGroup(config.joinDrop)
			s2cKalimaReward(false, actorId, config, rewards, bName, bJob)
		end
	end
	local data = getGlobalData() --记录归属者
	data[kalimaId] = {name=bName}

	--boss信息重置
	bossData.hpPercent = 0
	bossData.hfuben = 0
	bossData.damageList = {}
	bossData.reliveTime = config.refreshTime  + System.getNowTime()
	LActor.postScriptEventLite(nil, config.refreshTime * 1000, refreshBoss, kalimaId)
	--LActor.postScriptEventLite(nil, 10 * 1000, refreshBoss, kalimaId)
	quainton.addAnger(config.anger, belongId, config.level, config.bossId)
	s2cKalimaUpdate(kalimaId, bossData.bossId)
end

local function onEnterFb(ins, actor)
	local bossData = getBossData(ins.data.pkalimaid)
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
	local kalimaId = ins.data.pkalimaid
	local monid = Fuben.getMonsterId(monster)
	if monid ~= KalimaFubenConfig[kalimaId].bossId then
		return
	end
	local bossData = getBossData(kalimaId)

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
			bossData.nextShield = getNextShield(ins.data.pkalimaid, bossData.curShield.hp) --再取下一个预备护盾
			
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
		data.challengeCd = System.getNowTime() + KalimaCommonConfig.cdTime 
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
	--data.rebornCd = now + KalimaCommonConfig.rebornCd

	local et = LActor.getEntity(killHdl)
	if not et then return end
	local attacker = LActor.getEntityType(et)

	local bossData = getBossData(ins.data.pkalimaid)
	if nil == bossData then return end

	if actor == bossData.belong then
		s2cBelongListClear(bossData)
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


local function initGlobalData()
	if System.isBattleSrv() then return end
	--注册事件
	actorevent.reg(aeUserLogin, onLogin)
	for _, conf in pairs(KalimaFubenConfig) do
		insevent.registerInstanceWin(conf.fbId, onBossDie)
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
		insevent.registerInstanceExit(conf.fbId, onExitFb)
		insevent.registerInstanceOffline(conf.fbId, onOffline)
		insevent.registerInstanceActorDie(conf.fbId, onActorDie)
	end
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_KalimaInfo, c2sKalimaInfo)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_KalimaList, c2sKalimaList)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_KalimaSetup, c2sKalimaSetup)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_KalimaFight, c2sKalimaFight)

	if next(g_kalimaData) then return end
	for id, conf in pairs(KalimaFubenConfig) do
		if not g_kalimaData[id] then
			local hfuben = instancesystem.createFuBen(conf.fbId)
			g_kalimaData[id] = {
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
				ins.data.pkalimaid = id
				ins.data.bossid = conf.bossId
			end
		end
	end
end
table.insert(InitFnTable, initGlobalData)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.flushkalima = function (actor, args)
	local id = tonumber(args[1])
	local bossData = getBossData(id)
	bossData.reliveTime = System.getNowTime()
	refreshBoss(nil, id)
end

gmCmdHandlers.kalimafight = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sKalimaFight(actor, pack)
end

gmCmdHandlers.kalimareborn = function (actor)
	c2sKalimaReborn(actor)
end

gmCmdHandlers.kalimalist = function (actor)
	c2sKalimaList(actor)
end

gmCmdHandlers.kalimaclearCD = function (actor)
	local var = getStaticData(actor)
	var.challengeCd = 0
	s2cKalimaInfo(actor)
end

