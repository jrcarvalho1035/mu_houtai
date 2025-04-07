--主城场景副本
module("mainscenefuben", package.seeall)

local maxActorCount = 35--主城最大可容许的人数上限
local MonstersConfig = MonstersConfig
Drop_Box_Start = Drop_Box_Start or nil
BoxRefreshTime = BoxRefreshTime or 0
RefreshBoxIndex1 = RefreshBoxIndex1 or {}
RefreshBoxIndex2 = RefreshBoxIndex2 or {}

function getMainVar(isCreateEmpty)
    local var = System.getDyanmicVar()
    if not var then return end
    
    if not var.mainScene then var.mainScene = {} end--保存主城的所有副本handle
    if not var.mainSceneCount then var.mainSceneCount = 0 end--已经开启了多少个主城副本
    if isCreateEmpty then
        getEmptyFuben()
    end
    return var
end

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.dropbox then
        var.dropbox = {}
        var.dropbox.gettimes = 0
    end
    return var.dropbox
end

function getEmptyFuben()
    local var = getMainVar()
    for i = 1, var.mainSceneCount do
        if var.mainScene[i] and Fuben.getFubenPtr(var.mainScene[i]) then
            local ins = instancesystem.getInsByHdl(var.mainScene[i])
            if ins and ins.actor_list_count < maxActorCount then
                return var.mainScene[i]
            end
        end
    end
    
    --没有空位置了，就重新建一个新的主城副本
    local fbHandle = instancesystem.createFuBen(0)
    if not fbHandle or fbHandle == 0 then print("getEmptyFuben:create fb fail") return end
    
    var.mainSceneCount = var.mainSceneCount + 1
    var.mainScene[var.mainSceneCount] = fbHandle
    return fbHandle
end

function sendData(pack)
    local var = System.getDyanmicVar()
    if not var then return end
    
    if not var.mainScene then return end
    if not var.mainSceneCount or var.mainSceneCount == 0 then return end
    
    for i = 1, var.mainSceneCount do
        local fbHandle = var.mainScene[i]
        Fuben.sendData(fbHandle, pack)
    end
end

--进入主城
function enterMainScene(actor, sceneid, posX, posY)
    if not actor then return end
    if not utils.checkFuben(actor, 0) then return end
    
    local fbHandle, isnew = getEmptyFuben()
    if not fbHandle then print("enterMainScene:no main fbHandle") return end
    
    if not posX then
        posX, posY = utils.getSceneEnterCoor(0)
    end
    if isnew and Drop_Box_Start then
        refreshBoxMonster(fbHandle)
    end
    return LActor.enterFuBen(actor, fbHandle, sceneid or - 1, posX, posY)
end

function addGuajiAwards(actor)
    local var = guajifuben.getActorVar(actor)
    if not var or not var.fbId then return end
    local fbId = LActor.getFubenId(actor)
    if fbId ~= 0 then return end
    
    var.posTimes = var.posTimes + 1
    
    -- local allMonsterCount = var.all_monster_count
    local monsterList = var.monster_list
    -- if allMonsterCount <= 0 then return end
    -- local avgCount = allMonsterCount / #monsterList
    --local count = avgCount * (3/60) --3秒内的杀怪数量
    
    if #monsterList <= 0 then return end
    local index = var.posTimes % #monsterList
    if index == 0 then index = #monsterList end
    local monId = monsterList[index][1]
    local count = monsterList[index][2]
    count = count * (3 / 60) --3秒内的杀怪数量
    
    local exp = math.floor(MonstersConfig[monId].exp * (actorcommon.getDropExpRate(actor) + 1)) --策划要求在主城挂机也要额外增加0.5倍的经验（连斩）
    LActor.addExp(actor, exp, "zhucheng_guaji_"..monId, true, false, 1)
    local moneyRate = actorcommon.getDropGoldRate(actor) + 1
    local dropItems = {}
    monsterdrop.guajiDropItems(dropItems, monId, count, moneyRate)
    actoritem.addItems(actor, dropItems, "zhucheng_guaji_awards", 1) --主城挂机
    
    LActor.postScriptEventLite(actor, 3000, addGuajiAwards)
end

-- function cancelGuajiAwards(actor)
-- local var = guajifuben.getActorVar(actor)
-- if not var or not var.posEid then return end

-- LActor.cancelScriptEvent(actor, var.posEid)
-- var.posEid = nil
-- end

function sendInfo(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_DropBoxLoginInfo)
    LDataPack.writeChar(pack, DropBoxConstConfig.collecttimes - var.gettimes)
    LDataPack.flush(pack)
end

function sendMonsters(actor)
    local monIdList = {}
    table.insert(monIdList, DropBoxConstConfig.monster1)
    table.insert(monIdList, DropBoxConstConfig.monster2)
    slim.s2cMonsterConfig(actor, monIdList)
end

function onEnterBefore(ins, actor)
    if not Drop_Box_Start then return end
    sendMonsters(actor)
end

function reqEnterMainScene(actor)
    if System.isCrossWarSrv() then return end
    if not actorlogin.checkCanEnterCross(actor) then return end
    local zslevel = LActor.getZhuansheng(actor)
    if zslevel < FubenConfig[0].condition.zslevel then return end
    
    local crossId = csbase.getCrossServerId()
    if not csbase.isConnected(crossId) then return end
    LActor.loginOtherServer(actor, crossId, 1, 0, 0, 0, "cross")
    return true
end

function ehEnterFuben(ins, actor)
    --进入主城之后，定时给挂机经验
    local var = guajifuben.getActorVar(actor)
    if not var then return end
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_DropBoxActInfo)
    LDataPack.writeChar(npack, Drop_Box_Start and 1 or 0)
    LDataPack.writeShort(npack, math.max(0, DropBoxConstConfig.keeptime - (System.getNowTime() - (Drop_Box_Start or 0))))
    LDataPack.writeShort(npack, math.max(0, DropBoxConstConfig.refreshtime - (System.getNowTime() - (BoxRefreshTime or 0))))
    LDataPack.flush(npack)
    
    var.posTimes = 0
    LActor.postScriptEventLite(actor, 3000, addGuajiAwards)
    actorevent.onEvent(actor, aeInterMainscene)
    
    hefucupsystem.sendHFCupWorship(actor)
end

local function enterMainFuben(actor)
    if not System.isBattleSrv() then return end
    enterMainScene(actor)
end

function onOffline(ins, actor)
    local actorId = LActor.getActorId(actor)
    ins.actor_list[actorId] = nil
    ins.actor_list_count = ins.actor_list_count - 1
end

function refreshBoxMonster(hscene)
    local constConf = DropBoxConstConfig
    if not RefreshBoxIndex1[hscene] then
        RefreshBoxIndex1[hscene] = {}
        RefreshBoxIndex2[hscene] = {}
    end
    for k, v in ipairs(constConf.pos1) do
        local monster = Fuben.createMonster(hscene, constConf.monster1, v[1], v[2])
        RefreshBoxIndex1[hscene][k] = LActor.getHandle(monster)
    end
    for k, v in ipairs(constConf.pos2) do
        local monster = Fuben.createMonster(hscene, constConf.monster2, v[1], v[2])
        RefreshBoxIndex2[hscene][k] = LActor.getHandle(monster)
    end
    
    LActor.postScriptEventLite(nil, DropBoxConstConfig.refreshtime * 1000, refreshBoxs, hscene)
end

local function dropBoxStart()
    Drop_Box_Start = System.getNowTime()
    BoxRefreshTime = System.getNowTime()
    sendActInfo()
    if not System.isBattleSrv() then return end
    
    local list = System.getOnlineActorList()
    if list then
        for _, actor in ipairs(list) do
            sendMonsters(actor)
        end
    end
    
    local mvar = mainscenefuben.getMainVar(true)
    for i = 1, mvar.mainSceneCount do
        if mvar.mainScene[i] and Fuben.getFubenPtr(mvar.mainScene[i]) then
            local ins = instancesystem.getInsByHdl(mvar.mainScene[i])
            refreshBoxMonster(ins.scene_list[1])
        end
    end
end

function refreshBoxs(_, hscene)
    if not Drop_Box_Start then return end
    BoxRefreshTime = System.getNowTime()
    if not RefreshBoxIndex1[hscene] then
        RefreshBoxIndex1[hscene] = {}
        RefreshBoxIndex2[hscene] = {}
    end
    local constConf = DropBoxConstConfig
    for k, v in ipairs(constConf.pos1) do
        if not RefreshBoxIndex1[hscene][k] then
            local monster = Fuben.createMonster(hscene, constConf.monster1, v[1], v[2])
            RefreshBoxIndex1[hscene][k] = LActor.getHandle(monster)
        end
    end
    for k, v in ipairs(constConf.pos2) do
        if not RefreshBoxIndex2[hscene][k] then
            local monster = Fuben.createMonster(hscene, constConf.monster2, v[1], v[2])
            RefreshBoxIndex2[hscene][k] = LActor.getHandle(monster)
        end
    end
    
    sendActInfo()
    LActor.postScriptEventLite(nil, DropBoxConstConfig.refreshtime * 1000, refreshBoxs, hscene)
end

function sendActInfo()
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_AllFuben2)
    LDataPack.writeByte(npack, Protocol.sFubenCmd_DropBoxActInfo)
    LDataPack.writeChar(npack, Drop_Box_Start and 1 or 0)
    LDataPack.writeShort(npack, math.max(0, DropBoxConstConfig.keeptime - (System.getNowTime() - (Drop_Box_Start or 0))))
    LDataPack.writeShort(npack, math.max(0, DropBoxConstConfig.refreshtime - (System.getNowTime() - (BoxRefreshTime or 0))))
    System.broadcastData(npack)
end

local function dropBoxEnd()
    Drop_Box_Start = nil
    if not System.isBattleSrv() then return end
    local mvar = mainscenefuben.getMainVar()
    for i = 1, mvar.mainSceneCount do
        if mvar.mainScene[i] and Fuben.getFubenPtr(mvar.mainScene[i]) then
            local ins = instancesystem.getInsByHdl(mvar.mainScene[i])
            Fuben.clearAllGatherMonster(ins.scene_list[1])
        end
    end
    sendActInfo()
end

local function onGatherMonsterUpdate(ins, monster, actor)
    local status, gather_tick, wait_tick = LActor.getGatherMonsterInfo(monster)  
    if status ~= GatherStatusType_Finish then return end
    
    local monsterhandle = LActor.getHandle(monster)
    local hscene = LActor.getSceneHandle(actor)
    if not RefreshBoxIndex1[hscene] then
        RefreshBoxIndex1[hscene] = {}
        RefreshBoxIndex2[hscene] = {}
    end

    local ishave = false
    for k, v in pairs(RefreshBoxIndex1[hscene]) do
        if v == monsterhandle then
            RefreshBoxIndex1[hscene] [k] = nil
            ishave = true
            break
        end
    end
    if not ishave then
        for k, v in pairs(RefreshBoxIndex2[hscene]) do
            if v == monsterhandle then
                RefreshBoxIndex2[hscene][k] = nil
                break
            end
        end
    end
    
    if not actor then return end
    local var = getActorVar(actor)
    if var.gettimes >= DropBoxConstConfig.collecttimes then return end
    
    var.gettimes = var.gettimes + 1
    
    local monid = Fuben.getMonsterId(monster)
    local conf = (monid == DropBoxConstConfig.monster1) and DropBox1Config or DropBox2Config
    local zslevel = LActor.getZhuansheng(actor)
    local rewards = {}
    for k, v in ipairs(conf) do
        if v.zslevel == zslevel then
            rewards = drop.dropGroup(v.drop)
            local isopen, dropindexs = subactivity12.checkIsStart()
            if isopen then
                for j = 1, #dropindexs do
                    local rewards1 = drop.dropGroup(v.actdrop[dropindexs[j]])
                    for i = 1, #rewards1 do
                        table.insert(rewards, {type = rewards1[i].type, id = rewards1[i].id, count = rewards1[i].count})
                    end
                end
            end
            break
        end
    end
    actoritem.addItems(actor, rewards, "drop box")
    
    sendInfo(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sMainCmd_DropBoxReward)
    LDataPack.writeChar(npack, #rewards)
    for k, v in ipairs(rewards) do
        LDataPack.writeInt(npack, v.id)
        LDataPack.writeDouble(npack, v.count)
    end
    LDataPack.flush(npack)
    actorevent.onEvent(actor, aeDropBox)
end

function onLogin(actor)
    sendInfo(actor)
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_DropBoxActInfo)
    LDataPack.writeChar(npack, Drop_Box_Start and 1 or 0)
    LDataPack.writeShort(npack, math.max(0, DropBoxConstConfig.keeptime - (System.getNowTime() - (Drop_Box_Start or 0))))
    LDataPack.writeShort(npack, math.max(0, DropBoxConstConfig.refreshtime - (System.getNowTime() - (BoxRefreshTime or 0))))
    LDataPack.flush(npack)
end

local function OnGameStart(...)
    if not System.isBattleSrv() then return end
    dropBoxStart()
end

function onNewDay(actor, login)
    local var = getActorVar(actor)
    var.gettimes = 0
end

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)
--engineevent.regGameStartEvent(OnGameStart)
_G.dropBoxStart = dropBoxStart
_G.dropBoxEnd = dropBoxEnd
_G.enterMainFuben = enterMainFuben

function init()
    if not System.isBattleSrv() then return end
    insevent.registerInstanceEnter(0, ehEnterFuben)
    insevent.registerInstanceEnterBefore(0, onEnterBefore)
    -- insevent.registerInstanceGatherMonsterCreate(0, onGatherMonsterCreate)
    -- insevent.registerInstanceGatherMonsterCheck(0, onGatherMonsterCheck)
    insevent.registerInstanceGatherMonsterUpdate(0, onGatherMonsterUpdate)
    insevent.registerInstanceOffline(0, onOffline)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.mainFubenTest = function (actor)
    local var = System.getDyanmicVar()
    print(var.mainSceneCount)
    return true
end

gmCmdHandlers.dropboxstart = function (actor)
    dropBoxStart()
    return true
end

gmCmdHandlers.dropboxend = function (actor)
    dropBoxEnd()
    return true
end

gmCmdHandlers.mainpeopleset = function (actor, args)
    maxActorCount = tonumber(args[1])
    return true
end
