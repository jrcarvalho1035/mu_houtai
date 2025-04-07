--幻兽系统
module("huanshousystem", package.seeall)

local HSEQUIP_MAKE_MAX_COUNT = 5

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.huanshou then
        var.huanshou = {
            fightCount = 0,
            extendPitCount = 0,
            huanshous = {},
            fightPits = {},
        }
    end
    return var.huanshou
end

local function getHuanshouVar(var, id)
    if not HuanShouBaseConfig[id] then return end
    if not var then return end
    if not var.huanshous[id] then
        var.huanshous[id] = {
            isFight = 0, --出战状态
            pitId = 0, --使用坑位
            equips = {}, --幻兽装备
        }
    end
    return var.huanshous[id]
end

--同步出战数量与实际的出战数量
local function checkHSFightCount(actor)
    local var = getActorVar(actor)
    local count = 0
    for id, conf in ipairs(HuanShouBaseConfig) do
        local huanshou = getHuanshouVar(var, id)
        if huanshou and huanshou.isFight == 1 then
            count = count + 1
        end
    end
    var.fightCount = count
end

--出现异常时,检查所有通用技能槽的出战幻兽id是否都召回了
local function checkHSFightPit(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local maxFightCount = var.extendPitCount + HuanShouConstConfig.fightCount
    for idx = 1, maxFightCount do
        local pit = var.fightPits[idx]
        local huanshouId = pit and pit.huanshouId or 0
        local huanshou = var.huanshous[huanshouId]
        if huanshou and huanshou.isFight == 0 then
            pit.huanshouId = 0
        end
    end
end

local function getHSFightPit(var, idx, isInit)
    if not var then return end
    if not var.fightPits[idx] and isInit then
        var.fightPits[idx] = {
            huanshouId = 0,
        }
        local pit = var.fightPits[idx]
        for idx, commonSkillId in ipairs(HuanShouConstConfig.commonSkillIndex) do
            pit[idx] = commonSkillId
        end
    end
    return var.fightPits[idx]
end

local function calcAttr(actor, calc)
    local var = getActorVar(actor)
    local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_huanshou)
    attrs:Reset()
    
    local HuanShouCommonSkillConfig = HuanShouCommonSkillConfig
    local commonSkillIndex = HuanShouConstConfig.commonSkillIndex
    local huanshouAttr = {}
    local equipBaseAttr = {}
    local equipExAttr = {}
    local commonSkillAttr = {}
    local wakeSkillAttr = {}
    local exAttr = {}
    local finalAttr = {}
    local power = 0
    
    for id, conf in ipairs(HuanShouBaseConfig) do
        local huanshou = getHuanshouVar(var, id)
        if huanshou.isFight == 1 then
            --=======幻兽基础属性=======
            huanshouAttr[id] = {}
            for _, v in ipairs(conf.baseAttrs) do
                huanshouAttr[id][v.type] = (huanshouAttr[id][v.type] or 0) + v.value
            end
            
            --=======幻兽装备属性=======
            equipBaseAttr[id] = {}--白字基础属性
            equipExAttr[id] = {}--紫色卓越属性(蓝色直接加到总属性中)
            local equips = huanshou.equips
            for slot in ipairs(conf.equipIndex) do
                equipBaseAttr[id][slot] = {}
                local equipId = equips[slot].id
                local equipLv = equips[slot].lv
                local equipConfig = HuanShouEquipConfig[equipId] and HuanShouEquipConfig[equipId][equipLv]
                if equipConfig then
                    for _, v in ipairs(equipConfig.baseAttrs) do
                        equipBaseAttr[id][slot][v.type] = (equipBaseAttr[id][slot][v.type] or 0) + v.value
                    end
                    
                    for _, v in ipairs(equipConfig.exAttrs1) do
                        finalAttr[v.type] = (finalAttr[v.type] or 0) + v.value
                    end
                    
                    for _, v in ipairs(equipConfig.exAttrs2) do
                        equipExAttr[id][v.type] = (equipExAttr[id][v.type] or 0) + v.value
                    end
                    power = power + equipConfig.extraPower
                end
            end
            
            --=======幻兽通用技能属性=======
            commonSkillAttr[id] = {}
            local pit = getHSFightPit(var, huanshou.pitId)
            if pit then
                for idx in ipairs(commonSkillIndex) do
                    local commonSkillId = pit[idx]
                    local commonSkillConfig = HuanShouCommonSkillConfig[commonSkillId]
                    for _, v in ipairs(commonSkillConfig.baseAttrs) do
                        finalAttr[v.type] = (finalAttr[v.type] or 0) + v.value
                    end
                    
                    for _, v in ipairs(commonSkillConfig.skillAttrs) do
                        commonSkillAttr[id][v.type] = (commonSkillAttr[id][v.type] or 0) + v.value
                    end
                end
            end
            
            --=======幻兽觉醒技能属性=======
            wakeSkillAttr[id] = {}
            local wakeSkillConfig = HuanShouWakeSkillConfig[conf.skillId]
            if wakeSkillConfig then
                for _, v in ipairs(wakeSkillConfig.skillAttrs) do
                    if v.type >= Attribute.atHSAtkSelfPer and v.type <= Attribute.atHSAllSelfPer then
                        wakeSkillAttr[id][v.type] = (wakeSkillAttr[id][v.type] or 0) + v.value
                    elseif v.type >= Attribute.atHSThreeFightPer and v.type <= Attribute.atHSAllFightPer then
                        exAttr[v.type] = (exAttr[v.type] or 0) + v.value
                    end
                end
            end
            
            --=======计算装备卓越属性=======
            --幻兽生命万分比
            local hsAttr = huanshouAttr[id]
            local hsHpMaxPer = equipExAttr[id][Attribute.atHSHpMaxPer] or 0
            if hsHpMaxPer > 0 then
                finalAttr[Attribute.atHSHpMax] = (finalAttr[Attribute.atHSHpMax] or 0) + math.floor((hsAttr[Attribute.atHSHpMax] or 0) * hsHpMaxPer / 10000)
            end
            
            --幻兽攻击万分比
            local hsAtkPer = equipExAttr[id][Attribute.atHSAtkPer] or 0
            if hsAtkPer > 0 then
                finalAttr[Attribute.atHSAtk] = (finalAttr[Attribute.atHSAtk] or 0) + math.floor((hsAttr[Attribute.atHSAtk] or 0) * hsAtkPer / 10000)
            end
            
            --幻兽防御力万分比
            local hsDefPer = equipExAttr[id][Attribute.atHSDefPer] or 0
            if hsDefPer > 0 then
                finalAttr[Attribute.atHSDef] = (finalAttr[Attribute.atHSDef] or 0) + math.floor((hsAttr[Attribute.atHSDef] or 0) * hsDefPer / 10000)
            end
            
            --幻兽破防万分比
            local hsIgnoreDefPer = equipExAttr[id][Attribute.atHSIgnoreDefPer] or 0
            if hsIgnoreDefPer > 0 then
                finalAttr[Attribute.atHSIgnoreDef] = (finalAttr[Attribute.atHSIgnoreDef] or 0) + math.floor((hsAttr[Attribute.atHSIgnoreDef] or 0) * hsIgnoreDefPer / 10000)
            end
            
            --=======计算通用技能部位加成=======
            local hsEquipAttr = equipBaseAttr[id]
            --兽装圣角部位
            local hsHornPer = commonSkillAttr[id][Attribute.atHSHornPer] or 0
            if hsHornPer > 0 then
                for k, v in pairs(equipBaseAttr[id][HSEquipType_Horn]) do
                    finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * hsHornPer / 10000)
                end
            end
            
            --兽装魔躯部位
            local hsBobyPer = commonSkillAttr[id][Attribute.atHSBobyPer] or 0
            if hsBobyPer > 0 then
                for k, v in pairs(equipBaseAttr[id][HSEquipType_Boby]) do
                    finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * hsBobyPer / 10000)
                end
            end
            
            --兽装神瞳部位
            local hsPupilPer = commonSkillAttr[id][Attribute.atHSPupilPer] or 0
            if hsPupilPer > 0 then
                for k, v in pairs(equipBaseAttr[id][HSEquipType_Pupil]) do
                    finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * hsPupilPer / 10000)
                end
            end
            
            --兽装圣爪部位
            local hsClawPer = commonSkillAttr[id][Attribute.atHSClawPer] or 0
            if hsClawPer > 0 then
                for k, v in pairs(equipBaseAttr[id][HSEquipType_Claw]) do
                    finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * hsClawPer / 10000)
                end
            end
            
            --兽装幻尾部位
            local hsTailPer = commonSkillAttr[id][Attribute.atHSTailPer] or 0
            if hsTailPer > 0 then
                for k, v in pairs(equipBaseAttr[id][HSEquipType_Tail]) do
                    finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * hsTailPer / 10000)
                end
            end
            
            --=======计算觉醒技能万分比属性=======
            --兽装攻击万分比
            local hsAtkSelfPer = wakeSkillAttr[id][Attribute.atHSAtkSelfPer] or 0
            if hsAtkSelfPer > 0 then
                for _, slotAttr in ipairs(equipBaseAttr[id]) do
                    for k, v in pairs(slotAttr) do
                        if k == Attribute.atHSAtk then
                            finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * hsAtkSelfPer / 10000)
                        end
                    end
                end
            end
            
            --兽装生命万分比
            local hsHpSelfPer = wakeSkillAttr[id][Attribute.atHSHpSelfPer] or 0
            if hsHpSelfPer > 0 then
                for _, slotAttr in ipairs(equipBaseAttr[id]) do
                    for k, v in pairs(slotAttr) do
                        if k == Attribute.atHSHpMax then
                            finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * hsHpSelfPer / 10000)
                        end
                    end
                end
            end
            
            --兽装防御万分比
            local hsDefSelfPer = wakeSkillAttr[id][Attribute.atHSDefSelfPer] or 0
            if hsDefSelfPer > 0 then
                for _, slotAttr in ipairs(equipBaseAttr[id]) do
                    for k, v in pairs(slotAttr) do
                        if k == Attribute.atHSDef then
                            finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * hsDefSelfPer / 10000)
                        end
                    end
                end
            end
            
            --兽装全属性万分比
            local hsAllSelfPer = wakeSkillAttr[id][Attribute.atHSAllSelfPer] or 0
            if hsAllSelfPer > 0 then
                for _, slotAttr in ipairs(equipBaseAttr[id]) do
                    for k, v in pairs(slotAttr) do
                        finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * hsAllSelfPer / 10000)
                    end
                end
            end
            
        end
    end
    
    --=======计算觉醒技能中加3、4个和全部出战最高品质幻兽兽装属性=======
    local threePer = exAttr[Attribute.atHSThreeFightPer] or 0 --3个最高品质出战幻兽的兽装全属性加成万分比
    local fourPer = exAttr[Attribute.atHSFourFightPer] or 0 --4个最高品质出战幻兽的兽装全属性加成万分比
    local allPer = exAttr[Attribute.atHSAllFightPer] or 0 --全部出战幻兽的兽装全属性加成万分比
    if threePer > 0 or fourPer > 0 or allPer > 0 then
        local count = 0
        for id = #HuanShouBaseConfig, 1, -1 do
            if equipBaseAttr[id] then
                for _, slotAttr in ipairs(equipBaseAttr[id]) do
                    for k, v in pairs(slotAttr) do
                        if count < 3 then
                            finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * (threePer + fourPer + allPer) / 10000)
                        elseif count < 4 then
                            finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * (fourPer + allPer) / 10000)
                        else
                            finalAttr[k] = (finalAttr[k] or 0) + math.floor(v * allPer / 10000)
                        end
                    end
                end
                count = count + 1
            end
        end
    end
    
    --所有属性整合到一起
    for _, attrs in pairs(huanshouAttr) do
        for k, v in pairs(attrs) do
            finalAttr[k] = (finalAttr[k] or 0) + v
        end
    end
    
    for _, slotAttrs in pairs(equipBaseAttr) do
        for __, slotAttr in pairs(slotAttrs) do
            for k, v in pairs(slotAttr) do
                finalAttr[k] = (finalAttr[k] or 0) + v
            end
        end
    end
    
    for _, attrs in pairs(equipExAttr) do
        for k, v in pairs(attrs) do
            finalAttr[k] = (finalAttr[k] or 0) + v
        end
    end
    
    for _, attrs in pairs(commonSkillAttr) do
        for k, v in pairs(attrs) do
            finalAttr[k] = (finalAttr[k] or 0) + v
        end
    end
    
    for _, attrs in pairs(wakeSkillAttr) do
        for k, v in pairs(attrs) do
            finalAttr[k] = (finalAttr[k] or 0) + v
        end
    end
    
    for k, v in pairs(exAttr) do
        finalAttr[k] = (finalAttr[k] or 0) + v
    end
    
    --将整合后的属性加到玩家身上
    for k, v in pairs(finalAttr) do
        attrs:Set(k, v)
    end
    
    if power > 0 then
        attrs:SetExtraPower(power)
    end
    if calc then
        LActor.reCalcAttr(actor)
    end
end

function getHSFightCount(actor)
    local var = getActorVar(actor)
    return var.fightCount
end

--幻兽系统-出战
function hsFight(actor, huanshouId)
    local equipIndex = HuanShouBaseConfig[huanshouId] and HuanShouBaseConfig[huanshouId].equipIndex
    if not equipIndex then return false end
    local var = getActorVar(actor)
    if not var then return end
    local huanshou = getHuanshouVar(var, huanshouId)
    if not huanshou then return end
    if huanshou.isFight == 1 then return end
    
    local maxFightCount = var.extendPitCount + HuanShouConstConfig.fightCount
    if var.fightCount >= maxFightCount then return end
    
    local equips = huanshou.equips
    for slot in ipairs(equipIndex) do
        local equip = equips[slot]
        if not equip then return end
        if equip.id == 0 then return end
    end
    
    for idx = 1, maxFightCount do
        local pit = getHSFightPit(var, idx, true)
        if pit.huanshouId == 0 then
            var.fightCount = var.fightCount + 1
            huanshou.isFight = 1
            huanshou.pitId = idx
            pit.huanshouId = huanshouId
            break
        end
    end
    
    calcAttr(actor, true)
    s2cHSUpdate(actor, huanshouId)
end

--幻兽系统-召回
function hsCancel(actor, huanshouId)
    if not HuanShouBaseConfig[huanshouId] then return end
    local var = getActorVar(actor)
    if not var then return end
    local huanshou = getHuanshouVar(var, huanshouId)
    if not huanshou then return end
    if huanshou.isFight ~= 1 then return end
    
    huanshou.isFight = 0
    local pit = getHSFightPit(var, huanshou.pitId)
    if pit then
        pit.huanshouId = 0
    else
        checkHSFightPit(actor)
    end
    huanshou.pitId = 0
    var.fightCount = var.fightCount - 1
    
    calcAttr(actor, true)
    s2cHSUpdate(actor, huanshouId)
end

--幻兽系统-穿戴/替换
function hsEquipPutOn(actor, huanshouId, slot, uid)
    local huanshouConfig = HuanShouBaseConfig[huanshouId]
    if not huanshouConfig then return end
    
    local slotItemId = huanshouConfig.equipIndex[slot]
    if not slotItemId then return end
    
    local slotItemConfig = ItemConfig[slotItemId]
    if not slotItemConfig then return end
    
    local itemId = LActor.getItemIdByUid(actor, uid, BagType_HuanshouEquip)
    local itemConfig = ItemConfig[itemId]
    if not itemConfig then return end
    
    local equipConfig = HuanShouEquipConfig[itemId]
    if not equipConfig then return end
    
    if slotItemConfig.subType ~= itemConfig.subType then return end
    if slotItemConfig.quality > itemConfig.quality then return end
    if slotItemConfig.star > itemConfig.star then return end
    
    local var = getActorVar(actor)
    if not var then return end
    local huanshou = getHuanshouVar(var, huanshouId)
    if not huanshou then return end
    if not huanshou.equips[slot] then
        huanshou.equips[slot] = {
            id = 0,
            lv = 0,
        }
    end
    local equip = huanshou.equips[slot]
    local oldEquipId = equip.id
    local oldEquipLv = equip.lv
    
    local itemLv = LActor.getHuanshouEquipLv(actor, uid)
    LActor.costItemByUid(actor, uid, 1, BagType_HuanshouEquip, "huanshou equip putOn")
    equip.id = itemId
    equip.lv = itemLv
    
    if oldEquipId > 0 then
        LActor.giveHuanshouEquipItem(actor, oldEquipId, 1, oldEquipLv, "huanshou equip putOff", 0)
    end
    
    --未出战幻兽不用计算属性变更
    if huanshou.isFight == 1 then
        calcAttr(actor, true)
    end
    s2cHSEquipPut(actor, huanshouId, slot, itemId, itemLv)
end

--幻兽系统-卸下装备
function hsEquipPutOff(actor, huanshouId, slot)
    local huanshouConfig = HuanShouBaseConfig[huanshouId]
    if not huanshouConfig then return end
    
    local var = getActorVar(actor)
    if not var then return end
    local huanshou = getHuanshouVar(var, huanshouId)
    if not huanshou then return end
    local equip = huanshou.equips[slot]
    if not equip then return end
    if equip.id == 0 then return end
    if LActor.getHanshouEquipBagSpace(actor) < 1 then
        LActor.sendTipmsg(actor, string.format(ScriptTips.bag01), ttScreenCenter)
        return
    end
    
    local oldEquipId = equip.id
    local oldEquipLv = equip.lv
    equip.id = 0
    equip.lv = 0
    LActor.giveHuanshouEquipItem(actor, oldEquipId, 1, oldEquipLv, "huanshou equip putOff", 0)
    
    if huanshou.isFight == 1 then
        hsCancel(actor, huanshouId)
    end
    s2cHSEquipPut(actor, huanshouId, slot, 0, 0)
end

--幻兽系统-升级通用技能
function hsSkillUp(actor, huanshouId, index)
    local huanshouConfig = HuanShouBaseConfig[huanshouId]
    if not huanshouConfig then return end
    
    local var = getActorVar(actor)
    if not var then return end
    local huanshou = getHuanshouVar(var, huanshouId)
    if not huanshou then return end
    if huanshou.isFight ~= 1 then return end
    local pit = getHSFightPit(var, huanshou.pitId)
    if not pit then return end
    local commonSkillId = pit[index]
    if not commonSkillId then return end
    
    local commonSkillConfig = HuanShouCommonSkillConfig[commonSkillId]
    if not commonSkillConfig then return end
    local nextCommonSkillId = commonSkillConfig.nextId
    if not HuanShouCommonSkillConfig[nextCommonSkillId] then return end
    
    if not actoritem.checkItems(actor, commonSkillConfig.needItems) then return end
    actoritem.reduceItems(actor, commonSkillConfig.needItems, "huanshou commonskill up")
    
    pit[index] = nextCommonSkillId
    
    calcAttr(actor, true)
    s2cHSSkillUp(actor, huanshouId, index, nextCommonSkillId)
end

--幻兽系统-一键强化
function hsEquipUpgrade(actor, huanshouId)
    local equipIndex = HuanShouBaseConfig[huanshouId] and HuanShouBaseConfig[huanshouId].equipIndex
    if not equipIndex then return end
    
    local var = getActorVar(actor)
    if not var then return end
    local huanshou = getHuanshouVar(var, huanshouId)
    if not huanshou then return end
    
    --if huanshou.isFight ~= 1 then return end
    local itemId = HuanShouConstConfig.needItemId
    local itemCount = actoritem.getItemCount(actor, itemId)
    if itemCount <= 0 then return end
    
    local minLv, maxLv
    local equips = huanshou.equips
    local temEquips = {}
    for slot in ipairs(equipIndex) do
        local equipId = equips[slot] and equips[slot].id or 0
        local equipLv = equips[slot] and equips[slot].lv or 0
        temEquips[slot] = {id = equipId, lv = equipLv, }
        if equipId > 0 then
            if minLv == nil or minLv > equipLv then
                minLv = equipLv
            end
            if maxLv == nil or maxLv < equipLv then
                maxLv = equipLv
            end
        end
    end
    
    local costCount = 0
    if minLv == maxLv then --最低等级等于最高等级一样的话,就每个都强化一级
        for slot in ipairs(equipIndex) do
            local equipId = temEquips[slot].id
            local equipLv = temEquips[slot].lv
            if equipId > 0 then
                if not HuanShouEquipConfig[equipId] then break end
                if not HuanShouEquipConfig[equipId][equipLv + 1] then break end
                local equipConfig = HuanShouEquipConfig[equipId][equipLv]
                if not equipConfig then break end
                
                if costCount + equipConfig.needCount <= itemCount then
                    temEquips[slot].lv = equipLv + 1
                    costCount = costCount + equipConfig.needCount
                end
            end
        end
    elseif minLv < maxLv then --如果最低等级小于最高等级,就把低等级的装备都强化到最高级
        repeat
            local isBreak = true
            for slot in ipairs(equipIndex) do
                local equipId = temEquips[slot].id
                local equipLv = temEquips[slot].lv
                if equipId > 0 and equipLv == minLv then
                    if not HuanShouEquipConfig[equipId] then break end
                    if not HuanShouEquipConfig[equipId][equipLv + 1] then break end
                    local equipConfig = HuanShouEquipConfig[equipId][equipLv]
                    if not equipConfig then break end
                    
                    if costCount + equipConfig.needCount <= itemCount then
                        temEquips[slot].lv = equipLv + 1
                        costCount = costCount + equipConfig.needCount
                        isBreak = false
                    end
                end
            end
            if isBreak then break end
            minLv = minLv + 1
        until minLv == maxLv
    end
    
    if costCount <= 0 then return end
    actoritem.reduceItem(actor, itemId, costCount, "huanshou equip upgrade")
    for slot, v in ipairs(temEquips) do
        if v.id > 0 then
            equips[slot].lv = v.lv
        end
    end
    
    calcAttr(actor, true)
    s2cHSEquipUpgrade(actor, huanshouId)
end

--幻兽系统-请求扩展出战数量
function hsExtend(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local extendPitCount = var.extendPitCount
    if extendPitCount >= HuanShouConstConfig.extendFightCount then return end
    
    if not actoritem.checkItems(actor, HuanShouConstConfig.needFightItem) then return end
    actoritem.reduceItems(actor, HuanShouConstConfig.needFightItem, "huanshou extend")
    
    extendPitCount = extendPitCount + 1
    var.extendPitCount = extendPitCount
    s2cHSExtend(actor, extendPitCount)
end

--幻兽系统-请求合成装备
function hsEquipMake(actor, equipId, costItems)
    local itemConfig = ItemConfig[equipId]
    if not itemConfig then return end
    if itemConfig.type ~= ItemType_HuanshouEquip then return end
    
    local star = itemConfig.star
    local dazaoConfig = DazaoHuanShouEquipConfig[star]
    if not dazaoConfig then return end
    if #costItems < dazaoConfig.costEquipCount then return end
    if not actoritem.checkItems(actor, dazaoConfig.costItem) then return end
    
    local quality = itemConfig.quality
    local gainCount = 0
    for _, uid in ipairs(costItems) do
        local itemId = LActor.getItemIdByUid(actor, uid, BagType_HuanshouEquip)
        local itemLv = LActor.getHuanshouEquipLv(actor, uid)
        local config = ItemConfig[itemId]
        if not config then return end
        if config.type ~= ItemType_HuanshouEquip then return end
        if config.quality ~= quality then return end
        if config.star + 1 ~= star then return end
        
        if itemLv > 0 then
            if not HuanShouEquipConfig[itemId] then return end
            local equipConfig = HuanShouEquipConfig[itemId][itemLv]
            if not equipConfig then return end
            local equipConfig0 = HuanShouEquipConfig[itemId][0]
            if not equipConfig0 then return end
            
            gainCount = gainCount + equipConfig.gainCount - equipConfig0.gainCount
        end
    end
    
    actoritem.reduceItems(actor, dazaoConfig.costItem, "huanshou equip make")
    for _, uid in ipairs(costItems) do
        LActor.costItemByUid(actor, uid, 1, BagType_HuanshouEquip, "huanshou equip make")
    end
    
    LActor.giveHuanshouEquipItem(actor, equipId, 1, 0, "huanshou equip make", 0)
    if gainCount > 0 then
        actoritem.addItem(actor, HuanShouConstConfig.needItemId, gainCount, "huanshou equip make back")
    end
    s2cHSEquipMake(actor, equipId)
end

--幻兽系统-请求分解装备
function hsEquipResolve(actor, costItems)
    if #costItems <= 0 then return end
    
    local gainId = HuanShouConstConfig.needItemId
    local gainCount = 0
    
    for _, uid in ipairs(costItems) do
        local itemId = LActor.getItemIdByUid(actor, uid, BagType_HuanshouEquip)
        local itemLv = LActor.getHuanshouEquipLv(actor, uid)
        local equipConfig = HuanShouEquipConfig[itemId] and HuanShouEquipConfig[itemId][itemLv]
        if not equipConfig then break end
        
        LActor.costItemByUid(actor, uid, 1, BagType_HuanshouEquip, "huanshou equip resolve")
        gainCount = gainCount + equipConfig.gainCount
    end
    if gainCount <= 0 then return end
    
    actoritem.addItem(actor, gainId, gainCount, "huanshou equip resolve")
    s2cHSEquipResolve(actor, gainId, gainCount)
end

----------------------------------------------------------------------------------
--协议处理
--84-80 幻兽系统-基础信息
function s2cHSInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sHuanshou_Info)
    if not pack then return end
    
    local commonSkillIndex = HuanShouConstConfig.commonSkillIndex
    LDataPack.writeChar(pack, var.fightCount)
    LDataPack.writeChar(pack, var.extendPitCount)
    LDataPack.writeChar(pack, #HuanShouBaseConfig)
    for id, conf in ipairs(HuanShouBaseConfig) do
        LDataPack.writeChar(pack, id)
        local huanshou = getHuanshouVar(var, id)
        LDataPack.writeChar(pack, huanshou.isFight)
        
        local equips = huanshou.equips
        LDataPack.writeChar(pack, #conf.equipIndex)
        for slot in ipairs(conf.equipIndex) do
            LDataPack.writeChar(pack, slot)
            local equip = equips[slot] or {}
            LDataPack.writeInt(pack, equip.id or 0)
            LDataPack.writeShort(pack, equip.lv or 0)
        end
        
        local commonSkills = var.fightPits[huanshou.pitId] or {}
        LDataPack.writeChar(pack, #commonSkillIndex)
        for index in ipairs(commonSkillIndex) do
            LDataPack.writeChar(pack, index)
            LDataPack.writeInt(pack, commonSkills[index] or 0)
        end
    end
    LDataPack.flush(pack)
end

--84-81 幻兽系统-请求出战/召回
local function c2sHSFight(actor, pack)
    local id = LDataPack.readChar(pack)
    local fight_type = LDataPack.readChar(pack)
    if fight_type == 1 then
        hsFight(actor, id)
    elseif fight_type == 2 then
        hsCancel(actor, id)
    end
end

--84-81 幻兽系统-更新单个幻兽信息
function s2cHSUpdate(actor, id)
    local huanshouConfig = HuanShouBaseConfig[id]
    if not huanshouConfig then return end
    
    local var = getActorVar(actor)
    if not var then return end
    local huanshou = getHuanshouVar(var, id)
    if not huanshou then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sHuanshou_Update)
    if not pack then return end
    
    local commonSkillIndex = HuanShouConstConfig.commonSkillIndex
    LDataPack.writeChar(pack, var.fightCount)
    LDataPack.writeChar(pack, id)
    LDataPack.writeChar(pack, huanshou.isFight)
    
    local equips = huanshou.equips
    LDataPack.writeChar(pack, #huanshouConfig.equipIndex)
    for slot in ipairs(huanshouConfig.equipIndex) do
        LDataPack.writeChar(pack, slot)
        local equip = equips[slot] or {}
        LDataPack.writeInt(pack, equip.id or 0)
        LDataPack.writeShort(pack, equip.lv or 0)
    end
    
    local commonSkills = var.fightPits[huanshou.pitId] or {}
    LDataPack.writeChar(pack, #commonSkillIndex)
    for index in ipairs(commonSkillIndex) do
        LDataPack.writeChar(pack, index)
        LDataPack.writeInt(pack, commonSkills[index] or 0)
    end
    LDataPack.flush(pack)
end

--84-82 幻兽系统-穿戴/替换/卸下装备
local function c2sHSEquipPut(actor, pack)
    local id = LDataPack.readChar(pack)
    local slot = LDataPack.readChar(pack)
    local uid = LDataPack.readDouble(pack)
    if uid > 0 then
        hsEquipPutOn(actor, id, slot, uid)
    else
        hsEquipPutOff(actor, id, slot)
    end
end

--84-82 幻兽系统-返回装备操作
function s2cHSEquipPut(actor, huanshouId, slot, equipId, equipLv)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sHuanshou_EquipPut)
    if not pack then return end
    
    LDataPack.writeChar(pack, huanshouId)
    LDataPack.writeChar(pack, slot)
    LDataPack.writeInt(pack, equipId)
    LDataPack.writeShort(pack, equipLv)
    LDataPack.flush(pack)
end

--84-83 幻兽系统-请求升级通用技能
local function c2sHSSkillUp(actor, pack)
    local id = LDataPack.readChar(pack)
    local index = LDataPack.readChar(pack)
    hsSkillUp(actor, id, index)
end

--84-83 幻兽系统-返回升级通用技能
function s2cHSSkillUp(actor, id, index, skillId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sHuanshou_SkillUp)
    if not pack then return end
    
    LDataPack.writeChar(pack, id)
    LDataPack.writeChar(pack, index)
    LDataPack.writeInt(pack, skillId)
    LDataPack.flush(pack)
end

--84-84 幻兽系统-一键强化
local function c2sHSEquipUpgrade(actor, pack)
    local id = LDataPack.readChar(pack)
    hsEquipUpgrade(actor, id)
end

--84-84 幻兽系统-更新单个幻兽装备
function s2cHSEquipUpgrade(actor, id)
    local huanshouConfig = HuanShouBaseConfig[id]
    if not huanshouConfig then return end
    
    local var = getActorVar(actor)
    if not var then return end
    local huanshou = getHuanshouVar(var, id)
    if not huanshou then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sHuanshou_EquipUpgrade)
    if not pack then return end
    
    LDataPack.writeChar(pack, id)
    
    local equips = huanshou.equips
    LDataPack.writeChar(pack, #huanshouConfig.equipIndex)
    for slot in ipairs(huanshouConfig.equipIndex) do
        LDataPack.writeChar(pack, slot)
        local equip = equips[slot] or {}
        LDataPack.writeInt(pack, equip.id or 0)
        LDataPack.writeShort(pack, equip.lv or 0)
    end
    LDataPack.flush(pack)
end

--84-85 幻兽系统-请求扩展出战数量
local function c2sHSExtend(actor, pack)
    hsExtend(actor)
end

--84-85 幻兽系统-更新最大出战数量
function s2cHSExtend(actor, count)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sHuanshou_Extend)
    if not pack then return end
    
    LDataPack.writeChar(pack, count)
    LDataPack.flush(pack)
end

--84-86 幻兽系统-请求合成装备
local function c2sHSEquipMake(actor, pack)
    local equipId = LDataPack.readInt(pack)
    local costItems = {}
    local count = LDataPack.readChar(pack)
    for i = 1, count do
        local uid = LDataPack.readDouble(pack)
        table.insert(costItems, uid)
    end
    hsEquipMake(actor, equipId, costItems)
end

--84-86 幻兽系统-返回合成装备
function s2cHSEquipMake(actor, equipId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sHuanshou_EquipMake)
    if not pack then return end
    
    LDataPack.writeInt(pack, equipId)
    LDataPack.flush(pack)
end

--84-87 幻兽系统-请求分解装备
local function c2sHSEquipResolve(actor, pack)
    local costItems = {}
    local count = LDataPack.readInt(pack)
    for i = 1, count do
        local uid = LDataPack.readDouble(pack)
        table.insert(costItems, uid)
    end
    hsEquipResolve(actor, costItems)
end

--84-87 幻兽系统-获得分解材料
function s2cHSEquipResolve(actor, id, count)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Play, Protocol.sHuanshou_EquipResolve)
    if not pack then return end
    
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, count)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function onInit(actor)
    calcAttr(actor, false)
end

local function onLogin(actor)
    checkHSFightCount(actor)
    checkHSFightPit(actor)
    s2cHSInfo(actor)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cHuanshou_Fight, c2sHSFight)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cHuanshou_EquipPut, c2sHSEquipPut)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cHuanshou_SkillUp, c2sHSSkillUp)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cHuanshou_EquipUpgrade, c2sHSEquipUpgrade)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cHuanshou_Extend, c2sHSExtend)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cHuanshou_EquipMake, c2sHSEquipMake)
    netmsgdispatcher.reg(Protocol.CMD_Play, Protocol.cHuanshou_EquipResolve, c2sHSEquipResolve)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.gmHSClear = function(actor, args)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    var.huanshou = nil
    s2cHSInfo(actor)
    return true
end

gmCmdHandlers.gmHSPrint = function(actor, args)
    local var = getActorVar(actor)
    print("var.fightCount =", var.fightCount)
    print("var.extendPitCount =", var.extendPitCount)
    print("*******huanshous*******")
    for id, conf in ipairs(HuanShouBaseConfig) do
        local huanshou = getHuanshouVar(var, id)
        print("===============")
        print("id =", id)
        print("isFight =", huanshou.isFight)
        print("pitId =", huanshou.pitId)
        local equips = huanshou.equips
        for slot = 1, 5 do
            local equip = equips[slot] or {}
            print(string.format("equip[%d] id=%d lv=%d", slot, equip.id or 0, equip.lv or 0))
        end
    end
    print("*******fightPits*******")
    for idx = 1, var.extendPitCount + HuanShouConstConfig.fightCount do
        local pit = var.fightPits[idx] or {}
        print("huanshouId = ", pit.huanshouId)
        print("skill[1] = ", pit[1])
        print("skill[2] = ", pit[2])
        print("skill[3] = ", pit[3])
        print("skill[4] = ", pit[4])
        print("skill[5] = ", pit[5])
    end
    return true
end

gmCmdHandlers.gmHSFight = function(actor, args)
    local id = tonumber(args[1])
    if not id then return end
    hsFight(actor, id)
    return true
end

gmCmdHandlers.gmHSCancel = function(actor, args)
    local id = tonumber(args[1])
    if not id then return end
    hsCancel(actor, id)
    return true
end

gmCmdHandlers.gmHSUpgrade = function(actor, args)
    local id = tonumber(args[1])
    if not id then return end
    hsEquipUpgrade(actor, id)
    return true
end

