--微信任务
module("wechattask", package.seeall)

--[[
任务处理逻辑
1.初始化任务分组，分为界面分组和任务分组
2.界面分组是用于区分界面的，1-好友邀请，2-好友齐聚，3-好友转生，4-好友SVIP
3.任务分组是用于显示任务列表的,相同分组的任务只显示一个
4.领取奖励后，由于需要删除一个，再添加一个，所以直接下发界面中的所有任务
5.完成的任务将不显示在界面中
6.如果该任务是该分组中最后一个，则显示该任务
]]

local TaskGroup = {} --任务分组,相同分组的任务同时只显示一个

local function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then
        return nil
    end
    if not var.wechattask then
        var.wechattask = {
            tasks = {},
        }
        local tasks = var.wechattask.tasks
        for group, config in ipairs(WeChatTaskConfig) do
            if not tasks[group] then
                tasks[group] = {}
            end
            for id, conf in ipairs(config) do
                tasks[group][id] = {
                    id = id, --配置的任务id
                    status = 0, --任务的状态
                    progress = 0, --任务的进度
                    show = 0, --任务是否显示
                }
            end
        end
    end
    return var.wechattask
end

--用于初始化任务
--默认会初始化所有任务
--当配置有新增的任务时，需要初始化新增的任务
local function initWXTask(actor, var, group, id)
    if not var.tasks[group] then
        var.tasks[group] = {}
    end
    var.tasks[group][id] = {
        id = id,
        status = 0,
        progress = 0,
        show = 0,
    }

    local config = WeChatTaskConfig[group][id]
    local taskType = config.type
    if taskcommon.getHandleType(taskType) == taskcommon.eCoverType then
        local record = taskevent.getRecord(actor)
        local value = 0
        if taskevent.needParam(taskType) then
            if record[taskType] == nil then record[taskType] = {} end
            for _, param in pairs(config.param) do 
                if record[taskType][param] then 
                    value = math.max(value, record[taskType][param])
                end
            end
        else
            value = record[taskType] or taskevent.initRecord(taskType, actor)
        end
        var.tasks[group][id].progress = value
        if value >= config.target then
            var.tasks[group][id].status = taskcommon.statusType.emCanAward
        end
    end
end

--将配置表中的任务配置进行分组
--第一层为界面分组，用于前端区分界面
--第二层为任务分组，相同任务分组的只会显示一个
local function initTaskGroup()
    for group, config in ipairs(WeChatTaskConfig) do
        if not TaskGroup[group] then
            TaskGroup[group] = {}
        end
        for id, conf in ipairs(config) do
            local taskgroup = conf.taskgroup
            if not TaskGroup[group][taskgroup] then
                TaskGroup[group][taskgroup] = {}
            end
            table.insert(TaskGroup[group][taskgroup], id)
        end
    end
end

--更新任务进度
--需要注意，这里的更新任务只通过wechatsystem调用
--不通过taskevent管理
function updateWXTaskValue(actor, taskType, param, value)
    local var = getActorVar(actor)
    if not var then return end
    for group, config in pairs(WeChatTaskConfig) do
        for id, conf in ipairs(config) do
            repeat
                if (conf.type ~= taskType) then break end
                if (conf.param[1] ~= -1) and not utils.checkTableValue(conf.param, param) then --有-1时不对参数做验证
                    break
                end
                
                if not (var.tasks[group] and var.tasks[group][id]) then
                    initWXTask(actor, var, group, id)
                end
                local taskVar = var.tasks[group][id]
                if taskVar.status ~= taskcommon.statusType.emDoing then break end --任务已完成
                if taskcommon.getHandleType(taskType) == taskcommon.eAddType then
                    taskVar.progress = taskVar.progress + value
                elseif taskcommon.getHandleType(taskType) == taskcommon.eCoverType then
                    if value > (taskVar.progress or 0) then
                        taskVar.progress = value
                    end
                end

                if taskVar.progress >= conf.target then
                    taskVar.status = taskcommon.statusType.emCanAward
                end
                if taskVar.show == 1 then
                    s2cWeChatTask(actor, group, id, taskVar.progress, taskVar.status)
                end
            until(true)
        end
    end
end

--领取微信任务奖励
--由于前端无法处理列表中不存在的任务
--所以领取奖励后要更新界面中的所有任务(删除不显示的任务)
function GetWeChatTaskReward(actor, group, taskid)
    local config = WeChatTaskConfig[group] and WeChatTaskConfig[group][taskid]
    if not config then
        print("WeChatTaskConfig not find!  group =", group, "taskid =", taskid)
        return
    end
    
    local var = getActorVar(actor)
    local taskVar = var.tasks[group] and var.tasks[group][taskid]
    if not taskVar then
        print("taskVar not find! group =", group, "taskid =", taskid)
        return
    end
    
    if taskVar.status ~= taskcommon.statusType.emCanAward then
        print("taskVar can't reward status =", taskVar.status)
        return
    end
    
    local rewards = config.rewards
    if not actoritem.checkEquipBagSpaceJob(actor, rewards) then return end
    
    taskVar.status = taskcommon.statusType.emHaveAward
    actoritem.addItems(actor, rewards, "wechat task rewards")
    
    s2cWeChatTaskByGroup(actor, config.group)
end

----------------------------------------------------------------------------------
--协议处理

--88-1 信息
function s2cWeChatTaskInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wechat, Protocol.sWechatCmd_TaskInfo)
    if pack == nil then return end
    LDataPack.writeChar(pack, #TaskGroup)
    for group, taskgroup in ipairs(TaskGroup) do
        LDataPack.writeChar(pack, group)
        LDataPack.writeShort(pack, #taskgroup)
        for _, tasks in ipairs(taskgroup) do
            local taskid = tasks[#tasks]
            local rewardCount = #tasks
            local taskVar
            for __, id in ipairs(tasks) do
                taskVar = var.tasks[group] and var.tasks[group][id]
                if not taskVar then
                    initWXTask(actor, var, group, id)
                    taskVar = var.tasks[group][id]
                end
                if taskVar.status ~= taskcommon.statusType.emHaveAward then
                    taskid = id
                    taskVar.show = 1
                    break
                else
                    taskVar.show = 0
                    rewardCount = rewardCount - 1
                end
            end LDataPack.writeShort(pack, taskid)
            LDataPack.writeChar(pack, taskVar.status)
            LDataPack.writeDouble(pack, taskVar.progress)
            LDataPack.writeChar(pack, rewardCount)
        end
    end
    LDataPack.flush(pack)
end

--88-2 领取微信任务奖励
function c2sGetWeChatTaskReward(actor, packet)
    local group = LDataPack.readChar(packet)
    local taskid = LDataPack.readShort(packet)
    GetWeChatTaskReward(actor, group, taskid)
end

--88-2 更新单个任务
function s2cWeChatTask(actor, group, id, progress, status)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wechat, Protocol.sWeChatCmd_UpdateTask)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, group)
    LDataPack.writeShort(pack, id)
    LDataPack.writeChar(pack, status)
    LDataPack.writeDouble(pack, progress)
    LDataPack.flush(pack)
end

--88-3 更新一组任务
function s2cWeChatTaskByGroup(actor, group)
    local var = getActorVar(actor)
    if not var then return end
    if not TaskGroup[group] then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wechat, Protocol.sWeChatCmd_UpdateTaskGroup)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, group)
    LDataPack.writeShort(pack, #TaskGroup[group])
    for _, tasks in ipairs(TaskGroup[group]) do
        local taskid = tasks[#tasks]
        local rewardCount = #tasks
        local taskVar
        for __, id in ipairs(tasks) do
            taskVar = var.tasks[group] and var.tasks[group][id]
            if not taskVar then
                initWXTask(actor, var, group, id)
                taskVar = var.tasks[group][id]
            end
            
            if taskVar.status ~= taskcommon.statusType.emHaveAward then
                taskid = id
                taskVar.show = 1
                break
            else
                taskVar.show = 0
                rewardCount = rewardCount - 1
            end
        end
        LDataPack.writeShort(pack, taskid)
        LDataPack.writeChar(pack, taskVar.status)
        LDataPack.writeDouble(pack, taskVar.progress)
        LDataPack.writeChar(pack, rewardCount)
    end
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function onLogin(actor)
    s2cWeChatTaskInfo(actor)
end

--现在不需要每日重置任务状态了
-- local function onNewDay(actor, login)
--     local var = getActorVar(actor)
--     if not var then return end
--     for group, config in ipairs(WeChatTaskConfig) do
--         for id, conf in ipairs(config) do
--             if conf.isNewday ~= 0 then
--                 local taskVar = var.tasks[group] and var.tasks[group][id]
--                 if taskVar then
--                     taskVar.status = 0
--                     taskVar.progress = 0
--                 else
--                     initWXTask(actor, var, group, id)
--                 end
--             end
--         end
--     end
--     if not login then
--         s2cWeChatTaskInfo(actor)
--     end
-- end

----------------------------------------------------------------------------------
--初始化
local function init()
    if System.isCrossWarSrv() then return end
    initTaskGroup()
    
    actorevent.reg(aeUserLogin, onLogin)
    
    netmsgdispatcher.reg(Protocol.CMD_Wechat, Protocol.cWechatCmd_TaskGetReward, c2sGetWeChatTaskReward)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.wxTaskRward = function (actor, args)
    local taskid = tonumber(args[1])
    GetWeChatTaskReward(actor, taskid)
end

gmCmdHandlers.wxTaskClear = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.wechattask = nil
    s2cWeChatTaskInfo(actor)
end

