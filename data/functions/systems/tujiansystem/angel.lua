-- @version	1.0
-- @author	qianmeng
-- @date	2017-5-22 14:22:47
-- @system	守护神系统

module("angel", package.seeall)
require("tujian.angelstar")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.angel then 
		var.angel = {} 
		var.angel.star = 0
	end
	return var.angel
end

--刷新属性
function updateAttr(actor, calc)
	local var = getActorVar(actor)
	if not var then return end
	local attrTable = AngelStarConfig[var.star].attr

	local attr = LActor.getActorSystemAttrs(actor, AttrActorSysId_Angel)
	attr:Reset()
	for k, v in pairs(attrTable) do
		attr:Set(v.type, v.value)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end
-------------------------------------------------------------------------------------------
--守护神信息
function c2sAngelInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_MiscAgreement, Protocol.sTujian_AngelInfo)
	if not pack then return end
	LDataPack.writeInt(pack, var.star)
	LDataPack.flush(pack)
end

--守护神升星
function c2sAngelStar(actor, packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.angel) then return end
	local var = getActorVar(actor)
	if not AngelStarConfig[var.star+1] then return end
	local conf = AngelStarConfig[var.star]
	if not actoritem.checkItems(actor, conf.items) then return end
	actoritem.reduceItems(actor, conf.items, "angel upstar")
	var.star = var.star + 1
	updateAttr(actor, true)
	c2sAngelInfo(actor)
	utils.logCounter(actor, "angel star", var.star)
end

function onLogin(actor)
	c2sAngelInfo(actor)
end

function onInit(actor)
	updateAttr(actor, false)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_MiscAgreement, Protocol.cTujian_AngelStar, c2sAngelStar)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.checkAngel = function (actor, args)
	c2sAngelStar(actor)
	return true
end
