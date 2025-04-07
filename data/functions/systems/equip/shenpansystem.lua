-- @version1.0
-- @authorqianmeng
-- @date2017-9-21 15:53:21.
-- @system审判套装系统

module("shenpansystem", package.seeall)
require("equip.suitattr")

function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.suitdata then
        var.suitdata = {}
    end
    return var.suitdata
end

function getShenPanStage(actor)
    local allStage = 0
    if not actor then return allStage end
    for slot, conf in pairs(SuitAttrConfig) do
        local level = getSuitLevel(actor, slot)
        allStage = allStage + conf[level].stage
    end
    return allStage
end

--创建一个套装数据结构
function setSuitLevel(actor, slot, level)
    local var = getActorVar(actor)
    if not var then return end
    var[slot] = level --套装等级
end

--返回套装等级
function getSuitLevel(actor, slot)
    local level = 0
    local var = getActorVar(actor)
    level = var[slot] or 0
    return level
end

--更新属性
function updateAttr(actor, calc)
    local addAttrs = {}
    local role = LActor.getRole(actor)
    local job = LActor.getJob(role)
    
    for slot, conf in pairs(SuitAttrConfig) do
        local level = getSuitLevel(actor, slot)
        if level > 0 and conf[level] then
            for k, v in pairs(conf[level].attr) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
            end
        end
    end
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Shenpan)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    if calc then
        LActor.reCalcRoleAttr(actor)
    end
end

-------------------------------协议---------------------------------------------
--套装信息
function s2cShenpanInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sShenPanSuitCmd_SuitInfo)
    if pack == nil then return end
    local count = 0
    local pos = LDataPack.getPosition(pack)
    LDataPack.writeChar(pack, count)
    for slot, v in pairs(SuitAttrConfig) do
        local level = getSuitLevel(actor, slot)
        LDataPack.writeChar(pack, slot)
        LDataPack.writeChar(pack, level)
        count = count + 1
    end
    local npos = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, pos)
    LDataPack.writeChar(pack, count)
    LDataPack.setPosition(pack, npos)
    LDataPack.flush(pack)
end

--套装升级
function c2sEquipSuitUp(actor, pack)
    local slot = LDataPack.readChar(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenpan) then return end
    if not SuitAttrConfig[slot] then return end
    
    local level = getSuitLevel(actor, slot)
    local nextLevel = level + 1
    local conf = SuitAttrConfig[slot][level]
    if not SuitAttrConfig[slot][level + 1] then return end
    if not actoritem.checkItems(actor, conf.items) then
        return
    end
    actoritem.reduceItems(actor, conf.items, "shenpan suit up:"..level)
    
    setSuitLevel(actor, slot, nextLevel) --升级
    actorevent.onEvent(actor, aeShenPanLevelUp, 1)
    updateAttr(actor, true) --更新属性
    
    --给前端回包
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sShenPanSuitCmd_SuitUp)
    if pack == nil then return end
    LDataPack.writeChar(pack, slot)
    LDataPack.writeChar(pack, nextLevel)
    LDataPack.flush(pack)
    
    local extra = string.format("slot:%d,level:%d", slot, nextLevel)
    utils.logCounter(actor, "othersystem", "", extra, "suit", "up")
end

local function onInit(actor)
    updateAttr(actor, false)
end

local function onLogin(actor)
    s2cShenpanInfo(actor)
end

local function init()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cShenPanSuitCmd_SuitUp, c2sEquipSuitUp)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.shenpanAll = function (actor, args)
    local var = getActorVar(actor)
    for slot, conf in pairs(SuitAttrConfig) do
        var[slot] = #conf
    end
    updateAttr(actor, true)
    s2cShenpanInfo(actor)
    return true
end
