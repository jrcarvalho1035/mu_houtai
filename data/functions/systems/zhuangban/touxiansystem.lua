--头衔系统
module("touxiansystem", package.seeall )

TouxianTypeCount = 0

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.touxian then var.touxian = {} end
    if not var.touxian.level then var.touxian.level = 0 end
    if not var.touxian.exp then var.touxian.exp = 0 end
    if not var.touxian.dailystatus then var.touxian.dailystatus = {} end
    if not var.touxian.tasks then var.touxian.tasks = {} end
    return var.touxian
end

local function initTask(actor, conf)
	local var = {}
    var.id = conf.id
	var.progress = 0
    var.status = taskcommon.statusType.emDoing

	local taskHandleType = taskcommon.getHandleType(conf.type)
	if taskHandleType == taskcommon.eCoverType then
		local record = taskevent.getRecord(actor)
		if taskevent.needParam(conf.type) then
			if record[conf.type] == nil then
				record[conf.type] = {}
			end
			var.progress = 0
			for k, v in pairs(conf.param) do
				if record[conf.type][v] then var.progress = record[conf.type][v] break end
			end
		else
			var.progress = record[conf.type] or taskevent.initRecord(conf.type, actor)
        end
		if var.progress >= conf.target then --成就完成
			var.status = taskcommon.statusType.emCanAward
		end
	end
	return var
end

local function touxianTaskInit(actor)
	local var = getActorVar(actor)
	for id, conf in pairs(TouxianTaskConfig) do
        if conf.head == 1 then
			if not var.tasks[conf.aType] and guajifuben.getCustom(actor) >= conf.needcustom then
				var.tasks[conf.aType] = initTask(actor, conf)
			end
		end
	end
end

local function updateTask(taskType, taskVar, value)
	if (taskcommon.getHandleType(taskType) == taskcommon.eAddType) then
		--这是叠加类型的
		taskVar.progress = taskVar.progress + value
		return true
	elseif (taskcommon.getHandleType(taskType) == taskcommon.eCoverType) then
		--这是覆盖类型的
		if (value > taskVar.progress) then
			taskVar.progress = value
			return true
		end
	end
	return false
end

--外部接口
function updateTaskValue(actor, taskType, param, value)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.touxian) then return end
	if taskcommon.taskTypeHandleType[taskType] ~= taskcommon.eCoverType then
		return
	end
	local var = getActorVar(actor)
	if not var then return end --触发时玩家不在线
	for i=1, TouxianTypeCount do
        repeat
            if not var.tasks[i] then break end
			local config = TouxianTaskConfig[var.tasks[i].id]
			if not config or taskType ~= config.type or var.tasks[i].status ~= taskcommon.statusType.emDoing then break end
			if config.param[1] ~= -1 and  not utils.checkTableValue(config.param, param) then break end
			updateTask(taskType, var.tasks[i], value)
			if var.tasks[i].progress < config.target then
				s2cTaskUpdate(actor, i)
				break
			end
			var.tasks[i].status = taskcommon.statusType.emCanAward
			s2cTaskUpdate(actor, i)
		until(true)
	end
end

function s2cTaskUpdate(actor, tp)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhuangBan, Protocol.sTouxianCmd_UpdateTask)
    LDataPack.writeChar(pack, tp)
    LDataPack.writeInt(pack, var.tasks[tp].id)
    LDataPack.writeChar(pack, var.tasks[tp].status)
    LDataPack.writeDouble(pack, var.tasks[tp].progress)
    LDataPack.flush(pack)
end

local function updateAttr(actor, calc)
	local var = getActorVar(actor)
    if var.level > 0 then
        local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Touxian)
        attr:Reset()
        for k, v in ipairs(TouxianConfig[var.level].attr) do
            attr:Set(v.type, v.value)
        end
    end
    if calc then
        LActor.reCalcAttr(actor)
    end
end

function getTouxian(actor)
    local var = getActorVar(actor)
    return TouxianConfig[var.level].stage
end

--头衔信息
function sendTouxianInfo(actor, tp)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhuangBan, Protocol.sTouxianCmd_Info)
    LDataPack.writeShort(pack, var.level)
    LDataPack.writeInt(pack, var.exp)
    LDataPack.writeShort(pack, #TouxianConfig)
    for k in ipairs(TouxianConfig) do
        LDataPack.writeChar(pack, var.dailystatus[k] or 1)
    end

    local count = 0
    local countPos = LDataPack.getPosition(pack)
    LDataPack.writeChar(pack, count)
    for i = 1, TouxianTypeCount do
		if var.tasks[i] then
			LDataPack.writeChar(pack, i)
            LDataPack.writeInt(pack, var.tasks[i].id)
			LDataPack.writeChar(pack, var.tasks[i].status)
			LDataPack.writeDouble(pack, var.tasks[i].progress)
			count = count + 1
		end
    end
	local newpos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, countPos)
	LDataPack.writeChar(pack, count)
    LDataPack.setPosition(pack, newpos)
    LDataPack.flush(pack)
end

function s2cGetTaskReturn(actor, tp)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhuangBan, Protocol.sTouxianCmd_GetTaskReward)
    LDataPack.writeShort(pack, var.level)
    LDataPack.writeInt(pack, var.exp)
    LDataPack.writeChar(pack, tp)
    LDataPack.writeInt(pack, var.tasks[tp].id)
    LDataPack.writeChar(pack, var.tasks[tp].status)
    LDataPack.writeDouble(pack, var.tasks[tp].progress)
    LDataPack.flush(pack)
end

function c2sGetTaskReward(actor, pack)
    local tp = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    if not var.tasks[tp] then return end
    local conf = TouxianTaskConfig[var.tasks[tp].id]
    if var.tasks[tp].status ~= taskcommon.statusType.emCanAward then
		return
    end

    var.tasks[tp].status = taskcommon.statusType.emHaveAward
    actoritem.addItems(actor, conf.awardList, "touxian task reward")

    for k, v in ipairs(conf.awardList) do
        if v.id == NumericType_SoulValue then
            var.exp = var.exp + v.count
            break
        end
    end

    if TouxianConfig[var.level + 1] and var.exp >= TouxianConfig[var.level].soulvalue then
        local before = var.level
        var.level = var.level + 1
        var.dailystatus[var.level] = 0
        if TouxianConfig[var.level].stage > TouxianConfig[before].stage then
            LActor.setTouxian(actor, TouxianConfig[var.level].stage)
            actoritem.addItems(actor, TouxianConfig[var.level].stagereward, "touxian stage up reward")
            actorevent.onEvent(actor, aeNotifyFacade)
        end
        utils.rankfunc.updateRankingList(actor, var.level, RankingType_Touxian)
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhuangBan, Protocol.sTouxianCmd_GetDailyReward)
        LDataPack.writeShort(pack, var.level)
        LDataPack.writeChar(pack, var.dailystatus[var.level])
        LDataPack.flush(pack)
    end

    if TouxianTaskConfig[conf.next] then
		var.tasks[conf.aType] = initTask(actor, TouxianTaskConfig[conf.next])
    end
    s2cGetTaskReturn(actor, tp)
    updateAttr(actor, true)
end

function c2sGetDailyReward(actor, pack)
    local level = LDataPack.readShort(pack)
    local var = getActorVar(actor)
    if var.dailystatus[level] == 1 then return end
    var.dailystatus[level] = 1
    actoritem.addItems(actor, TouxianConfig[level].rewards, "touxian daily reward")
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhuangBan, Protocol.sTouxianCmd_GetDailyReward)
    LDataPack.writeShort(pack, level)
    LDataPack.writeChar(pack, var.dailystatus[level])
    LDataPack.flush(pack)
end

function onLogin(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.touxian) then return end
    local var = getActorVar(actor)
    utils.rankfunc.updateRankingList(actor, var.level, RankingType_Touxian)
    sendTouxianInfo(actor)
end

function getTouxianStage(actor)
    local var = getActorVar(actor)
    return TouxianConfig[var.level] and TouxianConfig[var.level].stage or 0
end


local function ehInit(actor)
    touxianTaskInit(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.touxian) then return end
    updateAttr(actor)
    local var = getActorVar(actor)
    LActor.setTouxian(actor, getTouxianStage(actor))
end

local function onNewDay(actor, login)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.touxian) then return end
    local var = getActorVar(actor)
    var.dailystatus[var.level] = 0
    if not login then
        sendTouxianInfo(actor)
    end
end

function onCustomChange(actor, custom, oldcustom)
    local var = getActorVar(actor)
    local change = false
    if LimitConfig[actorexp.LimitTp.touxian].custom > oldcustom and LimitConfig[actorexp.LimitTp.touxian].custom <= custom then
        var.level = 1
        var.dailystatus[var.level] = 0
        LActor.setTouxian(actor, TouxianConfig[var.level].stage)
        actorevent.onEvent(actor, aeNotifyFacade)
        change = true
        updateAttr(actor, true)
    end
	for id, conf in pairs(TouxianTaskConfig) do
        if conf.head == 1 then
			if not var.tasks[conf.aType] and custom >= conf.needcustom and oldcustom < conf.needcustom then
                var.tasks[conf.aType] = initTask(actor, conf)
                change = true
			end
        end
    end
    if change then
        sendTouxianInfo(actor)
    end
end

local function init()
	actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeInit, ehInit)
    actorevent.reg(aeNewDayArrive, onNewDay)
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
    actorevent.reg(aeCustomChange, onCustomChange)
	netmsgdispatcher.reg(Protocol.CMD_ZhuangBan, Protocol.cTouxianCmd_GetTaskReward, c2sGetTaskReward)
	netmsgdispatcher.reg(Protocol.CMD_ZhuangBan, Protocol.cTouxianCmd_GetDailyReward, c2sGetDailyReward)
end

for id, conf in pairs(TouxianTaskConfig) do
	if TouxianTypeCount < conf.aType then
		TouxianTypeCount = conf.aType
	end
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.touxiantask = function (actor, args)
    local var = getActorVar(actor)
    for i=1, TouxianTypeCount do
        var.tasks[i].status = 1
    end
    sendTouxianInfo(actor)
	return true
end

gmCmdHandlers.touxianlevel = function (actor, args)
    local var = getActorVar(actor)
    var.level = tonumber(args[1])
    sendTouxianInfo(actor)
	return true
end

gmCmdHandlers.touxianexp = function (actor, args)
    local var = getActorVar(actor)
    var.exp = tonumber(args[1])
    sendTouxianInfo(actor)
	return true
end

gmCmdHandlers.touxianAll = function (actor, args)
    local var = getActorVar(actor)
    var.level = #TouxianConfig
    LActor.setTouxian(actor, TouxianConfig[var.level].stage)
    actorevent.onEvent(actor, aeNotifyFacade)
    utils.rankfunc.updateRankingList(actor, var.level, RankingType_Touxian)
    updateAttr(actor, true)
    sendTouxianInfo(actor)
    return true
end
