--圣戒系统
module("starsoul", package.seeall)

local starsoulLevelConfig = StarsoulLevelConfig --等级配置
local starsoulStageConfig = StarsoulStageConfig --等阶配置
local netmsgdispatcher = netmsgdispatcher

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.starsoul then var.starsoul = {} end
	if not var.starsoul.starlevel then var.starsoul.starlevel = 0 end --魔戒等级
	if not var.starsoul.soulevel then var.starsoul.soulevel = 0 end --魔戒之魂等阶
	return var.starsoul
end

local function starsoulDataSync(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Starsoul, Protocol.sStarsoulCmd_DataSync)
	if pack == nil then return end
	local var = getActorVar(actor)
	LDataPack.writeInt(pack, var.soulevel)
	LDataPack.writeInt(pack, var.starlevel)	
	LDataPack.flush(pack)	
end

local function addStarsoulAttr(actor, roleId)
	local stage, level = LActor.getStarsoulInfo(actor, roleId)
	if (not stage or level < 0) then
		return
	end

	--先把等级和阶级的属性汇总
	local attrList = {}

	local levelConfig = starsoulLevelConfig[level]
	if (levelConfig) then
		for _,tb in pairs(levelConfig.attr) do
			LActor.addStarsoulAttr(actor, roleId, tb.type, tb.value)
		end
	end
end

local function updateAttr(actor, calc)
	local var = getActorVar(actor)
	local addAttrs = {}
	local levelConfig = starsoulLevelConfig[var.starlevel]
	for _,v in pairs(levelConfig.attr) do
		addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
		if v.type == Attribute.atAtk or v.type == Attribute.atAtkMin or v.type == Attribute.atAtkMax then
			addAttrs[v.type] = math.floor(addAttrs[v.type] * (1 + StarsoulStageConfig[var.soulevel].atkper/10000))
		elseif v.type == Attribute.atHpMax then
			addAttrs[v.type] = math.floor(addAttrs[v.type] * (1 + StarsoulStageConfig[var.soulevel].hpper/10000))
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_StarSoul)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

---------------------------------------------------------------------------------------------------
--处理星魂升级请求
local function c2sStarsoulLevelup(actor, pack)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.starsoul) then return end

	--星魂等级
	local var = getActorVar(actor)

	--检查是否有下一等级信息
	local next_level = var.starlevel + 1
	if not starsoulLevelConfig[next_level] then return end

	--检查是否等级已满
	if (var.starlevel >= StarsoulCommonConfig.max_level) then return end

	--检查数值是否足够
	local levelConfig = starsoulLevelConfig[var.starlevel]
	if not levelConfig then return end
	if levelConfig.needLv > LActor.getLevel(actor) then --等级不足
		return
	end

	if not actoritem.checkItem(actor, levelConfig.itemId, levelConfig.count) then
		return
	end
	actoritem.reduceItem(actor, levelConfig.itemId, levelConfig.count, "starsoul star up")
	var.starlevel = var.starlevel + 1	

	updateAttr(actor, true)
	actorevent.onEvent(actor, aeStarsoulUpStage, starsoulLevelConfig[next_level].rank)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Starsoul, Protocol.sStarsoulCmd_StarLevelUp)
	LDataPack.writeInt(pack, var.starlevel)
	LDataPack.flush(pack)	

	utils.logCounter(actor, "starsoul level", next_level)
end

--魔戒之魂升阶
function c2sStarsoulSoulup(actor, pack)	
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.starsoul) then return end
	--星魂等级，等阶
	local var = getActorVar(actor)
	local conf = StarsoulStageConfig[var.soulevel]

	if not StarsoulStageConfig[var.soulevel + 1] then
		return
	end
	if conf.needstar > var.starlevel then
		return
	end

	var.soulevel = var.soulevel + 1
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Starsoul, Protocol.sStarsoulCmd_SoulLevelUp)
	LDataPack.writeInt(pack, var.soulevel)
	LDataPack.flush(pack)	

	
	updateAttr(actor, true)
	utils.logCounter(actor, "starsoul stage", var.soulevel)
end

function onInit(actor)
	updateAttr(actor, false)
end

--玩家登陆回调
function onLogin(actor)
	starsoulDataSync(actor) --发送星魂数据
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Starsoul, Protocol.cStarsoulCmd_StarLevelUp, c2sStarsoulLevelup)
netmsgdispatcher.reg(Protocol.CMD_Starsoul, Protocol.cStarsoulCmd_SoulLevelUp, c2sStarsoulSoulup)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.setstarsoullevel = function (actor, args)
	local level = tonumber(args[1])
	local roleId = tonumber(args[2] or 0)

	if not starsoulLevelConfig[level] then return end
	LActor.setStarsoulLevel(actor, roleId, level)
	local stage = math.modf(level / StarsoulCommonConfig.level_per_stage)
	LActor.setStarsoulStage(actor, roleId, stage)
	updateAttr(actor, roleId)
	starsoulDataSync(actor, roleId)
	return true
end

gmCmdHandlers.starsoulAll = function (actor, args)
	local IsChange = false
	local var = getActorVar(actor)
	local maxlevel = #starsoulLevelConfig
	if (var.starlevel or 0) < maxlevel then
		var.starlevel = maxlevel
		actorevent.onEvent(actor, aeStarsoulUpStage, starsoulLevelConfig[var.starlevel].rank)
		IsChange = true
	end
	maxlevel = #StarsoulStageConfig
	if (var.soulevel or 0) < maxlevel then
		var.soulevel = maxlevel
		IsChange = true
	end
	if IsChange then
		updateAttr(actor, true)
		onLogin(actor)
	end
end
