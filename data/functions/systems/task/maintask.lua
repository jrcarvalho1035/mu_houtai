--主线任务
module("maintask", package.seeall)
require("task.maintask")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.maintask then 
		var.maintask = {} 
		var.maintask.curId = 0 --当前做到的服务器记录id
		var.maintask.state = 0
		var.maintask.curValue = 0
	end
	return var.maintask
end

--当前的任务，用服务器id去查出任务id
function getMainTaskIdx(actor)
	local var = getActorVar(actor)
	if not var then return 1 end
	local data = System.getDyanmicVar()
	return data.g_maintaskKeys[var.curId] or 1
end

--当前服务器记录id
function getMainTaskCurId(actor)
	local var = getActorVar(actor)
	if not var then return 0 end
	return var.curId or 0
end

--当前任务状态
function getMainTaskState(actor)
	local var = getActorVar(actor)
	if not var then return 0 end
	return var.state or 0
end

--这个任务的配置
function getNowTaskConf(taskId)
	local data = System.getDyanmicVar()
	local idx = data.g_maintaskKeys[taskId]
	return MainTaskConfig[idx], idx
end

--接任务,taskId是服务器记录id
function onAcceptTask(actor, taskId)
	local data = System.getDyanmicVar()

	local var = getActorVar(actor)
	if not var then return end

	local idx = data.g_maintaskKeys[taskId] or 0
	local config = MainTaskConfig[idx]
	if not config then
		return
	end
	var.curId = taskId
	var.state = taskcommon.statusType.emDoing
	var.curValue = 0
	utils.logCounter(actor, "othersystem", taskId, "", "maintask", "accept")

	local tp = MainTaskConfig[idx].type
	local taskHandleType = taskcommon.getHandleType(tp)
	if taskHandleType == taskcommon.eCoverType or MainTaskConfig[idx].controlSync == 1 then
		local record = taskevent.getRecord(actor)
		local value = 0
		if taskevent.needParam(tp) then
			if record[tp] == nil then record[tp] = {} end
			value = 0
			for k, v in pairs(config.param) do 
				if record[tp][v] then value = record[tp][v]	break end
			end
		else
			value = record[tp] or taskevent.initRecord(tp, actor)
		end
		var.curValue = value
		--对获取历史数据的任务,这里做简单任务进度检测		
		if var.curValue >= config.target then
			if tp == taskcommon.taskType.emZhuanshengLevel then
				var.curValue = 1
			end
			var.state = taskcommon.statusType.emCanAward
		else
			if tp == taskcommon.taskType.emZhuanshengLevel then
				var.curValue = 0
			end
		end		
	end
	LActor.setMainTask(actor, var.curId)
	actorevent.onEvent(actor, aeMainTaskAccept, var.curId)
end

--更新任务进度
function updateTaskValue(actor, taskType, param, value)
	local var = getActorVar(actor)
	if not var then return end
	local config, idx = getNowTaskConf(var.curId)
	if not config then return end
	if config.type ~= taskType then return end
	if (config.param[1] ~= -1) and (not utils.checkTableValue(config.param, param)) then --有-1时不对参数做验证
		return 
	end 
	if var.state ~= taskcommon.statusType.emDoing then return end --状态不用再处理
	local change = false
	if taskcommon.getHandleType(taskType) == taskcommon.eAddType then
		var.curValue = (var.curValue or 0) + value
		change = true
	elseif taskcommon.getHandleType(taskType) == taskcommon.eCoverType then
		if value > (var.curValue or 0) then
			var.curValue = value
			change = true
		end
	end
	if change then		
		if var.curValue >= config.target then	
			if taskType == taskcommon.taskType.emZhuanshengLevel then
				var.curValue = 1
			end		
			var.state = taskcommon.statusType.emCanAward
		else
			if taskType == taskcommon.taskType.emZhuanshengLevel then
				var.curValue = 0
			end	
		end
		s2cMaintaskInfo(actor)
	else
		if taskType == taskcommon.taskType.emZhuanshengLevel then
			var.curValue = 0
		end	
	end
end

function onLogin(actor)
	-- local juqingdata = juqingtask.getVar(actor)
	-- if juqingdata.status ~= 2 then
	-- 	return
	-- end

	local var = getActorVar(actor)
	if not var then return end

	if not var.curId or var.curId == 0 then --初始主线任务
		onAcceptTask(actor, MainTaskConfig[1].id)
	end

	local conf = getNowTaskConf(var.curId)
	if not conf then return end --策划改配置有可能使现有的任务进度超出配置表
	if var.state == taskcommon.statusType.emHaveAward and MainTaskConfig[conf.next] then --自动接任务，配置有新增任务时的处理
		onAcceptTask(actor, MainTaskConfig[conf.next].id)
	end

	s2cMaintaskInfo(actor, true)
end

--------------------------------------------------------------------------------------------------------
--发送信息
function s2cMaintaskInfo(actor, isInit)
	local var = getActorVar(actor)
	if not var or var.curId==0 then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sTaskCmd_MainTaskInfo)
	if pack == nil then return end

	local id = getMainTaskIdx(actor)
	LDataPack.writeInt(pack, id)
	LDataPack.writeInt(pack, var.state or 0)
	LDataPack.writeInt(pack, var.curValue or 0)
	LDataPack.writeByte(pack, isInit and 1 or 0)
	LDataPack.flush(pack)
end

--完成任务
function c2sMainGetAwards(actor)
	--print("enter c2sMainGetAwards:actorid:" .. LActor.getActorId(actor))
	local var = getActorVar(actor)
	if not var then return end
	local curId = var.curId --记录这个任务的id
	local conf = getNowTaskConf(var.curId)
	if not conf then return end
	if LActor.getLevel(actor) < conf.level or LActor.getActorPower(LActor.getActorId(actor)) < conf.fight then return end --未激活

	if var.state ~= taskcommon.statusType.emCanAward then return end

	var.state = taskcommon.statusType.emHaveAward
	actoritem.addItemsByJob(actor, conf.awardList, "main_task:"..var.curId, 0, "maintask") --领奖励

	actorevent.onEvent(actor, aeMainTaskFinish, curId) --完成任务，一定要在onAcceptTask之前，使taskacceptaction要先删事件再增事件
	utils.logCounter(actor, "othersystem", curId, "", "maintask", "finish")
	if MainTaskConfig[conf.next] then
		onAcceptTask(actor, MainTaskConfig[conf.next].id)
	end
	s2cTaskReward(actor, curId)
	s2cMaintaskInfo(actor)
end

--领奖回包
function s2cTaskReward(actor, curId)
	local data = System.getDyanmicVar()
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sTaskCmd_TaskReward)
	if pack == nil then return end
	LDataPack.writeInt(pack, data.g_maintaskKeys[curId] or 0)--每日任务与环任务curId为空
	LDataPack.flush(pack)
end

actorevent.reg(aeUserLogin, onLogin, 1)
netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cTaskCmd_MainTaskReward, c2sMainGetAwards)

local function initGlobalData()
	local var = System.getDyanmicVar()
	var.g_maintaskKeys = {}
	for k, v in ipairs(MainTaskConfig) do --建立从任务id至任务key的寻找
		var.g_maintaskKeys[v.id] = k
	end
end
table.insert(InitFnTable, initGlobalData)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.maintaskSet = function (actor, args)
	local id = tonumber(args[1]) or #MainTaskConfig
	local var = getActorVar(actor)
	if not var then return end
	local start = var.curId --记录这个任务的id
	if id < var.curId then
		onAcceptTask(actor, MainTaskConfig[id].id)
	else
		for i = 1 , id - start do
			local curId = var.curId
			local conf = getNowTaskConf(var.curId)
			var.state = taskcommon.statusType.emHaveAward
			actoritem.addItemsByJob(actor, conf.awardList, "main_task:"..var.curId, 0, "maintask")
			actorevent.onEvent(actor, aeMainTaskFinish, curId)
			if MainTaskConfig[conf.next] then
				onAcceptTask(actor, MainTaskConfig[conf.next].id)
			end
		end
		--s2cTaskReward(actor, curId)
	end
	s2cMaintaskInfo(actor)
	return true
end

gmCmdHandlers.maintaskAll = function (actor, args)
	local maxid = #MainTaskConfig - 1
	local var = getActorVar(actor)
	if not var then return end
	var.curId = maxid
	local conf = getNowTaskConf(var.curId)
	if MainTaskConfig[conf.next] then
		onAcceptTask(actor, MainTaskConfig[conf.next].id)
		var.state = taskcommon.statusType.emCanAward
	end
	s2cMaintaskInfo(actor)
	return true
end

gmCmdHandlers.maintaskInit = function (actor, args)
	initGlobalData()
	return true
end

gmCmdHandlers.mtinfo = function (actor, args)
	local maintask = getActorVar(actor)
	
	--历史记录
	local config, idx = getNowTaskConf(maintask.curId)
	local hisvalue = 0
	local tp = config.type
	local taskHandleType = taskcommon.getHandleType(tp)
	if taskHandleType == taskcommon.eCoverType or config.controlSync == 1 then
		local record = taskevent.getRecord(actor)
		if taskevent.needParam(tp) then
			if record[tp] ~= nil then
				hisvalue = record[tp][config.param[1]] or 0
			end
		else
			hisvalue = record[tp] or 0
		end
	end

	print("maintask.curId:" .. maintask.curId)
	print("maintask.state:" .. maintask.state)
	print("maintask.curValue:" .. maintask.state)
	local msg = "任务ID：" .. maintask.curId .. "\n"
				.. "任务状态(0：进行中，1：可领，2：已领)：" .. maintask.state .. "\n"
				.. "任务进度：" .. maintask.curValue .. "\n"
				.. 	"历史数据：" .. hisvalue
	LActor.sendTipmsg(actor, msg, ttDialog)
	return true
end
