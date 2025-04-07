--一元抢购
module("yyqgsystem",package.seeall)

function getActorVar(actor, id)
    local var = LActor.getStaticVar(actor)
    if not var.yycg then var.yycg = {} end
    if not var.yycg.status then var.yycg.status = 0 end
    if not var.yycg.endtime then var.yycg.endtime = 0 end
    return var.yycg
end

function updateInfo(actor)
    local var = getActorVar(actor)
    local now = System.getNowTime()
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sYyqgCmd_Update)
    LDataPack.writeChar(npack, var.status)
    LDataPack.writeInt(npack, math.max(0, var.endtime - now))
    LDataPack.flush(npack)
end

local function sendMail(actor)
    if System.isCrossWarSrv() then return end
    local var = getActorVar(actor)
    if var.status ~= 1 then return end
    var.status = 2
    local actorid = LActor.getActorId(actor)
    local mail_data = {}
    mail_data.head = RechargeConstConfig.yyqghead
    mail_data.context = RechargeConstConfig.yyqgcontent
    mail_data.tAwardList = RechargeConstConfig.yyqgrewards
    mailsystem.sendMailById(actorid, mail_data)
end

function dispear(actor)
    local var = getActorVar(actor)
    if var.eid then
        var.eid = nil
        sendMail(actor)
        updateInfo(actor)
    end
end


function sendInfo(actor)
    local now = System.getNowTime()
    local var = getActorVar(actor)
    if var.endtime - now > 0 and var.status ~= 2 then
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sYyqgCmd_Info)
        LDataPack.writeChar(npack, var.status)
        LDataPack.writeInt(npack, var.endtime - now)
        LDataPack.flush(npack)
        var.eid = LActor.postScriptEventLite(actor, (var.endtime - now) * 1000, dispear)
    end
end

function buyYYQG(actor)
    local var = getActorVar(actor)
    var.status = 1    
    updateInfo(actor)
    rechargesystem.addVipExp(actor, RechargeConstConfig.yyqgyuanbao)
end

function getReward(actor)
    local var = getActorVar(actor)
    if var.status ~= 1 then return end
    if not actoritem.checkEquipBagSpaceJob(actor, RechargeConstConfig.yyqgrewards) then
        return
    end
    var.status = 2
    actoritem.addItems(actor, RechargeConstConfig.yyqgrewards, "yyqg")
    updateInfo(actor)
end

function yyqgisbuy(count)
    return RechargeConstConfig.yyqgyuanbao == count
end

function buy(actorid) 
    local actor = LActor.getActorById(actorid)
    if actor then
        buyYYQG(actor)
    else
        local npack = LDataPack.allocPacket()
        System.sendOffMsg(actorid, 0, OffMsgType_yyqg, npack)
    end
end

function OffMsgyyqg(actor, offmsg)
    buyYYQG(actor, count)
end

function onLogin(actor)
    local var = getActorVar(actor)
    if var.status == 1 and var.endtime <= System.getNowTime() then
        sendMail(actor)
    end
    sendInfo(actor)
end

function onCustomChange(actor, custom, oldcustom)
    local svip = LActor.getSVipLevel(actor)
    local var = getActorVar(actor)
    if RechargeConstConfig.yyqgcustom > oldcustom and RechargeConstConfig.yyqgcustom <= custom then
        var.endtime = RechargeConstConfig.yyqgshowtime * 60 + System.getNowTime()
        sendInfo(actor)
        var.eid = LActor.postScriptEventLite(actor, RechargeConstConfig.yyqgshowtime * 60 * 1000, dispear)
    end
end

local function init()    
    if System.isCrossWarSrv() then return end
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeCustomChange, onCustomChange)
    msgsystem.regHandle(OffMsgType_yyqg, OffMsgyyqg)
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cYyqgCmd_GetReward, getReward) 
end

table.insert(InitFnTable, init)

