-- module("guildbattleredpacket", package.seeall)

-- day_sec = utils.day_sec

-- local function getActorData(actor)
-- 	local var = LActor.getStaticVar(actor)
-- 	if var == nil then 
-- 		return nil
-- 	end
-- 	if var.guild_battle_red_packet == nil then 
-- 		var.guild_battle_red_packet = {}
-- 	end
-- 	return var.guild_battle_red_packet
-- end

-- local function getGlobalData(actor)
-- 	local var = System.getStaticVar()
-- 	if var == nil then 
-- 		return nil
-- 	end
-- 	if var.guild_battle_red_packet == nil then 
-- 		var.guild_battle_red_packet = {}
-- 	end
-- 	return var.guild_battle_red_packet
-- end

-- function isGetRedPacket(guild_id,actor_id)
-- 	if redPacketEmpyt(guild_id) then 
-- 		return true
-- 	end
-- 	local var = getRedPacketData(guild_id)
-- 	local ret = false
-- 	for i,v in pairs(var.red_packet_msg) do 
-- 		if v.actor_id  == actor_id then
-- 			ret = true
-- 			break
-- 		end
-- 	end
-- 	return ret
-- end

-- function getRedPacketMaxCount(guild_id) 
-- 	if guild_id == 0 then 
-- 		return 0
-- 	end
-- 	local var = getRedPacketData(guild_id)
-- 	return var.end_index - 1
-- end

-- function getRedPacketRemainCount(guild_id)
-- 	if guild_id == 0 then 
-- 		return 0
-- 	end
-- 	local var = getRedPacketData(guild_id)
-- 	return var.end_index - var.begin_index
-- end

-- function getRedPacketData(guild_id) --得到红包数据
-- 	System.log("guildbattleredpacket", "getRedPacketData", "call", guild_id)
-- 	if guild_id == 0 then 
-- 		return
-- 	end
-- 	local var = getGlobalData()
-- 	if var[guild_id] == nil then 
-- 		var[guild_id] = {}
-- 	end

-- 	local oneGuild = var[guild_id]

-- 	if oneGuild.yuan_bao == nil then 
-- 		--有多少元宝
-- 		oneGuild.yuan_bao = 0
-- 	end

-- 	if oneGuild.send_time == nil then 
-- 		oneGuild.send_time = 0
-- 		--发送时间
-- 	end

-- 	if oneGuild.red_packet == nil then 
-- 		oneGuild.red_packet = {}
-- 		--红包数据
-- 		--
-- 		--[[
-- 		yuan_bao -- 元宝
-- 		]]
-- 	end
-- 	if oneGuild.begin_index == nil then 
-- 		oneGuild.begin_index = 1
-- 		--开始index
-- 	end
-- 	if oneGuild.end_index == nil then 
-- 		oneGuild.end_index = 1
-- 		--结束index
-- 	end

-- 	if oneGuild.red_packet_msg == nil then 
-- 		oneGuild.red_packet_msg = {}
-- 		--red_packet_msg
-- 		--[[
-- 			yuan_bao -- 元宝
-- 			name --名字
-- 			actor_id
-- 		]]
-- 	end

-- 	if oneGuild.msg_size == nil then 
-- 		oneGuild.msg_size = 0
-- 		--消息大小
-- 	end

-- 	if oneGuild.red_packet_total_yuan_bao == nil  then
-- 		oneGuild.red_packet_total_yuan_bao = 0
-- 	end
	
-- 	return oneGuild
-- end

-- function redPacketEmpyt(guild_id) --红包是否空
-- 	if guild_id == 0 then 
-- 		return false
-- 	end

-- 	local var = getRedPacketData(guild_id)
-- 	if var == nil then return true end

-- 	return var.begin_index == var.end_index
-- end

-- function addRedPacketYuanBao(guild_id, num) --增加红包元宝
-- 	if guild_id == 0 then 
-- 		return
-- 	end
-- 	if not redPacketEmpyt(guild_id) then 
-- 		return 
-- 	end
-- 	local var = getRedPacketData(guild_id)
-- 	var.yuan_bao = var.yuan_bao + num 
-- 	if var.yuan_bao < 0 then 
-- 		var.yuan_bao = 0
-- 	end
-- 	System.log("guildbattleredpacket", "addRedPacketYuanBao", "mark1", guild_id, var.yuan_bao, num)
-- end

-- function sendRedPacket(guild_id, yuan_bao, count) --发送红包
-- 	if guild_id == 0 then 
-- 		return false
-- 	end 
-- 	if count == 0 or yuan_bao == 0 then 
-- 		return false
-- 	end
-- 	local tmp_yuan_bao = yuan_bao
-- 	if not guildbattlefb.isWinGuildId(guild_id) then 
-- 		print(guild_id .. " 不是获胜公会")
-- 		return false
-- 	end
-- 	if not redPacketEmpyt(guild_id) then 
-- 		print(guild_id .. " 重复发红包 ")
-- 		return false
-- 	end
-- 	if yuan_bao < count then 
-- 		print(guild_id .. " 元宝小于要发放的数量 " .. yuan_bao .. " " .. count)
-- 		return false
-- 	end
-- 	if count > LGuild.getGuildMemberCount(LGuild.getGuildById(guild_id)) then 
-- 		print(guild_id .. " 红包份数大于帮成员 " .. count .. " " ..  LGuild.getGuildMemberCount(LGuild.getGuildById(guild_id)))
-- 		return false
-- 	end
-- 	local var = getRedPacketData(guild_id)
-- 	if var.yuan_bao < yuan_bao then 
-- 		print(guild_id .. " 发红包元宝不足 " .. yuan_bao .. " " .. var.yuan_bao) 
-- 		return false
-- 	end

-- 	var.yuan_bao = var.yuan_bao - yuan_bao
	
-- 	local basic_yuan_bao = math.floor((yuan_bao / count ) / 3)
-- 	if basic_yuan_bao == 0 then 
-- 		basic_yuan_bao = 1
-- 	end

-- 	local red_packet = var.red_packet
-- 	for i = 1, count do
-- 		red_packet[var.end_index] = basic_yuan_bao
-- 		var.end_index  = var.end_index + 1
-- 	end
-- 	yuan_bao = yuan_bao - (basic_yuan_bao * count)
	
-- 	if count ~= 1 then
-- 		while (yuan_bao ~= 0) do 
-- 			local index = math.random(1, count-1)
-- 			local alloc = math.floor(yuan_bao / count) 
-- 			if alloc == 0 then 
-- 				alloc = yuan_bao
-- 			end
-- 			local yb = math.random(alloc)
-- 			red_packet[index] = red_packet[index] + yb
-- 			yuan_bao = yuan_bao - yb
-- 		end
-- 	else 
-- 		red_packet[1] = yuan_bao + basic_yuan_bao
-- 	end

-- 	for i = 1, count do
-- 		print(i .. " " .. red_packet[i])
-- 	end

-- 	var.send_time = System.getNowTime()
-- 	LActor.postScriptEventLite(nil, day_sec  * 1000, function() redPacketTimeOutCallBack(guild_id) end)
-- 	if var.yuan_bao ~= 0 then 
-- 		-- 发邮件
-- 		local mail_data = {}
-- 		mail_data.head = GuildBattleConst.sendRedPacketHead
-- 		mail_data.context = GuildBattleConst.sendRedPacketContext
-- 		mail_data.tAwardList = 
-- 		{ 
-- 			{
-- 				type  = AwardType_Numeric,
-- 				id    = NumericType_YuanBao,
-- 				count = var.yuan_bao
-- 			}
-- 		}
-- 		LActor.log(LGuild.getLeaderId(LGuild.getGuildById(guild_id)), "guildbattleredpacket.sendRedPacket", "sendmail")
-- 		mailsystem.sendMailById(LGuild.getLeaderId(LGuild.getGuildById(guild_id)),mail_data)
-- 		var.yuan_bao = 0
-- 	end
-- 	var.red_packet_total_yuan_bao = tmp_yuan_bao

-- 	System.log("guildbattleredpacket", "sendRedPacket", "mark1", guild_id, tmp_yuan_bao, count)
-- 	return true
-- end

-- function getRedPacket(actor) --得到红包
-- 	local guild_id = LActor.getGuildId(actor)
-- 	if guild_id == 0 then 
-- 		LActor.log(actor, "guildbattleredpacket.getRedPacket", "mark1")
-- 		return false
-- 	end

-- 	if redPacketEmpyt(guild_id) then 
-- 		LActor.log(actor, "guildbattleredpacket.getRedPacket", "mark2")
-- 		return false
-- 	end
-- 	local gvar = getRedPacketData(guild_id)
-- 	local var = getActorData(actor)
-- 	local actor_id = LActor.getActorId(actor)
-- 	if isGetRedPacket(guild_id, actor_id) then 
-- 		LActor.log(actor, "guildbattleredpacket.getRedPacket", "mark3", guild_id)
-- 		return false
-- 	end

-- 	local red_packet =  gvar.red_packet
-- 	actoritem.addItem(actor, NumericType_YuanBao, red_packet[gvar.begin_index], "gb red packet")
-- 	local red_packet_msg = 
-- 	{
-- 		yuan_bao = red_packet[gvar.begin_index],
-- 		name     = LActor.getName(actor),
-- 		actor_id = actor_id
-- 	}
-- 	red_packet[gvar.begin_index] = nil
-- 	gvar.begin_index = gvar.begin_index + 1
-- 	table.insert(gvar.red_packet_msg, red_packet_msg)
-- 	return true
-- end

-- function rsfRedPacket(guild_id) --刷新红包
-- 	if guild_id   == 0 then 
-- 		return
-- 	end

-- 	local gvar = getGlobalData()
-- 	if gvar[guild_id] == nil then
-- 		return
-- 	end
-- 	local var = getRedPacketData(guild_id)
-- 	local red_packet = var.red_packet
-- 	local yuan_bao = var.yuan_bao
-- 	while (not redPacketEmpyt(guild_id)) do 
-- 		yuan_bao = yuan_bao + red_packet[var.begin_index]
-- 		var.begin_index = var.begin_index + 1
-- 	end
-- 	System.log("guildbattleredpacket", "rsfRedPacket", "mark1", guild_id, var.begin_index, yuan_bao)

-- 	if yuan_bao ~= 0 then
-- 		local mail_data = {}
-- 		mail_data.head = GuildBattleConst.redPacketTimeOutHead
-- 		mail_data.context = GuildBattleConst.redPacketTimeContext
-- 		mail_data.tAwardList = 
-- 		{ 
-- 			{
-- 				type  = AwardType_Numeric,
-- 				id    = NumericType_YuanBao,
-- 				count = yuan_bao 
-- 			}
-- 		}
-- 		LActor.log(LGuild.getLeaderId(LGuild.getGuildById(guild_id)), "guildbattleredpacket.rsfRedPacket", "sendmail")
-- 		mailsystem.sendMailById(LGuild.getLeaderId(LGuild.getGuildById(guild_id)), mail_data)
-- 	end
-- 	gvar[guild_id] = nil
-- end

-- function checkRedPacketTimeOut(guild_id) --红包是否超时
-- 	if guild_id == 0 then 
-- 		return true
-- 	end
-- 	if  redPacketEmpyt(guild_id) then 
-- 		return true
-- 	end
-- 	local var = getRedPacketData(guild_id)
-- 	local now = System.getNowTime()
-- 	if now >= (var.send_time + day_sec) then 
-- 		return true
-- 	end
-- 	return false
-- end


-- function redPacketTimeOutCallBack(guild_id)
-- 	if checkRedPacketTimeOut(guild_id) then 
-- 		rsfRedPacket(guild_id)
-- 	end
-- end

-- local function initTimer() 
-- 	if System.isBattleSrv() then return end
-- 	print("init red pack time out call back")
-- 	local var = getGlobalData()
-- 	local now = System.getNowTime()
-- 	for i,v in pairs(var) do 
-- 		if v.send_time ~= 0 then 
-- 			local sec = (v.send_time + day_sec) - now 
-- 			LActor.postScriptEventLite(nil, sec  * 1000,function() redPacketTimeOutCallBack(i) end)
-- 		end
-- 	end
-- end

-- local function freeTimeOut() -- 回收过期的红包
-- 	if System.isBattleSrv() then return end
-- 	local var = getGlobalData()
-- 	for i,v in pairs(var) do 
-- 		if v.send_time ~= 0 then 
-- 			if checkRedPacketTimeOut(i) then 
-- 				rsfRedPacket(i)
-- 			end
-- 		end
-- 	end
-- end

-- function sendRedPacketData(actor)
-- 	if not guildbattle.checkOpen(actor) then 
-- 		return
-- 	end
-- 	local guild_id = LActor.getGuildId(actor)
-- 	local gvar = getRedPacketData(guild_id) 
-- 	if not guildbattlefb.isWinGuild(actor) then 
-- 		LActor.log(actor, "guildbattleredpacket.sendRedPacketData", "mark1", guild_id)
-- 		return false
-- 	end
-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SendRedPacketData)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	if guildbattle.isLeader(actor) then 
-- 		LDataPack.writeInt(npack,gvar.yuan_bao)
-- 		local is_send = false

-- 		if gvar.yuan_bao ~= 0  and redPacketEmpyt(guild_id) then 
-- 			is_send = true
-- 		end

-- 		LDataPack.writeByte(npack,is_send and 1 or 0)
-- 	else
-- 		LDataPack.writeInt(npack,0)
-- 		LDataPack.writeByte(npack,0)
-- 	end
-- 	if redPacketEmpyt(guild_id) then 
-- 		LDataPack.writeByte(npack,0)
-- 		LDataPack.writeInt(npack,0)
-- 		--红包空了就为0
-- 	else
-- 		local is_get = not isGetRedPacket(guild_id,LActor.getActorId(actor)) 
-- 		LDataPack.writeByte(npack, is_get and 1 or 0)
-- 		LDataPack.writeInt(npack, gvar.red_packet_total_yuan_bao)
-- 	end
-- 	LDataPack.writeInt(npack,getRedPacketMaxCount(guild_id))
-- 	LDataPack.writeInt(npack,getRedPacketRemainCount(guild_id))
-- 	local red_packet_msg = gvar.red_packet_msg
-- 	LDataPack.writeInt(npack, #gvar.red_packet_msg)
-- 	for i = 1,#red_packet_msg do 
-- 		LDataPack.writeInt(npack, red_packet_msg[i].yuan_bao)
-- 		LDataPack.writeString(npack, red_packet_msg[i].name)
-- 		LDataPack.writeInt(npack, red_packet_msg[i].actor_id)
-- 	end
-- 	LDataPack.flush(npack)
-- end

-- local function retSendRedPacket(actor, ok)
-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SendRedPacketDataRetrun)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	LDataPack.writeByte(npack, ok and 1 or 0)
-- 	LDataPack.flush(npack)
-- end

-- local function reqSendRedPacket(actor, pack)
-- 	local yuan_bao = LDataPack.readInt(pack)
-- 	local count    = LDataPack.readInt(pack)

-- 	isSuccess = false
-- 	repeat
-- 		if not guildbattle.checkOpen(actor) then 
-- 			break
-- 		end
-- 		if not guildbattle.isLeader(actor) then 
-- 			break
-- 		end

-- 		local guild_id = LActor.getGuildId(actor) 
-- 		isSuccess = sendRedPacket(guild_id, yuan_bao, count)
-- 		rsfOnlineActorData(guild_id)
-- 	until(true)

-- 	retSendRedPacket(actor, isSuccess)	
-- end

-- local function retGetRedPacket(actor, ok)
-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_GetRedPacketDataRetrun)
-- 	if npack == nil then 
-- 		return
-- 	end
-- 	LDataPack.writeByte(npack, ok and 1 or 0)
-- 	LDataPack.flush(npack)
-- end

-- local function reqGetRedPacket(actor,pack)
-- 	local ret = getRedPacket(actor)
-- 	local guild_id = LActor.getGuildId(actor)
-- 	rsfOnlineActorData(guild_id)

-- 	retGetRedPacket(actor, ret)
-- end

-- function rsfOnlineActorData(guild_id) 
-- 	local actors = LGuild.getOnlineActor(guild_id) or {}
-- 	for i = 1, #actors  do 
-- 		sendRedPacketData(actors[i])
-- 	end
-- end

-- function onInit(actor)
-- 	if System.isBattleSrv() then return end
-- end

-- function onLogin(actor)
-- 	if System.isBattleSrv() then return end
-- 	sendRedPacketData(actor)
-- end

-- function onJoinGuild( actor )
-- 	onInit(actor)
-- 	onLogin(actor)
-- end

-- actorevent.reg(aeInit, onInit)
-- actorevent.reg(aeUserLogin, onLogin)
-- actorevent.reg(aeJoinGuild, onJoinGuild)

-- netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_SendRedPacket, reqSendRedPacket)
-- netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetRedPacket, reqGetRedPacket)

-- engineevent.regGameStartEvent(freeTimeOut)
-- engineevent.regGameStartEvent(initTimer)


