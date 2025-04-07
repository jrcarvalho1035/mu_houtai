-- @version1.0
-- @authorqianmeng
-- @date2017-1-9 17:38:23.
-- @systemactoritem

module("actoritem", package.seeall)
require("item.currencydata")

--检查这物品是否货币
function isCurrency(id)
    if id == NumericType_Exp --经验
        or id == NumericType_Gold --金币
        or id == NumericType_YuanBao --钻石
        or id == NumericType_Essence--魔晶
        or id == NumericType_StarValue--星魂
        or id == NumericType_Feats--功勋
        or id == NumericType_Recharge--充值钻石
        or id == NumericType_TalentValue --天赋值
        or id == NumericType_Diamond --点券
        then
        return true
    end
    return false
end

local spe_currency_list = {
    [NumericType_Crystal] = true, --灵晶
    [NumericType_GuildContrib] = true, --公会贡献
    [NumericType_GuildFund] = true, --公会资金
    [NumericType_Powder] = true, --元素粉末
    [NumericType_Debris] = true, --精灵积分
    [NumericType_Integral] = true, --神秘商店刷新积分
    [NumericType_Mark] = true, --成就点
    [NumericType_Cream] = true, --元素精华
    [NumericType_Guard] = true, --守护值
    [NumericType_Honor] = true, --荣誉
    [NumericType_Chip] = true, --紫色碎片
    [NumericType_DarkStone] = true, --暗黑之石
    [NumericType_SeerSoul] = true, --先知之魂
    [NumericType_SiegeScore] = true, --怪物攻城积分
    [NumericType_Renown] = true, --声望
    [NumericType_Spar] = true, --图鉴经验
    [NumericType_MountScore] = true, --坐骑积分
    [NumericType_CSTTHonour] = true, --跨服天梯荣誉点
    [NumericType_Jetton] = true, --城战能量
    [NumericType_LianjinExp] = true, --炼金经验,特殊处理，直接加到炼金阵上
    [NumericType_SoulValue] = true, --先魂值
    [NumericType_Adventure] = true, -- 奇遇点
    [NumericType_Secret] = true, -- 谜语结晶
    [NumericType_DartToken] = true, --掠夺令
    [NumericType_DartScore] = true, --押镖积分
    [NumericType_Shouhun] = true, --兽魂积分
    [NumericType_ContributionCamp] = true, --阵营贡献
    [NumericType_HFCupScore] = true, --巅峰积分(合服64强)
    [NumericType_ZhanQuBi] = true, --战区币
}

--是否属于特殊货币
function isSpeCurrency(id)
    if spe_currency_list[id] then
        return true
    end
    return false
end

local equicolor = {"0xcdc8be", "0x13ee22", "0x23becd", "0xcd8cff", "0xff9b0f", "0xff0000", "0xff0000", "0xff0000", "0xff0000", "0xff0000", "0xff0000"}
function getColor(id)
    return equicolor[ItemConfig[id].quality + 1]
end

--是否装备道具
function isEquip(itemConf)
    return itemConf and (itemConf.type == ItemType_Equip
        --or itemConf.type ==  ItemType_WingEquip
        --or itemConf.type ==  ItemType_GodEquip
        or itemConf.type == ItemType_TianEquip
        --or itemConf.type ==  ItemType_MountEquip
    )
end

-- 是否足迹装备
function isFootEquip(itemConf)
    return itemConf and itemConf.type == ItemType_FootEquip
end

function isElement(itemConf)
    return itemConf and itemConf.type == ItemType_Element
end

function isHuanshouEquip(itemConf)
    return itemConf and itemConf.type == ItemType_HuanshouEquip
end

function getSpeCurrency(actor, id)
    local actorVar = LActor.getStaticVar(actor)
    if id == NumericType_Crystal then
        return actorVar.crystal or 0
    elseif id == NumericType_GuildContrib then --战盟战功
        return guildcommon.getContrib(actor)
    elseif id == NumericType_GuildFund then --战盟资金
        local guildId = LActor.getGuildId(actor)
        if guildId == 0 then return 0 end
        return guildcommon.getGuildFundById(guildId)
    elseif id == NumericType_Powder then
        return actorVar.powder or 0
    elseif id == NumericType_Debris then
        return actorVar.debris or 0
    elseif id == NumericType_Integral then
        return actorVar.integral or 0
    elseif id == NumericType_Mark then
        return actorVar.mark or 0
    elseif id == NumericType_Cream then
        return actorVar.cream or 0
    elseif id == NumericType_Guard then
        return actorVar.guard or 0
    elseif id == NumericType_Honor then
        return actorVar.honor or 0
    elseif id == NumericType_Chip then
        return actorVar.chip or 0
    elseif id == NumericType_DarkStone then
        return actorVar.darkstone or 0
    elseif id == NumericType_SeerSoul then
        return actorVar.seersoul or 0
    elseif id == NumericType_SiegeScore then
        return actorVar.msscore or 0
    elseif id == NumericType_Renown then
        return liliansystem.getRenown(actor)
    elseif id == NumericType_Spar then
        return actorVar.spar or 0
    elseif id == NumericType_MountScore then
        return actorVar.mountscore or 0
    elseif id == NumericType_CSTTHonour then
        return compatmoney.getCSTTHonourValue(actor)
    elseif id == NumericType_Jetton then
        return actorVar.jetton or 0
    elseif id == NumericType_Adventure then
        return actorVar.adventure or 0
    elseif id == NumericType_Secret then
        return actorVar.secret or 0
    elseif id == NumericType_DartToken then
        return actorVar.darttoken or 0
    elseif id == NumericType_DartScore then
        return actorVar.dartscore or 0
    elseif id == NumericType_Shouhun then
        return actorVar.shouhun or 0
    elseif id == NumericType_ContributionCamp then
        return actorVar.contributioncamp or 0
    elseif id == NumericType_HFCupScore then
        return actorVar.hfcupScore or 0
    elseif id == NumericType_ZhanQuBi then
        return actorVar.zhanqubi or 0
    end
    return 0
end

function changeSpeCurrency(actor, id, number, log, tp)
    local actorVar = LActor.getStaticVar(actor)
    local currency = "unknown"
    local old = 0
    if id == NumericType_Crystal then
        old = actorVar.crystal or 0
        actorVar.crystal = old + number
        s2cMoneyUpdate(actor, NumericType_Crystal, actorVar.crystal, tp)
        currency = "crystal"
    elseif id == NumericType_GuildContrib then
        if System.isCommSrv() then
            old = guildcommon.getContrib(actor)
            guildcommon.changeContrib(actor, number, log)
            s2cMoneyUpdate(actor, NumericType_GuildContrib, guildcommon.getContrib(actor), tp)
            currency = "contrib"
        else
            guildcommon.changeContrib(actor, number, log)
            LGuild.changeTotalGx(LActor.getActorId(actor), number)
        end
    elseif id == NumericType_GuildFund then
        local guildId = LActor.getGuildId(actor)
        if guildId == 0 then return end
        old = guildcommon.getGuildFundById(guildId)
        guildcommon.changeGuildFund(guildId, number, actor, log)
        s2cMoneyUpdate(actor, NumericType_GuildFund, guildcommon.getGuildFundById(guildId), tp)
        currency = "fund"
    elseif id == NumericType_Powder then
        old = actorVar.powder or 0
        actorVar.powder = (actorVar.powder or 0) + number
        s2cMoneyUpdate(actor, NumericType_Powder, actorVar.powder, tp)
        currency = "powder"
    elseif id == NumericType_Debris then
        old = actorVar.debris or 0
        actorVar.debris = (actorVar.debris or 0) + number
        s2cMoneyUpdate(actor, NumericType_Debris, actorVar.debris, tp)
        currency = "debris"
    elseif id == NumericType_Integral then
        old = actorVar.integral or 0
        actorVar.integral = (actorVar.integral or 0) + number
        s2cMoneyUpdate(actor, NumericType_Integral, actorVar.integral, tp)
        currency = "integral"
    elseif id == NumericType_Mark then
        old = actorVar.mark or 0
        actorVar.mark = (actorVar.mark or 0) + number
        s2cMoneyUpdate(actor, NumericType_Mark, actorVar.mark, tp)
        currency = "mark"
    elseif id == NumericType_Cream then
        old = actorVar.cream or 0
        actorVar.cream = (actorVar.cream or 0) + number
        s2cMoneyUpdate(actor, NumericType_Cream, actorVar.cream, tp)
        currency = "cream"
    elseif id == NumericType_Guard then
        old = actorVar.guard or 0
        actorVar.guard = (actorVar.guard or 0) + number
        s2cMoneyUpdate(actor, NumericType_Guard, actorVar.guard, tp)
        currency = "guard"
    elseif id == NumericType_Honor then
        old = actorVar.honor or 0
        actorVar.honor = (actorVar.honor or 0) + number
        s2cMoneyUpdate(actor, NumericType_Honor, actorVar.honor, tp)
        currency = "honor"
    elseif id == NumericType_Chip then
        old = actorVar.chip or 0
        actorVar.chip = (actorVar.chip or 0) + number
        s2cMoneyUpdate(actor, NumericType_Chip, actorVar.chip, tp)
        currency = "chip"
    elseif id == NumericType_DarkStone then
        old = actorVar.darkstone or 0
        actorVar.darkstone = (actorVar.darkstone or 0) + number
        s2cMoneyUpdate(actor, NumericType_DarkStone, actorVar.darkstone, tp)
        currency = "darkstone"
    elseif id == NumericType_SeerSoul then
        old = actorVar.seersoul or 0
        actorVar.seersoul = (actorVar.seersoul or 0) + number
        s2cMoneyUpdate(actor, NumericType_SeerSoul, actorVar.seersoul, tp)
        currency = "seersoul"
    elseif id == NumericType_SiegeScore then
        old = actorVar.msscore or 0
        actorVar.msscore = (actorVar.msscore or 0) + number
        s2cMoneyUpdate(actor, NumericType_SiegeScore, actorVar.msscore, tp)
        currency = "msscore"
        monstersiege.addScore(actor, number)
    elseif id == NumericType_Renown then
        liliansystem.addRenown(actor, number)
        s2cMoneyUpdate(actor, NumericType_Renown, liliansystem.getRenown(actor), tp)
        currency = "renown"
    elseif id == NumericType_Spar then
        old = actorVar.spar or 0
        actorVar.spar = (actorVar.spar or 0) + number
        s2cMoneyUpdate(actor, NumericType_Spar, actorVar.spar, tp)
        currency = "spar"
    elseif id == NumericType_MountScore then
        old = actorVar.mountscore or 0
        actorVar.mountscore = (actorVar.mountscore or 0) + number
        s2cMoneyUpdate(actor, NumericType_MountScore, actorVar.mountscore, tp)
        currency = "mountscore"
    elseif id == NumericType_CSTTHonour then
        old = compatmoney.getCSTTHonourValue(actor)
        local new = compatmoney.changeCSTTHonourValue(actor, number)
        s2cMoneyUpdate(actor, NumericType_CSTTHonour, new, tp)
        currency = "cstthonour"
    elseif id == NumericType_Jetton then
        old = actorVar.jetton or 0
        actorVar.jetton = (actorVar.jetton or 0) + number
        s2cMoneyUpdate(actor, NumericType_Jetton, actorVar.jetton, tp)
        currency = "jetton"
    elseif id == NumericType_LianjinExp then
        equipsystem.addSmeltExp(actor, number, {})
    elseif id == NumericType_Adventure then
        old = actorVar.adventure or 0
        actorVar.adventure = (actorVar.adventure or 0) + number
        s2cMoneyUpdate(actor, NumericType_Adventure, actorVar.adventure, tp)
        currency = "adventure"
    elseif id == NumericType_Secret then
        old = actorVar.secret or 0
        actorVar.secret = (actorVar.secret or 0) + number
        s2cMoneyUpdate(actor, NumericType_Secret, actorVar.secret, tp)
        currency = "secret"
    elseif id == NumericType_DartToken then
        old = actorVar.darttoken or 0
        actorVar.darttoken = (actorVar.darttoken or 0) + number
        s2cMoneyUpdate(actor, NumericType_DartToken, actorVar.darttoken, tp)
        currency = "darttoken"
    elseif id == NumericType_DartScore then
        old = actorVar.dartscore or 0
        actorVar.dartscore = (actorVar.dartscore or 0) + number
        s2cMoneyUpdate(actor, NumericType_DartScore, actorVar.dartscore, tp)
        currency = "dartscore"
    elseif id == NumericType_Shouhun then
        old = actorVar.shouhun or 0
        actorVar.shouhun = (actorVar.shouhun or 0) + number
        s2cMoneyUpdate(actor, NumericType_Shouhun, actorVar.shouhun, tp)
        currency = "shouhun"
    elseif id == NumericType_ContributionCamp then
        old = actorVar.contributioncamp or 0
        actorVar.contributioncamp = (actorVar.contributioncamp or 0) + number
        s2cMoneyUpdate(actor, NumericType_ContributionCamp, actorVar.contributioncamp, tp)
        currency = "contributioncamp"
    elseif id == NumericType_HFCupScore then
        old = actorVar.hfcupScore or 0
        actorVar.hfcupScore = (actorVar.hfcupScore or 0) + number
        s2cMoneyUpdate(actor, NumericType_HFCupScore, actorVar.hfcupScore, tp)
        currency = "hfcupScore"
    elseif id == NumericType_ZhanQuBi then
        old = actorVar.zhanqubi or 0
        actorVar.zhanqubi = (actorVar.zhanqubi or 0) + number
        s2cMoneyUpdate(actor, NumericType_ZhanQuBi, actorVar.zhanqubi, tp)
        currency = "zhanqubi"
    end
    local kingdom = number > 0 and "earning" or "expenditure"
    utils.logEnconomy(actor, currency, number, "1", kingdom, log, old)
end
_G.changeCurrency = changeSpeCurrency

--找到物品数量
function getItemCount(actor, id)
    if isSpeCurrency(id) then
        return getSpeCurrency(actor, id)
    elseif isCurrency(id) then
        return LActor.getCurrency(actor, id)
    else
        return LActor.getItemCount(actor, id)
    end
    return 0
end

--检查玩家物品是否足够
function checkItem(actor, id, number)
    local curCount = 0
    if isSpeCurrency(id) then
        curCount = getSpeCurrency(actor, id)
    elseif isCurrency(id) then
        curCount = LActor.getCurrency(actor, id)
    else
        curCount = LActor.getItemCount(actor, id)
    end
    return number <= curCount
end

--检查玩家物品是否足够
function checkItems(actor, items)
    local actoritems = getItemsByJob(actor, items)
    for k, v in pairs(actoritems) do
        local curCount = 0
        if isSpeCurrency(v.id) then
            curCount = getSpeCurrency(actor, v.id)
        elseif isCurrency(v.id) then
            curCount = LActor.getCurrency(actor, v.id)
        else
            curCount = LActor.getItemCount(actor, v.id)
        end
        if (v.count > curCount) then
            return false
        end
    end
    return true
end

--扣除单个物品接口
function reduceItem(actor, id, number, log)
    if number < 0 then return end
    if isSpeCurrency(id) then
        changeSpeCurrency(actor, id, -number, log)
    elseif isCurrency(id) then
        LActor.changeCurrency(actor, id, -number, log)
    else
        LActor.costItem(actor, id, number, log)
    end
    return true
end

--扣除物品接口
function reduceItems(actor, items, log)
    local actoritems = getItemsByJob(actor, items)
    for k, v in pairs(actoritems) do
        reduceItem(actor, v.id, v.count, log)
    end
    return true
end

--增加单个物品接口
function addItem(actor, id, number, log, tp)
    if number < 0 then return end
    tp = tp or 0
    if isSpeCurrency(id) then
        changeSpeCurrency(actor, id, number, log, tp)
    elseif isCurrency(id) then
        LActor.changeCurrency(actor, id, number, log, tp)
    elseif ItemConfig[id] then
        if ItemConfig[id].type == ItemType_Shenshou then
            shenshousystem.addShenShou(actor, id, number)
        else
            if ElementBaseConfig[id] then
                id = ElementBaseConfig[id].soleid
            end
            LActor.giveItem(actor, id, number, log, tp)
            if privilege.isBuyPrivilege(actor) and LActor.getEquipBagSpace(actor) == 0 then
                LActor.smeltAllEquip(actor)
                actorevent.onEvent(actor, aeSmeltEquip, 1)
            end
        end
    elseif ElementLevelConfig[id] then
        LActor.giveItem(actor, id, number, log, tp)
    else
        utils.printInfo("addItem not the item id:", id)
    end
    
    actorevent.onEvent(actor, aeItemAdd, id, number)
    return true
end

--增加物品接口
function addItems(actor, items, log, tp)
    addItemsByJob(actor, items, log, tp)
end

--根据装备背包剩余格子数来增加物品，格子数不能放下所有装备的，让其按平均的份额加入背包
function addItemsBySpace(actor, items, log, tp)
    tp = tp or 0
    local space = LActor.getEquipBagSpace(actor) --剩余空间
    local temp = {} --装进背包的物品
    --先把每件装备放一个进背包
    for k, v in pairs(items) do
        local itemConf = ItemConfig[v.id]
        if itemConf and isEquip(itemConf) then --装备添加要判断数量
            local count = math.min(space, 1)
            if count > 0 then
                LActor.giveItem(actor, v.id, count, log, tp)
                table.insert(temp, {type = v.type, id = v.id, count = count})
            end
            space = space - count
        end
    end
    local sum = 0 --剩余装备数量
    for k, v in pairs(items) do
        local itemConf = ItemConfig[v.id]
        if itemConf and isEquip(itemConf) then
            sum = sum + v.count
        end
    end
    local rate = 1 --根据剩余格子求出装备放入的份额
    if space < sum then
        rate = space / sum
    end
    
    for k, v in pairs(items) do
        local itemConf = ItemConfig[v.id]
        if itemConf and isEquip(itemConf) then --装备添加要判断数量
            if space > 0 then
                local count = math.ceil((v.count - 1) * rate)
                count = math.min(count, space)
                if count > 0 then
                    LActor.giveItem(actor, v.id, count, log, tp)
                    table.insert(temp, {type = v.type, id = v.id, count = count})
                end
                space = space - count
            end
        else
            addItem(actor, v.id, v.count, log, tp)
            table.insert(temp, {type = v.type, id = v.id, count = v.count})
        end
    end
    return temp
end

--背包格子数不够的物品，变成邮件
function addItemsByMail(actor, items, log, tp, text)
    local temp = {} --没法拿的物品
    local equspa = LActor.getEquipBagSpace(actor)
    local foot_eq_space = LActor.getFootEquipBagSpace(actor)
    local huanshou_eq_space = LActor.getHanshouEquipBagSpace(actor)
    for k, v in pairs(items) do
        local itemConf = ItemConfig[v.id]
        if itemConf then
            if isEquip(itemConf) then
                if equspa >= v.count then
                    addItem(actor, v.id, v.count, log, tp)
                    equspa = equspa - v.count
                else
                    table.insert(temp, {type = v.type, id = v.id, count = v.count})
                end
            elseif isFootEquip(itemConf) then
                if foot_eq_space >= v.count then
                    addItem(actor, v.id, v.count, log, tp)
                    foot_eq_space = foot_eq_space - v.count
                else
                    table.insert(temp, {type = v.type, id = v.id, count = v.count})
                end
            elseif isHuanshouEquip(itemConf) then
                if huanshou_eq_space >= v.count then
                    addItem(actor, v.id, v.count, log, tp)
                    huanshou_eq_space = huanshou_eq_space - v.count
                else
                    table.insert(temp, {type = v.type, id = v.id, count = v.count})
                end
            else
                addItem(actor, v.id, v.count, log, tp)
            end
        else
            addItem(actor, v.id, v.count, log, tp)
        end
    end
    if #temp > 0 then
        local context = ScriptContents[text] or ScriptContents.context1
        local mailData = {head = ScriptContents.head1, context = context, tAwardList = temp}
        mailsystem.sendMailById(LActor.getActorId(actor), mailData)
    end
end

--计算装备熔炼后的星魂值
local function smeltEquip(equipId)
    local conf = ItemConfig[equipId]
    if not conf then
        return 0
    end
    return SmeltConfig[conf.rank][conf.quality]
end

--留下当前职业每部位评分最高的装备，其余熔炼
function getItemsByScore(actor, items, log, tp)
    local items0 = {} --最终奖励物
    for k, v in pairs(items) do
        local conf = ItemConfig[v.id]
        if conf and conf.type == 0 and conf.job > 0 then --是装备
            for kk, vv in ipairs(SmeltConfig[conf.rank][conf.quality].additem) do
                items0[vv.id] = (items0[vv.id] or 0) + vv.count
            end
        else
            items0[v.id] = (items0[v.id] or 0) + v.count --物品加入奖励
        end
    end
    local rewards = changeItemFormat(items0) --转移格式
    rewards = utils.sortItem(rewards) --排序
    return rewards
end

--留下当前职业每部位评分最高的装备，其余熔炼
function addItemsByScore(actor, items, log, tp)
    local items0 = {} --最终奖励物
    for k, v in pairs(items) do
        local conf = ItemConfig[v.id]
        if conf and conf.type == 0 and conf.type == ItemType_Equip then --是装备
            for kk, vv in ipairs(SmeltConfig[conf.rank][conf.quality].additem) do
                items0[vv.id] = (items0[vv.id] or 0) + vv.count
            end
        else
            items0[v.id] = (items0[v.id] or 0) + v.count --物品加入奖励
        end
    end
    local rewards = changeItemFormat(items0) --转移格式
    rewards = utils.sortItem(rewards) --排序
    addItems(actor, rewards, log, tp)
    return rewards
end

--加入寻宝背包
function addXunbaoItems(actor, items, log)
    tp = tp or 0
    for k, v in pairs(items) do
        if ItemConfig[v.id] or ElementLevelConfig[v.id] then
            LActor.giveXunbaoItem(actor, v.id, v.count, log, tp)
        else
            utils.printInfo("addXunbaoItem not the item id:", id)
        end
    end
end

function addJinzhuanItems(actor, items, log)
    tp = tp or 0
    for k, v in pairs(items) do
        if ItemConfig[v.id] or ElementLevelConfig[v.id] then
            LActor.giveJinzhuanItem(actor, v.id, v.count, log, tp)
        else
            utils.printInfo("addJinzhuanItem not the item id:", id)
        end
    end
end

--通过职业来进行奖励，超出的发邮件
function addItemsByJob(actor, items, log, tp, text)
    local space = LActor.getEquipBagSpace(actor) --剩余空间
    local space1 = LActor.getHanshouEquipBagSpace(actor) --剩余空间
    
    local temp = {} --没法拿的物品
    for k, v in pairs(items) do
        local itemConf = ItemConfig[v.id]
        if itemConf and isEquip(itemConf) then --装备添加要判断数量
            if (not v.job) or (v.job == 1) then --判断是否有职业限制
                local count = math.min(space, v.count)
                if count > 0 then
                    addItem(actor, v.id, count, log, tp)
                end
                if v.count > count then
                    table.insert(temp, {type = v.type, id = v.id, count = v.count - count})
                end
                space = space - count
            end
        elseif itemConf and isHuanshouEquip(itemConf) then
            if (not v.job) or (v.job == 1) then
                local count = math.min(space1, v.count)
                if count > 0 then
                    addItem(actor, v.id, count, log, tp)
                end
                if v.count > count then
                    table.insert(temp, {type = v.type, id = v.id, count = v.count - count})
                end
                space1 = space1 - count
            end
        else
            if (not v.job) or (v.job == 1) then --判断是否有职业限制
                addItem(actor, v.id, v.count, log, tp)
            end
        end
    end
    if #temp > 0 then
        local context = ScriptContents[text] or ScriptContents.context1
        local mailData = {head = ScriptContents.head1, context = context, tAwardList = temp}
        mailsystem.sendMailById(LActor.getActorId(actor), mailData)
    end
end

--根据职业返回奖励
function getItemsByJob(actor, items)
    local job = LActor.getJob(actor)
    local temp = {}
    for k, v in pairs(items) do
        if (not v.job) or (v.job == 1) then
            table.insert(temp, v)
        end
    end
    return temp
end

--根据职业返回奖励
function getItemsByJobId(job, items)
    local temp = {}
    for k, v in pairs(items) do
        if (not v.job) or (v.job == job) then
            table.insert(temp, v)
        end
    end
    return temp
end

--物品格式变换
function changeItemFormat(items0)
    local items = {}
    for k, v in pairs(items0) do
        local tp = (isCurrency(k) or isSpeCurrency(k)) and 0 or 1
        table.insert(items, {type = tp, id = k, count = v})
    end
    return items
end

--合并物品组
function mergeItems(...)
    --at = os.clock()
    local items0 = {}
    for k, items in pairs(arg) do
        if type(items) == "table" then
            for k1, item in pairs(items) do
                items0[item.id] = (items0[item.id] or 0) + item.count
            end
        end
    end
    local items = changeItemFormat(items0)
    --utils.printInfo("mergeItems use time:", os.clock() - at)
    return items
end

--合并双重物品表
function mergeItemsTable(itemTabs)
    local at = os.clock()
    local items0 = {}
    for k, items in pairs(itemTabs) do
        for k1, item in pairs(items) do
            items0[item.id] = (items0[item.id] or 0) + item.count
        end
    end
    local items = changeItemFormat(items0)
    utils.printInfo("mergeItemsTable use time:", os.clock() - at)
    return items
end

--求物品将占用的背包空间
function getItemsSpace(items)
    local count = 0
    for _, item in ipairs(items) do
        local itemConf = ItemConfig[item.id]
        if itemConf and isEquip(itemConf) then
            count = count + 1
        end
    end
    return count
end

--领取职业限制物品时判断背包空间
function checkEquipBagSpaceJob(actor, items)
    local needSpace = 0
    local needElement = 0
    local needFootEq = 0
    local needHuanshouEq = 0
    for _, item in ipairs(items) do
        local itemConf = ItemConfig[item.id]
        if itemConf and isEquip(itemConf) then
            needSpace = needSpace + 1
        elseif itemConf and isElement(itemConf) then
            needElement = needElement + 1
        elseif itemConf and isFootEquip(itemConf) then
            needFootEq = needFootEq + 1
        elseif itemConf and isHuanshouEquip(itemConf) then
            needHuanshouEq = needHuanshouEq + 1
        end
    end
    if LActor.getEquipBagSpace(actor) < needSpace then
        LActor.sendTipmsg(actor, ScriptTips.bag02, ttScreenCenter)
        return false
    end
    if LActor.getElementBagSpace(actor) < needElement then
        LActor.sendTipmsg(actor, ScriptTips.bag03, ttScreenCenter)
        return false
    end
    if LActor.getFootEquipBagSpace(actor) < needFootEq then
        LActor.sendTipmsg(actor, ScriptTips.bag04, ttScreenCenter)
        return false
    end
    if LActor.getHanshouEquipBagSpace(actor) < needHuanshouEq then
        LActor.sendTipmsg(actor, ScriptTips.bag07, ttScreenCenter)
        return false
    end    
    return true
end

function checkBagSpaceByItem(actor, id, number)
    local itemConf = ItemConfig[id]
    if itemConf and isEquip(itemConf) and LActor.getEquipBagSpace(actor) < number then
        LActor.sendTipmsg(actor, ScriptTips.bag02, ttScreenCenter)
        return false
    elseif itemConf and isElement(itemConf) and LActor.getElementBagSpace(actor) < number then
        LActor.sendTipmsg(actor, ScriptTips.bag03, ttScreenCenter)
        return false
    elseif itemConf and isFootEquip(itemConf) and LActor.getFootEquipBagSpace(actor) < number then
        LActor.sendTipmsg(actor, ScriptTips.bag04, ttScreenCenter)
        return false
    elseif itemConf and isHuanshouEquip(itemConf) and LActor.getHanshouEquipBagSpace(actor) < number then
        LActor.sendTipmsg(actor, ScriptTips.bag07, ttScreenCenter)
        return false
    end
    return true
end

function getValueByItems(items, id)
    for k, v in pairs(items) do
        if v.id == id then
            return v.count, k
        end
    end
    return 0, nil
end
-------------------------------------------------------------------------------------------

--更新时发送
function s2cMoneyUpdate(actor, id, number, tp)
    tp = tp or 0
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_UpdateMoney)
    LDataPack.writeShort(pack, id)
    LDataPack.writeDouble(pack, number)
    LDataPack.writeChar(pack, tp)
    LDataPack.flush(pack)
end

--登录时发送所有的货币数值
function onLogin(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_LoginMoney)
    local pos = LDataPack.getPosition(pack)
    local count = 0
    LDataPack.writeChar(pack, count)
    for id, v in pairs(CurrencyConfig) do
        if id > 0 then
            local number = getItemCount(actor, id)
            LDataPack.writeShort(pack, id)
            LDataPack.writeDouble(pack, number)
            count = count + 1
        end
    end
    if count > 0 then
        local npos = LDataPack.getPosition(pack)
        LDataPack.setPosition(pack, pos)
        LDataPack.writeChar(pack, count)
        LDataPack.setPosition(pack, npos)
    end
    LDataPack.flush(pack)
end

actorevent.reg(aeUserLogin, onLogin)
