-- @version	1.0
-- @author	qianmeng
-- @date	2017-9-1 11:11:57.
-- @system	梅林宝箱

module( "merlintreasure", package.seeall )
require("merlin.treasure")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.treasureMerlin then 
		var.treasureMerlin = {} 
	end
	return var.treasureMerlin
end

function acceptTreasure(actor)
	local var = getActorVar(actor)
	if (var.dropId or 0) <= 0 then return end

	local items = {}
	for i=1, #var.rewards do
		local v = var.rewards[i]
		table.insert(items, {type=v.type, id=v.id, count=v.count})
	end

	actoritem.addItems(actor, items, "treasure accept")
	var.dropId = 0
	var.times = 0
	var.rewards = {}
end

---------------------------------------------------------------------------------
--开梅林宝箱
function c2sTreasureOpen(actor, packet)
	local itemId = LDataPack.readInt(packet)
	local conf = TreasurelConfig[itemId]
	if not conf then return end

	if not actoritem.checkItem(actor, itemId, 1) then
		return
	end
	actoritem.reduceItem(actor, itemId, 1, "treasure open")

	local rewards = drop.dropGroup(conf.dropId)
	local var = getActorVar(actor)
	var.dropId = conf.dropId
	var.times = 1
	var.rewards = {}
	for k, v in ipairs(rewards) do
		var.rewards[k] = v
	end
	s2cTreasureRewards(actor)
end

--宝箱奖励列表
function s2cTreasureRewards(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Merlin, Protocol.sTreasure_Info)
	LDataPack.writeChar(pack, #var.rewards)
	for i = 1, #var.rewards do
		LDataPack.writeInt(pack, var.rewards[i].type)
		LDataPack.writeInt(pack, var.rewards[i].id)
		LDataPack.writeInt(pack, var.rewards[i].count)
	end
	LDataPack.writeShort(pack, var.times)
	LDataPack.flush(pack)
end

--重开梅林宝箱
function c2sTreasureAgain(actor, packet)
	local var = getActorVar(actor)
	if (var.dropId or 0) <= 0 then return end --未开启过梅林宝箱

	local leng = #BookCommonConfig[1].openPrice
	local price = var.times <= leng and BookCommonConfig[1].openPrice[var.times] or BookCommonConfig[1].openPrice[leng]

	if not actoritem.checkItem(actor, NumericType_YuanBao, price) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, price, "treasure again")

	var.times = var.times + 1
	var.rewards = {}
	local rewards = drop.dropGroup(var.dropId)
	for k, v in ipairs(rewards) do
		var.rewards[k] = v
	end
	s2cTreasureRewards(actor)
end

--接受梅林宝箱奖励
function c2sTreasureAccept(actor, packet)
	acceptTreasure(actor)
end

--离开游戏时没拿宝箱就自动拿掉
function onLogout(actor)
	acceptTreasure(actor)
end

actorevent.reg(aeUserLogout, onLogout)
netmsgdispatcher.reg(Protocol.CMD_Merlin, Protocol.cTreasure_Open, c2sTreasureOpen)
netmsgdispatcher.reg(Protocol.CMD_Merlin, Protocol.cTreasure_Again, c2sTreasureAgain)
netmsgdispatcher.reg(Protocol.CMD_Merlin, Protocol.cTreasure_Accept, c2sTreasureAccept)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.treasureopen = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, tonumber(args[1]))
	LDataPack.setPosition(pack, 0)
	c2sTreasureOpen(actor, pack)
end

gmCmdHandlers.treasureagain = function (actor, args)
	c2sTreasureAgain(actor)
end

gmCmdHandlers.treasureaccept = function (actor, args)
	c2sTreasureAccept(actor)
end
