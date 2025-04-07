--守护商城
module("subactivity18", package.seeall)

local subType = 18

local function getActorVar(actor, id)
	local var = activitymgr.getSubVar(actor, id)
	if (var == nil) then return end
	var = var.data
	
	if not var.storelimit then var.storelimit = {}	end
	return var
end

local function updateInfo(actor, id)
	local var = getActorVar(actor, id)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Store18Info)
	if npack == nil then return end

	LDataPack.writeInt(npack, id)
	LDataPack.writeChar(npack, #ActivityType18Config[id])
	for k,v in ipairs(ActivityType18Config[id]) do
		LDataPack.writeShort(npack, var.storelimit[k] or 0)
	end

	LDataPack.flush(npack)
end


subactivitymgr.actorLoginFuncs[subType] = function(actor, type, id)
	if activitymgr.activityTimeIsOver(id) then return end
	updateInfo(actor, id)
end

--登录协议回调(为免客户端读错，每个活动类型都有)
function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	-- local v = record and record.data and record.data.rewardsRecord or 0
	-- LDataPack.writeInt(npack, v)
	LDataPack.writeInt(npack, 0)
end

function onAfterNewDay(actor)
	for id in pairs(ActivityType18Config) do
		if not activitymgr.activityTimeIsEnd(id) then
			updateInfo(actor, id)
		end
	end
end

function onBeforeNewDay(actor)
	for id in pairs(ActivityType18Config) do
		if not activitymgr.activityTimeIsEnd(id) then
			local var = getActorVar(actor, id)
			for k,v in ipairs(ActivityType18Config[id]) do
				if v.limit.type == 1 then
					var.storelimit[k] = 0
				end
			end
		end
	end
end

function c2sBuy(actor, pack)
	local id = LDataPack.readInt(pack)
	if not ActivityType18Config[id] then return end
	if activitymgr.activityTimeIsEnd(id) then return end
	local index = LDataPack.readChar(pack)
	local buycount = LDataPack.readShort(pack)
	local config = ActivityType18Config[id][index]
	if not config then return end

	local var = getActorVar(actor, id)
	if LActor.getSVipLevel(actor) < config.vip then return end
	if config.limit.type ~= 0 and (var.storelimit[index] or 0) + buycount > config.limit.count then return end
	if not actoritem.checkItem(actor, config.currencyType, config.price * buycount) then
		return false
	end
	var.storelimit[index] = (var.storelimit[index] or 0) + buycount
	actoritem.reduceItem(actor, config.currencyType, config.price * buycount, "act18 buy")
	for k,v in ipairs(config.rewards) do
		actoritem.addItem(actor, v.id, v.count * buycount, "act18 buy")	
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Buy18Ret)
	LDataPack.writeInt(npack, id)
	LDataPack.writeChar(npack, index)
    LDataPack.writeShort(npack, var.storelimit[index])
    LDataPack.flush(npack)
end

function init()
	if System.isCrossWarSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Buy18, c2sBuy)
	subactivitymgr.regNewDayAfterFunc(subType, onAfterNewDay)
	subactivitymgr.regNewDayFunc(subType, onBeforeNewDay)
end

table.insert(InitFnTable, init)

subactivitymgr.regWriteRecordFunc(subType, writeRecord)

local gmCmdHandlers = gmsystem.gmCmdHandlers
function gmCmdHandlers.act18new(actor, args)
	for id in pairs(ActivityType18Config) do
		if not activitymgr.activityTimeIsEnd(id) then
			local var = getActorVar(actor, id)
			for k,v in ipairs(ActivityType18Config[id]) do
				if v.limit.type == 1 then
					var.storelimit[k] = 0
				end
			end
			updateInfo(actor, id)
		end
	end
	return true
end


