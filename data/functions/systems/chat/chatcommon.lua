module("chatcommon", package.seeall)

local LIMIT_CHAT_BEGIN = System.timeEncode(2021, 6, 30, 20, 0, 0)
local LIMIT_CHAT_END = System.timeEncode(2021, 7, 2, 10, 0, 0)
local LIMIT_CHAT_TIPS = '由于系统需要进行临时升级，因此需要限制聊天功能的使用'

function isLimitChat(actor)
	local now = System.getNowTime()
	if now >= LIMIT_CHAT_BEGIN and now < LIMIT_CHAT_END then
		LActor.sendTipmsg(actor, LIMIT_CHAT_TIPS, ttScreenCenter)
		return true
	end
	return false
end

function getActorVar(actor)
    local var = LActor.getStaticVar(actor) 
	if var == nil then return end
	if not var.chatCommon then var.chatCommon= {} end
	local chatCommon = var.chatCommon
	if not chatCommon.shutup then chatCommon.shutup = 0 end
	return chatCommon
end

local function chsize(char)
	if not char then
		print("not char")
		return 0
	elseif char >= 240 then
		return 4
	elseif char >= 224 then
		return 3
	elseif char >= 192 then
		return 2
	else
		return 1
	end
end

-- 计算utf8字符串字符数, 各种字符都按一个字符计算
-- 例如utf8len("1你好") => 3
function utf8len(str)
	local len = 0
	local currentIndex = 1
	while currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		currentIndex = currentIndex + chsize(char)
		len = len +1
	end
	return len
end

function getConfig(actor)
	local power = LActor.getActorData(actor).total_power
	local id = 0
	for i = 1,#(ChatLevelConfig) do 
		local conf = ChatLevelConfig[i]
		if power >= conf.power then 
			id = i
		else 
			break
		end
	end
	return ChatLevelConfig[id]
end

function makeTable(actor,msg,channel,target_actor_id)
	local tbl = {}
	local data = LActor.getActorData(actor)
	tbl.channel = channel
	tbl.actor_id = data.actor_id	
	tbl.actor_name = data.actor_name
	tbl.job = data.job
	tbl.sex = data.sex
	tbl.vip = data.vip
	tbl.vip_level = data.vip_level
	tbl.msg = msg
	tbl.target_actor_id = target_actor_id
	tbl.stime = System.getNowTime()
	return tbl
end

function makeTableByPack(npack)
	local tbl = {}	
	tbl.channel = LDataPack.readByte(npack)
	tbl.actor_id = LDataPack.readUInt(npack)
	tbl.actor_name = LDataPack.readString(npack)
	tbl.job = LDataPack.readByte(npack)
	tbl.sex = LDataPack.readByte(npack)
	tbl.vip = LDataPack.readByte(npack)
	tbl.vip_level = LDataPack.readByte(npack)
	tbl.target_actor_id = LDataPack.readUInt(npack)
	tbl.msg = LDataPack.readString(npack)
	tbl.stime = LDataPack.readInt(npack)
	return tbl
end

function makePack(npack,tbl)
	if tbl.channel == 0 then
		assert(false)
	end
	LDataPack.writeByte(npack,tbl.channel)
	LDataPack.writeUInt(npack,tbl.actor_id)
	LDataPack.writeString(npack,tbl.actor_name)
	LDataPack.writeByte(npack,tbl.job)
	LDataPack.writeByte(npack,tbl.sex)
	LDataPack.writeByte(npack,tbl.vip or 0)
	LDataPack.writeByte(npack,tbl.vip_level)
	LDataPack.writeUInt(npack,tbl.target_actor_id)
	LDataPack.writeString(npack,tbl.msg)
	LDataPack.writeUInt(npack,tbl.stime)
end

function sendSystemTips(actor,level,pos,tips)
	local actorLevel = LActor.getLevel(actor)
	if actorLevel < level then return end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Chat, Protocol.sChatCmd_Tipmsg)
	if npack == nil then return end
	LDataPack.writeInt(npack,level)
	LDataPack.writeInt(npack,pos)
	LDataPack.writeString(npack,tips)
	LDataPack.flush(npack)
end

--net
local function onChatMsg(actor,packet)
	print("enter onChatMsg")
	if isLimitChat(actor) then return end
	local channel = LDataPack.readByte(packet)
	local target_actor_id = LDataPack.readUInt(packet)
	local msg = LDataPack.readString(packet)
	local ret = false
	if channel == ciChannelAll then 
		ret = worldchat.sendChatMsg(actor,msg)
	elseif channel == ciChannelLianfu then
		ret = worldchat.sendLianFuChatMsg(actor,msg)
	elseif channel == ciChannelMap then
		ret = scenechat.sendChatMsg(actor, msg)
	elseif channel == ciChannelKuafu then
		ret = crosschat.sendChatMsg(actor, msg)
	end
	
	actorevent.onEvent(actor, aeChat, channel)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Chat, Protocol.sChatCmd_ChatMsgResult)
	if npack == nil then return end
	LDataPack.writeByte(npack,ret and 1 or 0)
	LDataPack.flush(npack)
	if ret then
		System.logChat(actor, channel, msg)
	end
end

local function shutup(actor, time)
	local var  = getActorVar(actor)
	var.shutup = System.getNowTime() + (time * 60)
end

function shutupById(actorid, time)
	local actor = LActor.getActorById(actorid)
	if actor then
		shutup(actor, time)
	else
		local npack = LDataPack.allocPacket()
		LDataPack.writeInt(npack, time)
		System.sendOffMsg(actorid, 0, OffMsgType_Shutup, npack)
	end
end

function OffMsgShutup(actor, offmsg)
	local time = LDataPack.readInt(offmsg)
	shutup(actor, time)
end

function releaseShutup(actor)
	local var  = getActorVar(actor)
	var.shutup = 0
end

function releaseShutupById(actorid)
	local actor = LActor.getActorById(actorid)
	if actor then
		releaseShutup(actor)
	else
		local npack = LDataPack.allocPacket()
		System.sendOffMsg(actorid, 0, OffMsgType_Shutup, npack)
	end
end

function OffMsgReleaseShutup(actor, offmsg)
	releaseShutup(actor)
end

local function getAServerName(actor)
	local serverid = LActor.getServerId(actor)
	return getServerNameBySId(serverid)
end

function getServerConfName()
	local serverid = System.getServerId()
	return getServerNameBySId(serverid)
end

function getServerNameBySId(serverid)
	return ServerNameConf[serverid] and "S"..ServerNameConf[serverid].name or ""
end

function gamestart()
	System.SetServerName(getServerNameBySId(System.getServerId()))
end

LActor.getServerName = getAServerName
_G.getServerNameBySId = getServerNameBySId


msgsystem.regHandle(OffMsgType_Shutup, OffMsgShutup)
msgsystem.regHandle(OffMsgType_ReleaseShutup, OffMsgReleaseShutup)

netmsgdispatcher.reg(Protocol.CMD_Chat, Protocol.cChatCmd_ChatMsg,onChatMsg)
