-- @version	2.0
-- @author	qianmeng
-- @date	2017-11-22 17:03:26.
-- @system	头衔系统

module("dailytasksystem", package.seeall)

function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.dailytaskdata then
		var.dailytaskdata = {
			dayRenown = 0,
			rewardsRecord = 0,
		}
	end
	if not var.dailytaskdata.mateLv then var.dailytaskdata.mateLv = 1 end
	if not var.dailytaskdata.taskFinishCnt then var.dailytaskdata.taskFinishCnt = {} end --完成次数
	if not var.dailytaskdata.taskGetCnt then var.dailytaskdata.taskGetCnt = {} end --领取次数
	return var.dailytaskdata
end

function getRenown(actor)
	local var = getActorVar(actor)
	if not var then return 0 end
	return var.renown or 0
end

function addRenown(actor, number)
	local var = getActorVar(actor)
	if not var then return end
	var.renown = (var.renown or 0) + number
	if number > 0 then
		var.dayRenown = var.dayRenown + number
	end
end

function getTarget(actor, conf)
	local vip = LActor.getVipLevel(actor)
	if conf.isbuy ~= "" then
		return conf.target + VipConfig[vip][conf.isbuy]
	end
	return conf.target
end

function updateTaskValue(actor, taskType, param, value)
	if taskcommon.taskTypeHandleType[taskType] ~= taskcommon.eAddType then
		return
	end
	local var = getActorVar(actor)
	if not var then return end
	local config = DailyTaskConfig[var.mateLv]

	for id, conf in pairs(config) do 
		repeat
			if (conf.type ~= taskType) then break end
			if (conf.param[1] ~= -1) and not utils.checkTableValue(conf.param, param) then --有-1时不对参数做验证
				break 
			end 
			if (var.taskFinishCnt[id] or 0) >= getTarget(actor, conf) then break end --任务奖励已领取完
			
			var.taskFinishCnt[id] = (var.taskFinishCnt[id] or 0) + value
			if var.taskFinishCnt[id] > getTarget(actor, conf) then
				var.taskFinishCnt[id] = getTarget(actor, conf)
			end
			s2cDailyTaskTask(actor, id, var.taskFinishCnt[id], var.taskGetCnt[id])
			break
		until(true)
	end
end

--求配适的等级
function getMateLevel(actor)
	local level = LActor.getLevel(actor)
	local mate = 0
	for lv, config in pairs(DailyTaskConfig) do
		if level >= lv and mate < lv then
			mate = lv
		end
	end
	return mate
end

----------------------------------------------------------------------------------------
function s2cDailyTaskInfo(actor)
	local var = getActorVar(actor)
	local config = DailyTaskConfig[var.mateLv]
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sDailyTask_Info)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.mateLv)
	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeShort(pack, count)
	for id, conf in pairs(config) do
		LDataPack.writeShort(pack, id)
		LDataPack.writeChar(pack, var.taskFinishCnt[id] or 0)
		LDataPack.writeChar(pack, var.taskGetCnt[id] or 0)
		LDataPack.writeChar(pack, getTarget(actor, conf))
		count = count + 1
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeShort(pack, count)
	LDataPack.setPosition(pack, npos)
	LDataPack.writeInt(pack, var.dayRenown)

	LDataPack.writeInt(pack, var.rewardsRecord)
	LDataPack.flush(pack)
end

function s2cDailyTaskTask(actor, id, value, status)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sDailyTask_Update)
	if pack == nil then return end
	LDataPack.writeChar(pack, id)
	LDataPack.writeChar(pack, value or 0)
	LDataPack.writeChar(pack, status or 0)
	LDataPack.flush(pack)
end

--声望任务领奖
function c2sDailyTaskHave(actor, packet)
	print("c2sDailyTaskHave")
	local id = LDataPack.readChar(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.dailytask) then return end
	local var = getActorVar(actor)
	if not var then return end
	local config = DailyTaskConfig[var.mateLv]
	local conf = config[id]
	if not conf then return end
	if not var.taskGetCnt[id] then var.taskGetCnt[id] = 0 end
	if not var.taskFinishCnt[id] then var.taskFinishCnt[id] = 0 end
	if var.taskGetCnt[id] >= getTarget(actor, conf) then
		return
	end
	if var.taskGetCnt[id] >= var.taskFinishCnt[id] then
		return
	end
	local cangetcnt = var.taskFinishCnt[id] - var.taskGetCnt[id]
	var.taskGetCnt[id] = var.taskFinishCnt[id]
	actoritem.addItem(actor, NumericType_Renown, conf.renown * cangetcnt, "renown task "..id)

	maintask.s2cTaskReward(actor) --任务领奖特效显示

	print("Protocol.CMD_AllTask:" .. Protocol.CMD_AllTask)
	print("Protocol.sDailyTask_Have:" .. Protocol.sDailyTask_Have)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sDailyTask_Have)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.dayRenown)
	LDataPack.writeChar(pack, id)
	LDataPack.writeChar(pack, var.taskFinishCnt[id])
	LDataPack.writeChar(pack, var.taskGetCnt[id])
	LDataPack.flush(pack)

	utils.logCounter(actor, "othersystem", id, "", "renowntask", "finish")
end

--领取声望奖励
function c2sDailyTaskReward(actor, packet)
	local id = LDataPack.readChar(packet)
	local conf = RenownRewardConfig[id]
	if not conf then return end
	local var = getActorVar(actor)
	if var.dayRenown < conf.renown then
		return
	end
	if System.bitOPMask(var.rewardsRecord, id) then
		return false
	end

	var.rewardsRecord = System.bitOpSetMask(var.rewardsRecord, id, true)
	actoritem.addItems(actor, conf.rewards[var.mateLv], "renown rewards")

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sDailyTask_Reward)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.rewardsRecord)
	LDataPack.flush(pack)
end

--------------------------------------------------------------------------------
function onLogin(actor)
	s2cDailyTaskInfo(actor)
end

--新的一天，重置声望任务
function onNewDay(actor, login)
	local var = getActorVar(actor)
	if not var then return end
	var.dayRenown = 0
	var.taskFinishCnt = {}
	var.taskGetCnt = {}
	var.rewardsRecord = 0
	var.mateLv = getMateLevel(actor)
	if not login then
		s2cDailyTaskInfo(actor)
	end
end

function onVipLevel(actor, level)
	s2cDailyTaskInfo(actor)
end

actorevent.reg(aeUserLogin,onLogin)
actorevent.reg(aeNewDayArrive,onNewDay)
actorevent.reg(aeVipLevel, onVipLevel)

netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cDailyTask_Reward, c2sDailyTaskReward)
netmsgdispatcher.reg(Protocol.CMD_AllTask, Protocol.cDailyTask_Have, c2sDailyTaskHave)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.dailytaskreward = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sDailyTaskReward(actor, pack)
end

gmCmdHandlers.dailyrenown = function (actor, args)
	local var = getActorVar(actor)
	var.dayRenown = tonumber(args[1])
	s2cDailyTaskInfo(actor)
	return true
end
gmCmdHandlers.dailytaskget = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sDailyTaskHave(actor, pack)
end

gmCmdHandlers.dailytaskset = function (actor, args)
	local lv = tonumber(args[1])
	local var = getActorVar(actor)


	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllTask, Protocol.sDailyTask_Up)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.touLv)
	LDataPack.flush(pack)
	actorevent.onEvent(actor, aeNotifyFacade, -1)
end

gmCmdHandlers.dailytaskfinish = function (actor, args)
	local var = getActorVar(actor)
	local config = DailyTaskConfig[var.mateLv]
	for id, conf in ipairs(config) do
		var.taskGetCnt[id] = taskcommon.statusType.emCanAward
	end
	s2cDailyTaskInfo(actor)
end
