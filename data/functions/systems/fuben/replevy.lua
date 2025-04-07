-- @version	2.0
-- @author	qianmeng
-- @date	2017-12-25 22:49:36
-- @system	副本追回

module("replevy", package.seeall)
require "scene.replevyfuben"

RTP = {
	xuese = 1,
	devil = 2,
	dayexp = 3,
}
--启动时求副本追回组id
GROUP = {
	xuese = 0,
	devil = 0,
	dayexp = 0,
}

local function nameinit()
	for k, v in ipairs(ReplevyFuben) do
		if RTP.xuese == k then
			GROUP.xuese = v.group
		elseif RTP.devil == k then
			GROUP.devil = v.group
		elseif RTP.dayexp == k then
			GROUP.dayexp = v.group
		end
	end
end

function getActorVar(actor, id)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.replevyData then 
		var.replevyData = {} 
	end
	if not var.replevyData[id] then 
		var.replevyData[id] = {} 
	end
	if not var.replevyData[id].dayTimes then var.replevyData[id].dayTimes = {} end --每天可用次数
	if not var.replevyData[id].getTimes then var.replevyData[id].getTimes = 0 end --追回次数
	return var.replevyData[id]
end

local function getUseTimes(var)
	local sum = 0
	for i=1, 3 do
		sum = sum + (var.dayTimes[i] or 0)
	end
	return sum
end

local function addUseTimes(var, value)
	var.dayTimes[3] = var.dayTimes[2]
	var.dayTimes[2] = var.dayTimes[1]
	var.dayTimes[1] = value
end

local function reduceUseTimes(var, value)
	for i=3, 1, -1 do
		local tmp = value - (var.dayTimes[i] or 0)
		if tmp <= 0 then
			var.dayTimes[i] = (var.dayTimes[i] or 0) - value 
			break
		else 
			var.dayTimes[i] = 0
			value = tmp
		end
	end
end

--设置可追回次数
function SetReplevyCount(actor, id, value, total, limitLv)
	value = math.max(value, 0)
	local var = getActorVar(actor, id)
	if not var then return end
	local oldLv = var.outLv or LActor.getLevel(actor)
	if oldLv < limitLv then return end --离线时等级没达到开放系统的等级

	if not var.days then var.days = {} end
	--连续几天没登录，要加入那些天数
	if var.osDay then
		local delay = math.min(3, System.getOpenServerDay() - var.osDay)
		for i=1, delay - 1 do
			addUseTimes(var, total)
		end
	end

	addUseTimes(var, value)
end

function GetReplevyTimes(actor, id)
	local var = getActorVar(actor, id)
	return var.getTimes
end
---------------------------------------------------------------------------------------------
function s2cReplevyInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_ReplevyInfo)
	LDataPack.writeChar(pack, #ReplevyFuben)
	for k, v in ipairs(ReplevyFuben) do
		local var = getActorVar(actor, k)
		local useTimes = getUseTimes(var)
		LDataPack.writeChar(pack, k)
		LDataPack.writeChar(pack, useTimes)
		LDataPack.writeChar(pack, var.getTimes)
	end
	LDataPack.flush(pack)
end

--副本追回
function c2sReplevyGet(actor, packet)
	local id = LDataPack.readChar(packet)
	local number = LDataPack.readChar(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.replevy) then return end
	local conf = ReplevyFuben[id]
	if not conf then return end
	local var = getActorVar(actor, id)

	local useTimes = getUseTimes(var)
	if useTimes < number then return end --无可追的次数
	if not actoritem.checkItem(actor, NumericType_YuanBao, conf.price*number) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, conf.price*number, "replevy fuben")

	reduceUseTimes(var, number)
	var.getTimes = var.getTimes + number

	if id == RTP.devil then
		devilsquare.s2cDevilsquareInfo(actor)
	elseif id == RTP.xuese then
		xuese.s2cXueseInfo(actor)
	elseif id == RTP.dayexp then
		dailyfuben.onSendFubenInfo(actor)
	end

	s2cReplevyInfo(actor)
	LActor.sendTipmsg(actor, string.format(ScriptTips.fuben08, conf.name, number), ttScreenCenter)
end

local function onLogin(actor)
	s2cReplevyInfo(actor)
end 

local function onLogout(actor)
	for id, v in ipairs(ReplevyFuben) do
		local var = getActorVar(actor, id)
		if var then
			var.outLv = LActor.getLevel(actor) --记录离线时等级
			var.osDay = System.getOpenServerDay() --记录离线时开服天数
		end
	end
end

local function onNewDay(actor, login)
	for id, v in ipairs(ReplevyFuben) do
		local var = getActorVar(actor, id)
		if var then
			var.getTimes = 0
		end
	end

	if not login then
		s2cReplevyInfo(actor)
	end
end

local function init()
	if System.isBattleSrv() then return end
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeUserLogout, onLogout)
	actorevent.reg(aeNewDayArrive, onNewDay)

	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_ReplevyGet, c2sReplevyGet)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.replevyget = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeChar(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sReplevyGet(actor, pack)
end

nameinit()
