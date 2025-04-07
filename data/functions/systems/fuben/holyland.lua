-- @version	1.0
-- @author	qianmeng
-- @date	2018-1-12 12:12:12.
-- @system	叹息神殿

module("holyland", package.seeall)
require("scene.holylandcommon")
require("scene.holylandfuben")

local function getGlobalData()
	local var = System.getStaticVar()
	if not var then return end
	if not var.holylandSet then 
		var.holylandSet = {}
	end
	return var.holylandSet;
end

--返回叹息神殿副本
g_holylandData = g_holylandData or {}
local function getHolylandData()
	return g_holylandData
end

local function getStaticData(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.holylandfuben then
		var.holylandfuben = {}
		var.holylandfuben.reminds = {}
	end
	local holylandfuben = var.holylandfuben
	if not holylandfuben.challengeCd then holylandfuben.challengeCd = 0 end
	if not holylandfuben.curHolylandId then holylandfuben.curHolylandId = 0 end --上一个挑战的Boss
	if not holylandfuben.rebornCd then holylandfuben.rebornCd = 0 end
	if not holylandfuben.progress then holylandfuben.progress = 0 end --挑战进度
	if not holylandfuben.isreward then holylandfuben.isreward = 0 end
	if not holylandfuben.count then holylandfuben.count = HolylandCommonConfig.maxCount end--玩家可挑战次数
	if not holylandfuben.last_time then holylandfuben.last_time = 0 end	--下一次恢复时间
	return holylandfuben
end

local function getBossData(id)
	return g_holylandData[id]
end

--求下一个护盾
local function getNextShield(id, hp)
	if nil == hp then hp = 101 end

	local conf = HolylandFubenConfig[id]
	if nil == conf then return nil end
	for i, s in ipairs(conf.shield) do
		if s.hp < hp then return s end
	end
	return nil
end

--发送击杀boss的公告
local function setNoticeKillboss(actorId, config)
	noticesystem.broadCastNotice(noticesystem.NTP.holylandKill,LActor.getActorName(actorId), utils.getMonsterName(config.bossId))
end

--清空归属者
local function clearBelongInfo(ins, actor)
	local bossData = getBossData(ins.data.pholylandid)
	if not bossData then print("clearBelongInfo:bossData is null, id:"..ins.data.pholylandid) return end

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

--重置副本，如果boss死了就创建新副本
local function refreshBoss(_, id)
	local bossData = getBossData(id)
	local hfuben = instancesystem.createFuBen(HolylandFubenConfig[id].fbId)
	bossData.hpPercent = 100
	bossData.damageList = {}
	bossData.hfuben = hfuben

	local ins = instancesystem.getInsByHdl(hfuben)
	if ins ~= nil then
		ins.data.pholylandid = id
	end

	bossData.nextShield = getNextShield(id)
	bossData.curShield = nil
	bossData.shield = 0
	if bossData.shieldEid then
		LActor.cancelScriptEvent(nil, bossData.shieldEid)
		bossData.shieldEid = nil
	end
	s2cHolylandUpdate(id, bossData.bossId)
end

--护盾结束
function finishShield(_, bossData)
	bossData.shield = 0
	LActor.setInvincible(bossData.monster, false)
	instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, bossData.curShield.shield)
end

--更新挑战次数
local function updateFightCount(actor)
	local var = getStaticData(actor)
	if var.count >= HolylandCommonConfig.maxCount then
		return
	end
	local now = System.getNowTime()
	local cd = HolylandCommonConfig.recoverTime
	while (var.last_time + cd < now) do
		var.last_time = var.last_time + cd
		var.count = var.count + 1
		if var.count >= HolylandCommonConfig.maxCount then
			var.last_time = 0
			break
		end
	end
end
-------------------------------------------------------------------------------------------------------
function c2sHolylandInfo(actor, packet)
	s2cHolylandInfo(actor)
end

--叹息神殿个人信息
function s2cHolylandInfo(actor)
	updateFightCount(actor)
	local var = getStaticData(actor)
	local now = System.getNowTime()
	local cd = HolylandCommonConfig.recoverTime
	local leftTime = cd - (now - var.last_time)  --恢复时间剩余时间

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_HolylandInfo)
	if npack == nil then return end
	LDataPack.writeInt(npack, math.max(var.challengeCd-now, 0))
	LDataPack.writeShort(npack, var.count)
	LDataPack.writeShort(npack, math.max(0, leftTime))
	LDataPack.writeShort(npack, var.progress)
	LDataPack.writeByte(npack, var.isreward)
	LDataPack.flush(npack)
end

--叹息神殿列表查看
function c2sHolylandList(actor, packet)
	s2cHolylandList(actor)
end

--叹息神殿列表
function s2cHolylandList(actor)
	local bossDatas = getHolylandData()
	local var = getStaticData(actor)
	local now = System.getNowTime()
	local data = getGlobalData()

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_HolylandList)
	if npack == nil then return end
	LDataPack.writeShort(npack, #HolylandFubenConfig)
	for id, boss in pairs(bossDatas) do
		local ins = instancesystem.getInsByHdl(boss.hfuben)
		local count = ins and ins.actor_list_count or 0 		--挑战者数量
		local isRemind = var.reminds and var.reminds[id] or 1 	--是否提醒
		local found = false										--正在是否挑战这boss
		if (var.curHolylandId == id) and boss.damageList[LActor.getActorId(actor)] then
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

--叹息神殿提醒设置
function c2sHolylandSetup(actor, pack)
	local id = LDataPack.readShort(pack)
	local isRemind = LDataPack.readByte(pack)
	local data = getStaticData(actor)
	if not data.reminds then
		data.reminds = {}
	end
	data.reminds[id] = isRemind
end

--叹息神殿挑战
function c2sHolylandFight(actor, pack)
	local holylandId = LDataPack.readInt(pack)
	local conf = HolylandFubenConfig[holylandId]
	if not conf then return end
	if LActor.getLevel(actor) < conf.level then
		return
	end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.holyland) then return end

	local bossData = getBossData(holylandId)
	if bossData.hpPercent == 0 or bossData.hfuben == 0 then
		return
	end

	local var = getStaticData(actor)
	if var.curHolylandId == holylandId then
		if System.getNowTime() < (var.challengeCd or 0) then --检查cd
			return
		end
	end
	if var.count <= 0 then return end
	if not utils.checkFuben(actor, conf.fbId) then return end

	--处理进入
	var.curHolylandId = holylandId
	local x,y = utils.getSceneEnterCoor(conf.fbId)
	local ret = LActor.enterFuBen(actor, bossData.hfuben, 0, x, y)
	if not ret then
		print("Error holyland enterFuben failed.. aid:"..LActor.getActorId(actor))
	end
	if var.count == HolylandCommonConfig.maxCount then
		var.last_time = System.getNowTime()
	end
	var.progress = var.progress + 1
	var.count = var.count - 1
	s2cHolylandInfo(actor)
end

--叹息神殿结算
function s2cHolylandResult(isBelong, actorId, config, rewards, bName, bJob)
	local actor = LActor.getActorById(actorId)
	if actor and LActor.getFubenId(actor) == config.fbId then --玩家在线且在副本里， 发送结束协议
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_HolylandResult)
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
		actoritem.addItems(actor, rewards, "holyland rewards")
	else
		local mailData = {head=config.mailTitle, context=config.mailContent, tAwardList=rewards}
		mailsystem.sendMailById(actorId, mailData)
	end
end

--叹息神殿Boss更新
function s2cHolylandUpdate(id, bossId)
	local bossData = getBossData(id)
	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
	LDataPack.writeByte(npack, Protocol.sFubenCmd_HolylandUpdate)

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
end

--为副本内的攻击者清除归属者列表
function s2cBelongListClear(bossData)
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
	LDataPack.writeByte(npack, Protocol.sFubenCmd_HolylandAttackList)
	if nil == npack then return end
	LDataPack.writeUInt(npack, 0)
	Fuben.sendData(bossData.hfuben, npack)
end

function c2sHolylandGet(actor, packet)
	local var = getStaticData(actor)
	if var.isreward == 1 then return end
	if var.progress < HolylandCommonConfig.getcount then return end
	var.isreward = 1
	actoritem.addItems(actor, HolylandCommonConfig.rewards, "holy land get")
	s2cHolylandInfo(actor)
end

-------------------------------------------------------------------------------------------

--登录事件
local function onLogin(actor)
	s2cHolylandInfo(actor)
	s2cHolylandList(actor)
end

local function onNewDay(actor, login)
	local var = getStaticData(actor)
	var.progress = 0
	var.isreward = 0
	if not login then
		s2cHolylandInfo(actor)
	end
end

local function onBossDie(ins)
	local holylandId = ins.data.pholylandid
	local bossData = getBossData(holylandId)
	local belongId = LActor.getActorId(bossData.belong) 
	local bName = LActor.getActorName(belongId)
	local bJob = LActor.getJob(bossData.belong)
	local config = HolylandFubenConfig[holylandId]
	if not config then return end

	for actorId, v in pairs(bossData.damageList) do
		if actorId == belongId then --归属者
			local rewards = drop.dropGroup(config.belongDrop)
			s2cHolylandResult(true, actorId, config, rewards, bName, bJob)
			setNoticeKillboss(actorId, config)
		else
			local rewards = drop.dropGroup(config.joinDrop)
			s2cHolylandResult(false, actorId, config, rewards, bName, bJob)
		end
	end
	local data = getGlobalData() --记录归属者
	data[holylandId] = {name=bName}

	--boss信息重置
	bossData.hpPercent = 0
	bossData.hfuben = 0
	bossData.damageList = {}
	bossData.reliveTime = config.refreshTime  + System.getNowTime()
	LActor.postScriptEventLite(nil, config.refreshTime * 1000, refreshBoss, holylandId)
	s2cHolylandUpdate(holylandId, bossData.bossId)
end

local function onEnterFb(ins, actor)
	local bossData = getBossData(ins.data.pholylandid)
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
	local holylandId = ins.data.pholylandid
	local monid = Fuben.getMonsterId(monster)
	if monid ~= HolylandFubenConfig[holylandId].bossId then
		return
	end
	local bossData = getBossData(holylandId)

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
			bossData.nextShield = getNextShield(ins.data.pholylandid, bossData.curShield.hp) --再取下一个预备护盾
			
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
		data.challengeCd = System.getNowTime() + HolylandCommonConfig.cdTime 
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

	local bossData = getBossData(ins.data.pholylandid)
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
	actorevent.reg(aeNewDayArrive, onNewDay)
	for _, conf in pairs(HolylandFubenConfig) do
		insevent.registerInstanceWin(conf.fbId, onBossDie)
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
		insevent.registerInstanceExit(conf.fbId, onExitFb)
		insevent.registerInstanceOffline(conf.fbId, onOffline)
		insevent.registerInstanceActorDie(conf.fbId, onActorDie)
	end

	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_HolylandInfo, c2sHolylandInfo)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_HolylandList, c2sHolylandList)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_HolylandSetup, c2sHolylandSetup)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_HolylandFight, c2sHolylandFight)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_HolylandGet, c2sHolylandGet)

	if next(g_holylandData) then return end
	for id, conf in pairs(HolylandFubenConfig) do
		if not g_holylandData[id] then
			local hfuben = instancesystem.createFuBen(conf.fbId)
			g_holylandData[id] = {
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
				ins.data.pholylandid = id
				ins.data.bossid = conf.bossId
			end
		end
	end
end
table.insert(InitFnTable, initGlobalData)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.flushholyland = function (actor, args)
	local id = tonumber(args[1])
	local bossData = getBossData(id)
	bossData.reliveTime = System.getNowTime()
	refreshBoss(nil, id)
	return true
end

gmCmdHandlers.holylandfight = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sHolylandFight(actor, pack)
	return true
end

gmCmdHandlers.holylandreborn = function (actor)
	c2sHolylandReborn(actor)
	return true
end

gmCmdHandlers.holylandlist = function (actor)
	c2sHolylandList(actor)
	return true
end

gmCmdHandlers.holylandclearCD = function (actor)
	local var = getStaticData(actor)
	var.challengeCd = 0
	s2cHolylandInfo(actor)
	return true
end

gmCmdHandlers.holylandaddpro = function (actor, args)
	local var = getStaticData(actor)
	var.progress = var.progress + tonumber(args[1])
	return true
end

gmCmdHandlers.holylandsetpro = function (actor, args)
	print ("holylandsetpro")
	local var = getStaticData(actor)
	var.progress = tonumber(args[1]) or 0
	s2cHolylandInfo(actor)
	return true
end

gmCmdHandlers.holylandsetcount = function (actor, args)
	local var = getStaticData(actor)
	var.count = var.count + (tonumber(args[1]) or 0)
	s2cHolylandInfo(actor)
	return true
end
