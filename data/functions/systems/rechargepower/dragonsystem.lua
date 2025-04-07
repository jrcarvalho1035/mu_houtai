--黄金圣龙
module("dragonsystem", package.seeall)

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.dragon then var.dragon = {} end
    if not var.dragon.status then var.dragon.status = 0 end --是否购买
    if not var.dragon.getid then var.dragon.getid = 0 end --已领取到第几个配置id
    return var.dragon
end


function updateAttr(actor, calc)
    local addAttrs = {}
	local var = getActorVar(actor)

    if var.status == 2 then
        for k, attr in pairs(RechagePowerConstConfig.zclattrs) do
            addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
        end
    end

	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Dragon)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

function c2sGet(actor)
    local var = getActorVar(actor)
    if var.status ~= 1 then return end
    if not actoritem.checkEquipBagSpaceJob(actor, RechagePowerConstConfig.zclreward) then
        return 
    end
    actoritem.addItems(actor, RechagePowerConstConfig.zclreward, "dragon buy")
    actoritem.addItem(actor, NumericType_Diamond, RechagePowerConstConfig.zclmoshi, "dragon buy")
    var.status = 2
    updateAttr(actor, true)
    
    s2cUpdateStatus(actor)
end

function s2cUpdateStatus(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_RechargePower, Protocol.sRPowerCmd_ZCLUpdate)
    if not pack then return end
    local var = getActorVar(actor)
    LDataPack.writeChar(pack, var.status)
    LDataPack.flush(pack)  
end

function c2sGetReward(actor)
    local var = getActorVar(actor)
    if var.status ~= 2 then return end
    
    local addyuanbao = 0
    for i=var.getid + 1, #ZCLConfig do
        if zhuansheng.checkZSLevel(actor, ZCLConfig[i].zhuansheng) then
            addyuanbao = addyuanbao + ZCLConfig[i].yuanbao
            var.getid = i
        else
            break
        end
    end
    if addyuanbao == 0 then return end
    
    actoritem.addItem(actor, NumericType_YuanBao, addyuanbao, "dragon get reward")

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_RechargePower, Protocol.sRPowerCmd_ZCLGetReward)
    if not pack then return end
    local var = getActorVar(actor)
    LDataPack.writeShort(pack, var.getid)
    LDataPack.flush(pack)
end

function sendTotalInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_RechargePower, Protocol.sRPowerCmd_ZCLInfo)
    if not pack then return end
    local var = getActorVar(actor)    
    LDataPack.writeChar(pack, var.status)
    LDataPack.writeShort(pack, var.getid)
    LDataPack.flush(pack)    
end

function onLogin(actor)
    sendTotalInfo(actor)
end


function onInit(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.dragon) then return end
    updateAttr(actor)
end

function buyDragon(actor)
    local var = getActorVar(actor)
    if var.status ~= 0 then
        return
    end
    var.status = 1
    rechargesystem.addVipExp(actor, RechagePowerConstConfig.zclbuycount)
    s2cUpdateStatus(actor)
end

function buy(actorid) 
	local actor = LActor.getActorById(actorid)
	if actor then
		buyDragon(actor)
	else
		local pack = LDataPack.allocPacket()
		System.sendOffMsg(actorid, 0, OffMsgType_BuyDragon, pack)
	end
end

function OffMsgBuyDragon(actor, offmsg)
	print(string.format("OffMsgDragonInvest actorid:%d ", LActor.getActorId(actor)))
	buyDragon(actor)
end



msgsystem.regHandle(OffMsgType_BuyDragon, OffMsgBuyDragon)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

local function init()
    --if System.isBattleSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_RechargePower, Protocol.cRPowerCmd_ZCLGet, c2sGet)
    netmsgdispatcher.reg(Protocol.CMD_RechargePower, Protocol.cRPowerCmd_ZCLGetReward, c2sGetReward)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.buydragon = function(actor) 
	buyDragon(actor)
	return true
end
