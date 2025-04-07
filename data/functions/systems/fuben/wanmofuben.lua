-- @version 1.0
-- @author  qianmeng
-- @date    2017-2-11 18:03:31.
-- @system  万魔爬塔

module("wanmofuben", package.seeall)
require("scene.challengefuben")
require("scene.challengefubenbase")

function getActorVar(actor)
	if not actor then return end

	local var = LActor.getStaticVar(actor)
	if not var then return end

	if not var.wanmofuben then
		var.wanmofuben = {}
	end
	local wanmofuben = var.wanmofuben
	if not wanmofuben.curId then wanmofuben.curId = 1 end --当前正在挑战的副本
	if not wanmofuben.saodangTime then wanmofuben.saodangTime = 0 end	--扫荡结束时间
	if not wanmofuben.saodangCount then wanmofuben.saodangCount = 1 end --今天已扫荡的次数
	if not wanmofuben.buyCount then wanmofuben.buyCount = 0 end			--今天已购买的扫荡次数
	if not wanmofuben.smallid then wanmofuben.smallid = 0 end			--小关卡领取奖励层数
	if not wanmofuben.bigid then wanmofuben.bigid = 0 end			--大关卡领取的奖励层数

	return wanmofuben	
end

function getWanmoFloor(actor)
	local var = getActorVar(actor)
	return var.curId - 1
end

function onFbWin(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then return end --胜利的 时候不可能找不到吧
	local var = getActorVar(actor)
	if not var then return end

	local config = ChallengefbConfig[var.curId]
	if not config then return end

	if ins.id ~= config.fbid then print("fb id error   "..ins.id.." "..config.fbid) return end

	actorevent.onEvent(actor,aeWanmoFuben, var.curId) --curId在+1前发
	var.curId = var.curId + 1
	local items = actoritem.mergeItems(config.normalAwards, config.saodangAwards)--首通奖励+扫荡奖励
	instancesystem.setInsRewards(ins, actor, items)
	slim.wanmoFuben(actor, var.curId+1, true) --发送下一个怪物的UI信息
	sendChallengeInfo(actor)
	utils.rankfunc.updateRankingList(actor, var.curId - 1, RankingType_Wanmo)
end

function onFbLose(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then return end

	instancesystem.setInsRewards(ins, actor, nil)
end

function onLogin(actor)
	local var = getActorVar(actor)
	if not var then return end

	slim.wanmoFuben(actor, var.curId)
	if var.saodangTime > 0 and var.saodangTime <= System.getNowTime() and ChallengefbConfig[var.saodangId] then
		local aid = LActor.getActorId(actor)
		saodangFuben(nil, aid) --给离线时扫荡产生的奖励
	else
		sendChallengeInfo(actor)
	end
	utils.rankfunc.updateRankingList(actor, var.curId - 1, RankingType_Wanmo)
end

function onNewDay(actor, login)
	local var = getActorVar(actor)
	if not var then return end

	--var.saodangCount = 0
	var.buyCount = 0
	var.saodangTime = 0
	if not login then
		sendChallengeInfo(actor)
	end
end


function sendChallengeInfo(actor)
	local var = getActorVar(actor)
	if not var then return end

	local time = 0
	local now = System.getNowTime()

	if var.saodangTime > now then
		time = var.saodangTime - now
	elseif var.saodangCount > 0 then
		time = -1
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sWanmo_Info)
	if pack == nil then return end
	local count = SVipConfig[LActor.getSVipLevel(actor)].wanmoReset + 1 --可购买次数+免费重置次数
	LDataPack.writeInt(pack, var.curId - 1)					--挑战到哪个副本
	LDataPack.writeInt(pack, var.saodangCount)				--今天已扫荡的次数
	LDataPack.writeInt(pack, count-var.buyCount)			--今天已购买的扫荡次数
	LDataPack.writeInt(pack, time)							--(-1重置按钮，0扫荡按钮，大于0扫荡剩余时间)
	LDataPack.writeInt(pack, #ChallengefbConfig)			--副本总数
	LDataPack.writeByte(pack, var.buyCount < 1 and 1 or 0) 	--是否免费重置
	local actordata = LActor.getActorData(actor)
	local power = math.floor(actordata.total_power * ChallengefbBaseConfig[1].powerper / 10000)
	LDataPack.writeChar(pack, (var.curId >= ChallengefbBaseConfig[1].canquick and ChallengefbConfig[var.curId] and ChallengefbConfig[var.curId].power < power) and 1 or 0)

	local ifhave1=false
	local number1=var.smallid
	for j=var.smallid+1,#ChallengefbConfig do
		if ChallengefbConfig[j].smallreward.type then
			ifhave1=true
			number1=j;
			break		
		end
	end
	
	if ifhave1==false then
		LDataPack.writeChar(pack, 1)
	else	
		LDataPack.writeChar(pack, 0)
	end 
	LDataPack.writeShort(pack,number1)
	LDataPack.writeInt(pack, ChallengefbConfig[number1].smallreward.id)
	LDataPack.writeInt(pack, ChallengefbConfig[number1].smallreward.count)

	local ifhave=false
	local number=var.bigid
	for i=var.bigid+1,#ChallengefbConfig do
		if ChallengefbConfig[i].bigreward.type then
			ifhave=true
			number=i;
			break
		end
	end
	if ifhave==false then
		LDataPack.writeChar(pack, 1)
	else		
		LDataPack.writeChar(pack, 0)
	end
	LDataPack.writeShort(pack,number)
	LDataPack.writeInt(pack, ChallengefbConfig[number].bigreward.id)
	LDataPack.writeInt(pack, ChallengefbConfig[number].bigreward.count)

	LDataPack.flush(pack)
end

function c2sCreateFuben(actor)
	local var = getActorVar(actor)
	if not var then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.wanmo) then
		return
	end
	local config = ChallengefbConfig[var.curId]
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

	local time = ChallengefbBaseConfig[1].everyTime * (var.curId-1)
	if time > ChallengefbBaseConfig[1].maxTime then
		time = ChallengefbBaseConfig[1].maxTime
	end
	var.saodangTime = now + time
	var.saodangCount = (var.saodangCount or 0) + 1
	var.saodangId = var.curId-1
	sendChallengeInfo(actor)

	LActor.postScriptEventLite(nil, time * 1000, function(...) saodangFuben(...) end, LActor.getActorId(actor))
end

--快速挑战副本
function c2sQuick(actor)
	local var = getActorVar(actor)
	if var.curId < ChallengefbBaseConfig[1].canquick then return end
	local actordata = LActor.getActorData(actor)
	local power = math.floor(actordata.total_power * ChallengefbBaseConfig[1].powerper / 10000)
	local maxid = 1
	if ChallengefbConfig[#ChallengefbConfig].power <= power then
		maxid = #ChallengefbConfig + 1
	else
		for i=var.curId, #ChallengefbConfig do
			if ChallengefbConfig[i].power >= power then
				maxid = i
			end
		end
	end
	for k,v in ipairs(ChallengefbConfig) do
		if v.power >= power then
			maxid = k
			break
		end
	end

	if maxid <= var.curId then return end
	local curId = var.curId
	local config = ChallengefbConfig[maxid]
	actorevent.onEvent(actor,aeWanmoFuben, maxid) --curId在+1前发
	var.curId = maxid

	sendQuickReward(actor, curId, maxid)

	slim.wanmoFuben(actor, var.curId) --发送下一个怪物的UI信息
	sendChallengeInfo(actor)
	utils.rankfunc.updateRankingList(actor, var.curId - 1, RankingType_Wanmo)
end

function insertTotalReward(total, one)
	local ishave = false
	for k,v in ipairs(total) do
		if v.id == one.id then
			v.count = v.count + one.count
			ishave = true
			break
		end
	end
	if not ishave then
		total[#total + 1] = {}
		total[#total].id = one.id
		total[#total].count = one.count
	end
end

--快速挑战奖励
function sendQuickReward(actor, curId, maxid)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sWanmo_Quick)
	LDataPack.writeShort(pack, curId)
	LDataPack.writeShort(pack, maxid - 1)
	LDataPack.writeChar(pack, maxid - curId + 1 > 11 and 11 or maxid - curId + 1) --+1是包含总奖励
	local totalreward = {}
	--发送多层奖励
	local max = math.min(curId + 4, maxid - 1)
	for i=curId, max do
		local reward = ChallengefbConfig[i].normalAwards
		LDataPack.writeChar(pack, #reward)
		for j=1, #reward do
			LDataPack.writeInt(pack, reward[j].id)
			LDataPack.writeInt(pack, reward[j].count)
		end
	end
	local min = math.max(curId + 5, maxid - 5)
	for i=min, maxid - 1 do
		local reward = ChallengefbConfig[i].normalAwards
		LDataPack.writeChar(pack, #reward)
		for j=1, #reward do
			LDataPack.writeInt(pack, reward[j].id)
			LDataPack.writeInt(pack, reward[j].count)			
		end
	end
	for i=curId, maxid - 1 do
		local reward = ChallengefbConfig[i].normalAwards
		for j=1, #reward do
			insertTotalReward(totalreward, reward[j])
		end
	end


	LDataPack.writeChar(pack, #totalreward)
	for i=1, #totalreward do
		LDataPack.writeInt(pack, totalreward[i].id)
		LDataPack.writeInt(pack, totalreward[i].count)
	end
	LDataPack.flush(pack)
	actoritem.addItems(actor, totalreward, "wanmo quick challenge fuben reward")
end

--扫荡奖励
function saodangFuben(entity, aid) 
	local actor = LActor.getActorById(aid)
	local var = getActorVar(actor)
	if not var then return end
	if not var.saodangId or not ChallengefbConfig[var.saodangId] then
		return 
	end

	local items0 = {}
	local fbIds = {}
	for i=1, var.saodangId do
		for k, v in pairs(ChallengefbConfig[i].saodangAwards) do
			items0[v.id] = (items0[v.id] or 0) + v.count
		end
		fbIds[#fbIds+1] = ChallengefbConfig[i].fbid
	end
	local items = actoritem.changeItemFormat(items0)

	local context = string.format(ChallengefbBaseConfig[1].saodangContext, var.saodangId)
	local mailData = {head=ChallengefbBaseConfig[1].saodangTitle, context=context, tAwardList=items}
	mailsystem.sendMailById(LActor.getActorId(actor), mailData) --发送奖励邮件
	sendChallengeInfo(actor)

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
	if var.buyCount >= SVipConfig[vip].wanmoReset + 1 then
		return
	end

	if var.buyCount >= 1 then --一次以内的重置免费，超出的收费
		if not actoritem.checkItem(actor, NumericType_YuanBao, ChallengefbBaseConfig[1].cost) then
			return
		end
		actoritem.reduceItem(actor, NumericType_YuanBao, ChallengefbBaseConfig[1].cost, "wanmofuben_resetSaodang")
	end

	var.saodangCount = 0 
	var.saodangTime = 0
	var.buyCount = (var.buyCount or 0) + 1
	sendChallengeInfo(actor)
end
--领取奖励
function c2sGetReward(actor, packet)
	local type = LDataPack.readChar(packet)
	local var = getActorVar(actor)
	if type == 1 then
		for i=var.smallid + 1, #ChallengefbConfig do
			if ChallengefbConfig[i].smallreward.type then
				if var.curId < i then
					return
				end
				var.smallid = i
				actoritem.addItem(actor, ChallengefbConfig[i].smallreward.id, ChallengefbConfig[i].smallreward.count, "wanmofuben get small reward")
				break
			end
		end
	else
		for i=var.bigid + 1, #ChallengefbConfig do
			if ChallengefbConfig[i].bigreward.type then
				if var.curId < i then
					return
				end
				var.bigid = i
				actoritem.addItem(actor, ChallengefbConfig[i].bigreward.id, ChallengefbConfig[i].bigreward.count, "wanmofuben get big reward")
				break
			end
		end
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sWanmo_GetReward)
	
	local ifhave1=false
	local number1=var.smallid
	for j=var.smallid+1,#ChallengefbConfig do
		if ChallengefbConfig[j].smallreward.type then
			ifhave1=true
			number1=j;
			break		
		end
	end
	if ifhave1==false then
		LDataPack.writeChar(pack, 1)		
	else	
		LDataPack.writeChar(pack, 0)		
	end 
	LDataPack.writeShort(pack,number1)
	LDataPack.writeInt(pack, ChallengefbConfig[number1].smallreward.id)
	LDataPack.writeInt(pack, ChallengefbConfig[number1].smallreward.count)

	local ifhave=false
	local number=var.bigid
	for i=var.bigid+1,#ChallengefbConfig do
		if ChallengefbConfig[i].bigreward.type then
			ifhave=true
			number=i;
			break		
		end
	end
	if ifhave==false then
		LDataPack.writeChar(pack, 1)		
	else		
		LDataPack.writeChar(pack, 0)	
	end
	LDataPack.writeShort(pack,number)
	LDataPack.writeInt(pack, ChallengefbConfig[number].bigreward.id)
	LDataPack.writeInt(pack, ChallengefbConfig[number].bigreward.count)
	LDataPack.flush(pack)
end

local function init()
	actorevent.reg(aeNewDayArrive, onNewDay)

	if System.isCrossWarSrv() then return end
	actorevent.reg(aeUserLogin, onLogin)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cWanmo_Challenge, c2sCreateFuben)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cWanmo_ResetSaodang, c2sResetSaodang)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cWanmo_SaodangFuben, c2sSaodangFuben)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cWanmo_Query, sendChallengeInfo)	
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cWanmo_Quick, c2sQuick)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cWanmo_GetReward, c2sGetReward)
	

	--注册相关回调
	for _, config in pairs(ChallengefbConfig) do
		insevent.registerInstanceWin(config.fbid, onFbWin)
		insevent.registerInstanceLose(config.fbid, onFbLose)
	end
end
table.insert(InitFnTable, init)


--local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.checkWanmo = function (actor, args)
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

gmCmdHandlers.passWanmo = function (actor)
	local var = getActorVar(actor)
	if ChallengefbConfig[var.curId] then
		var.curId = var.curId + 1
		slim.wanmoFuben(actor, var.curId)
		utils.rankfunc.updateRankingList(actor, var.curId - 1, RankingType_Wanmo)
	end
	sendChallengeInfo(actor)
	return true
end

gmCmdHandlers.reachWanmo = function (actor, args)
	local num = tonumber(args[1])
	local var = getActorVar(actor)
	if ChallengefbConfig[num-1] then
		var.curId = num
		slim.wanmoFuben(actor, var.curId)
		utils.rankfunc.updateRankingList(actor, var.curId - 1, RankingType_Wanmo)
	end
	sendChallengeInfo(actor)
	return true
end

gmCmdHandlers.wanmoquick = function(actor, args)
	local curId = tonumber(args[1])
	local maxid = tonumber(args[2])
	sendQuickReward(actor, curId, maxid)
	return true
end
