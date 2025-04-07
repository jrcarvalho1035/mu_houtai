-- @version	1.0
-- @author	rancho
-- @date	2019-06-11 
-- @system  跨服聊天
module("crosschat", package.seeall)

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor) 
	if var == nil then return nil end
	if not var.crossChat then var.crossChat = {} end
	local crossChat = var.crossChat
	if not crossChat.chatCd then crossChat.chatCd = System.getNowTime() end
	if not crossChat.chatSize then crossChat.chatSize = 0 end
	return crossChat
end

local function GetSystemVar()
    local var = System.getStaticChatVar()
    if not var then return end
    if not var.crossChat then var.crossChat = {} end
    local crossChat = var.crossChat
    if crossChat.chatList == nil then crossChat.chatList = {} end
    return crossChat
end

local function getSystemDynamicVar()
    local var = System.getDyanmicVar()
    if not var then return end
    if not var.crossChat then var.crossChat = {} end
    local crossChat = var.crossChat
    if not crossChat.chatList then crossChat.chatList = {} end
    return crossChat
end

local function clearSystemDynamicVar()
    local var = System.getDyanmicVar()
    if not var then return end
    var.crossChat = nil
end

local function broadcastChatMsg(tbl)
    local actors = System.getOnlineActorList()
    if actors == nil then return end
    for _, actor in ipairs(actors) do
        if actorexp.checkLevelCondition(actor, actorexp.LimitTp.cschat) then
            local npack = LDataPack.allocPacket(actor, Protocol.CMD_Chat, Protocol.sChatCmd_ChatMsg)
            if npack == nil then break end
            LDataPack.writeByte(npack, 1)
            chatcommon.makePack(npack,tbl)
            LDataPack.flush(npack)
        end
    end
end

local function sendDynamicChatList(actor)
    local var = getSystemDynamicVar()
    local chatList = var.chatList
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Chat, Protocol.sChatCmd_ChatMsg)
    if npack == nil then return end
    LDataPack.writeByte(npack, #chatList)
    for _,tbl in ipairs(chatList) do
        chatcommon.makePack(npack,tbl)
    end
    LDataPack.flush(npack)
end

local function sendBattleChatList(actor)
    local var = GetSystemVar()
    local chatList = var.chatList
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Chat, Protocol.sChatCmd_ChatMsg)
    if npack == nil then return end
    LDataPack.writeByte(npack, #chatList)
    for _,tbl in ipairs(chatList) do
        chatcommon.makePack(npack, tbl)
    end
    LDataPack.flush(npack)
end


local function broadcastDynamicChatList()
    local actors = System.getOnlineActorList()
    if actors == nil then return end
    for _, actor in ipairs(actors) do
        if actorexp.checkLevelCondition(actor, actorexp.LimitTp.cschat) then
            sendDynamicChatList(actor)
        end
    end
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

local function addOneChatToDynamicList(tbl)
    if tbl == nil then return end
    local var = getSystemDynamicVar()
    local chatList = var.chatList
    table.insert( chatList, tbl)
    if #chatList > ChatConstConfig.saveChatListSize then
        table.remove( chatList, 1)
    end
end

--普通服发送聊天
function sendChatMsg(actor, msg)
    local comvar = chatcommon.getActorVar(actor)
    if comvar.shutup > System.getNowTime() then return end

	msg = System.filterText(msg)
    if chatcommon.utf8len(msg) > ChatConstConfig.chatLen then return end
    --是否能跨服聊天
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.cschat) then return end
    
    if System.isBattleSrv() then --跨服内聊天
        local chatTable = chatcommon.makeTable(actor,msg,ciChannelKuafu,0)
        addOneChatToList(chatTable)
        addChatMsg(chatTable)
        broadcastChatMsg(chatTable)
        return 
    end
    if actor == nil or msg == nil then return end

    

    local var = getActorVar(actor) 
	if var.chatCd > System.getNowTime() then return end

	local conf = chatcommon.getConfig(actor) 
	if conf == nil then return end
	if var.chatSize >= conf.chatSize then 
		chatcommon.sendSystemTips(actor,1,2,ScriptTips.chatSizeLimit)
		return
    end

    local chatTable = chatcommon.makeTable(actor,msg,ciChannelKuafu,0)
    var.chatCd = System.getNowTime() + ChatConstConfig.chatCd
    var.chatSize = var.chatSize + 1
    
    local tbl = chatcommon.makeTable(actor, msg, ciChannelKuafu, 0)
    local npack = LDataPack.allocPacket()
    if npack == nil then return end
    LDataPack.writeByte(npack, CrossSrvCmd.SCChatCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCChatCmd_SendChat)
    chatcommon.makePack(npack, chatTable)
    System.sendPacketToAllGameClient(npack, 0)

    return true
end

--跨服收到聊天
function onSendChatMsg_c2b(sId, sType, dp)
    if not System.isBattleSrv() then return end
    local tbl = chatcommon.makeTableByPack(dp)
    addOneChatToList(tbl)
    addChatMsg(tbl)

    -- System.logCrossChat(tbl.actor_id, tbl.channe, tbl.account_name,
    --     tbl.actor_name, tbl.msg, tostring(tbl.serverid))
end

--跨服发送增加单条聊天
function addChatMsg(tbl)
    local npack = LDataPack.allocPacket()
    if npack == nil then return end
    LDataPack.writeByte(npack, CrossSrvCmd.SCChatCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCChatCmd_UpdateChat)
    chatcommon.makePack(npack, tbl)
    System.sendPacketToAllGameClient(npack, 0)
end

--普通服收到增加单条聊天
function onAddChatMsg_b2c(sId, sType, dp)
    if not System.isCommSrv() then return end
    local tbl = chatcommon.makeTableByPack(dp)
    addOneChatToDynamicList(tbl)
    broadcastChatMsg(tbl)
end

--跨服同步聊天记录到普通服
function SyncAllChatMsg(sId)
    if not System.isBattleSrv() then return end
    local var = GetSystemVar()
    if not var then return end

    local chatList = var.chatList
    local chatCount = #chatList
    if chatCount <= 0 then return end

    local npack = LDataPack.allocPacket()
    if npack == nil then return end
    LDataPack.writeByte(npack, CrossSrvCmd.SCChatCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCChatCmd_SyncChatInfo)
    LDataPack.writeByte(npack, #chatList)
    for _,chatTable in ipairs(chatList) do
        chatcommon.makePack(npack,chatTable)
    end
    System.sendPacketToAllGameClient(npack, sId)
end

--普通服收到跨服同步聊天记录
function  onSyncAllChatMsg_b2c(sId, sType, dp)
    if not System.isCommSrv() then return end
    clearSystemDynamicVar()
    local count = LDataPack.readByte(dp)
    for i = 1, count do
        local chatTable = chatcommon.makeTableByPack(dp)
        addOneChatToDynamicList(chatTable)
    end
    broadcastDynamicChatList()
end


--连接时跨服同步聊天记录到普通服
function onConnected(sId, sType)
    if not System.isBattleSrv() then return end
    if ServerType_Common ~= sType then return end
    SyncAllChatMsg(sId)
end

local function onLogin(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.cschat) then return end
    if System.isBattleSrv() then
        sendBattleChatList(actor)
    else
        sendDynamicChatList(actor)
    end
end

actorevent.reg(aeUserLogin, onLogin)

csmsgdispatcher.Reg(CrossSrvCmd.SCChatCmd, CrossSrvSubCmd.SCChatCmd_SyncChatInfo, onSyncAllChatMsg_b2c)
csmsgdispatcher.Reg(CrossSrvCmd.SCChatCmd, CrossSrvSubCmd.SCChatCmd_UpdateChat, onAddChatMsg_b2c)
csmsgdispatcher.Reg(CrossSrvCmd.SCChatCmd, CrossSrvSubCmd.SCChatCmd_SendChat, onSendChatMsg_c2b)

csbase.RegConnected(onConnected)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.clearcschat = function ( actor, args )
    local var = LActor.getStaticVar(actor) 
    if var == nil then return nil end
    var.crossChat = nil
    return true
end
