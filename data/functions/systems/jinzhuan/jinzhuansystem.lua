-- @system  点券系统

module("jinzhuansystem", package.seeall)

Total_Record = Total_Record or {}
Self_Record = Self_Record or {}
local Max_Self_Record = 100
local Max_All_Record = 20

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
	if var == nil then return end

    if not var.jinzhuan then var.jinzhuan = {} end
    if not var.jinzhuan.dailyget then var.jinzhuan.dailyget = 0 end --今日获得点券
    if not var.jinzhuan.score then var.jinzhuan.score = 0 end --祝福值
    if not var.jinzhuan.scoretimes then var.jinzhuan.scoretimes = 1 end --领取第几次祝福值奖励
    if not var.jinzhuan.scroestatus then var.jinzhuan.scroestatus = 0 end
    if not var.jinzhuan.secretindexs then var.jinzhuan.secretindexs = {} end
    if not var.jinzhuan.secretnexttime then var.jinzhuan.secretnexttime = 0 end
    return var.jinzhuan
end

function sendInfo(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sJinzhuanCmd_Info)
    LDataPack.writeInt(pack, var.score)
    LDataPack.writeInt(pack, var.dailyget)
    LDataPack.writeChar(pack, var.scoretimes)
    LDataPack.writeInt(pack, var.scroestatus)
    LDataPack.flush(pack)
end

function sendDrawInfo(actor, items)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sJinzhuanCmd_Draw)
    local var = getActorVar(actor)
    LDataPack.writeChar(pack, #items)
    for k,v in ipairs(items) do
        LDataPack.writeInt(pack, v.id)
        LDataPack.writeInt(pack, v.count)
        LDataPack.writeChar(pack, v.xiyou)
    end
    LDataPack.writeInt(pack, var.score)
    LDataPack.flush(pack)
end

function s2cRecordInfo(actor, type)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sJinzhuanCmd_SendRecord)
    LDataPack.writeChar(npack, type)
    if type == 0 then
        local actorid = LActor.getActorId(actor)
        if not Self_Record then Self_Record = {} end
        if not Self_Record[actorid] then Self_Record[actorid] = {} end
        LDataPack.writeChar(npack, #Self_Record[actorid])
        for k,v in ipairs(Self_Record[actorid]) do
            LDataPack.writeString(npack, v.name)
            LDataPack.writeInt(npack, v.id)
            LDataPack.writeInt(npack, v.count)
        end
    else
        LDataPack.writeChar(npack, #Total_Record)
        for k,v in ipairs(Total_Record) do
            LDataPack.writeString(npack, v.name)
            LDataPack.writeInt(npack, v.id)
            LDataPack.writeInt(npack, v.count)
        end
    end
    LDataPack.flush(npack)
end

function draw(actor, items)
    local rand = System.getRandomNumber(10000) + 1
    local total = 0
    for k,v in ipairs(JinzhuanXunbaoConfig) do
        total = total + v.probability1
        if rand <= total then
            items[#items + 1] = v.item
            items[#items].xiyou = v.xiyou
            local actorid = LActor.getActorId(actor)
            local name = LActor.getName(actor)
            if not Self_Record[actorid] then Self_Record[actorid] = {} end
            table.insert(Self_Record[actorid], 1, {name = name, id = v.item.id, count = v.item.count})
            if #Self_Record[actorid] > Max_Self_Record then
                table.remove(Self_Record[actorid])
            end
            if v.isbro == 1 then
                table.insert(Total_Record, 1, {name = name, id = v.item.id, count = v.item.count})
                if #Total_Record > Max_All_Record then
                    table.remove(Total_Record)
                end
            end
            return
        end
    end
end

function c2sDraw(actor, pack)
    local index = LDataPack.readChar(pack)
    if not JinzhuanConstConfig.drawcost[index] then return end

    local config = JinzhuanXunbaoConfig
    local var = getActorVar(actor, id)
    local times = JinzhuanConstConfig.drawtimes[index]
    local cost = JinzhuanConstConfig.drawcost[index]

    if LActor.getJinzhuanBagSpace(actor) < times then --剩余空间
        return
    end
    --扣除道具
    if not actoritem.checkItem(actor, NumericType_Diamond, cost) then
        return
    end
    actoritem.reduceItem(actor, NumericType_Diamond, cost, "jinzhuan draw")

    local items = {}
    for i=1, times do
        draw(actor, items)
    end
    var.score = var.score + times * JinzhuanConstConfig.addscore

    --发送奖励
    actoritem.addJinzhuanItems(actor, items, "jinzhuan draw")
    --发送前端
    sendDrawInfo(actor, items)
    s2cRecordInfo(actor, 1)
    s2cRecordInfo(actor, 0)
    actorevent.onEvent(actor, aeJinzhuanDraw, id, times)
end

function c2sGetRecord(actor, pack)
    local type = LDataPack.readChar(pack)
    s2cRecordInfo(actor, type)
end

function c2sZhufuReward(actor, pack)
    local index = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    local config = JinzhuanZhufuConfig[var.scoretimes][index]
    if not config then return end
    if System.bitOPMask(var.scroestatus, index - 1) then
        return
    end
    if var.score < config.score then
        return
    end
    var.scroestatus = System.bitOpSetMask(var.scroestatus, index - 1, true)
    actoritem.addItem(actor, config.item.id, config.item.count, "jinzhuan zhufu")
    local all = true
    for k,v in ipairs(JinzhuanZhufuConfig[var.scoretimes]) do
        if not System.bitOPMask(var.scroestatus, k - 1) then
            all = false
            break
        end
    end
    if all then
        var.scroestatus = 0
        var.score = var.score - JinzhuanZhufuConfig[var.scoretimes][#JinzhuanZhufuConfig[var.scoretimes]].score
        if var.scoretimes == 1 then
            var.scoretimes = var.scoretimes + 1
        end
    end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sJinzhuanCmd_GetZhufuReward)
    LDataPack.writeChar(npack, var.scoretimes)
    LDataPack.writeChar(npack, index)
    LDataPack.writeInt(npack, var.scroestatus)
    LDataPack.writeInt(npack, var.score)
    LDataPack.flush(npack)
end

local function getDiscountIndx(config)
    local rand = System.getRandomNumber(10000) + 1
    local total = 0
    for i=1, #config do
        total = total + config[i].pro
        if rand <= total then
            return i
        end
    end
    return 1
end

function refresh(actor)
    local var = getActorVar(actor)
    for i=1, JinzhuanConstConfig.secretcount do
        local rand = System.getRandomNumber(10000) + 1
        local total = 0
        for k,v in ipairs(JinzhuanSecretConfig) do
            total = total + v.probability1
            if rand <= total then
                var.secretindexs[i] = {}
                var.secretindexs[i].index = k
                var.secretindexs[i].discountindex = getDiscountIndx(v.discount)
                var.secretindexs[i].isbuy = 0
                break
            end
        end
    end
end

function refreshSecret(actor)
    local var = getActorVar(actor)
    refresh(actor)
    var.secretnexttime = System.getNowTime() + JinzhuanConstConfig.refreshtime * 60
    LActor.postScriptEventLite(actor, JinzhuanConstConfig.refreshtime * 60 * 1000, refreshSecret)
    sendSecretInfo(actor, Protocol.sJinzhuanCmd_RefreshSecret)
end

function sendSecretInfo(actor, packid)
    local var = getActorVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, packid)
    LDataPack.writeInt(npack, math.max(var.secretnexttime - System.getNowTime(), 0))
    LDataPack.writeChar(npack, JinzhuanConstConfig.secretcount)
    for i=1, JinzhuanConstConfig.secretcount do
        LDataPack.writeChar(npack, var.secretindexs[i].isbuy)
        LDataPack.writeShort(npack, var.secretindexs[i].index)
        local config = JinzhuanSecretConfig[var.secretindexs[i].index].discount[var.secretindexs[i].discountindex]
        LDataPack.writeShort(npack, config.discount)
        LDataPack.writeShort(npack, config.cost)
    end
    LDataPack.flush(npack)
end

function c2sSecretInfo(actor, pack)
    sendSecretInfo(actor, Protocol.sJinzhuanCmd_SendSecret)
end

function c2sRefreshSecret(actor, pack)
    if not actoritem.checkItem(actor, NumericType_YuanBao, JinzhuanConstConfig.needyuanbao) then
        return
    end
    actoritem.reduceItem(actor, NumericType_YuanBao, JinzhuanConstConfig.needyuanbao, "jinzhuan secret")
    refresh(actor)
    sendSecretInfo(actor, Protocol.sJinzhuanCmd_RefreshSecret)
end

function c2sSecretBuy(actor, pack)
    local index = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    if not var.secretindexs[index] then
        return
    end
    if var.secretindexs[index].isbuy ~= 0 then
        return
    end
    local config = JinzhuanSecretConfig[var.secretindexs[index].index]
    local cost = config.discount[var.secretindexs[index].discountindex].cost
    if not actoritem.checkItem(actor, NumericType_Diamond, cost) then
        return
    end
    actoritem.reduceItem(actor, NumericType_Diamond, cost, "jinzhuan secret")
    var.secretindexs[index].isbuy = 1
    actoritem.addItem(actor, config.item.id, config.item.count, "jinzhuan secret")
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sJinzhuanCmd_SecretBuy)
    LDataPack.writeChar(npack, index)
    LDataPack.writeInt(npack, var.secretindexs[index].isbuy)
    LDataPack.flush(npack)
end

function onLogin(actor)
    sendInfo(actor)
    sendSecretInfo(actor, Protocol.sJinzhuanCmd_SendSecret)
end

function addjinzhuan(actor, number)
    local var = getActorVar(actor)
    local svip = LActor.getSVipLevel(actor)
    local inActivity19 = subactivity19.isOpen()
    -- 当点券狂欢活动开启时，不设上限
    if not inActivity19 then
        if var.dailyget >= SVipConfig[svip].jinzhuan then
            return 0
        end
        if var.dailyget + number >= SVipConfig[svip].jinzhuan then
            number = SVipConfig[svip].jinzhuan - var.dailyget
        end
    end
    var.dailyget = var.dailyget + number
    LActor.changeCurrency(actor, NumericType_Diamond, number, "rechage", 0)
    -- 活动期间，前端不显示当天获取的总数
    if not inActivity19 then
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sJinzhuanCmd_DailyInfo)
        LDataPack.writeInt(npack, var.dailyget)
        LDataPack.flush(npack)
    end
    return number
end

function onInit(actor)
    local var = getActorVar(actor)
    if not var.secretindexs[1] or var.secretnexttime < System.getNowTime() then
        refresh(actor)
        var.secretnexttime = System.getNowTime() + JinzhuanConstConfig.refreshtime  * 60
    end
    var.eid = LActor.postScriptEventLite(actor, (var.secretnexttime  - System.getNowTime()) * 1000, refreshSecret)
end

function onNewDay(actor, login)
    local var = getActorVar(actor)
    var.dailyget = 0
    if not login then
        sendInfo(actor)
    end
end

local function addRobotRecord()
    local robotNames = JinzhuanConstConfig.robot
    local maxCount = #robotNames
    if maxCount == 0 then return end
    local record = JinzhuanConstConfig.record
    if not record then return end
    for _, itemId in ipairs(record) do
        local name = robotNames[math.random(1,maxCount)]
        table.insert(Total_Record, 1, {name = name, id = itemId, count = 1})
    end
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
engineevent.regGameStartEvent(addRobotRecord)

netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cJinzhuanCmd_Draw, c2sDraw)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cJinzhuanCmd_GetRecord, c2sGetRecord)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cJinzhuanCmd_GetZhufuReward, c2sZhufuReward)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cJinzhuanCmd_GetSecret, c2sSecretInfo)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cJinzhuanCmd_RefreshSecret, c2sRefreshSecret)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cJinzhuanCmd_SecretBuy, c2sSecretBuy)



local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.setjz = function(actor, args)
    local num = tonumber(args[1])
    LActor.changeCurrency(actor, NumericType_Diamond, num, "gm", 0)
	return true
end

gmCmdHandlers.setjzzf = function(actor, args)
    local num = tonumber(args[1])
    local var = getActorVar(actor)
    var.score = num
    sendInfo(actor)
	return true
end
