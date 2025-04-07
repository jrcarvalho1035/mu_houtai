-- @version	2.0
-- @author	qianmeng
-- @date	2017-10-26 17:48:36.
-- @system	大富翁系统

module("tanmisystem", package.seeall)
require("tanmi.ceil")
require("tanmi.floor")
require("tanmi.step")
require("tanmi.tanmicommon")
require("tanmi.miwenstore")
require("tanmi.qizhenstore")

function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if var.tanmiVar == nil then
		var.tanmiVar = {}
		var.tanmiVar.pos = 0
		var.tanmiVar.miwen = 0
		var.tanmiVar.qizhen = 0
		var.tanmiVar.freeCount = 0
		var.tanmiVar.roundCount = 0
		var.tanmiVar.stepCount = 0
		var.tanmiVar.refreshTime = 0
		var.tanmiVar.floorAward = {}
		var.tanmiVar.stepAward = {}
	end
	return var.tanmiVar
end

function isSystemOpen(actor)
	return actorexp.checkLevelCondition(actor, actorexp.LimitTp.tanmi) 
end

--把这个格子的奖励拿走
function givePosAward(actor, pos)
	local config = TanMiCeilConf[pos]
	if not config then return end
	actoritem.addItem(actor, config.id, config.count, "tanmi pos", 2) --屏幕提示
	if ItemConfig[config.id] then
		noticesystem.broadCastNotice(noticesystem.NTP.tanmi1, LActor.getActorName(LActor.getActorId(actor)))
	end
end

--邮件发送层数奖励
function sendFloorAwardMail(actor)
	local actorVar = getActorVar(actor)
	local floor = math.ceil(actorVar.pos/16)
	for index, t in pairs(TanMiFloorConf) do
		if floor >= t.floor and actorVar.floorAward[index] ~= 2 then
			local mailData = {head = TanMiCommonConf.floorMailHead, context = TanMiCommonConf.floorMailContent, tAwardList=t.items}
			mailsystem.sendMailById(LActor.getActorId(actor), mailData)
			actorVar.floorAward[index] = 2		
		end
	end
end

--邮件发送步数奖励
function sendStepAwardMail(actor)
	local actorVar = getActorVar(actor)
	for index,t in pairs(TanMiStepConf) do
		if actorVar.stepCount >= t.step and actorVar.stepAward[index] ~= 2 then
			local mailData = {head = TanMiCommonConf.stepMailHead, context = TanMiCommonConf.stepMailContent, tAwardList=t.items}
			mailsystem.sendMailById(LActor.getActorId(actor), mailData)
			actorVar.stepAward[index] = 2		
		end
	end
end

--黑石兑换
function darkstoneExchange(actor, index, count)
	local config = TanMiMiwenStore[index]
	if not config then return end
	local day = System.getOpenServerDay()
	if day < config.day then return end
	if not actoritem.checkItemSpace(actor, config.id, config.count * count) then
		return
	end
	if not actoritem.checkItem(actor, NumericType_DarkStone, config.price * count) then
		return
	end
	actoritem.reduceItem(actor, NumericType_DarkStone, config.price * count, "dark exchange:"..config.id..";"..config.count * count)
	actoritem.addItem(actor, config.id, config.count * count, "dark exchange")
	utils.logCounter(actor, "othersystem", config.id, "", "tanmi", "darkexchange")
end

--先魂兑换
function seersoulExchange(actor, index, count)
	local config = TanMiQizhenStore[index]
	if not config then return end
	local day = System.getOpenServerDay()
	if day < config.day then return end
	if not actoritem.checkItemSpace(actor, config.id, config.count * count) then
		return
	end
	if not actoritem.checkItem(actor, NumericType_SeerSoul, config.price * count) then
		return
	end
	actoritem.reduceItem(actor, NumericType_SeerSoul, config.price * count, "seer exchange:"..config.id..";"..config.count * count)
	actoritem.addItem(actor, config.id, config.count * count, "seer exchange")
	utils.logCounter(actor, "othersystem", config.id, "", "tanmi", "seerexchange")
end

--每周更新
function tanmiTimeUpReset(actor)
	local actorVar = getActorVar(actor)
	local nowTime = System.getNowTime()
	--没初始化的话就给他初始化
	if actorVar.refreshTime == 0 then
		actorVar.refreshTime = nowTime
	end

	if not System.isSameWeek(actorVar.refreshTime, nowTime) then
		actorVar.refreshTime = nowTime
		sendStepAwardMail(actor)
		sendFloorAwardMail(actor)

		actorVar.pos = 0
		actorVar.freeCount = 0
		actorVar.roundCount = 0
		actorVar.stepCount = 0
		actorVar.floorAward = {}
		actorVar.stepAward = {}
	end
end

--每日更新
function tanmiDailyReset(actor)
	sendStepAwardMail(actor)
	
	local actorVar = getActorVar(actor)
	if actorVar.roundCount >= TanMiCommonConf.MaxRound and actorVar.pos >= #TanMiCeilConf then
		sendFloorAwardMail(actor)
		actorVar.floorAward = {}
		actorVar.pos = 0
	end
	actorVar.freeCount = 0
	actorVar.roundCount = 0
	actorVar.stepCount = 0	
	actorVar.stepAward = {}
end

function onLogin(actor)
	if not isSystemOpen(actor) then return end
	tanmiTimeUpReset(actor)
	c2sTanmiInfo(actor)
end

function onNewDay(actor, login)
	if not isSystemOpen(actor) then return end	
	tanmiTimeUpReset(actor)
	tanmiDailyReset(actor)

	if not login then
		c2sTanmiInfo(actor)
	end
end

function onLevelUp(actor, level, oldLevel)
	local lv = actorexp.getLimitLevel(actor,actorexp.LimitTp.tanmi)
	if lv > oldLevel and lv <= level and isSystemOpen(actor) then
		tanmiTimeUpReset(actor)
		c2sTanmiInfo(actor)
	end
end

--------------------------------------------------------------------------------------
--探秘信息
function c2sTanmiInfo(actor)
	local actorVar = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tanmi, Protocol.sTanmiCmd_Info) 
	LDataPack.writeInt(npack, actorVar.pos) --当前格子数
	LDataPack.writeChar(npack, TanMiCommonConf.freeCount - actorVar.freeCount) --剩余免费次数
	LDataPack.writeChar(npack, TanMiCommonConf.MaxRound - actorVar.roundCount) --今日已走轮次
	LDataPack.writeInt(npack, actorVar.stepCount) --今日已走步数

	LDataPack.writeInt(npack, #TanMiFloorConf)
	local floor = math.ceil(actorVar.pos/16)
	for index,t in ipairs(TanMiFloorConf) do
		LDataPack.writeInt(npack, index)
		if floor < t.floor then
			LDataPack.writeChar(npack, 0)
		elseif actorVar.floorAward[index] == 2 then
			LDataPack.writeChar(npack, 2)
		else
			LDataPack.writeChar(npack, 1)
		end
	end

	LDataPack.writeInt(npack, #TanMiStepConf)
	for index,t in ipairs(TanMiStepConf) do
		LDataPack.writeInt(npack, index)
		if actorVar.stepCount < t.step then
			LDataPack.writeChar(npack, 0)
		elseif actorVar.stepAward[index] == 2 then
			LDataPack.writeChar(npack, 2)
		else
			LDataPack.writeChar(npack, 1)
		end
	end
	LDataPack.flush(npack)
end

--摇骰子
function c2sTanmiRoll(actor)
	if not isSystemOpen(actor) then return end

	local actorVar = getActorVar(actor)
	if actorVar.freeCount >= TanMiCommonConf.freeCount 
	and	(not actoritem.checkItem(actor, TanMiCommonConf.itemId, 1))
	and	(not actoritem.checkItem(actor, NumericType_YuanBao, TanMiCommonConf.ybCost)) then
		return
	end

	if actorVar.pos >= #TanMiCeilConf and actorVar.roundCount >= TanMiCommonConf.MaxRound then
		return
	end

	if actorVar.freeCount < TanMiCommonConf.freeCount then
		actorVar.freeCount = actorVar.freeCount + 1
	else
		if actoritem.checkItem(actor, TanMiCommonConf.itemId, 1)  then
			actoritem.reduceItem(actor, TanMiCommonConf.itemId, 1, "tanmiRollDice")
		else
			actoritem.reduceItem(actor, NumericType_YuanBao, TanMiCommonConf.ybCost, "tanmiRollDice")
		end
	end

	local step = math.random(6) --随机步数
	if actorVar.pos + step >= #TanMiCeilConf and actorVar.roundCount >= TanMiCommonConf.MaxRound then
		step = #TanMiCeilConf - actorVar.pos
	end

	actorVar.pos = actorVar.pos + step
	if actorVar.pos > #TanMiCeilConf then --走进下一轮次
		sendFloorAwardMail(actor) --没领的层数奖励邮件下发
		actorVar.floorAward = {}

		actorVar.pos = actorVar.pos - #TanMiCeilConf
		actorVar.roundCount = actorVar.roundCount + 1
	end

	actorVar.stepCount = actorVar.stepCount + step
	
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tanmi, Protocol.sTanmiCmd_Roll)   
	LDataPack.writeChar(npack, step)
	LDataPack.writeInt(npack, actorVar.pos)
	LDataPack.writeChar(npack, TanMiCommonConf.freeCount - actorVar.freeCount)
	LDataPack.writeChar(npack, TanMiCommonConf.MaxRound - actorVar.roundCount)
	LDataPack.writeInt(npack, actorVar.stepCount)
	LDataPack.flush(npack)

	givePosAward(actor, actorVar.pos)

	utils.logCounter(actor, "othersystem", math.ceil(actorVar.pos/16), "", "tanmi", "roll")
end

--领层数奖励
function c2sTanmiFloorReward(actor, packet)
	local index = LDataPack.readInt(packet)
	s2cFloorReward(actor, index)
end

function s2cFloorReward(actor, index)
	local config = TanMiFloorConf[index]
	if not config then return end

	local actorVar = getActorVar(actor)
	local floor = math.ceil((actorVar.pos or 0)/16)
	if floor < config.floor	then
		return
	end

	if actorVar.floorAward[index] == 2 then
		return
	end

	actorVar.floorAward[index] = 2
	actoritem.addItemsByMail(actor, config.items, "tanmiFloorAward", 0, "tanmifloor")

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tanmi, Protocol.sTanmiCmd_FloorReward)   
	LDataPack.writeInt(npack, index)
	LDataPack.writeChar(npack, 2)
	LDataPack.flush(npack)
end

--领步数奖励
function c2sTanmiStepReward(actor, packet)
	local index = LDataPack.readInt(packet)
	s2cStepReward(actor, index)
end

function s2cStepReward(actor, index)
	local config = TanMiStepConf[index]
	if not config then return end

	local actorVar = getActorVar(actor)
	if actorVar.stepCount < config.step	then
		return
	end	

	if actorVar.stepAward[index] == 2 then
		return
	end

	actorVar.stepAward[index] = 2
	actoritem.addItemsByMail(actor, config.items, "tanmiStepAward", 0, "tanmistep")

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tanmi, Protocol.sTanmiCmd_StepReward)   
	LDataPack.writeInt(npack, index)
	LDataPack.writeChar(npack, 2)
	LDataPack.flush(npack)
end

--兑换
function c2sExchange(actor, packet)
	local stype = LDataPack.readChar(packet)
	local index = LDataPack.readInt(packet)
	local count = LDataPack.readShort(packet)
	if stype == 0 then
		darkstoneExchange(actor, index, count)
	else
		seersoulExchange(actor, index, count)
	end
end


actorevent.reg(aeUserLogin,onLogin)
actorevent.reg(aeNewDayArrive,onNewDay)
actorevent.reg(aeLevel, onLevelUp)

netmsgdispatcher.reg(Protocol.CMD_Tanmi, Protocol.cTanmiCmd_Info, c2sTanmiInfo)
netmsgdispatcher.reg(Protocol.CMD_Tanmi, Protocol.cTanmiCmd_Roll, c2sTanmiRoll)
netmsgdispatcher.reg(Protocol.CMD_Tanmi, Protocol.cTanmiCmd_FloorReward, c2sTanmiFloorReward)
netmsgdispatcher.reg(Protocol.CMD_Tanmi, Protocol.cTanmiCmd_StepReward, c2sTanmiStepReward)
netmsgdispatcher.reg(Protocol.CMD_Tanmi, Protocol.cTanmiCmd_Exchange, c2sExchange)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.tanmiinfo = function (actor, args)
	c2sTanmiInfo(actor)
end

gmCmdHandlers.tanmiroll = function (actor, args)
	c2sTanmiRoll(actor)
end

gmCmdHandlers.tanmifloor = function (actor, args)
	s2cFloorReward(actor, tonumber(args[1]))
end

gmCmdHandlers.tanmistep = function (actor, args)
	s2cStepReward(actor, tonumber(args[1]))
end

gmCmdHandlers.tanmiexchange = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeInt(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sExchange(actor, pack)
end

gmCmdHandlers.settanmiStep = function (actor, args)
	local actorVar = getActorVar(actor)
	actorVar.pos = tonumber(args[1])
	c2sTanmiInfo(actor)
end
