module("shenqisystem", package.seeall)

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.shenqi then
        var.shenqi = {} ----命名空间
        var.shenqi.level = 0----神器等级
        var.shenqi.huanhua = {}----神器幻化
        var.shenqi.choose = 0 --当前幻化的神器id
        var.shenqi.pilluse = {}----神器附魂使用
        var.shenqi.tmpchoose = 0 --临时幻化武器
        var.shenqi.power = 0
    end

    return var.shenqi
end

function getShenqiLv(actor)----获得神器等级
    local var = getActorVar(actor)
    return var.level
end

function getPower(actor)
    local var = getActorVar(actor)
    return var.power
end

function updateAttr(actor, isCalc)----升级后的属性
    local var = getActorVar(actor)
    local addAttrs = {}
    local power = 0

    for k,v in pairs(ShenqiHuanhuaBaseConfig) do         
        if (var.huanhua[k] or 0) > 0 then
            for kk,vv in ipairs(v.baseAttrs) do
                addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * var.huanhua[k]
            end
        end
    end

    for k,v in ipairs(ShenqiPillConfig) do
        for kk,vv in ipairs(v.attr) do
            addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * (var.pilluse[k] or 0)
        end
    end

    if (var.level or 0) > 0 then
        for k,v in ipairs(ShenqiLevelConfig[var.level or 0].attr) do
            local add = addAttrs[Attribute.atShenqiTotal] or 0
            addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * (1+add/10000)
        end
    end
    for k,v in ipairs(ShenqiConstConfig.skills) do
        local conf = SkillPassiveConfig[v][passiveskill.getSkillLv(actor, v)]
        if conf.type == 1 then
            for k,v in ipairs(conf.addattr) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value                
            end         
        end
        power = power + conf.power
    end

    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Shenqi)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    attr:SetExtraPower(power)
    if isCalc then
        LActor.reCalcAttr(actor)  
        if System.isCommSrv() then
            var.power = utils.getAttrPower0(addAttrs) + power
            utils.rankfunc.updateRankingList(actor, var.power, RankingType_Shenqi)
            actorevent.onEvent(actor, aeChangeRankPower, var.power, subactivity4.minType.shenqi)
        end      
    end
end

function sendTotalInfo(actor)----发送完整的配置
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_SQInfo)
    LDataPack.writeInt(pack, var.choose)
    LDataPack.writeShort(pack, var.level)
    local count = 0
    local pos = LDataPack.getPosition(pack)
    LDataPack.writeInt(pack, count)
    for k,v in pairs(ShenqiHuanhuaBaseConfig) do
        LDataPack.writeInt(pack, k)
        LDataPack.writeInt(pack, var.huanhua[k] or 0)
        count = count + 1
    end
    local npos = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, pos)
    LDataPack.writeInt(pack, count)
    LDataPack.setPosition(pack, npos)
    
    LDataPack.writeInt(pack, #ShenqiPillConfig)
    for i=1, #ShenqiPillConfig do
        LDataPack.writeInt(pack, var.pilluse[i] or 0)
    end
    
    LDataPack.flush(pack)
end

--神器升级
function levelUp(actor, pack)
    local var = getActorVar(actor)
    if not ShenqiLevelConfig[var.level + 1] then return end
    if not actoritem.checkItems(actor, ShenqiLevelConfig[var.level].needitem) then
        return
    end
    actoritem.reduceItems(actor, ShenqiLevelConfig[var.level].needitem, "shenqi level up")
    var.level = var.level + 1

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_SQLevelUpRet)
    LDataPack.writeShort(pack, var.level)
    LDataPack.flush(pack)
    
    updateAttr(actor, true)
    actorevent.onEvent(actor, aeShenqiLevelUp, var.level)
end

--神器升阶
function stageUp(actor, pack)
    local shenqiid = LDataPack.readInt(pack)
    local var = getActorVar(actor)
    local conf = ShenqiHuanhuaBaseConfig[shenqiid]
    if not conf then return end
    if (var.huanhua[shenqiid] or 0) >= conf.maxLevel then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = ShenqiHuanhuaBaseConfig[shenqiid].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (var.huanhua[shenqiid] or 0) >= conf.maxLevel then
		count = conf.maxLevel - (var.huanhua[shenqiid] or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "shenqi stage up")
    var.huanhua[shenqiid] = (var.huanhua[shenqiid] or 0) + count
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_SQHHStageUpRet)
    LDataPack.writeInt(pack, shenqiid)
    LDataPack.writeInt(pack, var.huanhua[shenqiid])
    LDataPack.flush(pack)
    
    updateAttr(actor, true)

    if shenqiid > var.choose then
        var.choose = shenqiid
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_SQChangeRet)
        LDataPack.writeInt(pack, var.choose)
        LDataPack.flush(pack)
        actorevent.onEvent(actor, aeNotifyFacade)
    end

    if var.huanhua[shenqiid] == 1 then
        actorevent.onEvent(actor, aeFacadeActive, 4, ShenqiHuanhuaBaseConfig[shenqiid].quality)
    end
end

function getQualityCount(actor, quality)
    local var = getActorVar(actor)
    local count = 0
    for shenqiid,v in pairs(ShenqiHuanhuaBaseConfig) do
        if v.quality >= quality and (var.huanhua[shenqiid] or 0) >= 1 then
            count = count + 1
        end
    end
    return count
end

local function getMaxCanUse(index, level)
    local conf = ShenqiPillMaxConfig[index]
    for k,v in ipairs(conf) do
        if conf[k+1] and v.level <= level and conf[k+1].level > level then
            return v.max
        end
    end
    return conf[#conf].max
end

--神器附魂
function usePill(actor, pack)
    local pillindex = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    local max = getMaxCanUse(pillindex, LActor.getLevel(actor))
	
	--função para chamar ID e contar a quantidade de itens
	local id = ShenqiPillConfig[pillindex].itemuse[1]
	count = actoritem.getItemCount(actor, id)
	
	if count + (var.pilluse[pillindex] or 0) >= max then
		count = max - (var.pilluse[pillindex] or 0)
	end
	
	---
	
    if (var.pilluse[pillindex] or 0) >= max then return end

    if not actoritem.checkItems(actor, ShenqiPillConfig[pillindex].needitem) then
        return
    end
    actoritem.reduceItem(actor, id, count, "shenqi level up")

    var.pilluse[pillindex] = (var.pilluse[pillindex] or 0) + count

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_SQUsePillRet)
    LDataPack.writeInt(pack, pillindex)
    LDataPack.writeInt(pack, var.pilluse[pillindex])
    LDataPack.flush(pack)

    updateAttr(actor, true)
end

--神器幻化
function change(actor, pack)
    local id = LDataPack.readInt(pack)
    local var = getActorVar(actor)
    if not var.huanhua[id] or var.huanhua[id] == 0 then return end

    var.choose = id
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_SQChangeRet)
    LDataPack.writeInt(pack, var.choose)
    LDataPack.flush(pack)
    actorevent.onEvent(actor, aeNotifyFacade)
end

function getShenqiId(actor)
    local var = getActorVar(actor)
    return var.tmpchoose ~= 0 and var.tmpchoose or var.choose
end

function onLogin(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenqi) then return end
    local var = getActorVar(actor)
    var.tmpchoose = 0
    sendTotalInfo(actor)
end

function onInit(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenqi) then return end
    updateAttr(actor, true)
end

function onSystemOpen(actor)
    local var = getActorVar(actor)
    if var.level ~= 0 then return end
    var.level = 1
    sendTotalInfo(actor)
    updateAttr(actor, true)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

_G.getShenqiId = getShenqiId
local function init(actor)    
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.shenqi, onSystemOpen)

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_SQLevelUp, levelUp)
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_SQHHStageUp, stageUp)
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_SQUsePill, usePill)
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_SQChange, change)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.sqfuhunadd = function (actor, args)
    local tmp = tonumber(args[2])
    local var = getActorVar(actor)
    local pillindex = tonumber(args[1])
    for i=1,tmp do
        actoritem.addItems(actor, ShenqiPillConfig[pillindex].needitem, "shenqi level up")
    end
end

gmCmdHandlers.sqshengjiadd = function (actor, args)
    local tmp = tonumber(args[1])
    local var = getActorVar(actor)
    for i=1,tmp do
        actoritem.addItems(actor, ShenqiLevelConfig[var.level].needitem, "shenqi level up")
    end
end

gmCmdHandlers.sqshengjieadd = function (actor, args)
    local tmp = tonumber(args[2])
    local var = getActorVar(actor)
    local shenqiid = tonumber(args[1])
    for i=1,tmp do
    local item = ShenqiHuanhuaBaseConfig[shenqiid][(var.huanhua[shenqiid] or 0)].needitem
    actoritem.addItems(actor, item, "shenqi stage up")
    end
end

gmCmdHandlers.shenqiAll = function (actor, args)
    local IsChange = false
    local var = getActorVar(actor)
    local maxlevel = #ShenqiLevelConfig
    if var.level < maxlevel then
        var.level = maxlevel
        actorevent.onEvent(actor, aeShenqiLevelUp, var.level)
        IsChange = true
    end
    for id,conf in pairs(ShenqiHuanhuaBaseConfig) do
        maxlevel = conf.maxLevel
        if (var.huanhua[id] or 0) < maxlevel then
            var.huanhua[id] = maxlevel
            actorevent.onEvent(actor, aeFacadeActive, 4, ShenqiHuanhuaBaseConfig[id].quality)
            IsChange = true
        end
    end
    local actorLevel = LActor.getLevel(actor)
    for pillindex,conf in pairs(ShenqiPillConfig) do
        maxlevel = getMaxCanUse(pillindex, actorLevel)
        if (var.pilluse[pillindex] or 0) < maxlevel then
            var.pilluse[pillindex] = maxlevel
            IsChange = true
        end
    end
    if var.choose ~= #ShenqiHuanhuaBaseConfig then
        var.choose = #ShenqiHuanhuaBaseConfig
        actorevent.onEvent(actor, aeNotifyFacade)
    end
    if IsChange then
        onLogin(actor)
        updateAttr(actor, true)
    end
    return true
end
