-- module("guildbattlefb", package.seeall)

-- guild_battle_fb =  guild_battle_fb or {}
-- local gate_id = 1 --城门的关卡id
-- local city_within = 2 --城内的关卡id
-- local qian_dian = 3 --前殿
-- local imperial_palace = 4 --皇宫id

-- --结束类型
-- local UNDEFINED_END = 0
-- local TIME_END = 1
-- local GATHER_END = 2

-- local version = 1

-- local function getActorData(actor)
-- 	local var = LActor.getStaticVar(actor)
-- 	if var == nil then 
-- 		return nil
-- 	end
-- 	if var.guild_battle_fb == nil then 
-- 		var.guild_battle_fb = {}
-- 	end

-- 	local guild_battle_fb = var.guild_battle_fb
-- 	if guild_battle_fb.version == version then
-- 		return guild_battle_fb
-- 	end

-- 	guild_battle_fb.version = version

-- 	if guild_battle_fb.scene_feats == nil then 
-- 		guild_battle_fb.scene_feats = 0
-- 		--场景功勋
-- 	end
-- 	if guild_battle_fb.resurgence_cd == nil then 
-- 		guild_battle_fb.resurgence_cd = 0
-- 		--复活cd
-- 	end
-- 	if guild_battle_fb.switch_scene_cd == nil then 
-- 		guild_battle_fb.switch_scene_cd = 0
-- 		--切换场景cd
-- 	end
-- 	if guild_battle_fb.kill_role == nil then 
-- 		guild_battle_fb.kill_role = 0
-- 		--杀死的玩家 
-- 	end

-- 	if guild_battle_fb.was_killed == nil then 
-- 		guild_battle_fb.was_killed = 0
-- 		--被杀次数
-- 	end

-- 	if guild_battle_fb.multi_kill == nil then 
-- 		guild_battle_fb.multi_kill = 0 
-- 		--连杀
-- 	end
-- 	if guild_battle_fb.level_id == nil then 
-- 		guild_battle_fb.level_id = 0
-- 		--当前关卡id
-- 	end
-- 	if guild_battle_fb.last_level_id == nil then
-- 		guild_battle_fb.last_level_id = 0
-- 		--前一个的关卡
-- 	end
-- 	if guild_battle_fb.open_size == nil then 
-- 		guild_battle_fb.open_size = 0
-- 	end
-- 	return guild_battle_fb
-- end

-- function rsfActorData(actor) -- 刷新数据
-- 	local var = getActorData(actor)
-- 	if var.open_size ~= guildbattle.getOpenSize() then
-- 		var.scene_feats     = 0
-- 		var.resurgence_cd   = 0
-- 		var.switch_scene_cd = 0
-- 		var.kill_role       = 0
-- 		var.multi_kill      = 0
-- 		var.level_id        = 0
-- 		var.last_level_id	= 0
-- 		var.was_killed      = 0
-- 		var.open_size       = guildbattle.getOpenSize()
-- 	end
-- end

-- local function getGlobalData()
-- 	local var = System.getStaticVar()
-- 	if var == nil then 
-- 		return nil
-- 	end
-- 	if var.guild_battle_fb == nil then 
-- 		var.guild_battle_fb = {}
-- 	end
-- 	return var.guild_battle_fb
-- end

-- local function initDynGlobalData()
-- 	if System.isBattleSrv() then return end
-- 	if guild_battle_fb.version == version then return end

-- 	guild_battle_fb.version = version

-- 	--副本动态数据
-- 	if guild_battle_fb.gate_die == nil then 
-- 		guild_battle_fb.gate_die = false
-- 	end
-- 	if guild_battle_fb.is_open == nil then 
-- 		guild_battle_fb.is_open = false
-- 	end
-- 	if guild_battle_fb.is_lottery == nil then 
-- 		guild_battle_fb.is_lottery = false
-- 	end
-- 	if guild_battle_fb.join_lottery == nil then 
-- 		guild_battle_fb.join_lottery = {}
-- 	end
-- 	if guild_battle_fb.join_lottery_map == nil then
-- 		guild_battle_fb.join_lottery_map = {}
-- 	end
-- 	if guild_battle_fb.gate_handle == nil then 
-- 		guild_battle_fb.gate_handle = 0
-- 	end
-- 	if guild_battle_fb.gate_count_down == nil then 
-- 		guild_battle_fb.gate_count_down = 0;
-- 	end
-- 	if guild_battle_fb.end_time == nil then
-- 		guild_battle_fb.end_time = 0
-- 	end
	
-- 	--旗帜
-- 	if guild_battle_fb.flags == nil then 
-- 		guild_battle_fb.flags = {}
-- 	end
-- 	local flags = guild_battle_fb.flags
-- 	if flags.status == nil then 
-- 		flags.status = 0
-- 		-- 0 不可采集
-- 		-- 1 可采集
-- 		-- 2 采集中
-- 		-- 3 采集完成
-- 	end
-- 	if flags.cur_fuben_shield == nil then
-- 		flags.cur_fuben_shield = 0
-- 	end
-- 	if flags.max_fuben_shield == nil then
-- 		flags.max_fuben_shield = 0
-- 	end
-- 	if flags.wait_tick == nil then 
-- 		flags.wait_tick = 0
-- 		-- 等待采集的时间(秒)
-- 	end
-- 	if flags.gatherers_name == nil then 
-- 		flags.gatherers_name = ""
-- 		-- 采集者名字
-- 	end
-- 	if flags.gatherers_guild == nil then 
-- 		flags.gatherers_guild = ""
-- 		-- 采集者公会名字
-- 	end
-- 	if flags.gatherers_actor_id == nil then 
-- 		flags.gatherers_actor_id = 0
-- 		-- 采集者actor_id
-- 	end
-- 	if flags.gatherers_actor_handle == nil then
-- 		gatherers_actor_handle = 0
-- 		-- 采集者handle
-- 	end
-- 	if flags.gather_tick == nil then 
-- 		flags.gather_tick = 0
-- 		-- 采集时间
-- 	end
-- end

-- function getDistributionData()
-- 	local var = getGlobalData()
-- 	if var.distribution == nil then
-- 		var.distribution = {}
-- 	end
-- 	return var.distribution
-- end

-- function getGateHandle()
-- 	return guild_battle_fb.gate_handle
-- end

-- function setGateHandle(hdl)
-- 	guild_battle_fb.gate_handle = hdl
-- end

-- function getFlagHandle()
-- 	if not guild_battle_fb[imperial_palace] then return 0 end
-- 	return guild_battle_fb[imperial_palace].flags_hdl
-- end

-- function setFlagHandle(hdl)
-- 	if not guild_battle_fb[imperial_palace] then return 0 end
-- 	guild_battle_fb[imperial_palace].flags_hdl = hdl
-- end

-- function getJoinLotteryMap()
-- 	return guild_battle_fb.join_lottery_map
-- end

-- function getJoinLottery()
-- 	return guild_battle_fb.join_lottery
-- end

-- function getLottery()
-- 	return guild_battle_fb.is_lottery
-- end

-- function isOpen()
-- 	return guild_battle_fb.is_open
-- end

-- function getDistributionDataById(guild_id)
-- 	local var = getDistributionData()
-- 	if var[guild_id] == nil then 
-- 		var[guild_id] = {}
-- 	end
-- 	if var[guild_id].distribution_ids == nil then 
-- 		var[guild_id].distribution_ids = {}
-- 	end
-- 	return var[guild_id]
-- end

-- function rsfDistributionData()
-- 	local gvar = getGlobalData()
-- 	gvar.distribution = {}
-- end

-- function getOccupyData()
-- 	local var = getGlobalData()
-- 	if var.occupy == nil then
-- 		var.occupy = {}
-- 	end
-- 	local occupy = var.occupy

-- 	if occupy.version == version then
-- 		return occupy
-- 	end

-- 	occupy.version = version
	
-- 	if occupy.guild_id == nil then 
-- 		occupy.guild_id = 0
-- 	end
-- 	if occupy.guild_name == nil then 
-- 		occupy.guild_name = ""
-- 	end
-- 	if occupy.leader_name == nil then 
-- 		occupy.leader_name = ""
-- 	end
-- 	if occupy.leader_actor_id == nil then 
-- 		occupy.leader_actor_id = 0
-- 	end
-- 	if occupy.leader_job == nil then 
-- 		occupy.leader_job = 0
-- 	end
-- 	if occupy.leader_sex == nil then 
-- 		occupy.leader_sex = 0
-- 	end
-- 	if occupy.leader_coat == nil then 
-- 		occupy.leader_coat = 0
-- 	end
-- 	if occupy.leader_weapon == nil then 
-- 		occupy.leader_weapon = 0
-- 	end
-- 	if occupy.leader_illusionWeaponId == nil then
-- 		occupy.leader_illusionWeaponId = 0
-- 	end
-- 	if occupy.leader_wing_open_status == nil then 
-- 		occupy.leader_wing_open_status = 0
-- 	end
-- 	if occupy.leader_wing_level == nil then 
-- 		occupy.leader_wing_level = 0
-- 	end
-- 	if occupy.leader_shineWeapon == nil then 
-- 		occupy.leader_shineWeapon = 0
-- 	end
-- 	if occupy.leader_shineArmor == nil then 
-- 		occupy.leader_shineArmor = 0
-- 	end
-- 	if occupy.leader_damonId == nil then 
-- 		occupy.leader_damonId = 0
-- 	end
-- 	if occupy.leader_damonLevel == nil then 
-- 		occupy.leader_damonLevel = 0
-- 	end
-- 	return occupy
-- end

-- function getWinGuild()
-- 	local var = getOccupyData()
-- 	return var.guild_id
-- end

-- function getWinGuildName()
-- 	local var = getOccupyData()
-- 	return var.guild_name
-- end

-- function rsfOccupyData()
-- 	local gvar = getGlobalData()
-- 	gvar.occupy = nil
-- end

-- function rsfTitle()
-- 	local occupyData = getOccupyData()
-- 	if occupyData == nil then return end
-- 	if occupyData.guild_id == 0 then return end

-- 	local leader_actor_id = LGuild.getLeaderIdById(occupyData.guild_id)
-- 	local leaderActor = LActor.getActorById(leader_actor_id)
-- 	if leaderActor then
-- 		titlesystem.delitle(leaderActor, GuildBattleConst.occupationTitle)
-- 	end

-- 	local id_list = LGuild.getMemberIdList(LGuild.getGuildById(occupyData.guild_id)) or {}
-- 	for i = 1, #id_list do
-- 		local actor_id = id_list[i]
-- 		if actor_id ~= leader_actor_id then 
-- 			local memberActor = LActor.getActorById(actor_id)
-- 			if memberActor then
-- 				titlesystem.delitle(memberActor, GuildBattleConst.memberOccupationAward)
-- 			end
-- 		end
-- 	end
-- end

-- function sendSettlement(actor) -- 发送结算数据
-- 	local guild_id = LActor.getGuildId(actor) 
-- 	if guild_id == 0 then 
-- 		return
-- 	end
-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_Settlement)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	LDataPack.writeString(npack, getWinGuildName())
-- 	LDataPack.writeInt(npack, guildbattlepersonalaward.getIntegral(actor))
-- 	LDataPack.writeInt(npack, guildbattlepersonalaward.getTotalIntegral(guild_id))
-- 	LDataPack.writeInt(npack, guildbattlepersonalaward.getRanking(guild_id))
-- 	LDataPack.writeInt(npack, guildbattleintegralrank.getRank(actor))
-- 	LDataPack.flush(npack)
-- end

-- local function getWinLeaderInfo(actorId)
-- 	local var = getOccupyData()
-- 	local actor = LActor.getActorById(actorId)
-- 	local roleCloneData, actorCloneData = actorcommon.getCloneData(actorId)	
-- 	var.guild_id					= roleCloneData.guildId
-- 	var.guild_name					= roleCloneData.guildName
-- 	var.leader_name					= roleCloneData.name
-- 	var.leader_actor_id				= actorId
-- 	var.leader_job					= roleCloneData.job
-- 	var.leader_shenzhuang			= roleCloneData.shenzhuangchoose
-- 	var.leader_shenqi				= roleCloneData.shenqichoose
-- 	var.leader_wingchoose			= roleCloneData.wingchoose
-- 	print(utils.t2s(var))
-- end

-- function makeWinGuidInfo(npack) 
-- 	local var = getOccupyData()
-- 	LDataPack.writeByte(npack, var.endStat or 0)
-- 	LDataPack.writeInt(npack, var.guild_id)
-- 	LDataPack.writeString(npack, var.guild_name)
-- 	LDataPack.writeString(npack, var.leader_name)
-- 	LDataPack.writeInt(npack, var.leader_actor_id)
-- 	LDataPack.writeByte(npack, var.leader_job)
-- 	LDataPack.writeInt(npack, var.leader_shenzhuang or 0)
-- 	LDataPack.writeInt(npack, var.leader_shenqi or 0)
-- 	LDataPack.writeInt(npack, var.leader_wingchoose or 0)
-- end

-- function broadcastWinGuildInfo()
-- 	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_WinGuildInfo)
-- 	if not npack then 
-- 		return
-- 	end
-- 	makeWinGuidInfo(npack)
-- 	System.broadcastData(npack)
-- end

-- function sendWinGuidInfo(actor)
-- 	local guild_id = LActor.getGuildId(actor)
-- 	if guild_id == 0 then 
-- 		return
-- 	end
-- 	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_WinGuildInfo)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	makeWinGuidInfo(npack)
-- 	LDataPack.flush(npack)
-- end

-- function setGuildBattleWinGuildId(guild_id, endStat) 
-- 	System.log("guildbattlefb", "setGuildBattleWinGuildId", "call", "guild_id:" .. (guild_id or ""))
-- 	if isOpen()  == false then 
-- 		System.log("guildbattlefb", "setGuildBattleWinGuildId", "not open")
-- 		return 
-- 	end
-- 	-- System.log("guildbattlefb", "setGuildBattleWinGuildId", "mark1")
-- 	local  function sendSettlementAll()
-- 		for i,v in ipairs(GuildBattleLevel) do 
-- 			if i ~= city_within then 
-- 				local actors = Fuben.getAllActor(guild_battle_fb[i].hfuben)
-- 				if actors ~= nil then 
-- 					for j = 1, #actors do 
-- 						sendSettlement(actors[j])
-- 					end
-- 				end
-- 			else
-- 				for j,jv in ipairs(guild_battle_fb[i].hfubens) do 
-- 					local actors = Fuben.getAllActor(jv)
-- 					if actors ~= nil then 
-- 						for x = 1, #actors do 
-- 							sendSettlement(actors[x])
-- 						end
-- 					end
-- 				end
-- 			end
-- 		end
-- 	end

-- 	--积分
-- 	guildbattlepersonalaward.sendAllPersonalAward()
-- 	guildbattleintegralrank.sendPersonalRankAward()
	
-- 	--没有城主
-- 	local gvar = getOccupyData()
-- 	if guild_id == 0 then 
-- 		sendSettlementAll()
-- 		gvar.guild_id = 0
-- 		gvar.guild_name = ""
-- 		gvar.endStat = 0
-- 		close()
-- 		broadcastDistributionDataForOnlineLeader()
-- 		broadcastWinGuildInfo()
-- 		noticesystem.broadCastNotice(noticesystem.NTP.guildBattle13)
-- 		return false
-- 	end

-- 	--设置结束类型
-- 	gvar.endStat = endStat
-- 	local guild_ptr        = LGuild.getGuildById(guild_id)
-- 	local leader_actor_id  = LGuild.getLeaderId(guild_ptr)
-- 	--主要是为了发结算数据
-- 	gvar.guild_id          = guild_id
-- 	gvar.guild_name        = LGuild.getGuildName(guild_ptr)
-- 	System.log("guildbattlefb", "setGuildBattleWinGuildId", "mark2", "guild_id:" .. guild_id, "leader_actor_id:" .. leader_actor_id)
-- 	getWinLeaderInfo(leader_actor_id)
-- 	sendSettlementAll()
-- 	broadcastWinGuildInfo()

-- 	--帮主奖励
-- 	local mail_data      = {}
-- 	mail_data.head       = GuildBattleConst.occupationAwardHead
-- 	mail_data.context    = GuildBattleConst.occupationAwardContext
-- 	mail_data.tAwardList = GuildBattleConst.occupationAward
-- 	mailsystem.sendMailById(leader_actor_id, mail_data)
-- 	--帮主称号
-- 	local leaderActor = LActor.getActorById(leader_actor_id)
-- 	if leaderActor then
-- 		titlesystem.addTitle(leaderActor, GuildBattleConst.occupationTitle)
-- 		actorevent.onEvent(leaderActor, aeLLFBWin)
-- 	else
-- 		local actorData = offlinedatamgr.GetDataByOffLineDataType(leader_actor_id, offlinedatamgr.EOffLineDataType.EOperable)
-- 		if actorData then
-- 			actorData.isguildbattlewin = 1
-- 		end
-- 	end

-- 	--帮众奖励
-- 	local id_list = LGuild.getMemberIdList(guild_ptr) or {}
-- 	for i = 1, #id_list do
-- 		local actor_id = id_list[i]
-- 		if actor_id ~= leader_actor_id then 
-- 			mail_data = {}
-- 			mail_data.head       = GuildBattleConst.memberOccupationAwardHead
-- 			mail_data.context    = GuildBattleConst.memberOccupationAwardContext
-- 			mail_data.tAwardList = {}
-- 			mailsystem.sendMailById(actor_id, mail_data)
-- 			local memberActor = LActor.getActorById(actor_id)
-- 			if memberActor then
-- 				--帮众称号
-- 				titlesystem.addTitle(memberActor, GuildBattleConst.memberOccupationAward)
-- 				actorevent.onEvent(memberActor, aeLLFBWin)
-- 			else
-- 				local actorData = offlinedatamgr.GetDataByOffLineDataType(actor_id, offlinedatamgr.EOffLineDataType.EOperable)
-- 				if actorData then
-- 					actorData.isguildbattlewin = 1
-- 				end
-- 			end
-- 		end
-- 	end
	
-- 	close()
-- 	--subactivitytype13.sendReward()
-- 	guildbattleredpacket.addRedPacketYuanBao(guild_id, GuildBattleConst.redPacketYuanBao)
-- 	guildbattleredpacket.rsfOnlineActorData(guild_id)
-- 	guildbattledayaward.rsfOnlineActorData()
-- 	broadcastDistributionDataForOnlineLeader()
-- 	noticesystem.broadCastNotice(noticesystem.NTP.guildBattle14, gvar.guild_name)
-- end

-- function isWinGuild(actor) 
-- 	local guild_id = LActor.getGuildId(actor) 
-- 	return isWinGuildId(guild_id)
-- end

-- function isWinGuildId(guild_id)
-- 	local win_guild = getWinGuild()
-- 	if guild_id == 0 then 
-- 		return false
-- 	end
-- 	if win_guild == 0 then 
-- 		return false
-- 	end
-- 	return guild_id == win_guild
-- end


-- function getFlagsData()
-- 	return guild_battle_fb.flags
-- end

-- function setFlagsStatus(status)
-- 	local var = getFlagsData()
-- 	var.status = status
-- end

-- function setFlagsWaitTick(tick)
-- 	local var = getFlagsData()
-- 	var.wait_tick = tick
-- end

-- function getFlagsWaitTick()
-- 	local var = getFlagsData()
-- 	return var.wait_tick
-- end

-- function setFlagsGatherTick(tick)
-- 	local var = getFlagsData()
-- 	var.gather_tick = tick
-- end

-- function getFlagsGatherTick(tick)
-- 	local var = getFlagsData()
-- 	return var.gather_tick 
-- end

-- function setFlagsGatherersName(name)
-- 	local var = getFlagsData()
-- 	var.gatherers_name = name
-- end

-- function setFlagsGatherersGulid(name)
-- 	local var = getFlagsData()
-- 	var.gatherers_guild = name
-- end

-- function getSceneGuildActorData()
-- 	if guild_battle_fb.sceneGuildActorData == nil then 
-- 		guild_battle_fb.sceneGuildActorData = {}
-- 	end

-- 	local sceneGuildActorData = guild_battle_fb.sceneGuildActorData
-- 	for i = gate_id, imperial_palace do
-- 		if sceneGuildActorData[i] == nil then
-- 			sceneGuildActorData[i] = {}
-- 		end
-- 	end

-- 	return sceneGuildActorData
-- end

-- function getSceneGuildActorDataById(levelid, guildId)
-- 	local sceneGuildActorData = getSceneGuildActorData()
-- 	if  sceneGuildActorData[levelid][guildId] == nil then
-- 		sceneGuildActorData[levelid][guildId] = 0
-- 	end
-- 	return sceneGuildActorData[levelid][guildId]
-- end

-- function changeSceneGuildActorDataById( levelid, guildId, count )
-- 	local sceneGuildActorData = getSceneGuildActorData()
-- 	if  sceneGuildActorData[levelid][guildId] == nil then
-- 		sceneGuildActorData[levelid][guildId] = 0
-- 	end
-- 	sceneGuildActorData[levelid][guildId] = sceneGuildActorData[levelid][guildId] + count
-- 	if sceneGuildActorData[levelid][guildId] < 0 then
-- 		sceneGuildActorData[levelid][guildId] = 0
-- 	end
-- 	broadcastSceneGuildActor(levelid, guildId)
-- end

-- local function rsfDynGlobalData()
-- 	guild_battle_fb = {}
-- 	initDynGlobalData()
-- end

-- function addKillRole(actor, num)
-- 	LActor.log(actor, "guildbattlefb.addKillRole", "call", "num:" .. num)
-- 	local var = getActorData(actor) 
-- 	var.kill_role = var.kill_role + num 
-- 	LActor.log(actor, "guildbattlefb.addKillRole", "var.kill_role:" .. var.kill_role)
-- 	if var.kill_role < 0 then 
-- 		var.kill_role = 0
-- 	end
-- 	if num > 0 then 
-- 		var.multi_kill = var.multi_kill + 1
-- 	else 
-- 		var.multi_kill = 0
-- 	end
-- 	if var.multi_kill > 1 then 
-- 		local conf = GuildBattleMultiKill[var.multi_kill]
-- 		if conf == nil then 
-- 			conf = GuildBattleMultiKill[#GuildBattleMultiKill]
-- 		end
-- 		if conf == nil then 
-- 			LActor.log(actor, "guildbattlefb.addKillRole", "not conf", var.multi_kill)
-- 			return
-- 		end
-- 		if conf.integral > 0 then
-- 			guildbattlepersonalaward.addIntegral(LActor.getActorId(actor), conf.integral)
-- 		end
-- 		noticesystem.broadCastNotice(conf.notice, LActor.getName(actor), var.multi_kill)
-- 	end

-- 	LActor.log(actor, "guildbattlefb.addKillRole", "mark", var.multi_kill, var.kill_role, num)
-- end

-- function addSceneFeats(actor, num) -- 加功勋
-- 	local var = getActorData(actor)
-- 	var.scene_feats = var.scene_feats + num 
-- 	LActor.log(actor, "guildbattlefb.addSceneFeats", "mark", var.scene_feats, num)
-- 	if var.scene_feats < 0 then 
-- 		return
-- 	end

-- 	sendSceneFeats(actor)
-- end

-- function getSceneFeats(actor)
-- 	local var = getActorData(actor)
-- 	return var.scene_feats
-- end

-- function getIntegralPhase(percentage)
-- 	if percentage == -1 then
-- 		return  GuildBattleIntegralPhase[#GuildBattleIntegralPhase]
-- 	end
-- 	local ret = nil
-- 	for i = 1,#GuildBattleIntegralPhase do 
-- 		local v = GuildBattleIntegralPhase[i]
-- 		if percentage < v.percentagePhase then 
-- 			ret = v
-- 			break
-- 		end
-- 	end
-- 	return ret  or GuildBattleIntegralPhase[#GuildBattleIntegralPhase] 
-- end

-- function isAddWasKilledIntegral(actor)
-- 	local var = getActorData(actor)
-- 	if var.was_killed >= GuildBattleConst.wasKilledCount then 
-- 		return false
-- 	end
-- 	return true
-- end

-- function addWasKilledIntegral(actor, num) 
-- 	local var = getActorData(actor)
-- 	var.was_killed = var.was_killed + num
-- 	if var.was_killed >= GuildBattleConst.wasKilledCount then 
-- 		var.was_killed = GuildBattleConst.wasKilledCount
-- 	end
-- 	if var.was_killed < 0 then 
-- 		var.was_killed = 0
-- 	end
-- end

-- --杀死了角色
-- function killRole(actor, beKillActor, level_id) 
-- 	LActor.log(actor, "guildbattlefb.killRole", "mark1", beKillActor, LActor.getName(beKillActor), level_id)
-- 	local conf = GuildBattleLevel[level_id]
-- 	if conf == nil then 
-- 		return
-- 	end

-- 	local percentage = -1
-- 	local actorIntegral = guildbattlepersonalaward.getIntegral(actor)
-- 	local beKillActorIntegral = guildbattlepersonalaward.getIntegral(beKillActor)
-- 	if beKillActorIntegral > 0 then
-- 		percentage = actorIntegral / beKillActorIntegral * 100
-- 	end
-- 	local pconf = getIntegralPhase(percentage)
-- 	local add_percentage = pconf.addPercentage / 100
-- 	LActor.log(actor, "guildbattlefb.killRole", "mark2", utils.t2s(pconf), percentage, add_percentage)
-- 	--击杀积分
-- 	guildbattlepersonalaward.addIntegral(LActor.getActorId(actor), math.floor(GuildBattleConst.killRoleIntegral * add_percentage))
-- 	--被击杀积分
-- 	if isAddWasKilledIntegral(beKillActor) then 
-- 		guildbattlepersonalaward.addIntegral(LActor.getActorId(beKillActor), GuildBattleConst.wasKilledRoleIntegral)
-- 	end

-- 	--第二个场景有功勋
-- 	if level_id == city_within then 
-- 		addSceneFeats(actor, math.floor(GuildBattleConst.killRolefeats * add_percentage))
-- 		if isAddWasKilledIntegral(beKillActor) then 
-- 			addSceneFeats(beKillActor, GuildBattleConst.wasKilledRolefeats)
-- 		end
-- 	end

-- 	--击杀数
-- 	addKillRole(actor, 1)
-- 	--被击杀数
-- 	addWasKilledIntegral(beKillActor, 1)
-- end

-- function clearSwitchSceneCd(actor) --清空切换场景cd
-- 	local var = getActorData(actor)
-- 	var.switch_scene_cd = 0 
-- end

-- --检查是否可分配(所有的)
-- local function checkDistribution(guild_id)
-- 	if guild_id == 0 then 
-- 		return false
-- 	end
-- 	local var  = getDistributionDataById(guild_id)
-- 	local rank = guildbattlepersonalaward.getRanking(guild_id)
-- 	local conf = GuildBattleDistributionAward[rank]
-- 	if conf == nil then 
-- 		return  false
-- 	end
-- 	for i,v in pairs(conf) do 
-- 		if var.distribution_ids[i] ~= nil then 
-- 			return false
-- 		end
-- 	end
-- 	return true
-- end

-- local function sendDistributionData(actor) --发送分配奖励数据
-- 	local guild_id = LActor.getGuildId(actor)
-- 	if guild_id == 0 then 
-- 		return
-- 	end
	
-- 	if not guildbattle.isLeader(actor) then 
-- 		--print(LActor.getActorId(actor) .. " not Leader")
-- 		return 
-- 	end
	
-- 	local rank = guildbattlepersonalaward.getRanking(guild_id)
-- 	local conf = GuildBattleDistributionAward[rank]
-- 	if conf == nil then 
-- 		return 
-- 	end

-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_DistributionData)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	LDataPack.writeInt(npack,rank)
-- 	if isOpen() then 
-- 		LDataPack.writeByte(npack, 0)
-- 	else
-- 		LDataPack.writeByte(npack, checkDistribution(guild_id) and 1 or 0 )
-- 	end
-- 	LDataPack.flush(npack)
-- end

-- function broadcastDistributionDataForOnlineLeader() --广播数据到所有在线 leader
-- 	local rank = guildbattlepersonalaward.gerRankingTbl()
-- 	for i,v in pairs(rank) do 
-- 		local guild_ptr = LGuild.getGuildById(v)
-- 		local leader = LGuild.getOnlineLeaderActor(guild_ptr)
-- 		if leader ~= nil then 
-- 			sendDistributionData(leader)
-- 		end
-- 	end
-- end

-- function broadcastRsfDistributionDataForOnlineLeader()
-- 	local rank = guildbattlepersonalaward.gerRankingTbl()
-- 	for i,v in pairs(rank) do 
-- 		local guild_ptr = LGuild.getGuildById(v)
-- 		local leader = LGuild.getOnlineLeaderActor(guild_ptr)
-- 		if leader ~= nil then 
-- 			local npack = LDataPack.allocPacket(leader, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_DistributionData)
-- 			if npack == nil then 
-- 				return
-- 			end
-- 			LDataPack.writeInt(npack, i)
-- 			LDataPack.writeByte(npack, 0)
-- 			LDataPack.flush(npack)
-- 		end
-- 	end
-- end

-- function enterFb(actor,id) --进入场景
-- 	-- LActor.log(actor, "guildbattlefb.enterFb", "call")
-- 	if not guildbattle.checkOpen(actor) then 
-- 		LActor.log(actor, "guildbattlefb.enterFb", "mark1")
-- 		return false
-- 	end

-- 	if not isOpen()  then 
-- 		LActor.log(actor, "guildbattlefb.enterFb", "mark2")
-- 		return false
-- 	end

-- 	local conf = GuildBattleLevel[id]
-- 	if conf == nil then 
-- 		LActor.log(actor, "guildbattlefb.enterFb", "mark3")
-- 		return false
-- 	end
-- 	local fb_id = conf.fbId

-- 	local var = getActorData(actor)
-- 	if var.id == id then 
-- 		return false
-- 	end

-- 	local now = System.getNowTime()
-- 	if now < var.switch_scene_cd then 
-- 		return false
-- 	end

-- 	if guild_battle_fb[id] == nil then 
-- 		return false
-- 	end

-- 	if var.id ~= imperial_palace and id ~= qian_dian then 
-- 		if conf.feats > getSceneFeats(actor) then 
-- 			return false
-- 		end
-- 	end

-- 	local x,y = utils.getSceneEnterCoor(fb_id)
-- 	local guild_id = LActor.getGuildId(actor)
-- 	LActor.setCamp(actor,CampType_Player)
-- 	if id ~= city_within then
-- 		LActor.enterFuBen(actor, guild_battle_fb[id].hfuben,0,x,y)
-- 	else 
-- 		local hfuben = nil 
-- 		local tmp_size = 0
-- 		local data = guild_battle_fb[id].hfubens
-- 		for i = 1,#data do 
-- 			local ins = instancesystem.getInsByHdl(data[i])
-- 			if ins ~= nil then 
-- 				local actor_size = #(ins:getActorList())
-- 				local member_size = 0
-- 				for j,jv in pairs(ins:getActorList()) do 
-- 					if LActor.getGuildId(jv) == guild_id then 
-- 						member_size = member_size + 1
-- 					end
-- 				end
-- 				if actor_size < GuildBattleConst.cityWithinActorSize and member_size < 5 then 
-- 					if actor_size >= tmp_size then 
-- 						hfuben = data[i]
-- 						tmp_size = actor_size
-- 					end
-- 				end
-- 			end
-- 		end
-- 		if hfuben == nil then 
-- 			hfuben = instancesystem.createFuBen(fb_id)
-- 			if hfuben ~= 0 then
-- 				local ins = instancesystem.getInsByHdl(hfuben)
-- 				if ins ~= nil then
-- 					ins.data.level_id = id
-- 				end
-- 				table.insert(data,hfuben)
-- 			end
-- 		end
-- 		if hfuben ~= nil then
-- 			LActor.enterFuBen(actor,hfuben,0,x,y)
-- 		end
-- 	end

-- 	return true
-- end

-- function enterNextFb(actor) --进入下一下关卡
-- 	-- LActor.log(actor, "guildbattlefb.enterFb", "call")
-- 	local var = getActorData(actor)

-- 	local conf = GuildBattleLevel[var.level_id]
-- 	if conf == nil then 
-- 		return 
-- 	end

-- 	local next_level_id = conf.nextLevel
-- 	if next_level_id == 0 then 
-- 		return 
-- 	end

-- 	if var.level_id == gate_id then 
-- 		if not guild_battle_fb.gate_die  then 
-- 			LActor.log(actor, "guildbattlefb.enterNextFb", "mark3")
-- 			return 
-- 		end
-- 	end

-- 	local next_config = GuildBattleLevel[next_level_id]
-- 	if next_config == nil then 
-- 		LActor.log(actor, "guildbattlefb.enterNextFb", "mark4")
-- 		return 
-- 	end

-- 	enterFb(actor,next_level_id)
-- end

-- function sendGateAward(ins) --发送城门奖励
-- 	System.log("guildbattlefb", "sendGateAward", "call")
-- 	local rank = bossinfo.getDdamageRank(ins)
-- 	if rank == nil or not next(rank) then 
-- 		return
-- 	end

-- 	--第一名
-- 	if rank[1] ~= nil then 
-- 		local mail_data = {}
-- 		mail_data.head       = GuildBattleConst.gateAwardHead
-- 		mail_data.context    = string.format(GuildBattleConst.gateAwardContext,1)
-- 		mail_data.tAwardList = GuildBattleConst.gateFirstAward
-- 		LActor.log(rank[1].id, "guildbattlefb.sendGateAward", "sendMail2")
-- 		mailsystem.sendMailById(rank[1].id,mail_data)
-- 		guildbattlepersonalaward.addIntegral(rank[1].id, GuildBattleConst.gateFirstIntegral)
-- 		noticesystem.broadCastNotice(noticesystem.NTP.guildBattle3, rank[1].name)
-- 	end

-- 	--第二名到最后
-- 	for i = 2,#rank do 
-- 		local mail_data = {}
-- 		mail_data.head       = GuildBattleConst.gateAwardHead
-- 		mail_data.context    = string.format(GuildBattleConst.gateAwardContext,i)
-- 		mail_data.tAwardList = GuildBattleConst.gateCommonAward
-- 		LActor.log(rank[i].id, "guildbattlefb.sendGateAward", "sendMail1")
-- 		mailsystem.sendMailById(rank[i].id,mail_data)
-- 		guildbattlepersonalaward.addIntegral(rank[i].id, GuildBattleConst.gateCommonIntegral)
-- 	end
-- end

-- local function closeCallBack()
-- 	if not isOpen()  then return end

-- 	local gId = guildbattlepersonalaward.getImperialPalaceAttributionGuildId()
-- 	setGuildBattleWinGuildId(gId, TIME_END)
-- end

-- function rsfOnlineActorData()
-- 	local actors = System.getOnlineActorList() or {}
-- 	for i=1,#actors do 
-- 		rsfActorData(actors[i])
-- 	end
-- end

-- local function autoAddIntegral(id)
-- 	if not isOpen() then 
-- 		return
-- 	end
-- 	local conf = GuildBattleLevel[id] 
-- 	if conf == nil then 
-- 		return
-- 	end
-- 	local var = guild_battle_fb[id]
-- 	if id ~= city_within then 
-- 		local actors = Fuben.getAllActor(var.hfuben)
-- 		if actors ~= nil then
-- 			for i = 1,#actors do

-- 				guildbattlepersonalaward.addIntegral(LActor.getActorId(actors[i]), conf.addIntegral)
-- 			end
-- 		end
-- 	else 
-- 		for i,v in pairs(var.hfubens) do 
-- 			local actors = Fuben.getAllActor(v)
-- 			if actors ~= nil then
-- 				for j = 1,#actors  do 
-- 					guildbattlepersonalaward.addIntegral(LActor.getActorId(actors[j]), conf.addIntegral)
-- 				end
-- 			end
-- 		end
-- 	end
-- 	if conf.addIntegralSec ~= 0 then
-- 		LActor.postScriptEventLite(nil, conf.addIntegralSec  * 1000, function() autoAddIntegral(id) end)
-- 	end
-- end

-- function killGate()
-- 	LActor.KillMonster(getGateHandle())
-- 	setGateHandle(0)
-- end

-- function killGateCallBack()
-- 	if not isOpen() then
-- 		return
-- 	end
-- 	killGate()
-- end

-- --发送城门信息
-- function sendGateInfo(actor)
-- 	local dieFlag = 1
-- 	local restTime = 0
-- 	if not guild_battle_fb.gate_die then
-- 		dieFlag = 0
-- 		local curr = System.getNowTime()
-- 		restTime = guild_battle_fb.gate_count_down - curr
-- 		if restTime < 0 then 
-- 			restTime = 0
-- 		end
-- 	end

-- 	local npack = nil
-- 	if actor then
-- 		npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_GateInfo)
-- 	else
-- 		npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_GateInfo)
-- 	end

-- 	if npack == nil then return end

-- 	LDataPack.writeByte(npack, dieFlag)
-- 	LDataPack.writeInt(npack, restTime)

-- 	if actor then
-- 		LDataPack.flush(npack)
-- 	else
-- 		sendDataForSceneById(npack, gate_id)
-- 	end
-- end


-- function sendJoinLotteryCallBack()
-- 	if not isOpen() then return end
-- 	guild_battle_fb.is_lottery = true
	
-- 	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_LotteryInfo)
-- 	if npack == nil then return end

-- 	LDataPack.writeInt(npack, GuildBattleConst.gateLotteryItem.id)
-- 	LDataPack.writeInt(npack, GuildBattleConst.gateLotteryCountDown)
-- 	sendDataForSceneById(npack, gate_id)

-- 	LActor.postScriptEventLite(nil, (GuildBattleConst.gateLotteryCountDown)  * 1000, function() joinLotteryCallBack() end)
-- end

-- function getEndTime()
-- 	if not isOpen() then 
-- 		return 0
-- 	end
-- 	if guild_battle_fb.end_time == 0 then
-- 		return 0
-- 	end
-- 	local now_t = System.getNowTime()
-- 	local sub = guild_battle_fb.end_time - now_t
-- 	if sub < 0 then 
-- 		sub = 0
-- 	end
-- 	return sub
-- end


-- function open()
-- 	System.log("guildbattlefb", "open", "call")
-- 	if isOpen()  then
-- 		System.log("guildbattlefb", "open", "mark1")
-- 		return
-- 	end

-- 	guild_battle_fb.is_open = true
-- 	guildbattle.addOpenSize(1)

-- 	--创建活动副本
-- 	for i,v in ipairs(GuildBattleLevel) do 
-- 		if guild_battle_fb[i] == nil and i ~= city_within then 
-- 			guild_battle_fb[i] = {}
-- 			if guild_battle_fb[i].hfuben == nil then
-- 				guild_battle_fb[i].hfuben  = instancesystem.createFuBen(v.fbId)
-- 				if guild_battle_fb[i].hfuben == 0 then 
-- 					System.log("guildbattlefb", "open", "createFB error", v.fbId)
-- 				end
-- 			end
-- 			local ins = instancesystem.getInsByHdl(guild_battle_fb[i].hfuben)
-- 			if ins ~= nil then
-- 				ins.data.level_id = i
-- 			end
-- 		end
-- 		if guild_battle_fb[i] == nil and i == city_within then 
-- 			guild_battle_fb[i] = {}
-- 			guild_battle_fb[i].hfubens = {}
-- 		end
-- 	end

-- 	local now_t = System.getNowTime()
-- 	--城战持续时间
-- 	LActor.postScriptEventLite(nil,(GuildBattleConst.continueTime)  * 1000,function() closeCallBack() end)
-- 	guild_battle_fb.end_time = now_t + GuildBattleConst.continueTime
	
-- 	--城门存活时间
-- 	LActor.postScriptEventLite(nil,(GuildBattleConst.gateLiveTime)  * 1000,function() killGateCallBack() end)
-- 	guild_battle_fb.gate_count_down = now_t + GuildBattleConst.gateLiveTime

-- 	--抽奖时间
-- 	LActor.postScriptEventLite(nil,(GuildBattleConst.gateLotteryWaitTime)  * 1000,function() sendJoinLotteryCallBack() end)

-- 	--定时加积分
-- 	for i,v in ipairs(GuildBattleLevel) do 
-- 		if v.addIntegralSec ~= 0 then
-- 			LActor.postScriptEventLite(nil, v.addIntegralSec  * 1000, function() autoAddIntegral(i) end)
-- 		end
-- 	end

-- 	-- 刷新以前的公会红包
-- 	guildbattleredpacket.rsfRedPacket(getWinGuild())
-- 	guildbattleredpacket.rsfOnlineActorData(getWinGuild())
	
-- 	--分配奖励
-- 	broadcastRsfDistributionDataForOnlineLeader()
-- 	rsfDistributionData()
	
-- 	--积分奖励
-- 	guildbattlepersonalaward.rsfGlobalData()
-- 	guildbattlepersonalaward.rsfOnlineActorData()

-- 	--称号
-- 	rsfTitle()
	
-- 	--城主信息
-- 	rsfOccupyData()

-- 	--每日奖励
-- 	guildbattledayaward.rsfOnlineActorData()

-- 	--广播城主信息
-- 	broadcastWinGuildInfo()

-- 	--玩家副本信息
-- 	rsfOnlineActorData()

-- 	--自动广播前三名帮派
-- 	guildbattlepersonalaward.autoBroadcastGuildRankingGtopThree()

-- 	--城战开启公告
-- 	noticesystem.broadCastNotice(noticesystem.NTP.guildBattle2)
	
-- 	--发送城战开启信息
-- 	guildbattle.broadcastOpenData()

-- 	--帮派系统设置屏蔽标记
-- 	guildsystem.setShielding(true)
-- end

-- function close()
-- 	System.log("guildbattlefb", "open", "close")
-- 	if isOpen() == false then 
-- 		System.log("guildbattlefb", "open", "mark1")
-- 		return
-- 	end
-- 	for i,v in ipairs(GuildBattleLevel) do 
-- 		if guild_battle_fb[i] ~= nil then
-- 			if i ~= city_within then 
-- 				local ins = instancesystem.getInsByHdl(guild_battle_fb[i].hfuben)
-- 				if ins ~= nil then 
-- 					ins:release()
-- 				end
-- 			else
-- 				for j,jv in pairs(guild_battle_fb[i].hfubens) do 
-- 					local ins = instancesystem.getInsByHdl(jv)
-- 					if ins ~= nil then 
-- 						ins:release()
-- 					end
-- 				end
-- 			end
-- 		end
-- 	end
-- 	rsfDynGlobalData()
-- 	guildbattle.broadcastOpenData()
-- 	guildsystem.setShielding(false)
-- end

-- ------------------
-- local function onEnterFuben(ins,actor)
-- 	local level_id = ins.data.level_id
-- 	local fbId = ins.id
-- 	local var = getActorData(actor)
	
-- 	local conf = GuildBattleLevel[level_id]
-- 	var.level_id = level_id
-- 	var.switch_scene_cd = System.getNowTime() + conf.switchSceneCd

-- 	--峡谷大门
-- 	if level_id == gate_id then
-- 		sendGateInfo(actor)
-- 	end

-- 	--叹息之桥
-- 	if level_id == city_within then
-- 		sendSceneFeats(actor)
-- 	end

-- 	--城堡外围
-- 	if level_id == qian_dian then
-- 		var.scene_feats = 0
-- 		sendSceneFeats(actor)
-- 		if var.last_level_id == city_within then
-- 			LActor.recover(actor)
-- 		end
-- 	end

-- 	--罗兰城堡
-- 	if level_id == imperial_palace then
-- 		sendShield(actor)
-- 	end

-- 	if conf.pvp == 1 then 
-- 		LActor.setCamp(actor, LActor.getGuildId(actor))
-- 	end

-- 	--同场景人数
-- 	changeSceneGuildActorDataById(level_id, LActor.getGuildId(actor), 1)

-- 	--积分
-- 	guildbattlepersonalaward.updateSceneName(actor, FubenConfig[fbId].name)
-- 	guildbattlepersonalaward.sendGuildRankingGtopThree(actor)
-- 	guildbattlepersonalaward.sendPersonalAwardData(actor)
-- 	guildbattlepersonalaward.sendGuildAndActorIntegral(actor)
	
-- 	--罗兰之剑
-- 	sendFlagsData(actor)

-- 	LActor.addSkillEffect(actor, GuildBattleConst.extraEffectId)
-- end

-- local function onExitFuben(ins, actor)  
-- 	-- LActor.log(actor, "guildbattlefb.onExitFuben", "call")
-- 	local level_id = ins.data.level_id
-- 	local conf = GuildBattleLevel[level_id]
-- 	if conf == nil then 
-- 		return
-- 	end

-- 	LActor.setCamp(actor, CampType_Player)
-- 	local var = getActorData(actor) 
-- 	if var.level_id == level_id then 
-- 		var.level_id = 0
-- 		var.last_level_id = level_id
-- 		var.switch_scene_cd = System.getNowTime()  + GuildBattleConst.exitAndOfflineSwitchSceneCd
-- 	end
	
-- 	--同场景人数
-- 	changeSceneGuildActorDataById(level_id, LActor.getGuildId(actor), -1)
	
-- 	guildbattlepersonalaward.updateSceneName(actor, "")

-- 	LActor.delSkillEffect(actor, GuildBattleConst.extraEffectId)
-- end

-- local function onOffline(ins,actor)
-- 	LActor.exitFuben(actor)
-- end

-- local function onRoleDie(ins, role, killer_hdl)
-- 	local level_id = ins.data.level_id
-- 	local conf = GuildBattleLevel[level_id]
-- 	if conf == nil then
-- 		return
-- 	end

-- 	local actor = LActor.getActor(role)
-- 	local et = LActor.getEntity(killer_hdl)
-- 	if LActor.getEntityType(et) ~= EntityType_Role then return end
-- 	local killerActor = LActor.getActor(et)
-- 	if killerActor == nil then return end
	
-- 	if conf.pvp == 1 then 
-- 		killRole(killerActor, actor, level_id)
-- 	end
 
--  	--击杀提示
-- 	local str = string.format(GuildBattleConst.killTips, LActor.getName(actor), actorrole.getJobName(LActor.getJob(role)))
-- 	LActor.sendTipmsg(killerActor, str)
-- end

-- -- 复活回调
-- function resurgenceCallBack(actor) 
-- 	local var = getActorData(actor)
-- 	if var.level_id ~= gate_id then
-- 		enterFb(actor, gate_id)
-- 	end
-- end

-- function getResurgenceConfig(integral)
-- 	local ret = nil
-- 	for i = 1,#GuildBattleResurgence do 
-- 		local v = GuildBattleResurgence[i]
-- 		if integral < v.integral then 
-- 			ret = v
-- 			break
-- 		end
-- 	end
-- 	return ret  and ret or GuildBattleResurgence[#GuildBattleResurgence] 
-- end

-- function getResurgenceCd(actor) 
-- 	local conf = getResurgenceConfig( guildbattlepersonalaward.getIntegral(actor) )
-- 	return conf.cd
-- end

-- local function onActorDie(ins, actor, killer_hdl)
-- 	print("guildbattle onActorDie")
-- 	local level_id = ins.data.level_id
	
-- 	if level_id == gate_id then return end

-- 	local var = getActorData(actor) 
-- 	local et = LActor.getEntity(killer_hdl)
-- 	local etType = LActor.getEntityType(et)
-- 	local killerName = ""
-- 	local killerGuildName = ""
-- 	if etType == EntityType_Role then
-- 		local killerActor = LActor.getActor(et)
-- 		killerName = LActor.getName(killerActor) or ""
-- 		killerGuildName = LGuild.getGuildName(LActor.getGuildPtr(killerActor)) or ""
-- 	elseif etType == EntityType_Monster then
-- 		local monsterId = LActor.getId(et)
-- 		killerName = utils.getMonsterName(monsterId)
-- 	end

-- 	--复活
-- 	local cd = getResurgenceCd(actor)
-- 	print("guildbattle onActorDie cd:" .. cd)
-- 	LActor.postScriptEventLite(actor, (cd) * 1000, function() resurgenceCallBack(actor) end)

-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_ResurgenceInfo)
-- 	if npack == nil then return end
-- 	LDataPack.writeInt(npack, cd)
-- 	LDataPack.writeByte(npack, etType)
-- 	LDataPack.writeString(npack, killerName)
-- 	LDataPack.writeString(npack, killerGuildName)
-- 	LDataPack.flush(npack)

-- 	local multiKill = var.multi_kill
-- 	if multiKill >= GuildBattleConst.finalMultikillCount then 
-- 		noticesystem.broadCastNotice(noticesystem.NTP.guildBattle10, killerName, LActor.getName(actor), multiKill)
-- 	else 
-- 		LActor.log(actor, "guildbattlefb.onActorDie", "mark1")
-- 	end
-- 	var.multi_kill = 0
-- 	var.kill_role = 0
-- end

-- local function onMonsterDie(ins, mon, killer_hdl)
-- 	local level_id = ins.data.level_id

-- 	--峡谷大门击杀boss
-- 	if level_id == gate_id and not guild_battle_fb.gate_die then 
-- 		System.log("guildbattlefb", "onMonsterDie", "mark1", Fuben.getMonsterId(mon), level_id, ins.id)
-- 		sendGateAward(ins)
-- 		guild_battle_fb.gate_die = true
-- 		sendGateInfo()
-- 		return
-- 	end

-- 	local et = LActor.getEntity(killer_hdl)
-- 	local killerActor = LActor.getActor(et)
-- 	if killerActor ~= nil then
-- 		--峡谷大门击杀普通怪物不加积分
-- 		if level_id ~= gate_id then 
-- 			guildbattlepersonalaward.addIntegral(LActor.getActorId(killerActor), GuildBattleConst.killMonsterIntegral)
-- 		end

-- 		--叹息之桥
-- 		if level_id == city_within then 
-- 			addSceneFeats(killerActor, GuildBattleConst.killMonsterfeats)
-- 		end
-- 	end
-- end

-- function getLotteryWin()
-- 	local var = getJoinLottery()
-- 	if not next(var) then 
-- 		return {}
-- 	end
-- 	local tbl = {}
-- 	for i = 1,#var do 
-- 		if not next(tbl) then 
-- 			tbl = var[i]
-- 			if tbl.num == 100 then 
-- 				break
-- 			end
-- 		else 
-- 			if var[i].num == 100 then 
-- 				tbl = var[i]
-- 				break
-- 			end
-- 			if var[i].num >= tbl.num then 
-- 				tbl = var[i]
-- 			end
-- 		end
-- 	end
-- 	return tbl
-- end

-- function sendLotteryWin()
-- 	local tbl = getLotteryWin()
-- 	if not next(tbl) then 
-- 		System.log("guildbattlefb", "sendLotteryWin", "mark1")
-- 		return 
-- 	end
-- 	local actorId = tbl.actorId
-- 	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_ReturnJoinLotteryBigNum)
-- 	if npack == nil then return end
-- 	LDataPack.writeInt(npack, tbl.num)
-- 	LDataPack.writeString(npack, LActor.getActorName(actorId))
-- 	sendDataForSceneById(npack, gate_id)
-- end

-- function joinLotteryCallBack()
-- 	local tbl = getLotteryWin()
-- 	if not next(tbl) then 
-- 		System.log("guildbattlefb", "joinLotteryCallBack", "mark1")
-- 		return 
-- 	end
-- 	local actorId = tbl.actorId
-- 	local mail_data = {}
-- 	mail_data.head       = GuildBattleConst.gateLotteryHead
-- 	mail_data.context    = GuildBattleConst.gateLotteryContext
-- 	mail_data.tAwardList = {GuildBattleConst.gateLotteryItem}
-- 	mailsystem.sendMailById(actorId, mail_data)
-- 	noticesystem.broadCastNotice(noticesystem.NTP.guildBattle4,
-- 		LActor.getActorName(actorId),
-- 		ItemConfig[GuildBattleConst.gateLotteryItem.id].name[1])
-- end

-- --添加采集效果
-- local function addGatherEffect(actor)
-- 	local mainRole = LActor.getMainRole(actor)
-- 	--当前主角色添加最高伤害效果、护盾效果
-- 	if mainRole == nil then return end
-- 	LActor.addSkillEffect(mainRole, GuildBattleConst.highestHurtEffectId)
-- 	LActor.addSkillEffect(mainRole, GuildBattleConst.shieldEffectId)
	
-- 	--其他角色添加无敌效果、霸体效果
-- 	for i = 0, 1 - 1 do
-- 		local role = LActor.getRole(actor)
-- 		if role ~= mainRole then
-- 			LActor.addSkillEffect(role, GuildBattleConst.invincibleEffectId)
-- 		end
-- 	end
-- end

-- --删除采集效果
-- local function delGatherEffect(actor)
-- 	local mainRole = LActor.getMainRole(actor)
-- 	--当前主角色删除最高伤害效果、护盾效果
-- 	if mainRole == nil then return end
-- 	LActor.delStatus(mainRole, StatusType_HighestHurt)
-- 	LActor.delStatus(mainRole, StatusType_FubenShield)
	
-- 	--其他角色添加无敌效果、霸体效果
-- 	local role = LActor.getRole(actor)
-- 	if role ~= mainRole then
-- 		LActor.delStatus(role, StatusType_Invincibility)
-- 	end	
-- end

-- --取消采集
-- local function cancelGather(actor)
-- 	LActor.cancelGather(actor)
-- end

-- local function onGateCreate(ins, mon)
-- 	local hdl = LActor.getRealHandle(mon)
-- 	setGateHandle(hdl)
-- end

-- local function onFubenShieldUpdate(ins, et, effectId, value)
-- 	local etType = LActor.getEntityType(et)
-- 	if etType ~= EntityType_Role then return end
-- 	if effectId ~= GuildBattleConst.shieldEffectId then return end

-- 	local var =  getFlagsData()
-- 	if var == nil then return end

-- 	var.cur_fuben_shield = value > 0 and value or 0
-- 	broadcastShield()

-- 	--护盾被打破，取消采集
-- 	if var.cur_fuben_shield <= 0 then
-- 		local actor = LActor.getActor(et)
-- 		cancelGather(actor)
-- 	end
-- end

-- local function onGatherMonsterCreate(ins, gatherMonster, actor)
-- 	local conf = GuildBattleLevel[imperial_palace]
-- 	if ins.id ~= conf.fbId then return end

-- 	local hdl = LActor.getHandle(mon)
-- 	setFlagHandle(hdl)
-- 	--设置采集相关信息
-- 	local var =  getFlagsData()
-- 	if var == nil then return end
-- 	local status, gather_tick, wait_tick = LActor.getGatherMonsterInfo(gatherMonster)
-- 	var.status = status
-- 	var.gather_tick = gather_tick
-- 	var.wait_tick = wait_tick
-- end

-- local function onGatherMonsterCheck( ins, gatherMonster, actor )
-- 	local conf = GuildBattleLevel[imperial_palace]
-- 	if ins.id ~= conf.fbId then return end
-- 	return true
-- end

-- local function gatherMonsterBegin( ins, gatherMonster, actor )
-- 	local actorData = LActor.getActorData(actor)
-- 	if actorData == nil then return end
-- 	local var =  getFlagsData()
-- 	if var == nil then return end

-- 	var.gatherers_actor_id = actorData.actor_id
-- 	var.gatherers_actor_handle = LActor.getHandle(actor)
-- 	var.gatherers_name = actorData.actor_name
-- 	var.gatherers_guild = LGuild.getGuilNameById(actorData.guild_id_)

-- 	--添加采集效果
-- 	addGatherEffect(actor)
	
-- 	--护盾
-- 	local effect = EffectsConfig[GuildBattleConst.shieldEffectId]
-- 	var.cur_fuben_shield = effect.args.a
-- 	var.max_fuben_shield = effect.args.a
-- 	broadcastShield()

-- 	--被采集公告
-- 	noticesystem.broadCastNotice(noticesystem.NTP.guildBattle12, var.gatherers_guild, var.gatherers_name)
-- end

-- local function gatherMonsterWait(ins, gatherMonster, actor )
-- 	local var =  getFlagsData()
-- 	if var == nil then return end

-- 	var.gatherers_actor_id = 0
-- 	var.gatherers_actor_handle = 0
-- 	var.gatherers_name = ""
-- 	var.gatherers_guild = ""

-- 	--删除采集效果
-- 	if actor then
-- 		delGatherEffect(actor)
-- 	end
-- end

-- local function gatherMonsterCanGather( ins, gatherMonster, actor )
-- 	--发送可采集公告
-- 	noticesystem.broadCastNotice(noticesystem.NTP.guildBattle11)
-- end

-- local function GatherMonsterFinish( ins, gatherMonster, actor )
-- 	local guild_id = LActor.getGuildId(actor)
-- 	setGuildBattleWinGuildId(guild_id, GATHER_END)
-- end

-- local function onGatherMonsterUpdate( ins, gatherMonster, actor )
-- 	if not isOpen() then return end

-- 	local var =  getFlagsData()
-- 	if var == nil then return end

-- 	local conf = GuildBattleLevel[imperial_palace]
-- 	if ins.id ~= conf.fbId then return end

-- 	--设置采集相关信息
-- 	local status, gather_tick, wait_tick = LActor.getGatherMonsterInfo(gatherMonster)

-- 	var.status = status
-- 	var.gather_tick = gather_tick
-- 	var.wait_tick = wait_tick

-- 	if status == GatherStatusType_Wait then
-- 		gatherMonsterWait(ins, gatherMonster, actor)
-- 	elseif status == GatherStatusType_CanGather then
-- 		gatherMonsterCanGather(ins, gatherMonster, actor)
-- 	elseif status == GatherStatusType_Gathering then
-- 		gatherMonsterBegin(ins, gatherMonster, actor)
-- 	elseif status == GatherStatusType_Finish then
-- 		GatherMonsterFinish(ins, gatherMonster, actor)
-- 	end

-- 	broadcastFlagsData()
-- end

-- local function initFbCallBack()
-- 	for i,v in ipairs(GuildBattleLevel) do
-- 		insevent.registerInstanceEnter(v.fbId, onEnterFuben)
-- 		insevent.registerInstanceExit(v.fbId, onExitFuben)
-- 		insevent.registerInstanceOffline(v.fbId, onOffline)
--         insevent.registerInstanceActorDie(v.fbId, onActorDie)
-- 	    insevent.registerInstanceMonsterDie(v.fbId, onMonsterDie)
-- 	    insevent.regRoleDie(v.fbId, onRoleDie)
-- 	end
-- 	--gate
-- 	local conf1 = GuildBattleLevel[gate_id]
-- 	insevent.registerInstanceMonsterCreate(conf1.fbId, onGateCreate)
-- 	--imperial_palace
-- 	local conf2 = GuildBattleLevel[imperial_palace]
-- 	insevent.registerInstanceFubenShieldUpdate(conf2.fbId, onFubenShieldUpdate)
-- 	insevent.registerInstanceGatherMonsterCreate(conf2.fbId, onGatherMonsterCreate)
-- 	insevent.registerInstanceGatherMonsterCheck(conf2.fbId, onGatherMonsterCheck)
-- 	insevent.registerInstanceGatherMonsterUpdate(conf2.fbId, onGatherMonsterUpdate)
-- end
-- -------------------

-- local function reqEnter(actor,pack)
-- 	clearSwitchSceneCd(actor) --进入场景不会在有cd
-- 	enterFb(actor,gate_id)
-- end

-- local function reqEnterNext(actor)	
-- 	if LActor.isDeath(actor) then
-- 		LActor.log(actor,"guildbattlefb","reqEnterNext","all die")
-- 		return
-- 	end
-- 	enterNextFb(actor)
-- end

-- local function reqJoinLottery(actor, pack)
-- 	local actorId = LActor.getActorId(actor)
-- 	local joinLotteryMap = getJoinLotteryMap()
-- 	if joinLotteryMap[actorId] then return end
	
-- 	local joinLottery = getJoinLottery()
-- 	local index = #joinLottery + 1
-- 	local num = math.random(1,100)
-- 	joinLottery[index] = {
-- 		actorId = actorId,
-- 		num = num
-- 	}
-- 	joinLotteryMap[actorId] = num

-- 	--返回点数
-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_ReturnJoinLottery)
-- 	if npack == nil then return end
-- 	LDataPack.writeInt(npack, num)
-- 	LDataPack.flush(npack)
	
-- 	--返回最大点数
-- 	sendLotteryWin()
-- end

-- local function checkDistributionById(guild_id, distribution_id, distData)
-- 	if guild_id == 0 then 
-- 		return false
-- 	end
-- 	local guild_ptr = LGuild.getGuildById(guild_id)
-- 	local var       = getDistributionDataById(guild_id)
-- 	local rank      = guildbattlepersonalaward.getRanking(guild_id)
-- 	if GuildBattleDistributionAward[rank] == nil then 
-- 		return false
-- 	end
-- 	local conf = GuildBattleDistributionAward[rank][distribution_id]
-- 	if conf == nil then 
-- 		return false
-- 	end
-- 	if conf.count ~= distData.count then 
-- 		System.log("guildbattlefb", "checkDistributionById", "mark1", guild_id, distData.count, conf.count)
-- 		return false
-- 	end
-- 	local actors = distData.actors
-- 	for actorId, count in pairs(actors) do 
-- 		if not LGuild.isMember(guild_ptr, actorId) then 
-- 			print(guild_id .. "  没有成员 " .. actorId )
-- 			System.log("guildbattlefb", "checkDistributionById", "mark2", guild_id, actorId)
-- 			return false
-- 		end
-- 	end
-- 	if var.distribution_ids[distribution_id] ~= nil then 
-- 		System.log("guildbattlefb", "checkDistributionById", "mark3", guild_id, distribution_id)
-- 		return false
-- 	end
-- 	return true
-- end

-- local function getDistributionAward(guild_id, distribution_id, distData) --得到分配奖励
-- 	local guild_ptr = LGuild.getGuildById(guild_id)
-- 	local var       = getDistributionDataById(guild_id)
-- 	local rank      = guildbattlepersonalaward.getRanking(guild_id)
-- 	if GuildBattleDistributionAward[rank] == nil then 
-- 		System.log("guildbattlefb", "getDistributionAward", "mark2")
-- 		return false
-- 	end
-- 	local conf = GuildBattleDistributionAward[rank][distribution_id]
-- 	if conf == nil then 
-- 		System.log("guildbattlefb", "getDistributionAward", "mark3")
-- 		return false
-- 	end
-- 	var.distribution_ids[distribution_id] = true

-- 	local actors = distData.actors
-- 	for actorId, awardCount in pairs(actors) do 
-- 		local mail_data = {}
-- 		mail_data.head       = GuildBattleConst.distributionAwardHead
-- 		mail_data.context    = GuildBattleConst.distributionAwardContext
-- 		mail_data.tAwardList = {}
-- 		for j = 1, awardCount do
-- 			local award = conf.award
-- 			for k = 1, #award do
-- 				table.insert(mail_data.tAwardList, award[k])
-- 			end 
-- 		end
-- 		LActor.log(i, "guildbattlefb.getDistributionAward", "sendMail")
-- 		mailsystem.sendMailById(actorId, mail_data)
-- 	end

-- 	local str = ScriptTips.guildbattle001 .. ItemConfig[conf.award[1].id].name[1] .. ":  "
-- 	for actorId, awardCount in pairs(actors) do 
-- 		local basic_data = LActor.getActorDataById(actorId)
-- 		if basic_data == nil then
-- 			basic_data = offlinedatamgr.GetDataByOffLineDataType(var.rivalId, offlinedatamgr.EOffLineDataType.EBasic)
-- 		end
-- 		if basic_data ~= nil then
-- 			str = str .. basic_data.actor_name .. awardCount .. ScriptTips.guildbattle001 .. " "
-- 		end
-- 	end
-- 	guildchat.sendNotice(LGuild.getGuildById(guild_id), str)

-- 	return true
-- end

-- local function reqDistributionAward(actor, pack)
-- 	local guild_id = LActor.getGuildId(actor)
-- 	if guild_id == 0 then 
-- 		return
-- 	end

-- 	if not guildbattle.isLeader(actor) then 
-- 		return
-- 	end

-- 	local function sendRet(ok)
-- 		local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_DistributionReturn)
-- 		if npack == nil then 
-- 			return
-- 		end
-- 		LDataPack.writeByte(npack, ok and 1 or 0)
-- 		LDataPack.flush(npack)
-- 	end

-- 	local isSucces = false
-- 	repeat
-- 		if isOpen() then 
-- 			break
-- 		end

-- 		if not checkDistribution(guild_id) then 
-- 			break
-- 		end

-- 		local count = LDataPack.readInt(pack)
-- 		local rank = guildbattlepersonalaward.getRanking(guild_id)
-- 		local conf  = GuildBattleDistributionAward[rank]
-- 		if conf == nil then 
-- 			break
-- 		end
-- 		if #conf ~= count then 
-- 			break
-- 		end

-- 		local i   = 0
-- 		local arr = {}
-- 		local id_map = {}
-- 		while (i < count) do 
-- 			local id = LDataPack.readInt(pack)
-- 			if id_map[id] ~= nil then 
-- 				log_print(" guildbattlefb.reqDistributionAward: repeat_id  " .. id)
-- 				break
-- 			end

-- 			local count_arr = LDataPack.readInt(pack)
-- 			if count_arr > 100 then break end --写死了

-- 			local distData = {}
-- 			distData.count = 0
-- 			distData.actors = {}
-- 			local oneDistCount = distData.count
-- 			local actors = distData.actors
-- 			local isBreak = false
-- 			local j = 0
-- 			while (j < count_arr) do
-- 				local actor_id = LDataPack.readInt(pack)
-- 				local z          	= 0
-- 				local award_count	= LDataPack.readInt(pack)
-- 				if award_count < 0 or award_count > 100 then isBreak = true break end --写死了
-- 				actors[actor_id] = award_count
-- 				oneDistCount = oneDistCount + award_count
-- 				j = j + 1
-- 			end
-- 			if isBreak then break end
-- 			distData.count = oneDistCount

-- 			id_map[id] = true
-- 			arr[id] = distData
-- 			i = i + 1
-- 		end

-- 		for id, distData in pairs(arr) do 
-- 			if not checkDistributionById(guild_id, id, distData) then 
-- 				break
-- 			end
-- 		end

-- 		for id, distData in pairs(arr) do 
-- 			getDistributionAward(guild_id, id, distData)
-- 		end
-- 		sendDistributionData(actor)
-- 		isSucces = true	
-- 	until(true)

-- 	sendRet(isSucces)
-- end

-- local function reqWinGuildInfo(actor,pack)
-- 	sendWinGuidInfo(actor)
-- end

-- function broadcastSceneGuildActor(levelid, guildId)
-- 	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SameGuildActor)
-- 	if npack == nil then return end
-- 	LDataPack.writeInt(npack, guildId)
-- 	LDataPack.writeInt(npack, getSceneGuildActorDataById(levelid, guildId))
-- 	sendDataForSceneById(npack, levelid)
-- end

-- function sendSceneFeats(actor)
-- 	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SceneFeats)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	LDataPack.writeInt(npack, getSceneFeats(actor))
-- 	LDataPack.flush(npack)
-- end

-- function sendDataForScene(pack) -- 广播数据到所有活动场景
-- 	if not isOpen() then 
-- 		return
-- 	end
-- 	for i,v in ipairs(GuildBattleLevel) do 
-- 		if i ~= city_within then 
-- 			Fuben.sendData(guild_battle_fb[i].hfuben,pack)
-- 		else
-- 			for j,jv in ipairs(guild_battle_fb[i].hfubens) do 
-- 				Fuben.sendData(jv,pack)
-- 			end
-- 		end
-- 	end
-- end

-- function sendDataForSceneById(pack,id) -- 广播数据到指定id的场景
-- 	if not isOpen() then 
-- 		return
-- 	end
-- 	if guild_battle_fb[id] == nil then
-- 		return
-- 	end
-- 	local i = id
-- 	if i ~= city_within then 
-- 		Fuben.sendData(guild_battle_fb[i].hfuben,pack)
-- 	else
-- 		for j,jv in ipairs(guild_battle_fb[i].hfubens) do 
-- 			Fuben.sendData(jv,pack)
-- 		end
-- 	end
-- end

-- function makeSendFlagsData(npack)  -- 生成flags data 的数据包
-- 	local var = getFlagsData()   
-- 	local nowTick = System.getGameTick() 
-- 	LDataPack.writeShort(npack, var.status)
-- 	if var.status == 0 then  -- 不可采集
-- 		local sec = 0
-- 		if var.wait_tick > nowTick then 
-- 			sec = (var.wait_tick - nowTick) / 1000
-- 		end
-- 		LDataPack.writeInt(npack, sec)
-- 	elseif var.status == 2 then --采集中
-- 		local sec = 0
-- 		if var.gather_tick > nowTick then 
-- 			sec = (var.gather_tick - nowTick) / 1000
-- 		end
-- 		LDataPack.writeString(npack, var.gatherers_name)
-- 		LDataPack.writeDouble(npack, var.gatherers_actor_handle)
-- 		LDataPack.writeString(npack, var.gatherers_guild)
-- 		LDataPack.writeInt(npack, sec)
-- 	end
-- end

-- function sendFlagsData(actor)
-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_FlagsData)
-- 	if npack == nil then 
-- 		return false
-- 	end
-- 	makeSendFlagsData(npack)
-- 	LDataPack.flush(npack)
-- end

-- function broadcastFlagsData()
-- 	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_FlagsData)
-- 	if npack == nil then 
-- 		return false
-- 	end
-- 	makeSendFlagsData(npack)
-- 	sendDataForScene(npack)
-- end

-- function broadcastFlagsGather()
-- 	noticesystem.broadCastNotice(GuildBattleConst.flagsGatherNotice)
-- end

-- function sendShield( actor )
-- 	local var = getFlagsData()
-- 	if var == nil then return end
-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_ShieldData)
-- 	if npack == nil then 
-- 		return false
-- 	end
-- 	LDataPack.writeInt(npack, var.cur_fuben_shield or 0)
-- 	LDataPack.writeInt(npack, var.max_fuben_shield or 0)
-- 	LDataPack.flush(npack)
-- end

-- function broadcastShield()
-- 	local var = getFlagsData()
-- 	if var == nil then return end
-- 	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_ShieldData)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	LDataPack.writeInt(npack, var.cur_fuben_shield or 0)
-- 	LDataPack.writeInt(npack, var.max_fuben_shield or 0)
-- 	sendDataForSceneById(npack, imperial_palace)
-- end

-- function currGatherFlagsNotice()
-- 	local var = getFlagsData()
-- 	local actor = LActor.getActorById(var.gatherers_actor_id)
-- 	if actor == nil then 
-- 		return
-- 	end
-- 	local guild_id = LActor.getGuildId(actor) 
-- 	if guild_id == 0 then 
-- 		return
-- 	end
-- 	local guild_ptr = LActor.getGuildPtr(actor) 
-- 	local guild_name  = LGuild.getGuildName(guild_ptr)
-- 	noticesystem.broadCastNotice(GuildBattleConst.flagsCurrGatherNotice, guild_name, LActor.getName(actor))
-- end

-- --罗兰城战称号
-- local function synTitle(actor, isInit)
-- 	local occupyData = getOccupyData()
-- 	if occupyData == nil then return end

-- 	local actorId = LActor.getActorId(actor)
-- 	local guildId = LActor.getGuildId(actor)
-- 	local isLeader = false
-- 	if actorId ==  LGuild.getLeaderIdById(guildId) then
-- 		isLeader = true
-- 	end

-- 	local isDel = true
-- 	repeat
-- 		--无城主
-- 		if occupyData.guild_id == 0 then
-- 			break
-- 		end

-- 		--非城主帮派
-- 		if guildId ~= occupyData.guild_id then 
-- 			break 
-- 		end

-- 		isDel = false
-- 	until(true)

-- 	if isLeader then
-- 		titlesystem.delitle(actor, GuildBattleConst.memberOccupationAward, not isInit, isInit)
-- 		if not isDel then
-- 			titlesystem.addTitle(actor, GuildBattleConst.occupationTitle, isInit)
-- 		else
-- 			titlesystem.delitle(actor, GuildBattleConst.occupationTitle, not isInit, isInit)
-- 		end
-- 	else
-- 		titlesystem.delitle(actor, GuildBattleConst.occupationTitle, not isInit, isInit)
-- 		if not isDel then
-- 			titlesystem.addTitle(actor, GuildBattleConst.memberOccupationAward, isInit)
-- 		else
-- 			titlesystem.delitle(actor, GuildBattleConst.memberOccupationAward, not isInit, isInit)
-- 		end
-- 	end	
-- end

-- -------------
-- function onInit(actor)
-- 	if System.isBattleSrv() then return end
-- 	rsfActorData(actor)
-- 	synTitle(actor, true)
-- end

-- function onLogin(actor)
-- 	if System.isBattleSrv() then return end
-- 	sendDistributionData(actor)
-- 	sendWinGuidInfo(actor)
-- end

-- function onJoinGuild( actor )
-- 	synTitle(actor)
-- 	sendDistributionData(actor)
-- end

-- function onLeftGuild( actor )
-- 	synTitle(actor)
-- end

-- function onChangeGuildPos( actor, newPos, oldPos )
-- 	if newPos == smGuildLeader or oldPos == smGuildLeader then
-- 		synTitle(actor)
-- 	end
-- end

-- actorevent.reg(aeUserLogin, onLogin)
-- actorevent.reg(aeInit, onInit)
-- actorevent.reg(aeJoinGuild, onJoinGuild)
-- actorevent.reg(aeLeftGuild, onLeftGuild)
-- actorevent.reg(aeChangeGuildPos, onChangeGuildPos)

-- netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_Enter, reqEnter)
-- netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_EnterNext, reqEnterNext)
-- netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_DistributionAward, reqDistributionAward)
-- netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_WinGuildInfo, reqWinGuildInfo) -- 无用
-- netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_RequestJoinLottery, reqJoinLottery)

-- engineevent.regGameStartEvent(initDynGlobalData)

-- initFbCallBack()


-- local gmCmdHandlers = gmsystem.gmCmdHandlers
-- gmCmdHandlers.addgbfeat = function (actor, args)
-- 	local num = tonumber(args[1])
-- 	addSceneFeats(actor, num)
-- 	return true
-- end

-- gmCmdHandlers.addgbintegral = function (actor, args)
-- 	local num = tonumber(args[1])
-- 	guildbattlepersonalaward.addIntegral(LActor.getActorId(actor), num)
-- 	return true
-- end

-- gmCmdHandlers.gbfenter = function (actor, args)
-- 	local conf = GuildBattleLevel[imperial_palace]
-- 	local fb_id = conf.fbId
-- 	local x,y = utils.getSceneEnterCoor(fb_id)
-- 	LActor.enterFuBen(actor, guild_battle_fb[imperial_palace].hfuben,0,x,y)
-- 	return true
-- end
