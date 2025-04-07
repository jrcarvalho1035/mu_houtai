--冲值系统
module("rechargesystem", package.seeall)
require("recharge.payitems")
require("recharge.paymoney")
require("recharge.firstrecharge")

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then return nil end
    if var.rechargeData == nil
        then var.rechargeData = {}
    end
    local var = var.rechargeData
    if not var.firstRecord then var.firstRecord = 0 end --首冲套餐领取记录
    return var
end

function getRewardPerByPf(actor, itemid)
    local per = 1
    local config = PayMoneyConfig[itemid]
    if not config then return per end
    
    local rmbPf = getRmbByPf(actor, itemid)
    --local exRate = getExRateByPf(actor, itemid)
    per = rmbPf / (config.rmb * GlobalConfig.rateRmbToHb)
    print("getRewardPerByPf: per =", per)
    return per
end

function getVipExpByPf(actor, itemid)
    local config = PayMoneyConfig[itemid]
    if not config then return itemid end
    
    local key = "vipExp"..LActor.getPayId(actor)
    print("getVipExpByPf: key =", key)
    local vipExp = config[key]
    if not vipExp then
        print("getVipExpByPf: can't find config key =", key)
        return config.vipExp
    end
    return vipExp
end

function getExRateByPf(actor, itemid)
    local exRate = 1
    local config = PayMoneyConfig[itemid]
    if not config then return exRate end
    
    local key = "exRate"..LActor.getPayId(actor)
    print("getExRateByPf: key =", key)
    if not config[key] then
        print("getExRateByPf: can't find config key =", key)
        return exRate
    end
    return config[key]
end

function getRmbByPf(actor, itemid)
    local config = PayMoneyConfig[itemid]
    if not config then return math.floor(itemid / GlobalConfig.rateHbToYb) end
    
    local key = "rmb"..LActor.getPayId(actor)
    print("getRmbByPf: key =", key)
    local cash = config[key]
    if not cash then
        print("getRmbByPf: can't find config key =", key)
        return config.rmb
    end
    return cash
end

function getDiamondByPf(actor, itemid)
    local yb = getVipExpByPf(actor, itemid)
    return math.floor(yb * GlobalConfig.rateYbtoDq)
end

function addVipExp(actor, itemid)
    local config = PayMoneyConfig[itemid]
    if not config then return end
    
    local vipExp = getVipExpByPf(actor, itemid)
    LActor.addRecharge(actor, 0, itemid, vipExp)
end

function addDiamond(actor, itemid, log)
    local config = PayMoneyConfig[itemid]
    if not config then return end
    
    local diamond = getDiamondByPf(actor, itemid)
    actoritem.addItem(actor, NumericType_Diamond, diamond, log or "unknown")
end

--检查套餐是否已首充
function checkFirstRecharge(actor, count)
    local config = PayItemsConfig[count]
    if not config then return false end
    local var = getActorVar(actor)
    if not var then return false end
    if config.isForeverDouble == 0 and System.bitOPMask(var.firstRecord, config.id) then
        return false
    end
    return true
end

--发送充值邮件
function sendRechargeMail(actor, itemid)
    local config = PayMoneyConfig[itemid]
    if not config then
        print("rechargesystem.sendRechargeMail can't find itemid: ", itemid)
        return
    end
    local mailData = {}
    local rmb = getRmbByPf(actor, itemid)
    mailData.head = string.format(config.title, rmb)
    mailData.context = string.format(config.content, rmb)
    mailData.tAwardList = {}
    if config.content_type == 1 then
        local yb = getVipExpByPf(actor, itemid)
        mailData.context = string.format(config.content, yb)
    end
    mailsystem.sendMailById(LActor.getActorId(actor), mailData)
end

--------------------------------------------------------------------------------------------------------
--首冲套餐奖励领取信息
local function s2cFirstRechargeRecord(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_FirstRechargeMeal)
    if npack == nil then return end
    local var = getActorVar(actor)
    if var == nil then return end
    LDataPack.writeInt(npack, var.firstRecord)
    LDataPack.flush(npack)
end

--充值后处理
local function onRechargeReward(actor, itemid)
    local config = PayItemsConfig[itemid]
    if config then
        local diamond = getDiamondByPf(actor, itemid)
        jinzhuansystem.addjinzhuan(actor, diamond)
        --actoritem.addItem(actor, NumericType_Diamond, config.jinzuan, "first recharge item:")
    end
    sendRechargeMail(actor, itemid)
end

--充值后进行首充奖励
local function onFirstRechargeReward(actor, itemid)
    local config = PayItemsConfig[itemid]
    local yb = getVipExpByPf(actor, itemid)
    
    local var = getActorVar(actor)
    if config.isForeverDouble == 0 then
        var.firstRecord = System.bitOpSetMask(var.firstRecord, config.id, true)
    end
    actoritem.addItem(actor, NumericType_YuanBao, yb, "first recharge item:")
    local diamond = getDiamondByPf(actor, itemid)
    jinzhuansystem.addjinzhuan(actor, diamond)
    --actoritem.addItem(actor, NumericType_Diamond, config.jinzuan, "first recharge item:")
    
    local mailData = {
        head = RechargeConstConfig.doubleHead,
        context = string.format(RechargeConstConfig.doubleContent, yb, yb),
    tAwardList = {}}
    mailsystem.sendMailById(LActor.getActorId(actor), mailData)
    
    local isAllDouble = true
    for k, v in pairs(PayItemsConfig) do
        if v.isForeverDouble == 0 then
            if not System.bitOPMask(var.firstRecord, v.id) then
                isAllDouble = false
                break
            end
        end
    end
    if isAllDouble then
        var.firstRecord = 0
    end
    s2cFirstRechargeRecord(actor)
end

function onRecharge(actor, count, itemid)
    if checkFirstRecharge(actor, itemid) then --是首充
        onFirstRechargeReward(actor, itemid)
    else
        onRechargeReward(actor, itemid)
    end
    LActor.showEquipBagCapacity(actor) --显示背包新格子数
end

function onLogin(actor)
    s2cFirstRechargeRecord(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeRecharge, onRecharge)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_FirstRechargeActiveGet, c2sFirstRechargeActive)
