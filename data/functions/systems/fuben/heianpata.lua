-- @version 1.0
-- @author  qianmeng
-- @date    2017-2-6 21:14:25.
-- @system  黑暗爬塔

module("heianpata", package.seeall)
require("scene.heianfuben")
require("scene.heianfubenbase")


function getActorVar(actor)
	if not actor then return end

	local var = LActor.getStaticVar(actor)
	if not var then return end

	if not var.heianfuben then
		var.heianfuben = {}
	end
	local heianfuben = var.heianfuben
	if not heianfuben.curId then heianfuben.curId = 1 end --当前正在挑战的副本
	if not heianfuben.saodangTime then heianfuben.saodangTime = 0 end	--扫荡结束时间
	if not heianfuben.saodangCount then heianfuben.saodangCount = 1 end --今天已扫荡的次数
	if not heianfuben.buyCount then heianfuben.buyCount = 0 end			--今天已购买的扫荡次数

	return heianfuben	
end

function getHeianFloor(actor)
	local var = getActorVar(actor)
	return var.curId - 1
end

function onFbWin(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then return end --胜利的 时候不可能找不到吧
	local var = getActorVar(actor)
	if not var then return end

	local config = HeianfbConfig[var.curId]
	if not config then return end

	if ins.id ~= config.fbid then print("fbid error   "..ins.id.." "..config.fbid) return end

	actorevent.onEvent(actor,aeHeianFuben, var.curId) --curId在+1前发
	var.curId = var.curId + 1
	local items = actoritem.mergeItems(config.normalAwards, config.saodangAwards)--首通奖励+扫荡奖励
	instancesystem.setInsRewards(ins, actor, items)
	slim.heianFuben(actor, var.curId+1, true) --发送下一个怪物的UI信息
	sendHeianInfo(actor)
	utils.rankfunc.updateRankingList(actor, var.curId - 1, RankingType_Heian)
end

function onFbLose(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then return end

	instancesystem.setInsRewards(ins, actor, nil)
end

function onLogin(actor)
	local var = getActorVar(actor)
	if not var then return end

	slim.heianFuben(actor, var.curId)
	if var.saodangTime > 0 and var.saodangTime <= System.getNowTime() and HeianfbConfig[var.saodangId] then
		local aid = LActor.getActorId(actor)
		saodangFuben(nil, aid) --给在离线时产生的扫荡奖励
	else
		sendHeianInfo(actor)
	end
	utils.rankfunc.updateRankingList(actor, var.curId - 1, RankingType_Heian)
end

function onNewDay(actor, login)
	local var = getActorVar(actor)
	if not var then return end

	--var.saodangCount = 0 
	var.buyCount = 0
	var.saodangTime = 0
	if not login then 
		sendHeianInfo(actor)
	end
end

-----------------------------------------------------------------------------------------------------------------------

function sendHeianInfo(actor)
	local var = getActorVar(actor)
	if not var then return end

	local time = 0
	local now = System.getNowTime()
	if var.saodangTime > now then
		time = var.saodangTime - now
	elseif var.saodangCount > 0 then
		time = -1
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sHeian_Info)
	if pack == nil then return end
	local count = SVipConfig[LActor.getSVipLevel(actor)].heianReset + 1 --可购买次数+免费重置次数
	LDataPack.writeInt(pack, var.curId - 1) 				--挑战到哪个副本
	LDataPack.writeInt(pack, var.saodangCount)				--今天已扫荡的次数
	LDataPack.writeInt(pack, count-var.buyCount)			--可重置次数
	LDataPack.writeInt(pack, time)							--(-1重置按钮，0扫荡按钮，大于0扫荡剩余时间)
	LDataPack.writeInt(pack, #HeianfbConfig)				--副本总数
	LDataPack.writeByte(pack, var.buyCount < 1 and 1 or 0) 	--是否免费重置
	LDataPack.flush(pack)
end

function c2sCreateFuben(actor)
	local var = getActorVar(actor)
	if not var then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.heian) then
		return
	end
	local config = HeianfbConfig[var.curId]
	if not config then return end	
	if not utils.checkFuben(actor, config.fbid) then return end
	local hfuben = instancesystem.createFuBen(config.fbid)
	if hfuben == 0 then return end
	local x, y = utils.getSceneEnterCoor(config.fbid)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
end

--扫荡副本
function c2sSaodangFuben(actor)
	local var = getActorVar(actor)
	if not var then return end

	local now = System.getNowTime()
	if var.saodangTime and var.saodangTime > now then return end
	if var.saodangCount and var.saodangCount > 0 then return end
	if var.curId <= 1 then return end

	local time = HeianfbBaseConfig[1].everyTime * (var.curId-1)
	if time > HeianfbBaseConfig[1].maxTime then
		time = HeianfbBaseConfig[1].maxTime
	end
	var.saodangTime = now + time
	var.saodangCount = (var.saodangCount or 0) + 1
	var.saodangId = var.curId-1
	sendHeianInfo(actor)

	LActor.postScriptEventLite(nil, time * 1000, function(...) saodangFuben(...) end, LActor.getActorId(actor))
end

--扫荡奖励
function saodangFuben(entity, aid)
	local actor = LActor.getActorById(aid)
	local var = getActorVar(actor)
	if not var then return end
	if not var.saodangId or not HeianfbConfig[var.saodangId] then
		return 
	end

	local items0 = {}
	local fbIds = {}
	for i=1, var.saodangId do
		for k, v in pairs(HeianfbConfig[i].saodangAwards) do
			items0[v.id] = (items0[v.id] or 0) + v.count
		end
		fbIds[#fbIds + 1] = HeianfbConfig[i].fbid
	end
	local items = actoritem.changeItemFormat(items0)

	local context = string.format(HeianfbBaseConfig[1].saodangContext, var.saodangId)
	local mailData = {head=HeianfbBaseConfig[1].saodangTitle, context=context, tAwardList=items}
	mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	sendHeianInfo(actor)

	for i = 1, #fbIds do
		actorevent.onEvent(actor, aeSaoDang, fbIds[i], 1)
	end
	var.saodangId = 0
end

--扫荡重置
function c2sResetSaodang(actor)
	local var = getActorVar(actor)
	if not var or not var.saodangCount or not var.saodangTime then return end
	if var.saodangTime > System.getNowTime() then return end --还在扫荡时间内

	local vip = LActor.getSVipLevel(actor)
	if var.buyCount >= SVipConfig[vip].heianReset + 1 then
		return
	end

	if var.buyCount >= 1 then --一次以内的重置免费，超出的收费
		if not actoritem.checkItem(actor, NumericType_YuanBao, HeianfbBaseConfig[1].cost) then
			return
		end
		actoritem.reduceItem(actor, NumericType_YuanBao, HeianfbBaseConfig[1].cost, "heianfuben_resetSaodang")
	end

	var.saodangCount = 0 
	var.saodangTime = 0
	var.buyCount = (var.buyCount or 0) + 1
	sendHeianInfo(actor)
end

local function init()
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)

	if System.isCrossWarSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cHeian_Challenge, c2sCreateFuben)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cHeian_ResetSaodang, c2sResetSaodang)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cHeian_SaodangFuben, c2sSaodangFuben)

	--注册相关回调
	for _, config in pairs(HeianfbConfig) do
		insevent.registerInstanceWin(config.fbid, onFbWin)
		insevent.registerInstanceLose(config.fbid, onFbLose)
	end
end
table.insert(InitFnTable, init)


--local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.checkHeian = function (actor, args)
	local tmp = tonumber(args[1])
	if tmp == 1 then
		c2sCreateFuben(actor)
	elseif tmp == 2 then
		c2sSaodangFuben(actor)
	elseif tmp == 3 then
		c2sResetSaodang(actor)
	end
	return true
end

gmCmdHandlers.passHeian = function (actor)
	local var = getActorVar(actor)
	if HeianfbConfig[var.curId] then
		var.curId = var.curId + 1
		slim.heianFuben(actor, var.curId)
		utils.rankfunc.updateRankingList(actor, var.curId - 1, RankingType_Heian)
	end
	sendHeianInfo(actor)
	return true
end

gmCmdHandlers.reachHeian = function (actor, args)
	local num = tonumber(args[1])
	local var = getActorVar(actor)
	if HeianfbConfig[num-1] then
		var.curId = num
		slim.heianFuben(actor, var.curId)
		utils.rankfunc.updateRankingList(actor, var.curId - 1, RankingType_Heian)
	end
	sendHeianInfo(actor)
	return true
end
