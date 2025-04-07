-- 真红boss
module("zhenhongfuben", package.seeall)

local rType = {
    belong = 1,
    help = 2,
}
local ZHRank_type

ZHBOSS_OPEN = false
ZHBOSS_DATA = ZHBOSS_DATA or {}

local function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.zhfb then
        var.zhfb = {
            helpCount = 0,
            initSummon = 0,
            initFight = 0,
        }
    end
    return var.zhfb
end

local function getZHBOSSData(actorId)
    return ZHBOSS_DATA[actorId]
end

local function checkZHBOSSOpen()
    return ZHBOSS_OPEN
end

local function checkZHFBHave(actor)
    local actorId = LActor.getActorId(actor)
    return ZHBOSS_DATA[actorId] == nil
end

local function checkZHFBCount()
    local count = 0
    for k, v in pairs(ZHBOSS_DATA) do
        count = count + 1
    end
    return count < ZHFBCommonConfig.bossMaxCount
end

local function creatZHFuben(tp, belongId, belongName, serverId)
    if ZHBOSS_DATA[belongId] then return end
    
    local bossList = ZHSummonConfig[tp].bossList
    local maxCount = #bossList
    if maxCount <= 0 then return end
    
    local id = bossList[math.random(1, maxCount)]
    local config = ZHBossConfig[id]
    if not config then return end
    local hfuben = instancesystem.createFuBen(config.fbId)
    if hfuben == 0 then return end
    
    local ins = instancesystem.getInsByHdl(hfuben)
    if not ins then return end
    
    ins.data.belongId = belongId
    ins.data.nextHitTime = 0
    ins.data.damageList = {}
    
    ZHBOSS_DATA[belongId] = {
        id = id,
        bossId = config.bossId,
        fbId = config.fbId,
        tp = tp,
        hfuben = hfuben,
        belongId = belongId,
        serverId = serverId,
        belongName = belongName,
        hp = 10000,
        people = 0,
        keepTime = System.getNowTime() + config.keepTime,
        actorList = {},
        rank = {},
    }
    return true
end

function zhBOSSFight(actor, belongId)
    local bossData = getZHBOSSData(belongId)
    if not bossData then return end
    
    if bossData.hp == 0 then return end
    
    local var = getActorVar(actor)
    if var.initFight ~= 0 then return end
    
    local actorList = bossData.actorList
    local actorId = LActor.getActorId(actor)
    if actorId ~= belongId and actorList[actorId] == nil then
        local config = ZHSummonConfig[bossData.tp]
        if bossData.people >= config.helpMaxPeople then
            print("zhBOSSFight people is full count =", bossData.people)
            return
        end
        local var = getActorVar(actor)
        if bossData.tp ~= 2 and var.helpCount >= ZHFBCommonConfig.helpMaxCount then
            print("zhBOSSFight helpCount is full count =", var.helpCount)
            return
        end
    end
    
    local x, y = utils.getSceneEnterCoor(bossData.fbId)
    LActor.loginOtherServer(actor, csbase.getCrossServerId(), bossData.hfuben, 0, x, y, 'zhenhongboss')
    var.initFight = 1
    return true
end

function zhBOSSCreate(actor, tp)
    if not checkZHFBHave(actor) then return end
    if not checkZHFBCount() then return end
    local var = getActorVar(actor)
    if var.initSummon ~= 0 then return end
    local config = ZHSummonConfig[tp]
    if not config then return end
    
    local itemId = config.itemId
    if not actoritem.checkItem(actor, itemId, 1) then return end
    actoritem.reduceItem(actor, itemId, 1, "create zhenhongboss")
    var.initSummon = 1
    sendCreateFb(tp, LActor.getActorId(actor), LActor.getName(actor))
    utils.logCounter(actor, "zhenhongfuben", "summonType", tp, "zhBOSSCreate")
end

function zhBossBelongResult(actorId, bossData)
    local serverId = bossData.serverId
    local belongName = bossData.belongName
    local config = ZHBossConfig[bossData.id]
    local itemId = config.belongItemId
    local actor = LActor.getActorById(actorId)
    
    if actor and LActor.getFubenHandle(actor) == bossData.hfuben then
        actoritem.addItem(actor, itemId, 1, "zhenhong boss kill")
        s2cZHBOSSBelongResult(actor, 1, itemId)
    else
        local items = {{type = 1, id = itemId, count = 1}}
        sendZHBossEmail(actorId, serverId, items, true)
    end
    zhenhongrank.setZHRankScore(ZHRank_type.kill, actorId, serverId, belongName, 1)
    if actor then
        actorevent.onEvent(actor, aeZHBossKill, -1, 1)
    else
        taskevent.transferEvent(actorId, serverId, aeZHBossKill, -1, 1)
    end
end

function zhBossHelpResult(bossData)
    local rank = bossData.rank
    if not rank then return end
    local config = ZHBossConfig[bossData.id]
    for i, itemId in ipairs(config.joinItems) do
        if rank[i] then
            rank[i].itemId = itemId
        end
    end
    for i, v in ipairs(rank) do
        local actorId = v.aid
        local serverId = v.serverId
        local name = v.name
        zhenhongrank.setZHRankScore(ZHRank_type.kill, actorId, serverId, name, 1)
        
        local actor = LActor.getActorById(actorId)
        local itemId = v.itemId
        if actor and LActor.getFubenHandle(actor) == bossData.hfuben then
            if itemId then
                actoritem.addItem(actor, itemId, 1, "zhenhong boss kill")
            end
            s2cZHBOSSHelpResult(actor, 1, rank)
        else
            if itemId then
                local items = itemId and {{type = 1, id = itemId, count = 1}}
                sendZHBossEmail(actorId, serverId, items, true)
            end
        end
        if actor then
            actorevent.onEvent(actor, aeZHBossKill, -1, 1)
        else
            taskevent.transferEvent(actorId, serverId, aeZHBossKill, -1, 1)
        end
    end
end

function sendZHBossEmail(actorId, serverId, items, isWin)
    local mailData = {
        head = isWin and ZHFBCommonConfig.winMailTitle or ZHFBCommonConfig.loseMailTitle,
        context = isWin and ZHFBCommonConfig.winMailContent or ZHFBCommonConfig.loseMailContent,
        tAwardList = items,
    }
    mailsystem.sendMailById(actorId, mailData, serverId)
end

function closeZHfuben(belongId)
    ZHBOSS_DATA[belongId] = nil
    deleteZHFbInfo(belongId)
end

function sortZHRank(ins)
    local belongId = ins.data.belongId
    local damageList = ins.data.damageList
    
    local rank = {}
    for actorId, v in pairs(damageList) do
        table.insert(rank, {aid = actorId, serverId = v.serverId, dmg = v.dmg, name = v.name})
    end
    table.sort(rank, function(a, b) return a.dmg > b.dmg end)
    
    local bossData = getZHBOSSData(belongId)
    bossData.rank = rank
end

----------------------------------------------------------------------------------
--事件处理
local function onLogin(actor)
    local var = getActorVar(actor)
    var.initSummon = 0
    var.initFight = 0
    s2cZHBOSSList(actor)
    s2cZHBOSSHelpCount(actor)
    s2cZHBOSSOpen(actor)
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    var.helpCount = 0
    if not login then
        s2cZHBOSSHelpCount(actor)
    end
end

local function onEnterFb(ins, actor)
    local belongId = ins.data.belongId
    local bossData = getZHBOSSData(belongId)
    local damageList = ins.data.damageList
    local actorId = LActor.getActorId(actor)
    local serverId = LActor.getServerId(actor)
    local name = LActor.getName(actor)
    
    if not bossData then
        LActor.exitFuben(actor)
        return
    end
    
    if actorId ~= belongId and damageList[actorId] == nil then
        local config = ZHSummonConfig[bossData.tp]
        if bossData.hp == 0 or bossData.people >= config.helpMaxPeople then
            LActor.exitFuben(actor)
        else
            if bossData.tp ~= 2 then
                local var = getActorVar(actor)
                var.helpCount = var.helpCount + 1
            end
            damageList[actorId] = {aid = actorId, serverId = serverId, dmg = 0, name = name}
            bossData.people = bossData.people + 1
            bossData.actorList[actorId] = 1
            updateZHFbPeople(belongId)
        end
    end
end

local function onExitFb(ins, actor)
    local var = getActorVar(actor)
    var.initSummon = 0
    var.initFight = 0
end

local function onOffline(ins, actor)
    local var = getActorVar(actor)
    var.initSummon = 0
    var.initFight = 0
end

local function onBossDamage(ins, monster, value, attacker, res)
    local belongId = ins.data.belongId
    local nextHitTime = ins.data.nextHitTime
    
    local oldhp = LActor.getHp(monster)
    if oldhp <= 0 then return end
    
    local now = System.getNowTime()
    if nextHitTime <= now then
        local bossData = getZHBOSSData(belongId)
        local config = ZHBossConfig[bossData.id]
        local hp = oldhp - math.random(config.hitParam[1], config.hitParam[2])
        if hp < 0 then hp = 0 end
        bossData.hp = hp
        res.ret = hp
        ins.data.nextHitTime = now + config.hitTime
        updateZHFbHp(belongId, hp)
    else
        res.ret = oldhp
    end
end

local function onBossRealDamage(ins, monster, value, attacker)
    local belongId = ins.data.belongId
    local damageList = ins.data.damageList
    
    local actor = LActor.getActor(attacker)
    if not actor then return end
    
    local actorId = LActor.getActorId(actor)
    if actorId == -1 then return end
    
    if actorId ~= belongId then
        damageList[actorId].dmg = damageList[actorId].dmg + value
    end
end

local function onWin(ins)
    sortZHRank(ins)
    sendZHBOSSRank(ins)
    
    local belongId = ins.data.belongId
    local bossData = getZHBOSSData(belongId)
    zhBossBelongResult(belongId, bossData)
    zhBossHelpResult(bossData)
    
    closeZHfuben(belongId)
end

local function onLose(ins)
    local belongId = ins.data.belongId
    local bossData = getZHBOSSData(belongId)
    local damageList = ins.data.damageList
    closeZHfuben(belongId)
    
    local belong = LActor.getActorById(belongId)
    if belong and LActor.getFubenHandle(belong) == ins.handle then
        s2cZHBOSSBelongResult(belong, 0, 0)
    else
        sendZHBossEmail(belongId, bossData.serverId, {}, false)
    end
    
    for actorId, v in pairs(damageList) do
        local actor = LActor.getActorById(actorId)
        if actor and LActor.getFubenHandle(actor) == ins.handle then
            s2cZHBOSSHelpResult(actor, 0, {})
        else
            sendZHBossEmail(actorId, v.serverId, {}, false)
        end
    end
end

local function onTimerRank(ins)
    sortZHRank(ins)
    sendZHBOSSRank(ins)
end

local function checkZHOpen()
    local now = System.getNowTime()
    local weekTime = System.getWeekFistTime()
    local d, h, m = string.match(ZHFBCommonConfig.startTime, "(%d+)-(%d+):(%d+)")
    if d == nil or h == nil or m == nil then return end
    local startTime = weekTime + d * 24 * 3600 + h * 3600 + m * 60
    
    d, h, m = string.match(ZHFBCommonConfig.endTime, "(%d+)-(%d+):(%d+)")
    if d == nil or h == nil or m == nil then return end
    local endTime = weekTime + d * 24 * 3600 + h * 3600 + m * 60
    if now >= startTime and now < endTime then
        ZHBOSS_OPEN = true
    end
end

_G.ZHBOSSOpen = function()
    ZHBOSS_OPEN = true
    sendZHBOSSOpen()
end

_G.ZHBOSSClose = function()
    ZHBOSS_OPEN = false
    sendZHBOSSOpen()
end

-------------------------------------------------------------------------------------------------------
--协议处理
--85-87 请求真红boss信息
local function c2sZHBOSSInfo(actor)
    s2cZHBOSSList(actor)
end

--85-87 返回真红boss信息
function s2cZHBOSSList(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.s2cZHBOSS_Info)
    if pack == nil then return end
    
    local now = System.getNowTime()
    local actorId = LActor.getActorId(actor)
    local count = 0
    local pos1 = LDataPack.getPosition(pack)
    LDataPack.writeChar(pack, 0)
    for belongId, bossData in pairs(ZHBOSS_DATA) do
        local mon_conf = MonstersConfig[bossData.bossId]
        local canFight = 1
        if belongId == actorId or bossData.actorList[actorId] then
            canFight = 0
        end
        LDataPack.writeChar(pack, bossData.tp)
        LDataPack.writeInt(pack, belongId)
        LDataPack.writeString(pack, bossData.belongName)
        LDataPack.writeInt(pack, bossData.keepTime - now)
        LDataPack.writeChar(pack, bossData.people)
        LDataPack.writeChar(pack, canFight)
        LDataPack.writeShort(pack, bossData.hp)
        LDataPack.writeString(pack, mon_conf.name)
        LDataPack.writeString(pack, mon_conf.head)
        count = count + 1
    end
    
    local pos2 = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, pos1)
    LDataPack.writeChar(pack, count)
    LDataPack.setPosition(pack, pos2)
    LDataPack.flush(pack)
end

--85-88 增加单个boss
function sendAddBossInfo(belongId)
    local bossData = getZHBOSSData(belongId)
    if not bossData then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Cross)
    LDataPack.writeByte(pack, Protocol.s2cZHBOSS_AddBossInfo)
    local mon_conf = MonstersConfig[bossData.bossId]
    LDataPack.writeChar(pack, bossData.tp)
    LDataPack.writeInt(pack, belongId)
    LDataPack.writeString(pack, bossData.belongName)
    LDataPack.writeInt(pack, bossData.keepTime - System.getNowTime())
    LDataPack.writeChar(pack, bossData.people)
    LDataPack.writeChar(pack, 1)
    LDataPack.writeShort(pack, bossData.hp)
    LDataPack.writeString(pack, mon_conf.name)
    LDataPack.writeString(pack, mon_conf.head)
    System.broadcastData(pack)
end

--85-89 删除单个boss
function sendDelBossInfo(belongId)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Cross)
    LDataPack.writeByte(pack, Protocol.s2cZHBOSS_DelBossInfo)
    LDataPack.writeInt(pack, belongId)
    System.broadcastData(pack)
end

--85-90 更新boss支援人数
function sendZHBOSSPeople(belongId)
    local bossData = getZHBOSSData(belongId)
    if not bossData then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Cross)
    LDataPack.writeByte(pack, Protocol.s2cZHBOSS_UpdatePeople)
    LDataPack.writeInt(pack, belongId)
    LDataPack.writeChar(pack, bossData.people)
    System.broadcastData(pack)
end

--85-91 挑战真红boss
local function c2sZHBOSSFight(actor, pack)
    local belongId = LDataPack.readInt(pack)
    
    if System.isCrossWarSrv() then return end
    if not actorlogin.checkCanEnterCross(actor) then return end
    local fbId = LActor.getFubenId(actor)
    if not staticfuben.isStaticFuben(fbId) then return end
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zhfb) then return end
    local ret = zhBOSSFight(actor, belongId)
    s2cZHBOSSFight(actor, belongId, ret)
end

--85-91 返回挑战真红boss
function s2cZHBOSSFight(actor, belongId, ret)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.s2sZHBOSS_Fight)
    if pack == nil then return end
    LDataPack.writeInt(pack, belongId)
    LDataPack.writeChar(pack, ret and 1 or 0)
    LDataPack.flush(pack)
end

--85-92 召唤真红boss
local function c2sZHBOSSCreate(actor, pack)
    local tp = LDataPack.readChar(pack)
    
    if not checkZHBOSSOpen() then return end
    if System.isCrossWarSrv() then return end
    if not actorlogin.checkCanEnterCross(actor) then return end
    local fbId = LActor.getFubenId(actor)
    if not staticfuben.isStaticFuben(fbId) then return end
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zhfb) then return end
    zhBOSSCreate(actor, tp)
end

--85-92 返回召唤真红boss
function s2cZHBOSSCreate(actor, belongId, ret)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.s2sZHBOSS_Create)
    if pack == nil then return end
    LDataPack.writeInt(pack, belongId)
    LDataPack.writeChar(pack, ret)
    LDataPack.flush(pack)
end

--85-93 召唤者战斗结算
function s2cZHBOSSBelongResult(actor, ret, itemId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.s2cZHBOSS_Result)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, ret)
    LDataPack.writeChar(pack, rType.belong)
    LDataPack.writeInt(pack, itemId)
    LDataPack.flush(pack)
end

--85-93 支援者战斗结算
function s2cZHBOSSHelpResult(actor, ret, rank)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.s2cZHBOSS_Result)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, ret)
    LDataPack.writeChar(pack, rType.help)
    LDataPack.writeChar(pack, #rank)
    for i, v in ipairs(rank) do
        LDataPack.writeDouble(pack, v.dmg)
        LDataPack.writeString(pack, v.name)
        LDataPack.writeInt(pack, v.itemId or 0)
    end
    LDataPack.flush(pack)
end

--85-94 更新支援次数
function s2cZHBOSSHelpCount(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.s2cZHBOSS_HelpCount)
    if pack == nil then return end
    LDataPack.writeChar(pack, var.helpCount)
    LDataPack.flush(pack)
end

--85-95 更新排行榜
function sendZHBOSSRank(ins)
    local belongId = ins.data.belongId
    local bossData = getZHBOSSData(belongId)
    local rank = bossData and bossData.rank
    if not rank then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Cross)
    LDataPack.writeByte(pack, Protocol.s2cZHBOSS_Rank)
    
    LDataPack.writeInt(pack, bossData.bossId)
    LDataPack.writeShort(pack, bossData.hp)
    LDataPack.writeByte(pack, #rank)
    for i = 1, #rank do
        LDataPack.writeInt(pack, rank[i].aid)
        LDataPack.writeString(pack, rank[i].name)
        LDataPack.writeDouble(pack, rank[i].dmg)
    end
    LDataPack.writeInt(pack, bossData.fbId)
    local conf = MonstersConfig[bossData.bossId]
    LDataPack.writeString(pack, conf.name)
    LDataPack.writeString(pack, conf.head)
    LDataPack.writeInt(pack, conf.level)
    LDataPack.writeShort(pack, conf.HpMax)
    Fuben.sendData(ins.handle, pack)
end

--85-99 广播更新活动开启状态
function sendZHBOSSOpen()
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Cross)
    LDataPack.writeByte(pack, Protocol.s2cZHBOSS_UpdateOpen)
    LDataPack.writeChar(pack, ZHBOSS_OPEN and 1 or 0)
    System.broadcastData(pack)
end

--85-99 更新活动开启状态
function s2cZHBOSSOpen(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.s2cZHBOSS_UpdateOpen)
    if pack == nil then return end
    LDataPack.writeChar(pack, ZHBOSS_OPEN and 1 or 0)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--跨服协议
--普通服通知跨服创建新boss
function sendCreateFb(tp, belongId, belongName)
    if System.isCrossWarSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCZhenHongCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCZhenHongCmd_CreateFb)
    
    LDataPack.writeInt(pack, belongId)
    LDataPack.writeByte(pack, tp)
    LDataPack.writeString(pack, belongName)
    System.sendPacketToAllGameClient(pack, 0)
end

--跨服收到则创建新boss
--普通服收到则通知召唤者进入副本
local function onSendCreateFb(sId, sType, dp)
    if System.isBattleSrv() then
        local belongId = LDataPack.readInt(dp)
        local tp = LDataPack.readByte(dp)
        local belongName = LDataPack.readString(dp)
        local ret = creatZHFuben(tp, belongId, belongName, sId)
        
        if ret then
            zhenhongrank.setZHRankScore(ZHRank_type.summon, belongId, sId, belongName, ZHSummonConfig[tp].score)
            updateZHFbInfo(belongId)
        end
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCZhenHongCmd)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCZhenHongCmd_CreateFb)
        
        LDataPack.writeInt(pack, belongId)
        LDataPack.writeByte(pack, tp)
        LDataPack.writeByte(pack, ret and 1 or 0)
        System.sendPacketToAllGameClient(pack, sId)
    else
        local actorId = LDataPack.readInt(dp)
        local tp = LDataPack.readByte(dp)
        local ret = LDataPack.readByte(dp)
        
        local bossData = getZHBOSSData(actorId)
        if ret == 0 then
            local mailData = {
                head = ZHFBCommonConfig.mailTitle,
                context = ZHFBCommonConfig.mailContent,
                tAwardList = {{type = 1, id = ZHSummonConfig[tp].itemId, count = 1}},
            }
            mailsystem.sendMailById(actorId, mailData)
            print("summon fail", "actorId =", actorId, "tp =", tp)
        else
            local actor = LActor.getActorById(actorId)
            if actor and bossData then
                local x, y = utils.getSceneEnterCoor(bossData.fbId)
                LActor.loginOtherServer(actor, csbase.getCrossServerId(), bossData.hfuben, 0, x, y, 'zhenhongboss')
                actorevent.onEvent(actor, aeZHBossSummon, -1, 1)
                s2cZHBOSSCreate(actor, actorId, ret)
            else
                taskevent.sendTaskEventOffMsg(actorId, aeZHBossSummon, -1, 1)
            end
        end
    end
end

--跨服向普通服同步boss信息
function sendZHFbInfo(serverId)
    if not System.isBattleSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCZhenHongCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCZhenHongCmd_SyncAllFbInfo)
    local bossDataUd = bson.encode(ZHBOSS_DATA)
    LDataPack.writeUserData(pack, bossDataUd)
    System.sendPacketToAllGameClient(pack, serverId or 0)
end

--普通服收到跨服boss信息
local function onSendZHFbInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local bossDataUd = LDataPack.readUserData(dp)
    ZHBOSS_DATA = bson.decode(bossDataUd)
end

--跨服给普通服更新单个boss信息
function updateZHFbInfo(belongId)
    if not System.isBattleSrv() then return end
    local bossData = getZHBOSSData(belongId)
    if not bossData then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCZhenHongCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCZhenHongCmd_SyncUpdateFbInfo)
    
    LDataPack.writeInt(pack, belongId)
    local bossDataUd = bson.encode(bossData)
    LDataPack.writeUserData(pack, bossDataUd)
    System.sendPacketToAllGameClient(pack, 0)
end

--普通服收到更新单个boss信息
local function onUpdateZHFbInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local belongId = LDataPack.readInt(dp)
    local bossDataUd = LDataPack.readUserData(dp)
    local bossData = bson.decode(bossDataUd)
    ZHBOSS_DATA[belongId] = bossData
    sendAddBossInfo(belongId)
end

--跨服通知普通服删除单个boss信息
function deleteZHFbInfo(belongId)
    if not System.isBattleSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCZhenHongCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCZhenHongCmd_SyncDeleteFbInfo)
    LDataPack.writeInt(pack, belongId)
    System.sendPacketToAllGameClient(pack, 0)
end

--普通服收到跨服删除单个boss信息
local function onDeleteZHFbInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local belongId = LDataPack.readInt(dp)
    ZHBOSS_DATA[belongId] = nil
    sendDelBossInfo(belongId)
end

--跨服通知普通服更新副本人数
function updateZHFbPeople(belongId)
    if not System.isBattleSrv() then return end
    local bossData = getZHBOSSData(belongId)
    if not bossData then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCZhenHongCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCZhenHongCmd_SyncUpdatePeople)
    LDataPack.writeInt(pack, belongId)
    LDataPack.writeByte(pack, bossData.people)
    
    local actorList = bossData.actorList
    local count = 0
    local pos1 = LDataPack.getPosition(pack)
    LDataPack.writeByte(pack, 0)
    for actorId in pairs(actorList) do
        LDataPack.writeInt(pack, actorId)
        count = count + 1
    end
    
    local pos2 = LDataPack.getPosition(pack)
    LDataPack.setPosition(pack, pos1)
    LDataPack.writeChar(pack, count)
    LDataPack.setPosition(pack, pos2)
    
    System.sendPacketToAllGameClient(pack, 0)
end

--普通服收到跨服更新副本人数
local function onUpdateZHFbPeople(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local actorList = {}
    local belongId = LDataPack.readInt(dp)
    local people = LDataPack.readByte(dp)
    local count = LDataPack.readByte(dp)
    for i = 1, count do
        local actorId = LDataPack.readInt(dp)
        actorList[actorId] = 1
    end
    local bossData = getZHBOSSData(belongId)
    if not bossData then return end
    bossData.people = people
    bossData.actorList = actorList
    sendZHBOSSPeople(belongId)
end

--跨服通知普通服更新BOSS血量
function updateZHFbHp(belongId, hp)
    if not System.isBattleSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCZhenHongCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCZhenHongCmd_SyncUpdateHp)
    LDataPack.writeInt(pack, belongId)
    LDataPack.writeShort(pack, hp)
    System.sendPacketToAllGameClient(pack, 0)
end

--普通服收到跨服更新BOSS血量
local function onUpdateZHFbHp(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local belongId = LDataPack.readInt(dp)
    local hp = LDataPack.readShort(dp)
    local bossData = getZHBOSSData(belongId)
    if not bossData then return end
    bossData.hp = hp
end

--跨服通知普通服触发玩家事件
function sendZHEvent(actorId, serverId, eventType, count)
    if not System.isBattleSrv() then return end
    transferEvent(actorId, serverId, eventType, -1, count)
    -- local pack = LDataPack.allocPacket()
    -- LDataPack.writeByte(pack, CrossSrvCmd.SCZhenHongCmd)
    -- LDataPack.writeByte(pack, CrossSrvSubCmd.SCCBCmd_SendZHEvent)
    -- LDataPack.writeInt(pack, actorId)
    -- LDataPack.writeInt(pack, eventType)
    -- LDataPack.writeInt(pack, count)
    -- System.sendPacketToAllGameClient(pack, 0)
end

--普通服收到跨服触发玩家事件
local function onSendZHEvent(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local actorId = LDataPack.readInt(dp)
    local eventType = LDataPack.readInt(dp)
    local count = LDataPack.readInt(dp)
    
    local actor = LActor.getActorById(actorId)
    if actor then
        actorevent.onEvent(actor, eventType, -1, count)
    else
        taskevent.sendTaskEventOffMsg(actorId, eventType, -1, count)
    end
end

--连接跨服事件
local function onZHFBConnected(serverId, serverType)
    sendZHFbInfo(serverId)
end
----------------------------------------------------------------------------------
--初始化
local function initGlobalData()
    if System.isLianFuSrv() then return end
    ZHRank_type = zhenhongrank.ZHRank_type
    checkZHOpen()
    
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.c2sZHBOSS_Info, c2sZHBOSSInfo)
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.c2sZHBOSS_Fight, c2sZHBOSSFight)
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.c2sZHBOSS_Create, c2sZHBOSSCreate)
    
    csmsgdispatcher.Reg(CrossSrvCmd.SCZhenHongCmd, CrossSrvSubCmd.SCZhenHongCmd_CreateFb, onSendCreateFb)
    csmsgdispatcher.Reg(CrossSrvCmd.SCZhenHongCmd, CrossSrvSubCmd.SCZhenHongCmd_SyncAllFbInfo, onSendZHFbInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCZhenHongCmd, CrossSrvSubCmd.SCZhenHongCmd_SyncUpdateFbInfo, onUpdateZHFbInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCZhenHongCmd, CrossSrvSubCmd.SCZhenHongCmd_SyncDeleteFbInfo, onDeleteZHFbInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCZhenHongCmd, CrossSrvSubCmd.SCZhenHongCmd_SyncUpdatePeople, onUpdateZHFbPeople)
    csmsgdispatcher.Reg(CrossSrvCmd.SCZhenHongCmd, CrossSrvSubCmd.SCZhenHongCmd_SyncUpdateHp, onUpdateZHFbHp)
    --csmsgdispatcher.Reg(CrossSrvCmd.SCZhenHongCmd, CrossSrvSubCmd.SCCBCmd_SendZHEvent, onSendZHEvent)
    
    if not System.isBattleSrv() then return end
    for _, conf in ipairs(ZHBossConfig) do
        local fbId = conf.fbId
        insevent.registerInstanceWin(fbId, onWin)
        insevent.registerInstanceLose(fbId, onLose)
        insevent.registerInstanceEnter(fbId, onEnterFb)
        insevent.registerInstanceMonsterDamage(fbId, onBossDamage)
        insevent.registerInstanceRealDamage(fbId, onBossRealDamage)
        insevent.registerInstanceExit(fbId, onExitFb)
        insevent.registerInstanceOffline(fbId, onOffline)
        insevent.regCustomFunc(fbId, onTimerRank, "onTimerRank")
    end
    
    csbase.RegConnected(onZHFBConnected)
end
table.insert(InitFnTable, initGlobalData)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.ZHBOSSFight = function (actor, args)
    local belongId = tonumber(args[1])
    zhBOSSFight(actor, belongId)
    return true
end

gmCmdHandlers.ZHBOSSCreate = function (actor, args)
    local tp = tonumber(args[1])
    zhBOSSCreate(actor, tp)
    return true
end

gmCmdHandlers.ZHFbPrint = function (actor, args)
    utils.printTable(ZHBOSS_DATA)
    if System.isCommSrv() then
        SCTransferGM("ZHFbPrint")
    end
    return true
end

gmCmdHandlers.ZHFbClear = function (actor, args)
    local belongId = tonumber(args[1])
    ZHBOSS_DATA[belongId] = nil
    if System.isCommSrv() then
        SCTransferGM("ZHFbClear", args)
    end
    return true
end

gmCmdHandlers.ZHFbStart = function (actor, args)
    ZHBOSS_OPEN = true
    sendZHBOSSOpen()
    if System.isCommSrv() then
        SCTransferGM("ZHFbStart", args)
    end
    return true
end

gmCmdHandlers.ZHFbStop = function (actor, args)
    ZHBOSS_OPEN = false
    sendZHBOSSOpen()
    if System.isCommSrv() then
        SCTransferGM("ZHFbStop", args)
    end
    return true
end

