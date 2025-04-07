module("yongbingsystem", package.seeall)

--佣兵数据获取
function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var.yongbing then 
		var.yongbing = {}
		var.yongbing.level = 0
		var.yongbing.levelexp = 0
		var.yongbing.stage = 0
		var.yongbing.stageexp = 0
		var.yongbing.huanhua = {}
		var.yongbing.pilluse = {}
		var.yongbing.mozhen = {}
		var.yongbing.yongbingchoose = 0 --当前选择的佣兵
		var.yongbing.mozhenchoose = 0 --当前选择的魔阵
		var.yongbing.power = 0
	end
	return var.yongbing
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
	for k,v in ipairs(YongbingStageConfig[var.stage].baseAttrs) do
        addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
    end

	for k,v in pairs(YongbingHuanhuaBaseConfig) do
		local level = var.huanhua[k] or 0
		if level > 0 then
	        for kk,vv in ipairs(v.baseAttrs) do
	            addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * level
	        end
	    end
    end

    for k,v in ipairs(YongbingPillConfig) do
        for kk,vv in ipairs(v.baseAttrs) do
            addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * (var.pilluse[k] or 0)
        end
    end

	for k,v in ipairs(YongbingMozhenBaseConfig) do
		local level = var.mozhen[k] or 0
		if level > 0 then
			for __,vv in ipairs(v.baseAttrs) do
				addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * level
			end
		end
	end

	for k,v in ipairs(YongbingConstConfig.levelskills) do
		local conf = SkillPassiveConfig[v][passiveskill.getSkillLv(actor, v)]
		if conf.type == 1 then
			for k,v in ipairs(conf.addattr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value                
			end			
		end
		power = power + conf.power
	end

	for k,v in ipairs(YongbingConstConfig.stageskills) do
		local conf = SkillPassiveConfig[v][passiveskill.getSkillLv(actor, v)]
		if conf.type == 1 then
			for k,v in ipairs(conf.addattr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
			end			
		end
		power = power + conf.power
	end

	local add = addAttrs[Attribute.atYongbingTotal] or 0
	if (var.level or 0) > 0 then
		for k,v in ipairs(YongbingLevelConfig[var.level].baseAttrs) do
			addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * (1+add/10000)
		end
	end

    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Yongbing)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
	end
	attr:SetExtraPower(power)
    if isCalc then
		LActor.reCalcAttr(actor)
		if System.isCommSrv() then
			var.power = utils.getAttrPower0(addAttrs) + power
			utils.rankfunc.updateRankingList(actor, var.power, RankingType_Yongbing)
			actorevent.onEvent(actor, aeChangeRankPower, var.power, subactivity4.minType.yongbing)
		end		
	end	
end

function sendTotalInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_YBData)
	LDataPack.writeInt(pack, var.yongbingchoose)
	LDataPack.writeInt(pack, var.mozhenchoose)
	LDataPack.writeShort(pack, var.level)
	LDataPack.writeInt(pack, var.levelexp)
	LDataPack.writeShort(pack, var.stage)
	LDataPack.writeInt(pack, var.stageexp)

	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, count)
	for k,v in pairs(YongbingHuanhuaBaseConfig) do
		LDataPack.writeInt(pack, k)
		LDataPack.writeInt(pack, var.huanhua[k] or 0)
		count = count + 1
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeInt(pack, count)
	LDataPack.setPosition(pack, npos)
	
	LDataPack.writeInt(pack, #YongbingPillConfig)
	for i=1, #YongbingPillConfig do
		LDataPack.writeInt(pack, i)
        LDataPack.writeInt(pack, var.pilluse[i] or 0)
	end
	count = 0
	pos = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, count)
	for k,v in ipairs(YongbingMozhenBaseConfig) do
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

--佣兵升级
function levelUp(actor)
	local var = getActorVar(actor)
	if not YongbingLevelConfig[var.level + 1] then
		return
	end
	local count = actoritem.getItemCount(actor, YongbingConstConfig.levelitemid)
	if count <= 0 then
		return
	end
	count = math.min(count, math.ceil((YongbingLevelConfig[var.level].needexp - var.levelexp)/YongbingConstConfig.leveladdexp))
	actoritem.reduceItem(actor, YongbingConstConfig.levelitemid, count, "yongbing level up")

	var.levelexp = var.levelexp + YongbingConstConfig.leveladdexp * count
	
	if var.levelexp >= YongbingLevelConfig[var.level].needexp then
		var.levelexp = var.levelexp - YongbingLevelConfig[var.level].needexp
		var.level = var.level + 1
	end	
	
	actorevent.onEvent(actor, aeYongbingLevel, var.level, count)
	updateAttr(actor, true)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_YBLevelUpRet)
	LDataPack.writeShort(pack, var.level)
	LDataPack.writeInt(pack, var.levelexp)
    LDataPack.flush(pack)
end

--佣兵进阶
function stageUp(actor)
	local var = getActorVar(actor)
	if not YongbingStageConfig[var.stage + 1] then
		return
	end
	local count = actoritem.getItemCount(actor, YongbingConstConfig.stageitemid)
	if count <= 0 then
		return
	end
	local conf = YongbingStageConfig[var.stage]
	count = math.min(count, math.ceil((conf.needexp - var.stageexp)/YongbingConstConfig.stageaddexp))
	actoritem.reduceItem(actor, YongbingConstConfig.stageitemid, count, "yongbing stage up")

	var.stageexp = var.stageexp + YongbingConstConfig.stageaddexp * count
	if var.stageexp >= conf.needexp then
		var.stageexp = var.stageexp - conf.needexp
		var.stage = var.stage + 1
	end	
	
	updateAttr(actor, true)
	actorevent.onEvent(actor, aeYongbingStage, var.stage, count)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_YBStageUpRet)
	LDataPack.writeShort(pack, var.stage)
	LDataPack.writeInt(pack, var.stageexp)
	LDataPack.flush(pack)
	if YongbingStageConfig[var.stage].stage > conf.stage then
		var.yongbingchoose = YongbingStageConfig[var.stage].stage
		sendChoose(actor)
		LActor.setYonbingId(actor, var.yongbingchoose, var.mozhenchoose)
		actorevent.onEvent(actor, aeFacadeActive, 2, YongbingHuanhuaBaseConfig[var.yongbingchoose].quality)
	end
end

--佣兵直升石
function useStone(actor, pack)
	local var = getActorVar(actor)
	if not YongbingStageConfig[var.stage + 1] then
		return
	end
	local stage = LDataPack.readShort(pack)
	local conf = YongbingHuanhuaBaseConfig[stage]
	if not conf then return end

	if YongbingStageConfig[var.stage].stage < stage then
		return
	end
	if conf.stoneid == 0 then return end
	if not actoritem.checkItem(actor, conf.stoneid, 1) then
		return
	end
	actoritem.reduceItem(actor, conf.stoneid, 1, "yongbing use stage stone")

	local before = YongbingStageConfig[var.stage].stage
	if YongbingStageConfig[var.stage].stage == stage then
		for i=var.stage, #YongbingStageConfig do
			if YongbingStageConfig[i].stage ~= stage then
				var.stage = i
				var.stageexp = 0
				break
			end
		end
	else
		var.stageexp = var.stageexp + conf.stoneaddexp
		while YongbingStageConfig[var.stage + 1] and var.stageexp >= YongbingStageConfig[var.stage].needexp do
			var.stageexp = var.stageexp - YongbingStageConfig[var.stage].needexp
			var.stage = var.stage + 1
		end	
	end
	
	updateAttr(actor, true)
	actorevent.onEvent(actor, aeYongbingStage, var.stage, 1)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_YBStageUpRet)
	LDataPack.writeShort(pack, var.stage)
	LDataPack.writeInt(pack, var.stageexp)
	LDataPack.flush(pack)
	if YongbingStageConfig[var.stage].stage > before then
		var.yongbingchoose = YongbingStageConfig[var.stage].stage
		sendChoose(actor)
		LActor.setYonbingId(actor, var.yongbingchoose, var.mozhenchoose)
		actorevent.onEvent(actor, aeFacadeActive, 2, YongbingHuanhuaBaseConfig[var.yongbingchoose].quality)
	end
end

--幻化佣兵激活升级
function huanhuaUp(actor, pack)
	local id = LDataPack.readInt(pack)	
	local var = getActorVar(actor)
	local conf = YongbingHuanhuaBaseConfig[id]
	if not conf then return end
	if (var.huanhua[id] or 0) >= conf.maxLevel then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = YongbingHuanhuaBaseConfig[id].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (var.huanhua[id] or 0) >= conf.maxLevel then
		count = conf.maxLevel - (var.huanhua[id] or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "huanhua up")
    var.huanhua[id] = (var.huanhua[id] or 0) + count

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_YBHuanhuaUpRet)
	LDataPack.writeInt(pack, id)
	LDataPack.writeInt(pack, var.huanhua[id])
    LDataPack.flush(pack)
    
	updateAttr(actor, true)
	var.yongbingchoose = id
	sendChoose(actor)
	actorevent.onEvent(actor, aeFacadeActive, 2, YongbingHuanhuaBaseConfig[var.yongbingchoose].quality)
	LActor.setYonbingId(actor, var.yongbingchoose, var.mozhenchoose)
end

local function getMaxCanUse(index, level)
    local conf = YongbingPillMaxConfig[index]
	for k,v in ipairs(conf) do
        if conf[k+1] and v.level <= level and conf[k+1].level > level then
            return v.max
        end
    end
    return conf[#conf].max
end

--佣兵使用印记
function usePill(actor, pack)
	local pillindex = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    local max = getMaxCanUse(pillindex, LActor.getLevel(actor))
	
	--função para chamar ID e contar a quantidade de itens
	local id = YongbingPillConfig[pillindex].itemuse[1]
	count = actoritem.getItemCount(actor, id)
	
	if count + (var.pilluse[pillindex] or 0) >= max then
		count = max - (var.pilluse[pillindex] or 0)
	end
	
	---
	
    if (var.pilluse[pillindex] or 0) >= max then return end

    if not actoritem.checkItems(actor, YongbingPillConfig[pillindex].needitem) then
        return
    end
	
	
	actoritem.reduceItem(actor, id, count, 'yongbing pill use')
	var.pilluse[pillindex] = (var.pilluse[pillindex] or 0) + count
	
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_YBUsePillRet)
    LDataPack.writeInt(pack, pillindex)
	LDataPack.writeInt(pack, var.pilluse[pillindex])
    LDataPack.flush(pack)

    updateAttr(actor, true)
end


--佣兵升级魔阵
function mozhenUp(actor, pack)
	local id = LDataPack.readShort(pack)	
	local var = getActorVar(actor)
	local conf = YongbingMozhenBaseConfig[id]
	if not conf then return end
	if (var.mozhen[id] or 0) >= conf.maxLevel then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = YongbingMozhenBaseConfig[id].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (var.mozhen[id] or 0) >= conf.maxLevel then
		count = conf.maxLevel - (var.mozhen[id] or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "mozhen level up")
    var.mozhen[id] = (var.mozhen[id] or 0) + count

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_YBMozhenUpRet)
	LDataPack.writeInt(pack, id)
	LDataPack.writeInt(pack, var.mozhen[id])
	LDataPack.flush(pack)
	
	if var.mozhen[id] == 1 then
		var.mozhenchoose = id
		sendMozhenChoose(actor)
		if var.yongbingchoose ~= 0 then
			LActor.setYonbingId(actor, var.yongbingchoose, var.mozhenchoose)
		end
	end
    
    updateAttr(actor, true)
end

function sendChoose(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_YBChangeRet)
	LDataPack.writeInt(pack, var.yongbingchoose)
	LDataPack.flush(pack)	
end

--幻化佣兵
function change(actor, pack)
	local id = LDataPack.readInt(pack)
	local var = getActorVar(actor)
	local config = YongbingHuanhuaBaseConfig[id]
	if config.maxLevel ~= 0 and (var.huanhua[id] or 0) == 0 then return end
	if config.maxLevel == 0 and (id - 1) * 10 > var.stage then return end
	var.yongbingchoose = id
	sendChoose(actor)
	if var.yongbingchoose ~= 0 then
		LActor.setYonbingId(actor, var.yongbingchoose, var.mozhenchoose)
	end
end

function sendMozhenChoose(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_YBMozhenChoose)
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
	if var.yongbingchoose ~= 0 then
		LActor.setYonbingId(actor, var.yongbingchoose, var.mozhenchoose)
	end
end

function onLogin(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.yongbing) then return end
	sendTotalInfo(actor)
	sendChoose(actor)	
end

function onInit(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.yongbing) then return end
	updateAttr(actor, true)
	local var = getActorVar(actor)
	if var.yongbingchoose > 0 then
		LActor.setYonbingId(actor, var.yongbingchoose, var.mozhenchoose, true)
	end
end

function onSystemOpen(actor)
    local var = getActorVar(actor)
    if var.level ~= 0 then return end
	var.level = 1
	var.stage = 0
	var.yongbingchoose = 1
	sendTotalInfo(actor)
	updateAttr(actor, true)
	LActor.setYonbingId(actor, var.yongbingchoose, var.mozhenchoose)
	actorevent.onEvent(actor, aeFacadeActive, 2, YongbingHuanhuaBaseConfig[var.yongbingchoose].quality)
end


actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)


local function init()
	newsystem.regSystemOpenFuncs(actorexp.LimitTp.yongbing, onSystemOpen)

	if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_YBLevelUp, levelUp)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_YBStageUp, stageUp)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_YBHuanhuaUp, huanhuaUp)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_YBUsePill, usePill)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_YBMozhenUp, mozhenUp)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_YBChange, change)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_YBMozhenChange, mozhenChange)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_YBUseStageStone, useStone)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.yongbingAll = function (actor, args)
    local IsChange = false
    local var = getActorVar(actor)
    local maxlevel = #YongbingLevelConfig
    if var.level < maxlevel then
        var.level = maxlevel
        local count = 0
        local exp = 0
        for level = 1, var.level - 1 do
            exp = exp + YongbingLevelConfig[level].needexp
        end
        count = math.floor(exp / YongbingConstConfig.leveladdexp)
        actorevent.onEvent(actor, aeYongbingLevel, var.level, count)
        IsChange = true
    end
    maxlevel = #YongbingStageConfig
    if var.stage < maxlevel then
        var.stage = maxlevel
        local count = 0
        local exp = 0
        for stagelevel = 1, var.stage - 1 do
            exp = exp + YongbingStageConfig[stagelevel].needexp
        end
        count = math.floor(exp / YongbingConstConfig.stageaddexp)
        actorevent.onEvent(actor, aeYongbingStage, var.stage, count)
        IsChange = true
    end
    for id, conf in pairs(YongbingHuanhuaBaseConfig) do
        maxlevel = conf.maxLevel
        if maxlevel > 0 and (var.huanhua[id] or 0) < maxlevel then
            var.huanhua[id] = maxlevel
            IsChange = true
        end
    end
    local actorLevel = LActor.getLevel(actor)
    for pillindex, conf in pairs(YongbingPillConfig) do
        maxlevel = getMaxCanUse(pillindex, actorLevel)
        if (var.pilluse[pillindex] or 0) < maxlevel then
            var.pilluse[pillindex] = maxlevel
            IsChange = true
        end
    end
    for id, conf in pairs(YongbingMozhenBaseConfig) do
        maxlevel = conf.maxLevel
        if (var.mozhen[id] or 0) < maxlevel then
            var.mozhen[id] = maxlevel
            IsChange = true
        end
    end
    for yongbing in pairs(YongbingHuanhuaBaseConfig) do
        var.yongbingchoose = math.max(var.yongbingchoose, yongbing)
    end
    var.mozhenchoose = #YongbingMozhenBaseConfig
    actorevent.onEvent(actor, aeFacadeActive, 2, YongbingHuanhuaBaseConfig[var.yongbingchoose].quality)
    
    if IsChange then
        onLogin(actor)
        updateAttr(actor, true)
    end
    return true
end
