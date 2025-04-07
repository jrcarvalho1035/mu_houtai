-- @version 1.0
-- @author  qianmeng
-- @date    2017-4-20 10:45:55.
-- @system  累计登录奖励

module("activitylogin", package.seeall)
require("loginrewards.loginrewards")

function getSystemVar()
	local sysVar = System.getStaticVar()
	if not sysVar then return end
	if not sysVar.activityLoginData then sysVar.activityLoginData = {} end
	if not sysVar.activityLoginData.finish then sysVar.activityLoginData.finish = 0 end
	return sysVar.activityLoginData
end

function isActivityFinish()
	local sysVar = getSystemVar()
	return sysVar.finish == 1
end

function setActivityFinish(flag)
	local sysVar = getSystemVar()
	sysVar.finish = flag
end

-- loginRewardsData = {
-- 	rewardGet={}, 	--奖励是否领取
-- 	login_day=0, 	--创建角色时onNewDay会加1
-- 	finish=0,		--奖励是否领完
-- }
function getLoginRewardsData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return end
	if not var.loginRewardsData then var.loginRewardsData = {} end
	local var = var.loginRewardsData
	if not var.rewardGet then var.rewardGet = {} end --奖励是否领取
	return var
end

--检测是否全领取
local function checkFinish(actor)
	local var = getLoginRewardsData(actor)
	for k, v in ipairs(LoginRewardsConfig) do
		if (var.rewardGet[k] or 0) == 0 then
			return false
		end
	end
	return true
end

--登录奖励信息
function s2cLoginRewardInfo(actor)
	local var = getLoginRewardsData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_LoginRewardInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, var.login_day or 0) 
	LDataPack.writeShort(npack, #LoginRewardsConfig) 
	for k, v in ipairs(LoginRewardsConfig) do
		LDataPack.writeByte(npack, var.rewardGet[k] or 0)
	end
	LDataPack.flush(npack)
end

--领取登录奖励
local function c2sGetLoginReward(actor, packet)
	if isActivityFinish() then return end
	local id = LDataPack.readInt(packet) 
	local var = getLoginRewardsData(actor)
	local conf = LoginRewardsConfig[id]
	if not conf then return end

	if (var.login_day or 0) < conf.day then
		return
	end
	if var.rewardGet[id] == 1 then
		return
	end
	var.rewardGet[id] = 1
	actoritem.addItems(actor, conf.rewards, "login rewards")

	s2cLoginRewardInfo(actor)
	if checkFinish(actor) then --领完后设置该活动结束
		var.finish = 1
	end
	utils.logCounter(actor, "login reward", id)
end

local function onLogin(actor)
	if isActivityFinish() then return end
	local var = getLoginRewardsData(actor)
	if (var.finish or 0) == 0 then
		s2cLoginRewardInfo(actor)
	end
end

local function onNewDay(actor, login)
	if isActivityFinish() then return end
	local var = getLoginRewardsData(actor)
	if (var.finish or 0) == 0 then
		var.login_day = (var.login_day or 0) + 1
		if not login then
			s2cLoginRewardInfo(actor)
		end
	end
end

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_LoginRewardGet, c2sGetLoginReward)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.stopactivitylogin = function (actor)
	setActivityFinish(1)
	return true
end

gmCmdHandlers.startactivitylogin = function (actor)
	setActivityFinish(0)
	return true
end
