module("wingsystem", package.seeall)

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.wing then
        var.wing = {} 
        var.wing.level = 0
        var.wing.huanhua = {}
        var.wing.choose = 0 --当前幻化的翅膀id
        var.wing.pilluse = {}
        var.wing.power = 0
    end

    return var.wing
end

function getWingLv(actor)
    local var = getActorVar(actor)
    return var.level
end

function getPower(actor)
    local var = getActorVar(actor)
    return var.power
end

function updateAttr(actor, isCalc)
    local var = getActorVar(actor)
    local addAttrs = {}
    local power = 0

    for k,v in pairs(WingHuanhuaBaseConfig) do  
        if (var.huanhua[k] or 0) > 0 then
            for kk,vv in ipairs(v.baseAttrs) do
                addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * var.huanhua[k]
            end
        end
    end

    for k,v in ipairs(WingPillConfig) do
        for kk,vv in ipairs(v.attr) do
            addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * (var.pilluse[k] or 0)
        end
    end

    if (var.level or 0) > 0 then
        for k,v in ipairs(WingLevelConfig[var.level].attr) do
            local add = addAttrs[Attribute.atWingTotal] or 0
            addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * (1+add/10000)
        end
    end

    for k,v in ipairs(WingConstConfig.skills) do
        local conf = SkillPassiveConfig[v][passiveskill.getSkillLv(actor, v)]
        if conf.type == 1 then
            for k,v in ipairs(conf.addattr) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value                
            end         
        end
        power = power + conf.power
    end

    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Wing)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    attr:SetExtraPower(power)
    if isCalc then
        LActor.reCalcAttr(actor)   
        if System.isCommSrv() then
            var.power = utils.getAttrPower0(addAttrs) + power        
            utils.rankfunc.updateRankingList(actor, var.power, RankingType_Wing)
            actorevent.onEvent(actor, aeChangeRankPower, var.power, subactivity4.minType.wing)
        end     
    end 
end

function sendTotalInfo(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_WingInfo)
    LDataPack.writeInt(pack, var.choose)
    LDataPack.writeShort(pack, var.level)
    local count = 0
    local pos = LDataPack.getPosition(pack)
    LDataPack.writeInt(pack, count)
    for k,v in pairs(WingHuanhuaBaseConfig) do
        LDataPack.writeInt(pack, k)
        LDataPack.writeInt(pack, var.huanhua[k] or 0)
        count = count + 1
    end
    local npos = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, pos)
    LDataPack.writeInt(pack, count)
    LDataPack.setPosition(pack, npos)
    
    LDataPack.writeInt(pack, #WingPillConfig)
    for i=1, #WingPillConfig do
        LDataPack.writeInt(pack, var.pilluse[i] or 0)
    end
    
    LDataPack.flush(pack)
end

--翅膀升级
function levelUp(actor, pack)
    local var = getActorVar(actor)
    if not WingLevelConfig[var.level + 1] then return end
    if not actoritem.checkItems(actor, WingLevelConfig[var.level].needitem) then
        return
    end
    actoritem.reduceItems(actor, WingLevelConfig[var.level].needitem, "wing level up")
    var.level = var.level + 1

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_WingLevelUpRet)
    LDataPack.writeShort(pack, var.level)
    LDataPack.flush(pack)
    actorevent.onEvent(actor, aeWingLevelUp, var.level)
    updateAttr(actor, true)
end

--翅膀升阶
function stageUp(actor, pack)
    local wingid = LDataPack.readInt(pack)
    local var = getActorVar(actor)
    local conf = WingHuanhuaBaseConfig[wingid]
    if not conf then return end
    if (var.huanhua[wingid] or 0) >= conf.maxLevel then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = WingHuanhuaBaseConfig[wingid].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (var.huanhua[wingid] or 0) >= conf.maxLevel then
		count = conf.maxLevel - (var.huanhua[wingid] or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "wing stage up")
    var.huanhua[wingid] = (var.huanhua[wingid] or 0) + count

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_WingHHStageUpRet)
    LDataPack.writeInt(pack, wingid)
    LDataPack.writeInt(pack, var.huanhua[wingid])
    LDataPack.flush(pack)    

    updateAttr(actor, true)

    if wingid > var.choose then
        var.choose = wingid
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_WingChangeRet)
        LDataPack.writeInt(pack, var.choose)
        LDataPack.flush(pack)
        actorevent.onEvent(actor, aeNotifyFacade)
    end

    if var.huanhua[wingid] == 1 then
        actorevent.onEvent(actor, aeFacadeActive, 5, WingHuanhuaBaseConfig[wingid].quality)
    end
end

function getQualityCount(actor, quality)
    local var = getActorVar(actor)
    local count = 0
    for wingid,v in pairs(WingHuanhuaBaseConfig) do
        if v.quality >= quality and (var.huanhua[wingid] or 0) >= 1 then
            count = count + 1
        end
    end
    return count
end

local function getMaxCanUse(index, level)
    local conf = WingPillMaxConfig[index]
    for k,v in ipairs(conf) do
        if conf[k+1] and v.level <= level and conf[k+1].level > level then
            return v.max
        end
    end
    return conf[#conf].max
end

--翅膀附魂
function usePill(actor, pack)
    local pillindex = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    local max = getMaxCanUse(pillindex, LActor.getLevel(actor))
	
	--função para chamar ID e contar a quantidade de itens
	local id = WingPillConfig[pillindex].itemuse[1]
	count = actoritem.getItemCount(actor, id)
	
	if count + (var.pilluse[pillindex] or 0) >= max then
		count = max - (var.pilluse[pillindex] or 0)
	end
	
	---
	
    if (var.pilluse[pillindex] or 0) >= max then return end

    if not actoritem.checkItems(actor, WingPillConfig[pillindex].needitem) then
        return
    end
    actoritem.reduceItem(actor, id, count, "wing level up")

    var.pilluse[pillindex] = (var.pilluse[pillindex] or 0) + count

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_WingUsePillRet)
    LDataPack.writeInt(pack, pillindex)
    LDataPack.writeInt(pack, var.pilluse[pillindex])
    LDataPack.flush(pack)

    updateAttr(actor, true)
end

--翅膀幻化
function change(actor, pack)
    local id = LDataPack.readInt(pack)
    local var = getActorVar(actor)
    if not var.huanhua[id] or var.huanhua[id] == 0 then return end

    var.choose = id
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_WingChangeRet)
    LDataPack.writeInt(pack, var.choose)
    LDataPack.flush(pack)
    actorevent.onEvent(actor, aeNotifyFacade)
end

function getWingId(actor)
    local var = getActorVar(actor)
    return var.choose
end

_G.getWingId = getWingId
function onLogin(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.wing) then return end
    sendTotalInfo(actor)
end

function onInit(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.wing) then return end
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

local function init()
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.wing, onSystemOpen)

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_WingLevelUp, levelUp)
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_WingHHStageUp, stageUp)
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_WingUsePill, usePill)
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_WingChange, change)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.wingfuhunadd = function (actor, args)
    local tmp = tonumber(args[2])
    local var = getActorVar(actor)
    local pillindex = tonumber(args[1])
    for i=1,tmp do
        actoritem.addItems(actor, WingPillConfig[pillindex].needitem, "shenqi level up")
    end
end

gmCmdHandlers.wingshengjiadd = function (actor, args)
    local tmp = tonumber(args[1])
    local var = getActorVar(actor)
    for i=1,tmp do
        actoritem.addItems(actor, WingLevelConfig[var.level].needitem, "shenqi level up")
    end
end

gmCmdHandlers.wingshengjieadd = function (actor, args)
    local tmp = tonumber(args[2])
    local var = getActorVar(actor)
    local shenqiid = tonumber(args[1])
    for i=1,tmp do
    local item = WingHuanhuaBaseConfig[shenqiid][(var.huanhua[shenqiid] or 0)].needitem
    actoritem.addItems(actor, item, "shenqi stage up")
    end
end

gmCmdHandlers.wingAll = function (actor, args)
    local IsChange = false
    local var = getActorVar(actor)
    local maxlevel = #WingLevelConfig
    if var.level < maxlevel then
        var.level = maxlevel
        actorevent.onEvent(actor, aeWingLevelUp, var.level)
        IsChange = true
    end
    for id,conf in pairs(WingHuanhuaBaseConfig) do
        maxlevel = conf.maxLevel
        if (var.huanhua[id] or 0) < maxlevel then
            var.huanhua[id] = maxlevel
            actorevent.onEvent(actor, aeFacadeActive, 5, WingHuanhuaBaseConfig[id].quality)
            IsChange = true
        end
    end
    local actorLevel = LActor.getLevel(actor)
    for pillindex,conf in pairs(WingPillConfig) do
        maxlevel = getMaxCanUse(pillindex, actorLevel)
        if (var.pilluse[pillindex] or 0) < maxlevel then
            var.pilluse[pillindex] = maxlevel
            IsChange = true
        end
    end
    if var.choose ~= #WingHuanhuaBaseConfig then
        var.choose = #WingHuanhuaBaseConfig
        actorevent.onEvent(actor, aeNotifyFacade)
    end
    if IsChange then
        onLogin(actor)
        updateAttr(actor, true)
    end
    return true
end
