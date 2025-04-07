--主角光环
module("halosystem", package.seeall)

local autoSystemId = {
    actorexp.LimitTp.huanshoufb,
    actorexp.LimitTp.huanshoucross,
}

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    
    if not var.halo then
        var.halo = {
            status = 0,
            auto = {},
        }
    end
    return var.halo
end

local function calcAttr(actor, calc)
    local var = getActorVar(actor)
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Halo)
    attr:Reset()
    if var.status == 1 then
        for i, v in ipairs(HaloConfig.attrs) do
            attr:Set(v.type, v.value)
        end
        attr:SetExtraPower(HaloConfig.power)
    end
    if calc then
        LActor.reCalcAttr(actor)
    end
end

local function getHaloDailyReward()
    local openday = System.getOpenServerDay()
    local count = 0
    for i, conf in ipairs(HaloConfig.dailyRewards) do
        if openday >= conf.day then
            count = conf.count
        else
            break
        end
    end
    if count <= 0 then return end
    return {{type = 0, id = NumericType_Diamond, count = count}}
end

--外部接口,检查主角光环是否购买
function isBuyHalo(actor)
    local var = getActorVar(actor)
    if not var then return end
    return var.status == 1
end

--外部接口,sdk调用
function buy(actorid)
    local actor = LActor.getActorById(actorid)
    if actor then
        buyHalo(actor)
    else
        local npack = LDataPack.allocPacket()
        System.sendOffMsg(actorid, 0, OffMsgType_Halo, npack)
    end
end

--购买主角光环
function buyHalo(actor)
    local var = getActorVar(actor)
    if not var then return end
    if var.status == 1 then return end
    
    var.status = 1
    rechargesystem.addVipExp(actor, HaloConfig.money)
    actoritem.addItems(actor, HaloConfig.rewards, "halo buy")
    titlesystem.addTitle(actor, HaloConfig.title, true)
    sendHaloDailyMail(LActor.getActorId(actor))
    yuansufuben.changeYSPoint(actor, YSFBCommonConfig.haloPoint, "halo buy")
    shenjifuben.changeSJPoint(actor, SJFBCommonConfig.haloPoint, "halo buy")
    
    calcAttr(actor, true)
    sendHaloData(actor)
    utils.logCounter(actor, "halo buy")
    broadCastNotice(noticesystem.NTP.haleopen, LActor.getName(actor))
end

function haloSetAuto(actor, systemId, status)
    if status ~= 0 and status ~= 1 then return end--数据非法，状态记录只能是0和1
    if not utils.checkTableValue(autoSystemId, systemId) then return end
    if not isBuyHalo(actor) then return end
    
    local var = getActorVar(actor)
    if not var then return end
    var.auto[systemId] = status
    s2cHaloSetAuto(actor, systemId, status)
end

--发送每日邮件
function sendHaloDailyMail(actorid, serverid)
    local dailyReward = getHaloDailyReward()
    if not dailyReward then return end
    local mail_data = {
        head = HaloConfig.mailHead,
        context = HaloConfig.mailContext,
        tAwardList = dailyReward,
    }
    mailsystem.sendMailById(actorid, mail_data, serverid)
    print("sendHaloDailyMail actorid =", actorid)
end

----------------------------------------------------------------------------------
--协议处理
--27-100 主角光环-基础信息
function sendHaloData(actor)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_HaloData)
    LDataPack.writeChar(pack, var.status)
    LDataPack.writeChar(pack, #autoSystemId)
    for _, systemId in ipairs(autoSystemId) do
        LDataPack.writeShort(pack, systemId)
        LDataPack.writeChar(pack, var.auto[systemId] or 0)
    end
    LDataPack.flush(pack)
end

--27-101 主角光环-设置自动挑战状态
local function c2sHaloSetAuto(actor, pack)
    local systemId = LDataPack.readShort(pack)
    local status = LDataPack.readChar(pack)
    haloSetAuto(actor, systemId, status)
end

--27-101 主角光环-返回自动挑战状态
function s2cHaloSetAuto(actor, systemId, status)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_HaloSetAuto)
    if not pack then return end
    
    LDataPack.writeShort(pack, systemId)
    LDataPack.writeChar(pack, status)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function OffMsgHalo(actor, offmsg)
    print(string.format("OffMsgHalo actorid:%d ", LActor.getActorId(actor)))
    buyHalo(actor)
end

local function onInit(actor)
    calcAttr(actor, false)
end

local function onLogin(actor)
    sendHaloData(actor)
end

local function onNewDay(actor)
    local var = getActorVar(actor)
    if not var then return end
    if var.status ~= 1 then return end
    sendHaloDailyMail(LActor.getActorId(actor), LActor.getServerId(actor))
end

----------------------------------------------------------------------------------
--初始化
local function init()
    msgsystem.regHandle(OffMsgType_Halo, OffMsgHalo)
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_HaloSetAuto, c2sHaloSetAuto)
end
table.insert(InitFnTable, init)

