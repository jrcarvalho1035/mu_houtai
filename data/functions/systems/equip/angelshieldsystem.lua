
module("angelshieldsystem", package.seeall)

function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.angelshield then var.angelshield = {} end
    local angelshield = var.angelshield
    if not angelshield.isactive then angelshield.isactive = 0 end
    if not angelshield.level then angelshield.level = 0 end
    if not angelshield.exp then angelshield.exp = 0 end
    if not angelshield.dan then angelshield.dan = {} end
    for i = 1, 3 do
        if not angelshield.dan[i] then angelshield.dan[i] = 0 end
    end
    return angelshield
end

function getAngelshieldStage(actor)
    if not actor then return 0 end
    local var = getActorVar(actor)
    return math.ceil((var.level + 1) / 11)
end

local function tableAddMulit(t, attrs, n)
    for _, v in ipairs(attrs) do
        t[v.type] = (t[v.type] or 0) + (v.value * n)
    end
end

--这星级是否属于要升阶的
local function isEndLevel(level)
    if level == #ShengdunLvConfig then
        return false
    end
    return ShengdunLvConfig[level].exp == 0
end

function calcAttr(actor, calc)
    local var = getActorVar(actor)
    local totalAttrs = {}
    local power = 0
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_AngelShield)
    attr:Reset()
    
    local totalAttrs = {}
    if var.isactive == 1 then
        tableAddMulit(totalAttrs, ShengdunLvConfig[var.level].attr, 1)
    end
    local addper = 1 + (ShengdundanConfig[3].per * (var.dan[3] or 0) / 10000)
    for type in pairs(totalAttrs) do
        totalAttrs[type] = math.floor(totalAttrs[type] * addper)
    end
    local stage = math.ceil((var.level + 1) / 11)
    for i = 1, #ShengdunSkillConfig do
        if stage >= ShengdunSkillConfig[i].stage then
            tableAddMulit(totalAttrs, ShengdunSkillConfig[i].attr, 1)
            power = power + ShengdunSkillConfig[i].power
        else
            break
        end
    end
    for i = 1, #ShengdundanConfig do
        tableAddMulit(totalAttrs, ShengdundanConfig[i].attr, var.dan[i] or 0)
        power = power + ShengdundanConfig[i].power * (var.dan[i] or 0)
    end
    
    for k, v in pairs(totalAttrs) do
        attr:Set(k, v)
    end
    if power > 0 then
        attr:SetExtraPower(power)
    end
    
    if calc then
        LActor.reCalcRoleAttr(actor)
    end
end

function sendAngelShieldInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AngelShield, Protocol.sAngelShield_Info)
    local var = getActorVar(actor)
    LDataPack.writeChar(pack, var.isactive)
    LDataPack.writeShort(pack, var.level)
    LDataPack.writeInt(pack, var.exp)
    LDataPack.writeChar(pack, #ShengdundanConfig)
    for j = 1, #ShengdundanConfig do
        LDataPack.writeShort(pack, var.dan[j])
    end
    
    LDataPack.flush(pack)
end

function c2sLevelUp(actor, pack)
    local index = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.angelshield) then return end
    
    local var = getActorVar(actor)
    if ShengdunLvConfig[var.level].exp ~= 0 then
        if not actoritem.checkItem(actor, UpItemConfig[index].itemid, 1) then
            return
        end
        if not ShengdunLvConfig[var.level + 1] then return end
        
        actoritem.reduceItem(actor, UpItemConfig[index].itemid, 1, "angelshield level up")
        var.exp = var.exp + UpItemConfig[index].addexp
    end
    
    while(var.exp >= ShengdunLvConfig[var.level].exp and ShengdunLvConfig[var.level + 1]) do
        var.exp = var.exp - ShengdunLvConfig[var.level].exp
        var.level = var.level + 1
        if isEndLevel(var.level) then
            break
        end
    end
    
    actorevent.onEvent(actor, aeAngelshield, math.ceil((var.level + 1) / 11))
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AngelShield, Protocol.sAngelShield_LevelUp)
    LDataPack.writeShort(pack, var.level)
    LDataPack.writeInt(pack, var.exp)
    LDataPack.flush(pack)
    calcAttr(actor, true)
end

function c2sUsePill(actor, pack)
    local index = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    if not ShengdundanConfig[index] then return end
    
    if var.dan[index] >= ShengdunStageConfig[math.ceil((var.level + 1) / 11)].maxpill[index] then
        return
    end
    
    if not actoritem.checkItem(actor, ShengdundanConfig[index].itemid, 1) then
        return
    end
    actoritem.reduceItem(actor, ShengdundanConfig[index].itemid, 1, "angelshield level up")
    
    var.dan[index] = (var.dan[index] or 0) + 1
    
    sendAngelShieldInfo(actor)
    calcAttr(actor, true)
end

function c2sActive(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.angelshield) then return end
    local var = getActorVar(actor)
    if var.isactive ~= 0 then
        return
    end
    var.isactive = 1
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AngelShield, Protocol.sAngelShield_Active)
    LDataPack.flush(pack)
    sendAngelShieldInfo(actor)
    calcAttr(actor, true)
end

function onLogin(actor)
    sendAngelShieldInfo(actor)
end

local function onInit(actor)
    calcAttr(actor, false)
end

local function onSystemOpen(actor)
    sendAngelShieldInfo(actor)
end

function init()
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.angelshield, onSystemOpen)
    
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)

    if System.isLianFuSrv() then return end
    
    netmsgdispatcher.reg(Protocol.CMD_AngelShield, Protocol.cAngelShield_LevelUp, c2sLevelUp)
    netmsgdispatcher.reg(Protocol.CMD_AngelShield, Protocol.cAngelShield_UsePill, c2sUsePill)
    netmsgdispatcher.reg(Protocol.CMD_AngelShield, Protocol.cAngelShield_Active, c2sActive)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.shengdunAll = function (actor, args)
    local var = getActorVar(actor)
    var.isactive = 1
    var.level = #ShengdunLvConfig
    local conf = ShengdunStageConfig[#ShengdunStageConfig]
    for idx = 1, #ShengdundanConfig do
        var.dan[idx] = conf.maxpill[idx]
    end
    calcAttr(actor, true)
    sendAngelShieldInfo(actor)
    return true
end
