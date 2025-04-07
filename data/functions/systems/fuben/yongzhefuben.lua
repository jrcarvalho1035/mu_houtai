-- @system  勇者之塔

module("yongzhefuben", package.seeall)
require("scene.yongzhefuben")

--YongzheFloorConfig = {}

local function getActorVar(actor)
    if not actor then return end
    
    local var = LActor.getStaticVar(actor)
    if not var then return end
    
    if not var.yongzhefuben then
        var.yongzhefuben = {}
    end
    if not var.yongzhefuben.curId then var.yongzhefuben.curId = 1 end --当前挑战层数
    if not var.yongzhefuben.customReward then var.yongzhefuben.customReward = {} end --关卡奖励
    if not var.yongzhefuben.firstReward then var.yongzhefuben.firstReward = {} end --首通奖励
    return var.yongzhefuben
end

local function getSystemVar()
    local var = System.getStaticVar()
    if not var then return end
    if not var.yongzhefuben then
        var.yongzhefuben = {}
    end
    if not var.yongzhefuben.firstMaxCustom then var.yongzhefuben.firstMaxCustom = 0 end --记录全服首通最大层数
    if not var.yongzhefuben.firstCustomInfo then var.yongzhefuben.firstCustomInfo = {} end --记录首通玩家信息
    return var.yongzhefuben
end

function getYongzheFloor(actor)
    local var = getActorVar(actor)
    return var.curId - 1
end

function setFirstInfo(actor, custom)
    local sysVar = getSystemVar()
    if not sysVar then return end
    if custom <= sysVar.firstMaxCustom then return end

    local conf = YongzheFubenConfig[custom]
    if not conf then return end
    
    if custom - sysVar.firstMaxCustom > 1 then
        print("yongzhefuben.setFirstInfo set next maxcustom must diff = 1, but diff =", custom - sysVar.firstMaxCustom)
    end
    
    for i = sysVar.firstMaxCustom + 1, custom do
        if not sysVar.firstCustomInfo[i] then
            sysVar.firstCustomInfo[i] = {
                actorid = LActor.getActorId(actor),
                job = LActor.getJob(actor),
                actorname = LActor.getName(actor),
            }
        end
    end
    sysVar.firstMaxCustom = custom
    sendFirstCustomInfo()
    
    noticesystem.broadCastNotice(noticesystem.NTP.yongzhefb, LActor.getName(actor), conf.floor, conf.index)
end

function onFbWin(ins)
    local actor = ins:getActorList()[1]
    if actor == nil then return end --胜利的 时候不可能找不到吧
    local var = getActorVar(actor)
    if not var then return end
    
    local config = YongzheFubenConfig[var.curId]
    if not config then return end
    
    if ins.id ~= config.fbId then
        print("yongzhefuben fb id error   ins.fbId:", ins.fbId, "config.fbId:", config.fbId)
        return
    end
    
    local custom = var.curId
    var.curId = var.curId + 1
    instancesystem.setInsRewards(ins, actor, config.bossReward)
    --actoritem.addItems(actor, config.bossReward, "yongzhefuben boss rewards")
    
    setFirstInfo(actor, custom)
    updateInfo(actor)
end

function onFbLose(ins)
    local actor = ins:getActorList()[1]
    if actor == nil then return end
    
    instancesystem.setInsRewards(ins, actor, nil)
end

--87-61 请求挑战
function c2sFight(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.yongzhefuben) then return end
    local var = getActorVar(actor)
    if not var then return end
    
    local config = YongzheFubenConfig[var.curId]
    if not config then return end
    
    local zslevel = LActor.getZhuansheng(actor)
    if zslevel < config.zslevel then return end
    
    if not utils.checkFuben(actor, config.fbId) then return end
    local hfuben = instancesystem.createFuBen(config.fbId)
    if hfuben == 0 then return end
    local x, y = utils.getSceneEnterCoor(config.fbId)
    LActor.enterFuBen(actor, hfuben, 0, x, y)
end

--87-61 副本信息
function sendYongzheInfo(actor)
    local actorVar = getActorVar(actor)
    if not actorVar then return end
    local sysVar = getSystemVar()
    if not sysVar then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sYongzhe_Info)
    if not pack then return end
    LDataPack.writeShort(pack, actorVar.curId)
    LDataPack.writeShort(pack, sysVar.firstMaxCustom)
    local myCustom = actorVar.curId - 1
    LDataPack.writeShort(pack, myCustom)
    for idx = 1, myCustom do
        LDataPack.writeChar(pack, actorVar.customReward[idx] or 0)
    end
    local sysCustom = #YongzheFubenConfig
    LDataPack.writeShort(pack, sysCustom)
    for idx = 1, sysCustom do
        LDataPack.writeChar(pack, actorVar.firstReward[idx] or 0)
    end
    LDataPack.flush(pack)
end

--87-62 请求领奖
local function c2sGetYongzheReward(actor, packet)
    local reward_type = LDataPack.readChar(packet)
    local idx = LDataPack.readShort(packet)
    if reward_type == 1 then
        getCustomReward(actor, idx)
    elseif reward_type == 2 then
        getGetFirstReward(actor, idx)
    end
end

--领取关卡奖励
function getCustomReward(actor, index)
    local config = YongzheFubenConfig[index]
    if not config then return end
    if not next(config.customReward) then return end
    local actorVar = getActorVar(actor)
    if not actorVar then return end
    if index >= actorVar.curId then return end
    if actorVar.customReward[index] == 1 then return end
    
    actorVar.customReward[index] = 1
    actoritem.addItems(actor, config.customReward, "yongzhefuben custom rewards")
    sendCustomRewardInfo(actor, index)
end

--领取首通奖励
function getGetFirstReward(actor, index)
    local config = YongzheFubenConfig[index]
    if not config then return end
    if not next(config.firstReward) then return end
    local sysVar = getSystemVar()
    if not sysVar then return end
    if sysVar.firstMaxCustom < index then return end
    
    local actorVar = getActorVar(actor)
    if not actorVar then return end
    if actorVar.firstReward[index] == 1 then return end
    
    actorVar.firstReward[index] = 1
    actoritem.addItems(actor, config.firstReward, "yongzhefuben first rewards")
    sendFirstRewardInfo(actor, index)
end

--87-62 关卡奖励返回
function sendCustomRewardInfo(actor, idx)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sYongzhe_UpdateReward)
    if not pack then return end
    LDataPack.writeChar(pack, 1)
    LDataPack.writeShort(pack, idx)
    LDataPack.writeChar(pack, var.customReward[idx] or 0)
    LDataPack.flush(pack)
end

--87-62 首通奖励返回
function sendFirstRewardInfo(actor, idx)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sYongzhe_UpdateReward)
    if not pack then return end
    LDataPack.writeChar(pack, 2)
    LDataPack.writeShort(pack, idx)
    LDataPack.writeChar(pack, var.firstReward[idx] or 0)
    LDataPack.flush(pack)
end

--87-63 通关信息
function sendFirstCustomInfo()
    local sysVar = getSystemVar()
    if not sysVar then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_AllFuben2)
    LDataPack.writeByte(pack, Protocol.sYongzhe_UpdateFirstCustom)
    LDataPack.writeShort(pack, sysVar.firstMaxCustom)
    System.broadcastData(pack)
end

--87-64 请求首通玩家信息
local function c2sGetFirstInfo(actor)
    local sysVar = getSystemVar()
    if not sysVar then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sYongzhe_GetFirstInfo)
    if not pack then return end
    local num = sysVar.firstMaxCustom
    LDataPack.writeShort(pack, num)
    for idx = 1, num do
        LDataPack.writeString(pack, sysVar.firstCustomInfo[idx].actorname)
    end
    LDataPack.flush(pack)
end

--87-65 更新副本信息
function updateInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sYongzhe_UpdateInfo)
    if not pack then return end
    LDataPack.writeShort(pack, var.curId)
    LDataPack.flush(pack)
end

-- function initFloorConfig()
--     for idx, conf in ipairs(YongzheFubenConfig) do
--         if not YongzheFloorConfig[conf.floor] then
--             YongzheFloorConfig[conf.floor] = {}
--         end
--         table.insert(YongzheFloorConfig[conf.floor], idx)
--     end
-- end

local function onLogin(actor)
    sendYongzheInfo(actor)
end

local function init()
    if System.isCrossWarSrv() then return end
    
    --initFloorConfig()
    
    actorevent.reg(aeUserLogin, onLogin)
    
    netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cYongzhe_challenge, c2sFight)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cYongzhe_GetReward, c2sGetYongzheReward)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cYongzhe_GetFirstInfo, c2sGetFirstInfo)
    
    --注册相关回调
    for _, config in pairs(YongzheFubenConfig) do
        insevent.registerInstanceWin(config.fbId, onFbWin)
        insevent.registerInstanceLose(config.fbId, onFbLose)
    end
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.yongzheFight = function (actor, args)
    c2sFight(actor)
    return true
end

gmCmdHandlers.yongzheReward = function (actor, args)
    local reward_type = tonumber(args[1]) or 1
    local index = tonumber(args[2]) or 1
    local pack = LDataPack.allocPacket()
    LDataPack.writeChar(pack, reward_type)
    LDataPack.writeShort(pack, index)
    LDataPack.setPosition(pack, 0)
    c2sGetYongzheReward(actor, pack)
    return true
end

gmCmdHandlers.reachYongzhe = function (actor, args)
    local custom = tonumber(args[1])
    if not custom then return end
    local var = getActorVar(actor)
    if not var then return end
    if var.curId > custom then
        LActor.sendTipmsg(actor, "请注意，你设置的层数低于你当前挑战的层数！", ttScreenCenter)
    end
    var.curId = custom
    sendYongzheInfo(actor)
    return true
end

gmCmdHandlers.yongzheClear = function (actor, args)
    local var = System.getStaticVar()
    var.yongzhefuben = {}
    return true
end

gmCmdHandlers.yongzhePrint = function (actor, args)
    local sysVar = getSystemVar()
    for idx = 1, sysVar.firstMaxCustom do
        print("idx:", idx, "actorname:", sysVar.firstCustomInfo[idx] and sysVar.firstCustomInfo[idx].actorname or "nil")
    end
    return true
end
