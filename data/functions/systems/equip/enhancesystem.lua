--强化系统
module( "enhancesystem", package.seeall )

local ENHANCE_ORDER = {0,2,3,4,8,1,6,7,5,9}

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.enhance then 
		var.enhance = {} 
		var.enhance.darenlv = 0
		var.enhance.dashilv = 0
		for i=0, EquipType_Max-1 do
			var.enhance[i] = {}
			var.enhance[i].level = 0
		end
	end
	return var.enhance
end

local function getEnhanceConfig(slot, level)
	if EnhanceAttrConfig[slot] then
		return EnhanceAttrConfig[slot][level]
	end
	return false
end

--更新属性
function updateAttr(actor, calc)
	local addAttrs = {}
	local var = getActorVar(actor)

	for i=0, EquipType_Max -1 do
		if var[i].level ~= 0 then
			for k, attr in pairs(EnhanceAttrConfig[i][var[i].level].attr) do
				addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
			end
		end
	end

	for k, v in pairs(addAttrs) do
		if k == Attribute.atAtk then
			addAttrs[k] = math.floor(addAttrs[k] * (1 + (EnhanceAddDaRenConfig[var.darenlv].atkper + EnhanceAddDaShiConfig[var.dashilv].atkper)/10000))
		elseif k == Attribute.atHpMax then
			addAttrs[k] = math.floor(addAttrs[k] * (1 + (EnhanceAddDaRenConfig[var.darenlv].hpper + EnhanceAddDaShiConfig[var.dashilv].hpper)/10000))
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Enhance)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end


--装备强化时
function onEquipEnhanceUpLevel(actor, slot, level)
	for i=1, #EquipConstConfig.enhancelevel do
		if level == EquipConstConfig.enhancelevel[i] then
			--发送强化公告
			local name = LActor.getActorName(LActor.getActorId(actor))
			local part = ItemConfig[equipsystem.getPutEquipId(actor, slot)].name
			--noticesystem.broadCastNotice(noticesystem.NTP.enhance, name, part, level) 
		end
	end
end
-------------------------------协议---------------------------------------------

function c2sEquipEnhance(actor, pack)
	local slot = LDataPack.readShort(pack)

	if not EnhanceAttrConfig[slot] then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.enhance) then return end
	local var = getActorVar(actor)
	local level = var[slot].level or 0
	local nextLevel = level + 1
	local costConfig = EnhanceCostConfig[level]
	if not EnhanceCostConfig[level+1] then return end
	if not equipsystem.checkPutEquip(actor, slot) then return end
	local var = getActorVar(actor)
	if not actoritem.checkItems(actor, costConfig.items) then
		return 
	end

	actoritem.reduceItems(actor, costConfig.items, "equip enhance:"..level)
	--等级是否改变
	if nextLevel ~= level then
		var[slot].level = nextLevel
		--更新属性
		updateAttr(actor, true)
	end
	actorevent.onEvent(actor, aeEnhanceEquip, slot, nextLevel)
	s2cEquipEnhance(actor, slot, nextLevel)
	--onEquipEnhanceUpLevel(actor, slot, nextLevel)
end

function s2cEquipEnhance(actor, slot, level)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_Enhance)
	if pack == nil then return end
	LDataPack.writeChar(pack, slot)
	LDataPack.writeShort(pack, level)
	LDataPack.flush(pack)

	--actorevent.onEvent(actor, aeEnhanceEquip, slot, level)
	local extra = string.format("slot:%d,level:%d", slot, level)
	utils.logCounter(actor, "othersystem", "", extra, "enhance", "up")
end

--求指定件数是
function getMinLevel(actor, count)
	local var = getActorVar(actor)
	local levels = {}
	for i=0, EquipType_Max-1 do
		levels[i+1] = var[i].level
	end
	table.sort(levels, function(a,b) return a > b end)
	return levels[count]
end

function c2sEnhanceOneKey(actor, pack)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.enhance) then return end----检查等级
	local var = getActorVar(actor)
	local minlv = 9999----角色装备最大等级
	local maxlv = 0----角色装备最小等级
	for i=0, EquipType_Max - 1 do----装备类型的最大值
		if equipsystem.checkPutEquip(actor, i) then
			if var[i].level > maxlv then
				maxlv = var[i].level
			end
			if var[i].level < minlv then
				minlv = var[i].level
			end
		end
	end---------minlv和maxlv设置成角色本身的
	local change = false
	if minlv == maxlv then
		for k = 1, #ENHANCE_ORDER do-- i=0, EquipType_Max - 1 do
			i = ENHANCE_ORDER[k]
			local level = var[i].level
			if equipsystem.checkPutEquip(actor, i) and level == minlv then
				if not EnhanceCostConfig[level+1] then break end
				if not actoritem.checkItems(actor, EnhanceCostConfig[level].items) then
					break 
				end
				change = true
				var[i].level = level + 1
				actoritem.reduceItems(actor, EnhanceCostConfig[level].items, "equip enhance:"..level)
				actorevent.onEvent(actor, aeEnhanceEquip, i, level + 1)
			end
		end
	end
	while(minlv < maxlv) do
		local isbreak = false
		for k = 1, #ENHANCE_ORDER do-- i=0, EquipType_Max - 1 do
			i = ENHANCE_ORDER[k]
			local level = var[i].level
			if equipsystem.checkPutEquip(actor, i) and level == minlv then----前面是检查装备是否穿上 
				if not EnhanceCostConfig[level+1] then--------这段是判断这个装备的等级是否是最高的 
					isbreak = true
					break
				end
				if not actoritem.checkItems(actor, EnhanceCostConfig[level].items) then
					isbreak = true
					break 
				end
				var[i].level = level + 1
				change = true
				actoritem.reduceItems(actor, EnhanceCostConfig[level].items, "equip enhance:"..level)-----------------------
				actorevent.onEvent(actor, aeEnhanceEquip, i, level + 1)
			end
		end
		minlv = minlv + 1
		if isbreak then
			break
		end
	end
	if change then
		updateAttr(actor, true)
		s2cEquipOneEnhance(actor)
	end
end

function s2cEquipOneEnhance(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_OnkeyEnhance)
	if pack == nil then return end
	local var = getActorVar(actor)
	for i=0, EquipType_Max - 1 do
		LDataPack.writeShort(pack, var[i].level)
	end	
	LDataPack.flush(pack)	
end

function c2sEnhanceStageUp(actor, pack)
	local type = LDataPack.readChar(pack)
	local var = getActorVar(actor)
	
	local curEnhanceLv = 0
	local conf
	local nextLevel = 0
	if type == 1 then
		conf = EnhanceAddDaRenConfig[var.darenlv]
		if not EnhanceAddDaRenConfig[var.darenlv + 1] then return end
		curEnhanceLv = getMinLevel(actor, EquipConstConfig.darencount)
		if curEnhanceLv < conf.needlevel then return end
		var.darenlv = var.darenlv + 1
		nextLevel = var.darenlv
	else
		conf = EnhanceAddDaShiConfig[var.dashilv]
		if not EnhanceAddDaShiConfig[var.dashilv + 1] then return end
		curEnhanceLv = getMinLevel(actor, EquipConstConfig.dashicount)
		if curEnhanceLv < conf.needlevel then return end
		var.dashilv = var.dashilv + 1
		nextLevel = var.dashilv
	end

	updateAttr(actor, true)
	
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_EnhanceStageUp)
	if pack == nil then return end
	local var = getActorVar(actor)
	LDataPack.writeChar(pack, type)
	LDataPack.writeChar(pack, nextLevel)
	LDataPack.flush(pack)	
end

function sendEnhanceList(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_EnhanceList)
	if pack == nil then return end
	local var = getActorVar(actor)
	LDataPack.writeChar(pack, var.darenlv)
	LDataPack.writeChar(pack, var.dashilv)
	for i=0, EquipType_Max-1 do
		LDataPack.writeShort(pack, var[i].level)
	end	
	LDataPack.flush(pack)	
end

function onLogin(actor)
    sendEnhanceList(actor)
end

function onInit(actor)
    updateAttr(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

local function init()
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_Enhance, c2sEquipEnhance)
	netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_EnhanceStageUp, c2sEnhanceStageUp)
	netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_OnkeyEnhance, c2sEnhanceOneKey)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.enhanceAll = function (actor, args)
    local IsChange = false
    local var = getActorVar(actor)
    for slot,conf in pairs(EnhanceAttrConfig) do
        local maxlevel = #conf
        if (var[slot].level or 0) < maxlevel then
            var[slot].level = maxlevel
            -- for i=1,maxlevel do
            -- 	actorevent.onEvent(actor, aeEnhanceEquip, slot, var[slot].level)
            -- end
            --这段代码太卡了
            IsChange = true
        end
    end
    maxlevel = #EnhanceAddDaRenConfig
    if (var.darenlv or 0) < maxlevel then
        var.darenlv = maxlevel
        IsChange = true
    end
    maxlevel = #EnhanceAddDaShiConfig
    if (var.dashilv or 0) < maxlevel then
        var.dashilv = maxlevel
        IsChange = true
    end

    if IsChange then
        onLogin(actor)
        updateAttr(actor, true)
    end
    return true
end
