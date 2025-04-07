-- 一元秒杀2
-- 根据转生等级刷新
module("yyms2system", package.seeall)
local zsList = {}

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    local yyms2 = var.yyms2
    if not yyms2 then
        var.yyms2 = {}
        yyms2 = var.yyms2
    end
    return yyms2
end

local function getVarZs(var)
    return var.zs or 10000
end

local function sendInfo(actor, var)
    local zs = getVarZs(var)
    local list = YYMS2Config[zs]

    if list then
        local len = #list - 1
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_YYMS2Info)
        LDataPack.writeInt(pack, zs)
        LDataPack.writeChar(pack, len)
        for id = 1, len do
            LDataPack.writeChar(pack, var[id] or 0)
        end
        LDataPack.flush(pack)
    else
        print('yyms2system.sendInfo list==nil zs=', zs)
    end
end

local function getMyZsLv(actor)
    local tem = 10000
    local zsLv = LActor.getZhuansheng(actor)

    for _, lv in ipairs(zsList) do
        if zsLv >= lv then
            tem = lv
        else
            break
        end
    end

    return tem
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)

    local zs = getVarZs(var)
    local list = YYMS2Config[zs]
    if list then
        for id in ipairs(list) do
            if var[id] == 1 and next(list[id].rewards) then    
                local mailData = {head=list[id].mailTitle, context=list[id].mailContent, tAwardList=list[id].rewards}
                mailsystem.sendMailById(LActor.getActorId(actor), mailData)--发送邮件
            end
            var[id] = nil
        end
    end

    local zsLv = getMyZsLv(actor)
    if zs ~= zsLv and YYMS2Config[zsLv] then
        var.zs = zsLv
    end

    if not login then
        sendInfo(actor, var)
    end
end

local function onLogin(actor)
    local var = getActorVar(actor)
    sendInfo(actor, var)
end

local function handleGetReward(actor, reader)
    local id = LDataPack.readByte(reader)

    local var = getActorVar(actor)
    local zs = getVarZs(var)
    local list = YYMS2Config[zs]
    if list == nil then
        print('yyms2system.handleGetReward list==nil zs=', zs)
        return
    end

    local conf = list[id]
    if conf == nil then
        print('yyms2system.handleGetReward conf==nil zs=', zs)
        return
    end

    if id == #list then
        for i = 1, id - 1 do
            local st = var[i] or 0
            if st == 1 then
                local log = string.format('yyms2 %d %d', zs, i)
                actoritem.addItems(actor, conf.rewards, log)
            end
            var[i] = 2
        end
        var[id] = 2
    else
        local st = var[id] or 0
        if st == 1 then
            local log = string.format('yyms2 %d %d', zs, id)
            actoritem.addItems(actor, conf.rewards, log)
            var[id] = 2
        end

        -- 所有都已经领取
        local all = true
        for i = 1, #list - 1 do
            local st = var[i] or 0
            if st ~= 2 then
                all = false
                break
            end
        end
        if all then
            var[#list] = 2
        end
    end

    sendInfo(actor, var)
end

function isBuy(count)
    for _, list in pairs(YYMS2Config) do
        for _, conf in ipairs(list) do
            if conf.cash == count then
                return true
            end
        end
    end

    return false
end

local function killBuy(actor, count)
    local actor_id = LActor.getActorId(actor)
    local var = getActorVar(actor)
    local zs = getVarZs(var)
    local list = YYMS2Config[zs]
    if list == nil then
        print('yyms2system.killBuy list==nil zs=', zs, 'actor_id=', actor_id)
        return
    end

    local id
    local conf
    for i, c in ipairs(list) do
        if c.cash == count then
            id = i
            conf = c
            break
        end
    end

    if id == nil or conf == nil then
        print('yyms2system.killBuy bad id=', id, 'conf=', conf, 'count=', count, 'actor_id=', actor_id)
        return
    end

    rechargesystem.addVipExp(actor, count)

    if id == #list then
        local ok = false
        for i = 1, id - 1 do
            local st = var[i] or 0
            if st == 0 then
                ok = true
                break
            end
        end

        if ok == false then
            print('yyms2system.killBuy bad i=', i, 'id=', id, 'actor_id=', actor_id)
            return
        end

        for i = 1, id do
            local st = var[i] or 0
            if st == 0 then
                var[i] = 1
            end
        end
    else
        local st = var[id] or 0
        if st ~= 0 then
            print('yyms2system.killBuy bad st=', st, 'id=', id, 'actor_id=', actor_id)
            return
        end

        var[id] = 1

        -- 所有都已购买
        local all = true
        for i = 1, #list - 1 do
            local st = var[i] or 0
            if st ~= 1 then
                all = false
                break
            end
        end
        if all then
            var[#list] = 1
        end
    end

    sendInfo(actor, var)

    local isAllBuy = true
    for i = 1, #list - 1 do
        if var[i] ~= 1 and var[i] ~= 2 then
            isAllBuy = false
        end
    end
    if isAllBuy then
        actorevent.onEvent(actor, aeZSMSBuy)
    end
end

function buy(actor_id, count)
    local actor = LActor.getActorById(actor_id)
    if actor then
        killBuy(actor, count)
    else
        local npack = LDataPack.allocPacket()
        LDataPack.writeInt(npack, count)
        System.sendOffMsg(actor_id, 0, OffMsgType_YYSM2, npack)
    end
end

local function handleOffMsYYMS2(actor, reader)
    local count = LDataPack.readInt(reader)
    killBuy(actor, count)
end

local function initGlobalData()
    zsList = {}
    for zs in pairs(YYMS2Config) do
        table.insert(zsList, zs)
    end
    table.sort(zsList)

    actorevent.reg(aeNewDayArrive, onNewDay)
    actorevent.reg(aeUserLogin, onLogin)

    if System.isLianFuSrv() then return end
    msgsystem.regHandle(OffMsgType_YYSM2, handleOffMsYYMS2)
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_YYMS2GetReward, handleGetReward)
end
table.insert(InitFnTable, initGlobalData)

