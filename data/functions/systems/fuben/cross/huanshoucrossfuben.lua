-- 幻兽岛(多人)
module("huanshoucrossfuben", package.seeall)

HSBOSS_CROSS_DATA = HSBOSS_CROSS_DATA or {}
HSBOSS_CROSS_LIST = HSBOSS_CROSS_LIST or {}
local mtAttack = 1--击杀类型
local mtGatherCrystal = 2--水晶类型
local mtGatherStone = 3--圣石类型

local function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.hscrossfb then
        var.hscrossfb = {
            belongTimes = 0,
            gatherCrystalTimes = 0,
            gatherStoneTimes = 0,
            reminds = {},
        }
    end
    return var.hscrossfb
end

local function getHSCrossBossData(id)
    return HSBOSS_CROSS_DATA[id]
end

--求下一个护盾
local function getNextShield(id, hp)
    if nil == hp then hp = 101 end
    
    local conf = HuanshouCorssBossConfig[id]
    if nil == conf then return nil end
    for _, s in ipairs(conf.shield) do
        if s.hp < hp then
            return s
        end
    end
end

local function refreshBoss(_, id)
    if not System.isBattleSrv() then return end
    local bossData = getHSCrossBossData(id)
    local ins = instancesystem.getInsByHdl(bossData.hfuben)
    local handle = ins.scene_list[1]
    
    local position = HuanshouCorssBossConfig[id].pos
    Fuben.createMonster(ins.scene_list[1], id, position[1], position[2])
    
    bossData.hpPercent = 100
    bossData.damageList = {}
    bossData.nextShield = getNextShield(id)
    bossData.curShield = nil
    bossData.shield = 0
    bossData.refreshtime = 0
    if bossData.shieldEid then
        LActor.cancelScriptEvent(nil, bossData.shieldEid)
        bossData.shieldEid = nil
    end
    if bossData.tombHandle then
        LActor.destroyEntity(bossData.tombHandle)
        bossData.tombHandle = nil
    end
    
    updateHSFbInfo(id)
end

local function refreshCrystal(_, id)
    if not System.isBattleSrv() then return end
    local bossData = getHSCrossBossData(id)
    local ins = instancesystem.getInsByHdl(bossData.hfuben)
    local handle = ins.scene_list[1]
    
    for i, pos in ipairs(bossData.gatheredList) do
        Fuben.createMonster(ins.scene_list[1], id, pos[1], pos[2])
    end
    
    bossData.hpPercent = 100
    bossData.refreshtime = 0
    bossData.nextTime = System.getNowTime() + HuanshouBossCommonConfig.refreshtime
    bossData.gatheredList = {}
    
    LActor.postScriptEventLite(nil, HuanshouBossCommonConfig.refreshtime * 1000, refreshCrystal, id)
    broadHSCrossBossInfo(ins.handle, id, bossData.refreshtime)
    updateHSFbInfo(id)
end

local function refreshStone()
    if not System.isBattleSrv() then return end
    for mosterId, conf in pairs(HuanshouStoneGatherConfig) do
        local bossData = getHSCrossBossData(mosterId)
        if bossData.hpPercent == 0 then
            local ins = instancesystem.getInsByHdl(bossData.hfuben)
            local handle = ins.scene_list[1]
            local mon = Fuben.createMonster(ins.scene_list[1], mosterId, conf.postions[1], conf.postions[2])
            Fuben.setGatherExtend(mon, conf.extendTime, conf.extendMaxCount)
            
            bossData.hpPercent = 100
            bossData.refreshtime = 0
            broadHSCrossBossInfo(ins.handle, mosterId, bossData.refreshtime)
            updateHSFbInfo(mosterId)
        end
    end
end

--清空归属者
function clearBelongInfo(ins, actor, bossData)
    if LActor.getActorId(actor) == bossData.belongId then
        local x, y = LActor.getEntityScenePos(actor)
        instancesystem.s2cBelongListClear(bossData.hfuben, x, y)
        bossData.belongId = 0
        onBelongChange(bossData, actor, nil, x, y)
        return true
    end
    return false
end

function finishShield(_, bossData)
    if bossData.curShield == nil then return end
    
    bossData.shieldEid = nil
    bossData.shield = 0
    local x, y = HuanshouCorssBossConfig[bossData.bossId].pos[1], HuanshouCorssBossConfig[bossData.bossId].pos[2]
    instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, bossData.curShield.shield, nil, x, y)
end

function onBelongChange(bossData, oldBelong, newBelong, x, y)
    if oldBelong then
        LActor.setCamp(oldBelong, CampType_Normal)
    end
    if newBelong then
        LActor.setCamp(newBelong, CampType_Belong)
    end
    --广播归属者信息
    instancesystem.s2cBelongData(nil, oldBelong, LActor.getActorById(bossData.belongId), bossData.hfuben, x, y) ---归属者信息
end

function onEnerBossArea(ins, actor, bossId)
    local config = HuanshouCorssBossConfig[bossId]
    local bossData = getHSCrossBossData(bossId)
    if bossData.monType == mtGatherStone then
        instancesystem.s2cGatherBelongData(actor, nil, LActor.getActorById(bossData.belongId), bossData.hfuben)
        return
    end
    local actorId = LActor.getActorId(actor)
    if not bossData.damageList[actorId] then
        bossData.damageList[actorId] = LActor.getServerId(actor)
    end
    
    local handle = ins.scene_list[1]
    --护盾信息
    if bossData.curShield then
        nowShield = bossData.shield
        if (bossData.curShield.type or 0) == 1 then
            nowShield = nowShield - System.getNowTime()
            if nowShield < 0 then
                nowShield = 0
            end
        end
        
        instancesystem.s2cShieldInfo(ins.handle, bossData.curShield.type, nowShield, bossData.curShield.shield, actor)
    else
        instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, config.shield[1].shield, actor)
    end
    instancesystem.s2cBelongData(actor, nil, LActor.getActorById(bossData.belongId), bossData.hfuben)
    LActor.setCamp(actor, CampType_Normal)--设置阵营为普通模式
end

function onExitBossArea(ins, actor, bossId)
    if not ins then return end
    
    local bossData = getHSCrossBossData(bossId)
    if bossData.monType == mtGatherStone then
        local config = HuanshouStoneGatherConfig[bossId]
        instancesystem.s2cGatherBelongData(actor, nil, nil, bossData.hfuben)
        instancesystem.s2cGatherBelongData(nil, nil, nil, bossData.hfuben, config.postions[1], config.postions[2])
        return
    end
    
    LActor.setCamp(actor, CampType_Normal)
    local actorId = LActor.getActorId(actor)
    bossData.damageList[actorId] = nil
    
    local config = HuanshouCorssBossConfig[bossId]
    local isBelong = clearBelongInfo(ins, actor, bossData) --清除归属者
    instancesystem.s2cBelongData(actor, nil, nil, bossData.hfuben)
    instancesystem.s2cBelongData(nil, nil, nil, bossData.hfuben, config.pos[1], config.pos[2])
end

function hsCrossFbFight(actor, floor)
    local conf = HuanshouCrossFubenConfig[floor]
    if not conf then return end
    
    local hfuben = HSBOSS_CROSS_LIST[floor]
    if not hfuben then return end
    
    local x, y = utils.getSceneEnterCoor(conf.fbId)
    local crossId = csbase.getCrossServerId()
    LActor.loginOtherServer(actor, crossId, hfuben, 0, x, y, 'huanshou cross')
end

function hsCrossRemind(actor, bossId, status)
    if status ~= 0 and status ~= 1 then return end
    if not HSBOSS_CROSS_DATA[bossId] then return end
    local var = getActorVar(actor)
    if not var then return end
    
    var.reminds[bossId] = status
    s2cHSCrossRemind(actor, bossId, status)
end

function onHSCrystalFinish(ins, monster, actor)
    local monsterid = Fuben.getMonsterId(monster)
    local bossData = getHSCrossBossData(monsterid)
    local crystalGatherConfig = HuanshouCrystalGatherConfig[monsterid]
    --添加已采集列表,只刷新此列表的采集怪
    local gatheredList = bossData.gatheredList
    local x, y = LActor.getEntityScenePos(monster)
    table.insert(gatheredList, {x, y})
    if #gatheredList == #crystalGatherConfig.postions then
        bossData.hpPercent = 0
        bossData.refreshtime = bossData.nextTime
        broadHSCrossBossInfo(ins.handle, monsterid, bossData.refreshtime)
        updateHSFbInfo(monsterid)
    end
    
    local var = getActorVar(actor)
    if not var then return end
    if var.gatherCrystalTimes >= HuanshouBossCommonConfig.maxCrystalCount then return end
    
    var.gatherCrystalTimes = var.gatherCrystalTimes + 1
    local rewards = drop.dropGroup(crystalGatherConfig.dropId)
    actoritem.addItems(actor, rewards, "hscrossfb crystal rewards")
    s2cHSCrossUpdateInfo(actor)
end

function onHSStoneFinish(ins, monster, actor)
    local monsterid = Fuben.getMonsterId(monster)
    local bossData = getHSCrossBossData(monsterid)
    bossData.hpPercent = 0
    bossData.refreshtime = utils.getNextTimeByInterval(2)
    broadHSCrossBossInfo(ins.handle, monsterid, bossData.refreshtime)
    updateHSFbInfo(monsterid)
    
    local var = getActorVar(actor)
    if not var then return end
    if var.gatherStoneTimes >= HuanshouBossCommonConfig.maxStoneCount then return end
    
    var.gatherStoneTimes = var.gatherStoneTimes + 1
    local stoneGatherConfig = HuanshouStoneGatherConfig[monsterid]
    local rewards = drop.dropGroup(stoneGatherConfig.dropId)
    actoritem.addItems(actor, rewards, "hscrossfb stone rewards")
    noticesystem.broadCastCrossNotice(noticesystem.NTP.huanshoucross, LActor.getName(actor))
    s2cHSCrossGatherResult(actor, rewards)
    s2cHSCrossUpdateInfo(actor)
end

----------------------------------------------------------------------------------
--事件处理
local function onLogin(actor)
    s2cHSCrossFbInfo(actor)
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    var.belongTimes = 0
    var.gatherCrystalTimes = 0
    var.gatherStoneTimes = 0
    if not login then
        s2cHSCrossFbInfo(actor)
    end
end

local function onEnterBefore(ins, actor)
    local floor = ins.data.floor
    local config = HuanshouCrossFubenConfig[floor]
    if not config then return end
    
    local monsterList = {}
    --幻兽boss列表
    for _, monsterId in ipairs(config.refreshMonsters) do
        table.insert(monsterList, monsterId)
    end
    --幻兽水晶
    table.insert(monsterList, config.crystalMonsterId)
    --幻兽晶石
    if config.stoneMonsterId > 0 then
        table.insert(monsterList, config.stoneMonsterId)
    end
    --墓碑
    table.insert(monsterList, HuanshouBossCommonConfig.tombMonId)
    slim.s2cMonsterConfig(actor, monsterList)
end

local function onEnterFb(ins, actor)
    LActor.setCamp(actor, CampType_Normal)
end

local function onExitFb(ins, actor)
    local bossId = Fuben.getBossIdInArea(actor)
    if bossId == 0 then return end
    onExitBossArea(ins, actor, bossId)
end

local function onOffline(ins, actor)
    local bossId = Fuben.getBossIdInArea(actor)
    if bossId == 0 then return end
    onExitBossArea(ins, actor, bossId)
end

local function onBossDamage(ins, monster, value, attacker, res)
    local bossId = Fuben.getMonsterId(monster)
    local config = HuanshouCorssBossConfig[bossId]
    local bossData = getHSCrossBossData(bossId)
    
    local actor = LActor.getActor(attacker)
    if not actor then return end
    
    local actorId = LActor.getActorId(actor)
    if not bossData.damageList[actorId] then
        bossData.damageList[actorId] = LActor.getServerId(actor)
    end
    
    local var = getActorVar(actor)
    if var.belongTimes < HuanshouBossCommonConfig.maxBelongCount then
        if 0 == bossData.belongId and bossData.hfuben == LActor.getFubenHandle(attacker) then
            if LActor.isDeath(actor) == false and bossId == Fuben.getBossIdInArea(actor) then
                local oldBelong = LActor.getActorById(bossData.belongId)
                bossData.belongId = LActor.getActorId(actor)
                local x, y = LActor.getEntityScenePos(monster)
                onBelongChange(bossData, oldBelong, actor, x, y)
            end
        end
    end
    
    --更新boss血量信息
    local oldhp = LActor.getHp(monster)
    if oldhp <= 0 then return end
    
    local hp = oldhp - value
    if hp < 0 then hp = 0 end
    
    hp = hp / LActor.getHpMax(monster) * 100
    bossData.hpPercent = math.ceil(hp)
    
    --护盾判断
    local needShield = false
    if oldhp == LActor.getHpMax(monster) then
        bossData.nextShield = getNextShield(bossId)
        bossData.shield = 0
        bossData.curShield = nil
        -- 一刀秒死boss
        if hp == 0 then
            needShield = true
        end
    end
    if 0 == bossData.shield then --现在没有护盾
        if bossData.nextShield and 0 ~= bossData.nextShield.hp and hp < bossData.nextShield.hp then --从预备护盾里取护盾
            needShield = true
        end
    end
    
    if needShield then
        bossData.curShield = bossData.nextShield
        bossData.nextShield = getNextShield(bossId, bossData.curShield.hp) --再取下一个预备护盾
        
        res.ret = math.floor(LActor.getHpMax(monster) * bossData.curShield.hp / 100) --避免一招秒而不触发护盾，这里要恢复血量
        bossData.hpPercent = bossData.curShield.hp --要把血量设置回原值
        LActor.setInvincible(monster, bossData.curShield.shield * 1000) --设无敌状态
        bossData.shield = bossData.curShield.shield + System.getNowTime()
        local x, y = LActor.getEntityScenePos(monster)
        instancesystem.s2cShieldInfo(bossData.hfuben, 1, bossData.curShield.shield, bossData.curShield.shield, nil, x, y)
        --注册护盾结束定时器
        bossData.shieldEid = LActor.postScriptEventLite(nil, bossData.curShield.shield * 1000, finishShield, bossData)
        noticesystem.fubenAreaCastNotice(bossData.hfuben, noticesystem.NTP.homeShield, bossData.bossId)
    end
end

local function onBossDie(ins, monster, killHdl)
    local bossId = Fuben.getMonsterId(monster)
    local config = HuanshouCorssBossConfig[bossId]
    if not config then return end
    
    local bossData = getHSCrossBossData(bossId)
    if not bossData then return end
    
    LActor.postScriptEventLite(nil, config.refreshTime * 1000, refreshBoss, bossId)
    
    local belongInfo = {
        name = "",
        job = 0,
        id = 0
    }
    
    local belong = LActor.getActorById(bossData.belongId)
    if belong then
        belongInfo.name = LActor.getName(belong)
        belongInfo.job = LActor.getJob(belong)
        belongInfo.id = bossData.belongId
    end
    
    local scene_hdl = LActor.getSceneHandle(monster)
    local x, y = config.pos[1], config.pos[2]
    
    for actorId, serverId in pairs(bossData.damageList) do
        if actorId == bossData.belongId then
            if belong then
                LActor.setCamp(belong, CampType_Normal)

                local var = getActorVar(belong)
                var.belongTimes = var.belongTimes + 1
                local rewards = drop.dropGroup(config.belongDropId)
                sendHSCrossRewardResult(belong, 1, belongInfo, rewards, serverId)
                s2cHSCrossUpdateInfo(belong)
            end
        else
            local actor = LActor.getActorById(actorId)
            if actor then
                LActor.setCamp(actor, CampType_Normal)
                sendHSCrossRewardResult(actor, 0, belongInfo, {}, serverId)
            end
        end
    end
    instancesystem.s2cBelongData(nil, nil, nil, bossData.hfuben, x, y) ---归属者信息
    
    bossData.hpPercent = 0
    local refreshtime = config.refreshTime + System.getNowTime()
    bossData.refreshtime = refreshtime
    bossData.damageList = {}
    clearBelongInfo(ins, belong, bossData) --清除归属者
    bossData.belongId = 0
    
    broadHSCrossBossInfo(ins.handle, bossId, refreshtime)
    updateHSFbInfo(bossId)
    
    local tomb = Fuben.createMonster(scene_hdl, HuanshouBossCommonConfig.tombMonId, x, y)
    if tomb then
        bossData.tombHandle = LActor.getRealHandle(tomb)
    end
end

local function onActorDie(ins, actor, killHdl)
    local et = LActor.getEntity(killHdl)
    if not et then return end
    
    local attacker = LActor.getEntityType(et)
    local bossId = Fuben.getBossIdInArea(actor)
    local config = HuanshouCorssBossConfig[bossId]
    if not config then return end
    
    local bossData = getHSCrossBossData(bossId)
    if nil == bossData then return end
    local x, y = LActor.getEntityScenePos(actor)
    
    if LActor.getActorId(actor) == bossData.belongId then
        instancesystem.s2cBelongListClear(bossData.hfuben, x, y)
        --归属者被玩家打死，该玩家是新归属者
        if actorcommon.isActor(attacker) then
            local newactor = LActor.getActor(et)
            bossData.belongId = LActor.getActorId(newactor)
        elseif EntityType_Monster == attacker then --归属者被怪物打死，怪物无归属
            bossData.belongId = 0
        end
        local belong = LActor.getActorById(bossData.belongId)
        if belong then
            x, y = LActor.getEntityScenePos(belong)
            --广播归属者信息
            onBelongChange(bossData, actor, belong, x, y)
        else
            bossData.belongId = 0
            instancesystem.s2cBelongData(nil, nil, nil, bossData.hfuben, x, y)
        end
    else
        --不是归属者,死亡时候切换回正常阵营
        if LActor.getCamp(actor) == CampType_Attack then
            LActor.setCamp(actor, CampType_Normal)
        end
    end
end

local function onGatherMonsterUpdate(ins, monster, actor)
    local status, gather_time, wait_time = LActor.getGatherMonsterInfo(monster)
    local monsterid = Fuben.getMonsterId(monster)
    local bossData = getHSCrossBossData(monsterid)
    if not bossData then return end
    if status == GatherStatusType_CanGather then
        if bossData.monType ~= mtGatherStone then return end
        local oldBelong = LActor.getActorById(bossData.belongId)
        bossData.belongId = 0
        
        local stoneGatherConfig = HuanshouStoneGatherConfig[monsterid]
        if not stoneGatherConfig then return end
        instancesystem.s2cGatherBelongData(nil, oldBelong, nil, bossData.hfuben, stoneGatherConfig.postions[1], stoneGatherConfig.postions[2])
    elseif status == GatherStatusType_Gathering then
        if bossData.monType ~= mtGatherStone then return end
        local oldBelong = LActor.getActorById(bossData.belongId)
        bossData.belongId = LActor.getActorId(actor)
        
        local stoneGatherConfig = HuanshouStoneGatherConfig[monsterid]
        if not stoneGatherConfig then return end
        instancesystem.s2cGatherBelongData(nil, oldBelong, actor, bossData.hfuben, stoneGatherConfig.postions[1], stoneGatherConfig.postions[2])
    elseif status == GatherStatusType_Finish then
        if bossData.monType == mtGatherCrystal then
            onHSCrystalFinish(ins, monster, actor)
        elseif bossData.monType == mtGatherStone then
            onHSStoneFinish(ins, monster, actor)
            
            bossData.belongId = 0
            local stoneGatherConfig = HuanshouStoneGatherConfig[monsterid]
            if not stoneGatherConfig then return end
            instancesystem.s2cGatherBelongData(nil, nil, nil, bossData.hfuben, stoneGatherConfig.postions[1], stoneGatherConfig.postions[2])
        end
    end
end

-------------------------------------------------------------------------------------------------------
--协议处理
--85-120 幻兽岛-请求界面信息
local function c2sHSCrossFbInfo(actor)
    s2cHSCrossFbInfo(actor)
end

--85-120 幻兽岛-界面信息
function s2cHSCrossFbInfo(actor)
    if next(HSBOSS_CROSS_DATA) == nil then return end
    
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sHSCrossFb_Info)
    if pack == nil then return end
    
    LDataPack.writeInt(pack, var.belongTimes)
    LDataPack.writeInt(pack, var.gatherCrystalTimes)
    LDataPack.writeInt(pack, var.gatherStoneTimes)
    local pos = LDataPack.getPosition(pack)
    local count = 0
    LDataPack.writeChar(pack, count)
    for bossId, bossData in pairs(HSBOSS_CROSS_DATA) do
        local mon_conf = MonstersConfig[bossId]
        LDataPack.writeInt(pack, bossId)
        LDataPack.writeChar(pack, bossData.monType)
        LDataPack.writeChar(pack, bossData.floor)
        LDataPack.writeString(pack, mon_conf.name)
        LDataPack.writeString(pack, mon_conf.head)
        LDataPack.writeShort(pack, mon_conf.avatar[1])
        LDataPack.writeInt(pack, bossData.refreshtime)
        LDataPack.writeChar(pack, var.reminds[bossId] or 0)
        count = count + 1
    end
    local pos2 = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, pos)
    LDataPack.writeChar(pack, count)
    LDataPack.setPosition(pack, pos2)
    LDataPack.flush(pack)
end

--85-121 幻兽岛-进入副本
local function c2sHSCrossFbFight(actor, pack)
    local floor = LDataPack.readChar(pack)
    
    if System.isCrossWarSrv() then return end
    if not actorlogin.checkCanEnterCross(actor) then return end
    if not staticfuben.canEnterFuben(actor) then return end
    hsCrossFbFight(actor, floor)
end

--85-122 幻兽岛-副本内更新幻兽boss复活状态
function broadHSCrossBossInfo(fbhdl, id, refreshtime)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Cross)
    LDataPack.writeByte(pack, Protocol.sHSCrossFb_BossInfo)
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, refreshtime)
    Fuben.sendData(fbhdl, pack)
end

--85-122 幻兽岛-副本外更新幻兽boss复活状态
function broadHSCrossFbInfo(id)
    local bossData = getHSCrossBossData(id)
    if not bossData then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Cross)
    LDataPack.writeByte(pack, Protocol.sHSCrossFb_BossInfo)
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, bossData.refreshtime)
    System.broadcastData(pack)
end

--85-123 幻兽岛-战斗结算
function sendHSCrossRewardResult(actor, res, belongInfo, rewards, serverId)
    if actor and actoritem.checkEquipBagSpaceJob(actor, rewards) then
        actoritem.addItems(actor, rewards, "hscrossfb rewards")
    else
        local mailData = {head = HuanshouBossCommonConfig.mailTitle, context = HuanshouBossCommonConfig.mailContent, tAwardList = rewards}
        mailsystem.sendMailById(LActor.getActorId(actor), mailData, serverId)
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sHSCrossFb_Result)
    if pack == nil then return end
    LDataPack.writeChar(pack, res)
    LDataPack.writeInt(pack, belongInfo.id)
    LDataPack.writeString(pack, belongInfo.name)
    LDataPack.writeChar(pack, belongInfo.job)
    LDataPack.writeChar(pack, #rewards)
    for _, reward in ipairs(rewards) do
        LDataPack.writeInt(pack, reward.type)
        LDataPack.writeInt(pack, reward.id)
        LDataPack.writeInt(pack, reward.count)
    end
    LDataPack.flush(pack)
end

--85-124 幻兽岛-更新基础数据
function s2cHSCrossUpdateInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sHSCrossFb_Update)
    if pack == nil then return end
    
    LDataPack.writeInt(pack, var.belongTimes)
    LDataPack.writeInt(pack, var.gatherCrystalTimes)
    LDataPack.writeInt(pack, var.gatherStoneTimes)
    LDataPack.flush(pack)
end

--85-125 幻兽岛-请求关注
local function c2sHSCrossRemind(actor, pack)
    local bossId = LDataPack.readInt(pack)
    local status = LDataPack.readChar(pack)
    
    hsCrossRemind(actor, bossId, status)
end

--85-125 幻兽岛-返回关注
function s2cHSCrossRemind(actor, bossId, status)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sHSCrossFb_Remind)
    if pack == nil then return end
    
    LDataPack.writeInt(pack, bossId)
    LDataPack.writeInt(pack, status)
    LDataPack.flush(pack)
end

--85-126 幻兽岛-采集结算
function s2cHSCrossGatherResult(actor, rewards)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sHSCrossFb_GatherResult)
    if pack == nil then return end
    
    --LDataPack.writeChar(pack, res)
    --LDataPack.writeInt(pack, belongInfo.id)
    --LDataPack.writeString(pack, belongInfo.name)
    --LDataPack.writeChar(pack, belongInfo.job)
    LDataPack.writeChar(pack, #rewards)
    for _, reward in ipairs(rewards) do
        LDataPack.writeInt(pack, reward.type)
        LDataPack.writeInt(pack, reward.id)
        LDataPack.writeInt(pack, reward.count)
    end
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--跨服协议
--跨服向普通服同步boss信息
function sendHSFbInfo(serverId)
    if not System.isBattleSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCHuanShouCrossCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCHuanShouCrossCmd_SyncAllFbInfo)
    
    LDataPack.writeByte(pack, #HuanshouCrossFubenConfig)
    for floor in ipairs(HuanshouCrossFubenConfig) do
        LDataPack.writeInt64(pack, HSBOSS_CROSS_LIST[floor])
    end
    
    local bossDataUd = bson.encode(HSBOSS_CROSS_DATA)
    LDataPack.writeUserData(pack, bossDataUd)
    
    System.sendPacketToAllGameClient(pack, serverId or 0)
end

--普通服收到跨服boss信息
function onSendHSFbInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    HSBOSS_CROSS_LIST = {}
    
    local count = LDataPack.readByte(dp)
    for floor = 1, count do
        HSBOSS_CROSS_LIST[floor] = LDataPack.readInt64(dp)
    end
    
    local bossDataUd = LDataPack.readUserData(dp)
    HSBOSS_CROSS_DATA = bson.decode(bossDataUd)
end

--跨服给普通服更新单个boss信息
function updateHSFbInfo(id)
    if not System.isBattleSrv() then return end
    local bossData = getHSCrossBossData(id)
    if not bossData then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCHuanShouCrossCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCHuanShouCrossCmd_SyncUpdateFbInfo)
    
    LDataPack.writeInt(pack, bossData.bossId)
    LDataPack.writeInt64(pack, bossData.hfuben)
    LDataPack.writeInt(pack, bossData.refreshtime)
    System.sendPacketToAllGameClient(pack, 0)
end

--普通服收到更新单个boss信息
function onUpdateHSFbInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local id = LDataPack.readInt(dp)
    if not HSBOSS_CROSS_DATA[id] then return end
    HSBOSS_CROSS_DATA[id].hfuben = LDataPack.readInt64(dp)
    HSBOSS_CROSS_DATA[id].refreshtime = LDataPack.readInt(dp)
    broadHSCrossFbInfo(id)
end

--连接跨服事件
local function onHSFBConnected(serverId, serverType)
    sendHSFbInfo(serverId)
end
----------------------------------------------------------------------------------
--初始化
local function initGlobalData()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cHSCrossFb_Info, c2sHSCrossFbInfo)
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cHSCrossFb_Fight, c2sHSCrossFbFight)
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cHSCrossFb_Remind, c2sHSCrossRemind)
    
    csmsgdispatcher.Reg(CrossSrvCmd.SCHuanShouCrossCmd, CrossSrvSubCmd.SCHuanShouCrossCmd_SyncAllFbInfo, onSendHSFbInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHuanShouCrossCmd, CrossSrvSubCmd.SCHuanShouCrossCmd_SyncUpdateFbInfo, onUpdateHSFbInfo)
    
    if not System.isBattleSrv() then return end
    for _, conf in pairs(HuanshouCrossFubenConfig) do
        local fbId = conf.fbId
        local floor = conf.floor
        
        insevent.registerInstanceEnterBefore(fbId, onEnterBefore)
        insevent.registerInstanceEnter(fbId, onEnterFb)
        insevent.registerInstanceExit(fbId, onExitFb)
        insevent.registerInstanceOffline(fbId, onOffline)
        insevent.registerInstanceMonsterDamage(fbId, onBossDamage)
        insevent.registerInstanceMonsterDie(fbId, onBossDie)
        insevent.registerInstanceActorDie(fbId, onActorDie)
        insevent.registerInstanceEnerBossArea(fbId, onEnerBossArea)
        insevent.registerInstanceExitBossArea(fbId, onExitBossArea)
        insevent.registerInstanceGatherMonsterUpdate(fbId, onGatherMonsterUpdate)
        
        local hfuben = HSBOSS_CROSS_LIST[floor] or 0
        if hfuben == 0 then
            hfuben = instancesystem.createFuBen(fbId)
            HSBOSS_CROSS_LIST[floor] = hfuben
        end
        assert(hfuben ~= 0)
        
        local ins = instancesystem.getInsByHdl(hfuben)
        ins.data.floor = floor
        for _, bossId in ipairs(conf.refreshMonsters) do
            if not HSBOSS_CROSS_DATA[bossId] then
                HSBOSS_CROSS_DATA[bossId] = {
                    bossId = bossId,
                    monType = mtAttack,
                    floor = floor,
                    hpPercent = 100,
                    hfuben = hfuben,
                    shield = 0,
                    curShield = nil,
                    nextShield = getNextShield(bossId),
                    belongId = 0,
                    damageList = {},
                    refreshtime = 0,
                }
                local pos = HuanshouCorssBossConfig[bossId].pos
                Fuben.createMonster(ins.scene_list[1], bossId, pos[1], pos[2])
            end
        end
        
        local crystalMonsterId = conf.crystalMonsterId
        if not HSBOSS_CROSS_DATA[crystalMonsterId] then
            HSBOSS_CROSS_DATA[crystalMonsterId] = {
                bossId = crystalMonsterId,
                monType = mtGatherCrystal,
                floor = floor,
                hpPercent = 100,
                hfuben = hfuben,
                refreshtime = 0,
                nextTime = System.getNowTime() + HuanshouBossCommonConfig.refreshtime,
                gatheredList = {},
            }
            local crystalGatherConfig = HuanshouCrystalGatherConfig[crystalMonsterId]
            for idx, pos in ipairs(crystalGatherConfig.postions) do
                Fuben.createMonster(ins.scene_list[1], crystalMonsterId, pos[1], pos[2])
            end
            LActor.postScriptEventLite(nil, HuanshouBossCommonConfig.refreshtime * 1000, refreshCrystal, crystalMonsterId)
        end
        
        local stoneMonsterId = conf.stoneMonsterId
        if stoneMonsterId > 0 and not HSBOSS_CROSS_DATA[stoneMonsterId] then
            HSBOSS_CROSS_DATA[stoneMonsterId] = {
                bossId = stoneMonsterId,
                monType = mtGatherStone,
                floor = floor,
                hpPercent = 100,
                hfuben = hfuben,
                belongId = 0,
                refreshtime = 0,
            }
            local stoneGatherConfig = HuanshouStoneGatherConfig[stoneMonsterId]
            local mon = Fuben.createMonster(ins.scene_list[1], stoneMonsterId, stoneGatherConfig.postions[1], stoneGatherConfig.postions[2])
            Fuben.setGatherExtend(mon, stoneGatherConfig.extendTime, stoneGatherConfig.extendMaxCount)
        end
    end
    csbase.RegConnected(onHSFBConnected)
end
table.insert(InitFnTable, initGlobalData)

_G.RefreshStone = refreshStone

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.HSreset = function (actor, args)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    var.hscrossfb = nil
    s2cHSCrossUpdateInfo(actor)
    return true
end

gmCmdHandlers.HSPrint = function (actor, args)
    local var = getActorVar(actor)
    print("belongTimes =", var.belongTimes)
    print("gatherCrystalTimes =", var.gatherCrystalTimes)
    print("gatherStoneTimes =", var.gatherStoneTimes)
    return true
end

gmCmdHandlers.HSFight = function (actor, args)
    local floor = tonumber(args[1])
    hsCrossFbFight(actor, floor)
    return true
end

gmCmdHandlers.HSFbPrint = function (actor, args)
    utils.printTable(HSBOSS_CROSS_DATA)
    utils.printTable(HSBOSS_CROSS_LIST)
    return true
end

gmCmdHandlers.HSFbRefresh = function (actor, args)
    if not System.isBattleSrv() then return end
    local monsterId = tonumber(args[1])
    if not monsterId then return end
    local bossData = getHSCrossBossData(monsterId)
    if not bossData then return end
    if bossData.monType == mtAttack then
        refreshBoss(nil, monsterId)
    elseif bossData.monType == mtGatherCrystal then
        refreshCrystal(nil, monsterId)
    elseif bossData.monType == mtGatherStone then
        refreshStone()
    end
    return true
end

