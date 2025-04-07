-- @system	装备追加

module( "appendsystem", package.seeall)

local APPEND_ORDER = {0,2,3,4,8,1,6,7,5,9}

local function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var.append then 
		var.append = {}
		var.append.level = {}
		for i=0, EquipType_Max - 1 do
			var.append.level[i] = 0
		end
		var.append.yuanshi = {}
		for i=1, #AppendYuanShiConfig do
			var.append.yuanshi[i] = 0
		end
	end
	return var.append
end

--求指定件数是
function getMinLevel(actor, count)
	local var = getActorVar(actor)
	local levels = {}
	for i=0, EquipType_Max-1 do
		levels[i+1] = var.level[i]
	end
	table.sort(levels, function(a,b) return a > b end)
	return levels[count]
end

--更新属性
function updateAttr(actor, calc)
	local addAttrs = {}
	local var = getActorVar(actor)

	for i=0, EquipType_Max -1 do		
		if var.level[i] ~= 0 then
			for k, attr in pairs(AppendAttrConfig[i][var.level[i]].attr) do
				addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
			end			
		end				
	end
	
	local per = 0
	for i=1, #AppendYuanShiConfig do
		for k, attr in pairs(AppendYuanShiConfig[i].attr) do
			if attr.type == Attribute.atAppendPer then
				per = per + attr.value * var.yuanshi[i]				
			end
		end
	end

	for k,v in ipairs(addAttrs) do
		addAttrs[k] = math.floor(addAttrs[k] * (1 + per/10000))
	end

	for i=1, #AppendYuanShiConfig do
		for k, attr in pairs(AppendYuanShiConfig[i].attr) do
			addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value * var.yuanshi[i]
		end
	end	

	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Append)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

-------------------------------协议---------------------------------------------
function c2sAppend(actor, slot)
	local var = getActorVar(actor)
	if not AppendCostConfig[var.level[slot]+1] then return end
	if not actoritem.checkItems(actor, AppendCostConfig[var.level[slot]].items) then return end
	var.level[slot] = var.level[slot] + 1

	actoritem.reduceItems(actor, AppendCostConfig[var.level[slot]].items, "equip append:"..var.level[slot])
	updateAttr(actor, true)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_AppendOneKey)
	if pack == nil then return end
	LDataPack.writeChar(pack, 1)
	LDataPack.writeChar(pack, slot)
	LDataPack.writeShort(pack, var.level[slot])	
	LDataPack.flush(pack)	
	actorevent.onEvent(actor, aeAppendEquip, slot, var.level[slot])
end


function c2sAppendOneKey(actor, pack)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.append) then return end
	local type = LDataPack.readChar(pack)
	if type == 1 then
		local slot = LDataPack.readChar(pack)
		c2sAppend(actor, slot)
		return 
	end
	local var = getActorVar(actor)
	local minlv = 9999
	local maxlv = 0
	
	for i=0, EquipType_Max - 1 do
		if equipsystem.checkPutEquip(actor, i) then
			if var.level[i] > maxlv then
				maxlv = var.level[i]
			end
			if var.level[i] < minlv then
				minlv = var.level[i]
			end
		end
	end
	local change = false
	if minlv == maxlv then
		for k = 1, #APPEND_ORDER do-- i=0, EquipType_Max - 1 do
			i = APPEND_ORDER[k]
			local level = var.level[i]
			if equipsystem.checkPutEquip(actor, i) and level == minlv then
				if not AppendCostConfig[level+1] then break end
				if not actoritem.checkItems(actor, AppendCostConfig[level].items) then
					break 
				end
				change = true
				var.level[i] = level + 1
				actoritem.reduceItems(actor, AppendCostConfig[level].items, "equip append:"..level)
				actorevent.onEvent(actor, aeAppendEquip, i, level + 1)
			end
		end
	end
	while(minlv < maxlv) do
		local isbreak = false
		for k = 1, #APPEND_ORDER do-- i=0, EquipType_Max - 1 do
			i = APPEND_ORDER[k]
			local level = var.level[i]
			if equipsystem.checkPutEquip(actor, i) and level == minlv then
				if not AppendCostConfig[level+1] then 
					isbreak = true
					break
				end
				if not actoritem.checkItems(actor, AppendCostConfig[level].items) then
					isbreak = true
					break 
				end
				var.level[i] = level + 1
				change = true
				actoritem.reduceItems(actor, AppendCostConfig[level].items, "equip append:"..level)
				actorevent.onEvent(actor, aeAppendEquip, i, level + 1)
			end
		end
		minlv = minlv + 1
		if isbreak then
			break
		end
	end
	if change then
		updateAttr(actor, true)
		s2cOneKeyInfo(actor)
	end
end

--源石升级
function c2sAppendYuanshi(actor, pack)
	local index = LDataPack.readInt(pack)
	if not AppendYuanShiConfig[index] then return end
	local var = getActorVar(actor)
	local maxindex = 0
	local conf = AppendYuanShiConfig[index].condition
	-- for k,v in ipairs(conf) do
	-- 	if var.yuanshi[index] < v[3] then
	-- 		maxindex = k
	-- 		break
	-- 	end
	-- end
	--if maxindex == 0 or maxindex > #conf then return end

	--if minlevel < conf[maxindex][2] then return end
	-- for k,v in ipairs(conf) do
	-- 	if minlevel < v[2] then
	-- 		maxindex = k - 1
	-- 		break
	-- 	elseif minlevel == v[2] then
	-- 		maxindex = k
	-- 		break
	-- 	end
	-- end
	local minlevel = getMinLevel(actor, conf[1][1])
	for idx,v in ipairs(conf) do
		if minlevel >= v[2] then
			maxindex = idx
		else
			break
		end
	end
	if maxindex <= 0 then return end
	if var.yuanshi[index] >= conf[maxindex][3] then return end
	
	local count = actoritem.getItemCount(actor, AppendYuanShiConfig[index].itemid)
	local usecount = math.min(count, conf[maxindex][3]-var.yuanshi[index])

	if not actoritem.checkItem(actor, AppendYuanShiConfig[index].itemid, usecount) then
		return
	end

	var.yuanshi[index] = var.yuanshi[index] + usecount
	actoritem.reduceItem(actor, AppendYuanShiConfig[index].itemid, usecount, "equip append yuanshi")
	updateAttr(actor, true)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_AppendYuanshi)
	if pack == nil then return end
	LDataPack.writeInt(pack, index)
	LDataPack.writeInt(pack, var.yuanshi[index])
	LDataPack.flush(pack)	
end

function s2cOneKeyInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_AppendOneKey)
	if pack == nil then return end
	LDataPack.writeChar(pack, EquipType_Max)
	for i=0, EquipType_Max - 1 do
		LDataPack.writeChar(pack, i)
		LDataPack.writeShort(pack, var.level[i])
	end
	LDataPack.flush(pack)	
end

--追加信息
function sendAppendInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_AppendInfo)
	if pack == nil then return end
	LDataPack.writeInt(pack, EquipType_Max)
	for i=0, EquipType_Max - 1 do
		LDataPack.writeInt(pack, var.level[i])
	end
	LDataPack.writeInt(pack, #AppendYuanShiConfig)
	for i=1, #AppendYuanShiConfig do
		LDataPack.writeInt(pack, var.yuanshi[i])
	end
	LDataPack.flush(pack)	
end

function onLogin(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.append) then return end
    sendAppendInfo(actor)
end

function onInit(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.append) then return end
    updateAttr(actor)
end

function onCustomChange(actor, custom, oldcustom)
	if LimitConfig[actorexp.LimitTp.append].custom > oldcustom and LimitConfig[actorexp.LimitTp.append].custom <= custom then
        sendAppendInfo(actor)
    end
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

local function init()
	--if System.isBattleSrv() then return end
	if System.isLianFuSrv() then return end
	actorevent.reg(aeCustomChange, onCustomChange)
	netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_AppendOneKey, c2sAppendOneKey)
	netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_AppendYuanshi, c2sAppendYuanshi)	
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.appendAll = function (actor, args)
    local var = getActorVar(actor)
    local AppendAttrConfig = AppendAttrConfig
    for slot = 0, EquipType_Max - 1 do
        local maxlevel = #AppendAttrConfig[slot]
        var.level[slot] = maxlevel
        -- for i=1,maxlevel do
        -- 	actorevent.onEvent(actor, aeAppendEquip, slot, var.level[slot])
        -- end
        --这段代码太卡
    end
    for index, conf in pairs(AppendYuanShiConfig) do
        local maxlevel = conf.condition[#conf.condition][3]
        var.yuanshi[index] = maxlevel
    end
    updateAttr(actor, true)
    onLogin(actor)
    return true
end
