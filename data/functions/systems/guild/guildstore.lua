-- 公会商店
module("guildstore", package.seeall)

local LActor = LActor
local LDataPack = LDataPack
local LGuild = LGuild

local guildStoreIndex = 3  -- 公会商店索引
local logType = 9          --guildsystem.GuildLogType.ltStore
local storeQuality = 3		--开宝箱记录品质（紫色或以上）

GUILD_STORE_LOG = GUILD_STORE_LOG or {}

local function getGuildStoreLevel(actor)
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return -1 end

	local storeLevel = guildcommon.getBuildingLevelById(guildId, guildStoreIndex)
	return storeLevel
end

local function initVar(actor, var)
	var.lastGuildId = LActor.getGuildId(actor)
	local storeLevel = getGuildStoreLevel(actor)
	var.lastTime = GuildStoreConfig.time[storeLevel] or 0
	var.curDayTime = 0
	var.sumTime = var.sumTime or GuildStoreConfig.initTime
end

local function getGuildStoreVar(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then
        return nil
    end

    if var.guildstoreVare == nil then
        var.guildstoreVare = {}
        var.guildstoreVare.lastGuildId = 0 --上一个公会id
        var.guildstoreVare.lastTime = 0 --上一个公会次数
        var.guildstoreVare.curDayTime = 0 --当天已用次数
        var.guildstoreVare.sumTime = GuildStoreConfig.initTime    --已用次数统计

        initVar(actor, var.guildstoreVare)
    end
    return var.guildstoreVare
end

local function isOpen(actor)
	if System.getOpenServerDay() + 1 < GuildStoreConfig.day then
		return false
	end
	return true
end

local function getGuildStoreConfDayTime(actor)
	local var = getGuildStoreVar(actor)
	if var == nil then return 0 end

	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end

	if var.lastGuildId ~= 0 and var.lastGuildId ~= guildId then
		return var.lastTime
	end

	local storeLevel = getGuildStoreLevel(actor)
	return GuildStoreConfig.time[storeLevel] or 0
end

-- 
local function handleGetCommInfo(actor, packet)
	local var = getGuildStoreVar(actor)
	if var == nil then return end

	local storeLevel = getGuildStoreLevel(actor)
	if storeLevel == -1 then return end

	local confTime = getGuildStoreConfDayTime(actor)
	local dayTime = confTime - var.curDayTime
	if dayTime < 0 then dayTime = 0 end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildStore, Protocol.sGuildStoreCmd_CommInfo)
	if pack == nil then return end
	LDataPack.writeData(pack, 2, dtByte, storeLevel, dtByte, dayTime)
	LDataPack.flush(pack)
	-- print("===============",var.lastGuildId,var.lastTime,storeLevel,confTime,var.curDayTime,dayTime)
end

-- 获取记录
local function handleGetLog(actor, packet)
	local lastTime = LDataPack.readUInt(packet)

	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetStoreLog)	
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	System.sendPacketToAllGameClient(npack, 0)
end

local function getdropGroupId(actor,var)
	local level = LActor.getLevel(actor)

	local config = GuildStoreLevelConfig[level]
	if config == nil or not next(config) then 
		print("not level config " .. level);
		return 0
	end
	local index = 0
	for i,v in pairs(config.cumulativeDropGroupId) do 
		if math.floor(var.sumTime % v.count) == 0 then 
			index = i
		end
	end

	if index == 0 then
		return config.dropGroupId
	else 
		return config.cumulativeDropGroupId[index].dropGroupId
	end
end

local function onGetStoreLog(sId, sType, cpack)
	sendStoreLog(sId, LDataPack.readInt(cpack))
end

function sendStoreLog(sId, actorid)
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_SendStoreLog)	
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeByte(npack, #GUILD_STORE_LOG)
	for i=1, #GUILD_STORE_LOG do
		LDataPack.writeUInt(npack, GUILD_STORE_LOG[i].time)
		LDataPack.writeString(npack, GUILD_STORE_LOG[i].name)
		LDataPack.writeInt(npack, GUILD_STORE_LOG[i].id)
	end
	System.sendPacketToAllGameClient(npack, sId)
end

local function onSendStoreLog(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorid)
	if not actor then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildStore, Protocol.sGuildStoreCmd_Log)
	local count = LDataPack.readByte(cpack)
	LDataPack.writeByte(pack, count)
	for i=1, count do
		LDataPack.writeUInt(pack, LDataPack.readUInt(cpack))
		LDataPack.writeString(pack, LDataPack.readString(cpack))
		LDataPack.writeInt(pack, LDataPack.readInt(cpack))
	end
	LDataPack.flush(pack)
end

local function onUpdateStoreLog(sId, sType, cpack)
	local actorid = LDataPack.readInt(cpack)
	local guildId = LDataPack.readInt(cpack)
	local name = LDataPack.readString(cpack)
	local count = LDataPack.readByte(cpack)
	local guild = LGuild.getGuildById(guildId)
	if not guild then
		return
	end

	local itemList = {}
	for i=1, count do
		local id = LDataPack.readInt(cpack)
		-- 追加公会事件
		LGuild.addGuildLog(guild, logType, name,"", id)
		-- 公会频道
		local tips = string.format(ScriptTips.guildbox1, name, actoritem.getColor(id), ItemConfig[id].name[1])
		guildchat.sendNotice(guild, tips)
		-- 追加记录
		local time = System.getNowTime() - 1
		table.insert(GUILD_STORE_LOG, 1, {time = System.getNowTime(), name = name, id = id})
		if #GUILD_STORE_LOG > 50 then
			table.remove(GUILD_STORE_LOG)
		end
		-- 同步客户端记录
		sendStoreLog(sId, actorid)
	end
end

local function sendAwardList(actor, guildId, awardList)
	local actorid = LActor.getActorId(actor)
	local name = LActor.getName(actor)
	local itemList = {}
	local tmpList = {}
	for _,tb in pairs(awardList) do
		actoritem.addItem(actor, tb.id, tb.count, "guildstore handleUnpack")
		if tb.type ~= AwardType_Numeric then
			table.insert(itemList, tb)
        end
		if tb.type == AwardType_Item and ItemConfig[tb.id] and ItemConfig[tb.id].quality >= storeQuality then
			table.insert(tmpList, tb.id)
        end
	end
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_UpdateStoreLog)	
	LDataPack.writeInt(npack, actorid)
	LDataPack.writeInt(npack, guildId)
	LDataPack.writeString(npack, name)
	LDataPack.writeByte(npack, #tmpList)
	for i=1, #tmpList do
		LDataPack.writeInt(npack, tmpList[i])
	end
	System.sendPacketToAllGameClient(npack, 0)

	return itemList
end

-- 开箱
local function handleUnpack(actor, packet)
	if not isOpen() then return end

	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end

	local var = getGuildStoreVar(actor)
	if var == nil then return end

	local confTime = getGuildStoreConfDayTime(actor)
	local dayTime = confTime - var.curDayTime
	if dayTime <= 0 then
		return
	end

	local needContrib = GuildStoreConfig.needContrib
	local haveContrib = guildcommon.getContrib(actor)
	if needContrib > haveContrib then
		return
	end

	local dropGroupId = getdropGroupId(actor,var)
	if DropGroupConfig[dropGroupId] == nil then return end

	if LActor.getEquipBagSpace(actor) < #DropGroupConfig[dropGroupId] then
		LActor.sendTipmsg(actor, string.format(ScriptTips.bag01), ttScreenCenter)
		return
	end

	local awardList = drop.dropGroup(dropGroupId)
	if awardList == nil or next(awardList) == nil then return end

	if not actoritem.checkEquipBagSpaceJob(actor, awardList) then
		LActor.sendTipmsg(actor, string.format(ScriptTips.bag01), ttScreenCenter)
		return
	end

	--扣贡献，下发道具
	guildcommon.changeContrib(actor,-needContrib, "store")
	var.curDayTime = var.curDayTime + 1
	var.sumTime = var.sumTime + 1
	-- LActor.log(actor, "guildstore.handleUnpack", "make1", var.curDayTime, var.sumTime)
	local itemList = sendAwardList(actor, guildId, awardList)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildStore, Protocol.sGuildStoreCmd_Unpack)
	if pack == nil then return end

	LDataPack.writeByte(pack, #itemList)
	for _,tb in ipairs(itemList) do
		LDataPack.writeData(pack, 2, dtInt, tb.id,	dtInt, tb.count)
	end
	LDataPack.flush(pack)
end

local function onNewDay(actor, login)
	local var = getGuildStoreVar(actor)
	if var == nil then return end

	local guildId = LActor.getGuildId(actor)
	--零点重置次数
	var.curDayTime = 0

	--公会当天零点重置
	if guildId ~= var.lastGuildId then
		initVar(actor, var)
		return 
	end
end

local function onLogin(actor)
	handleGetCommInfo(actor)
end

local function onJoinGuild(actor)
	local var = getGuildStoreVar(actor)
	if var == nil then return end

	if var.lastGuildId == 0 then
		initVar(actor, var)
		return
	end
	local storeLevel = getGuildStoreLevel(actor)
	local curConfTime = GuildStoreConfig.time[storeLevel] or 0
	if curConfTime > var.lastTime then return end
	var.lastTime = curConfTime
end

local function onLeftGuild(actor)
	local var = getGuildStoreVar(actor)
	if var == nil then return end

	local oldStoreLevel = guildcommon.getBuildingLevelById(var.lastGuildId or 0, guildStoreIndex)
	local lastTime = GuildStoreConfig.time[oldStoreLevel] or 0
	var.lastTime = lastTime
end

function storeLevelChange(actor, storeLevel)
	local var = getGuildStoreVar(actor)
	if var == nil then return 0 end

	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end

	if var.lastGuildId ~= 0 and var.lastGuildId ~= guildId then
		local confTime = GuildStoreConfig.time[storeLevel] or 0
		local diff = confTime - var.lastTime
		if diff > 0 then var.lastTime = var.lastTime + diff end
	end
end


actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeJoinGuild, onJoinGuild)
actorevent.reg(aeLeftGuild, onLeftGuild)

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendStoreLog, onSendStoreLog)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_UpdateStoreLog, onUpdateStoreLog)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetStoreLog, onGetStoreLog)

local function init()
	if System.isCrossWarSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_GuildStore, Protocol.cGuildStoreCmd_CommInfo, handleGetCommInfo)
	netmsgdispatcher.reg(Protocol.CMD_GuildStore, Protocol.cGuildStoreCmd_Log, handleGetLog)
	netmsgdispatcher.reg(Protocol.CMD_GuildStore, Protocol.cGuildStoreCmd_Unpack, handleUnpack)
end

table.insert(InitFnTable, init)



-- local gmsystem    = require("systems.gm.gmsystem")
-- local gmCmdHandlers = gmsystem.gmCmdHandlers

-- gmCmdHandlers.guildstore = function(actor, args)
-- 	handleGetCommInfo(actor)
-- end

-- gmCmdHandlers.guildstorelog = function(actor, args)
-- 	handleGetLog(actor)
-- end

-- gmCmdHandlers.guildstoreunpack = function(actor, args)
-- 	handleUnpack(actor)
-- end

