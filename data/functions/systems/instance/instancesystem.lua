module("instancesystem", package.seeall)
--setfenv(1, systems.instance.instancesystem)
--require("systems.instance.instanceconfig")
--require("systems.instance.other.bossinfo")
require("systems.instance.instance")



instanceList = instanceList or {}
releaseList = releaseList or {}

function checkFubenSign(hfuben, group)
    if not FubenGroupAlias[group] or #FubenGroupAlias[group].fubensign == 0 then
        return
    end
    for i = 1, #FubenGroupAlias[group].fubensign do
        Fuben.setFubenSign(hfuben, FubenGroupAlias[group].fubensign[i])
    end
end

function createFuBen(fbid)
    local fb_data = FubenConfig[fbid]
    if not fb_data then
        print("fuben not exit, fuben_id:" .. fbid)
        return 0
    end
    local hfuben = Fuben.createFuBen(fb_data.fbid, fb_data.scenes, fb_data.group)
    checkFubenSign(hfuben, fb_data.group)
    return hfuben
end

local function createInstance(fid, hdl, ...)
    local ins = instance.new()
    if ins:init(fid, hdl, ...) then
        instanceList[hdl] = ins
        refreshmonsterapi.init(ins) --开始刷怪要写在instanceList[hdl] = ins之后，避免在onMonsterCreate时找不到ins
        return true
    end
    
    print("create Instance failed ")
    return false
end

--统一运行避免频繁调用脚本
local function onRun()
    if 0 < #releaseList then
        for _, hdl in ipairs(releaseList) do
            instanceList[hdl] = nil
        end
        releaseList = {}
    end
    
    local now_t = System.getNowTime()
    for _, ins in pairs(instanceList) do
        ins:runOne(now_t)
        bossinfo.onTimer(ins, now_t)
    end
end

--回调函数
local function beforeInstanceEnter(hdl, actor, isLogin)
    local ins = instanceList[hdl]
    if ins == nil then return end
    ins:beforeEnter(actor, isLogin)
end

local function onEnterInstance(hdl, actor, isLogin, isCw)
    local ins = instanceList[hdl]
    if ins == nil then return end
    ins:onEnter(actor, isLogin, isCw)
    bossinfo.onEnter(ins, actor)
    
    System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
    "enter fuben", tostring(ins.config.fbid), "1", "", ins.config.name, "", "", "")
end

local function onExitInstance(hdl, actor)
    local ins = instanceList[hdl]
    if ins == nil then return end
    
    ins:onExit(actor)
    bossinfo.onExit(ins, actor)
end

local function onOfflineInstance(hdl, actor)
    local ins = instanceList[hdl]
    if ins == nil then return end
    ins:onOffline(actor)
end

local function onEntityDie(hdl, et, killerHdl, killerHdl_double, killActorId, killHpper)
    local ins = instanceList[hdl]
    if ins == nil then return end
    ins:onEntityDie(et, killerHdl, killerHdl_double, killActorId, killHpper)
end

--当前游戏中没有
local function onGatherFinished(hdl, et, actor)
    local ins = instanceList[hdl]
    if ins == nil then return end
    
    return ins:onGatherFinished(et, actor)
end

local function onMonsterDamage(hdl, monster, value, attacker, ret)
    local ins = instanceList[hdl]
    if ins == nil then return end
    return insevent.onMonsterDamage(ins, monster, value, attacker, ret)
end

local function onMonsterCreate(hdl, monster)
    local ins = instanceList[hdl]
    if ins == nil then return end
    return ins:onMonsterCreate(monster)
end

local function onRoleCloneDamage(hdl, monster, value, attacker, ret)
    local ins = instanceList[hdl]
    if ins == nil then return end
    return insevent.onRoleCloneDamage(ins, monster, value, attacker, ret)
end

local function onShieldOutput(hdl, monster, value, attacker)
    local ins = instanceList[hdl]
    if ins == nil then return end
    bossinfo.onShieldOutput(ins, monster, value, attacker)
    return insevent.onShieldOutput(ins, monster, value, attacker)
end

local function onRealDamage(hdl, monster, value, attacker)
    local ins = instanceList[hdl]
    if ins == nil then return end
    return insevent.onRealDamage(ins, monster, value, attacker)
end

local function onFubenShieldUpdate(hdl, et, effectId, value)
    local ins = instanceList[hdl]
    if ins == nil then return end
    insevent.onFubenShieldUpdate(ins, et, effectId, value)
end

local function onGatherMonsterCreate(hdl, gatherMonster)
    local ins = instanceList[hdl]
    if ins == nil then return end
    insevent.onGatherMonsterCreate(ins, gatherMonster)
end

local function onGatherMonsterCheck(hdl, gatherMonster, actor)
    local ins = instanceList[hdl]
    if ins == nil then return end
    return insevent.onGatherMonsterCheck(ins, gatherMonster, actor)
end

local function onGatherMonsterUpdate(hdl, gatherMonster, actor)
    local ins = instanceList[hdl]
    if ins == nil then return end
    insevent.onGatherMonsterUpdate(ins, gatherMonster, actor)
    s2cGatherMonsterUpdate(ins, gatherMonster, actor)
end

local function onMonsterAiReset(hdl, monster)
    local ins = instanceList[hdl]
    if ins then
        bossinfo.bossHpReset(ins, monster)
        insevent.onMonsterAiReset(ins, monster)
    end
end

local function onEnerBossArea(hdl, actor, bossId)
    local ins = instanceList[hdl]
    if ins == nil then return end
    bossinfo.onEnerBossArea(ins, actor, bossId)
    insevent.onEnerBossArea(ins, actor, bossId)
end

local function onExitBossArea(hdl, actor, bossId)
    local ins = instanceList[hdl]
    if ins == nil then return end
    bossinfo.onExitBossArea(ins, actor, bossId)
    insevent.onExitBossArea(ins, actor, bossId)
end

--当前游戏中没有
local function onNextSection(hdl, sect, scenePtr)
    local ins = instanceList[hdl]
    if ins == nil then return end
    return ins:onSectionTrigger(sect, scenePtr)
end

_G.createInstance = createInstance
_G.beforeInstanceEnter = beforeInstanceEnter
_G.onInstanceEnter = onEnterInstance
_G.onInstanceExit = onExitInstance
_G.onInstanceOffline = onOfflineInstance
_G.onInstanceEntityDie = onEntityDie
_G.onInstanceRun = onRun
_G.onInstanceMonsterDamage = onMonsterDamage
_G.onInstanceMonsterCreate = onMonsterCreate
_G.onInstanceRoleCloneDamage = onRoleCloneDamage
_G.onInstanceShieldOutput = onShieldOutput
_G.onInstanceRealOutput = onRealDamage
_G.onInstanceFubenShieldUpdate = onFubenShieldUpdate
_G.onInstanceGatherMonsterCreate = onGatherMonsterCreate
_G.onInstanceGatherMonsterCheck = onGatherMonsterCheck
_G.onInstanceGatherMonsterUpdate = onGatherMonsterUpdate
_G.onInstanceMonsterAiReset = onMonsterAiReset
_G.onInstanceEnterBossArea = onEnerBossArea
_G.onInstanceExitBossArea = onExitBossArea

local function exit(actor)
    LActor.exitFuben(actor)
    local var = LActor.getDynamicVar(actor)
    if not var.instance then
        var.instance = {}
    end
    if var.instance.exitEid then
        LActor.cancelScriptEvent(actor, var.instance.exitEid)
    end
end

function DelayExit(actor)
    local var = LActor.getDynamicVar(actor)
    if not var.instance then
        var.instance = {}
    end
    var.instance.exitEid = LActor.postScriptEventLite(actor, 4000, exit)
end

--副本通用消息处理 --退出
local function onReqExit(actor, packet)
    --关于退出时血量处理，1.要添加Actor:IsDeath 2.要确认什么时候恢复
    --[[if LActor.isDeath(actor) then
LActor.relive(actor)
local maxhp = LActor.getHpMax(actor)
LActor.setHp(actor, maxhp)
end
--]]
    --主动退出副本，如果副本不是永久副本，那就马上清理它
    local hfuben = LActor.getFubenHandle(actor)
    local ins = instancesystem.getInsByHdl(hfuben)
    if ins then
        local conf = FubenConfig[ins.id]
        if conf.totalTime > 0 and conf.isPublic == 0 then
            ins.destroy_time = System.getNowTime() + 1 --清理时间设为1秒后
        end
    end
    
    exit(actor)
end

--领取副本奖励(已经无奖励可领，仅触发事件)
local function onReqInsReward(actor, packet)
    local hfuben = LActor.getFubenHandle(actor)
    local ins = instancesystem.getInsByHdl(hfuben)
    if ins == nil or ins.is_end == false then
        return
    end
    --ins:giveRewards(actor)
    insevent.onGetRewards(ins, actor)
end

--复活
local function onReborn(actor, packet)
    local rebornType = LDataPack.readByte(packet)
    if rebornType <= RebornType_None or rebornType >= RebornType_Max then return end
    --随机复活不用处理
    if rebornType == RebornType_Random then return end
    --阵营复活也不用处理
    if rebornType == RebornType_Camp then return end
    
    local hfuben = LActor.getFubenHandle(actor)
    local ins = instancesystem.getInsByHdl(hfuben)
    if ins == nil or ins.is_end == true then
        return
    end
    
    if not ins:isInRebornMap(actor) then return end
    
    local conf = FubenConfig[ins.id]
    if not conf then return end
    local sceneId = conf.scenes[1]
    if not sceneId then return end
    local sceneConf = ScenesConfig[sceneId]
    if not sceneConf then return end
    
    local reborn = sceneConf.reborn
    local rebornCount = #reborn
    if rebornCount == 0 then return end
    local useConf = nil
    for i = 1, rebornCount do
        local oneReborn = reborn[i]
        if rebornType == oneReborn.type then
            useConf = oneReborn
            break
        end
    end
    
    if useConf == nil then return end
    
    if not actoritem.checkItems(actor, useConf.costitems) then
        return
    end
    
    actoritem.reduceItems(actor, useConf.costitems, "ins reborn")
    
    ins:cancelReborn(actor)
    
    if rebornType == RebornType_InSitu then
        --原地复活
        LActor.reborn(actor)
    end
end

local p = Protocol
netmsgdispatcher.reg(p.CMD_AllFuben, p.cFubenCmd_InsQuit, onReqExit)
netmsgdispatcher.reg(p.CMD_AllFuben, p.cFubenCmd_InsGetReward, onReqInsReward)
netmsgdispatcher.reg(p.CMD_AllFuben, p.cFubenCmd_InsReborn, onReborn)


--外部其他接口回调
function setInsRewards(ins, actor, rewards)
    ins:setRewards(actor, rewards)
    -- ins:notifyRewards(actor)
end

function releaseInstance(hdl)
    local fb = Fuben.getFubenPtr(hdl)
    if fb == nil then return end
    --print("release fb".. hdl)
    table.insert(releaseList, hdl)
    --通知c++端清理副本
    Fuben.releaseInstance(fb)
end

--获取lua副本对象
function getInsByHdl(fhdl)
    --local fb = Fuben.getFubenPtr(fhdl)
    --if fb == nil then return nil end
    return instanceList[fhdl]
end

function getIns(fb)
    local hdl = Fuben.getFubenHandle(fb)
    return instanceList[hdl]
end

function getActorIns(actor)
    local hdl = LActor.getFubenHandle(actor)
    return instanceList[hdl]
end

--副本扫荡奖励 通知前端
function onSendSaodangAwards(actor, fubenGroup, exp, rewards)
    local isDouble = 0
    if subactivity12.checkIsStart() then
        isDouble = 1
    end
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_SaodangAwards)
    if npack == nil then return end
    local count = 0
    local items = {}
    for k, v in ipairs(rewards) do
        if not items[v.id] then count = count + 1 end
        items[v.id] = (items[v.id] or 0) + v.count
    end
    
    LDataPack.writeInt(npack, fubenGroup)
    LDataPack.writeShort(npack, count) --物品数量
    for k, v in pairs(items) do
        LDataPack.writeInt(npack, 0)
        LDataPack.writeInt(npack, k)
        LDataPack.writeDouble(npack, v)
        LDataPack.writeByte(npack, isDouble)
    end
    LDataPack.flush(npack)
end

--副本内容展示
function exhibitionFuben(actor, exhibit)
    if exhibit.id and exhibit.count then
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_InsExhibit)
        if npack == nil then return end
        LDataPack.writeInt(npack, exhibit.id)
        LDataPack.writeDouble(npack, math.floor(exhibit.count))
        LDataPack.flush(npack)
    end
end

--护盾信息
function s2cShieldInfo(hfuben, tp, shield, maxShield, actor, x, y)
    if not hfuben then return end
    local npack
    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_InsShield)
    else
        npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
        LDataPack.writeByte(npack, Protocol.sFubenCmd_InsShield)
    end
    
    LDataPack.writeByte(npack, tp or 0)
    LDataPack.writeInt(npack, shield)
    LDataPack.writeInt(npack, maxShield)
    if actor then
        LDataPack.flush(npack)
    else
        Fuben.sendData(hfuben, npack, x or 0, y or 0)
    end
end

--发送归属者信息
function s2cBelongData(actor, oldBelong, newBelong, hfuben, x, y)
    local npack = nil
    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_InsBelong)
    else
        npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
        LDataPack.writeByte(npack, Protocol.sFubenCmd_InsBelong)
    end
    
    --新归属者
    local hdl = 0 --玩家handle
    local newName = ""
    local job = 0
    local hp = 0
    local maxHp = 0
    local serverid = 0
    if newBelong then
        hdl = LActor.getHandle(newBelong)
        local belongId = LActor.getActorId(newBelong)
        local hf = LActor.getFubenHandle(newBelong)
        local ins = instancesystem.getInsByHdl(hf)
        newName = LActor.getActorName(belongId)
        job = LActor.getActorJob(belongId)
        local role = LActor.getRole(newBelong)
        hp = LActor.getHp(role)
        maxHp = LActor.getHpMax(role)
    end
    LDataPack.writeDouble(npack, hdl)
    
    --上一任归属者
    local ohdl = 0
    local oldName = ""
    if oldBelong then
        ohdl = LActor.getHandle(oldBelong)
        local actorId = LActor.getActorId(oldBelong)
        oldName = LActor.getActorName(actorId)
    end
    LDataPack.writeDouble(npack, ohdl)
    LDataPack.writeString(npack, oldName)
    LDataPack.writeString(npack, newName)
    LDataPack.writeChar(npack, job)
    LDataPack.writeDouble(npack, hp)
    LDataPack.writeDouble(npack, maxHp)
    LDataPack.writeInt(npack, serverid)
    
    if actor then
        LDataPack.flush(npack)
    else
        Fuben.sendData(hfuben, npack, x or 0, y or 0)
    end
end

--发送采集归属者信息
function s2cGatherBelongData(actor, oldBelong, newBelong, hfuben, x, y)
    local npack = nil
    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_InsGatherBelong)
    else
        npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
        LDataPack.writeByte(npack, Protocol.sFubenCmd_InsGatherBelong)
    end
    
    --新归属者
    local hdl = 0 --玩家handle
    local newName = ""
    local job = 0
    local hp = 0
    local maxHp = 0
    local serverid = 0
    if newBelong then
        hdl = LActor.getHandle(newBelong)
        local belongId = LActor.getActorId(newBelong)
        local hf = LActor.getFubenHandle(newBelong)
        local ins = instancesystem.getInsByHdl(hf)
        newName = LActor.getActorName(belongId)
        job = LActor.getActorJob(belongId)
        local role = LActor.getRole(newBelong)
        hp = LActor.getHp(role)
        maxHp = LActor.getHpMax(role)
    end
    LDataPack.writeDouble(npack, hdl)
    
    --上一任归属者
    local ohdl = 0
    local oldName = ""
    if oldBelong then
        ohdl = LActor.getHandle(oldBelong)
        local actorId = LActor.getActorId(oldBelong)
        oldName = LActor.getActorName(actorId)
    end
    LDataPack.writeDouble(npack, ohdl)
    LDataPack.writeString(npack, oldName)
    LDataPack.writeString(npack, newName)
    LDataPack.writeChar(npack, job)
    LDataPack.writeDouble(npack, hp)
    LDataPack.writeDouble(npack, maxHp)
    LDataPack.writeInt(npack, serverid)
    
    if actor then
        LDataPack.flush(npack)
    else
        Fuben.sendData(hfuben, npack, x or 0, y or 0)
    end
end

--为副本内的攻击者清除归属者列表
function s2cBelongListClear(hfuben, x, y)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
    LDataPack.writeByte(npack, Protocol.sFubenCmd_InsAttackList)
    if nil == npack then return end
    LDataPack.writeUInt(npack, 0)
    Fuben.sendData(hfuben, npack, x or 0, y or 0)
end

--战斗开始倒计时
function s2cFightCountDown(actor, countDown)
    local fbid = LActor.getFubenId(actor)
    local conf = FubenConfig[fbid]
    if not conf then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_Countdown)
    if pack == nil then return end
    LDataPack.writeInt(pack, conf.group)
    LDataPack.writeInt(pack, countDown) --倒计时
    LDataPack.flush(pack)
end

function s2cGatherMonsterUpdate(ins, monster, actor)
    local status, gather_tick, wait_tick = LActor.getGatherMonsterInfo(monster)
    local monsterhandle = LActor.getHandle(monster)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_Base)
    LDataPack.writeByte(npack, Protocol.sBaseCmd_GatherEntityStatus)
    LDataPack.writeDouble(npack, monsterhandle)
    LDataPack.writeChar(npack, status)
    LDataPack.writeInt(npack, status == 2 and gather_tick or 0)
    LDataPack.writeDouble(npack, actor and LActor.getHandle(actor) or 0)
    Fuben.sendData(ins.handle, npack)
end

