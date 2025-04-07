-- @system密语系统

module("secretsystem", package.seeall)

function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.secretData then var.secretData = {} end
    return var.secretData
end

-------------------------------------------------------------------------------------------
--密语信息
function updateAttr(actor, calc)
    local addAttrs = {}
    local var = getActorVar(actor)
    local power = 0
    
    for k, v in ipairs(SecretStarConfig) do
        if (var[k] or 0) > 0 then
            for __, attr in ipairs(v[var[k]].attr) do
                addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
            end
        end
        
        if (var[k] or 0) >= SecretConfig[k].needstar then
            local conf = SkillPassiveConfig[SecretConfig[k].skillid][1]
            if conf.type == 1 then
                for k, v in ipairs(conf.addattr) do
                    addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
                end
            end
            power = power + conf.power
        end
    end
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Secret)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    attr:SetExtraPower(power)
    if calc then
        LActor.reCalcAttr(actor)
    end
end

function s2cSecretInfo(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sFeathersCmd_Info)
    LDataPack.writeChar(pack, #SecretConfig)
    for k, v in ipairs(SecretConfig) do
        LDataPack.writeInt(pack, var[k] or 0)
    end
    LDataPack.flush(pack)
end

--密语升星
function c2sSecretStarUp(actor, pack)
    local id = LDataPack.readChar(pack)
    local conf = SecretStarConfig[id]
    local var = getActorVar(actor)
    local star = var[id] or 0
    if not star then return end --未激活
    if not conf[star + 1] then return end --已满级
    if SecretConfig[id].param[1] ~= 0 then --前一个密语未达到指定等级
        if (var[SecretConfig[id].param[1]] or 0) < SecretConfig[id].param[2] then
            return
        end
    end
    if not actoritem.checkItem(actor, conf[star].items.id, conf[star].items.count) then
        return
    end
    actoritem.reduceItem(actor, conf[star].items.id, conf[star].items.count, "secret star up")

    var[id] = star + 1
    if var[id] == SecretConfig[id].needstar then
        passiveskill.levelUp(actor, SecretConfig[id].skillid)
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sSecretCmd_StarUp)
    LDataPack.writeChar(pack, id)
    LDataPack.writeInt(pack, var[id])
    LDataPack.flush(pack)
    updateAttr(actor, true)

    actorevent.onEvent(actor, aeSecretStarUp, 1)
    --s2cSecretInfo(actor)
end

function onLogin(actor)
    s2cSecretInfo(actor)
end

function onInit(actor)
    updateAttr(actor, false)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Old, Protocol.cSecretCmd_StarUp, c2sSecretStarUp)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.secretlv = function (actor, args)
    local var = getActorVar(actor)
    var[tonumber(args[1])] = tonumber(args[2])
    s2cSecretInfo(actor)
    return true
end

gmCmdHandlers.secretAll = function (actor, args)
    local var = getActorVar(actor)
    for id, conf in ipairs(SecretStarConfig) do
        var[id] = #conf
    end
    updateAttr(actor, true)
    s2cSecretInfo(actor)
    return true
end
