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
	return var.plumedata
end

function setPlume(actor, level)
	local var = getActorVar(actor)
	if not var then return end
	var = level
	updateAttr(actor, true)
	s2cPlumeUpdate(actor, level)
	actorevent.onEvent(actor, aePlumeUp, level)
end

function getPlume(actor)
	local var = getActorVar(actor)
	if var and var then
		return var
	end
	return 0
end

function getVarPlume(var)
	if var and var then
		return var
	end
	return 0
end

--更新属性
function updateAttr(actor, calc)
	local addAttrs = {}
	local wingAttrs = {} --翅膀属性
	local level = 0 --总注灵等级
	local var = getActorVar(actor)

	local level = getVarPlume(var)
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
				local level, star, exp, status = LActor.getWingInfo(actor, idx)
				for _,tb in pairs(WingStarConfig[star].attr) do 
					wingAttrs[tb.type] = (wingAttrs[tb.type] or 0) + tb.value --加入翅膀的属性
				end
			end
			for k, v in pairs(wingAttrs) do 
				addAttrs[k] = (addAttrs[k] or 0) + v * rconf.addition / 10000
			end
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Plume)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcRoleAttr(actor)
	end
end

-------------------------------------------------------------------------------------
--注灵信息
function s2cPlumeInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sPlumeCmd_Info)
	if pack == nil then return end
	local var = getActorVar(actor)
	local lv = getVarPlume(var)
	LDataPack.writeShort(pack, lv)
	LDataPack.flush(pack)
end

--注灵升级
function c2sPlumeLevel(actor, packet)
	local level = getPlume(actor)
	local newLv = level + 1
	if not PlumeConfig[newLv] then return end
	local conf = PlumeConfig[level]
	if not conf then return end

	if not actoritem.checkItems(actor, conf.item) then --低级注灵不足
		return 
	end 
	actoritem.reduceItems(actor, conf.item, "plume level")
	
	setPlume(actor, newLv)

	local extra = string.format("role:%d,level:%d", newLv)
	utils.logCounter(actor, "othersystem", "", extra, "plume", "uplevel")
end

--注灵更新
function s2cPlumeUpdate(actor, level)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Old, Protocol.sPlumeCmd_Up)
	if pack == nil then return end
	LDataPack.writeShort(pack, level)
	LDataPack.flush(pack)
end

---------------------------------------------------------------------------

local function onInit(actor)
	updateAttr(actor, false)
end

local function onLogin(actor)
	s2cPlumeInfo(actor)
end 

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
netmsgdispatcher.reg(Protocol.CMD_Old, Protocol.cPlumeCmd_Up, c2sPlumeLevel)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.plumelevel = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sPlumeLevel(actor, pack)
end

gmCmdHandlers.plumeset = function (actor, args)
	local newLv = tonumber(args[2])
	setPlume(actor, newLv)
end

gmCmdHandlers.plumeclear = function (actor, args)
	local var = getActorVar(actor)
	var[0] = 0
	var[1] = 0
	var[2] = 0
end

gmCmdHandlers.plumeinfo = function (actor, args)
	local var = getActorVar(actor)
	local lv = getVarPlume(var)
	LDataPack.writeShort(pack, lv)
	utils.printInfo("plume", lv)
end
