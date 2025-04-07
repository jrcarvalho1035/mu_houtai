-- @version 1.0
-- @author  qianmeng
-- @date    2017-4-26 16:21:01.
-- @system  一元好礼

module("oneyan",package.seeall)
require("recharge.oneyan")

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end
	if not var.oneyanData then var.oneyanData = {} end
	if not var.oneyanData.isBuy then var.oneyanData.isBuy = 0 end --今天是否购买了
	return var.oneyanData
end


function buyOneyan(actor) 
	local var = getStaticData(actor)
	if var.isBuy == 1 then
		return
	end

	actoritem.addItems(actor, OneyanConfig[1].rewards, "oneyan rewards")
	var.isBuy = 1
	s2cOneyanInfo(actor)
	actorevent.onEvent(actor, aeRecharge, OneyanConfig[1].cash, 1)
	print( LActor.getActorId(actor) .. " buyOneyan: ok")
	utils.logCounter(actor, "oneyan buy")
end

function buy(actorid) 
	local actor = LActor.getActorById(actorid)
	if actor then
		buyOneyan(actor)
	else
		local npack = LDataPack.allocPacket()
		System.sendOffMsg(actorid, 0, OffMsgType_OneYan, npack)
	end
end

function OffMsgOneYan(actor, offmsg)
	print(string.format("OffMsgOneYan actorid:%d ", LActor.getActorId(actor)))
	buyOneyan(actor)
end

---------------------------------------------------------------------------------------------------------------
function s2cOneyanInfo(actor)
	local var = getStaticData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_OneyanData)
	LDataPack.writeByte(npack, var.isBuy)
	LDataPack.writeShort(npack, 1) --一元表的id
	LDataPack.flush(npack)
end

local function onLogin(actor) 
	s2cOneyanInfo(actor)
end

local function onNewDayArrive(actor, login)
	local var = getStaticData(actor)
	var.isBuy = 0
	if not login then
		s2cOneyanInfo(actor)
	end
end

msgsystem.regHandle(OffMsgType_OneYan, OffMsgOneYan)
actorevent.reg(aeNewDayArrive, onNewDayArrive)
actorevent.reg(aeUserLogin, onLogin)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.buyoneyan = function(actor) 
	buyOneyan(actor)
	return true
end

