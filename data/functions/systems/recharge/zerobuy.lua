--0元购
module("zerobuy", package.seeall)

--0元购
local function getStaticVar(actor)
	local var = LActor.getStaticVar(actor)
    if not var.zerobuy then var.zerobuy = {} end
    if not var.zerobuy.isbuy then var.zerobuy.isbuy = 0 end
	return var.zerobuy
end


--0元购购买
function zeroBuy(actor, count)
    local var = getStaticVar(actor)
    local index = 0
    for i=1, #ZeroBuyConfig do
        if count == ZeroBuyConfig[i].money then
            index = i
        end
    end
    if index == 0 then
        return
    end
    if var.isbuy ~= 0 then
        return
    end
    var.isbuy = index
    actoritem.addItems(actor, ZeroBuyConfig[index].reward, "zero buy")
    local data = LActor.getActorData(actor)
    data.recharge = data.recharge + count
    actorevent.onEvent(actor, aeRecharge, count, 1)
    sendInfo(actor)
end

--是否是0元购的数额
function isZeroBuy(count)
    for i=1, #ZeroBuyConfig do
        if count == ZeroBuyConfig[i].money then
            return true
        end
    end
    return false
end

--发送0元购信息
function sendInfo(actor)
    local var = getStaticVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_ZeroBuyInfo)    
    LDataPack.writeChar(pack, var.isbuy)
    LDataPack.flush(pack)
end

--
function buy(actorid, count)
	local actor = LActor.getActorById(actorid)
	if actor then
		zeroBuy(actor, count)
	else
		local npack = LDataPack.allocPacket()
		System.sendOffMsg(actorid, 0, OffMsgType_ZeroBuy, npack)
	end
end

function OffMsgZeroBuy(actor, offmsg)
    local count = LDataPack.readByte(offmsg)
    zeroBuy(actor, count)
end


function onLogin(actor)
    sendInfo(actor)
end

function onNewDay(actor, login)
    local var = getStaticVar(actor)
    if var.isbuy ~= 0 then
        local actorid = LActor.getActorId(actor)
        
        local maildata = {}
        maildata.head       = InvestConstConfig.zeroHead
        maildata.context    = InvestConstConfig.zeroContext
        maildata.tAwardList = {{type = 0, id = NumericType_YuanBao, count = ZeroBuyConfig[var.isbuy].money}}
        mailsystem.sendMailById(actorid, maildata)
    end
    var.isbuy = 0
    if not login then
        sendInfo(actor)
    end
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
msgsystem.regHandle(OffMsgType_ZeroBuy, OffMsgZeroBuy)



local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.zerobuy = function(actor, args) 
    zeroBuy(actor, tonumber(args[1]))
	return true
end
