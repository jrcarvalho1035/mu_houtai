module("cstiantitask" , package.seeall)

gwinPoint = 1 		--胜点任务
pipeiCount = 2		--匹配次数
lianshengCount = 3	--连胜次数


local taskConf = CsttTaskConfig or {}
local levelMap = {}
for _,t in pairs(CsttTaskConfig) do
	levelMap[t.level] = levelMap[t.level] or {}
	levelMap[t.level].maxRate = levelMap[t.level].maxRate or 0
	levelMap[t.level].taskList = levelMap[t.level].taskList or {}

	levelMap[t.level].maxRate = levelMap[t.level].maxRate + (t.rate or 0)
	table.insert(levelMap[t.level].taskList, t)
end

function getActorVar(actor)
	local var = LActor.getCrossVar(actor)
	if var.cstiantitask == nil then
		var.cstiantitask = {}
	end

	for level,_ in pairs(levelMap) do
		if var.cstiantitask[level] == nil then
			csTianTiTaskInit(var.cstiantitask, level)
		end
	end

	return var.cstiantitask
end

--从当前等级随机出一个任务
local function randomTask(level)
	local conf = levelMap[level]
	if not conf then return end

	local rate = math.random(conf.maxRate)
	for _,t in pairs(conf.taskList) do
		if t.rate < rate then
			rate = rate - t.rate
		else
			return t
		end
	end
end

--初始化任务数据，在每天或赛季开始时
function csTianTiTaskInit(var, level)
	local task = randomTask(level)
	if not task then return end
	var[level] = {}
	var[level].id = task.id
	var[level].value = task.value or 0
	var[level].status = task.status or 0
end

--外部调用，更新天梯任务进度
function csTianTiTaskUpdate(actor, type, value)
	local var = getActorVar(actor)
	for level,_ in pairs(levelMap) do
		local id = var[level].id
		local conf = taskConf[id]
		if conf and conf.type == type and (var[level].value or 0) < conf.target then
			var[level].value = (var[level].value or 0) + value
		end
	end
end

--------------------------------------------------------------------------------------
function c2sTaskReward(actor, packet)
	local id = LDataPack.readInt(packet)
	local conf = taskConf[id]
	if not conf then return end

	local var = getActorVar(actor)
	local level = conf.level
	if var[level].id ~= id or var[level].value < conf.target or var[level].status == 1 then
		return
	end

	var[level].status = 1
	actoritem.addItems(actor, conf.reward, "TianTiTaskAward")
	s2cTianTiTaskInfo(actor)
end

function s2cTianTiTaskInfo(actor)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsTianti_TaskInfo)
	LDataPack.writeShort(npack, #levelMap)
	for level,_ in ipairs(levelMap) do
		LDataPack.writeInt(npack, var[level].id)
		LDataPack.writeInt(npack, level)
		LDataPack.writeInt(npack, var[level].value or 0)
		LDataPack.writeByte(npack, var[level].status or 0)
	end
	LDataPack.flush(npack)
end

function newday(actor, isLogin, isNewSession)
	local var = getActorVar(actor)
	for level,_ in pairs(levelMap) do
		if var[level] == nil or var[level].status == 1 or isNewSession then
			csTianTiTaskInit(var, level)
		end
	end

	if not isLogin then
		s2cTianTiTaskInfo(actor)
	end
end

function login(actor)
	s2cTianTiTaskInfo(actor)
end

actorevent.reg(aeNewDayArrive,newday)
actorevent.reg(aeUserLogin,login)
netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsTianti_TaskReward, c2sTaskReward)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.cstttask = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sTaskReward(actor, pack)
	return true
end
