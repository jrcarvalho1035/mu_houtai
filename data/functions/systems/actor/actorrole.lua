module("actorrole", package.seeall)
require("protocol")

--[装备部位] = 装备部位属性加成万分比
--例如：[武器部位] = 武器部位属性增加万分比
local SLOT_ATTRIBUTE = {
    [EquipType_Weapon] = Attribute.atWeaponPer,
    [EquipType_Helmet] = Attribute.atHelmetPer,
    [EquipType_Coat] = Attribute.atCoatPer,
    [EquipType_Hant] = Attribute.atHantPer,
    [EquipType_Pant] = Attribute.atPantPer,
    [EquipType_Shoe] = Attribute.atShoePer,
    [EquipType_Necklace] = Attribute.atNecklacePer,
    [EquipType_Ring] = Attribute.atRingPer,
    [EquipType_Talisman] = Attribute.atTalismanPer,
    [EquipType_Emblem] = Attribute.atEmblemPer,
}

--[装备总属性加成万分比] = 需要增加的属性类型
--例如：[装备攻击力万分比] = 攻击力附加
local EQUIP_ATTRIBUTE = {
    [Attribute.atEquipAtkPer] = Attribute.atAtk,
    [Attribute.atEquipHpPer] = Attribute.atHpMax,
    [Attribute.atEquipIgnoreDefPer] = Attribute.atIgnoreDef,
    [Attribute.atEquipDefPer] = Attribute.atDef,
    [Attribute.atEquipZMYJPer] = Attribute.atZMYJ,
    [Attribute.atEquipRefZMYJPer] = Attribute.atResZMYJ,
    [Attribute.atEquipAtkSucPer] = Attribute.atAtkSuc,
    [Attribute.atEquipDefSucPer] = Attribute.atDefSuc,
}

function getJobName(job)
    if JobConfig[job] then
        return JobConfig[job].name
    end
    return ""
end

_G.calcExtraAttr = function (actor)
    local baseAttrs = LActor.getRoleAttrsBasic(actor)
    local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_extra)
    attrs:Reset()
    
    local addAttrs = {}
    --各个装备部位的属性加成
    for slot, atType in pairs(SLOT_ATTRIBUTE) do
        local eAttrs = equipsystem.getPutEquipAttr(actor, slot)
        local exAttrPer = baseAttrs[atType] / 10000
        for _, v in ipairs(eAttrs) do
            addAttrs[v.type] = (addAttrs[v.type] or 0) + math.floor(v.value * exAttrPer)
        end
    end
    
    --装备总属性加成
    local eAttrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Equip)
    for atTypeEx, atType in pairs(EQUIP_ATTRIBUTE) do
        local exAttrPer = baseAttrs[atTypeEx] / 10000
        addAttrs[atType] = (addAttrs[atType] or 0) + math.floor(eAttrs[atType] * exAttrPer)
    end

    --按万分比增加魔灵装备属性
    local mlEquipAttrs = smequipsystem.getSMEquipAttrs(actor)
    local mlEquipPer = (baseAttrs[Attribute.atMLEquipPer] or 0) / 10000
    if mlEquipPer > 0 then
        for k,v in pairs(mlEquipAttrs) do
            addAttrs[k] = (addAttrs[k] or 0) + math.floor(v * mlEquipPer)
        end
    end
    
    for k, v in pairs(addAttrs) do
        attrs:Set(k, v)
    end
end

