-- @version	1.0
-- @author	qianmeng
-- @date	2017-7-22 17:14:38.
-- @system	奇迹之路

module("waysystem", package.seeall)
require("limit.way")
require("limit.way2")

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end
	if not var.waysys then var.waysys = {} end
	return var.waysys
end

local function getStaticData2(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end
	if not var.way2sys then var.way2sys = {} end
	return var.way2sys
end

function onLogin(actor)
	s2cWaySystemOpen(actor)
	s2cWay2SystemOpen(actor)
end

----------------------------------------------------------------------------------------------
function s2cWaySystemOpen(actor)
	local var = getStaticData(actor)
	if not var then return end
	local npack = LDataPack.allocPacket(actor,  Protocol.CMD_Other, Protocol.sWayCmd_Info)
	if npack == nil then return end
	local count = 0
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeChar(npack, count) 
	for k, v in ipairs(WayConfig) do --发送已开启的路
		if var[k] then
			LDataPack.writeChar(npack, k)
			count = count + 1
		end
	end
	if count > 0 then
		local npos = LDataPack.getPosition(npack)
		LDataPack.setPosition(npack, pos)
		LDataPack.writeChar(npack, count)
		LDataPack.setPosition(npack, npos)
	end
	LDataPack.flush(npack)
end

function s2cWay2SystemOpen(actor)
	local var = getStaticData2(actor)
	if not var then return end
	local npack = LDataPack.allocPacket(actor,  Protocol.CMD_Other, Protocol.sWay2Cmd_Info)
	if npack == nil then return end
	local count = 0
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeChar(npack, count) 
	for k, v in ipairs(Way2Config) do --发送已开启的路
		if var[k] == 1 then
			LDataPack.writeChar(npack, k)
			count = count + 1
		end
	end
	if count > 0 then
		local npos = LDataPack.getPosition(npack)
		LDataPack.setPosition(npack, pos)
		LDataPack.writeChar(npack, count)
		LDataPack.setPosition(npack, npos)
	end
	LDataPack.flush(npack)
end

function c2sWayOpen(actor, packet)
	local id = LDataPack.readChar(packet) 
	local conf = WayConfig[id]
	if not conf then return end
	local var = getStaticData(actor)
	if not var then return end
	if var[id] then return end --已领取
	if guajifuben.getCustom(actor) < conf.guanqia then return end
	if maintask.getMainTaskIdx(actor) < conf.taskId then return end
	var[id] = 1
	actoritem.addItemsByJob(actor, conf.rewards, "way rewards", 0, "way")
	s2cWaySystemOpen(actor)
	actorevent.onEvent(actor, aeWayOpen, id)
end

function c2sWay2Open(actor, packet)
	local id = LDataPack.readInt(packet) 
	local conf = Way2Config[id]
	if not conf then return end
	local var = getStaticData2(actor)
	if not var then return end
	if var[id] == 1 then return end --已领取
	if LActor.getZhuansheng(actor) < conf.zslevel then return end
	if System.getOpenServerDay() < conf.openDay then return end
	var[id] = 1
	actoritem.addItemsByJob(actor, conf.rewards, "way2 rewards", 0, "way2")
	s2cWay2SystemOpen(actor)
end

--启动初始化
local function init()
	actorevent.reg(aeUserLogin, onLogin)
	netmsgdispatcher.reg(Protocol.CMD_Other, Protocol.cWayCmd_Open, c2sWayOpen)
	netmsgdispatcher.reg(Protocol.CMD_Other, Protocol.cWay2Cmd_Open, c2sWay2Open)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.wayset = function (actor, args)
	local var = getStaticData(actor)
	local id = tonumber(args[1])
	var[id] = 1
	s2cWaySystemOpen(actor)
end

gmCmdHandlers.rway = function (actor, args)
	local var = getStaticData(actor)
	for k, v in ipairs(WayConfig) do --发送已开启的路
		var[k] = nil
	end
	s2cWaySystemOpen(actor)
	return true
end

gmCmdHandlers.way2get = function (actor, args)
	local id = tonumber(args[1])
	if not id then return end
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, id)
	LDataPack.setPosition(pack, 0)
	c2sWay2Open(actor, pack)
	return true
end

