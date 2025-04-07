module("juqingtask",package.seeall)

local fconf = FubenPlotConfig
local cconf = FubenPlotCommonConfig
function getVar(actor)
    local var = LActor.getStaticVar(actor)
    if var.juqing == nil then var.juqing = {} end
    if var.juqing.curId == nil then var.juqing.curId = 1 end
    if var.juqing.status == nil then var.juqing.status = 0 end
    if var.juqing.tmpId == nil then var.juqing.tmpId = 1 end
    return var.juqing
end

function sendTaskInfo(actor)    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Juqing, Protocol.sJuqingCmd_CurTask)
    local data = getVar(actor)
    LDataPack.writeWord(pack, data.tmpId)
    LDataPack.writeByte(pack, data.status)
    LDataPack.flush(pack)
end

--领取奖励
function getReward(actor)
    local data = getVar(actor)
    if data.status == 2 then return end
    local idconfig = fconf[data.tmpId]
    if not idconfig then return end
    actoritem.addItemsByJob(actor, idconfig.awardList, "juqing rewards")
    if idconfig.titleId ~= 0 then
        titlesystem.addTitle(actor, idconfig.titleId)
    end
    utils.logCounter(actor, "othersystem", data.tmpId, "", "novicetask", "finish")
    if data.curId ~= #fconf then        
        data.tmpId = data.tmpId + 1        
        if fconf[data.tmpId - 1].issave ~= 0 then
            data.curId = data.tmpId
        end
        sendTaskInfo(actor)
        utils.logCounter(actor, "othersystem", data.tmpId, "", "novicetask", "accept")

        --是否切换副本
        local curidconfig = fconf[data.tmpId]
        if not curidconfig then return end
        if curidconfig.fbId == idconfig.fbId then return end
        
        local fbHandle = instancesystem.createFuBen(curidconfig.fbId)
        if not fbHandle or fbHandle == 0 then return end
        LActor.enterFuBen(actor, fbHandle, -1, curidconfig.rolePos.x, curidconfig.rolePos.y)
        return
    end
    
    --剧情任务做完了
    data.status = 2    
    sendTaskInfo(actor)
    maintask.onLogin(actor)
    staticfuben.returnToGuajiFuben(actor)
end

--切换剧情副本
function switchFuben(actor, packet)
    local data = getVar(actor)
    local idconfig = fconf[data.tmpId]
    if not idconfig then return end
    
    local preidconfig = fconf[data.tmpId - 1]
    if not preidconfig then return end
    if idconfig.fbId == preidconfig.fbId then return end

    local fbHandle = instancesystem.createFuBen(idconfig.fbId)
    if not fbHandle or fbHandle == 0 then print("switchFuben:create fb fail") return end
    LActor.enterFuBen(actor, fbHandle, -1, idconfig.rolePos.x, idconfig.rolePos.y)
end

function enterPlotFuben(actor)
    local data = getVar(actor)
    if data.status == 2 then return end
    --if data.tmpId == #fconf then return end
    local idconfig = fconf[data.tmpId]
    if not idconfig then return end
    
    local fbHandle = instancesystem.createFuBen(idconfig.fbId)
    if not fbHandle or fbHandle == 0 then print("enterPlotFuben:create fb fail") return end
    return LActor.enterFuBen(actor, fbHandle, -1, idconfig.rolePos.x, idconfig.rolePos.y)
end

function onLogin(actor)
    local data = getVar(actor)
    if data.status == 2 then return end
    --if data.tmpId > #fconf then return end
    data.tmpId = data.curId
    sendTaskInfo(actor)
    --怪物
    local list = {}
    for i=1, #cconf.monsterIds do
        table.insert(list, cconf.monsterIds[i])
    end
    slim.s2cMonsterConfig(actor, list)
end

_G.enterPlotFuben = enterPlotFuben

actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Juqing, Protocol.cJuqingCmd_GetReward, getReward)
--netmsgdispatcher.reg(Protocol.CMD_Juqing, Protocol.cJuqingCmd_SwitchFuben, switchFuben)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.juqing = function (actor, args)
    local data = getVar(actor)
    data.tmpId = tonumber(args[1])
    data.status = 0
    sendTaskInfo(actor)
    return true
end

gmCmdHandlers.juqingf = function (actor, args)
    local data = getVar(actor)
    for i = 1, #fconf do
        actoritem.addItemsByJob(actor, fconf[i].awardList, "juqing rewards")
    end
    data.tmpId = #fconf
    data.status = 2
    sendTaskInfo(actor)
    maintask.onLogin(actor)
    staticfuben.returnToGuajiFuben(actor)
    return true
end
