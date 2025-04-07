--套装系统
module( "suitsystem", package.seeall )

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.suit then var.suit = {} end
	for k, conf in pairs(SuitConfig) do
		if not var.suit[k] then
			var.suit[k] = {}
			var.suit[k].status = {}
			for j=0, EquipSlotType_Normal_Max - 1 do
				var.suit[k].status[j] = 0
			end
		end
	end
	return var.suit	
end

--更新属性
function updateAttr(actor, calc)
	local var = getActorVar(actor)
	local addAttrs = {}

	for suitid, conf in pairs(SuitConfig) do
		local count = 0
		for i=0, EquipSlotType_Normal_Max - 1 do
			if (var[suitid].status[i] or 0) > 0 then
				count = count + 1
			end			
		end
		if count > 0 then
			for k, v in pairs(conf.attrs[count+1]) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
			end
		end
		if count == EquipSlotType_Normal_Max then
			addAttrs[conf.skillattrs.type] = (addAttrs[conf.skillattrs.type] or 0) + conf.skillattrs.value
		end
	end
	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Suit)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

-------------------------------协议---------------------------------------------
--套装信息
function s2cSuitInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_SuitInfo)
	if pack == nil then return end
	local var = getActorVar(actor)
	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeChar(pack, count)
	for k, v in pairs(SuitConfig) do
		LDataPack.writeShort(pack, k)
		local ec = 0
		LDataPack.writeChar(pack, EquipSlotType_Normal_Max)
		for i=0, EquipSlotType_Normal_Max-1 do
			LDataPack.writeChar(pack, var[k].status[i] or 0)
		end
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
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.suit) then return end
	local suitid = LDataPack.readShort(pack)
	local slot = LDataPack.readChar(pack)
	if slot < 0 or slot > EquipSlotType_Normal_Max then return end
	
	if not SuitConfig[suitid] then return end

	local var = getActorVar(actor)
	if var[suitid].status[slot] ~= 0 then return end
	local conf = ItemConfig[equipsystem.getPutEquipId(actor, slot)]
	if not conf then return end
	if conf.quality < SuitConfig[suitid].condition.quality or conf.rank < SuitConfig[suitid].condition.rank or conf.star < SuitConfig[suitid].condition.star then
		return
	end
	var[suitid].status[slot] = 1
	updateAttr(actor, true) --更新属性
	equipsystem.updateAttr(actor, true)
	--给前端回包
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_SuitUp)
	if pack == nil then return end
	LDataPack.writeShort(pack, suitid)
	LDataPack.writeChar(pack, slot)
	LDataPack.writeChar(pack, var[suitid].status[slot])
	LDataPack.flush(pack)

	local count = 0
	for i=0, EquipSlotType_Normal_Max - 1 do
		if (var[suitid].status[i] or 0) > 0 then
			count = count + 1
			if count == 8 then
				actorevent.onEvent(actor, aeSuitActive, suitid)
			end
		end			
	end	
end

local function onInit(actor)
	updateAttr(actor, false)
end

local function onLogin(actor)
	s2cSuitInfo(actor)
end 

local function init()
	actorevent.reg(aeInit, onInit, 1)
	actorevent.reg(aeUserLogin, onLogin)

	if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_SuitUp, c2sEquipSuitUp)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.suitAll = function (actor, args)
    local var = getActorVar(actor)
    for suitid, conf in pairs(SuitConfig) do
        for slot = 0, EquipSlotType_Normal_Max - 1 do
            var[suitid].status[slot] = 1
        end
        actorevent.onEvent(actor, aeSuitActive, suitid)
    end
    updateAttr(actor, true)
    onLogin(actor)
end
