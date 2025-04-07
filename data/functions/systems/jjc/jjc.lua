-- @version	1.0
-- @author	qianmeng
-- @date	2017-6-5 21:08:54.
-- @system	竞技场

module("jjc", package.seeall)
require("jjc.jjcconst")
require("jjc.jjcmatch")
require("jjc.jjcaward")
require("jjc.jjcrobot")

local DefRobotId = 21

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var.jjcData then
		var.jjcData = {
			fightTimes = 0, --挑战次数
			buyTimes = 0,	--购买次数
			nextTime = 0,	--下一次进入时间
		}
	end
	local jjcData = var.jjcData
	if not jjcData.history then jjcData.history = JjcConstConfig.maxRankCount + 1 end --历史最高排名
	if not jjcData.rivalId then jjcData.rivalId = 0 end --对战对手的id
	if not jjcData.downTime then jjcData.downTime = 0 end --开始战斗时刻
	if not jjcData.exitTime then jjcData.exitTime = 0 end --结束战斗时刻
	return jjcData
end


function getRankAwardSection(idx)
	local id = 0
	for k, v in ipairs(JjcRewardConfig) do
		if idx >= v.rank then
			id = k
		else
			break
		end
	end
	return id
end

function getRankMatchSection(idx)
	local id = 0
	for k, v in ipairs(JjcMatchConfig) do
		if idx >= v.rank then
			id = k
		else
			break
		end
	end
	return id
end

--求历史奖励
function getHistoryReward(new, old)
	local sum = 0
	old = old - 1 --因为原排名的奖励在上一次已拿过
	for k, v in ipairs(JjcRewardConfig) do
		if new <= v.most then --开始累加
			local a = math.max(v.rank, new)
			local b = math.min(v.most, old)
			sum = sum + (b - a + 1) * v.historyReward
			if old <= v.most then --退出累加
				break
			end
		end
	end
	return math.ceil(sum) --向上取整小数
end

function getJjcData(ins)
	if ins.data.jjcData then
		return ins.data.jjcData
	end
	ins.data.jjcData = {}
	local jjcData = ins.data.jjcData

	return jjcData
end

--匹配对手排名
function matchRival(idx)
	local rivals = {}
	local id = getRankMatchSection(idx)
	if not JjcMatchConfig[id] then return end
	local low = math.max(1, idx - JjcMatchConfig[id].forward)
	local high = math.min(JjcConstConfig.maxRankCount, idx + JjcMatchConfig[id].backward)

	return utils.getRandomIndexs(low, high, 3, idx) --不重复随机数，限制匹配到自身
end

--根据actorId设置新排名
-- function setJjcRank(actor_id, ranking)
-- 	local score = JjcConstConfig.maxRankCount + 1 - ranking
-- 	jjcrank.updateRankingList(actor_id, score)
-- end

--求子角色职业
function getRoleJobs(actor_id)
	local jobs = {}
	local tor = LActor.getActorById(actor_id)
	if tor then
		local role = LActor.getRole(tor)
		local job = LActor.getJob(role)
		table.insert(jobs, job)
	else
		local actorData = offlinedatamgr.GetDataByOffLineDataType(actor_id, offlinedatamgr.EOffLineDataType.EBasic)
		if not actorData then return jobs end
		table.insert(jobs, actorData.job)
	end
	return jobs
end

--求第一角色数据
function getFirstRoleData(actor_id, data)
	local basic_data = LActor.getActorDataById(actor_id)
	if not basic_data then return end
	data.id = actor_id
	data.name = basic_data.actor_name
	data.level = basic_data.level
	data.power = basic_data.total_power
	data.job = basic_data.job
	local tor = LActor.getActorById(actor_id)
	if tor then
		local roleData = LActor.getRoleData(tor)
		local slotdata = roleData.equips_data.slot_data
		local wingData = roleData.wings.wdatas[0]
		data.weapon = slotdata[EquipSlotType_Weapon].equip_data.id
		data.cloth = slotdata[EquipSlotType_Coat].equip_data.id
		data.wshine = LActor.getRoleShineWeapon(tor, 0)
		data.ashine = LActor.getRoleShineArmor(tor, 0)
		data.wingId = 0
	else
		local actorData = offlinedatamgr.GetDataByOffLineDataType(actor_id, offlinedatamgr.EOffLineDataType.EBasic)
		if actorData then
			data.weapon = actorData.equips[EquipSlotType_Weapon+1].id
			data.cloth = actorData.equips[EquipSlotType_Coat+1].id
			data.wshine = actorData.ShineWeapon
			data.ashine = actorData.ShineArmor
			data.wingId = 0
		else
			--容错处理，在玩家数据不存在时，使用机器人数据
			local robot = JjcRobotConfig[DefRobotId]
			data.id = robot.id
			data.name = chatcommon.getServerConfName().."."..robot[0].name
			data.level = robot[0].level
			data.job = robot[0].job
			data.weapon = robot[0].weaponId
			data.cloth = robot[0].clothesId
			data.wshine = robot[0].shineWeapon
			data.ashine = robot[0].shineArmor
			data.wingId = robot[0].wingId
			data.power = robot[0].power
		end

	end
end

--生成对战对手
local function challengRival(actor, ins)
	local var = getActorVar(actor)
	local roleCloneData = nil
	local actorData = nil
	local roleSuperData = nil
	if JjcRobotConfig[var.rivalId] then --对手是机器人
		roleCloneData, actorData, roleSuperData = actorcommon.createRobotClone(JjcRobotConfig, var.rivalId)
	else --对手是玩家
		roleCloneData, actorData, roleSuperData = actorcommon.getCloneData(var.rivalId)
		if not roleCloneData then--读不到数据时的容错处理
			roleCloneDatas, actorData, roleSuperData = actorcommon.createRobotClone(JjcRobotConfig, DefRobotId)
		end
	end

	if roleSuperData then
		roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
		roleSuperData.aiId = FubenConstConfig.roleSuperAi
	end

	local tarPos = JjcConstConfig.tarPos
	local actorid = var.rivalId
	local sceneHandle = ins.scene_list[1]
	local x = tarPos[1][1]
	local y = tarPos[1][2]
	local actorClone = LActor.createActorCloneWithData(actorid, sceneHandle, x, y, actorData, roleCloneData, roleSuperData)

	local roleClone = LActor.getRole(actorClone)
	if roleClone then
		local pos = tarPos[1]
		LActor.setEntityScenePos(roleClone, pos[1], pos[2])
	end
	local yongbing = LActor.getYongbing(actorClone)
	if yongbing then
		local pos = tarPos[2]
		LActor.setEntityScenePos(yongbing, pos[1], pos[2])
	end

	--定身
	LActor.addSkillEffect(actorClone, JjcConstConfig.bindEffectId)
	LActor.addSkillEffect(actor, JjcConstConfig.bindEffectId)
end

--竞技结果
function challengesResult(actor, ins, win)
	local var = getActorVar(actor)
	local oldRanking = jjcrank.getrank(actor) --旧排名
	local rivalRanking = jjcrank.getrankById(var.rivalId) --对手排名
	local ranking = oldRanking --新排名
	local reward = false
	local id = getRankAwardSection(rivalRanking)
	local rise = 0 --升了多少名
	local num = 0 --升排名奖励

	if win then
		reward = JjcRewardConfig[id].winReward
		if rivalRanking < oldRanking then
			rise = oldRanking - rivalRanking
			ranking = rivalRanking
			--与对手交换排名
			jjcrank.swapRankingItem(LActor.getActorId(actor), var.rivalId)

			--自己与对手的排名变化事件
			actorevent.onEvent(actor, aeJjcRank, ranking)
			local tor = LActor.getActorById(var.rivalId)
			if tor then --是玩家并且在线
				actorevent.onEvent(tor, aeJjcRank, oldRanking)
			end
			if not JjcRobotConfig[var.rivalId] then --被击败玩家发邮件
				local mail_data = {}
				mail_data.head = JjcConstConfig.rankMailHead1
				mail_data.context = string.format(JjcConstConfig.rankMailContext1, LActor.getName(actor), oldRanking)
				mail_data.tAwardList = {}
				mailsystem.sendMailById(var.rivalId, mail_data)
			end
			if rivalRanking <= 3 then
				noticesystem.broadCastNotice(noticesystem.NTP.jjcrank, LActor.getName(actor), rivalRanking)
			end
		end
	else
		reward = JjcRewardConfig[id].loseReward
		var.nextTime = System.getNowTime() + JjcConstConfig.cdTime
		updateCdTime(actor)
	end

	local history = var.history --要发送新排名之前的数据给客户端
	if ranking < var.history then --记录历史最高排名
		num = getHistoryReward(ranking, var.history)
		var.history = ranking
		instancesystem.setInsRewards(ins, actor, {{type=0,id=NumericType_YuanBao,count=num}})
	end
	local tmp = {}
	local exRate = ins.data.exRate or 1
	for k,v in ipairs(reward) do
		tmp[k] = {}
		tmp[k].id = v.id
		tmp[k].type = v.type
		tmp[k].count =  v.count * exRate
	end
	instancesystem.setInsRewards(ins, actor, tmp)
	local time = 0 --战斗所花时间
	s2cJjcResult(actor, win, tmp, time, ranking, history, num)
end

function updateCdTime(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_JJC, Protocol.sJjcCmd_ClearCD)
	LDataPack.writeInt(pack, math.max(0, var.nextTime - System.getNowTime()))
	LDataPack.flush(pack)
end

--战斗开始
function startFight(actor, ins)
	if ins.is_end then --副本已结束
		return
	end
	challengRival(actor, ins) --刷出对手
	s2cJjcDao(actor)
end

local function onLogin(actor)
	if System.isCrossWarSrv() then return end
	s2cJjcInfo(actor)
end

local function onNewDay(actor, login)
	local var = getActorVar(actor)
	var.fightTimes = 0
	var.buyTimes = 0
	var.nextTime = 0
	if not login then
		s2cJjcInfo(actor)
	end
end

function onJjcRankChange(actor, ranking)
	if System.isCrossWarSrv() then return end
	s2cJjcInfo(actor)
end

--------------------------------------------------------------------------------------------
--竞技场信息
function s2cJjcInfo(actor)
	local var = getActorVar(actor)
	if not var then return end
	local cdTime = math.max(0, var.nextTime - System.getNowTime())
	local idx = jjcrank.getrank(actor)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_JJC, Protocol.sJjcCmd_Info)
	if pack == nil then return end
	LDataPack.writeShort(pack, idx)
	LDataPack.writeShort(pack, var.fightTimes)
	LDataPack.writeShort(pack, var.buyTimes)
	LDataPack.writeInt(pack, cdTime) --冷却时间
	LDataPack.writeShort(pack, var.history)
	LDataPack.flush(pack)
end

--玩家刷新对手
local function c2sJjcRefresh(actor,packet)
	local var = getActorVar(actor)
	local idx = jjcrank.getrank(actor)
	local rivals = matchRival(idx) --取得匹配对手的排名
	if not rivals then return end
	table.sort(rivals)

	local rankTbl = jjcrank.getRankTbl(rivals[#rivals]) --读取排名数量至排位最低的那位
	if rankTbl == nil then rankTbl = {} end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_JJC, Protocol.sJjcCmd_Refresh)
	if pack == nil then return end
	LDataPack.writeChar(pack, #rivals)
	for k, v in ipairs(rivals) do
		local prank = rankTbl[v]
		local actor_id = Ranking.getId(prank)
		local isRobot = Ranking.getSubInt(prank, 6)
		local rival = {id=0, name="", level=0, power=0, jobs={}}
		local isFail = false --是否找不到数据
		if JjcRobotConfig[actor_id] then --对手是机器人
			local robot = JjcRobotConfig[actor_id] --机器人id
			rival.id = robot.id
			rival.name = chatcommon.getServerConfName().."."..robot.name
			rival.level = robot.level
			rival.power = robot.power --使用策划算好的值，免得玩家输给战斗力低的机器人
			rival.job = robot.job
			rival.shenzhuang = robot.shenzhuang
			rival.shenqi = robot.shenqi
			rival.wing = robot.wing
		else   --对手是玩家
			local actor_id = Ranking.getId(prank)
			local roledata = actorcommon.getCloneData(actor_id)
			if roledata then
				rival.id = actor_id
				rival.name = roledata.name
				rival.level = roledata.level
				rival.power = roledata.total_power
				rival.job = roledata.job
				rival.shenzhuang = roledata.shenzhuangchoose
				rival.shenqi = roledata.shenqichoose
				rival.wing = roledata.wingchoose
			else
				actor_id = DefRobotId
				local robot = JjcRobotConfig[actor_id]
				rival.id = robot.id
				rival.name = chatcommon.getServerConfName().."."..robot.name
				rival.level = robot.level
				rival.power = robot.power --使用策划算好的值，免得玩家输给战斗力低的机器人
				rival.job = robot.job
				rival.shenzhuang = robot.shenzhuang
				rival.shenqi = robot.shenqi
				rival.wing = robot.wing
			end
		end
		local num = getHistoryReward(v, var.history) --胜利获得钻石

		LDataPack.writeShort(pack, isFail and DefRobotId or v) --排名
		LDataPack.writeInt(pack, actor_id)
		LDataPack.writeString(pack, rival.name)
		LDataPack.writeInt(pack, rival.level)
		LDataPack.writeDouble(pack, rival.power)
		LDataPack.writeChar(pack, rival.job)
		LDataPack.writeInt(pack, rival.shenzhuang)
		LDataPack.writeInt(pack, rival.shenqi)
		LDataPack.writeInt(pack, rival.wing)
		LDataPack.writeByte(pack, isRobot)
		LDataPack.writeInt(pack, math.max(num, 0))
	end
	LDataPack.flush(pack)
end

--查看排名前三的对手
local function c2sJjcThrone(actor,packet)
	local rivals = {1, 2, 3}
	local rankTbl = jjcrank.getRankTbl(rivals[#rivals]) --读取排名数量至排位最低的那位
	if rankTbl == nil then rankTbl = {} end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_JJC, Protocol.sJjcCmd_Throne)
	if pack == nil then return end
	LDataPack.writeChar(pack, #rivals)
	for k, v in ipairs(rivals) do
		local prank = rankTbl[v]
		local actor_id = Ranking.getId(prank)
		local isRobot = Ranking.getSubInt(prank, 6)
		local rival = {id=0, name="", level=0, power=0, job=0, weapon=0, cloth=0, wshine=0, ashine=0, wingSt=0, wingLv=0}

		if JjcRobotConfig[actor_id] then --对手是机器人
			local robot = JjcRobotConfig[actor_id] --机器人id
			rival.id = robot.id
			rival.name = chatcommon.getServerConfName().."."..robot.name
			rival.level = robot.level
			rival.power = robot.power --使用策划算好的值，免得玩家输给战斗力低的机器人
			rival.job = robot.job
			rival.shenzhuang = robot.shenzhuang
			rival.shenqi = robot.shenqi
			rival.wing = robot.wing
		else   --对手是玩家
			local roledata = actorcommon.getCloneData(actor_id)
			if roledata then
				rival.id = actor_id
				rival.name = roledata.name
				rival.level = roledata.level
				rival.power = roledata.total_power
				rival.job = roledata.job
				rival.shenzhuang = roledata.shenzhuangchoose
				rival.shenqi = roledata.shenqichoose
				rival.wing = roledata.wingchoose
			end
		end

		LDataPack.writeShort(pack, k) --排名
		LDataPack.writeInt(pack, actor_id)
		LDataPack.writeString(pack, rival.name)
		LDataPack.writeInt(pack, rival.level)
		LDataPack.writeDouble(pack, rival.power)
		LDataPack.writeChar(pack, rival.job)
		LDataPack.writeInt(pack, rival.shenzhuang or 0)
		LDataPack.writeInt(pack, rival.shenqi or 0)
		LDataPack.writeInt(pack, rival.wing or 0)
		LDataPack.writeByte(pack, isRobot)
	end
	LDataPack.flush(pack)
end


local function c2sJjcBuy(actor,packet)
	local var = getActorVar(actor)
	local vip = LActor.getSVipLevel(actor)
	if var.buyTimes >= SVipConfig[vip].jjcbuy then return end
	if not actoritem.checkItem(actor, NumericType_YuanBao, JjcConstConfig.buyPrice[var.buyTimes+1]) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, JjcConstConfig.buyPrice[var.buyTimes+1], "buy jjc fightTimes")

	var.fightTimes = var.fightTimes - 1
	var.buyTimes = var.buyTimes + 1

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_JJC, Protocol.sJjcCmd_Buy)
	if pack == nil then return end
	LDataPack.writeShort(pack, var.fightTimes)
	LDataPack.writeShort(pack, var.buyTimes)
	LDataPack.flush(pack)
	utils.logCounter(actor, "jjc buy")
end

local function fightFuben(actor, rivalId, fightTimes)
	local hfuben = instancesystem.createFuBen(JjcConstConfig.fuBen.id)
	if hfuben == 0 then return end
	local ins = instancesystem.getInsByHdl(hfuben)
	if ins == nil then return end

	ins.data.exRate = fightTimes
	local now = System.getNowTime()
	local var = getActorVar(actor)
	var.rivalId = rivalId
	var.fightTimes = var.fightTimes + fightTimes
	var.downTime = now + 5 --开始时间
	var.exitTime = now + JjcConstConfig.fightTime + 5 --结束时间
	local x,y = utils.getSceneEnterCoor(ins.id)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
	actorevent.onEvent(actor, aeEnterJjc, fightTimes)


	local pack = LDataPack.allocPacket(actor, Protocol.CMD_JJC, Protocol.sJjcCmd_Fight)
	if pack == nil then return end
	LDataPack.writeShort(pack, var.fightTimes)
	LDataPack.writeInt(pack, math.max(0, var.nextTime - System.getNowTime())) --冷却时间
	LDataPack.flush(pack)
end

--竞技场战斗
local function c2sJjcFight(actor, packet)
	local actor_id = LDataPack.readInt(packet)

	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.jjc) then return end
	local var = getActorVar(actor)

	local t = var.nextTime - System.getNowTime()
	if t > 0 then
		LActor.sendTipmsg(actor, string.format(ScriptTips.fuben05, t), ttScreenCenter)
		return
	end

	local fightTimes = neigua.checkOpenNeigua(actor, FubenConfig[JjcConstConfig.fuBen.id].group, JjcConstConfig.challengesCount - var.fightTimes)
	if fightTimes <= 0 then return end

	if LActor.getActorId(actor) == actor_id then --不能挑战自己
		LActor.sendTipmsg(actor, string.format(ScriptTips.fuben06, t), ttScreenCenter)
		return
	end

	local rIdx = jjcrank.getrankById(actor_id)
	if rIdx > JjcConstConfig.maxRankCount then return end --对手不在排行榜内
	if rIdx <= 3 then
		if jjcrank.getrank(actor) > JjcConstConfig.highRank then --王座对手要前20名才能挑战
			return
		end
	end

	fightFuben(actor, actor_id, fightTimes)
	utils.logCounter(actor, "jjc fight", actor_id)
end

--清除倒计时
function c2sJjcClearCd(actor)
	local var = getActorVar(actor)
	local remain = math.max(0, var.nextTime - System.getNowTime())
	if remain <= 0 then
		return
	end

	if not actoritem.checkItem(actor, NumericType_YuanBao, math.ceil(remain * JjcConstConfig.cdPrice)) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, math.ceil(remain * JjcConstConfig.cdPrice), "jjc clear cd time")
	var.nextTime = 0
	updateCdTime(actor)
end

--竞技场结果
function s2cJjcResult(actor, win, reward, time, ranking, history, number)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_JJC, Protocol.sJjcCmd_Result)
	if pack == nil then return end
	LDataPack.writeByte(pack, win and 1 or 0)
	LDataPack.writeShort(pack, #reward)
	for k,v in pairs(reward) do
		LDataPack.writeInt(pack, v.type)
		LDataPack.writeInt(pack, v.id)
		LDataPack.writeInt(pack, v.count)
	end
	LDataPack.writeInt(pack, time)
	LDataPack.writeShort(pack, ranking) --当前排名
	LDataPack.writeShort(pack, history) --历史排名最高
	LDataPack.writeInt(pack, number) --排名提升奖励钻石数量
	LDataPack.flush(pack)
end

--竞技场倒计时
function s2cJjcDao(actor)
	local var = getActorVar(actor)
	local now = System.getNowTime()
	local second = var.downTime - now --离开始的倒计时秒数
	local tp = 1
	if second <= 0 then
		second = var.exitTime - now --离结束的倒计时秒数
		tp = 2
	end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_JJC, Protocol.sJjcCmd_Dao)
	if pack == nil then return end
	LDataPack.writeChar(pack, tp)
	LDataPack.writeShort(pack, second) --倒计时
	LDataPack.flush(pack)
end


--net end

local function onEnterFuBen(ins, actor)
	--设置角色位置
	local myPos = JjcConstConfig.myPos
	local role = LActor.getRole(actor)
	LActor.setEntityScenePos(role, myPos[1][1], myPos[1][2])
	local yongbing = LActor.getYongbing(actor)
	if yongbing then
		LActor.setEntityScenePos(yongbing, myPos[2][1], myPos[2][2])
	end

	LActor.ClearCD(actor)

	local jjcData = getJjcData(ins)
	if not jjcData.hadCreated then
		challengRival(actor, ins) --对手出现
		jjcData.hadCreated = true
	else
		-- if jjcData.extraEffectId then
		-- 	LActor.addSkillEffect(actor, jjcData.extraEffectId )
		-- end
	end
	s2cJjcDao(actor)
end

local function onWin(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end

	challengesResult(actor, ins, true)
end

local function onLose(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end

	challengesResult(actor, ins, false)
end

local function onExitFb(ins, actor)
	if not ins.is_end then --主动退出，以失败处理
		ins:lose()
	end
	LActor.delStatus(actor, StatusType_Bind)
	-- local jjcData = getJjcData(ins)
	-- if jjcData.extraEffectId then
	-- 	LActor.delSkillEffect(actor, jjcData.extraEffectId)
	-- end
end

local function onActorDie(ins, actor)
	ins:lose()
end

local function onActorCloneDie(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end
	ins:win()
end

local function fuBenInit()
	actorevent.reg(aeNewDayArrive, onNewDay)

	if System.isCrossWarSrv() then return end
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeJjcRank, onJjcRankChange)
	netmsgdispatcher.reg(Protocol.CMD_JJC, Protocol.cJjcCmd_Refresh, c2sJjcRefresh)
	netmsgdispatcher.reg(Protocol.CMD_JJC, Protocol.cJjcCmd_Throne, c2sJjcThrone)
	netmsgdispatcher.reg(Protocol.CMD_JJC, Protocol.cJjcCmd_Buy, c2sJjcBuy)
	netmsgdispatcher.reg(Protocol.CMD_JJC, Protocol.cJjcCmd_Fight, c2sJjcFight)
	netmsgdispatcher.reg(Protocol.CMD_JJC, Protocol.cJjcCmd_ClearCD, c2sJjcClearCd)


	local fubenId = JjcConstConfig.fuBen.id
	insevent.registerInstanceEnter(fubenId, onEnterFuBen)
	insevent.registerInstanceExit(fubenId, onExitFb)
	insevent.registerInstanceWin(fubenId, onWin)
	insevent.registerInstanceLose(fubenId, onLose)
	insevent.registerInstanceActorDie(fubenId, onActorDie)
	insevent.regActorCloneDie(fubenId, onActorCloneDie)
end
table.insert(InitFnTable, fuBenInit)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.jjcfight = function (actor, args)
	local idx = tonumber(args[1])
	fightFuben(actor, idx)
	return true
end

gmCmdHandlers.jjcreset = function (actor, args)
	local var = getActorVar(actor)
	var.nextTime = System.getNowTime()
	return true
end

gmCmdHandlers.jjcclimb = function (actor, args)
	local ranking = tonumber(args[1])
	local rankTbl = jjcrank.getRankTbl(ranking)
	local prank = rankTbl[ranking]
	local actor_id = Ranking.getId(prank)
	fightFuben(actor, actor_id)
end

gmCmdHandlers.jjcclone = function (actor, args)
	local CreateCount = tonumber(args[1]) or 1
	local hfuben = instancesystem.createFuBen(JjcConstConfig.fuBen.id)
	if hfuben == 0 then return end
	local ins = instancesystem.getInsByHdl(hfuben)
	if ins == nil then return end

	local jjcData = getJjcData(ins)
	if not jjcData.hadCreated then
		jjcData.hadCreated = true
	end

	local tarPos = JjcConstConfig.tarPos

	local roleCloneData = nil
	local roleSuperData = nil
	local actorData = nil
	roleCloneData, actorData, roleSuperData = actorcommon.getCloneData(LActor.getActorId(actor))

	if roleSuperData then
		roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1],FubenConstConfig.randChangeTime[2])
		roleSuperData.aiId = FubenConstConfig.roleSuperAi
	end

	local actorClone = LActor.createActorCloneWithData(LActor.getActorId(actor), ins.scene_list[1], 26, 13, actorData, roleCloneData, roleSuperData)
	local roleClone = LActor.getRole(actorClone)
	if roleClone then
		LActor.setCamp(roleClone, CampType_None)
		local pos = tarPos[1]
		LActor.setEntityScenePos(roleClone, pos[1], pos[2])
	end

	local yongbing = LActor.getYongbing(actorClone)
	if yongbing then
		local pos = tarPos[2]
		LActor.setEntityScenePos(yongbing, pos[1], pos[2])
	end
	--定身
	LActor.addSkillEffect(actorClone, JjcConstConfig.bindEffectId)
	LActor.addSkillEffect(actor, JjcConstConfig.bindEffectId)
	-- LActor.addSkillEffect(actorClone, JjcConstConfig.extraEffectIds[2])
	LActor.enterFuBen(actor, ins.handle, ins.scene_list[1], math.random(20), math.random(25))
	-- LActor.addSkillEffect(actor, JjcConstConfig.extraEffectIds[2])
	return true
end
