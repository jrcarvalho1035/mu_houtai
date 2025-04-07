module("subactivity13", package.seeall)
--飞升抢购
local subType = 13

ACTIVITY13_TOTAL_GET_COUNT = ACTIVITY13_TOTAL_GET_COUNT or {} --全服已购买数量


local function getActorVar(actor, id)
	local var = activitymgr.getSubVar(actor, id)
	if (var == nil) then return end
	var = var.data
    if not var.getcount then var.getcount = 0 end
	return var
end

local function getGlobalData(id)
	local var = activitymgr.getGlobalVar(id)
	if not var then return end
    if not var.totalgetcount then var.totalgetcount = 0 end   
	return var
end

--登录协议回调
function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	local v = record and record.data and record.data.rewardsRecord or 0
	local var = getActorVar(actor, id)
	LDataPack.writeShort(npack, var.getcount)
	LDataPack.writeShort(npack, ACTIVITY13_TOTAL_GET_COUNT[id] or 0)
end

--领取奖励
local function onGetReward(actor, config, id, idx, record)
	local config = config[id][1]
	local var = getActorVar(actor, id)

	if var.getcount >= config.cancount then
		return false
	end
	if not ACTIVITY13_TOTAL_GET_COUNT[id] then
		ACTIVITY13_TOTAL_GET_COUNT[id] = 0
	end
	if ACTIVITY13_TOTAL_GET_COUNT[id] >= config.totalcount then
		LActor.sendTipmsg(actor, ScriptTips.mssys016, ttScreenCenter)
		s2cUpdateTotalCount(actor, id)
		return false
	end

	if not actoritem.checkItem(actor, NumericType_YuanBao, config.needyuanbao) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, config.needyuanbao, "activity13 buy:"..id)

	var.getcount = var.getcount + 1
	actoritem.addItems(actor, config.rewards, "activity13 buy item"..id)
  
	updateTotalCount(id)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	LDataPack.writeByte(npack, 1)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, idx)
	LDataPack.writeShort(npack, var.getcount)
	LDataPack.writeShort(npack, ACTIVITY13_TOTAL_GET_COUNT[id] + 1)
	LDataPack.flush(npack)
end

function updateTotalCount(id)
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, CrossSrvCmd.SCAcitivity13Cmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCAcitivity13Cmd_UpdateGetCount)
	LDataPack.writeInt(pack, id)
	System.sendPacketToAllGameClient(pack, 0)
end

local function onUpdateGetCount(sId, sType, cpack)
	local id = LDataPack.readInt(cpack)
	local gvar = getGlobalData(id)
	gvar.totalgetcount = gvar.totalgetcount + 1
	local maxcount = ActivityType13Config[id] and ActivityType13Config[id][1].totalcount or 0
	if maxcount > 0 and gvar.totalgetcount > maxcount then
		gvar.totalgetcount = maxcount
	end
	sendActivityCount(id)
end

function sendActivityCount(id)
	local pack = LDataPack.allocPacket()	
	if pack == nil then return end	
	local gvar = getGlobalData(id)
	LDataPack.writeByte(pack, CrossSrvCmd.SCAcitivity13Cmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCAcitivity13Cmd_SendGetCount)
	LDataPack.writeInt(pack, id)
	LDataPack.writeShort(pack, gvar.totalgetcount)
	System.sendPacketToAllGameClient(pack, 0)
end

function onGetTotalGetCount(sId, sType, cpack)
	if System.isBattleSrv() then return end	
	local id = LDataPack.readInt(cpack)
	local count = LDataPack.readShort(cpack)
	ACTIVITY13_TOTAL_GET_COUNT[id] = count
end

function onConnected(sId, sType)
	if System.isBattleSrv() then
		for id,v in pairs(ActivityType13Config) do
			if not activitymgr.activityTimeIsEnd(id) then
				sendActivityCount(id)
			end
		end
	end    
end

function onActivityFinish(id)
	if System.isBattleSrv() then
		local gvar = getGlobalData(id)
		gvar.totalgetcount = 0
	else
		ACTIVITY13_TOTAL_GET_COUNT[id] = 0
	end

    local actors = System.getOnlineActorList()
	if actors then
		for i = 1, #actors do
			local actor = actors[i]
			if actor then
				local var = getActorVar(actor, id)
				var.getcount = 0
			end
		end
	end    
end

function c2sUpdateTotalCount(actor, pack)
	local id = LDataPack.readInt(pack)
	s2cUpdateTotalCount(actor, id)
end

function s2cUpdateTotalCount(actor, id)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Update13)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, ACTIVITY13_TOTAL_GET_COUNT[id] or 0)
	LDataPack.flush(npack)
end

netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Update13, c2sUpdateTotalCount)
csmsgdispatcher.Reg(CrossSrvCmd.SCAcitivity13Cmd, CrossSrvSubCmd.SCAcitivity13Cmd_UpdateGetCount, onUpdateGetCount)
csmsgdispatcher.Reg(CrossSrvCmd.SCAcitivity13Cmd, CrossSrvSubCmd.SCAcitivity13Cmd_SendGetCount, onGetTotalGetCount)
--subactivitymgr.regActivityFinish(subType, onActivityFinish)
csbase.RegConnected(onConnected)
subactivitymgr.regGetRewardFunc(subType, onGetReward)
subactivitymgr.regWriteRecordFunc(subType, writeRecord)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.act13Reset = function (actor, args)
	if not System.isBattleSrv() then return end
	for id, conf in pairs(ActivityType13Config) do
		local var = getGlobalData(id)
		var.totalgetcount = 0
		sendActivityCount(id)
	end
	return true
end
