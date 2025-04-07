--神兽打工

module("shenshouwork", package.seeall)

function getShenShouStaticVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.ShenShouwork then
        var.ShenShouwork = {}
    end
    var = var.ShenShouwork
    if not var.worktimes then var.worktimes = 0 end --今天工作次数
    if not var.curcnt then var.curcnt = 0 end --现在打工的团队个数
    if not var.groupcnt then var.groupcnt = ShenShouCommonConfig.initTeamCnt end --分队个数
    if not var.timesstatus then var.timesstatus = 0 end --打工次数奖励领取状态
    for i = 1, ShenShouCommonConfig.initTeamCnt + #ShenShouCommonConfig.newTeamYuanbao do
        if not var[i] then
            var[i] = {}
            var[i].choosetime = 0
            var[i].starttime = 0
            var[i].membercnt = 0
            var[i].team = {}
            for j = 1, 3 do
                var[i].team[j] = {}
                var[i].team[j].ShenShouId = 0
            end
        end
    end
    return var
end

function sendShenShouWorkInfo(actor)
    local data = getShenShouStaticVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_WorkInfo)
    LDataPack.writeChar(pack, data.worktimes)
    LDataPack.writeInt(pack, data.timesstatus)
    local totalCnt = ShenShouCommonConfig.initTeamCnt + #ShenShouCommonConfig.newTeamYuanbao
    LDataPack.writeChar(pack, totalCnt)
    for i = 1, totalCnt do
        LDataPack.writeChar(pack, i)
        if i > data.groupcnt then
            LDataPack.writeChar(pack, 0)
        else
            LDataPack.writeChar(pack, 1)
        end
        LDataPack.writeChar(pack, data[i].membercnt)
        local wanchengdu = 0
        for j = 1, data[i].membercnt do
            LDataPack.writeInt(pack, data[i].team[j].ShenShouId)
            wanchengdu = wanchengdu + ShenShouConfig[data[i].team[j].ShenShouId].completion / 10000
        end
        local remaintime = data[i].starttime + data[i].choosetime * 3600 - os.time()
        LDataPack.writeInt(pack, remaintime > 0 and remaintime or 0)
        local cnt = data[i].choosetime * wanchengdu
        LDataPack.writeDouble(pack, cnt)
    end
    LDataPack.flush(pack)
end

--新增打工队列
function addWorkTeam(actor, data, index)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_GoWork)
    LDataPack.writeChar(pack, index)
    LDataPack.writeChar(pack, data.membercnt)
    local wanchengdu = 0
    for i = 1, data.membercnt do
        LDataPack.writeInt(pack, data.team[i].ShenShouid)
        wanchengdu = wanchengdu + ShenShouConfig[data.team[i].ShenShouId].completion / 10000
    end
    local remaintime = data.starttime + data.choosetime * 3600 - os.time()
    LDataPack.writeInt(pack, remaintime > 0 and remaintime or 0)
    local cnt = data.choosetime * wanchengdu
    LDataPack.writeDouble(pack, cnt)
    
    LDataPack.flush(pack)
end

--检查该精灵是否已经在工作
function checkIsWork(data, ShenShouId)
    for i = 1, data.groupcnt do
        if data[i].starttime ~= 0 then
            for j = 1, data[i].membercnt do
                if data[i].team[j].ShenShouId == ShenShouId then
                    return true
                end
            end
        end
    end
    return false
end

--开始打工
function c2sGoWork(actor, pack)
    local chooseIndex = LDataPack.readChar(pack)
    local chooseCnt = LDataPack.readChar(pack)
    local choose = {}
    for i = 1, chooseCnt do
        choose[i] = LDataPack.readInt(pack)
    end
    
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenshou) then return end
    local data = getShenShouStaticVar(actor)
    local ShenShouData = shenshousystem.getShenShouStaticVar(actor)
    if data.curcnt >= data.groupcnt then return end
    if not ShenShouCommonConfig.checkTime[chooseIndex] then return end
    for i = 1, chooseCnt do
        if not ShenShouData.ShenShous[choose[i]] then return end
        if checkIsWork(data, choose[i]) then return end
    end

    local groupIndex = 0
    for i = 1, data.groupcnt do
        if data[i].starttime == 0 then
            data[i].starttime = os.time()
            data[i].membercnt = #choose
            data[i].choosetime = ShenShouCommonConfig.checkTime[chooseIndex]
            for j = 1, #choose do
                if data[i].team[j] then
                    data[i].team[j].ShenShouId = choose[j]
                end
            end
            groupIndex = i
            break
        end
    end
    data.curcnt = data.curcnt + 1
    addWorkTeam(actor, data[groupIndex], groupIndex)
end

--精灵打工取消返回
function sendCancel(actor, index)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_CancelWork)
    LDataPack.writeChar(pack, index)
    LDataPack.flush(pack)
end

--取消打工
function c2sCancelWork(actor, pack)
    local chooseIndex = LDataPack.readChar(pack)
    local data = getShenShouStaticVar(actor)
    if not data[chooseIndex] or data[chooseIndex].starttime == 0 then
        return
    end
    data[chooseIndex].starttime = 0
    data[chooseIndex].choosetime = 0
    data[chooseIndex].membercnt = 0
    data.curcnt = data.curcnt - 1
    sendCancel(actor, chooseIndex)
end

--快速打工
function c2sQuicklyWork(actor, pack)
    local chooseIndex = LDataPack.readChar(pack)
    local data = getShenShouStaticVar(actor)
    if not data[chooseIndex] then
        return
    end
    local remaintime = data[chooseIndex].starttime + data[chooseIndex].choosetime * 3600 - os.time()
    if remaintime <= 0 then
        return
    end
    local needYuanbao = math.ceil(ShenShouCommonConfig.quicklyYuanbao * remaintime / 60)
    if not actoritem.checkItem(actor, NumericType_YuanBao, needYuanbao) then
        return false
    end
    data[chooseIndex].starttime = data[chooseIndex].starttime - remaintime
    actoritem.reduceItem(actor, NumericType_YuanBao, needYuanbao, "ShenShou work quickly")
    sendShenShouWorkInfo(actor)
end

--领取打工奖励
function c2sGetWorkReward(actor, pack)
    local chooseIndex = LDataPack.readChar(pack)
    local data = getShenShouStaticVar(actor)
    local work = data[chooseIndex]
    if not work or work.starttime == 0 then
        return
    end
    local remaintime = work.starttime + work.choosetime * 3600 - os.time()
    if remaintime > 0 then
        return
    end
    local wanchengdu = 0
    for i = 1, work.membercnt do
        wanchengdu = wanchengdu + ShenShouConfig[work.team[i].ShenShouId].completion / 10000
    end
    
    local multiple = 1
    if halosystem.isBuyHalo(actor) then
        multiple = 2
    end
    for k, conf in ipairs(ShenShouCommonConfig.workNormal) do
        actoritem.addItem(actor, conf.id, math.floor(conf.count / 2 * wanchengdu * work.choosetime) * multiple, "ShenShou work reward")
    end
    
    --特殊奖励
    local isGetSpec = 0
    if math.random(1, 10000) <= math.ceil(wanchengdu / 6 * 10000) then
        actoritem.addItems(actor, ShenShouCommonConfig.workSpec)
        isGetSpec = 1
    end
    sendGetWorkReward(actor, isGetSpec, chooseIndex)
    work.starttime = 0
    work.choosetime = 0
    work.membercnt = 0
    data.curcnt = data.curcnt - 1
    data.worktimes = data.worktimes + 1
    sendShenShouWorkInfo(actor)
end

--领取打工奖励返回
function sendGetWorkReward(actor, isGetSpec, index)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_GetWorkReward)
    LDataPack.writeChar(pack, isGetSpec)
    LDataPack.writeChar(pack, index)
    LDataPack.flush(pack)
end

--领取打工次数奖励
function c2sGetTimesReward(actor, pack)
    local index = LDataPack.readChar(pack)
    if not ShenShouWorkTimesConfig[index] then return end
    local data = getShenShouStaticVar(actor)
    if data.worktimes < ShenShouWorkTimesConfig[index].times then
        return
    end
    if System.bitOPMask(data.timesstatus, index) then
        return
    end
    data.timesstatus = System.bitOpSetMask(data.timesstatus, index, true)
    actoritem.addItems(actor, ShenShouWorkTimesConfig[index].reward, "ShenShou work times reward")
    sendShenShouWorkInfo(actor)
end

--开启团队个数
function c2sOpenTeam(actor, pack)
    local data = getShenShouStaticVar(actor)
    local index = data.groupcnt - ShenShouCommonConfig.initTeamCnt + 1
    if not ShenShouCommonConfig.newTeamYuanbao[index] then
        return
    end
    
    local Svip = LActor.getSVipLevel(actor)
    if data.groupcnt + 1 > SVipConfig[Svip].shenshouworkteam then
        return
    end
    if not actoritem.checkItem(actor, NumericType_YuanBao, ShenShouCommonConfig.newTeamYuanbao[index]) then
        return false
    end
    actoritem.reduceItem(actor, NumericType_YuanBao, ShenShouCommonConfig.newTeamYuanbao[index], "ShenShou work open team")
    data.groupcnt = data.groupcnt + 1
    sendShenShouWorkInfo(actor)
end

local function onNewDayArrive(actor, login)
    local data = getShenShouStaticVar(actor)
    data.worktimes = 0
    data.timesstatus = 0
    if not login then
        sendShenShouWorkInfo(actor)
    end
end

local function onLogin(actor)
    sendShenShouWorkInfo(actor)
end

local function regEvent()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDayArrive)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_GoWork, c2sGoWork)
    netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_CancelWork, c2sCancelWork)
    netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_QuicklyWork, c2sQuicklyWork)
    netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_GetWorkReward, c2sGetWorkReward)
    netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_GetTimesReward, c2sGetTimesReward)
    netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_OpenTeam, c2sOpenTeam)
end

table.insert(InitFnTable, regEvent)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.worktimes = function (actor, args)
    local data = getShenShouStaticVar(actor)
    data.worktimes = tonumber(args[1])
    sendShenShouWorkInfo(actor)
end

gmCmdHandlers.gowork = function (actor, args)
    local data = getShenShouStaticVar(actor)
    local ShenShouData = shenshousystem.getShenShouStaticVar(actor)
    if data.curcnt >= data.groupcnt then return end
    local chooseIndex = 1
    if not ShenShouCommonConfig.checkTime[chooseIndex] then return end
    local chooseCnt = 1
    local choose = {}
    for i = 1, chooseCnt do
        choose[i] = {}
        choose[i].ShenShouId = 500001
        choose[i].roleId = 0
        if not ShenShouData.ShenShous[choose[i].roleId] or not ShenShouData.ShenShous[choose[i].roleId][choose[i].ShenShouId] then return end
        if checkIsWork(data, choose[i].ShenShouId, choose[i].roleId) then return end
    end
    
    local groupIndex = 0
    for i = 1, data.groupcnt do
        if data[i].starttime == 0 then
            data[i].starttime = os.time()
            data[i].membercnt = #choose
            data[i].choosetime = ShenShouCommonConfig.checkTime[chooseIndex]
            for j = 1, #choose do
                data[i].team[j].ShenShouId = choose[j].ShenShouId
                data[i].team[j].roleId = choose[j].roleId
            end
            groupIndex = i
            break
        end
    end
    
    data.curcnt = data.curcnt + 1
    
    addWorkTeam(actor, data[groupIndex], groupIndex)
    return true
end

gmCmdHandlers.setWorkTime = function (actor, args)
    local data = getShenShouStaticVar(actor)
    local num = tonumber(args[1] or 1)
    local time = tonumber(args[2] or 0)
    if data[num].choosetime > 0 then
        data[num].starttime = math.max(data[num].starttime - time, 0)
    end
    sendShenShouWorkInfo(actor)
    return true
end

gmCmdHandlers.clearWork = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.ShenShouwork = nil
    sendShenShouWorkInfo(actor)
    return true
end

