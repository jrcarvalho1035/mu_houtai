--图鉴系统
module("tujian", package.seeall)
require("tujian.tujianrecover")
require("tujian.monstertujianconfig")
require("tujian.sceneconfig")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end

	if not var.tujian then var.tujian = {} end
	if not var.tujian.monster then var.tujian.monster = {} end	--按位读
	if not var.tujian.scene then var.tujian.scene = {} end
	if var.tujian.scene == 0 then 
		var.tujian.scene = {} 
	end
	return var.tujian
end

--刷新属性
function updateTujianAttr(actor, calc)
	local var = getActorVar(actor)
	if not var then return end

	local attrTable = {}
	for monTujianId, conf in pairs(MonsterTujianConfig) do
		if var.monster[monTujianId] == 1 then
			for _, attrConf in pairs(conf.attr) do
				attrTable[attrConf.type] = (attrTable[attrConf.type] or 0) + attrConf.value
			end
		end
	end 
	for sceneId, conf in pairs(SceneTujianConfig) do
		if var.scene[sceneId] == 1 then
			for _, attrConf in pairs(conf.attr) do
				attrTable[attrConf.type] = (attrTable[attrConf.type] or 0) + attrConf.value
			end
		end
	end

	local attr = LActor.getActorSystemAttrs(actor, AttrActorSysId_Tujian)
	attr:Reset()
	for k, v in pairs(attrTable) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

function onInit(actor)
	updateTujianAttr(actor, false)
end

function onLogin(actor)
	sendTujianInfo(actor)
end

-----------------------------------------------------------------------------------------------------------
function sendTujianInfo(actor)
	local var = getActorVar(actor)
	if not var then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_MiscAgreement, Protocol.sTujian_Info)
	if not pack then return end
	LDataPack.writeInt(pack, #MonsterTujianConfig)
	for i = 1, #MonsterTujianConfig do
		LDataPack.writeByte(pack, var.monster[i] or 0)
	end
	LDataPack.writeInt(pack, #SceneTujianConfig)
	for i = 1, #SceneTujianConfig do
		LDataPack.writeByte(pack, var.scene[i] or 0)
	end
	LDataPack.flush(pack)
end

--激活怪物图鉴
function activateMonster(actor, packet)
	local monTujianId = LDataPack.readInt(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.tujian) then return end

	local conf = MonsterTujianConfig[monTujianId]
	if not conf then return end

	local var = getActorVar(actor)
	if not var then return end

	if not actoritem.checkItem(actor, conf.needItem, conf.needCount) then
		return
	end
	actoritem.reduceItem(actor, conf.needItem, conf.needCount, "tujian active")
	var.monster[monTujianId] = 1 --激活图鉴

	--检查是否可以激活场景图鉴
	local sceneId
	for idx, conf in pairs(SceneTujianConfig) do
		for _, monsterId in pairs(conf.needMonsters) do
			if monsterId == monTujianId then
				sceneId = idx
				break
			end
		end
		if sceneId then break end
	end
	if not sceneId then return end

	local flag = true
	if (var.scene[sceneId] or 0) == 0 then
		for _, monId in pairs(SceneTujianConfig[sceneId].needMonsters) do
			if (var.monster[monId] or 0) == 0 then
				flag = false
				break
			end
		end
	end
	if flag then
		var.scene[sceneId] = 1 --激活场景
	end

	updateTujianAttr(actor, true)
	sendTujianInfo(actor)

	actorevent.onEvent(actor, aeTujianActive, 1, monTujianId)
	utils.logCounter(actor, "tujian active", monTujianId)
end

--回收图鉴
function c2sTujianRecover(actor, packet)
	local count = LDataPack.readShort(packet)
	local items = {}
	for i=1, count do
		local id = LDataPack.readInt(packet)
		local num = LDataPack.readInt(packet)
		table.insert(items, {id=id, count=num})
	end

	if not actoritem.checkItems(actor, items) then --要回收的图鉴数目不对应
		return
	end

	actoritem.reduceItems(actor, items, "tujian recover")
	local sum = 0
	for k, v in pairs(items) do
		sum = sum + TujianRecoverConfig[v.id].guard * v.count
	end
	actoritem.addItem(actor, NumericType_Guard, sum, "recover tujian")
end


actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_MiscAgreement, Protocol.cTujian_activate, activateMonster)
netmsgdispatcher.reg(Protocol.CMD_MiscAgreement, Protocol.cTujian_Recover, c2sTujianRecover)

--local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.checkTujian = function (actor, args)
	-- activateMonster(actor, tonumber(args[1]))
end
