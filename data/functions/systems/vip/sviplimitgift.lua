-- @system  vip

module("sviplimitgift", package.seeall)

--所需数据一部分在ActorBasicData中
-- svip level
-- vip level

local function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return nil end

	if var.sviplimitgift == nil then var.sviplimitgift = {} end
	if not var.sviplimitgift.count then var.sviplimitgift.count = 0 end
	if not var.sviplimitgift.info then var.sviplimitgift.info = {} end
	return var.sviplimitgift
end

--限时礼包购买
function c2sBuy(actor, pack)
	local var = getActorVar(actor)	
	local id = LDataPack.readChar(pack)
	local index = 0
	for i=1, var.count do
		if var.info[i].id == id then
			index = i
			break
		end
	end
	if index == 0 then return end
	local config = SVipLimitGiftConfig[id][var.info[index].svip]
	if not config then
		return
	end
	local svip = LActor.getSVipLevel(actor)
	if svip < var.info[index].svip then
		return
	end
	if not actoritem.checkItem(actor, NumericType_YuanBao, config.needyuanbao) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, config.needyuanbao, "svip limit gift buy")
	actoritem.addItems(actor, config.rewards, "svip limit gift buy")
	if not SVipLimitGiftConfig[id][var.info[index].svip + 1] then
		updateInfo(actor, 2, index, id)
		giftdisappear(actor, id)
	else		
		var.info[index].svip = var.info[index].svip + 1	
		updateInfo(actor, 3, index)
	end
	
end

function s2cLimitInfo(actor)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVimCmd_SVipLimitGiftInfo)
	if npack == nil then return end
	local now = System.getNowTime()
	LDataPack.writeChar(npack, var.count)
	for i=1, var.count do
		LDataPack.writeChar(npack, var.info[i].id)
		LDataPack.writeChar(npack, var.info[i].svip)
		LDataPack.writeInt(npack, math.max(0, SVipLimitGiftConfig[var.info[i].id][0].showtime * 60 - ((now - var.info[i].starttime) + var.info[i].keeptime)))
	end
	LDataPack.flush(npack)
end

function updateInfo(actor, status, index, id)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVimCmd_SVipLimitGiftUpdate)
	if npack == nil then return end
	local now = System.getNowTime()
	LDataPack.writeChar(npack, status)
	if id then
		LDataPack.writeChar(npack, id)
		LDataPack.writeChar(npack, 0)
		LDataPack.writeInt(npack, 0)
	else
		LDataPack.writeChar(npack, var.info[index].id)
		LDataPack.writeChar(npack, var.info[index].svip)
		LDataPack.writeInt(npack, math.max(0, SVipLimitGiftConfig[var.info[index].id][0].showtime * 60 - ((now - var.info[index].starttime) + var.info[index].keeptime)))
	end
	LDataPack.flush(npack)
end

function giftdisappear(actor, id)
	local var = getActorVar(actor)
	local index = 0
	for i=1, var.count do
		if var.info[i].id == id then
			index = i
		end
	end
	if index == 0 then
		return
	end
	if index == var.count or not var.info[index].eid then
		var.info[index] = {}
	else
		for i=index, var.count - 1 do
			var.info[i].id = var.info[i+1].id
			var.info[i].svip = var.info[i+1].svip
			var.info[i].starttime = var.info[i+1].starttime
			var.info[i].eid = var.info[i+1].eid
		end
		var.info[var.count] = {}
	end	
	var.count = var.count - 1

	updateInfo(actor, 2, nil, id)
end

local function onLevelUp(actor, level, oldlevel)
	for k,v in pairs(SVipLimitGiftConfig) do
		if level >= v[0].level and oldlevel < v[0].level then
			local var = getActorVar(actor)
			var.count = var.count + 1
			var.info[var.count] = {}
			var.info[var.count].id = k
			var.info[var.count].svip = 0
			var.info[var.count].starttime = System.getNowTime()
			var.info[var.count].keeptime = 0
			updateInfo(actor, 1, var.count)
			var.info[var.count].eid = LActor.postScriptEventLite(actor, v[0].showtime * 60 * 1000, giftdisappear, k)
		end
	end
end

local function onLogin(actor)	
	local var = getActorVar(actor)
	local now = System.getNowTime()
	for i=1, var.count do
		var.info[i].starttime = now
		var.info[var.count].eid = LActor.postScriptEventLite(actor, math.max(0, (SVipLimitGiftConfig[var.info[i].id][0].showtime*60 - var.info[i].keeptime)) * 1000, giftdisappear, var.info[i].id)
	end
	s2cLimitInfo(actor)
end

function onLogout(actor)
	local var = getActorVar(actor)
	local now = System.getNowTime()
	for i=1, var.count do
		var.info[i].keeptime = var.info[i].keeptime + now - var.info[i].starttime
	end
end

--注册事件
actorevent.reg(aeUserLogout, onLogout)
actorevent.reg(aeLevel, onLevelUp)
actorevent.reg(aeUserLogin, onLogin)

local function init()
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Vip, Protocol.cVimCmd_SVipLimitGiftBuy, c2sBuy)
end

table.insert(InitFnTable, init)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.setVip = function (actor, args)
	local vip = tonumber(args[1])
	if not VipConfig[vip] then return false end
	LActor.setVipLevel(actor, vip)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_VipData)
	if npack == nil then return end
	LDataPack.writeChar(npack, vip)
	LDataPack.writeChar(npack, 2)
	LDataPack.flush(npack)
end
