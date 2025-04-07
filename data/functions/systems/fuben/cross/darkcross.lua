-- 跨服暗黑神殿
module("darkcross", package.seeall)

DARKCROSS_DATA = DARKCROSS_DATA or {}
local function getdarkData()
    return DARKCROSS_DATA
end

function getVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.dark then
        var.dark = {}
        var.dark.remind_list = {} -- 提醒或自动挑战
        var.dark.challengeCd = 0
    end
    if not var.dark.freetimes then var.dark.freetimes = 0 end
    if not var.dark.buytimes then var.dark.buytimes = 0 end
    return var.dark
end

function addDrakTimes(actor, count)
    local var = getVar(actor)
    local num = var.buytimes + count
    var.buytimes = num
    s2cBelongTimes(actor)
end

local function getBossData(id)
    return DARKCROSS_DATA[id]
end

local function getConfigBybossId(bossId)
    for _, v in ipairs(DarkFubenConfig) do
        if v.bossId == bossId then
            return v
        end
    end
end

--求下一个护盾
local function getNextShield(id, hp)
    if nil == hp then hp = 101 end
    
    local conf = DarkFubenConfig[id]
    if nil == conf then return nil end
    for _, s in ipairs(conf.shield) do
        if s.hp < hp then
            return s
        end
    end
end

local function getMonsterName(bossId)
    if MonstersConfig[bossId] then
        return tostring(MonstersConfig[bossId].name)
    end
    return "nil"
end

--清空归属者
local function clearBelongInfo(ins, actor, bossData)
    if LActor.getActorId(actor) == bossData.belongId then
        local x, y = LActor.getEntityScenePos(actor)
        instancesystem.s2cBelongListClear(bossData.hfuben, x, y)
        bossData.belongId = 0
        onBelongChange(bossData, actor, nil, x, y)
        return true
    end
    return false
end

--归属者改变处理
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

--重置副本，如果boss死了就创建新副本，如果没死就满血
local function refreshBoss(_, id)
    local bossData = getBossData(id)
    local ins = instancesystem.getInsByHdl(bossData.hfuben)
    local handle = ins.scene_list[1]
    -- local scene = Fuben.getScenePtr(handle)
    local refreshConf = RefreshMonsters[ins.config.refreshMonster]
    local position = refreshConf.position[DarkFubenConfig[bossData.id].index]
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
    
    sendServerBossInfo(id)
end

--护盾结束
function finishShield(_, bossData)
    if bossData.curShield == nil then
        return
    end
    
    bossData.shieldEid = nil
    bossData.shield = 0
    local x, y = LActor.getEntityScenePos(bossData.monster)
    -- LActor.setInvincible(bossData.monster, false)
    instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, bossData.curShield.shield, nil, x, y)
end

-------------------------------------------------------------------------------------------------------

local function sendResult(actor, res, belongInfo, rewards)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsDarkBoss_Result)
    if npack == nil then return end
    LDataPack.writeChar(npack, res)
    LDataPack.writeInt(npack, belongInfo.id)
    LDataPack.writeString(npack, belongInfo.name)
    LDataPack.writeChar(npack, belongInfo.job)
    if rewards then
        LDataPack.writeChar(npack, #rewards)
        for _, t in ipairs(rewards) do
            LDataPack.writeInt(npack, t.type)
            LDataPack.writeInt(npack, t.id)
            LDataPack.writeInt(npack, t.count)
        end
    else
        LDataPack.writeChar(npack, 0)
    end
    LDataPack.flush(npack)
end

local function killTomb(_, hdl)
    LActor.destroyEntity(hdl)
end

local function broadcastBossInfo(fbhdl, id, endtime, hpPercent)
    local npack = LDataPack.allocPacket()
    if npack then
        LDataPack.writeByte(npack, Protocol.CMD_Cross)
        LDataPack.writeByte(npack, Protocol.sCsDarkBoss_BossInfo)
        LDataPack.writeChar(npack, id)
        LDataPack.writeChar(npack, hpPercent or 0)
        LDataPack.writeInt(npack, endtime)
        Fuben.sendData(fbhdl, npack)
    end
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
        print('Darkcross.onMonsterAiReset config==nil bossId=' .. bossId)
        return
    end
    local index = config.id
    local bossData = getBossData(index)
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

function getBossPos(ins, bossId)
    if ins.data.bossPos then
        local t = ins.data.bossPos[bossId]
        return t.x, t.y
    end
    return 0, 0
end

local function onBossDie(ins, monster, killHdl)
    local bossId = Fuben.getMonsterId(monster)
    local config = getConfigBybossId(bossId)
    if config == nil then
        print('Darkcross.onBossDie config==nil bossId=' .. bossId)
        return
    end
    
    local index = config.id
    local bossData = getBossData(index)
    local x, y = LActor.getEntityScenePos(monster)
    
    local belongInfo = {
        name = "",
        job = 0,
        id = 0,
    }
    local belong = LActor.getActorById(bossData.belongId)
    if belong then
        belongInfo.name = LActor.getActorName(bossData.belongId)
        belongInfo.job = LActor.getJob(belong)
        belongInfo.id = bossData.belongId
    end
    
    for actorId in pairs(bossData.damageList) do
        if actorId == bossData.belongId then --归属者
            local belong = LActor.getActorById(bossData.belongId)
            local rewards = drop.dropGroup(config.belongDrop)
            if halosystem.isBuyHalo(belong) then
                local haloRewards = utils.table_clone(config.haloRewards)
                for _, reward in ipairs(haloRewards) do
                    table.insert(rewards, reward)
                end
            end
            local posX, posY = LActor.getEntityScenePoint(monster)
            
            for _, v in ipairs(rewards) do
                local item_conf = ItemConfig[v.id]
                if item_conf and item_conf.type == 54 then
                    local arg1 = actorcommon.getVipShow(LActor.getActorById(actorId))
                    local arg2 = LActor.getActorName(actorId)
                    local arg3 = config.scenename
                    local arg4 = getMonsterName(config.bossId)
                    local arg5 = utils.getItemName(v.id)
                    noticesystem.broadCastCrossNotice(noticesystem.NTP.smbossdrop, arg1, arg2, arg3, arg4, arg5)
                    noticesystem.broadCastNotice(noticesystem.NTP.smbossdrop, arg1, arg2, arg3, arg4, arg5)
                end
            end
            
            ins:addDropBagItem(belong, rewards, 10, posX, posY, true)
            local var = getVar(belong)
            if var.freetimes > 0 then
                var.freetimes = var.freetimes - 1
            else
                var.buytimes = var.buytimes - 1
            end
            s2cBelongTimes(belong)
            LActor.setCamp(belong, CampType_Normal)
            sendResult(belong, 1, belongInfo, rewards)
            
            actorevent.onEvent(belong, aeDarkBossKill, 1)
        else
            -- 非归属结算
            local actor = LActor.getActorById(actorId)
            if actor then
                LActor.setCamp(actor, CampType_Normal)
                sendResult(actor, 0, belongInfo)
            end
        end
    end
    instancesystem.s2cBelongData(nil, nil, nil, bossData.hfuben, x, y) ---归属者信息
    --boss信息重置
    bossData.hpPercent = 0
    
    local now = System.getNowTime()
    local Y, M, D, H, M, S = System.timeDecode(now)
    local refresh_endtime = now + (59 - M) * 60 + (60 - S)
    bossData.refreshtime = refresh_endtime
    bossData.damageList = {}
    clearBelongInfo(ins, belong, bossData) --清除归属者
    bossData.belongId = 0
    
    -- 更新副本玩家
    broadcastBossInfo(ins.handle, index, refresh_endtime, bossData.hpPercent)
    -- 更新普通服
    sendServerBossInfo(index)
end

function onEnerBossArea(ins, actor, bossId)
    local config = getConfigBybossId(bossId)
    local bossData = getBossData(config.id)
    -- local actorId = LActor.getActorId(actor)
    
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

local function onEnterFb(ins, actor)
    LActor.setCamp(actor, CampType_Normal)--设置阵营为普通模式
end

local function onBossDamage(ins, monster, value, attacker, res)
    local bossId = Fuben.getMonsterId(monster)
    local config = getConfigBybossId(bossId)
    if config == nil then
        print('Darkcross.onBossDamage config==nil bossId=' .. bossId)
        return
    end
    
    local index = config.id
    -- local bossId = Fuben.getMonsterId(monster)
    local bossData = getBossData(index)
    local actor = LActor.getActor(attacker)
    -- local var = getVar(actor)
    local actorId = LActor.getActorId(actor)
    
    bossData.damageList[actorId] = bossData.damageList[actorId] or 0
    
    local var = getVar(actor)
    --第一下攻击者为boss归属者
    if 0 == bossData.belongId and bossData.hfuben == LActor.getFubenHandle(attacker) and actor and (var.freetimes > 0 or var.buytimes > 0) then
        if LActor.isDeath(actor) == false and bossId == Fuben.getBossIdInArea(actor) then
            local oldBelong = LActor.getActorById(bossData.belongId)
            bossData.belongId = LActor.getActorId(actor)
            local x, y = LActor.getEntityScenePos(monster)
            onBelongChange(bossData, oldBelong, actor, x, y)
            --使怪物攻击归属者
            --LActor.setAITarget(monster, LActor.getBattleLiveByOrder(actor))
        end
    end
    
    --更新boss血量信息
    local oldhp = LActor.getHp(monster)
    if oldhp <= 0 then return end
    
    local hp = oldhp - value
    if hp < 0 then hp = 0 end
    
    hp = hp / LActor.getHpMax(monster) * 100
    local isUdate = bossData.hpPercent ~= hp
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
    if isUdate then
        updateDarkBlood(index)
    end
end

local function onExitFb(ins, actor)
    local var = getVar(actor)
    var.challengeCd = System.getNowTime() + DarkCommonConfig.entercd
    local bossId = Fuben.getBossIdInArea(actor)
    if bossId == 0 then return end
    onExitBossArea(ins, actor, bossId)
end

function onExitBossArea(ins, actor, bossId)
    if not ins then return end
    local config = getConfigBybossId(bossId)
    -- local data = getVar(actor)
    
    LActor.setCamp(actor, CampType_Normal) --退出变回正常阵营，此行影响s2cAttackList里的攻击者数量
    local bossData = getBossData(config.id)
    local actorId = LActor.getActorId(actor)
    bossData.damageList[actorId] = nil
    
    local isBelong = clearBelongInfo(ins, actor, bossData) --清除归属者
    local x, y = getBossPos(ins, bossId)
    instancesystem.s2cBelongData(actor, nil, nil, bossData.hfuben, x, y)
    
    -- local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SMBossDisappear)
    -- LDataPack.writeByte(pack, config.id)
    -- LDataPack.flush(pack)
    
    -- -- 尝试转移归属
    -- if isBelong then
    --     Fuben.bossAttackActorInArea(bossId, actor)
    -- end
    -- boss面板消失
end

local function onOffline(ins, actor)
    -- local var = getVar(actor)
    local bossId = Fuben.getBossIdInArea(actor)
    if bossId == 0 then return end
    onExitBossArea(ins, actor, bossId)
end

local function onActorDie(ins, actor, killHdl)
    local et = LActor.getEntity(killHdl)
    if not et then return end
    local attacker = LActor.getEntityType(et)
    local bossId = Fuben.getBossIdInArea(actor)
    local config = getConfigBybossId(bossId)
    if not config then return end
    local bossData = getBossData(config.id)
    if nil == bossData then return end
    local x, y = LActor.getEntityScenePos(actor)
    
    if LActor.getActorId(actor) == bossData.belongId then
        instancesystem.s2cBelongListClear(bossData.hfuben, x, y)
        --归属者被玩家打死，该玩家是新归属者
        if actorcommon.isActor(attacker) then
            local newactor = LActor.getActor(et)
            local var = getVar(newactor)
            if var.freetimes > 0 or var.buytimes > 0 then
                bossData.belongId = LActor.getActorId(newactor)
            else
                bossData.belongId = 0
            end
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
            --广播归属者信息
            onBelongChange(bossData, actor, nil, x, y)
        end
    else
        --不是归属者,死亡时候切换回正常阵营
        if LActor.getCamp(actor) == CampType_Attack then
            LActor.setCamp(actor, CampType_Normal)
        end
    end
end

function s2cBelongTimes(actor)
    local var = getVar(actor)
    local count = var.freetimes + var.buytimes
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsDarkBoss_BelongTimes)
    if npack == nil then return end
    LDataPack.writeShort(npack, count)
    LDataPack.flush(npack)
end

--注册事件
function onNewDay(actor, login)
    local var = getVar(actor)
    local count = var.freetimes
    local freetimes = DarkCommonConfig.freetimes
    count = math.min(count + freetimes, freetimes * 2)
    
    var.freetimes = count
    if not login then
        s2cBelongTimes(actor)
    end
end

-- id：配置的id, 0 for all
function sendServerBossInfo(id, serverId)
    local list = {}
    if id == 0 then
        for _, info in pairs(DARKCROSS_DATA) do
            table.insert(list, info)
        end
    else
        local info = DARKCROSS_DATA[id]
        if info then
            table.insert(list, info)
        else
            assert(id, debug.traceback())
        end
    end
    
    if #list <= 0 then
        return
    end
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCDarkCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCdarkCmd_SendDarkBossInfo)
    LDataPack.writeShort(npack, #list)
    for _, info in ipairs(list) do
        LDataPack.writeInt(npack, info.id)
        LDataPack.writeInt(npack, info.refreshtime)
        LDataPack.writeInt64(npack, info.hfuben)
        LDataPack.writeChar(npack, info.hpPercent)
    end
    System.sendPacketToAllGameClient(npack, serverId or 0)
end

local function onServerConnect(serverId, serverType)
    print('Darkcross.onServerConnect serverId=' .. serverId .. ' serverType=' .. serverType)
    sendServerBossInfo(0, serverId) -- 0 for all
end

function updateDarkBlood(id)
    if not System.isBattleSrv() then return end
    local bossData = getBossData(id)
    if not bossData then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCDarkCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCdarkCmd_UpdateDarkBlood)
    
    LDataPack.writeByte(pack, id)
    LDataPack.writeByte(pack, bossData.hpPercent)
    
    System.sendPacketToAllGameClient(pack, 0)
end

function gmRefreshBoss(id)
    print('Darkcross.gmRefreshBoss id=' .. tostring(id))
    refreshBoss(nil, id)
end

--boss刷新
function flushDarkBoss()
    if not System.isBattleSrv() then return end
    for id, conf in pairs(DarkFubenConfig) do
        local bossData = getBossData(id)
        if bossData.hpPercent <= 0 then
            refreshBoss(nil, id)
        end
    end
end

local function initGlobalData()
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    if not System.isBattleSrv() then return end
    local fb_list = {}
    for _, conf in pairs(DarkFubenConfig) do
        if fb_list[conf.fbId] == nil then
            fb_list[conf.fbId] = true
            insevent.registerInstanceMonsterDie(conf.fbId, onBossDie)
            insevent.registerInstanceEnter(conf.fbId, onEnterFb)
            insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
            insevent.registerInstanceExit(conf.fbId, onExitFb)
            insevent.registerInstanceOffline(conf.fbId, onOffline)
            insevent.registerInstanceActorDie(conf.fbId, onActorDie)
            insevent.registerInstanceMonsterCreate(conf.fbId, onBossCreate)
            insevent.registerInstanceMonsterAiReset(conf.fbId, onMonsterAiReset)
            insevent.registerInstanceEnerBossArea(conf.fbId, onEnerBossArea)
            insevent.registerInstanceExitBossArea(conf.fbId, onExitBossArea)
        end
    end
    
    csbase.RegConnected(onServerConnect)
    
    if next(DARKCROSS_DATA) then return end
    local hfubenlist = {}
    for id, conf in pairs(DarkFubenConfig) do
        if not DARKCROSS_DATA[id] then
            if not hfubenlist[conf.stage] then
                hfubenlist[conf.stage] = instancesystem.createFuBen(conf.fbId)
            end
            local hfuben = hfubenlist[conf.stage]
            DARKCROSS_DATA[id] = {
                id = conf.id,
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
            
            local ins = instancesystem.getInsByHdl(hfuben)
            if ins then
                ins.boss_mult = true -- 多个bossinfo
                if not ins.data.darkindex then
                    ins.data.darkindex = {}
                    ins.data.smbossid = {}
                end
                ins.data.darkindex[#ins.data.darkindex + 1] = id
                ins.data.smbossid[#ins.data.smbossid + 1] = conf.bossId
            end
        end
    end
end
table.insert(InitFnTable, initGlobalData)

_G.flushDarkBoss = flushDarkBoss

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.fulshDark = function (actor, args)
    local id = tonumber(args[1])
    refreshBoss(nil, id)
    return true
end
