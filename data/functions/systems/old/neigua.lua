--内挂助手

module("neigua", package.seeall)

local status_type = {
    haveBuy = 1,
    outBuy = 2,
}

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.neigua then
        var.neigua = {
            endTime = 0,
            status = 0,
            systems = {},
        }
    end
    return var.neigua
end

local function calcAttr(actor, calc)
    local var = getActorVar(actor)
    local attrs = LActor.getRoleSystemAttrs(actor, AttrActorSysId_Neigua)
    attrs:Reset()
    if var.status == status_type.haveBuy then
        for _, v in ipairs(NeiGuaConstConfig.attrs) do
            attrs:Set(v.type, v.value)
        end
    end
    if calc then
        LActor.reCalcAttr(actor)
    end
end

--购买内挂助手
function buyNeigua(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.neigua) then return end
    if not actoritem.checkItems(actor, NeiGuaConstConfig.consume) then
        return
    end
    actoritem.reduceItems(actor, NeiGuaConstConfig.consume, "neigua buy")
    
    local var = getActorVar(actor)
    local oldStatus = var.status
    if var.status == status_type.haveBuy then
        var.endTime = var.endTime + NeiGuaConstConfig.day * 86400
    else
        var.endTime = System.getToday() + NeiGuaConstConfig.day * 86400
    end
    var.status = status_type.haveBuy
    calcAttr(actor, true)
    s2cNeiguaInfo(actor)
    s2cNeiguaFirstBuy(actor, oldStatus)
    utils.logCounter(actor, "neigua buy")
end

--改变内挂助手状态
function changeNeigua(actor, id)
    local var = getActorVar(actor)
    if var.status ~= status_type.haveBuy then return end
    local config = GuaJiZhuShouConfig[id]
    if not config then return end
    if not var.systems[config.fbGroup] then return end
    
    local status = (var.systems[config.fbGroup].status + 1) % 2
    var.systems[config.fbGroup].status = status
    s2cNeiguaStatus(actor, id, status)
end

--外部接口,检查功能开启状态
function checkOpenNeigua(actor, group, exCount)
    print("actorid =", LActor.getActorId(actor), "group =", group, "exCount =", exCount)
    local var = getActorVar(actor)
    local neigua = var.systems[group]
    if not neigua then
        print("not have this fb")
        return 0
    end
    
    exCount = exCount or GuaJiZhuShouConfig[neigua.id].consumeCount
    local fightCount = math.min(exCount, 1)
    if var.status == status_type.haveBuy and neigua.status == 1 then
        fightCount = math.min(GuaJiZhuShouConfig[neigua.id].consumeCount, exCount)
    end
    neigua.count = fightCount
    print("fightCount =", fightCount)
    return fightCount
end

--外部接口,用于任务系统计算副本次数
function getNeiguaFightCount(actor, group)
    local var = getActorVar(actor)
    if not var.systems[group] then return 1 end
    return var.systems[group].count
end

----------------------------------------------------------------------------------
--协议处理

--27-50 内挂助手购买
local function c2sBuyNeigua(actor)
    buyNeigua(actor)
end

--27-50 内挂助手信息
function s2cNeiguaInfo(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_NeiguaInfo)
    LDataPack.writeInt(pack, var.endTime - System.getNowTime())
    LDataPack.writeChar(pack, var.status)
    LDataPack.writeChar(pack, #GuaJiZhuShouConfig)
    for id, conf in pairs(GuaJiZhuShouConfig) do
        LDataPack.writeChar(pack, id)
        if not var.systems[conf.fbGroup] then
            var.systems[conf.fbGroup] = {
                id = conf.id,
                status = conf.open,
                count = 1,
            }
        end
        LDataPack.writeChar(pack, var.systems[conf.fbGroup].status)
    end
    LDataPack.flush(pack)
end

--27-51 内挂助手功能开启
local function c2sChangeNeigua(actor, pack)
    local id = LDataPack.readChar(pack)
    changeNeigua(actor, id)
end

--27-51 内挂助手更新功能状态
function s2cNeiguaStatus(actor, id, status)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_NeiguaStatus)
    LDataPack.writeChar(pack, id)
    LDataPack.writeChar(pack, status)
    LDataPack.flush(pack)
end

--27-52 内挂助手是否第一次购买
function s2cNeiguaFirstBuy(actor, oldStatus)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_NeiguaIsFirst)
    LDataPack.writeChar(pack, oldStatus == 0 and 1 or 0)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function onInit(actor)
    calcAttr(actor, false)
end

local function onLogin(actor)
    s2cNeiguaInfo(actor)
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    if var.endTime < System.getNowTime() then
        var.status = status_type.outBuy
        calcAttr(actor, true)
    end
    if not login then
        s2cNeiguaInfo(actor)
    end
end

----------------------------------------------------------------------------------
--初始化
local function init()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_NeiguaBuy, c2sBuyNeigua)
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_NeiguaChange, c2sChangeNeigua)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.buyneigua = function(actor)
    buyNeigua(actor)
    return true
end

gmCmdHandlers.changeneigua = function(actor, args)
    local id = tonumber(args[1])
    if not id then return end
    changeNeigua(actor, id)
    return true
end

gmCmdHandlers.clearneigua = function(actor)
    local var = LActor.getStaticVar(actor)
    var.neigua = nil
    s2cNeiguaInfo(actor)
    return true
end

gmCmdHandlers.printneigua = function(actor)
    local var = getActorVar(actor)
    print("endTime = ", var.endTime)
    print("status = ", var.status)
    for id, conf in pairs(GuaJiZhuShouConfig) do
        print("*******")
        print("id = ", id)
        print("fbGroup = ", conf.fbGroup)
        print("status = ", var.systems[conf.fbGroup].status)
        print("count = ", var.systems[conf.fbGroup].count)
        print("*******")
    end
    return true
end

