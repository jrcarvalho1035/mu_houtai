module("zhuansheng", package.seeall)

local function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var.zhuansheng then 
		var.zhuansheng = {}
        var.zhuansheng.task = {}
        for i=1, 4 do
            var.zhuansheng.task[i] = {}
            var.zhuansheng.task[i].status = 0 --是否领取
            var.zhuansheng.task[i].progress = 0 --进度
        end
	end
	return var.zhuansheng
end

function getZSLevel(actor)
    return LActor.getZhuansheng(actor)
end

--判断转生等级是否足够
function checkZSLevel(actor, configlevel)
    return getZSLevel(actor) >= configlevel
end

--更新属性
function updateAttr(actor, calc)
	local addAttrs = {}
	local var = getActorVar(actor)
    local zhuansheng = getZSLevel(actor)
	if zhuansheng > 0 then
        for k, attr in pairs(ZhuanShengLevelConfig[zhuansheng].attr) do
            addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
        end
    end

	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_ZhuanSheng)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

--更新任务进度
function updateTaskValue(actor, taskType, param, value)
	local var = getActorVar(actor)
    if not var then return end
    
    local conf = ZhuanShengLevelConfig[LActor.getZhuansheng(actor)]
    if not conf then return end    
    for i=1, #conf.taskids do
        local taskconf = ZhuanshengTaskConfig[conf.taskids[i]]
        if not taskconf then return end
        if taskType == taskconf.type then
            repeat
                if (taskconf.param[1] ~= -1) and (not utils.checkTableValue(taskconf.param, param)) then --有-1时不对参数做验证
                    break
                end 

                if var.task[i].status ~= taskcommon.statusType.emDoing then break end --状态不用再处理
                
                local change = false
                if taskcommon.getHandleType(taskType) == taskcommon.eAddType then
                    var.task[i].progress = (var.task[i].progress or 0) + value
                    change = true
                elseif taskcommon.getHandleType(taskType) == taskcommon.eCoverType then
                    if value > (var.task[i].progress or 0) then
                        var.task[i].progress = value
                        change = true
                    end
                end

                if change then
                    if var.task[i].progress >= taskconf.target then
                        var.task[i].status = taskcommon.statusType.emCanAward
                    end
                    updateTaskInfo(actor, i)
                end
            until(true)
        end
    end
end

function setNextTask(actor, zslevel)
    local var = getActorVar(actor)
    if not var then return end
    
    local conf = ZhuanShengLevelConfig[LActor.getZhuansheng(actor)]
    if not conf then return end        
    if #conf.taskids == 0 then
        for i=1, #ZhuanShengLevelConfig[10000].taskids do
            var.task[i].status = 0
            var.task[i].progress = 0
        end
    else
        for i=1, #conf.taskids do
            local taskconf = ZhuanshengTaskConfig[conf.taskids[i]]
            if not taskconf then return end

            local value = 0
            local record = taskevent.getRecord(actor)
            if taskevent.needParam(taskconf.type) then
                if record[taskconf.type] == nil then record[taskconf.type] = {} end
                for k, v in pairs(taskconf.param) do 
                    if record[taskconf.type][v] then value = record[taskconf.type][v] break end
                end
            else
                value = record[taskconf.type] or taskevent.initRecord(taskconf.type, actor)
            end
            var.task[i].progress = value        
            if var.task[i].progress >= taskconf.target then
                var.task[i].status = taskcommon.statusType.emCanAward
                updateTaskInfo(actor, i)
            end
        end
    end
end

function updateTaskInfo(actor, index)
    local var = getActorVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Other, Protocol.sZhuanShengCmd_UpdataTask)
    LDataPack.writeChar(npack, index - 1)
    LDataPack.writeChar(npack, var.task[index].status)
    LDataPack.writeInt(npack, var.task[index].progress)
    LDataPack.flush(npack)
end

--领取任务奖励
function c2sGetTaskReward(actor, pack)
    local index = LDataPack.readChar(pack) + 1
    local var = getActorVar(actor)
    local conf = ZhuanShengLevelConfig[LActor.getZhuansheng(actor)]
    if not conf then return end
    local taskconf = ZhuanshengTaskConfig[conf.taskids[index]]
    if not taskconf then return end
    if var.task[index].status ~= taskcommon.statusType.emCanAward then return end

    var.task[index].status = taskcommon.statusType.emHaveAward
    actoritem.addItemsByMail(actor, taskconf.rewards, "zhuansheng task")
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Other, Protocol.sZhuanShengCmd_GetTaskReward)
    LDataPack.writeChar(npack, index - 1)
    LDataPack.writeChar(npack, var.task[index].status)
    LDataPack.flush(npack)
end

--一键转生
function c2sOneKey(actor, pack)
    local var = getActorVar(actor)
    local zhuansheng = LActor.getZhuansheng(actor)
    if not ZhuanShengLevelConfig[ZhuanShengLevelConfig[zhuansheng].nextId] then return end    
    local conf = ZhuanShengLevelConfig[zhuansheng]
    
    local count = 0
    for i=1, #conf.taskids do
        if var.task[i].status ~= taskcommon.statusType.emDoing then
            count = count + 1
        end
    end
    --如果任务都完成了，则不能消耗道具转生，只能点击转生按钮
    if count == #conf.taskids then return end
    local ishave = false
    for i=conf.cslevel, #ChongshengLevelConfig do
        if actoritem.checkItem(actor, ChongshengLevelConfig[i].needitem.id, ChongshengLevelConfig[i].needitem.count) then 
            actoritem.reduceItem(actor, ChongshengLevelConfig[i].needitem.id, ChongshengLevelConfig[i].needitem.count, "zhuansheng yijian zhansheng")
            ishave = true
            break
        end        
    end
    if not ishave then return end
    zhuansheng = ZhuanShengLevelConfig[zhuansheng].nextId
    LActor.setZhuansheng(actor, zhuansheng)
    local cslevel = ZhuanShengLevelConfig[zhuansheng].cslevel
    if conf.cslevel < cslevel then
        actoritem.addItemsByMail(actor, {[1]=ChongshengLevelConfig[cslevel].additem1}, "zhuansheng yijian zhansheng")
        actoritem.addItemsByMail(actor, ChongshengLevelConfig[cslevel].additem2, "zhuansheng yijian zhansheng")
    end
    for i=1, #conf.taskids do
        if var.task[i].status ~= taskcommon.statusType.emHaveAward then
            actoritem.addItemsByMail(actor, ZhuanshengTaskConfig[conf.taskids[i]].rewards, "zhuansheng yijian zhuansheng") 
        end
    end
    for i=1, #conf.taskids do
        var.task[i].status = 0
        var.task[i].progress = 0
    end
    updateAttr(actor, true)
    setNextTask(actor, zhuansheng)
    sendZhuanShengInfo(actor, Protocol.sZhuanShengCmd_OneKey)    
    actorevent.onEvent(actor, aeZhuansheng, zhuansheng, conf.id)
    print("c2sOneKey actorid".. LActor.getActorId(actor) ..  "zhuansheng level = "..zhuansheng)
end

--开始转生
function c2sZhuangSheng(actor, pack)
    local var = getActorVar(actor)
    local zhuansheng = LActor.getZhuansheng(actor)
    if not ZhuanShengLevelConfig[ZhuanShengLevelConfig[zhuansheng].nextId] then return end    
    local conf = ZhuanShengLevelConfig[zhuansheng]    
    for i=1, #conf.taskids do
        if var.task[i].status == taskcommon.statusType.emDoing then
            return
        end
    end
    zhuansheng = ZhuanShengLevelConfig[zhuansheng].nextId
    LActor.setZhuansheng(actor, zhuansheng)
    if conf.cslevel < ZhuanShengLevelConfig[zhuansheng].cslevel then
        actoritem.addItemsByMail(actor, {[1]=ChongshengLevelConfig[conf.cslevel+1].additem1}, "zhuansheng zhansheng")
        actoritem.addItemsByMail(actor, ChongshengLevelConfig[conf.cslevel+1].additem2, "zhuansheng zhansheng")
    end
    for i=1, #conf.taskids do
        if var.task[i].status == taskcommon.statusType.emCanAward then
            actoritem.addItemsByMail(actor, ZhuanshengTaskConfig[conf.taskids[i]].rewards, "zhuansheng zhuansheng") 
        end
    end
    for i=1, #conf.taskids do
        var.task[i].status = 0
        var.task[i].progress = 0
    end
    updateAttr(actor, true)
    actorevent.onEvent(actor, aeZhuansheng, zhuansheng, conf.id)
    setNextTask(actor, zhuansheng)
    sendZhuanShengInfo(actor, Protocol.sZhuanShengCmd_ZhuangSheng)
    print("c2sZhuangSheng actorid".. LActor.getActorId(actor) ..  "zhuansheng level = "..zhuansheng)
end

function sendZhuanShengInfo(actor, cmd)
    local zhuansheng = LActor.getZhuansheng(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Other, cmd)
    if pack == nil then return end
    LDataPack.writeInt(pack, zhuansheng)
    LDataPack.writeChar(pack, #ZhuanShengLevelConfig[zhuansheng].taskids)
	for i=1, #ZhuanShengLevelConfig[zhuansheng].taskids do        
        LDataPack.writeInt(pack, var.task[i].progress)
        LDataPack.writeChar(pack, var.task[i].status)
	end
	LDataPack.flush(pack)	
end

function onLogin(actor)
    sendZhuanShengInfo(actor, Protocol.sZhuanShengCmd_Info)
end

function onInit(actor)
    updateAttr(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

local function init()
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Other, Protocol.cZhuanShengCmd_GetTaskReward, c2sGetTaskReward)
    netmsgdispatcher.reg(Protocol.CMD_Other, Protocol.cZhuanShengCmd_OneKey, c2sOneKey)
    netmsgdispatcher.reg(Protocol.CMD_Other, Protocol.cZhuanShengCmd_ZhuangSheng, c2sZhuangSheng)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.zstask = function (actor, args)
    local var = getActorVar(actor)
    var.task[tonumber(args[1])].status = 1
    sendZhuanShengInfo(actor, Protocol.sZhuanShengCmd_Info)
	return true
end

gmCmdHandlers.zstaskall = function (actor, args)
    local var = getActorVar(actor)
    for i=1, 4 do
        var.task[i].status = 1
    end
    sendZhuanShengInfo(actor, Protocol.sZhuanShengCmd_Info)
	return true
end

gmCmdHandlers.zslevel = function (actor, args)
    local var = getActorVar(actor)
    local old = LActor.getZhuansheng(actor)
    local num = tonumber(args[1])
    local level = 0
    if not num then return end
    if num >= 10000 then
        level = num
    else
        local index = num + 1
        local zslevels = {}
        for k, v in pairs(ZhuanShengLevelConfig) do
            table.insert(zslevels, k)
        end
        table.sort(zslevels,function ( a,b ) return a < b end)
        level = zslevels[index]
    end

    if ZhuanShengLevelConfig[level] then
        LActor.setZhuansheng(actor, level)
        updateAttr(actor, true)
        setNextTask(actor, level)
        sendZhuanShengInfo(actor, Protocol.sZhuanShengCmd_Info)
        actorevent.onEvent(actor, aeZhuansheng, level, old)
        return true
    end
    return false
end

gmCmdHandlers.zhuangshengAll = function (actor, args)
    local IsChange = false
    local var = getActorVar(actor)
    local old = LActor.getZhuansheng(actor)
    local zslevel = {}
    for k, v in pairs(ZhuanShengLevelConfig) do
        table.insert(zslevel, k)
    end
    table.sort(zslevel,function ( a,b ) return a < b end)
    local beforelevel = zslevel[#zslevel - 1]
    local maxlevel = zslevel[#zslevel]
    if LActor.getZhuansheng(actor) < maxlevel then
        LActor.setZhuansheng(actor, beforelevel)
        setNextTask(actor, beforelevel)
        local conf = ZhuanShengLevelConfig[beforelevel]   
        for i=1, #conf.taskids do
            var.task[i].status = taskcommon.statusType.emHaveAward
            updateTaskInfo(actor, i)
        end
        sendZhuanShengInfo(actor, Protocol.sZhuanShengCmd_Info)
        LActor.setZhuansheng(actor, maxlevel)
        actorevent.onEvent(actor, aeZhuansheng, maxlevel, old)
        IsChange = true
    end
    if IsChange then
        onLogin(actor)
        updateAttr(actor, true)
    end
    return true
end
