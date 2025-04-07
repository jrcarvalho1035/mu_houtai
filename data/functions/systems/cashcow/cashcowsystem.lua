-- 摇钱树
module("cashcowsystem", package.seeall)

require("cashcow.cashcowlimit")
require("cashcow.cashcowbasic")
require("cashcow.cashcowamplitude")
require("cashcow.cashcowbox")

--初始值
local cashCowVarDef = 
{
	--当天已使用次数
	curDayTime = 0,
	--增幅等级
	ampLv     = 1,
	--经验值
	exp       = 0,
	--宝箱次数
	boxTime   = 0,
	--宝箱领取位集
	boxMask   = 0,
}


local function getCashCowVar(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then return nil end
	if var.cashCowVar == nil then
		var.cashCowVar            = {}
		var.cashCowVar.curDayTime = cashCowVarDef.curDayTime
		var.cashCowVar.boxTime    = cashCowVarDef.boxTime
		var.cashCowVar.boxMask    = cashCowVarDef.boxMask
		var.cashCowVar.ampLv      = cashCowVarDef.ampLv
		var.cashCowVar.exp        = cashCowVarDef.exp
	end

	return var.cashCowVar
end

local function checkShakeCondition(actor) 
	local var = getCashCowVar(actor) 
	if not var then return false end

	local config
	--检查vip等级次数
	local vipLv = LActor.getVipLevel(actor)
	config = CashCowLimitConfig[vipLv]
	if not config then return false end
	if var.curDayTime >= config.maxTime then
		return false
	end

	--检查下一次消耗元宝是否足够
	local nextTime = var.curDayTime + 1
	if nextTime > #CashCowBasicConfig then return end
	config = CashCowBasicConfig[nextTime]
	if not config then return false end
	if not actoritem.checkItem(actor, NumericType_YuanBao, config.yuanbao) then
		return false
	end
	return true
end

local function calcCurCrit(actor) 
	local vipLv = LActor.getVipLevel(actor)
	local limitconfig = CashCowLimitConfig[vipLv]
	local rate = 1
	local result = 0
	local rand = math.random(1,100)
	for _, info in ipairs(limitconfig.crit) do
		result = result + info.odds
		if result >= rand then
			return info.rate
		end
	end
	return rate
end

local function updateAmpLv(actor)
	local amplitudeConfig = CashCowAmplitudeConfig
	local var = getCashCowVar(actor)
	local nextAmpLv = var.ampLv + 1
	if nextAmpLv > #amplitudeConfig then return end
	if var.exp >= amplitudeConfig[nextAmpLv].needExp then
		var.ampLv = var.ampLv + 1
		var.exp = var.exp - amplitudeConfig[nextAmpLv].needExp
	end
end

local function calcCurAmplitude(ampLv)
	local amplitudeConfig = CashCowAmplitudeConfig
	local rate = amplitudeConfig[ampLv].rate/100
	return rate
end

local function resetCashCowVar(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then return nil end
	if var.cashCowVar == nil then return end
	
	var.cashCowVar.curDayTime = cashCowVarDef.curDayTime
	var.cashCowVar.boxTime    = cashCowVarDef.boxTime
	var.cashCowVar.boxMask    = cashCowVarDef.boxMask
end

-----------------------------------------------------------------------------------------------
--摇钱树信息
function s2cCashCowInfo(actor)
	local var = getCashCowVar(actor)
	if not var then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_CashCow, Protocol.sCashCowCmd_AllInfoSync)
	if pack == nil then return end
	LDataPack.writeData(pack, 5,
						dtShort, var.curDayTime,
						dtShort, var.boxTime,
						dtShort, var.ampLv,
						dtShort, var.exp,
						dtInt,   var.boxMask)
	LDataPack.flush(pack)
end

--摇钱
function c2sShakeCashCow(actor, packet)
	if not checkShakeCondition(actor) then return end
	local var = getCashCowVar(actor)
	local nextTime = var.curDayTime + 1
	local config = CashCowBasicConfig[nextTime]
	actoritem.reduceItem(actor, NumericType_YuanBao, config.yuanbao, "cashcowsystem handleShake")
	var.curDayTime = var.curDayTime + 1
	var.boxTime = var.boxTime + 1
	var.exp = var.exp + 1

	updateAmpLv(actor)

	-- 玩家每次使用摇钱树获得的金币=基础金币数x增幅倍数x暴击倍率
	local amp = calcCurAmplitude(var.ampLv)
	local crit = calcCurCrit(actor)
	local gold = config.gold * amp * crit
	actoritem.addItem(actor, NumericType_Gold, gold, "cashcowsystem handleShake")

	s2cShakeResult(actor,crit) -- 回包
end

function s2cShakeResult(actor,crit)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CashCow, Protocol.sCashCowCmd_Shake)
	if not npack then return end
	local var = getCashCowVar(actor)
	LDataPack.writeData(npack, 5,
						dtShort, var.curDayTime,
						dtShort, var.boxTime,
						dtShort, var.ampLv,
						dtShort, var.exp,
						dtShort, crit)
	LDataPack.flush(npack)
end

--宝箱领取
function c2sGetCashCowBox(actor, packet)
	local index = LDataPack.readInt(packet)

	boxConfig = CashCowBoxConfig
	if boxConfig[index] == nil then return end

	local var = getCashCowVar(actor)
	if var.boxTime < boxConfig[index].time then 
		return 
	end

	local bitIndex = index - 1
	if System.bitOPMask(var.boxMask, bitIndex) then
	    return
	end

	var.boxMask = System.bitOpSetMask(var.boxMask, bitIndex, true)

	local boxDetailConf = boxConfig[index].box
	for _, gold in ipairs(boxDetailConf) do
		actoritem.addItem(actor, NumericType_Gold, gold, "cashcowsystem handleGetBox")
	end
	
	s2cBoxResult(actor) --回包
end

function s2cBoxResult(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CashCow, Protocol.sCashCowCmd_GetBox)
	if not npack then return end
	local var = getCashCowVar(actor)
	LDataPack.writeInt(npack, var.boxMask)
	LDataPack.flush(npack)
end

local function onLogin(actor)
	s2cCashCowInfo(actor)
end

local function onNewDay(actor, login)
	resetCashCowVar(actor)
	if not login then
		s2cCashCowInfo(actor)
	end
end

netmsgdispatcher.reg(Protocol.CMD_CashCow, Protocol.cCashCowCmd_Shake, c2sShakeCashCow)
netmsgdispatcher.reg(Protocol.CMD_CashCow, Protocol.cCashCowCmd_GetBox, c2sGetCashCowBox)

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive,onNewDay)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.cashcowbox = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sGetCashCowBox(actor, pack)
	return true
end

gmCmdHandlers.cashcowshake= function (actor, args)
	c2sShakeCashCow(actor)
	return true
end
