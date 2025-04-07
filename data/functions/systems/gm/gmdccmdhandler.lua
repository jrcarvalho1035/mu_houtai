
-- 处理后台发出的gm命令
module("systems.gm.gmdccmdhandler" , package.seeall)
setfenv(1, systems.gm.gmdccmdhandler)

if nil == gmDcCmdHandlers then gmDcCmdHandlers = {} end
--local lianfuutils = require("systems.lianfu.lianfuutils")
--local crossutils = require("utils.cross.crossutils")

--local gmsystem    = require("systems.gm.gmsystem")
--[[
local chatsystem  = require("systems.chat.chatsystem")
local noticemgr   = require("base.notice.noticemanager")
local gmanswer    = require("systems.gmquestion.gmquestion")
local goldrank    = require("systems.betaactivity.goldrank")
local operations  = require("systems.activity.operations")
local zhongqiu 	  = require("systems.liveness.liveness")
local xyybbase 	  = require("activity.qqplatform.xyybbase")
local xianqisys	  = require("systems.xianqi.xianqisys")
local arenasys	  = require("systems.xiandaohui.arena")
local guildbattlebase   = require("systems.guildbattle.guildbattlebase")
local marryrank   = require("systems.marry.marryrank")
local merge = require("base.mergeserver.merge")
--]]

local gmCmdHandlers = gmsystem.gmCmdHandlers
local gmDcCmdHandlers = gmDcCmdHandlers

local luaex = require("utils.luaex")


gmDcCmdHandlers.rsf = function(dp)
	System.reloadGlobalNpc(nil, 0)
	return true
end

gmDcCmdHandlers.gc = function(dp)
	System.engineGc()
	return true
end

gmDcCmdHandlers.gmMemoryLog = function()
	System.memoryLog()
end

gmDcCmdHandlers.off2txt = function()
	offlinedatamgr.bson2txt()
end

gmDcCmdHandlers.off2txt2 = function()
	offlinedatamgr.bson2txt2()
end

gmDcCmdHandlers.fri2txt = function()
	friendmgr.bson2txt()
end

gmDcCmdHandlers.exportranking = function(db)
	Ranking.updateRanking()
	local i = RankingType_Power
	local f = io.open("./ranking_"..System.getServerId()..".log","w")
	f:write("serverid,排行类型,排名,用户名,用户id,等级,转生等级,总战力,翅膀总战力,战士战力,法师战力,历练等级,宝石总等级\n")
	while (i < RankingType_Count) do
		local var = Ranking.getRankDataByType(i)
		if var ~= nil then
			local str = ""
			local j = 1
			while (j <= 3) do
				if var[j] ~= nil then
					local basic_data = toActorBasicData(var[j])
					str = str   .. System.getServerId()
					str = str .. "," .. i
					str = str .. "," .. j
					str = str .. "," .. basic_data.actor_name
					str = str .. "," .. basic_data.actor_id
					str = str .. "," .. basic_data.level
					str = str .. "," .. basic_data.zhuansheng_lv
					str = str .. "," .. basic_data.total_power

					str = str .. "," .. basic_data.total_wing_power
					str = str .. "," .. basic_data.warrior_power
					str = str .. "," .. basic_data.mage_power
					str = str .. "," .. basic_data.train_level
					str = str .. "," .. basic_data.total_stone_level
					str = str .. "\n"
				end
				j = j + 1
			end
			f:write(str)
		end
		i = i + 1
	end
	f:close()
end

--设置禁言
gmDcCmdHandlers.shutup = function(dp)
	local actor_id = tonumber(LDataPack.readString(dp))
	local time     = tonumber(LDataPack.readString(dp))
	chatcommon.shutupById(actor_id, time)
end

--解封禁言
gmDcCmdHandlers.releaseshutup = function(dp)
	local actor_id = tonumber(LDataPack.readString(dp))
	chatcommon.releaseShutupById(actor_id)
end

local fangchenmistr={"您的账号已被纳入防沉迷系统，每日游戏时间为1.5小时（3小时），每日22点00分至次日8点00分不能登录游戏，请合理安排游戏时间。",
"您的账号还有5分钟即将被强制下线。","您的账号已到达每日游戏时间上限。"}
gmDcCmdHandlers.fangchenmi = function(dp)
	local actor_id = tonumber(LDataPack.readString(dp))
	local args     = tonumber(LDataPack.readString(dp))
	--chatcommon.shutupById(actor_id, time)
	if not fangchenmistr[args] then return end
	local mail_data = {}
	mail_data.head = "防沉迷提示"
	mail_data.context = fangchenmistr[args]
	mail_data.tAwardList = {}
	mailsystem.sendMailById(actorid,mail_data)
end

gmDcCmdHandlers.getgift = function(dp)
	local actor_id = tonumber(LDataPack.readString(dp))
	local code     = LDataPack.readString(dp)
	--chatcommon.shutupById(actor_id, time)
	giftcode.getgift(actor_id, code)
end

--购买月卡
gmDcCmdHandlers.buymonthcard = function(dp)
	local actor_id = tonumber(LDataPack.readString(dp))
	if actor_id == nil then
		print("acotrid is nil")
		return
	end
	monthcard.buy(actor_id)
end

--发送奖励邮件
gmDcCmdHandlers.sendGlobalMail = function(dp)
	if System.isCrossWarSrv() then return end
	local head = LDataPack.readString(dp)
	local context = LDataPack.readString(dp)
	local item_str = LDataPack.readString(dp)
	local appid = LDataPack.readString(dp)
	print("gmDcCmdHandlers.sendGlobalMail head:" .. head)
	print("gmDcCmdHandlers.sendGlobalMail item_str:" .. item_str)
	print("gmDcCmdHandlers.sendGlobalMail appid:",appid)
	System.addGlobalMail(head,context,appid,item_str)
end

--发送邮件
gmDcCmdHandlers.sendMail = function( dp )
	if System.isBattleSrv() then return end
	local head = LDataPack.readString(dp)
	local context = LDataPack.readString(dp)
	local actorid = tonumber(LDataPack.readString(dp))
	local item_str = LDataPack.readString(dp)
	print("gmDcCmdHandlers.sendMail head:" .. head)
	print("gmDcCmdHandlers.sendMail actorid:" .. actorid)
	print("gmDcCmdHandlers.sendMail item_str:" .. item_str)
	local function split(str, delimiter)
		if str==nil or str=='' or delimiter==nil then
			return nil
		end

		local result = {}
		for match in (str..delimiter):gmatch("(.-)"..delimiter) do
			table.insert(result, match)
		end
		return result
	end
	local mail_data = {}
	mail_data.head = head
	mail_data.context = context
	mail_data.tAwardList = {}
	local tmp = luaex.stringSplit(item_str, ";")
	if tmp ~= nil then
		for i = 1, #tmp do
			local tbl = luaex.stringSplit(tmp[i],",")
			if #tbl == 3 and tonumber(tbl[3]) > 0 then
				local award = {}
				award.type = tonumber(tbl[1])
				award.id = tonumber(tbl[2])
				award.count = tonumber(tbl[3])
				table.insert(mail_data.tAwardList,award)
			end
		end
	end
	mailsystem.sendMailById(actorid,mail_data)
end

--发送公告
gmDcCmdHandlers.addnotice = function(dp)
	local content = LDataPack.readString(dp)
	local type = LDataPack.readString(dp)
	local startTime = LDataPack.readString(dp)
	local endTime = LDataPack.readString(dp)
	--单位分钟
	local interval = LDataPack.readString(dp)
	print("type:"..type)
	print("content:"..content)
	print("--------------------------------------------")
	print("--------------------------------------------")
	print("--------------------------------------------")
	print("--------------------------------------------")

	--2016-06-30 13:19:18
	local Y,M,D,d,h,m = string.match(startTime, "(%d+)-(%d+)-(%d+)%s(%d+):(%d+):(%d+)")
	print("on addnotice."..Y.." "..M.." "..D.." "..d.." "..h.." "..m)
	local st = System.timeEncode(Y,M,D,d,h,m)

	Y,M,D,d,h,m = string.match(endTime, "(%d+)-(%d+)-(%d+)%s(%d+):(%d+):(%d+)")
	print("on addnotice."..Y.." "..M.." "..D.." "..d.." "..h.." "..m)
	local et = System.timeEncode(Y,M,D,d,h,m)

	noticesystem.addDelayNotice(content, type, st, et, interval)
	return true
end

--删除所有公告
gmDcCmdHandlers.delAllNotice = function(packet)
	noticesystem.delAllDelayNotice()
	return true
end

--设置游戏公告
gmDcCmdHandlers.setAnnouncement = function (dp)
	local content = LDataPack.readString(dp)
	local item_str = LDataPack.readString(dp)
	print("gmDcCmdHandlers.setAnnouncement content:" .. content)
	print("gmDcCmdHandlers.setAnnouncement item_str:" .. item_str)
	local tmp = luaex.stringSplit(item_str, ";")
	local rewards = {}
	if tmp ~= nil then
		for i = 1,#tmp do
			repeat
				local tbl = luaex.stringSplit(tmp[i],",")
				if #tbl ~= 3 then
					print("gmDcCmdHandlers.setAnnouncement #tbl error tmp[i]:" .. tmp[i])
					break
				end

				local award = {type=tonumber(tbl[1]), id=tonumber(tbl[2]), count=tonumber(tbl[3])}
				if award.type ~= 0 and award.type ~= 1 then
					print("gmDcCmdHandlers.setAnnouncement award.type error tmp[i]:" .. tmp[i])
					break
				end
				if award.id == nil then
					print("gmDcCmdHandlers.setAnnouncement award.id error tmp[i]:" .. tmp[i])
					break
				end
				if award.count == nil or award.count <= 0 then
					print("gmDcCmdHandlers.setAnnouncement award.count error tmp[i]:" .. tmp[i])
					break
				end
				table.insert(rewards, award)
			until(true)
		end
	end

	noticesystem.setAnnouncement(content, rewards)
	return true
end

--Configurações de ladder entre servidores para switches de ladder durante a temporada
gmDcCmdHandlers.starcstianti = function (dp)
	--cstianticontrol.gmSetSysState(1)
end

--A escada entre servidores perdeu o horário de abertura e foi forçada a abrir.
gmDcCmdHandlers.ocstt = function (dp)
	--cstianticontrol.gmForceOpenTianTi()
end

--Solicitar função de compartilhamento do WeChat em segundo plano (processamento especial por Kaiying)
gmDcCmdHandlers.weixinfenxiang = function (packet)
	local actorid = tonumber(LDataPack.readString(packet))
	if not actorid then return end
	local actor = LActor.getActorById(actorid, true)
	if not actor then return end
	sdkapi.onGetShareReward(actor)
end

--踢玩家下线
gmDcCmdHandlers.kick = function(packet)
	local actorid = tonumber(LDataPack.readString(packet))
	if not actorid then return end
	local actor = LActor.getActorById(actorid, true)
	if not actor then return end

	System.closeActor(actor)
	return true
end

gmDcCmdHandlers.act23 = function(packet)
	local actorid = tonumber(LDataPack.readString(packet))
	local id = tonumber(LDataPack.readString(packet))
	subactivity23.addGm23(actorid, id)
	return true
end

gmDcCmdHandlers.monupdate = function ()
	System.monUpdate()
	System.reloadGlobalNpc(nil, 0)
	return true
end

gmDcCmdHandlers.setGuildUpgrade7Time = function(dp)
	local guildid = tonumber(LDataPack.readString(dp))
	local time     = tonumber(LDataPack.readString(dp))
	local guild = LGuild.getGuildById(guildid)
	if guild == nil then
		print("can't find guild:".. tostring(guildid))
		return true
	end

	guildcommon.gmRefreshGuildLevelUpTime(guild, time)
	return true
end

gmDcCmdHandlers.additem = function (dp)
	local actorid = tonumber(LDataPack.readString(dp))
	local itemId = tonumber(LDataPack.readString(dp))
	local count = tonumber(LDataPack.readString(dp))
	local actor = LActor.getActorById(actorid)
	gmCmdHandlers.additem(actor, {itemId, count})
	return true
end

gmDcCmdHandlers.recharge = function(dp)
	local actorid = tonumber(LDataPack.readString(dp))
	local value = tonumber(LDataPack.readString(dp))
	local actor = LActor.getActorById(tonumber(actorid))
	gmCmdHandlers.recharge(actor, {value})
	return true
end

gmDcCmdHandlers.back_recharge = function(dp)
	local actorid = tonumber(LDataPack.readString(dp))
	local value = tonumber(LDataPack.readString(dp))
	local actor = LActor.getActorById(tonumber(actorid))
	gmCmdHandlers.chongzhi(actor, {value, actorid})
	return true
end


gmCmdHandlers.ttt = function(actor, args)
	local actorid = LActor.getActorId(actor)
	local value = tonumber(args[1])
	local packet = LDataPack.allocPacket()
	LDataPack.writeData(packet, 2, dtString, actorid, dtInt, value)
	LDataPack.setPosition(packet, 0)
	gmDcCmdHandlers.back_recharge(packet)
	return true
end

gmDcCmdHandlers.itemupdate = function()
	System.itemUpdate()
	System.reloadGlobalNpc(nil, 0)
	return true
end

-- 设置版本公告更新
gmDcCmdHandlers.setserverupdate = function(dp)
	return true
end

--设置禁止发邮件(没用)
gmDcCmdHandlers.forbidmail = function(dp)
	local aid = LDataPack.readString(dp)
	local time = LDataPack.readString(dp)

	local actor = LActor.getActorById(tonumber(aid))
	if actor == nil then
		print("forbidmail error: actor not exist")
		return
	end

	--LActor.setForbidMailTime(actor, tonumber(time))
	return true
end

--是否开启定期检测服务器人数
gmDcCmdHandlers.openfcm = function(dp)
	local arg1 = LDataPack.readString(dp)
	local sysVar = System.getStaticVar()
	if arg1 == "on" then
		sysVar.openfcm = 1
		sysVar.openfcmtime = System.getNowTime()
		print("open fcm")
	else
		sysVar.openfcm = 0
		sysVar.openfcmtime = nil
		print("close fcm")
	end
	return true
end

--Releia o roteiro
gmDcCmdHandlers.agreload = function(dp)
	System.actorMgrReloadScript()
	return true
end

--读过滤字库
gmDcCmdHandlers.agfilter = function (actor, args)
	System.actorMgrLoadFilterNames()
end

gmDcCmdHandlers.reloadServerName = function (packet)
	engineevent.preLoadServerName()
	return true
end

gmDcCmdHandlers.reloadServerRoute = function (packet)
	engineevent.preLoadServerRoute()
	return true
end

gmDcCmdHandlers.hefucallback = function(packet)
	if not System.isCommSrv() then return end

	local pfName = LDataPack.readString(packet) or ""
	local masterSid = tonumber(LDataPack.readString(packet) or "")
	local slaveStr = LDataPack.readString(packet) or ""
	print("gmDcCmdHandlers.hefucallback pfName:" .. pfName)
	print("gmDcCmdHandlers.hefucallback masterSid:" .. masterSid)
	print("gmDcCmdHandlers.hefucallback slaveStr:" .. slaveStr)

	if slaveStr == "" then return end

	local slaveTbl = luaex.stringSplit(slaveStr, "|")

	if #slaveTbl == 0 then return end

	for k,v in ipairs(slaveTbl) do
		slaveTbl[k] = tonumber(v)
	end

	local sId = System.getServerId()
	if sId ~= masterSid then return end
	hefuevent.onEvent(masterSid, slaveTbl)
end

gmDcCmdHandlers.hefu = function(packet)
	if System.isCommSrv() then 
		gmCmdHandlers.tianticlose()
	else
		guildboss.flushGuildBoss()
		dartrank.dartSettlement()
	end
end

gmDcCmdHandlers.shenmoRefreshBoss = function(dp)
	local id = tonumber(LDataPack.readString(dp))
	print('gmDcCmdHandlers.shenmoRefreshBoss id=' .. tostring(id))
	if id == nil then
		return
	end

	shenmobosscross.gmRefreshBoss(id)
end

-- local lsc = require "luarocks.site_config"
-- ‍require("socket")
-- local system = lsc.LUAROCKS_UNAME_S or io.popen("uname -s"):read("*l")

gmDcCmdHandlers.actorAllLogin = function (packet)
	print("actorAllLogin start ----------------")
	local db = System.createActorsDbConn()
	local ret = System.dbConnect(db)
	if not ret then
		print('actor allLogin error dbConnect fail ret=', ret)
		return
	end
	local srvid = System.getServerId()
	local err = System.dbQuery(db, 'SELECT `actorid`,`serverindex`,`pfid`,`appid` FROM actors')
	local count = System.dbGetRowCount(db)
	if count > 0 then
		local row = System.dbCurrentRow(db)
		for i = 1, count do
			local actorid = tonumber(System.dbGetRow(row, 0))
			local serverid = tonumber(System.dbGetRow(row, 1))
			local pfid = System.dbGetRow(row, 2)
			local appid = System.dbGetRow(row, 3)
			System.ActorGMLogin(actorid, 0, serverid, "", pfid, appid)
			--socket.select(nil, nil, 0.1)
			row = System.dbNextRow(db)
		end
	end
	print("actorAllLogin end ----------------")
end

gmDcCmdHandlers.actorAllLogout = function (packet)
	print("actorAllLogout start ----------------")
	System.ActorGMLogout()
	print("actorAllLogout end   ----------------")
end

gmDcCmdHandlers.dartSettlement = function(packet)
	dartrank.dartSettlement()
end

gmDcCmdHandlers.dartGmSelfSettlement = function(packet)
	dartrank.dartGmSelfSettlement()
end

gmDcCmdHandlers.dartCars = function(packet)
	local index = tonumber(LDataPack.readString(packet))
	dartcross.settlement(index)
end

gmDcCmdHandlers.mineClearRecord = function(packet)
	minesystem.gmClearRecrod()
end

gmDcCmdHandlers.act33GmAdd = function(packet)
    local actorid = tonumber(LDataPack.readString(packet))
    local name = LDataPack.readString(packet)
    local sId = tonumber(LDataPack.readString(packet))
    local count = tonumber(LDataPack.readString(packet))
    print("onDbGmCmd ")
    print("actorid =",actorid,"name =",name,"sId =",sId,"count =",count)
    subactivity33.act33GmAdd(actorid, name, sId, count)
end

gmDcCmdHandlers.GmDcUseGlobalFunc = function(packet)
    local func_str = LDataPack.readString(packet)
    local func = _G[func_str]
    local isGm = true
    if type(func) == "function" then
    	func(isGm)
    end
end

gmDcCmdHandlers.cbBreakTeam = function(packet)
    local actorid = tonumber(LDataPack.readString(packet))
    campbattleteam.gmBreakCBteam(actorid)
end

gmDcCmdHandlers.wxInvite = function(packet)
    local actorid = LDataPack.readString(packet)
    print("wxInvite: actorid =", actorid)
    wechatsystem.wxCmdMsg(tonumber(actorid), wechatsystem.WXCmdType.WXInvite)
end

gmDcCmdHandlers.wxMsg = function(packet)
    local actorid = LDataPack.readString(packet)
    local msgType = LDataPack.readString(packet)
    local msgParam = LDataPack.readString(packet)

    print("wxMsg: actorid =", actorid, "msgType =", msgType, "msgType =", msgParam)
    wechatsystem.wxCmdMsg(tonumber(actorid), tonumber(msgType), tonumber(msgParam))
end

gmDcCmdHandlers.hfcupUpdate = function(packet)
    if not System.isBattleSrv() then return end
    local stage = tonumber(LDataPack.readString(packet))
    hefucupsystem.gmHFCupUpdate(stage)
end

gmDcCmdHandlers.ttSendEmail = function(packet)
    if not System.isBattleSrv() then return end
    tiantirank.gmSendTTEmail()
end

gmDcCmdHandlers.offDataSet = function(packet)
    local offlineDataSet = offlinedatamgr.GetDataSet()
    for actorid, aData in pairs(offlineDataSet) do
        local tData = aData[1]
        if tData then
        	local isChange = false
        	if (tData.attrs[141] or 0) > 100 then
        		tData.attrs[141] = 0
        		isChange = true
        	end
        	if (tData.attrs[158] or 0) > 100 then
        		tData.attrs[158] = 0
        		isChange = true
        	end
        	if isChange then
        		if not aData[4] then
        			aData[4] = {}
        		end
	            local mData = aData[4]
	            if mData then
	            	mData.isDirty = true
	        	end
	        end
        end
    end
end

local function SendGmResultToSys(cmdid, result)	
	-- 发送结果给后台，说明gameworld执行了gm命令
	if cmdid ~= 0 then
		SendUrl("/gmcallback.jsp", string.format("&cmdid=%d&serverid=%d&ret=%s", cmdid, System.getServerId(), result))
	end
	return true
end

_G.CmdGM = function(cmd, cmdid, dp)
	if nil == gmDcCmdHandlers then gmDcCmdHandlers = {} end

	print("on gmcmd: "..tostring(cmd))
	local handle = gmDcCmdHandlers[cmd]
	if nil == handle then return end
	if not System.isServerStarted() then
		print("server not started. discarded.")
		SendGmResultToSys(cmdid, "false")
	else
		local result = handle(dp)
		if not result then result = false end
		local result = tostring(result)
		SendGmResultToSys(cmdid, result)
	end
end

local dbretdispatcher = require("utils.net.dbretdispatcher")

function onDbGmCmd(reader)
	local cmd = LDataPack.readString(reader)
	local cmdid = LDataPack.readInt(reader)

	CmdGM(utils.trim(cmd), cmdid, reader)
end
--todo 整理数据库消息时再改
dbretdispatcher.reg(dbGlobal, 5, onDbGmCmd)

