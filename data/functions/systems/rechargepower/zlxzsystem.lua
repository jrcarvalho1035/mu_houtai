--战力勋章
module("zlxzsystem", package.seeall)

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.zlxz then var.zlxz = {} end
    if not var.zlxz.status then var.zlxz.status = 0 end --是否购买
    if not var.zlxz.getid then var.zlxz.getid = 0 end --已领取到第几个配置id
    return var.zlxz
end


function updateAttr(actor, calc)
    local addAttrs = {}
	local var = getActorVar(actor)
    local power = 0

    if var.status >= 1 then
        local conf = SkillPassiveConfig[RechagePowerConstConfig.zlxzskill][passiveskill.getSkillLv(actor, RechagePowerConstConfig.zlxzskill)]
        power = power + conf.power
    end
    if var.getid > 0 then        
        for k, attr in ipairs(ZLXZConfig[var.getid].attr) do
            addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
        end
    end

	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_ZLXZ)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
    end
    attr:SetExtraPower(power)
	if calc then
		LActor.reCalcAttr(actor)
	end
end

function c2sGet(actor)
    local var = getActorVar(actor)
    if var.status ~= 1 then return end
    if not actoritem.checkEquipBagSpaceJob(actor, RechagePowerConstConfig.zlxzreward) then
        return 
    end
    var.status = 2
    actoritem.addItems(actor, RechagePowerConstConfig.zlxzreward, "zlxz buy")
    actoritem.addItem(actor, NumericType_Diamond, RechagePowerConstConfig.zlxzmoshi, "zlxz buy")
    LActor.setPassiveLevel(actor, RechagePowerConstConfig.zlxzskill, 1)
    s2cUpdateStatus(actor)
end

function s2cUpdateStatus(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_RechargePower, Protocol.sRPowerCmd_ZLXZUpdate)
    if not pack then return end
    local var = getActorVar(actor)
    LDataPack.writeChar(pack, var.status)
    LDataPack.flush(pack)  
end

function c2sGetReward(actor)
    local var = getActorVar(actor)
    if var.status ~= 2 then return end
    local change = false
    for i=var.getid + 1, #ZLXZConfig do
        if zhuansheng.checkZSLevel(actor, ZLXZConfig[i].zhuansheng) then
            var.getid = i
            change = true
        else
            break
        end
    end
    if not change then return end
    updateAttr(actor, true)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_RechargePower, Protocol.sRPowerCmd_ZLXZGetReward)
    if not pack then return end
    local var = getActorVar(actor)
    LDataPack.writeShort(pack, var.getid)
    LDataPack.flush(pack)  
end

function sendTotalInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_RechargePower, Protocol.sRPowerCmd_ZLXZInfo)
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
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zlxz) then return end
    updateAttr(actor)
end

function buyZLXZ(actor)
    local var = getActorVar(actor)
    if var.status ~= 0 then
        return
    end
    var.status = 1
    rechargesystem.addVipExp(actor, RechagePowerConstConfig.zlxzbuycount)
    s2cUpdateStatus(actor)
    updateAttr(actor, true)
end

function buy(actorid) 
	local actor = LActor.getActorById(actorid)
	if actor then
		buyZLXZ(actor)
	else
		local pack = LDataPack.allocPacket()
		System.sendOffMsg(actorid, 0, OffMsgType_BuyZLXZ, pack)
	end
end

function OffMsgBuyZLXZ(actor, offmsg)
	print(string.format("OffMsgZLXZInvest actorid:%d ", LActor.getActorId(actor)))
	buyZLXZ(actor)
end



msgsystem.regHandle(OffMsgType_BuyZLXZ, OffMsgBuyZLXZ)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

local function init()
    --if System.isBattleSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_RechargePower, Protocol.cRPowerCmd_ZLXZGet, c2sGet)
    netmsgdispatcher.reg(Protocol.CMD_RechargePower, Protocol.cRPowerCmd_ZLXZGetReward, c2sGetReward)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.buyzlxz = function(actor) 
	buyZLXZ(actor)
	return true
end

gmCmdHandlers.zlxzAll = function (actor, args)
    local var = getActorVar(actor)
    var.status = 2
    var.getid = #ZLXZConfig
    updateAttr(actor, true)
    onLogin(actor)
end
