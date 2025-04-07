--领地争夺战跨服逻辑
module("guildbattlecross", package.seeall)

GUILD_FUBEN_HANDLE = GUILD_FUBEN_HANDLE or {}
GUILD_JOINT_INFO = GUILD_JOINT_INFO or {}

function canOpenBattle()
	local openDay = System.getOpenServerDay()
	if openDay <= 6 and openDay == GBConstConfig.openServer then
		return true
	elseif openDay > 6 and System.getDayOfWeek() == GBConstConfig.openweek then
		return true
	end
	return false
end

function guildPowerApplyStart()
	guildbattlesystem.calcBattleStageTime()
	guildbattlesystem.sendBattleStageTime()
	guildbattlesystem.sendBattleStageInfo()
	if not System.isBattleSrv() then return end
	local openDay = System.getOpenServerDay()
	local canRefresh = false
	if openDay <= 6 and openDay == GBConstConfig.openServer + 1 then
		canRefresh = true
	elseif openDay > 6 and System.getDayOfWeek() == 1 then --周日刷新
		canRefresh = true
	end
	print("guildPowerApplyStart", canRefresh)
	if canRefresh then		
		local gvar = guildbattlesystem.getGlobalData()
		for i=1, GBConstConfig.manorcount do
			gvar.applyssorts[i] = {} --排序后的战盟列表
			gvar.guesss[i] = {}  --竞猜信息
			gvar.semifinal[i] = {}
			gvar.final[i] = {}
		end
		System.saveStaticBattle()
	end	
end

function onUpdateGuildSemiWin(sId, sType, cpack)
	local guildId1 = LDataPack.readInt(cpack)
	local guildId2 = LDataPack.readInt(cpack)
	GUILD_FUBEN_HANDLE[guildId1] = nil
	GUILD_FUBEN_HANDLE[guildId2] = nil
end

function sendJoinFinalMail(guildId)
	local guild = LGuild.getGuildById(guildId)
	if not guild then return end
    local members = LGuild.getMemberIdList(guild)
	if not members then return end
    local mailData = {}
	mailData.head = GBConstConfig.finaljoinhead
	mailData.context = GBConstConfig.finaljoincontent
	mailData.tAwardList = {}
	for _, actorid in ipairs(members) do
    	mailsystem.sendMailById(actorid, mailData, 0)
    end
end

function openGuildBattle1()
	print("openGuildBattle1")
	guildbattlesystem.sendBattleStageInfo()	
	if not System.isBattleSrv() then return end	
	guildBattleStartCreate()
end

function openGuildBattle2()
	print("openGuildBattle2")
	guildbattlesystem.sendBattleStageInfo()	
	if not System.isBattleSrv() then return end	
	guildBattleStartCreate()
end

function guildBattleStartCreate()
	print("guildBattleStartCreate")
	for _, hfuben in ipairs(GUILD_FUBEN_HANDLE) do
		local ins = instancesystem.getInsByHdl(hfuben)
		if ins then
			for monid, conf in pairs(GbRefreshMonsterConfig) do
				Fuben.createMonster(ins.scene_list[1], monid, conf.position.x, conf.position.y)
			end
		end
	end
end

function enterGuildBattle2()	
	guildbattlesystem.sendBattleStageInfo()
	if not System.isBattleSrv() then return end	
	local tmps = {}
	local gvar = guildbattlesystem.getGlobalData()
	GUILD_FUBEN_HANDLE = {}
	print("enterGuildBattle2")
	for k,v in ipairs(gvar.applyssorts) do
		local final = gvar.final[k]
		--生成副本		
		for j=1, 4, 2 do
			local guildId = final[j] and v[final[j]] and v[final[j]].guildId and v[final[j]].guildId ~=0 and v[final[j]].guildId or 0
			local otherGuildId = final[j+1] and v[final[j+1]] and v[final[j+1]].guildId and v[final[j+1]].guildId ~=0 and v[final[j+1]].guildId or k*j
			print("enterGuildBattle2 final guildIds:", k, j, guildId, otherGuildId)
			if guildId ~= 0 then
				local fbId = GBConstConfig.fbId[GBManorIndexConfig[k].level]
				
				local hfuben = instancesystem.createFuBen(fbId)
				table.insert(GUILD_FUBEN_HANDLE, hfuben)
				local tmpindex1 = j > 2 and j-2 or j
				tmps[#tmps + 1] = {fbId = fbId, guildId = guildId, hfuben = hfuben, index = tmpindex1}
				gvar.fightinfo[guildId] = {}
				gvar.fightinfo[guildId].manorindex = k
				gvar.fightinfo[guildId].index = tmpindex1
				gvar.fightinfo[guildId].fbId = fbId
				gvar.fightinfo[guildId].level = GBManorIndexConfig[k].level

				local tmpindex2 = j > 2 and j-1 or j+1
				tmps[#tmps + 1] = {fbId = fbId, guildId = otherGuildId, hfuben = hfuben, index = tmpindex2}
				gvar.fightinfo[otherGuildId] = {}
				gvar.fightinfo[otherGuildId].manorindex = k
				gvar.fightinfo[otherGuildId].index = tmpindex2
				gvar.fightinfo[otherGuildId].fbId = fbId
				gvar.fightinfo[otherGuildId].level = GBManorIndexConfig[k].level
				if not gvar.fbinfo[hfuben] then gvar.fbinfo[hfuben] = {} end
				print("enterGuildBattle2 createfuben", gvar.fightinfo[guildId].index, hfuben)
				gvar.fbinfo[hfuben][tmpindex1] = guildId
				gvar.fbinfo[hfuben][tmpindex2] = otherGuildId
			end
		end
	end
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendFuben)
	LDataPack.writeShort(npack, #tmps)
	for i=1, #tmps do
		LDataPack.writeInt(npack, tmps[i].guildId)
		LDataPack.writeInt(npack, tmps[i].fbId)		
		LDataPack.writeDouble(npack, tmps[i].hfuben)
		LDataPack.writeChar(npack, tmps[i].index)
	end
	System.sendPacketToAllGameClient(npack, 0)
	System.saveStaticBattle()
end

function enterGuildBattle1()
	guildbattlesystem.sendBattleStageInfo()
	if not System.isBattleSrv() then return end	
	local tmps = {}
	local gvar = guildbattlesystem.getGlobalData()
	gvar.fightinfo = {}
	gvar.selfrank = {}
	GUILD_FUBEN_HANDLE = {}
	for k,v in ipairs(gvar.applyssorts) do
		local semifinal = gvar.semifinal[k]
		for j=1, #semifinal, 2 do
			if not semifinal[j] or not v[semifinal[j]] then break end
			local guildId = v[semifinal[j]].guildId
			print("enterGuildBattle1 semifinal ", k, j, guildId)
			if guildId ~= 0 then
				local otherGuildId = semifinal[j+1] and v[semifinal[j+1]] and v[semifinal[j+1]].guildId~=0 and v[semifinal[j+1]].guildId or k*j
				print("enterGuildBattle1 otherGuildId", otherGuildId)
				local fbId = GBConstConfig.fbId[GBManorIndexConfig[k].level]
				
				local hfuben = instancesystem.createFuBen(fbId)
				table.insert(GUILD_FUBEN_HANDLE, hfuben)
				local tmpindex1 = j > 2 and j-2 or j
				tmps[#tmps + 1] = {fbId = fbId, guildId = guildId, hfuben = hfuben, index = tmpindex1}
				gvar.fightinfo[guildId] = {}
				gvar.fightinfo[guildId].manorindex = k
				gvar.fightinfo[guildId].index = tmpindex1
				gvar.fightinfo[guildId].fbId = fbId
				gvar.fightinfo[guildId].level = GBManorIndexConfig[k].level

				local tmpindex2 = j > 2 and j-1 or j+1
				tmps[#tmps + 1] = {fbId = fbId, guildId = otherGuildId, hfuben = hfuben, index = tmpindex2}
				gvar.fightinfo[otherGuildId] = {}
				gvar.fightinfo[otherGuildId].manorindex = k
				gvar.fightinfo[otherGuildId].index = tmpindex2
				gvar.fightinfo[otherGuildId].fbId = fbId
				gvar.fightinfo[otherGuildId].level = GBManorIndexConfig[k].level
				if not gvar.fbinfo[hfuben] then gvar.fbinfo[hfuben] = {} end
				print("enterGuildBattle1 createfuben", gvar.fightinfo[guildId].index, hfuben)
				gvar.fbinfo[hfuben][tmpindex1] = guildId
				gvar.fbinfo[hfuben][tmpindex2] = otherGuildId
			end
		end		
	end
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendFuben)
	LDataPack.writeShort(npack, #tmps)
	for i=1, #tmps do
		LDataPack.writeInt(npack, tmps[i].guildId)
		LDataPack.writeInt(npack, tmps[i].fbId)		
		LDataPack.writeDouble(npack, tmps[i].hfuben)
		LDataPack.writeChar(npack, tmps[i].index)
	end
	System.sendPacketToAllGameClient(npack, 0)
	System.saveStaticBattle()
end

local function onSendFuben(sId, sType, cpack)
	GUILD_FUBEN_HANDLE = {} 
	local count = LDataPack.readShort(cpack)
	for i=1, count do
		local guildId = LDataPack.readInt(cpack)
		GUILD_FUBEN_HANDLE[guildId] = {}
		GUILD_FUBEN_HANDLE[guildId].fbId = LDataPack.readInt(cpack)
		GUILD_FUBEN_HANDLE[guildId].hfuben = LDataPack.readDouble(cpack)
		GUILD_FUBEN_HANDLE[guildId].index = LDataPack.readChar(cpack)
	end
end

function sendJoinMailByGuildId(guildId, manorindex)
    local guild = LGuild.getGuildById(guildId)
    if not guild then return end
    local members = LGuild.getMemberIdList(guild)
    if not members then return end
    local mailData = {}
    if manorindex > 0 then
    	mailData.head = GBConstConfig.joinhead
    	mailData.context = string.format(GBConstConfig.joincontext, GBManorIndexConfig[manorindex].name)
    	mailData.tAwardList = {}
    else
    	mailData.head = GBConstConfig.notjoinhead
    	mailData.context = GBConstConfig.notjoincontext
    	mailData.tAwardList = {}
    end
    for _, actorid in ipairs(members) do
    	mailsystem.sendMailById(actorid, mailData, 0)
    end
end

--给战盟匹配对手,半决赛和竞猜
function matchRivals()
	print("... matchRivals")
	local gvar = guildbattlesystem.getGlobalData()
	local canJoinGuild = {}
	local cancount = 0
	local notJoinGuild = {}
	local notcount = 0
	for i=1, GBConstConfig.manorcount do
		gvar.final[i] = {} --清空上届决赛信息
		gvar.semifinal[i] = {}
		gvar.guildResult = {} --清空上届排行信息
		local tmp = {}
		for j=1, #gvar.applyssorts[i] do
			local guildId = gvar.applyssorts[i][j].guildId
			print("matchRivals join guildId", i,j, guildId)
			if j <= 4 then
				tmp[j] = j
				canJoinGuild[guildId] = i
				cancount = cancount + 1
				if notJoinGuild[guildId] then
					notJoinGuild[guildId] = nil
					notcount = notcount - 1
				end							
			else
				notJoinGuild[guildId] = i
				notcount = notcount + 1
			end
		end
		if #tmp > 2 then
			local rivalindex = math.random(2,#tmp) --给第一名匹配对手
			table.remove(tmp, rivalindex)
			table.remove(tmp, 1)
			gvar.semifinal[i][1] = 1
			gvar.semifinal[i][2] = rivalindex
			gvar.semifinal[i][3] = tmp[1] or 3
			gvar.semifinal[i][4] = tmp[2] or 4
		elseif #tmp == 2 then
			gvar.semifinal[i][1] = 1
			gvar.semifinal[i][2] = 3
			gvar.semifinal[i][3] = 2
			gvar.semifinal[i][4] = 4
		else
			gvar.semifinal[i][1] = 1
			gvar.semifinal[i][2] = 2
			gvar.semifinal[i][3] = 3
			gvar.semifinal[i][4] = 4
		end

		if not gvar.applyssorts[i] then
			gvar.applyssorts[i] = {}
		end
		if #gvar.applyssorts[i] ~= 0 then
			for j=#gvar.applyssorts[i] + 1, 4 do
				gvar.applyssorts[i][j] = {guildId = 0, guildName = "", membercount = 0, level = 0, power = 0}
			end
		end
	end

	for guildId, manorindex in pairs(canJoinGuild) do
		sendJoinMailByGuildId(guildId, manorindex)
	end

	for guildId in pairs(notJoinGuild) do 
		sendJoinMailByGuildId(guildId, 0)
	end

	-- local npack = LDataPack.allocPacket()
    -- LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    -- LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendJoinInfo)
	-- LDataPack.writeChar(npack, cancount)
	-- for k,v in pairs(canJoinGuild) do 
	-- 	LDataPack.writeInt(npack, k)
	-- 	LDataPack.writeChar(npack, v)
	-- end
	-- LDataPack.writeChar(npack, notcount)
	-- for k,v in pairs(notJoinGuild) do 
	-- 	LDataPack.writeInt(npack, k)
	-- 	LDataPack.writeChar(npack, v)
	-- end
	-- System.sendPacketToAllGameClient(npack, 0)

	for k,v in pairs(canJoinGuild) do 
		local guild = LGuild.getGuildById(k)
		guildchat.sendNotice(guild, string.format(GBConstConfig.jointips, GBManorIndexConfig[v].name), enGuildChatNew)
	end
	--LDataPack.writeChar(npack, notcount)
	for k,v in pairs(notJoinGuild) do
		local guild = LGuild.getGuildById(k)
		guildchat.sendNotice(guild, GBConstConfig.notjointips, enGuildChatNew)
	end
end

-- local function onSendJoinInfo(sId, sType, cpack)
-- 	GUILD_JOINT_INFO = {}
-- 	GUILD_JOINT_INFO.join = {}
-- 	GUILD_JOINT_INFO.notjoin = {}
-- 	local cancount = LDataPack.readChar(cpack)
-- 	for i=1, cancount do
-- 		GUILD_JOINT_INFO.join[LDataPack.readInt(cpack)] = LDataPack.readChar(cpack)
-- 	end
-- 	local notcount = LDataPack.readChar(cpack)
-- 	for i=1, notcount do
-- 		GUILD_JOINT_INFO.notjoin[LDataPack.readInt(cpack)] = LDataPack.readChar(cpack)		
-- 	end
-- 	local actors = System.getOnlineActorList()
-- 	if actors then
-- 		for i=1, #actors do						
-- 			sendJoinMail(actors[i])
-- 		end
-- 	end
-- end

function sendJoinMail(actor)
	local var = guildbattlesystem.getActorVar(actor)
	local now = System.getNowTime()
	if not var.getmailstime or var.getmailstime == 0 or not System.isSameDay(now, var.getmailstime) then
		var.getmailstime = now
		var.getmailstime = 0
	end
	if var.getmails and var.getmails == 1 then return end
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end
	local manorindex = GUILD_JOINT_INFO.join[guildId]
	if manorindex then
		local mailData = {head = GBConstConfig.joinhead, context = string.format(GBConstConfig.joincontext, GBManorIndexConfig[manorindex].name), tAwardList={}}
		mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	elseif GUILD_JOINT_INFO.notjoin[guildId] then
		local mailData = {head = GBConstConfig.notjoinhead, context = GBConstConfig.notjoincontext, tAwardList={}}
		mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	end
	var.getmails = 1
end

function onLogin(actor)
	if System.isCrossWarSrv() then return end
	--发送是否参赛邮件
	sendJoinMail(actor)
end

--竞猜时间到,清空上次对战结果
function guildBattleGuess()
	print("guildBattleGuess start")
	guildbattlesystem.sendBattleStageInfo()
	if not System.isBattleSrv() then
		guildbattlesystem.BATTLE_RANK_INFO = {}
		return		
	end
	local gvar = guildbattlesystem.getGlobalData()
	gvar.guildResult = {}
	gvar.winguidlids = {}
	for i=1, GBConstConfig.manorcount do
		gvar.winguidlids[i] = {}
	end
	gvar.worship.job = 0
	gvar.worship.times = 0
	matchRivals()
	System.saveStaticBattle()
end

--刷新公会战力
function updateGuildPower()	
	if not canOpenBattle() then return end
	if System.isCrossWarSrv() then return end
	print("updateGuildPower2")
	local hour, minute, sec = System.getTime()
	if hour == 19 and minute >= 29 then return end
	guildbattleapply.updateGuildPower()
	LActor.postScriptEventLite(nil, 300 * 1000, updateGuildPower)
end
--十点刷新战力
function updateGuildPower1()	
	if System.isCrossWarSrv() then return end
	print("updateGuildPower1")
	guildbattleapply.updateGuildPower()
end
--二十二点刷新战力
function updateGuildPower2()	
	if System.isCrossWarSrv() then return end
	print("updateGuildPower2")
	if not canOpenBattle() then
		guildbattleapply.updateGuildPower()
	end
end

--领地争夺战决出胜负
function guildBattleStop()
	print("guildBattleStop")
	guildbattlesystem.sendBattleStageInfo()	
	if System.isBattleSrv() then		
		guildbattlesystem.sendRankInfo()
		local gvar = guildbattlesystem.getGlobalData()
		for i=1, GBConstConfig.manorcount do
			guildbattlesystem.sendGuessReward(i) --发送竞猜结果
			gvar.applyssorts[i] = {} --排序后的战盟列表
			gvar.guesss[i] = {}  --竞猜信息
		end
		sendSelfRankReward(gvar)
	else
		GUILD_JOINT_INFO = {}
	end
end

function guildBattleFinish()
	print("guildBattleFinish")
	if not System.isBattleSrv() then return end
	for k,v in ipairs(GUILD_FUBEN_HANDLE) do
		print("guildBattleFinish", k,v)
		local ins = instancesystem.getInsByHdl(v)
		if ins then
			ins:win()
		end
	end
end

--发送个人积分排行奖励
function sendSelfRankReward(gvar)
	for k,v in ipairs(gvar.selfrank) do
		for kk,vv in ipairs(GBRankRewardConfig) do
			if k >= vv.ranks[1] and k<=vv.ranks[2] then
				local context = string.format(GBConstConfig.selfrankcontext, GBManorIndexConfig[v.manorindex].name,k)
				local mailData = {head = GBConstConfig.selfrankhead, context = context, tAwardList=vv.reward}
				mailsystem.sendMailById(v.actorid, mailData, v.sId)
				break
			end
		end		
	end
end

function getFirstSelfRankInfo(actorid, sId)
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_GetFirstGuildLeaderInfo)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeChar(npack, 2)
    System.sendPacketToAllGameClient(npack, 0)
end

function setFirstRankInfo(cpack)
	local gvar = guildbattlesystem.getGlobalData()
	gvar.selfrank.job = LDataPack.readChar(cpack)
	gvar.selfrank.name = LDataPack.readString(cpack)    
	gvar.selfrank.shenzhuang = LDataPack.readInt(cpack)
	gvar.selfrank.shenqi = LDataPack.readInt(cpack)
	gvar.selfrank.wing = LDataPack.readInt(cpack)
	gvar.selfrank.shengling = LDataPack.readInt(cpack)
	gvar.selfrank.meilin = LDataPack.readInt(cpack)
end

function handleSelfRank(actor, pack)
	if System.isBattleSrv() then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SendSelfRank)
		if not npack then return end
		local actorid = LActor.getActorId(actor)
		local gvar = guildbattlesystem.getGlobalData()
		local myrank = 0
		local myscore = 0
		LDataPack.writeShort(npack, #gvar.selfrank)
		for k,v in ipairs(gvar.selfrank) do
			LDataPack.writeString(npack, v.guildname)
			LDataPack.writeString(npack, v.actorname)
			LDataPack.writeInt(npack, v.score)
			if actorid == v.actorid then
				myrank = k
				myscore = v.score
			end
		end
		LDataPack.writeShort(npack, myrank)
		LDataPack.writeInt(npack, myscore)
		LDataPack.writeString(npack, gvar.selfrank.name or "")
		LDataPack.writeChar(npack, gvar.selfrank.job or 0)
		LDataPack.writeInt(npack, gvar.selfrank.shenzhuang or 0)
		LDataPack.writeInt(npack, gvar.selfrank.shenqi or 0)
		LDataPack.writeInt(npack, gvar.selfrank.wing or 0)
		LDataPack.writeInt(npack, gvar.selfrank.shengling or 0)
		LDataPack.writeInt(npack, gvar.selfrank.meilin or 0)
		LDataPack.flush(npack)
	else
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_GetGuildSelfRank)
		LDataPack.writeInt(npack, LActor.getActorId(actor))
		System.sendPacketToAllGameClient(npack, 0)	
	end
end

local function onGetSelfRank(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_SendGuildSelfRank)
	if not npack then return end
	LDataPack.writeInt(npack, actorid)
	local gvar = guildbattlesystem.getGlobalData()
	local myrank = 0
	local myscore = 0
	LDataPack.writeShort(npack, #gvar.selfrank)
	for k,v in ipairs(gvar.selfrank) do
		LDataPack.writeString(npack, v.guildname)
		LDataPack.writeString(npack, v.actorname)
		LDataPack.writeInt(npack, v.score)
		if actorid == v.actorid then
			myrank = k
			myscore = v.score
		end
	end
	LDataPack.writeShort(npack, myrank)
	LDataPack.writeInt(npack, myscore)
	LDataPack.writeString(npack, gvar.selfrank.name or "")
	LDataPack.writeChar(npack, gvar.selfrank.job or 0)
	LDataPack.writeInt(npack, gvar.selfrank.shenzhuang or 0)
	LDataPack.writeInt(npack, gvar.selfrank.shenqi or 0)
	LDataPack.writeInt(npack, gvar.selfrank.wing or 0)
	LDataPack.writeInt(npack, gvar.selfrank.shengling or 0)
	LDataPack.writeInt(npack, gvar.selfrank.meilin or 0)
	System.sendPacketToAllGameClient(npack, sId)
end

local function onSendSelfRank(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorid)
	if not actor then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SendSelfRank)
	if not npack then return end
	local count = LDataPack.readShort(cpack)
	LDataPack.writeShort(npack, count)
	for i=1, count do
		LDataPack.writeString(npack, LDataPack.readString(cpack))
		LDataPack.writeString(npack, LDataPack.readString(cpack))
		LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	end
	LDataPack.writeShort(npack, LDataPack.readShort(cpack))
	LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	LDataPack.writeString(npack, LDataPack.readString(cpack))
	LDataPack.writeChar(npack, LDataPack.readChar(cpack))
	LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	LDataPack.flush(npack)
end

--是否可移动
function checkCanMove()
	local now = System.getNowTime()
	if now > guildbattlesystem.BATTLE_STAGE_TIME[2] and now < guildbattlesystem.BATTLE_STAGE_TIME[3] then
		return false
	end
	if now > guildbattlesystem.BATTLE_STAGE_TIME[4] and now < guildbattlesystem.BATTLE_STAGE_TIME[5] then
		return false
	end
	return true
end

function openGuildBattle1Timer()
	if not canOpenBattle() then return end
	openGuildBattle1()
end

function openGuildBattle2Timer()
	if not canOpenBattle() then return end
	openGuildBattle2()
end

function enterGuildBattle1Timer()
	if not canOpenBattle() then return end
	enterGuildBattle1()
end

function enterGuildBattle2Timer()
	if not canOpenBattle() then return end
	enterGuildBattle2()
end

function guildBattleGuessTimer()
	if not canOpenBattle() then return end
	guildBattleGuess()
end

function guildBattleStopTimer()
	if not canOpenBattle() then return end
	guildBattleStop()
end

function guildBattleFinishTimer()
	if not canOpenBattle() then return end
	guildBattleFinish()
end

_G.guildPowerApplyStart = guildPowerApplyStart
_G.openGuildBattle1 = openGuildBattle1Timer
_G.openGuildBattle2 = openGuildBattle2Timer
_G.guildBattleGuess = guildBattleGuessTimer
_G.enterGuildBattle1 = enterGuildBattle1Timer
_G.enterGuildBattle2 = enterGuildBattle2Timer
_G.guildBattleStop = guildBattleStopTimer
_G.checkCanMove = checkCanMove
_G.updateGuildPower = updateGuildPower
_G.updateGuildPower1 = updateGuildPower1
_G.updateGuildPower2 = updateGuildPower2
_G.guildBattleFinish = guildBattleFinishTimer


csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendFuben, onSendFuben)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_GetGuildSelfRank, onGetSelfRank)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendGuildSelfRank, onSendSelfRank)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_UpdateGuildSemiWin, onUpdateGuildSemiWin)
--csmsgdispatcher.Reg(CrossSrvCmd.SCGuildFight, CrossSrvSubCmd.SCGuildFightCmd_SendJoinInfo, onSendJoinInfo)


local gmCmdHandlers = gmsystem.gmCmdHandlers
function gmCmdHandlers.gbupdatepower(actor, args)
    updateGuildPower()
    print(" gmCmdHandlers.updateGuildPower end")
    return true
end

function gmCmdHandlers.gbfinish(actor, args)
	if not System.isBattleSrv() then return end
	guildBattleFinish(true)
end

