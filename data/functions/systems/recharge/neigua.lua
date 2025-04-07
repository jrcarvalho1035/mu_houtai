--内挂助手

module("neigua",package.seeall)

local function getData(actor) 
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	if var.neigua == nil then 
		var.neigua = {}
	end
	if var.neigua.starttime == nil then var.neigua.starttime = 0 end --开始购买时间
    if var.neigua.buycount == nil then var.neigua.buycount = 0 end
    if var.neigua.neiguaflag == nil then var.neigua.neiguaflag = 0 end
    if var.neigua.status == nil then var.neigua.status = 0 end
    if var.neigua.start == nil then var.neigua.start = 1 end

	return var.neigua
end

local function sendEndMall(actor)
	local actor_id = LActor.getActorId(actor)
    local var = getData(actor)
    
	local mail_data = {}
	mail_data.head       = neiguaConfig.endMailHead
	mail_data.context    = neiguaConfig.endMailContext
	mail_data.tAwardList = {}
	mailsystem.sendMailById(actor_id, mail_data)
end

local function sendMail(actorid)
	local mail_data = {}
	mail_data.head = neiguaConfig.mailHead
	mail_data.context = neiguaConfig.mailContext
	mail_data.tAwardList = neiguaConfig.mailAward
	mailsystem.sendMailById(actorid, mail_data)
end

--离特权卡状态结束还有多少秒
local function getSurplusTime(actor)
    local var = getData(actor)
    local remaintime = var.starttime + var.buycount * InvestConstConfig.day * 24 * 3600 - System.getNowTime()
    return remaintime > 0 and remaintime or 0
end

local function calcAttr(actor, calc)
	local var = getData(actor)
	if var.neiguaflag ~= 1 then
		if calc then
			local attr = LActor.getRoleSystemAttrs(actor, AttrActorSysId_Neigua)
			attr:Reset()
			LActor.reCalcAttr(actor)
		end
		return
	end
	local attr = LActor.getRoleSystemAttrs(actor, AttrActorSysId_Neigua)
    attr:Reset()
    for k,v in pairs(InvestConstConfig.attrs) do
        attr:Add(v.type, v.value)
    end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

local function sendneiguaData(actor)
	local var = getData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_NeiguaInfo)
	LDataPack.writeDouble(npack, getSurplusTime(actor))
    LDataPack.writeChar(npack, var.neiguaflag)
    LDataPack.writeInt(npack, var.status)
	LDataPack.flush(npack)
end


--特权卡结束时触发
local function timer(actor)
    local var = getData(actor)
	var.neiguaflag = 2
	var.buycount = 0
    var.starttime = 0
    var.status = 0
	calcAttr(actor, true)
	sendneiguaData(actor)
	--sendEndMall(actor)
end

local function updataTimer(actor) 
	local var = LActor.getDynamicVar(actor)	
	local sur = getSurplusTime(actor)
	if sur > 0 then 
		if var.neigua == nil then 
			var.neigua = {}
		else 
			LActor.cancelScriptEvent(actor,var.neigua.eid)
		end
		var.neigua.eid = LActor.postScriptEventLite(actor, sur * 1000, timer, actor)
	else
		local data = getData(actor)
		if data.buycount >= 1 and data.starttime > 0 then
			timer(actor)
		end
	end
end

--改变内挂助手状态
function changeneigua(actor, pack)
    local index = LDataPack.readChar(pack)
    local var = getData(actor)
    if getSurplusTime(actor) <= 0 then return end

    if System.bitOPMask(var.status, index) then
        var.status = System.bitOpSetMask(var.status, index, false)
    else
        var.status = System.bitOpSetMask(var.status, index, true)
    end
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_NeiguaStatus)
    LDataPack.writeChar(npack, index)
    LDataPack.writeChar(npack, System.bitOPMask(var.status, index) and 1 or 0)
    LDataPack.flush(npack)
end

function buyneigua(actor)    
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.neigua) then return end
	local var = getData(actor)

    if not actoritem.checkItem(actor, InvestConstConfig.consume.id, InvestConstConfig.consume.count) then
        return
    end
    actoritem.reduceItem(actor, InvestConstConfig.consume.id, InvestConstConfig.consume.count, "neigua buy")

	if var.buycount == 0 then
        var.starttime = System.getToday()
        var.buycount = 1
        var.status = 8388607
		--sendMail(LActor.getActorId(actor))
    else
        var.buycount = var.buycount + 1
    end
    var.neiguaflag = 1
	calcAttr(actor, true)
	updataTimer(actor)
    sendneiguaData(actor)
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_NeiguaIsFirst)
    LDataPack.writeChar(npack, var.buycount == 1 and 1 or 0)
    LDataPack.flush(npack)

	utils.logCounter(actor, "neigua buy")
end

local function onInit(actor)
	updataTimer(actor)
	calcAttr(actor, false)
end

local function onLogin(actor) 
	sendneiguaData(actor)
end

function checkOpenNeigua(actor, group)
    local var = getData(actor)
    for k,v in ipairs(GuaJiZhuShouConfig) do
        if v.fbGroup == group then
            return System.bitOPMask(var.status, k) and v.consumeCount or 1
        end
    end
end

function setConsumeTimes(count)
    local var = getData(actor)
    var.start = count
end

function getConsumeTimes(count)
    local var = getData(actor)
    return var.start
end

local function onNewDayArrive(actor, login)
	-- local var = getData(actor)
	-- if var.neiguaflag ~= 1 then
	-- 	return
	-- end
	-- sendMail(LActor.getActorId(actor))
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDayArrive)

netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_NeiguaChange, changeneigua)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_NeiguaBuy, buyneigua)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.buyneigua = function(actor) 
	buyneigua(actor)
	return true
end

gmCmdHandlers.setneigua = function(actor,args) 
	local second = tonumber(args[1])
	local dday
	if second then
		dday = (System.getNowTime() + second - System.getToday()) / 86400
	else
		dday = 30
	end
	InvestConstConfig.day = dday
	print (dday)
	return true
end
