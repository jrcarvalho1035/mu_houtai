module("noticesystem", package.seeall)
require("notice.notice")
require("notice.loginnotice")

global_notice_list_max = 50

NTP = {
	despair = 1,
	enhance = 2,
	zhuansheng = 3,
	job = 4,
	homeKill = 5,
	homeBelong = 6,
	homeResh = 7,
	homeShield = 8,
	kalimaKill = 9,
	kalimaAnger = 10,
	kalimaAppera = 11,
	quaintonClose = 12,
	enchantActive = 13,
	enchantLevel = 14,
	touxian = 15,
	godwake = 16,
	molian = 17,
	zhuzai1 = 18,
	zhuzai2 = 19,
	zhuzai3 = 20,
	zhuzai4 = 21,
	tianmo = 22,
	gather = 23,
	zhuzai5 = 24,
	mine1 = 25,
	mine2 = 26,
	mine3 = 27,
	fund = 28,
	holylandKill = 29,
	braveKill = 30,
	guildBattle1 = 31,
	guildBattle2 = 32,
	guildBattle3 = 33,
	guildBattle4 = 34,
	guildBattle5 = 35,
	guildBattle6 = 36,
	guildBattle7 = 37,
	guildBattle8 = 38,
	guildBattle9 = 39,
	guildBattle10 = 40,
	guildBattle11 = 41,
	guildBattle12 = 42,
	guildBattle13 = 43,
	guildBattle14 = 44,


	guildCreate = 48,
	fort1 = 49,
	fort2 = 50,
	fort3 = 51,
	fort4 = 52,
	fort5 = 53,
	agreement = 54,
	monSiege1 = 55,
	monSiege2 = 56,
	monSiege3 = 57,
	monSiege4 = 58,
	monSiege5 = 59,
	monSiege6 = 60,
	monSiege7 = 61,
	monSiege8 = 62,
	badge = 63,
	tanmi1 = 65,
	ringpowerup = 72,
	deter = 73,

	cstt1 = 78,
	cstt2 = 79,
	cstt3 = 80,
	cstt4 = 81,
	cstt5 = 82,

	kalima = 83,
	bosshome = 84,
	fort = 85,
	guzhanchang = 86,
	guildsiege = 87,

	damon = 88,
	shenmo = 89,
	godequip = 90,
	wing = 91,
	foot = 92,
	zhuanzhi = 93,
	despairkill = 94,
	quaintonpro = 95,
	quaintonenter = 96,
	jjcrank = 97,
	cshomeKill = 98,
	cshomeResh = 99,
	csboss = 100,
	smbossenter = 101,
	smbossdrop = 102,
	csclose = 104,
	shenglingTagAll = 108,
	yongzhefb = 109,
	wxrank = 110,
	wxegg = 111,
	gzcfirst = 112,
	gzcjoin = 113,
	gzcfirst1 = 114,
	hfcup1 = 115,
	hfcup2 = 116,
	hfcup3 = 117,
	haleopen = 133,
	huanshoucross = 134,
}

--系统延时公告
local DelayNoticeEid = DelayNoticeEid or {}
function addDelayNotice(content, type, startTime, endTime, interval)
	local nowTime = System.getNowTime()
	if endTime < nowTime or endTime < startTime then return end

	local delay = 0
	local times = 1
	if startTime >= nowTime then
		delay = startTime - nowTime
		times = math.floor((endTime - startTime)/  (interval * 60))
	else
		delay = 0
		times = math.floor((endTime - nowTime)/  (interval * 60))
	end

	local eId = LActor.postScriptEventEx(nil, delay * 1000,
	function(actor, type, content)
		broadCastContent(type, content, 0)
	end,
		interval * 60 * 1000,
		times,
		type,
		content
	)

	if eId then
		DelayNoticeEid[#DelayNoticeEid+1] = eId
	end
end

function delAllDelayNotice( ... )
	for i, k in ipairs(DelayNoticeEid) do
		 LActor.cancelScriptEvent(nil, k)
	end
end


local function getNoticeData()
	local var = System.getStaticChatVar()
	if var == nil then
		return nil
	end
	if var.Notice == nil then
		var.Notice = {}
	end
	if var.Notice.notice_list_begin == nil then
		var.Notice.notice_list_begin = 0
	end
	if var.Notice.notice_list_end == nil then
		var.Notice.notice_list_end = 0;
	end
	if var.Notice.notice_list == nil then
		var.Notice.notice_list = {}
	end
	return var.Notice;
end

local function getGlobalData()
	local var = System.getStaticVar()
	if not var then return end
	if not var.noticeSet then
		var.noticeSet = {
			announcement = ""
		}
	end
	if not var.noticeSet.rewards then var.noticeSet.rewards = {} end
	if not var.noticeSet.update then var.noticeSet.update = 0 end
	return var.noticeSet;
end

local function getData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then
		return nil
	end
	if var.notice == nil then
		var.notice = {}
	end
	if var.notice.time == nil then
		var.notice.time = 1 --防止被除0
	end
	if not var.notice.update then var.notice.update = 0 end
	return var.notice
end

local function addNoticeList(type, content, link)
	local tbl   = {}
	tbl.type    = type
	tbl.content = content
	tbl.link = link

	local var = getNoticeData()
	var.notice_list[var.notice_list_end] = tbl
	var.notice_list_end = var.notice_list_end + 1
	while (var.notice_list_end - var.notice_list_begin) > global_notice_list_max do
		var.notice_list[var.notice_list_begin] = nil
		var.notice_list_begin = var.notice_list_begin + 1
	end
end

------------------------------------------------------------------------------------------------------

function sendNoticeListAll(actor)
	local var = getNoticeData()
	local b = var.notice_list_begin
	local e = var.notice_list_end

	--避免死循环（理论上不可能出现）
	if b > e then
		print("ERROR: SendNoticeList fall into endless loop")
		return
	end

	local count = 0
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Notice, Protocol.sNoticeCmd_NoticeSyncLogin)
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeShort(pack, count)
	while (b ~= e) do
		local tbl = var.notice_list[b]
		if tbl then
			LDataPack.writeShort(pack,tbl.type)
			LDataPack.writeString(pack,tbl.content)
			LDataPack.writeByte(pack, 1)
			LDataPack.writeChar(pack, tbl.link or 0) --超链接id
			LDataPack.writeInt(pack, tbl.stime or 0)
			count = count + 1
		end
		b = b + 1
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeShort(pack, count)
	LDataPack.setPosition(pack, npos)
	LDataPack.flush(pack)
end

--发送今天是否打开了公告
local function sendTodayLook(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Notice, Protocol.sNoticeCmd_TodayLook)
	if npack == nil then
		return
	end
	local var = getData(actor)
	local curr_time = os.time()
	LDataPack.writeByte(npack,utils.getDay(var.time) ~= utils.getDay(curr_time) and 1 or 0)
	LDataPack.flush(npack)
end

--打开公告
local function onSetTodayLook(actor,packet)
	local var = getData(actor)
	var.time = os.time()
end

local function onNoticeLogin(actor)
	if System.isCrossWarSrv() then return end
	sendTodayLook(actor)
	--LActor.postScriptEventLite(actor,5000,sendNoticeListAll,actor)
	sendNoticeListAll(actor)
	s2cCheckReward(actor)
end

function broadLoginNotice2(id, job, name)
	if not System.isCommSrv() then return end
	if not id then
		print('noticesystem.broadLoginNotice2 id==nil')
		return
	end
	if not LoginNoticeConfig[id] then return end

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCChatCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCChatCmd_UpdateLoginBroadcast)
	LDataPack.writeChar(npack, id)
	LDataPack.writeChar(npack, job)
	LDataPack.writeString(npack, name)
    System.sendPacketToAllGameClient(npack, 0)
end

function broadLoginNotice(actor, id)
	broadLoginNotice2(id, LActor.getJob(actor), LActor.getName(actor))
end

function onUpdateLogin(sId, sType, cpack)
	local id = LDataPack.readChar(cpack)
	local job = LDataPack.readChar(cpack)
	local name = LDataPack.readString(cpack)

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCChatCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCChatCmd_SendLoginBroadcast)
	LDataPack.writeChar(npack, id)
	LDataPack.writeChar(npack, job)
	LDataPack.writeString(npack, name)
	System.sendPacketToAllGameClient(npack, 0)


	local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Notice)
    LDataPack.writeByte(pack, Protocol.sNoticeCmd_NoticeLoginBroadCast)
	LDataPack.writeChar(pack, id)
	LDataPack.writeChar(pack, job)
	LDataPack.writeString(pack, name)
    System.broadcastData(pack)
end

function onSendLogin(sId, sType, cpack)
	local id = LDataPack.readChar(cpack)
	local job = LDataPack.readChar(cpack)
	local name = LDataPack.readString(cpack)

	local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Notice)
    LDataPack.writeByte(pack, Protocol.sNoticeCmd_NoticeLoginBroadCast)
	LDataPack.writeChar(pack, id)
	LDataPack.writeChar(pack, job)
	LDataPack.writeString(pack, name)
    System.broadcastData(pack)
end


function getNoticeConfigById(id)
	return NoticeConfig[id]
end

--Faça um anúncio
function broadCastNotice(id, ...)
	--print("TODO start broadCastNotice")
	local config = getNoticeConfigById(id)
	if (not config) then
		return
	end

	local content = string.format(config.content, unpack({...}))
	broadCastContent(config.type, content, config.link)
end

function broadCastCrossNotice(id, ...)
	--print("TODO start broadCastNotice")
	local config = getNoticeConfigById(id)
	if (not config) then
		return
	end

	local content = string.format(config.content, unpack({...}))

	addNoticeList(config.type, content, config.link)
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, Protocol.CMD_Notice)
	LDataPack.writeByte(npack, Protocol.sNoticeCmd_NoticeSync)
	LDataPack.writeShort(npack, tonumber(config.type))
	LDataPack.writeString(npack, content)
	LDataPack.writeByte(npack, 0) --旧公告
	LDataPack.writeChar(npack, config.link) --超链接id
	LDataPack.writeInt(npack, System.getNowTime())
	System.broadcastData(npack)
end

function s2cCrossNotice(actor,id, ...)
	local config = getNoticeConfigById(id)
	if (not config) then
		return
	end

	local content = string.format(config.content, unpack({...}))
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Notice, Protocol.sNoticeCmd_NoticeSync)
    if pack == nil then return end

	LDataPack.writeShort(pack, tonumber(config.type))
	LDataPack.writeString(pack, content)
	LDataPack.writeByte(pack, 0) --旧公告
	LDataPack.writeChar(pack, config.link) --超链接id
	LDataPack.writeInt(pack, System.getNowTime())
	LDataPack.flush(pack)
end

local function sendServerBroadcastContent(stype, content)
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCChatCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCChatCmd_SendServerBroadcast)
	LDataPack.writeShort(npack, stype)
	LDataPack.writeString(npack, content)
    System.sendPacketToAllGameClient(npack, 0)
end


--发公告，用类型
function broadCastContent(type, content, link)
	if System.isCommSrv() then
		addNoticeList(type, content, link)
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_Notice)
		LDataPack.writeByte(npack, Protocol.sNoticeCmd_NoticeSync)
		LDataPack.writeShort(npack, tonumber(type))
		LDataPack.writeString(npack, content)
		LDataPack.writeByte(npack, 0) --旧公告
		LDataPack.writeChar(npack, link) --超链接id
		LDataPack.writeInt(npack, System.getNowTime())
		System.broadcastData(npack)
	else

		sendServerBroadcastContent(type, content)
	end
end

--发跨服公告
function broadCastCrossContent(id, ...)
	--print("TODO start broadCastNotice")
	local config = getNoticeConfigById(id)
	if (not config) then
		return
	end

	local content = string.format(config.content, unpack({...}))
	
	if System.isCommSrv() then
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCChatCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCChatCmd_SendServerBroadcast)
		LDataPack.writeShort(npack, config.type)
		LDataPack.writeString(npack, content)
		System.sendPacketToAllGameClient(npack, csbase.getCrossServerId())
	else
		sendServerBroadcastContent(config.type, content)
	end
end

--发跨服和本服公告
function broadAllServerContent(type, content, link)
	if System.isCrossWarSrv() then
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_Notice)
		LDataPack.writeByte(npack, Protocol.sNoticeCmd_NoticeSync)
		LDataPack.writeShort(npack, type)
		LDataPack.writeString(npack, content)
		LDataPack.writeByte(npack, 0) --旧公告
		LDataPack.writeChar(npack, link or 0) --超链接id
		LDataPack.writeInt(npack, System.getNowTime())
		System.broadcastData(npack)
	end
	sendServerBroadcastContent(type, content)
end

local function onCrossBroadcast(sId, sType, pack)
	local stype = LDataPack.readShort(pack)
	local content = LDataPack.readString(pack)
	local link = LDataPack.readShort(pack)
	broadCastContent(stype, content, link)
end

_G.broadCastNotice = broadCastNotice
_G.broadCastContent = broadCastContent

--对副本内的人发提示
function fubenCastNotice(hfuben, id, ...)
	local config = getNoticeConfigById(id)
	if (not config) then return end
	local content = string.format(config.content, unpack({...}))

	local actors = Fuben.getAllActor(hfuben)
	if not actors then --hfuben出问题或副本内没人的情况
		utils.printInfo("Error notice not actors", id, hfuben)
		return
	end
	for i = 1,#actors do
		LActor.sendTipmsg(actors[i], content, ttScreenCenter)
	end
end

--对副本内的指定区域的人发提示
function fubenAreaCastNotice(hfuben, id, arg)
	local config = getNoticeConfigById(id)
	if (not config) then return end
	local content = config.content

	local actors = Fuben.getAllActor(hfuben)
	if not actors then --hfuben出问题或副本内没人的情况
		utils.printInfo("Error notice not actors", id, hfuben)
		return
	end
	for i = 1,#actors do
		if arg == Fuben.getBossIdInArea(actors[i]) then
			LActor.sendTipmsg(actors[i], content, ttScreenCenter)
		end
	end
end

--设置游戏内公告
function setAnnouncement(content, rewards)
	local data = getGlobalData()
	data.announcement = content
	data.rewards = rewards
	data.update = data.update + 1
end

--查看游戏公告内容
function c2sCheckAnnouncement(actor, packet)
	local data = getGlobalData()
	local var = getData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Notice, Protocol.sNoticeCmd_Announcement)
	if npack == nil then return end
	LDataPack.writeString(npack, data.announcement)
	LDataPack.writeByte(npack, var.update<data.update and 1 or 0) --是否领能领奖
	LDataPack.writeInt(npack, #data.rewards)
	for k, v in pairs(data.rewards) do
		LDataPack.writeInt(npack, v.type)
		LDataPack.writeInt(npack, v.id)
		LDataPack.writeInt(npack, v.count)
	end
	LDataPack.flush(npack)
end

--发送游戏公告是否有更新
function s2cCheckReward(actor)
	local data = getGlobalData()
	local var = getData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Notice, Protocol.sNoticeCmd_CheckReward)
	LDataPack.writeByte(npack, var.update<data.update and 1 or 0) --是否有更新
	LDataPack.flush(npack)
	if var.update<data.update and #data.rewards == 0 then --如果没奖励可领，直接设已更新
		var.update = data.update
	end
end

--领取游戏公告奖励
function c2sAnnouncementReward(actor, packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.announcement) then return end
	local data = getGlobalData()
	local var = getData(actor)
	if var.update>=data.update then return end
	var.update = data.update
	actoritem.addItems(actor, data.rewards, "announcement")
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Notice, Protocol.sNoticeCmd_AnnouncementReward)
	LDataPack.flush(npack)
end

actorevent.reg(aeUserLogin, onNoticeLogin)
netmsgdispatcher.reg(Protocol.CMD_Notice, Protocol.cNoticeCmd_SetTodayLook, onSetTodayLook)
netmsgdispatcher.reg(Protocol.CMD_Notice, Protocol.cNoticeCmd_Announcement, c2sCheckAnnouncement)
netmsgdispatcher.reg(Protocol.CMD_Notice, Protocol.cNoticeCmd_AnnouncementReward, c2sAnnouncementReward)

csmsgdispatcher.Reg(CrossSrvCmd.SCChatCmd, CrossSrvSubCmd.SCChatCmd_SendServerBroadcast, onCrossBroadcast)
csmsgdispatcher.Reg(CrossSrvCmd.SCChatCmd, CrossSrvSubCmd.SCChatCmd_UpdateLoginBroadcast, onUpdateLogin)
csmsgdispatcher.Reg(CrossSrvCmd.SCChatCmd, CrossSrvSubCmd.SCChatCmd_SendLoginBroadcast, onSendLogin)


local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.noticeAnnouncement = function (actor, args)
	local content = args[1]
	local id = tonumber(args[2])
	setAnnouncement(content, {{type=0, id=id, count=1234}})
end

gmCmdHandlers.announcementreward = function (actor, args)
	c2sAnnouncementReward(actor)
end

gmCmdHandlers.announcementcheck = function (actor, args)
	c2sCheckAnnouncement(actor)
end
