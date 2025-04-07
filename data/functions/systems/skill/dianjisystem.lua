-- @version	2.0
-- @author	qianmeng
-- @date	2018-1-12 17:58:45.
-- @system	技能典籍系统

module("dianjisystem", package.seeall )

require("skill.dianji")
require("skill.dianjislot")
require("skill.dianjichange")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.dianjidata then var.dianjidata = {} end
	return var.dianjidata
end

function setDianjiId(actor, roleId, slot, id)
	local var = getActorVar(actor)
	if not var then return end
	if not var[roleId] then	
		var[roleId] = {}
	end
	var[roleId][slot] = id
end

function getDianjiId(actor, roleId, slot)
	local var = getActorVar(actor)
	if var and var[roleId] then
		return var[roleId][slot] or 0
	end
	return 0
end

function getVarDianjiId(var, roleId, slot)
	if var and var[roleId] then
		return var[roleId][slot] or 0
	end
	return 0
end

--更新属性
function updateAttr(actor, roleId, calc)
	local addAttrs = {}
	local role = LActor.getRole(actor,roleId)
	local var = getActorVar(actor)
	local extraPower = 0
	local dianjis = {} --习得的典籍
	for slot, v in ipairs(DianjiSlotConfig) do
		local id = getVarDianjiId(var, roleId, slot)
		local conf = DianjiConfig[id]
		if conf then
			dianjis[id] = true
		end
	end
	for k, v in pairs(dianjis) do
		local conf = DianjiConfig[k]
		if not dianjis[conf.high] then
			for k, attr in pairs(conf.attr) do
				addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
			end
			extraPower = extraPower + conf.extra
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Dianji)
	attr:Reset()
	attr:SetExtraPower(extraPower)
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
	end
end

-------------------------------------------------------------------------------------
--技能典籍信息
function s2cDianjiInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_DianjiInfo)
	if pack == nil then return end
	local var = getActorVar(actor)
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count) --角色数量
	for roleId = 0, count-1 do
		LDataPack.writeChar(pack, roleId) --角色id
		local slotcount = 0
		local slotpos = LDataPack.getPosition(pack)
		LDataPack.writeChar(pack, slotcount) --槽数量
		for slot, config in ipairs(DianjiSlotConfig) do
			local id = getVarDianjiId(var, roleId, slot)
			if id > 0 then
				LDataPack.writeChar(pack, slot) --槽位
				LDataPack.writeInt(pack, id)
				slotcount = slotcount + 1
			end
		end
		if slotcount > 0 then
			local npos = LDataPack.getPosition(pack)
			LDataPack.setPosition(pack, slotpos)
			LDataPack.writeChar(pack, slotcount)
			LDataPack.setPosition(pack, npos)
		end
	end
	LDataPack.flush(pack)
end

--技能典籍学习
function c2sDianjiLearn(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local dianjiId = LDataPack.readInt(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.dianji) then return end
	if not utils.checkRoleId(actor, roleId) then return end
	if not DianjiConfig[dianjiId] then return end
	local tp = DianjiConfig[dianjiId].type
	local level = LActor.getLevel(actor)
	local vip = LActor.getVipLevel(actor)

	local sum = 0
	local tmp = {}
	local var = getActorVar(actor)
	for k, conf in ipairs(DianjiSlotConfig) do
		if level < conf.level and vip < conf.viplevel then --等级与vip限制
			break
		end
		local id = getVarDianjiId(var, roleId, k)
		local dconf = DianjiConfig[id]
		if not dconf then --空槽
			table.insert(tmp, {k, conf.pro[tp]})
			sum = sum + conf.pro[tp]
			break
		elseif dconf.type == 1 then
			table.insert(tmp, {k, conf.pro1[tp]})
			sum = sum + conf.pro1[tp]
		elseif dconf.type == 2 then
			table.insert(tmp, {k, conf.pro2[tp]})
			sum = sum + conf.pro2[tp]
		end
		if id == dianjiId or dconf.ban == dianjiId then --学后禁学技能
			return
		end
	end
	local slot = 1
	if sum <= 0 then return end --没可装的槽
	local r = math.random(1, sum)
	for k, v in ipairs(tmp) do
		if r <= v[2] then 
			slot = v[1]
			break
		else
			r = r - v[2]
		end
	end

	if not actoritem.checkItem(actor, dianjiId, 1) then
		return
	end
	actoritem.reduceItem(actor, dianjiId, 1, "dianji learn")
	setDianjiId(actor, roleId, slot, dianjiId)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_DianjiLearn)
	if pack == nil then return end
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, slot)
	LDataPack.writeInt(pack, dianjiId)
	LDataPack.flush(pack)

	local extra = string.format("role:%d,slot:%d,id:%d",  roleId, slot, dianjiId)
	utils.logCounter(actor, "othersystem", "", extra, "dianji", "learn")
end

--技能典籍特效播完
function c2sDianjiFinish(actor, packet)
	local roleId = LDataPack.readChar(packet)
	updateAttr(actor, roleId, true)
end

--技能典籍转换
function c2sDianjiChange(actor, packet)
	local items = {}
	local number = 0
	local count = LDataPack.readChar(packet)
	if count < #DianjiChangeConfig then return end
	for i=1, count do
		local id = LDataPack.readInt(packet)
		table.insert(items, {type=1, id=id, count=1})
		local conf = DianjiConfig[id]
		if not conf then return end
		if conf.type == 2 then
			number = number + 1
		end
	end
	local conf = DianjiChangeConfig[number]
	if not conf then return end
	if not actoritem.checkItems(actor, items) then
		return
	end
	actoritem.reduceItems(actor, items, "dianji change")
	local rewards = drop.dropGroup(conf.dropId)
	actoritem.addItems(actor, rewards, "dianji change")
	local id = 0
	local _, item = next(rewards) 
	if item then id = item.id end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_DianjiChange)
	if pack == nil then return end
	LDataPack.writeInt(pack, id)
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
	s2cDianjiInfo(actor)
end 

local function onOpenRole(actor, roleId)
	s2cDianjiInfo(actor)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_DianjiLearn, c2sDianjiLearn)
netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_DianjiChange, c2sDianjiChange)
netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_DianjiFinish, c2sDianjiFinish)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.dianjilearn = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.writeInt(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sDianjiLearn(actor, pack)
end

gmCmdHandlers.dianjichange = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, 3)
	LDataPack.writeInt(pack, args[1])
	LDataPack.writeInt(pack, args[2])
	LDataPack.writeInt(pack, args[3])
	LDataPack.setPosition(pack, 0)
	c2sDianjiChange(actor, pack)
end

gmCmdHandlers.dianjiclean = function (actor, args)
	local var = getActorVar(actor)
	var[0] = {}
	var[1] = {}
	var[2] = {}
	s2cDianjiInfo(actor)
end

gmCmdHandlers.dianjiset = function (actor, args)
	local roleId = tonumber(args[1])
	local slot = tonumber(args[2])
	local dianjiId = tonumber(args[3])
	setDianjiId(actor, roleId, slot, dianjiId)
	updateAttr(actor, roleId, true)
	s2cDianjiInfo(actor)
end
