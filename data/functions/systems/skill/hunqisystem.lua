--魂器系统
module("hunqisystem", package.seeall)


function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.hunqi then var.hunqi = {} end
    if not var.hunqi.level then var.hunqi.level = 1 end
    if not var.hunqi.exp then var.hunqi.exp = 0 end
    if not var.hunqi.hunqi then var.hunqi.hunqi = {} end
    if not var.hunqi.power then var.hunqi.power = 0 end
    return var.hunqi
end

function getHunqiLevel(actor)
    local var = getActorVar(actor)
    return var.level
end

function getPower(actor)
    local var = getActorVar(actor)
    return var.power + LActor.getSkillPower(actor)
end

local function updateAttr(actor, isCalc)
    local var = getActorVar(actor)
    local addAttrs = {}

    for k,v in ipairs(HunqiIdConfig) do
        if (var.hunqi[k] or 0) > 0 then
            for kk,vv in ipairs(HunqiLevelConfig[v.quality][var.hunqi[k] or 0].attr) do
                addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value
            end
            for i=1, var.hunqi[k] do
                for kk, vv in ipairs(HunqiLevelConfig[v.quality][i].attrlh) do
                    addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value
                end
            end
        end        
    end

    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Hunqi)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    attr:SetExtraPower(HunqiAwakeConfig[var.level].power)
    if isCalc then
        LActor.reCalcAttr(actor)
    end
    if System.isCommSrv() then
        var.power = utils.getAttrPower0(addAttrs) + HunqiAwakeConfig[var.level].power
        onPowerChange(actor)
    end
end

function onPowerChange(actor)
    if System.isCommSrv() then
        local var = getActorVar(actor)
        local rankpower = var.power + LActor.getSkillPower(actor)
        utils.rankfunc.updateRankingList(actor, rankpower, RankingType_Hunqi)        
    end
end

function onSkillUp(actor)
    onPowerChange(actor)
end

--魂器列表
function sendHunqiList(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_HunqiList)
    LDataPack.writeShort(pack, var.level)
    LDataPack.writeInt(pack, var.exp)
    LDataPack.writeChar(pack, #HunqiIdConfig)
    for k,v in ipairs(HunqiIdConfig) do
        LDataPack.writeShort(pack, k)
        LDataPack.writeShort(pack, var.hunqi[k] or 0)
    end
    
    LDataPack.flush(pack)
end

--魂器升级
function levelUp(actor, pack)
    local var = getActorVar(actor)
    local id = LDataPack.readShort(pack)
    local conf = HunqiLevelConfig[HunqiIdConfig[id].quality]
    if not conf[(var.hunqi[id] or 0) + 1] then return end
    local count = actoritem.getItemCount(actor, HunqiIdConfig[id].itemid)
    if count < conf[(var.hunqi[id] or 0)].itemcount then
        if (var.hunqi[id] or 0) ~= 0 then        
            if count + actoritem.getItemCount(actor, HunqiQualityConfig[HunqiIdConfig[id].quality].itemid) < conf[(var.hunqi[id] or 0)].itemcount then
                return
            end
        else
            return
        end
	end
    
    if count >= conf[(var.hunqi[id] or 0)].itemcount then
        actoritem.reduceItem(actor, HunqiIdConfig[id].itemid, conf[(var.hunqi[id] or 0)].itemcount, "hunqi level up")
    else
        actoritem.reduceItem(actor, HunqiIdConfig[id].itemid, count, "hunqi level up")
        actoritem.reduceItem(actor, HunqiQualityConfig[HunqiIdConfig[id].quality].itemid, conf[(var.hunqi[id] or 0)].itemcount - count, "hunqi level up")
    end
    
    var.hunqi[id] = (var.hunqi[id] or 0) + 1
    var.exp = var.exp + (conf[var.hunqi[id] or 0].exp - conf[var.hunqi[id] - 1].exp)
    local beforelv = var.level
    for i=1, 10 do        
        if var.exp < HunqiAwakeConfig[var.level].exp or not HunqiAwakeConfig[var.level + 1] then
            break
        end
        
        var.exp = var.exp - HunqiAwakeConfig[var.level].exp
        var.level = var.level + 1
    end
    
    actorevent.onEvent(actor, aeHunqiLevel, var.hunqi[id], HunqiIdConfig[id].quality, var.level)
    updateAttr(actor, true)
    if beforelv ~= var.level then
        LActor.setSkillParamPer(actor, HunqiAwakeConfig[var.level].skilladd)
    end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_HunqiLevelUp)
    LDataPack.writeShort(pack, var.level)
    LDataPack.writeInt(pack, var.exp)
    LDataPack.writeShort(pack, id)
    LDataPack.writeShort(pack, var.hunqi[id] or 0)
    LDataPack.flush(pack)
end

function getSkillMax(actor)
    local var = getActorVar(actor)
    return HunqiAwakeConfig[var.level].skillmax
end

function onLogin(actor)
    sendHunqiList(actor)
end

function onInit(actor)
    updateAttr(actor)
    local var = getActorVar(actor)
    LActor.setSkillParamPer(actor, HunqiAwakeConfig[var.level].skilladd)
end


_G.getSkillMax = getSkillMax

actorevent.reg(aeSkillLevelup, onSkillUp)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_HunqiLevelup, levelUp)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.hunqiAll = function (actor, args)
    local IsChange = false
    local HunqiLevelConfig = HunqiLevelConfig
    local var = getActorVar(actor)
    local maxlevel = #HunqiAwakeConfig
    if (var.level or 0) < maxlevel then
        var.level = maxlevel
        IsChange = true
    end

    for id,conf in pairs(HunqiIdConfig) do
        maxlevel = #HunqiLevelConfig[conf.quality]
        if (var.hunqi[id] or 0) < maxlevel then
            var.hunqi[id] = maxlevel
            if HunqiIdConfig[id].quality == 4 then
                actorevent.onEvent(actor, aeHunqiLevel, 1, HunqiIdConfig[id].quality, var.level)
            end
            actorevent.onEvent(actor, aeHunqiLevel, var.hunqi[id], HunqiIdConfig[id].quality, var.level)
            IsChange = true
        end
    end

    if IsChange then
        onLogin(actor)
        updateAttr(actor, true)
    end
    return true
end
