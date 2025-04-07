-- @version	1.0
-- @author	qianmeng
-- @date	2016-12-20 10:30:00
-- @system	神羽系统

module("shenyusystem", package.seeall)

require "wing.shenyulevel"
require "wing.shenyurank"
require "wing.shenyucommon"

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.shenyu then var.shenyu = {} end
	return var.shenyu
end

--创建一个神羽数据结构
function createShenyu(actor, roleId, idx, tp)
	local var = getActorVar(actor)
	if not var then return end
	if not var[roleId] then
		var[roleId] = {}
	end
	if not var[roleId][idx] then
		var[roleId][idx] = {}
	end
	if not var[roleId][idx][tp] then
		var[roleId][idx][tp] = {
			rank = 0,
			level = 0,
		}
	end
	return var[roleId][idx][tp]
end

--返回神羽的等级与阶级
function getShenyuInfo(actor, roleId, idx, tp)
	local rank = 0
	local level = 0
	local var = getActorVar(actor)
	if var[roleId] and var[roleId][idx] and var[roleId][idx][tp] then
		rank = var[roleId][idx][tp].rank
		level = var[roleId][idx][tp].level
	end
	return level, rank
end


--更新属性
function updateAttr(actor, roleId, calc)
	local addAttrs = {}
	local totalRank = 0

	--等级属性
	for tp = 1, ShenyuCommonConfig.maxTp do
		for idx = 0, 1 do
			local level, rank = getShenyuInfo(actor, roleId, idx, tp)
			if level > 0 then
				totalRank = totalRank + rank
				local conf = ShenyuLevelConfig[level]
				for k, v in pairs(conf.attrs[tp]) do
					addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
				end
			end
		end
	end

	--总阶级附加属性
	local rankAttr
	for k, v in ipairs(ShenyuRankConfig) do
		if totalRank >= v.rank then
			rankAttr = v.attr
		else
			break
		end
	end
	if rankAttr then
		for k, v in pairs(rankAttr) do
			addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Shenyu)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
	end
end

function getPower(actor)
	local attrList = {}
	local count = LActor.getRoleCount(actor)
	for roleId = 0, count-1 do
		local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Shenyu)
		for k, v in pairs(AttrPowerConfig) do
			local value = attr:Get(k)
			if value > 0 then
				attrList[k] = value
			end
		end
	end
	return utils.getAttrPower0(attrList)
end

--检查翅膀序号的正确性
local function checkIdx(actor, roleId, idx)
	if idx == 1 then 
		return true 
	elseif idx == 2 then 
		local role = LActor.getRole(actor, roleId)
		local job = LActor.getJob(role)
		return job > 3
	end
	return false
end

--设置神羽的等级
function setShenyuLevel(actor, roleId, idx, tp, level)
	local shenyu = createShenyu(actor, roleId, idx, tp)
	if not ShenyuLevelConfig[level] then return end
	shenyu.level = level
	local rank = math.floor(shenyu.level / ShenyuCommonConfig.stage)
	if rank > shenyu.rank then
		shenyu.rank = rank
	end
	updateAttr(actor, roleId, true)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sShenyuCmd_Update)
	if pack == nil then return end
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, idx+1) --翅膀序号返回客户端要+1
	LDataPack.writeChar(pack, tp)
	LDataPack.writeInt(pack, shenyu.rank)
	LDataPack.writeInt(pack, shenyu.level)
	LDataPack.flush(pack)
	
	utils.logCounter(actor, "shenyu", roleId, idx, tp, level)
end

---------------------------------------------------------------------------------------------------
--神羽信息
function s2cShenyuInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sShenyuCmd_Info)
	if pack == nil then return end
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count)
	for roleId = 0, count-1 do
		LDataPack.writeChar(pack, roleId)
		LDataPack.writeChar(pack, 2)
		for idx = 0, 1 do
			LDataPack.writeChar(pack, idx+1)
			LDataPack.writeChar(pack, ShenyuCommonConfig.maxTp)
			for tp = 1, ShenyuCommonConfig.maxTp do
				local level, rank = getShenyuInfo(actor, roleId, idx, tp)
				LDataPack.writeChar(pack, tp)
				LDataPack.writeInt(pack, rank)
				LDataPack.writeInt(pack, level)
			end
		end
	end
	LDataPack.flush(pack)
end

--神羽升级
function c2sShenyuUpdate(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local idx = LDataPack.readChar(packet) 
	local tp = LDataPack.readChar(packet) 
	if not utils.checkRoleId(actor, roleId) then return end
	if not checkIdx(actor, roleId, idx) then return end
	if tp < 0 or tp > ShenyuCommonConfig.maxTp then return end
	idx = idx - 1 --C++用的翅膀序号要减1

	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenyu) then return end --等级不足

	local level, rank = getShenyuInfo(actor, roleId, idx, tp)
	local conf = ShenyuLevelConfig[level]
	if not ShenyuLevelConfig[level+1] then return end
	if not actoritem.checkItems(actor, conf.items[tp]) then
		return
	end
	actoritem.reduceItems(actor, conf.items[tp], "shenyu up level:"..level..':'..rank)

	setShenyuLevel(actor, roleId, idx, tp, level+1)
end

local function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId, false)
	end
end

local function onLogin(actor)
	s2cShenyuInfo(actor)
end 

function onOpenRole(actor, roleId)
	s2cShenyuInfo(actor)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cShenyuCmd_Update, c2sShenyuUpdate)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.shenyulevel = function (actor, args)
	local tp = tonumber(args[1])
	local level = tonumber(args[2])
	setShenyuLevel(actor, 0, 1, tp, level)
	return true
end
