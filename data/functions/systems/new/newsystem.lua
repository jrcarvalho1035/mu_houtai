-- @version	1.0
-- @author	qianmeng
-- @date	2017-6-2 10:17:15.
-- @system	新功能开启

module("newsystem", package.seeall)
require("limit.limit")

systemOpenFuncs = {}

function regSystemOpenFuncs(tp, func)
	if systemOpenFuncs[tp] ~= nil or tp == nil then
		assert(false)
		return
	end
	systemOpenFuncs[tp] = func
end

function callSystemOpen(actor, tp, ...)
	if systemOpenFuncs[tp] then
		xpcall(function() systemOpenFuncs[tp](actor, unpack(arg)) end, script_error_handle)
	end
end

--用于记录玩家已开启过的系统，避免重复触发
local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end
	if not var.newsys then var.newsys = {} end 
	return var.newsys
end

function getNewData()
	local var = System.getDyanmicVar()
	if not var.newfunctions then
		var.newfunctions = {}
	end
	return var.newfunctions
end

--用于记录玩家被触发的系统
function getDyanmicVar(actor)
	local var = LActor.getGlobalDyanmicVar(actor)
	if not var.newsys then
		var.newsys = {
			funs = {},
		}
	end
	return var.newsys
end

--进入静态副本
function onEnternStaticFuben(actor)
	s2cNewSystemOpen(actor)
end

function onZhuansheng(actor, zslevel)
	local var = getStaticData(actor)
	local dyan = getDyanmicVar(actor)
	local day = System.getOpenServerDay() --开服天数
	local custom = guajifuben.getCustom(actor)
	for idx, v in pairs(LimitConfig) do
		if custom >= LimitConfig[idx].custom and (not var[idx]) and day >= v.day and zslevel >= v.zslevel then
			table.insert(dyan.funs, idx)
			var[idx] = 1
			callSystemOpen(actor, idx)
		end
	end
	local fbId = LActor.getFubenId(actor)
	if staticfuben.isStaticFuben(fbId) then --在静态副本内，直接显示
		s2cNewSystemOpen(actor)
	end
end

function onCustomChange(actor, custom, oldcustom)
	local var = getStaticData(actor)
	local data = getNewData()
	local dyan = getDyanmicVar(actor)
	local curTaskId = maintask.getMainTaskIdx(actor)
	local zslevel = zhuansheng.getZSLevel(actor)
	local day = System.getOpenServerDay() --开服天数
	for idx, v in pairs(LimitConfig) do
		if custom >= LimitConfig[idx].custom and day >= LimitConfig[idx].day and day < LimitConfig[idx].closeday 
		and zslevel >= v.zslevel and (not var[idx]) then
			table.insert(dyan.funs, idx)
			var[idx] = 1
			callSystemOpen(actor, idx)
		end
	end
	local fbId = LActor.getFubenId(actor)
	if staticfuben.isStaticFuben(fbId) then --在静态副本内，直接显示
		s2cNewSystemOpen(actor)
	end
end

function onNewDay(actor, login)
	local var = getStaticData(actor)
	local dyan = getDyanmicVar(actor)
	local day = System.getOpenServerDay() --开服天数
	local zslevel = zhuansheng.getZSLevel(actor)
	local custom = guajifuben.getCustom(actor)
	for idx, v in pairs(LimitConfig) do
		if custom >= LimitConfig[idx].custom and day >= v.day and day <= v.closeday and (not var[idx]) and zslevel >= v.zslevel  then
			table.insert(dyan.funs, idx)
			var[idx] = 1
			callSystemOpen(actor, idx , true)
		end
	end
	local fbId = LActor.getFubenId(actor)
	if staticfuben.isStaticFuben(fbId) then --在静态副本内，直接显示
		s2cNewSystemOpen(actor)
	end
end
----------------------------------------------------------------------------------------------
function s2cNewSystemOpen(actor)
	local dyan = getDyanmicVar(actor)
	if not next(dyan.funs) then
		return
	end
	local npack = LDataPack.allocPacket(actor,  Protocol.CMD_Other, Protocol.sNewCmd_Open)
	if npack == nil then return end
	LDataPack.writeShort(npack, #dyan.funs)
	for k, idx in pairs(dyan.funs) do
		LDataPack.writeShort(npack, idx)
	end
	LDataPack.flush(npack)
	dyan.funs = {}
end

local FourOpenSystem = {actorexp.LimitTp.wing, actorexp.LimitTp.shenqi, actorexp.LimitTp.shenzhuang, actorexp.LimitTp.meilin,
		actorexp.LimitTp.daomonmozhen, actorexp.LimitTp.yongbingmozhen, actorexp.LimitTp.shenmomozhen}
function onVip(actor)
	local var = getStaticData(actor)
	local dyan = getDyanmicVar(actor)
	local custom = guajifuben.getCustom(actor)
	for i=1, #FourOpenSystem do
		local idx = FourOpenSystem[i]
		if not var[idx] then
			table.insert(dyan.funs, idx)
			var[idx] = 1
			callSystemOpen(actor, idx)
		end
	end
	local fbId = LActor.getFubenId(actor)
	if staticfuben.isStaticFuben(fbId) then --在静态副本内，直接显示
		s2cNewSystemOpen(actor)
	end
end


--启动初始化
local function init()
	actorevent.reg(aeSVipLevel, onVip)
	actorevent.reg(aeZhuansheng, onZhuansheng)
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeInterGuajifu, onEnternStaticFuben)
	actorevent.reg(aeInterMainscene, onEnternStaticFuben)
	actorevent.reg(aeCustomChange, onCustomChange)
end
table.insert(InitFnTable, init)


