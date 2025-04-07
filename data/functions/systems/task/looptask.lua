--环任务
module("looptask", package.seeall)
require("task.looptask")
require("task.looptaskfinalawardsconfig")

local EVERYDAY_TASK_COUNT = 10	--每日的环数
local EVERYDAY_MAX_TASK = 5		--最多可存在几个环任务
local REFRESH_TIME = 3600			--刷新时间

function getActorVar(actor)
	if not actor then return end

	local var = LActor.getStaticVar(actor)
	if not var then return end

	if not var.looptask then 
		var.looptask = {} 
		var.looptask.curTaskId = 1
		var.looptask.curValue = 0
		var.looptask.state = 0
		var.looptask.loopTaskId = 0 --第几个环任务
		var.looptask.curTaskCount = EVERYDAY_MAX_TASK --当前环任务数量
		var.looptask.taskRefreshTime = 0 --环任务刷新时间
		var.looptask.star = 1
	end
	if not var.looptask.finish then var.looptask.finish = 0 end --是否完成所有
	return var.looptask
end

--根据当前等级获得任务id
function setNewTaskId(actor)
	local var = getActorVar(actor)
	local level = LActor.getLevel(actor)
	local beginIdx
	local endIdx
	--环任务取等级合适的一段
	for idx, conf in ipairs(LoopTaskConfig) do
		if level >= conf.minLevel then			
			endIdx = idx
		end
	end
	if not endIdx then return end --等级不足开环任务
	beginIdx = endIdx - EVERYDAY_TASK_COUNT + 1
	--随机求任务
	var.curTaskId = System.getRandomNumber(endIdx + 1 - beginIdx) + beginIdx
end

--新的任务
function createNextLoop(actor)
	local var = getActorVar(actor)
	if not var then return end

	-- local level = LActor.getLevel(actor)
	-- local beginIdx
	-- local endIdx
	-- --环任务取等级合适的一段
	-- for idx, conf in ipairs(LoopTaskConfig) do
	-- 	if level >= conf.minLevel then
	-- 		endIdx = idx
	-- 	end
	-- end
	-- if not endIdx then return end --等级不足开环任务
	-- beginIdx = endIdx - EVERYDAY_TASK_COUNT + 1

	-- --随机求任务
	-- local taskId = System.getRandomNumber(endIdx + 1 - beginIdx) + beginIdx
	setNewTaskId(actor)
	--权值求星级
	local star = 1
	local taskConf = LoopTaskConfig[var.curTaskId]
	local rand = System.getRandomNumber(100)
	local totalPro = 0
	for idx, value in ipairs(taskConf.starPro) do
		totalPro = totalPro + value
		if rand <= totalPro then
			star = idx
			break
		end
	end

	--设置环任务的值
	var.loopTaskId = var.loopTaskId + 1
	--var.curTaskId = taskId
	var.star = star
	var.curValue = 0
	var.state = taskcommon.statusType.emDoing
	utils.logCounter(actor, "othersystem", var.loopTaskId, "", "looptask", "accept")

	--如果是成就型任务要读历史记录
	config = LoopTaskConfig[var.loopTaskId]
	local tp = config.type
	local taskHandleType = taskcommon.getHandleType(tp)
	if taskHandleType == taskcommon.eCoverType then
		local record = taskevent.getRecord(actor)
		if taskevent.needParam(tp) then
			if record[tp] == nil then record[tp] = {} end
			var.curValue = 0
			for k, v in pairs(config.param) do 
				if record[tp][v] then var.curValue = record[tp][v]	break end 
			end
		else
			var.curValue = record[tp] or taskevent.initRecord(tp, actor)
		end
	end

	actorevent.onEvent(actor, aeLoopTaskAccept, var.curTaskId)
end

--更新任务进度
function updateTaskValue(actor, taskType, param, value)
	local var = getActorVar(actor)
	if not var then return end

	local taskConf = LoopTaskConfig[var.curTaskId]
	if not taskConf then return end
	if taskConf.type ~= taskType then return end
	if (taskConf.param[1] ~= -1) and not utils.checkTableValue(taskConf.param, param) then --有-1时不对参数做验证
		return 
	end 

	if (var.curValue or 0) >= taskConf.target then return end
	
	local change = false
	if taskcommon.getHandleType(taskType) == taskcommon.eAddType then
		var.curValue = (var.curValue or 0) + value
		change = true
	elseif taskcommon.getHandleType(taskType) == taskcommon.eCoverType then
		if value > var.curValue then
			var.curValue = value
			change = true
		end
	end
	
	if change then
		if var.curValue >= taskConf.target then
			var.state = taskcommon.statusType.emCanAward
			actorevent.onEvent(actor, aeLoopTaskFinish, var.curTaskId)	
		end
		s2cLooptaskInfo(actor)
	end
end

local function getReward(actor, finish, star, taskId)
	if finish == 1 then --给终极奖励了
		local mId = utils.matchingLevel(actor, LoopTaskFinalAwardsConfig)
		return LoopTaskFinalAwardsConfig[mId].loopFinalAwards
	else
		local taskConf = LoopTaskConfig[taskId]
		if star == 1 then return taskConf.awardList1
		elseif star == 2 then return taskConf.awardList2
		elseif star == 3 then return taskConf.awardList3
		elseif star == 4 then return taskConf.awardList4
		elseif star == 5 then return taskConf.awardList5
		end
	end
	return
end

--领取环任务奖励
local function getLoopReward(actor)
	local var = getActorVar(actor)
	local taskConf = LoopTaskConfig[var.curTaskId]
	if not taskConf then return end
	local awardList = getReward(actor, var.finish, var.star, var.curTaskId)
	var.state = taskcommon.statusType.emHaveAward
	actoritem.addItems(actor, awardList, "loop task "..var.curTaskId) --领奖励
	maintask.s2cTaskReward(actor) --领奖回包
	utils.logCounter(actor, "othersystem", var.curTaskId, "", "looptask", "finish")
end

------------------------------------------------------------------------------------------------------------

function s2cLooptaskInfo(actor)
	local var = getActorVar(actor)
	if not var or not var.loopTaskId then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sTaskCmd_LoopInfo)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.curTaskId or 1)
	LDataPack.writeInt(pack, var.state or 0)
	LDataPack.writeInt(pack, var.curValue or 0)
	LDataPack.writeInt(pack, var.star or 1)
	LDataPack.writeInt(pack, var.loopTaskId or 1)	
	LDataPack.writeInt(pack, (var.taskRefreshTime + REFRESH_TIME - os.time()) > 0 and (var.taskRefreshTime + REFRESH_TIME - os.time()) or 0)
	LDataPack.writeShort(pack, var.curTaskCount)
	LDataPack.writeChar(pack, var.finish == 2 and 1 or 0)
	LDataPack.flush(pack)
end

--领取最终奖励
function c2sGetFinishReward(actor, packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.loop) then return end
	local var = getActorVar(actor)
	if not var then return end
	if var.loopTaskId < EVERYDAY_TASK_COUNT then return end
	if var.curTaskCount > 0 then return end
	if var.finish ~= 1 then return end
	getLoopReward(actor) --最终奖励
	var.finish = 2
	s2cLooptaskInfo(actor)
end

--领取奖励
function c2sLoopReward(actor, packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.loop) then return end
	local var = getActorVar(actor)
	if not var then return end
	if var.loopTaskId > EVERYDAY_TASK_COUNT then return end
	if var.state ~= taskcommon.statusType.emCanAward then return end
	getLoopReward(actor) --拿走奖励

	var.curTaskCount = var.curTaskCount - 1
	local id = var.curTaskId
	if var.loopTaskId >= EVERYDAY_TASK_COUNT then 
		var.finish = 1
		--getLoopReward(actor) --最终奖励
	else
		if var.curTaskCount > 0 then
			createNextLoop(actor)
		end
		if var.taskRefreshTime == 0 and var.curTaskCount + var.loopTaskId < EVERYDAY_TASK_COUNT then
			var.taskRefreshTime = os.time()
			updataTimer(actor)
		end
	end
	s2cLooptaskInfo(actor)
	actorevent.onEvent(actor, aeFinishLoop, 1)
end

--一键5星
function c2sLoopFullStar(actor, packet)
	local var = getActorVar(actor)
	if not var or not var.loopTaskId or var.loopTaskId > EVERYDAY_TASK_COUNT then return end
	if not var.curTaskId or not var.curValue then return end
	if var.star >= 5 then return end

	local taskConf = LoopTaskConfig[var.curTaskId]
	if not taskConf then return end

	if not actoritem.checkItem(actor, NumericType_YuanBao, taskConf.onkeyStar) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, taskConf.onkeyStar, "loop_task_refresh")
	var.star = 5

	s2cLooptaskInfo(actor)
	utils.logCounter(actor, "task loop 5star", var.curTaskId)
end

--一键完成
function c2sLoopFinish(actor, packet)
	local var = getActorVar(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.loop) then return end
	if var.finish == 1 then return end

	local mId = utils.matchingLevel(actor, LoopTaskFinalAwardsConfig)
	local comConf = LoopTaskFinalAwardsConfig[mId]
	if not comConf then return end

	local curnum = var.curTaskCount
	local num = var.curTaskCount --要完成任务的数量
	if var.state == taskcommon.statusType.emCanAward then
		num = num - 1
	end
	if num <= 0 then return end --没有要继续完成的任务
	if not actoritem.checkItem(actor, NumericType_YuanBao, comConf.quickFinish*num) then
		return
	end

	actoritem.reduceItem(actor, NumericType_YuanBao, comConf.quickFinish*num, "loop_task_finsh")
	if var.state == taskcommon.statusType.emCanAward then
		getLoopReward(actor)
	end

	local rewards = {}
	local tmp = getReward(actor, 0, 5, var.curTaskId) --环任务的5星奖励
	for k, v in pairs(tmp) do
		table.insert(rewards, {type=v.type, id=v.id, count=v.count*1})
	end
	--
	if num > 1 then
		setNewTaskId(actor)
		local tmp = getReward(actor, 0, 5, var.curTaskId) --环任务的5星奖励
		for k, v in pairs(tmp) do
			table.insert(rewards, {type=v.type, id=v.id, count=v.count*(num-1)})
		end
	end

	var.loopTaskId = var.loopTaskId + var.curTaskCount - 1
	var.curValue = LoopTaskConfig[var.curTaskId].target
	var.star = 5
	var.state = taskcommon.statusType.emHaveAward
	var.curTaskCount = 0
	if var.loopTaskId == EVERYDAY_TASK_COUNT then
		local tmp = getReward(actor, 1, 0, var.curTaskId) --环任务的终极奖励
		for k, v in pairs(tmp) do
			table.insert(rewards, {type=v.type, id=v.id, count=v.count})
		end
		var.finish = 1
		actoritem.addItems(actor, rewards, "loop finish rewards")
	else
		actoritem.addItems(actor, rewards, "loop finish rewards")
		if var.taskRefreshTime == 0 then
			var.taskRefreshTime = os.time()
			updataTimer(actor)
		end
	end
	
	s2cLooptaskInfo(actor)
	actorevent.onEvent(actor, aeFinishLoop, curnum)
	utils.logCounter(actor, "othersystem", 0, "", "looptask", "all finish")
end

--等级 开启第一个环任务
function onLevelUp(actor, level, oldLevel)
	if LoopTaskConfig[1].minLevel > oldLevel and LoopTaskConfig[1].minLevel <= level then
		createNextLoop(actor)
		s2cLooptaskInfo(actor)
	end
end

function onLogin(actor)
	if LActor.getLevel(actor) < LoopTaskConfig[1].minLevel then
		return
	end
	s2cLooptaskInfo(actor)
end

function onNewDay(actor, login)
	if LActor.getLevel(actor) < LoopTaskConfig[1].minLevel then
		return
	end
	local var = getActorVar(actor)
	if not var then return end
	var.loopTaskId = 0
	var.curTaskCount = EVERYDAY_MAX_TASK
	var.taskRefreshTime = 0
	var.finish = 0
	createNextLoop(actor)
	if not login then
		s2cLooptaskInfo(actor)
	end
end

function checkCanRefresh(data)
	if data.loopTaskId == EVERYDAY_TASK_COUNT or data.curTaskCount >= EVERYDAY_MAX_TASK or (data.loopTaskId + data.curTaskCount) > EVERYDAY_TASK_COUNT then
		return false
	end
	return true
end

function timer(actor)
	local data = getActorVar(actor)
	local var = LActor.getDynamicVar(actor)
	if not checkCanRefresh(data) then
		data.taskRefreshTime = 0
		LActor.cancelScriptEvent(actor,var.looptask.eid)
		s2cLooptaskInfo(actor)
		return
	end
	data.curTaskCount = data.curTaskCount + 1
	if not checkCanRefresh(data) then
		data.taskRefreshTime = 0
	else
		data.taskRefreshTime = os.time()		
		if data.curTaskCount == 1 then
			createNextLoop(actor)
		end
		local remaintime = (data.taskRefreshTime + REFRESH_TIME - os.time()) > 0 and (data.taskRefreshTime + REFRESH_TIME - os.time()) or 0
		var.looptask.eid = LActor.postScriptEventLite(actor, remaintime * 1000, timer, actor)
	end
	s2cLooptaskInfo(actor)
end

function updataTimer(actor) 
	local var = LActor.getDynamicVar(actor)
	local data = getActorVar(actor)
	
	if data.taskRefreshTime > 0 and checkCanRefresh(data) then
		local remaintime = data.taskRefreshTime + REFRESH_TIME - os.time()
		if remaintime < 0 then
			local cnt = math.floor(-remaintime / REFRESH_TIME)
			for i=1, cnt do
				data.curTaskCount = data.curTaskCount + 1
				if data.curTaskCount == 1 then
					createNextLoop(actor)
				end
				if not checkCanRefresh(data) then
					data.taskRefreshTime = 0
					s2cLooptaskInfo(actor)
					return
				end
			end
			data.taskRefreshTime = data.taskRefreshTime + cnt * REFRESH_TIME
			remaintime = (data.taskRefreshTime + REFRESH_TIME - os.time()) > 0 and (data.taskRefreshTime + REFRESH_TIME - os.time()) or 0
		end
		if var.looptask == nil then 
			var.looptask = {}
		-- else 
		-- 	LActor.cancelScriptEvent(actor,var.looptask.eid)
		end
		var.looptask.eid = LActor.postScriptEventLite(actor, remaintime * 1000, timer, actor)
	end
end

local function onInit(actor)
	updataTimer(actor)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeLevel, onLevelUp)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cTaskCmd_LoopReward, c2sLoopReward)
netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.csTaskCmd_LoopFullStar, c2sLoopFullStar)
netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cTaskCmd_LoopFinish, c2sLoopFinish)
netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cTaskCmd_LoopFinishReward, c2sGetFinishReward)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.loopInfo= function (actor)
	local var = getActorVar(actor)
	utils.printInfo("loop info", var.finish, var.star, var.curTaskId)
	return true
end
gmCmdHandlers.loopfinish = function (actor)
	local var = getActorVar(actor)
	local taskConf = LoopTaskConfig[var.curTaskId]
	var.curValue = taskConf.target
	var.state = taskcommon.statusType.emCanAward
	actorevent.onEvent(actor, aeLoopTaskFinish, var.curTaskId)	
	s2cLooptaskInfo(actor)
	return true
end

gmCmdHandlers.looprefresh = function (actor)
	timer(actor)
	return
end
