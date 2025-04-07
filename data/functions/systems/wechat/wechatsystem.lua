--微信事件处理
module("wechatsystem", package.seeall)

WXCmdType = {
    WXShare = 1, --微信分享
    WXInvite = 2, --微信邀请
    WXZhuangsheng = 3, --微信转生
    WXSvip = 4, --微信充值Svip
}

WXMsgFuncs = {} --各个事件处理函数

WXAllowUserPF = {
    --"",
    --"zy",
    "qqxyx",
    "wxxyx",
}

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then
        return nil
    end
    if not var.wechat then
        var.wechat = {
            shareCount = 0,
            shareCD = 0,
            inviteCount = 0,
        }
    end
    return var.wechat
end

--注册各个事件处理函数
local function initFuncs()
    WXMsgFuncs = {
        [1] = WXShareEvent, --微信分享事件
        [2] = WXInviteEvent, --微信邀请事件
        [3] = WXZhuangshengEvent, --微信转生事件
        [4] = WXSvipEvent, --微信充值Svip事件
    }
end

--用户是否属于微信平台
function isAllowOpenUser(actor)
    local pf = LActor.getPf(actor)
    if not utils.checkTableValue(WXAllowUserPF, pf) then
        print("user isn't allowed actorid =", LActor.getActorId(actor), "pf =", pf)
        return false
    end
    return true
end

--处理gmDC发来的消息
--分享是前端发过来的,在wechatshare中处理
function wxCmdMsg(actorid, msgType, msgParam)
    local actor = LActor.getActorById(actorid)
    if actor then
        wxTaskEvent(actor, msgType, msgParam)
    else
        local pack = LDataPack.allocPacket()
        LDataPack.writeInt(pack, msgType)
        LDataPack.writeInt(pack, msgParam or 0)
        System.sendOffMsg(actorid, 0, OffMsgType_WXCmdMsg, pack)
        print("sendOffMsg: msg = OffMsgType_WXCmdMsg, msgType =", msgType, "msgParam =", msgParam)
    end
end

function wxTaskEvent(actor, msgType, msgParam)
    if not isAllowOpenUser(actor) then return end
    local func = WXMsgFuncs[msgType]
    if not func then
        print("func is nil msgType = ", msgType)
        return
    end
    print("wxTaskEvent: actorid =", LActor.getActorId(actor), "msgType =", msgType, "msgParam =", msgParam)
    func(actor, msgParam)
end

--微信分享事件
function WXShareEvent(actor)
    actorevent.onEvent(actor, aeWXShare, 1)
end

--微信邀请事件
function WXInviteEvent(actor)
    actorevent.onEvent(actor, aeWXInvite, 1)
end

--微信转生事件
function WXZhuangshengEvent(actor, param)
    actorevent.onEvent(actor, aeWXZhuangsheng, param, 1)
end

--微信充值Svip事件
function WXSvipEvent(actor, param)
    actorevent.onEvent(actor, aeWXSvip, param, 1)
end

local function updateWXTask(actor, taskType, param, value)
    wechattask.updateWXTaskValue(actor, taskType, param, value)
end

function sendWeChatInfo(actor)
    s2cInviteInfo(actor)
    s2cShareInfo(actor)
end

----------------------------------------------------------------------------------
--协议处理

--88-15,分享成功次数
function s2cShareInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wechat, Protocol.sWechatCmd_Share)
    if not pack then return end
    LDataPack.writeChar(pack, var.shareCount)
    LDataPack.flush(pack)
end

--88-16,邀请成功次数
function s2cInviteInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wechat, Protocol.sWechatCmd_Invite)
    if not pack then return end
    LDataPack.writeChar(pack, var.inviteCount)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function onLogin(actor)
    sendWeChatInfo(actor)
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    if not var then return end
    var.inviteCount = 0
    var.shareCount = 0
    if not login then
        sendWeChatInfo(actor)
    end
end

local function onZhuansheng(actor, level, oldLevel)
    if not isAllowOpenUser(actor) then return end
    local temStr = "http://%s/%s/api?m=player&fn=gmGetInviteInfo&invited_account=%s&actor_id=%d&type=%d&value=%d"
    local webhost, webport = System.getWebServer()
    local openid = LActor.getAccountName(actor)
    local actorid = LActor.getActorId(actor)
    local url = string.format(temStr, webhost, LActor.getPf(actor), openid, actorid, WXCmdType.WXZhuangsheng, level)
    print("wechatsystem.onZhuansheng url =", url)
    sendMsgToWeb(url)
end

local function onSVipLevel(actor, level, oldLevel)
    if not isAllowOpenUser(actor) then return end
    local temStr = "http://%s/%s/api?m=player&fn=gmGetInviteInfo&invited_account=%s&actor_id=%d&type=%d&value=%d"
    local webhost, webport = System.getWebServer()
    local openid = LActor.getAccountName(actor)
    local actorid = LActor.getActorId(actor)
    local cmdType = WXCmdType.WXSvip
    for i = oldLevel + 1, level do
        local url = string.format(temStr, webhost, LActor.getPf(actor), openid, actorid, cmdType, i)
        print("wechatsystem.onSVipLevel url =", url)
        sendMsgToWeb(url)
    end
end

local function OffMsgWXCmdMsg(actor, offmsg)
    local msgType = LDataPack.readInt(offmsg)
    local msgParam = LDataPack.readInt(offmsg)
    wxTaskEvent(actor, msgType, msgParam)
end

local function onWXShare(actor)
    local var = getActorVar(actor)
    if not var then return end
    if var.shareCount >= WeChatConstConfig.maxShareCount then return end
    local now = System.getNowTime()
    if now < var.shareCD then return end
    
    var.shareCount = var.shareCount + 1
    var.shareCD = now + WeChatConstConfig.cdTime
    s2cShareInfo(actor)
    
    local record = taskevent.getRecord(actor)
    local count = record[taskcommon.taskType.emWXShare] or 0
    count = count + 1
    record[taskcommon.taskType.emWXShare] = count
    updateWXTask(actor, taskcommon.taskType.emWXShare, 0, count)
    updateWXTask(actor, taskcommon.taskType.emWXShareAdd, 0, 1)
end

local function onWXInvite(actor)
    --微信邀请事件
    local var = getActorVar(actor)
    if not var then return end
    if var.inviteCount >= WeChatConstConfig.maxInviteCount then return end
    var.inviteCount = var.inviteCount + 1
    s2cInviteInfo(actor)
    
    local record = taskevent.getRecord(actor)
    local count = record[taskcommon.taskType.emWXInvite] or 0
    count = count + 1
    record[taskcommon.taskType.emWXInvite] = count
    updateWXTask(actor, taskcommon.taskType.emWXInvite, 0, count)
    updateWXTask(actor, taskcommon.taskType.emWXInviteAdd, 0, 1)
end

local function onWXZhuangsheng(actor, param)
    --微信转生事件
    local record = taskevent.getRecord(actor)
    if not record[taskcommon.taskType.emWXZhuangshenglv] then
        record[taskcommon.taskType.emWXZhuangshenglv] = {}
    end
    local count = record[taskcommon.taskType.emWXZhuangshenglv][param] or 0
    count = count + 1
    record[taskcommon.taskType.emWXZhuangshenglv][param] = count
    updateWXTask(actor, taskcommon.taskType.emWXZhuangshenglv, param, count)
    updateWXTask(actor, taskcommon.taskType.emWXZhuangshenglvAdd, param, 1)
end

local function onWXSvip(actor, param)
    --微信充值Svip事件
    local record = taskevent.getRecord(actor)
    if not record[taskcommon.taskType.emWXSViplv] then
        record[taskcommon.taskType.emWXSViplv] = {}
    end
    local count = record[taskcommon.taskType.emWXSViplv][param] or 0
    count = count + 1
    record[taskcommon.taskType.emWXSViplv][param] = count
    updateWXTask(actor, taskcommon.taskType.emWXSViplv, param, count)
    updateWXTask(actor, taskcommon.taskType.emWXSViplvAdd, param, 1)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    actorevent.reg(aeZhuansheng, onZhuansheng)--玩家转生事件
    actorevent.reg(aeSVipLevel, onSVipLevel)--玩家提升Svip事件
    
    if System.isCrossWarSrv() then return end
    initFuncs()
    
    actorevent.reg(aeWXShare, onWXShare)--微信分享事件
    actorevent.reg(aeWXInvite, onWXInvite)--微信邀请事件
    actorevent.reg(aeWXZhuangsheng, onWXZhuangsheng)--微信转生事件
    actorevent.reg(aeWXSvip, onWXSvip)--微信充值Svip事件
    
    msgsystem.regHandle(OffMsgType_WXCmdMsg, OffMsgWXCmdMsg)--离线消息
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.wxShare = function (actor, args)
    local value = tonumber(args[1]) or 1
    local actorid = tonumber(args[2]) or LActor.getActorId(actor)
    wxCmdMsg(actorid, 1, 0, value)
end

gmCmdHandlers.wxInvite = function (actor, args)
    local value = tonumber(args[1]) or 1
    local actorid = tonumber(args[2]) or LActor.getActorId(actor)
    wxCmdMsg(actorid, 2, 0, value)
end

gmCmdHandlers.wxZhuangsheng = function (actor, args)
    local param = tonumber(args[1]) or 10101
    local value = tonumber(args[2]) or 1
    local actorid = tonumber(args[3]) or LActor.getActorId(actor)
    wxCmdMsg(actorid, 3, param, value)
end

gmCmdHandlers.wxSvip = function (actor, args)
    local param = tonumber(args[1]) or 1
    local value = tonumber(args[2]) or 1
    local actorid = tonumber(args[3]) or LActor.getActorId(actor)
    wxCmdMsg(actorid, 4, param, value)
end

gmCmdHandlers.wxShareClearCD = function (actor, args)
    local var = getActorVar(actor)
    var.shareCD = 0
end

gmCmdHandlers.wxFuncPrint = function (actor, args)
    utils.printTable(WXMsgFuncs)
end

