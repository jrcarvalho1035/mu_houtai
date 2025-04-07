-- 点券放送
module("subactivity20", package.seeall)

local subType = 20
local vt = {}
local PV_MAX = 10000000
local GV_MAX = 100
local type20rank3id = {}

local function getActorVar(actor, id)
    return activitymgr.getSubVar(actor, id)
end

local function setGvAutoUse(actor, id, val)
    local var = getActorVar(actor, id)
    var.gv_auto = val
end

local function isGvAutoUse(actor, id)
    local var = getActorVar(actor, id)
    return var.gv_auto
end

local function clearActorValue(actor, id, login)
    local var = getActorVar(actor, id)
    var.pv = 0
    local param = activitymgr.getParamConfig(id)
    subactivity1.clearRecord(actor, param)
    subactivity1.setType20Pv(actor, 0)
    if not login then
        sendInfo(actor, id)
    end
end

local function clearOnlineActorValue(id)
    local list = System.getOnlineActorList()
    if list then
        for _, actor in ipairs(list) do
            clearActorValue(actor, id)
        end
    end
end

local function getActorData(id, actor_id)
    local var = activitymgr.getGlobalVar(id)
    if not var.actor_data then
        var.actor_data = {}
    end

    local actor_data = var.actor_data[actor_id]
    if actor_data == nil  then
        actor_data = {}
        var.actor_data[actor_id] = actor_data
    end

    local cv_num = getCvNum(id)
    local cv_data = actor_data[cv_num]
    if cv_data == nil then
        cv_data = {}
        actor_data[cv_num] = cv_data
    end

    return cv_data
end

local function clearActorData(id, actor_id)
    local var = activitymgr.getGlobalVar(id)
    if not var.actor_data then
        var.actor_data = {}
    end

    var.actor_data[actor_id] = nil
end

local function actorSetPv(id, actor_id, val)
    local data = getActorData(id, actor_id)
    data.pv = val
end

local function actorSetPvRecord(id, actor_id, flag)
    local data = getActorData(id, actor_id)
    data.flag = flag
end

local function iterActor(id, fn)
    local var = activitymgr.getGlobalVar(id)
    if not var.actor_data then
        var.actor_data = {}
    end

    for actor_id, data in pairs(var.actor_data) do
        fn(actor_id, data)
    end
end

local function getPvRank(id)
    local cv_num = getCvNum(id)
    local rankName = 'type20pvrank_' .. tostring(id) .. '_' .. tostring(cv_num)
    local rank = Ranking.getRanking(rankName)
    if rank == nil then
        local rankFile = rankName .. '.rank'
        rank = utils.rankfunc.InitRank(rankName, rankFile, 1000, {'time', 'serverid', 'actorid', 'job', 'name'}, true)
    end

    return rank
end

local function clearPvRank(id)
    for cv_num = 0, 1000 do
        local rankName = 'type20pvrank_' .. tostring(id) .. '_' .. tostring(cv_num)
        local rank = Ranking.getRanking(rankName)
        if rank then
            Ranking.clearRanking(rank)
            Ranking.save(rank, rankName .. '.rank')
        end
    end
end

local function getPvNo1Data(id, cv_num)
    local var = activitymgr.getGlobalVar(id)
    local data = var[cv_num]
    if data == nil then
        var[cv_num] = {}
        data = var[cv_num]
    end
    return data
end

local function clearPvNo1Data(id, cv_num)
    local var = activitymgr.getGlobalVar(id)
    var[cv_num] = {}
end

-- Este servidor
local function onCrossPvNo1(sId, sType, pack)
    local id = LDataPack.readInt(pack)
    local cv_num = LDataPack.readInt(pack)
    local pv = LDataPack.readInt(pack)
    local server_id = LDataPack.readInt(pack)
    local actor_id = LDataPack.readInt(pack)
    local job = LDataPack.readByte(pack)
    local name = LDataPack.readString(pack)

    local isNew = false
    local data = getPvNo1Data(id, cv_num)
    if data.actor_id ~= actor_id then
        isNew = true
    end
    data.server_id = server_id
    data.actor_id = actor_id
    data.job = job
    data.name = name
    data.pv = pv
    print('subactivity20.onCrossPvNo1 id=', id, 'cv_num=', cv_num, 'server_id=', server_id, 'actor_id=', actor_id, 'name=', name, 'pv=', pv)

    if isNew then
        local list = System.getOnlineActorList()
        if list then
            for _, actor in ipairs(list) do
                sendInfo(actor, id)
            end
        end
    else
        local actor = LActor.getActorById(actor_id)
        if actor then
            sendInfo(actor, id)
        end
    end
end

-- Este servidor
local function onCrossPvNo1Point(sId, sType, pack)
    local id = LDataPack.readInt(pack)
    local cv_num = LDataPack.readInt(pack)
    local actor_id = LDataPack.readInt(pack)
    local pv = LDataPack.readInt(pack)

    local data = getPvNo1Data(id, cv_num)
    if data.actor_id == actor_id then
        data.pv = pv
    end
    print('subactivity20.onCrossPvNo1Point id=', id, 'cv_num=', cv_num, 'actor_id=', actor_id, 'pv=', pv)

    local actor = LActor.getActorById(actor_id)
    if actor then
        sendInfo(actor, id)
    end
end

local function sendServerPvNo1Point(id, no1_id, point)
    local cv_num = getCvNum(id)

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCActivity20Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivity20Cmd_SendServerPvNo1Point)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, cv_num)
    LDataPack.writeInt(npack, no1_id)
    LDataPack.writeInt(npack, point)
    System.sendPacketToAllGameClient(npack, 0)
end

local function sendServerPvNo1(id, no1_id, rankItem)
    assert(rankItem)

    local server_id = Ranking.getSubInt(rankItem, 1)
    local actor_id = Ranking.getSubInt(rankItem, 2)

    local job = Ranking.getSubInt(rankItem, 3)
    local name = Ranking.getSub(rankItem, 4)

    local cv_num = getCvNum(id)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCActivity20Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivity20Cmd_SendServerPvNo1)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, cv_num)
    LDataPack.writeInt(npack, Ranking.getPoint(rankItem))
    LDataPack.writeInt(npack, server_id)
    LDataPack.writeInt(npack, actor_id)
    LDataPack.writeByte(npack, job)
    LDataPack.writeString(npack, name)
    System.sendPacketToAllGameClient(npack, 0)
end

local function sendServerClearPvNo1(id)
    local cv_num = getCvNum(id)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCActivity20Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivity20Cmd_SendServerPvNo1)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, cv_num)
    LDataPack.writeInt(npack, 0)
    LDataPack.writeInt(npack, 0)
    LDataPack.writeInt(npack, 0)
    LDataPack.writeByte(npack, 0)
    LDataPack.writeString(npack, '')
    System.sendPacketToAllGameClient(npack, 0)
end

-- Cross Server
local function onServerPv(sId, sType, pack)
    local id = LDataPack.readInt(pack)
    local val = LDataPack.readInt(pack)
    local actor_id = LDataPack.readInt(pack)
    local job = LDataPack.readByte(pack)
    local name = LDataPack.readString(pack)

    local rank = getPvRank(id)
    if rank == nil then
        print('subactivity20.onServerPv rank==nil id=', id)
        return
    end

    local no1_id = 0
    local rankItem = Ranking.getItemFromIndex(rank, 0)
    if rankItem then
        no1_id = Ranking.getSubInt(rankItem, 2)
    else
        local var = activitymgr.getGlobalVar(id)
        if var.leftCv then
            val = val - var.leftCv
            var.leftCv = nil
            addPvToComsrv(sId, id, actor_id, val)
        end
    end

    if val <= 0 then
        return
    end

    rankItem = Ranking.getItemPtrFromId(rank, actor_id)
    if rankItem then
        Ranking.updateItem(rank, actor_id, val)
    else
        rankItem = Ranking.tryAddItem(rank, actor_id, val)
        if rankItem then
            Ranking.setSubInt(rankItem, 0, System.getNowTime())
            Ranking.setSubInt(rankItem, 1, sId)
            Ranking.setSubInt(rankItem, 2, actor_id)
            Ranking.setSubInt(rankItem, 3, job)
            Ranking.setSub(rankItem, 4, name)
        end
    end

    -- Primeiro lugar: Profeta
    rankItem = Ranking.getItemFromIndex(rank, 0)
    if rankItem then
        sendServerPvNo1(id, no1_id, rankItem)
    end
end

local function sendCrossPv(actor, id, val)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCActivity20Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivity20Cmd_SendCrossPv)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, val)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeByte(npack, LActor.getJob(actor))
    LDataPack.writeString(npack, LActor.getName(actor))
    System.sendPacketToAllGameClient(npack, csbase.getCrossServerId())
end

-- Pontos pessoal
local function addPv(actor, id, val)
    local var = getActorVar(actor, id)
    local old = var.pv or 0
    local new = old + val
    if PV_MAX < new then
        new = PV_MAX
        val = new - old
    end
    var.pv = new
    var.cv_num = getCvNum(id)
    local actor_id = LActor.getActorId(actor)
    actorSetPv(id, actor_id, new)
    subactivity1.setType20Pv(actor, new)
    subactivity1.addType20PvSum(actor, val)
    subactivity34.addValue(actor, val, 2)

    activitymgr.sendValue(actor, id, vt.type20Pv, new)
    utils.logCounter(actor, 'type20pv', new, old, val, id)
    sendCrossPv(actor, id, val)
end

function addPvToComsrv(serverid, actid, actorid, pv)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCActivity20Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivity20Cmd_CrossAddPv)
    LDataPack.writeInt(npack, actid)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeInt(npack, pv)
    System.sendPacketToAllGameClient(npack, serverid)
end

--Aqui apenas o progresso do sacrifício do indivíduo nesta rodada é adicionado, e o progresso perdido é adicionado de volta.
function onCrossAddPv(sId, sType, pack)
    local id = LDataPack.readInt(pack)
    local actorid = LDataPack.readInt(pack)
    local pv = LDataPack.readInt(pack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end --Os jogadores não serão adicionados se não estiverem online.
    local var = getActorVar(actor, id)
    var.pv = (var.pv or 0) + pv
    subactivity1.setType20Pv(actor, var.pv)
    activitymgr.sendValue(actor, id, vt.type20Pv, var.pv)
end

function getPv(actor, id)
    local var = getActorVar(actor, id)
    return var.pv or 0
end

-- Valor da zona de guerra, enviado para vários servidores
local function addCv(id, val)
    if not System.isCommSrv() then return end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCActivity20Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivity20Cmd_SendCrossAddCv)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, val)
    System.sendPacketToAllGameClient(npack, csbase.getCrossServerId())
end

local function sendServerCv(id, val)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCActivity20Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivity20Cmd_SendServerCv)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, val)
    System.sendPacketToAllGameClient(npack, 0)
end

-- Obtenha o estágio de toda a região
function getCvNum(id, var)
    if not var then
        var = activitymgr.getGlobalVar(id)
    end

    return var.cv_num or 0
end

local function addCvNum(id, var)
    if not var then
        var = activitymgr.getGlobalVar(id)
    end
    local old = var.cv_num or 0
    local new = old + 1
    var.cv_num = new
    clearPvNo1Data(id, new)
    print('subactivity20.addCvNum id=', id, 'cv_num=', new)
    return new
end

local function setCvNum(id, cv_num, var)
    if not var then
        var = activitymgr.getGlobalVar(id)
    end
    var.cv_num = cv_num
    print('subactivity20.setCvNum id=', id, 'cv_num=', cv_num)
    subactivity1.broadcastType20CvNum(cv_num)
end

function getCvConf(id, var)
    local config = ActivityType20Config[id]
    if config then
        local cv_num = getCvNum(id, var)
        return config[cv_num]
    end
end

function getCvConfPrev(id, var)
    local config = ActivityType20Config[id]
    if config then
        local cv_num = getCvNum(id, var)
        return config[cv_num - 1]
    end
end

-- Executado neste servidor
-- Mesclar e-mail de recompensa
local function onNewCvNum(id, cv_num)
    local param = activitymgr.getParamConfig(id)
    local type1conf = subactivitymgr.getConfig(1)[param]
    if type1conf then
        local old_cv_num = getCvNum(id)
        local cv_conf = getCvConf(id)
        if cv_conf and 0 < cv_conf.cv then -- not max config
            iterActor(id, function(actor_id, data)
                local cv_data = data[old_cv_num]
                if cv_data then
                    local pv = cv_data.pv or 0
                    local flag = cv_data.flag or 0
                    local list = {}
                    for k, conf in ipairs(type1conf) do
                        if conf.condition <= pv and System.bitOPMask(flag, k) == false then
                            flag = System.bitOpSetMask(flag, k, true)
                            list = actoritem.mergeItems(list, conf.rewards)
                        end
                    end

                    if 0 < flag then
                        cv_data.flag = flag
                    end

                    if 0 < #list then
                        local conf1 = type1conf[1]
                        local tMailData = {
                            head = conf1.head,
                            context = string.format(conf1.text, old_cv_num, pv),
                            tAwardList = list,
                        }
                        --mailsystem.sendMailById(actor_id, tMailData)
                        print('subactivity20.onNewCvNum #list=', #list, 'pv=', pv, 'flag=', flag, 'id=', id, 'actor_id=', actor_id)
                    else
                        print('subactivity20.onNewCvNum #list==0 pv=', pv, 'flag=', flag, 'actor_id=', actor_id)
                    end
                end
            end)
        end
    else
        print('subactivity20.onNewCvNum type1conf==nil param=', param, 'cv_num=', cv_num, 'id=', id)
    end

    setCvNum(id, cv_num)
    local var = activitymgr.getGlobalVar(id)
    var.cv = nil
    -- Limpar dados do jogador online
    clearOnlineActorValue(id)
end

-- Este servidor
local function onCrossCvNum(sId, sType, pack)
    local id = LDataPack.readInt(pack)
    local cv_num = LDataPack.readInt(pack)
    local job = LDataPack.readInt(pack)
    local name = LDataPack.readString(pack)
    onNewCvNum(id, cv_num)
    -- Anúncio de rotação de sacerdotes
    local type20NextNoticeId = ActivityCommonConfig.type20NextNoticeId
    if type20NextNoticeId then
        local noticeId = type20NextNoticeId[id]
        noticesystem.broadLoginNotice2(noticeId, job, name)
    end
end

local function sendServerCvNum(id, cv_num, no1_job, no1_name)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCActivity20Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivity20Cmd_SendServerCvNum)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, cv_num)
    LDataPack.writeInt(npack, no1_job or 0)
    LDataPack.writeString(npack, no1_name or '')
    System.sendPacketToAllGameClient(npack, 0)
end

local function sendServerPvNo1Reward(id)
    local rank = getPvRank(id)
    if rank == nil then
        print('subactivity20.sendServerPvNo1Reward rank==nil id=', id)
        return
    end

    local rankItem = Ranking.getItemFromIndex(rank, 0)
    if rankItem == nil then
        print('subactivity20.sendServerPvNo1Reward rankItem==nil id=', id)
        return
    end

    local conf = getCvConf(id)
    if conf == nil then
        print('subactivity20.sendServerPvNo1Reward conf==nil id=', id)
        return
    end

    if 0 < conf.cv then -- not max config
        local server_id = Ranking.getSubInt(rankItem, 1)
        local actor_id = Ranking.getSubInt(rankItem, 2)
        local tMailData = {
            head = conf.head,
            context = string.format(conf.context, conf.name),
            tAwardList = conf.reward,
        }
        mailsystem.sendMailById(actor_id, tMailData, server_id)
        print('subactivity20.sendServerPvNo1Reward id=', id, 'actor_id=', actor_id, 'server_id=', server_id)
    end
    local job = Ranking.getSubInt(rankItem, 3)
    local name = Ranking.getSub(rankItem, 4)
    return job, name
end

-- Servidor cruzado
local function onServerAddCv(sId, sType, pack)
    local id = LDataPack.readInt(pack)
    local val = LDataPack.readInt(pack)

    local var = activitymgr.getGlobalVar(id)
    local conf = getCvConf(id, var)
    if conf == nil then
        print('subactivity20.onServerAddCv conf==nil sId=', sId, 'id=', id, 'val=', val)
        return
    end

    local old = var.cv or 0
    local new = old + val
    local toNext = false
    local leftCv = 0
    if conf.cv < new then
        toNext = true
        leftCv = new - conf.cv
    end

    var.cv = new
    print('subactivity20.onServerAddCv sId=', sId, 'id=', id, 'val=', val, 'old=', old, 'new=', new, 'toNext=', toNext)

    sendServerCv(id, new)

    -- Entre na próxima etapa
    if not toNext then
        return
    end

    -- Recompensa do Profeta
    local job, name = sendServerPvNo1Reward(id)

    local cv_num = addCvNum(id, var)
    conf = getCvConf(id, var)
    if conf == nil then
        print('subactivity20.onServerAddCv toNext conf==nil sId=', sId, 'id=', id, 'cv_num=', cv_num)
        return
    end

    clearPvNo1Data(id, cv_num)
    sendServerCvNum(id, cv_num, job, name)
    sendServerClearPvNo1(id)
    local rank = getPvRank(id)
    Ranking.clearRanking(rank)
    var.leftCv = val - leftCv -- trick
    if var.leftCv <= 0 then
        var.leftCv = nil
    end
    -- Dados limpos para 0
    var.cv = leftCv
    sendServerCv(id, leftCv)
    clearOnlineActorValue(id)
end

-- Este servidor
local function onCrossCv(sId, sType, pack)
    local id = LDataPack.readInt(pack)
    local val = LDataPack.readInt(pack)
    local var = activitymgr.getGlobalVar(id)
    var.cv = val
    print('subactivity20.onCrossCv id=', id, 'cv=', val)
    activitymgr.broadcastValue(id, vt.type20Cv, val)
end

local function getCv(id)
    local var = activitymgr.getGlobalVar(id)
    return var.cv or 0
end

-- Alma do Profeta
local function addGv(actor, id, val)
    local var = getActorVar(actor, id)
    local old = var.gv or 0
    local new = old + val

    local conf = getCvConf(id)
    if conf then
        if conf.barV < new then
            new = conf.barV
        end
    else
        if GV_MAX < new then
            new = GV_MAX
        end
    end
    var.gv = new

    activitymgr.sendValue(actor, id, vt.type20Gv, new)
    utils.logCounter(actor, 'type20gv', new, old, val, id)
end

local function clearGv(actor, id)
    local var = getActorVar(actor, id)
    local old = var.gv or 0
    var.gv = nil
    activitymgr.sendValue(actor, id, vt.type20Gv, 0)
    utils.logCounter(actor, 'type20clearGv', 0, old, 0, id)
end

local function getGv(actor, id)
    local var = getActorVar(actor, id)
    return var.gv or 0
end

function isGvMax(actor, id)
    local conf = getCvConf(id)
    if conf == nil then
        return false
    end

    local gv = getGv(actor, id)
    if gv < conf.barV then
        return false
    end

    return true
end

function useItem(actor, conf, count)
    count = count or 1
    for id in pairs(ActivityType20Config) do
        if conf.id == id and not activitymgr.activityTimeIsEnd(id) then
            local cv_conf = getCvConf(id)
            if cv_conf and 0 < cv_conf.cv then
                local pv = conf.pv * count
                local cv = conf.cv * count

                addCv(id, cv)
                addPv(actor, id, pv)
                addGv(actor, id, conf.gv * count)

                -- Acumular os drops para cada uso do item
                local totalRewards = {}
                for i = 1, count do
                    local rewards = drop.dropGroup(conf.dropId)
                    for _, reward in ipairs(rewards) do
                        totalRewards[reward.id] = (totalRewards[reward.id] or 0) + reward.count
                    end
                end

                -- Converter a tabela acumulada em uma lista para adicionar ao jogador
                local aggregatedRewards = {}
                for itemId, cnt in pairs(totalRewards) do
                    table.insert(aggregatedRewards, { id = itemId, count = cnt })
                end

                actoritem.addItems(actor, aggregatedRewards, "activity type20 drop rewards")
            end
        end
    end
end


-- Quando o progresso total de todo o servidor atingir o máximo (após 100 rodadas), o limite precisará ser aumentado
-- Todos os jogadores não poderão mais realizar sacrifícios
function isCvNumMax(id)
    local cv_conf = getCvConf(id)
    if cv_conf then
        return cv_conf.cv <= 0
    else
        return true
    end
end

function sendInfo(actor, id)
    local cv_num = getCvNum(id)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Type20Info)
    if pack then
        LDataPack.writeInt(pack, id)
        LDataPack.writeInt(pack, getCv(id))
        LDataPack.writeShort(pack, cv_num)
        local data = getPvNo1Data(id, cv_num)
        LDataPack.writeInt(pack, data.pv or 0)
        LDataPack.writeString(pack, data.name or '')
        LDataPack.writeByte(pack, data.job or 0)
        LDataPack.writeByte(pack, isGvAutoUse(actor, id) and 1 or 0)
        LDataPack.flush(pack)
    end
end

local function handleInfo(actor, reader)
    local id = LDataPack.readInt(reader)

    sendInfo(actor, id)
end

local function handleUseGv(actor, reader)
    if System.isCrossWarSrv() then return end
    local id = LDataPack.readInt(reader)

    local actor_id = LActor.getActorId(actor)
    if activitymgr.activityTimeIsEnd(id) then
        print('subactivity20.handleUseGv activity is end id=', id, 'actor_id=', actor_id)
        return
    end

    local conf = getCvConf(id)
    if conf == nil then
        print('subactivity20.handleUseGv conf==nil id=', id, 'actor_id=', actor_id)
        return
    end

    local gv = getGv(actor, id)
    if gv < conf.barV then
        print('subactivity20.handleUseGv bad gv=', gv, 'id=', id, 'actor_id=', actor_id)
        return
    end

    clearGv(actor, id)

    local addVal = 1000
    utils.logCounter(actor, 'type20useGv', addVal, id)
    addCv(id, addVal)
    addPv(actor, id, addVal)
    print('subactivity20.handleUseGv addVal=', addVal, 'id=', id, 'actor_id=', actor_id)
end

local function onActivityFinish(id)
    print('subactivity20.onActivityFinish id=', id)
    sendServerPvNo1Reward(id)
end

local function loginCheckRank3(actor, id)
    local toId = type20rank3id[id]
    if toId then
        local actor_id = LActor.getActorId(actor)
        local index = subactivity34.getRank3Index(toId, actor_id)
        if index then
            local noticeId = ActivityCommonConfig.type20rank3NoticeId[index]
            if noticeId then
                noticesystem.broadLoginNotice(actor, noticeId)
            end
        end
    end
end

local function onLogin(actor)
    for id, config in pairs(ActivityType20Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local var = getActorVar(actor, id)
            if (var.cv_num or 0) ~= getCvNum(id) then
                clearActorValue(actor, id, 'login')
            end

            activitymgr.sendValue(actor, id, vt.type20Pv, getPv(actor, id))
            activitymgr.sendValue(actor, id, vt.type20Gv, getGv(actor, id))

            loginCheckRank3(actor, id)

            sendInfo(actor, id)
        end
    end
end

local function onType1Reward(actor, id, config, record)
    local actor_id = LActor.getActorId(actor)
    local param = activitymgr.getParamConfig(id)
    actorSetPvRecord(param, actor_id, record.data.rewardsRecord)
end

local function onServerReset(sId, sType, pack)
    local id = LDataPack.readInt(pack)
    clearOnlineActorValue(id)
    activitymgr.clearGlobalVar(id)
    subactivity34.reset()
    clearPvRank(id)
    local var = activitymgr.getGlobalVar(id)
    for i = 0, 1000 do
        var[i] = nil
        clearPvNo1Data(id, i)
    end
    print('subactivity20.onServerReset id=', id)
end

local function onServerCvNext(sId, sType, pack)
    local id = LDataPack.readInt(pack)

    local var = activitymgr.getGlobalVar(id)
    local cv_num = addCvNum(id)
    local no1_job, no1_name = sendServerPvNo1Reward(id)
    sendServerCvNum(id, cv_num, no1_job, no1_name)
    -- Dados limpos para 0
    var.cv = nil
    sendServerCv(id, 0)
    clearOnlineActorValue(id)
    print('subactivity20.onServerCvNext id=', id, 'cv_num=', cv_num)
end

local function sendCrossReset(id)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCActivity20Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivity20Cmd_SendCrossReset)
    LDataPack.writeInt(npack, id)
    System.sendPacketToAllGameClient(npack, csbase.getCrossServerId())
end

local function sendCrossCvNext(id)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCActivity20Cmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivity20Cmd_SendServerCvNext)
    LDataPack.writeInt(npack, id)
    System.sendPacketToAllGameClient(npack, csbase.getCrossServerId())
end

local function writeRecord(npack, record, config, id, actor)
    LDataPack.writeInt(npack, 0)
end

local function buy(actor, id, idx, param1, param2)
    local config = ActivityType20ExConfig[id]
    if config == nil then
        print('subactivity20.buy config==nil id=', id)
        return
    end

    local conf = config[idx]
    if conf == nil then
        print('subactivity20.buy conf==nil id=', id, 'idx=', idx)
        return
    end

    local diamond = conf.diamond or 0
    if diamond <= 0 then
        print('subactivity20.buy bad diamond=', diamond, 'id=', id, 'idx=', idx)
        return
    end

    if not actoritem.checkItem(actor, NumericType_YuanBao, diamond * param2) then
        print('subactivity20.buy checkItem fail diamond=', diamond, 'id=', id, 'idx=', idx)
        return
    end

    if not actoritem.reduceItem(actor, NumericType_YuanBao, diamond * param2, 'type20buy ' .. tostring(idx)) then
        print('subactivity20.buy reduceItem fail diamond=', diamond, 'id=', id, 'idx=', idx)
        return
    end

    if param1 == 0 then -- Comprar
        actoritem.addItem(actor, conf.item, param2, 'type20buy ' .. tostring(idx))
    else -- Compre e use
        if isGvMax(actor, id) then
            print('subactivity20.buy use isGvMax id=', id)
            return
        end

        if activitymgr.activityTimeIsEnd(id) then
            print('subactivity20.buy use activity end id=', id)
            return
        end

        useItem(actor, conf, param2)
    end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	if pack then
		LDataPack.writeByte(pack, 1) -- sucesso
		LDataPack.writeInt(pack, id)
        LDataPack.writeShort(pack, idx)
        LDataPack.writeShort(pack, param1)
        LDataPack.writeShort(pack, param2)
		LDataPack.flush(pack)
	end
end

local function handleSetGvAutoUse(actor, id, idx, param1, param2)
    if param2 == 0 then
        setGvAutoUse(actor, id, nil) -- false
    else
        setGvAutoUse(actor, id, true)
    end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	if pack then
		LDataPack.writeByte(pack, 1) -- 成sucesso功
		LDataPack.writeInt(pack, id)
        LDataPack.writeShort(pack, idx)
        LDataPack.writeShort(pack, param1)
        LDataPack.writeShort(pack, param2)
		LDataPack.flush(pack)
	end
end

local function getReward(actor, typeConfig, id, idx, record, reader)
    local param1 = LDataPack.readShort(reader)
    local param2 = LDataPack.readShort(reader)

    if param1 == 0 or param1 == 1 then
        buy(actor, id, idx, param1, param2)
    else
        handleSetGvAutoUse(actor, id, idx, param1, param2)
    end
end

local function onNewDayAfter(actor, id)
    sendInfo(actor, id)
end

local function initGlobalData()
    vt = activitymgr.vt
    type20rank3id = ActivityCommonConfig.type20rank3id or {}

    subactivitymgr.regLoginFunc(subType, onLogin)
    subactivitymgr.regGetRewardFunc(subType, getReward)
    subactivitymgr.regWriteRecordFunc(subType, writeRecord)
    subactivitymgr.regNewDayAfterFunc(subType, onNewDayAfter) -- Obrigatório ao longo dos dias
    for id in pairs(ActivityType20Config) do
        local type20pv = ActivityCommonConfig.type20pv
        if type20pv then
            local param = type20pv[id]
            if param then
                subactivity1.regRewardCallback(param, onType1Reward)
            end
        end
    end

    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_Type20Info, handleInfo)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_UseGv, handleUseGv)

    csmsgdispatcher.Reg(CrossSrvCmd.SCActivity20Cmd, CrossSrvSubCmd.SCActivity20Cmd_SendServerCv, onCrossCv)
    csmsgdispatcher.Reg(CrossSrvCmd.SCActivity20Cmd, CrossSrvSubCmd.SCActivity20Cmd_SendServerPvNo1, onCrossPvNo1)
    csmsgdispatcher.Reg(CrossSrvCmd.SCActivity20Cmd, CrossSrvSubCmd.SCActivity20Cmd_SendServerPvNo1Point, onCrossPvNo1Point)
    csmsgdispatcher.Reg(CrossSrvCmd.SCActivity20Cmd, CrossSrvSubCmd.SCActivity20Cmd_SendServerCvNum, onCrossCvNum)
    csmsgdispatcher.Reg(CrossSrvCmd.SCActivity20Cmd, CrossSrvSubCmd.SCActivity20Cmd_CrossAddPv, onCrossAddPv)

    if System.isCommSrv() then
        return
    end

    subactivitymgr.regActivityFinish(subType, onActivityFinish)

    csmsgdispatcher.Reg(CrossSrvCmd.SCActivity20Cmd, CrossSrvSubCmd.SCActivity20Cmd_SendCrossAddCv, onServerAddCv)
    csmsgdispatcher.Reg(CrossSrvCmd.SCActivity20Cmd, CrossSrvSubCmd.SCActivity20Cmd_SendCrossPv, onServerPv)
    csmsgdispatcher.Reg(CrossSrvCmd.SCActivity20Cmd, CrossSrvSubCmd.SCActivity20Cmd_SendCrossReset, onServerReset)
    csmsgdispatcher.Reg(CrossSrvCmd.SCActivity20Cmd, CrossSrvSubCmd.SCActivity20Cmd_SendServerCvNext, onServerCvNext)
end
table.insert(InitFnTable, initGlobalData)

local gmCmdHandlers = gmsystem.gmCmdHandlers
function gmCmdHandlers.type20UseItem(actor, args)
    local idx = tonumber(args[1]) or 1
    local count = tonumber(args[2]) or 1

    local k = next(ActivityType20ExConfig)
    local list = ActivityType20ExConfig[k]
    if list == nil then
        print('list==nil')
        return
    end

    local conf = list[idx]
    if conf == nil then
        print('conf==nil')
        return
    end

    for i = 1, count do
        useItem(actor, conf)
    end
    return true
end

-- Redefinir servidor cruzado ao mesmo tempo
function gmCmdHandlers.type20reset(actor, args)
    local id = tonumber(args[1])
    if id == nil then
        print('id==nil')
        return
    end

    local actor_id = LActor.getActorId(actor)
    local var = getActorVar(actor, id)
    var.pv = nil
    var.gv = nil
    clearActorData(id, actor_id)
    clearActorValue(actor, id)
    clearOnlineActorValue(id)

    local param = 1002
    subactivity1.clearRecord(actor, param)
    subactivity1.setType20Pv(actor, 0)
    subactivity1.setType20PvSum(actor, 0)
    activitymgr.sendActivityInfo(actor, param, true)

    for cv_num = 1, 1000 do
        clearPvNo1Data(id, cv_num)
    end

    activitymgr.clearGlobalVar(id)
    sendCrossReset(id)
    sendInfo(actor, id)
    return true
end

function gmCmdHandlers.type20CvNext(actor, args)
    local id = tonumber(args[1])
    if id == nil then
        print('id==nil')
        return
    end

    local count = tonumber(args[2]) or 1
    for i = 1, count do
        sendCrossCvNext(id)
    end
    return true
end

function gmCmdHandlers.type20loginNotice(actor, args)
    local id = tonumber(args[1])
    if id == nil then
        print('id==nil')
        return
    end

    local job = LActor.getJob(actor)
    local name = LActor.getName(actor)
    noticesystem.broadLoginNotice2(id, job, name)
    return true
end

--[[
* Entre na próxima etapa para limpar
* As recompensas que não foram reivindicadas deverão ser enviadas juntas por e-mail.
* config.param Associe meu ID de atividade alvo e limpe o progresso
]]
function gmCmdHandlers.testType20CvNext(actor, args)
    local id = tonumber(args[1])
    if id == nil then
        print('id==nil')
        return
    end

    clearActorValue(actor, id)
    sendCrossReset(id)

    -- Use adereços 1 vez
    gmCmdHandlers.type20UseItem(actor, {1, 1})
    local old_cv_num = getCvNum(id)
    onNewCvNum(id, old_cv_num + 1)
    assert(old_cv_num + 1 == getCvNum(id))
    assert(getPv(actor, id) == 0)
    assert(getGv(actor, id) == 0)
    assert(getCv(id) == 0)

    return true
end

function gmCmdHandlers.testType20Empty(actor, args)
    local id = tonumber(args[1])
    if id == nil then
        print('id==nil')
        return
    end

    assert(getPv(actor, id) == 0)
    assert(getGv(actor, id) == 0)
    return true
end
