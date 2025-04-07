--微信收藏
module("wechatcollect", package.seeall)

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then
        return nil
    end
    if not var.wechatcollect then
        var.wechatcollect = {
            status = 0
        }
    end
    return var.wechatcollect
end

function sendWXCollectMail(actor)
    --if not wechatsystem.isAllowOpenUser(actor) then return end
    local var = getActorVar(actor)
    if not var then return end
    if var.status == 1 then return end
    
    var.status = 1
    local mailData = {
        head = WeChatConstConfig.collectHead,
        context = WeChatConstConfig.collectContext,
        tAwardList = WeChatConstConfig.collectReward
    }
    mailsystem.sendMailById(LActor.getActorId(actor), mailData, LActor.getServerId(actor))
    s2cCollectInfo(actor)
end

----------------------------------------------------------------------------------
--协议处理

--88-13,请求领奖
function c2sGetCollectReward(actor)
    sendWXCollectMail(actor)
end

function s2cCollectInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wechat, Protocol.sWechatCmd_CollectInfo)
    if not pack then return end
    LDataPack.writeChar(pack, var.status or 0)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function onLogin(actor)
    s2cCollectInfo(actor)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    if System.isCrossWarSrv() then return end

    actorevent.reg(aeUserLogin, onLogin)

    netmsgdispatcher.reg(Protocol.CMD_Wechat, Protocol.cWechatCmd_GetCollectReward, c2sGetCollectReward)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.wxGetCollect = function (actor, args)
    sendWXCollectMail(actor)
end

