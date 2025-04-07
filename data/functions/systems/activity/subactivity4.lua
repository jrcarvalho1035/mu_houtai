--排行榜活动奖励
module("subactivity4", package.seeall)

local subType = 4
local rankNum = 20

minType = {
    shenmo = 1, --神魔
    yongbing = 2, --佣兵
    shenqi = 3, --神器
    wing = 4, --翅膀
    damon = 5, --精灵
    shenzhuang = 6, --神装
    meilin = 7, --梅林
}

local function getMinRank(id)
    return ActivityType4Config[id][#ActivityType4Config[id]].ranking[2]
end

local function getIndex(id, rank)
    for k, v in ipairs(ActivityType4Config[id]) do
        if v.ranking[1] <= rank and v.ranking[2] >= rank then
            return k
        end
    end
    return 0
end

local function getGlobalData(id)
    local var = activitymgr.getGlobalVar(id)
    if not var then return end
    if not var.updateTime then var.updateTime = 0 end
    if not var.rank then
        var.rank = {}
        var.rankcount = getMinRank(id)
        var.minRankcount = getMinRank(id)
        for i = 1, var.rankcount do
            var.rank[i] = {}
            var.rank[i].power = ActivityType4Config[id][getIndex(id, i)].value
            var.rank[i].name = ""
        end
    end
    
    return var
end

--发送排名奖励邮件
function sendRankRewards(id, config)
    local gvar = getGlobalData(id)
    print ("subactivity4 rankReward actId: ", id)
    for i = 1, gvar.minRankcount do
        local actor_id = gvar.rank[i].actorId
        print ("rank: ", i, " actorid: ", actor_id)
        for k, v in ipairs(config) do
            if actor_id and i >= v.ranking[1] and i <= v.ranking[2] then
                local conf = config[k]
                local mailData = {head = conf.head, context = string.format(conf.context, i), tAwardList = conf.rewards}
                mailsystem.sendMailById(actor_id, mailData)
                break
            end
        end
    end
    print ("subactivity4 rankReward count: ", gvar.minRankcount)
end

function onAfterNewDay(actor, id)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.rankopen) then return end
    local time = 0
    local now = System.getNowTime()
    local et = activitymgr.getEndTime(id)
    if now - et >= 0 and now - et < 86400 then
        time = et
    else
        return
    end
    if id == 0 then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_RankFinish)
    local gvar = getGlobalData(id)
    LDataPack.writeInt(npack, id)
    local count = math.min(gvar.rankcount, 10)
    LDataPack.writeChar(npack, count)
    for i = 1, count do
        if gvar.rank[i].name == "" then
            LDataPack.writeInt(npack, 0)
            LDataPack.writeString(npack, ScriptTips.act001)
        else
            LDataPack.writeInt(npack, gvar.rank[i].actorId)
            LDataPack.writeString(npack, gvar.rank[i].name)
        end
    end
    LDataPack.writeInt(npack, time)
    LDataPack.flush(npack)
end

function onActivityFinish(id)
    sendRankRewards(id, ActivityType4Config[id])
    local data = getGlobalData(id)
    data.updateTime = System.getNowTime()
    
    local actors = System.getOnlineActorList()
    if actors then
        for i = 1, #actors do
            local actor = actors[i]
            if actor then
                onAfterNewDay(actor, id)
            end
        end
    end
end

function sortRank(id, index)
    local gvar = getGlobalData(id)
    local minrank = gvar.minRankcount
    local change = false
    if index <= minrank then
        change = true
    else
        if gvar.rank[index].power >= gvar.rank[minrank].power then
            gvar.rank[minrank], gvar.rank[index] = gvar.rank[index], gvar.rank[minrank]
            change = true
        end
    end
    if not change then return end
    for i = 1, minrank do
        for j = i + 1, minrank do
            if gvar.rank[i].power < gvar.rank[j].power then
                gvar.rank[i], gvar.rank[j] = gvar.rank[j], gvar.rank[i]
                if not gvar.rank[j].actorId then
                    gvar.rank[j].power = ActivityType4Config[id][getIndex(id, j)].value
                end
            elseif gvar.rank[i].power == gvar.rank[j].power and not gvar.rank[i].actorId and gvar.rank[j].actorId then
                gvar.rank[i], gvar.rank[j] = gvar.rank[j], gvar.rank[i]
                if not gvar.rank[j].actorId then
                    gvar.rank[j].power = ActivityType4Config[id][getIndex(id, j)].value
                end
            end
        end
    end
end

function c2sGetRank(actor, pack)
    local id = LDataPack.readInt(pack)
    if not ActivityType4Config[id] then return end
    s2cRankInfo(actor, id)
end

function s2cRankInfo(actor, id)
    local gvar = getGlobalData(id)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Info4)
    if npack == nil then return end
    local myrank = 0
    local mypower = 0
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, gvar.minRankcount)
    for i = 1, gvar.rankcount do
        if gvar.minRankcount >= i then
            LDataPack.writeString(npack, gvar.rank[i].name)
            LDataPack.writeDouble(npack, gvar.rank[i].power)
        end
        if gvar.rank[i].actorId and gvar.rank[i].actorId == LActor.getActorId(actor) then
            myrank = gvar.minRankcount >= i and i or 0
            mypower = gvar.rank[i].power
        end
    end
    LDataPack.writeShort(npack, myrank)
    LDataPack.writeDouble(npack, mypower)
    
    LDataPack.flush(npack)
end

local function onChangeRankPower(actor, power, type)
    for id, v in pairs(ActivityType4Config) do
        if not activitymgr.activityTimeIsEnd(id) and v[1].sType == type then
            local gvar = getGlobalData(id)
            local index
            for k, v in ipairs(gvar.rank) do
                if v.actorId and v.actorId == LActor.getActorId(actor) then
                    v.power = power
                    index = k
                    break
                end
            end
            if not index then
                gvar.rankcount = gvar.rankcount + 1
                gvar.rank[gvar.rankcount] = {actorId = LActor.getActorId(actor), power = power, name = LActor.getName(actor)}
                index = gvar.rankcount
            end
            --sendPower(actor)
            sortRank(id, index)
            s2cRankInfo(actor, id)
            break
        end
    end
end

local function onNewDay(actor)
    for id, v in pairs(ActivityType4Config) do
        local power = 0
        if not activitymgr.activityTimeIsEnd(id) then
            if v[1].sType == minType.damon then
                power = damonsystem.getPower(actor)
            elseif v[1].sType == minType.yongbing then
                power = yongbingsystem.getPower(actor)
            elseif v[1].sType == minType.shenqi then
                power = shenqisystem.getPower(actor)
            elseif v[1].sType == minType.wing then
                power = wingsystem.getPower(actor)
            elseif v[1].sType == minType.shenmo then
                power = shenmosystem.getPower(actor)
            elseif v[1].sType == minType.shenzhuang then
                power = shenzhuangsystem.getPower(actor)
            elseif v[1].sType == minType.meilin then
                power = meilinsystem.getPower(actor)
            end
        end
        if power > 0 then
            onChangeRankPower(actor, power, v[1].sType)
        end
        onAfterNewDay(actor, id)
    end
end

actorevent.reg(aeChangeRankPower, onChangeRankPower)

function checkEndTime()
    if System.isBattleSrv() then return end
    for id, v in pairs(ActivityType4Config) do
        local now = System.getNowTime()
        local et = activitymgr.getEndTime(id)
        local data = getGlobalData(id)
        if et ~= 0 and now - et > 0 and data.updateTime < et then
            onActivityFinish(id)
        end
    end
end

function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local v = record and record.data and record.data.rewardsRecord or 0
    LDataPack.writeInt(npack, v)
end
subactivitymgr.regWriteRecordFunc(subType, writeRecord)
subactivitymgr.regActivityFinish(subType, onActivityFinish)
subactivitymgr.regNewDayFunc(subType, onNewDay)

local function init()
    if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Info4, c2sGetRank)
end

table.insert(InitFnTable, init)


onChangeName = function(actor, res, name, rawName, way)
    for id, v in pairs(ActivityType4Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local gvar = getGlobalData(id)
            for k, v in pairs(gvar.rank) do
                if v.actorId and v.actorId == LActor.getActorId(actor) then
                    v.name = name
                    break
                end
            end
        end
    end
end

actorevent.reg(aeChangeName, onChangeName)

