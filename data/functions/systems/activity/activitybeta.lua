-- @version 1.0
-- @author  qianmeng
-- @date    2017-9-14 19:57:48.
-- @system  封测登录奖励

module("activitybeta", package.seeall)
require("loginrewards.betarewards")
require("loginrewards.betalevel")

-- betaLoginData = {
-- 	rewardGet={}, 	--奖励是否领取
-- 	login_day=0, 	--创建角色时onNewDay会加1
-- }
local function getBetaRewardsData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return end
	if not var.betaLoginData then var.betaLoginData = {} end
	local var = var.betaLoginData
	if not var.rewardGet then var.rewardGet = {} end --奖励是否领取
	if not var.levelRecord then var.levelRecord = 0 end --等级奖励
	return var
end

--封测登录奖励信息
function s2cBetaLoginRewardInfo(actor)
	local var = getBetaRewardsData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sBetaCmd_LoginRewardInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, var.login_day or 0) 
	LDataPack.writeShort(npack, #BetaRewardsConfig) 
	for k, v in ipairs(BetaRewardsConfig) do
		LDataPack.writeByte(npack, var.rewardGet[k] or 0)
	end
	LDataPack.flush(npack)
end

--封测登录奖励领取
local function c2sGetBetaLoginReward(actor, packet)
	local id = LDataPack.readInt(packet) 
	local var = getBetaRewardsData(actor)
	if not var then return end
	local conf = BetaRewardsConfig[id]
	if not conf then return end

	if (var.login_day or 0) < conf.day then
		return
	end
	if var.rewardGet[id] == 1 then
		return
	end
	var.rewardGet[id] = 1
	actoritem.addItems(actor, conf.rewards, "beta login rewards")

	s2cBetaLoginRewardInfo(actor)
	LActor.sendTipmsg(actor, string.format(ScriptTips.actor002), ttScreenCenter)
	utils.logCounter(actor, "beta login reward", id)
end

--封测等级礼包信息
function s2cBetaLevelRewardInfo(actor)
	local var = getBetaRewardsData(actor)
	if not var then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sBetaCmd_LevelRewardInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, #BetaLevelConfig) 
	for k, v in ipairs(BetaLevelConfig) do
		LDataPack.writeByte(npack, System.bitOPMask(var.levelRecord, k) and 1 or 0)
	end
	LDataPack.flush(npack)
end

--封测等级礼包领取
local function c2sGetBetaLevelReward(actor, packet)
	local id = LDataPack.readInt(packet) 
	local conf = BetaLevelConfig[id]
	if LActor.getLevel(actor) < conf.level then
		return false
	end
	local var = getBetaRewardsData(actor)
	for i=1, id-1 do
		if not System.bitOPMask(var.levelRecord, i) then --之前的等级奖励都要先领取
			return
		end
	end
	if not var then return end
	if System.bitOPMask(var.levelRecord, id) then --已领取
		return false
	end

	var.levelRecord = System.bitOpSetMask(var.levelRecord, id, true)
	actoritem.addItems(actor, conf.rewards, "beta level rewards")
	s2cBetaLevelRewardInfo(actor)
	LActor.sendTipmsg(actor, string.format(ScriptTips.actor002), ttScreenCenter)
	utils.logCounter(actor, "beta level reward", id)
end

local function onLogin(actor)
	local var = getBetaRewardsData(actor)
	s2cBetaLoginRewardInfo(actor)
	s2cBetaLevelRewardInfo(actor)
end

local function onNewDay(actor, login)
	local var = getBetaRewardsData(actor)
	var.login_day = (var.login_day or 0) + 1
	if not login then
		s2cBetaLoginRewardInfo(actor)
	end
end

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cBetaCmd_LoginRewardGet, c2sGetBetaLoginReward)
netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cBetaCmd_LevelRewardGet, c2sGetBetaLevelReward)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.betareward = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sGetBetaLoginReward(actor, pack)
end

gmCmdHandlers.betalevel = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sGetBetaLevelReward(actor, pack)
end
