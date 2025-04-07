module("dailyfuben", package.seeall)

local function getActorVar(actor, fubenGroup)----获得人物属性
	local data = LActor.getStaticVar(actor)
	if data == nil then return end

	if not data.dailyFubenData then data.dailyFubenData = {} end
	if not data.dailyFubenData[fubenGroup] then data.dailyFubenData[fubenGroup] = {} end
	if not data.dailyFubenData[fubenGroup].dailyFubenIdx then data.dailyFubenData[fubenGroup].dailyFubenIdx = 0 end --当前挑战的副本序号
	if not data.dailyFubenData[fubenGroup].isfirst then data.dailyFubenData[fubenGroup].isfirst = 0 end --是否第一次挑战
	return data.dailyFubenData[fubenGroup]
end

local function onLogin(actor)----登录触发的函数
	onSendFubenInfo(actor)
end

local function onZhuansheng( actor, level, oldLevel)
	local change = false
	for fubenGroup, conf in pairs(DailyFubenConfig) do
		for idx=1, #conf do
			if conf[idx].zsLevel > oldLevel and conf[idx].zsLevel <= level then
				local var = getActorVar(actor, fubenGroup)
				if var.dailyFubenIdx ~= idx then
					change = true
				end
			end
		end
	end
	if change then
		onSendFubenInfo(actor)
	end
end

local function onNewDay(actor, login)-----新的一天
	local actorlevel = LActor.getLevel(actor)
	for fubenGroup, _ in pairs(DailyFubenConfig) do
		local var = getActorVar(actor, fubenGroup)
		var.saodangCount = 0 --已扫荡次数
		var.fightCount = 0
	end
	if not login then
		onSendFubenInfo(actor)
	end
end

local function getawards(fubenGroup)----获得奖励
	local baseConfig = BaseDailyFubenConfig[fubenGroup]
	if not baseConfig then return end

	if next(baseConfig.awards) then
		return baseConfig.awards[1].id,baseConfig.awards[1]
	end
end

local function getBossawards(fubenId)----获得BOSS奖励
	local rId = FubenConfig[fubenId].refreshMonster
	local rmConf = RefreshMonsters[rId]
	local monsterId = rmConf.monsters[#rmConf.monsters].monsterid
	local rewards = monsterdrop.randomDropResult(monsterId) --查boss掉落物品
	return rewards
end

--扫荡副本
function saodangFuben(actor, fubenGroup)
	local var = getActorVar(actor, fubenGroup)
	if not var or var.fightCount == 0 then return end
	--onSendFubenInfo(actor)

	if not actoritem.checkItem(actor, NumericType_YuanBao, BaseDailyFubenConfig[fubenGroup].moneyCount[(var.saodangCount or 0) + 1]) then----判断是否够砖石
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, BaseDailyFubenConfig[fubenGroup].moneyCount[(var.saodangCount or 0)+1], "dailysaodanfuben")

	local dailyConf = DailyFubenConfig[fubenGroup][var.dailyFubenIdx]
	local fubenId = dailyConf.fbId
	local items = {}
	local exp = 0
	local double = 1
	if subactivity12.checkIsStart() then
		double = 2
	end
	local bossReward = getBossawards(fubenId)
	for k, v in pairs(bossReward) do
		v.count = v.count * double
		if v.type == 1 then
			table.insert(items, v)
		end
	end

	local _,item = getawards(fubenGroup)
	if item then
		table.insert(items, {type=item.type, id=item.id, count=(var.result or DailyFubenConfig[fubenGroup][var.dailyFubenIdx].minCount[1].count)*double})
	end
	var.saodangCount = (var.saodangCount or 0) + 1
	actoritem.addItems(actor, items, "sao dang daily fuben_"..fubenId)
	instancesystem.onSendSaodangAwards(actor, fubenGroup, exp, items)
	actorevent.onEvent(actor, aeSaoDang, fubenId, 1)
	onSendFubenInfo(actor)
end

--进入副本，设置展示id，收获展示物品后会发送给客户端
local function onEnterFb(ins, actor)
	local fubenGroup = FubenConfig[ins.id].group
	local id,_ = getawards(fubenGroup)
	if id then
		ins.exhibit.id = id
	end
	setScoreTimer(actor, ins.config.group, true)
end

local function setChallengeResultfrompicks(var,ins,actorid,srcgrp,id)----设置挑战回报从选择中
	local flag = (var and ins and actorid and srcgrp and id)
	if not flag then return end
	if ins.actor_list and ins.actor_list[actorid] and ins.actor_list[actorid].exp then
		var.result = ins.actor_list[actorid].exp
		return
	end
	if not (ins.actor_list and ins.actor_list[actorid] and ins.actor_list[actorid].picks) then return end

	for _, v in ipairs(ins.actor_list[actorid].picks) do
		if v.id == id then
			var.result = v.count
			break
		end
	end
end

--日常副本结算奖励，记录最高的奖励
local function onChallengeResult(ins, actor)
	if not ins then return end
	if not actor then actor = ins:getActorList()[1] end
	local fubenId = LActor.getFubenId(actor)
	local fubenGroup = FubenConfig[fubenId].group
	local baseConfig = BaseDailyFubenConfig[fubenGroup]
	if not baseConfig then return end
	local var = getActorVar(actor, fubenGroup)
	if not var then return end
	var.isfirst = 1
	local actorId = LActor.getActorId(actor)
	local id,item = getawards(FubenConfig[fubenId].group)
	setChallengeResultfrompicks(var, ins, actorId, FubenConfig[fubenId].group, id)

	if DailyFubenConfig[fubenGroup][var.dailyFubenIdx] then
		var.result = math.max(var.result or 0, DailyFubenConfig[fubenGroup][var.dailyFubenIdx].minCount[1].count)
	end

	var.score = 0
	onSendFubenInfo(actor)
	if fubenGroup == fubencommon.gold then
		subactivity1.onGetGold(actor, var.result)
	elseif  fubenGroup == fubencommon.talent then
		subactivity1.onGetTalent(actor, var.result)
	end
end

local function onWin(ins, actor)----赢了的函数
	onChallengeResult(ins, actor)
	-- if not actor then actor = ins:getActorList()[1] end
	-- local fubenId = LActor.getFubenId(actor)
	-- local fubenGroup = FubenConfig[fubenId].group
	-- local baseConfig = BaseDailyFubenConfig[fubenGroup]
	-- if not baseConfig then return end
	-- local var = getActorVar(actor, fubenGroup)
	-- if not var then return end
	-- if var.isfirst == 0 then
	-- 	var.isfirst = 1
	-- 	onSendFubenInfo(actor)
	-- end
end

local function onChallengeExit(ins, actor)----挑战退出
	local fubenId = LActor.getFubenId(actor)
	local fubenGroup = FubenConfig[fubenId].group
	local baseConfig = BaseDailyFubenConfig[fubenGroup]
	if not baseConfig then return end
	local var = getActorVar(actor, fubenGroup)
	if not var then return end
	onChallengeResult(ins, actor)
end

function onActorDie(ins)
	ins:lose()
end

local function onMonsterAllDie(ins, mon)----怪物全死了的函数
	local fubenGroup = FubenConfig[ins.id].group
	local actor = ins:getActorList()[1]
	if not actor then return end
	local var = getActorVar(actor, fubenGroup)
	local conf = DailyFubenConfig[fubenGroup][var.dailyFubenIdx]
	if conf then
		local items = conf.wavedrop[ins.refresh_monster_idx]
		if items then
			local monPosX, monPosY = LActor.getEntityScenePoint(mon)
			ins:addDropBagItem(actor, items, 100, monPosX, monPosY)
		end
	end
end

function getFubenByZSLevel(actor, fubenGroup)
	local fubenId = 0
	local idx = BaseDailyFubenConfig[fubenGroup].firstIdx
	local zsLevel = zhuansheng.getZSLevel(actor)
	local var = getActorVar(actor, fubenGroup)
	if var.isfirst == 0 and idx >= 0 then
		fubenId = DailyFubenConfig[fubenGroup][idx].fbId
		return fubenId, idx
	end
	for _, conf in ipairs(DailyFubenConfig[fubenGroup]) do
		if zhuansheng.checkZSLevel(actor, conf.zsLevel) then
			fubenId = conf.fbId
			idx = conf.idx
		else
			break
		end
	end
	return fubenId, idx
end

function isFirstChallenge(actor, fubenGroup)
	local var = getActorVar(actor, fubenGroup)
	if var.isfirst == 0 and BaseDailyFubenConfig[fubenGroup].firstIdx >= 0 then
		return true
	end
	return false
end

-----------------------------------------------------------------------------------------------------------------
--每日副本信息
function onSendFubenInfo(actor)
	if not actor then return end
	local len = 0
	for __,__ in pairs(BaseDailyFubenConfig) do
		len = len + 1
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sDaily_FubenInfo)
	if not pack then return end
	LDataPack.writeInt(pack, len)
	for fubenGroup in pairs(BaseDailyFubenConfig) do
		local flag = 0
		local conf = BaseDailyFubenConfig[fubenGroup]
		local var = getActorVar(actor, fubenGroup)
		LDataPack.writeInt(pack, fubenGroup)
		local fubenId, idx = getFubenByZSLevel(actor, fubenGroup)
		LDataPack.writeInt(pack, fubenId)
		LDataPack.writeShort(pack, conf.fightCount - (var.fightCount or 0))
		LDataPack.writeShort(pack, var.saodangCount or 0)
		LDataPack.writeInt(pack, var.result or 0)
		if var.dailyFubenIdx == idx and idx ~= 0 then
			flag = 1
		end
		LDataPack.writeChar(pack, flag)
	end
	LDataPack.flush(pack)
end

function getResult(actor, fubenGroup)
	local var = getActorVar(actor, fubenGroup)
	return var.result or 0
end

function getLimitId(fubenGroup)
	return 1
end

--进入副本
local function onChallenge(actor, packet)
	local fubenGroup = LDataPack.readInt(packet)

	local baseConfig = BaseDailyFubenConfig[fubenGroup]
	local var = getActorVar(actor, fubenGroup)
	if (var.fightCount or 0) >= baseConfig.fightCount then return end
	--if not actorexp.checkLevelCondition(actor, getLimitId(fubenGroup)) then return end
	if guajifuben.getCustom(actor) < baseConfig.condition.custom then return end
	if LActor.getLevel(actor) < baseConfig.condition.level then return end

	local fubenId,idx = getFubenByZSLevel(actor, fubenGroup)
	if not fubenId == 0 then return end

	if not utils.checkFuben(actor, fubenId) then return end

	local hfuben = instancesystem.createFuBen(fubenId)
	if hfuben == 0 then
		print("create dailyfuben failed."..fubenId)
		return
	end

	local ins = instancesystem.getInsByHdl(hfuben)
	if ins then
		ins.data.double = subactivity12.checkIsStart() and 1 or 0
	end

	var.dailyFubenIdx = idx
	--var.result = math.max(var.result or 0, DailyFubenConfig[fubenGroup][idx].minCount[1].count)
	if not isFirstChallenge(actor, fubenGroup) then
		var.fightCount = (var.fightCount or 0) + 1
	end
	--onSendFubenInfo(actor)
	local x, y = utils.getSceneEnterCoor(fubenId)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
end

function c2sOnekey(actor, packet)
	local svip = LActor.getSVipLevel(actor)
	if not privilege.isBuyPrivilege(actor) then return end
	local double = 1
	if subactivity12.checkIsStart() then
		double = 2
	end
	local type = LDataPack.readChar(packet)
	local custom = guajifuben.getCustom(actor)
	local level = LActor.getLevel(actor)
	if type == 1 then
		local items = {}
		local ritems = {}
		local bitems = {}
		for k, v in pairs(BaseDailyFubenConfig) do
			local var = getActorVar(actor, k)
			local fubenId,idx = getFubenByZSLevel(actor, k)

			if custom >= v.condition.custom and level >= v.condition.level and var.dailyFubenIdx == idx and idx ~= 0 then
				local id = getawards(k)
				if id then
					actorevent.onEvent(actor, aeSaoDang, fubenId,  v.fightCount - var.fightCount)
					for i=var.fightCount+1, v.fightCount do
						ritems[id] = (ritems[id] or 0) + (var.result or DailyFubenConfig[k][idx].minCount[1].count)
						local bossReward = getBossawards(fubenId)
						for k, v in pairs(bossReward) do
							if v.type == 1 then
								bitems[v.id] = (bitems[v.id] or 0) + v.count
							end
						end
						var.fightCount = var.fightCount + 1
					end
				end
			end
		end
		for k,v in pairs(ritems) do
			items[#items+1] = {type = 1, id = k, count = v*double}
		end
		for k,v in pairs(bitems) do
			items[#items+1] = {type = 1, id = k, count = v*double}
		end
		if #items > 0 then
			actoritem.addItems(actor, items, "sao dang daily fuben one key")
			onSendFubenInfo(actor)
			local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DailyOneKey)
			LDataPack.writeChar(pack, type)
			LDataPack.flush(pack)
		end
	else
		local need = 0
		for k, v in pairs(BaseDailyFubenConfig) do
			local var = getActorVar(actor, k)
			if v.fightCount <= var.fightCount then
				for i=(var.saodangCount or 0)+1, SVipConfig[svip].dailysaodang do
					need = need + v.moneyCount[i]
				end
			end
		end

	 	if not actoritem.checkItem(actor, NumericType_YuanBao, need) then
			return
		end

		actoritem.reduceItem(actor, NumericType_YuanBao, need, "saodang dailyfuben one key")
		local items = {}
		local ritems = {}
		local bitems = {}
		for k, v in pairs(BaseDailyFubenConfig) do
			local var = getActorVar(actor, k)
			local fubenId,idx = getFubenByZSLevel(actor, k)
			if v.fightCount <= var.fightCount then
				local _,item = getawards(k)
				if item then
					actorevent.onEvent(actor, aeSaoDang, fubenId, SVipConfig[svip].dailysaodang - (var.saodangCount or 0))
					for i=(var.saodangCount or 0)+1, SVipConfig[svip].dailysaodang do
						ritems[item.id] = (ritems[item.id] or 0) + (var.result or DailyFubenConfig[k][idx].minCount[1].count)
						local bossReward = getBossawards(fubenId)
						for k, v in pairs(bossReward) do
							if v.type == 1 then
								bitems[v.id] = (bitems[v.id] or 0) + v.count
							end
						end
						var.saodangCount = (var.saodangCount or 0) + 1
					end
				end
			end
		end
		for k,v in pairs(ritems) do
			items[#items+1] = {type = 1, id = k, count = v*double}
		end

		for k,v in pairs(bitems) do
			items[#items+1] = {type = 1, id = k, count = v*double}
		end
		if #items > 0 then
			actoritem.addItems(actor, items, "sao dang daily fuben one key")
			onSendFubenInfo(actor)
			local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DailyOneKey)
			LDataPack.writeChar(pack, type)
			LDataPack.flush(pack)
		end
	end
end

--杀怪处理, 增加积分（之后要处理收获奖励）
local function onMonsterDie(ins, mon, killer_hdl)
	local et = LActor.getEntity(killer_hdl)
	local actor = LActor.getActor(et)
	local var = getActorVar(actor, ins.config.group)
	if not var then return end
	var.score = (var.score or 0) + 1 --杀怪数量
	setScoreTimer(actor, ins.config.group)
end

function setScoreTimer(actor, group, isinit)
	local var = getActorVar(actor, group)
	if isinit then
		var.score = 0
		if (group == fubencommon.talent or group == fubencommon.gold) then
			local now = System.getNowTime()
			if (var.scoreTime or 0) > now then return end
			var.scoreTime = now + 1 --限制1秒后才发送下一次
		end
	end
	s2cDailyFubenScore(actor, group, var.score)
end

function s2cDailyFubenScore(actor, group, score)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DailyKillInfo)
	if pack == nil then return end
	LDataPack.writeInt(pack, group) --
	LDataPack.writeInt(pack, score or 0) --杀怪个数
	LDataPack.flush(pack)
end


--免费扫荡副本
local function onSaodangFuben(actor, packet)
	local fubenGroup = LDataPack.readInt(packet)
	local var = getActorVar(actor, fubenGroup)
	--if not var or not var.dailyFubenIdx then return end

	local svip = LActor.getSVipLevel(actor)
	if (var.saodangCount or 0) >= SVipConfig[svip].dailysaodang then
		return
	end

	--var.saodangCount = (var.saodangCount or 0) + 1
	saodangFuben(actor, fubenGroup)
end

local function init()
	actorevent.reg(aeNewDayArrive, onNewDay)
	if System.isCrossWarSrv() then return end
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeZhuansheng, onZhuansheng)

	--netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cDaily_BuyFubenCount, onBuySaodangCount)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cDaily_ChallengeFuben, onChallenge)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cDaily_SaodangFuben, onSaodangFuben)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_DailyOneKey, c2sOnekey)


	for group, v in pairs(DailyFubenConfig) do
		for _, conf in pairs(v) do
			insevent.registerInstanceEnter(conf.fbId, onEnterFb)
			insevent.registerInstanceWin(conf.fbId, onWin)
			insevent.registerInstanceLose(conf.fbId, onChallengeResult)
			insevent.registerInstanceExit(conf.fbId, onChallengeExit)
			insevent.registerInstanceActorDie(conf.fbId, onActorDie)
			insevent.registerInstanceMonsterAllDie(conf.fbId, onMonsterAllDie)
			insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
		end
	end
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.dailyFight = function (actor)
	local fubenGroup = 10002
	local var = getActorVar(actor, fubenGroup)
	local fubenId, idx = getFubenByZSLevel(actor, fubenGroup)
	if not fubenId == 0 then
		return
	end
	if not utils.checkFuben(actor, fubenId) then return end
	local hfuben = instancesystem.createFuBen(fubenId)
	var.dailyFubenIdx = idx
	var.result = 0
	var.fightCount = (var.fightCount or 0) + 1
	onSendFubenInfo(actor)
	local x, y = utils.getSceneEnterCoor(fubenId)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
	return true
end

