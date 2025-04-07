--魔兽宝典
module("warcraftsystem", package.seeall)

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.warcraft then
        var.warcraft = {}
        var.warcraft.baodian = {}
        var.warcraft.dashi = {}
        var.warcraft.stage = 0
    end
    
    return var.warcraft
end

function getWarcraftStage(actor)
    if not actor then return 0 end
    local var = getActorVar(actor)
    return WCStageConfig[var.stage].stage
end

function updateAttr(actor, isCalc)----升级后的属性
    local var = getActorVar(actor)
    local addAttrs = {}
    --local power = 0
    
    for k, v in pairs(WCLevelConfig) do
        if (var.baodian[k] or 0) > 0 then
            for kk, vv in ipairs(v.addattr) do
                local per = 1 + WCDashiConfig[v.type][var.dashi[v.type] or 0].per / 10000 + WCStageConfig[var.stage].per / 10000
                addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * var.baodian[k] * per
            end
        end
    end
    
    -- for k,v in ipairs(WCDashiConfig) do
    --     if (var.dashi[k] or 0) > 0 then
    --         for kk,vv in ipairs(v[var.dashi[k]].addattr) do
    --             addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value
    --         end
    --     end
    -- end
    
    if (var.stage or 0) > 0 then
        for k, v in ipairs(WCStageConfig[var.stage].addattr) do
            addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
        end
    end
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_WarCraft)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    
    --attr:SetExtraPower(power)
    if isCalc then
        LActor.reCalcAttr(actor)
    end
end

function sendInfo(actor)
    local var = getActorVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_WarCraft, Protocol.sWarCraftCmd_Info)
    if not npack then return end
    LDataPack.writeShort(npack, #WCLevelConfig)
    for k in ipairs(WCLevelConfig) do
        LDataPack.writeShort(npack, var.baodian[k] or 0)
    end
    LDataPack.writeChar(npack, #WCDashiConfig)
    for k in ipairs(WCDashiConfig) do
        LDataPack.writeShort(npack, var.dashi[k] or 0)
    end
    LDataPack.writeShort(npack, var.stage)
    LDataPack.flush(npack)
end

local function baodianUp(actor, pack)
    local id = LDataPack.readShort(pack)
    local config = WCLevelConfig[id]
    if not config then return end
    local var = getActorVar(actor)
    var.baodian[id] = var.baodian[id] or 0
    if var.baodian[id] >= config.maxLevel then
        return
    end
    if not actoritem.checkItem(actor, config.needitem.id, config.needitem.count) then
        return
    end
    actoritem.reduceItem(actor, config.needitem.id, config.needitem.count, "warcraft baodianup")
    
    var.baodian[id] = var.baodian[id] + 1
    
    actorevent.onEvent(actor, aeTujianActive, 1)

    updateAttr(actor, true)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_WarCraft, Protocol.sWarCraftCmd_BaodianUpRet)
    if not npack then return end
    LDataPack.writeShort(npack, id)
    LDataPack.writeShort(npack, var.baodian[id])
    LDataPack.flush(npack)
end

local function dashiUp(actor, pack)
    local quality = LDataPack.readChar(pack)
    if not WCQualityConfig[quality] then
        return
    end
    local var = getActorVar(actor)
    var.dashi[quality] = var.dashi[quality] or 0
    if not WCDashiConfig[quality][var.dashi[quality] + 1] then return end
    local havecount = 0
    for k, id in ipairs(WCQualityConfig[quality].haveid) do
        if (var.baodian[id] or 0) >= WCDashiConfig[quality][var.dashi[quality]].needlv then
            havecount = havecount + 1
        end
    end
    if havecount < WCDashiConfig[quality][var.dashi[quality]].neednumber then
        return
    end
    
    var.dashi[quality] = var.dashi[quality] + 1
    
    updateAttr(actor, true)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_WarCraft, Protocol.sWarCraftCmd_DashiUpRet)
    if not npack then return end
    LDataPack.writeChar(npack, quality)
    LDataPack.writeShort(npack, var.dashi[quality])
    LDataPack.flush(npack)
end

local function stageUp(actor, pack)
    local var = getActorVar(actor)
    if var.stage >= #WCStageConfig then
        return
    end
    local config = WCStageConfig[var.stage]
    if not actoritem.checkItem(actor, config.needitem.id, config.needitem.count) then
        return
    end
    actoritem.reduceItem(actor, config.needitem.id, config.needitem.count, "warcraft baodianup")
    var.stage = var.stage + 1
    
    actorevent.onEvent(actor, aeWarcraftStage, WCStageConfig[var.stage].stage)
    updateAttr(actor, true)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_WarCraft, Protocol.sWarCraftCmd_StageUpRet)
    if not npack then return end
    LDataPack.writeShort(npack, var.stage)
    LDataPack.flush(npack)
end

local function onLogin(actor)
    sendInfo(actor)
end

local function onInit(actor)
    updateAttr(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

local function init(actor)
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_WarCraft, Protocol.cWarCraftCmd_BaodianUp, baodianUp)
    netmsgdispatcher.reg(Protocol.CMD_WarCraft, Protocol.cWarCraftCmd_DashiUp, dashiUp)
    netmsgdispatcher.reg(Protocol.CMD_WarCraft, Protocol.cWarCraftCmd_StageUp, stageUp)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.warcraftAll = function (actor, args)
    local var = getActorVar(actor)
    for id, conf in pairs(WCLevelConfig) do
        var.baodian[id] = conf.maxLevel
    end
    for quality, conf in pairs(WCDashiConfig) do
        var.dashi[quality] = #conf
    end
    var.stage = #WCStageConfig
    updateAttr(actor, true)
    sendInfo(actor)
    return true
end
