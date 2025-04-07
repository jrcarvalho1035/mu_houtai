module("shenzhuangsystem", package.seeall)

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.shenzhuang then
        var.shenzhuang = {}
        var.shenzhuang.level = 0
        var.shenzhuang.huanhua = {}
        var.shenzhuang.choose = 0 --当前幻化的神装id
        var.shenzhuang.pilluse = {}
        var.shenzhuang.power = 0
    end

    return var.shenzhuang
end

function getShenzhuangLv(actor)
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

    for k,v in pairs(SzHuanhuaBaseConfig) do   
        if (var.huanhua[k] or 0) > 0 then
            for kk,vv in ipairs(v.baseAttrs) do
                addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * var.huanhua[k]
            end
        end
    end

    for k,v in ipairs(SzPillConfig) do
        for kk,vv in ipairs(v.attr) do
            addAttrs[vv.type] = (addAttrs[vv.type] or 0) + vv.value * (var.pilluse[k] or 0)
        end
    end

    if (var.level or 0) > 0 then
        for k,v in ipairs(SzLevelConfig[var.level].attr) do
            local add = addAttrs[Attribute.atSzTotal] or 0
            addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * (1+add/10000)
        end
    end

    for k,v in ipairs(SzConstConfig.skills) do
        local conf = SkillPassiveConfig[v][passiveskill.getSkillLv(actor, v)]
        if conf.type == 1 then
            for k,v in ipairs(conf.addattr) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value                
            end         
        end
        power = power + conf.power
    end
    
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Shenzhuang)
    attr:Reset()
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end
    attr:SetExtraPower(power)
    if isCalc then
        LActor.reCalcAttr(actor)     
        if System.isCommSrv() then
            var.power = utils.getAttrPower0(addAttrs) + power
            utils.rankfunc.updateRankingList(actor, var.power, RankingType_Shenzhuang)
            actorevent.onEvent(actor, aeChangeRankPower, var.power, subactivity4.minType.shenzhuang)
        end   
    end 
end

function sendTotalInfo(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_ShenzhuangInfo)
    LDataPack.writeInt(pack, var.choose)
    LDataPack.writeShort(pack, var.level)
    local count = 0
    local pos = LDataPack.getPosition(pack)
    LDataPack.writeInt(pack, count)
    for k,v in pairs(SzHuanhuaBaseConfig) do
        LDataPack.writeInt(pack, k)
        LDataPack.writeInt(pack, var.huanhua[k] or 0)
        count = count + 1
    end
    local npos = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, pos)
    LDataPack.writeInt(pack, count)
    LDataPack.setPosition(pack, npos)
    
    LDataPack.writeInt(pack, #SzPillConfig)
    for i=1, #SzPillConfig do
        LDataPack.writeInt(pack, var.pilluse[i] or 0)
    end
    
    LDataPack.flush(pack)
end

--神装升级
function levelUp(actor, pack)
    local var = getActorVar(actor)
    if not SzLevelConfig[var.level + 1] then return end
    if not actoritem.checkItems(actor, SzLevelConfig[var.level].needitem) then
        return
    end
    actoritem.reduceItems(actor, SzLevelConfig[var.level].needitem, "shenzhuang level up")
    var.level = var.level + 1

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_ShenzhuangLevelUpRet)
    LDataPack.writeShort(pack, var.level)
    LDataPack.flush(pack)
    
    updateAttr(actor, true)
    actorevent.onEvent(actor, aeShenzhuangLevelUp, var.level)
end

--神装升阶
function stageUp(actor, pack)
    local shenzhuangid = LDataPack.readInt(pack)
    local var = getActorVar(actor)
    local conf = SzHuanhuaBaseConfig[shenzhuangid]
    if not conf then return end
    if (var.huanhua[shenzhuangid] or 0) >= conf.maxLevel then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = SzHuanhuaBaseConfig[shenzhuangid].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (var.huanhua[shenzhuangid] or 0) >= conf.maxLevel then
		count = conf.maxLevel - (var.huanhua[shenzhuangid] or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, idz, count, "shenzhuang stage up")
    var.huanhua[shenzhuangid] = (var.huanhua[shenzhuangid] or 0) + count

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_ShenzhuangHHStageUpRet)
    LDataPack.writeInt(pack, shenzhuangid)
    LDataPack.writeInt(pack, var.huanhua[shenzhuangid])
    LDataPack.flush(pack)
    
    updateAttr(actor, true)

    if shenzhuangid > var.choose then
        var.choose = shenzhuangid
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_ShenzhuangChangeRet)
        LDataPack.writeInt(pack, var.choose)
        LDataPack.flush(pack)
        actorevent.onEvent(actor, aeNotifyFacade)
    end

    if var.huanhua[shenzhuangid] == 1 then
        actorevent.onEvent(actor, aeFacadeActive, 6, SzHuanhuaBaseConfig[shenzhuangid].quality)
    end
end

function getQualityCount(actor, quality)
    local var = getActorVar(actor)
    local count = 0
    for shenzhuangid,v in pairs(SzHuanhuaBaseConfig) do
        if v.quality >= quality and (var.huanhua[shenzhuangid] or 0) >= 1 then
            count = count + 1
        end
    end
    return count
end


local function getMaxCanUse(index, level)
    local conf = SzPillMaxConfig[index]
    for k,v in ipairs(conf) do
        if conf[k+1] and v.level <= level and conf[k+1].level > level then
            return v.max
        end
    end
    return conf[#conf].max
end

--神装附魂
function usePill(actor, pack)
    local pillindex = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    local max = getMaxCanUse(pillindex, LActor.getLevel(actor))
	
	--função para chamar ID e contar a quantidade de itens
	local id = SzPillConfig[pillindex].itemuse[1]
	count = actoritem.getItemCount(actor, id)
	
	if count + (var.pilluse[pillindex] or 0) >= max then
		count = max - (var.pilluse[pillindex] or 0)
	end
	
	---
	
    if (var.pilluse[pillindex] or 0) >= max then return end

    if not actoritem.checkItems(actor, SzPillConfig[pillindex].needitem) then
        return
    end
    actoritem.reduceItem(actor, id, count, "shenzhuang level up")

    var.pilluse[pillindex] = (var.pilluse[pillindex] or 0) + count

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_ShenzhuangUsePillRet)
    LDataPack.writeInt(pack, pillindex)
    LDataPack.writeInt(pack, var.pilluse[pillindex])
    LDataPack.flush(pack)

    updateAttr(actor, true)
end

--神装幻化
function change(actor, pack)
    local id = LDataPack.readInt(pack)
    local var = getActorVar(actor)
    if not var.huanhua[id] or var.huanhua[id] == 0 then return end

    var.choose = id
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Feed, Protocol.sFeedCmd_ShenzhuangChangeRet)
    LDataPack.writeInt(pack, var.choose)
    LDataPack.flush(pack)
    actorevent.onEvent(actor, aeNotifyFacade)
end

function onLogin(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenzhuang) then return end
    sendTotalInfo(actor)
end

function onInit(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenzhuang) then return end
    updateAttr(actor, true)
end

function getShenzhuangId(actor)
    local var = getActorVar(actor)
    return var.choose
end
_G.getShenzhuangId = getShenzhuangId

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
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.shenzhuang, onSystemOpen)

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_ShenzhuangLevelUp, levelUp)
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_ShenzhuangHHStageUp, stageUp)
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_ShenzhuangUsePill, usePill)
    netmsgdispatcher.reg(Protocol.CMD_Feed, Protocol.cFeedCmd_ShenzhuangChange, change)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.szfuhunadd = function (actor, args)
    local tmp = tonumber(args[2])
    local var = getActorVar(actor)
    local pillindex = tonumber(args[1])
    for i=1,tmp do
        actoritem.addItems(actor, SzPillConfig[pillindex].needitem, "shenqi level up")
    end
end

gmCmdHandlers.szshengjiadd = function (actor, args)
    local tmp = tonumber(args[1])
    local var = getActorVar(actor)
    for i=1,tmp do
        actoritem.addItems(actor, SzLevelConfig[var.level].needitem, "shenqi level up")
    end
end

gmCmdHandlers.szshengjieadd = function (actor, args)
    local tmp = tonumber(args[2])
    local var = getActorVar(actor)
    local shenqiid = tonumber(args[1])
    for i=1,tmp do
    local item = SzHuanhuaBaseConfig[shenqiid][(var.huanhua[shenqiid] or 0)].needitem
    actoritem.addItems(actor, item, "shenqi stage up")
    end
end

gmCmdHandlers.shenzhuangAll = function (actor, args)
    local IsChange = false
    local var = getActorVar(actor)
    local maxlevel = #SzLevelConfig
    if var.level < maxlevel then
        var.level = maxlevel
        actorevent.onEvent(actor, aeShenzhuangLevelUp, var.level)
        IsChange = true
    end
    for id, conf in pairs(SzHuanhuaBaseConfig) do
        maxlevel = conf.maxLevel
        if (var.huanhua[id] or 0) < maxlevel then
            var.huanhua[id] = maxlevel
            actorevent.onEvent(actor, aeFacadeActive, 6, SzHuanhuaBaseConfig[id].quality)
            IsChange = true
        end
    end
    local actorLevel = LActor.getLevel(actor)
    for pillindex, conf in pairs(SzPillConfig) do
        maxlevel = getMaxCanUse(pillindex, actorLevel)
        if (var.pilluse[pillindex] or 0) < maxlevel then
            var.pilluse[pillindex] = maxlevel
            IsChange = true
        end
    end
    if var.choose ~= #SzHuanhuaBaseConfig then
        var.choose = #SzHuanhuaBaseConfig
        actorevent.onEvent(actor, aeNotifyFacade)
    end
    if IsChange then
        onLogin(actor)
        updateAttr(actor, true)
    end
    return true
end
