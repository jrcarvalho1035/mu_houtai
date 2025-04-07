module("monthcard",package.seeall)

daySec = 24 * 60 * 60

local function getActorVar(actor) 
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	if var.monthCard == nil then var.monthCard = {} end
	if var.monthCard.time == nil then   --购买时间
		var.monthCard.time = System.getNowTime()
	end
	if var.monthCard.end_time == nil then  --结束时间
		var.monthCard.end_time = 0
	end
	if var.monthCard.surplus_day == nil then --还可领取的天数
		var.monthCard.surplus_day = 0
	end
	if var.monthCard.send_end_mall == nil then  --是否发了结束邮件
		var.monthCard.send_end_mall = 0
	end
	if var.monthCard.monthcard == nil then var.monthCard.monthcard = 0 end

	return var.monthCard
end

local function isSendEndMail(actor)
	local var = getActorVar(actor)
	if var.end_time == 0 then 
		return false
	end
	local curr = System.getNowTime()
	if var.end_time <= curr and var.send_end_mall == 0 then 
		return true
	end
	return false
end

local function sendEndMall(actor)
	local actor_id = LActor.getActorId(actor)
	local var = getActorVar(actor)
	if not isSendEndMail(actor) then 
		return
	end
	var.send_end_mall = 1
	local mail_data = {}
	mail_data.head       = MonthCardConfig.endMailHead
	mail_data.context    = MonthCardConfig.endMailContext
	mail_data.tAwardList = {}
	mailsystem.sendMailById(actor_id, mail_data)
	--print(LActor.getActorId(actor) .. " sendEndMall: ok")
end

--离月卡状态结束还有多少秒
local function getSurplusTime(actor) 
	local var = getActorVar(actor)
	local now = System.getNowTime()
	if now > var.end_time then 
		return 0
	else 
		return var.end_time - now
	end
end

function isBuyMonthCard(actor)
	local var = getActorVar(actor)
	return var.monthcard == 1
end

local function calcAttr(actor, calc)
	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Monthcard)
	attr:Reset()
	if getSurplusTime(actor) > 0 then
		for k,v in ipairs(MonthCardConfig.attr) do
			attr:Set(v.type, v.value)
		end
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

local function setMonthCardFlags(actor)
	--0为没购买1,为没过期,2为过期
	local var = getActorVar(actor) 
	if var.end_time == 0 then 
		var.monthcard = 0
	elseif var.end_time > System.getNowTime() then
		var.monthcard = 1
	else
		var.monthcard = 2
	end
	LActor.updataEquipBagCapacity(actor)

	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
		"monthcard", tostring(var.monthcard), tostring(var.end_time), "", "set", "", "")
end

local function sendMonthCardData(actor)
	local var = getActorVar(actor)
	if var == nil then 
		return
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_MonthCardData)
	if npack == nil then 
		return 
	end
	LDataPack.writeUInt(npack, getSurplusTime(actor))
	LDataPack.writeInt(npack, var.monthcard)
	LDataPack.flush(npack)
end

function getFightPlus(actor)
	local var = getActorVar(actor)
	if var.monthcard == 1 then
		return MonthCardConfig.quickFightPlus / 10000
	end
	return 0
end


--月卡结束时触发
local function timer(actor)
	calcAttr(actor, true)
	setMonthCardFlags(actor)
	sendMonthCardData(actor)
	sendEndMall(actor)
end

local function updataTimer(actor) 
	local dvar = LActor.getDynamicVar(actor)
	local sur = getSurplusTime(actor)
	if sur > 0 then 
		if dvar.monthcard == nil then 
			dvar.monthcard = {}
		else 
			LActor.cancelScriptEvent(actor, dvar.monthcard.eid)
		end
		dvar.monthcard.eid = LActor.postScriptEventLite(actor, sur * 1000, timer, actor)
	else	
		local var = getActorVar(actor)	
		if var.monthcard == 1 then
			timer(actor)
		end
	end
end

function isOpenMonthCard(actor) 
	local var = getActorVar(actor) 
	return System.getNowTime() < var.end_time
end

function subDay(actor) 
	local is_open = isOpenMonthCard(actor)
	if not is_open then
		return 0
	end

	local var = getActorVar(actor)
	local now = System.getNowTime() 
	local sub = math.floor(now / daySec) - math.floor(var.time / daySec)
	if sub > 0 then
		sub = math.min(sub, var.surplus_day)
		var.surplus_day = var.surplus_day - sub
		var.time = now
	end
	return sub
end

local function sendMail(actorid,size) 
	if size > 0 then
		local actor = LActor.getActorById(actorid)
		if actor then
			actorevent.onEvent(actor, aeMonthCardReward) --月卡奖励事件
		end
	end
	while (size > 0) do 
		local mail_data = {}
		mail_data.head = MonthCardConfig.mailHead
		mail_data.context = MonthCardConfig.mailContext
		mail_data.tAwardList = MonthCardConfig.mailAward
		mailsystem.sendMailById(actorid,mail_data)
		size = size - 1
	end
end



function buyMonthCard(actor)
	local var = getActorVar(actor)
	local now = System.getNowTime()
	local zeroTime = System.getToday() --购买月卡按照凌晨时间来计算购买时间
	-- var.surplus_day = var.surplus_day + MonthCardConfig.buyDay
	-- if var.end_time > now then --在月卡的时限内，顺延月卡时间
	-- 	var.end_time = var.end_time + (MonthCardConfig.buyDay * daySec)
	-- else
	-- 	var.end_time = now + (MonthCardConfig.buyDay * daySec)
	-- 	var.surplus_day = var.surplus_day - 1
	-- 	var.time = now
	-- 	sendMail(LActor.getActorId(actor), 1)
	-- end

	local is_open = isOpenMonthCard(actor)
	var.surplus_day = var.surplus_day + MonthCardConfig.buyDay
	if not is_open then
		var.end_time = zeroTime + (MonthCardConfig.buyDay * daySec)		
		var.time = zeroTime
		sendMail(LActor.getActorId(actor),1)
		var.surplus_day = var.surplus_day - 1
	else --已购月卡，顺延
		var.end_time = var.end_time + (MonthCardConfig.buyDay * daySec) 
	end
	actoritem.addItem(actor, NumericType_Diamond, MonthCardConfig.diamond, "monthcard buy")
	calcAttr(actor, true)
	updataTimer(actor)
	setMonthCardFlags(actor)
	sendMonthCardData(actor)

	rechargesystem.addVipExp(actor, MonthCardConfig.money)
	
	var.send_end_mall = 0
	LActor.sendTipmsg(actor, ScriptTips.actor004, ttMessage)
	print( LActor.getActorId(actor) .. " buyMonthCard: ok")
	utils.logCounter(actor, "monthCard buy")
end

function buy(actorid) 
	local actor = LActor.getActorById(actorid)
	if actor then
		buyMonthCard(actor)
	else
		local npack = LDataPack.allocPacket()
		System.sendOffMsg(actorid, 0, OffMsgType_MonthCard, npack)
	end
end

function OffMsgMonthCard(actor, offmsg)
	print(string.format("OffMsgMonthCard actorid:%d ", LActor.getActorId(actor)))
	buyMonthCard(actor)
end

local function onBeforeLogin(actor) 
	-- print("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- monthcard -=-=-=-=-=-=-=-==-=-=-=-=-=-=")
	sendMail(LActor.getActorId(actor), subDay(actor)) --newday的计算时间有误差，所以要每次登录验证月卡邮件是否要发送
end

local function onInit(actor)
	updataTimer(actor)
	calcAttr(actor, false)
end

local function onLogin(actor) 
	--setMonthCardFlags(actor)
	sendMonthCardData(actor)
end

local function onNewDayArrive(actor, login)
	sendMail(LActor.getActorId(actor), subDay(actor))
	calcAttr(actor, false)
	--setMonthCardFlags(actor)
	if not login then
		sendMonthCardData(actor)
	end
end

msgsystem.regHandle(OffMsgType_MonthCard, OffMsgMonthCard)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeNewDayArrive, onNewDayArrive)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onBeforeLogin)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.buymonthcard = function(actor) 
	buyMonthCard(actor)
	return true
end

gmCmdHandlers.clearmonthcard = function(actor) 
	local var = getActorVar(actor)
	var.time = System.getNowTime()
	var.end_time = 0
	var.surplus_day = 0
	var.send_end_mall = 0
	setMonthCardFlags(actor)
	sendMonthCardData(actor)
	return true
end
