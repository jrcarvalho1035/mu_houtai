-- @version	1.0
-- @author	qianmeng
-- @date	2017-8-29 15:41:32.
-- @system	梅林秘语

module( "secretsystem", package.seeall )
require("merlin.secretskill")

local secretAttr = {Attribute.atEasyHurt, Attribute.atBreakArmor, Attribute.atDeceleration, Attribute.atPoisoning}

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.secretdata then var.secretdata = {} end
	if not var.secretdata.powers then var.secretdata.powers = {} end
	return var.secretdata
end

function createSecret(actor, roleId)
	local var = getActorVar(actor)
	if not var then return end
	if not var[roleId] then	
		var[roleId] = {
			atts = {},
			curId = 0,
		} 
		for k, v in ipairs(SecretskillConfig) do
			var[roleId].atts[k] = BookCommonConfig[1].minVal
		end
	end
	return var[roleId]
end

function getSecretInfo(actor, roleId)
	local var = getActorVar(actor)
	if not var then return end
	if var[roleId] then
		return var[roleId].curId, var[roleId].atts
	end
	return 0, {}
end

function getSecretAttr(actor, roleId)
	local var = getActorVar(actor)
	if not var then return 0, 0 end
	local curId = 0
	local value = 0
	if var[roleId] then
		curId = var[roleId].curId
		value = var[roleId].atts[curId] or 0
		local star, rank = booksystem.getBookInfo(actor, roleId)
		value = (value + BookRankConfig[rank].extraSecret) * 100
	end
	return curId, value
end

local function isOpenSystem(actor)
	if actorexp.checkLevelCondition(actor, actorexp.LimitTp.merlin) then 
		return true
	end
	return false
end

function updateAttr(actor, roleId, calc)
	local curId, atts = getSecretInfo(actor, roleId)
	if secretAttr[curId] then
		local star, rank = booksystem.getBookInfo(actor, roleId)
		local extra = BookRankConfig[rank].extraSecret --梅林之书附加概率
		local value = (atts[curId]+extra) * 100 --百分比转换成万分比
		local role = LActor.getRole(actor,roleId)

		local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Secret)
		attr:Reset()
		attr:Set(secretAttr[curId], value)
		if calc then
			LActor.reCalcRoleAttr(actor, roleId)
			local var = getActorVar(actor)
			var.powers[roleId] = utils.getAttrPower({{type=secretAttr[curId], value=value}})
			booksystem.updateRankingList(actor, getPower(actor)+booksystem.getPower(actor)) --记入梅林排行榜
		end
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

---------------------------------------------------------------------------------
--梅林秘语信息
function s2cSecretInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Merlin, Protocol.sSecret_Info)
	if pack == nil then return end
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count)
	for roleId = 0, count-1 do
		local curId, atts = getSecretInfo(actor, roleId)
		LDataPack.writeChar(pack, #SecretskillConfig)
		for k, v in ipairs(SecretskillConfig) do
			LDataPack.writeDouble(pack, atts[k] or BookCommonConfig[1].minVal)
		end
		LDataPack.writeChar(pack, curId)
	end
	LDataPack.flush(pack)
end

--梅林秘语使用
function c2sSecretUse(actor, packet)
	if not isOpenSystem(actor) then return end
	local roleId = LDataPack.readChar(packet)
	local id = LDataPack.readChar(packet)
	if not SecretskillConfig[id] then return end
	local star, rank = booksystem.getBookInfo(actor, roleId)
	if rank <= 0 then return end

	local data = createSecret(actor, roleId)
	data.curId = id
	updateAttr(actor, roleId, true)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Merlin, Protocol.sSecret_Use)
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, data.curId)
	LDataPack.flush(pack)
	actorevent.onEvent(actor, aeMerlinSecretUp, data.curId)
end

--梅林秘语提升
function c2sSecretPromote(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local tp = LDataPack.readChar(packet)
	local id = LDataPack.readChar(packet)
	local conf = SecretskillConfig[id]
	if not conf then return end
	if not conf.value[tp] then return end
	local star, rank = booksystem.getBookInfo(actor, roleId)
	if rank <= 0 then return end
	local data = createSecret(actor, roleId)
	if data.atts[id] >= BookCommonConfig[1].maxVal then
		return
	end

	local cost = conf['cost'..tp]
	if not actoritem.checkItems(actor, cost) then
		return
	end
	actoritem.reduceItems(actor, cost, "secret up")

	local val = (data.atts[id] or 0) + conf.value[tp]
	val = math.min(BookCommonConfig[1].maxVal, val)
	data.atts[id] = val

	updateAttr(actor, roleId, true)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Merlin, Protocol.sSecret_Promote)
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, data.curId)
	LDataPack.writeDouble(pack, data.atts[id])
	LDataPack.flush(pack)
	actorevent.onEvent(actor, aeMerlinSecretUp, data.curId)
end

local function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId, false)
	end
end

local function onLogin(actor)
	if isOpenSystem(actor) then
		s2cSecretInfo(actor)
	end
end

local function onCreateRole(actor, roleId)
	if isOpenSystem(actor) then
		s2cSecretInfo(actor)
	end
end

local function onLevelUp(actor, level, oldLevel)
	local lv = actorexp.getLimitLevel(actor,actorexp.LimitTp.merlin)
	if lv > oldLevel and lv <= level then
		s2cSecretInfo(actor)
	end
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeCreateRole,onCreateRole)
actorevent.reg(aeLevel, onLevelUp)
netmsgdispatcher.reg(Protocol.CMD_Merlin, Protocol.cSecret_Use, c2sSecretUse)
netmsgdispatcher.reg(Protocol.CMD_Merlin, Protocol.cSecret_Promote, c2sSecretPromote)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.secretinfo = function (actor, args)
	s2cSecretInfo(actor)
end

gmCmdHandlers.secretuse = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeChar(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sSecretUse(actor, pack)
end

gmCmdHandlers.secretpromote = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeChar(pack, args[2])
	LDataPack.writeChar(pack, args[3])
	LDataPack.setPosition(pack, 0)
	c2sSecretPromote(actor, pack)
end

gmCmdHandlers.secretset = function (actor, args)
	local roleId = tonumber(args[1])
	local id = tonumber(args[2])
	local val = tonumber(args[3])
	local data = createSecret(actor, roleId)
	data.atts[id] = val
	s2cSecretInfo(actor)
end
