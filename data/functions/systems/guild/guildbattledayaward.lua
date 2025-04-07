-- module("guildbattledayaward", package.seeall)

-- local version = 1

-- local function getActorData(actor)
-- 	local var = LActor.getStaticVar(actor)
-- 	if var == nil then 
-- 		return nil
-- 	end
-- 	if var.guild_battle_day_award == nil then 
-- 		var.guild_battle_day_award = {}
-- 	end
	
-- 	local guild_battle_day_award = var.guild_battle_day_award
	
-- 	if guild_battle_day_award.version == version then
-- 		return guild_battle_day_award
-- 	end

-- 	guild_battle_day_award.version = version

-- 	if guild_battle_day_award.day == nil then 
-- 		guild_battle_day_award.day = 1
-- 		--签到了多少天
-- 	end

-- 	if guild_battle_day_award.time == nil then 
-- 		guild_battle_day_award.time = os.time()
-- 	end
-- 	if guild_battle_day_award.today_get == nil then 
-- 		guild_battle_day_award.today_get = 0 
-- 		--今天是否领取
-- 	end
-- 	if guild_battle_day_award.open_size == nil then 
-- 		guild_battle_day_award.open_size = 0
-- 	end

-- 	return guild_battle_day_award
-- end

-- function getAward(actor, day)
-- 	LActor.log(actor, "guildbattledayaward.getAward", "call", "day:" .. (day or ""))
-- 	if not guildbattlefb.isWinGuild(actor) then 
-- 		return
-- 	end
-- 	local var = getActorData(actor)
-- 	if var.today_get == 1 then 
-- 		print(LActor.getActorId(actor) .. " 今天领取了")
-- 		return
-- 	end
-- 	if var.day < day then 
-- 		--签到时间不足
-- 		print(LActor.getActorId(actor) .. " 签到时间不足 ")
-- 		return false
-- 	end

-- 	local conf = GuildBattleDayAward[day]
-- 	if conf == nil then 
-- 		print("guildbattledayaward no has config " .. day)
-- 		return false
-- 	end
-- 	LActor.log(actor, "guildbattledayaward.getAward", "giveAward")
-- 	var.today_get = 1
-- 	actoritem.addItems(actor, conf.award, "guild battle day award")
-- 	return true
-- end

-- function update(actor)
-- 	if not guildbattlefb.isWinGuild(actor) then 
-- 		return
-- 	end
-- 	local var = getActorData(actor)
-- 	local curr = os.time()
-- 	if utils.getDay(curr) ~= utils.getDay(var.time) then 
-- 		var.day = var.day + 1
-- 		var.time = curr
-- 		var.today_get = 0
-- 		LActor.log(actor, "guildbattledayaward.update", "mark1", var.day, var.time)
-- 	end
-- 	if var.day > GuildBattleConst.maxDay then 
-- 		var.day = GuildBattleConst.maxDay
-- 		LActor.log(actor, "guildbattledayaward.update", "mark2",  var.day)
-- 	end
-- end

-- function rsfActorData(actor)
-- 	LActor.log(actor, "guildbattledayaward.rsfActorData", "call")
-- 	local var   = getActorData(actor)
-- 	if var.open_size == nil or var.open_size ~= guildbattle.getOpenSize() then 
-- 		var.day       = 1
-- 		var.time      = os.time()
-- 		var.open_size = guildbattle.getOpenSize()
-- 		LActor.log(actor, "guildbattledayaward.rsfActorData", "mark1")
-- 	end
-- 	LActor.log(actor, "guildbattledayaward.rsfActorData", "mark2")
-- end

-- function rsfOnlineActorData()
-- 	System.log("guildbattledayaward", "rsfOnlineActorData", "call")
-- 	local actors = System.getOnlineActorList()
-- 	if actors == nil then
-- 		return
-- 	end
-- 	for i = 1,#actors do 
-- 		rsfActorData(actors[i])
-- 		sendData(actors[i])
-- 	end
-- end

-- function sendData(actor)
-- 	local var = getActorData(actor)
-- 	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_SignInData)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	if guildbattlefb.isWinGuild(actor)  then
-- 		local is_get = true
-- 		if var.today_get == 1 then 
-- 			is_get = false
-- 		end
-- 		LDataPack.writeByte(npack, 1)
-- 		LDataPack.writeByte(npack, is_get and 0 or 1)
-- 	else 
-- 		LDataPack.writeByte(npack, 0)
-- 		LDataPack.writeByte(npack, 0)
-- 	end
-- 	--print(guildbattlefb.isWinGuild(actor))
-- 	LDataPack.writeInt(npack, var.day)
-- 	LDataPack.flush(npack)
-- end

-- local function reqGetAward(actor,pack)
-- 	if not guildbattlefb.isWinGuild(actor) then 
-- 		return
-- 	end
-- 	local day = LDataPack.readInt(pack)
-- 	getAward(actor, day)
-- 	sendData(actor)
-- end

-- function onInit(actor)
-- 	if System.isBattleSrv() then return end
-- 	rsfActorData(actor)
-- end

-- function onLogin(actor)
-- 	if System.isBattleSrv() then return end
-- 	sendData(actor)
-- end

-- local function onNewDay(actor)
-- 	if System.isBattleSrv() then return end
-- 	update(actor)
-- 	sendData(actor)
-- end

-- function onJoinGuild( actor )
-- 	onInit(actor)
-- 	onLogin(actor)
-- end

-- actorevent.reg(aeInit, onInit)
-- actorevent.reg(aeUserLogin, onLogin)
-- actorevent.reg(aeNewDayArrive, onNewDay)
-- actorevent.reg(aeJoinGuild, onJoinGuild)

-- netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetSignInAward, reqGetAward)


