--宝藏猎人

module("subactivity40", package.seeall)

local subType = 40

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.floor then var.floor = 1 end
    if not var.index then var.index = 1 end
    if not var.curChoose then var.curChoose = 0 end
    if not var.count then var.count = 0 end
    if not var.chooses then var.chooses = {} end
    if not var.boxs then var.boxs = {} end
    return var
end

local function getAct40CommonReward(config)
    local reward
    local rate = math.random(1, 10000)
    for _, conf in ipairs(config.commonRewardPool) do
        if rate <= conf.rate then
            reward = {
                type = conf.type,
                id = conf.id,
                count = conf.count,
                baoji = conf.baoji or 1,
            }
            break
        else
            rate = rate - conf.rate
        end
    end
    return reward
end

function getAct40Reward(var, index, config, count)
    local rate = 0
    for _, conf in ipairs(config.superRates) do
        if count <= conf.count then
            rate = conf.rate
            break
        end
    end
    
    local reward
    local commonRewards = {}
    local isSuper = rate >= math.random(1, 10000)
    if isSuper then
        reward = utils.table_clone(config.superRewards[var.curChoose])
        reward.baoji = 1
        for idx = 1, config.maxBox do
            if not var.boxs[idx] and index ~= idx then
                local item = getAct40CommonReward(config)
                item.idx = idx
                table.insert(commonRewards, item)
            end
        end
    else
        reward = getAct40CommonReward(config)
    end
    
    return reward, isSuper, commonRewards
end

----------------------------------------------------------------------------------
--Processamento de protocolo
--71-110 Dados de atividades de caçadores de tesouros
function s2cAct40Info(actor, id)
    local var = getActorVar(actor, id)
    if not var then return end
    
    local config = ActivityType40Config[id][var.index]
    if not config then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Act40Info)
    if not pack then return end
    
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, var.floor)
    LDataPack.writeInt(pack, var.index)
    LDataPack.writeChar(pack, var.curChoose)
    
    LDataPack.writeChar(pack, #config.superRewards)
    for idx in ipairs(config.superRewards) do
        LDataPack.writeChar(pack, idx)
        LDataPack.writeChar(pack, var.chooses[idx] or 0)
    end
    
    LDataPack.writeChar(pack, config.maxBox)
    for idx = 1, config.maxBox do
        local box = var.boxs[idx]
        LDataPack.writeChar(pack, idx)
        LDataPack.writeInt(pack, box and box.id or 0)
        LDataPack.writeInt(pack, box and box.count or 0)
        LDataPack.writeChar(pack, box and box.baoji or 0)
    end
    LDataPack.flush(pack)
end

--71-111 Treasure Hunter-Solicite um flop
local function c2sAct40GetReward(actor, pack)
    local id = LDataPack.readInt(pack)
    local idx = LDataPack.readChar(pack)
    if activitymgr.activityTimeIsEnd(id) then return end
    
    if not ActivityType40Config[id] then return end
    
    local var = getActorVar(actor, id)
    if not var then return end
    
    if var.curChoose == 0 then return end
    
    local index = var.index
    local config = ActivityType40Config[id][index]
    if not config then return end
    
    if idx <= 0 or idx > config.maxBox then return end
    if var.boxs[idx] then return end
    
    local count = var.count + 1
    if count > config.maxBox then return end
    
    if not actoritem.checkItem(actor, config.costItemId, config.costItemCount) then
        return
    end
    actoritem.reduceItem(actor, config.costItemId, config.costItemCount, "activity40 cost")
    
    var.count = count
    local reward, isSuper, rewards = getAct40Reward(var, idx, config, count)
    if not reward then 
        print("subactivity40.c2sAct40GetReward reward is nil")
        return 
    end
    var.boxs[idx] = {
        id = reward.id,
        count = reward.count,
        baoji = reward.baoji,
    }
    actoritem.addItem(actor, reward.id, reward.count * reward.baoji, 'activity40 reward')

    if isSuper then
        local nIndex = index + 1
        if config.loopIndex ~= 0 then
            nIndex = config.loopIndex
        end
        local choose = var.curChoose
        local nConfig = ActivityType40Config[id][nIndex]
        if not nConfig then
            nIndex = 1
            print("subactivity40.c2sAct40GetReward nConfig is nil")
        end
        var.floor = var.floor + 1
        var.index = nIndex
        var.curChoose = 0
        var.count = 0
        if config.loopIndex ~= 0 or nConfig.group ~= config.group then
            var.chooses = {}
        else
            var.chooses[choose] = 1
        end
        var.boxs = {}
        
        -- Distribua as recompensas restantes
        for _, v in ipairs(rewards) do
            actoritem.addItem(actor, v.id, v.count * v.baoji, 'activity40 rewards')
        end
        subactivity34.addValue(actor, 1, 4)
    end
    subactivity1.addType40selfScore(actor, 1)
    s2cAct40GetReward(actor, id, idx, reward, isSuper, rewards)
    if isSuper then
        s2cAct40Info(actor, id)
    end
end

--71-111 Caçador de Tesouros - Retorno ao Flop
function s2cAct40GetReward(actor, id, idx, reward, isSuper, rewards)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Act40GetReward)
    if not pack then return end
    
    LDataPack.writeInt(pack, id)
    LDataPack.writeChar(pack, idx)
    LDataPack.writeInt(pack, reward.id)
    LDataPack.writeInt(pack, reward.count)
    LDataPack.writeChar(pack, reward.baoji)
    LDataPack.writeChar(pack, isSuper and 1 or 0)
    LDataPack.writeChar(pack, #rewards)
    for _, v in ipairs(rewards) do
        LDataPack.writeChar(pack, v.idx)
        LDataPack.writeInt(pack, v.id)
        LDataPack.writeInt(pack, v.count)
        LDataPack.writeChar(pack, v.baoji)
    end
    LDataPack.flush(pack)
end

--71-112 Caçador de Tesouros - Solicitação para selecionar o Jackpot
local function c2sAct40Choose(actor, pack)
    local id = LDataPack.readInt(pack)
    local choose = LDataPack.readChar(pack)
    if activitymgr.activityTimeIsEnd(id) then return end

    if not ActivityType40Config[id] then return end
    
    local var = getActorVar(actor, id)
    if not var then return end
    
    local index = var.index
    local config = ActivityType40Config[id][index]
    if not config then return end
    if not config.superRewards[choose] then return end
    if var.chooses[choose] == 1 then return end
    
    var.curChoose = choose
    s2cAct40Choose(actor, id, choose)
end

--71-112 Voltar para selecionar o Grande Prêmio
function s2cAct40Choose(actor, id, choose)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Act40Choose)
    if not pack then return end
    
    LDataPack.writeInt(pack, id)
    LDataPack.writeChar(pack, choose)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--manipulação de eventos

local function onLogin(actor, type, id)
    if activitymgr.activityTimeIsOver(id) then return end
    s2cAct40Info(actor, id)
end

local function onAfterNewDay(actor, id)
    if activitymgr.activityTimeIsOver(id) then return end
    s2cAct40Info(actor, id)
end

local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    local v = record and record.data and record.data.rewardsRecord or 0
    LDataPack.writeInt(npack, v)
end

----------------------------------------------------------------------------------
--inicialização
function init()
    if System.isLianFuSrv() then return end
    subactivitymgr.regNewDayAfterFunc(subType, onAfterNewDay)
    subactivitymgr.regLoginFunc(subType, onLogin)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Act40GetReward, c2sAct40GetReward)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Act40Choose, c2sAct40Choose)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--Comandos GM
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.act40GetReward = function (actor, args)
    local id = 5020
    local idx = tonumber(args[1])
    if not idx then
        idx = math.random(1, 49)
    end
    print("on act40GetReward idx =", idx)
    local pack = LDataPack.allocPacket()
    LDataPack.writeInt(pack, id)
    LDataPack.writeChar(pack, idx)
    LDataPack.setPosition(pack, 0)
    c2sAct40GetReward(actor, pack)
    return true
end

gmCmdHandlers.act40Choose = function (actor, args)
    local id = 5020
    local choose = tonumber(args[1])
    if not choose then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeInt(pack, id)
    LDataPack.writeChar(pack, choose)
    LDataPack.setPosition(pack, 0)
    c2sAct40Choose(actor, pack)
    return true
end

gmCmdHandlers.act40Print = function (actor, args)
    local id = 5020
    local var = getActorVar(actor, id)
    if not var then return end
    
    local config = ActivityType40Config[id][var.index]
    if not config then return end
    
    print("var.floor =", var.floor)
    print("var.index =", var.index)
    print("var.curChoose =", var.curChoose)
    print("var.count =", var.count)
    for idx in ipairs(config.superRewards) do
        print("superReward var.chooses[idx] =", var.chooses[idx])
    end
    
    for idx = 1, config.maxBox do
        local box = var.boxs[idx]
        if box then
            print("superReward idx =", idx, "id =", box.id, "count =", box.count, "baoji =", box.baoji)
        end
    end
    return true
end
