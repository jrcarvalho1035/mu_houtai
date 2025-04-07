--主城场景副本
module("lianfumainfuben", package.seeall)

local maxActorCount = 35--主城最大可容许的人数上限
local MonstersConfig = MonstersConfig

local LianfuMainId = 3

function getMainVar(isCreateEmpty)
    local var = System.getDyanmicVar()
    if not var then return end
    
    if not var.mainScene then var.mainScene = {} end--保存主城的所有副本handle
    if not var.mainSceneCount then var.mainSceneCount = 0 end--已经开启了多少个主城副本
    if isCreateEmpty then
        getEmptyFuben()
    end
    return var
end

function getEmptyFuben()
    local var = getMainVar()
    for i = 1, var.mainSceneCount do
        if var.mainScene[i] and Fuben.getFubenPtr(var.mainScene[i]) then
            local ins = instancesystem.getInsByHdl(var.mainScene[i])
            if ins and ins.actor_list_count < maxActorCount then
                return var.mainScene[i]
            end
        end
    end
    
    --没有空位置了，就重新建一个新的主城副本
    local fbHandle = instancesystem.createFuBen(LianfuMainId)
    if not fbHandle or fbHandle == 0 then print("getEmptyFuben:create fb fail") return end
    
    var.mainSceneCount = var.mainSceneCount + 1
    var.mainScene[var.mainSceneCount] = fbHandle
    return fbHandle
end

function sendData(pack)
    local var = System.getDyanmicVar()
    if not var then return end
    
    if not var.mainScene then return end
    if not var.mainSceneCount or var.mainSceneCount == 0 then return end
    
    for i = 1, var.mainSceneCount do
        local fbHandle = var.mainScene[i]
        Fuben.sendData(fbHandle, pack)
    end
end

--进入主城
function enterMainScene(actor, sceneid, posX, posY)
    if not actor then return end
    if not utils.checkFuben(actor, LianfuMainId) then return end
    
    local fbHandle, isnew = getEmptyFuben()
    if not fbHandle then print("enterMainScene:no main fbHandle") return end

    if not posX then
        posX, posY = utils.getSceneEnterCoor(LianfuMainId)
    end

    return LActor.enterFuBen(actor, fbHandle, sceneid or - 1, posX, posY)
end

function reqEnterMainScene(actor)
    if System.isCrossWarSrv() then return end
    if not actorlogin.checkCanEnterCross(actor) then return end
    local zslevel = LActor.getZhuansheng(actor)
    if zslevel < FubenConfig[LianfuMainId].condition.zslevel then return end

    local lianfuId = csbase.getLianfuServerId()
    if not csbase.isConnected(lianfuId) then return end
    LActor.loginOtherServer(actor, lianfuId, 1, 0, 0, 0, "lianfu")
    return true
end

local function enterLianfuMain(actor)
    if not System.isLianFuSrv() then return end
    enterMainScene(actor)
end

function onOffline(ins, actor)
    local actorId = LActor.getActorId(actor)
    ins.actor_list[actorId] = nil
    ins.actor_list_count = ins.actor_list_count - 1
end

function onNewDay(actor, login)
    local var = getActorVar(actor)
    var.gettimes = 0
end

local function onLogin(actor)
    if System.isCrossWarSrv() then return end
    local ret = csbase.getLianfuServerId() and 1 or 0
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_IsHaveLianfu)
    if not pack then return end
    LDataPack.writeChar(pack, ret)
    LDataPack.flush(pack)
end

--actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)
--engineevent.regGameStartEvent(OnGameStart)

_G.enterLianfuMain = enterLianfuMain

function init()
    if not System.isLianFuSrv() then return end
    --insevent.registerInstanceEnter(LianfuMainId, ehEnterFuben)
    insevent.registerInstanceOffline(LianfuMainId, onOffline)
end
table.insert(InitFnTable, init)
netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.sBaseCmd_ReqEnterLianfu, reqEnterMainScene)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.mainFubenTest = function (actor)
    local var = System.getDyanmicVar()
    print(var.mainSceneCount)
    return true
end
