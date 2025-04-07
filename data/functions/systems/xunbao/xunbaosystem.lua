module("xunbaosystem", package.seeall)

local First_Draw_Mutli = 1 --首次连抽时
local Draw_Mutli = 2 --连抽X次时

Total_Record = Total_Record or {}
Self_Record = Self_Record or {}
local Max_Self_Record = 100
local Max_All_Record = 20

function getActorVar(actor, id)
    local var = LActor.getStaticVar(actor)
    if not var.xunbao then var.xunbao = {} end
    if not var.xunbao[id] then
        var.xunbao[id] = {}
        var.xunbao[id].existip = 0 --寻宝兑换是否提醒
        var.xunbao[id].score = 0 --寻宝积分
        var.xunbao[id].firstget = 0 --第三个首抽必得是否已领取，0未，1已
        var.xunbao[id].dailyfirst = 0 --每日免费首抽是否已使用
        var.xunbao[id].lucky = 0 --当前幸运值
        var.xunbao[id].luckytimes = 0 --第几次抽幸运值奖励
    end
    if not Total_Record[id] then Total_Record[id] = {} end
    if not Self_Record[id] then Self_Record[id] = {} end
    if not Self_Record[id][LActor.getActorId(actor)] then Self_Record[id][LActor.getActorId(actor)] = {} end
    return var.xunbao[id]
end

function s2cXunbaoInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Xunbao, Protocol.sXunbaoCmd_Info)
    LDataPack.writeChar(pack, #XunbaoExchangeConfig)
    for k, v in ipairs(XunbaoExchangeConfig) do
        local var = getActorVar(actor, k)
        LDataPack.writeChar(pack, k)
        LDataPack.writeChar(pack, var.firstget)
        LDataPack.writeChar(pack, var.dailyfirst)
        LDataPack.writeShort(pack, var.lucky)
        LDataPack.writeInt(pack, var.score)
        LDataPack.writeInt(pack, var.existip)
    end
    LDataPack.flush(pack)
end

--提醒修改
function c2sChangeTip(actor, pack)
    local id = LDataPack.readChar(pack)
    local index = LDataPack.readChar(pack)
    if not XunbaoExchangeConfig[id] then return end
    if not XunbaoExchangeConfig[id][index] then return end
    index = index - 1
    
    local var = getActorVar(actor, id)
    if System.bitOPMask(var.existip, index) then
        var.existip = System.bitOpSetMask(var.existip, index, false)
    else
        var.existip = System.bitOpSetMask(var.existip, index, true)
    end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Xunbao, Protocol.sXunbaoCmd_UpdateChange)
    LDataPack.writeChar(npack, id)
    LDataPack.writeInt(npack, var.existip)
    LDataPack.flush(npack)
end

--兑换
function c2sExchange(actor, pack)
    local id = LDataPack.readChar(pack)
    local index = LDataPack.readChar(pack)
    if not XunbaoExchangeConfig[id] then return end
    if not XunbaoExchangeConfig[id][index] then return end
    local config = XunbaoExchangeConfig[id][index]
    local var = getActorVar(actor, id)
    
    if var.score < config.score then return end
    
    local itemConf = ItemConfig[config.item.id]
    --空间不足时不能兑换
    if itemConf and actoritem.isEquip(itemConf) then
        local space = LActor.getEquipBagSpace(actor)
        if space < 1 then
            LActor.sendTipmsg(actor, string.format(ScriptTips.bag01), ttScreenCenter)
            return
        end
    elseif itemConf and actoritem.isElement(itemConf) then
        local space = LActor.getElementBagSpace(actor)
        if space < 1 then
            LActor.sendTipmsg(actor, string.format(ScriptTips.bag01), ttScreenCenter)
            return
        end
    end
    
    var.score = var.score - config.score
    actoritem.addItem(actor, config.item.id, config.item.count)
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Xunbao, Protocol.sXunbaoCmd_Exchange)
    LDataPack.writeChar(npack, id)
    LDataPack.writeChar(npack, index)
    LDataPack.writeInt(npack, var.score)
    LDataPack.flush(npack)
end

--获取记录
function c2sGetRecord(actor, pack)
    local id = LDataPack.readChar(pack)
    local type = LDataPack.readChar(pack)
    if not XunbaoExchangeConfig[id] then return end
    s2cRecordInfo(actor, id, type)
end

function s2cRecordInfo(actor, id, type)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Xunbao, Protocol.sXunbaoCmd_RecordInfo)
    LDataPack.writeChar(npack, id)
    LDataPack.writeChar(npack, type)
    if type == 0 then
        local actorid = LActor.getActorId(actor)
        if not Self_Record[id] then Self_Record[id] = {} end
        if not Self_Record[id][actorid] then Self_Record[id][actorid] = {} end
        LDataPack.writeChar(npack, #Self_Record[id][actorid])
        for k, v in ipairs(Self_Record[id][actorid]) do
            LDataPack.writeString(npack, v.name)
            LDataPack.writeInt(npack, v.id)
            LDataPack.writeInt(npack, v.count)
        end
    else
        if not Total_Record[id] then Total_Record[id] = {} end
        LDataPack.writeChar(npack, #Total_Record[id])
        for k, v in ipairs(Total_Record[id]) do
            LDataPack.writeString(npack, v.name)
            LDataPack.writeInt(npack, v.id)
            LDataPack.writeInt(npack, v.count)
        end
    end
    LDataPack.flush(npack)
end

function getConfig(id)
    if id == 1 then
        return XunbaoEquipConfig, subactivity12.minType.equipXB
    elseif id == 2 then
        return XunbaoHunqiConfig, subactivity12.minType.hunqiXB
    elseif id == 3 then
        return XunbaoElementConfig, subactivity12.minType.fuwenXB
    elseif id == 4 then
        return XunbaoDianfengConfig, subactivity12.minType.dianfengXB
    elseif id == 5 then
        return XunbaoZhizhunConfig, subactivity12.minType.zhizunXB
    elseif id == 6 then
        return XunbaoLingqiConfig, 0
    end
end

--获取抽奖道具
function draw(actor, items, config, id, isact, actType)
    local isOpen = subactivity12.checkIsStart(actType)
    local rand = System.getRandomNumber(10000) + 1
    local total = 0
    for k, v in ipairs(config) do
        local pro = 0
        if isOpen then
            pro = v.probability3
        else
            pro = isact and v.probability1 or v.probability2
        end
        total = total + pro
        if rand <= total then
            items[#items + 1] = config[k].item
            items[#items].xiyou = config[k].xiyou
            local actorid = LActor.getActorId(actor)
            local name = LActor.getName(actor)
            table.insert(Self_Record[id][actorid], 1, {name = name, id = config[k].item.id, count = config[k].item.count})
            if #Self_Record[id][actorid] > Max_Self_Record then
                table.remove(Self_Record[id][actorid])
            end
            if config[k].isbro == 1 then
                table.insert(Total_Record[id], 1, {name = name, id = config[k].item.id, count = config[k].item.count})
                if #Total_Record[id] > Max_All_Record then
                    table.remove(Total_Record[id])
                end
            end
            return
        end
    end
end

--检查是否使用幸运值奖池
function checkLuckyDraw(actor, id, items, config, var, isact, actType)
    if XunbaoConstConfig.xunbaolucky[id] > 0 and var.lucky >= XunbaoConstConfig.xunbaolucky[id] then
        if config[var.luckytimes + 1] then
            draw(actor, items, config[var.luckytimes + 1], id, isact, actType)
            var.luckytimes = var.luckytimes + 1
        elseif config[var.luckytimes] then
            draw(actor, items, config[var.luckytimes], id, isact, actType)
        else
            draw(actor, items, config[0], id, isact)
        end
        var.lucky = var.lucky - XunbaoConstConfig.xunbaolucky[id]
    else
        draw(actor, items, config[0], id, isact, actType)
    end
end

--发送抽奖信息
function sendDrawInfo(actor, id, items)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Xunbao, Protocol.sXunbaoCmd_Draw)
    local var = getActorVar(actor, id)
    LDataPack.writeChar(pack, id)
    LDataPack.writeChar(pack, #items)
    for k, v in ipairs(items) do
        LDataPack.writeInt(pack, v.id)
        LDataPack.writeInt(pack, v.count)
        LDataPack.writeChar(pack, v.xiyou)
    end
    LDataPack.writeInt(pack, var.score)
    LDataPack.writeShort(pack, var.lucky)
    LDataPack.writeChar(pack, var.dailyfirst)
    LDataPack.writeChar(pack, var.firstget)
    LDataPack.flush(pack)
end

--抽奖
function c2sDraw(actor, pack)
    local id = LDataPack.readChar(pack)
    local index = LDataPack.readChar(pack)
    local isCostYuanbao = LDataPack.readChar(pack)
    if not XunbaoExchangeConfig[id] then return end
    if not XunbaoConstConfig.costcount[index] then return end
    
    local config, actType = getConfig(id)
    local var = getActorVar(actor, id)
    local times = 0
    local count = 0
    local costconfig = {}
    if id == 3 then
        times = XunbaoConstConfig.elementcost[index][1]
        count = XunbaoConstConfig.elementcost[index][2]
        costconfig = XunbaoConstConfig.elementcost
    else
        times = XunbaoConstConfig.costcount[index][1]
        count = XunbaoConstConfig.costcount[index][2]
        costconfig = XunbaoConstConfig.costcount
    end
    
    if LActor.getXunbaoBagSpace(actor) < times then --剩余空间
        return
    end
    --扣除道具
    if var.dailyfirst == 0 and index == 1 then
        var.dailyfirst = 1
    else
        local havecount = actoritem.getItemCount(actor, XunbaoConstConfig.itemid[id])
        if havecount < count then
            if isCostYuanbao == 1 then
                if not storesystem.buyItem(actor, XunbaoConstConfig.itemid[id], count - havecount) then
                    return
                end
                actoritem.reduceItem(actor, XunbaoConstConfig.itemid[id], havecount, "xunbao draw")
            else
                return
            end
        end
        actoritem.reduceItem(actor, XunbaoConstConfig.itemid[id], count, "xunbao draw")
    end
    local openday = System.getOpenServerDay() + 1
    local isact = openday < XunbaoConstConfig.openday[1]
    --找到奖池
    local items = {}
    if times == 1 then
        var.lucky = var.lucky + 1
        checkLuckyDraw(actor, id, items, config, var, isact, actType)
    else
        if config[times] and config[times][1].status == First_Draw_Mutli and var.firstget == 0 then
            for i = 1, times do
                var.lucky = var.lucky + 1
                if i == 1 then
                    draw(actor, items, config[times], id, isact, actType)
                else
                    checkLuckyDraw(actor, id, items, config, var, isact, actType)
                end
            end
            var.firstget = 1
        elseif config[times] and config[times][1].status == Draw_Mutli then
            for i = 1, times do
                var.lucky = var.lucky + 1
                if i == 1 then
                    draw(actor, items, config[times], id, isact, actType)
                else
                    checkLuckyDraw(actor, id, items, config, var, isact, actType)
                end
            end
        else
            for i = 1, times do
                var.lucky = var.lucky + 1
                checkLuckyDraw(actor, id, items, config, var, isact, actType)
            end
        end
    end
    
    var.score = var.score + XunbaoConstConfig.addscore * (times * 10)
    --发送奖励
    actoritem.addXunbaoItems(actor, items, "xunbao draw")
    --发送前端
    sendDrawInfo(actor, id, items)
    s2cRecordInfo(actor, id, 1)
    s2cRecordInfo(actor, id, 0)
    actorevent.onEvent(actor, aeXunbao, id, times)
end

local function addRobotRecord()
    --local recordNum = #Total_Record
    --if recordNum > 0 then return end --有记录了
    local robotNames = XunbaoConstConfig.robot
    local maxCount = #robotNames
    if maxCount == 0 then return end
    for id in ipairs(XunbaoExchangeConfig) do
        local record = XunbaoConstConfig["record"..id]
        if not record then return end
        for _, itemId in ipairs(record) do
            if not Total_Record[id] then Total_Record[id] = {} end
            local name = robotNames[math.random(1, maxCount)]
            table.insert(Total_Record[id], 1, {name = chatcommon.getServerConfName() .. "."..name, id = itemId, count = 1})
        end
    end
end

local function onLogin(actor)
    s2cXunbaoInfo(actor)
end

local function onNewDayArrive(actor, login)
    for i = 1, #XunbaoExchangeConfig do
        local var = getActorVar(actor, i)
        var.dailyfirst = 0
    end
    if not login then
        s2cXunbaoInfo(actor)
    end
end

local function init()
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDayArrive)
    netmsgdispatcher.reg(Protocol.CMD_Xunbao, Protocol.cXunbaoCmd_Draw, c2sDraw)
    netmsgdispatcher.reg(Protocol.CMD_Xunbao, Protocol.cXunbaoCmd_GetRecord, c2sGetRecord)
    netmsgdispatcher.reg(Protocol.CMD_Xunbao, Protocol.cXunbaoCmd_Exchange, c2sExchange)
    netmsgdispatcher.reg(Protocol.CMD_Xunbao, Protocol.cXunbaoCmd_ChangeTip, c2sChangeTip)
end

table.insert(InitFnTable, init)
engineevent.regGameStartEvent(addRobotRecord)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.xunbaoRecord = function (actor)
    utils.printTable(Total_Record)
    return true
end

gmCmdHandlers.addxb = function(actor, args)
    local items = {}
    local id = tonumber(args[1])
    local count = tonumber(args[2])
    table.insert(items, {type = 1, id = tonumber(args[1]), count = tonumber(args[2])})
    actoritem.addXunbaoItems(actor, items, "xunbao draw")
    return true
end

gmCmdHandlers.xunbaoclear = function (actor)
    for id in pairs(XunbaoExchangeConfig) do
        local var = getActorVar(actor, id)
        if var and var.score then
            var.score = 0
        end
    end
    return true
end
