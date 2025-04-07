module("guildgift", package.seeall)
require("guild.guildgift")

local Max_List = 20 --充值记录最大数量

local function getGuildVar(guild)
	local var = LGuild.getStaticVar(guild, true)
	if not var.gift then
		var.gift = {
			level = 1,
			exp = 0,
			charge_list = {}, --充值记录
			charge_begin = 0,
			charge_end = 0,
		}
	end
	return var.gift
end

local function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.guildgiftData then
		var.guildgiftData = {
			gifts = {}
		}
	end
	if not var.guildgiftData.giftEnd then var.guildgiftData.giftEnd = 0 end
	return var.guildgiftData 
end

local function getGiftId(lv, quality)
	local conf = GuildGiftConfig[lv]
	if conf and conf['gift'..quality] then
		return conf['gift'..quality]
	end
	return 0
end

--增加充值记录
local function addChargeRecord(guild, name, num, time, level, quality, count)
	local gvar = getGuildVar(guild)
	if not gvar then return end
	gvar.charge_list[gvar.charge_end] = {name=name, num=num, time=time, level=level, quality=quality, count=count}
	gvar.charge_end = gvar.charge_end + 1
	while (gvar.charge_end - gvar.charge_begin) > Max_List do
		gvar.charge_list[gvar.charge_begin] = nil
		gvar.charge_begin = gvar.charge_begin + 1
	end
end

--增加礼物奖励
local function addGuildGift(actor, level, quality, count, name, charge_end)
	if not actor then return end --离线的情况加不进去
	local var = getActorVar(actor)
	var.gifts[#var.gifts+1] = {level=level, quality=quality, count=count, name=name}
	var.giftEnd = charge_end
	s2cGiftNotice(actor, true)
end

------------------------------------------------------------------------------------------------------

function getgiftcharge(actor)
	local var = getActorVar(actor)
	return var.giftEnd
end

function c2sGiftInfo(actor, packet)
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetGiftInfo)
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	LDataPack.writeInt(npack, LActor.getGuildId(actor))
	System.sendPacketToAllGameClient(npack, 0)
end

--领取战盟礼物
function c2sGiftGive(actor, packet)
	local var = getActorVar(actor)
	if not var then return end
	local items = {}
	for i = 1, #var.gifts do
		local gift = var.gifts[i]
		local id = getGiftId(gift.level, gift.quality)
		if id > 0 then
			for i = 1, (gift.count or 1) do
				local dropId = ItemConfig[id].useArg.dropId
				local rewards = drop.dropGroup(dropId)
				for k, v in ipairs(rewards) do
					table.insert(items, v)
				end
			end
		end
	end
	actoritem.addItems(actor, items, "guild gift")
	var.gifts = {}
	s2cGiftNotice(actor, false) --通知客户端礼物领完
	
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetGiftInfo)
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	LDataPack.writeInt(npack, LActor.getGuildId(actor))
	System.sendPacketToAllGameClient(npack, 0)
end

--战盟礼物通知
function s2cGiftNotice(actor, flag)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildActity, Protocol.sGuildActivityCmd_GiftNotice)
	if pack == nil then return end
	LDataPack.writeByte(pack, flag and 1 or 0)
	LDataPack.flush(pack)
end

--充值处理
function onRecharge(actor, count, item) 
	local conf = PayItemsConfig[item]
	if not conf then return end  --只计入常规充值

	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GuildRecharge)
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeInt(npack, count)
	LDataPack.writeInt(npack, item)
	LDataPack.writeString(npack, LActor.getName(actor))
	System.sendPacketToAllGameClient(npack, 0)
end

local function onGuildRecharge(sId, sType, cpack)
	if not System.isBattleSrv() then return end
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)
	local count = LDataPack.readInt(cpack)
	local item = LDataPack.readInt(cpack)
	local name = LDataPack.readString(cpack)

	local guild = LGuild.getGuildById(guildId)
	local gvar = getGuildVar(guild)
	--成长值增长
	gvar.exp = gvar.exp + count
	while GuildGiftConfig[gvar.level+1] and gvar.exp >= GuildGiftConfig[gvar.level].exp do
		gvar.level = gvar.level + 1
	end

	local now = System.getNowTime()
	local conf = PayItemsConfig[item]
	addChargeRecord(guild, name, count, now, gvar.level, conf.giftQuality, conf.giftCount) --充值记录

	--现有的帮会全员添加礼物
	local members = LGuild.getMemberIdList(guild)
	if not members then return end
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_UpdateGift)
	LDataPack.writeInt(npack, gvar.level)
	LDataPack.writeByte(npack, conf.giftQuality)
	LDataPack.writeInt(npack, conf.giftCount)
	LDataPack.writeString(npack, name)
	LDataPack.writeInt(npack, gvar.charge_end)
	local count = LGuild.getGuildMemberCount(guild)
	LDataPack.writeShort(npack, count)
	for k, v in pairs(members) do
		LDataPack.writeInt(npack, v)		
	end
	System.sendPacketToAllGameClient(npack, 0)
end

local function onUpdateGift(sId, sType, cpack)
	local level = LDataPack.readInt(cpack)
	local quality = LDataPack.readByte(cpack)
	local count = LDataPack.readInt(cpack)
	local name = LDataPack.readString(cpack)
	local change_end = LDataPack.readInt(cpack)
	local membercount = LDataPack.readShort(cpack)
	for i=1, membercount do
		local actorid = LDataPack.readInt(cpack)
		local actor = LActor.getActorById(actorid)
		if actor then
			addGuildGift(actor, level, quality, count, name, change_end)
		end
	end
end

--退出战盟处理
function onLeftGuild(actor)
	local var = getActorVar(actor)
	if not var then return end
	var.gifts = {}
	var.giftEnd = 0
	s2cGiftNotice(actor, false)
end

function sendGiftInfo(guild, actorid, sId)
	local gvar = getGuildVar(guild)
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendGiftInfo)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeShort(npack, gvar.level)
	LDataPack.writeInt(npack, gvar.exp)
	LDataPack.writeShort(npack, gvar.charge_end - gvar.charge_begin)
	for i = gvar.charge_begin, gvar.charge_end-1 do
		local record = gvar.charge_list[i]
		LDataPack.writeInt(npack, record.time)
		LDataPack.writeString(npack, record.name)
		LDataPack.writeInt(npack, record.num)
	end
	System.sendPacketToAllGameClient(npack, sId)
end

function onActorLogin(guild, actorid, sId, giftEnd)
	local gvar = getGuildVar(guild)
	if not gvar then return end
	--把登录前的奖励数据加入
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendGiftData)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeInt(npack, gvar.charge_end)
	for i = giftEnd, gvar.charge_end - 1 do
		local data = gvar.charge_list[i]
		if data then
			LDataPack.writeInt(npack, data.level)
			LDataPack.writeInt(npack, data.quality)
			LDataPack.writeInt(npack, data.count)
			LDataPack.writeString(npack, data.name)
		else
			LDataPack.writeInt(npack, 0)
			LDataPack.writeInt(npack, 0)
			LDataPack.writeInt(npack, 0)
			LDataPack.writeString(npack, "")
		end
	end
	System.sendPacketToAllGameClient(npack, sId)
end

local function onGetGiftInfo(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)
	local guild = LGuild.getGuildById(guildId)
	if not guild then return end
	sendGiftInfo(guild, actorid, sId)
end

local function onSendGiftData(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local charge_end = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorid)
	local var = getActorVar(actor)
	if not var then return end
	--把登录前的奖励数据加入
	for i = var.giftEnd, charge_end - 1 do
		local level = LDataPack.readInt(cpack)
		var.gifts[#var.gifts+1] = {level=level, quality=LDataPack.readInt(cpack), count=LDataPack.readInt(cpack), name=LDataPack.readString(cpack)}
	end
	var.giftEnd = charge_end
	if #var.gifts > 0 then --有礼物时通知领取
		s2cGiftNotice(actor, true)
	end
end

local function onSendGiftInfo(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorid)
	if not actor then return end
	local var = getActorVar(actor)
	if not (var) then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildActity, Protocol.sGuildActivityCmd_GiftInfo)
	if pack == nil then return end
	LDataPack.writeShort(pack, LDataPack.readShort(cpack))
	LDataPack.writeInt(pack, LDataPack.readInt(cpack))
	local count = LDataPack.readShort(cpack)
	LDataPack.writeShort(pack, count)
	for i = 1, count do
		LDataPack.writeInt(pack, LDataPack.readInt(cpack))
		LDataPack.writeString(pack, LDataPack.readString(cpack))
		LDataPack.writeInt(pack, LDataPack.readInt(cpack))
	end
	LDataPack.writeShort(pack, #var.gifts)
	for i = 1, #var.gifts do
		local gift = var.gifts[i]
		local id = getGiftId(gift.level, gift.quality)
		LDataPack.writeInt(pack, id)
		LDataPack.writeInt(pack, gift.count or 1)
		LDataPack.writeShort(pack, gift.level)
		LDataPack.writeString(pack, gift.name)
	end
	LDataPack.flush(pack)
end

function sendGiftCharge(guild, actorid)
	local gvar = getGuildVar(guild)
	if not (gvar) then return end
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendGiftCharge)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeInt(npack, gvar.charge_end or 0)
	System.sendPacketToAllGameClient(npack, 0)	
end

local function onSendGiftCharge(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local chargeEnd = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorid)
	if actor then
		local var = getActorVar(actor)
		if not (var) then return end
		var.giftEnd = chargeEnd --设置礼物领取的边界，入盟前的礼物领不了
	else
		local npack = LDataPack.allocPacket()
		LDataPack.writeInt(npack, chargeEnd)
		System.sendOffMsg(actorid, 0, OffMsgType_GuildGiftCharge, npack)
	end
end

local function OffMsgGuildGift(actor, packet)
	local chargeEnd = LDataPack.readInt(packet)
	local var = getActorVar(actor)
	if not (var) then return end
	var.giftEnd = chargeEnd 
end

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendGiftData, onSendGiftData)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendGiftCharge, onSendGiftCharge)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendGiftInfo, onSendGiftInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetGiftInfo, onGetGiftInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GuildRecharge, onGuildRecharge)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_UpdateGift, onUpdateGift)

actorevent.reg(aeRecharge, onRecharge)
actorevent.reg(aeLeftGuild, onLeftGuild)

local function init()
	if System.isCrossWarSrv() then return end
	msgsystem.regHandle(OffMsgType_GuildGiftCharge, OffMsgGuildGift)
	netmsgdispatcher.reg(Protocol.CMD_GuildActity, Protocol.cGuildActivityCmd_GiftInfo, c2sGiftInfo)
	netmsgdispatcher.reg(Protocol.CMD_GuildActity, Protocol.cGuildActivityCmd_GiftGive, c2sGiftGive)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.guildgiftInfo = function (actor, args)
end

gmCmdHandlers.guildgiftGive = function (actor, args)
	c2sGiftGive(actor)
end
