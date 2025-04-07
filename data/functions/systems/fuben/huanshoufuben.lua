-- 无尽岛
module("huanshoufuben", package.seeall)

local function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.hsfb then
        var.hsfb = {
            idx = getHSBossFubenIndex(actor),
            refreshTimes = {},
            reminds = {},
        }
    end
    return var.hsfb
end

function getHSBossFubenIndex(actor)
    local zslevel = LActor.getZhuansheng(actor)
    local idx = 1
    for i, conf in ipairs(HuanshouSingleFubenConfig) do
        if conf.zsLevel <= zslevel then
            idx = i
        else
            break
        end
    end
    return idx
end

local function refreshBoss(actor, idx)
    local var = getActorVar(actor)
    if not var then return end
    var.refreshTimes[idx] = 0
    s2cHSBOSSUpdate(actor, idx)
    
    local ins = instancesystem.getActorIns(actor)
    if not ins then return end
    --if ins.data.idx ~= var.idx then return end
    if ins.config.group ~= HuanshouBossCommonConfig.groupId then return end
    local monsterId = HuanshouSingleFubenConfig[var.idx].refreshMonsters[idx]
    
    local bossInfo = ins.data.bossInfo
    if not bossInfo then return end
    local bInfo = bossInfo[monsterId]
    if not bInfo then return end
    
    bInfo.refreshtime = 0
    local refreshConfig = HuanshouSingleBossConfig[bInfo.id]
    if refreshConfig then
        Fuben.createMonster(ins.scene_list[1], bInfo.id, refreshConfig.pos[1], refreshConfig.pos[2])
    end
    
    if bInfo.tombHandle then
        LActor.destroyEntity(bInfo.tombHandle)
    end
end

function hsBossFight(actor)
    local var = getActorVar(actor)
    local config = HuanshouSingleFubenConfig[var.idx]
    if not config then return end
    
    local fbHandle = instancesystem.createFuBen(config.fbId)
    if not fbHandle or fbHandle == 0 then return end
    
    local ins = instancesystem.getInsByHdl(fbHandle)
    ins.data.idx = var.idx
    ins.data.bossInfo = {}
    local bossInfo = ins.data.bossInfo
    for index, monsterId in ipairs(config.refreshMonsters) do
        bossInfo[monsterId] = {
            index = index,
            id = monsterId,
            refreshTime = var.refreshTimes[index] or 0,
        }
    end
    
    local x, y = utils.getSceneEnterCoor(config.fbId)
    LActor.enterFuBen(actor, fbHandle, 0, x, y)
end

function hsBOSSRemind(actor, index)
    local var = getActorVar(actor)
    local idx = var.idx
    local config = HuanshouSingleFubenConfig[idx]
    if not config then return end
    if not config.refreshMonsters[index] then return end
    local status = var.reminds[index] or 1
    status = (status + 1) % 2
    var.reminds[index] = status
    
    s2cHSBOSSRemind(actor, index, status)
end

function checkHSBossRefreshTime(actor)
    local var = getActorVar(actor)
    if not var then return end
    local config = HuanshouSingleFubenConfig[var.idx]
    if not config then return end
    
    local now = System.getNowTime()
    for index in ipairs(config.refreshMonsters) do
        local refreshTime = var.refreshTimes[index] or 0
        if refreshTime > 0 then
            local costTime = refreshTime - now
            if costTime <= 0 then
                refreshBoss(actor, index)
            else
                LActor.postScriptEventLite(actor, costTime * 1000, refreshBoss, index)
            end
        end
    end
end

----------------------------------------------------------------------------------
--事件处理
local function onLogin(actor)
    s2cHSBOSSInfo(actor)
    checkHSBossRefreshTime(actor)
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    if not var then return end
    
    local idx = getHSBossFubenIndex(actor)
    if idx > var.idx then
        var.idx = idx
        --如果玩家在副本中,则踢出副本
        local ins = instancesystem.getActorIns(actor)
        if ins and ins.config.group == HuanshouBossCommonConfig.groupId then
            LActor.exitFuben(actor)
        end
    end
    if not login then
        s2cHSBOSSInfo(actor)
    end
end

local function onEnterBefore(ins, actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local config = HuanshouSingleFubenConfig[var.idx]
    if not config then return end
    
    local monIdList = {}
    for _, monsterId in pairs(config.refreshMonsters) do
        table.insert(monIdList, monsterId)
    end
    table.insert(monIdList, HuanshouBossCommonConfig.tombMonId)
    slim.s2cMonsterConfig(actor, monIdList)
end

local function onEnterFb(ins, actor)
    local bossInfo = ins.data.bossInfo
    if not bossInfo then return end
    
    for _, info in pairs(bossInfo) do
        local refreshConfig = HuanshouSingleBossConfig[info.id]
        if info.refreshTime <= 0 then
            if refreshConfig then
                Fuben.createMonster(ins.scene_list[1], info.id, refreshConfig.pos[1], refreshConfig.pos[2])
            end
        else
            if refreshConfig then
                local tomb = Fuben.createMonster(ins.scene_list[1], HuanshouBossCommonConfig.tombMonId, refreshConfig.pos[1], refreshConfig.pos[2])
                if tomb then
                    info.tombHandle = LActor.getRealHandle(tomb)
                end
            end
        end
    end
end

local function onOffline(ins, actor)
    LActor.exitFuben(actor)
end

local function onBossDie(ins, monster, killHdl)
    local bossInfo = ins.data.bossInfo
    if not bossInfo then return end
    
    local actor = ins:getActorList()[1]
    if not actor then return end
    
    local bossId = Fuben.getMonsterId(monster)
    local bInfo = bossInfo[bossId]
    if not bInfo then return end
    local refreshConfig = HuanshouSingleBossConfig[bossId]
    if not refreshConfig then return end
    
    local var = getActorVar(actor)
    if not var then return end
    
    local refreshTime = System.getNowTime() + refreshConfig.refreshTime
    var.refreshTimes[bInfo.index] = refreshTime
    bInfo.refreshTime = refreshTime
    
    local rewards = drop.dropGroup(refreshConfig.dropId)
    actoritem.addItemsByMail(actor, rewards, "huanshou single boss rewards")
    LActor.postScriptEventLite(actor, refreshConfig.refreshTime * 1000, refreshBoss, bInfo.index)
    
    local tomb = Fuben.createMonster(ins.scene_list[1], HuanshouBossCommonConfig.tombMonId, refreshConfig.pos[1], refreshConfig.pos[2])
    if tomb then
        bInfo.tombHandle = LActor.getRealHandle(tomb)
    end
    s2cHSBOSSReuslt(actor, rewards)
    s2cHSBOSSUpdate(actor, bInfo.index)
end

-------------------------------------------------------------------------------------------------------
--协议处理
--87-75 无尽岛-基础信息
function s2cHSBOSSInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local config = HuanshouSingleFubenConfig[var.idx]
    if not config then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.s2cHSBOSS_Info)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, var.idx)
    LDataPack.writeChar(pack, #config.refreshMonsters)
    for index, monsterId in ipairs(config.refreshMonsters) do
        LDataPack.writeChar(pack, index)
        LDataPack.writeInt(pack, monsterId)
        local monsterConfig = MonstersConfig[monsterId]
        LDataPack.writeString(pack, monsterConfig.name)
        LDataPack.writeString(pack, monsterConfig.head)
        LDataPack.writeInt(pack, var.refreshTimes[index] or 0)
        LDataPack.writeChar(pack, var.reminds[index] or 1)
    end
    LDataPack.flush(pack)
end

--87-76 无尽岛-请求挑战
local function c2sHSBOSSFight(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.huanshoufb) then return end
    hsBossFight(actor)
end

--87-76 无尽岛-更新单个boss信息
function s2cHSBOSSUpdate(actor, index)
    local var = getActorVar(actor)
    if not var then return end
    
    local config = HuanshouSingleFubenConfig[var.idx]
    if not config then return end
    local monsterId = config.refreshMonsters[index]
    local monsterConfig = MonstersConfig[monsterId]
    if not monsterConfig then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.s2cHSBOSS_Update)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, index)
    LDataPack.writeInt(pack, monsterId)
    LDataPack.writeString(pack, monsterConfig.name)
    LDataPack.writeString(pack, monsterConfig.head)
    LDataPack.writeInt(pack, var.refreshTimes[index] or 0)
    LDataPack.writeInt(pack, var.reminds[index] or 1)
    
    LDataPack.flush(pack)
end

--87-77 无尽岛-请求关注
local function c2sHSBOSSRemind(actor, pack)
    local idx = LDataPack.readChar(pack)
    hsBOSSRemind(actor, idx)
end

--87-77 无尽岛-返回关注
function s2cHSBOSSRemind(actor, index, status)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.s2sHSBOSS_Remind)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, index)
    LDataPack.writeChar(pack, status)
    LDataPack.flush(pack)
end

--87-78 无尽岛-战斗结算
function s2cHSBOSSReuslt(actor, items)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.s2sHSBOSS_Result)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, #items)
    for _, v in ipairs(items) do
        LDataPack.writeInt(pack, v.id)
        LDataPack.writeInt(pack, v.count)
    end
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--初始化
local function initGlobalData()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    if System.isCrossWarSrv() then return end
    
    netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.c2sHSBOSS_Fight, c2sHSBOSSFight)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.c2sHSBOSS_Remind, c2sHSBOSSRemind)
    
    for _, conf in ipairs(HuanshouSingleFubenConfig) do
        local fbId = conf.fbId
        insevent.registerInstanceEnterBefore(fbId, onEnterBefore)
        insevent.registerInstanceEnter(fbId, onEnterFb)
        insevent.registerInstanceOffline(fbId, onOffline)
        insevent.registerInstanceMonsterDie(fbId, onBossDie)
    end
end
table.insert(InitFnTable, initGlobalData)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.HSBOSSFight = function (actor, args)
    hsBossFight(actor)
    return true
end

gmCmdHandlers.hsfbprint = function (actor, args)
    print("now =", System.getNowTime())
    local fbhl = LActor.getFubenHandle(actor)
    local ins = instancesystem.getInsByHdl(fbhl)
    if ins then
        utils.printTable(ins.data)
    end
    return true
end

gmCmdHandlers.hsfbrefresh = function (actor, args)
    local index = tonumber(args[1])
    if not index then
        local var = getActorVar(actor)
        if not var then return end
        local config = HuanshouSingleFubenConfig[var.idx]
        if not config then return end
        
        local now = System.getNowTime()
        for i in ipairs(config.refreshMonsters) do
            local refreshTime = var.refreshTimes[i] or 0
            if refreshTime > 0 then
                refreshBoss(actor, i)
            end
        end
    else
        refreshBoss(actor, index)
    end
    return true
end

