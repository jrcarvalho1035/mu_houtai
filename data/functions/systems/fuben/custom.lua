-- @version	1.0
-- @author	qianmeng
-- @date	2017-7-27 17:35:13
-- @system	守关副本

module("custom", package.seeall)
require "worldmap.customfuben"

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.customData then 
		var.customData = {
			curId = 0,
		} 
	end
	return var.customData
end

--已完成的关卡
function getCustomId(actor)
	local var = getActorVar(actor)
	return var.curId
end

--检查是否可以进入副本
function checkEnterFuben(actor, idx)
	if not actor then return end
	local var = getActorVar(actor)
	local conf = CustomFubenConfig[idx]
	if not conf then return false end
	if var.curId + 1 < idx then return false end--前置副本限制
	return true
end

--进入副本
function onEnterFuben(actor, idx)
	if not checkEnterFuben(actor, idx) then return end
	local conf = CustomFubenConfig[idx]
	if not utils.checkFuben(actor, conf.fbId) then return end
	local fbHandle = instancesystem.createFuBen(conf.fbId)
	if not fbHandle or fbHandle == 0 then return end
	local x, y = utils.getSceneEnterCoor(conf.fbId)
	LActor.enterFuBen(actor, fbHandle, 0, x, y)
end

--挑战通关
function onCustomWin(ins)
	local actor = ins:getActorList()[1]
	local var = getActorVar(actor)
	if not var then return end

	local idx
	for key, conf in pairs(CustomFubenConfig) do
		if conf.fbId == ins.id then
			idx = key
			break
		end
	end
	if not idx then return end
	if var.curId < idx then
		var.curId = idx
	end

	s2cCustomInfo(actor)
	actorevent.onEvent(actor, aeBeatMapBoss, idx)
end

local function onLogin(actor)
	s2cCustomInfo(actor, true)
end

function getMaxFubenId(actor)
	local var = getActorVar(actor)
	return CustomFubenConfig[var.curId].maxfuben
end
---------------------------------------------------------------------------------------------
function s2cCustomInfo(actor, islogin)
	local var = getActorVar(actor)
	local curId = var.curId
	if CustomFubenConfig[curId+1] then
		curId = curId + 1
	end
	local bossId = CustomFubenConfig[curId].bossId
	local conf = MonstersConfig[bossId]
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_CustomInfo)
	LDataPack.writeInt(pack, var.curId + 1)
	LDataPack.writeShort(pack, conf.avatar)
	LDataPack.writeString(pack, conf.name)
	LDataPack.writeChar(pack, islogin and 1 or 0)
	LDataPack.flush(pack)
end

--挑战守关boss
function c2sCustomFight(actor, packet)
	local var = getActorVar(actor)
	local idx = var.curId
	if CustomFubenConfig[idx+1] then
		onEnterFuben(actor, idx+1)
	end
end


local function init()
	if System.isBattleSrv() then return end
	for _, conf in pairs(CustomFubenConfig) do
		insevent.registerInstanceWin(conf.fbId, onCustomWin)
	end
	actorevent.reg(aeUserLogin, onLogin)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_CustomFight, c2sCustomFight)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.customEnter = function (actor, args)
	local var = getActorVar(actor)
	local idx = tonumber(args[1])
	local conf = CustomFubenConfig[idx]
	local fbHandle = instancesystem.createFuBen(conf.fbId)
	if not fbHandle or fbHandle == 0 then return end
	local x, y = utils.getSceneEnterCoor(conf.fbId)
	LActor.enterFuBen(actor, fbHandle, 0, x, y)
end

gmCmdHandlers.customset = function (actor, args)
	local var = getActorVar(actor)
	var.curId = tonumber(args[1])
	s2cCustomInfo(actor)
end
