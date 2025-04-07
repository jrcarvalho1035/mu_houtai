--精灵打工


function getDamonStaticVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.damonwork then
        var.damonwork = {}
    end
    var = var.damonwork
    if not var.worktimes then var.worktimes = 0 end --今天工作次数
    if not var.curcnt then var.curcnt = 0 end --现在打工的团队个数
    if not var.groupcnt then var.groupcnt = DamonCommonConfig.initTeamCnt end --分队个数
    if not var.timesstatus then var.timesstatus = 0 end --打工次数奖励领取状态
    for i=1, DamonCommonConfig.initTeamCnt + #DamonCommonConfig.newTeamYuanbao do
        if not var[i] then
            var[i] = {}
            var[i].choosetime = 0
            var[i].starttime = 0
            var[i].membercnt = 0
            var[i].team = {}
            for j=1, 4 do
                var[i].team[j] = {}
                var[i].team[j].damonId = 0
                var[i].team[j].roleId = 0
            end
        end
    end
    return var
end

function sendDamonWorkInfo(actor)
    local data = getDamonStaticVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_WorkInfo)
    LDataPack.writeChar(pack, data.worktimes)
    LDataPack.writeInt(pack, data.timesstatus)
    local totalCnt = DamonCommonConfig.initTeamCnt + #DamonCommonConfig.newTeamYuanbao
    LDataPack.writeChar(pack, totalCnt)
    for i=1, totalCnt do
        LDataPack.writeChar(pack, i)
        if i > data.groupcnt then
            LDataPack.writeChar(pack, 0)
        else
            LDataPack.writeChar(pack, 1)
        end
        LDataPack.writeChar(pack, data[i].membercnt)
        local wanchengdu = 0
        for j=1, data[i].membercnt do
            LDataPack.writeInt(pack, data[i].team[j].damonId)
            LDataPack.writeChar(pack, data[i].team[j].roleId)
            wanchengdu = wanchengdu + DamonConfig[data[i].team[j].damonId].completion/10000
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
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_GoWork)
    LDataPack.writeChar(pack, index)
    LDataPack.writeChar(pack, data.membercnt)
    local wanchengdu = 0
    for i=1, data.membercnt do
        LDataPack.writeInt(pack, data.team[i].damonid)
        LDataPack.writeChar(pack, data.team[i].roleId)
        wanchengdu = wanchengdu + DamonConfig[data.team[i].damonId].completion/10000
    end
    local remaintime = data.starttime + data.choosetime * 3600 - os.time()
    LDataPack.writeInt(pack, remaintime > 0 and remaintime or 0)
    local cnt = data.choosetime * wanchengdu
    LDataPack.writeDouble(pack, cnt)

    LDataPack.flush(pack)    
end

--检查该精灵是否已经在工作
function checkIsWork(data, damonId, roleId)
    for i=1, data.groupcnt do
        if data[i].starttime ~= 0 then
            for j=1, data[i].membercnt do
                if data[i].team[j].damonId == damonId and data[i].team[j].roleId == roleId then
                    return true
                end
            end
        end
    end
    return false
end

--开始打工
function c2sGoWork(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.damonwork) then return end
    local data = getDamonStaticVar(actor)
    local damonData = damonsystem.getDamonStaticVar(actor)
    if data.curcnt >= data.groupcnt then return end        
    local chooseIndex = LDataPack.readChar(pack)
    if not DamonCommonConfig.checkTime[chooseIndex] then return end
    local chooseCnt = LDataPack.readChar(pack)
    local choose = {}
    for i=1, chooseCnt do
        choose[i] = {}
        choose[i].damonId = LDataPack.readInt(pack)
        choose[i].roleId = LDataPack.readChar(pack)
        if not damonData.damons[choose[i].roleId] or not damonData.damons[choose[i].roleId][choose[i].damonId] then return end
        if checkIsWork(data, choose[i].damonId, choose[i].roleId) then return end
    end

    local groupIndex = 0
    for i=1, data.groupcnt do
        if data[i].starttime == 0 then
            data[i].starttime = os.time()
            data[i].membercnt = #choose
            data[i].choosetime = DamonCommonConfig.checkTime[chooseIndex]
            for j=1, #choose do
                data[i].team[j].damonId = choose[j].damonId
                data[i].team[j].roleId = choose[j].roleId
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
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_CancelWork)
    LDataPack.writeChar(pack, index)
    LDataPack.flush(pack)
end

--取消打工
function c2sCancelWork(actor, pack)
    local chooseIndex = LDataPack.readChar(pack)
    local data = getDamonStaticVar(actor)
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
    local data = getDamonStaticVar(actor)
    if not data[chooseIndex] then
        return
    end
    local remaintime = data[chooseIndex].starttime + data[chooseIndex].choosetime * 3600 - os.time()
    if remaintime <= 0 then
        return
    end
    local needYuanbao = math.ceil(DamonCommonConfig.quicklyYuanbao * remaintime/60)
    if not actoritem.checkItem(actor, NumericType_YuanBao, needYuanbao) then
		return false
    end
    data[chooseIndex].starttime = data[chooseIndex].starttime - remaintime
	actoritem.reduceItem(actor, NumericType_YuanBao, needYuanbao, "damon work quickly")
    sendDamonWorkInfo(actor)
end

--领取打工奖励
function c2sGetWorkReward(actor, pack)
    local chooseIndex = LDataPack.readChar(pack)
    local data = getDamonStaticVar(actor)
    local work = data[chooseIndex]
    if not work or work.starttime == 0 then
        return
    end
    local remaintime = work.starttime + work.choosetime * 3600 -  os.time()
    if remaintime > 0 then
        return
    end
    local wanchengdu = 0
    for i=1, work.membercnt do
        wanchengdu = wanchengdu + DamonConfig[work.team[i].damonId].completion/10000
    end

    for k,conf in ipairs(DamonCommonConfig.workNormal) do
        actoritem.addItem(actor, conf.id, math.floor(conf.count/2*wanchengdu * work.choosetime), "damon work reward")
    end

    --特殊奖励
    local isGetSpec = 0
    if math.random(1, 10000) <= math.ceil(wanchengdu/6 * 10000) then
        actoritem.addItems(actor, DamonCommonConfig.workSpec)
        isGetSpec = 1
    end
    sendGetWorkReward(actor, isGetSpec, chooseIndex)
    work.starttime = 0
    work.choosetime = 0
    work.membercnt = 0
    data.curcnt = data.curcnt - 1
    data.worktimes = data.worktimes + 1
    sendDamonWorkInfo(actor)
end

--领取打工奖励返回
function sendGetWorkReward(actor, isGetSpec, index)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_GetWorkReward)
    LDataPack.writeChar(pack, isGetSpec)
    LDataPack.writeChar(pack, index)
    LDataPack.flush(pack)
end

--领取打工次数奖励
function c2sGetTimesReward(actor, pack)
    local index = LDataPack.readChar(pack)
    if not DamonWorkTimesConfig[index] then return end
    local data = getDamonStaticVar(actor)
    if data.worktimes < DamonWorkTimesConfig[index].times then
        return
    end
    if System.bitOPMask(data.timesstatus, index) then
		return
    end
    data.timesstatus = System.bitOpSetMask(data.timesstatus, index, true)
    actoritem.addItems(actor, DamonWorkTimesConfig[index].reward, "damon work times reward")
    sendDamonWorkInfo(actor)
end

--开启团队个数
function c2sOpenTeam(actor, pack)
    local data = getDamonStaticVar(actor)  
    local index = data.groupcnt - DamonCommonConfig.initTeamCnt + 1
    if not DamonCommonConfig.newTeamYuanbao[index] then
        return
    end

    local vip = LActor.getVipLevel(actor)
    if data.groupcnt + 1 > VipConfig[vip].damonworkteam then
        return
    end
    if not actoritem.checkItem(actor, NumericType_YuanBao, DamonCommonConfig.newTeamYuanbao[index]) then
		return false
    end	
	actoritem.reduceItem(actor, NumericType_YuanBao, DamonCommonConfig.newTeamYuanbao[index], "damon work open team")
    data.groupcnt = data.groupcnt + 1
    sendDamonWorkInfo(actor)
end


local function onNewDayArrive(actor, login)
    local data = getDamonStaticVar(actor)
    data.worktimes = 0
    data.timesstatus = 0
    if not login then
        sendDamonWorkInfo(actor)
    end
end

local function onLogin(actor)
    sendDamonWorkInfo(actor)
end

local function regEvent()
--	actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
--    actorevent.reg(aeCreateRole, onCreateRole)
    actorevent.reg(aeNewDayArrive, onNewDayArrive)

	netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_GoWork, c2sGoWork)
    netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_CancelWork, c2sCancelWork)
    netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_QuicklyWork, c2sQuicklyWork)    
	netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_GetWorkReward, c2sGetWorkReward)
    netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_GetTimesReward, c2sGetTimesReward)
    netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_OpenTeam, c2sOpenTeam)    
end

table.insert(InitFnTable, regEvent)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.worktimes = function (actor, args)
    local data = getDamonStaticVar(actor)
    data.worktimes = tonumber(args[1])
    sendDamonWorkInfo(actor)
end

gmCmdHandlers.gowork = function (actor, args)
    local data = getDamonStaticVar(actor)
    local damonData = damonsystem.getDamonStaticVar(actor)
    if data.curcnt >= data.groupcnt then return end
    local chooseIndex = 1
    if not DamonCommonConfig.checkTime[chooseIndex] then return end
    local chooseCnt = 1
    local choose = {}
    for i=1, chooseCnt do
        choose[i] = {}
        choose[i].damonId = 500001
        choose[i].roleId = 0
        if not damonData.damons[choose[i].roleId] or not damonData.damons[choose[i].roleId][choose[i].damonId] then return end
        if checkIsWork(data, choose[i].damonId, choose[i].roleId) then return end
    end

    local groupIndex = 0
    for i=1, data.groupcnt do
        if data[i].starttime == 0 then
            data[i].starttime = os.time()
            data[i].membercnt = #choose
            data[i].choosetime = DamonCommonConfig.checkTime[chooseIndex]
            for j=1, #choose do
                data[i].team[j].damonId = choose[j].damonId
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
    local data = getDamonStaticVar(actor)
    local num = tonumber(args[1] or 1)
    local time = tonumber(args[2] or 0)
    if data[num].choosetime > 0 then
        data[num].starttime = math.max(data[num].starttime - time,0) 
    end
    sendDamonWorkInfo(actor)
    return true
end
