-- @version	2.0
-- @author	qianmeng
-- @date	2018-2-2 11:17:57.
-- @system	圣物系统

module("shengwusystem", package.seeall )

require("equip.shengwuattr")
require("equip.shengwuextra")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.shengwudata then var.shengwudata = {} end
	return var.shengwudata
end

--更新属性
function updateAttr(actor, roleId, calc)
	local addAttrs = {}
	local role = LActor.getRole(actor,roleId)
	local var = getActorVar(actor)

	for tp, config in pairs(ShengwuAttrConfig) do
		local minLv = 1000 --该类型所有部位的最小等级
		for hold, conf in pairs(config) do
			local level = getVarShengwu(var, roleId, tp, hold)
			if level > 0 and conf[level] then
				for k, attr in pairs(conf[level].attr) do
					addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
				end
			end
			minLv = math.min(minLv, level)
		end

		if ShengwuExtraConfig[tp] then
			local match = 0
			for k, v in ipairs(ShengwuExtraConfig[tp]) do
				if minLv >= v.level then 
					match = v.idx 
				else
					break
				end
			end
			local extraConf = ShengwuExtraConfig[tp] and ShengwuExtraConfig[tp][match]
			if extraConf then
				for k, attr in pairs(extraConf.attr) do
					addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
				end
			end
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Shengwu)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
	end
end

function setShengwu(actor, roleId, tp, hold, level)
	local var = getActorVar(actor)
	if not var then return end
	if not var[roleId] then	
		var[roleId] = {}
	end
	if not var[roleId][tp] then
		var[roleId][tp] = {}
	end
	var[roleId][tp][hold] = level
	updateAttr(actor, roleId, true)
end

function getShengwu(actor, roleId, tp, hold)
	local var = getActorVar(actor)
	if var and var[roleId] and var[roleId][tp] and var[roleId][tp][hold] then
		return var[roleId][tp][hold]
	end
	return 0
end

function getVarShengwu(var, roleId, tp, hold)
	if var and var[roleId] and var[roleId][tp] and var[roleId][tp][hold] then
		return var[roleId][tp][hold]
	end
	return 0
end

-------------------------------------------------------------------------------------
--圣物信息
function s2cShengwuInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_ShengwuInfo)
	if pack == nil then return end
	local var = getActorVar(actor)
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count) --角色数量
	for roleId = 0, count-1 do
		LDataPack.writeChar(pack, roleId) --角色id
		local tpcount = 0 
		local tppos = LDataPack.getPosition(pack)
		LDataPack.writeChar(pack, tpcount) --类型数量
		for tp, v in pairs(ShengwuAttrConfig) do
			local flag = false 
			local holdcount = 0 
			local holdpos = 0
			for hold, v1 in pairs(v) do
				local lv = getVarShengwu(var, roleId, tp, hold)
				if lv > 0 then
					if not flag then --循环内只发第一次
						LDataPack.writeChar(pack, tp) --类型
						holdpos = LDataPack.getPosition(pack)
						LDataPack.writeChar(pack, holdcount) --圣物槽数量
						flag = true
					end
					holdcount = holdcount + 1
					LDataPack.writeChar(pack, hold) --槽位置
					LDataPack.writeShort(pack, lv)	--等级
				end
			end
			if holdcount > 0 then
				local npos = LDataPack.getPosition(pack)
				LDataPack.setPosition(pack, holdpos)
				LDataPack.writeChar(pack, holdcount)
				LDataPack.setPosition(pack, npos)
			end

			if flag then
				tpcount = tpcount + 1
			end
			
		end
		if tpcount > 0 then
			local npos = LDataPack.getPosition(pack)
			LDataPack.setPosition(pack, tppos)
			LDataPack.writeChar(pack, tpcount)
			LDataPack.setPosition(pack, npos)
		end
	end
	LDataPack.flush(pack)
end

--圣物升级
function c2sShengwuUp(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local tp = LDataPack.readChar(packet)
	local hold = LDataPack.readChar(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shengwu) then return end

	local lv = getShengwu(actor, roleId, tp, hold)
	local conf = ShengwuAttrConfig[tp] and ShengwuAttrConfig[tp][hold] 
	if(not conf) or (not conf[lv]) or (not conf[lv+1]) then return end

	if not (actoritem.checkItem(actor, NumericType_Gold, conf[lv].gold) and actoritem.checkItems(actor, conf[lv].items)) then
		return
	end
	actoritem.reduceItem(actor, NumericType_Gold, conf[lv].gold, "shengwu up")
	actoritem.reduceItems(actor, conf[lv].items, "shengwu up")

	local ret = math.random(1, 10000) <= conf[lv].rate --是否成功
	if ret then
		lv = lv + 1
		setShengwu(actor, roleId, tp, hold, lv)
	else
		actoritem.addItems(actor, conf[lv].restore, "shengwu restore", 2)
	end
	s2cShengwuUpdate(actor, ret, roleId, tp, hold, lv)

	local extra = string.format("role:%d,tp:%d,hold:%d,lv:%d",  roleId, tp, hold, lv)
	utils.logCounter(actor, "othersystem", "", extra, "shengwu", "uplevel")
end

--圣物更新
function s2cShengwuUpdate(actor, isSuc, roleId, tp, hold, newLv)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_EquipSlot, Protocol.sEquipSlotCmd_ShengwuUp)
	if pack == nil then return end
	LDataPack.writeByte(pack, isSuc and 1 or 0)
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, tp)
	LDataPack.writeChar(pack, hold)
	LDataPack.writeShort(pack, newLv)
	LDataPack.flush(pack)
end

---------------------------------------------------------------------------

local function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId, false)
	end
end

local function onLogin(actor)
	s2cShengwuInfo(actor)
end 

local function onOpenRole(actor, roleId)
	s2cShengwuInfo(actor)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
netmsgdispatcher.reg(Protocol.CMD_EquipSlot, Protocol.cEquipSlotCmd_ShengwuUp, c2sShengwuUp)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.shengwuup = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeChar(pack, args[2])
	LDataPack.writeChar(pack, args[3])
	LDataPack.setPosition(pack, 0)
	c2sShengwuUp(actor, pack)
	return true
end

gmCmdHandlers.shengwuclean = function (actor, args)
	local var = getActorVar(actor)
	var[0] = {}
	var[1] = {}
	var[2] = {}
	s2cShengwuInfo(actor)
	return true
end
