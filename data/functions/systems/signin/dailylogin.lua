
--登录豪礼
module("dailylogin", package.seeall)

local function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end
    if not var.dailylogin then var.dailylogin = {} end
    if not var.dailylogin.id then var.dailylogin.id = 1 end
    if not var.dailylogin.loginday then var.dailylogin.loginday = 0 end
    if not var.dailylogin.status then var.dailylogin.status = 0 end
    return var.dailylogin
end


function s2cInfo(actor)
    local var = getActorVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuli, Protocol.sDailyFuli_Info)
    LDataPack.writeChar(npack, var.id)
    LDataPack.writeChar(npack, var.loginday)
    LDataPack.writeInt(npack, var.status)
    LDataPack.flush(npack)
end

function getReward(actor, pack)
    local index = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    if var.loginday == 0 then
        var.loginday = 1
    end
    local config = LoginGiftConfig[var.id][var.loginday][index]
    if not config then return end
    local svip = LActor.getSVipLevel(actor)
    if svip < config.sviplevel then
        return
    end
    if System.bitOPMask(var.status, index - 1) then
		return false
    end
    var.status = System.bitOpSetMask(var.status, index - 1, true)

    if not actoritem.checkEquipBagSpaceJob(actor, config.rewards) then
        return
    end
    actoritem.addItems(actor, config.rewards, "dailylogin rewards")

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuli, Protocol.sDailyFuli_GetRewards)
    LDataPack.writeInt(npack, var.status)
    LDataPack.flush(npack)
end


local function onLogin(actor)
    s2cInfo(actor)
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    var.loginday = var.loginday + 1
    if var.loginday > #LoginGiftConfig[var.id] then
        var.loginday = 1
        if var.id == 1 then
            var.id = 2
        end
    end
    var.status = 0
    if not login then
        s2cInfo(actor)
    end
end




actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Fuli, Protocol.cDailyFuli_GetReward, getReward)
