
module("levelinvest",package.seeall)

local function getData(actor) 
    local var = LActor.getStaticVar(actor)
    if not var.levelinvest then var.levelinvest = {} end
    if not var.levelinvest.isinvest then var.levelinvest.isinvest = 0 end
    if not var.levelinvest.status then var.levelinvest.status = 0 end

    return var.levelinvest
end

--抢购等级投资
function buyLevelInvest(actor)
    local data = getData(actor)
    if data.isinvest == 1 then
        return
    end
    data.isinvest = 1

    local data = LActor.getActorData(actor)
	data.recharge = data.recharge + InvestConstConfig.levelmoney
    actorevent.onEvent(actor, aeRecharge, InvestConstConfig.levelmoney, 1)
    sendLevelInvestData(actor)
end

function buy(actorid) 
	local actor = LActor.getActorById(actorid)
	if actor then
		buyLevelInvest(actor)
	else
		local npack = LDataPack.allocPacket()
		System.sendOffMsg(actorid, 0, OffMsgType_LevelInvest, npack)
	end
end

--领取投资奖励
function c2sgetReward(actor, pack)
    local data = getData(actor)
    if data.isinvest ~= 1 then
        return
    end
    local id = LDataPack.readChar(pack)
    local conf = LevelInvestConfig[id]
    if not conf then
        return
    end
    if conf.level > LActor.getLevel(actor) then
        return
    end
    if System.bitOPMask(data.status, id) then
		return
    end
    data.status = System.bitOpSetMask(data.status, id, true)
    actoritem.addItems(actor, conf.reward, "level invest")
    sendLevelInvestData(actor)
end

--发送投资信息
function sendLevelInvestData(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_LevelInvestInfo)
    local data = getData(actor)
    LDataPack.writeChar(pack, data.isinvest)
    LDataPack.writeInt(pack, data.status)
    
    LDataPack.flush(pack)
end

function OffMsgLevelInvest(actor, offmsg)
	print(string.format("OffMsgLevelInvest actorid:%d ", LActor.getActorId(actor)))
	buyLevelInvest(actor)
end

local function onLogin(actor) 
	sendLevelInvestData(actor)
end

actorevent.reg(aeUserLogin, onLogin)
msgsystem.regHandle(OffMsgType_LevelInvest, OffMsgLevelInvest)

netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_GetLevelInvest, c2sgetReward)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.buylevel = function(actor) 
	buyLevelInvest(actor)
	return true
end
