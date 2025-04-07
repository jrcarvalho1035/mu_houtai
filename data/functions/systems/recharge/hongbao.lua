-- @version 1.0
-- @author  qianmeng
-- @date    2017-6-13 10:44:44.
-- @system  红包系统

module("hongbao",package.seeall)

global_hongbao_max = 1000
global_hongbao_note = 20

local function getGlobalData()
	local var = System.getStaticVar()
	if not var then return end
	if not var.hongbaoSet then 
		var.hongbaoSet = {
			wrap = {},
			wrap_begin = 1,
			wrap_end = 1,
			note = {},
			note_begin = 1,
			note_end = 1,
		}
	end
	if not var.hongbaoSet.robotcount then var.hongbaoSet.robotcount = 0 end
	return var.hongbaoSet;
end


local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end
	if not var.hongbaoData then var.hongbaoData = {} end
	if not var.hongbaoData.baos then var.hongbaoData.baos = {} end
	if not var.hongbaoData.redBegin then var.hongbaoData.redBegin = 1 end
	if not var.hongbaoData.redEnd then var.hongbaoData.redEnd = 1 end
	return var.hongbaoData
end

--把红包拆分成10个不等值红包
function splitHongbao(moneys, tp)
	local amounts = HongbaoConfig.amounts[tp] or HongbaoConfig.amounts[1]
	local count = HongbaoConfig.count[tp] or HongbaoConfig.count[1]
	local r = math.floor(amounts / count) * 2 - 1
	amounts = amounts - count
	for i=1, count do
		local num = 0
		if i < count then
			num = math.random(0, r)
			num = math.min(amounts, num)
			amounts = amounts - num
		else
			num = amounts
		end
		moneys[i] = num + 1
	end
end

--创建一个机器人红包
function createHongbaoRobot(actor, index)
	--生成红包数据
	local now = System.getNowTime()
	local data = getGlobalData()
	local baoId = data.wrap_end
	local actorid = math.random(1, #HongbaoRobotConfig)
	local bao = {
		id = baoId,
		tp = index,
		moneys = {},	--红包数额
		tasks = {}, 	--抢红包的人
		taskTimes = {}, --抢红包的时间
		idx = 0, 		--红包被抢到第几个
		isSend = 0, 	--是否已发送
		sendTime = now + 1,	--发送限时
		keepTime = now + HongbaoConfig.keepTime,	--保留时间
		actor_id = actorid,
		actor_name = HongbaoRobotConfig[actorid].name,
		job = HongbaoRobotConfig[actorid].job,
		vip_level = HongbaoRobotConfig[actorid].vip,
		monthcard = 0,
	}
	splitHongbao(bao.moneys, index) --分拆红包数额

	--红包加入红包集，删除超出范围的红包
	data.wrap[baoId] = bao
	data.wrap_end = data.wrap_end + 1
	while (data.wrap_end - data.wrap_begin) > global_hongbao_max do 
		data.wrap[data.wrap_begin] = nil
		data.wrap_begin = data.wrap_begin + 1
	end
	autoSendHongbao(_, baoId)
end

--创建一个红包
function createHongbao(actor, tp)
	local var = getStaticData(actor)
	if not var then return end

	--生成红包数据
	local now = System.getNowTime()
	local data = getGlobalData()
	local baoId = data.wrap_end
	local actordata = LActor.getActorData(actor)
	local bao = {
		id = baoId,
		tp = tp,
		moneys = {},	--红包数额
		tasks = {}, 	--抢红包的人
		taskTimes = {}, --抢红包的时间
		idx = 0, 		--红包被抢到第几个
		isSend = 0, 	--是否已发送
		sendTime = now + HongbaoConfig.sendTime,	--发送限时
		keepTime = now + HongbaoConfig.keepTime,	--保留时间
		actor_id = actordata.actor_id,
		actor_name = actordata.actor_name,
		job = actordata.job,
		vip_level = actordata.vip_level,
		monthcard = actordata.monthcard,
	}
	splitHongbao(bao.moneys, tp) --分拆红包数额

	--红包加入红包集，删除超出范围的红包
	data.wrap[baoId] = bao
	data.wrap_end = data.wrap_end + 1
	while (data.wrap_end - data.wrap_begin) > global_hongbao_max do 
		data.wrap[data.wrap_begin] = nil
		data.wrap_begin = data.wrap_begin + 1
	end

	--把红包id记录进玩家数据
	var.baos[var.redEnd] = baoId
	var.redEnd = var.redEnd + 1
	LActor.postScriptEventLite(nil, HongbaoConfig.sendTime * 1000, autoSendHongbao, baoId)
end

--到期自动发送红包
function autoSendHongbao(_, baoId)
	local data = getGlobalData()
	if not data then return end
	local bao = data.wrap[baoId]
	if not bao then return end
	if bao.isSend ~= 0 then return end --已发送
	local now = System.getNowTime()
	s2cHongbaoRece(bao, now) --广播这红包

	local actor = LActor.getActorById(bao.actor_id)
	if actor then --如果红包持有者在线，就发送红包的改变信息
		s2cHongbaoInfo(actor, false)
	end
end

--玩家手动发送红包
function sendHongbao(actor)
	local data = getGlobalData()
	if not data then return end
	local var = getStaticData(actor)
	if not var then return end
	if var.redBegin == var.redEnd then return end

	local now = System.getNowTime()
	--找到能发送的红包
	for i = var.redBegin, var.redEnd-1 do
		local baoId = var.baos[i]
		local bao = data.wrap[baoId]
		if bao and bao.isSend == 0 and bao.keepTime >= now then
			s2cHongbaoRece(bao, now) --广播这红包
			utils.logCounter(actor, "hongbao send")
			break
		end
	end
	s2cHongbaoInfo(actor, false)
end

--拿走红包奖励
function giveHongbao(actor, baoId)
	local data = getGlobalData()
	if not data then 
		return 
	end
	local bao = data.wrap[baoId]
	if not bao then --可能红包过期被删
		s2cHongbaoGive(actor, baoId, 0, 3, 0)
		return 
	end
	if bao.isSend == 0 then 
		return 
	end --这红包还未发送
	local now = System.getNowTime()
	if bao.keepTime < now then --这红包已过期
		s2cHongbaoGive(actor, baoId, 0, 3, 0)
		return 
	end 
	if bao.idx >= #bao.moneys then --红包已抢光
		s2cHongbaoGive(actor, baoId, 0, 2, 0)
		return 
	end
	local myId = LActor.getActorId(actor) 
	for i=0, bao.idx do
		if myId == bao.tasks[i] then --自己已抢过
			s2cHongbaoGive(actor, baoId, 0, 1, 0)
			return
		end
	end

	bao.idx = bao.idx + 1
	bao.tasks[bao.idx] = LActor.getActorId(actor) 	--记录抢红包者
	bao.taskTimes[bao.idx] = now 					--记录时间
	local num = bao.moneys[bao.idx]
	actoritem.addItem(actor, NumericType_YuanBao, num, "red bao get")
	s2cHongbaoGive(actor, baoId, 1, 1, num)
end

--检查是否有离线红包
function checkOfflineHongbao(actor)
	local data = getGlobalData()
	if not data then return end
	local now = System.getNowTime()
	local actor_id = LActor.getActorId(actor)
	for i = data.note_begin, data.note_end-1 do
		local baoId = data.note[i].id
		local bao = data.wrap[baoId]
		if bao and bao.idx < #bao.moneys and bao.keepTime >= now then
			local flag = false --检测这红包是否已抢
			for i=0, bao.idx do
				if actor_id == bao.tasks[i] then 
					flag = true
				end
			end
			if not flag then 
				return true
			end
		end
	end
	return false
end

--定期清理过期的红包
function updateHongbaoData()
	if System.isBattleSrv() then return end
	local data = getGlobalData()
	if not data then return end
	local now = System.getNowTime()
	local begin = data.wrap_begin
	for i=data.wrap_begin, data.wrap_end-1 do
		if (not data.wrap[i]) or (data.wrap[i] and data.wrap[i].keepTime < now) then
			data.wrap[i] = nil
			begin = i + 1
		end
	end
	data.wrap_begin = begin
end
_G.updateHongbaoData = updateHongbaoData
---------------------------------------------------------------------------------------------------------------
--红包信息
function s2cHongbaoInfo(actor, login)
	local data = getGlobalData()
	if not data then return end --没有红包
	local var = getStaticData(actor)

	local now = System.getNowTime()
	local wrap = {}
	local begin = var.redBegin 
	for i = var.redBegin, var.redEnd-1 do
		local baoId = var.baos[i]
		local bao = data.wrap[baoId]
		if bao and bao.isSend == 0 and bao.keepTime >= now then
			table.insert(wrap, baoId)
		end
		if not bao then --清除掉已不存在的红包记录
			begin = i+1
		end
	end
	var.redBegin = begin
	local pay = LActor.getRecharge(actor)
	-- local flag = 0 --是否有离线红包
	-- if login and checkOfflineHongbao(actor) then
	-- 	flag = 1
	-- end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_HongbaoData)
	if npack == nil then return end
	LDataPack.writeShort(npack, #wrap)
	for k, v in ipairs(wrap) do
		local tp = data.wrap[v].tp
		LDataPack.writeInt(npack, v)
		LDataPack.writeShort(npack, HongbaoConfig.amounts[tp] or HongbaoConfig.amounts[1]) --总额
		LDataPack.writeShort(npack, HongbaoConfig.count[tp] or HongbaoConfig.count[1]) --个数
	end
	LDataPack.writeInt(npack, pay)
	LDataPack.writeByte(npack, 0) --是否有离线红包，红包改为主动下发，这字段不用了
	LDataPack.flush(npack)
end

--红包发送
local function c2sHongbaoSend(actor, packet)
	sendHongbao(actor)
end

--红包接收
function s2cHongbaoRece(bao, now)
	--把红包加入红包消息列表
	local data = getGlobalData()
	if not data then return end 
	data.note[data.note_end] = {
		id = bao.id,
		time = now,
	}
	data.note_end = data.note_end + 1
	while (data.note_end - data.note_begin) > global_hongbao_note do 
		data.note[data.note_begin] = nil
		data.note_begin = data.note_begin + 1
	end
	bao.isSend = 1 --设红包已发送

	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_Recharge)
	LDataPack.writeByte(npack, Protocol.sRechargeCmd_HongbaoRece)

	LDataPack.writeInt(npack, bao.actor_id)
	LDataPack.writeInt(npack, bao.id)
	LDataPack.writeString(npack, bao.actor_name)
	LDataPack.writeChar(npack, bao.job)
	LDataPack.writeChar(npack, bao.vip_level)
	LDataPack.writeChar(npack, bao.monthcard)
	LDataPack.writeInt(npack, now)
	System.broadcastData(npack) --向所有人广播红包
end

--红包领取
local function c2sHongbaoGive(actor, packet)
	local baoId = LDataPack.readInt(packet)
	giveHongbao(actor, baoId)
end

--红包领取状态
function s2cHongbaoGive(actor, baoId, isSuc, state, num)
	if isSuc == 0 and state == 1 then --已领取又不成功表示玩家同时点击多次，所以不向客户端回包
		return
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_HongbaoGive)
	if npack == nil then return end
	LDataPack.writeInt(npack, baoId)
	LDataPack.writeChar(npack, isSuc) --0不成功，1成功
	LDataPack.writeChar(npack, state) --1 已领取，2 已抢光，3 已过期
	LDataPack.writeInt(npack, num) --领取钻石数量
	LDataPack.flush(npack)
end

--查看红包领取记录
function c2sHongbaoRecord(actor, packet)
	local baoId = LDataPack.readInt(packet)
	s2cHongbaoRecord(actor, baoId)
end

--红包领取记录
function s2cHongbaoRecord(actor, baoId)
	local data = getGlobalData()
	if not data then return end 
	local bao = data.wrap[baoId]
	if not bao then return end

	local now = System.getNowTime()
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_HongbaoRecord)
	if npack == nil then return end
	LDataPack.writeInt(npack, baoId)
	LDataPack.writeChar(npack, bao.idx)
	for i=1, bao.idx do
		local tarId = bao.tasks[i]
		local basic_data = LActor.getActorDataById(tarId)
		if not basic_data then --如果数据库账号被清除，但红包仍在，会出现找不到的情况
			utils.printInfo("not basic_data", i, tarId)
			basic_data = {actor_name="tuhao", job=1}
		end
		LDataPack.writeString(npack, basic_data.actor_name)
		LDataPack.writeChar(npack, basic_data.job)
		LDataPack.writeChar(npack, bao.moneys[i])
		LDataPack.writeInt(npack, now - bao.taskTimes[i])
	end
	LDataPack.writeShort(npack, HongbaoConfig.amounts[bao.tp] or HongbaoConfig.amounts[1])
	LDataPack.writeShort(npack, HongbaoConfig.count[bao.tp] or HongbaoConfig.count[1])
	LDataPack.flush(npack)
end

--红包查看消息
function c2sHongbaoNote(actor, packet)
	--s2cHongbaoNote(actor)
end

--红包消息列表
function s2cHongbaoNote(actor)
	local data = getGlobalData()
	if not data then return end
	local now = System.getNowTime()
	local myId = LActor.getActorId(actor)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_HongbaoNote)
	if npack == nil then return end
	local count = 0
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeInt(npack, count) 
	for i = data.note_begin, data.note_end-1 do
		local baoId = data.note[i].id
		local bao = data.wrap[baoId]
		if bao and bao.idx < #bao.moneys and bao.keepTime >= now then
			local time = data.note[i].time
			local flag = false --自己是否抢过
			for i=0, bao.idx do
				if myId == bao.tasks[i] then 
					flag = true
				end
			end
			if not flag then
				LDataPack.writeInt(npack, bao.actor_id)
				LDataPack.writeInt(npack, bao.id)
				LDataPack.writeString(npack, bao.actor_name)
				LDataPack.writeChar(npack, bao.job)
				LDataPack.writeChar(npack, bao.vip_level)
				LDataPack.writeChar(npack, bao.monthcard)
				LDataPack.writeInt(npack, time)
				count = count + 1
			end
		end
	end
	if count > 0 then
		local npos = LDataPack.getPosition(npack)
		LDataPack.setPosition(npack, pos)
		LDataPack.writeInt(npack, count)
		LDataPack.setPosition(npack, npos)
	end
	LDataPack.flush(npack)
end

local function onLogin(actor) 
	if System.isBattleSrv() then return end
	s2cHongbaoInfo(actor, true)
	s2cHongbaoNote(actor)
end

local function onRecharge(actor, count)
	if System.isBattleSrv() then return end
	local var = getStaticData(actor)
	local pay = LActor.getRecharge(actor)
	for i = var.redEnd, #HongbaoConfig.condition do
		if pay >= HongbaoConfig.condition[i] then
			createHongbao(actor, i)
		end
	end
	s2cHongbaoInfo(actor, false)
end

function onTimerRobot()
	local now = System.getNowTime()
	local year, month, day, hour, minute, _ = System.timeDecode(now)
	--是否到时间
	local sysvar = getGlobalData()
	if HongbaoConfig.openday < System.getOpenServerDay() + 1 then
		if sysvar.eid then
			LActor.cancelScriptEvent(nil, sysvar.eid)
		end
		return
	end
	if hour < HongbaoConfig.opentime[1] then
		return
	end
	if hour >= HongbaoConfig.opentime[2] then
		return
	end
	
	--是否刷红包
	if sysvar.robotcount >= HongbaoConfig.counthour then
		if minute <= math.max(0, HongbaoConfig.counthour - 2) then
			sysvar.robotcount = 0
		end
		return
	end
	local rand = math.random(1, 60)
	if rand > HongbaoConfig.counthour then
		if minute % 10 == 0 then --每十分钟检测一次是否刷机器人红包
			if sysvar.robotcount >= minute / 10 and minute ~= 0 then
				return
			end
		else
			return
		end
	end
	

	--刷红包
	local index = HongbaoConfig.weight[sysvar.robotcount + 1]
	if index then
		createHongbaoRobot(actor, index)
	end

	local sysvar = getGlobalData()
	sysvar.robotcount = sysvar.robotcount + 1
	if minute == 0 then --整点清空，上面的清空在不够次数的时候不会执行
		sysvar.robotcount = 0
	end
end

function initRobotHongbao()
	local day = System.getOpenServerDay() + 1 --开服第几天
	if HongbaoConfig.openday < day then
		return
	end
	local sysvar = getGlobalData()
	sysvar.eid = LActor.postScriptEventEx(nil, 60000, function() onTimerRobot() end, 60000, -1)
end

--启动服务器时设置自动发红包时间
hongbaoInit = hongbaoInit or false
local function initFunc()
	if hongbaoInit then return end
	hongbaoInit = true --限制开服只执行一次
	local data = getGlobalData()
	if not data then return end
	local now = System.getNowTime()
	for i=data.wrap_begin, data.wrap_end-1 do
		local bao = data.wrap[i]
		if bao.isSend == 0 and bao.sendTime > now then
			LActor.postScriptEventLite(nil, bao.sendTime - now, autoSendHongbao, baoId) 
		end
	end
end 

engineevent.regGameStartEvent(initRobotHongbao)
table.insert(InitFnTable, initFunc)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_HongbaoSend, c2sHongbaoSend)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_HongbaoGive, c2sHongbaoGive)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_HongbaoRecord, c2sHongbaoRecord)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_HongbaoNote, c2sHongbaoNote)
actorevent.reg(aeRecharge, onRecharge)
actorevent.reg(aeUserLogin, onLogin)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.sendbao = function(actor, args)
	sendHongbao(actor)
	return true
end

gmCmdHandlers.hongbaoCreate = function (actor, args)
	local i = tonumber(args[1])
	createHongbao(actor, i)
	s2cHongbaoInfo(actor, false)
	return true
end

gmCmdHandlers.hongbaoGive = function (actor, args)
	local baoId = tonumber(args[1])
	giveHongbao(actor, baoId)
	return true
end

gmCmdHandlers.hongbaoRecord = function (actor, args)
	local baoId = tonumber(args[1])
	s2cHongbaoRecord(actor, baoId)
	return true
end

gmCmdHandlers.hongbaoInfo = function (actor)
	local data = getGlobalData()
	if not data then return end 
	local var = getStaticData(actor)
	utils.printInfo("hongbao info", LActor.getActorId(actor), var.redBegin, var.redEnd)

	for i = var.redBegin, var.redEnd-1 do
		local baoId = var.baos[i]
		local bao = data.wrap[baoId]
		utils.printInfo("==============bao============", baoId)
		utils.printTable(bao)
	end
	return true
end

gmCmdHandlers.hongbaoNote = function (actor, args)
	s2cHongbaoNote(actor)
	return true
end

gmCmdHandlers.hongbaoTest = function (actor, args)
	updateHongbaoData()
	return true
end

gmCmdHandlers.hongbaoData = function (actor, args)
	local data = getGlobalData()
	utils.printTable(data)
end
