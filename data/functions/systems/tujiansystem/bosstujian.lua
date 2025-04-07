--boss图鉴系统
module("bosstujian", package.seeall)
require("tujian.bosstujian")
require("tujian.bossseries")
require("tujian.seriesattr")
require("tujian.tujianresolve")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.bosstujiandata then var.bosstujiandata = {} end
	return var.bosstujiandata
end

function setBosstujian(actor, id, lv)
	local var = getActorVar(actor)
	if not var then return end
	var[id] = lv
	updateAttr(actor, true)
end

function getBosstujian(actor, id)
	local var = getActorVar(actor)
	if var and var[id] then
		return var[id]
	end
	return -1
end

function getVarBosstujian(var, id, slot)
	if var and var[id] then
		return var[id]
	end
	return -1
end

--更新属性
function updateAttr(actor, calc)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.tujian) then return end
	local addAttrs = {}
	local var = getActorVar(actor)
	for id, config in pairs(BossTujianConfig) do
		local lv = getVarBosstujian(var, id)
		local conf = config[lv]
		for k, v in pairs(conf.attr) do
			addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
		end
	end

	for k, v in pairs(BossSeriesConfig) do
		local count = 0
		for k1, id in pairs(v.groups) do
			local lv = getVarBosstujian(var, id)
			if lv > -1 then
				count = count + 1
			end
		end
		for i = #SeriesAttrConfig[k], 1, -1 do
			if count >= SeriesAttrConfig[k][i].number then
				for k, v in pairs(SeriesAttrConfig[k][i].attr) do
					addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
				end
				break
			end
		end
	end

	local attr = LActor.getActorSystemAttrs(actor, AttrActorSysId_Bosstujian)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

-------------------------------------------------------------------------------------
--Boss图鉴信息
function s2cBosstujianInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_MiscAgreement, Protocol.sBossTujian_Info)
	if pack == nil then return end
	local var = getActorVar(actor)
	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, count) 
	for id, config in pairs(BossTujianConfig) do
		local lv = getVarBosstujian(var, id)
		if lv > -1 then
			LDataPack.writeInt(pack, id)
			LDataPack.writeShort(pack, lv)
			count = count + 1
		end
	end
	if count > 0 then
		local npos = LDataPack.getPosition(pack)
		LDataPack.setPosition(pack, pos)
		LDataPack.writeChar(pack, count)
		LDataPack.setPosition(pack, npos)
	end
	LDataPack.flush(pack)
end

--Boss图鉴升星
function c2sBosstujianLevel(actor, packet)
	local id = LDataPack.readInt(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.tujian) then print("#### 1") return end
	local config = BossTujianConfig[id]
	if not config then print("#### 2", id) return end
	local lv = getBosstujian(actor, id)
	if not config[lv+1] then print("#### 3") return end
	local conf = config[lv]
	if not actoritem.checkItems(actor, conf.items) then
		print("#### 4")
		return
	end
	actoritem.reduceItems(actor, conf.items, "bosstujian level")
	setBosstujian(actor, id, lv+1)
	updateAttr(actor, true)
	s2cBosstujianUpdate(actor, id, lv+1)
end

--Boss图鉴更新
function s2cBosstujianUpdate(actor, id, lv)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_MiscAgreement, Protocol.sBossTujian_Up)
	if pack == nil then return end
	LDataPack.writeInt(pack, id)
	LDataPack.writeShort(pack, lv)
	LDataPack.flush(pack)
end

--Boss图鉴分解
function c2sBosstujianResolve(actor, packet)
	local id = LDataPack.readInt(packet)
	local count = 1 --LActor.getItemCount(actor, id)
	local conf = TujianResolveConfig[id]
	if not conf then return end
	if not actoritem.checkItem(actor, id, count) then --要回收的图鉴数目不对应
		print("#### 1")
		return
	end
	actoritem.reduceItem(actor, id, count, "bosstujian resolve")

	actoritem.addItem(actor, NumericType_Spar, conf.value * count, "bosstujian resolve")

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_MiscAgreement, Protocol.sBossTujian_Resolve)
	if pack == nil then return end
	LDataPack.writeInt(pack, id)
	LDataPack.flush(pack)
end
---------------------------------------------------------------------------

local function onInit(actor)
	updateAttr(actor, false)
end

local function onLogin(actor)
	s2cBosstujianInfo(actor)
end 

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_MiscAgreement, Protocol.cBossTujian_Up, c2sBosstujianLevel)
netmsgdispatcher.reg(Protocol.CMD_MiscAgreement, Protocol.cBossTujian_Resolve, c2sBosstujianResolve)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.bosstujianlevel = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sBosstujianLevel(actor, pack)
	return true
end

gmCmdHandlers.bosstujianresolve = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sBosstujianResolve(actor, pack)
	return true
end

gmCmdHandlers.bosstujianclean = function (actor, args)
	local var = getActorVar(actor)
	for id, config in pairs(BossTujianConfig) do
		var[id] = nil
	end
	s2cBosstujianInfo(actor)
	return true 
end
