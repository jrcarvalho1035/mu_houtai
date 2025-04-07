module("zerobuy", package.seeall)

local function getActorVar(actor, id)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end
    if not var.zerobuy then var.zerobuy = {} end
    if not var.zerobuy.status then var.zerobuy.status = {} end 
    if not var.zerobuy.buytime then var.zerobuy.buytime = {} end 
	return var.zerobuy
end



function s2cInfo(actor)
    local var = getActorVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sJinzhuanCmd_ZeroInfo)
    LDataPack.writeChar(npack, #ZeroBuyConfig)
    local now = System.getNowTime()
    for k,v in ipairs(ZeroBuyConfig) do
        LDataPack.writeChar(npack, var.status[k] or 0)
        LDataPack.writeInt(npack, math.max(0, (var.buytime[k] or 0) - now))
    end
	LDataPack.flush(npack)
end


function c2sBuy(actor, pack)
    local index = LDataPack.readChar(pack)
    local config = ZeroBuyConfig[index]
    if not config then return end
    local var = getActorVar(actor)
    if (var.status[index] or 0) ~= 0 then return end
    if not actoritem.checkItem(actor, NumericType_Diamond, config.need) then
        return
    end
    local now = System.getNowTime() 
    actoritem.reduceItem(actor, NumericType_Diamond, config.need, "jinzhuan zero buy")
    var.status[index] = 1
    var.buytime[index] = now + config.returnday*86400
    actoritem.addItemsByMail(actor, config.item, "jinzhuan zero buy")
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sJinzhuanCmd_ZeroBuy)
    LDataPack.writeChar(npack, index)
    LDataPack.writeInt(npack, math.max(0, (var.buytime[index] or 0) - now))
	LDataPack.flush(npack)
end

function c2sGet(actor, pack)
    local index = LDataPack.readChar(pack)
    local config = ZeroBuyConfig[index]
    if not config then return end
    local var = getActorVar(actor)
    if (var.status[index] or 0) ~= 1 then return end
    if (var.buytime[index] or 0) - System.getNowTime() > 0 then return end
    var.status[index] = 2
    actoritem.addItem(actor, NumericType_Diamond, config.need)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sJinzhuanCmd_ZeroGetRet)
    LDataPack.writeChar(npack, index)
	LDataPack.flush(npack)
end


function onLogin(actor)
    s2cInfo(actor)
end


actorevent.reg(aeUserLogin, onLogin)
local function init()
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cJinzhuanCmd_ZeroBuy, c2sBuy)
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cJinzhuanCmd_ZeroGet, c2sGet)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.zero = function (actor, args)
    local var = getActorVar(actor)
    for i=1,3 do
        var.status[i] = 1
        var.buytime[i] = 0
    end
    s2cInfo(actor)
end


