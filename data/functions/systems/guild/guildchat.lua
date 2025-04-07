-- 公会聊天

module("guildchat", package.seeall)

local LActor = LActor
local LDataPack = LDataPack
local systemId = Protocol.CMD_Guild
--local common = guildcommon --需要保证加载顺序
local global_chat_cd = 3 -- 公会聊天CD(秒)
local global_chat_char_len = 160 -- 文字最大长度

-- 
function handleChat(actor, packet)
	if chatcommon.isLimitChat(actor) then return end
	local content = LDataPack.readString(packet)
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then print("guild is nil") return end

	local nowTime = System.getNowTime()
	local actorVar = guildcommon.getActorVar(actor)

	if actorVar.lastchat ~= nil and (nowTime - actorVar.lastchat < global_chat_cd) then
		print("guild chat cd : "..actorVar.lastchat)
		return 
	end

	if System.getStrLenUtf8(content) > global_chat_char_len then
		print("max chat len, actorId : "..LActor.getActorId(actor))
		return
	end
	content = System.filterText(content)
	local actorData = LActor.getActorData(actor)
	if actorData == nil then return end
	actorVar.lastchat = nowTime
	if System.isBattleSrv() then
		local actorId = LActor.getActorId(actor)
		local pos = LActor.getGuildPos(actor)
		local guild = LGuild.getGuildById(guildId)
		LGuild.addChatLog(guild, enGuildChatChat, content, actorId, actorData.actor_name, actorData.job, actorData.sex, actorData.vip, actorData.vip_level, pos)

		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendGuildChat)
		LDataPack.writeByte(npack, enGuildChatChat)
		LDataPack.writeInt(npack, guildId)	
		LDataPack.writeString(npack, content)
		LDataPack.writeInt(npack, actorId)
		LDataPack.writeString(npack, actorData.actor_name)
		LDataPack.writeByte(npack, actorData.job)
		LDataPack.writeByte(npack, actorData.sex)
		LDataPack.writeByte(npack, actorData.vip)
		LDataPack.writeByte(npack, actorData.vip_level)
		LDataPack.writeByte(npack, pos)
		System.sendPacketToAllGameClient(npack, 0)

		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, systemId)
		LDataPack.writeByte(npack, Protocol.sGuildCmd_Chat)
		LDataPack.writeByte(npack, enGuildChatChat)
		LDataPack.writeString(npack, content)
		LDataPack.writeInt(npack, actorId)
		LDataPack.writeString(npack, actorData.actor_name)
		LDataPack.writeByte(npack, actorData.job)
		LDataPack.writeByte(npack, actorData.sex)
		LDataPack.writeByte(npack, actorData.vip)
		LDataPack.writeByte(npack, actorData.vip_level)
		LDataPack.writeByte(npack, pos)
		LDataPack.writeInt(npack, System.getNowTime())
	
		LGuild.broadcastData(guildId, npack)
	else
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetGuildChat)
		LDataPack.writeByte(npack, enGuildChatChat)
		LDataPack.writeInt(npack, guildId)	
		LDataPack.writeString(npack, content)
		LDataPack.writeInt(npack, LActor.getActorId(actor))
		LDataPack.writeString(npack, actorData.actor_name)
		LDataPack.writeByte(npack, actorData.job)
		LDataPack.writeByte(npack, actorData.sex)
		LDataPack.writeByte(npack, actorData.vip)
		LDataPack.writeByte(npack, actorData.vip_level)
		LDataPack.writeByte(npack, LActor.getGuildPos(actor))
		System.sendPacketToAllGameClient(npack, 0)
	end
	-- LActor.log(actor, "guildchat.handleChat", "make1", actorVar.lastchat)
end

local function onGetGuildChat(sId, sType, cpack)
	local type = LDataPack.readByte(cpack)
	local guildId = LDataPack.readInt(cpack)
	local guild = LGuild.getGuildById(guildId)
	if not guild then 
		return
	end	
	local content = LDataPack.readString(cpack)	
	
	local actorId = 0
	local name = ""
	local job = 0
	local sex = 0
	local vip = 0
	local svip = 0
	local pos = 0

	if type == enGuildChatChat then
		actorId = LDataPack.readInt(cpack)
		name = LDataPack.readString(cpack)
		job = LDataPack.readByte(cpack)
		sex = LDataPack.readByte(cpack)
		vip = LDataPack.readByte(cpack)
		svip = LDataPack.readByte(cpack)
		pos = LDataPack.readByte(cpack)
	end
	LGuild.addChatLog(guild, type, content, actorId, name, job, sex, vip, svip, pos)

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendGuildChat)
	LDataPack.writeByte(npack, type)
	LDataPack.writeInt(npack, guildId)	
	LDataPack.writeString(npack, content)
	if type == enGuildChatChat then
		LDataPack.writeInt(npack, actorId)
		LDataPack.writeString(npack, name)
		LDataPack.writeByte(npack, job)
		LDataPack.writeByte(npack, sex)
		LDataPack.writeByte(npack, vip)
		LDataPack.writeByte(npack, svip)
		LDataPack.writeByte(npack, pos)
	end
	System.sendPacketToAllGameClient(npack, 0)
end

local function onSendGuildChat(sId, sType, cpack)
	local type = LDataPack.readByte(cpack)
	local guildId = LDataPack.readInt(cpack)
	
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, systemId)
	LDataPack.writeByte(npack, Protocol.sGuildCmd_Chat)
	LDataPack.writeByte(npack, type)
	local content = LDataPack.readString(cpack)
	LDataPack.writeString(npack, content)
	if type == enGuildChatChat then
		LDataPack.writeInt(npack, LDataPack.readInt(cpack))
		LDataPack.writeString(npack, LDataPack.readString(cpack))
		LDataPack.writeByte(npack, LDataPack.readByte(cpack))
		LDataPack.writeByte(npack, LDataPack.readByte(cpack))
		LDataPack.writeByte(npack, LDataPack.readByte(cpack))
		LDataPack.writeByte(npack, LDataPack.readByte(cpack))
		LDataPack.writeByte(npack, LDataPack.readByte(cpack))		
	end
	LDataPack.writeInt(npack, System.getNowTime())
	LGuild.broadcastData(guildId, npack)
end

-- 获取聊天记录
function handleChatLog(actor, packet)
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then 
		return 
	end
	if System.isBattleSrv() then
		local guild = LGuild.getGuildById(guildId)
		local npack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_ChatLog)
		LGuild.writeChatLog(guild, npack)	
		LDataPack.flush(npack)
	else
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetGuildChatLog)
		LDataPack.writeInt(npack, guildId)
		LDataPack.writeInt(npack, LActor.getActorId(actor))
		System.sendPacketToAllGameClient(npack, 0)
	end
end

local function onGetGuildChatLog(sId, sType, cpack)
	local guildId = LDataPack.readInt(cpack)
	local guild = LGuild.getGuildById(guildId)
	if not guild then
		return
	end
	local actorId = LDataPack.readInt(cpack)
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendGuildChatLog)
	LDataPack.writeInt(npack, actorId)
	LGuild.writeChatLog(guild, npack)
	System.sendPacketToAllGameClient(npack, sId)
end

local function onSendGuildChatLog(sId, sType, cpack)
	local actorId = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorId)
	if not actor then
		return
	end
	local npack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_ChatLog)
	local count = LDataPack.readInt(cpack)
	LDataPack.writeInt(npack, count)
	for i=1, count do
		local logtype = LDataPack.readByte(cpack)
		LDataPack.writeByte(npack, logtype)
		LDataPack.writeString(npack, LDataPack.readString(cpack))
		if logtype == enGuildChatChat then
			LDataPack.writeInt(npack, LDataPack.readInt(cpack))
			LDataPack.writeString(npack, LDataPack.readString(cpack))
			LDataPack.writeByte(npack, LDataPack.readByte(cpack))
			LDataPack.writeByte(npack, LDataPack.readByte(cpack))
			LDataPack.writeByte(npack, LDataPack.readByte(cpack))
			LDataPack.writeByte(npack, LDataPack.readByte(cpack))
			LDataPack.writeByte(npack, LDataPack.readByte(cpack))
		end
		LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	end

	LDataPack.flush(npack)
end

-- 发送帮派公告
function sendNotice(guild, content, type)
	if not System.isBattleSrv() then return end
	local guildId = LGuild.getGuildId(guild)
	LGuild.addChatLog(guild, type or enGuildChatSystem, content)
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendGuildChat)
	LDataPack.writeByte(npack, type or enGuildChatSystem)
	LDataPack.writeInt(npack, guildId)	
	LDataPack.writeString(npack, content)
	System.sendPacketToAllGameClient(npack, 0)
end

function sendAndBroNotice(guild, content, type)
	if not System.isBattleSrv() then return end
	local guildId = LGuild.getGuildId(guild)
	LGuild.addChatLog(guild, type or enGuildChatSystem, content)

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, systemId)
	LDataPack.writeByte(npack, Protocol.sGuildCmd_Chat)
	LDataPack.writeByte(npack, type or enGuildChatSystem)
	LDataPack.writeString(npack, content)
	LDataPack.writeInt(npack, 0)
	LDataPack.writeString(npack, "")
	LDataPack.writeByte(npack, 0)
	LDataPack.writeByte(npack, 0)
	LDataPack.writeByte(npack, 0)
	LDataPack.writeByte(npack, 0)
	LDataPack.writeByte(npack, 0)
	LDataPack.writeInt(npack, System.getNowTime())
	LGuild.broadcastData(guildId, npack)

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendGuildChat)
	LDataPack.writeByte(npack, type or enGuildChatSystem)
	LDataPack.writeInt(npack, guildId)	
	LDataPack.writeString(npack, content)
	System.sendPacketToAllGameClient(npack, 0)
end

function onLogin(actor)
	-- local guild = LActor.getGuildPtr(actor)
	-- if guild == nil then return end
end

actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_Chat, handleChat)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ChatLog, handleChatLog)

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetGuildChat, onGetGuildChat)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendGuildChat, onSendGuildChat)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetGuildChatLog, onGetGuildChatLog)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendGuildChatLog, onSendGuildChatLog)