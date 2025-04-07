--等级奖励

module("subactivity1", package.seeall)

local subType = 1
local rewardCallbak = {}

local minType = {
    level = 1, --等级达标
    consume = 2, --消费达标
    power = 3, --战力达标
    online = 4, --在线达标
    floor = 5, --爬塔达标
    login = 6, --连续登录达标
    pay = 7, --每日累计充值
    totalpay = 8, --活动期间累计充值
    openseven = 9, --开服七天达标
    custom = 16, --关卡达标
    yuanbaodraw = 17, --钻石夺宝积分达标
    duobaoscore = 18, --冲榜夺宝
    jifenscore = 19, --跨服积分达标
    itemscore = 20, --跨服道具消耗数量达标
    pay1 = 21, --每日累计充值,前端需除以100
    
    killboss = 22, -- 击杀boss数量达标
    heian = 23, -- 黑暗深渊的层数达标
    talent = 24, -- 天赋值达标
    gold = 25, -- 金币值达标
    devilexp = 26, -- 恶魔要塞获得经验达标
    
    type20pv = 27, -- 活动类型20我的祭祀值达标
    type20pvSum = 28, -- 活动类型20个人祭祀达标
    type20cvNum = 29, -- 活动类型20全服祭祀达标
    
    type35 = 30, --转盘积分
    xunbaoscore = 31, --寻宝积分
    sendgift = 32, --送礼达标
    zadan = 33, --砸蛋达标
    diamond = 34, --点券消费
    type40self = 35, --宝藏猎人-战利品(个人)
    type40all = 36, --宝藏猎人-战利品(全民)
}
local sType = {
    shenmo = 9, --神魔达标
    yongbing = 10, --佣兵达标
    shenqi = 11, --神器达标
    wing = 12, --翅膀达标
    damon = 13, --精灵达标
    shenzhuang = 14, --神装达标
    meilin = 15, --神魔达标
}

local initEx = {
    [minType.killboss] = true,
    [minType.devilexp] = true,
}

local function getSubTypeVar(actor)
    local var = LActor.getStaticVar(actor)
    if var.type1SubTypeVar == nil then
        var.type1SubTypeVar = {}
    end
    return var.type1SubTypeVar
end

local function getSystemVar(id)
    local var = activitymgr.getGlobalVar(id)
    if not var then return end
    if not var.score then var.score = 0 end
    return var
end

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if ActivityType1Config[id][1].subType == minType.consume then
        if not var.consume then var.consume = 0 end --活动内消费数
    elseif ActivityType1Config[id][1].subType == minType.online then
        if not var.isStart then var.isStart = 0 end --计时是否已开始
        if not var.startTime then var.startTime = 0 end --开始计时时间
        if not var.logoutTime then var.logoutTime = 0 end --离线时间记录
    elseif ActivityType1Config[id][1].subType == minType.login then
        if not var.logindays then var.logindays = 0 end --活动内连续登录天数
    elseif ActivityType1Config[id][1].subType == minType.pay or ActivityType1Config[id][1].subType == minType.pay1 then
        if not var.payCount then var.payCount = 0 end --今天累计充值
    elseif ActivityType1Config[id][1].subType == minType.totalpay then
        if not var.payCount then var.payCount = 0 end --活动累计充值
    elseif ActivityType1Config[id][1].subType == minType.sType then --开服达标活动
        if not var.level then var.level = 0 end
    elseif ActivityType1Config[id][1].subType == minType.duobaoscore then
        if not var.duobaoscore then var.duobaoscore = 0 end
    elseif ActivityType1Config[id][1].subType == minType.jifenscore then
        if not var.jifenscore then var.jifenscore = 0 end
    elseif ActivityType1Config[id][1].subType == minType.itemscore then
        if not var.itemscore then var.itemscore = 0 end
    elseif ActivityType1Config[id][1].subType == minType.type35 then
        if not var.recharge then var.recharge = 0 end
        if not var.luckyScore then var.luckyScore = 0 end
    elseif ActivityType1Config[id][1].subType == minType.xunbaoscore then
        if not var.xunbaoscore then var.xunbaoscore = 0 end
    elseif ActivityType1Config[id][1].subType == minType.diamond then
        if not var.diamond then var.diamond = 0 end
    else
        if not var.score then var.score = 0 end
    end
    return var
end

--记录数据
local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local v = record and record.data and record.data.rewardsRecord or 0
    
    LDataPack.writeDouble(npack, getConditionPer(actor, id, config[1]))
    LDataPack.writeDouble(npack, v)
end

function clearRecord(actor, id)
    local record = activitymgr.getSubVar(actor, id)
    if record then
        record.data.rewardsRecord = nil
    end
    print('subactivity1.clearRecord id=', id, 'actor_id=', LActor.getActorId(actor))
    --activitymgr.sendActivityInfo(actor, id, true)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
    LDataPack.writeByte(npack, 1)
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, 1)
    LDataPack.writeDouble(npack, 0)
    LDataPack.flush(npack)
end

--获得达标进度
function getConditionPer(actor, id, config)
    local subType = config.subType
    if subType == minType.level then
        return LActor.getLevel(actor)
    elseif subType == minType.consume then
        local var = getActorVar(actor, id)
        return var.consume
    elseif subType == minType.power then
        return LActor.getActorData(actor).total_power
    elseif subType == minType.online then
        local var = getActorVar(actor, id)
        return System.getNowTime() - var.startTime
    elseif subType == minType.floor then
        return wanmofuben.getWanmoFloor(actor)
    elseif subType == minType.login then
        local var = getActorVar(actor, id)
        return var.logindays
    elseif subType == minType.pay or subType == minType.pay1 then
        local var = getActorVar(actor, id)
        return var.payCount
    elseif subType == minType.totalpay then
        local var = getActorVar(actor, id)
        return var.payCount
    elseif subType == minType.custom then
        return guajifuben.getCustom(actor)
    elseif subType == minType.yuanbaodraw then
        local var = getActorVar(actor, id)
        return var.score
    elseif subType == minType.duobaoscore then
        local var = getActorVar(actor, id)
        return var.duobaoscore
    elseif subType == minType.jifenscore then
        local var = getActorVar(actor, id)
        return var.jifenscore
    elseif subType == minType.itemscore then
        local var = getActorVar(actor, id)
        return var.itemscore
    elseif config.sType == sType.damon then
        return damonsystem.getLevel(actor)
    elseif config.sType == sType.yongbing then
        return yongbingsystem.getLevel(actor)
    elseif config.sType == sType.shenqi then
        return shenqisystem.getShenqiLv(actor)
    elseif config.sType == sType.wing then
        return wingsystem.getWingLv(actor)
    elseif config.sType == sType.shenmo then
        return shenmosystem.getLevel(actor)
    elseif config.sType == sType.shenzhuang then
        return shenzhuangsystem.getShenzhuangLv(actor)
    elseif config.sType == sType.meilin then
        return meilinsystem.getMeilinLv(actor)
    elseif subType == minType.heian then
        return heianpata.getHeianFloor(actor)
    elseif subType == minType.gold then
        local p = activitymgr.getParamConfig(id)
        return dailyfuben.getResult(actor, p)
    elseif subType == minType.talent then
        local p = activitymgr.getParamConfig(id)
        return dailyfuben.getResult(actor, p)
    elseif subType == minType.devilexp then
        return devilsquare.getHighExp(actor)
    elseif subType == minType.type20pv then
    elseif subType == minType.type20cvNum then
        local param = activitymgr.getParamConfig(id)
        return subactivity20.getCvNum(param)
    elseif subType == minType.type35 then
        local var = getActorVar(actor, id)
        return var.luckyScore
    elseif subType == minType.xunbaoscore then
        local var = getActorVar(actor, id)
        return var.xunbaoscore
    elseif subType == minType.sendgift then
        local var = getActorVar(actor, id)
        return var.score
    elseif subType == minType.zadan then
        local var = getActorVar(actor, id)
        return var.score
    elseif subType == minType.diamond then
        local var = getActorVar(actor, id)
        return var.diamond
    elseif subType == minType.type40self then
        local var = getActorVar(actor, id)
        return var.score
    elseif subType == minType.type40all then
        local data = getSystemVar(id)
        return data.score
    end
    
    return getSubTypeValue(actor, id)
end

--检测能否领取奖励
local function checkLevelReward(actor, config, index, record, id)
    if config[index] == nil then
        return false
    end
    
    local cond = getConditionPer(actor, id, config[index])
    if cond < config[index].condition then
        print ("subactivity1.checkLevelReward Condition is not match id=", id, 'cond=', cond, "conf.cond=", config[index].condition)
        return false
    end
    if record.data.rewardsRecord == nil then
        record.data.rewardsRecord = 0
    end
    if System.bitOPMask(record.data.rewardsRecord, index) then
        return false
    end
    if not actoritem.checkEquipBagSpaceJob(actor, config[index].rewards) then
        return false
    end
    return true
end

--领取奖励
local function onGetReward(actor, config, id, idx, record)
    config = config[id]
    local ret = checkLevelReward(actor, config, idx, record, id)
    if ret then
        record.data.rewardsRecord = System.bitOpSetMask(record.data.rewardsRecord, idx, true)
        actoritem.addItemsByJob(actor, config[idx].rewards, "activity type1 rewards", 0, "act1")
        
        local cb = rewardCallbak[id]
        if cb then
            cb(actor, id, config, record)
        end
    end
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
    LDataPack.writeByte(npack, ret and 1 or 0)
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, idx)
    LDataPack.writeDouble(npack, record.data.rewardsRecord or 0)
    LDataPack.flush(npack)
end

function regainConsumeYuanbao(actor, count)
    for id, v in pairs(ActivityType1Config) do
        if not activitymgr.activityTimeIsEnd(id) and v[1].subType == minType.consume then
            local var = getActorVar(actor, id)
            var.consume = var.consume - count
        end
    end
end

subactivitymgr.actorLoginFuncs[subType] = function(actor, type, id)
    if activitymgr.activityTimeIsOver(id) then return end
    
    local st_var = getSubTypeVar(actor)
    if st_var.killboss then
        addSubTypeValue(actor, minType.killboss, st_var.killboss)
        st_var.killboss = nil
    end
    
    local stype = ActivityType1Config[id][1].subType
    if stype == minType.login then
        local var = getActorVar(actor, id)
        if not var.isadd then
            var.logindays = var.logindays + 1
            var.isadd = 1
            updateDabiao(actor, id, var.logindays)
        end
    end
end

local function onConsumeYuanbao(actor, count, log)
    if log == "diral draw" then return end
    for id, v in pairs(ActivityType1Config) do
        if not activitymgr.activityTimeIsEnd(id) and v[1].subType == minType.consume then
            local var = getActorVar(actor, id)
            var.consume = var.consume + count
            updateDabiao(actor, id, var.consume)
        end
    end
end

local function onConsumeDiamond(actor, count)
    for id, v in pairs(ActivityType1Config) do
        if not activitymgr.activityTimeIsEnd(id) and v[1].subType == minType.diamond then
            local var = getActorVar(actor, id)
            var.diamond = var.diamond + count
            updateDabiao(actor, id, var.diamond)
        end
    end
end

function onAfterNewDay(actor, id)
    if activitymgr.activityTimeIsEnd(id) then return end
    local config = ActivityType1Config[id]
    if not config then return end
    
    if config[1].subType == minType.login then
        local var = getActorVar(actor, id)
        if not var.isadd then
            var.logindays = var.logindays + 1
            var.isadd = 1
        end
        updateDabiao(actor, id)
    end
end

--退出登录
function onActorLogout(id, conf)
    return function(actor)
        if ActivityType1Config[id][1].subType == minType.online then
            local var = getActorVar(actor, id)
            var.logoutTime = System.getNowTime()
        end
    end
end

--新的一天，在活动信息协议发送前执行
function onBeforeNewDay(actor, record, config, id)
    if activitymgr.activityTimeIsEnd(id) then return end
    if ActivityType1Config[id][1].subType == minType.online then
        local var = getActorVar(actor, id)
        var.isStart = 0
        var.logoutTime = 0
        if record and record.data then
            record.data.rewardsRecord = 0
        end
    elseif ActivityType1Config[id][1].subType == minType.login then
        local var = getActorVar(actor, id)
        var.isadd = nil
    elseif ActivityType1Config[id][1].subType == minType.pay or ActivityType1Config[id][1].subType == minType.pay1 then
        local var = getActorVar(actor, id)
        for k, v in ipairs(config[id]) do --把未领取的奖励以邮件发送
            if var.payCount >= v.condition then
                if record.data.rewardsRecord == nil then
                    record.data.rewardsRecord = 0
                end
                if not System.bitOPMask(record.data.rewardsRecord, k) then
                    record.data.rewardsRecord = System.bitOpSetMask(record.data.rewardsRecord, k, true)
                    local mailData = {head = v.head, context = v.text, tAwardList = v.rewards}
                    mailsystem.sendMailById(LActor.getActorId(actor), mailData)
                end
            end
        end
        if record and record.data then
            var.payCount = 0 --要在这里清理累充值，因为activityTimeIsEnd，前七天的活动无法在onNewDayLogin里清理
            record.data.rewardsRecord = 0 --奖励回复
        end
    elseif ActivityType1Config[id][1].subType == minType.type35 then
        local var = getActorVar(actor, id)
        if record.data.rewardsRecord == nil then
            record.data.rewardsRecord = 0
        end
        for k, v in ipairs(config[id]) do --把未领取的奖励以邮件发送
            if var.luckyScore >= v.condition then
                if not System.bitOPMask(record.data.rewardsRecord, k) then
                    record.data.rewardsRecord = System.bitOpSetMask(record.data.rewardsRecord, k, true)
                    local mailData = {head = v.head, context = v.text, tAwardList = v.rewards}
                    mailsystem.sendMailById(LActor.getActorId(actor), mailData)
                end
            end
        end
        var.recharge = 0
        var.luckyScore = 0
        record.data.rewardsRecord = 0
    end
end

function onTimeOut(id, config, actor, record)
    if not record then return end
    local config = config[id]
    local per = getConditionPer(actor, id, config[1])
    for k, v in ipairs(config) do
        if v.head ~= "" then
            if record.data.rewardsRecord == nil then
                record.data.rewardsRecord = 0
            end
            if per >= v.condition and (not System.bitOPMask(record.data.rewardsRecord, k)) then
                record.data.rewardsRecord = System.bitOpSetMask(record.data.rewardsRecord, k, true)
                local mailData = {head = v.head, context = v.text, tAwardList = v.rewards}
                mailsystem.sendMailById(LActor.getActorId(actor), mailData)
            end
        end
    end
end

function onActivityFinish(id)
    local config = ActivityType1Config
    if config[id][1].head == "" then return end
    local actors = System.getOnlineActorList()
    if actors then
        for i = 1, #actors do
            local actor = actors[i]
            local var = activitymgr.getStaticData(actor)
            local record = var.records[id]
            --onTimeOut(id, config, actor, record)
        end
    end
end

local function c2sUpdateDaBiao(actor, pack)
    local id = LDataPack.readInt(pack)
    if activitymgr.activityTimeIsEnd(id) then return end
    if ActivityType1Config[id][1].subType == minType.type40all then
        local data = getSystemVar(id)
        updateDabiao(actor, id, data.score)
    end
end

function updateDabiao(actor, id, value)
    if not value then
        value = getConditionPer(actor, id, ActivityType1Config[id][1])
    end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_UpdateDaBiao)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt64(npack, value)
    LDataPack.flush(npack)
end

function broadDabiao(id, value)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_Activity)
    LDataPack.writeByte(npack, Protocol.sActivityCmd_UpdateDaBiao)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt64(npack, value or 0)
    System.broadcastData(npack)
end

function addSubTypeValue(actor, stype, value)
    for id, v in pairs(ActivityType1Config) do
        if v[1].subType == stype then
            if not activitymgr.activityTimeIsEnd(id) then
                local var = getActorVar(actor, id)
                local old = var.value or 0
                local newVal = old + value
                var.value = newVal
                updateDabiao(actor, id, newVal)
            end
        end
    end
end

function setSubTypeValue(actor, stype, value)
    for id, v in pairs(ActivityType1Config) do
        if v[1].subType == stype then
            if not activitymgr.activityTimeIsEnd(id) then
                local var = getActorVar(actor, id)
                var.value = value
                updateDabiao(actor, id, value)
            end
        end
    end
end

function getSubTypeValue(actor, id)
    local var = getActorVar(actor, id)
    return var.value or 0
end

function setType20Pv(actor, value)
    setSubTypeValue(actor, minType.type20pv, value)
end

function addType20PvSum(actor, value)
    addSubTypeValue(actor, minType.type20pvSum, value)
end

function setType20PvSum(actor, value)
    setSubTypeValue(actor, minType.type20pvSum, value)
end

function broadcastType20CvNum(value)
    local stype = minType.type20cvNum
    for id, v in pairs(ActivityType1Config) do
        if v[1].subType == stype then
            if not activitymgr.activityTimeIsEnd(id) then
                local param = activitymgr.getParamConfig(id)
                if 0 < param then
                    local npack = LDataPack.allocPacket()
                    if npack then
                        LDataPack.writeByte(npack, Protocol.CMD_Activity)
                        LDataPack.writeByte(npack, Protocol.sActivityCmd_UpdateDaBiao)
                        LDataPack.writeInt(npack, id)
                        LDataPack.writeInt64(npack, value)
                        System.broadcastData(npack)
                    end
                end
            end
        end
    end
end

function onKillBoss(actor, bossid, count)
    if not actor then return end
    count = count or 1
    if System.isBattleSrv() then
        local var = getSubTypeVar(actor)
        local old = var.killboss or 0
        var.killboss = old + count
        return
    end
    addSubTypeValue(actor, minType.killboss, count)
end

function onGetTalent(actor, value)
    for id, v in pairs(ActivityType1Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            if v[1].subType == minType.talent then
                updateDabiao(actor, id, value)
            end
        end
    end
    
end

function onGetGold(actor, value)
    for id, v in pairs(ActivityType1Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            if v[1].subType == minType.gold then
                updateDabiao(actor, id, value)
            end
        end
    end
end

function onGetDevilExp(actor, value)
    setSubTypeValue(actor, minType.devilexp, value)
end

function onCostItem(actor, itemid, count)
    for id, v in pairs(ActivityType1Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            if itemid == v[1].needitem then
                if v[1].subType == minType.jifenscore then
                    local var = getActorVar(actor, id)
                    var.jifenscore = var.jifenscore + count * 10
                    updateDabiao(actor, id, var.jifenscore)
                elseif v[1].subType == minType.itemscore then
                    local var = getActorVar(actor, id)
                    var.itemscore = var.itemscore + count
                    updateDabiao(actor, id, var.itemscore)
                elseif v[1].subType == minType.type40all then
                    sendSCDaBiao(id, count)
                end
            end
        end
    end
end

function getYuanbaoDrawScore(actor)
    for id, v in pairs(ActivityType1Config) do
        if not activitymgr.activityTimeIsEnd(id) and v[1].subType == minType.yuanbaodraw then
            local var = getActorVar(actor, id)
            return var.score
        end
    end
    return 0
end

local function onAddYuanbaoDraw(actor, score, id)
    local config = ActivityType1Config[id]
    if not config then return end
    if not activitymgr.activityTimeIsEnd(id) and config[1].subType == minType.yuanbaodraw then
        local var = getActorVar(actor, id)
        var.score = var.score + score
        updateDabiao(actor, id, var.score)
    end
end

local function onRecharge(actor, count)
    local temp = {} --记录序号
    for id, conf in pairs(ActivityType1Config) do
        if not temp[id] and not activitymgr.activityTimeIsEnd(id) then --每种序号只执行一次
            if (conf[1].subType == minType.pay or conf[1].subType == minType.pay1 or conf[1].subType == minType.totalpay) then
                local var = getActorVar(actor, id)
                var.payCount = var.payCount + count
                updateDabiao(actor, id, var.payCount)
            elseif conf[1].subType == minType.type35 then
                local var = getActorVar(actor, id)
                var.recharge = var.recharge + count
                local num = math.floor(var.recharge / ActivityCommonConfig.act35LuckyScore)
                var.recharge = var.recharge - num * ActivityCommonConfig.act35LuckyScore
                var.luckyScore = var.luckyScore + num
                updateDabiao(actor, id, var.luckyScore)
            end
            temp[id] = true
        end
    end
end

function onAddDuobaoScore(actor, score, id)
    local config = ActivityType1Config[id]
    if not config then return end
    if not activitymgr.activityTimeIsEnd(id) and config[1].subType == minType.duobaoscore then
        local var = getActorVar(actor, id)
        var.duobaoscore = var.duobaoscore + score
        updateDabiao(actor, id, var.duobaoscore)
    end
end

function addXunbaoScore(actor, id, score)
    local config = ActivityType1Config[id]
    if not config then return end
    if not activitymgr.activityTimeIsEnd(id) and config[1].subType == minType.xunbaoscore then
        local var = getActorVar(actor, id)
        var.xunbaoscore = var.xunbaoscore + score
        updateDabiao(actor, id, var.xunbaoscore)
    end
end

function addSendGiftScore(actor, score)
    -- local config = ActivityType1Config[id]
    -- if not config then return end
    for id, v in pairs(ActivityType1Config) do
        if not activitymgr.activityTimeIsEnd(id) and v[1].subType == minType.sendgift then
            local var = getActorVar(actor, id)
            var.score = var.score + score
            updateDabiao(actor, id, var.score)
        end
    end
end

function addZaDanScore(actor, score)
    -- local config = ActivityType1Config[id]
    -- if not config then return end
    for id, v in pairs(ActivityType1Config) do
        if not activitymgr.activityTimeIsEnd(id) and v[1].subType == minType.zadan then
            local var = getActorVar(actor, id)
            var.score = var.score + score
            updateDabiao(actor, id, var.score)
        end
    end
end

function addType40selfScore(actor, score)
    -- local config = ActivityType1Config[id]
    -- if not config then return end
    for id, v in pairs(ActivityType1Config) do
        if not activitymgr.activityTimeIsEnd(id) and v[1].subType == minType.type40self then
            local var = getActorVar(actor, id)
            var.score = var.score + score
            updateDabiao(actor, id, var.score)
        end
    end
end

function getSendScore(actor)
    for id, v in pairs(ActivityType1Config) do
        if v[1].subType == minType.sendgift and not activitymgr.activityTimeIsEnd(id) then
            local var = getActorVar(actor, id)
            return var.score
        end
    end
    return 0
end

function onLevelUp(actor, level, oldLevel)
    for id, v in pairs(ActivityType1Config) do
        if v[1].subType == minType.level and not activitymgr.activityTimeIsEnd(id) then
            updateDabiao(actor, id, level)
        end
    end
end

function onDamonLevel(actor, level)
    for id, v in pairs(ActivityType1Config) do
        if v[1].sType == sType.damon and not activitymgr.activityTimeIsEnd(id) then
            updateDabiao(actor, id, level)
        end
    end
end
function onShenmoLevel(actor, level)
    for id, v in pairs(ActivityType1Config) do
        if v[1].sType == sType.shenmo and not activitymgr.activityTimeIsEnd(id) then
            updateDabiao(actor, id, level)
        end
    end
end
function onShenqiLv(actor, level)
    for id, v in pairs(ActivityType1Config) do
        if v[1].sType == sType.shenqi and not activitymgr.activityTimeIsEnd(id) then
            updateDabiao(actor, id, level)
        end
    end
end
function onShenzhuangLv(actor, level)
    for id, v in pairs(ActivityType1Config) do
        if v[1].sType == sType.shenzhuang and not activitymgr.activityTimeIsEnd(id) then
            updateDabiao(actor, id, level)
        end
    end
end
function onMeilinLv(actor, level)
    for id, v in pairs(ActivityType1Config) do
        if v[1].sType == sType.meilin and not activitymgr.activityTimeIsEnd(id) then
            updateDabiao(actor, id, level)
        end
    end
end
function onYongbingLevel(actor, level)
    for id, v in pairs(ActivityType1Config) do
        if v[1].sType == sType.yongbing and not activitymgr.activityTimeIsEnd(id) then
            updateDabiao(actor, id, level)
        end
    end
end
function onWingLevelUp(actor, level)
    for id, v in pairs(ActivityType1Config) do
        if v[1].sType == sType.wing and not activitymgr.activityTimeIsEnd(id) then
            updateDabiao(actor, id, level)
        end
    end
end
function onCumstomChange(actor, custom, old)
    for id, v in pairs(ActivityType1Config) do
        if v[1].subType == minType.custom and not activitymgr.activityTimeIsEnd(id) then
            updateDabiao(actor, id, custom)
        end
    end
end
function onWanmoFuben(actor, floor)
    for id, v in pairs(ActivityType1Config) do
        if v[1].subType == minType.floor and not activitymgr.activityTimeIsEnd(id) then
            updateDabiao(actor, id, floor)
        end
    end
end
function onHeianFuben(actor, floor)
    for id, v in pairs(ActivityType1Config) do
        if v[1].subType == minType.heian and not activitymgr.activityTimeIsEnd(id) then
            updateDabiao(actor, id, floor)
        end
    end
end

function sendSCDaBiao(id, count)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCActiivityCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCActiivityCmd_Act1DaBiao)
    
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt64(pack, count)

    local crossId = csbase.getCrossServerId() or 0
    System.sendPacketToAllGameClient(pack, crossId)
end

local function onSCDaBiao(sId, sType, dp)
    if System.isBattleSrv() then
        local id = LDataPack.readInt(dp)
        local count = LDataPack.readInt64(dp)
        
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCActiivityCmd)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCActiivityCmd_Act1DaBiao)
        
        LDataPack.writeInt(pack, id)
        LDataPack.writeInt64(pack, count)
        System.sendPacketToAllGameClient(pack, 0)
    elseif System.isCommSrv() then
        local id = LDataPack.readInt(dp)
        local count = LDataPack.readInt64(dp)
        if activitymgr.activityTimeIsEnd(id) then return end
        local conf = ActivityType1Config[id]
        if not conf then return end

        if conf[1].subType == minType.type40all then
            local data = getSystemVar(id)
            data.score = data.score + count
            --broadDabiao(id, data.score)
        end
    end
end


subactivitymgr.initFuncs[subType] = function(id, conf)
    --actorevent.reg(aeNewDayArrive, onNewDayLogin(id, conf))
    actorevent.reg(aeUserLogout, onActorLogout(id, conf))
end

function regRewardCallback(id, fn)
    rewardCallbak[id] = fn
end

function init()
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_UpdateDaBiao, c2sUpdateDaBiao)
    
    csmsgdispatcher.Reg(CrossSrvCmd.SCActiivityCmd, CrossSrvSubCmd.SCActiivityCmd_Act1DaBiao, onSCDaBiao)

    actorevent.reg(aeHeianFuben, onHeianFuben)
    actorevent.reg(aeWanmoFuben, onWanmoFuben)
    actorevent.reg(aeCustomChange, onCumstomChange)
    actorevent.reg(aeDamonLevel, onDamonLevel)
    actorevent.reg(aeShenmoLevel, onShenmoLevel)
    actorevent.reg(aeShenqiLevelUp, onShenqiLv)--神器升级
    actorevent.reg(aeShenzhuangLevelUp, onShenzhuangLv)--神装升级
    actorevent.reg(aeMeilinLevelUp, onMeilinLv)--梅林升级
    actorevent.reg(aeYongbingLevel, onYongbingLevel)--佣兵升级
    actorevent.reg(aeWingLevelUp, onWingLevelUp)
    actorevent.reg(aeLevel, onLevelUp)
    actorevent.reg(aeCostItem, onCostItem)
    actorevent.reg(aeConsumeYuanbao, onConsumeYuanbao)
    actorevent.reg(aeConsumeDiamond, onConsumeDiamond)
    if System.isCrossWarSrv() then return end
    actorevent.reg(aeRecharge, onRecharge)
    actorevent.reg(aeDuobaoScore, onAddDuobaoScore)
    actorevent.reg(aeYuanbaoDrawScore, onAddYuanbaoDraw)
    actorevent.reg(aeDespairBoss, onKillBoss)
    subactivitymgr.regNewDayFunc(subType, onBeforeNewDay)
    subactivitymgr.regActivityFinish(subType, onActivityFinish)
    --subactivitymgr.regTimeOut(subType, onTimeOut)
    subactivitymgr.regNewDayAfterFunc(subType, onAfterNewDay)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    subactivitymgr.regGetRewardFunc(subType, onGetReward)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
-- 增加达标类型的值
function gmCmdHandlers.type1Add(actor, args)
    local stype = tonumber(args[1])
    if stype == nil then
        print('stype==nil')
        return
    end
    local value = tonumber(args[2]) or 1
    addSubTypeValue(actor, stype, value)
    return true
end

-- 领取达标类型奖励
function gmCmdHandlers.type1Get(actor, args)
    local config = subactivitymgr.getConfig(1)
    if config == nil then
        print('config==nil')
        return
    end
    
    local id = tonumber(args[1])
    if id == nil then
        print('id==nil')
        return
    end
    
    local idx = tonumber(args[2]) or 1
    local record = activitymgr.getSubVar(actor, id)
    onGetReward(actor, config, id, idx, record)
    return true
end

-- 达标活动id结束
function gmCmdHandlers.type1End(actor, args)
    local config = subactivitymgr.getConfig(1)
    if config == nil then
        print('config==nil')
        return
    end
    
    local id = tonumber(args[1])
    if id == nil then
        print('id==nil')
        return
    end
    local record = activitymgr.getSubVar(actor, id)
    --onTimeOut(id, config, actor, record)
    return true
end

function gmCmdHandlers.gmclearrecord(actor, args)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
    LDataPack.writeByte(npack, 1)
    LDataPack.writeInt(npack, 1001)
    LDataPack.writeShort(npack, 1)
    LDataPack.writeDouble(npack, 0)
    LDataPack.flush(npack)
end

function gmCmdHandlers.gmOnRecharge(actor, args)
    local count = tonumber(args[1])
    onRecharge(actor, count)
end

