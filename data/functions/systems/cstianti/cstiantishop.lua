module("cstiantishop", package.seeall)
--跨服天梯兑换商店

function getActorVar(actor)
	if not System.isCommSrv() then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.csttshop then
		var.csttshop = {
			record = {} --记录每个道具兑换次数
		}
	end
	return var.csttshop
end

function clearActorVar(actor, needSync)
	local var = getActorVar(actor)
	var.record = {}
	if needSync then
		s2cShopInfo(actor)
	end
end
-----------------------------------------------------------------------------------------------
function s2cShopInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsTianti_ShopInfo)
	if not pack then return end

	local var = getActorVar(actor)
	local shopvar = var.record
	LDataPack.writeChar(pack, #CsttShopConfig)
	for id, v in ipairs(CsttShopConfig) do
		LDataPack.writeChar(pack, id)
		LDataPack.writeChar(pack, shopvar[id] or 0)
	end
	LDataPack.flush(pack)
end

function c2sExchange(actor, packet)
	local id = LDataPack.readChar(packet)
	local conf = CsttShopConfig[id]
	if not conf then return end

	local var = getActorVar(actor)
	if not var then return end

	local record = var.record
	local buyCnt = record[id] or 0

	if conf.time ~= 0 and buyCnt >= conf.time then
		return
	end
	if not actoritem.checkItem(actor, NumericType_CSTTHonour, conf.cost) then
		return
	end
	actoritem.reduceItem(actor, NumericType_CSTTHonour, conf.cost, "cstiantishop")

	record[id] = buyCnt + 1
	actoritem.addItem(actor, conf.item.id, conf.item.count, "cstiantishop")
	s2cShopInfo(actor)
end

local function onLogin(actor)
	if not System.isCommSrv() then return end
	s2cShopInfo(actor)
end

actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsTianti_ShopBuy, c2sExchange)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.csttshop = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sExchange(actor, pack)
	return true
end
