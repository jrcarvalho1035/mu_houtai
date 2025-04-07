-- @装备精炼系统

module("purifysystem", package.seeall)

function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.purifydata then var.purifydata = {} end
    if not var.purifydata.darenlv then var.purifydata.darenlv = 0 end
    if not var.purifydata.dashilv then var.purifydata.dashilv = 0 end
    return var.purifydata
end

function setPurify(actor, slot, level)
    local var = getActorVar(actor)
    if not var then return end
    var[slot] = level
    updateAttr(actor, true)
end

function getPurify(actor, slot)
    local var = getActorVar(actor)
    if var and var[slot] then
        return var[slot]
    end
    return 0
end

function getVarPurify(var, slot)
    if var and var[slot] then
        return var[slot]
    end
    return 0
end

--精炼总星级
function getPurifyTotalLv(actor)
    local var = getActorVar(actor)
    local lv = 0
    for slot in pairs(EnhanceAttrConfig) do
        lv = lv + getVarPurify(var, slot)
    end
    return lv
end

local function getMinLevel(actor, count)
    local var = getActorVar(actor)
    local levels = {}
    for i=0, EquipType_Max-1 do
        levels[i+1] = var[i] or 0
    end
    table.sort(levels, function(a,b) return a > b end)
    return levels[count]
end

--更新属性
function updateAttr(actor, calc)
    local addAttrs = {}
    local var = getActorVar(actor)
    
    local maxLevel = 100 --所有部位等级
	local enhanceVar = enhancesystem.getActorVar(actor)
    local power = 0
	for slot=0, EquipType_Max -1 do
		local level = getVarPurify(var, slot)
		local conf = PurifyAttrConfig[slot][level]
		if conf then
			if enhanceVar[slot].level ~= 0 then
				for k, attr in pairs(EnhanceAttrConfig[slot][enhanceVar[slot].level].attr) do
					addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value * conf.plus / 10000
				end
			end
			local attrs = equipsystem.getPutEquipAttr(actor, slot)
			for __, v in ipairs(attrs) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * conf.plus / 10000
			end
			for __, v in ipairs(conf.addattr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
			end
		end			
		if level < maxLevel then
			maxLevel = level
		end
    end
    
    for k,v in ipairs(PurifyDaRenConfig[var.darenlv].addAttr) do
        addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
    end
    power = power + PurifyDaRenConfig[var.darenlv].power

    for k,v in ipairs(PurifyDaShiConfig[var.dashilv].addAttr) do
        addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
    end
    power = power + PurifyDaShiConfig[var.dashilv].power
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Purify)
    attr:Reset()
	for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    attr:SetExtraPower(power)
    if calc then
        LActor.reCalcRoleAttr(actor)
    end
end

-------------------------------------------------------------------------------------
--精炼信息
function s2cPurifyInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_PurifyInfo)
    if pack == nil then return end
    local var = getActorVar(actor)
    local slotcount = 0
    local slotpos = LDataPack.getPosition(pack)
    LDataPack.writeChar(pack, slotcount) --装备部位数量
    for slot, config in pairs(EnhanceAttrConfig) do
        local level = getVarPurify(var, slot)
        if level > 0 then
            LDataPack.writeChar(pack, slot) --装备部位
            LDataPack.writeShort(pack, level)--精炼等级
            slotcount = slotcount + 1
        end
    end
    if slotcount > 0 then
        local npos = LDataPack.getPosition(pack)
        LDataPack.setPosition(pack, slotpos)
        LDataPack.writeChar(pack, slotcount)
        LDataPack.setPosition(pack, npos)
    end
    LDataPack.writeShort(pack, var.darenlv)
    LDataPack.writeShort(pack, var.dashilv)
    LDataPack.flush(pack)
end

--精炼升级
function c2sPurifyLevel(actor, packet)
    local slot = LDataPack.readChar(packet)
    local tp = LDataPack.readChar(packet)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.purify) then return end
    if not equipsystem.checkPutEquip(actor, slot) then return end
    local level = getPurify(actor, slot)
    local nextLevel = level + 1
    local conf = PurifyAttrConfig[slot][level]
    if not PurifyAttrConfig[slot][level + 1] then return end --下一级的信息不存在（达到最高级）
    local cost = conf.cost[tp]
    if not cost then return end --没这个类型
    
    if not actoritem.checkItems(actor, cost.items) then
        return
    end
    actoritem.reduceItems(actor, cost.items, "purify level")
    
    --判断升级是否成功
    local ret = math.random(1, 10000) <= cost.rate
    if not ret then --失败
        local num = math.random(1, 10000)
        local count = 0
        for k, weight in pairs(conf.fail) do
            count = count + weight
            if count >= num then
                nextLevel = level - k --下降到几级
                break
            end
        end
    end
    
    setPurify(actor, slot, nextLevel)
    s2cPurifyUpdate(actor, ret, slot, nextLevel)
    actorevent.onEvent(actor, aePurifyEquip, 0)
    local extra = string.format("slot:%d,level:%d", slot, nextLevel)
    utils.logCounter(actor, "othersystem", "", extra, "purify", "uplevel")

    actorevent.onEvent(actor, aePurifyLevel, 1)
end

--精炼更新
function s2cPurifyUpdate(actor, ret, slot, nextLevel)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_PurifyUp)
    if pack == nil then return end
    LDataPack.writeByte(pack, ret and 1 or 0)
    LDataPack.writeChar(pack, slot)
    LDataPack.writeShort(pack, nextLevel)
    LDataPack.flush(pack)
end

function c2sPurifyStageUp(actor, pack)
	local type = LDataPack.readChar(pack)
	local var = getActorVar(actor)
	local curLv = 0
	local conf
	local nextLevel = 0
	if type == 1 then
		conf = PurifyDaRenConfig[var.darenlv]
		if not PurifyDaRenConfig[var.darenlv + 1] then return end
		curLv = getMinLevel(actor, EquipConstConfig.darencount)
		if curLv < conf.needlevel then return end
		var.darenlv = var.darenlv + 1
		nextLevel = var.darenlv
	else
		conf = PurifyDaShiConfig[var.dashilv]
		if not PurifyDaShiConfig[var.dashilv + 1] then return end
		curLv = getMinLevel(actor, EquipConstConfig.dashicount)
		if curLv < conf.needlevel then return end
		var.dashilv = var.dashilv + 1
		nextLevel = var.dashilv
	end
	updateAttr(actor, true)
	
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_PurifyStageUp)
	if pack == nil then return end
	local var = getActorVar(actor)
	LDataPack.writeChar(pack, type)
	LDataPack.writeShort(pack, nextLevel)
	LDataPack.flush(pack)	
end
---------------------------------------------------------------------------

local function onInit(actor)
    updateAttr(actor, false)
end

local function onLogin(actor)
    s2cPurifyInfo(actor)
end

local function onEquip(actor, slot)
    updateAttr(actor, true)
end

local function onEquipEnhance(actor, slot)
	updateAttr(actor, true)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aePutEquip, onEquip)
actorevent.reg(aeEnhanceEquip, onEquipEnhance)
netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_PurifyUp, c2sPurifyLevel)
netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_PurifyStageUp, c2sPurifyStageUp)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.purifylevel = function (actor, args)
    local pack = LDataPack.allocPacket()
    LDataPack.writeChar(pack, args[1])
    LDataPack.writeChar(pack, args[2])
    LDataPack.setPosition(pack, 0)
    c2sPurifyLevel(actor, pack)
end

gmCmdHandlers.purifyclean = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.purifydata = nil
    s2cPurifyInfo(actor)
end

gmCmdHandlers.purifyset = function (actor, args)
    local count = tonumber(args[1])
    local level = tonumber(args[2])
    local var = getActorVar(actor)
    for slot = 0, count - 1 do
        var[slot] = level
        actorevent.onEvent(actor, aePurifyEquip, 0)
    end
    updateAttr(actor, true)
    s2cPurifyInfo(actor)
    return true
end

gmCmdHandlers.purifyAll = function (actor, args)
    local level = #PurifyAttrConfig[0]
    local var = getActorVar(actor)
    for slot, conf in pairs(PurifyAttrConfig) do
        var[slot] = #conf
    end
    var.darenlv = #PurifyDaRenConfig
    var.dashilv = #PurifyDaShiConfig
    updateAttr(actor, true)
    s2cPurifyInfo(actor)
    return true
end

