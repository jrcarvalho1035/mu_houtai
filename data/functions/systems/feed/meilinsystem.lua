module("meilinsystem", package.seeall)

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.meilin then
        var.meilin = {} 
        var.meilin.level = 0
        var.meilin.huanhua = {}
        var.meilin.choose = -1 --当前幻化的梅林id
        var.meilin.pilluse = {}
        var.meilin.power = 0
    end

    return var.meilin
end

function getMeilinLv(actor)
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

    for k,v in pairs(MeilinHuanhuaBaseConfig) do          
        if (var.huanhua[k] or 0) > 0 then
            for kk,vv in ipairs(v.baseAttrs) do
                addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * var.huanhua[k]
            end
        end
    end

    for k,v in ipairs(MeilinPillConfig) do
        for kk,vv in ipairs(v.attr) do
            addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * (var.pilluse[k] or 0)
        end
    end
    if (var.level or 0) > 0 then
        for k,v in ipairs(MeilinLevelConfig[var.level].attr) do
            local add = addAttrs[Attribute.atMeilinTotal] or 0
            addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * (1+add/10000)
        end
    end

    for k,v in ipairs(MeilinConstConfig.skills) do
        local conf = SkillPassiveConfig[v][passiveskill.getSkillLv(actor, v)]
        if conf.type == 1 then
            for k,v in ipairs(conf.addattr) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value                
            end         
        end
        power = power + conf.power
    end

    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Meilin)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    attr:SetExtraPower(power)
    if isCalc then
        LActor.reCalcAttr(actor)
        if System.isCommSrv() then
            var.power = utils.getAttrPower0(addAttrs) + power
            utils.rankfunc.updateRankingList(actor, var.power, RankingType_Meilin)
            actorevent.onEvent(actor, aeChangeRankPower, var.power, subactivity4.minType.meilin)
        end
    end
end

function sendTotalInfo(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_MeilinInfo)
    LDataPack.writeInt(pack, var.choose)
    LDataPack.writeShort(pack, var.level)
    local count = 0
    local pos = LDataPack.getPosition(pack)
    LDataPack.writeInt(pack, count)
    for k,v in pairs(MeilinHuanhuaBaseConfig) do
        LDataPack.writeInt(pack, k)
        LDataPack.writeInt(pack, var.huanhua[k] or 0)
        count = count + 1
    end
    local npos = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, pos)
    LDataPack.writeInt(pack, count)
    LDataPack.setPosition(pack, npos)
    
    LDataPack.writeInt(pack, #MeilinPillConfig)
    for i=1, #MeilinPillConfig do
        LDataPack.writeInt(pack, var.pilluse[i] or 0)
    end
    
    LDataPack.flush(pack)
end

--梅林升级
function levelUp(actor, pack)
    local var = getActorVar(actor)
    if not MeilinLevelConfig[var.level + 1] then return end
    if not actoritem.checkItems(actor, MeilinLevelConfig[var.level].needitem) then
        return
    end
    actoritem.reduceItems(actor, MeilinLevelConfig[var.level].needitem, "meilin level up")
    var.level = var.level + 1

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_MeilinLevelUpRet)
    LDataPack.writeShort(pack, var.level)
    LDataPack.flush(pack)
    
    updateAttr(actor, true)
    actorevent.onEvent(actor, aeMeilinLevelUp, var.level)
end

--梅林升阶
function stageUp(actor, pack)
    local meilinid = LDataPack.readInt(pack)
    local var = getActorVar(actor)
    local conf = MeilinHuanhuaBaseConfig[meilinid]
    if not conf then return end
    if (var.huanhua[meilinid] or 0) >= conf.maxLevel then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = MeilinHuanhuaBaseConfig[meilinid].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (var.huanhua[meilinid] or 0) >= conf.maxLevel then
		count = conf.maxLevel - (var.huanhua[meilinid] or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "meilin stage up")
    var.huanhua[meilinid] = (var.huanhua[meilinid] or 0) + count

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_MeilinHHStageUpRet)
    LDataPack.writeInt(pack, meilinid)
    LDataPack.writeInt(pack, var.huanhua[meilinid])
    LDataPack.flush(pack)
    
    updateAttr(actor, true)

    if meilinid > var.choose then
        var.choose = meilinid
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_MeilinChangeRet)
        LDataPack.writeInt(pack, var.choose)
        LDataPack.flush(pack)
        LActor.setMeilin(actor, var.choose)
    end

    if var.huanhua[meilinid] == 1 then
        actorevent.onEvent(actor, aeFacadeActive, 7, MeilinHuanhuaBaseConfig[meilinid].quality)
    end
end

function getQualityCount(actor, quality)
    local var = getActorVar(actor)
    local count = 0
    for meilinid,v in pairs(MeilinHuanhuaBaseConfig) do
        if v.quality >= quality and (var.huanhua[meilinid] or 0) >= 1 then
            count = count + 1
        end
    end
    return count
end


local function getMaxCanUse(index, level)
    local conf = MeilinPillMaxConfig[index]
    for k,v in ipairs(conf) do
        if conf[k+1] and v.level <= level and conf[k+1].level > level then
            return v.max
        end
    end
    return conf[#conf].max
end

--梅林附魂
function usePill(actor, pack)
    local pillindex = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    local max = getMaxCanUse(pillindex, LActor.getLevel(actor))
	
	--função para chamar ID e contar a quantidade de itens
	local id = MeilinPillConfig[pillindex].itemuse[1]
	count = actoritem.getItemCount(actor, id)
	
	if count + (var.pilluse[pillindex] or 0) >= max then
		count = max - (var.pilluse[pillindex] or 0)
	end
	
	---
	
    if (var.pilluse[pillindex] or 0) >= max then return end

    if not actoritem.checkItems(actor, MeilinPillConfig[pillindex].needitem) then
        return
    end
    actoritem.reduceItem(actor, id, count, "meilin level up")

    var.pilluse[pillindex] = (var.pilluse[pillindex] or 0) + count

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_MeilinUsePillRet)
    LDataPack.writeInt(pack, pillindex)
    LDataPack.writeInt(pack, var.pilluse[pillindex])
    LDataPack.flush(pack)

    updateAttr(actor, true)
end

--梅林幻化
function change(actor, pack)
    local id = LDataPack.readInt(pack)
    local var = getActorVar(actor)
    if not var.huanhua[id] or var.huanhua[id] == 0 then return end

    var.choose = id
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_MeilinChangeRet)
    LDataPack.writeInt(pack, var.choose)
    LDataPack.flush(pack)
    LActor.setMeilin(actor, var.choose)
    actorevent.onEvent(actor, aeFacadeActive, 7, MeilinHuanhuaBaseConfig[id].quality)
end

function onLogin(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.meilin) then return end
    sendTotalInfo(actor)
end

function onInit(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.meilin) then return end    
    updateAttr(actor, true)
    local var = getActorVar(actor)
    LActor.setMeilin(actor, var.choose)
end

function onSystemOpen(actor, isnewday)
    local var = getActorVar(actor)
    if var.level ~= 0 then return end
    var.level = 1
    var.choose = 0
    sendTotalInfo(actor)
    updateAttr(actor, true)
    LActor.setMeilin(actor, var.choose, isnewday)
    actorevent.onEvent(actor, aeFacadeActive, 7, MeilinHuanhuaBaseConfig[var.choose].quality)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

local function init()   
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.meilin, onSystemOpen)

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_MeilinLevelUp, levelUp)
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_MeilinHHStageUp, stageUp)
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_MeilinUsePill, usePill)
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_MeilinChange, change)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.mlfuhunadd = function (actor, args)
    local tmp = tonumber(args[2])
    local var = getActorVar(actor)
    local pillindex = tonumber(args[1])
    for i=1,tmp do
        actoritem.addItems(actor, MeilinPillConfig[pillindex].needitem, "shenqi level up")
    end
end

gmCmdHandlers.mlshengjiadd = function (actor, args)
    local tmp = tonumber(args[1])
    local var = getActorVar(actor)
    for i=1,tmp do
        actoritem.addItems(actor, MeilinLevelConfig[var.level].needitem, "shenqi level up")
    end
end

gmCmdHandlers.mlshengjieadd = function (actor, args)
    local tmp = tonumber(args[2])
    local var = getActorVar(actor)
    local shenqiid = tonumber(args[1])
    for i=1,tmp do
    local item = MeilinHuanhuaBaseConfig[shenqiid][(var.huanhua[shenqiid] or 0)].needitem
    actoritem.addItems(actor, item, "shenqi stage up")
    end
end

gmCmdHandlers.meilinAll = function (actor, args)
    local IsChange = false
    local var = getActorVar(actor)
    local maxlevel = #MeilinLevelConfig
    if var.level < maxlevel then
        var.level = maxlevel
        actorevent.onEvent(actor, aeMeilinLevelUp, var.level)
        IsChange = true
    end
    for id,conf in pairs(MeilinHuanhuaBaseConfig) do
        maxlevel = conf.maxLevel
        if (var.huanhua[id] or 0) < maxlevel then
            var.huanhua[id] = maxlevel
            actorevent.onEvent(actor, aeFacadeActive, 7, MeilinHuanhuaBaseConfig[id].quality)
            IsChange = true
        end
    end
    local actorLevel = LActor.getLevel(actor)
    for pillindex,conf in pairs(MeilinPillConfig) do
        maxlevel = getMaxCanUse(pillindex, actorLevel)
        if (var.pilluse[pillindex] or 0) < maxlevel then
            var.pilluse[pillindex] = maxlevel
            IsChange = true
        end
    end
    if var.choose ~= #MeilinHuanhuaBaseConfig then
        var.choose = #MeilinHuanhuaBaseConfig
    end
    if IsChange then
        onLogin(actor)
        updateAttr(actor, true)
    end
    return true
end


