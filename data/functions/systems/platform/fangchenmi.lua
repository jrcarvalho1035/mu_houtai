module("fangchenmi", package.seeall)

local function getActorVar(actor)
    if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.fangchenmi then var.fangchenmi = {} end
    if not var.fangchenmi.ischenmi then var.fangchenmi.ischenmi = 0 end --0非防沉迷，1防沉迷，2游客
    if not var.fangchenmi.chenmitime then var.fangchenmi.chenmitime = 0 end
    if not var.fangchenmi.eid then var.fangchenmi.eid = 0 end
    if not var.fangchenmi.eid1 then var.fangchenmi.eid1 = 0 end
	return var.fangchenmi
end

local function closeActor(actor)
    System.closeActor(actor)
end

local function kickFanchenmi()
    local actors = System.getOnlineActorList()
    if not actors then return end
    for i=1, #actors do
        local var = getActorVar(actors[i])
        if var.ischenmi == 1 then
            local pack = LDataPack.allocPacket(actors[i], 255, 11)
            LDataPack.writeByte(pack, 16)
            LDataPack.flush(pack)
            LActor.postScriptEventLite(actors[i], 1000, closeActor)
        end
    end
end

local function kickActor(actor)
    local pack = LDataPack.allocPacket(actor, 255, 11)
    LDataPack.writeByte(pack, 16)
    LDataPack.flush(pack)
    LActor.postScriptEventLite(actor, 1000, closeActor)
end

local function fiveMinutes(actor)
    local mail_data = {}
    mail_data.head = "防沉迷提示"
    mail_data.context = "您的账号还有5分钟即将被强制下线。"
    mail_data.tAwardList = {}
    mailsystem.sendMailById(LActor.getActorId(actor), mail_data)
end


function c2sFangChenmi(actor, pack)
    local var = getActorVar(actor)
    var.ischenmi = LDataPack.readByte(pack)
    var.chenmitime = LDataPack.readInt(pack)
    if var.ischenmi ~= 0 then
        if var.ischenmi == 1 and var.chenmitime >= 0 then
            local mail_data = {}
            mail_data.head = "防沉迷提示"
            mail_data.context = string.format("您的账号已被纳入防沉迷系统，法定节假日每日累计不得超过3小时，其他时间每日累计不得超过1.5小时。每日22点00分至次日8点00分不能登录游戏，请合理安排游戏时间。")
            mail_data.tAwardList = {}
            mailsystem.sendMailById(LActor.getActorId(actor),mail_data)
        end
        if var.chenmitime > 0 then
            if var.chenmitime > 300 then
                if var.eid1 ~= 0 then
                    LActor.cancelScriptEvent(actor, var.eid1)
                end
                var.eid1 = LActor.postScriptEventLite(actor, (var.chenmitime - 300) * 1000, fiveMinutes)
            end
            if var.eid ~= 0 then
                LActor.cancelScriptEvent(actor, var.eid)
            end
            var.eid = LActor.postScriptEventLite(actor, var.chenmitime * 1000, kickActor)
        elseif var.chenmitime ~= -1 then
            local pack = LDataPack.allocPacket(actor, 255, 11)
            LDataPack.writeByte(pack, 16)
            LDataPack.flush(pack)
            if var.eid ~= 0 then
                LActor.cancelScriptEvent(actor, var.eid)
            end
            var.eid = LActor.postScriptEventLite(actor, 1000, closeActor)
        end
    else
        if var.eid ~= 0 then
            LActor.cancelScriptEvent(actor, var.eid)
            var.eid = 0
        end
        if var.eid1 ~= 0 then
            LActor.cancelScriptEvent(actor, var.eid1)
            var.eid1 = 0
        end
    end
end

netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.sBaseCmd_FangChenmi, c2sFangChenmi)
_G.kickFanchenmi = kickFanchenmi
