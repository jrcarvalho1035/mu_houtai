module("damonsystem", package.seeall)

--精灵数据获取
function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var.damon then 
		var.damon = {}
		var.damon.level = 0
		var.damon.levelexp = 0
		var.damon.stage = 0
		var.damon.stageexp = 0
		var.damon.huanhua = {}
		var.damon.pilluse = {}
		var.damon.mozhen = {}
		var.damon.damonchoose = 0 --当前选择的精灵
		var.damon.mozhenchoose = 0 --当前选择的魔阵
		var.damon.power = 0
	end
	return var.damon
end

function getLevel(actor)
	local var = getActorVar(actor)
	return var.level
end

function getStage(actor)
	local var = getActorVar(actor)
	return var.stage
end

function getPower(actor)
	local var = getActorVar(actor)
	return var.power
end

function updateAttr(actor, isCalc)
    local var = getActorVar(actor)
	local addAttrs = {}
	local power = 0
	for k,v in ipairs(DamonStageConfig[var.stage].baseAttrs) do
        addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
    end

	for k,v in pairs(DamonHuanhuaBaseConfig) do
		local level = var.huanhua[k] or 0
		if level > 0 then
	        for kk,vv in ipairs(v.baseAttrs) do
	            addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * level
	        end
	    end
    end

    for k,v in ipairs(DamonPillConfig) do
        for kk,vv in ipairs(v.baseAttrs) do
            addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * (var.pilluse[k] or 0)
        end
    end

	for k,v in ipairs(DamonMozhenBaseConfig) do
		local level = var.mozhen[k] or 0
		if level > 0 then
			for __,vv in ipairs(v.baseAttrs) do
				addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * level
			end
		end
	end
	
	for k,v in ipairs(DamonConstConfig.levelskills) do
		local conf = SkillPassiveConfig[v][passiveskill.getSkillLv(actor, v)]
		if conf.type == 1 then
			for k,v in ipairs(conf.addattr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value                
			end			
		end
		power = power + conf.power
	end

	for k,v in ipairs(DamonConstConfig.stageskills) do
		local conf = SkillPassiveConfig[v][passiveskill.getSkillLv(actor, v)]
		if conf.type == 1 then
			for k,v in ipairs(conf.addattr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value                
			end			
		end
		power = power + conf.power
	end

	local add = addAttrs[Attribute.atDamonTotal] or 0
	if (var.level or 0) > 0 then
		for k,v in ipairs(DamonLevelConfig[var.level].baseAttrs) do
			addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * (1+add/10000)
		end
	end

    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Damon)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
	end
	attr:SetExtraPower(power)
    if isCalc then
		LActor.reCalcAttr(actor)	
		if System.isCommSrv() then
			var.power = utils.getAttrPower0(addAttrs) + power
			utils.rankfunc.updateRankingList(actor, var.power, RankingType_Damon)
			actorevent.onEvent(actor, aeChangeRankPower, var.power, subactivity4.minType.damon)
		end	
	end	
end

function sendTotalInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_JLData)
	LDataPack.writeInt(pack, var.damonchoose)
	LDataPack.writeInt(pack, var.mozhenchoose)
	LDataPack.writeShort(pack, var.level)
	LDataPack.writeInt(pack, var.levelexp)
	LDataPack.writeShort(pack, var.stage)
	LDataPack.writeInt(pack, var.stageexp)

	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, count)
	for k,v in pairs(DamonHuanhuaBaseConfig) do
		LDataPack.writeInt(pack, k)
		LDataPack.writeInt(pack, var.huanhua[k] or 0)
		count = count + 1
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeInt(pack, count)
	LDataPack.setPosition(pack, npos)
	
	LDataPack.writeInt(pack, #DamonPillConfig)
	for i=1, #DamonPillConfig do
		LDataPack.writeInt(pack, i)
        LDataPack.writeInt(pack, var.pilluse[i] or 0)
	end
	count = 0
	pos = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, count)
	for k,v in ipairs(DamonMozhenBaseConfig) do
		LDataPack.writeInt(pack, k)
		LDataPack.writeInt(pack, var.mozhen[k] or 0)
		count = count + 1
	end
	npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeInt(pack, count)
	LDataPack.setPosition(pack, npos)
	
    LDataPack.flush(pack)
end

--精灵升级
function levelUp(actor)
	local var = getActorVar(actor)
	if not DamonLevelConfig[var.level + 1] then
		return
	end
	local count = actoritem.getItemCount(actor, DamonConstConfig.levelitemid)
	if count <= 0 then
		return
	end
	count = math.min(count, math.ceil((DamonLevelConfig[var.level].needexp - var.levelexp)/DamonConstConfig.leveladdexp))
	actoritem.reduceItem(actor, DamonConstConfig.levelitemid, count, "damon level up")

	var.levelexp = var.levelexp + DamonConstConfig.leveladdexp * count
	
	if var.levelexp >= DamonLevelConfig[var.level].needexp then
		var.levelexp = var.levelexp - DamonLevelConfig[var.level].needexp
		var.level = var.level + 1
	end	
	
	updateAttr(actor, true)
	actorevent.onEvent(actor, aeDamonLevel, var.level, count)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_JLLevelUpRet)
	LDataPack.writeShort(pack, var.level)
	LDataPack.writeInt(pack, var.levelexp)
    LDataPack.flush(pack)
end

--精灵进阶
function stageUp(actor)
	local var = getActorVar(actor)
	if not DamonStageConfig[var.stage + 1] then
		return
	end
	local count = actoritem.getItemCount(actor, DamonConstConfig.stageitemid)
	if count <= 0 then
		return
	end
	local conf = DamonStageConfig[var.stage]
	count = math.min(count, math.ceil((conf.needexp - var.stageexp)/DamonConstConfig.stageaddexp))
	actoritem.reduceItem(actor, DamonConstConfig.stageitemid, count, "damon stage up")

	var.stageexp = var.stageexp + DamonConstConfig.stageaddexp * count
	if var.stageexp >= conf.needexp then
		var.stageexp = var.stageexp - conf.needexp
		var.stage = var.stage + 1
	end	
	
	updateAttr(actor, true)
	actorevent.onEvent(actor, aeDamonStage, var.stage, count)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_JLStageUpRet)
	LDataPack.writeShort(pack, var.stage)
	LDataPack.writeInt(pack, var.stageexp)
	LDataPack.flush(pack)
	if DamonStageConfig[var.stage].stage > conf.stage then
		var.damonchoose = DamonStageConfig[var.stage].stage
		sendChoose(actor)
		LActor.setDamon(actor, var.damonchoose, var.mozhenchoose)
		actorevent.onEvent(actor, aeFacadeActive, 1, DamonHuanhuaBaseConfig[var.damonchoose].quality)
	end
end

--佣兵直升石
function useStone(actor, pack)
	local var = getActorVar(actor)
	if not DamonStageConfig[var.stage + 1] then
		return
	end
	local stage = LDataPack.readShort(pack)
	local conf = DamonHuanhuaBaseConfig[stage]
	if not conf then return end

	if DamonStageConfig[var.stage].stage < stage then
		return
	end
	if conf.stoneid == 0 then return end
	if not actoritem.checkItem(actor, conf.stoneid, 1) then
		return
	end
	actoritem.reduceItem(actor, conf.stoneid, 1, "damon use stage stone")
	local before = DamonStageConfig[var.stage].stage
	if DamonStageConfig[var.stage].stage == stage then
		for i=var.stage, #DamonStageConfig do
			if DamonStageConfig[i].stage ~= stage then
				var.stage = i
				var.stageexp = 0
				break
			end
		end
	else
		var.stageexp = var.stageexp + conf.stoneaddexp
		while DamonStageConfig[var.stage + 1] and var.stageexp >= DamonStageConfig[var.stage].needexp do
			var.stageexp = var.stageexp - DamonStageConfig[var.stage].needexp
			var.stage = var.stage + 1
		end	
	end
	
	updateAttr(actor, true)
	actorevent.onEvent(actor, aeDamonStage, var.stage, 1)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_JLStageUpRet)
	LDataPack.writeShort(pack, var.stage)
	LDataPack.writeInt(pack, var.stageexp)
	LDataPack.flush(pack)
	if DamonStageConfig[var.stage].stage > before then
		var.damonchoose = DamonStageConfig[var.stage].stage
		sendChoose(actor)
		LActor.setDamon(actor, var.damonchoose, var.mozhenchoose)
		actorevent.onEvent(actor, aeFacadeActive, 1, DamonHuanhuaBaseConfig[var.damonchoose].quality)
	end
end

--幻化精灵激活升级
function huanhuaUp(actor, pack)
	local id = LDataPack.readInt(pack)	
	local var = getActorVar(actor)
	local conf = DamonHuanhuaBaseConfig[id]
	if not conf then return end
	if (var.huanhua[id] or 0) >= conf.maxLevel then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = DamonHuanhuaBaseConfig[id].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (var.huanhua[id] or 0) >= conf.maxLevel then
		count = conf.maxLevel - (var.huanhua[id] or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "huanhua up")
    var.huanhua[id] = (var.huanhua[id] or 0) + count

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_JLHuanhuaUpRet)
	LDataPack.writeInt(pack, id)
	LDataPack.writeInt(pack, var.huanhua[id])
    LDataPack.flush(pack)
    
	updateAttr(actor, true)
	var.damonchoose = id
	sendChoose(actor)
	LActor.setDamon(actor, var.damonchoose, var.mozhenchoose)
	actorevent.onEvent(actor, aeFacadeActive, 1, DamonHuanhuaBaseConfig[var.damonchoose].quality)
end

local function getMaxCanUse(index, level)
    local conf = DamonPillMaxConfig[index]
	for k,v in ipairs(conf) do
        if conf[k+1] and v.level <= level and conf[k+1].level > level then
            return v.max
        end
    end
    return conf[#conf].max
end

--精灵使用印记
function usePill(actor, pack)
	local pillindex = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    local max = getMaxCanUse(pillindex, LActor.getLevel(actor))
	
	--função para chamar ID e contar a quantidade de itens
	local id = DamonPillConfig[pillindex].itemuse[1]
	count = actoritem.getItemCount(actor, id)
	
	if count + (var.pilluse[pillindex] or 0) >= max then
		count = max - (var.pilluse[pillindex] or 0)
	end
	
	---
	
    if (var.pilluse[pillindex] or 0) >= max then return end

    if not actoritem.checkItems(actor, DamonPillConfig[pillindex].needitem) then
        return
    end
	
	
    actoritem.reduceItem(actor, id, count, "shenqi level up")

    var.pilluse[pillindex] = (var.pilluse[pillindex] or 0) + count

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_JLUsePillRet)
    LDataPack.writeInt(pack, pillindex)
	LDataPack.writeInt(pack, var.pilluse[pillindex])
    LDataPack.flush(pack)

    updateAttr(actor, true)
end


--精灵升级魔阵
function mozhenUp(actor, pack)
	local id = LDataPack.readShort(pack)	
	local var = getActorVar(actor)
	local conf = DamonMozhenBaseConfig[id]
	if not conf then return end
	if (var.mozhen[id] or 0) >= conf.maxLevel then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = DamonMozhenBaseConfig[id].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (var.mozhen[id] or 0) >= conf.maxLevel then
		count = conf.maxLevel - (var.mozhen[id] or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "mozhen level up")
    var.mozhen[id] = (var.mozhen[id] or 0) + count

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_JLMozhenUpRet)
	LDataPack.writeInt(pack, id)
	LDataPack.writeInt(pack, var.mozhen[id])
	LDataPack.flush(pack)
	
	if var.mozhen[id] == 1 then
		var.mozhenchoose = id
		sendMozhenChoose(actor)
		if var.damonchoose ~= 0 then
			LActor.setDamon(actor, var.damonchoose, var.mozhenchoose)
		end
	end
    
    updateAttr(actor, true)
end

function sendChoose(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_JLChangeRet)
	LDataPack.writeInt(pack, var.damonchoose)
    LDataPack.flush(pack)
end

--幻化精灵
function change(actor, pack)
	local id = LDataPack.readInt(pack)
	local var = getActorVar(actor)

	local config = DamonHuanhuaBaseConfig[id]
	if config.maxLevel ~= 0 and (var.huanhua[id] or 0) == 0 then return end
	if config.maxLevel == 0 and (id - 1) * 10 > var.stage then return end
	var.damonchoose = id
	sendChoose(actor)
	if var.damonchoose ~= 0 then
		LActor.setDamon(actor, var.damonchoose, var.mozhenchoose)
	end
end

function sendMozhenChoose(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_JLMozhenChoose)
	LDataPack.writeInt(pack, var.mozhenchoose)
	LDataPack.flush(pack)
end

--幻化魔阵
function mozhenChange(actor, pack)
	local id = LDataPack.readChar(pack)
	local var = getActorVar(actor)
	if (var.mozhen[id] or 0) <= 0 then return end
	var.mozhenchoose = id
	sendMozhenChoose(actor)
	if var.damonchoose ~= 0 then
		LActor.setDamon(actor, var.damonchoose, var.mozhenchoose)
	end
end

function onLogin(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.damon) then return end
	sendTotalInfo(actor)	
end

function onInit(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.damon) then return end
	updateAttr(actor, true)	
	local var = getActorVar(actor)
	if var.damonchoose ~= 0 then
		LActor.setDamon(actor, var.damonchoose, var.mozhenchoose)
	end
end

function onSystemOpen(actor)
	local var = getActorVar(actor)
	if var.level ~= 0 then return end
	var.level = 1
	var.stage = 0
	var.damonchoose = 1
	sendTotalInfo(actor)
	updateAttr(actor, true)
	LActor.setDamon(actor, var.damonchoose, var.mozhenchoose)
	actorevent.onEvent(actor, aeFacadeActive, 1, DamonHuanhuaBaseConfig[var.damonchoose].quality)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)
local function init()	
	newsystem.regSystemOpenFuncs(actorexp.LimitTp.damon, onSystemOpen)

	if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_JLLevelUp, levelUp)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_JLStageUp, stageUp)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_JLHuanhuaUp, huanhuaUp)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_JLUsePill, usePill)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_JLMozhenUp, mozhenUp)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_JLChange, change)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_JLMozhenChange, mozhenChange)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_JLUseStageStone, useStone)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.damonAll = function (actor, args)
    local IsChange = false
    local var = getActorVar(actor)
    local maxlevel = #DamonLevelConfig
    if var.level < maxlevel then
        var.level = maxlevel
        local count = 0
        local exp = 0
        for level = 1, var.level - 1 do
            exp = exp + DamonLevelConfig[level].needexp
        end
        count = math.floor(exp / DamonConstConfig.leveladdexp)
        actorevent.onEvent(actor, aeDamonLevel, var.level, count)
        IsChange = true
    end
    maxlevel = #DamonStageConfig
    if var.stage < maxlevel then
        var.stage = maxlevel
        count = 0
        exp = 0
        for stagelevel = 1, var.stage - 1 do
            exp = exp + DamonStageConfig[stagelevel].needexp
        end
        count = math.floor(exp / DamonConstConfig.stageaddexp)
        actorevent.onEvent(actor, aeDamonStage, var.stage, count)
        IsChange = true
    end
    for id, conf in pairs(DamonHuanhuaBaseConfig) do
        maxlevel = conf.maxLevel
        if maxlevel > 0 and (var.huanhua[id] or 0) < maxlevel then
            var.huanhua[id] = maxlevel
            IsChange = true
        end
    end
    local actorLevel = LActor.getLevel(actor)
    for pillindex, conf in pairs(DamonPillConfig) do
        maxlevel = getMaxCanUse(pillindex, actorLevel)
        if (var.pilluse[pillindex] or 0) < maxlevel then
            var.pilluse[pillindex] = maxlevel
            IsChange = true
        end
    end
    for id, conf in pairs(DamonMozhenBaseConfig) do
        maxlevel = conf.maxLevel
        if (var.mozhen[id] or 0) < maxlevel then
            var.mozhen[id] = maxlevel
            IsChange = true
        end
    end
    for damon in pairs(DamonHuanhuaBaseConfig) do
        var.damonchoose = math.max(var.damonchoose, damon)
    end
    var.mozhenchoose = #DamonMozhenBaseConfig
    actorevent.onEvent(actor, aeFacadeActive, 1, DamonHuanhuaBaseConfig[var.damonchoose].quality)
    
    if IsChange then
        onLogin(actor)
        updateAttr(actor, true)
    end
    return true
end
