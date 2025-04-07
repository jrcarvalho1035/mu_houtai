--微信邀请比拼
module("wechatrank", package.seeall)

local function getGlobalData()
    local var = System.getStaticVar()
    if not var then return end
    if not var.wechatrank then var.wechatrank = {} end
    var = var.wechatrank
    
    if not var.updateTime then var.updateTime = System.getNowTime() end--如果结算时未启动服务器，通过此时间来判断是否发奖
    if not var.startTime then var.startTime = 0 end--活动开始时间
    if not var.endTime then var.endTime = 0 end--活动结算时间
    if not var.overTime then var.overTime = 0 end--活动结束时间
    
    if not var.rank then
        var.rank = {}
        for i, conf in ipairs(WeChatRankConfig) do
            var.rank[i] = {}
            var.rank[i].score = conf.value
            var.rank[i].name = ""
            var.rank[i].job = 0
        end
        var.minRankcount = #WeChatRankConfig
        var.rankcount = #WeChatRankConfig
    end
    return var
end

local function wxRankloadTime()
    local data = getGlobalData()
    
    --startTime
    local d, h, m = string.match(WeChatConstConfig.startTime, "(%d+)-(%d+):(%d+)")
    if d == nil or h == nil or m == nil then
        data.startTime = 0
        data.endTime = 0
        data.overTime = 0
    end
    local st = System.getOpenServerStartDateTime()
    data.startTime = st + d * 24 * 3600 + h * 3600 + m * 60
    
    --endTime
    d, h, m = string.match(WeChatConstConfig.endTime, "(%d+)-(%d+):(%d+)")
    if d == nil or h == nil or m == nil then
        data.startTime = 0
        data.endTime = 0
        data.overTime = 0
    end
    local et = System.getOpenServerStartDateTime()
    data.endTime = et + d * 24 * 3600 + h * 3600 + m * 60
    
    --overTime
    data.overTime = data.endTime + WeChatConstConfig.time * 60
end

local function wxRankIsEnd()
    local data = getGlobalData()
    if data then
        local now_t = System.getNowTime()
        if now_t >= data.startTime and now_t < data.endTime then
            return false
        end
    end
    return true
end

local function wxRankIsOver()
    local data = getGlobalData()
    if data then
        local now_t = System.getNowTime()
        if now_t >= data.startTime and now_t < data.overTime then
            return false
        end
    end
    return true
end

--发送排名奖励邮件
function wxRankSendRewards()
    local data = getGlobalData()
    print ("WeChat rankReward")
    for i, conf in ipairs(WeChatRankConfig) do
        local actor_id = data.rank[i].actorId
        print ("rank: ", i, " actorid: ", actor_id)
        if actor_id then
            local mailData = {head = conf.head, context = string.format(conf.context, i), tAwardList = conf.rewards}
            mailsystem.sendMailById(actor_id, mailData)
        end
    end
    print ("WeChat rankReward count =", data.minRankcount)
    data.updateTime = System.getNowTime()
end

--名次排名
function wxRankSort(index)
    local data = getGlobalData()
    local minrank = data.minRankcount
    local change = false
    if index <= minrank then
        change = true
    else
        if data.rank[index].score >= data.rank[minrank].score then
            data.rank[minrank], data.rank[index] = data.rank[index], data.rank[minrank]
            change = true
        end
    end
    if not change then return false end
    for i = 1, minrank do
        for j = i + 1, minrank do
            if data.rank[i].score < data.rank[j].score then
                if not data.rank[i].actorId then
                    data.rank[i].score = 0
                end
                data.rank[i], data.rank[j] = data.rank[j], data.rank[i]
            elseif data.rank[i].score == data.rank[j].score and not data.rank[i].actorId and data.rank[j].actorId then
                data.rank[i].score = 0
                data.rank[i], data.rank[j] = data.rank[j], data.rank[i]
            end
        end
    end
    for i = minrank, 1, -1 do
        if not data.rank[i].actorId then
            data.rank[i].score = WeChatRankConfig[i].value
        end
    end
    return true
end

function wxRankSendNotice(actorid)
    local data = getGlobalData()
    for i = 1, data.minRankcount do
        if data.rank[i].actorId and data.rank[i].actorId == actorid then
            noticesystem.broadCastNotice(noticesystem.NTP.wxrank, LActor.getActorName(actorid))
        end
    end
end

----------------------------------------------------------------------------------
--协议处理

--88-5请求排名信息
function c2sGetWeChatRank(actor)
    if wxRankIsOver() then return end
    s2cWeChatRankInfo(actor)
end

--88-5 返回排行信息
function s2cWeChatRankInfo(actor)
    local data = getGlobalData()
    if not data then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wechat, Protocol.sWechatCmd_RankInfo)
    if pack == nil then return end
    local myrank = 0
    local myscore = 0
    LDataPack.writeShort(pack, data.minRankcount)
    for i = 1, data.rankcount do
        if data.minRankcount >= i then
            LDataPack.writeString(pack, data.rank[i].name)
            LDataPack.writeShort(pack, data.rank[i].score)
            LDataPack.writeChar(pack, data.rank[i].job)
        end
        if data.rank[i].actorId and data.rank[i].actorId == LActor.getActorId(actor) then
            myrank = data.minRankcount >= i and i or 0
            myscore = data.rank[i].score
        end
    end
    LDataPack.writeShort(pack, myrank)
    LDataPack.writeShort(pack, myscore)
    LDataPack.writeInt(pack, data.endTime)
    
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--事件处理
local function onWXInvite(actor)
    if wxRankIsEnd() then return end
    local data = getGlobalData()
    local index
    local actorid = LActor.getActorId(actor)
    for k, v in ipairs(data.rank) do
        if v.actorId and v.actorId == actorid then
            v.score = v.score + 1
            index = k
            break
        end
    end
    if not index then
        data.rankcount = data.rankcount + 1
        data.rank[data.rankcount] = {
            actorId = actorid,
            score = 1,
            name = LActor.getName(actor),
            job = LActor.getJob(actor),
        }
        index = data.rankcount
    end
    local needNotice = wxRankSort(index)
    s2cWeChatRankInfo(actor)
    if needNotice and index > data.minRankcount then
        wxRankSendNotice(actorid)
    end
end

local function onLogin(actor)
    if wxRankIsOver() then return end
    s2cWeChatRankInfo(actor)
end

local function onChangeName(actor, res, name, rawName, way)
    local data = getGlobalData()
    for _, rank in ipairs(data.rank) do
        if rank.actorId and rank.actorId == LActor.getActorId(actor) then
            rank.name = name
            break
        end
    end
end

local function onWeChatRankFinish()
    wxRankSendRewards()
end

local function wxRankCheckTime()
    wxRankloadTime()
    local data = getGlobalData()
    local now = System.getNowTime()
    local difftime = data.endTime - now
    if difftime > 0 then
        LActor.postScriptEventLite(nil, (data.endTime - now) * 1000, onWeChatRankFinish)
    elseif difftime == 0 then
        onWeChatRankFinish()
    else
        if data.updateTime < data.endTime then
            onWeChatRankFinish()
        end
    end
end

----------------------------------------------------------------------------------
--初始化
local function init()
    if System.isCrossWarSrv() then return end
    engineevent.regGameStartEvent(wxRankCheckTime)
    
    actorevent.reg(aeWXInvite, onWXInvite)--微信邀请事件
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeChangeName, onChangeName)
    
    netmsgdispatcher.reg(Protocol.CMD_Wechat, Protocol.cWechatCmd_RankInfo, c2sGetWeChatRank)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.wxRankClear = function (actor, args)
    local var = System.getStaticVar()
    var.wechatrank = nil
end

gmCmdHandlers.wxRankEnd = function (actor, args)
    wxRankSendRewards()
end
