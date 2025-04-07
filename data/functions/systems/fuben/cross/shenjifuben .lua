-- 神迹秘境
module("shenjifuben", package.seeall)

SJBOSS_DATA = SJBOSS_DATA or {}
SJFUBEN_LIST = SJFUBEN_LIST or {}
SJBOSS_INDEX = SJBOSS_INDEX or {}

local function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.sjfb then
        var.sjfb = {
            maxPoint = SJFBCommonConfig.maxPoint
        }
    end
    return var.sjfb
end

local function getSJBossData(id)
    return SJBOSS_DATA[id]
end

local function getConfigBybossId(bossId)
    local id = SJBOSS_INDEX[bossId]
    return ShenJiBossConfig[id]
end

--求下一个护盾
local function getNextShield(id, hp)
    if nil == hp then hp = 101 end
    
    local conf = ShenJiBossConfig[id]
    if nil == conf then return nil end
    for _, s in ipairs(conf.shield) do
        if s.hp < hp then
            return s
        end
    end
end

local function refreshBoss(_, id)
    local bossData = getSJBossData(id)
    local ins = instancesystem.getInsByHdl(bossData.hfuben)
    local handle = ins.scene_list[1]
    -- local scene = Fuben.getScenePtr(handle)
    print("shenjifuben refreshBoss handle =", ins.handle, " id =", id, "bossId =", bossData.bossId)
    local position = ShenJiBossConfig[id].refreshpos
    local boss = ins:insCreateMonster(handle, bossData.bossId, position.x, position.y)
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
    bossinfo.createBossInfo(ins, bossData.bossId, boss)
    
    updateSJFbInfo(id)
end

local function killTomb(_, hdl)
    LActor.destroyEntity(hdl)
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
    local x, y = LActor.getEntityScenePos(bossData.monster)
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
    local config = getConfigBybossId(bossId)
    local bossData = getSJBossData(config.id)
    local actorId = LActor.getActorId(actor)
    if not bossData.damageList[actorId] then
        bossData.damageList[actorId] = LActor.getServerId(actor)
    end
    
    local handle = ins.scene_list[1]
    local scene = Fuben.getScenePtr(handle)
    local monster = Fuben.getSceneMonsterById(scene, bossData.bossId)
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
    local config = getConfigBybossId(bossId)
    
    LActor.setCamp(actor, CampType_Normal) --退出变回正常阵营，此行影响s2cAttackList里的攻击者数量
    local bossData = getSJBossData(config.id)
    local actorId = LActor.getActorId(actor)
    bossData.damageList[actorId] = nil
    
    local isBelong = clearBelongInfo(ins, actor, bossData) --清除归属者
    local refreshpos = config.refreshpos
    instancesystem.s2cBelongData(actor, nil, nil, bossData.hfuben, refreshpos.x, refreshpos.y)
    instancesystem.s2cBelongData(nil, nil, nil, bossData.hfuben, refreshpos.x, refreshpos.y)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SMBossDisappear)
    LDataPack.writeByte(pack, config.id)
    LDataPack.flush(pack)
    -- 尝试转移归属
    if isBelong then
        Fuben.bossAttackActorInArea(bossId, actor)
    end
end

function SJBossFight(actor, sjId, floor)
    if not sjzhsystem.checkSJZHOpen(actor, sjId) then return end
    
    local conf = ShenJiFubenConfig[sjId] and ShenJiFubenConfig[sjId][floor]
    if not conf then return end
    
    local var = getActorVar(actor)
    if var.maxPoint <= 0 then return end
    
    local hfuben = SJFUBEN_LIST[sjId] and SJFUBEN_LIST[sjId][floor]
    if not hfuben then return end
    
    local x, y = utils.getSceneEnterCoor(conf.fbId)
    local crossId = csbase.getCrossServerId()
    LActor.loginOtherServer(actor, crossId, hfuben, 0, x, y, 'shenjiboss')
end

function changeSJPoint(actor, count, costType)
    local var = getActorVar(actor)
    if not var then return end
    local beforePoint = var.maxPoint
    local afterPoint = beforePoint + count
    local maxConfigPoint = SJFBCommonConfig.maxPoint
    if halosystem.isBuyHalo(actor) then
        maxConfigPoint = maxConfigPoint + SJFBCommonConfig.haloPoint
    end
    if afterPoint <= 0 then
        afterPoint = 0
        LActor.postScriptEventLite(actor, 3 * 1000, exitSJFb)
    elseif afterPoint > maxConfigPoint then
        afterPoint = maxConfigPoint
    end
    var.maxPoint = afterPoint
    s2cSJMaxPoint(actor)
    local extra = string.format("before:%d,after:%d", beforePoint, afterPoint)
    costType = costType or "default"
    utils.logCounter(actor, 'changeSJPoint', count, extra, costType)
end

function exitSJFb(actor)
    if not System.isBattleSrv() then return end
    LActor.exitFuben(actor)
end

----------------------------------------------------------------------------------
--事件处理
local function onLogin(actor)
    s2cSJBossList(actor)
    s2cSJBossSetDouble(actor)
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    local maxPoint = var.maxPoint
    local maxConfigPoint = SJFBCommonConfig.maxPoint
    if halosystem.isBuyHalo(actor) then
        maxConfigPoint = maxConfigPoint + SJFBCommonConfig.haloPoint
    end
    if maxPoint < maxConfigPoint then
        var.maxPoint = maxConfigPoint
    end
    if not login then
        s2cSJBossList(actor)
    end
end

local function onEnterBefore(ins, actor)
    slim.s2cMonsterConfig(actor, {SJFBCommonConfig.tombMonId})
end

local function onEnterFb(ins, actor)
    LActor.setCamp(actor, CampType_Normal)
    local count = SJFBCommonConfig.consumePoint
    LActor.postScriptEventEx(actor, SJFBCommonConfig.consumeTime * 1000, function(...) changeSJPoint(actor, -count) end, SJFBCommonConfig.consumeTime * 1000, -1)
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

local function onBossCreate(ins, monster)
    if not ins.data.bossPos then
        ins.data.bossPos = {}
    end
    
    local bossId = Fuben.getMonsterId(monster)
    local x, y = LActor.getEntityScenePos(monster)
    ins.data.bossPos[bossId] = {
        x = x,
        y = y,
    }
end

local function onMonsterAiReset(ins, monster)
    local bossId = Fuben.getMonsterId(monster)
    local config = getConfigBybossId(bossId)
    if config == nil then
        print('shenjifuben.onMonsterAiReset config==nil bossId=' .. bossId)
        return
    end
    local index = config.id
    local bossData = getSJBossData(index)
    if bossData == nil then
        return
    end
    finishShield(nil, bossData)
    -- bug:6929 【Boss圣殿】进入Boss区域需要立即更新Boss的血条数据​
    if ins.boss_info then
        local info = ins.boss_info[bossId]
        if info then
            info.hp = LActor.getHp(monster)
        end
    end
end

local function onBossDamage(ins, monster, value, attacker, res)
    local bossId = Fuben.getMonsterId(monster)
    local config = getConfigBybossId(bossId)
    local index = config.id
    local bossData = getSJBossData(index)
    
    local actor = LActor.getActor(attacker)
    if not actor then return end
    
    local actorId = LActor.getActorId(actor)
    if not bossData.damageList[actorId] then
        bossData.damageList[actorId] = LActor.getServerId(actor)
    end
    
    local var = getActorVar(actor)
    if var.maxPoint > 0 then
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
    
    bossData.monster = monster --记录BOSS实体
    
    --护盾判断
    local needShield = false
    if oldhp == LActor.getHpMax(monster) then
        bossData.nextShield = getNextShield(bossData.id)
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
        bossData.nextShield = getNextShield(bossData.id, bossData.curShield.hp) --再取下一个预备护盾
        
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
    local config = getConfigBybossId(bossId)
    if not config then return end
    
    local index = config.id
    local bossData = getSJBossData(index)
    --先注册定时器通知复活,防止因为报错导致不会刷新
    print("shenjifuben onBossDie handle =", ins.handle, " id =", bossData.id, "bossId =", bossId)
    LActor.postScriptEventLite(nil, config.refreshtime * 1000, refreshBoss, bossData.id)
    
    local belong = LActor.getActorById(bossData.belongId)
    if not belong then return end
    
    local bName = LActor.getActorName(bossData.belongId)
    local bJob = LActor.getJob(belong)
    local belongInfo = {
        name = bName,
        job = bJob,
        id = bossData.belongId
    }
    
    local scene_hdl = LActor.getSceneHandle(monster)
    local x, y = LActor.getEntityScenePos(monster)
    
    local rewardPoint = SJFBCommonConfig.rewardPoint
    for actorId, serverId in pairs(bossData.damageList) do
        if actorId == bossData.belongId then
            LActor.setCamp(belong, CampType_Normal)
            
            local var = getActorVar(belong)
            if var.maxPoint > 0 then
                local rewards = drop.dropGroup(config.belongDrop)
                if var.isDouble == 1 then
                    for _, reward in ipairs(rewards) do
                        reward.count = reward.count * 2
                    end
                    changeSJPoint(belong, -(rewardPoint * 2), "belongReward double")
                else
                    changeSJPoint(belong, -rewardPoint, "belongReward")
                end
                sendSJRewardResult(belong, 1, belongInfo, rewards, serverId)
                s2cSJMaxPoint(belong)
            end
        else
            local actor = LActor.getActorById(actorId)
            if actor then
                LActor.setCamp(actor, CampType_Normal)
                
                local var = getActorVar(actor)
                if var.maxPoint > 0 then
                    local rewards = drop.dropGroup(config.joinDrop)
                    if var.isDouble == 1 then
                        for _, reward in ipairs(rewards) do
                            reward.count = reward.count * 2
                        end
                        changeSJPoint(belong, -(rewardPoint * 2), "joinReward")
                    else
                        changeSJPoint(actor, -rewardPoint, "joinReward")
                    end
                    sendSJRewardResult(actor, 0, belongInfo, rewards, serverId)
                    s2cSJMaxPoint(actor)
                end
            end
        end
    end
    instancesystem.s2cBelongData(nil, nil, nil, bossData.hfuben, x, y) ---归属者信息
    --boss信息重置
    bossData.hpPercent = 0
    local refreshtime = config.refreshtime
    local refresh_endtime = refreshtime + System.getNowTime()
    bossData.refreshtime = refresh_endtime
    bossData.damageList = {}
    clearBelongInfo(ins, belong, bossData) --清除归属者
    bossData.belongId = 0
    
    -- 更新副本玩家
    broadSJBossInfo(ins.handle, index, refresh_endtime)
    -- 更新普通服
    updateSJFbInfo(index)
    -- 创建boss墓碑
    local tomb = Fuben.createMonster(scene_hdl, SJFBCommonConfig.tombMonId, x, y, refreshtime, 0, bName)
    if tomb then
        local hdl = LActor.getRealHandle(tomb)
        LActor.postScriptEventLite(nil, refreshtime * 1000 - 1, killTomb, hdl)
    end
end

local function onActorDie(ins, actor, killHdl)
    local et = LActor.getEntity(killHdl)
    if not et then return end
    
    local attacker = LActor.getEntityType(et)
    local bossId = Fuben.getBossIdInArea(actor)
    local config = getConfigBybossId(bossId)
    if not config then return end
    
    local bossData = getSJBossData(config.id)
    if nil == bossData then return end
    local x, y = LActor.getEntityScenePos(actor)
    
    if LActor.getActorId(actor) == bossData.belongId then
        instancesystem.s2cBelongListClear(bossData.hfuben, x, y)
        --归属者被玩家打死，该玩家是新归属者
        if actorcommon.isActor(attacker) then
            local newactor = LActor.getActor(et)
            bossData.belongId = LActor.getActorId(newactor)
            --怪物攻击新的归属者
            local handle = ins.scene_list[1]
            local scene = Fuben.getScenePtr(handle)
            local monster = Fuben.getSceneMonsterById(scene, bossData.bossId)
            if not monster then
                print("Error monster in actor belongId die")
            end
            LActor.setAITarget(monster, et)
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

-------------------------------------------------------------------------------------------------------
--协议处理
--85-80 神迹秘境-请求秘境boss信息
local function c2sSJBossInfo(actor)
    s2cSJBossList(actor)
end

--85-80 神迹秘境-更新秘境boss信息
function s2cSJBossList(actor)
    if next(SJBOSS_DATA) == nil then return end
    
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsSJBoss_Info)
    if pack == nil then return end
    
    LDataPack.writeInt(pack, var.maxPoint)
    LDataPack.writeChar(pack, #ShenJiBossConfig)
    for id, conf in pairs(ShenJiBossConfig) do
        local bossData = getSJBossData(id)
        local mon_conf = MonstersConfig[conf.bossId]
        LDataPack.writeChar(pack, id)
        LDataPack.writeString(pack, mon_conf.name)
        LDataPack.writeString(pack, mon_conf.head)
        LDataPack.writeShort(pack, mon_conf.avatar[1])
        LDataPack.writeInt(pack, bossData.refreshtime)
    end
    LDataPack.flush(pack)
end

--85-81 神迹秘境-挑战秘境boss
local function c2sSJBossFight(actor, pack)
    local sjId = LDataPack.readChar(pack)
    local floor = LDataPack.readChar(pack)
    
    if System.isCrossWarSrv() then return end
    if not actorlogin.checkCanEnterCross(actor) then return end
    if not staticfuben.canEnterFuben(actor) then return end
    SJBossFight(actor, sjId, floor)
end

--85-82 神迹秘境-副本内更新秘境boss复活状态
function broadSJBossInfo(fbhdl, id, refreshtime)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Cross)
    LDataPack.writeByte(pack, Protocol.sCsSJBoss_BossInfo)
    LDataPack.writeChar(pack, id)
    LDataPack.writeInt(pack, refreshtime)
    Fuben.sendData(fbhdl, pack)
end

--85-82 神迹秘境-副本外更新秘境boss复活状态
function broadSJFbInfo(id)
    local bossData = getSJBossData(id)
    if not bossData then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Cross)
    LDataPack.writeByte(pack, Protocol.sCsSJBoss_BossInfo)
    LDataPack.writeChar(pack, id)
    LDataPack.writeInt(pack, bossData.refreshtime)
    System.broadcastData(pack)
end

--85-83 神迹秘境-玩家战斗结算
function sendSJRewardResult(actor, res, belongInfo, rewards, serverId)
    if actor and actoritem.checkEquipBagSpaceJob(actor, rewards) then
        actoritem.addItems(actor, rewards, "sjfb rewards")
    else
        local mailData = {head = SJFBCommonConfig.mailTitle, context = SJFBCommonConfig.mailContent, tAwardList = rewards}
        mailsystem.sendMailById(LActor.getActorId(actor), mailData, serverId)
    end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsSJBoss_Result)
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

--85-84 神迹秘境-更新元素能量值
function s2cSJMaxPoint(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsSJBoss_MaxPoint)
    if pack == nil then return end
    
    LDataPack.writeInt(pack, var.maxPoint)
    LDataPack.flush(pack)
end

--85-85 神迹秘境-设置双倍消耗状态
local function c2sSJBossSetDouble(actor)
    if not halosystem.isBuyHalo(actor) then return end
    local var = getActorVar(actor)
    if not var then return end
    local status = var.isDouble or 0
    status = (status + 1) % 2
    
    var.isDouble = status
    s2cSJBossSetDouble(actor)
end

--85-85 神迹秘境-更新双倍消耗状态
function s2cSJBossSetDouble(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsSJBoss_SetDouble)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, var.isDouble or 0)
    LDataPack.flush(pack)
end
----------------------------------------------------------------------------------
--跨服协议
--跨服向普通服同步boss信息
function sendSJFbInfo(serverId)
    if not System.isBattleSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCShenJiCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCShenJiCmd_SyncAllFbInfo)
    
    LDataPack.writeByte(pack, #ShenJiFubenConfig)
    for sjId, config in ipairs(ShenJiFubenConfig) do
        LDataPack.writeByte(pack, #config)
        for floor, conf in ipairs(config) do
            LDataPack.writeInt64(pack, SJFUBEN_LIST[sjId][floor])
        end
    end
    
    LDataPack.writeByte(pack, #ShenJiBossConfig)
    for id in ipairs(ShenJiBossConfig) do
        local bossData = getSJBossData(id)
        LDataPack.writeByte(pack, bossData.id)
        LDataPack.writeInt64(pack, bossData.hfuben)
        LDataPack.writeInt(pack, bossData.bossId)
        LDataPack.writeInt(pack, bossData.refreshtime)
    end
    System.sendPacketToAllGameClient(pack, serverId or 0)
end

--普通服收到跨服boss信息
function onSendSJFbInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local count = LDataPack.readByte(dp)
    SJFUBEN_LIST = {}
    for sjId = 1, count do
        SJFUBEN_LIST[sjId] = {}
        local cnt = LDataPack.readByte(dp)
        for floor = 1, cnt do
            SJFUBEN_LIST[sjId][floor] = LDataPack.readInt64(dp)
        end
    end
    
    local number = LDataPack.readByte(dp)
    SJBOSS_DATA = {}
    for i = 1, number do
        local id = LDataPack.readByte(dp)
        SJBOSS_DATA[id] = {}
        SJBOSS_DATA[id].hfuben = LDataPack.readInt64(dp)
        SJBOSS_DATA[id].bossId = LDataPack.readInt(dp)
        SJBOSS_DATA[id].refreshtime = LDataPack.readInt(dp)
    end
end

--跨服给普通服更新单个boss信息
function updateSJFbInfo(id)
    if not System.isBattleSrv() then return end
    local bossData = getSJBossData(id)
    if not bossData then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCShenJiCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCShenJiCmd_SyncUpdateFbInfo)
    
    LDataPack.writeByte(pack, id)
    LDataPack.writeInt64(pack, bossData.hfuben)
    LDataPack.writeInt(pack, bossData.bossId)
    LDataPack.writeInt(pack, bossData.refreshtime)
    System.sendPacketToAllGameClient(pack, 0)
end

--普通服收到更新单个boss信息
function onUpdateSJFbInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local id = LDataPack.readByte(dp)
    SJBOSS_DATA[id] = {}
    SJBOSS_DATA[id].hfuben = LDataPack.readInt64(dp)
    SJBOSS_DATA[id].bossId = LDataPack.readInt(dp)
    SJBOSS_DATA[id].refreshtime = LDataPack.readInt(dp)
    
    broadSJFbInfo(id)
end

--连接跨服事件
local function onSJFBConnected(serverId, serverType)
    sendSJFbInfo()
end
----------------------------------------------------------------------------------
--初始化
local function initGlobalData()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsSJBoss_Info, c2sSJBossInfo)
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsSJBoss_Fight, c2sSJBossFight)
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsSJBoss_SetDouble, c2sSJBossSetDouble)
    
    csmsgdispatcher.Reg(CrossSrvCmd.SCShenJiCmd, CrossSrvSubCmd.SCShenJiCmd_SyncAllFbInfo, onSendSJFbInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCShenJiCmd, CrossSrvSubCmd.SCShenJiCmd_SyncUpdateFbInfo, onUpdateSJFbInfo)
    
    if not System.isBattleSrv() then return end
    for _, config in pairs(ShenJiFubenConfig) do
        for __, conf in ipairs(config) do
            insevent.registerInstanceEnterBefore(conf.fbId, onEnterBefore)
            insevent.registerInstanceEnter(conf.fbId, onEnterFb)
            insevent.registerInstanceExit(conf.fbId, onExitFb)
            insevent.registerInstanceOffline(conf.fbId, onOffline)
            insevent.registerInstanceMonsterCreate(conf.fbId, onBossCreate)
            insevent.registerInstanceMonsterAiReset(conf.fbId, onMonsterAiReset)
            insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
            insevent.registerInstanceMonsterDie(conf.fbId, onBossDie)
            insevent.registerInstanceActorDie(conf.fbId, onActorDie)
            insevent.registerInstanceEnerBossArea(conf.fbId, onEnerBossArea)
            insevent.registerInstanceExitBossArea(conf.fbId, onExitBossArea)
            
            SJFUBEN_LIST[conf.sjId] = SJFUBEN_LIST[conf.sjId] or {}
            if not SJFUBEN_LIST[conf.sjId][conf.floor] then
                SJFUBEN_LIST[conf.sjId][conf.floor] = instancesystem.createFuBen(conf.fbId)
            end
        end
    end
    
    for id, conf in ipairs(ShenJiBossConfig) do
        local hfuben = SJFUBEN_LIST[conf.sjId][conf.floor]
        if not SJBOSS_DATA[id] then
            SJBOSS_DATA[id] = {
                id = id,
                hpPercent = 100,
                hfuben = hfuben,
                shield = 0,
                curShield = nil,
                nextShield = getNextShield(conf.id),
                belongId = 0,
                damageList = {},
                bossId = conf.bossId,
                refreshtime = 0,
            }
        end
        SJBOSS_INDEX[conf.bossId] = id
    end
    csbase.RegConnected(onSJFBConnected)
end
table.insert(InitFnTable, initGlobalData)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.SJreset = function (actor, args)
    local var = getActorVar(actor)
    var.maxPoint = SJFBCommonConfig.maxPoint
    return true
end

gmCmdHandlers.SJPrint = function (actor, args)
    local var = getActorVar(actor)
    print("maxPoint =", var.maxPoint)
    return true
end

gmCmdHandlers.SJFight = function (actor, args)
    local sjId = tonumber(args[1])
    local floor = tonumber(args[2])
    SJBossFight(actor, sjId, floor)
    return true
end

gmCmdHandlers.SJFbPrint = function (actor, args)
    utils.printTable(SJBOSS_DATA)
    utils.printTable(SJFUBEN_LIST)
    utils.printTable(SJBOSS_INDEX)
    return true
end

