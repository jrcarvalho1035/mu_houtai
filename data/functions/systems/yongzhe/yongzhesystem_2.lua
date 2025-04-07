-- 勇者之徵
module('yongzhe', package.seeall)

--[[
    open = 0, -- 开启标记
    season = 1, -- 第几赛季
    round = 1, -- 第几轮
    endTime = 0, -- 阶段结束时间
    deluxe = 0, -- 有没有购买98的圣徵
    chest = [0, 0, 0, 0], -- 有没有领取宝箱
    level = 0, -- 等级
    exp = 0, -- 经验
    lvReward={
        [1] = 1, -- 等级奖励领取状态
    },
    rTaskLen = 0, -- 阶段任务数量
    roundTask = {
        [1] = {
            id = 0, -- 任务id
            state = 0, -- 任务状态：0进行中，1可领奖，2已领奖
            done = 0, -- 完成次数
        }
    },
    sTaskLen = 0, -- 赛季任务数量
    sTask = {
        [1] = {
            id = 0, -- 任务id
            state = 0, -- 任务状态：0进行中，1可领奖，2已领奖
        }
    }
]]
local ROUND_DURATION = 7 * 24 * 3600
local ROUND_PER_SEASON = 4
local SEASON_DURATION = ROUND_PER_SEASON * ROUND_DURATION
local TaskType = {
    Round = 1,
    Season = 2
}
local RewardType = {
    Normal = 1,
    Extra = 2
}

local function initTaskValue(actor, task, taskConf)
    local task_type = taskConf.type
    local taskHandleType = taskcommon.getHandleType(task_type)
    task.value = 0
    if taskHandleType == taskcommon.eCoverType then
        local record = taskevent.getRecord(actor)
        local value = 0
        if taskevent.needParam(task_type) then
            if record[task_type] == nil then
                record[task_type] = {}
            end
            value = 0
            for k, v in pairs(taskConf.param) do
                if record[task_type][v] then
                    value = record[task_type][v]
                    break
                end
            end
        else
            value = record[task_type] or taskevent.initRecord(task_type, actor)
        end
        task.value = value
        --对获取历史数据的任务,这里做简单任务进度检测
        if task.value >= taskConf.target then
            if task_type == taskcommon.taskType.emZhuanshengLevel then
                task.value = 1
            end
            task.state = taskcommon.statusType.emCanAward
        else
            if task_type == taskcommon.taskType.emZhuanshengLevel then
                task.value = 0
            end
        end
    end
end

local function resetDaily(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    -- 每天重置任务状态
    local roundConf = YongZheTaskConfig[var.round]
    -- update: 限定配置的任务id必须是从1开始的连续数字,所以id==index
    if not var.rTask then
        var.rTask = {}
    end
    if roundConf then
        for id, taskConf in ipairs(roundConf) do
            if not var.rTask[id] then
                var.rTask[id] = {}
            end
            local task = var.rTask[id]
            task.id = taskConf.id
            task.done = task.done or 0
            task.state = taskcommon.statusType.emDoing
            initTaskValue(actor, task, taskConf)
        end
        var.rTaskLen = #roundConf
    else
        var.rTaskLen = 0
    end
end

local function resetRound(actor, round, var)
    if not var then
        var = getActorVar(actor)
    end
    var.round = round
    resetDaily(actor, var)
    -- 重围阶段任务的完成数
    for idx = 1, var.rTaskLen do
        local task = var.rTask[idx]
        task.done = 0
    end
end

local function resetSeason(actor, season, round, var)
    -- 新赛季重置任务状态
    if not var then
        var = getActorVar(actor)
    end
    var.season = season
    var.exp = 0
    var.level = 0
    var.deluxe = 0
    var.lvReward = {}

    var.sTask = {}
    local seasonConf = YongZheSeasonTaskConfig[var.season]
    if seasonConf then
        -- update: 限定配置的任务id必须是从1开始的连续数字,所以id==index
        for id, taskConf in ipairs(seasonConf) do
            var.sTask[id] = {}
            local task = var.sTask[id]
            task.id = taskConf.id
            task.state = taskcommon.statusType.emDoing
            initTaskValue(actor, task, taskConf)
        end
        var.sTaskLen = #seasonConf
    else
        -- 如果没有对应赛季的配置，就没有任务
        var.sTaskLen = 0
    end
    --重置经验宝箱领取状态
    var.chest = {}
    for i = 1, ROUND_PER_SEASON do
        var.chest[i] = 0
    end

    resetRound(actor, round, var)
end

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if var.yongzheData == nil then
        var.yongzheData = {}
    end
    var = var.yongzheData
    if not var.season then
        local openTime = os.time() + 86400 -- 第一赛季开启时间
        local pastTime = os.time() - openTime + 30 -- 已过去的秒数,多加点余地
        local season = 1 -- 默认第一赛季
        local round = 1 -- 默认第一轮
        if pastTime > 0 then
            season = math.ceil(pastTime / SEASON_DURATION) -- 第几赛季
            round = math.ceil((pastTime - (season - 1) * SEASON_DURATION) / ROUND_DURATION) -- 第几轮
        end
        resetSeason(actor, season, round, var)
    end

    return var
end

local function clearActorVar(actor)
    local var = LActor.getStaticVar(actor)
    var.yongzheData = nil
end

local function isOpen(actor, var)
    if not var then
        var = getActorVar(actor)
    end
    return var.open ~= nil
end

local function getRoundTask(actor, idx, var)
    if not var then
        var = getActorVar(actor)
    end

    if not var.rTask then
        var.rTask = {}
        var.rTaskLen = 0
    end

    return var.rTask[idx]
end

local function getSeasonTask(actor, idx, var)
    if not var then
        var = getActorVar(actor)
    end

    if not var.sTask then
        var.sTask = {}
    end

    return var.sTask[idx]
end

local function getChestList(actor, var)
    if not var then
        var = getActorVar(actor)
    end

    if not var.chest then
        return {0, 0, 0, 0}
    end
    local chest = {}
    for i = 1, ROUND_PER_SEASON do
        table.insert(chest, var.chest[i])
    end
    return chest
end

local function setChestList(actor, chest, var)
    if not var then
        var = getActorVar(actor)
    end

    if not var.chest then
        var.chest = {}
    end

    for i, c in ipairs(chest) do
        var.chest[i] = c
    end
end

local function isRewardTaken(actor, level, reward_type, var)
    if not var then
        var = getActorVar(actor)
    end
    if reward_type == RewardType.Normal then
        local r = var.lvReward[level]
        if not r or r == 0 or r == 2 then
            return false
        else
            return true
        end
    else
        local r = var.lvReward[level]
        if not r or r == 0 or r == 1 then
            return false
        else
            return true
        end
    end
end

local function setRewardTaken(actor, level, reward_type, var)
    if not var then
        var = getActorVar(actor)
    end
    if reward_type == RewardType.Normal then
        local r = var.lvReward[level]
        if not r or r == 0 then
            var.lvReward[level] = 1
        else
            var.lvReward[level] = 3
        end
    else
        local r = var.lvReward[level]
        if not r or r == 0 then
            var.lvReward[level] = 2
        else
            var.lvReward[level] = 3
        end
    end
end

local function sendData(actor, var)
    if not var then
        var = getActorVar(actor)
    end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sYongzheCmd_Info)
    if pack then
        local chest = getChestList(actor, var)
        LDataPack.writeChar(pack, var.season)
        LDataPack.writeChar(pack, var.round)
        LDataPack.writeChar(pack, var.deluxe)
        LDataPack.writeChar(pack, #chest)
        for i, c in ipairs(chest) do
            LDataPack.writeChar(pack, c)
        end
        LDataPack.writeShort(pack, var.level)
        LDataPack.writeInt(pack, var.exp)

        LDataPack.writeShort(pack, var.level)
        for i = 1, var.level do
            local v = var.lvReward[i]
            if not v or v == 0 then
                LDataPack.writeByte(pack, 0)
                LDataPack.writeByte(pack, 0)
            elseif v == 1 then
                LDataPack.writeByte(pack, 1)
                LDataPack.writeByte(pack, 0)
            elseif v == 2 then
                LDataPack.writeByte(pack, 0)
                LDataPack.writeByte(pack, 1)
            else
                LDataPack.writeByte(pack, 1)
                LDataPack.writeByte(pack, 1)
            end
        end

        LDataPack.writeShort(pack, var.rTaskLen)
        for i = 1, var.rTaskLen do
            local task = var.rTask[i]
            LDataPack.writeByte(pack, task.state)
            LDataPack.writeInt(pack, task.value)
            LDataPack.writeShort(pack, task.done)
        end

        LDataPack.writeShort(pack, var.sTaskLen)
        for i = 1, var.sTaskLen do
            local task = var.sTask[i]
            LDataPack.writeByte(pack, task.state)
            LDataPack.writeInt(pack, task.value)
            if task.state == taskcommon.statusType.emHaveAward then
                LDataPack.writeShort(pack, 1)
            else
                LDataPack.writeShort(pack, 0)
            end
        end
        LDataPack.flush(pack)
    end
end

local function sendDeluxe(actor, var)
    if not var then
        var = getActorVar(actor)
    end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sYongzheCmd_Deluxe)
    if pack then
        LDataPack.writeByte(pack, var.deluxe)
        LDataPack.flush(pack)
    end
end

local function sendLevel(actor, var)
    if not var then
        var = getActorVar(actor)
    end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sYongzheCmd_Level)
    if pack then
        LDataPack.writeShort(pack, var.level)
        LDataPack.flush(pack)
    end
end

local function sendTask(actor, t_type, idx, var)
    if not var then
        var = getActorVar(actor)
    end
    local task
    if t_type == TaskType.Season then
        task = getSeasonTask(actor, idx, var)
    else
        task = getRoundTask(actor, idx, var)
    end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sYongzheCmd_Task)
    if pack then
        LDataPack.writeByte(pack, t_type)
        LDataPack.writeInt(pack, task.id)
        LDataPack.writeInt(pack, task.value)
        -- print('sendTask idx='..idx .. ' id='.. task.id.. ' value='..task.value)
        if t_type == TaskType.Round then
            LDataPack.writeInt(pack, task.done)
        else
            if task.state == taskcommon.statusType.emHaveAward then
                LDataPack.writeInt(pack, 1)
            else
                LDataPack.writeInt(pack, 0)
            end
        end
        LDataPack.writeByte(pack, task.state)
        LDataPack.flush(pack)
    end
end

local function sendResponseTaskReward(actor, t_type, task, var)
    if not var then
        var = getActorVar(actor)
    end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sYongzheCmd_ResponseTaskReward)
    if pack then
        LDataPack.writeByte(pack, t_type)
        LDataPack.writeInt(pack, task.id)
        LDataPack.writeByte(pack, task.state)
        LDataPack.writeShort(pack, task.done or 1)
        LDataPack.writeShort(pack, var.level)
        LDataPack.writeInt(pack, var.exp)
        LDataPack.flush(pack)
    end
end

local function sendResponseChestReward(actor, round, var)
    if not var then
        var = getActorVar(actor)
    end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sYongzheCmd_ResponseChestReward)
    if pack then
        local chest = getChestList(actor, var)
        LDataPack.writeShort(pack, var.level)
        LDataPack.writeInt(pack, var.exp)
        LDataPack.writeByte(pack, round)
        LDataPack.writeByte(pack, var.chest[round])
        LDataPack.flush(pack)
    end
end

local function sendResponseReward(actor, level, reward_type, var)
    if not var then
        var = getActorVar(actor)
    end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sYongzheCmd_ResponsseReward)
    if pack then
        LDataPack.writeByte(pack, reward_type)
        LDataPack.writeInt(pack, level)
        LDataPack.writeByte(pack, 1)
        LDataPack.flush(pack)
    end
end

local function addExp(actor, value, var)
    if not var then
        var = getActorVar(actor)
    end
    local newExp = (var.exp or 0) + value
    local newLv = var.level
    local send = false
    if newExp < 0 then
        newExp = 0
    else
        for i = 1, 100 do
            -- 暂定，一次最多升100级，有需要再改
            local lvConf = YongZheLevelConfig[newLv + 1]
            if lvConf then
                -- 未满级
                lvConf = YongZheLevelConfig[newLv]
                if newExp >= lvConf.exp then
                    newExp = newExp - lvConf.exp
                    newLv = newLv + 1
                else
                    break
                end
            else
                -- 满级不再加经验
                newExp = 0
                break
            end
        end
        if var.exp ~= newExp or var.level ~= newLv then
            send = true
        end
        var.exp = newExp
        var.level = newLv
    end
    if send then
        utils.logCounter(actor, "yongzhe exp", value, newLv, newExp)
        sendData(actor, var)
    end
end

local function getLevelReward(actor, level, reward_type, var)
    if not var then
        var = getActorVar(actor)
    end
    if level > var.level then
        return
    end
    if reward_type == RewardType.Extra and var.deluxe ~= 1 then
        return
    end
    if isRewardTaken(actor, level, reward_type, var) then
        print('reward already taken')
        return
    end
    local seasonConf = YongZheRewardConfig[var.season]
    local lvConf = seasonConf[level]
    setRewardTaken(actor, level, reward_type, var)
    if reward_type == RewardType.Extra then
        actoritem.addItem(actor, lvConf.reward2.id, lvConf.reward2.count, 'yongzhe')
    else
        actoritem.addItem(actor, lvConf.reward.id, lvConf.reward.count, 'yongzhe')
    end
    sendResponseReward(actor, level, reward_type, var)
end

local function buyDeluxe(actor)
    local var = getActorVar(actor)

    if var.deluxe == 1 then
        return
    end

    var.deluxe = 1
    sendDeluxe(actor, var)

    rechargesystem.addVipExp(actor, YongZheConfig.vipExp)
    -- 发点券
    actoritem.addItem(actor, NumericType_Diamond, YongZheConfig.dianquan, 'yongzhe')
end

function buy(actorid)
    local actor = LActor.getActorById(actorid)

    if not actor then
        local pack = LDataPack.allocPacket()
        System.sendOffMsg(actorid, 0, OffMsgType_BuyYongZhe, pack)
    else
        buyDeluxe(actor)
    end

end

local function buyLevel(actor, toLv, var)
    if not var then
        var = getActorVar(actor)
    end
    local lv = var.level
    if toLv <= lv or YongZheConfig.maxBuyLv <= lv then
        return
    end

    if YongZheConfig.maxBuyLv < toLv then
        toLv = YongZheConfig.maxBuyLv
    end

    local cost = 0
    for l = lv, toLv - 1 do
        local lvConf = YongZheLevelConfig[l]
        cost = cost + lvConf.price
    end
    if not actoritem.checkItem(actor, NumericType_Diamond, cost) then
        return
    end

    --先扣钱
    actoritem.reduceItem(actor, NumericType_Diamond, cost, 'yongzhe')

    var.level = toLv

    sendLevel(actor, var)
end

local function getChestReward(actor, round, var)
    if not var then
        var = getActorVar(actor)
    end
    if var.deluxe ~= 1 then
        -- 没交钱，不给领
        return
    end
    if round > var.round or var.chest[round] == 1 then
        return
    end
    -- 可以领
    local seasonConf = YongZheSaiJiConfig[var.season]
    local exp = seasonConf.exp[var.round]
    addExp(actor, exp, var)
    var.chest[round] = 1
    sendResponseChestReward(actor, round, var)
end

local function getTaskReward(actor, task_type, id, var)
    if not var then
        var = getActorVar(actor)
    end
    local task
    local taskConf
    if task_type == TaskType.Round then
        task = getRoundTask(actor, id, var)
        if not task then
            print('round task not exist id=' .. id)
            return
        end
        if task.state ~= taskcommon.statusType.emCanAward then
            print('round task not finished id=' .. id .. ' state=' .. task.state)
            return
        end

        local roundConf = YongZheTaskConfig[var.round]
        taskConf = roundConf[task.id]
        if task.done >= taskConf.done then
            print('round task.done=' .. task.done .. ' conf.done=' .. taskConf.done)
            return
        end
        task.done = task.done + 1
    else
        task = getSeasonTask(actor, id, var)
        if not task then
            print('season task not exist id=' .. id)
            return
        end
        if task.state ~= taskcommon.statusType.emCanAward then
            print('season task not finished id=' .. id .. ' state=' .. task.state)
            return
        end
        local seasonConf = YongZheSeasonTaskConfig[var.season]
        taskConf = seasonConf[task.id]
    end
    task.state = taskcommon.statusType.emHaveAward
    addExp(actor, taskConf.exp, var)
    sendResponseTaskReward(actor, task_type, task, var)
end

-- 领取任务奖励
local function c2sGetReward(actor, reader)
    local reward_type = LDataPack.readByte(reader)
    local level = LDataPack.readInt(reader)
    return getLevelReward(actor, level, reward_type)
end

local function c2sGetChestReward(actor, reader)
    local round = LDataPack.readInt(reader)
    return getChestReward(actor, round)
end

local function c2sGetTaskReward(actor, reader)
    local task_type = LDataPack.readByte(reader)
    local id = LDataPack.readInt(reader)
    return getTaskReward(actor, task_type, id)
end

local function c2sBuyLevel(actor, reader)
    local level = LDataPack.readShort(reader)
    return buyLevel(actor, level)
end

local function updateOneTask(task, taskType, param, value, taskConf)
    local change = false
    if task.state == taskcommon.statusType.emDoing then
        -- 任务进行中
        if (taskConf.param[1] ~= -1) and (not utils.checkTableValue(taskConf.param, param)) then --有-1时不对参数做验证
            return
        end
        local handleType = taskcommon.getHandleType(taskType)
        if handleType == taskcommon.eAddType then
            if taskType == taskcommon.taskType.emFortFloorAdd then
                -- 爬塔类型，更新的value是层数
                if not task.value or task.value < value then
                    task.value = value
                    change = true
                end
            else
                task.value = (task.value or 0) + value
                change = true
            end
        elseif handleType == taskcommon.eCoverType then
            if value > (task.value or 0) then
                task.value = value
                change = true
            end
        end
        if change then
            if task.value >= taskConf.target then
                if taskType == taskcommon.taskType.emZhuanshengLevel then
                    task.value = 1
                else
                    task.value = taskConf.target
                end
                task.state = taskcommon.statusType.emCanAward -- 任务完成
            else
                if taskType == taskcommon.taskType.emZhuanshengLevel then
                    task.value = 0
                end
            end
        else
            if taskType == taskcommon.taskType.emZhuanshengLevel then
                task.value = 0
            end
        end
    end
    return change
end

function updateTaskValue(actor, taskType, param, value)
    -- 任务进度从创号就开始统计
    local var = getActorVar(actor)
    local roundConf = YongZheTaskConfig[var.round]
    for id, taskConf in pairs(roundConf) do
        if taskType == taskConf.type then
            local task = var.rTask[id]
            if task and updateOneTask(task, taskType, param, value, taskConf) then
                sendTask(actor, TaskType.Round, id, var)
            end
        end
    end

    roundConf = YongZheSeasonTaskConfig[var.season]
    for id, taskConf in pairs(roundConf) do
        if taskType == taskConf.type then
            local task = var.sTask[id]
            if task and updateOneTask(task, taskType, param, value, taskConf) then
                sendTask(actor, TaskType.Season, id, var)
            end
        end
    end
end

local function tryOpen(actor, custom, var)
    if not var then
        var = getActorVar(actor)
    end
    local tp = actorexp.LimitTp.yongzhe
    local var = getActorVar(actor)

    if isOpen(actor, var) then
        return
    end
    if LimitConfig[tp].custom <= custom and System.getOpenServerDay() >= LimitConfig[tp].day then
        -- 条件满足
        var.open = 1
    end
end

local function onLogin(actor, isFirst, offTime, logoutTime, isCross)
    local var = getActorVar(actor)
    if not isOpen(actor, var) then
        tryOpen(actor, guajifuben.getCustom(actor), var)
    end
    if isOpen(actor, var) then
        sendData(actor)
    end
end

local function onNewDayArrive(actor, isLogin)
    local var = getActorVar(actor)
    local openTime = os.time() + 86400 -- 第一赛季开启时间
    local pastTime = os.time() - openTime -- 已过去的秒数,多加点余地
    if os.date('%H') == '00' then
        -- 0点有可能跨季
        pastTime = pastTime + 180 -- 时间加点余地，因为每个玩家触发事件的时间不一定是0秒
    end
    local season = 1
    local round = 1
    if pastTime > 0 then
        season = math.ceil(pastTime / SEASON_DURATION) -- 第几赛季
        round = math.ceil((pastTime - (season - 1) * SEASON_DURATION) / ROUND_DURATION) -- 第几轮
    end
    --print('onNewDayArrive season=' .. season .. ' round=' .. round .. ' past=' .. pastTime)
    if not var.season or var.season ~= season then
        -- 新赛季
        resetSeason(actor, season, round, var)
    elseif var.round ~= round then
        resetRound(actor, round, var)
    else
        resetDaily(actor, var)
    end
    tryOpen(actor, guajifuben.getCustom(actor), var)
    if isOpen(actor, var) and not isLogin then
        sendData(actor, var)
    end
end

local function onCustomChange(actor, custom, oldcustom)
    local var = getActorVar(actor)
    if not isOpen(actor, var) then
        tryOpen(actor, custom, var)
        if isOpen(actor, var) then
            sendData(actor, var)
        end
    end
end

function OffMsgBuyYongZhe(actor, offmsg)
    print(string.format('OffMsgBuyYongZhe actorid:%d ', LActor.getActorId(actor)))
    buyDeluxe(actor)
end

local function initGlobalData()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDayArrive, 2)
    actorevent.reg(aeCustomChange, onCustomChange)
    msgsystem.regHandle(OffMsgType_BuyYongZhe, OffMsgBuyYongZhe)

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cYongzheCmd_BuyLevel, c2sBuyLevel)
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cYongzheCmd_GetChestReward, c2sGetChestReward)
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cYongzheCmd_GetReward, c2sGetReward)
    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cYongzheCmd_GetTaskReward, c2sGetTaskReward)
end
table.insert(InitFnTable, initGlobalData)

local gmCmdHandlers = gmsystem.gmCmdHandlers
function gmCmdHandlers.yzFinishAll(actor, args)
    local var = getActorVar(actor)
    for i = 1, var.rTaskLen do
        local task = var.rTask[i]
        task.state = taskcommon.statusType.emCanAward
    end
    for i = 1, var.sTaskLen do
        local task = var.sTask[i]
        task.state = taskcommon.statusType.emCanAward
    end
    return true
end

function gmCmdHandlers.yzResetTask(actor, args)
    local var = getActorVar(actor)
    for i = 1, var.rTaskLen do
        local task = var.rTask[i]
        task.state = taskcommon.statusType.emDoing
    end
    for i = 1, var.sTaskLen do
        local task = var.sTask[i]
        task.state = taskcommon.statusType.emDoing
    end
    return true
end

function gmCmdHandlers.yzInfo(actor, args)
    local var = getActorVar(actor)
    print('------------------------yongzhe----------------------------')
    print('season=' .. var.season .. ' round=' .. var.round)
    print(' level=' .. var.level .. ' exp=' .. var.exp)
    print(' deluxe=' .. var.deluxe)
    print('\n')
    print('chest=[')
    local chest = getChestList(actor, var)
    for i, v in ipairs(chest) do
        print(v .. ', ')
    end
    print(']\n')
    print('reward lv=[')
    for lv = 1, var.level do
        local v = var.lvReward[lv]
        if v then
            print(' ' .. lv)
        end
    end
    print(']\n')
    print('round taskLen=' .. var.rTaskLen .. '\n')
    for i = 1, var.rTaskLen do
        local task = var.rTask[i]
        print('    task id=' .. task.id .. ' value=' .. task.value .. ' state' .. task.state .. ' done=' .. task.done)
        print('\n')
    end

    print('season taskLen=' .. var.sTaskLen .. '\n')
    for i = 1, var.sTaskLen do
        local task = var.sTask[i]
        print('    task id=' .. task.id .. ' value=' .. task.value .. ' state' .. task.state)
        print('\n')
    end

    return true
end

function gmCmdHandlers.yzReward(actor, args)
    local reward_type = tonumber(args[1]) or 1
    local lv = tonumber(args[2]) or 1
    getLevelReward(actor, lv, reward_type)
    return true
end

function gmCmdHandlers.yzExp(actor, args)
    local exp = tonumber(args[1]) or 100
    addExp(actor, exp)
    return true
end

function gmCmdHandlers.yzBuyLevel(actor, args)
    local lv = tonumber(args[1]) or 2
    buyLevel(actor, lv)
    return true
end

function gmCmdHandlers.yzClear(actor, args)
    clearActorVar(actor)
    return true
end

function gmCmdHandlers.yzTaskReward(actor, args)
    local task_type = tonumber(args[1]) or 1
    local id = tonumber(args[2]) or 1
    getTaskReward(actor, task_type, id)
    return true
end

function gmCmdHandlers.yzChest(actor, args)
    local round = tonumber(args[1]) or 1

    getChestReward(actor, round)
    return true
end

function gmCmdHandlers.yzNewSeason(actor, args)
    local var = getActorVar(actor)
    var.season = 0
    onNewDayArrive(actor, false)
    return true
end

function gmCmdHandlers.yzNextRound(actor, args)
    local var = getActorVar(actor)
    var.round = 0
    onNewDayArrive(actor, false)
    return true
end
