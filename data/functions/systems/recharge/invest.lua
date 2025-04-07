module("invest",package.seeall)

function getActorVar(actor, id)
	local var = LActor.getStaticVar(actor)
    if not var.invest then var.invest = {} end
    if not var.invest.loginstatus then var.invest.loginstatus = 0 end
    if not var.invest.loginreward then var.invest.loginreward = 0 end
    if not var.invest.customstatus then var.invest.customstatus = 0 end
    if not var.invest.customreward then var.invest.customreward = 0 end
    if not var.invest.levelstatus then var.invest.levelstatus = 0 end
    if not var.invest.levelreward then var.invest.levelreward = 0 end
    if not var.invest.loginday then var.invest.loginday = 0 end
    return var.invest
end

function c2sGetReward(actor, pack)
    local type = LDataPack.readChar(pack)
    local index = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    local status = 0
    if type == 1 then
        if var.loginstatus ~= 1 then return end
        if var.loginday < LoginInvestConfig[index].day then
            return
        end
        if not actoritem.checkEquipBagSpaceJob(actor, LoginInvestConfig[index].reward) then
            return
        end
        if System.bitOPMask(var.loginreward, index) then
            return
        end
        var.loginreward = System.bitOpSetMask(var.loginreward, index, true)
        status = var.loginreward
        actoritem.addItems(actor, LoginInvestConfig[index].reward, "login invest")
    elseif type == 2 then
        if var.customstatus ~= 1 then return end
        if guajifuben.getCustom(actor) < CustomInvestConfig[index].custom then
            return
        end
        if not actoritem.checkEquipBagSpaceJob(actor, CustomInvestConfig[index].reward) then
            return
        end
        if System.bitOPMask(var.customreward, index) then
            return
        end
        var.customreward = System.bitOpSetMask(var.customreward, index, true)
        status = var.customreward
        actoritem.addItems(actor, CustomInvestConfig[index].reward, "login invest")
    else
        if var.levelstatus ~= 1 then return end
        if LActor.getLevel(actor) < LevelInvestConfig[index].level then
            return
        end
        if not actoritem.checkEquipBagSpaceJob(actor, LevelInvestConfig[index].reward) then
            return
        end
        if System.bitOPMask(var.levelreward, index) then
            return
        end
        var.levelreward = System.bitOpSetMask(var.levelreward, index, true)
        status = var.levelreward
        actoritem.addItems(actor, LevelInvestConfig[index].reward, "login invest")
    end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sInvestCmd_GetReward)
    local var = getActorVar(actor, id)
    LDataPack.writeChar(pack, type)
    LDataPack.writeInt(pack, status)
    LDataPack.flush(pack)
end



function s2cLoginInfo(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sInvestCmd_Info)
    local var = getActorVar(actor, id)
    LDataPack.writeChar(pack, var.loginstatus)
    LDataPack.writeChar(pack, var.customstatus)
    LDataPack.writeChar(pack, var.levelstatus)
    LDataPack.writeInt(pack, var.loginreward)
    LDataPack.writeInt(pack, var.customreward)
    LDataPack.writeInt(pack, var.levelreward)
    LDataPack.writeChar(pack, var.loginday)
    LDataPack.flush(pack)
end


local function onLogin(actor)
    s2cLoginInfo(actor)
end

local function onNewDayArrive(actor, login)
    local var = getActorVar(actor)
    if var.loginday < #LoginInvestConfig then
        var.loginday = var.loginday + 1
    end        
    if not login then
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sInvestCmd_UpdateLogin)
        LDataPack.writeChar(pack, var.loginday)
        LDataPack.flush(pack)
    end
end

function c2sBuy(actor, pack)
    local var = getActorVar(actor)
    local type = LDataPack.readChar(pack)
    local svip = LActor.getSVipLevel(actor)
    if type == 1 then
        if var.loginstatus == 1 then return end
        if svip < RechargeConstConfig.loginsvip then
            return
        end
        if not actoritem.checkItem(actor, NumericType_YuanBao, RechargeConstConfig.loginyuanbao) then
            return
        end
        actoritem.reduceItem(actor, NumericType_YuanBao, RechargeConstConfig.loginyuanbao, "logininvest buy")        
        var.loginstatus = 1
    elseif type == 2 then
        if var.customstatus == 1 then return end
        if svip < RechargeConstConfig.customsvip then
            return
        end
        if not actoritem.checkItem(actor, NumericType_YuanBao, RechargeConstConfig.customyuanbao) then
            return
        end
        actoritem.reduceItem(actor, NumericType_YuanBao, RechargeConstConfig.customyuanbao, "custominvest buy")        
        var.customstatus = 1
    elseif type == 3 then
        if var.levelstatus == 1 then return end
        if svip < RechargeConstConfig.levelsvip then
            return
        end
        if not actoritem.checkItem(actor, NumericType_YuanBao, RechargeConstConfig.levelyuanbao) then
            return
        end
        actoritem.reduceItem(actor, NumericType_YuanBao, RechargeConstConfig.levelyuanbao, "levelinvest buy")        
        var.levelstatus = 1
    end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sInvestCmd_Buy)
    LDataPack.writeChar(pack, type)
    LDataPack.flush(pack)
end

local function init()
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDayArrive)
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cInvestCmd_GetReward, c2sGetReward)
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cInvestCmd_Buy, c2sBuy)
end

table.insert(InitFnTable, init)



