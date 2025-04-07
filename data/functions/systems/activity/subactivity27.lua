--连续可间断充值
module("subactivity27", package.seeall)

local subType = 27



local function getStaticData(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.payDay then var.payDay = {} end --活动内充值天数
    if not var.isAdd then var.isAdd = {} end --活动内充值天数
    if not var.pay then var.pay = 0 end --今天充值数
    if not var.isget then var.isget = 0 end
	return var
end

--记录数据
local function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end

    local var = getStaticData(actor, id)
    LDataPack.writeChar(npack, #ActivityType27Config[id])
    for i=1, #ActivityType27Config[id] do
        LDataPack.writeChar(npack, var.payDay[i] or 0)
    end
    LDataPack.writeInt(npack, var.isget)
    LDataPack.writeInt(npack, var.pay)
end

function s2cActivity27Info(actor, actId)
    local var = getStaticData(actor, actId)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_RechargeLianchong)
    LDataPack.writeInt(npack, actId)
    LDataPack.writeChar(npack, #ActivityType27Config[actId])
    for i=1, #ActivityType27Config[actId] do
        LDataPack.writeByte(npack, var.payDay[i] or 0)
    end
    LDataPack.writeInt(npack, var.pay)
    LDataPack.flush(npack)
end

--领取奖励
local function onGetReward(actor, config, id, index, record)
    local var = getStaticData(actor, id)
    config = config[id]
    if not config then return end
    if not config[index] then return end

    if (var.payDay[index] or 0) < config[index].condition then
        return
    end

    if System.bitOPMask(var.isget, index) then
		return false
    end
    var.isget = System.bitOpSetMask(var.isget, index, true)


    if not actoritem.checkEquipBagSpaceJob(actor, config[index].rewards) then
        return
    end

    actoritem.addItems(actor, config[index].rewards, "activity type27 rewards")

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	LDataPack.writeByte(npack, 1)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, index)
	LDataPack.writeInt(npack, var.isget)
	LDataPack.flush(npack)
end

local function onRecharge(actor, count)
    for id,v in pairs(ActivityType27Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local var = getStaticData(actor, id)
            var.pay = var.pay + count
            for i=1, #v do
                if var.pay >= v[i].yuanbao and (var.isAdd[i] or 0) == 0 then
                    var.isAdd[i] = 1
                    var.payDay[i] = (var.payDay[i] or 0) + 1
                end
            end
            s2cActivity27Info(actor, id)
        end
    end
end

function onTimeOut(id, config, actor, record)
    config = config[id]
    if config[1].head == "" then return end
    local var = getStaticData(actor, id)
    for k, v in ipairs(config) do
        if (var.payDay[k] or 0) >= v.condition and not System.bitOPMask(var.isget, k) then
            var.isget = System.bitOpSetMask(var.isget, k, true)
            local mailData = {head = v.head, context = v.text, tAwardList= v.rewards}
            mailsystem.sendMailById(LActor.getActorId(actor), mailData)
        end
    end
end

function onActivityFinish(id)
	local config = ActivityType27Config
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


function onNewDayLogin(id, conf)
	return function(actor)
		if not activitymgr.activityTimeIsEnd(id) then
            local var = getStaticData(actor, id)
            for i=1, #ActivityType27Config[id] do
                var.isAdd[i] = 0
            end
            var.pay = 0
            s2cActivity27Info(actor, id)
        end
	end
end

subactivitymgr.initFuncs[subType] = function(id, conf)
    actorevent.reg(aeNewDayArrive, onNewDayLogin(id, conf))
end

function init()
	if System.isCrossWarSrv() then return end
    subactivitymgr.regActivityFinish(subType, onActivityFinish)
    subactivitymgr.regTimeOut(subType, onTimeOut)
    --subactivitymgr.regLoginFunc(subType, onLogin)
    actorevent.reg(aeRecharge, onRecharge)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    subactivitymgr.regGetRewardFunc(subType, onGetReward)
end

table.insert(InitFnTable, init)


function addGm27(actorid, id)
    print("add act27 reward", actorid, id)
	local actor = LActor.getActorById(actorid)
	if not actor then return end
	if not activitymgr.activityTimeIsEnd(id) then
		print("act27  done")
		local var = getStaticData(actor, id)
		var.isAdd = 1
        var.pay = 1
        local conf = ActivityType27Config[id][1]
        if conf.subType == minType.payDay4 then
            var.curday = activitymgr.getCurDay(id)
        else
            var.curday = var.payDay + 1
        end
		s2cActivity27Info(actor, id)
    end
end

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.act27ref = function ( actor, args )
    local id = tonumber(args[1])
    print('act27ref id=', id)
    if not actor then return end
    if not activitymgr.activityTimeIsEnd(id) then
        local var = getStaticData(actor, id)
        var.isAdd = 1
        var.pay = 1
        local conf = ActivityType27Config[id][1]
        if conf.subType == minType.payDay4 then
            var.curday = activitymgr.getCurDay(id)
        else
            var.curday = var.payDay + 1
        end
        s2cActivity27Info(actor, id)
    else
        print('activity is over')
    end
    return true
end

gmCmdHandlers.act27Reward = function ( actor, args )
    local id = tonumber(args[1])
    print('act27Reward id=', id)
    if not actor then return end
    if not activitymgr.activityTimeIsEnd(id) then
        local conf = ActivityType27Config
        onGetReward(actor, conf, id, 1, nil)
    else
        print('activity is over')
    end
    return true
end

gmCmdHandlers.act27Clear = function ( actor, args )
    local id = tonumber(args[1])
    print('act27Reward id=', id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var.data = {}
    return true
end


