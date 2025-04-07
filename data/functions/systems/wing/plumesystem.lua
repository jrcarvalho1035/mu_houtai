-- @version	1.0
-- @author	qianmeng
-- @date	2017-12-1 16:05:46.
-- @system	翅膀注灵系统

module( "plumesystem", package.seeall )

require("wing.plume")
require("wing.plumeadd")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.plumedata then var.plumedata = {} end
	if not var.plumedata.powers then var.plumedata.powers = {} end
	return var.plumedata
end

function setPlume(actor, roleId, level)
	local var = getActorVar(actor)
	if not var then return end
	var[roleId] = level
	updateAttr(actor, roleId, true)
	s2cPlumeUpdate(actor, roleId, level)
	actorevent.onEvent(actor, aePlumeUp, level)
end

function getPlume(actor, roleId)
	local var = getActorVar(actor)
	if var and var[roleId] then
		return var[roleId]
	end
	return 0
end

function getVarPlume(var, roleId)
	if var and var[roleId] then
		return var[roleId]
	end
	return 0
end

--更新属性
function updateAttr(actor, roleId, calc)
	local addAttrs = {}
	local wingAttrs = {} --翅膀属性
	local level = 0 --总注灵等级
	local role = LActor.getRole(actor,roleId)
	local var = getActorVar(actor)

	local level = getVarPlume(var, roleId)
	local conf = PlumeConfig[level]
	if level > 0 and conf then
		for k, attr in pairs(conf.attr) do
			addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
			wingAttrs[attr.type] = (wingAttrs[attr.type] or 0) + attr.value --加成的属性包括翅膀属性与注灵属性
		end
		--全属性加成的附加
		local rconf = PlumeAddConfig[conf.rank]
		if rconf.addition > 0 then
			for idx=0, 1 do 
				local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
				for _,tb in pairs(WingStarConfig[star].attr) do 
					wingAttrs[tb.type] = (wingAttrs[tb.type] or 0) + tb.value --加入翅膀的属性
				end
			end
			for k, v in pairs(wingAttrs) do 
				addAttrs[k] = (addAttrs[k] or 0) + v * rconf.addition / 10000
			end
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Plume)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
		var.powers[roleId] = utils.getAttrPower0(addAttrs)
	end
end

function getPower(actor)
	local var = getActorVar(actor)
	if not var then return 0 end
	local power = 0
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		power = power + (var.powers[roleId] or 0)
	end
	return power
end
_G.getPlumePower = getPower

-------------------------------------------------------------------------------------
--注灵信息
function s2cPlumeInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sPlumeCmd_Info)
	if pack == nil then return end
	local var = getActorVar(actor)
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count)
	for roleId = 0, count-1 do
		LDataPack.writeChar(pack, roleId)
		local lv = getVarPlume(var, roleId)
		LDataPack.writeShort(pack, lv)
	end
	LDataPack.flush(pack)
end

--注灵升级
function c2sPlumeLevel(actor, packet)
	local roleId = LDataPack.readChar(packet)

	local level = getPlume(actor, roleId)
	local newLv = level + 1
	if not PlumeConfig[newLv] then return end
	local conf = PlumeConfig[level]
	if not conf then return end
	local wingLv = LActor.getWingInfo(actor, roleId, 0) --翅膀的等阶
	if not wingLv then return end --没有这个角色
	if wingLv < conf.limit then return end

	if not actoritem.checkItems(actor, conf.item) then --低级注灵不足
		return 
	end 
	actoritem.reduceItems(actor, conf.item, "plume level")
	
	setPlume(actor, roleId, newLv)

	local extra = string.format("role:%d,level:%d",  roleId, newLv)
	utils.logCounter(actor, "othersystem", "", extra, "plume", "uplevel")
end

--注灵更新
function s2cPlumeUpdate(actor, roleId, level)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sPlumeCmd_Up)
	if pack == nil then return end
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeShort(pack, level)
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
	s2cPlumeInfo(actor)
end 

function onOpenRole(actor, roleId)
	s2cPlumeInfo(actor)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cPlumeCmd_Up, c2sPlumeLevel)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.plumelevel = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sPlumeLevel(actor, pack)
end

gmCmdHandlers.plumeset = function (actor, args)
	local roleId = tonumber(args[1])
	local newLv = tonumber(args[2])

	setPlume(actor, roleId, newLv)
end

gmCmdHandlers.plumeclear = function (actor, args)
	local var = getActorVar(actor)
	var[0] = 0
	var[1] = 0
	var[2] = 0
end

gmCmdHandlers.plumeinfo = function (actor, args)
	local var = getActorVar(actor)
	for roleId = 0, 2 do
		LDataPack.writeChar(pack, roleId)
		local lv = getVarPlume(var, roleId)
		LDataPack.writeShort(pack, lv)
		utils.printInfo("plume", lv)
	end
end
