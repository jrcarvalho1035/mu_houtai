module("passiveskill", package.seeall)
--passiveskill = {[skillid] = level}

PASSIVE_TYPE_ADD_ATTR = 1 --加属性
PASSIVE_TYPE_TIMER = 2 --定时
PASSIVE_TYPE_CHUFA = 3 --触发
PASSIVE_TYPE_OTHER = 4 --其他技能

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.passive then var.passive = {} end
    if not var.passive.count then var.passive.count = 0 end
    if not var.passive.skills then var.passive.skills = {} end
    return var.passive
end

function sendSkillList(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_PassiveList)
    local count = 0
    for k, v in pairs(SkillPassiveConfig) do
        local level = (v[0].type == PASSIVE_TYPE_ADD_ATTR) and (var.skills[k] or 0) or LActor.getPassiveLevel(actor, k)
        if level > 0 then
            count = count + 1
        end
    end
    LDataPack.writeShort(pack, count)
    for k, v in pairs(SkillPassiveConfig) do
        local level = (v[0].type == PASSIVE_TYPE_ADD_ATTR) and (var.skills[k] or 0) or LActor.getPassiveLevel(actor, k)
        if level > 0 then
            LDataPack.writeInt(pack, k)
            LDataPack.writeShort(pack, level)
        end
    end
    LDataPack.flush(pack)
end

function getSkillLv(actor, skillid)
    if SkillPassiveConfig[skillid][0].type == PASSIVE_TYPE_ADD_ATTR then
        local var = getActorVar(actor)
        return var.skills[skillid] or 0
    else
        return LActor.getPassiveLevel(actor, skillid)
    end
end

local function checkTypeLevel(actor, typeUp, needLv)
    if typeUp == 1 then --神器
        return shenqisystem.getShenqiLv(actor) >= needLv
    elseif typeUp == 2 then --精灵等级
        return damonsystem.getLevel(actor) >= needLv
    elseif typeUp == 3 then --精灵等阶
        return damonsystem.getStage(actor) >= needLv
    elseif typeUp == 4 then --翅膀
        return wingsystem.getWingLv(actor) >= needLv
    elseif typeUp == 5 then --守护等级
        return yongbingsystem.getLevel(actor) >= needLv
    elseif typeUp == 6 then --守护等阶
        return yongbingsystem.getStage(actor) >= needLv
    elseif typeUp == 7 then --神装
        return shenzhuangsystem.getShenzhuangLv(actor) >= needLv
    elseif typeUp == 8 then --梅林
        return meilinsystem.getMeilinLv(actor) >= needLv
    elseif typeUp == 9 then --神魔等级
        return shenmosystem.getLevel(actor) >= needLv
    elseif typeUp == 10 then --神魔进阶
        return shenmosystem.getStage(actor) >= needLv
    elseif typeUp == 18 then -- 神佑系统 印记等级限制
        return shenyousystem.getTagLevel(actor) >= needLv
    elseif typeUp == 20 then -- 元素系统 水元素等级限制
        return yuansusystem.getYSLevel(actor, 1) >= needLv
    elseif typeUp == 21 then -- 元素系统 水元素等级限制
        return yuansusystem.getYSLevel(actor, 2) >= needLv
    elseif typeUp == 22 then -- 元素系统 水元素等级限制
        return yuansusystem.getYSLevel(actor, 3) >= needLv
    elseif typeUp == 23 then -- 元素系统 水元素等级限制
        return yuansusystem.getYSLevel(actor, 4) >= needLv
    elseif typeUp == 24 then -- 元素系统 水元素等级限制
        return yuansusystem.getYSLevel(actor, 5) >= needLv
    elseif typeUp == 25 then -- 真红圣装 真红一击套装等级限制
        return zhenhongsystem.getZHYJLevel(actor) >= needLv
    elseif typeUp == 26 then -- 真红圣装 真红霸体套装等级限制
        return zhenhongsystem.getZHBTLevel(actor) >= needLv
    elseif typeUp >= 27 and typeUp <= 56 then -- 灵器升级条件
        return lingqisystem.checkLQLevel(actor, typeUp, needLv)
    elseif typeUp >= 57 and typeUp <= 86 then -- 灵器升阶条件
        return lingqisystem.checkLQStage(actor, typeUp, needLv)
    elseif typeUp >= 87 and typeUp <= 116 then -- 魔灵升阶条件
        return smzlsystem.checkMLLevel(actor, typeUp, needLv)
    elseif typeUp == 117 then -- 元素系统 水元素等级限制
        return yuansusystem.getYSShengqiLevel(actor, 1) >= needLv
    elseif typeUp == 118 then -- 元素系统 水元素等级限制
        return yuansusystem.getYSShengqiLevel(actor, 2) >= needLv
    elseif typeUp == 119 then -- 元素系统 水元素等级限制
        return yuansusystem.getYSShengqiLevel(actor, 3) >= needLv
    elseif typeUp == 120 then -- 元素系统 水元素等级限制
        return yuansusystem.getYSShengqiLevel(actor, 4) >= needLv
    elseif typeUp == 121 then -- 元素系统 水元素等级限制
        return yuansusystem.getYSShengqiLevel(actor, 5) >= needLv
    elseif typeUp >= 122 and typeUp <= 128 then --神迹之魂星级限制
        return sjzhsystem.checkSJZHStar(actor, typeUp, needLv)
    end
    return true
end

function updateSysAttr(actor, typeUp)
    if typeUp == 1 then --神器
        return shenqisystem.updateAttr(actor, true)
    elseif typeUp == 2 then --精灵等级
        return damonsystem.updateAttr(actor, true)
    elseif typeUp == 3 then --精灵等阶
        return damonsystem.updateAttr(actor, true)
    elseif typeUp == 4 then --翅膀
        return wingsystem.updateAttr(actor, true)
    elseif typeUp == 5 then --守护等级
        return yongbingsystem.updateAttr(actor, true)
    elseif typeUp == 6 then --守护等阶
        return yongbingsystem.updateAttr(actor, true)
    elseif typeUp == 7 then --神装
        return shenzhuangsystem.updateAttr(actor, true)
    elseif typeUp == 8 then --梅林
        return meilinsystem.updateAttr(actor, true)
    elseif typeUp == 9 then --神魔等级
        return shenmosystem.updateAttr(actor, true)
    elseif typeUp == 10 then --神魔进阶
        return shenmosystem.updateAttr(actor, true)
    elseif typeUp == 11 then --奥义系统
        actorevent.onEvent(actor, aeAoyiLevelUp)
        return aoyisystem.updateAttr(actor, true)
    elseif typeUp == 13 then --战力勋章
        return zlxzsystem.updateAttr(actor, true)
    elseif typeUp == 16 or typeUp == 18 then
        return shenyousystem.updateAttr(actor, true)
    elseif typeUp >= 20 and typeUp <= 24 then
        return yuansusystem.updateYSAttr(actor, true)
    elseif typeUp >= 27 and typeUp <= 86 then
        return lingqisystem.updateLQAttr(actor, true)
    elseif typeUp >= 87 and typeUp <= 116 then
        return smzlsystem.calcAttr(actor, true)
    elseif typeUp >= 117 and typeUp <= 121 then
        return yuansusystem.updateYSAttr(actor, true)
    elseif typeUp >= 122 and typeUp <= 128 then
        return sjzhsystem.updateSJZHAttr(actor, true)
    end
end

function c2sLevelUp(actor, packet)
    local skillid = LDataPack.readInt(packet)
    levelUp(actor, skillid)
end

function levelUp(actor, skillid)
    local var = getActorVar(actor)
    if not SkillPassiveConfig[skillid] then return end
    
    local level = 0
    if SkillPassiveConfig[skillid][0].type == PASSIVE_TYPE_ADD_ATTR then
        level = var.skills[skillid] or 0
    else
        level = LActor.getPassiveLevel(actor, skillid)
    end
    
    if not SkillPassiveConfig[skillid][level + 1] then return end
    local conf = SkillPassiveConfig[skillid][level]
    
    --检查前置技能条件是否满足
    for _, condition in ipairs(conf.preCondition) do
        if getSkillLv(actor, condition.id) < condition.level then
            return
        end
    end
    
    --检查所需系统等级是否足够
    if not checkTypeLevel(actor, conf.typeUp, conf.typeLevel) then
        return
    end
    if conf.item.id then
        if actoritem.getItemCount(actor, conf.item.id) <= 0 then
            return
        end
        actoritem.reduceItem(actor, conf.item.id, conf.item.count, "passive skill up:")
    end
    
    if SkillPassiveConfig[skillid][0].type == PASSIVE_TYPE_ADD_ATTR then
        if not var.skills[skillid] then
            var.count = var.count + 1
        end
        var.skills[skillid] = level + 1
    else
        LActor.setPassiveLevel(actor, skillid, level + 1)
    end
    updateSysAttr(actor, conf.typeUp)
    updatePassiveSkill(actor, skillid, level + 1)
end

function updatePassiveSkill(actor, skillid, level)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_PassiveLevelUpRet)
    if not pack then return end
    
    LDataPack.writeInt(pack, skillid)
    LDataPack.writeShort(pack, level)
    LDataPack.flush(pack)
end

function onLogin(actor)
    sendSkillList(actor)
end

actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_PassiveLevelUp, c2sLevelUp)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.skillAll = function (actor, args)
    local var = getActorVar(actor)
    --主动技能满级
    for index, conf in pairs(SkillsLevelConfig) do
        local maxlevel = #conf
        LActor.setSkillLevel(actor, index, maxlevel - 1)
    end
    --被动技能满级
    for skillid, conf in pairs(SkillPassiveConfig) do
        local maxlevel = #conf
        if SkillPassiveConfig[skillid][maxlevel].type == PASSIVE_TYPE_ADD_ATTR then
            if not var.skills[skillid] then
                var.count = var.count + 1
            end
            var.skills[skillid] = maxlevel
        else
            LActor.setPassiveLevel(actor, skillid, maxlevel)
        end
        local typeUp = conf[maxlevel].typeUp
        updateSysAttr(actor, typeUp)
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_PassiveLevelUpRet)
        LDataPack.writeInt(pack, skillid)
        LDataPack.writeShort(pack, maxlevel)
        LDataPack.flush(pack)
    end
end

gmCmdHandlers.passive = function(actor, args)
    local skillid = tonumber(args[1])
    local level = tonumber(args[2]) - 1
    local conf = SkillPassiveConfig[skillid][level]
    if not conf then return false end
    
    if SkillPassiveConfig[skillid][0].type == PASSIVE_TYPE_ADD_ATTR then
        local var = getActorVar(actor)
        if not var.skills[skillid] then
            var.count = var.count + 1
        end
        var.skills[skillid] = level + 1
    else
        LActor.setPassiveLevel(actor, skillid, level + 1)
    end
    updateSysAttr(actor, conf.typeUp)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_PassiveLevelUpRet)
    LDataPack.writeInt(pack, skillid)
    LDataPack.writeShort(pack, level + 1)
    LDataPack.flush(pack)
    return true
end

gmCmdHandlers.passiveall = function(actor, args)
    local var = getActorVar(actor)
    for k, v in pairs(SkillPassiveConfig) do
        if v[0].type == PASSIVE_TYPE_ADD_ATTR then
            if not var.skills[v] then
                var.count = var.count + 1
            end
            var.skills[k] = #v
        else
            LActor.setPassiveLevel(actor, k, #v)
        end
    end
    
    return true
end

gmCmdHandlers.skilllevel = function(actor, args)
    local level = tonumber(args[1])
    local index = tonumber(args[2])
    if index then
        LActor.setSkillLevel(actor, index - 1, level - 1)
    else
        for i = 0, SkillsLen_Max - 1 do
            LActor.setSkillLevel(actor, i, level - 1)
        end
    end
    return true
end

gmCmdHandlers.skillclear = function(actor, args)
    local var = getActorVar(actor)
    for skillid, config in pairs(SkillPassiveConfig) do
        local typeUp = config[0].typeUp
        if (typeUp >= 27 and typeUp <= 56) or (typeUp >= 57 and typeUp <= 86) then -- 灵器升级条件
            if config[0].type == PASSIVE_TYPE_ADD_ATTR then
                var.skills[skillid] = 1
            else
                LActor.setPassiveLevel(actor, skillid, 1)
            end
        end
    end
    return true
end
