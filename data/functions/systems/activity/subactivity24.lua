--消费返利
module("subactivity24", package.seeall)

local subType = 24

local function getStaticData(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.consume then var.consume = 0 end --活动内消费数额
    if not var.pay then var.pay = 0 end
	return var
end

--记录数据
local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local v = record and record.data and record.data.rewardsRecord or 0
    LDataPack.writeInt(npack, v)
end

--领取奖励
local function onGetReward(actor, config, id, index, record)
    local var = getStaticData(actor, id)
    local config = config[id]
    if not config then return end
    if not config[index] then return end
    if config[index].consume > var.consume then return end
    if config[index].pay > var.pay then return end

    if record.data.rewardsRecord == nil then 
        record.data.rewardsRecord = 0
    end

    if not actoritem.checkEquipBagSpaceJob(actor, config[index].reward) then
        return
    end

    if System.bitOPMask(record.data.rewardsRecord, index) then
		return false
    end
    
    record.data.rewardsRecord = System.bitOpSetMask(record.data.rewardsRecord, index, true)
    actoritem.addItems(actor, config[index].reward, "activity type24 rewards")

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	LDataPack.writeByte(npack, 1)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, index)
	LDataPack.writeInt(npack, record.data.rewardsRecord or 0)
	LDataPack.flush(npack)
end

function sendConsumeInfo(actor, actId)
    if not actId then
        for id,v in pairs(ActivityType24Config) do
            if not activitymgr.activityTimeIsEnd(id) then
                actId = id
                break
            end
        end
    end
    if activitymgr.activityTimeIsEnd(actId) then return end
    local var = getStaticData(actor, actId)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_ConsumeInfo)
    LDataPack.writeShort(npack, actId)
    LDataPack.writeInt(npack, var.pay)
    LDataPack.writeInt(npack, var.consume)
    LDataPack.flush(npack)
end

function regainConsumeYuanbao(actor, count)
    for id,v in pairs(ActivityType24Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local var = getStaticData(actor, id)
            var.consume = var.consume - count
        end
    end
end

subactivitymgr.actorLoginFuncs[subType] = function(actor, type, id)
    if activitymgr.activityTimeIsOver(id) then return end
    sendConsumeInfo(actor, id)
end

local function onConsumeYuanbao(actor, count, log)
    if log == "diral draw" then return end
    for id,v in pairs(ActivityType24Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local var = getStaticData(actor, id)
            var.consume = var.consume + count
            sendConsumeInfo(actor, id)
        end
    end
end

local function onRecharge(actor, count)
    for id,v in pairs(ActivityType24Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local var = getStaticData(actor, id)
            var.pay = var.pay + count
            sendConsumeInfo(actor, id)
            break
        end
    end
end

function onAfterNewDay(actor)
    for id,v in pairs(ActivityType24Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            sendConsumeInfo(actor, id)
            break
        end
    end
end

--每天在活动协议发送之前的操作
function onBeforeNewDay(actor, record, config, id)
	if activitymgr.activityTimeIsEnd(id) then --活动时间已过
		if record.data.rewardsRecord == nil then 
			record.data.rewardsRecord = 0
		end
        for k, v in ipairs(config[id]) do --把未领取的达标奖励以邮件发送
            local var = getStaticData(actor, id)
            if config[id][k].consume < var.consume and config[id][k].pay < var.pay and not System.bitOPMask(record.data.rewardsRecord, k) then
                local mailData = {head = v.head, context = v.context, tAwardList=v.reward}
                mailsystem.sendMailById(LActor.getActorId(actor), mailData)
				record.data.rewardsRecord = System.bitOpSetMask(record.data.rewardsRecord, k, true)--把奖励设已领，以后达标也不能拿
			end
		end
    end
end

function init()
    actorevent.reg(aeConsumeYuanbao, onConsumeYuanbao)
	if System.isCrossWarSrv() then return end
    subactivitymgr.regTimeOut(subType, onTimeOut)
    actorevent.reg(aeRecharge, onRecharge)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    subactivitymgr.regGetRewardFunc(subType, onGetReward)
    subactivitymgr.regNewDayFunc(subType, onBeforeNewDay)
    subactivitymgr.regNewDayAfterFunc(subType, onAfterNewDay)
end

table.insert(InitFnTable, init)

