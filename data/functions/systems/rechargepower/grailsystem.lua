--不朽圣杯
module("grailsystem", package.seeall)

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.grail then 
        var.grail = {
            status = 0,
            stone = {}            
        } 
        for i=1, #GrailStoneConfig do
            var.grail.stone[i] = 0
        end
    end
    return var.grail
end


function updateAttr(actor, calc)
    
	local var = getActorVar(actor)
    if var.status ~= 2 then return end

    local addAttrs = {}
    local power = 0

    for k, attr in ipairs(RechagePowerConstConfig.grailattr) do
        addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
    end
    local per = 0
    for k,v in ipairs(GrailStoneConfig) do
        if var.stone[k] ~= 0 then
            per = per + v[var.stone[k]].percent
        end
    end
	
    power = power + SkillPassiveConfig[RechagePowerConstConfig.grailskill][1].power
    for k,v in pairs(addAttrs) do
        addAttrs[k] = math.floor(addAttrs[k] * (1 + per/10000))
    end

    for k,v in ipairs(GrailStoneConfig) do
        if var.stone[k] ~= 0 then
            for __,attr in ipairs(v[var.stone[k]].attr) do
                addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
            end
            power = power + v[var.stone[k]].power
        end
    end

	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Grail)
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
    if not actoritem.checkEquipBagSpaceJob(actor, RechagePowerConstConfig.grailreward) then
        return 
    end
    var.status = 2
    updateAttr(actor, true)
    LActor.setPassiveLevel(actor, RechagePowerConstConfig.grailskill, 1)
    actoritem.addItems(actor, RechagePowerConstConfig.grailreward, "grail buy")
    actoritem.addItem(actor, NumericType_Diamond, RechagePowerConstConfig.grailmoshi, "grail buy")
    s2cUpdateStatus(actor)
end

function s2cUpdateStatus(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_RechargePower, Protocol.sRPowerCmd_GrailUpdate)
    if not pack then return end
    local var = getActorVar(actor)
    LDataPack.writeChar(pack, var.status)
    LDataPack.flush(pack)  
end

function c2sInlay(actor, pack)
    local index = LDataPack.readChar(pack)
    if not GrailStoneConfig[index] then return end
    local var = getActorVar(actor)
    if var.status ~= 2 then return end
    local level = var.stone[index]
    if not GrailStoneConfig[index] or not GrailStoneConfig[index][level + 1] then return end
    local config = GrailStoneConfig[index][level]
    if not actoritem.checkItems(actor, config.items) then return end
    actoritem.reduceItems(actor, config.items, "grail inlay")
    level = level + 1
    var.stone[index] = level
    updateAttr(actor, true)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_RechargePower, Protocol.sRPowerCmd_GrailInlay)
    if not pack then return end
    local var = getActorVar(actor)
    LDataPack.writeChar(npack, index)
    LDataPack.writeShort(npack, level)
    LDataPack.flush(npack)  
end

function sendTotalInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_RechargePower, Protocol.sRPowerCmd_GrailInfo)
    if not pack then return end
    local var = getActorVar(actor)    
    LDataPack.writeChar(pack, var.status)
    LDataPack.writeChar(pack, #GrailStoneConfig)
    for i=1, #GrailStoneConfig do
        LDataPack.writeShort(pack, var.stone[i])
    end
    LDataPack.flush(pack)    
end

function onLogin(actor)
    sendTotalInfo(actor)
end


function onInit(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.grail) then return end
    updateAttr(actor)
end

function buyGrail(actor)
    local var = getActorVar(actor)
    if var.status ~= 0 then
        return
    end
    var.status = 1
    rechargesystem.addVipExp(actor, RechagePowerConstConfig.grailbuycount)
    s2cUpdateStatus(actor)
end

function buy(actorid) 
	local actor = LActor.getActorById(actorid)
	if actor then
		buyGrail(actor)
	else
		local pack = LDataPack.allocPacket()
		System.sendOffMsg(actorid, 0, OffMsgType_BuyGrail, pack)
	end
end

function OffMsgBuyGrail(actor, offmsg)
	print(string.format("OffMsgGrailInvest actorid:%d ", LActor.getActorId(actor)))
	buyGrail(actor)
end



msgsystem.regHandle(OffMsgType_BuyGrail, OffMsgBuyGrail)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

local function init()
    --if System.isBattleSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_RechargePower, Protocol.cRPowerCmd_GrailGet, c2sGet)
    netmsgdispatcher.reg(Protocol.CMD_RechargePower, Protocol.cRPowerCmd_GrailInlay, c2sInlay)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.buygrail = function(actor) 
	buyGrail(actor)
	return true
end

gmCmdHandlers.grailAll = function (actor, args)
    local var = getActorVar(actor)
    var.status = 2
    for index, conf in pairs(GrailStoneConfig) do
        local maxlevel = #conf
        var.stone[index] = maxlevel
    end
    updateAttr(actor, true)
    onLogin(actor)
    return true
end
