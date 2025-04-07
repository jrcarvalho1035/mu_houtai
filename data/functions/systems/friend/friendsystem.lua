--好友系统
--@rancho 20170710

module("friendsystem", package.seeall)

--系统是否开启
function isFriendSystemOpen(actor)
	return true
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
local function utf8len(str)
	local len = 0
	local currentIndex = 1
	while currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		currentIndex = currentIndex + chsize(char)
		len = len +1
	end
	return len
end

local function SendList(actor, dataType)
	if not (dataType > EFriendDataType.EUndefine and dataType < EFriendDataType.EMax - 1) then
		return
	end

	local aActorId = LActor.getActorId(actor)
	local tData = friendmgr.GetDataByType(aActorId, dataType)
	if not tData then 
		return
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, Protocol.sFriendCmd_GetList)
	if npack == nil then return end

	LDataPack.writeByte(npack, dataType)
	LDataPack.writeShort(npack,tData.len)
	for bActorId, bInfo in pairs(tData.list) do
		local bActor = LActor.getActorById(bActorId)
		local basicData = nil
		local online = 0
		if bActor then
			online = 1
			basicData = LActor.getActorData(bActor)
		else
			online = 0
			basicData = offlinedatamgr.GetDataByOffLineDataType(bActorId, EOffLineDataType.EBasic)
		end
		if basicData == nil then
			LDataPack.writeInt(npack, bActorId)
			LDataPack.writeString(npack, "")
			LDataPack.writeByte(npack, 0)
			LDataPack.writeDouble(npack, 0)
			LDataPack.writeShort(npack, 0)
			LDataPack.writeShort(npack, 0)
			LDataPack.writeByte(npack, 0)
			LDataPack.writeInt(npack, -1)
			LDataPack.writeString(npack, "")
		else
			LDataPack.writeInt(npack, basicData.actor_id)
			LDataPack.writeString(npack, basicData.actor_name)
			LDataPack.writeByte(npack, basicData.job or 0)
			LDataPack.writeDouble(npack, basicData.total_power)
			LDataPack.writeShort(npack, basicData.level)
			LDataPack.writeShort(npack, basicData.vip_level)
			LDataPack.writeByte(npack, online)

			if dataType == EFriendDataType.EAttention then
				--最后上线时间
				LDataPack.writeInt(npack, basicData.last_online_time or -1)
				LDataPack.writeString(npack, "")
			elseif dataType == EFriendDataType.EChat then
				--最后联系时间
				LDataPack.writeInt(npack, bInfo.lastContact or basicData.last_online_time or -1)
				LDataPack.writeString(npack, bInfo.contentList and bInfo.contentList[#bInfo.contentList][3] or "")
			elseif dataType == EFriendDataType.EBlack then
				LDataPack.writeInt(npack, -1)
				LDataPack.writeString(npack, "")
			end		
		end
	end
	LDataPack.flush(npack)
end

local function SendAddListMember(actor, dataType, bActorId)
	if not (dataType > EFriendDataType.EUndefine and dataType < EFriendDataType.EMax - 1) then
		return
	end
	local aActorId = LActor.getActorId(actor)
	local bInfo = friendmgr.GetBInfo(aActorId, dataType, bActorId)
	if not bInfo then 
		return
	end

	local bActor = LActor.getActorById(bActorId)
	local basicData = nil
	local online = 0
	if bActor then
		online = 1
		basicData = LActor.getActorData(bActor)
	else
		online = 0
		basicData = offlinedatamgr.GetDataByOffLineDataType(bActorId, EOffLineDataType.EBasic)
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, Protocol.sFriendCmd_AddListMember)
	if npack == nil then return end

	LDataPack.writeByte(npack, dataType)
	if basicData == nil then
		LDataPack.writeInt(npack, bActorId)
		LDataPack.writeString(npack, "")
		LDataPack.writeByte(npack, 0)
		LDataPack.writeDouble(npack, 0)
		LDataPack.writeShort(npack, 0)
		LDataPack.writeShort(npack, 0)
		LDataPack.writeByte(npack, 0)
		LDataPack.writeInt(npack, -1)
		LDataPack.writeString(npack, "")
	else
		LDataPack.writeInt(npack, basicData.actor_id)
		LDataPack.writeString(npack, basicData.actor_name)
		LDataPack.writeByte(npack, basicData.job or 0)
		LDataPack.writeDouble(npack, basicData.total_power)
		LDataPack.writeShort(npack, basicData.level)
		LDataPack.writeShort(npack, basicData.vip_level)
		LDataPack.writeByte(npack, online)

		if  dataType == EFriendDataType.EAttention then
			--最后上线时间
			LDataPack.writeInt(npack,basicData.last_online_time or -1)
			LDataPack.writeString(npack, "")
		elseif dataType == EFriendDataType.EChat then
			--最后联系时间
			LDataPack.writeInt(npack,bInfo.lastContact or basicData.last_online_time or -1)
			LDataPack.writeString(npack, bInfo.contentList and bInfo.contentList[#bInfo.contentList][3] or "")
		elseif dataType == EFriendDataType.EBlack then
			LDataPack.writeInt(npack, -1)
			LDataPack.writeString(npack, "")
		end
	end
	LDataPack.flush(npack)
end

local function SendDelListMember(actor, dataType, bActorId)
	if not (dataType > EFriendDataType.EUndefine and dataType < EFriendDataType.EMax - 1) then
		return
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, Protocol.sFriendCmd_DelListMember)
	if npack == nil then return false end
	LDataPack.writeByte(npack, dataType)
	LDataPack.writeInt(npack, bActorId)
	LDataPack.flush(npack)
end

local function SendChatContent(actor, chatInfo)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, Protocol.sFriendCmd_Chat)
	if npack == nil then return false end
	LDataPack.writeInt(npack, chatInfo[1])
	LDataPack.writeInt(npack, chatInfo[2])
	LDataPack.writeString(npack, chatInfo[3])
	LDataPack.flush(npack)
end

local function SendHistoryChat(actor, bActorId)
	local aActorId = LActor.getActorId(actor)
	
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, Protocol.sFriendCmd_GetHistoryChat)
	if npack == nil then return  end
	
	LDataPack.writeInt(npack, bActorId)
	local bInfo = friendmgr.GetBInfo(aActorId, EFriendDataType.EChat, bActorId)
	if bInfo == nil or bInfo.contentList == nil then
		LDataPack.writeShort(npack, 0) 
	else
		local contentList = bInfo.contentList
	 	LDataPack.writeShort(npack, #contentList)
		for i = 1, #contentList do
			local chatInfo = contentList[i]
			LDataPack.writeInt(npack, chatInfo[1])
			LDataPack.writeInt(npack, chatInfo[2])
			LDataPack.writeString(npack, chatInfo[3])
		end
	end
	LDataPack.flush(npack)
end

local function SendRefuseStranger(actor)
	local actorId = LActor.getActorId(actor)
	local EMiscData = friendmgr.GetMiscData(actorId)
	if not EMiscData  then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, Protocol.sFriendCmd_RefuseStranger)
	if npack == nil then return false end
	LDataPack.writeByte(npack, EMiscData.refuseStranger)
	LDataPack.flush(npack)
end

--获取列表信息
function GetList(actor, pack)
	local dataType = LDataPack.readInt(pack) 
	SendList(actor, dataType)
end

--关注某个玩家
function AddAttentionHandle(actor, pack)
	local bActorId = LDataPack.readInt(pack)
	local bActorName = LDataPack.readString(pack)

	if bActorId == 0 then
		--根据角色名字查id
		bActorId = LActor.getActorIdByName(bActorName)
		if bActorId == 0 then
			LActor.sendTipmsg(actor, ScriptTips.friend12)
			return
		end
	end

	--加自己为好友
	local aActorId = LActor.getActorId(actor)
	if aActorId == bActorId then return end
	
	--是否已经关注
	if friendmgr.GetBInfo(aActorId, EFriendDataType.EAttention, bActorId) ~= nil then
		LActor.sendTipmsg(actor, ScriptTips.friend02)
		return
	end

	--关注是否达到上限
	if friendmgr.IsListFull(aActorId, EFriendDataType.EAttention) then
		LActor.sendTipmsg(actor, ScriptTips.friend03)
		return
	end

	--我在对方黑名单中
	if friendmgr.GetBInfo(bActorId, EFriendDataType.EBlack, aActorId) ~= nil then
		LActor.sendTipmsg(actor, ScriptTips.friend01)
		return
	end

	--对方在我黑名单中
	if friendmgr.GetBInfo(aActorId, EFriendDataType.EBlack, bActorId) ~= nil then
		LActor.sendTipmsg(actor, ScriptTips.friend13)
		return
	end		

	--更新我的关注列表
	friendmgr.AddBInfo(aActorId, EFriendDataType.EAttention, bActorId)
	friendmgr.SetDirty(aActorId, true)

	--数据下发给玩家
	SendAddListMember(actor, EFriendDataType.EAttention, bActorId)
	
	LActor.sendTipmsg(actor, ScriptTips.friend04)
end

--取消关注某个玩家
function DelAttentionHandle(actor, pack)
	local bActorId = LDataPack.readInt(pack)
	local bActorName = LDataPack.readString(pack)

	if bActorId == 0 then
		--根据角色名字查id
		bActorId = LActor.getActorIdByName(bActorName)
		if bActorId == 0 then
			LActor.sendTipmsg(actor, ScriptTips.friend12)
			return
		end
	end

	--取消关注自己
	local aActorId = LActor.getActorId(actor)
	if aActorId == bActorId then return end
	
	--是否已经关注
	if friendmgr.GetBInfo(aActorId, EFriendDataType.EAttention, bActorId) == nil then
		return
	end

	--更新我的关注列表
	friendmgr.DelBInfo(aActorId, EFriendDataType.EAttention, bActorId)
	friendmgr.SetDirty(aActorId, true)

	--数据下发给玩家
	SendDelListMember(actor, EFriendDataType.EAttention, bActorId)

	LActor.sendTipmsg(actor, ScriptTips.friend05)
end

--拉黑某个玩家
function AddBlackHandle(actor, pack)
	local bActorId = LDataPack.readInt(pack)
	local bActorName = LDataPack.readString(pack)

	if bActorId == 0 then
		--根据角色名字查id
		bActorId = LActor.getActorIdByName(bActorName)
		if bActorId == 0 then
			LActor.sendTipmsg(actor, ScriptTips.friend12)
			return
		end
	end

	--拉黑自己
	local aActorId = LActor.getActorId(actor)
	if aActorId == bActorId then return end
	
	--是否已经拉黑
	if friendmgr.GetBInfo(aActorId, EFriendDataType.EBlack, bActorId) ~= nil then
		LActor.sendTipmsg(actor, ScriptTips.friend06)
		return
	end

	--拉黑是否达到上限
	if friendmgr.IsListFull(aActorId, EFriendDataType.EBlack) then
		LActor.sendTipmsg(actor, ScriptTips.friend07)
		return
	end

	if friendmgr.GetBInfo(aActorId, EFriendDataType.EAttention, bActorId) ~= nil then
		--更新我的关注列表
		friendmgr.DelBInfo(aActorId, EFriendDataType.EAttention, bActorId)
		--数据下发给玩家
		SendDelListMember(actor, EFriendDataType.EAttention, bActorId)
	end

	if friendmgr.GetBInfo(aActorId, EFriendDataType.EChat, bActorId) ~= nil then
		--删除聊天历史信息
		friendmgr.DelBInfo(aActorId, EFriendDataType.EChat, bActorId)
		SendDelListMember(actor, EFriendDataType.EChat, bActorId)
	end

	--更新我的拉黑列表
	friendmgr.AddBInfo(aActorId, EFriendDataType.EBlack, bActorId)

	--数据下发给玩家
	SendAddListMember(actor, EFriendDataType.EBlack, bActorId)


	friendmgr.SetDirty(aActorId, true)

	LActor.sendTipmsg(actor, ScriptTips.friend08)
end

--取消拉黑某个玩家
function DelBlackHandle(actor, pack)
	local bActorId = LDataPack.readInt(pack)
	local bActorName = LDataPack.readString(pack)

	if bActorId == 0 then
		--根据角色名字查id
		bActorId = LActor.getActorIdByName(bActorName)
		if bActorId == 0 then
			LActor.sendTipmsg(actor, ScriptTips.friend12)
			return
		end
	end

	--取消拉黑自己
	local aActorId = LActor.getActorId(actor)
	if aActorId == bActorId then return end
	
	--是否已经拉黑
	if friendmgr.GetBInfo(aActorId, EFriendDataType.EBlack, bActorId) == nil then
		return
	end

	--更新我的拉黑列表
	friendmgr.DelBInfo(aActorId, EFriendDataType.EBlack, bActorId)
	friendmgr.SetDirty(aActorId, true)

	--数据下发给玩家
	SendDelListMember(actor, EFriendDataType.EBlack, bActorId)

	LActor.sendTipmsg(actor, ScriptTips.friend09)
end

--私聊某个玩家
function ChatHandle(actor, pack)
	local bActorId = LDataPack.readInt(pack)
	local content = LDataPack.readString(pack)

	if bActorId == 0 then return end
	if #content == 0 then return end

	--说给自己
	local aActorId = LActor.getActorId(actor)
	if aActorId == bActorId then return end

	--聊天长度限制
	if utf8len(content) > FriendLimit.contentLen then
		return
	end

	--我在对方黑名单中
	if friendmgr.GetBInfo(bActorId, EFriendDataType.EBlack, aActorId) ~= nil then
		LActor.sendTipmsg(actor, ScriptTips.friend10, ttScreenCenter)
		return
	end

	--屏蔽陌生人
	local EMiscData = friendmgr.GetMiscData(bActorId)
	if EMiscData.refuseStranger == 1 then
		if friendmgr.GetBInfo(bActorId, EFriendDataType.EAttention, aActorId) == nil then
			LActor.sendTipmsg(actor, ScriptTips.friend11)
			return
		end
	end

	--脏话过滤
	content = System.filterText(content)

	local chatInfo = {aActorId, System.getNowTime(), content}
	--是否有记录聊天数据
	local bInfo = friendmgr.GetBInfo(aActorId, EFriendDataType.EChat, bActorId)
	if bInfo == nil then
		bInfo = friendmgr.AddBInfo(aActorId, EFriendDataType.EChat, bActorId)
		SendAddListMember(actor, EFriendDataType.EChat, bActorId)
		if friendmgr.IsListFull(aActorId, EFriendDataType.EChat) then
			local delActorId = friendmgr.DelEarliestBInfo(aActorId, EFriendDataType.EChat)
			SendDelListMember(actor, EFriendDataType.EChat, delActorId)
		end
	end
	bInfo.contentList = bInfo.contentList or {}
	local contentList = bInfo.contentList
	table.insert(contentList, #contentList + 1, chatInfo)
	--超过私聊内容列表长度 
	if #contentList > FriendLimit.contentListLen then
		table.remove(contentList, 1)
	end
	bInfo.lastContact = chatInfo[2]

	friendmgr.SetDirty(aActorId, true)
	SendChatContent(actor, chatInfo)

	local bActor = LActor.getActorById(bActorId)
	local bInfo2 = friendmgr.GetBInfo(bActorId, EFriendDataType.EChat, aActorId)
	if bInfo2 == nil then
		bInfo2 = friendmgr.AddBInfo(bActorId, EFriendDataType.EChat, aActorId)
		if bActor then
			SendAddListMember(bActor, EFriendDataType.EChat, aActorId)
		end
		if friendmgr.IsListFull(bActorId, EFriendDataType.EChat) then
			local delActorId = friendmgr.DelEarliestBInfo(bActorId, EFriendDataType.EChat)
			if bActor then
				SendDelListMember(bActor, EFriendDataType.EChat, delActorId)
			end
		end
	end
	bInfo2.contentList = bInfo2.contentList or {}
	local contentList2 = bInfo2.contentList
	table.insert(contentList2, #contentList2 + 1, chatInfo)
	--超过私聊内容列表长度 
	if #contentList2 > FriendLimit.contentListLen then
		table.remove(contentList2, 1)
	end
	bInfo2.lastContact = chatInfo[2]

	friendmgr.SetDirty(bActorId, true)

	if bActor then
		SendChatContent(bActor, chatInfo)
	end
end

--获取历史私聊内容
function HistoryChatHandle(actor, pack)
	local bActorId = LDataPack.readInt(pack)
	SendHistoryChat(actor, bActorId)
end

--切换拒绝跟非关注者私聊状态
function RefuseStrangerHandle(actor, pack)
	local changeValue = LDataPack.readByte(pack)
	if changeValue ~= 0 and changeValue ~= 1 then return end
	local actorId = LActor.getActorId(actor)
	local EMiscData = friendmgr.GetMiscData(actorId)
	if EMiscData.refuseStranger == changeValue then return end
	EMiscData.refuseStranger = changeValue
	SendRefuseStranger(actor)
end

--事件函数
function EhLogin(actor)
	if System.isCrossWarSrv() then return end
	SendRefuseStranger(actor)
end

function EhLogout(actor)
	-- body
end

--注册事件
actorevent.reg(aeUserLogin, EhLogin)
actorevent.reg(aeUserLogout, EhLogout)

--注册协议
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_GetList, GetList)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_Attention, AddAttentionHandle)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_DelAttention, DelAttentionHandle)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_Black, AddBlackHandle)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_DelBlack, DelBlackHandle)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_Chat, ChatHandle)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_GetHistoryChat, HistoryChatHandle)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_RefuseStranger, RefuseStrangerHandle)

--GM
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.pfrdlist = function (actor, arg)
	local actorId = tonumber(arg[1])
	if actorId == nil then
		actorId = LActor.getActorId(actor)
	end
	local fData = friendmgr.GetData(actorId)
	utils.printTable(fData)
	return true
end

gmCmdHandlers.cfrdlist = function (actor, arg)
	local actorId = tonumber(arg[1])
	if actorId == nil then
		actorId = LActor.getActorId(actor)
	end
	friendmgr.ClearData(actorId)
	return true
end
