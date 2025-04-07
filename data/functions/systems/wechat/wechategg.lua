--微信砸蛋
module("wechategg", package.seeall)

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then
        return nil
    end
    if not var.wechategg then
        var.wechategg = {
            freeCount = 0,
            eggCount = 0,
            eggs = {
            },
        }
    end
    return var.wechategg
end

local function eggIsOpen()
    local openday = System.getOpenServerDay()
    if openday > WeChatConstConfig.keepDay then
        print("not in act time openday =", openday, "keepDay = ", WeChatConstConfig.keepDay)
        return false
    end
    return true
end

function GetEggReward(actor, pos)
    if not wechatsystem.isAllowOpenUser(actor) then return end
    local openday = System.getOpenServerDay()
    if not WeChatEggConfig[openday] then
        print("not config openday =", openday)
        return
    end
    
    if pos > #WeChatEggConfig[openday] or pos <= 0 then
        print("no pos match pos =", pos)
        return
    end
    
    local var = getActorVar(actor)
    if not var then return end
    
    if var.eggs[pos] then
        print("pos is done pos =", pos)
        return
    end
    
    local index = var.eggCount + 1
    local config = WeChatEggConfig[openday][index]
    if not config then
        print("not config index")
        return
    end
    
    if var.freeCount <= 0 then
        needCount = WeChatConstConfig.needCount
        if not actoritem.checkItem(actor, NumericType_YuanBao, WeChatConstConfig.needCount) then return end
        actoritem.reduceItem(actor, NumericType_YuanBao, WeChatConstConfig.needCount, "wechatEgg")
    else
        var.freeCount = var.freeCount - 1
    end
    
    var.eggs[pos] = {
        itemid = config.itemid,
        count = config.count
    }
    var.eggCount = index
    
    actoritem.addItem(actor, config.itemid, config.count, "wechatEgg", 1)
    s2cGetEggReward(actor, pos, config.itemid, config.count)
    
    if config.needNotice ~= 0 then
        noticesystem.broadCastNotice(noticesystem.NTP.wxegg, LActor.getName(actor), utils.getItemName(config.itemid))
    end
end

----------------------------------------------------------------------------------
--协议处理

--88-8,信息
function s2cWXEggInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local openday = System.getOpenServerDay()
    local config = WeChatEggConfig[openday]
    if not config then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wechat, Protocol.sWechatCmd_EggInfo)
    if not pack then return end
    LDataPack.writeShort(pack, openday)
    LDataPack.writeChar(pack, var.freeCount)
    LDataPack.writeChar(pack, var.eggCount)
    for i in ipairs(config) do
        if var.eggs[i] then
            LDataPack.writeChar(pack, i)
            LDataPack.writeInt(pack, var.eggs[i].itemid)
            LDataPack.writeInt(pack, var.eggs[i].count)
        end
    end
    LDataPack.flush(pack)
end

--88-9,请求领奖
local function c2sGetEggReward(actor, packet)
    local pos = LDataPack.readInt(packet)
    GetEggReward(actor, pos)
end

--88-9,领奖返回
function s2cGetEggReward(actor, pos, itemid, count)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wechat, Protocol.sWechatCmd_EggGetReward)
    if not pack then return end
    LDataPack.writeChar(pack, var.freeCount)
    LDataPack.writeChar(pack, pos)
    LDataPack.writeInt(pack, itemid)
    LDataPack.writeInt(pack, count)
    LDataPack.flush(pack)
end

--88-11,更新免费次数
function s2cEggUpdate(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wechat, Protocol.sWechatCmd_EggUpdate)
    if not pack then return end
    LDataPack.writeChar(pack, var.freeCount)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function onLogin(actor)
    s2cWXEggInfo(actor)
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    if not var then return end
    var.freeCount = 0
    var.eggCount = 0
    var.eggs = {}
    if not login then
        s2cWXEggInfo(actor)
    end
end

local function onWXInvite(actor)
    if not eggIsOpen() then return end
    local var = getActorVar(actor)
    if not var then return end
    var.freeCount = var.freeCount + 1
    s2cEggUpdate(actor)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    actorevent.reg(aeWXInvite, onWXInvite)
    
    if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Wechat, Protocol.cWechatCmd_EggGetReward, c2sGetEggReward)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.wxEggAdd = function (actor, args)
    local var = getActorVar(actor)
    var.freeCount = var.freeCount + (tonumber(args[1]) or 1)
    s2cWXEggInfo(actor)
end

gmCmdHandlers.wxEggGet = function (actor, args)
    local pos = tonumber(args[1]) or 1
    GetEggReward(actor, pos)
end

gmCmdHandlers.wxEggClear = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.wechategg = nil
    s2cWXEggInfo(actor)
end

gmCmdHandlers.wxEggNotice = function (actor, args)
    noticesystem.broadCastNotice(noticesystem.NTP.wxegg, "测试玩家", "测试大奖")
end

