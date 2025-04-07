module('footsystem', package.seeall)

local function fixInitVar(actor, var)
    for k in ipairs(FootHuanhuaBaseConfig) do
        if not var.huanhua[k] then
            var.huanhua[k] = 0
        end
        if not var.equips[k] then
            var.equips[k] = {}
            for i = 1, #FootHuanhuaBaseConfig[k].equips do
                var.equips[k][i] = {level = 0}
            end
        end
        if not var.skills[k] then
            var.skills[k] = {}
        end
        local skills = var.skills[k]
        -- 初始化技能等级为0
        for kk, vv in ipairs(FootConstConfig.skills) do
            if not skills[kk] then
                skills[kk] = 0
            end
        end
    end
end

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.foot then
        var.foot = {} ----命名空间
        var.foot.level = 1
        ----足迹等级
        var.foot.exp = 0
        ----足迹等级
        var.foot.huanhua = {}
        ----足迹幻化等级
        var.foot.equips = {} --足迹装备
        var.foot.skills = {}
        var.foot.choose = 0 --当前幻化的足迹id
        var.foot.dashi = 0
        fixInitVar(actor, var.foot)
    end
    return var.foot
end

local function isOpen(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    return var.open ~= nil
end

local function updateAttr(actor, isCalc, var)
    if not var then
        var = getActorVar(actor)
    end
    local addAttrs = {}
    local power = 0
    local feedAttrs = {}
    --等级
    for k, v in ipairs(FootLevelConfig[var.level].attr) do
        feedAttrs[v.type] = (feedAttrs[v.type] or 0) + v.value
    end
    --大师
    for k, v in ipairs(FootDashiConfig[var.dashi].addattr) do
        addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
    end
    --幻化
    for k, conf in pairs(FootHuanhuaBaseConfig) do
        if (var.huanhua[k] or 0) > 0 then
            for __,vv in ipairs(conf.baseAttrs) do
                addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * var.huanhua[k]
            end
        end
        for i = 1, #conf.equips do
            if (var.equips[k][i].isequip or 0) ~= 0 then
                local equipid = FootHuanhuaBaseConfig[k].equips[i]
                local conf = ItemConfig[equipid]
                for kk, vv in ipairs(conf.pattr) do
                    addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value
                end
            end
            for kk, vv in ipairs(FootSecretConfig[i][var.equips[k][i].level or 0].addattr) do
                addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value
            end
        end

        for kk, vv in ipairs(FootConstConfig.skills) do
            local level = var.skills[k][kk]
            local conf = SkillPassiveConfig[vv][level]
            if conf.type == 1 then
                for _, attr in ipairs(conf.addattr) do
                    addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
                end
            end
            power = power + conf.power
        end
    end

    for k, v in pairs(feedAttrs) do
        --等级属性增加
        if k == Attribute.atHpMax then
            addAttrs[k] = (addAttrs[k] or 0) + math.floor((addAttrs[Attribute.atFootHpPer] or 0) / 10000 * v)
        elseif k == Attribute.atDef then
            addAttrs[k] = (addAttrs[k] or 0) + math.floor((addAttrs[Attribute.atFootDefPer] or 0) / 10000 * v)
        elseif k == Attribute.atDefSuc then
            addAttrs[k] = (addAttrs[k] or 0) + math.floor((addAttrs[Attribute.atFootDefSucPer] or 0) / 10000 * v)
        end
        --总属性增加
        addAttrs[k] = (addAttrs[k] or 0) + math.floor( v* ( 1 + (addAttrs[Attribute.atFootTotalPer] or 0) / 10000))
    end

    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Foot)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    attr:SetExtraPower(power)
    if isCalc then
        LActor.reCalcAttr(actor)
    end
end

local function sendChoose(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    actorevent.onEvent(actor, aeNotifyFacade)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Foot, Protocol.sFootCmd_SendChoose)
    LDataPack.writeChar(npack, var.choose)
    LDataPack.flush(npack)
end

local function sendInfo(actor)
    local var = getActorVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Foot, Protocol.sFootCmd_Info)
    LDataPack.writeShort(npack, var.level)
    LDataPack.writeInt(npack, var.exp)
    LDataPack.writeChar(npack, #FootHuanhuaBaseConfig)
    for k in ipairs(FootHuanhuaBaseConfig) do
        if not var.equips[k] or not var.huanhua[k] or not var.skills[k] then
            return
        end
        LDataPack.writeChar(npack, k)
        LDataPack.writeShort(npack, var.huanhua[k])
        LDataPack.writeChar(npack, #FootHuanhuaBaseConfig[k].equips)
        for kk in ipairs(FootHuanhuaBaseConfig[k].equips) do
            LDataPack.writeChar(npack, var.equips[k][kk].isequip or 0)
            LDataPack.writeShort(npack, var.equips[k][kk].level or 0)
        end
        LDataPack.writeChar(npack, #FootConstConfig.skills)
        for kk in ipairs(FootConstConfig.skills) do
            LDataPack.writeShort(npack, var.skills[k][kk] or 0)
        end
    end
    LDataPack.writeChar(npack, var.choose)
    LDataPack.writeChar(npack, var.dashi)
    LDataPack.flush(npack)
end

function levelUp(actor, pack)
    local index = LDataPack.readChar(pack)

    local conf = FootItemConfig[index]
    if not conf then
        return
    end

    local var = getActorVar(actor)
    if not FootLevelConfig[var.level + 1] then
        return
    end
    local count = actoritem.getItemCount(actor, conf.itemid)
    if count <= 0 then
        return
    end
    count = math.min(count, math.ceil((FootLevelConfig[var.level].needexp - var.exp) / conf.addexp))
    actoritem.reduceItem(actor, conf.itemid, count, 'foot level up')
    local sum = conf.addexp * count
    var.exp = var.exp + sum

    for i = 1, 100 do
        -- 一次最多升100级
        if var.exp >= FootLevelConfig[var.level].needexp then
            var.exp = var.exp - FootLevelConfig[var.level].needexp
            var.level = var.level + 1
        else
            break
        end
    end
    utils.logCounter(actor, "foot exp", sum, var.level, var.exp)
    updateAttr(actor, true)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Foot, Protocol.sFootCmd_LevelUp)
    LDataPack.writeShort(npack, var.level)
    LDataPack.writeInt(npack, var.exp)
    LDataPack.flush(npack)
end

local function huanhuaUp(actor, pack)
    local id = LDataPack.readChar(pack)
    local conf = FootHuanhuaBaseConfig[id]
    if not conf then return end
    local var = getActorVar(actor)
    local lv = var.huanhua[id] or 0
    if lv >= conf.maxLevel then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = FootHuanhuaBaseConfig[id].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (var.huanhua[id] or 0) >= conf.maxLevel then
		count = conf.maxLevel - (var.huanhua[id] or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "foot huanhua up")
    var.huanhua[id] = lv + count

    updateAttr(actor, true)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Foot, Protocol.sFootCmd_HuahuaUp)
    LDataPack.writeChar(npack, id)
    LDataPack.writeShort(npack, var.huanhua[id])
    LDataPack.flush(npack)
    if var.huanhua[id] == 1 then
        var.choose = id
    end
    sendChoose(actor)
end

local function putEquip(actor, pack)
    local id = LDataPack.readChar(pack)
    local index = LDataPack.readChar(pack)
    if not FootHuanhuaBaseConfig[id] or not FootHuanhuaBaseConfig[id].equips[index] then
        return
    end
    local var = getActorVar(actor)
    if (var.equips[id][index].isequip or 0) == 1 then
        return
    end
    local equipid = FootHuanhuaBaseConfig[id].equips[index]
    if not actoritem.checkItem(actor, equipid, 1) then
        return
    end

    actoritem.reduceItem(actor, equipid, 1, 'foot equip put on')
    var.equips[id][index].isequip = 1
    updateAttr(actor, true)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Foot, Protocol.sFootCmd_PutEquip)
    LDataPack.writeChar(npack, id)
    LDataPack.writeChar(npack, index)
    LDataPack.writeChar(npack, var.equips[id][index].isequip)
    LDataPack.flush(npack)
end

local function equipUp(actor, pack)
    local id = LDataPack.readChar(pack)
    if not FootHuanhuaBaseConfig[id] then
        return
    end
    local var = getActorVar(actor)
    local minlv = 9999
    local maxlv = 0
    local equips = FootHuanhuaBaseConfig[id].equips
    for i = 1, #equips do
        local eq = var.equips[id][i]
        if eq.isequip then
            eq.level = eq.level or 0
            local lv = eq.level
            if lv > maxlv then
                maxlv = lv
            end
            if lv < minlv then
                minlv = lv
            end
        end
    end
    local change = false
    if minlv == maxlv then
        for i = 1, #FootSecretConfig do -- i=0, EquipType_Max - 1 do
            local eq = var.equips[id][i]
            if eq.isequip then
                local level = eq.level or 0
                if level == minlv then
                    if not FootSecretConfig[i][level + 1] then
                        break
                    end
                    if not actoritem.checkItem(actor, NumericType_Secret, FootSecretConfig[i][level].need) then
                        break
                    end
                    change = true
                    eq.level = level + 1
                    actoritem.reduceItem(
                        actor,
                        NumericType_Secret,
                        FootSecretConfig[i][level].need,
                        'foot equip up:' .. level
                    )
                --actorevent.onEvent(actor, aeAppendEquip, i, level + 1)
                end
            end
        end
    end
    while (minlv < maxlv) do
        local isbreak = false
        for i = 1, #FootSecretConfig do -- i=0, EquipType_Max - 1 do
            local eq = var.equips[id][i]
            if eq.isequip then
                local level = eq.level
                if level == minlv then
                    if not FootSecretConfig[i][level + 1] then
                        isbreak = true
                        break
                    end
                    if not actoritem.checkItem(actor, NumericType_Secret, FootSecretConfig[i][level].need) then
                        isbreak = true
                        break
                    end
                    eq.level = level + 1
                    change = true
                    actoritem.reduceItem(
                        actor,
                        NumericType_Secret,
                        FootSecretConfig[i][level].need,
                        'foot equip up:' .. level
                    )
                --actorevent.onEvent(actor, aeAppendEquip, i, level + 1)
                end
            end
        end
        minlv = minlv + 1
        if isbreak then
            break
        end
    end
    if change then
        updateAttr(actor, true)
        s2cOneKeyInfo(actor, id)
    end
end

function s2cOneKeyInfo(actor, id)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Foot, Protocol.sFootCmd_EquipUp)
    local var = getActorVar(actor)
    LDataPack.writeChar(npack, id)
    LDataPack.writeChar(npack, #FootSecretConfig)
    for k in ipairs(FootSecretConfig) do
        LDataPack.writeChar(npack, var.equips[id][k].isequip or 0)
        LDataPack.writeShort(npack, var.equips[id][k].level or 0)
    end
    LDataPack.flush(npack)
end

function equipFenjie(actor, pack)
    local count = LDataPack.readShort(pack)
    local item_list = {}
    for i = 1, count do
        local id = LDataPack.readInt(pack)
        if item_list[id] then
            item_list[id].count = item_list[id].count + 1
        else
            item_list[id] = {id = id, count = 1}
        end
    end

    if not actoritem.checkItems(actor, item_list) then
        return
    end

    local conf = FootFenjieConfig
    local jing = 0
    for id, item in pairs(item_list) do
        local itemConf = ItemConfig[item.id]
        local fenjieConf = conf[itemConf.quality][itemConf.star]
        if not fenjieConf then
            print(
                'invalid quality to fenjie item.id=' ..
                    item.id .. ' quality=' .. itemConf.quality .. ' star=' .. itemConf.star
            )
        else
            jing = jing + fenjieConf.index * item.count
        end
    end

    actoritem.reduceItems(actor, item_list, 'foot equip fenjie')
    actoritem.addItem(actor, NumericType_Secret, jing, 'foot equip fenjie')

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Foot, Protocol.sFootCmd_EquipFenjie)
    LDataPack.flush(npack)
end

local function c2sEquipDazao(actor, pack)
    local tarid = LDataPack.readInt(pack)
    local len = LDataPack.readChar(pack)
    local material = {}
    for i = 1, len do
        local id = LDataPack.readInt(pack)
        if material[id] then
            material[id].count = material[id].count + 1
        else
            material[id] = {id = id, count = 1}
        end
    end

    local conf = ItemConfig[tarid]
    if not conf then
        print('no item config for tarid=' .. tarid)
        return
    end
    local star = conf.star

    -- 检查材料数量
    if star == 4 then
        if len ~= FootConstConfig.needcount4 then
            print('star = 4 need=' .. FootConstConfig.needcount4 .. ' has=' .. len .. 'tarid=' .. tarid)
            return
        end
    elseif star <= 1 then
        return
    else
        if len ~= FootConstConfig.needcount then
            print('need=' .. FootConstConfig.needcount .. ' has=' .. len .. ' star=' .. star .. 'tarid=' .. tarid)
            return
        end
    end
    -- 检查是否同星级，同品质
    for id, item in pairs(material) do
        local itemConf = ItemConfig[id]
        if not itemConf or itemConf.type ~= ItemType_FootEquip or itemConf.star ~= star - 1 or itemConf.rank ~= conf.rank then
            print('foot equip dazao check failed material=' .. id .. ' target=' .. tarid)
            return
        end
    end

    -- 打造4星级需要额外材料
    if star == 4 then
        material[FootConstConfig.dazaoneeditem.id] = FootConstConfig.dazaoneeditem
    end

    if not actoritem.checkItems(actor, material) then
        return
    end

    actoritem.reduceItems(actor, material, 'foot equip dazao')

    actoritem.addItem(actor, tarid, 1, 'dazao foot equip')

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Foot, Protocol.sFootCmd_EquipDazao)
    if npack == nil then
        return
    end
    LDataPack.writeInt(npack, tarid)
    LDataPack.flush(npack)
end

local function dashiUp(actor, pack)
    local var = getActorVar(actor)
    if not FootDashiConfig[var.dashi + 1] then
        print('dashiUp level max')
        return
    end
    if FootDashiConfig[var.dashi].needlv > var.level then
        print('dashiUp need level=' .. FootDashiConfig[var.dashi].needlv .. ' var.level=' .. var.level)
        return
    end

    var.dashi = var.dashi + 1

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Foot, Protocol.sFootCmd_DashiUp)
    LDataPack.writeChar(pack, var.dashi)
    LDataPack.flush(pack)

    updateAttr(actor, true)
end

function skillUp(actor, pack)
    local id = LDataPack.readChar(pack)
    local index = LDataPack.readChar(pack)
    local skillid = FootConstConfig.skills[index]
    if not FootHuanhuaBaseConfig[id] then
        return
    end
    if not FootConstConfig.skills[index] then
        return
    end
    local var = getActorVar(actor)
    if not SkillPassiveConfig[skillid][var.skills[id][index] + 1] then
        return
    end
    local minlv = 9999
    for i = 1, #FootHuanhuaBaseConfig[id].equips do
        local lv = var.equips[id][i].level or 0
        if lv < minlv then
            minlv = lv
        end
    end
    if minlv < SkillPassiveConfig[skillid][var.skills[id][index]].typeLevel then
        return
    end

    var.skills[id][index] = var.skills[id][index] + 1
    updateAttr(actor, true)

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Foot, Protocol.sFootCmd_SkillUp)
    LDataPack.writeChar(pack, id)
    LDataPack.writeChar(pack, index)
    LDataPack.writeShort(pack, var.skills[id][index])
    LDataPack.flush(pack)
end

local function changeChoose(actor, pack, var)
    if not var then
        var = getActorVar(actor)
    end
    local id = LDataPack.readChar(pack)
    if (var.huanhua[id] or 0) < 1 then
        return
    end
    var.choose = id
    sendChoose(actor, var)
end

local function tryOpen(actor, custom, var)
    if custom < actorexp.getLimitCustom(actor, actorexp.LimitTp.foot) then
        return
    end
    if not var then
        var = getActorVar(actor)
    end
    var.open = 1
end

local function onCustomChange(actor, custom, oldcustom)
    if not isOpen(actor) then
        tryOpen(actor, custom)
        if isOpen(actor) then
            sendInfo(actor)
        end
    end
end

function onLogin(actor)
    local var = getActorVar(actor)
    if not isOpen(actor, var) then
        tryOpen(actor, guajifuben.getCustom(actor), var)
    end
    if isOpen(actor) then
        -- 有可能策划改表，重新把数据里面缺少的部分补上
        fixInitVar(actor, var)
        sendInfo(actor)
    end
end

function onInit(actor)
    if isOpen(actor) then
        updateAttr(actor)
    end
end

function getFootId(actor)
    local var = getActorVar(actor)
    return var.choose
end

_G.getFootId = getFootId

local function init()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeCustomChange, onCustomChange)

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Foot, Protocol.cFootCmd_LevelUp, levelUp)
    netmsgdispatcher.reg(Protocol.CMD_Foot, Protocol.cFootCmd_HuahuaUp, huanhuaUp)
    netmsgdispatcher.reg(Protocol.CMD_Foot, Protocol.cFootCmd_PutEquip, putEquip)
    netmsgdispatcher.reg(Protocol.CMD_Foot, Protocol.cFootCmd_EquipUp, equipUp)
    netmsgdispatcher.reg(Protocol.CMD_Foot, Protocol.cFootCmd_EquipFenjie, equipFenjie)
    netmsgdispatcher.reg(Protocol.CMD_Foot, Protocol.cFootCmd_EquipDazao, c2sEquipDazao)
    netmsgdispatcher.reg(Protocol.CMD_Foot, Protocol.cFootCmd_ChangeChoose, changeChoose)
    netmsgdispatcher.reg(Protocol.CMD_Foot, Protocol.cFootCmd_DashiUp, dashiUp)
    netmsgdispatcher.reg(Protocol.CMD_Foot, Protocol.cFootCmd_SkillUp, skillUp)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
function gmCmdHandlers.ftClear(actor, args)
    local var = LActor.getStaticVar(actor)
    var.foot = nil
    return true
end

gmCmdHandlers.footAll = function (actor, args)
    local IsChange = false
    local var = getActorVar(actor)
    local maxlevel = #FootLevelConfig
    if var.level < maxlevel then
        var.level = maxlevel
        IsChange = true
    end

    maxlevel = #FootDashiConfig
    if var.dashi < maxlevel then
        var.dashi = maxlevel
        IsChange = true
    end

    local maxSkillNum = #FootConstConfig.skills
    for id, conf in pairs(FootHuanhuaBaseConfig) do
        maxlevel = conf.maxLevel
        if (var.huanhua[id] or 0) < maxlevel then
            var.huanhua[id] = maxlevel
            IsChange = true
        end

        for index, skillId in ipairs(FootConstConfig.skills) do
            maxlevel = #SkillPassiveConfig[skillId]
            if var.skills[id][index] < maxlevel then
                var.skills[id][index] = maxlevel
                IsChange = true
            end
        end
    end
    var.choose = #FootHuanhuaBaseConfig
    for id, conf in pairs(FootHuanhuaBaseConfig) do
        for index in ipairs(conf.equips) do
            maxlevel = #FootSecretConfig[index]
            if var.equips[id][index].isequip ~= 1 then
                var.equips[id][index].isequip = 1
                var.equips[id][index].level = maxlevel
                IsChange = true
            end
        end
    end
    updateAttr(actor, true)
    sendInfo(actor)
    return true
end

