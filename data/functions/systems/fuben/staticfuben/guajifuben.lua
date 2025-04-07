--挂机副本
module("guajifuben", package.seeall)

local MonstersConfig = MonstersConfig
local defaultFubenID = 10001 --首次登陆进入副本ID
--默认值
function getActorVar(actor)
	if not actor then return end

	local var = LActor.getStaticVar(actor)
	if not var then return end

	if not var.guajiFuben then
		var.guajiFuben = {}
		var.guajiFuben.efficiency = 0
		var.guajiFuben.efficiencygold = 0
		var.guajiFuben.quick_count = 0
		var.guajiFuben.quick_buy_count = 0
		var.guajiFuben.quickTimes = 0
		var.guajiFuben.all_monster_count = 0
		var.guajiFuben.monster_list = {}
		var.guajifuben.kill_monster_idx = 0
		var.guajifuben.custom = 1
		var.guajifuben.auto_challenge = 0
		var.guajifuben.big_custom_reward = 0
		var.guajifuben.request_help_count = 0
		var.guajifuben.help_count = 0

	end
	return var.guajifuben
end

function getDyanmicVar(actor)
	local var = LActor.getGlobalDyanmicVar(actor)
	if not var.guajiFuben then var.guajiFuben = {} end
	local  guajiFuben = var.guajiFuben
	if not guajiFuben.enter_time then guajiFuben.enter_time = 0 end
	if not guajiFuben.hGold then guajiFuben.hGold = 0 end
	if not guajiFuben.hItem1 then guajiFuben.hItem1 = 0 end
	if not guajiFuben.hItem2 then guajiFuben.hItem2 = 0 end
	if not guajiFuben.hItem3 then guajiFuben.hItem3 = 0 end
	if not guajiFuben.monster_exp then guajiFuben.monster_exp = 0 end
	if not guajiFuben.monster_gold then guajiFuben.monster_gold = 0 end
	if not guajiFuben.monster_list then  guajiFuben.monster_list = {} end
	return guajiFuben
end


--进入挂机副本接口
function enterGuajiFuben(actor)
	local var = getActorVar(actor)

	local fbId = GuajiFubenConfig[var.custom].id
	if not utils.checkFuben(actor, fbId) then return end

	local fbHandle = instancesystem.createFuBen(fbId)
	if not fbHandle or fbHandle == 0 then return end

	local posX, posY = utils.getSceneEnterCoor(fbId)
	return LActor.enterFuBen(actor, fbHandle, -1, posX, posY)
end

function getCustom(actor)
	local var = getActorVar(actor)
	return var.custom - 1
end

--检查副本效率是否过低（客户端不打怪会出现此情况）
function checkEfficiency(actor, fbId)
	local var = getActorVar(actor)
	local conf = FubenConfig[fbId]
	if var.efficiency < conf.expAward then --如果效率过低，使用配置的最低效率
		var.efficiency = conf.expAward
		var.monster_list = {}
		local sum = 0
		local monsterList = var.monster_list
		for i = 1, #conf.monsterCounts do
			local monId = conf.monsterCounts[i].monsterid
			local count = conf.monsterCounts[i].count
			monsterList[#monsterList + 1] = {}
			monsterList[#monsterList][1] = monId
			monsterList[#monsterList][2] = count
			sum = sum + count
		end
		var.all_monster_count = sum
	end
end

--杀完一波怪,
function monsterAllKilled(ins, mon, actor)
	if ins.config.type ~= 1 then return end
	if not actor then return end
	local monId = LActor.getId(mon)
	local var = getActorVar(actor)
	if GuajiFubenConfig[var.custom - 1] and monId == GuajiFubenConfig[var.custom - 1].bossid then return end
	actorevent.onEvent(actor, aeCustomWave)
	if var.kill_monster_idx < GuajiFubenConfig[var.custom].waves then
		var.kill_monster_idx = var.kill_monster_idx + 1
		s2cUpdateWaves(actor)
	end

	if var.auto_challenge == 1 and var.kill_monster_idx >= GuajiFubenConfig[var.custom].waves then
		ins.isFightCustomBoss = true
		Fuben.killAllMonster(ins.scene_list[1])
		LActor.clearSuper(actor)
		shenmosystem.changeSuperData(actor)
		--local pos = GuajiFubenConfig[var.custom].position
		LActor.postScriptEventLite(actor, 1500, refreshCustomBoss, ins, var.custom)
		--ins:insCreateMonster(ins.scene_list[1], GuajiFubenConfig[var.custom].bossid, pos.x, pos.y)
		s2cRefreshBoss(actor, 1, GuajiFubenConfig[var.custom].bossid)
		actorevent.onEvent(actor, aeCustomFight)
	end
end

function s2cRefreshBoss(actor, status, bossId)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sGuajiCmd_RefreshBossSuccess)
	LDataPack.writeChar(npack, status)
	LDataPack.writeInt(npack, bossId or 0)
	LDataPack.flush(npack)
end

--请求打boss
function c2sRefreshBoss(actor)
	local var = getActorVar(actor)
	if var.kill_monster_idx < GuajiFubenConfig[var.custom].waves then return end
	if not GuajiFubenConfig[var.custom + 1] then return end

	local hfuben = LActor.getFubenHandle(actor)
	local ins = instancesystem.getInsByHdl(hfuben)
	if ins.config.type ~= 1 then return end
	if ins.isFightCustomBoss then
		chatcommon.sendSystemTips(actor, 1, 2, ScriptTips.chuangguan01)
		return
	end

	ins.isFightCustomBoss = true
	Fuben.killAllMonster(ins.scene_list[1])
	--local pos = GuajiFubenConfig[var.custom].position
	LActor.clearSuper(actor)
	shenmosystem.changeSuperData(actor)
	LActor.postScriptEventLite(actor, 1500, refreshCustomBoss, ins, var.custom)
	--ins:insCreateMonster(ins.scene_list[1], GuajiFubenConfig[var.custom].bossid, pos.x, pos.y)
	s2cRefreshBoss(actor, 1, GuajiFubenConfig[var.custom].bossid)
	actorevent.onEvent(actor, aeCustomFight)
end

function refreshCustomBoss(actor, ins, custom)
	local pos = GuajiFubenConfig[custom].position
	ins:insCreateMonster(ins.scene_list[1], GuajiFubenConfig[custom].bossid, pos.x, pos.y)
end

function c2sSetAuto(actor, pack)
	local autoSet = LDataPack.readChar(pack)
	local var = getActorVar(actor)
	if not GuajiFubenConfig[var.custom + 1] then return end
	var.auto_challenge = autoSet
	s2cSetAuto(actor)
end

function s2cSetAuto(actor)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sGuajiCmd_AutoChallenge)
	if npack == nil then return end
	LDataPack.writeChar(npack, var.auto_challenge)
	LDataPack.flush(npack)
end

function c2sGetCustomReward(actor, pack)
	local bigcustom = LDataPack.readShort(pack)
	local var = getActorVar(actor)
	if not WorldMapConfig[bigcustom] then return end
	if GuajiFubenConfig[var.custom].group < bigcustom then
		return
	end
	var.big_custom_reward = bigcustom
	actoritem.addItems(actor, WorldMapConfig[bigcustom].rewards, "guaji bigcustom reward")
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sGuajiCmd_GetCustomReward)
	if npack == nil then return end
	LDataPack.writeShort(npack, var.big_custom_reward)
	LDataPack.flush(npack)
end

function helpBrocast(actor, guildId, helpname, name, custom, type)
	if type == 1 then
		local pack = LDataPack.allocPacket()
		LDataPack.writeByte(pack, Protocol.CMD_AllFuben)
		LDataPack.writeByte(pack, Protocol.sGuajiCmd_HelpBrocast)
		LDataPack.writeChar(pack, type)
		LDataPack.writeString(pack, helpname)
		LDataPack.writeString(pack, name)
		LDataPack.writeShort(pack, custom)
		LGuild.broadcastData(guildId, pack)
	elseif type == 2 then
		-- local pack = LDataPack.allocPacket()
		-- LDataPack.writeByte(pack, Protocol.CMD_AllFuben)
		-- LDataPack.writeByte(pack, Protocol.sGuajiCmd_HelpBrocast)
		-- LDataPack.writeChar(pack, type)
		-- LDataPack.writeString(pack, helpname)
		-- LDataPack.writeString(pack, name)
		-- LDataPack.writeShort(pack, custom)
		-- System.broadcastData(pack)
	end
end

--发送广播，请求协助
function c2sSeekHelp(actor, pack)
	local tp = LDataPack.readChar(pack)
	local var = getActorVar(actor)
	local dvar = getDyanmicVar(actor)

	if var.kill_monster_idx < GuajiFubenConfig[var.custom].waves then
		return
	end
	if var.request_help_count >= GuajiConstConfig.dailyreqcount then
		return
	end

	if tp == 1 then
		local guildId = LActor.getGuildId(actor)
		if guildId == 0 then return end

		local pack = LDataPack.allocPacket()
		LDataPack.writeByte(pack, Protocol.CMD_AllFuben)
		LDataPack.writeByte(pack, Protocol.sGuajiCmd_SeekHelpRet)
		LDataPack.writeChar(pack, tp)
		LDataPack.writeString(pack, LActor.getName(actor))
		LDataPack.writeInt(pack, LActor.getActorId(actor))
		LDataPack.writeShort(pack, var.custom)
		LDataPack.writeString(pack, LActor.getServerId(actor))
		LGuild.broadcastData(guildId, pack)
	elseif tp == 2 then
		crosshelpcustom.seekHelp(actor, var.custom)
	end

	if not dvar.eid then
		dvar.eid = LActor.postScriptEventLite(actor, GuajiConstConfig.matchtime * 60 * 1000, matchRobot, var.custom)
	end
end

--副本开始匹配机器人
function matchRobot(actor, custom)
	local var = getActorVar(actor)
	if var.custom ~= custom then return end

	local dvar = getDyanmicVar(actor)
	if dvar.eid then
		LActor.cancelScriptEvent(actor, dvar.eid)
		dvar.eid = nil
	end
	--if conf.fbid then return end
	local rank = utils.rankfunc.getRankById(RankingType_Power)
	if not rank then return end
	local rankindex = Ranking.getItemIndexFromId(rank, LActor.getActorId(actor))
	if rankindex == -1 then return end
	if rankindex < 4 then return end --前五名不匹配机器人

	local randnum = math.random(0, rankindex) --随机一个比他战力高的玩家帮他过关
	if rankindex == randnum then
		if rankindex == 0 then
			randnum = rankindex + 1
		else
			randnum = rankindex - 1
		end
	end
	local item = Ranking.getItemFromIndex(rank, randnum)
	local helpactorid = Ranking.getId(item)
	var.request_help_count = var.request_help_count + 1
	var.custom = var.custom + 1
	var.kill_monster_idx = 0
	local ins = instancesystem.getActorIns(actor)
	if ins.config.type == 1 then
		enterGuajiFuben(actor)
	end
	s2cUpdateWaves(actor)
	onCustomChange(actor, var.custom)
	s2cReqHelpResult(actor, var.request_help_count, var.custom)
	sendHelpMail(LActor.getActorId(actor), helpactorid, var.custom - 1, LActor.getServerId(actor))
end

function c2sEnterNew(actor)
	enterGuajiFuben(actor)
end

--发送挑战关卡boss状态信息
function sendKillStatus(actor, custom, status, rewards)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sGuajiCmd_KillBoss)
	LDataPack.writeChar(pack, status) --挑战失败
	LDataPack.writeShort(pack, custom)
	if rewards then
		LDataPack.writeChar(pack, #rewards)
		for i=1, #rewards do
			LDataPack.writeInt(pack, rewards[i].id)
			LDataPack.writeInt(pack, rewards[i].count)
		end
	else
		LDataPack.writeChar(pack, 0)
	end
	LDataPack.flush(pack)
end

function onActorDie(ins, actor, killhdl)
	LActor.recover(actor)
	local et = LActor.getEntity(killhdl)
	local monId = LActor.getId(et)
	if MonstersConfig[monId] and MonstersConfig[monId].type ~= 1 then
		return
	end
	ins.isFightCustomBoss = false
	local var = getActorVar(actor)
	sendKillStatus(actor, var.custom, 0) --挑战失败
	LActor.KillMonster(killhdl)
	if var.auto_challenge == 1 then
		var.auto_challenge = (var.auto_challenge + 1) % 2
	end
	s2cSetAuto(actor)
	--Fuben.clearAllMonster(ins.scene_list[1])
	refreshmonsterapi.refreshMonsters1(ins)
	s2cRefreshBoss(actor, 0)
end

function s2cHelpResult(actor, result, help_count)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sGuajiCmd_HelpActor)
	if npack == nil then return end
	LDataPack.writeChar(npack, result)
	LDataPack.writeChar(npack, help_count)
	LDataPack.flush(npack)
end

function s2cReqHelpResult(actor, request_help_count, custom)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sGuajiCmd_SeekHelpSuccess)
	if npack == nil then return end
	LDataPack.writeChar(npack, request_help_count)
	LDataPack.writeShort(npack, custom)
	LDataPack.flush(npack)
end


function sendHelpMail(actorid, helpactorid, custom, serverid)
	local sheadstr = string.format(GuajiConstConfig.shead, custom)
	local snamestr = "【"..LActor.getActorDataById(helpactorid).actor_name.."】"
	--通关奖励
	local rewards = drop.dropGroup(GuajiFubenConfig[custom].drop)
	local mailData = {head = sheadstr, context = string.format(GuajiConstConfig.scontent, snamestr, custom), tAwardList = rewards}
	mailsystem.sendMailById(actorid, mailData)
	--助战奖励
	if helpactorid then
		local hhcontext = string.format(GuajiConstConfig.hcontent, "【"..LActor.getActorName(actorid).."】", custom)
		mailData = {head = GuajiConstConfig.hhead, context = hhcontext, tAwardList= GuajiFubenConfig[custom].helprewards}
		mailsystem.sendMailById(helpactorid, mailData)
	end
end

--帮助玩家
function c2sHelpActor(helpActor, pack)
	local type = LDataPack.readChar(pack)
	local actorid = LDataPack.readInt(pack)
	local custom = LDataPack.readShort(pack)
	local helpvar = getActorVar(helpActor)
	if type == 1 then
		local actor = LActor.getActorById(actorid)
		if not actor then
			s2cHelpResult(helpActor, 2, helpvar.help_count)
			return
		end

		local helpactorid = LActor.getActorId(helpActor)
		if helpactorid == actorid then
			return
		end

		local var = getActorVar(actor)
		if var.custom ~= custom then
			s2cHelpResult(helpActor, 2, helpvar.help_count)
			return
		end

		if LActor.getActorData(helpActor).total_power < GuajiFubenConfig[var.custom].power then
			s2cHelpResult(helpActor, 3, helpvar.help_count) --战力不足，不帮助玩家
		end

		helpvar.help_count = helpvar.help_count + 1
		var.request_help_count = var.request_help_count + 1
		var.custom = var.custom + 1
		var.kill_monster_idx = 0
		local ins = instancesystem.getActorIns(actor)
		if ins.config.type == 1 then
			enterGuajiFuben(actor)
		end
		s2cUpdateWaves(actor)
		onCustomChange(actor, var.custom)
		s2cReqHelpResult(actor, var.request_help_count, var.custom)
		s2cHelpResult(helpActor, 1, helpvar.help_count)
		sendHelpMail(actorid, helpactorid, var.custom - 1, LActor.getServerId(helpActor))
		helpBrocast(actor, LActor.getGuildId(actor), LActor.getName(helpActor), LActor.getName(actor), var.custom - 1, type)
	else
		crosshelpcustom.helpActor(helpActor, helpvar, actorid, custom)
	end
end

--闯关信息
function s2cGuajiInfo(actor)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sGuajiCmd_CustomInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, var.custom)
	LDataPack.writeChar(npack, var.request_help_count)
	LDataPack.writeChar(npack, var.help_count)
	LDataPack.writeChar(npack, var.auto_challenge)
	LDataPack.writeChar(npack, var.kill_monster_idx)
	LDataPack.writeShort(npack, var.big_custom_reward)
	LDataPack.writeChar(npack, var.quick_count)
	LDataPack.writeChar(npack, var.quick_buy_count)
	LDataPack.flush(npack)
end

--计算在这个时间内的收益
function getMonsterRewardByTime(actor, time, isFast)
	local var = getActorVar(actor)

	--怪物数量计算
	local rateTmp = time / 60
	local monsterList = var.monster_list
	local monsterDropList = {}
	for i = 1, #monsterList do
		local monId = monsterList[i][1]
		local count = monsterList[i][2]
		monsterDropList[#monsterDropList + 1] = {}
		monsterDropList[#monsterDropList][1] = monId
		monsterDropList[#monsterDropList][2] = math.floor(count * rateTmp)
	end

	--掉落物
	local moneyRate = actorcommon.getDropGoldRate(actor) + 1
	local dropItems = {}
	local idxTmp = 1
	for i = 1, #monsterDropList do
		local monId = monsterDropList[i][1]
		local count = monsterDropList[i][2]
		monsterdrop.addDropItems(dropItems, monId, count, moneyRate, isFast)
	end
	dropItems = utils.mergeItem(dropItems)
	--金币
	for k,v in ipairs(dropItems) do
		if v.id == NumericType_Gold then
			v.count = math.floor(GuajiFubenConfig[var.custom].gold * moneyRate * time / 3600)
			break
		end
	end
	--经验
	local exp = math.floor(GuajiFubenConfig[var.custom].exp * time / 3600)

	--多倍额外经验
	local sexp = 0

	--属性加成
	local attrRate = actorcommon.getActorDropExpRate(actor) / 10000
	sexp = sexp + exp * (attrRate + actorexp.getWLExpPer(actor))

	return exp, sexp, dropItems
end


--额外创建一组怪物
function CreateExtraMonster(actor, fbid, monId, count, isDrop)
	local ins = instancesystem.getActorIns(actor)
	if not ins then return end
	refreshmonsterapi.refreshExtraMonster(ins, fbid, monId, count)
end

function s2cUpdateWaves(actor)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sGuajiCmd_UpdateWaves)
	if npack == nil then return end

	LDataPack.writeChar(npack, var.kill_monster_idx)
	LDataPack.flush(npack)
end

function onCustomChange(actor, custom)
	actorevent.onEvent(actor, aeCustomChange, custom-1, custom - 2)
	utils.rankfunc.updateRankingList(actor, custom-1, RankingType_Custom)
	local dvar = getDyanmicVar(actor)
	if dvar.eid then
		LActor.cancelScriptEvent(actor, dvar.eid)
		dvar.eid = nil
	end
end

--怪物死亡，给经验奖励
function onMonsterDie(ins, mon, killerHdl)
	local monId = LActor.getId(mon)
	local et = LActor.getEntity(killerHdl)
	local actor = LActor.getActor(et)
	--local actor = ins:getActorList()[1]
	if not actor then return end
	local var = getActorVar(actor)
	if monId == GuajiFubenConfig[var.custom].bossid and killerHdl then
		local var = getActorVar(actor)
		if var.kill_monster_idx < GuajiFubenConfig[var.custom].waves then return end
		if not GuajiFubenConfig[var.custom + 1] then return end
		var.custom = var.custom + 1
		if not GuajiFubenConfig[var.custom + 1] then 
			var.auto_challenge = 0
			s2cSetAuto(actor)
		end
		var.kill_monster_idx = 0
		--enterGuajiFuben(actor)
		s2cUpdateWaves(actor)
		local rewards = drop.dropGroup(GuajiFubenConfig[var.custom - 1].drop)
		local ins = instancesystem.getActorIns(actor)
		instancesystem.setInsRewards(ins, actor, rewards)
		sendKillStatus(actor, var.custom, 1, rewards)
		onCustomChange(actor, var.custom)
		s2cRefreshBoss(actor, 0)
	else
		local dvar = getDyanmicVar(actor)
		if not dvar or not dvar.monster_list then return end
		dvar.monster_list[monId] = (dvar.monster_list[monId] or 0) + 1
	end
end

--查看挂机收获
function c2sShowHarvest(actor, packet)
	local now_t = System.getNowTime()
	local dvar = getDyanmicVar(actor)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sGuajiCmd_Harvest)
	if not pack then return end

	LDataPack.writeInt(pack, now_t - dvar.enter_time)
	LDataPack.writeInt(pack, dvar.monster_exp)
	LDataPack.writeInt(pack, dvar.hGold)
	LDataPack.writeShort(pack, dvar.hItem1)
	LDataPack.writeShort(pack, dvar.hItem2)
	LDataPack.writeShort(pack, dvar.hItem3)
	LDataPack.flush(pack)
end

--显示离线奖励（注意如果背包满了，就不会有装备或装备熔炼后的东西出来）
function s2cSettlementOffline(actor)
	local dyan = getDyanmicVar(actor)
	if 0 == (dyan.offExp or 0) then	return end
	local equipNums = {}
	local beforeLv = LActor.getLevel(actor)
	LActor.addExp(actor, dyan.offExp+dyan.offSexp, "guaji offline", false, true, 1)
	local items
	if privilege.isBuyPrivilege(actor) then
		items = actoritem.addItemsByScore(actor, dyan.offItems, "guaji offline")
	else
		items = actoritem.addItemsBySpace(actor, dyan.offItems, "guaji offline", 2) --收获离线奖励
	end
	local rewards = {}
	for k,v in ipairs(items) do
		rewards[v.id] = (rewards[v.id] or 0) + v.count
	end
	rewards[NumericType_Exp] = dyan.offExp+dyan.offSexp

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sGuajiCmd_Settlement)
	if not pack then return end
	local hour = math.ceil(dyan.offTime / 3600) --挂了几小时（向上取整）
	LDataPack.writeInt(pack, dyan.offTime)
	-- LDataPack.writeDouble(pack, dyan.offExp)
	-- LDataPack.writeDouble(pack, dyan.offSexp)
	-- LDataPack.writeInt(pack, QuickfightConfig.doubleRewardPrice * hour)
	LDataPack.writeShort(pack, beforeLv)

	--发送道具物品, 累计装备数量
	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, count)
	for k, v in pairs(rewards) do
		local itemConf =  ItemConfig[k]
		if itemConf and actoritem.isEquip(itemConf) then
			equipNums[itemConf.quality] = (equipNums[itemConf.quality] or 0) + v
		else
			LDataPack.writeInt(pack, k)
			LDataPack.writeDouble(pack, v)
			count = count + 1
		end
	end
	if count > 0 then
		local npos = LDataPack.getPosition(pack)
		LDataPack.setPosition(pack, pos)
		LDataPack.writeInt(pack, count)
		LDataPack.setPosition(pack, npos)
	end

	--按品质发送装备的总数
	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, count)
	for k, v in pairs(equipNums) do
		LDataPack.writeInt(pack, k) --品质
		LDataPack.writeInt(pack, v) --数量
		count = count + 1
	end
	if count > 0 then
		local npos = LDataPack.getPosition(pack)
		LDataPack.setPosition(pack, pos)
		LDataPack.writeInt(pack, count)
		LDataPack.setPosition(pack, npos)
	end
	LDataPack.flush(pack)

	dyan.offExp = 0
	dyan.offSexp = 0
	dyan.offItems = {}
end

--获取离线奖励
function c2sGetOffline(actor, packet)
	-- if not actor or not packet then return end
	-- local tp = LDataPack.readInt(packet)

	-- local dyan = getDyanmicVar(actor)
	-- if (dyan.offBuyExp or 0) == 0 then return end
	-- if tp == 2 then
	-- 	local hour = math.ceil(dyan.offTime / 3600) --挂了几小时（向上取整）
	-- 	if not actoritem.checkItem(actor, NumericType_YuanBao, QuickfightConfig.doubleRewardPrice*hour) then
	-- 		return
	-- 	end
	-- 	actoritem.reduceItem(actor, NumericType_YuanBao, QuickfightConfig.doubleRewardPrice*hour, "get offline reward")
	-- 	LActor.addExp(actor, dyan.offBuyExp, "guaji offline", false, true, 1) --再得到一倍的经验
	-- end
	-- dyan.offBuyExp = 0
end

--快速战斗
function c2sQuickFight(actor, packet)
	local type = LDataPack.readChar(packet)
	local rewards, exp, sexp,items
	if type == 1 then
		local time = GuajiConstConfig.firstTime * 60 * 60
		exp, sexp, items = getMonsterRewardByTime(actor, time, true)
		rewards = actoritem.getItemsByScore(actor, items, "guaji quick") --把低级装备熔炼后的奖励
	else
		local var = getActorVar(actor)
		local vip = LActor.getSVipLevel(actor)
		if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.fast) then return end
		if var.quick_buy_count + GuajiConstConfig.quickCount < var.quick_count then return end
		local num = GuajiConstConfig.moneyCount[var.quick_count+1]
		if not num then
			return
		end

		if not actoritem.checkItem(actor, NumericType_YuanBao, num) then return end
		actoritem.reduceItem(actor, NumericType_YuanBao, num, "guaji quick")
		local time = GuajiConstConfig.firstTime * 60 * 60
		exp, sexp, items = getMonsterRewardByTime(actor, time, true)

		LActor.addExp(actor, math.floor(exp + sexp), "guaji quick", false, true, 1)

		rewards = actoritem.addItemsByScore(actor, items, "guaji quick") --把低级装备熔炼后的奖励
		var.quick_count = var.quick_count + 1
		actorevent.onEvent(actor, aeFastFight)
	end
	s2cQuickFight(actor, type, rewards, exp+sexp)
end

--购买快速战斗次数
function c2sQuickFightBuy(actor, pack)
	local var = getActorVar(actor)
	local vip = LActor.getSVipLevel(actor)
	if var.quick_buy_count >= SVipConfig[vip].quickfight then return end
	if not actoritem.checkItem(actor, NumericType_YuanBao, GuajiConstConfig.buyCount[var.quick_buy_count + 1]) then return end
	actoritem.reduceItem(actor, NumericType_YuanBao, GuajiConstConfig.buyCount[var.quick_buy_count + 1], "guaji quick buy times")
	var.quick_buy_count = var.quick_buy_count + 1
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sGuajiCmd_QuickFightBuy)
	LDataPack.writeChar(pack, var.quick_buy_count)
	LDataPack.writeChar(pack, var.quick_count)
	LDataPack.flush(pack)
end

function sendQuickFightInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sGuajiCmd_QuickFightInfo)
	LDataPack.writeChar(pack, var.quick_count)
	LDataPack.writeChar(pack, var.quick_buy_count)
	LDataPack.flush(pack)
end

--快速战斗奖励
function s2cQuickFight(actor, type, items, exp)
	local var = getActorVar(actor)
	local vip = LActor.getSVipLevel(actor)
	table.insert(items, 1, {type=0, id=NumericType_Exp, count=exp})
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sGuajiCmd_QuickFight)
	if not pack then return end
	LDataPack.writeChar(pack, type)
	LDataPack.writeChar(pack, var.quick_count)
	LDataPack.writeShort(pack, #items)
	for k, v in ipairs(items) do
		LDataPack.writeInt(pack, v.type)
		LDataPack.writeInt(pack, v.id)
		LDataPack.writeDouble(pack, v.count)
	end
	LDataPack.flush(pack)
end
-----------------------副本事件begin------------------------------

--进入副本事件
function onEnterFb(ins, actor)
	local var = getActorVar(actor)
	if not var then return end
	var.fbId = ins.id
	local dvar = getDyanmicVar(actor)
	if not dvar then return end
	dvar.enter_time = System.getNowTime()
	dvar.monster_exp = 0
	dvar.hGold = 0
	dvar.hItem1 = 0
	dvar.hItem2 = 0
	dvar.hItem3 = 0
	dvar.monster_list = {}
	checkEfficiency(actor, ins.id)
	actorevent.onEvent(actor, aeInterGuajifu, ins.id)
end

function getRandomActor(count, nums)
	local randomNum = 0
	for i=1, 20 do
		randomNum = System.getRandomNumber(count)
		for j=1, #nums do
			if nums[j] == randomNum then
				randomNum = 0
				break
			end
		end
	end
	return randomNum
end

--退出副本事件，记录信息
function onExitFuben(ins, actor)
	if not actor then return end
	if not ins then return end
	local fbConf = FubenConfig[ins.id]
	if not fbConf or fbConf.type ~= 1 then return end
	local dvar = getDyanmicVar(actor)
	if dvar.eid then
		LActor.cancelScriptEvent(actor, dvar.eid)
		dvar.eid = nil
	end
	ins.isFightCustomBoss = false
end

local function onOffline(ins, actor)
	local dvar = getDyanmicVar(actor)
	ins.isFightCustomBoss = false
	if dvar.eid then
		LActor.cancelScriptEvent(actor, dvar.eid)
		dvar.eid = nil
	end
end

--定时60秒设置挂机效率
function onTimecheck(ins)
	local alist = ins:getActorList()
	if #alist ~= 1 then return end
	local actor = alist[1]

	local var = getActorVar(actor)
	local dvar = getDyanmicVar(actor)
	var.efficiency =  dvar.monster_exp
	var.monster_list = {}
	local monsterList = var.monster_list
	local allMonsterCount = 0
	for k ,v in pairs(dvar.monster_list) do
		monsterList[#monsterList+ 1] = {}
		monsterList[#monsterList][1] = k
		monsterList[#monsterList][2] = v
		allMonsterCount = allMonsterCount + v
	end
	var.all_monster_count = allMonsterCount
	dvar.monster_exp = 0
	dvar.monster_list = {}

	checkEfficiency(actor, ins.id)
end

--副本拾物事件
function onPickItem(ins, actor, tp, id, count)
	local dvar = getDyanmicVar(actor)
	if tp == AwardType_Item then
		local conf = ItemConfig[id]
		if conf.type == 0 then
			if conf.quality == 0 then
				dvar.hItem1 = dvar.hItem1 + count
			elseif conf.quality == 1 then
				dvar.hItem2 = dvar.hItem2 + count
			end
		elseif conf.type == 1 and conf.type == 1 then
			dvar.hItem3 = dvar.hItem3 + count
		end
	elseif id == NumericType_Gold then
		dvar.hGold = dvar.hGold + count
	end
end

------------------------副本事件end--------------------------


function onLogin(actor, firstlogin, offtime, logout, iscross)
	local var = getActorVar(actor)
	if iscross then
		s2cSetAuto(actor)
		return
	else		
		var.auto_challenge = 0
	end
	local ins = instancesystem.getActorIns(actor)
	s2cSettlementOffline(actor)
	s2cGuajiInfo(actor)
	utils.rankfunc.updateRankingList(actor, var.custom-1, RankingType_Custom)
end

--上线计算 离线的挂机奖励
function onBeforeLogin(actor, delay, outTime, isFirst)
	local var = getActorVar(actor)
	if isFirst then return end --第一次登录不操作
	if not var or not var.monster_list then return end

	local now = System.getNowTime()
	local logoutTime = LActor.getLastLogoutTime(actor)
	local offTime = now - logoutTime --离线时间
	if offTime < 60 then return end
	offTime = math.min(GuajiConstConfig.maxMinute * 60, offTime) --最长不奖励超过12小时
	if not FubenConfig[var.fbId] then
		var.fbId = defaultFubenID
		return
	end

	local exp, sexp, items = getMonsterRewardByTime(actor, offTime) --计算收益

	local dyan = getDyanmicVar(actor)
	dyan.offTime = offTime
	dyan.offExp = exp --经验收益
	dyan.offSexp = sexp --双倍经验丹收益
	dyan.offBuyExp = exp + sexp --可购买的收益
	dyan.offItems = items
end

function onActorLogout(actor)
	if not actor then return end
	local ins = instancesystem.getActorIns(actor)
	if not ins then
		print("Error: onActorLogout ins is nil")
		return
	end

	onExitFuben(nil, actor)
end

function onNewDay(actor, login)
	local var = getActorVar(actor)
	var.quick_count = 0 --每天快速战斗次数恢复
	var.quick_buy_count = 0
	var.help_count = 0
	var.request_help_count = 0
	s2cGuajiInfo(actor)
end

function onInitGuajiFuben()
	actorevent.reg(aeNewDayArrive, onNewDay)

	if System.isCrossWarSrv() then return end
	for _, conf in pairs(FubenConfig) do
		if conf.type == 1 then
			insevent.regCustomFunc(conf.fbid, onTimecheck, "onTimecheck")
			insevent.registerInstanceEnter(conf.fbid, onEnterFb)
			insevent.registerInstanceExit(conf.fbid, onExitFuben)
			insevent.registerInstanceOffline(conf.fbid, onOffline)
			insevent.registerInstancePickItem(conf.fbid, onPickItem)
			insevent.registerInstanceMonsterDie(conf.fbid, onMonsterDie)
			insevent.registerInstanceActorDie(conf.fbid, onActorDie)
		end
	end

	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cGuajiCmd_RefreshBoss, c2sRefreshBoss)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cGuajiCmd_SeekHelp, c2sSeekHelp)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cGuajiCmd_HelpActor, c2sHelpActor)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cGuajiCmd_QuickFight, c2sQuickFight)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cGuajiCmd_QuickFightBuy, c2sQuickFightBuy)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cGuajiCmd_SetAutoChallenge, c2sSetAuto)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cGuajiCmd_GetCustomReward, c2sGetCustomReward)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cGuajiCmd_Settlement, c2sGetOffline)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cGuajiCmd_ReqEnterNewFb, c2sEnterNew)


	actorevent.reg(aeUserLogout, onActorLogout)
	actorevent.reg(aeInit, onBeforeLogin)
	actorevent.reg(aeUserLogin, onLogin)
end
table.insert(InitFnTable, onInitGuajiFuben)


-- local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.custom = function (actor, args)
	local var = getActorVar(actor)
	local old = var.custom
	var.custom = tonumber(args[1])
	local ins = instancesystem.getActorIns(actor)
	if ins.config.type == 1 then
		enterGuajiFuben(actor)
	end
	s2cGuajiInfo(actor)
	sendKillStatus(actor, var.custom, 1)
	actorevent.onEvent(actor, aeCustomChange, var.custom - 1, old - 1)
	return true
end
gmCmdHandlers.checkGuaji = function (actor, args)
	local tmp = tonumber(args[1])
	if tmp == 1 then
		enterGuajiFuben(actor)
	elseif tmp == 3 then
		c2sShowHarvest(actor)
	end
	return true
end

gmCmdHandlers.quickFight = function (actor, args)
	c2sQuickFight(actor)
	return true
end

gmCmdHandlers.offlinegaji = function (actor, args)
	local time = tonumber(args[1])
	local exp, sexp, items = getMonsterRewardByTime(actor, time*3600)
	local var = getActorVar(actor)
	local dyan = getDyanmicVar(actor)
	dyan.offTime = time*3600
	dyan.offExp = exp --经验收益
	dyan.offSexp = sexp --双倍经验丹收益
	dyan.offBuyExp = exp + sexp --可购买的收益
	dyan.offItems = items
	s2cSettlementOffline(actor)
	return true
end

gmCmdHandlers.enterfuben = function (actor, args)
	local fbId = tonumber(args[1])
	local fbHandle = instancesystem.createFuBen(fbId)
	if not fbHandle or fbHandle == 0 then return end
	LActor.enterFuBen(actor, fbHandle)
	return true
end

gmCmdHandlers.extramonster = function (actor, args)
	local fbId = LActor.getFubenId(actor)
	local monId = tonumber(args[1])
	CreateExtraMonster(actor, fbId, monId, 1, true)
	return true
end

gmCmdHandlers.customAll = function (actor, args)
    local max = #GuajiFubenConfig
    local var = getActorVar(actor)
	if (var.custom or 0) < max then
    	gmCmdHandlers.custom(actor, {max})
    end
    return true
end

