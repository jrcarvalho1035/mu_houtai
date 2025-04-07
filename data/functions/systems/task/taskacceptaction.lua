module( "taskacceptaction", package.seeall )

EActionType = 
{	
	tpNone = 0, --无类型
	tp1 = 1, --挂机副本创建怪物
	tpMax = 2, --添加新的类型记得修改这个值
}

local ActionHandle = {}

function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.taskacceptaction then 
		var.taskacceptaction = {} 
	end
	return var.taskacceptaction
end

function getActorVarByActionID(actor, actionid)
	if not actor then return end
	local actionDatas = getActorVar(actor)	
	if not actionDatas[actionid] then
		actionDatas[actionid] = {}
	end
	return actionDatas[actionid]
end

--添加行为数据
local function AddActionData(actor, bigtasktype, config)
	local actionid = config.acceptActionID
	if actionid <= EActionType.tpNone or actionid >= EActionType.tpMax then return end
	local actionData = getActorVarByActionID(actor, actionid)
	local action = nil
	for i = 1, #actionData do
		if actionData[i] == nil then
			actionData[i] = {}
			action = actionData[i]
			break
		end
	end

	if action == nil then 
		actionData[#actionData + 1] = {}
		action = actionData[#actionData]
	end

	action.bigtasktype  = bigtasktype
	action.taskidx = config.idx

	ActionHandle[actionid](actor)
end

local function DelFunc(a,b)
	return a.idx == b.idx
end

--删除行为数据
local function DelActionData(actor, bigtasktype, config)
	if not config then return end
	local actionid = config.acceptActionID
	if actionid <= EActionType.tpNone or actionid >= EActionType.tpMax then return end
	local actionData = getActorVarByActionID(actor, actionid)
	for i = 1, #actionData do
		local action = actionData[i]
		if action and action.bigtasktype == bigtasktype and action.taskidx == config.idx then
			actionData[i] = nil
			break	
		end
	end
end

--挂机副本创建怪物
local function CreateGuajiMonster(actor)
	local myfbid = LActor.getFubenId(actor)
	local actionData = getActorVarByActionID(actor, EActionType.tp1)
	for i = 1, #actionData do
		local action = actionData[i]
		if action then
			local config = taskcommon.getTaskConfig(action.bigtasktype, action.taskidx)
			if not config then return end
			local params = config.acceptActionParams
			local fbid = params[1]
			local monid = params[2]
			local moncount = params[3]
			if myfbid == fbid then
				guajifuben.CreateExtraMonster(actor, fbid, monid, moncount)
			end
		end
	end
end

ActionHandle[1] = CreateGuajiMonster

local function DoAction(actor, actionid)
	ActionHandle[actionid](actor)
end

local function ehMainTaskAccept(actor, taskid)
	local config, idx = maintask.getNowTaskConf(taskid)
	if not config then return end
	AddActionData(actor, taskcommon.ETaskBigType.tp2, config)
end

local function ehMainTaskFinish(actor, taskid)
	local config, idx = maintask.getNowTaskConf(taskid)
	if not config then return end
	DelActionData(actor, taskcommon.ETaskBigType.tp2, config)
end




local function  ehEnternGuajiFuben(actor, fbid)
	DoAction(actor, EActionType.tp1)
end

local function ehNewDayArrive(actor)
	actionDatas = getActorVar(actor)
	if not actionDatas then return end
	for i = 1, EActionType.tpMax - 1 do
		repeat
			actionData = actionDatas[i]
			if not actionData then break end
			for j = 1, #actionData do
				local action = actionData[j]
				if action and action.bigtasktype ==  taskcommon.ETaskBigType.tp1 then
					actionData[j] = nil
				end
			end
		until(true)
	end
end

--事件监听
actorevent.reg(aeInterGuajifu, ehEnternGuajiFuben)
actorevent.reg(aeMainTaskAccept, ehMainTaskAccept) --主线任务接受
actorevent.reg(aeMainTaskFinish, ehMainTaskFinish) --主线任务完成
actorevent.reg(aeNewDayArrive, ehNewDayArrive) --新的一天到来
 

local  gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.taainfo = function (actor, args)
	local actionid = tonumber(args[1])
	if actionid == nil then return end
	local actionData = getActorVarByActionID(actor, actionid)
	local msg = ""
	for i = 1, #actionData do
		local action = actionData[i]
		if action then
			msg = msg .. "接受任务行为：任务大类型：" .. action.bigtasktype .. "\n"
				 .. "接受任务行为：任务idx：" .. action.taskidx .. "\n"
		end
	end
	LActor.sendTipmsg(actor, msg, ttDialog)
	return true
end


