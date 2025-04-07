--[[
a)	例如：玩家开服第一天没有完成任意一档的首次充值，则第二天仍然显示首次充值的界面。如果玩家在某天完成了任意一档的首次充值，则第二天显示对应活动循环周期的每日充值
b)	活动循环周期：开服前7天每天变化，开服第8天起，每7天为一个活动循环周期，共包括7组活动，每天采用对应的活动内容
ccccc!!!!, 未领取的还要邮件发!!! 已经做在登陆时处理
--]]


module("chongzhi1", package.seeall)
require("recharge.chongzhi1")

--[[
data define:

	chongzhi1Data = {
		hasPayed -- number 0/1, 是否进入每日首冲的界面
		payCount -- number      已冲金额
		rewardRecord -- number  bitset  领取记录
	}
--]]


local p = Protocol
local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end

	if (var.chongzhi1Data == nil) then
		var.chongzhi1Data = {
			hasPayed = 0, --是否进入每日首冲的界面
			payCount = 0, --今日累冲
			rewardRecord = 0, --领奖位集
			beforeday = 0,
		}
	end

	return var.chongzhi1Data
end

----------------------------------------------------------------------------------------------------
local function updateInfo(actor)
	local data = getStaticData(actor)
	local npack = LDataPack.allocPacket(actor, p.CMD_Recharge, p.sRechargeCmd_UpdateChongZhi1)
	if npack == nil then return end

	LDataPack.writeInt(npack, data.payCount or 0)
	LDataPack.writeInt(npack, data.rewardRecord or 0)
	LDataPack.flush(npack)
end

local function onReqReward(actor, packet)
	local index = LDataPack.readShort(packet)
	local data = getStaticData(actor)

	if System.bitOPMask(data.rewardRecord or 0, index) then
		return
	end
	local day = System.getOpenServerDay() + 1
	if day > #ChongZhi1Config then
		day = #ChongZhi1Config
	end
	local config = ChongZhi1Config[day]
	if not config then return end
	if not config[index] then return end
	if config[index].pay > (data.payCount or 0) then
		return
	end
	if not actoritem.checkEquipBagSpaceJob(actor, config[index].awardList) then
		return
	end

	data.rewardRecord = System.bitOpSetMask(data.rewardRecord or 0, index, true)
	actoritem.addItemsByJob(actor, config[index].awardList, "chongzhi1", 0, "chongzhi1")
	updateInfo(actor)
end

local function sendInitInfo(actor)
	local data = getStaticData(actor)
	local npack = LDataPack.allocPacket(actor, p.CMD_Recharge, p.sRechargeCmd_InitChongZhi1)
	if npack == nil then return end
	LDataPack.writeByte(npack, data.hasPayed)
	LDataPack.writeInt(npack, data.payCount)
	LDataPack.writeInt(npack, data.rewardRecord)
	local day = System.getOpenServerDay() + 1
	if day > #ChongZhi1Config then
		day = #ChongZhi1Config
	end
	LDataPack.writeShort(npack, day)
	LDataPack.flush(npack)
end

function buyFirstRecharge(actor)
	local data = getStaticData(actor)
	data.hasPayed = 1
	sendInitInfo(actor)
end

local function onRecharge(actor, count)
	local data = getStaticData(actor)
	data.payCount = (data.payCount or 0) + count
	data.beforeday = System.getOpenServerDay() + 1
	if data.beforeday > #ChongZhi1Config then
		data.beforeday = #ChongZhi1Config
	end
	updateInfo(actor)
end

local function onLogin(actor)
	sendInitInfo(actor)
end

local function onNewDay(actor, isLogin)
	local data = getStaticData(actor)
	--邮件发送昨天能领未领的奖励
	if data.hasPayed == 1 then
		for index, conf in pairs(ChongZhi1Config[data.beforeday]) do
			if System.bitOPMask(data.rewardRecord, index) == false and data.payCount >= conf.pay then
				local rewards = actoritem.getItemsByJob(actor, conf.awardList)
				local mailData = {
					head = RechargeConstConfig.chongzhi1Head,
					context = RechargeConstConfig.chongzhi1Content,
					tAwardList= rewards
				}
				mailsystem.sendMailById(LActor.getActorId(actor), mailData)
			end
		end
	end

	data.payCount = 0
	data.rewardRecord = 0

	if not isLogin then
		sendInitInfo(actor)
	end
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeRecharge, onRecharge)

netmsgdispatcher.reg(p.CMD_Recharge, p.cRechargeCmd_ReqRewardChongZhi1, onReqReward)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.chongzhi1 = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	onReqReward(actor, pack)
end
