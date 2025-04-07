-- @version	1.0
-- @author	youquan
-- @date	2018-06-22 
-- @system	翎羽系统

module( "feathersystem", package.seeall )


--获得用户翎羽数据
function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.feathersdata then
		var.feathersdata = {}
	end
	local feathersdata = var.feathersdata
	if not feathersdata.powers then feathersdata.powers = {} end
	return feathersdata
end

--获得角色翎羽数据
function setfeathersLevel(actor, roleId, slot, level)
	if not roleId or not slot then return end
	local var = getActorVar(actor)
	if not var then return end
	if not var[roleId] then
		var[roleId] = {}
	end
	var[roleId][slot] = level
end

function getfeathersLevel(actor, roleId, slot)
	if not roleId or not slot then return 0 end
	local level = 0
	local var = getActorVar(actor)
	if var[roleId] then
		level = var[roleId][slot] or 0
	end
	return level
end

function updatefeatherslevelinfo(actor, roleId, slot,euid)
	if not roleId or not slot or not euid then return end

	setfeathersLevel(actor, roleId, slot,FeathersEidMapPos[euid].level)
end

function Calcfeathersattr(actor, roleId)
	local addAttrs = {}
	local addlevel = nil --翎羽装备加成等级
	for slot, conf in pairs(FeathersAttrConfig) do
		local level = getfeathersLevel(actor, roleId, slot)
		if conf[level] and conf[level].attr then
			for k, v in pairs(conf[level].attr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
			end
		end

		addlevel = addlevel or level
		addlevel = ((addlevel > level) and level) or addlevel
	end

	return addAttrs,addlevel
end

function CalcfeathersAddWingattr(actor, roleId, addlevel, addAttrs)
	if not addlevel or not FeathersAddConfig[addlevel] or FeathersAddConfig[addlevel].addition <= 0 then return end
	
	local  wingAttrs = {}
	for idx=0, 1 do 
		local level, star, exp, status = LActor.getWingInfo(actor, roleId, idx)
		for _,tb in pairs(WingStarConfig[star].attr) do 
			wingAttrs[tb.type] = (wingAttrs[tb.type] or 0) + tb.value --加入翅膀的属性
		end
	end
	for k, v in pairs(wingAttrs) do 
			addAttrs[k] = (addAttrs[k] or 0) + v * FeathersAddConfig[addlevel].addition / 10000
	end
end

--更新属性
function updateAttr(actor, roleId, calc)
	local addAttrs ,addlevel = Calcfeathersattr(actor, roleId)

	CalcfeathersAddWingattr(actor, roleId, addlevel, addAttrs)

	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Feathers)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
		var.powers[roleId] = utils.getAttrPower0(addAttrs)
	end
end

--合成翎羽装备
function synthesisFeathers(actor, euid)
	if not euid then return end

	local conf = FeathersEidMapPos[euid]
	if not conf or not conf.posid or not conf.level then return end

	local posid = conf.posid
	local level = conf.level
	if not FeathersAttrConfig[posid] or not not FeathersAttrConfig[posid][level] or not FeathersAttrConfig[posid][level].item then return end


	if not actoritem.checkItems(actor, FeathersAttrConfig[posid][level].item) then return end 

	actoritem.reduceItems(actor, FeathersAttrConfig[posid][level].item, "Feathers synthesis cost")

	actoritem.addItem(actor, euid, 1, "Feathers synthesis add")

	local extra = string.format("synthesis equipid:%d",  euid)
	utils.logCounter(actor, "othersystem", "", extra, "Feathers", "synthesis")
end

--转换翎羽装备
function changeFeathers(actor, seuid, deuid)
	if not seuid or not deuid then return end
	if not (seuid == deuid) then return end

	local sconf = FeathersEidMapPos[seuid]
	if not sconf or not sconf.level then return end

	local dconf = FeathersEidMapPos[deuid]
	if not dconf or not dconf.level then return end

	if not (dconf.level == sconf.level) then return end

	if not FeathersChangeCost[dconf.level] or FeathersChangeCost[dconf.level].items then return end

	actoritem.reduceItems(actor, FeathersChangeCost[dconf.level].items, "Feathers change cost")

	actoritem.reduceItem(actor, seuid, 1, "Feathers change reduce")

	actoritem.addItem(actor, deuid, 1, "Feathers change add")

	local extra = string.format("change equipid:%d to equipid:%d",  seuid, deuid)
	utils.logCounter(actor, "othersystem", "", extra, "Feathers", "change")
end

-------------------------------------------------------------------------------------
--翎羽装备信息
function s2cFeathersInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sFeathersCmd_Info)
	if pack == nil then return end
	local count = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, count)
	for roleId = 0, count-1 do
		local ec = 0
		LDataPack.writeChar(pack, roleId)
		local pos = LDataPack.getPosition(pack)
		LDataPack.writeChar(pack, ec)
		for slot, v in pairs(FeathersAttrConfig) do
			local level = getfeathersLevel(actor, roleId, slot)
			LDataPack.writeChar(pack, slot)
			LDataPack.writeChar(pack, level)
			ec = ec + 1
		end
		local npos = LDataPack.getPosition(pack)
		LDataPack.setPosition(pack, pos)
		LDataPack.writeChar(pack, ec)
		LDataPack.setPosition(pack, npos)
	end
	LDataPack.flush(pack)
end

--翎羽合成
function c2ssynthesisFeathers(actor, packet)
	local flag = LDataPack.readByte(packet)
	if 0 == flag then
		local euid = LDataPack.readInt(packet)
		synthesisFeathers(actor,euid)
	elseif 1 == flag then
		local seuid = LDataPack.readInt(packet)
		local deuid = LDataPack.readInt(packet)
		changeFeathers(actor,seuid,deuid)
	end
end

---------------------------------------------------------------------------

local function onInit(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId, false)
	end
end

local function onLogin(actor)
	s2cFeathersInfo(actor)
end 

function onOpenRole(actor, roleId)
	s2cFeathersInfo(actor)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenRole, onOpenRole)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cFeathersCmd_Synthesis, c2ssynthesisFeathers)


