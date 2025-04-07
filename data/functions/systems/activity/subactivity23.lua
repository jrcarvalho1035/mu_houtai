--连续可间断充值
module("subactivity23", package.seeall)

local subType = 23

local minType = {
    payDay4 = 4, -- 每日首充，奖励按活动天数领取，即第2天没充，第3天充值时领的是第3天的奖励
}

local function getStaticData(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.payDay then var.payDay = 0 end --活动内充值天数
    if not var.curday then
        --活动内可充值天数, 2020.3.23:类型4，活动开启的第几天
        local conf = ActivityType23Config[id]
        if conf[1].subType == minType.payDay4 then
            var.curday = activitymgr.getCurDay(id)
        else
            var.curday = 0
        end
    end
    if not var.pay then var.pay = 0 end --今天充值数
    if not var.isAdd then var.isAdd = 0 end --今天是否已计入充值
    if not var.isget then var.isget = {} end
	return var
end

--记录数据
local function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end

	LDataPack.writeInt(npack, 0)
end

function s2cActivity23Info(actor, actId)
    local var = getStaticData(actor, actId)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Recharge60Info)
    LDataPack.writeInt(npack, actId)
    LDataPack.writeShort(npack, var.payDay)
    LDataPack.writeShort(npack, #ActivityType23Config[actId])
    for i=1, #ActivityType23Config[actId] do
        LDataPack.writeByte(npack, var.isget[i] or 0)
    end
    LDataPack.writeInt(npack, var.pay)
    LDataPack.writeShort(npack, var.curday)
    LDataPack.flush(npack)
end

--领取奖励
local function onGetReward(actor, config, id, index, record)
    local var = getStaticData(actor, id)
    config = config[id]
    if not config then return end
    if config[1].subType == minType.payDay4 then
        -- 子类型4是按活动开启天数来领取奖励的
        index = var.curday
        if var.isAdd == 0 then return end
    else
        if index > var.payDay then return end
    end
    if (var.isget[index] or 0) == 1 then return end

    if not config[index] then return end

    if not actoritem.checkEquipBagSpaceJob(actor, config[index].reward) then
        return
    end
	
    var.isget[index] = 1
    actoritem.addItems(actor, config[index].reward, "activity type23 rewards")

    s2cActivity23Info(actor, id)
end

local function onRecharge(actor, count)
    for id,v in pairs(ActivityType23Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local var = getStaticData(actor, id)
            if var.isAdd == 0 then
                var.pay = var.pay + count
                if var.pay >= v[1].pay then
                    var.isAdd = 1
                    var.payDay = var.payDay + 1                    
                end
                s2cActivity23Info(actor, id)
            end 
        end
    end
end

function onNewDayLogin(id, conf)
    return function(actor)
		if not activitymgr.activityTimeIsEnd(id) then
            local var = getStaticData(actor, id)        
            if conf[1].subType == minType.payDay4 and ActivityType23Config[var.curday] then
                -- 如果前一天的奖励没有领取，就发邮件
                local lastDay = var.curday
                local cfg = conf[lastDay]
                if cfg and var.isAdd ~= 0 and (not var.isget[lastDay] or var.isget[lastDay] == 0) and cfg.head ~= "" then
                    var.isget[lastDay] = 1
                    local mailData = {head = cfg.head, context = cfg.text, tAwardList= cfg.reward}
                    mailsystem.sendMailById(LActor.getActorId(actor), mailData)
                end
                -- 类型4，curDay表示活动已经开启的天数
                var.curday = activitymgr.getCurDay(id)
            else
                var.curday = var.payDay + 1
            end
            var.isAdd = 0
            var.pay = 0
            s2cActivity23Info(actor, id)
        end
	end
end

function onLogin(actor)
    for id,v in pairs(ActivityType23Config) do
        if not activitymgr.activityTimeIsOver(id) then
            s2cActivity23Info(actor, id)
        end
    end
end

subactivitymgr.initFuncs[subType] = function(id, conf)
    actorevent.reg(aeNewDayArrive, onNewDayLogin(id, conf))    
end


function onTimeOut(id, config, actor, record)
    local config = config[id]
    if config[1].head == "" then return end
    local var = getStaticData(actor, id)
    if config[1].subType == minType.payDay4 then
        -- 当天奖励没有领取
        local curDay = var.curday
        local cfg = config[curDay]
        if var.isAdd ~= 0 and (not var.isget[curDay] or var.isget[curDay] == 0) and cfg.head ~= "" then
            var.isget[curDay] = 1
            local mailData = {head = cfg.head, context = cfg.text, tAwardList= cfg.reward}
            mailsystem.sendMailById(LActor.getActorId(actor), mailData)
        end
    else
        for k, v in ipairs(config) do            
            if var.payDay >= v.index and (var.isget[k] or 0) == 0 then
                var.isget[k] = 1
                local mailData = {head = v.head, context = v.text, tAwardList= v.reward}
                mailsystem.sendMailById(LActor.getActorId(actor), mailData)
            end
        end
    end
    --var = LActor.getEmptyStaticVar()
end

function onActivityFinish(id)
	local config = ActivityType23Config
	local actors = System.getOnlineActorList()
	if actors then
		for i = 1, #actors do
			local actor = actors[i]
			local var = activitymgr.getStaticData(actor)
			local record = var.records[id]
			onTimeOut(id, config, actor, record)
		end
	end	
end

function init()
	if System.isCrossWarSrv() then return end
    subactivitymgr.regActivityFinish(subType, onActivityFinish)
    subactivitymgr.regTimeOut(subType, onTimeOut)
    subactivitymgr.regLoginFunc(subType, onLogin)
    actorevent.reg(aeRecharge, onRecharge)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    subactivitymgr.regGetRewardFunc(subType, onGetReward)
end

table.insert(InitFnTable, init)


function addGm23(actorid, id)
    print("add act23 reward", actorid, id)
	local actor = LActor.getActorById(actorid)
	if not actor then return end
	if not activitymgr.activityTimeIsEnd(id) then
		print("act23  done")
		local var = getStaticData(actor, id)        
		var.isAdd = 1
        var.pay = 1
        local conf = ActivityType23Config[id][1]
        if conf.subType == minType.payDay4 then
            var.curday = activitymgr.getCurDay(id)
        else
            var.curday = var.payDay + 1
        end
		s2cActivity23Info(actor, id)
    end
end

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.act23ref = function ( actor, args )
    local id = tonumber(args[1])
    print('act23ref id=', id)
    if not actor then return end
    if not activitymgr.activityTimeIsEnd(id) then
        local var = getStaticData(actor, id)        
        var.isAdd = 1
        var.pay = 1
        local conf = ActivityType23Config[id][1]
        if conf.subType == minType.payDay4 then
            var.curday = activitymgr.getCurDay(id)
        else
            var.curday = var.payDay + 1
        end
        s2cActivity23Info(actor, id)
    else
        print('activity is over')
    end
    return true
end

gmCmdHandlers.act23Reward = function ( actor, args )
    local id = tonumber(args[1])
    print('act23Reward id=', id)
    if not actor then return end
    if not activitymgr.activityTimeIsEnd(id) then
        local conf = ActivityType23Config
        onGetReward(actor, conf, id, 1, nil)
    else
        print('activity is over')
    end
    return true
end

gmCmdHandlers.act23Clear = function ( actor, args )
    local id = tonumber(args[1])
    print('act23Reward id=', id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var.data = {}
    return true
end


