-- @version1.0
-- @authorqianmeng
-- @date2017-11-10 10:57:07.
-- @system卡利玛神庙

module("kalima", package.seeall)
require("scene.kalimacommon")
require("scene.kalimafuben")
require("scene.kalimadamagereward")

local function getGlobalData()
    local var = System.getStaticVar()
    if not var then return end
    if not var.kalimaSet then
        var.kalimaSet = {}
    end
    return var.kalimaSet;
end

--返回卡利玛副本
g_kalimaData = g_kalimaData or {}
local function getKalimaData()
    return g_kalimaData
end

local function getBossData(id)
    return g_kalimaData[id]
end

local function getStaticData(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.kalimafuben then
        var.kalimafuben = {}
        var.kalimafuben.reminds = {}
    end
    local kalimafuben = var.kalimafuben
    if not kalimafuben.challengeCd then kalimafuben.challengeCd = 0 end
    if not kalimafuben.curKalimaId then kalimafuben.curKalimaId = 0 end --上一个挑战的Boss
    if not kalimafuben.rebornCd then kalimafuben.rebornCd = 0 end
    if not kalimafuben.rewardsRecords then kalimafuben.rewardsRecords = {} end
    return kalimafuben
end

local function updateKalimaRank(id, force)
    local bossDatas = getKalimaData()
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
        table.insert(rank, {aid = actorId, dmg = v.damage})
    end
    table.sort(rank, function(a, b) return a.dmg > b.dmg end)
    bossData.rank = rank
end

--更新个人伤害53-148
local function updateKalimaDamage(actor, id)
    local bossData = getBossData(id)
    if not bossData then return end
    local actorId = LActor.getActorId(actor)
    local damage = bossData.damageList[actorId].damage
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_KalimaDamage)
    if pack == nil then return end
    LDataPack.writeChar(pack, id)
    LDataPack.writeDouble(pack, damage)
    LDataPack.flush(pack)
end

--求下一个护盾
local function getNextShield(id, hp)
    if nil == hp then hp = 101 end
    
    local conf = KalimaFubenConfig[id]
    if nil == conf then return nil end
    for i, s in ipairs(conf.shield) do
        if s.hp < hp then return s end
    end
    return nil
end

local function getMonsterName(bossId)
    if MonstersConfig[bossId] then
        return tostring(MonstersConfig[bossId].name)
    end
    return "nil"
end

--发送击杀boss的公告
local function setNoticeKillboss(actorId, config)
    noticesystem.broadCastNotice(noticesystem.NTP.kalimaKill, LActor.getActorName(actorId), getMonsterName(config.bossId))
end

--重置副本，如果boss死了就创建新副本，如果没死就满血
local function refreshBoss(_, id)
    local bossData = getBossData(id)
    local hfuben = instancesystem.createFuBen(KalimaFubenConfig[id].fbId)
    bossData.hpPercent = 100
    bossData.damageList = {}
    bossData.rank = nil
    bossData.hfuben = hfuben
    
    local ins = instancesystem.getInsByHdl(hfuben)
    if ins ~= nil then
        ins.data.pkalimaid = id
    end
    
    bossData.nextShield = getNextShield(id)
    bossData.curShield = nil
    bossData.shield = 0
    if bossData.shieldEid then
        LActor.cancelScriptEvent(nil, bossData.shieldEid)
        bossData.shieldEid = nil
    end
    updateKalimaFbInfo(id)
end

--护盾结束
function finishShield(_, bossData)
    bossData.shield = 0
    instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, bossData.curShield.shield)
end

-------------------------------------------------------------------------------------------------------
--卡利玛神庙个人信息
function c2sKalimaInfo(actor, pactet)
    s2cKalimaInfo(actor)
end

--卡利玛神庙个人信息53-141
function s2cKalimaInfo(actor)
    local var = getStaticData(actor)
    local now = System.getNowTime()
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_KalimaInfo)
    if npack == nil then return end
    LDataPack.writeShort(npack, math.max(var.challengeCd - now, 0))
    LDataPack.flush(npack)
end

--卡利玛神庙列表查看
function c2sKalimaList(actor, pactet)
    s2cKalimaList(actor)
end

--卡利玛神庙列表53-142
function s2cKalimaList(actor)
    local bossDatas = getKalimaData()
    if not next(bossDatas) then return end
    local var = getStaticData(actor)
    local now = System.getNowTime()
    local data = getGlobalData()
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_KalimaList)
    if npack == nil then return end
    LDataPack.writeShort(npack, #KalimaFubenConfig)
    for id, boss in pairs(bossDatas) do
        local ins = instancesystem.getInsByHdl(boss.hfuben)
        local count = ins and ins.actor_list_count or 0 --挑战者数量
        local isRemind = var.reminds and var.reminds[id] or 1 --是否提醒
        local found = false--正在是否挑战这boss
        -- if (var.curKalimaId == id) and boss.damageList[LActor.getActorId(actor)] then
        --     found = true
        -- end
        local name = data[id] and data[id].name or "" --上次属者名
        
        local mconf = MonstersConfig[boss.bossId]
        LDataPack.writeInt(npack, id)
        LDataPack.writeString(npack, mconf.name)
        LDataPack.writeString(npack, mconf.head)
        LDataPack.writeShort(npack, mconf.avatar[1])
        LDataPack.writeShort(npack, boss.hpPercent)
        LDataPack.writeShort(npack, count)
        LDataPack.writeInt(npack, boss.reliveTime - now)
        LDataPack.writeByte(npack, found and 1 or 0)
        LDataPack.writeByte(npack, isRemind)
        LDataPack.writeString(npack, name)
    end
    LDataPack.writeInt(npack, quainton.getAnger())
    LDataPack.writeInt(npack, quainton.getMaxAnger())
    LDataPack.flush(npack)
end

--进入副本时下发boss达标奖励53-144
function s2cKalimaFbInfo(actor)
    local var = getStaticData(actor)
    if not var then return end
    local id = var.curKalimaId
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_KalimaFbInfo)
    LDataPack.writeChar(pack, id)
    LDataPack.writeInt(pack, var.rewardsRecords[id])
    LDataPack.flush(pack)
end

--卡利玛神庙提醒设置
function c2sKalimaSetup(actor, pack)
    local id = LDataPack.readShort(pack)
    local isRemind = LDataPack.readByte(pack)
    local data = getStaticData(actor)
    if not data.reminds then
        data.reminds = {}
    end
    data.reminds[id] = isRemind
end

--卡利玛神庙挑战
function c2sKalimaFight(actor, pack)
    local kalimaId = LDataPack.readInt(pack)
    if not actorlogin.checkCanEnterCross(actor) then return end
    local conf = KalimaFubenConfig[kalimaId]
    if not conf then return end
    if LActor.getZhuansheng(actor) < conf.zslevel then return end
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.kalima) then return end
    
    local bossData = getBossData(kalimaId)
    if not bossData then
        LActor.sendTipmsg(actor, ScriptTips.mssys016, ttMessage)
        return
    end
    if bossData.hpPercent == 0 or bossData.hfuben == 0 then
        LActor.sendTipmsg(actor, ScriptTips.mssys013, ttMessage)
        return
    end
    
    local var = getStaticData(actor)
    if var.curKalimaId == kalimaId then
        if System.getNowTime() < (var.challengeCd or 0) then --检查cd
            return
        end
    end
    --if not utils.checkFuben(actor, conf.fbId) then return end
    local fightTimes = neigua.checkOpenNeigua(actor, FubenConfig[conf.fbId].group)
    
    if fightTimes > 1 then
        local item = {}
        for _, v in ipairs(conf.item) do
            table.insert(item, {type = v.type, id = v.id, count = v.count * fightTimes})
        end
        if not actoritem.checkItems(actor, item) then
            return
        end
        actoritem.reduceItems(actor, item, "fight kalima")
    else
        if not actoritem.checkItems(actor, conf.item) then
            return
        end
        actoritem.reduceItems(actor, conf.item, "fight kalima")
    end
    
    --处理进入
    var.curKalimaId = kalimaId
    local x, y = utils.getSceneEnterCoor(conf.fbId)
    if System.isCommSrv() then
        local crossId = csbase.getCrossServerId()
        LActor.loginOtherServer(actor, crossId, bossData.hfuben, 0, x, y, "cross")
    elseif System.isCrossWarSrv() then
        LActor.enterFuBen(actor, bossData.hfuben, 0, x, y)
    end
end

--卡利玛神庙奖励53-150
function s2cKalimaReward(actorId, config, rewards, fName, myrank)
    local actor = LActor.getActorById(actorId)
    if actor and LActor.getFubenId(actor) == config.fbId then --玩家在线且在副本里， 发送结束协议
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_KalimaReward)
        if npack == nil then return end
        LDataPack.writeString(npack, fName)
        LDataPack.writeInt(npack, myrank)
        LDataPack.writeShort(npack, #rewards)
        for _, v in ipairs(rewards) do
            LDataPack.writeInt(npack, v.type or 0)
            LDataPack.writeInt(npack, v.id or 0)
            LDataPack.writeInt(npack, v.count or 0)
        end
        LDataPack.flush(npack)
    end
    
    if actor and actoritem.checkEquipBagSpaceJob(actor, rewards) then
        actoritem.addItems(actor, rewards, "kalima rewards")
    else
        local text = config.mailContent
        local mailData = {head = config.mailTitle, context = text, tAwardList = rewards}
        mailsystem.sendMailById(actorId, mailData, 0)
    end
end

--卡利玛神庙单个信息更新53-145
function s2cKalimaUpdate(id)
    local bossData = getBossData(id)
    local npack = LDataPack.allocPacket()
    if npack == nil then return end
    LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
    LDataPack.writeByte(npack, Protocol.sFubenCmd_KalimaUpdate)
    
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, bossData.hpPercent)
    LDataPack.writeInt(npack, bossData.reliveTime - System.getNowTime())
    
    System.broadcastData(npack) --向所有人广播信息
end

function c2sKalimaGetReward(actor, packet)
    local id = LDataPack.readChar(packet)
    local index = LDataPack.readChar(packet)
    local conf = KalimaDamageRewardConfig[id] and KalimaDamageRewardConfig[id][index]
    if not conf then return end
    
    local bossData = getBossData(id)
    if not bossData then return end
    
    local actorId = LActor.getActorId(actor)
    if not bossData.damageList[actorId] then return end
    
    local myDamage = bossData.damageList[actorId].damage or 0
    if myDamage < conf.damage then return end
    
    local exRate = bossData.damageList[actorId].exRate or 1
    local var = getStaticData(actor)
    local reward = var.rewardsRecords[id]
    if System.bitOPMask(reward, index) then return end
    if not actoritem.checkEquipBagSpaceJob(actor, conf.rewards) then return end
    
    var.rewardsRecords[id] = System.bitOpSetMask(reward, index, true)
    for _ = 1, exRate do
        actoritem.addItems(actor, conf.rewards, "Kalima damage rewards")
    end
    s2cKalimaGetReward(actor)
end

--达标奖励领取53-147
function s2cKalimaGetReward(actor)
    local var = getStaticData(actor)
    if not var then return end
    local id = var.curKalimaId
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_KalimaGetReward)
    if not pack then return end
    LDataPack.writeChar(pack, id)
    LDataPack.writeInt(pack, var.rewardsRecords[id])
    LDataPack.flush(pack)
end

-------------------------------------------------------------------------------------------
function sendDamageRewardByEmail(actor, id)
    local config = KalimaDamageRewardConfig[id]
    if not config then return end
    local bossData = getBossData(id)
    if not bossData then return end
    local actorId = LActor.getActorId(actor)
    if not bossData.damageList[actorId] then return end
    local myDamage = bossData.damageList[actorId].damage or 0
    local exRate = bossData.damageList[actorId].exRate or 1
    local var = getStaticData(actor)
    local items = {}
    for index, conf in ipairs(config) do
        if myDamage >= conf.damage then
            if not System.bitOPMask(var.rewardsRecords[id], index) then
                var.rewardsRecords[id] = System.bitOpSetMask(var.rewardsRecords[id], index, true)
                for _, reward in ipairs(conf.rewards) do
                    table.insert(items, {type = reward.type, id = reward.id, count = reward.count * exRate})
                end
            end
        else
            break
        end
    end
    if next(items) then
        local mailData = {head = KalimaCommonConfig.damageMailTitle, context = KalimaCommonConfig.damageMailContent, tAwardList = items}
        mailsystem.sendMailById(actorId, mailData, 0)
    end
end

--登录事件
local function onLogin(actor)
    s2cKalimaInfo(actor)
    s2cKalimaList(actor)
end

local function onBossDie(ins)
    local kalimaId = ins.data.pkalimaid
    local bossData = getBossData(kalimaId)
    local config = KalimaFubenConfig[kalimaId]
    if not config then return end
    --提前注册复活定时器
    LActor.postScriptEventLite(nil, config.refreshTime * 1000, refreshBoss, kalimaId)
    updateKalimaRank(kalimaId, true)
    local rank = bossData.rank
    local firstId = 0
    local firstName = ""
    if rank ~= nil and rank[1] ~= nil then
        firstId = rank[1].aid
        firstName = LActor.getActorName(firstId)
        for i = 1, #rank do
            local actorId = rank[i].aid
            local exRate = bossData.damageList[rank[i].aid].exRate or 1
            local items = {}
            for _ = 1, exRate do
                local rewards
                if i == 1 then
                    rewards = drop.dropGroup(config.firstDrop)
                else
                    rewards = drop.dropGroup(config.otherDrop)
                end
                for _, v in ipairs(rewards) do
                    table.insert(items, v)
                end
            end
            s2cKalimaReward(actorId, config, items, firstName, i)
        end
    end
    
    local data = getGlobalData() --记录第一名
    data[kalimaId] = {name = firstName}
    
    --boss信息重置
    bossData.hpPercent = 0
    bossData.hfuben = 0
    --bossData.damageList = {}
    bossData.reliveTime = config.refreshTime + System.getNowTime()
    
    quainton.addAnger(config.anger, firstId, config.level, config.bossId)
    updateKalimaFbInfo(kalimaId)
end

local function onEnterFb(ins, actor)
    local id = ins.data.pkalimaid
    local bossData = getBossData(id)
    local damageList = bossData.damageList
    local actorId = LActor.getActorId(actor)
    
    local var = getStaticData(actor)
    local exRate = neigua.getNeiguaFightCount(actor, ins.config.group)
    if not damageList[actorId] then
        damageList[actorId] = {damage = 0, exRate = exRate}
        var.rewardsRecords[id] = 0
    else
        damageList[actorId].exRate = math.max(damageList[actorId].exRate, exRate)
    end
    
    if not var.eid then
        var.eid = LActor.postScriptEventEx(actor, 1, function() updateKalimaDamage(actor, id) end, 1000, -1)
    end
    
    --护盾信息
    if bossData.curShield then
        nowShield = bossData.shield
        if (bossData.curShield.type or 0) == 1 then
            nowShield = nowShield - System.getNowTime()
            if nowShield < 0 then nowShield = 0 end
        end
        instancesystem.s2cShieldInfo(ins.handle, bossData.curShield.type, nowShield, bossData.curShield.shield)
    end
    s2cKalimaFbInfo(actor)
end

--玩家在护盾期间的输出
local function onShieldOutput(ins, monster, value, attacker)
    local kalimaId = ins.data.pkalimaid
    
    local bossData = getBossData(kalimaId)
    local damageList = bossData.damageList
    --更新伤害信息
    local actorId = LActor.getEntityActorId(attacker)
    if actorId == -1 then return end
    bossData.damageList[actorId].damage = bossData.damageList[actorId].damage + value
end

local function onMonsterAiReset(ins, monster)
    local kalimaId = ins.data.pkalimaid
    local bossData = getBossData(kalimaId)
    if 0 ~= bossData.shield then
        finishShield(nil, bossData)
    end
    if bossData.shieldEid then
        LActor.cancelScriptEvent(nil, bossData.shieldEid)
        bossData.shieldEid = nil
    end
    bossData.nextShield = getNextShield(kalimaId)
    
    bossData.hpPercent = 100
    updateKalimaBlood(kalimaId)
end

local function onBossDamage(ins, monster, value, attacker, res)
    local kalimaId = ins.data.pkalimaid
    local monid = Fuben.getMonsterId(monster)
    if monid ~= KalimaFubenConfig[kalimaId].bossId then
        return
    end
    local bossData = getBossData(kalimaId)
    
    --更新boss血量信息
    local oldhp = LActor.getHp(monster)
    if oldhp <= 0 then return end
    
    local hp = oldhp - value
    if hp < 0 then hp = 0 end
    
    hp = hp / LActor.getHpMax(monster) * 100
    local isUdate = bossData.hpPercent ~= hp
    bossData.hpPercent = math.ceil(hp)
    
    --护盾判断
    if 0 == bossData.shield then --现在没有护盾
        if bossData.nextShield and 0 ~= bossData.nextShield.hp and hp < bossData.nextShield.hp then --从预备护盾里取护盾
            bossData.curShield = bossData.nextShield
            bossData.nextShield = getNextShield(ins.data.pkalimaid, bossData.curShield.hp) --再取下一个预备护盾
            
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
    
    local actorId = LActor.getEntityActorId(attacker)
    if actorId == -1 then return end
    local damageList = bossData.damageList
    if not damageList[actorId] then
        print("kalima.onBossDamage not find damageList[actorId] actorId =", actorId)
    end
    damageList[actorId].damage = damageList[actorId].damage + value
    
    if isUdate then
        updateKalimaBlood(kalimaId)
    end
end

local function onExitFb(ins, actor)
    local var = getStaticData(actor)
    if not var then return end
    if var.eid then
        LActor.cancelScriptEvent(actor, var.eid)
        var.eid = nil
    end
    
    if not ins.is_win then --胜利的副本不加CD
        var.challengeCd = System.getNowTime() + KalimaCommonConfig.cdTime
    end
    
    sendDamageRewardByEmail(actor, ins.data.pkalimaid)
end

local function onOffline(ins, actor)
    LActor.exitFuben(actor)
end

--跨服协议
---------------------------------------------------------------------------------
function sendKalimaFbInfo(serverId)
    if not System.isBattleSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCKalimaCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCKalimaCmd_SyncAllFbInfo)
    
    LDataPack.writeByte(pack, #KalimaFubenConfig)
    for id, conf in ipairs(KalimaFubenConfig) do
        LDataPack.writeByte(pack, id)
        local bossData = getBossData(id)
        LDataPack.writeByte(pack, bossData.hpPercent)
        LDataPack.writeInt64(pack, bossData.hfuben)
        LDataPack.writeInt(pack, bossData.bossId)
        LDataPack.writeInt(pack, bossData.reliveTime)
    end
    System.sendPacketToAllGameClient(pack, serverId or 0)
end

function onSendKalimaFbInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local bossDatas = getKalimaData()
    local number = LDataPack.readByte(dp)
    for i = 1, number do
        local id = LDataPack.readByte(dp)
        bossDatas[id] = {}
        bossDatas[id].hpPercent = LDataPack.readByte(dp)
        bossDatas[id].hfuben = LDataPack.readInt64(dp)
        bossDatas[id].bossId = LDataPack.readInt(dp)
        bossDatas[id].reliveTime = LDataPack.readInt(dp)
    end
end

function updateKalimaFbInfo(id)
    if not System.isBattleSrv() then return end
    local bossData = getBossData(id)
    if not bossData then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCKalimaCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCKalimaCmd_SyncUpdateFbInfo)
    
    LDataPack.writeByte(pack, id)
    LDataPack.writeByte(pack, bossData.hpPercent)
    LDataPack.writeInt64(pack, bossData.hfuben)
    LDataPack.writeInt(pack, bossData.bossId)
    LDataPack.writeInt(pack, bossData.reliveTime)
    
    local data = getGlobalData() --记录第一名
    LDataPack.writeString(pack, data[id].name)
    
    System.sendPacketToAllGameClient(pack, 0)
end

function onUpdateKalimaFbInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local bossDatas = getKalimaData()
    local id = LDataPack.readByte(dp)
    bossDatas[id] = {}
    bossDatas[id].hpPercent = LDataPack.readByte(dp)
    bossDatas[id].hfuben = LDataPack.readInt64(dp)
    bossDatas[id].bossId = LDataPack.readInt(dp)
    bossDatas[id].reliveTime = LDataPack.readInt(dp)
    
    local data = getGlobalData() --记录第一名
    data[id] = {name = LDataPack.readString(dp)}
    s2cKalimaUpdate(id)
end

function updateKalimaBlood(id)
    if not System.isBattleSrv() then return end
    local bossData = getBossData(id)
    if not bossData then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCKalimaCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCKalimaCmd_SyncUpdateBlood)
    
    LDataPack.writeByte(pack, id)
    LDataPack.writeByte(pack, bossData.hpPercent)
    
    System.sendPacketToAllGameClient(pack, 0)
end

function onUpdateKalimaBlood(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local bossDatas = getKalimaData()
    local id = LDataPack.readByte(dp)
    local hpPercent = LDataPack.readByte(dp)
    if bossDatas[id] and bossDatas[id].hpPercent then
        bossDatas[id].hpPercent = hpPercent
    end
end

function OnKalimaConnected(serverId, serverType)
    if not System.isBattleSrv() then return end
    sendKalimaFbInfo(serverId)
end

local function initGlobalData()
    if System.isLianFuSrv() then return end
    
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_KalimaFight, c2sKalimaFight)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_KalimaInfo, c2sKalimaInfo)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_KalimaList, c2sKalimaList)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_KalimaSetup, c2sKalimaSetup)
    
    csbase.RegConnected(OnKalimaConnected)
    
    csmsgdispatcher.Reg(CrossSrvCmd.SCKalimaCmd, CrossSrvSubCmd.SCKalimaCmd_SyncAllFbInfo, onSendKalimaFbInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCKalimaCmd, CrossSrvSubCmd.SCKalimaCmd_SyncUpdateFbInfo, onUpdateKalimaFbInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCKalimaCmd, CrossSrvSubCmd.SCKalimaCmd_SyncUpdateBlood, onUpdateKalimaBlood)
    
    actorevent.reg(aeUserLogin, onLogin)
    
    if not System.isBattleSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_KalimaGetReward, c2sKalimaGetReward)
    --netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_KalimaRank, c2sKalimaRank)
    
    for _, conf in pairs(KalimaFubenConfig) do
        insevent.registerInstanceWin(conf.fbId, onBossDie)
        insevent.registerInstanceEnter(conf.fbId, onEnterFb)
        insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
        insevent.registerInstanceMonsterAiReset(conf.fbId, onMonsterAiReset)
        insevent.registerInstanceShieldOutput(conf.fbId, onShieldOutput)
        insevent.registerInstanceExit(conf.fbId, onExitFb)
        insevent.registerInstanceOffline(conf.fbId, onOffline)
    end
    
    if next(g_kalimaData) then return end
    for id, conf in pairs(KalimaFubenConfig) do
        if not g_kalimaData[id] then
            local hfuben = instancesystem.createFuBen(conf.fbId)
            g_kalimaData[id] = {
                id = conf.id,
                hpPercent = 100,
                hfuben = hfuben,
                shield = 0,
                curShield = nil,
                nextShield = getNextShield(conf.id),
                damageList = {},
                bossId = conf.bossId,
                reliveTime = System.getNowTime(), --下一次复活时间
            }
            local ins = instancesystem.getInsByHdl(hfuben)
            if ins then
                ins.data.pkalimaid = id
                ins.data.bossid = conf.bossId
            end
        end
    end
end

table.insert(InitFnTable, initGlobalData)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.flushkalima = function (actor, args)
    local id = tonumber(args[1])
    local bossData = getBossData(id)
    bossData.reliveTime = System.getNowTime()
    refreshBoss(nil, id)
end

gmCmdHandlers.kalimafight = function (actor, args)
    local pack = LDataPack.allocPacket()
    LDataPack.writeInt(pack, args[1])
    LDataPack.setPosition(pack, 0)
    c2sKalimaFight(actor, pack)
end

gmCmdHandlers.kalimareborn = function (actor)
    -- c2sKalimaReborn(actor)
end

gmCmdHandlers.kalimalist = function (actor)
    c2sKalimaList(actor)
end

gmCmdHandlers.kalimaclearCD = function (actor)
    local var = getStaticData(actor)
    var.challengeCd = 0
    s2cKalimaInfo(actor)
end

gmCmdHandlers.kalimaGetRewad = function (actor, args)
    local pack = LDataPack.allocPacket()
    LDataPack.writeChar(pack, tonumber(args[1]) or 0)
    LDataPack.writeChar(pack, tonumber(args[2]) or 0)
    LDataPack.setPosition(pack, 0)
    c2sKalimaGetReward(actor, pack)
end

