-- 萃粉树
module("powdercowsystem", package.seeall)

require("cashcow.powdercowlimit")
require("cashcow.powdercowbasic")
require("cashcow.powdercowamplitude")
require("cashcow.powdercowbox")

--初始值
local powderCowVarDef = 
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


local function getPowderCowVar(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then return nil end
	if var.powderCowVar == nil then
		var.powderCowVar            = {}
		var.powderCowVar.curDayTime = powderCowVarDef.curDayTime
		var.powderCowVar.boxTime    = powderCowVarDef.boxTime
		var.powderCowVar.boxMask    = powderCowVarDef.boxMask
		var.powderCowVar.ampLv      = powderCowVarDef.ampLv
		var.powderCowVar.exp        = powderCowVarDef.exp
	end

	return var.powderCowVar
end

local function checkShakeCondition(actor) 
	local var = getPowderCowVar(actor) 
	if not var then return false end

	local config
	--检查vip等级次数
	local vipLv = LActor.getVipLevel(actor)
	config = PowderCowLimitConfig[vipLv]
	if not config then return false end
	if var.curDayTime >= config.maxTime then
		return false
	end

	--检查下一次消耗元宝是否足够
	local nextTime = var.curDayTime + 1
	if nextTime > #PowderCowBasicConfig then return false end
	config = PowderCowBasicConfig[nextTime]
	if not config then return false end
	if not actoritem.checkItem(actor, NumericType_YuanBao, config.yuanbao) then
		return false
	end
	return true
end

local function calcCurCrit(actor) 
	local vipLv = LActor.getVipLevel(actor)
	local limitconfig = PowderCowLimitConfig[vipLv]
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
	local amplitudeConfig = PowderCowAmplitudeConfig
	local var = getPowderCowVar(actor)
	local nextAmpLv = var.ampLv + 1
	if nextAmpLv > #amplitudeConfig then return end
	if var.exp >= amplitudeConfig[nextAmpLv].needExp then
		var.ampLv = var.ampLv + 1
		var.exp = var.exp - amplitudeConfig[nextAmpLv].needExp
	end
end

local function calcCurAmplitude(ampLv)
	local amplitudeConfig = PowderCowAmplitudeConfig
	local rate = amplitudeConfig[ampLv].rate/100
	return rate
end

local function resetPowderCowVar(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then return nil end
	if var.powderCowVar == nil then return end
	
	var.powderCowVar.curDayTime = powderCowVarDef.curDayTime
	var.powderCowVar.boxTime    = powderCowVarDef.boxTime
	var.powderCowVar.boxMask    = powderCowVarDef.boxMask
end

-----------------------------------------------------------------------------------------------
--摇粉树信息
function s2cPowderCowInfo(actor)
	local var = getPowderCowVar(actor)
	if not var then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_CashCow, Protocol.sPowderCowCmd_AllInfoSync)
	if pack == nil then return end
	LDataPack.writeData(pack, 5,
						dtShort, var.curDayTime,
						dtShort, var.boxTime,
						dtShort, var.ampLv,
						dtShort, var.exp,
						dtInt,   var.boxMask)
	LDataPack.flush(pack)
end

--摇粉
function c2sShakePowderCow(actor, packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.powder) then return end
	if not checkShakeCondition(actor) then return end
	local var = getPowderCowVar(actor)
	local nextTime = var.curDayTime + 1
	local config = PowderCowBasicConfig[nextTime]
	actoritem.reduceItem(actor, NumericType_YuanBao, config.yuanbao, "powdercowsystem handleShake")
	var.curDayTime = var.curDayTime + 1
	var.boxTime = var.boxTime + 1
	var.exp = var.exp + 1

	updateAmpLv(actor)

	-- 玩家每次使用摇粉树获得的金币=基础金币数x增幅倍数x暴击倍率
	local amp = calcCurAmplitude(var.ampLv)
	local crit = calcCurCrit(actor)
	local gold = config.gold * amp * crit
	actoritem.addItem(actor, NumericType_Powder, gold, "powdercowsystem handleShake")

	s2cShakeResult(actor,crit) -- 回包
end

function s2cShakeResult(actor,crit)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CashCow, Protocol.sPowderCowCmd_Shake)
	if not npack then return end
	local var = getPowderCowVar(actor)
	LDataPack.writeData(npack, 5,
						dtShort, var.curDayTime,
						dtShort, var.boxTime,
						dtShort, var.ampLv,
						dtShort, var.exp,
						dtShort, crit)
	LDataPack.flush(npack)
end

--宝箱领取
function c2sGetPowderCowBox(actor, packet)
	local index = LDataPack.readInt(packet)

	boxConfig = PowderCowBoxConfig
	if boxConfig[index] == nil then return end

	local var = getPowderCowVar(actor)
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
		actoritem.addItem(actor, NumericType_Powder, gold, "powdercowsystem handleGetBox")
	end
	
	s2cBoxResult(actor) --回包
end

function s2cBoxResult(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CashCow, Protocol.sPowderCowCmd_GetBox)
	if not npack then return end
	local var = getPowderCowVar(actor)
	LDataPack.writeInt(npack, var.boxMask)
	LDataPack.flush(npack)
end

local function onLogin(actor)
	s2cPowderCowInfo(actor)
end

local function onNewDay(actor, login)
	resetPowderCowVar(actor)
	if not login then
		s2cPowderCowInfo(actor)
	end
end

netmsgdispatcher.reg(Protocol.CMD_CashCow, Protocol.cPowderCowCmd_Shake, c2sShakePowderCow)
netmsgdispatcher.reg(Protocol.CMD_CashCow, Protocol.cPowderCowCmd_GetBox, c2sGetPowderCowBox)

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive,onNewDay)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.powdercowbox = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sGetPowderCowBox(actor, pack)
	return true
end

gmCmdHandlers.powdercowshake= function (actor, args)
	c2sShakePowderCow(actor)
	return true
end
