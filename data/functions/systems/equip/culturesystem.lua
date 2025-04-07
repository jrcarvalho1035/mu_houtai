-- @system	装备培养

module( "culturesystem", package.seeall )

require("equip.cultureattr")
require("equip.culturepos")
require("equip.culturetype")

local function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var.culture then 
		var.culture = {}
		for i=0, EquipType_Max - 1 do
			var.culture[i] = {}
			var.culture[i].attr = {}
		end
	end
	return var.culture
end

local function getCultureAttrTp(posId, idx)
	if CulturePosConfig[posId] then
		return CulturePosConfig[posId].attr[idx]
	end
	return 0
end

function getPower(actor)
	local attrList = {}	
	for posId = 0, EquipSlotType_Max-1 do --10个装备部位
		local info = LActor.getCultureInfo(actor, 0, posId)
		if info then
			for idx, attr in pairs(info) do 
				local tp = getCultureAttrTp(posId, idx+1)
				attrList[tp] = (attrList[tp] or 0) + attr
			end
		end
	end	
	return utils.getAttrPower0(attrList)
end

--更新属性
function updateAttr(actor, calc)
	local addAttrs = {}
	local var = getActorVar(actor)

	for posId = 0, EquipSlotType_Max-1 do --10个装备部位
		for i=1, #CulturePosConfig[posId].attr do
			local equipid = equipsystem.getPutEquipId(actor, posId)		
			if (var[posId].attr[i] or 0) > 0 and ItemConfig[equipid] and ItemConfig[equipid].rank >= CulturePosConfig[posId].stage[i] then
				addAttrs[CulturePosConfig[posId].attr[i]] = (addAttrs[CulturePosConfig[posId].attr[i]] or 0) + (var[posId].attr[i] or 0)
			end
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Culture)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

local function getCultureAttrConfig(posId, stage)
	local tmp = 0
	for k, v in pairs(CultureAttrConfig[posId]) do
		if stage >= k and k > tmp then
			tmp = k
		end
	end
	return CultureAttrConfig[posId][tmp]
end

--计算每次增加的属性点
local function calcPoints(tpCon, attrCon, have)
	local n = tpCon.interval[1]
	local sum = tpCon.total --剩余分配点
	local ids = {}
	for idx = 0, 3 do
		local num = attrCon.limit[idx+1]-(have[idx+1] or 0)
		table.insert(ids, {idx=idx, num=num})
		sum = sum - math.min(n, num)
	end
	table.sort(ids, function(a,b) return a.num>b.num end) --排序出差值最大的
	local points = {n, n, n, n} --四个培养增加值，有默认最小值
	for k, v in ipairs(ids) do
		if sum <= 0 then break end
		local r = math.min(sum, tpCon.interval[2] - n)
		local value = System.getRandomNumber(r+1)
		points[v.idx+1] = points[v.idx+1] + value
		sum = sum - value
	end
	return points
end

-------------------------------协议---------------------------------------------

local function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var.culture then 
		var.culture = {}		
		for i=0, EquipType_Max - 1 do			
			var.culture[i] = {}
			var.culture[i].attr = {}
		end
	end
	return var.culture
end


--装备培养
function c2sEquipCulture(actor, packet)
	local posId = LDataPack.readShort(packet)
	local moneyTp = LDataPack.readShort(packet)
	local times = LDataPack.readShort(packet) --培养次数
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.culture) then return end

	local var = getActorVar(actor)
	local tpCon = CultureTypeConfig[moneyTp]
	if not tpCon then return end
	local posCon = CulturePosConfig[posId]
	if not posCon then return end

	local equipid = equipsystem.getPutEquipId(actor, posId)
	local attrCon = getCultureAttrConfig(posId, ItemConfig[equipid].rank)
	if not attrCon then return end
	--货币不足
	local items = {}
	for k, v in ipairs(tpCon.items) do
		table.insert(items, {type=v.type, id=v.id, count=v.count*times})
	end
	if (not actoritem.checkItem(actor, tpCon.money, tpCon.num*times)) or (not actoritem.checkItems(actor, items)) then
		return
	end
	--分次执行培养装备操作
	for i=1, times do		
		local points = calcPoints(tpCon, attrCon, var[posId].attr)
		local flag = true --培养点是否全满
		for k, value in ipairs(points) do
			value = math.min(value, attrCon.limit[k]-(var[posId].attr[k] or 0)) --满限制
			if value > 0 then --判断此项属性是否满
				flag = false
			end
		end
		if flag then --培养点全满
			break
		end
		actoritem.reduceItem(actor, tpCon.money, tpCon.num, "equip culture")
		actoritem.reduceItems(actor, tpCon.items, "equip culture")		
		for k, value in ipairs(points) do
			value = math.min(value, attrCon.limit[k]-(var[posId].attr[k] or 0)) --满限制
			if value > 0 then
				var[posId].attr[k] = (var[posId].attr[k] or 0) + value
			end
		end
	end

	s2cCultureAttrSave(actor, posId)
	updateAttr(actor, true)
	actorevent.onEvent(actor, aeCultureEquip, posId, times)
	--utils.logCounter(actor, "equip culture", posId)
end

--显示史诗属性
function s2cCultureAttrSave(actor, posId)
	local posCon = CulturePosConfig[posId]
	if not posCon then return end
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_CultureReturn)
	if pack == nil then return end
	LDataPack.writeChar(pack, posId)
	LDataPack.writeChar(pack, #posCon.attr)
	for idx = 1, #posCon.attr do
		LDataPack.writeShort(pack, posCon.attr[idx])
		LDataPack.writeInt(pack, var[posId].attr[idx] or 0)
	end
	LDataPack.flush(pack)
end


function sendCultureInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_CultureInfo)
	if pack == nil then return end
	LDataPack.writeChar(pack, EquipType_Max)
	for i=0, EquipType_Max - 1 do
		LDataPack.writeChar(pack, #CulturePosConfig[i].attr)
		for k,v in ipairs(CulturePosConfig[i].attr) do
			LDataPack.writeShort(pack, v)
			LDataPack.writeInt(pack, var[i].attr[k] or 0)
		end
	end
	LDataPack.flush(pack)	
end

function onLogin(actor)
    sendCultureInfo(actor)
end

function onInit(actor)
    updateAttr(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

local function init()
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_Culture, c2sEquipCulture)
end

table.insert(InitFnTable, init)


local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.cultureAll = function (actor, args)
	local var = getActorVar(actor)
	local CultureAttrConfig = CultureAttrConfig
	for slot,conf in pairs(CulturePosConfig) do
		local t_max = CultureAttrConfig[slot][#CultureAttrConfig[slot]].limit
		for pos in ipairs(conf.attr) do
			var[slot].attr[pos] = t_max[pos]
		end
		actorevent.onEvent(actor, aeCultureEquip, slot, 25400)
	end
	updateAttr(actor, true)
	onLogin(actor)
end
