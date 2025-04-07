module("guildsystem", package.seeall)

require("systems.guild.guildcommon")
require("systems.guild.guildskill")
require("systems.guild.guildchat")
require("systems.guild.guildstore")
require("systems.guild.guildgift")
require("systems.guild.guildboss")
require("systems.guild.guildbossteam")

-- 战盟系统

-- 盟主，副盟主，长老，护法，堂主，精英

local MAX_MEMO_LEN = 128
local MAX_NAME_LEN = 6
local MAX_JOIN_APPLY = 100
local MAX_BUILDING = 4
local MAX_NEED_FIGHT = 99999999999
local DEFAULT_NEED_FIGHT = 99999

local LActor = LActor
local System = System
local LDataPack = LDataPack
local systemId = Protocol.CMD_Guild
local common = guildcommon
shielding = shielding or  false

function setShielding(b)
	shielding = b
end

local UpdateType = 
{
	dtMapInfo = 1, -- 战盟地图
	dtGuildInfo = 2, -- 战盟基础
	dtMemberList = 3, -- 成员管理
	dtGuildList = 4, -- 战盟列表
	dtGuildApply = 5, -- 申请列表
	dtBuilding = 6, -- 战盟建筑
}

GuildLogType =
{
	ltAddMember 		= 1, -- 加入战盟：xxx加入战盟
	ltLeft 				= 2, -- 离开战盟：xxx离开了战盟
	ltAppoint 			= 3, -- 副盟主任命：盟主任命[xxx]为副盟主
	ltAbdicate 			= 4, -- 盟主禅让：盟主禅让给[xxxx]
	ltImpeach 			= 5, -- 盟主弹劾：[xxx]弹劾战盟盟主，成为新的盟主
	ltFuben 			= 6, -- 战盟副本进度首通：[xxx]首次通关战盟副本第N关（仅本战盟第一个通关会记录）
	ltDonate 			= 7, -- 元宝/金币捐献：[xxx]捐献了n元宝/金币，获得N贡献
	ltUpgrade 			= 8, -- 建筑升级：[xxx]升级了xx大厅至N级
	ltStore 			= 9, -- 战盟商店：年-月-日 时-分 xxx在战盟商店获得[xxxx]
}

CREATE_GUILD_NAME_USED = 1 --创建战盟名字已被使用
CREATE_GUILD_ERROR = 2   --创建战盟失败
APPLY_GUILD_LESS_POWER = 3 --战力不足
GUILD_NOT_THIS_APPLYID = 4 --沒有此申请人
GUILD_MAX_MEMBERS = 5 --战盟人数已满
GUILD_IMPEACH_ERROR = 6 --弹劾错误

local function log_actor(actor, fmt, ...)
	print(string.format("[%d] ", LActor.getActorId(actor))..string.format(fmt, ...))
end

local function isOpen(actor)
	return actorexp.checkLevelCondition(actor, actorexp.LimitTp.guild)
end

local function changeMemo(guild, memo)
	local guildVar = LGuild.getStaticVar(guild, true)
	guildVar.memo = memo
end

local function onChangeMemo(sId, sType, cpack)
	local guildId = LDataPack.readInt(cpack)
	local guild = LGuild.getGuildById(guildId)
	if not guild then return end
	local memo = LDataPack.readString(cpack)
	changeMemo(guild, memo)
end

local function onSendGuildTip(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local typeid = LDataPack.readInt(cpack)
	local args = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorid)
	if not actor then return end
	if typeid == CREATE_GUILD_NAME_USED then
		actoritem.addItem(actor, GuildCreateConfig[1].moneyType, args, "guild error return")
		LActor.sendTipmsg(actor, ScriptTips.guild017, ttScreenCenter)
	elseif typeid == CREATE_GUILD_ERROR then
		actoritem.addItem(actor, GuildCreateConfig[1].moneyType, args, "guild error return")
		LActor.sendTipmsg(actor, ScriptTips.guild018, ttScreenCenter)
	elseif typeid == APPLY_GUILD_LESS_POWER then
		local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_JoinResult)
		if not pack then return end
		LDataPack.writeInt(pack, args)
		LDataPack.writeByte(pack, 0)
		LDataPack.flush(pack)
	elseif typeid == GUILD_NOT_THIS_APPLYID then
		LActor.sendTipmsg(actor, ScriptTips.guild020, ttScreenCenter)
	elseif typeid == GUILD_MAX_MEMBERS then
		LActor.sendTipmsg(actor, ScriptTips.guild019, ttScreenCenter)
	elseif typeid == GUILD_IMPEACH_ERROR then
		actoritem.addItem(actor, NumericType_YuanBao, GuildConfig.impeachCost, "guild error return")
	end
end

local function sendGuildTip(actorid, sId, args, typeid)
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendGuildTip)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeInt(npack, typeid)
	LDataPack.writeInt(npack, args)
	System.sendPacketToAllGameClient(npack, sId)
end

local function sendChangeGuildPos(actorid, sId, guildId, pos, name)
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_ChangeGuildPos)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeInt(npack, pos)
	LDataPack.writeString(npack, name or "")
	System.sendPacketToAllGameClient(npack, sId)
end

local function onChangeGuildPos(sId, sType, cpack)
	local guildId = LDataPack.readInt(cpack)
	local actorid = LDataPack.readInt(cpack)	
	local pos = LDataPack.readByte(cpack)
	local name = LDataPack.readString(cpack)
	local actor = LActor.getActorById(actorid)
	
	if actor then		
		local beforeid = LActor.getGuildId(actor)
		if beforeid ~= 0 and guildId == 0 then
			LActor.onLeftGuild(actor, beforeid)
		elseif guildId ~= 0 and beforeid == 0 then
			LActor.onJoinGuild(actor, guildId, pos, name)
		else
			LActor.changeGuildInfo(actor, guildId, pos)
		end		
		actorevent.onEvent(actor, aeNotifyFacade)
	else
		local npack = LDataPack.allocPacket()
		LDataPack.writeInt(npack, guildId)
		LDataPack.writeByte(npack, pos)
		LDataPack.writeString(npack, "")
		System.sendOffMsg(actorid, 0, OffMsgType_GuildInfo, npack)
	end
end

function handleGuildInfo(actor, packet)
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetGuildInfo)
	LDataPack.writeInt(npack, LActor.getActorId(actor))	
	LDataPack.writeInt(npack, guildId)
	System.sendPacketToAllGameClient(npack, 0)
end

local function onGetGuildInfo(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)
	-- 战盟ID, 战盟名称, 战盟建筑等级(array), 战盟资金, 战盟人数, 公告信息, 成员列表(名字, 职位, 贡献), 我的当前贡献
	local guild = LGuild.getGuildById(guildId)
	if guild == nil then
		return 
	end

	local guildVar = LGuild.getStaticVar(guild)
	local building = guildVar.building or {}
	local isAuto, needFight = LGuild.getAutoApprove(guild)

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendGuildInfo)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeByte(npack, 1)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeString(npack, LGuild.getGuildName(guild))
	LDataPack.writeByte(npack, MAX_BUILDING)
	for i=1,MAX_BUILDING do
		LDataPack.writeByte(npack, building[i] or 1)
	end
	LDataPack.writeInt(npack, guildVar.fund or 0) -- 战盟资金
	LDataPack.writeString(npack, guildVar.memo or "")
	LDataPack.writeByte(npack, isAuto)
	LDataPack.writeDouble(npack, needFight)
	System.sendPacketToAllGameClient(npack, sId)
end

local function onSendGuildInfo(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
	end
	
	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_GuildInfo)
    LDataPack.writeByte(pack, LDataPack.readByte(cpack))
    LDataPack.writeInt(pack, LDataPack.readInt(cpack))
	LDataPack.writeString(pack, LDataPack.readString(cpack))
	local count = LDataPack.readByte(cpack)
    LDataPack.writeByte(pack, count)
    for i=1,count do
    	LDataPack.writeByte(pack, LDataPack.readByte(cpack))
    end
    LDataPack.writeInt(pack, LDataPack.readInt(cpack)) -- 战盟资金
    LDataPack.writeString(pack, LDataPack.readString(cpack))
	LDataPack.writeByte(pack, LDataPack.readByte(cpack))
	LDataPack.writeDouble(pack, LDataPack.readDouble(cpack))
	LDataPack.flush(pack)
end

function handleCreateGuild(actor, packet)
	if not isOpen(actor) then return end

	local index = LDataPack.readByte(packet) -- 创建类型索引，从1开始
	local name = LDataPack.readString(packet)

	local conf = GuildCreateConfig[index]
	if not conf then
		return 
	end

	if conf.vipLv ~= nil and LActor.getSVipLevel(actor) < conf.vipLv then
		return 
	end

	local guildId = LActor.getGuildId(actor)
	if guildId ~= 0 then
		log_actor(actor, "create guild error, exist guild : "..guildId)
		return 
	end

	if name == "" or System.getStrLenUtf8(name) > MAX_NAME_LEN then
		LActor.sendTipmsg(actor, ScriptTips.guild015, ttScreenCenter)
		log_actor(actor, "create guild error, len")
		return 
	end 

	if not LActorMgr.checkNameStr(name) then
		log_actor(actor, "create guild error, len")
		LActor.sendTipmsg(actor, ScriptTips.guild016, ttScreenCenter)
		return 
	end

	if not actoritem.checkItem(actor, conf.moneyType, conf.moneyCount) then
		log_actor(actor, "create guild error, money")
		return
	end

	local basicData = LActor.getActorData(actor)
	if basicData == nil then return end


	actoritem.reduceItem(actor, conf.moneyType, conf.moneyCount, "create guild")

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetGuildCreate)
	LDataPack.writeInt(npack, LActor.getActorId(actor))	
	LDataPack.writeByte(npack, index)
	LDataPack.writeString(npack, name)
	LDataPack.writeString(npack, basicData.actor_name)
	LDataPack.writeByte(npack, basicData.job)
	LDataPack.writeByte(npack, basicData.sex)
	LDataPack.writeInt(npack, basicData.level)
	LDataPack.writeDouble(npack, basicData.total_power)
	LDataPack.writeByte(npack, basicData.vip_level)
	LDataPack.writeUInt(npack, 0)
	
	System.sendPacketToAllGameClient(npack, 0)
end

local function onGetGuildCreate(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local index = LDataPack.readByte(cpack)
	local name = LDataPack.readString(cpack)	
	local conf = GuildCreateConfig[index]
	if not conf then
		sendGuildTip(actorid, sId, conf.moneyCount, CREATE_GUILD_ERROR)
		return 
	end

	if LGuild.nameHasUsed(name) then	
		sendGuildTip(actorid, sId, conf.moneyCount, CREATE_GUILD_NAME_USED)
		return 
	end

	local guild = LGuild.createGuild(name, actorid)
	if guild == nil then		
		sendGuildTip(actorid, sId, conf.moneyCount, CREATE_GUILD_ERROR)
		return 
	end
	common.initGuild(guild, conf.buildingLevels)
	changeMemo(guild, GuildConfig.defaultMemo)

	local mInfo = GuildMemberInfo:new_local()
	if mInfo == nil then
		sendGuildTip(actorid, sId, conf.moneyCount, CREATE_GUILD_ERROR)
		return 
	end

	mInfo.actorId_ = actorid
	local actorname = LDataPack.readString(cpack)
	mInfo:setName(actorname)
	mInfo.job_ = LDataPack.readByte(cpack)
	mInfo.sex_ = LDataPack.readByte(cpack)
	mInfo.level_ = LDataPack.readInt(cpack)
	mInfo.fight_ = LDataPack.readDouble(cpack)
	local svip = LDataPack.readByte(cpack)
	mInfo.vip_ = svip
	mInfo.lastLogoutTime_ = LDataPack.readUInt(cpack)
	mInfo.pos_ = smGuildLeader
	LGuild.addMember(guild, mInfo)
	guildgift.sendGiftCharge(guild, actorid)	
	common.sendGuildBasicInfo()
	local guildId = LGuild.getGuildId(guild)	
	guildboss.initGuildBoss(guild, true)	
	noticesystem.broadCastNotice(noticesystem.NTP.guildCreate, actorcommon.getVipShow(nil, svip), actorname, conf.level, name)

	guildsiege.refreshBuildMonster(guild)
	guildsiege.updateSiegeInfo(guild, nil, true)

	sendChangeGuildPos(actorid, sId, guildId, smGuildLeader, name)

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendGuildCreate)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeByte(npack, index)
	LDataPack.writeInt(npack, LGuild.getGuildId(guild))
	LDataPack.writeString(npack, name)
	System.sendPacketToAllGameClient(npack, sId)
	
	guildbattlesystem.sendBaseInfo(sId, actorid, guildId)
end

local function onSendGuildCreate(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local index = LDataPack.readByte(cpack)
	local guildId = LDataPack.readInt(cpack)
	local name = LDataPack.readString(cpack)
    local actor = LActor.getActorById(actorid)
	if actor then
		sendLeftDonateCount(actor)
		actorevent.onEvent(actor, aeNotifyFacade, -1)
		actorevent.onEvent(actor, aeGuildCreate)
		local conf = GuildCreateConfig[index]
		if not conf then
			return
		end
		common.changeContrib(actor, conf.award, "createguild")

		local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_CreateGuild)
		if not pack then return end
		LDataPack.writeByte(pack, 0)
		LDataPack.writeInt(pack, guildId)
		LDataPack.flush(pack)
	end	
end

-- 自动同意入会申请设置
function handleAutoApprove(actor, packet)
	local guildPos = LActor.getGuildPos(actor)
	if guildPos < smGuildAssistLeader then
		print("pos limit")
		return
	end
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end

	local auto = LDataPack.readByte(packet)
	local needFight = LDataPack.readDouble(packet)

	-- print("战盟设置 ::" .. auto .. ":" .. needFight)
	if needFight < 0 or needFight > MAX_NEED_FIGHT then
		print("max needFight is err")
		return
	end

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetAutoApprove)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeByte(npack, auto)
	LDataPack.writeDouble(npack, needFight)
	System.sendPacketToAllGameClient(npack, 0)
end

local function onGetAutoApprove(sId, sType, cpack)
	local guildId = LDataPack.readInt(cpack)

	local guild = LGuild.getGuildById(guildId)
	if guild == nil then
		print("guild is nil")
		return 
	end

	local auto = LDataPack.readByte(cpack)
	local needFight = LDataPack.readDouble(cpack)

	LGuild.setAutoApprove(guild, auto, needFight)

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendAutoApprove)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeByte(npack, auto)
	LDataPack.writeDouble(npack, needFight)
	System.sendPacketToAllGameClient(npack, 0)
end

local function onSendAutoApprove(sId, sType, cpack)
	local guildId = LDataPack.readInt(cpack)
	local auto = LDataPack.readByte(cpack)
	local needFight = LDataPack.readDouble(cpack)

	local pack = LDataPack.allocBroadcastPacket(systemId, Protocol.sGuildCmd_AutoApprove)
	if not pack then return end
	LDataPack.writeByte(pack, auto)
	LDataPack.writeDouble(pack, needFight)
	LGuild.broadcastData(guildId, pack)
end

-- function notifyUpdateGuildInfo(guild, type, param)
-- 	if not guild then return end
-- 	local pack = LDataPack.allocBroadcastPacket(systemId, Protocol.sGuildCmd_Update)
-- 	if not pack then return end
-- 	LDataPack.writeByte(pack, type)
-- 	LDataPack.writeInt(pack, param or 0)
-- 	LGuild.broadcastData(guild, pack)
-- end

local function getMaxMember(guild)
	local guildLevel = common.getGuildLevel(guild)
	return GuildConfig.maxMember[guildLevel] or 0
end

-- 申请加入
function handleApplyJoin(actor, packet)
	if shielding then 
		return 
	end
	if not isOpen(actor) then return end

	local actorid = LActor.getActorId(actor)

	--是否已经加入帮派
	local agGuildId = LGuild.getGuildIdByActorId(actorid)
	if agGuildId ~= 0 then
		log_actor(actor, "exist guild")
		return
	end

	local guildId = LDataPack.readInt(packet)
	local basicData = LActor.getActorData(actor)
	if basicData == nil then return end

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetApplyJoin)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeString(npack, basicData.actor_name)
	LDataPack.writeByte(npack, basicData.job)
	LDataPack.writeByte(npack, basicData.sex)
	LDataPack.writeInt(npack, basicData.level)
	LDataPack.writeDouble(npack, basicData.total_power)
	LDataPack.writeByte(npack, basicData.vip_level)
	LDataPack.writeUInt(npack, 0)
	System.sendPacketToAllGameClient(npack, 0)
end

local function onGetApplyJoin(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)

	local guild = LGuild.getGuildById(guildId)
	if guild == nil then
		return 
	end
	--是否有申请信息
	if LGuild.getJoinMsg(guild, actorid) then
		return 
	end
	
	local isAuto, needFight = LGuild.getAutoApprove(guild)
	local name = LDataPack.readString(cpack)
	local job = LDataPack.readByte(cpack)
	local sex = LDataPack.readByte(cpack)
	local level = LDataPack.readInt(cpack)
	local fight = LDataPack.readDouble(cpack)
	local vip = LDataPack.readByte(cpack)
	local lastLogoutTime = LDataPack.readUInt(cpack)
	if isAuto == 1 then
		if fight < needFight then
			sendGuildTip(actorid, sId, guildId, APPLY_GUILD_LESS_POWER)
			return
		end
		-- 最大人数限制
		if LGuild.getGuildMemberCount(guild) < getMaxMember(guild) then			
			local mInfo = GuildMemberInfo:new_local()
			if mInfo == nil then return end

			mInfo.actorId_ = actorid
			mInfo:setName(name)
			mInfo.job_ = job
			mInfo.sex_ = sex
			mInfo.level_ = level
			mInfo.fight_ = fight
			mInfo.vip_ = vip
			mInfo.lastLogoutTime_ = lastLogoutTime
			mInfo.pos_ = smGuildCommon

			LGuild.addMember(guild, mInfo)
			guildgift.sendGiftCharge(guild, actorid)
			guildbattlesystem.sendBaseInfo(sId, actorid, guildId)
			LGuild.addGuildLog(guild, GuildLogType.ltAddMember, name)
			sendChangeGuildPos(actorid, sId, guildId, smGuildCommon)

			local npack = LDataPack.allocPacket()
			LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
			LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendJoinGuild)
			LDataPack.writeInt(npack, actorid)
			LDataPack.writeInt(npack, guildId)
			System.sendPacketToAllGameClient(npack, sId)
			
			local tips = string.format(GuildConfig.joinGuildNotice, name)
			guildchat.sendNotice(guild, tips, enGuildChatNew)
			return
		end
	end

	LGuild.postJoinMsg(guild, actorid, name, job, sex, level, fight, vip)

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendApplyJoin)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeInt(npack, guildId)
	System.sendPacketToAllGameClient(npack, 0)
end

local function onSendJoinGuild(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorid)
	if actor then
		sendLeftDonateCount(actor)
	end
end

function onSendApplyJoin(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)
	local pack = LDataPack.allocBroadcastPacket(systemId, Protocol.sGuildCmd_Join)
	if not pack then return end
	LDataPack.writeInt(pack, actorid)
	LGuild.broadcastData(guildId, pack)		
end

local function onGetOtherActor(sId, sType, cpack)
	local guildId = LDataPack.readInt(cpack)
	local applyId = LDataPack.readInt(cpack)
	local basicData = nil

	local applyer = LActor.getActorById(applyId)
	if applyer then
		basicData = LActor.getActorData(applyer)
	else
		basicData = offlinedatamgr.GetDataByOffLineDataType(applyId, EOffLineDataType.EBasic)
	end
	if basicData == nil then return end

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendOtherActor)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeInt(npack, applyId)
	LDataPack.writeString(npack, basicData.actor_name)
	LDataPack.writeByte(npack, basicData.job)
	LDataPack.writeByte(npack, basicData.sex)
	LDataPack.writeInt(npack, basicData.level)
	LDataPack.writeDouble(npack, basicData.total_power)
	LDataPack.writeByte(npack, basicData.vip_level)
	local actor = LActor.getActorById(applyId)
	LDataPack.writeUInt(npack, actor and 0 or basicData.last_online_time)
	System.sendPacketToAllGameClient(npack, 0)
end

local function onSendOtherActor(sId, sType, cpack)
	local guildId = LDataPack.readInt(cpack)
	local applyId = LDataPack.readInt(cpack)
	local name = LDataPack.readString(cpack)
	local job = LDataPack.readByte(cpack)
	local sex = LDataPack.readByte(cpack)
	local level = LDataPack.readInt(cpack)
	local fight = LDataPack.readDouble(cpack)
	local vip = LDataPack.readByte(cpack)
	local lastLogoutTime = LDataPack.readUInt(cpack)

	local guild = LGuild.getGuildById(guildId)
	if not guild then
		return
	end
	local mInfo = GuildMemberInfo:new_local()
	if mInfo == nil then return end
	mInfo.actorId_ = applyId
	mInfo:setName(name)
	mInfo.job_ = job
	mInfo.sex_ = sex
	mInfo.level_ = level
	mInfo.fight_ = fight
	mInfo.vip_ = vip
	mInfo.lastLogoutTime_ = lastLogoutTime
	mInfo.pos_ = smGuildCommon
	LGuild.addMember(guild, mInfo)
	guildgift.sendGiftCharge(guild, applyId)
	LGuild.addGuildLog(guild, GuildLogType.ltAddMember, name)
	sendChangeGuildPos(applyId, 0, guildId, smGuildCommon, LGuild.getGuildName(guild))

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendRespondJoin)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeInt(npack, applyId)
	LDataPack.writeByte(npack, 1)
	LDataPack.writeString(npack, LGuild.getGuildName(guild))
	System.sendPacketToAllGameClient(npack, 0)	
end

-- 回应加入申请
function handleRespondJoin(actor, packet)
	if shielding then 
		return
	end
	local applyId = LDataPack.readInt(packet)
	local ret = LDataPack.readByte(packet)
	local guildId = LActor.getGuildId(actor)

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetRespondJoin)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	LDataPack.writeInt(npack, applyId)
	LDataPack.writeByte(npack, ret)
	System.sendPacketToAllGameClient(npack, 0)
end

function onGetRespondJoin(sId, sType, cpack)
	local guildId = LDataPack.readInt(cpack)
	local actorid = LDataPack.readInt(cpack)
	local applyId = LDataPack.readInt(cpack)
	local ret = LDataPack.readByte(cpack)

	local guild = LGuild.getGuildById(guildId)
	if guild == nil then print("guild is nil") return end
	if not LGuild.getJoinMsg(guild, applyId) then
		sendGuildTip(actorid, sId, 0, GUILD_NOT_THIS_APPLYID)
		return 
	end
	LGuild.removeJoinMsg(guild, applyId)

	if ret == 1 then
		local agGuildId = LGuild.getGuildIdByActorId(applyId)
		--玩家是否已经加入帮派
		if agGuildId ~= 0 then
			--LActor.sendTipmsg(actor, string.format(ScriptTips.guild002, t), ttScreenCenter)
			return
		end
		--帮派人数是否已经满了
		if LGuild.getGuildMemberCount(guild) >= getMaxMember(guild) then
			sendGuildTip(actorid, sId, 0, GUILD_MAX_MEMBERS)			
			return
		end
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetOtherActor)
		LDataPack.writeInt(npack, guildId)
		LDataPack.writeInt(npack, applyId)
		System.sendPacketToAllGameClient(npack, 0)
		return
	else
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendRespondJoin)
		LDataPack.writeInt(npack, guildId)
		LDataPack.writeInt(npack, applyId)
		LDataPack.writeByte(npack, 0)
		LDataPack.writeString(npack, LGuild.getGuildName(guild))
		System.sendPacketToAllGameClient(npack, 0)
	end
end

local function onSendRespondJoin(sId, sType, cpack)
	local guildId = LDataPack.readInt(cpack)
	local applyId = LDataPack.readInt(cpack)
	local ret = LDataPack.readByte(cpack)
	local name = LDataPack.readString(cpack)
	local applyer = LActor.getActorById(applyId)
	if applyer then
		if ret == 1 then
			sendLeftDonateCount(applyer)
			local pack = LDataPack.allocPacket(applyer, systemId, Protocol.sGuildCmd_JoinResult)
			if not pack then return end
			LDataPack.writeInt(pack, guildId)
			LDataPack.writeByte(pack, ret)
			LDataPack.flush(pack)
		end		
		print("handleRespondJoin reject:" .. applyId)
	else
		print("handleRespondJoin not online:" .. applyId)
	end	
end

-- 弹劾
function handleImpeach(actor, packet)
	if shielding then 
		return
	end
	local guildPos = LActor.getGuildPos(actor)
	if guildPos < smGuildTz then
		print("pos limit:"..guildPos)
		return -- 堂主及以上官员
	end

	if not actoritem.checkItem(actor, NumericType_YuanBao, GuildConfig.impeachCost) then
		log_actor(actor, "no enough money")
		return 
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, GuildConfig.impeachCost, "impeach")

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetImpeach)
	LDataPack.writeInt(npack, LActor.getGuildId(actor))
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	LDataPack.writeString(npack, LActor.getName(actor))
	System.sendPacketToAllGameClient(npack, 0)
end

local function onGetImpeach(sId, sType, cpack)
	local guildId = LDataPack.readInt(cpack)
	local actorid = LDataPack.readInt(cpack)

	local guild = LGuild.getGuildById(guildId)
	if guild == nil then		
		sendGuildTip(actorid, sId, 0, GUILD_IMPEACH_ERROR)
		return 
	end

	local leaderId = LGuild.getLeaderId(guild)
	local name, _, _, _, lastLogoutTime = LGuild.getMemberInfo(guild, leaderId)
	if lastLogoutTime == nil then
		sendGuildTip(actorid, sId, 0, GUILD_IMPEACH_ERROR)
		return 
	end
	if System.getNowTime() - lastLogoutTime < GuildConfig.impeachTime then
		sendGuildTip(actorid, sId, 0, GUILD_IMPEACH_ERROR)
		return 
	end	
	LGuild.changeGuildPos(guild, leaderId, smGuildCommon)
	sendChangeGuildPos(leaderId, sId, guildId, smGuildCommon)
	LGuild.changeGuildPos(guild, actorid, smGuildLeader)
	sendChangeGuildPos(actorid, sId, guildId, smGuildLeader)

	LGuild.addGuildLog(guild, GuildLogType.ltImpeach, name or "")	

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendImpeach)
	LDataPack.writeInt(npack, leaderId)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeString(npack, LDataPack.readString(cpack))
	System.sendPacketToAllGameClient(npack, 0)	
end

local function onSendImpeach(sId, sType, cpack)
	local leaderId = LDataPack.readInt(cpack)
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)
	local leaderActor = LActor.getActorById(leaderId)
	if leaderActor then
		actorevent.onEvent(leaderActor, aeChangeGuildPos, smGuildCommon, smGuildLeader)	
	end
	
	local actor = LActor.getActorById(actorid)
	if actor then
		actorevent.onEvent(actor, aeChangeGuildPos, smGuildLeader, smGuildCommon)
		actorevent.onEvent(actor, aeNotifyFacade, -1)
		local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_ChangePos)
		if not pack then return end
		LDataPack.writeInt(pack, actorid)
		LDataPack.writeByte(pack, smGuildLeader)
		LDataPack.flush(pack)
	end

	local content = string.format(GuildConfig.impeachMailContext, LDataPack.readString(cpack))
    local mailData = {head=GuildConfig.impeachMailTitle, context = content, tAwardList={}}
	mailsystem.sendMailById(leaderId, mailData)
end

-- 禅让/降职/任命副盟主
function handleChangePos(actor, packet)
	if shielding then 
		return
	end
	local targetId = LDataPack.readInt(packet)
	local pos = LDataPack.readByte(packet)

	local guildPos = LActor.getGuildPos(actor)
	if guildPos ~= smGuildLeader then
		log_actor(actor, "guild pos error : "..guildPos)
		return 
	end
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetChangePos)
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	LDataPack.writeInt(npack, LActor.getGuildId(actor))
	LDataPack.writeInt(npack, targetId)	
	LDataPack.writeByte(npack, pos)
	System.sendPacketToAllGameClient(npack, 0)	
end

local function onGetChangePos(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)
	local targetId = LDataPack.readInt(cpack)
	local pos = LDataPack.readByte(cpack)
	local guild = LGuild.getGuildById(guildId)
	if guild == nil then		
		return 
	end

	if not LGuild.isMember(guild, targetId) then
		return
	end

	--pos = smGuildLeader
	if pos == smGuildLeader then -- 禅让
		if LGuild.getGuildPos(guild, targetId) ~= smGuildAssistLeader then
			return 
		end
		LGuild.changeGuildPos(guild, actorid, smGuildAssistLeader)
		LGuild.changeGuildPos(guild, targetId, smGuildLeader)

		local name = LGuild.getMemberInfo(guild, actorid)
		local tarname = LGuild.getMemberInfo(guild, targetId)
		LGuild.addGuildLog(guild, GuildLogType.ltAbdicate, tarname or "");

		local tips = string.format(GuildConfig.demiseNotice, name, tarname)
		guildchat.sendNotice(guild, tips)
	elseif pos == smGuildAssistLeader then -- 任命副盟主
		local guildLevel = common.getGuildLevel(guild)
		local countsConfig = GuildConfig.posCounts[guildLevel]
		if countsConfig == nil then
			return 
		end
		local maxAssist = countsConfig[2] or 0 -- 2表示是副盟主
		local assistLeaderList = LGuild.getAssistLeaderIdList(guild)
		local count = (assistLeaderList == nil and 0 or #assistLeaderList)
		if count >= maxAssist then
			print("max assist")
			return 
		end

		LGuild.changeGuildPos(guild, targetId, smGuildAssistLeader)
		
		local name = LGuild.getMemberInfo(guild, targetId)
		LGuild.addGuildLog(guild, GuildLogType.ltAppoint, name or "")

		local tips = string.format(GuildConfig.appointAssistantNotice, name)
		guildchat.sendNotice(guild, tips)
	else -- 降职
		if LGuild.getGuildPos(guild, targetId) ~= smGuildAssistLeader then
			return 
		end
		LGuild.changeGuildPos(guild, targetId, smGuildCommon) -- 以后再根据贡献排职位
	end

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendChangePos)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeInt(npack, targetId)
	LDataPack.writeByte(npack, pos)
	LDataPack.writeInt(npack, guildId)
	System.sendPacketToAllGameClient(npack, 0)	
end

local function onSendChangePos(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local targetId = LDataPack.readInt(cpack)
	local pos = LDataPack.readByte(cpack)
	local guildId = LDataPack.readInt(cpack)

	local actor = LActor.getActorById(actorid)
	local targetActor = LActor.getActorById(targetId)
	if pos == smGuildLeader then -- 禅让	
		if actor then
			LActor.changeGuildInfo(actor, guildId, smGuildAssistLeader)
			actorevent.onEvent(actor, aeChangeGuildPos, smGuildAssistLeader, smGuildLeader)
			actorevent.onEvent(actor, aeNotifyFacade, -1)
			common.sendBasicInfo(actor)
		else
			local npack = LDataPack.allocPacket()
			LDataPack.writeInt(npack, guildId)
			LDataPack.writeByte(npack, smGuildAssistLeader)
			LDataPack.writeString(npack, "")
			System.sendOffMsg(actorid, 0, OffMsgType_GuildInfo, npack)
		end
		if targetActor then
			LActor.changeGuildInfo(targetActor, guildId, smGuildLeader)
			actorevent.onEvent(targetActor, aeChangeGuildPos, smGuildLeader, smGuildAssistLeader)
			common.sendBasicInfo(targetActor)
		else
			local npack = LDataPack.allocPacket()
			LDataPack.writeInt(npack, guildId)
			LDataPack.writeByte(npack, smGuildLeader)
			LDataPack.writeString(npack, "")
			System.sendOffMsg(targetId, 0, OffMsgType_GuildInfo, npack)
		end
		
	elseif pos == smGuildAssistLeader then -- 任命副盟主		
		if targetActor then
			LActor.changeGuildInfo(targetActor, guildId, smGuildAssistLeader)
			actorevent.onEvent(targetActor, aeChangeGuildPos, smGuildAssistLeader, smGuildCommon)
			common.sendBasicInfo(targetActor)
		else
			local npack = LDataPack.allocPacket()
			LDataPack.writeInt(npack, guildId)
			LDataPack.writeByte(npack, smGuildAssistLeader)
			LDataPack.writeString(npack, "")
			System.sendOffMsg(targetId, 0, OffMsgType_GuildInfo, npack)
		end
	else -- 降职
		if targetActor then
			LActor.changeGuildInfo(targetActor, guildId, smGuildCommon)
			actorevent.onEvent(targetActor, aeChangeGuildPos, smGuildCommon, smGuildAssistLeader)
			common.sendBasicInfo(targetActor)
		else
			local npack = LDataPack.allocPacket()
			LDataPack.writeInt(npack, guildId)
			LDataPack.writeByte(npack, smGuildCommon)
			LDataPack.writeString(npack, "")
			System.sendOffMsg(targetId, 0, OffMsgType_GuildInfo, npack)
		end
	end
	if actor then
		local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_ChangePos)
		if not pack then return end
		LDataPack.writeInt(pack, targetId)
		LDataPack.writeByte(pack, pos)
		LDataPack.flush(pack)
	end
end

local function sendExitGuild(actor, targetId)
	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_Exit)
	LDataPack.writeInt(pack, targetId)
	LDataPack.flush(pack)
end

-- 踢出
function handleKick(actor, packet)
	if shielding then 
		return
	end
	local targetId = LDataPack.readInt(packet)

	local guildPos = LActor.getGuildPos(actor)
	if guildPos ~= smGuildLeader and guildPos ~= smGuildAssistLeader then
		log_actor(actor, "guild pos error : "..guildPos)
		return
	end

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetKick)
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	LDataPack.writeInt(npack, LActor.getGuildId(actor))
	LDataPack.writeInt(npack, targetId)
	System.sendPacketToAllGameClient(npack, 0)
end

local function onGetKick(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)
	local targetId = LDataPack.readInt(cpack)

	if guildbattlesystem.isBattleTime() then
		return
	end

	local guild = LGuild.getGuildById(guildId)
	if guild == nil then		
		return 
	end

	if not LGuild.isMember(guild, targetId) then
		return
	end

	local name = LGuild.getMemberInfo(guild, targetId)
	if name == nil then
		return 
	end

	LGuild.deleteMember(guild, targetId)
	LGuild.addGuildLog(guild, GuildLogType.ltLeft, name)
	dartcross.onDeleteMember(guildId, targetId)

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendKick)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeInt(npack, targetId)
	LDataPack.writeInt(npack, guildId)
	System.sendPacketToAllGameClient(npack, 0)	
end

local function onSendKick(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local targetId = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)

	local actor = LActor.getActorById(actorid)
	local targetActor = LActor.getActorById(targetId)
	if targetActor ~= nil then
		LActor.changeGuildInfo(targetActor, 0, smGuildCommon)
		sendExitGuild(targetActor, targetId)
		actorevent.onEvent(targetActor, aeNotifyFacade, -1)
	else
		local npack = LDataPack.allocPacket()
		LDataPack.writeInt(npack, 0)
		LDataPack.writeByte(npack, 0)
		LDataPack.writeString(npack, "")
		System.sendOffMsg(targetId, 0, OffMsgType_GuildInfo, npack)
	end
	if actor then
		sendExitGuild(actor, targetId)
	end

	local mailData = {head=GuildConfig.kickMailTitle, context = GuildConfig.kickMailContext, tAwardList={} }
	mailsystem.sendMailById(targetId, mailData)
end

function handleExit(actor, packet)
	if shielding then 
		return
	end
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetExit)
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	LDataPack.writeInt(npack, LActor.getGuildId(actor))
	LDataPack.writeString(npack, LActor.getName(actor))
	System.sendPacketToAllGameClient(npack, 0)	
end

local function onGetExit(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)
	local name = LDataPack.readString(cpack)

	if guildbattlesystem.isBattleTime() then
		return
	end

	local guild = LGuild.getGuildById(guildId)
	if guild == nil then print("guild is nil") return end

	local isLeader = (LGuild.getLeaderId(guild) == actorid)

	LGuild.deleteMember(guild, actorid) -- 玩家都是在线的，不会走到异步流程，下面获得的人数是正确的
	LGuild.addGuildLog(guild, GuildLogType.ltLeft, name)
	dartcross.onDeleteMember(guildId, actorid)

	if LGuild.getGuildMemberCount(guild) <= 0 then		
		guildbattleapply.deleteGuild(guildId)
		LGuild.deleteGuild(guild, "no member")
		common.sendGuildBasicInfo()		
	elseif isLeader then
		-- 如果是盟主,盟主之位自动转移给历史贡献最大的战盟成员，如果贡献度一样，则按玩家id来
		local newLeaderId = LGuild.getLargestContribution(guild)
		if newLeaderId ~= 0 then
			LGuild.changeGuildPos(guild, newLeaderId, smGuildLeader)
			sendChangeGuildPos(newLeaderId, sId, guildId, smGuildLeader)
		end		
	end	
	sendChangeGuildPos(actorid, sId, 0, 0, "")

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendExit)
	LDataPack.writeInt(npack, actorid)
	System.sendPacketToAllGameClient(npack, sId)	
end

local function onSendExit(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorid)
	if actor then
		sendExitGuild(actor, actorid)
		actorevent.onEvent(actor, aeNotifyFacade, -1)
	end
end

-- 获取捐献次数
local function getDanoteCount(actor, index)
	local actorData = common.getActorVar(actor)
	local danoteCounts = actorData.danoteCounts
	if danoteCounts == nil then return 0 end

	return danoteCounts[index] or 0
end

-- 获取对应vip每日最大捐献次数
local function getDonateDayCount(index, vip)
	local conf = GuildDonateConfig[index]
	if conf == nil then print("conf is nil") return 0 end

	if vip == nil then return 0 end

	if #conf.dayCount == 1 then
		return conf.dayCount[1]
	end

	local dayCount = conf.dayCount[vip+1]
	if dayCount then
		return dayCount
	else
		dayCount = conf.dayCount[#conf.dayCount]
		if not dayCount then
			print("vip count is nil" .. index .. ":" .. vip)
			return 0
		end
		return dayCount
	end
end

-- 
function sendLeftDonateCount(actor)
	local actorData = common.getActorVar(actor)
	local danoteCounts = actorData.danoteCounts or {}

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_DonateCount)
	LDataPack.writeByte(pack, #GuildDonateConfig)
	local vip = LActor.getSVipLevel(actor)
	for i=1,#GuildDonateConfig do
		local dayCount = getDonateDayCount(i, vip) or 0
		--print("leftcount", i, vip, dayCount, danoteCounts[i])
		LDataPack.writeInt(pack, dayCount - (danoteCounts[i] or 0))
	end
	LDataPack.flush(pack)
end

local function changeDanoteCount(actor, index, count, isSend)
	local actorData = common.getActorVar(actor)
	local danoteCounts = actorData.danoteCounts
	if danoteCounts == nil then
		actorData.danoteCounts = {}
		danoteCounts = actorData.danoteCounts
	end

	local danoteCount = danoteCounts[index] or 0
	danoteCounts[index] = danoteCount + count
	-- LActor.log(actor, "guildsystem.changeDanoteCount", "make1", danoteCounts[index], index)

	if danoteCounts[index] < 0 then
		danoteCounts[index] = 0
	end

	if isSend then
		sendLeftDonateCount(actor)
	end
end

local function resetDonateCount(actor)
	local actorData = common.getActorVar(actor)
	actorData.danoteCounts = {}
end

-- 捐献
function handleDonate(actor, packet)
	local index = LDataPack.readByte(packet) -- 捐献类型
	local conf = GuildDonateConfig[index]
	if conf == nil then print("conf is nil") return end

	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then print("guild is nil") return end

	local vip = LActor.getSVipLevel(actor)
	local dayCount = getDonateDayCount(index, vip) or 0
	if not dayCount then
		print("vip count is nil" .. vip)
		return
	end

	if getDanoteCount(actor, index) >= dayCount then
		log_actor(actor, "no donate times")
		return 
	end

	if not actoritem.checkItem(actor, conf.id, conf.count) then
		return
	end
	actoritem.reduceItem(actor, conf.id, conf.count, "guild donate")
	changeDanoteCount(actor, index, 1, true)
	actoritem.addItem(actor, NumericType_GuildContrib, conf.awardContri, "guild donate")
	actoritem.addItem(actor, NumericType_GuildFund, conf.awardFund, "guild donate")

	actorevent.onEvent(actor, aeGuildDonate, conf.type, conf.id, conf.count)

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetDonate)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeString(npack, LActor.getName(actor))
	LDataPack.writeInt(npack, conf.id)
	LDataPack.writeInt(npack, conf.count)
	System.sendPacketToAllGameClient(npack, 0)
end

local function onGetDonate(sId, sType, cpack)
	local guildId = LDataPack.readInt(cpack)
	local guild = LGuild.getGuildById(guildId)
	if guild then
		LGuild.addGuildLog(guild, GuildLogType.ltDonate, LDataPack.readString(cpack), "", LDataPack.readInt(cpack), LDataPack.readInt(cpack))
	end
end

-- 发送捐献次数
function handleDonateCount(actor, packet)
	sendLeftDonateCount(actor)
end

-- 获取战盟基本信息
function handleBasicInfo(actor, packet)
	if not isOpen(actor) then return end

	common.sendBasicInfo(actor)
end

-- 修改公告
function handleChangeMemo(actor, packet)
	local memo = LDataPack.readString(packet)
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then
		log_actor(actor, "guild is nil")
		return 
	end
	local sendResult = function(ret, str)
		local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_ChangeMemoResult)
	    LDataPack.writeByte(pack, ret)
	    LDataPack.writeString(pack, str or "")
	    LDataPack.flush(pack)
	end

	local guildPos = LActor.getGuildPos(actor)
	if guildPos ~= smGuildLeader and guildPos ~= smGuildAssistLeader then
		log_actor(actor, "guild pos error : "..guildPos)
		return 
	end
	if System.getStrLenUtf8(memo) > MAX_MEMO_LEN then
		log_actor(actor, "memo len error")
		sendResult(-1)
		return 
	end

	local memo = System.filterText(memo)	
	sendResult(0, memo)
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_ChangeMemo)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeString(npack, memo)
	System.sendPacketToAllGameClient(npack, 0)
end

-- 升级建筑
function handleUpgradeBuilding(actor, packet)
	local index = LDataPack.readByte(packet)
	local buildingConfig = GuildLevelConfig[index]
	if buildingConfig == nil then
		log_actor(actor, "building index error : "..index)
		return
	end

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetUpgradeBuilding)
	LDataPack.writeInt(npack, LActor.getGuildId(actor))
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	LDataPack.writeString(npack, LActor.getName(actor))	
	LDataPack.writeByte(npack, index)
	System.sendPacketToAllGameClient(npack, 0)
end

local function onGetUpgradeBuilding(sId, sType, cpack)
	local guildId = LDataPack.readInt(cpack)
	local actorid = LDataPack.readInt(cpack)
	local name = LDataPack.readString(cpack)
	local index = LDataPack.readByte(cpack)
	
	local guild = LGuild.getGuildById(guildId)
	if guild == nil then print("guild is nil") return end

	local buildingConfig = GuildLevelConfig[index]
	local buildingLevel = common.getBuildingLevel(guild, index)
	if not buildingConfig[buildingLevel + 1] then
		--log_actor(actor, "max level")
		return
	end
	if index ~= 1 then
		local hallLevel = common.getBuildingLevel(guild, 1)
		if buildingLevel >= hallLevel then
			--log_actor(actor, "hall level need")
			return
		end
		if index == 3 and System.getOpenServerDay() + 1 < GuildStoreConfig.day then
			return
		end
	end

	local needFund = buildingConfig[buildingLevel].upFund
	if common.getGuildFund(guild) < needFund then return end

	common.crossChangeGuildFund(actorid, guildId, -needFund)
	buildingLevel = buildingLevel + 1
	-- LActor.log(actor, "guildsystem.changeDanoteCount", "make1", LGuild.getGuildId(guild), buildingLevel, index)
	common.updateBuildingLevel(guild, index, buildingLevel)
	
	-- notifyUpdateGuildInfo(guild, UpdateType.dtBuilding)
	LGuild.addGuildLog(guild, GuildLogType.ltUpgrade, name, "", index, buildingLevel)


    local tips = string.format(GuildConfig.upgradeBuildingNotice, name, GuildConfig.buildingNames[index], buildingLevel)
	guildchat.sendNotice(guild, tips)
	
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendUpgradeBuilding)
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeInt(npack, buildingLevel)
	LDataPack.writeInt(npack, needFund)
	LDataPack.writeByte(npack, index)
	System.sendPacketToAllGameClient(npack, sId)
end

local function onSendUpgradeBuilding(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local buildingLevel = LDataPack.readInt(cpack)
	local needFund = LDataPack.readInt(cpack)
	local index = LDataPack.readByte(cpack)
	
	local actor = LActor.getActorById(actorid)
	if not actor then
		return
	end

	if index == 3 then
		guildstore.storeLevelChange(actor, buildingLevel)
	end

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_UpgradeBuilding)
    LDataPack.writeByte(pack, index)
    LDataPack.writeByte(pack, buildingLevel)
    LDataPack.flush(pack)
end

function onInit(actor)
	LActor.setGuildName(actor, common.getGuilNameById(LActor.getGuildId(actor)))
end

function onLogin(actor, firstlogin, offtime, logout, iscross)
	local guildId = LActor.getGuildId(actor)
	--if guildId == 0 then return end
	if System.isCommSrv() then
		local pack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_GuildInfo)
		LDataPack.writeInt(pack, guildId)
		LDataPack.writeString(pack, common.getGuilNameById(guildId))
		LDataPack.flush(pack)
		sendLeftDonateCount(actor)
		handleGuildInfo(actor)
		--common.sendBasicInfo(actor)
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_ActorLogin)
		LDataPack.writeInt(npack, LActor.getActorId(actor))
		LDataPack.writeInt(npack, guildId)
		local giftEnd = guildgift.getgiftcharge(actor)
		LDataPack.writeShort(npack, giftEnd)
		LDataPack.writeChar(npack, iscross and 1 or 0)
		System.sendPacketToAllGameClient(npack, 0)
	else
		local actorid = LActor.getActorId(actor)
		LGuild.onActorLogin(LActor.getGuildId(actor), actorid)
	end
	LActor.ChannelUser(actor, guildId, 0)
end

function onLogout(actor)
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end

	if System.isCommSrv() then
		local basicData = LActor.getActorData(actor)
		if basicData == nil then return end
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_ActorLogout)
		LDataPack.writeInt(npack, LActor.getActorId(actor))
		LDataPack.writeInt(npack, LActor.getGuildId(actor))	
		LDataPack.writeString(npack, basicData.actor_name)
		LDataPack.writeByte(npack, basicData.job)
		LDataPack.writeByte(npack, basicData.sex)
		LDataPack.writeInt(npack, basicData.level)
		LDataPack.writeDouble(npack, basicData.total_power)
		LDataPack.writeByte(npack, basicData.vip_level)
		LDataPack.writeUInt(npack, basicData.last_online_time)
		System.sendPacketToAllGameClient(npack, 0)		
	else
		local basicData = LActor.getActorData(actor)
		if basicData == nil then return end
		local mInfo = GuildMemberInfo:new_local()
		if mInfo == nil then return end
		mInfo.actorId_ = LActor.getActorId(actor)
		mInfo:setName(basicData.actor_name)
		mInfo.job_ = basicData.job
		mInfo.sex_ = basicData.sex
		mInfo.level_ = basicData.level
		mInfo.fight_ = basicData.total_power
		mInfo.vip_ = basicData.vip_level
		mInfo.lastLogoutTime_ = basicData.last_online_time
		mInfo.pos_ = 0

		LGuild.updateActorData(LGuild.getGuildById(guildId), mInfo)
	end	
	LActor.ChannelUser(actor, guildId, 1)
end

--跨服收到玩家登陆普通服了
local function onActorLogin(sId, sType, cpack)
	if not System.isBattleSrv() then return end
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)	
	local guild = LGuild.getGuildById(guildId)	
	guildbattlesystem.sendWorshipInfo(sId, actorid)
	LGuild.onActorLogin(guildId, actorid, sId, true)
	if guild then
		guildgift.onActorLogin(guild, actorid, sId, LDataPack.readShort(cpack))
		common.sendMemBasicInfo(sId, actorid)
		dartcross.sendPlunderList(sId, actorid)
		guildbattlesystem.onActorLogin(sId, actorid, guildId, LDataPack.readChar(cpack))
		guildboss.checkBossDestroy(guildId)
	end
end

local function onActorLogout(sId, sType, cpack)
	if not System.isBattleSrv() then return end
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)	
	local guild = LGuild.getGuildById(guildId)
	if not guild then return end

	local mInfo = GuildMemberInfo:new_local()
	if mInfo == nil then return end
	mInfo.actorId_ = actorid
	local actorname = LDataPack.readString(cpack)
	mInfo:setName(actorname)
	mInfo.job_ = LDataPack.readByte(cpack)
	mInfo.sex_ = LDataPack.readByte(cpack)
	mInfo.level_ = LDataPack.readInt(cpack)
	mInfo.fight_ = LDataPack.readDouble(cpack)
	mInfo.vip_ = LDataPack.readByte(cpack)
	mInfo.lastLogoutTime_ = LDataPack.readUInt(cpack)
	mInfo.pos_ = 0
	LGuild.updateActorData(guild, mInfo)	
end

function onJoinGuild(actor)
	common.resetContrib(actor)
end

function onLeftGuild(actor)
	common.resetContrib(actor)
end

function onNewDay(actor)
	resetDonateCount(actor)
end

function onCustom(actor, cur, old)
	local custom = actorexp.getLimitCustom(actor,actorexp.LimitTp.guild)
	if custom > old and custom <= cur then
		local conf = GuildConfig
		local mailData = {head=conf.openMailTitle, context=conf.openMaiContent, tAwardList=conf.openMailRewards}
		mailsystem.sendMailById(LActor.getActorId(actor), mailData) --发送战盟开启邮件
	end
end

-- 每天6点根据贡献排职位
function updateAllGuildPos()
	if not System.isBattleSrv() then return end
	print("updateAllGuildPos")
	local guildList = LGuild.getGuildList()
	if guildList == nil then return end

	for i=1,#guildList do
		local guild = guildList[i]
		LGuild.updateGuildPos(guild)
	end
end

-- 每天凌晨清数据
function updateGuildData()
	if not System.isBattleSrv() then return end
	local guildList = LGuild.getGuildList()
	if guildList == nil then return end

	for i=1,#guildList do
		local guild = guildList[i]
		LGuild.resetTodayContrib(guild)
		--guildfuben.clearGuildfbVar(guild)
	end
end

-- 战盟脚本数据加载完成后的处理
function onLoadGuildVar(guild)
	if not System.isBattleSrv() then return end
	common.initBuildingLevel(guild, GuildCreateConfig[1].buildingLevels)
	guildboss.initGuildBoss(guild)
end

-- 战盟数据加载完成后的处理
function onLoadGuild(guild)
	if not System.isBattleSrv() then return end
	-- 
end

_G.updateGuildData = updateGuildData
_G.updateAllGuildPos = updateAllGuildPos

local function OffMsgGuildInfo(actor, packet)	
	local guildId = LDataPack.readInt(packet)
	local pos = LDataPack.readByte(packet)
	local name = LDataPack.readString(packet)
	local beforeid = LActor.getGuildId(actor)
	if beforeid ~= 0 and guildId == 0 then
		LActor.onLeftGuild(actor, guildId)
	elseif guildId ~= 0 and beforeid == 0 then
		LActor.onJoinGuild(actor, guildId, pos, name)
	end
	LActor.changeGuildInfo(actor, guildId, pos, name)
end

local function onSetGuildInfo(actorid, sId, newGuildId, pos, name)
	if sId ~= 0 then
		sendChangeGuildPos(actorid, sId, newGuildId, pos, name)
	end
end


actorevent.reg(aeUserLogin, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeUserLogout, onLogout)
actorevent.reg(aeJoinGuild, onJoinGuild)
actorevent.reg(aeLeftGuild, onLeftGuild)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeCustomChange, onCustom)

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetGuildInfo, onGetGuildInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendGuildInfo, onSendGuildInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetGuildCreate, onGetGuildCreate)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendGuildCreate, onSendGuildCreate)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendGuildTip, onSendGuildTip)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetAutoApprove, onGetAutoApprove)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendAutoApprove, onSendAutoApprove)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetApplyJoin, onGetApplyJoin)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendApplyJoin, onSendApplyJoin)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetRespondJoin, onGetRespondJoin)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendRespondJoin, onSendRespondJoin)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetImpeach, onGetImpeach)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendImpeach, onSendImpeach)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetChangePos, onGetChangePos)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendChangePos, onSendChangePos)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetKick, onGetKick)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendKick, onSendKick)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetExit, onGetExit)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendExit, onSendExit)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetDonate, onGetDonate)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_ChangeMemo, onChangeMemo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetUpgradeBuilding, onGetUpgradeBuilding)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendUpgradeBuilding, onSendUpgradeBuilding)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendJoinGuild, onSendJoinGuild)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_ChangeGuildPos, onChangeGuildPos)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_ActorLogin, onActorLogin)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_ActorLogout, onActorLogout)	
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetOtherActor, onGetOtherActor)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendOtherActor, onSendOtherActor)


local function init()
	if System.isCrossWarSrv() then return end
	msgsystem.regHandle(OffMsgType_GuildInfo, OffMsgGuildInfo)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_GuildInfo, handleGuildInfo)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_CreateGuild, handleCreateGuild)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ExitGuild, handleExit)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ApplyJoin, handleApplyJoin)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_RespondJoin, handleRespondJoin)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ChangePos, handleChangePos)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_Impeach, handleImpeach)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_Kick, handleKick)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_Donate, handleDonate)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ChangeMemo, handleChangeMemo)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_SkillInfo, guildskill.handleSkillInfo)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_UpgradeSkill, guildskill.handleUpgradeSkill)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_PracticeBuilding, guildskill.handlePracticeSkill)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_UpgradeBuilding, handleUpgradeBuilding)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_DonateCount, handleDonateCount)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_BasicInfo, handleBasicInfo)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_AutoApprove, handleAutoApprove)
end

table.insert(InitFnTable, init)


_G.onLoadGuild = onLoadGuild
_G.onLoadGuildVar = onLoadGuildVar
_G.setGuildInfo = onSetGuildInfo

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.upgradeBuilding = function(actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1] or 1)
	LDataPack.setPosition(pack, 0)
	handleUpgradeBuilding(actor, pack)
end


--local gmsystem    = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.testguild = function(actor, args)
	handleImpeach(actor)
end
-- gmCmdHandlers.testguild = function(actor, args)
-- 	-- local dp = LDataPack.allocPacket()
-- 	-- LDataPack.writeByte(dp, 1)
-- 	-- LDataPack.writeString(dp, "fffxx")
-- 	-- LDataPack.setPosition(dp, 0)

-- 	-- handleCreateGuild(actor, dp)

-- 	-- common.changeContrib(actor, 100)
-- 	-- local guild = LActor.getGuildPtr(actor)
-- 	-- common.changeGuildFund(guild, 1000)
-- 	-- updateAllGuildPos()

-- 	-- local content = args[1] or ""

-- 	-- local guild = LActor.getGuildPtr(actor)
-- 	-- if guild == nil then print("guild is nil") return end

-- 	-- guildchat.sendNotice(guild, content)

-- 	-- print(LActor.getGuildId(actor))
-- 	-- updateGuildData()
-- 	-- updateAllGuildPos()

-- 	local value = (args[1] and tonumber(args[1]) or 0)
-- 	common.changeContrib(actor, value, "gmtest")
-- end

-- -- 删除战盟
-- -- @delguild 战盟名
-- gmCmdHandlers.delguild = function(actor, args)
-- 	local name = args[1]
-- 	if name == nil then
-- 		print("param error")
-- 		return 
-- 	end
-- 	local guild = LGuild.getGuildByName(name)
-- 	if guild == nil then
-- 		print("guild is nil")
-- 		return 
-- 	end

-- 	LGuild.deleteGuild(guild, "gm")
-- end

-- -- 修改职位
-- -- @changeguildpos 战盟名 玩家ID 职位
-- gmCmdHandlers.changeguildpos = function(actor, args)
-- 	local guildName, actorId, pos = args[1], args[2], args[3]
-- 	if guildName == nil or actorId == nil or pos == nil then
-- 		print("param error")
-- 		return 
-- 	end

-- 	local guild = LGuild.getGuildByName(guildName)
-- 	if guild == nil then
-- 		print("guild is nil")
-- 		return 
-- 	end

-- 	actorId = tonumber(actorId)
-- 	pos = tonumber(pos)

-- 	LGuild.changeGuildPos(guild, actorId, pos)
-- end

-- -- 删除战盟成员
-- -- @delguildmember 战盟名 玩家ID
-- gmCmdHandlers.delguildmember = function(actor, args)
-- 	local name, actorId = args[1], args[2]
-- 	if name == nil then
-- 		print("param error")
-- 		return false
-- 	end
-- 	local guild = LGuild.getGuildByName(name)
-- 	if guild == nil then
-- 		print("guild is nil")
-- 		return false
-- 	end

-- 	actorId = tonumber(actorId)

-- 	LGuild.deleteMember(guild, actorId)

-- 	return true
-- end

-- -- 添加战盟成员(需要在线)
-- -- @addguildmember 战盟名 玩家ID 职位
-- gmCmdHandlers.addguildmember = function(actor, args)
-- 	local name, actorId, pos = args[1], args[2], args[3]
-- 	if name == nil then
-- 		print("param error")
-- 		return false
-- 	end
-- 	local guild = LGuild.getGuildByName(name)
-- 	if guild == nil then
-- 		print("guild is nil")
-- 		return false
-- 	end

-- 	actorId = tonumber(actorId)
-- 	pos = (pos and tonumber(pos) or smGuildCommon)

-- 	local target = LActor.getActorById(actorId)
-- 	if target == nil then
-- 		print("target is offline")
-- 		return 
-- 	end

-- 	LGuild.addMember(guild, target, pos)

-- 	return true
-- end

