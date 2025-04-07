-- @version	1.0
-- @author	rancho
-- @date	2019-06-12 
-- @system  场景聊天
module("scenechat", package.seeall)

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor) 
	if var == nil then return nil end
	if not var.sceneChat then var.sceneChat= {} end
	local sceneChat = var.sceneChat
	if not sceneChat.chatCd then sceneChat.chatCd = System.getNowTime() end
	if not sceneChat.chatSize then sceneChat.chatSize = 0 end
	return sceneChat
end

function sendChatMsg(actor, msg)
    if actor == nil or msg == nil then  return end

	local fbid = LActor.getFubenId(actor)
	local fbconf = FubenConfig[fbid]
	if fbconf.mapTalk == 0 then return end

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

    local chatTable = chatcommon.makeTable(actor,msg,ciChannelMap,0)
    var.chatCd = System.getNowTime() + ChatConstConfig.chatCd
	-- var.chatSize = var.chatSize + 1

	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack,Protocol.CMD_Chat)
	LDataPack.writeByte(npack,Protocol.sChatCmd_ChatMsg)
	LDataPack.writeByte(npack,1)
	chatcommon.makePack(npack,chatTable)
	local fbhl = LActor.getFubenHandle(actor)
	Fuben.sendData(fbhl, npack)

	--头顶冒泡
	local prole = LActor.getRole(actor)
	local rolehl = LActor.getHandle(prole)
	local npack2 = LDataPack.allocPacket()
	if npack2 == nil then return end
	LDataPack.writeByte(npack2,Protocol.CMD_Base)
	LDataPack.writeByte(npack2,Protocol.sBaseCmd_EntityBubble)
	LDataPack.writeInt64(npack2,rolehl)
	LDataPack.writeString(npack2, msg)
	Fuben.sendData(fbhl, npack2)
end
