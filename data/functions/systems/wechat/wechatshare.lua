--微信分享
module("wechatshare", package.seeall)

function sendMsgWxShare(actor)
    local actorid = LActor.getActorId(actor)
    wechatsystem.wxCmdMsg(actorid, wechatsystem.WXCmdType.WXShare)
end

----------------------------------------------------------------------------------
--协议处理

--88-15,分享成功
function c2sShare(actor)
    sendMsgWxShare(actor)
end

----------------------------------------------------------------------------------
--事件处理

----------------------------------------------------------------------------------
--初始化
local function init()
    if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Wechat, Protocol.cWechatCmd_Share, c2sShare)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.wxSendShare = function (actor, args)
    sendMsgWxShare(actor)
end

