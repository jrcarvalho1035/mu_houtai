-- module("guildbattlepersonalaward", package.seeall)

-- local version = 1

-- local function getActorData(actor)
-- 	local var = LActor.getStaticVar(actor) 
-- 	if var == nil then 
-- 		return nil 
-- 	end

-- 	if var.guild_battle_personal_award == nil then 
-- 		var.guild_battle_personal_award = {}
-- 	end
-- 	local guild_battle_personal_award = var.guild_battle_personal_award

-- 	if guild_battle_personal_award.version == version then
-- 		return guild_battle_personal_award
-- 	end

-- 	guild_battle_personal_award.version = version

-- 	if guild_battle_personal_award.integral == nil then 
-- 		guild_battle_personal_award.integral = 0
-- 	end
-- 	if guild_battle_personal_award.id == nil then 
-- 		guild_battle_personal_award.id = 1
-- 	end
-- 	if guild_battle_personal_award.open_size == nil then 
-- 		guild_battle_personal_award.open_size = guildbattle.getOpenSize()
-- 	end

-- 	return guild_battle_personal_award
-- end

-- function rsfActorData(actor)
-- 	LActor.log(actor, "guildbattlepersonalaward.rsfActorData", "call")
-- 	local guild_id = LActor.getGuildId(actor) 
-- 	if guild_id == 0 then 
-- 		return
-- 	end
-- 	local var = getActorData(actor)
-- 	local guildBattleOpenSize = guildbattle.getOpenSize()
-- 	if var.open_size ~= guildBattleOpenSize then 
-- 		var.open_size = guildBattleOpenSize
-- 		var.id = 1
-- 		var.integral = 0
-- 	end
-- end

-- function sendAllPersonalAward()
-- 	local actors = System.getOnlineActorList() or {}
-- 	for i=1,#actors do 
-- 		while getPersonalAward(actors[i], true) do 
-- 		end
-- 	end
-- end

-- function rsfOnlineActorData()
-- 	System.log("guildbattlepersonalaward", "rsfOnlineActorData", "call")
-- 	local actors = System.getOnlineActorList() or {}
-- 	for i=1,#actors do 
-- 		rsfActorData(actors[i])
-- 	end
-- end

-- local function getGlobalData()
-- 	local var = System.getStaticVar() 
-- 	if var == nil then 
-- 		return nil
-- 	end
-- 	if var.guild_battle_personal_award == nil then 
-- 		var.guild_battle_personal_award = {}
-- 	end
-- 	return var.guild_battle_personal_award
-- end

-- local function initGlobalData()
-- 	if System.isBattleSrv() then return end
-- 	System.log("guildbattlepersonalaward", "initGlobalData", "call")
-- 	local var = getGlobalData()
-- 	if var.ranking == nil then 
-- 		var.ranking = {}
-- 	end
-- 	if var.ranking_guild == nil then 
-- 		var.ranking_guild = {}
-- 	end
-- 	if var.guild_data == nil then 
-- 		var.guild_data = {}
-- 		--[[
-- 			total_integral 总积分
-- 			actors 
-- 			{
-- 				actor_name 名字
-- 				scene_name 场景名字
-- 				integral 积分
-- 				total_power 总战力
-- 				pos 职位
-- 				job 职业 
-- 				sex 性别 
-- 			}
-- 			guild_name 公会名
-- 			leader_name 会长名
-- 		]]
-- 	end
-- 	if var.imperial_palace_attribution == nil then 
-- 		var.imperial_palace_attribution = ""
-- 		--皇宫归属帮派名字
-- 	end
-- 	if var.imperial_palace_attribution_guild_id == nil then 
-- 		var.imperial_palace_attribution_guild_id = 0
-- 	end
-- end

-- function rsfGlobalData()
-- 	System.log("guildbattlepersonalaward", "rsfGlobalData", "call")
-- 	local var									= getGlobalData()
-- 	var.ranking									= {}
-- 	var.ranking_guild							= {}
-- 	var.guild_data								= {}
-- 	var.imperial_palace_attribution				= ""
-- 	var.imperial_palace_attribution_guild_id	= 0
-- 	guildbattleintegralrank.resetRankingList()
-- end

-- function getGuildData(guild_id)
-- 	if guild_id == 0 then 
-- 		return nil
-- 	end

-- 	local var = getGlobalData() 
-- 	local guild_data = var.guild_data
-- 	if guild_data[guild_id] == nil then 
-- 		guild_data[guild_id] = {}
-- 	end
-- 	local one_guild_data = guild_data[guild_id]
-- 	if one_guild_data.total_integral == nil then 
-- 		one_guild_data.total_integral = 0
-- 	end
-- 	if one_guild_data.actors == nil then 
-- 		one_guild_data.actors = {}
-- 	end
-- 	if one_guild_data.guild_name == nil then 
-- 		one_guild_data.guild_name = LGuild.getGuildName(LGuild.getGuildById(guild_id))
-- 	end
-- 	if one_guild_data.leader_name == nil then 
-- 		one_guild_data.leader_name = LGuild.getLeaderName(LGuild.getGuildById(guild_id))
-- 	end
-- 	return one_guild_data
-- end

-- local function getGuildActorData(guild_id, actor_id)
-- 	LActor.log(actor, "guildbattlepersonalaward.getuildActorData", "call", guild_id)
-- 	if guild_id == 0 then 
-- 		return
-- 	end
-- 	local var = getGuildData(guild_id) 
-- 	if var.actors[actor_id] == nil then 
-- 		var.actors[actor_id] = {}
-- 	end
-- 	local oneActor = var.actors[actor_id]
-- 	if	oneActor.actor_id == nil then 
-- 		oneActor.actor_id = actor_id
-- 	end
-- 	if oneActor.actor_name == nil then 
-- 		oneActor.actor_name = ""
-- 	end
-- 	if oneActor.scene_name == nil then 
-- 		oneActor.scene_name = ""
-- 	end
-- 	if oneActor.integral == nil then 
-- 		oneActor.integral = 0
-- 	end
-- 	if oneActor.total_power == nil then 
-- 		oneActor.total_power = 0
-- 	end
-- 	if oneActor.pos == nil then 
-- 		oneActor.pos = 0
-- 	end
-- 	if oneActor.job == nil then 
-- 		oneActor.job = 0
-- 	end
-- 	if oneActor.sex == nil then 
-- 		oneActor.sex = 0
-- 	end

-- 	return oneActor
-- end

-- function getTotalIntegral(guild_id)
-- 	if guild_id == 0 then 
-- 		return 0
-- 	end
-- 	local var = getGuildData(guild_id) 
-- 	return var.total_integral
-- end

-- function getIntegral(actor)
-- 	local var = getActorData(actor)
-- 	return var.integral
-- end

-- function updateTotalIntegral(guild_id) 
-- 	--System.log("guildbattlepersonalaward", "updateTotalIntegral", "call", guild_id)
-- 	if guild_id == 0 then 
-- 		return
-- 	end
-- 	local var = getGuildData(guild_id)
-- 	var.total_integral = 0
-- 	for i,v in pairs(var.actors) do 
-- 		var.total_integral = var.total_integral + v.integral
-- 		--System.log("guildbattlepersonalaward", "updateTotalIntegral", "mark1", var.total_integral)
-- 	end
-- 	sortGuild()
-- end


-- function showRanking()
-- 	local var = getGlobalData()
-- 	for i,v in pairs(var.ranking) do 
-- 		print(i .. ": " .. var.ranking[i] .."--".. var.guild_data[v].total_integral)
-- 	end
-- end

-- function getImperialPalaceAttribution()
-- 	local var = getGlobalData()
-- 	return var.imperial_palace_attribution
-- end

-- function getImperialPalaceAttributionGuildId()
-- 	local var = getGlobalData()
-- 	return var.imperial_palace_attribution_guild_id
-- end

-- function setCastellanGuild(gId)
-- 	local var = getGlobalData()
-- 	var.imperial_palace_attribution = LGuild.getGuildName(LGuild.getGuildById(gId))
-- 	var.imperial_palace_attribution_guild_id = gId
-- end

-- function sortGuild() --排序
-- 	local var = getGlobalData()
-- 	local ranking_tbl = {}
-- 	for i,v in pairs(var.guild_data) do 
-- 		table.insert(ranking_tbl,i)
-- 	end
-- 	local function comps(a,b)
-- 		local avar = getGuildData(a)
-- 		local bvar = getGuildData(b)
-- 		return avar.total_integral > bvar.total_integral
-- 	end
-- 	table.sort(ranking_tbl,comps)
-- 	var.ranking = {}
-- 	var.ranking_guild = {}
-- 	var.ranking = ranking_tbl
-- 	for i,v in pairs(ranking_tbl) do 
-- 		var.ranking_guild[v] = i
-- 	end

-- 	local guild_id = ranking_tbl[1] or 0
-- 	if guild_id ~= 0 then 
-- 		var.imperial_palace_attribution = LGuild.getGuildName(LGuild.getGuildById(guild_id))
-- 		var.imperial_palace_attribution_guild_id = guild_id
-- 	else
-- 		var.imperial_palace_attribution = ""
-- 		var.imperial_palace_attribution_guild_id = 0
-- 	end
-- end

-- function getGuildIntegralRanking()
-- 	local var = getGlobalData()
-- 	return var.ranking
-- end

-- function getRanking(guild_id) 
-- 	if guild_id == 0 then 
-- 		-- print(guild_id .. " 没有排名 1")
-- 		return -1
-- 	end
-- 	local var = getGlobalData()
-- 	if var.ranking_guild[guild_id] == nil then 
-- 		-- print(guild_id .. " 没有排名 2")
-- 		return -1
-- 	end
-- 	return var.ranking_guild[guild_id]
-- end

-- function gerRankingTbl()
-- 	local var = getGlobalData()
-- 	return var.ranking
-- end

-- function updateSceneName(actor, name)
-- 	local actor_id = LActor.getActorId(actor)
-- 	local guild_id = LActor.getGuildId(actor)
-- 	if guild_id == 0 then 
-- 		return
-- 	end

-- 	actorData = LActor.getActorDataById(actor_id)
-- 	local oneActor = getGuildActorData(guild_id, actor_id)
-- 	oneActor.actor_name  = actorData.actor_name
-- 	oneActor.total_power = actorData.total_power
-- 	oneActor.pos         = LGuild.getGuildPosById(guild_id, actor_id)
-- 	oneActor.job         = actorData.job
-- 	oneActor.sex         = actorData.sex
-- 	oneActor.scene_name  = name
-- 	addGuildActorIntegral(guild_id, actor_id, 0)
-- 	LActor.log(actor, "guildbattlepersonalaward.updateSceneName", name)
-- end

-- function addGuildActorIntegral( guildId, actorId, num )
-- 	local gvar = getGuildData(guildId)
-- 	local oneActor = getGuildActorData(guildId, actorId)
-- 	oneActor.integral    = oneActor.integral + num
-- 	if oneActor.integral < 0 then oneActor.integral = 0 end

-- 	updateTotalIntegral(guildId)
-- 	broadcastIntegral(guildId)

-- 	--玩家积分排行榜
-- 	guildbattleintegralrank.updateRankingList(actorData, oneActor.integral)
-- end

-- function OffMsgAddIntegral( actor, offmsg )
-- 	local num = LDataPack.readInt(offmsg)
-- 	if not guildbattlefb.isOpen() then 
-- 		return
-- 	end
-- 	local var = getActorData(actor)
-- 	if var.open_size ~= guildbattle.getOpenSize() then
-- 		return
-- 	end
-- 	var.integral = var.integral + num
-- 	if var.integral < 0 then 
-- 		var.integral = 0
-- 	end
-- end

-- function addIntegral(actorId, num)
-- 	if not guildbattlefb.isOpen() then 
-- 		return
-- 	end

-- 	local actorData = LActor.getActorDataById(actorId)
-- 	if actorData == nil then
-- 		actorData = offlinedatamgr.GetDataByOffLineDataType(actorId, offlinedatamgr.EOffLineDataType.EBasic)
-- 	end
-- 	if actorData == nil then return end

-- 	local guildId = actorData.guild_id_ 
-- 	if guildId == 0 then return end

-- 	local actor = LActor.getActorById(actorId)
-- 	if actor then
-- 		local var = getActorData(actor)
-- 		var.integral = var.integral + num
-- 		if var.integral < 0 then 
-- 			var.integral = 0
-- 		end
-- 		sendPersonalAwardData(actor)
-- 	else
-- 		local npack = LDataPack.allocPacket()
-- 		LDataPack.writeInt(npack, num)
-- 		System.sendOffMsg(actorId, 0, OffMsgType_GuildBattleIntegral, npack)
-- 	end

-- 	--帮派成员积分
-- 	addGuildActorIntegral(guildId, actorId, num)	
-- end

-- function broadcastIntegral(guild_id) --广播数据到所有在线帮员
-- 	local actors = LGuild.getOnlineActor(guild_id) or {}
-- 	for i,v in pairs(actors) do 
-- 		sendGuildAndActorIntegral(v,num)
-- 	end
-- end

-- function checkGetPersonalAward(actor) 
-- 	local var = getActorData(actor)
-- 	local conf = GuildBattlePersonalAward[var.id] 
-- 	if conf == nil then 
-- 		print("getPersonalAward no has conf " .. var.id)
-- 		return false
-- 	end
-- 	if conf.integral > var.integral then 
-- 		return false
-- 	end

-- 	return true
-- end

-- function sendPersonalAwardData(actor) 
-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_PersonalAwardData)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	local var = getActorData(actor)
-- 	LDataPack.writeByte(npack, checkGetPersonalAward(actor) and 1 or 0)
-- 	LDataPack.writeInt(npack, var.id)
-- 	LDataPack.writeInt(npack, var.integral)
-- 	LDataPack.flush(npack)
-- end

-- function getPersonalAward(actor, mall) --得到个人奖励
-- 	LActor.log(actor, "guildbattlepersonalaward.getPersonalAward", "call", mall)
-- 	if not checkGetPersonalAward(actor) then 
-- 		return false
-- 	end
-- 	local actor_id = LActor.getActorId(actor)
-- 	local var = getActorData(actor)
-- 	local conf =  GuildBattlePersonalAward[var.id]
-- 	var.id = var.id + 1

-- 	if mall ~= nil and mall == true then
-- 		local mail_data = {}
-- 		mail_data.head = GuildBattleConst.personalIntegralHead
-- 		mail_data.context = string.format(GuildBattleConst.personalIntegralContext, conf.integral)
-- 		mail_data.tAwardList = conf.award
-- 		LActor.log(actor_id, "guildbattlepersonalaward.getPersonalAward", "mark1")
-- 		mailsystem.sendMailById(actor_id, mail_data)
-- 	else
-- 		LActor.log(actor, "guildbattlepersonalaward.getPersonalAward", "mark2")
-- 		actoritem.addItemsByMail(actor, conf.award, "gb PersonalAward", 0, "gbpreward")
-- 	end
-- 	sendPersonalAwardData(actor)
-- 	return true
-- end

-- function sendGuildAndActorIntegral(actor, num)
-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_GuileAndActorIntegral)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	local guild_id = LActor.getGuildId(actor)
-- 	LDataPack.writeInt(npack, getIntegral(actor))
-- 	LDataPack.writeInt(npack, getTotalIntegral(guild_id))
-- 	if num == nil then 
-- 		LDataPack.writeInt(npack, 0)
-- 	else 
-- 		LDataPack.writeInt(npack, num)
-- 	end
-- 	LDataPack.flush(npack)

-- end

-- function makeGuildRankingGtopThree(npack)
-- 	local count = 0
-- 	local ranking = getGuildIntegralRanking()
-- 	if #ranking >= 3 then 
-- 		count = 3
-- 	else 
-- 		count = #ranking
-- 	end
-- 	LDataPack.writeInt(npack,count)
-- 	for i = 1,count do 
-- 		local data = getGuildData(ranking[i])
-- 		LDataPack.writeString(npack,data.guild_name)
-- 		LDataPack.writeInt(npack,data.total_integral)
-- 	end
-- end

-- function sendGuildRankingGtopThree(actor) 
-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_GuildRankingGtopThree)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	makeGuildRankingGtopThree(npack)
-- 	LDataPack.flush(npack)
-- end

-- function broadcastGuildRankingGtopThree() 
-- 	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_GuildRankingGtopThree)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	makeGuildRankingGtopThree(npack)
-- 	guildbattlefb.sendDataForScene(npack)
-- end

-- function autoBroadcastGuildRankingGtopThree()
-- 	if not guildbattlefb.isOpen() then 
-- 		return
-- 	end
-- 	broadcastGuildRankingGtopThree()
-- 	LActor.postScriptEventLite(nil,(5)  * 1000,function() autoBroadcastGuildRankingGtopThree() end)
-- end

-- function sendGuildRanking(actor)
-- 	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_GuildRanking)
-- 	if npack == nil then 
-- 		return
-- 	end

-- 	local ranking = getGuildIntegralRanking()
-- 	local size = #ranking >= GuildBattleConst.guildIntegralRaningBoardSize  and GuildBattleConst.guildIntegralRaningBoardSize or #ranking 
-- 	LDataPack.writeInt(npack,size)
-- 	for i = 1,size do 
-- 		local data = getGuildData(ranking[i])
-- 		LDataPack.writeString(npack, data.guild_name)
-- 		LDataPack.writeString(npack, data.leader_name)
-- 		LDataPack.writeInt(npack, data.total_integral)
-- 	end
-- 	LDataPack.flush(npack)
-- end

-- function sendGuildActorIntegralList(actor)
-- 	local guild_id = LActor.getGuildId(actor)
-- 	if guild_id == 0 then 
-- 		return
-- 	end
-- 	local gvar = getGuildData(guild_id)
-- 	local tmp_arr = {}
-- 	for i,v in pairs(gvar.actors) do 
-- 		table.insert(tmp_arr,v)
-- 	end
-- 	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_GuildActorIntegralList)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	LDataPack.writeInt(npack, #tmp_arr)
-- 	for i=1, #tmp_arr do 
-- 		local v = tmp_arr[i]
-- 		LDataPack.writeInt(npack, v.actor_id or 0)
-- 		LDataPack.writeString(npack, v.actor_name)
-- 		LDataPack.writeString(npack, v.scene_name)
-- 		LDataPack.writeInt(npack, v.integral)
-- 		LDataPack.writeInt(npack, v.total_power)
-- 		LDataPack.writeInt(npack, v.pos)
-- 		LDataPack.writeInt(npack, v.job)
-- 		LDataPack.writeInt(npack, v.sex)
-- 	end
-- 	LDataPack.flush(npack)
-- end

-- local function onSendGuildRanking(actor,pack)
-- 	sendGuildRanking(actor)
-- end

-- local function onGuildActorIntegralList(actor,pack)
-- 	sendGuildActorIntegralList(actor)
-- end

-- local function onPersonalAwardData(actor,pack)
-- 	sendPersonalAwardData(actor)
-- end

-- local function onGetPersonalAward(actor,pack) 
-- 	getPersonalAward(actor)
-- end

-- function onInit(actor)
-- 	if System.isBattleSrv() then return end

-- 	local var = getActorData(actor)
-- 	local guildBattleOpenSize = guildbattle.getOpenSize()
-- 	if var.open_size > 0 then
-- 		--前一次城战有可能有积分奖励没领取
-- 		if var.open_size < guildBattleOpenSize then 
-- 			while getPersonalAward(actor, true) do 
-- 			end
-- 		end
		
-- 		--最近一次城战完了，有可能有积分奖励没领取
-- 		if not guildbattlefb.isOpen() and var.open_size == guildBattleOpenSize then
-- 			while getPersonalAward(actor, true) do 
-- 			end
-- 		end
-- 	end

-- 	rsfActorData(actor)
-- end

-- function onLogin( actor )
-- 	if System.isBattleSrv() then return end
-- 	-- body
-- end

-- function onJoinGuild( actor )
-- 	onInit(actor)
-- 	onLogin(actor)
-- end

-- onChangeName = function(actor, res, name, rawName, way)
-- 	local guild_id = LActor.getGuildId(actor)
-- 	if guild_id == 0 then 
-- 		return
-- 	end
-- 	local gvar = getGuildData(guild_id)
-- 	local tmp_arr = {}
-- 	for i,v in pairs(gvar.actors) do 
-- 		table.insert(tmp_arr,v)
-- 	end
-- 	for i=1, #tmp_arr do 
-- 		local v = tmp_arr[i]
-- 		if v.actor_name == rawName then
-- 			v.actor_name = name
-- 		end
-- 	end
-- end

-- actorevent.reg(aeChangeName, onChangeName)
-- actorevent.reg(aeInit, onInit)
-- actorevent.reg(aeJoinGuild, onJoinGuild)

-- msgsystem.regHandle(OffMsgType_GuildBattleIntegral, OffMsgAddIntegral)

-- netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GuildRanking, onSendGuildRanking)
-- netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GuileActorIntegralList, onGuildActorIntegralList)
-- netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_PersonalAwardData, onPersonalAwardData)
-- netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetPersonalAward, onGetPersonalAward)

-- engineevent.regGameStartEvent(initGlobalData)


