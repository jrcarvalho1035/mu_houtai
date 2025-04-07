
--每日签到
module("dailysignin", package.seeall)
MAX_DAY = 30

local function getStaticVar(actor)
	local var = LActor.getStaticVar(actor)
    if not var.signin then var.signin = {} end
    if not var.signin.canget then var.signin.canget = {} end
    if not var.signin.totalday then var.signin.totalday = 0 end
    if not var.signin.curday then var.signin.curday = 0 end
	return var.signin
end

local function getSigninCnt(var)
    local total = 0
    for i=1, MAX_DAY do
        if var.canget[i] and var.canget[i] == 2 then
            total = total + 1
        end
    end
    return total
end

--签到
function signin(actor, pack)
    local day = LDataPack.readShort(pack)
    local var = getStaticVar(actor)
    if not var.canget[day] or var.canget[day] ~= 1 then
        return
    end
    var.canget[day] = 2
    local count = 1
    if monthcard.isBuyMonthCard(actor) then
        count = MonthCardConfig.multiple
    end
    for k, v in ipairs(DailySigninConfig[day].reward) do
        actoritem.addItem(actor, v.id, v.count * count, "dailysignin")
    end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Fuli, Protocol.sDailySignin_SigninResult)
    LDataPack.writeChar(pack, #DailySigninConfig[day].reward)
    for k, v in ipairs(DailySigninConfig[day].reward) do
        LDataPack.writeInt(pack, v.id)
        LDataPack.writeInt(pack, v.count * count)
    end
    LDataPack.flush(pack)
    
    sendInfo(actor)
end

--领取累计签到奖励
function getTotalReward(actor)
    local var = getStaticVar(actor)
    local count = getSigninCnt(var)
    local index = 0
    for k, conf in ipairs(TotalSigninConfig) do
        if count >= conf.day and not System.bitOPMask(var.totalday, k) then
            index = k
            break
        end
    end
    if index == 0 then
        return
    end
    var.totalday = System.bitOpSetMask(var.totalday, index, true)
    actoritem.addItems(actor, TotalSigninConfig[index].reward, "daily signin total")
    sendInfo(actor)
end

--每日签到信息
function sendInfo(actor)
    local var = getStaticVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Fuli, Protocol.sDailySignin_Info)
    LDataPack.writeShort(pack, MAX_DAY)
    for i=1, MAX_DAY do
        LDataPack.writeChar(pack, (var.canget[i] or 0))
    end
    LDataPack.writeInt(pack, var.totalday)
    LDataPack.writeShort(pack, var.curday)
    LDataPack.flush(pack)
end


function onLogin(actor)
    sendInfo(actor)
end

function onNewDay(actor, login)
    local var = getStaticVar(actor)    
    var.curday = var.curday + 1
    if var.curday > MAX_DAY then
        local getall = true
        for i=1, MAX_DAY do
            if var.canget[i] ~= 2 then
                getall = false
                break
            end
        end
        for k, conf in ipairs(TotalSigninConfig) do
            if not System.bitOPMask(var.totalday, k) then
                getall = false
                break
            end
        end
        if not getall then
            var.curday = MAX_DAY
            return
        end
        var.canget[1] = 1
        for i=2, MAX_DAY do
           var.canget[i] = 0
        end
        var.curday = 1
        var.totalday = 0
    else        
        var.canget[var.curday] = 1
    end
    if not login then
        sendInfo(actor)
    end
end


actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)

netmsgdispatcher.reg(Protocol.CMD_Fuli, Protocol.cDailySignin_Signin, signin)
netmsgdispatcher.reg(Protocol.CMD_Fuli, Protocol.cDailySignin_GetTotalReward, getTotalReward)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.signin = function(actor, args) 
    local var = getStaticVar(actor)
    local day = tonumber(args[1])
    var.canget[day] = 1
    sendInfo(actor)
	return true
end

gmCmdHandlers.signinclear = function(actor, args) 
    local var = getStaticVar(actor)
    for i=1, MAX_DAY do
        var.canget[i] = 0
    end
    sendInfo(actor)
	return true
end
