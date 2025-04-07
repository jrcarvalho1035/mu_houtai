module("shenmosystem", package.seeall)

--神魔数据获取
function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var.shenmo then 
		var.shenmo = {}
		var.shenmo.level = 0
		var.shenmo.stage = 0
		var.shenmo.stageexp = 0
		var.shenmo.huanhua = {}
		var.shenmo.pilluse = {}
		var.shenmo.mozhen = {}
		var.shenmo.shenmochoose = 0 --当前选择的神魔
		var.shenmo.mozhenchoose = 0 --当前选择的魔阵
		var.shenmo.cd = 0
		var.shenmo.endTime = 0
		var.shenmo.power = 0
		var.shenmo.changetime = 0 --变身次数
		var.shenmo.autoChangeSuper = 0 --自动变身状态
	end
	if not var.shenmo.levelexp then var.shenmo.levelexp = 0 end
	return var.shenmo
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
	for k,v in ipairs(ShenmoStageConfig[var.stage].baseAttrs) do
        addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
    end

	for k,v in pairs(ShenmoHuanhuaBaseConfig) do
		local level = var.huanhua[k] or 0
		if level > 0 then
	        for kk,vv in ipairs(v.baseAttrs) do
	            addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * level
	        end
	    end
    end

    for k,v in ipairs(ShenmoPillConfig) do
        for kk,vv in ipairs(v.baseAttrs) do
            addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * (var.pilluse[k] or 0)
        end
    end

	for k,v in ipairs(ShenmoMozhenBaseConfig) do
		local level = var.mozhen[k] or 0
		if level > 0 then
			for __,vv in ipairs(v.baseAttrs) do
				addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * level
			end
		end
	end
	
	for k,v in ipairs(ShenmoConstConfig.levelskills) do
		local conf = SkillPassiveConfig[v][passiveskill.getSkillLv(actor, v)]
		if conf.type == 1 then
			for k,v in ipairs(conf.addattr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value                
			end			
		end
		power = power + conf.power
	end

	for k,v in ipairs(ShenmoConstConfig.stageskills) do
		local conf = SkillPassiveConfig[v][passiveskill.getSkillLv(actor, v)]
		if conf.type == 1 then
			for k,v in ipairs(conf.addattr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value                
			end			
		end
		power = power + conf.power
	end

	local add = addAttrs[Attribute.atShenmoTotal] or 0
	if (var.level or 0) > 0 then
		for k,v in ipairs(ShenmoLevelConfig[var.level].baseAttrs) do
			addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * (1+add/10000)
		end
	end

    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Shenmo)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
	end
	attr:SetExtraPower(power)
    if isCalc then
		LActor.reCalcAttr(actor)
		if System.isCommSrv() then
			var.power = utils.getAttrPower0(addAttrs) + power
			utils.rankfunc.updateRankingList(actor, var.power, RankingType_Shenmo)
			if guajifuben.getCustom(actor) >= 10 then --第十关才开始计算玩家神魔战力排行
				actorevent.onEvent(actor, aeChangeRankPower, var.power, subactivity4.minType.shenmo)
			end
		end	
	end
end

function sendTotalInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_SMData)
	LDataPack.writeInt(pack, var.shenmochoose)
	LDataPack.writeInt(pack, var.mozhenchoose)
	LDataPack.writeShort(pack, var.level)
	LDataPack.writeInt(pack, var.levelexp)
	LDataPack.writeShort(pack, var.stage)
	LDataPack.writeInt(pack, var.stageexp)

	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, count)
	for k,v in pairs(ShenmoHuanhuaBaseConfig) do
		LDataPack.writeInt(pack, k)
		LDataPack.writeInt(pack, var.huanhua[k] or 0)
		count = count + 1
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeInt(pack, count)
	LDataPack.setPosition(pack, npos)
	
	LDataPack.writeInt(pack, #ShenmoPillConfig)
	for i=1, #ShenmoPillConfig do
		LDataPack.writeInt(pack, i)
        LDataPack.writeInt(pack, var.pilluse[i] or 0)
	end
	count = 0
	pos = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, count)
	for k,v in ipairs(ShenmoMozhenBaseConfig) do
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

--神魔升级
function levelUp(actor)
	local var = getActorVar(actor)
	if not ShenmoLevelConfig[var.level + 1] then
		return
	end
	local count = actoritem.getItemCount(actor, ShenmoConstConfig.levelitemid)
	if count <= 0 then
		return
	end
	count = math.min(count, math.ceil((ShenmoLevelConfig[var.level].needexp - var.levelexp)/ShenmoConstConfig.leveladdexp))
	actoritem.reduceItem(actor, ShenmoConstConfig.levelitemid, count, "shenmo level up")

	var.levelexp = var.levelexp + ShenmoConstConfig.leveladdexp * count
	
	if var.levelexp >= ShenmoLevelConfig[var.level].needexp then
		var.levelexp = var.levelexp - ShenmoLevelConfig[var.level].needexp
		var.level = var.level + 1
	end	
	
	updateAttr(actor, true)
	actorevent.onEvent(actor, aeShenmoLevel, var.level, count)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_SMLevelUpRet)
	LDataPack.writeShort(pack, var.level)
	LDataPack.writeInt(pack, var.levelexp)
    LDataPack.flush(pack)
end

--神魔进阶
function stageUp(actor)
	local var = getActorVar(actor)
	if not ShenmoStageConfig[var.stage + 1] then
		return
	end
	local count = actoritem.getItemCount(actor, ShenmoConstConfig.stageitemid)
	if count <= 0 then
		return
	end
	local conf = ShenmoStageConfig[var.stage]
	count = math.min(count, math.ceil((conf.needexp - var.stageexp)/ShenmoConstConfig.stageaddexp))
	actoritem.reduceItem(actor, ShenmoConstConfig.stageitemid, count, "shenmo stage up")

	var.stageexp = var.stageexp + ShenmoConstConfig.stageaddexp * count
	if var.stageexp >= conf.needexp then
		var.stageexp = var.stageexp - conf.needexp
		var.stage = var.stage + 1
	end	
		
	actorevent.onEvent(actor, aeShenmoStage, var.stage, count)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_SMStageUpRet)
	LDataPack.writeShort(pack, var.stage)
	LDataPack.writeInt(pack, var.stageexp)
	LDataPack.flush(pack)
	if ShenmoStageConfig[var.stage].stage > conf.stage then
		var.shenmochoose = ShenmoStageConfig[var.stage].stage
		sendChoose(actor)
		actorevent.onEvent(actor, aeFacadeActive, 3, ShenmoHuanhuaBaseConfig[var.shenmochoose].quality)
	end
	updateAttr(actor, true)
end

function useStone(actor, pack)
	local var = getActorVar(actor)
	if not ShenmoStageConfig[var.stage + 1] then
		return
	end
	local stage = LDataPack.readShort(pack)
	local conf = ShenmoHuanhuaBaseConfig[stage]
	if not conf then return end

	if ShenmoStageConfig[var.stage].stage < stage then
		return
	end
	if conf.stoneid == 0 then return end
	if not actoritem.checkItem(actor, conf.stoneid, 1) then
		return
	end
	actoritem.reduceItem(actor, conf.stoneid, 1, "shenmo use stage stone")

	local before = ShenmoStageConfig[var.stage].stage
	if ShenmoStageConfig[var.stage].stage == stage then
		for i=var.stage, #ShenmoStageConfig do
			if ShenmoStageConfig[i].stage ~= stage then
				var.stage = i
				var.stageexp = 0
				break
			end
		end
	else
		var.stageexp = var.stageexp + conf.stoneaddexp
		while ShenmoStageConfig[var.stage + 1] and var.stageexp >= ShenmoStageConfig[var.stage].needexp do
			var.stageexp = var.stageexp - ShenmoStageConfig[var.stage].needexp
			var.stage = var.stage + 1
		end	
	end
		
	actorevent.onEvent(actor, aeShenmoStage, var.stage, 1)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_SMStageUpRet)
	LDataPack.writeShort(pack, var.stage)
	LDataPack.writeInt(pack, var.stageexp)
	LDataPack.flush(pack)
	if ShenmoStageConfig[var.stage].stage > before then
		var.shenmochoose = ShenmoStageConfig[var.stage].stage
		sendChoose(actor)
		actorevent.onEvent(actor, aeFacadeActive, 3, ShenmoHuanhuaBaseConfig[var.shenmochoose].quality)
	end
	updateAttr(actor, true)
end

--幻化神魔激活升级
function huanhuaUp(actor, pack)
	local id = LDataPack.readInt(pack)
	local var = getActorVar(actor)
	local conf = ShenmoHuanhuaBaseConfig[id]
	if not conf then return end
	if (var.huanhua[id] or 0) >= conf.maxLevel then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = ShenmoHuanhuaBaseConfig[id].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (var.huanhua[id] or 0) >= conf.maxLevel then
		count = conf.maxLevel - (var.huanhua[id] or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "huanhua up")
    var.huanhua[id] = (var.huanhua[id] or 0) + count

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_SMHuanhuaUpRet)
	LDataPack.writeInt(pack, id)
	LDataPack.writeInt(pack, var.huanhua[id])
    LDataPack.flush(pack)    
	
	var.shenmochoose = id
	sendChoose(actor)
	updateAttr(actor, true)
	actorevent.onEvent(actor, aeFacadeActive, 3, ShenmoHuanhuaBaseConfig[var.shenmochoose].quality)
end

local function getMaxCanUse(index, level)
    local conf = ShenmoPillMaxConfig[index]
	for k,v in ipairs(conf) do
        if conf[k+1] and v.level <= level and conf[k+1].level > level then
            return v.max
        end
    end
    return conf[#conf].max
end

--神魔使用印记
function usePill(actor, pack)
	local pillindex = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    local max = getMaxCanUse(pillindex, LActor.getLevel(actor))
	
	--função para chamar ID e contar a quantidade de itens
	local id = ShenmoPillConfig[pillindex].itemuse[1]
	count = actoritem.getItemCount(actor, id)
	
	if count + (var.pilluse[pillindex] or 0) >= max then
		count = max - (var.pilluse[pillindex] or 0)
	end
	
	---
	
    if (var.pilluse[pillindex] or 0) >= max then return end

    if not actoritem.checkItems(actor, ShenmoPillConfig[pillindex].needitem) then
        return
    end
	
	
    actoritem.reduceItem(actor, id, count, "shenmo level up")

    var.pilluse[pillindex] = (var.pilluse[pillindex] or 0) + count

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_SMUsePillRet)
    LDataPack.writeInt(pack, pillindex)
	LDataPack.writeInt(pack, var.pilluse[pillindex])
    LDataPack.flush(pack)

    updateAttr(actor, true)
end


function sendChoose(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_SMChangeRet)
	LDataPack.writeInt(pack, var.shenmochoose)
    LDataPack.flush(pack)
end

--幻化神魔
function change(actor, pack)
	local id = LDataPack.readInt(pack)
	local var = getActorVar(actor)
	local config = ShenmoHuanhuaBaseConfig[id]
	if config.maxLevel ~= 0 and (var.huanhua[id] or 0) == 0 then return end
	if config.maxLevel == 0 and (id - 1) * 10 > var.stage then return end

	var.shenmochoose = id	
	sendChoose(actor)
end

--神魔变身
function changeSuper(actor, pack)
	if LActor.isDeath(actor) then return end
	if LActor.isGatherMonster(actor) then return end --采集状态不可变身
	
    local var = getActorVar(actor)
	if not var then return end

    local choose = var.tiyan ~= 0 and var.tiyan or var.shenmochoose
    if choose == 0 then return end
    
    local chooseConfig = ShenmoHuanhuaBaseConfig[choose]
	if not chooseConfig then return end
	
	if var.cd > System.getTick() then
		return
	end
    
    local roleSuperData = getChangeInfoById(choose)
    LActor.CreateRoleSuper(actor, roleSuperData)

	var.endTime = System.getTick() + chooseConfig.duration * 1000
	var.cd = System.getTick() + chooseConfig.cd * 1000
	if var.changetime < 50 then
		var.changetime = var.changetime + 1
	end
    -- if change.count < 10 then
    --     change.count = change.count + 1
    -- end
    sendChangeSuperData(actor)
end

function setShenmoCd(actor, count)
	local var = getActorVar(actor)
	if not var then return end
	if not count then 
        count = math.random(FubenConstConfig.randChangeTime[1],FubenConstConfig.randChangeTime[2])
	end
	var.cd = System.getTick() + count * 1000
	var.endTime = 0
	sendChangeSuperData(actor)
end

function getShenmoId(actor)
	local var = getActorVar(actor)
    if not var then return end
	return var.shenmochoose
end

function getShenmoCd(actor)
	local var = getActorVar(actor)
	if not var then return end
	return var.cd - System.getTick()
end

function getShenmoFazhen(actor)
	local var = getActorVar(actor)
    if not var then return end
	return var.mozhenchoose
end

_G.getShenmoCd = getShenmoCd
_G.getShenmoId = getShenmoId
_G.getShenmoFazhen = getShenmoFazhen

--通过幻化id获取幻化信息
function getChangeInfoById(shenmochoose)
    local chooseConfig = ShenmoHuanhuaBaseConfig[shenmochoose]
    if not chooseConfig then return end
    local roleSuperData = RoleSuperData:new_local()
    roleSuperData.shemoChooseId = shenmochoose
    roleSuperData.hpMaxParam = chooseConfig.hpparam
    roleSuperData.atkParam = chooseConfig.atkparam
    roleSuperData.duration = chooseConfig.duration
    roleSuperData.cd = chooseConfig.cd

    local skills = roleSuperData.skills
    local configSkills = chooseConfig.skillid
    skills[0] = chooseConfig.appearskillid
    for i = 1, #chooseConfig.skillid do
        skills[i] = configSkills[i]
    end

    return roleSuperData
end

function getChangeInfo(actor)
	local var = getActorVar(actor) 
    if not var then return end
    return getChangeInfoById(var.shenmochoose)
end

function sendChangeSuperData(actor)
	--if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenmo) then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_SMChangeSuper)
    local var = getActorVar(actor)
    LDataPack.writeInt(pack, var.endTime - System.getTick())
    local cd = var.cd - System.getTick()
	LDataPack.writeInt(pack, cd < 0 and 0 or cd)
	LDataPack.writeChar(pack, var.changetime)
    LDataPack.flush(pack)
end

function changeSuperData(actor)
	local var = getActorVar(actor)
	if var.shenmochoose == 0 then return end
	local chooseConfig = ShenmoHuanhuaBaseConfig[var.shenmochoose]
	local rand = math.random(FubenConstConfig.randChangeTime[1],FubenConstConfig.randChangeTime[2])
	var.endTime = 0
	var.cd = System.getTick() + rand * 1000
	sendChangeSuperData(actor)
	actorevent.onEvent(actor, aeNotifyFacade)
end

--进入副本
function onEnterBefore(ins, actor)
    local var = getActorVar(actor)
    -- if ins.offlineShenmoCD ~= 0 then
    --     var.cd = ins.offlineShenmoCD
    --     var.endTime = 0
    --     sendShenmocData(actor)
    --     ins.offlineShenmoCD = 0
    --     return
    -- end
    if var.shenmochoose == 0 then return end
    if Fuben.checkFubenSign(ins.handle, FubenSign_IsSuperSpec) then
        local rand = math.random(FubenConstConfig.randChangeTime[1],FubenConstConfig.randChangeTime[2])
        var.endTime = 0
        var.cd = System.getTick() + rand * 1000
    elseif Fuben.checkFubenSign(ins.handle, FubenSign_NotSuperChange) then
        var.endTime = 0
        var.cd = System.getTick() + 99999 * 1000
    else
        local chooseConfig = ShenmoHuanhuaBaseConfig[var.shenmochoose]
        var.endTime = 0
        var.cd = System.getTick() + chooseConfig.scenecd * 1000     
    end    
end


--神魔升级魔阵
function mozhenUp(actor, pack)
	local id = LDataPack.readShort(pack)
	local var = getActorVar(actor)
	local conf = ShenmoMozhenBaseConfig[id]
	if not conf then return end
	if (var.mozhen[id] or 0) >= conf.maxLevel then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = ShenmoMozhenBaseConfig[id].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (var.mozhen[id] or 0) >= conf.maxLevel then
		count = conf.maxLevel - (var.mozhen[id] or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "mozhen level up")
    var.mozhen[id] = (var.mozhen[id] or 0) + count

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_SMMozhenUpRet)
	LDataPack.writeInt(pack, id)
	LDataPack.writeInt(pack, var.mozhen[id])
	LDataPack.flush(pack)
	
	if var.mozhen[id] == 1 then
		var.mozhenchoose = id
		sendMozhenChoose(actor)
		actorevent.onEvent(actor, aeNotifyFacade)
		-- if var.shenmochoose ~= 0 then
		-- 	LActor.setYonbingId(actor, var.shenmochoose, var.mozhenchoose)
		-- end
	end
    
    updateAttr(actor, true)
end


--幻化魔阵
function mozhenChange(actor, pack)
	local id = LDataPack.readChar(pack)
	local var = getActorVar(actor)
	if (var.mozhen[id] or 0) <= 0 then return end
	var.mozhenchoose = id
	sendMozhenChoose(actor)
	actorevent.onEvent(actor, aeNotifyFacade)
	-- if var.shenmochoose ~= 0 then
	-- 	LActor.setYonbingId(actor, var.shenmochoose, var.mozhenchoose)
	-- end
end

function sendMozhenChoose(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_SMMozhenChoose)
	LDataPack.writeInt(pack, var.mozhenchoose)
	LDataPack.flush(pack)
end

function setAutoChange(actor, pack)
	local staus = LDataPack.readChar(pack)
	local var = getActorVar(actor)
	var.autoChangeSuper = staus
	sendAutoChange(actor)
end

function sendAutoChange(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Shouhu, Protocol.sShouhuCmd_SMAutoChangeRet)
	LDataPack.writeChar(pack, var.autoChangeSuper or 0)
	LDataPack.flush(pack)
end

function onEnter(ins, actor)
	sendChangeSuperData(actor)
end

function onLogin(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenmo) then return end
    sendTotalInfo(actor)
    sendAutoChange(actor)
end

function onInit(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenmo) then return end
    updateAttr(actor, true)
end

function onSystemOpen(actor)
    local var = getActorVar(actor)
    if var.level ~= 0 then return end
	var.level = 1
	var.stage = 0
	var.shenmochoose = 1
	sendTotalInfo(actor)
	updateAttr(actor, true)
	actorevent.onEvent(actor, aeFacadeActive, 3, ShenmoHuanhuaBaseConfig[var.shenmochoose].quality)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)


local function init()
	for id in pairs(FubenConfig) do
		insevent.registerInstanceEnterBefore(id, onEnterBefore)
		insevent.registerInstanceEnter(id, onEnter)
	end
	newsystem.regSystemOpenFuncs(actorexp.LimitTp.shenmo, onSystemOpen)
	
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_SMChangeSuper, changeSuper)
	if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_SMLevelUp, levelUp)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_SMStageUp, stageUp)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_SMHuanhuaUp, huanhuaUp)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_SMUsePill, usePill)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_SMChange, change)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_SMMozhenUp, mozhenUp)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_SMMozhenChange, mozhenChange)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_SMSetAutoChange, setAutoChange)
	netmsgdispatcher.reg(Protocol.CMD_Shouhu, Protocol.cShouhuCmd_SMUseStageStone, useStone)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.shenmoAll = function (actor, args)
    local IsChange = false
    local var = getActorVar(actor)
    local maxlevel = #ShenmoLevelConfig
    if var.level < maxlevel then
        var.level = maxlevel
        local count = 0
        local exp = 0
        for level = 1, var.level - 1 do
            exp = exp + ShenmoLevelConfig[level].needexp
        end
        count = math.floor(exp / ShenmoConstConfig.leveladdexp)
        actorevent.onEvent(actor, aeShenmoLevel, var.level, count)
        IsChange = true
    end
    maxlevel = #ShenmoStageConfig
    if var.stage < maxlevel then
        var.stage = maxlevel
        local count = 0
        local exp = 0
        for stagelevel = 1, var.stage - 1 do
            exp = exp + ShenmoStageConfig[stagelevel].needexp
        end
        count = math.floor(exp / ShenmoConstConfig.stageaddexp)
        actorevent.onEvent(actor, aeShenmoStage, var.stage, count)
        IsChange = true
    end
    for id, conf in pairs(ShenmoHuanhuaBaseConfig) do
        maxlevel = conf.maxLevel
        if maxlevel > 0 and (var.huanhua[id] or 0) < maxlevel then
            var.huanhua[id] = maxlevel
            IsChange = true
        end
    end
    local actorLevel = LActor.getLevel(actor)
    for pillindex, conf in pairs(ShenmoPillConfig) do
        maxlevel = getMaxCanUse(pillindex, actorLevel)
        if (var.pilluse[pillindex] or 0) < maxlevel then
            var.pilluse[pillindex] = maxlevel
            IsChange = true
        end
    end
    for id, conf in pairs(ShenmoMozhenBaseConfig) do
        maxlevel = conf.maxLevel
        if (var.mozhen[id] or 0) < maxlevel then
            var.mozhen[id] = maxlevel
            IsChange = true
        end
    end
    for shenmo in pairs(ShenmoHuanhuaBaseConfig) do
        var.shenmochoose = math.max(var.shenmochoose, shenmo)
    end
    var.mozhenchoose = #ShenmoMozhenBaseConfig
    actorevent.onEvent(actor, aeFacadeActive, 3, ShenmoHuanhuaBaseConfig[var.shenmochoose].quality)
    if IsChange then
        onLogin(actor)
        updateAttr(actor, true)
    end
    return true
end
