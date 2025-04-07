-- @version 1.0
-- @author  qianmeng
-- @date    2017-12-16 10:10:10.
-- @system  世界BOSS

module("zhuzai", package.seeall)
require("scene.zhuzaifuben")
require("scene.zhazaicommon")

g_zhuzaiData = g_zhuzaiData or {}
g_zhuzai_open = g_zhuzai_open or false
g_end_time = g_end_time or 0

local function getGlobalData()
	local var = System.getStaticVar()
	if not var then return end
	if not var.zhuzaiSet then 
		var.zhuzaiSet = {
			damageRank = {}, --boss等级
		}
	end
	return var.zhuzaiSet;
end

local function getBossData(id)
	return g_zhuzaiData[id]
end

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.zhuzaidata then
		var.zhuzaidata = {
			curId = 0,
			cdTime = 0,
		}
	end
	return var.zhuzaidata	
end

function clearRankingRecord(id)
	local data = getGlobalData()
	data.damageRank[id] = {}
end

function setRankingRecord(id, ranking, name, damage)
	local data = getGlobalData()
	data.damageRank[id] = data.damageRank[id] or {}
	data.damageRank[id][ranking] = {name=name, damage=damage}
end

--求下一个护盾
local function getNextShield(id, hp)
	if nil == hp then hp = 101 end
	local conf = ZhuZaiFubenConfig[id]
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


function getConfigId(actor)
	local id = 0
	local level = LActor.getLevel(actor)
	for k, v in ipairs(ZhuZaiFubenConfig) do
		if level >= v.level then
			id = k
		else
			break
		end
	end
	return id
end

--求下一次开始的时间
function getNextStartTime()
	local timedata = false
	for k, v in pairs(TimerConfig) do
		if v.func == "ZhuZaiStart" then
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

--返回：倒计时，倒计时类型
function getTime()
	local now = System.getNowTime()
	if g_zhuzai_open then --结束倒计时
		return g_end_time - now, 2
	else --开始倒计时
		return getNextStartTime(), 1
	end
end

local function updateRank(id)
	local bossData = getBossData(id)
	if not bossData then return end
	local damageList = bossData.damageList
	if damageList == nil then return end

	local rank = {}
	for actorId, damage in pairs(damageList) do
		table.insert(rank, {aid=actorId,dmg=damage})
	end
	table.sort(rank, function(a,b) return a.dmg>b.dmg end)
	bossData.rank = rank
	return rank
end

function startLottery(ins, item)
	local id = ins.data.pzhuzaiid
	local bossData = getBossData(id)
	local conf = ZhuZaiFubenConfig[id]

	if bossData.lottery then
		LActor.cancelScriptEvent(nil, bossData.lottery.eid)
		endLottery(nil, bossData)
	end

	bossData.lottery = {}
	bossData.lottery.eid = LActor.postScriptEventLite(nil, ZhaZaiConfig.rollTime * 1000, endLottery, bossData)
	bossData.lottery.item = item
	bossData.lottery.aid = nil
	bossData.lottery.point = 0
	bossData.lottery.record = {}

	local actorList = ins:getActorList()
	for k, v in pairs(actorList) do
		s2cZhuZaiLottery(v, item[1].id)
	end
end

function endLottery(_, bossData)
	if not bossData.lottery then return end
	if not bossData.lottery.aid then return end

	local actorId = bossData.lottery.aid
	local roll = bossData.lottery.point

	local conf = ZhuZaiFubenConfig[bossData.id]
	if not conf then return end
	
	--邮件
	local mailData = {head=conf.luckMailTitle, context=conf.luckMailContent, tAwardList=bossData.lottery.item}
	mailsystem.sendMailById(actorId, mailData)
	bossData.lottery = nil

	noticesystem.broadCastNotice(noticesystem.NTP.zhuzai4, LActor.getActorName(actorId))
end

function resetData(actor)
	local var = getActorVar(actor)
	if not var then return end
	var.curId = 0
end
--------------------------------------------------------------------------------------------------
function s2cZhuZaiInfo(actor, isStart)
	local var = getActorVar(actor)
	if not var then return end

	local time, tp = getTime()
	time = math.max(time, 0)
	local curId = var.curId == 0 and getConfigId(actor) or var.curId
	local cdTime = math.max(var.cdTime - System.getNowTime(), 0)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_ZhuZaiInfo)
	if pack == nil then return end
	LDataPack.writeChar(pack, tp)
	LDataPack.writeInt(pack, time)
	LDataPack.writeInt(pack, cdTime) --重进cd时间
	LDataPack.writeChar(pack, #ZhuZaiFubenConfig)
	for k, v in ipairs(ZhuZaiFubenConfig) do
		local bossData = getBossData(k)
		LDataPack.writeByte(pack, bossData and bossData.isalive or 1)
		LDataPack.writeInt(pack, k)
	end
	LDataPack.writeInt(pack, curId)
	LDataPack.flush(pack)
end

--主宰挑战
function c2sZhuZaiFight(actor, packet)
	if not g_zhuzai_open then 
		chatcommon.sendSystemTips(actor, 1, 2, ScriptTips.zhuzai01)
		return 
	end
	local var = getActorVar(actor)
	if not var then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zhuzai) then
		return
	end
	if System.getNowTime() < var.cdTime then --检查cd
		return
	end
	if var.curId == 0 then --每次活动确定打BOSS的等级后不能改变
		var.curId = getConfigId(actor)
	end

	local bossData = getBossData(var.curId)
	if not bossData then return end

	local conf = ZhuZaiFubenConfig[var.curId]
	if not conf then return end
	if not utils.checkFuben(actor, conf.fbId) then return end
	--处理进入
	local x,y = utils.getSceneEnterCoor(conf.fbId)
	local ret = LActor.enterFuBen(actor, bossData.hfuben, 0, x, y)
	if not ret then
		print("Error zhuzai enterFuben failed.. aid:"..LActor.getActorId(actor))
	end
end

--主宰结算
function s2cZhuZaiResult(aid, isWin, firstName, killName, ranking, conf, reward, exReward)
	local items = actoritem.mergeItems(reward, exReward)
	local actor = LActor.getActorById(aid)
	if actor and LActor.getFubenId(actor) == conf.fbId then
		local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_ZhuZaiResult)
		if pack == nil then return end
		LDataPack.writeByte(pack, isWin)
		LDataPack.writeString(pack, firstName)
		LDataPack.writeString(pack, killName)
		LDataPack.writeInt(pack, ranking)
		LDataPack.writeShort(pack, #items)
		for k, v in ipairs(items) do
			LDataPack.writeInt(pack, v.type)
			LDataPack.writeInt(pack, v.id)
			LDataPack.writeDouble(pack, v.count)
		end
		LDataPack.flush(pack)
	end

	--发奖励
	local content = string.format(conf.mailContent, rank)
	local mailData = {head=conf.mailTitle, context=content, tAwardList=items}
	mailsystem.sendMailById(aid, mailData)
	if actor then
		s2cZhuZaiInfo(actor)
	end
end

--抽奖开始
function s2cZhuZaiLottery(actor, itemId)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_ZhuZaiLottery)
	if pack == nil then return end
	LDataPack.writeInt(pack, itemId)
	LDataPack.writeInt(pack, ZhaZaiConfig.rollTime)
	LDataPack.flush(pack)
end

--主宰摇骰
function c2sZhuZaiRoll(actor, packet)
	local var = getActorVar(actor)
	local bossData = getBossData(var.curId)
	if (not var) or (not bossData) then return end
	--判断玩家还在不在副本里面
	if bossData.hfuben ~= LActor.getFubenHandle(actor) then
		return
	end
	if not bossData.lottery then return end
	local actorId = LActor.getActorId(actor)
	if bossData.lottery.record[actorId] then return end --已摇过

	local roll = math.random(200)
	bossData.lottery.record[actorId] = roll

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_ZhuZaiRoll)
	LDataPack.writeShort(pack, roll)
	LDataPack.flush(pack)

	--如果是最高点数则保存
	if roll > bossData.lottery.point then
		bossData.lottery.point = roll
		bossData.lottery.aid = actorId
		local recordname = LActor.getName(actor)

		local ins = instancesystem.getInsByHdl(bossData.hfuben)
		if not ins then return end
		local actorList = ins:getActorList()
		for k, v in pairs(actorList) do
			s2cZhuZaiDraw(v, recordname, roll)
		end
	end
end

function s2cZhuZaiDraw(actor, name, roll)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_ZhuZaiDraw)
	LDataPack.writeString(pack, name)
	LDataPack.writeShort(pack, roll)
	LDataPack.flush(pack)
end

--主宰排名查看
function c2sZhuZaiRank(actor, packet)
	local id = LDataPack.readInt(packet) 
	local data = getGlobalData()
	local rank = data.damageRank[id] or {}

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_ZhuZaiRank)
	if pack == nil then return end
	LDataPack.writeInt(pack, id)
	LDataPack.writeShort(pack, #rank)
	for k, v in ipairs(rank) do
		LDataPack.writeInt(pack, k)
		LDataPack.writeString(pack, v.name)
		LDataPack.writeDouble(pack, v.damage)
	end
	LDataPack.flush(pack)
end

--------------------------------------------------------------------------------------------------------------

function onMonsterDie(ins, mon, killer_hdl)
	local id = ins.data.pzhuzaiid
	local bossData = getBossData(id)
	local conf = ZhuZaiFubenConfig[id]
	if not conf then return end
	bossData.isalive = 0
	bossData.hfuben = 0

	local rank = updateRank(id)
	local et = LActor.getEntity(killer_hdl)
	local killer_actor = LActor.getActor(et) --最后一击玩家
	local killName = LActor.getName(killer_actor)

	if rank and rank[1] then
		local firstName = LActor.getActorName(rank[1].aid)
		clearRankingRecord(id)
		for i=1, #rank do
			local aid = rank[i].aid
			local reward = drop.dropGroup(conf.rankDrops[i] or conf.rankDrops[#conf.rankDrops])--排名奖
			local exReward = {}
			if aid == LActor.getActorId(killer_actor) then --最后一击附加奖
				exReward = drop.dropGroup(conf.killDrop)
			end
			s2cZhuZaiResult(aid, 1, firstName, killName, i, conf, reward, exReward)
			if i <= ZhaZaiConfig.itemNum then
				setRankingRecord(id, i, LActor.getActorName(rank[i].aid), rank[i].dmg)
			end
		end
	end
	noticesystem.broadCastNotice(noticesystem.NTP.zhuzai2, killName, utils.getMonsterName(conf.bossId))
end

function onEnterFb(ins, actor)
	local id = ins.data.pzhuzaiid
	local bossData = getBossData(id)
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

function onExitFb(ins, actor)
	if not ins.is_win then --胜利的副本不加CD
		local var = getActorVar(actor)
		if not var then return end
		var.cdTime = System.getNowTime() + ZhaZaiConfig.cdTime
	end
	s2cZhuZaiInfo(actor)
end

function onOffline(ins, actor)
end

local function onBossDamage(ins, monster, value, attacker, res)
	local id = ins.data.pzhuzaiid
	local monid = Fuben.getMonsterId(monster)
	local conf = ZhuZaiFubenConfig[id]
	if monid ~= conf.bossId then
		return
	end
	local bossData = getBossData(id)

	--更新boss血量信息
	local oldhp = LActor.getHp(monster)
	if oldhp <= 0 then return end

	local hp = oldhp - value
	if hp < 0 then hp = 0 end
	hp = hp / LActor.getHpMax(monster) * 100

	bossData.monster = monster --记录BOSS实体

	--护盾判断
	if 0 == bossData.shield then --现在没有护盾
		if bossData.nextShield and 0 ~= bossData.nextShield.hp and hp < bossData.nextShield.hp then --从预备护盾里取护盾
			bossData.curShield = bossData.nextShield
			bossData.nextShield = getNextShield(id, bossData.curShield.hp) --再取下一个预备护盾
			
			res.ret = math.floor(LActor.getHpMax(monster) * bossData.curShield.hp / 100) --避免一招秒而不触发护盾，这里要恢复血量
			LActor.setInvincible(monster, true) --设无敌状态
			bossData.shield = bossData.curShield.shield + System.getNowTime()
			instancesystem.s2cShieldInfo(bossData.hfuben, 1, bossData.curShield.shield, bossData.curShield.shield)
			--注册护盾结束定时器
			bossData.shieldEid = LActor.postScriptEventLite(nil, bossData.curShield.shield*1000, finishShield, bossData)
			noticesystem.fubenCastNotice(bossData.hfuben, noticesystem.NTP.homeShield)
			startLottery(ins, conf.lotteryDrop)
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
	local id = ins.data.pzhuzaiid
	local bossData = getBossData(id)
	local actor = LActor.getActor(attacker)
	if actor == nil then return end
	local damageList = bossData.damageList
	local actorId = LActor.getActorId(actor)
	damageList[actorId] = (damageList[actorId] or 0) + value
end

function onLogin(actor)
	if System.isBattleSrv() then return end
	if not g_zhuzai_open then
		local var = getActorVar(actor)
		if var then var.curId = 0 end  --活动结束curId要设0
	end
	s2cZhuZaiInfo(actor)
end

function onLevelUp(actor, level, oldLevel)
	if System.isBattleSrv() then return end
	for k, v in pairs(ZhuZaiFubenConfig) do
		if v.level > oldLevel and v.level <= level then
			s2cZhuZaiInfo(actor) --因为等级从不能进到能进
			break
		end
	end
end

function ZhuZaiReady()
	-- if System.getOpenServerDay() < 1 then --第一天不开主宰活动
	-- 	return
	-- end
	if System.isBattleSrv() then return end
	noticesystem.broadCastNotice(noticesystem.NTP.zhuzai1)
end
_G.ZhuZaiReady = ZhuZaiReady

function ZhuZaiStart()
	-- if System.getOpenServerDay() < 1 then --第一天不开主宰活动
	-- 	return
	-- end
	if System.isBattleSrv() then return end
	g_zhuzai_open = true
	noticesystem.broadCastNotice(noticesystem.NTP.zhuzai5)
	g_end_time = System.getNowTime() + ZhaZaiConfig.zhuzaiTime
	for id, conf in pairs(ZhuZaiFubenConfig) do
		local hfuben = instancesystem.createFuBen(conf.fbId)
		g_zhuzaiData[id] = {
			id = conf.id,
			hfuben = hfuben,
			shield = 0,
			curShield = nil,
			nextShield = getNextShield(conf.id),
			damageList = {},
			bossId = conf.bossId,
			isalive = 1,
		}
		local ins = instancesystem.getInsByHdl(hfuben)
		if ins then
			ins.data.pzhuzaiid = id
			ins.data.bossid = conf.bossId
		end
	end
	local actors = System.getOnlineActorList() or {}
	for i =1, #actors do
		s2cZhuZaiInfo(actors[i])
	end
end
_G.ZhuZaiStart = ZhuZaiStart

function ZhuZaiStop()
	-- if System.getOpenServerDay() < 1 then --第一天不开主宰活动
	-- 	return
	-- end
	if System.isBattleSrv() then return end
	g_zhuzai_open = false
	local flag = false --有BOSS没死
	for id, conf in pairs(ZhuZaiFubenConfig) do
		local bossData = getBossData(id) or {}
		local ins = instancesystem.getInsByHdl(bossData.hfuben)
		if ins then
			flag = true
			local rank = updateRank(id)
			if rank and rank[1] then
				clearRankingRecord(id)
				local firstName = LActor.getActorName(rank[1].aid)
				for i=1, #rank do
					local aid = rank[i].aid
					local reward = drop.dropGroup(conf.rankDrops[i] or conf.rankDrops[#conf.rankDrops])
					s2cZhuZaiResult(aid, 0, firstName, "", i, conf, reward, {})
					if i <= ZhaZaiConfig.itemNum then
						setRankingRecord(id, i, LActor.getActorName(rank[i].aid), rank[i].dmg)
					end
				end
			end
		end
		bossData.hfuben = 0
		bossData.isalive = 1 --游戏结束，副本重置为未击杀状态
	end
	local actors = System.getOnlineActorList() or {}
	for i =1, #actors do
		local tor = actors[i]
		local var = getActorVar(tor)
		if var then var.curId = 0 end --活动结束curId要设0
		s2cZhuZaiInfo(tor)
	end
	if flag then
		noticesystem.broadCastNotice(noticesystem.NTP.zhuzai3)
	end
end
_G.ZhuZaiStop = ZhuZaiStop

onChangeName = function(actor, res, name, rawName, way)
	local data = getGlobalData()
	local rank = data.damageRank[id] or {}

	for k, v in ipairs(rank) do
		if v.name == rawName then
			v.name = name
		end		
	end
end

local function init()
	if System.isBattleSrv() then return end	
	actorevent.reg(aeChangeName, onChangeName)
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeLevel, onLevelUp)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_ZhuZaiFight, c2sZhuZaiFight)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_ZhuZaiRoll, c2sZhuZaiRoll)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_ZhuZaiRank, c2sZhuZaiRank)

	--注册相关回调
	for _, conf in pairs(ZhuZaiFubenConfig) do
		insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceExit(conf.fbId, onExitFb)
		--insevent.registerInstanceOffline(conf.fbId, onOffline)
		insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
		insevent.registerInstanceShieldOutput(conf.fbId, onShieldOutput)
	end
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.zhuzaifight = function (actor, args)
	c2sZhuZaiFight(actor)
end

gmCmdHandlers.zhuzaiready = function (actor, args)
	ZhuZaiReady()
end

gmCmdHandlers.zhuzaistart = function (actor, args)
	ZhuZaiStart()
end

gmCmdHandlers.zhuzaistop = function (actor, args)
	ZhuZaiStop()
end

gmCmdHandlers.zhuzairank = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sZhuZaiRank(actor, pack)
end

gmCmdHandlers.zhuzairoll = function (actor, args)
	c2sZhuZaiRoll(actor)
end

gmCmdHandlers.zhuzaiclearcd = function (actor, args)
	local var = getActorVar(actor)
	var.cdTime = System.getNowTime()
	s2cZhuZaiInfo(actor)
end
