-- @version1.0
-- @authorqianmeng
-- @date2017-1-16 18:20:33.
-- @systemdespairboss

--全民Boss
module("despairboss", package.seeall)
require("scene.despairbossdata")
require("scene.despairbosscommon")

--返回全民boss副本
g_despairbossData = g_despairbossData or {}
local function getDespairbossData()
    return g_despairbossData
end

local function getStaticData(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.despairfuben then
        var.despairfuben = {}
        var.despairfuben.count = DespairBossCommonConfig.maxCount --玩家可挑战次数
        var.despairfuben.last_time = 0 --上一次挑战时间
        var.despairfuben.reminds = {}
    end
    if not var.despairfuben.bossId then var.despairfuben.bossId = 0 end --上一个挑战的Boss
    if not var.despairfuben.times then var.despairfuben.times = 0 end --每天挑战次数
    return var.despairfuben
end

--求下一个护盾
function getNextShield(id, hp)
    if nil == hp then hp = 101 end
    
    local conf = DespairBossConfig[id]
    if nil == conf then return nil end
    for i, s in ipairs(conf.shield) do
        if s.hp < hp then return s end
    end
    return nil
end

--更新个人信息
local function updatePersonInfo(actor)
    local data = getStaticData(actor)
    if data.count >= DespairBossCommonConfig.maxCount then
        return
    end
    local now = System.getNowTime()
    local cd = (DespairBossCommonConfig.recoverTime or 0) * 60
    while (data.last_time + cd < now) do
        data.last_time = data.last_time + cd
        data.count = data.count + 1
        if data.count >= DespairBossCommonConfig.maxCount then
            data.last_time = 0
            break
        end
    end
end

local function updateRank(id, force)
    local bossDatas = getDespairbossData()
    local bossData = bossDatas[id]
    if not bossData then
        return
    end
    if not force and not bossData.needUpdate then return end
    bossData.needUpdate = false
    local damageList = bossData.damageList
    if damageList == nil then return end
    
    local rank = {}
    for actorId, v in pairs(damageList) do
        table.insert(rank, {aid = actorId, dmg = v.damage, usedrop = v.usedrop, useindex = v.useindex})
    end
    table.sort(rank, function(a, b) return a.dmg > b.dmg end)
    bossData.rank = rank
    
    --发给副本
    s2cDespairbossRank(id)
end

--是否在做全民副本的任务
function isDespairTask(actor)
    local taskId = maintask.getMainTaskIdx(actor)
    local state = maintask.getMainTaskState(actor)
    local conf = MainTaskConfig[taskId]
    if conf.type == taskcommon.taskType.emPassTypeDup and
        FubenGroupAlias[conf.param[1]] and
        FubenGroupAlias[conf.param[1]].isDespairTask == 1 and
        state == taskcommon.statusType.emDoing then
        return true
    end
    return false
end

function onTimerRobot()
    local bossDatas = getDespairbossData()
    for _, conf in pairs(DespairBossConfig) do
        repeat
            if conf.id > DespairBossCommonConfig.mathmaxindex then break end --指定副本才刷机器人
            
            local bossData = bossDatas[conf.id]
            local actors = Fuben.getAllActor(bossData.hfuben)
            if not actors or #actors > 1 then break end
            if bossData.clonecount >= DespairBossCommonConfig.matchmax then break end
            --定时刷机器人
            local now_t = System.getNowTime()
            if (bossData.robotRefreshTimer or 0) > now_t then break end
            bossData.robotRefreshTimer = now_t + math.random(DespairBossCommonConfig.matchtime[1], DespairBossCommonConfig.matchtime[2])
            
            local robot = 0
            for i = 1, #DespairRobotConfig do
                robot = math.random(1, #DespairRobotConfig)
                if not bossData.damageList[robot] then
                    break
                end
            end
            if robot == 0 then break end
            
            local roleCloneData, actorData, roleSuperData = actorcommon.createRobotClone(DespairRobotConfig, robot)
            
            --机器人属性是玩家属性的百分比
            local roleAttr = LActor.getRoleAttrsCache(actors[1])
            roleCloneData.attrs:Reset()
            for j = Attribute.atHp, Attribute.atCount - 1 do
                if j == Attribute.atShenYouShieldTagNum then
                elseif j ~= Attribute.atMvSpeed then
                    roleCloneData.attrs:Set(j, roleAttr[j] * DespairBossCommonConfig.robotpercent)
                else
                    roleCloneData.attrs:Set(j, roleAttr[j])
                end
            end
            
            if roleSuperData then
                roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
                roleSuperData.aiId = FubenConstConfig.roleSuperAi
            end
            
            local x, y = utils.getSceneEnterCoor(conf.fbId)
            local ins = instancesystem.getInsByHdl(bossData.hfuben)
            local actorClone = LActor.createActorCloneWithData(robot, ins.scene_list[1], x, y, actorData, roleCloneData, roleSuperData)
            bossData.clonecount = (bossData.clonecount or 0) + 1
            
            --local boss = Fuben.getSceneMonsterById(scene, bossData.bossId)
            --LActor.setAITarget(actorClone, boss) --设置目标为boss
            LActor.setCamp(actorClone, CampType_Normal)--设置阵营为普通模式
        until(true)
    end
end

--主线任务事件
local function onMainTaskAccept(actor, taskId)
    if isDespairTask(actor) then
        s2cDespairbossInfo(actor)
        s2cDespairBossList(actor)
    end
end

--登录事件
local function onLogin(actor)
    s2cDespairbossInfo(actor)
    s2cDespairBossList(actor)
end

--每天事件
local function onNewDay(actor, login)
    local var = getStaticData(actor)
    utils.logCounter(actor, "othersystem", var.times, "", "despairboss", "surplus") --记录每天挑战次数
    var.times = 0
end

--定时事件
local function onTimer()
    --定时更新副本内排行榜
    local bossDatas = getDespairbossData()
    for _, conf in pairs(DespairBossConfig) do
        if (bossDatas[conf.id].hpPercent or 100) ~= 0 then
            updateRank(conf.id)
        end
    end
end

local function getMonsterName(id)
    if MonstersConfig[id] then
        return tostring(MonstersConfig[id].name)
    end
    return "nil"
end

--发送击杀boss的公告
local function setNoticeKillboss(actorId, config)
    if config.id >= 3 then --第三个全民boss以后才公告
        local name = ""
        if DespairRobotConfig[actorId] then
            name = DespairRobotConfig[actorId].name
        else
            name = LActor.getActorName(actorId)
        end
        noticesystem.broadCastNotice(noticesystem.NTP.despair, actorcommon.getVipShow(LActor.getActorById(actorId)), name, getMonsterName(config.bossId))
    end
end

local function addReward(treward, sreward, exRate)
	exRate = exRate or 1
    for k, v in ipairs(sreward) do
        local ishave = false
        for i = 1, #treward do
            if v.id == treward[i].id and not actoritem.isEquip(ItemConfig[v.id]) then
                treward[i].count = treward[i].count + v.count * exRate
                ishave = true
                break
            end
        end
        if not ishave then
            table.insert(treward, {type = v.type, id = v.id, count = v.count * exRate})
        end
    end
end

local function refreshBoss(_, id)
    local bossDatas = getDespairbossData()
    local data = bossDatas[id]
    
    local hfuben = instancesystem.createFuBen(DespairBossConfig[id].fbId)
    
    data.hpPercent = 100
    data.damageList = {}
    data.hfuben = hfuben
    data.needUpdate = false
    
    local ins = instancesystem.getInsByHdl(hfuben)
    if ins ~= nil then
        ins.data.pbossid = id
    end
    
    data.nextShield = getNextShield(id)
    data.curShield = nil
    data.shield = 0
    if data.shieldEid then
        LActor.cancelScriptEvent(nil, data.shieldEid)
        data.shieldEid = nil
    end
    
    s2cDespairBossData(id, data.bossId)
end

function changeCd(actor)
    local data = getStaticData(actor)
    data.challengeCd = System.getNowTime() + DespairBossCommonConfig.challengeCd
end

local function onBossDie(ins)
    local bossid = ins.data.pbossid
    local bossDatas = getDespairbossData()
    local bossData = bossDatas[bossid]
    --计算最终伤害排名，发奖励 --发金钱 --发精魄
    updateRank(bossid, true)
    local rank = bossData.rank
    local damageList = bossData.damageList
    local config = DespairBossConfig[bossid]
    if config == nil then return end
    --先注册定时器通知复活,防止因为报错导致不会刷新
    LActor.postScriptEventLite(nil, config.refreshTime * 1000, refreshBoss, bossid)
    if rank ~= nil and rank[1] ~= nil then
        local actRewards = {}
        local isopen, dropindexs = subactivity12.checkIsStart()
        if isopen then
            for i = 1, #dropindexs do
                local tmp = drop.dropGroup(config.actRewards[dropindexs[i]])
                for i = 1, #tmp do
                    table.insert(actRewards, tmp[i])
                end
            end
        end
        --第一名
        local firstAid = rank[1].aid
        local firstDmg = rank[1].dmg
        local exRate = damageList[firstAid].exRate
        local firstName = LActor.getActorName(firstAid)
        local firstLevel = LActor.getActorLevel(firstAid)
        local firstReward = {}
        if firstAid > #DespairRobotConfig then
            --如果有引导组掉落，则走引导组，如果没则走正常
            for i = 1, exRate do
                local dropid = config.firstdropid
                if rank[1].usedrop and DespairDropConfig[rank[1].usedrop].firstdropids[rank[1].useindex[i]] then
                    dropid = DespairDropConfig[rank[1].usedrop].firstdropids[rank[1].useindex[i]]
                end
                local reward = drop.dropGroup(dropid)
                addReward(firstReward, reward)
            end
            addReward(firstReward, actRewards, exRate)
            s2cGiveReward(config.fbId, config, firstAid, firstName, firstLevel, 1, firstReward, firstReward, firstDmg)
        else
            firstName = DespairRobotConfig[firstAid].name
        end
        bossData.beforeFirstName = firstName
        setNoticeKillboss(firstAid, config) --第一名发公告
        local firstActor = LActor.getActorById(firstAid)
        if firstActor then
            actorevent.onEvent(firstActor, aeFirstBeatDespairBoss)
        end
        --其他
        for i = 2, #rank do
            local aid = rank[i].aid
            local dmg = rank[i].dmg
            local exRate = damageList[aid].exRate
            local otherreward = {}
            if aid > #DespairRobotConfig then
            	for j = 1, exRate do
	                local dropid = config.otherdropid
	                if rank[i].usedrop and DespairDropConfig[rank[i].usedrop].otherdropids and DespairDropConfig[rank[i].usedrop].otherdropids[rank[i].useindex[j]] then
	                    dropid = DespairDropConfig[rank[i].usedrop].otherdropids[rank[i].useindex[j]]
	                end
	                local reward = drop.dropGroup(dropid)
	                addReward(otherreward, reward)
	            end
                addReward(otherreward, actRewards, exRate)
                s2cGiveReward(config.fbId, config, aid, firstName, firstLevel, i, firstReward, otherreward, dmg)
            end
        end
        
        for i = 1, #rank do
            local aid = rank[i].aid
            local actor = LActor.getActorById(aid)
            if actor then
            	local exRate = damageList[aid].exRate or 1
                actorevent.onEvent(actor, aeDespairBoss, bossid, exRate)
            end
        end
        subactivity21.updateFirstName(firstName, firstActor, bossid)
        --utils.logCounter(actor, "othersystem", #rank, "", "despairboss", "join")
    end
    
    --boss信息重置
    bossData.hpPercent = 0
    bossData.clonecount = 0
    bossData.damage = {}
    --处理record
    if rank ~= nil and rank[1] ~= nil then
        if #bossData.record >= 5 then
            table.remove(bossData.record, 1)
        end
        table.insert(bossData.record, {time = System.getNowTime(), name = LActor.getActorName(rank[1].aid), power = LActor.getActorPower(rank[1].aid)})
    end
    
    --计算下次复活时间
    bossData.reliveTime = config.refreshTime + System.getNowTime()
    bossData.hfuben = 0
    bossData.rank = nil
    bossData.needUpdate = false
    
    --更新给客户端boss信息？
    s2cDespairBossData(bossid, bossData.bossId)
end

local function onEnterFb(ins, actor)
    local index = ins.data.pbossid
    local bossDatas = getDespairbossData()
    local bossData = bossDatas[index]
    local damageList = bossData.damageList
    local actorId = LActor.getActorId(actor)
    
    --护盾信息
    if bossData.curShield then
        nowShield = bossData.shield
        if (bossData.curShield.type or 0) == 1 then
            nowShield = nowShield - System.getNowTime()
            if nowShield < 0 then nowShield = 0 end
        end
        instancesystem.s2cShieldInfo(ins.handle, bossData.curShield.type, nowShield, bossData.curShield.shield)
    end
    
    local exRate = neigua.getNeiguaFightCount(actor, ins.config.group)
    if not damageList[actorId] then
        damageList[actorId] = {
            damage = 0,
            exRate = exRate,
        }
    else
        damageList[actorId].exRate = math.max(exRate, damageList[actorId].exRate)
    end
    updateRank(index)
    if not damageList[actorId].usedrop then
        local config = DespairBossConfig[index]
        if config.beforedropid ~= 0 then
            damageList[actorId].usedrop = config.beforedropid
            damageList[actorId].useindex = {}
            local data = getStaticData(actor)
            for _ = 1, exRate do
                data["totalcount"..config.beforedropid] = (data["totalcount"..config.beforedropid] or 0) + 1
                if not DespairDropConfig[config.beforedropid] then break end
                table.insert(damageList[actorId].useindex, data["totalcount"..config.beforedropid])
            end
        end
    end
    LActor.setCamp(actor, CampType_Normal)--设置阵营为普通模式,和机器人同阵营
end

--玩家在护盾期间的输出
local function onShieldOutput(ins, monster, value, attacker)
    local bossId = ins.data.pbossid
    local bossDatas = getDespairbossData()
    local bossData = bossDatas[bossId]
    --更新伤害信息
    local actorId = LActor.getEntityActorId(attacker)
    if actorId == -1 then return end
    bossData.damageList[actorId] = bossData.damageList[actorId] or {}
    bossData.damageList[actorId].damage = (bossData.damageList[actorId].damage or 0) + value
end

local function onBossDamage(ins, monster, value, attacker, res)
    local bossId = ins.data.pbossid
    local bossDatas = getDespairbossData()
    local bossData = bossDatas[bossId]
    local monid = Fuben.getMonsterId(monster)
    if monid ~= DespairBossConfig[bossId].bossId then
        return
    end
    --更新boss血量信息
    local oldhp = LActor.getHp(monster)
    if oldhp <= 0 then return end
    
    local hp = oldhp - value
    if hp < 0 then hp = 0 end
    
    hp = hp / LActor.getHpMax(monster) * 100
    bossData.hpPercent = math.ceil(hp)
    bossData.needUpdate = true
    
    --更新伤害信息
    local actorId = LActor.getEntityActorId(attacker)
    if actorId == -1 then return end
    bossData.damageList[actorId] = bossData.damageList[actorId] or {}
    bossData.damageList[actorId].damage = (bossData.damageList[actorId].damage or 0) + value
    
    bossData.monster = monster --记录BOSS实体
    
    --护盾判断
    if 0 == bossData.shield then --现在没有护盾
        if bossData.nextShield and 0 ~= bossData.nextShield.hp and hp < bossData.nextShield.hp then --从预备护盾里取护盾
            bossData.curShield = bossData.nextShield
            bossData.nextShield = getNextShield(ins.data.pbossid, bossData.curShield.hp) --再取下一个预备护盾
            
            res.ret = math.floor(LActor.getHpMax(monster) * bossData.curShield.hp / 100) --避免一招秒而不触发护盾，这里要恢复血量
            bossData.hpPercent = bossData.curShield.hp --要把血量设置回原值
            LActor.setInvincible(monster, bossData.curShield.shield * 1000) --设无敌状态
            bossData.shield = bossData.curShield.shield + System.getNowTime()
            instancesystem.s2cShieldInfo(bossData.hfuben, 1, bossData.curShield.shield, bossData.curShield.shield)
            --注册护盾结束定时器
            bossData.shieldEid = LActor.postScriptEventLite(nil, bossData.curShield.shield * 1000, finishShield, bossData)
            noticesystem.fubenCastNotice(bossData.hfuben, noticesystem.NTP.homeShield)
        end
    end
end

--护盾结束
function finishShield(_, bossData)
    bossData.shield = 0
    --LActor.setInvincible(bossData.monster, false)
    instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, bossData.curShield.shield)
end

function checkActors(ins)
    local actors = Fuben.getAllActor(ins.handle)
    if #actors == 1 then
        local bossId = ins.data.pbossid
        local bossDatas = getDespairbossData()
        local bossData = bossDatas[bossId]
        if bossData.clonecount <= 0 then return end
        
        Fuben.clearAllClone(ins.scene_list[1])
        bossData.clonecount = 0
    end
end

local function onExitFb(ins, actor)
    changeCd(actor)
    checkActors(ins)
    s2cDespairbossInfo(actor)
    s2cDespairBossList(actor)
end

local function onOffline(ins, actor)
    checkActors(ins)
end

local function onActorDie(ins, actor, killHdl)
    ins:notifyRewards(actor, true)
    instancesystem.DelayExit(actor)
end

-------------------------------------------------------------------------------------------------------
--全民BOSS个人信息
function c2sDespairbossInfo(actor, pack)
    s2cDespairbossInfo(actor)
end

function s2cDespairbossInfo(actor)
    updatePersonInfo(actor)
    local data = getStaticData(actor)
    
    local cd = DespairBossCommonConfig.recoverTime * 60
    local now = System.getNowTime()
    local leftTime = 0 --恢复时间剩余时间
    if data.last_time > 0 then
        leftTime = cd - (now - data.last_time)
        if leftTime < 0 then leftTime = 0 end
    end
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DespairbossInfo)
    if npack == nil then return end
    LDataPack.writeShort(npack, data.count)
    LDataPack.writeShort(npack, leftTime)
    local challengeCd = data.challengeCd or 0
    challengeCd = challengeCd - now
    if challengeCd < 0 then challengeCd = 0 end
    LDataPack.writeShort(npack, challengeCd)
    --LDataPack.writeInt(npack, data.clientdata or 0xffff)
    LDataPack.flush(npack)
end

--全民BOSS列表
function c2sDespairbossList(actor, pack)
    s2cDespairBossList(actor)
end

--全民BOSS列表
function s2cDespairBossList(actor)
    local bossDatas = getDespairbossData()
    local var = getStaticData(actor)
    local now = System.getNowTime()
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DespairbossList)
    if npack == nil then return end
    LDataPack.writeShort(npack, #DespairBossConfig)
    for id, boss in pairs(bossDatas) do
        local ins = instancesystem.getInsByHdl(boss.hfuben)
        local count = ins and ins.actor_list_count or 0 --挑战者数量
        local isRemind = var.reminds and var.reminds[id] or 0 --是否提醒
        local found = var.bossId == id and 1 or 0--正在是否挑战这boss
        local flag = (id == 1 and isDespairTask(actor)) --是否为引导副本
        
        LDataPack.writeInt(npack, id)
        LDataPack.writeString(npack, MonstersConfig[boss.bossId].name)
        LDataPack.writeString(npack, MonstersConfig[boss.bossId].head)
        LDataPack.writeShort(npack, flag and 100 or boss.hpPercent)
        LDataPack.writeShort(npack, flag and 0 or count)
        LDataPack.writeInt(npack, flag and 0 or boss.reliveTime - now)
        LDataPack.writeByte(npack, found)
        LDataPack.writeByte(npack, isRemind)
        LDataPack.writeString(npack, boss.beforeFirstName or "")
    end
    LDataPack.flush(npack)
end

--全民BOSS单个信息更新
function s2cDespairBossData(id, bossId)
    local bossDatas = getDespairbossData()
    local npack = LDataPack.allocPacket()
    if npack == nil then return end
    LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
    LDataPack.writeByte(npack, Protocol.sFubenCmd_UpdateBoss)
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, bossDatas[id].hpPercent)
    LDataPack.writeShort(npack, 0)
    LDataPack.writeInt(npack, bossDatas[id].reliveTime - System.getNowTime())
    LDataPack.writeByte(npack, 0)
    LDataPack.writeString(npack, MonstersConfig[bossId].name)
    LDataPack.writeString(npack, bossDatas[id].beforeFirstName or "")
    System.broadcastData(npack) --向所有人广播信息
end

--战胜BOSS奖励
function s2cGiveReward(fbId, config, aid, firstname, firstLevel, rank, firstReward, reward, damage)
    local actor = LActor.getActorById(aid)
    local job = 1
    if actor and LActor.getFubenId(actor) == fbId then --玩家在线且在当前全民副本
        job = LActor.getJob(actor)
        reward = actoritem.getItemsByJobId(job, reward)
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DespairbossFight)
        if npack == nil then return end
        LDataPack.writeShort(npack, rank)
        LDataPack.writeString(npack, firstname)
        LDataPack.writeShort(npack, firstLevel)
        LDataPack.writeShort(npack, #firstReward)
        for _, v in ipairs(firstReward) do
            LDataPack.writeInt(npack, v.type or 0)
            LDataPack.writeInt(npack, v.id or 0)
            LDataPack.writeInt(npack, v.count or 0)
        end
        LDataPack.writeShort(npack, #reward)
        for _, v in ipairs(reward) do
            LDataPack.writeInt(npack, v.type or 0)
            LDataPack.writeInt(npack, v.id or 0)
            LDataPack.writeInt(npack, v.count or 0)
        end
        LDataPack.writeDouble(npack, damage)
        LDataPack.flush(npack)
    end
    
    --发奖励
    if actor and actoritem.checkEquipBagSpaceJob(actor, reward) then --在线或背包够
        actoritem.addItems(actor, reward, "despairboss reward")
    else
        local actorData = offlinedatamgr.GetDataByOffLineDataType(aid, offlinedatamgr.EOffLineDataType.EBasic)
        if not actorData then return end
        local job = actorData.job
        local rewards = actoritem.getItemsByJobId(job, reward)
        local content = string.format(config.mailContent, rank)
        local mailData = {head = config.mailTitle, context = content, tAwardList = reward}
        mailsystem.sendMailById(aid, mailData)
    end
    
    for k, v in ipairs(reward) do
        if ItemConfig[v.id] and ItemConfig[v.id].type == 0 and ItemConfig[v.id].quality >= 5 then
            local bossName = MonstersConfig[config.bossId].name
            local name = ""
            if DespairRobotConfig[aid] then
                name = DespairRobotConfig[aid].name
            else
                name = LActor.getActorName(aid)
            end
            noticesystem.broadCastNotice(noticesystem.NTP.despairkill, actorcommon.getVipShow(actor), name, bossName, actoritem.getColor(v.id), ItemConfig[v.id].name[job])
        end
    end
end

--全民BOSS提醒设置
function c2sDespairbossSetup(actor, pack)
    local id = LDataPack.readShort(pack)
    local isRemind = LDataPack.readByte(pack)
    local data = getStaticData(actor)
    if not data.reminds then
        data.reminds = {}
    end
    data.reminds[id] = isRemind
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DespairbossSetup)
    LDataPack.writeShort(npack, id)
    LDataPack.writeChar(npack, isRemind)
    LDataPack.flush(npack)
end

--全民BOSS记录
function c2sDespairbossRecord(actor, pack)
    local id = LDataPack.readInt(pack)
    local bossDatas = getDespairbossData()
    local bossData = bossDatas[id]
    if bossData == nil then return end
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_DespairbossRecord)
    if npack == nil then return end
    
    if bossData.record == nil then bossData.record = {} end
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, #bossData.record)
    for _, record in ipairs(bossData.record) do
        LDataPack.writeInt(npack, record.time)
        LDataPack.writeString(npack, record.name)
        LDataPack.writeDouble(npack, record.power)
    end
    LDataPack.flush(npack)
end

--全民BOSS挑战
function c2sDespairbossFight(actor, pack)
    local bid = LDataPack.readInt(pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.boss) then return end
    if not staticfuben.canEnterFuben(actor) then return end
    
    local conf = DespairBossConfig[bid]
    local aid = LActor.getActorId(actor)
    local var = getStaticData(actor)
    
    if conf == nil then print("despair on reqChallengeBoss config is nil:"..bid.. " aid:"..LActor.getActorId(actor)) return end
    -- if LActor.getLevel(actor) < conf.level then
    -- print("despair boss req failed.. level. aid:"..LActor.getActorId(actor))
    -- return
    -- end
    if not zhuansheng.checkZSLevel(actor, conf.zsLevel) then
        print("despair boss req failed.. zslevel. aid:"..LActor.getActorId(actor))
        return
    end
    
    local bossDatas = getDespairbossData()
    local pdata = bossDatas[bid]
    local flag = bid == 1 and isDespairTask(actor) --是否挑战引导副本
    
    if not flag then
        if pdata.hpPercent == 0 or pdata.hfuben == 0 then
            LActor.sendTipmsg(actor, ScriptTips.mssys013, ttMessage)
            print("despair boss req failed.. is over. aid:"..LActor.getActorId(actor))
            return
        end
    end
    
    if var.bossId == bid and System.getNowTime() < (var.challengeCd or 0) then --检查cd
        return
    end
    
    local fightTimes = 1
    if not flag then
        fightTimes = neigua.checkOpenNeigua(actor, FubenConfig[conf.fbId].group, var.count)
        if fightTimes <= 0 then
            print("despair boss req failed.. count. aid:" .. LActor.getActorId(actor))
            return
        end
    end
    if var.count == DespairBossCommonConfig.maxCount then
        var.last_time = System.getNowTime()
    end
    
    if not utils.checkFuben(actor, conf.fbId) then return end
    
    --处理进入
    if flag then --第一次挑战第一关副本时，进入引导副本
        despairguide.fightDespairGuide(actor)
        actorevent.onEvent(actor, aeEnterDespire, 1, pdata.bossId)
    else
        var.bossId = bid
        var.count = var.count - fightTimes
        var.times = var.times + fightTimes
        actorevent.onEvent(actor, aeEnterDespire, fightTimes, pdata.bossId)
        local x, y = utils.getSceneEnterCoor(conf.fbId)
        local ret = LActor.enterFuBen(actor, pdata.hfuben, 0, x, y)
        if not ret then
            print("Error despair boss enterFuben failed.. aid:"..aid)
        end
    end
    
    if var.count == 0 then
        s2cDespairbossInfo(actor)
    end
    
    utils.logCounter(actor, "despairboss", 1, var.count)
end

--全民BOSS排行
function c2sDespairbossRank(actor, pack)
    local id = LDataPack.readInt(pack)
    local bossDatas = getDespairbossData()
    if bossDatas[id] == nil then return end
    s2cDespairbossRank(id, actor)
end

--发送全民BOSS排行榜
function s2cDespairbossRank(id, actor)
    local bossDatas = getDespairbossData()
    if not bossDatas then return end
    
    local rank = bossDatas[id].rank
    if rank == nil then return end
    
    local npack = false
    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.cFubenCmd_DespairbossRank)
    else --发送给所有人
        npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
        LDataPack.writeByte(npack, Protocol.cFubenCmd_DespairbossRank)
    end
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, #rank)
    for _, d in ipairs(rank) do
        LDataPack.writeInt(npack, d.aid)
        if DespairRobotConfig[d.aid] then
            LDataPack.writeString(npack, DespairRobotConfig[d.aid].name)
        else
            LDataPack.writeString(npack, LActor.getActorName(d.aid))
        end
        LDataPack.writeDouble(npack, d.dmg)
    end
    
    if actor then
        LDataPack.flush(npack)
    else
        Fuben.sendData(bossDatas[id].hfuben, npack)
    end
end

function remindNewBoss(actor, bossId)
    local data = getStaticData(actor)
    data.reminds = {}
    data.reminds[bossId] = 1
    s2cDespairBossList(actor)
end

function onLevelUp(actor, level, oldLevel)
    local zsLevel = zhuansheng.getZSLevel(actor)
    if ZhuanShengLevelConfig[zsLevel].cslevel > 0 then return end --已经转生就不关注未转生的BOSS了
    for bossId, conf in pairs(DespairBossConfig) do
        if level >= conf.level and oldLevel < conf.level and conf.zsLevel > 10000 then
            remindNewBoss(actor, bossId)
        end
    end
end

local function onZhuansheng(actor, level, oldLevel)
    for bossId, conf in ipairs(DespairBossConfig) do
        if conf.zsLevel <= level and conf.zsLevel > oldLevel and conf.zsLevel > 10000 then
            remindNewBoss(actor, bossId)
        end
    end
end

function regTimer()
    LActor.postScriptEventEx(nil, 5, function() onTimer() end, 5000, -1)
    LActor.postScriptEventEx(nil, 1000, function() onTimerRobot() end, 5000, -1)
end

local function initGlobalData()
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    if System.isCrossWarSrv() then return end
    actorevent.reg(aeZhuansheng, onZhuansheng)
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeMainTaskAccept, onMainTaskAccept)
    actorevent.reg(aeLevel, onLevelUp)
    --注册事件
    for _, conf in pairs(DespairBossConfig) do
        insevent.registerInstanceWin(conf.fbId, onBossDie)
        insevent.registerInstanceEnter(conf.fbId, onEnterFb)
        insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
        insevent.registerInstanceExit(conf.fbId, onExitFb)
        insevent.registerInstanceOffline(conf.fbId, onOffline)
        insevent.registerInstanceActorDie(conf.fbId, onActorDie)
        insevent.registerInstanceShieldOutput(conf.fbId, onShieldOutput)
    end
    
    --定时事件
    engineevent.regGameStartEvent(regTimer)
    
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_DespairbossInfo, c2sDespairbossInfo)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_DespairbossList, c2sDespairbossList)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_DespairbossSetup, c2sDespairbossSetup)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_DespairbossRecord, c2sDespairbossRecord)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_DespairbossFight, c2sDespairbossFight)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_DespairbossRank, c2sDespairbossRank)
    
    if next(g_despairbossData) then return end
    for id, boss in pairs(DespairBossConfig) do
        if not g_despairbossData[id] then
            local hfuben = instancesystem.createFuBen(boss.fbId)
            g_despairbossData[id] = {
                hpPercent = 100,
                damageList = {},
                record = {}, --记录击杀boss的玩家
                reliveTime = System.getNowTime(), --下一次复活时间
                shield = 0,
                curShield = nil,
                nextShield = getNextShield(id),
                hfuben = hfuben,
                needUpdate = false,
                bossId = boss.bossId,
                clonecount = 0--镜像玩家数量
            }
            local ins = instancesystem.getInsByHdl(hfuben)
            if ins then
                ins.data.pbossid = id
            end
        end
    end
end
table.insert(InitFnTable, initGlobalData)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.despairbossReset = function (actor)
    local data = getStaticData(actor)
    data.count = 10
    c2sDespairbossInfo(actor)
    return true
end

gmCmdHandlers.bossRefresh = function (actor, args)
    local id = tonumber(args[1])
    local bossDatas = getDespairbossData()
    bossDatas[id].reliveTime = System.getNowTime()
    refreshBoss(nil, id)
    return true
end

gmCmdHandlers.despairbossClear = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.despairfuben = nil
    return true
end

gmCmdHandlers.despairbossFight = function (actor, args)
    local index = tonumber(args[1])
    if not index then return end
    local bossDatas = getDespairbossData()
    if bossDatas[index].reliveTime > System.getNowTime() then
        bossDatas[index].reliveTime = System.getNowTime()
        refreshBoss(nil, index)
    end
    local data = getStaticData(actor)
    data.count = 10
    data.challengeCd = 0
    local pack = LDataPack.allocPacket()
    LDataPack.writeInt(pack, index)
    LDataPack.setPosition(pack, 0)
    c2sDespairbossFight(actor, pack)
    local hfuben = LActor.getFubenHandle(actor)
    local ins = instancesystem.getInsByHdl(hfuben)
    if FubenConfig[ins.id].group == 10008 then
        Fuben.killAllMonster(ins.scene_list[1])
    end
    return true
end

