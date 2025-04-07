-- @version	1.0
-- @author	rancho
-- @date	2019-06-12 
-- @system  世界聊天
module("worldchat", package.seeall)

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor) 
	if var == nil then return end
	if not var.worldChat then var.worldChat= {} end
	local worldChat = var.worldChat
	if not worldChat.chatCd then worldChat.chatCd = System.getNowTime() end
	if not worldChat.chatSize then worldChat.chatSize = 0 end
	return worldChat
end

local function GetSystemVar()
    local var = System.getStaticChatVar()
	if var == nil then return end
    if not var.worldChat then var.worldChat= {} end
    local worldChat = var.worldChat
    if not worldChat.chatList then worldChat.chatList = {} end
    return worldChat
end

local function addOneChatToList(chatTable)
    if chatTable == nil then return end
    local var = GetSystemVar()
    local chatList = var.chatList
    table.insert(chatList, chatTable)
    while #chatList > ChatConstConfig.saveChatListSize do
        table.remove(chatList, 1)
    end
end

local function sendChatList(actor)
    local var = GetSystemVar()
    local chatList = var.chatList
    if #chatList <= 0 then return end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Chat, Protocol.sChatCmd_ChatMsg)
    if npack == nil then return end
    LDataPack.writeByte(npack, #chatList)
    for _, chatTable in ipairs(chatList) do
        chatcommon.makePack(npack,chatTable)
    end
	LDataPack.flush(npack)
end

function sendChatMsg(actor, msg)
    if actor == nil or msg == nil then return end

    local comvar = chatcommon.getActorVar(actor)
    if comvar.shutup > System.getNowTime() then return end

	msg = System.filterText(msg)
    if chatcommon.utf8len(msg) > ChatConstConfig.chatLen then return end

    local var = getActorVar(actor) 
	if var.chatCd > System.getNowTime() then return end

	local conf = chatcommon.getConfig(actor) 
	if conf == nil then return end
	if var.chatSize >= conf.chatSize then 
		chatcommon.sendSystemTips(actor,1,2,ScriptTips.chatSizeLimit)
		return
    end

    local chatTable = chatcommon.makeTable(actor,msg,ciChannelAll,0)
	addOneChatToList(chatTable)
    var.chatCd = System.getNowTime() + ChatConstConfig.chatCd
	var.chatSize = var.chatSize + 1
    
	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack,Protocol.CMD_Chat)
	LDataPack.writeByte(npack,Protocol.sChatCmd_ChatMsg)
	LDataPack.writeByte(npack,1)
	chatcommon.makePack(npack,chatTable)
	System.broadcastData(npack)
	return true
end

function sendLianFuChatMsg(actor, msg)
    if actor == nil or msg == nil then return end

    local comvar = chatcommon.getActorVar(actor)
    if comvar.shutup > System.getNowTime() then return end

    msg = System.filterText(msg)
    if chatcommon.utf8len(msg) > ChatConstConfig.chatLen then return end

    local var = getActorVar(actor) 
    if var.chatCd > System.getNowTime() then return end

    local conf = chatcommon.getConfig(actor) 
    if conf == nil then return end
    if var.chatSize >= conf.chatSize then 
        chatcommon.sendSystemTips(actor,1,2,ScriptTips.chatSizeLimit)
        return
    end

    local chatTable = chatcommon.makeTable(actor,msg,ciChannelLianfu,0)
    addOneChatToList(chatTable)
    var.chatCd = System.getNowTime() + ChatConstConfig.chatCd
    var.chatSize = var.chatSize + 1
    
    local npack = LDataPack.allocPacket()
    if npack == nil then return end
    LDataPack.writeByte(npack,Protocol.CMD_Chat)
    LDataPack.writeByte(npack,Protocol.sChatCmd_ChatMsg)
    LDataPack.writeByte(npack,1)
    chatcommon.makePack(npack,chatTable)
    System.broadcastData(npack)

    local fbhl = LActor.getFubenHandle(actor)
    local prole = LActor.getRole(actor)
    local rolehl = LActor.getHandle(prole)
    local npack2 = LDataPack.allocPacket()
    if npack2 == nil then return end
    LDataPack.writeByte(npack2,Protocol.CMD_Base)
    LDataPack.writeByte(npack2,Protocol.sBaseCmd_EntityBubble)
    LDataPack.writeInt64(npack2,rolehl)
    LDataPack.writeString(npack2, msg)
    Fuben.sendData(fbhl, npack2)
    return true
end

local function onLogin(actor) 
    sendChatList(actor)
end

local function onNewDay(actor)
    local var = getActorVar(actor)
    var.chatSize = 0
end

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)
