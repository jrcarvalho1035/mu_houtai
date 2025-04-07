module("subactivity8", package.seeall)

--消费排行活动
local subType = 8

local function getMinRank(id)
    for i=1, #ActivityType8Config[id] do
        if ActivityType8Config[id][i].consume == 0 then
            return ActivityType8Config[id][i].rank[1] - 1
        end
    end
    return 0
end

local function getIndex(id, rank)
    for k,v in ipairs(ActivityType8Config[id]) do
        if v.rank[1] <= rank and v.rank[2] >= rank then
            return k
        end
    end
    return 0
end

local function getGlobalData(id)
    local var = activitymgr.getGlobalVar(id)
    if not var then return end
    if not var.rank then
        var.rank = {}
        var.rankcount = getMinRank(id)
        for i=1, var.rankcount do
            var.rank[i] = {}
            var.rank[i].consume = ActivityType8Config[id][getIndex(id, i)].consume
            var.rank[i].name = ""
        end
    end
    
	return var
end


function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	local v = record and record.data and record.data.rewardsRecord or 0
	LDataPack.writeInt(npack, v)
end

function sortRank(id)
    local gvar = getGlobalData(id)
    for i=1, gvar.rankcount do
        for j=i+1, gvar.rankcount do
            if gvar.rank[i].consume < gvar.rank[j].consume or (gvar.rank[i].consume == gvar.rank[j].consume and not gvar.rank[i].actorId and gvar.rank[j].actorId) then
                gvar.rank[i], gvar.rank[j] = gvar.rank[j], gvar.rank[i]
            end
        end
    end
    for i=gvar.rankcount, 1, -1 do
        if i > getMinRank(id) and not gvar.rank[i].actorId then
            for j=i, gvar.rankcount - 1 do
                gvar.rank[j] = gvar.rank[j+1]
            end
            gvar.rank[gvar.rankcount] = nil
            gvar.rankcount = gvar.rankcount - 1
        elseif i <= getMinRank(id) and not gvar.rank[i].actorId then
            gvar.rank[i].consume = ActivityType8Config[id][getIndex(id, i)].consume
        end
    end
end

local function sendRank(actor, pack)
    local id = LDataPack.readInt(pack)
    if not ActivityType8Config[id] then return end

    local gvar = getGlobalData(id)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_ConsumeRank)
	if npack == nil then return end
    local myrank = 0
    LDataPack.writeShort(npack, gvar.rankcount)
    for i=1, gvar.rankcount do
        LDataPack.writeString(npack, gvar.rank[i].name)
        LDataPack.writeInt(npack, gvar.rank[i].consume)
        if gvar.rank[i].actorId and gvar.rank[i].actorId == LActor.getActorId(actor) then
            myrank = i
        end
    end
    LDataPack.writeShort(npack, myrank)

	LDataPack.flush(npack)
end

function regainConsumeYuanbao(actor, count)
    for id,v in pairs(ActivityType8Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local gvar = getGlobalData(id)
            for k,v in pairs(gvar.rank) do
                if v.actorId == LActor.getActorId(actor) then
                    v.consume = v.consume - count
                end
            end
            break
        end
    end
end

local function onConsumeYuanbao(actor, count, log)
    if log == "diral draw" then return end
    for id,v in pairs(ActivityType8Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local isHave = false
            local gvar = getGlobalData(id)
            for k,v in pairs(gvar.rank) do
                if v.actorId and v.actorId == LActor.getActorId(actor) then
                    v.consume = v.consume + count
                    isHave = true
                    break
                end
            end
            if not isHave then
                gvar.rankcount = gvar.rankcount + 1
                gvar.rank[gvar.rankcount] = {}
                gvar.rank[gvar.rankcount].actorId = LActor.getActorId(actor)
                gvar.rank[gvar.rankcount].consume = count
                gvar.rank[gvar.rankcount].name = LActor.getName(actor)
            end
            sendConsumeInfo(actor, id)
            sortRank(id)
        end
    end
end

function onTimeOut(id, config, actor, record)
    local gvar = getGlobalData(id)
    for i=1, gvar.rankcount do
        if gvar.rank[i].actorId then
            local index = getIndex(id, i)
            if index == 0 then
                break
            end
            local conf = config[id][index]
            local mailData = {head = conf.head, context = string.format(conf.text, i), tAwardList= conf.rewards}
            mailsystem.sendMailById(gvar.rank[i].actorId, mailData)
            gvar.rank[i].actorId = nil
        end
    end
end

function sendConsumeInfo(actor, id)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Update16)
	if npack == nil then return end
    local gvar = getGlobalData(id)
    LDataPack.writeInt(npack, id)
    local isHave = false
    for k,v in pairs(gvar.rank) do
        if v.actorId == LActor.getActorId(actor) then            
            LDataPack.writeInt(npack, v.consume)
            isHave = true
            break   
        end
    end
    if not isHave then
        LDataPack.writeInt(npack, 0)
    end	
	LDataPack.flush(npack)
end

subactivitymgr.actorLoginFuncs[subType] = function(actor, type, id)
    if activitymgr.activityTimeIsOver(id) then return end
    sendConsumeInfo(actor, id)
end

function onActivityFinish(id)
	local config = ActivityType8Config
	local actors = System.getOnlineActorList()
	if actors then
		for i = 1, #actors do
			local actor = actors[i]
			local var = activitymgr.getStaticData(actor)
			local record = var.records[id]
			onTimeOut(id, config, actor, record)
		end
	end
    local gvar = getGlobalData(id)
    gvar = nil
end

-- netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_ConsumeRank, sendRank)

-- function init()
-- 	if System.isCrossWarSrv() then return end
--     subactivitymgr.regActivityFinish(subType, onActivityFinish)
--     actorevent.reg(aeConsumeYuanbao, onConsumeYuanbao)
--     subactivitymgr.regWriteRecordFunc(subType, writeRecord)
--     subactivitymgr.regGetRewardFunc(subType, onGetReward)
--     subactivitymgr.regTimeOut(subType, onTimeOut)
-- end

-- table.insert(InitFnTable, init)

