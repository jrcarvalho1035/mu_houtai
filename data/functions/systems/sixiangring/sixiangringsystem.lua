-- @version	1.0
-- @author	youquan
-- @date	2018-4-24
-- @system	四象灵戒系统

module("sixiangringsystem", package.seeall)

require("sixiangring.sixiangringcommon")
require("sixiangring.sixiangringitem")
require("sixiangring.sixiangringlevel")
require("sixiangring.sixiangringpowerup")

function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var then 
		print("getActorVar var is nil")
		return 
	end

	if var.sixiangRingVar == nil then
		var.sixiangRingVar = {}
		local sixiangRingVar = var.sixiangRingVar
		sixiangRingVar.firstRankCount = 0
		sixiangRingVar.updateTime = System.getNowTime()

		for i=1,4 do
			sixiangRingVar[i] = {}
			sixiangRingVar[i].normalFlag = 0
			sixiangRingVar[i].specialFlag = 0
			sixiangRingVar[i].exp = 0
			sixiangRingVar[i].level = 1
		end
	end

	if var.sixiangRingVar.updateTime == nil then
		var.sixiangRingVar.updateTime = System.getNowTime()
	end

	return var.sixiangRingVar
end

function powerUp(actor, ringType, powerUpType)
	if not SixiangRingPowerUpConfig[ringType] then
		return
	end

	local conf = SixiangRingPowerUpConfig[ringType][powerUpType]
	if not conf then
		return
	end

	local var = getActorVar(actor)
	local ringVar = var[ringType]
	if ringVar.specialFlag == 1 then
		return
	end

	if (powerUpType == 1 and ringVar.specialFlag == 1) or (powerUpType == 2 and ringVar.normalFlag == 1) then
		return
	end

	if conf.wayType == 1 then
		if var.firstRankCount < conf.count then
			return
		end
	elseif conf.wayType == 2 then
		if not actoritem.checkItem(actor, conf.param1, conf.count) then
			return
		end

		actoritem.reduceItem(actor, conf.param1, conf.count, "sixiangring_powerup")
	elseif conf.wayType == 3 then
		if not actoritem.checkItem(actor, NumericType_YuanBao, conf.count) then
			return
		end

		actoritem.reduceItem(actor, NumericType_YuanBao, conf.count, "sixiangring_powerup")

		noticesystem.broadCastNotice(noticesystem.NTP.ringpowerup, LActor.getName(actor), conf.count, SixiangRingCommonConfig.ringName[ringType])
	else
		return
	end

	ringVar.specialFlag = (powerUpType == 1 and 1) or ringVar.specialFlag
	ringVar.normalFlag = (powerUpType == 2 and 1) or ringVar.normalFlag

	updateAttr(actor)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_SixiangRing, Protocol.sSixiangRingCmd_PowerUp)  
	LDataPack.writeChar(npack, ringType)
	LDataPack.writeChar(npack, ringVar.normalFlag)
	LDataPack.writeChar(npack, ringVar.specialFlag)
	LDataPack.flush(npack)

	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor))
			, "sixiangring_powerup", ringType, powerUpType)
end

function levelUp(actor, ringType)
	local conf = SixiangRingLevelConfig[ringType]
	if not conf then
		return
	end	

	local var = getActorVar(actor)
	local ringVar = var[ringType]
	if ringVar.level >= #conf then
		return
	end

	if ringVar.exp < conf[ringVar.level].exp then
		return
	end

	local oldExp = ringVar.exp
	ringVar.exp = ringVar.exp - conf[ringVar.level].exp
	ringVar.level = ringVar.level + 1

	updateAttr(actor)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_SixiangRing, Protocol.sSixiangRingCmd_LevelUp)  
	LDataPack.writeChar(npack, ringType)
	LDataPack.writeInt(npack, ringVar.exp)
	LDataPack.writeInt(npack, ringVar.level)
	LDataPack.flush(npack)

	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor))
			, "sixiangring_levelup", ringType, ringVar.level, oldExp, ringVar.exp)
end

function useItem(actor, ringType)
	local itemConf = SixiangRingItemConfig[ringType]
	if not itemConf then
		return
	end

	local levelConf = SixiangRingLevelConfig[ringType]
	if not levelConf then
		return
	end

	local var = getActorVar(actor)
	local ringVar = var[ringType]
	if ringVar.level >= #levelConf then
		return
	end	


	if ringVar.exp > levelConf[ringVar.level].exp then
		return
	end
	if LActor.getItemCount(actor, itemConf.itemId) < 1 then
		return 
	end

	actoritem.reduceItem(actor, itemConf.itemId, 1, "sixiangring_upexp")

	ringVar.exp = ringVar.exp + itemConf.exp

	expRequest_c2s(actor)
end

function addExp(actor)
	local curTime = System.getNowTime()
	local var = getActorVar(actor)
	local addExp = math.floor((curTime - var.updateTime)/60) * SixiangRingCommonConfig.addExp

	for i=1,4 do
		local ringVar = var[i]
		local conf = SixiangRingLevelConfig[i]
		if (ringVar.normalFlag == 1 or ringVar.specialFlag == 1) and ringVar.exp < 3*conf[ringVar.level].exp then
			ringVar.exp = ringVar.exp + addExp

			if ringVar.exp > 3*conf[ringVar.level].exp then
				ringVar.exp = 3*conf[ringVar.level].exp
			end
		end
	end
	var.updateTime = curTime
end


function getringattr(actor)
	local tAttr = {}
	local var = getActorVar(actor)
	for ringType=1,4 do
		repeat
			local ringVar = var[ringType]
			if ringVar.normalFlag == 0 and ringVar.specialFlag == 0 then
				break
			end

			local levelConf = SixiangRingLevelConfig[ringType]
			if not levelConf then
				break
			end

			local conf = levelConf[ringVar.level]
			if not conf then
				break
			end

			for _,t in pairs(conf.attr) do
				tAttr[t.type] = tAttr[t.type] or 0
				tAttr[t.type] = tAttr[t.type] + t.value
			end

			if ringVar.specialFlag == 1 then
				local attr = SixiangRingPowerUpConfig[ringType][1].attr or {}
				for _,t in pairs(attr) do
					tAttr[t.type] = tAttr[t.type] or 0
					tAttr[t.type] = tAttr[t.type] + t.value					
				end
			end
		until(true)
	end	

	return tAttr
end

function updateAttr(actor)
	local tAttr = {}
	tAttr = getringattr(actor)

	local attr = LActor.getActorSystemAttrs(actor, AttrActorSysId_SixiangRing)
	attr:Reset()
	for k, v in pairs(tAttr) do
		attr:Set(k, v)
	end

	LActor.reCalcAttr(actor)
end


function onInit(actor)
	addExp(actor)
	updateAttr(actor)
end

function onLogin(actor)
	dataSync(actor)

	 LActor.postScriptEventEx(actor, 60 * 1000,  function (actor) addExp(actor) end,
	 	60 * 1000,
	 	-1,
	 	actor
	 )
end


function onOpenRole(actor,count)
	updateAttr(actor)
end


function addMaxDamageBossCount(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.sxring) then return end
	
	local var = getActorVar(actor)
	var.firstRankCount = var.firstRankCount + 1
	dataSync(actor)
end

function powerUp_c2s(actor, packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.sxring) then return end

	local ringType = LDataPack.readChar(packet)
	local powerUpType = LDataPack.readChar(packet)
	powerUp(actor, ringType, powerUpType)
end

function levelUp_c2s(actor, packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.sxring) then return end

	local ringType = LDataPack.readChar(packet)
	levelUp(actor, ringType)
end

function useItem_c2s(actor, packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.sxring) then return end

	local ringType = LDataPack.readChar(packet)
	useItem(actor, ringType)
end

function expRequest_c2s(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.sxring) then return end
	
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_SixiangRing, Protocol.sSixiangRingCmd_ExpSync)  
	for ringType = 1,4 do
		local ringVar = var[ringType]
		LDataPack.writeInt(npack, ringVar.exp)
	end
	LDataPack.flush(npack)
end

function dataSync(actor)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_SixiangRing, Protocol.sSixiangRingCmd_Data)  
	if not npack then return end

	for ringType = 1,4 do
		local ringVar = var[ringType]
		LDataPack.writeChar(npack, ringType)
		LDataPack.writeChar(npack, ringVar.normalFlag)
		LDataPack.writeChar(npack, ringVar.specialFlag)
		LDataPack.writeInt(npack, ringVar.exp)
		LDataPack.writeInt(npack, ringVar.level)
	end
	LDataPack.writeInt(npack, var.firstRankCount)

	LDataPack.flush(npack)
end



actorevent.reg(aeInit,onInit)
actorevent.reg(aeUserLogin,onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
actorevent.reg(aeFirstBeatDespairBoss,addMaxDamageBossCount)

netmsgdispatcher.reg(Protocol.CMD_SixiangRing, Protocol.cSixiangRingCmd_PowerUp, powerUp_c2s)
netmsgdispatcher.reg(Protocol.CMD_SixiangRing, Protocol.cSixiangRingCmd_LevelUp, levelUp_c2s)
netmsgdispatcher.reg(Protocol.CMD_SixiangRing, Protocol.cSixiangRingCmd_UseItem, useItem_c2s)
netmsgdispatcher.reg(Protocol.CMD_SixiangRing, Protocol.cSixiangRingCmd_ExpRequest, expRequest_c2s)

