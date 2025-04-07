
module("eightinvest",package.seeall)

local function getData(actor) 
    local var = LActor.getStaticVar(actor)
    if not var.eightinvest then var.eightinvest = {} end
    if not var.eightinvest.isinvest then var.eightinvest.isinvest = 0 end
    if not var.eightinvest.status then var.eightinvest.status = 0 end

    return var.eightinvest
end

--发送奖励
function sendMail(actor, index)
    local mail_data = {}
    mail_data.head = InvestConstConfig.mailHead
    mail_data.context = string.format(InvestConstConfig.mailContext, index)
    mail_data.tAwardList = EightInvestConfig[index].reward
    mailsystem.sendMailById(LActor.getActorId(actor), mail_data)
end

--抢购八天投资
function buyEightInvest(actor)
    local data = getData(actor)
    if data.isinvest == 1 then
        return
    end
    data.isinvest = 1

    local adata = LActor.getActorData(actor)
	adata.recharge = adata.recharge + InvestConstConfig.eightmoney
    actorevent.onEvent(actor, aeRecharge, InvestConstConfig.eightmoney, 1)
    
    local openday = math.min(8, System.getOpenServerDay() + 1)
    for i=openday, 1, -1 do        
        data.status = System.bitOpSetMask(data.status, i, true)
        sendMail(actor, i)
    end

    sendEightInvestData(actor)
    return true
end

function buy(actorid) 
	local actor = LActor.getActorById(actorid)
	if actor then
		buyEightInvest(actor)
	else
		local pack = LDataPack.allocPacket()
		System.sendOffMsg(actorid, 0, OffMsgType_EightInvest, pack)
	end
end

--发送投资信息
function sendEightInvestData(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_EightInvestInfo)
    local data = getData(actor)
    LDataPack.writeChar(pack, data.isinvest)
    LDataPack.writeInt(pack, data.status)
    
    LDataPack.flush(pack)
end

function OffMsgEightInvest(actor, offmsg)
	print(string.format("OffMsgEightInvest actorid:%d ", LActor.getActorId(actor)))
	buyEightInvest(actor)
end

local function onLogin(actor) 
	sendEightInvestData(actor)
end

local function onNewDayArrive(actor, login)    
    local data = getData(actor)
    if data.isinvest ~= 1 then
        return
    end
    local openday = math.min(8, System.getOpenServerDay() + 1)
    
    for i=1, openday do
        if not System.bitOPMask(data.status, i) then
            data.status = System.bitOpSetMask(data.status, openday, true)
            sendMail(actor, openday)
        end
    end
end

msgsystem.regHandle(OffMsgType_EightInvest, OffMsgEightInvest)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDayArrive)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.buyeight = function(actor) 
	buyEightInvest(actor)
	return true
end

gmCmdHandlers.eightitem = function(actor) 
	buyEightInvest(actor)
	return true
end
