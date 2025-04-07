--冲值系统
module("firstchargeactive", package.seeall)
require("recharge/firstrecharge")

function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return nil end
	if var.firstrechargeActive == nil 
		then var.firstrechargeActive = {}
	end
	local var = var.firstrechargeActive
	if not var.day then var.day = 0 end --首冲天数
	if not var.getday then var.getday = 0 end --首冲天数	
	if not var.expire_time then var.expire_time = 0 end
	return var
end
--------------------------------------------------------------------------------------------------------
--首充活动奖励信息
function s2cFirstRechargeActive(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_FirstRechargeActive)
	if npack == nil then return end
	local var = getActorVar(actor)

	LDataPack.writeChar(npack, var.day)
	LDataPack.writeInt(npack, var.getday)
	LDataPack.writeInt(npack, math.max(var.expire_time - System.getNowTime(), 0))
	LDataPack.flush(npack)
end

--首冲
function buyFirstRecharge(actor)
	local var = getActorVar(actor)
	if var.day > 0 then return end
	var.day = 1
	s2cFirstRechargeActive(actor)

	chongzhi1.buyFirstRecharge(actor)
	rechargesystem.addVipExp(actor, FirstRechargeConfig[1].pay)
end

function buy(actorid) 
	local actor = LActor.getActorById(actorid)
	if actor then
		buyFirstRecharge(actor)
	else
		local pack = LDataPack.allocPacket()
		System.sendOffMsg(actorid, 0, OffMsgType_FirstRecharge, pack)
	end
end


function c2sFirstRechargeActive(actor, pack)
	local index = LDataPack.readChar(pack)
	local config = FirstRechargeConfig[index]
	if not config then return end
	local var = getActorVar(actor)	

	if var.day < index then return end
	if System.bitOPMask(var.getday, index - 1) then return end
	if not actoritem.checkEquipBagSpaceJob(actor, config.awardList) then
		return
	end
	var.getday = System.bitOpSetMask(var.getday, index - 1, true)

	local rewards = actoritem.getItemsByJob(actor, config.awardList)
	actoritem.addItems(actor, rewards, "first recharge")
	s2cFirstRechargeActive(actor)
end

function onLogin(actor)
	s2cFirstRechargeActive(actor)
end

function OffMsgBuyFirstRecharge(actor, offmsg)
	print(string.format("OffMsgBuyFirstRecharge actorid:%d ", LActor.getActorId(actor)))
	buyFirstRecharge(actor)
end

function onCustomChange(actor, custom, oldCustom)
	if not (custom >= LimitConfig[actorexp.LimitTp.chong].custom and oldCustom < LimitConfig[actorexp.LimitTp.chong].custom) then return end	
	local var = getActorVar(actor)
	if var.expire_time == 0 then
		var.expire_time = System.getNowTime() + FirstRechargeConfig[1].timer * 60
	end
	s2cFirstRechargeActive(actor)
end

local function onNewDay(actor, login)
	local var = getActorVar(actor)
	if var.day > 0 and var.day < #FirstRechargeConfig then
		var.day = var.day + 1
	end
	if not login then
		s2cFirstRechargeActive(actor)
	end
end

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeCustomChange, onCustomChange)
msgsystem.regHandle(OffMsgType_FirstRecharge, OffMsgBuyFirstRecharge)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_FirstRechargeActiveGet, c2sFirstRechargeActive)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.getfirstrechargeactive = function (actor, args)
	s2cFirstRechargeActive(actor)
	return true
end
