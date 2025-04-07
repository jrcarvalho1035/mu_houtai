-- 合服64强赛

module("hefucupsystem", package.seeall)

local GAME_ACTOR_COUNT = 2
local MAX_ENROLL_COUNT = 64
local MAX_ROUND_COUNT = 7
local NO_RANDOM_SIZE = 4
local GROUP_SIZE = 4
local GAMEG_TOP32_GROUP = {}

local stage_Type = {
    enroll_begin = 1,
    enroll_end = 2,
    top32 = 3,
    top16 = 4,
    top8 = 5,
    top4 = 6,
    semi_final = 7,
    third_final = 8,
    champion_final = 9,
}

local status_Type = {
    start = 1,
    finish = 2,
}

local function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.hefucup then
        var.hefucup = {}
        var.hefucup.hfTime = 0 --Registre o servidor ao qual o jogador pertence
        var.hefucup.isEnroll = 0 --você se inscreveu
        var.hefucup.worshipCount = 0 --Horários de adoração
        var.hefucup.bets = {} --Número de apostas
    end
    return var.hefucup
end

local function getSystemVar()
    local var = System.getStaticHefuCupVar()
    if not var then return end
    if not var.hefucup then
        var.hefucup = {
            hfTime = 0,
            status = 0,
            stage = 0,
            round = 0,
            timeInfo = {},
            gameInfo = {},
            eventInfo = {},
            actorList = {},
            betRecord = {},
            powerRank = {},
            champion = {},
            notices = {},
        }
    end
    return var.hefucup
end

--获取报名玩家信息
local function getActorInfo(actorid, actor)
    actorid = actorid or LActor.getActorId(actor)
    if not actorid then return end
    local data = getSystemVar()
    return data.actorList[actorid]
end

--获取玩家投注信息
local function getActorBetRecord(actorid)
    local data = getSystemVar()
    return data.betRecord[actorid]
end

--获取对局信息
local function getGameInfo(idx)
    local data = getSystemVar()
    return data.gameInfo[idx]
end

--清除上届比赛数据
local function clearHFCupVar()
    local var = System.getStaticHefuCupVar()
    var.hefucup = nil
end

local function calcFightResult(gameInfo)
    local powers = {}
    local fightList = gameInfo.fightList
    for idx, fInfo in ipairs(fightList) do
        table.insert(fInfo.results, 0)
        local aInfo = getActorInfo(fInfo.actorid)
        powers[idx] = aInfo.power
    end
    local power1 = powers[1]
    local power2 = powers[2]
    
    local fInfo
    local rand = 0
    if power1 > power2 then
        if power1 > power2 * 1.05 then
            rand = 10000
        else
            rand = 7000 + math.ceil((power1 - power2) * 6 / power2 * 10000)
        end
        
        local rate = math.random(1, 10000)
        if rate <= rand then
            fInfo = fightList[1]
        else
            fInfo = fightList[2]
        end
        print("A > B: idx =", gameInfo.idx, " power1 =", power1, " power2 =", power2, " rate =", rate, "rand =", rand)
    elseif power1 == power2 then
        rand = 5000
        local rate = math.random(1, 10000)
        if rate <= rand then
            fInfo = fightList[1]
        else
            fInfo = fightList[2]
        end
        print("A = B: idx =", gameInfo.idx, " power1 =", power1, " power2 =", power2, " rate =", rate, "rand =", rand)
    else
        if power2 > power1 * 1.05 then
            rand = 10000
        else
            rand = 7000 + math.ceil((power2 - power1) * 6 / power1 * 10000)
        end
        
        local rate = math.random(1, 10000)
        if rate <= rand then
            fInfo = fightList[2]
        else
            fInfo = fightList[1]
        end
        print("A < B: idx =", gameInfo.idx, " power1 =", power1, " power2 =", power2, " rate =", rate, "rand =", rand)
    end
    fInfo.results[#fInfo.results] = 1
    fInfo.wincnt = fInfo.wincnt + 1
end

local function fightHFCup(idx)
    local gameInfo = getGameInfo(idx)
    if not gameInfo then return end
    if gameInfo.gamecnt >= gameInfo.maxcnt then return end
    local fightList = gameInfo.fightList
    local betList = gameInfo.betList
    local gamecnt = gameInfo.gamecnt + 1
    
    local actorCount = #fightList
    if actorCount == GAME_ACTOR_COUNT then
        calcFightResult(gameInfo)
    elseif actorCount == 1 then
        local fInfo = fightList[1]
        table.insert(fInfo.results, 1)
        fInfo.wincnt = fInfo.wincnt + 1
    end
    
    gameInfo.gamecnt = gamecnt
    local isFinish = gamecnt >= gameInfo.maxcnt
    if isFinish then
        for _, fInfo in ipairs(fightList) do
            local aInfo = getActorInfo(fInfo.actorid)
            if fInfo.wincnt >= gameInfo.wincnt then
                aInfo.rank = gameInfo.winRank
                onHFCupResult(fInfo.actorid, gameInfo, true)
            else
                aInfo.rank = gameInfo.loseRank
                onHFCupResult(fInfo.actorid, gameInfo, false)
            end
        end
        onHFCupFinish()
    end
    sendSCHFSyncGameInfo(idx, 0)
    
    if gameInfo.isLast == 1 then
        System.saveStaticHefuCup()
        sendSCHFSyncActorInfo()
        broadHFCupInfo()
        if isFinish then
            broadHFCupStageFinish()
        end
    end
end

local function updateHFCupStage(_, stage, isNow)
    local data = getSystemVar()
    local event = data.eventInfo[stage]
    local timeInfo = data.timeInfo
    event.updateTime = timeInfo[stage] or System.getNowTime()
    data.stage = stage
    local config = HefuCupFubenConfig[stage]
    if not config then return end
    data.round = config.round
    if stage == stage_Type.enroll_begin then --开始报名
        data.status = status_Type.start
    elseif stage == stage_Type.enroll_end then --开始分组
        local tempPowerRank = utils.table_clone(data.powerRank)
        for i = 1, NO_RANDOM_SIZE do
            local rInfo = tempPowerRank[1]
            if not rInfo then break end
            local idx = GAMEG_TOP32_GROUP[i]
            local actorid = rInfo.actorid
            local aInfo = getActorInfo(actorid)
            local gameInfo = getGameInfo(idx)
            if #gameInfo.fightList < GAME_ACTOR_COUNT and aInfo.isIn ~= 1 then
                aInfo.group = gameInfo.group
                aInfo.isIn = 1
                table.insert(gameInfo.fightList, {actorid = actorid, results = {}, wincnt = 0})
                gameInfo.betList[actorid] = {}
            end
            table.remove(tempPowerRank, 1)
            sendSCHFSyncGameInfo(idx, 0)
        end
        
        local isEmpty = false
        for count = 1, GAME_ACTOR_COUNT do
            for _, idx in ipairs(GAMEG_TOP32_GROUP) do
                if #tempPowerRank == 0 then
                    isEmpty = true
                    break
                end
                local gameInfo = getGameInfo(idx)
                if #gameInfo.fightList < count then
                    local pos = math.random(1, #tempPowerRank)
                    local actorid = tempPowerRank[pos].actorid
                    local aInfo = getActorInfo(actorid)
                    if aInfo.isIn ~= 1 then
                        aInfo.group = gameInfo.group
                        aInfo.isIn = 1
                        table.insert(gameInfo.fightList, {actorid = actorid, results = {}, wincnt = 0})
                        gameInfo.betList[actorid] = {}
                    end
                    table.remove(tempPowerRank, pos)
                end
                sendSCHFSyncGameInfo(idx, 0)
            end
            if isEmpty then break end
        end
        sendSCHFSyncActorInfo()
    end
    
    local count = config.fightGame
    local fightTime = config.fightTime
    if count > 0 then
        for idx, conf in ipairs(HefuCupStageConfig) do
            if conf.stage == stage then
                if isNow then
                    for i = 1, count do
                        fightHFCup(idx)
                    end
                else
                    LActor.postScriptEventEx(nil, 0, function() fightHFCup(idx) end, fightTime * 1000, count)
                end
            end
        end
    end
    sendSCHFSyncDataInfo()
    broadHFCupInfo()
end

local function loadHFCupTime()
    if not System.isBattleSrv() then return end
    local hfTime = hefutime.getHeFuTime()
    if not hfTime then return end
    
    local data = getSystemVar()
    if hfTime <= data.hfTime then return end
    if data.hfTime ~= 0 then
        clearHFCupVar()
        hefucuprank.clearHFCupRankVar()
        data = getSystemVar()
    end
    data.hfTime = hfTime
    
    local gameInfo = data.gameInfo
    for idx, conf in ipairs(HefuCupStageConfig) do
        local fbConfig = HefuCupFubenConfig[conf.stage]
        gameInfo[idx] = {
            idx = idx,
            gamecnt = 0,
            maxcnt = fbConfig.fightGame,
            wincnt = math.ceil(fbConfig.fightGame / 2),
            stage = conf.stage,
            group = conf.group,
            round = fbConfig.round,
            nextwin = conf.nextwin,
            nextlose = conf.nextlose,
            winRank = conf.winRank,
            loseRank = conf.loseRank,
            isLast = conf.isLast,
            fightList = {},
            betList = {},
        }
    end
    
    local timeInfo = data.timeInfo
    local eventInfo = data.eventInfo
    for stage, conf in ipairs(HefuCupSeasonConfig) do
        local d, h, m = string.match(conf.startTime, "(%d+)-(%d+):(%d+)")
        timeInfo[stage] = hfTime + d * 86400 + h * 3600 + m * 60
        eventInfo[stage] = {}
    end
    sendSCHFSyncGameInfo(0)
end

local function checkHFCupTime()
    if not System.isBattleSrv() then return end
    local data = getSystemVar()
    if data.hfTime == 0 then return end
    
    local timeInfo = data.timeInfo
    local eventInfo = data.eventInfo
    local now = System.getNowTime()
    --Se o horário atual exceder o prazo de inscrição, esta competição de pico não começará
    if (eventInfo[stage_Type.enroll_begin].updateTime or 0) < timeInfo[stage_Type.enroll_begin] and timeInfo[stage_Type.enroll_end] < now then
        return
    end
    
    for stage, conf in ipairs(HefuCupSeasonConfig) do
        local event = eventInfo[stage]
        local startTime = timeInfo[stage]
        
        local keepTime = startTime - now
        if keepTime > 0 then
            if event.eid then
                LActor.cancelScriptEvent(nil, event.eid)
                event.eid = nil
            end
            event.eid = LActor.postScriptEventLite(nil, keepTime * 1000, updateHFCupStage, stage)
        else
            if (event.updateTime or 0) < startTime then
                updateHFCupStage(nil, stage, true)
            end
        end
    end
end

--Aqui, devido a um erro, o ID do evento do timer é armazenado nos dados estáticos
--Como resultado, o cronômetro registrado por outros sistemas será cancelado por engano na próxima vez que o servidor for iniciado.
--O armazenamento de IDs de eventos em dados estáticos deve ser evitado daqui para frente
local function clearHFTimeEvent()
    if not System.isBattleSrv() then return end
    local data = getSystemVar()
    for stage, conf in ipairs(HefuCupSeasonConfig) do
        local event = data.eventInfo[stage]
        if event then
            event.eid = nil
        end
    end
end

function isHFCupOpen()
    local data = getSystemVar()
    if data.status == 0 then return false end
    return true
end

function isHFCupEnroll()
    local data = getSystemVar()
    return data.stage == stage_Type.enroll_begin
end

--Inscrição em torneios dos 64 melhores servidores combinados
function enrollCup(actor)
    if System.isCommSrv() then
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_Enroll)
        
        local actorid = LActor.getActorId(actor)
        LDataPack.writeInt(pack, actorid)
        LDataPack.writeByte(pack, LActor.getActorJob(actorid))
        LDataPack.writeDouble(pack, LActor.getActorPower(actorid))
        LDataPack.writeString(pack, LActor.getActorName(actorid))
        LDataPack.writeInt(pack, shenzhuangsystem.getActorVar(actor).choose)
        LDataPack.writeInt(pack, shenqisystem.getActorVar(actor).choose)
        LDataPack.writeInt(pack, wingsystem.getWingId(actor))
        LDataPack.writeInt(pack, getShengLingId(actor))
        LDataPack.writeInt(pack, meilinsystem.getActorVar(actor).choose)
        System.sendPacketToAllGameClient(pack, 0)
    else
        local actorid = LActor.getActorId(actor)
        local serverid = LActor.getServerId(actor)
        local actorData = {}
        actorData.job = LActor.getActorJob(actorid)
        actorData.total_power = LActor.getActorPower(actorid)
        actorData.actor_name = LActor.getActorName(actorid)
        actorData.shenzhuangchoose = shenzhuangsystem.getActorVar(actor).choose
        actorData.shenqichoose = shenqisystem.getActorVar(actor).choose
        actorData.wingchoose = wingsystem.getWingId(actor)
        actorData.shengling_id = getShengLingId(actor)
        actorData.meilinchoose = meilinsystem.getActorVar(actor).choose
        enrollByInfo(actorid, serverid, actorData)
    end
end

--A lista de finalistas para o torneio combinado dos 64 melhores servidores foi atualizada
function updatePowerRank(actorid, power)
    local data = getSystemVar()
    if data.stage >= stage_Type.enroll_end then return end
    local rank = data.powerRank
    if rank[MAX_ENROLL_COUNT] and rank[MAX_ENROLL_COUNT].power >= power then
        return
    end
    
    local isHave = false
    for idx, item in ipairs(rank) do
        if item.actorid == actorid then
            if item.power == power then return end
            item.power = power
            isHave = true
        end
    end
    
    if not isHave then
        if #rank >= MAX_ENROLL_COUNT then
            rank[MAX_ENROLL_COUNT] = {actorid = actorid, power = power}
        else
            table.insert(rank, {actorid = actorid, power = power})
        end
    end
    table.sort(rank, function (a, b) return a.power > b.power end)
end

--Gravar informações do player
function enrollByInfo(actorid, serverid, actorData)
    local data = getSystemVar()
    data.actorList[actorid] = {
        rank = 0,
        group = 0,
        actorid = actorid,
        serverid = serverid,
        job = actorData.job,
        power = actorData.total_power,
        name = actorData.actor_name,
        fightRecord = {},
        modelCache = {
            shenzhuang = actorData.shenzhuangchoose,
            shenqi = actorData.shenqichoose,
            wing = actorData.wingchoose,
            shengling = actorData.shengling_id,
            meilin = actorData.meilinchoose,
        },
    }
    updatePowerRank(actorid, actorData.total_power)
end

--投注
function hfCupBetGame(actor, index, betActorid)
    if not isHFCupOpen() then return end
    local info = getGameInfo(index)
    if not info then return end
    --if #info.fightList < GAME_ACTOR_COUNT then return end
    
    local data = getSystemVar()
    local stage = info.stage
    if data.stage >= stage then return end
    
    local config = HefuCupFubenConfig[stage]
    if not config then return end
    
    local var = getActorVar(actor)
    local count = var.bets[stage] or 0
    if count >= config.betGame then return end
    
    local betList = info.betList
    if not betList[betActorid] then return end
    
    local actorid = LActor.getActorId(actor)
    if betList[betActorid][actorid] then return end
    
    if not actoritem.checkItem(actor, NumericType_YuanBao, config.betCount) then
        return
    end
    
    actoritem.reduceItem(actor, NumericType_YuanBao, config.betCount, "hefucup bet")
    betList[betActorid][actorid] = LActor.getServerId(actor)
    local var = getActorVar(actor)
    var.bets[stage] = count + 1
    
    s2cUpdateBets(actor, index)
    s2cResBetInfo(actor, index)
    
    if System.isBattleSrv() then
        local aInfo = getActorInfo(betActorid)
        hefucuprank.setFansRankScore(aInfo.actorid, aInfo.serverid, aInfo.name, config.betCount)
        sendSCHFSyncGameInfo(index, 0)
    else
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_BetGame)
        LDataPack.writeInt(pack, actorid)
        LDataPack.writeChar(pack, index)
        LDataPack.writeInt(pack, betActorid)
        System.sendPacketToAllGameClient(pack, 0)
    end
end

--Interface externa, o front end pede para entrar em cena antes de enviar
function sendHFCupWorship(actor)
    s2cHFCupWorship(actor)
end

--Atualize regularmente o poder de combate do jogador
--Atualize todos os jogadores registrados antes do prazo de inscrição
--Após o prazo de inscrição, todos os jogadores pré-selecionados e não eliminados serão atualizados
function updateHFCup()
    if not System.isBattleSrv() then return end
    local data = getSystemVar()
    if data.status == status_Type.finish then return end
    for _, aInfo in pairs(data.actorList) do
        if data.stage == stage_Type.enroll_begin or (aInfo.isIn == 1 and aInfo.rank == 0) then
            syncHFCupActorPower(aInfo.actorid, aInfo.serverid)
        end
    end
end
_G.updateHFCup = updateHFCup

----------------------------------------------------------------------------------
--协议处理
--给在线玩家广播阶段切换
function broadHFCupInfo()
    local actors = System.getOnlineActorList()
    if actors then
        for _, actor in ipairs(actors) do
            s2cHFCupInfo(actor)
        end
    end
    
    if System.isBattleSrv() then
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_broadInfo)
        System.sendPacketToAllGameClient(pack, 0)
    end
end

--91-1 下发基础信息
function s2cHFCupInfo(actor)
    if not isHFCupOpen() then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_CupInfo)
    if pack == nil then return end
    
    local var = getActorVar(actor)
    if not var then return end
    local actorid = LActor.getActorId(actor)
    local data = getSystemVar()
    LDataPack.writeChar(pack, data.status)
    
    for stage = stage_Type.enroll_begin, stage_Type.champion_final do
        LDataPack.writeInt(pack, data.timeInfo[stage])
    end
    LDataPack.writeChar(pack, data.round)
    
    local actorList = data.actorList
    local powerRank = data.powerRank
    LDataPack.writeChar(pack, MAX_ENROLL_COUNT)
    for i = 1, MAX_ENROLL_COUNT do
        if powerRank[i] then
            local aInfo = actorList[powerRank[i].actorid]
            LDataPack.writeInt(pack, aInfo.actorid)
            LDataPack.writeChar(pack, aInfo.group)
            LDataPack.writeString(pack, aInfo.name)
            LDataPack.writeChar(pack, aInfo.job)
            LDataPack.writeDouble(pack, aInfo.power)
            LDataPack.writeChar(pack, #aInfo.fightRecord)
            for __, record in ipairs(aInfo.fightRecord) do
                LDataPack.writeChar(pack, record.iswin)
            end
        else
            LDataPack.writeInt(pack, 0)
            LDataPack.writeChar(pack, 0)
            LDataPack.writeString(pack, "")
            LDataPack.writeChar(pack, 0)
            LDataPack.writeDouble(pack, 0)
            LDataPack.writeChar(pack, 0)
        end
    end
    
    local gameInfo = data.gameInfo
    LDataPack.writeChar(pack, #gameInfo)
    for idx, gInfo in ipairs(gameInfo) do
        LDataPack.writeChar(pack, idx)
        LDataPack.writeChar(pack, gInfo.round)
        LDataPack.writeChar(pack, gInfo.group)
        
        local pos1 = LDataPack.getPosition(pack)
        LDataPack.writeChar(pack, 0)
        local isBet = 0
        for i = 1, GAME_ACTOR_COUNT do
            local aid = 0
            local fInfo = gInfo.fightList[i]
            if fInfo then
                aid = fInfo.actorid
                if gInfo.betList[aid] and gInfo.betList[aid][actorid] then
                    isBet = gInfo.betList[aid][actorid] and 1 or 0
                end
            end
            LDataPack.writeInt(pack, aid)
        end
        local pos2 = LDataPack.getPosition(pack)
        LDataPack.setPosition(pack, pos1)
        LDataPack.writeChar(pack, isBet)
        LDataPack.setPosition(pack, pos2)
    end
    LDataPack.writeChar(pack, MAX_ROUND_COUNT)
    for stage = stage_Type.top32, stage_Type.champion_final do
        LDataPack.writeChar(pack, var.bets[stage] or 0)
    end
    LDataPack.flush(pack)
end

--91-2 solicitar informações de correspondência
local function c2sReqGameInfo(actor, packet)
    local index = LDataPack.readChar(packet)
    s2cResGameInfo(actor, index)
end

--91-2 Retornar informações do jogo
function s2cResGameInfo(actor, idx)
    if not isHFCupOpen() then return end
    local gInfo = getGameInfo(idx)
    if not gInfo then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_ResGameInfo)
    if pack == nil then return end
    LDataPack.writeChar(pack, idx)
    LDataPack.writeChar(pack, GAME_ACTOR_COUNT)
    local myAid = LActor.getActorId(actor)
    for i = 1, GAME_ACTOR_COUNT do
        local fInfo = gInfo.fightList[i]
        if fInfo then
            local aInfo = getActorInfo(fInfo.actorid)
            LDataPack.writeString(pack, aInfo.name)
            LDataPack.writeDouble(pack, fInfo.power and fInfo.power or aInfo.power)
            LDataPack.writeChar(pack, gInfo.betList[fInfo.actorid][myAid] and 1 or 0)
            LDataPack.writeChar(pack, #fInfo.results)
            for __, result in ipairs(fInfo.results) do
                LDataPack.writeChar(pack, result)
            end
        else
            LDataPack.writeString(pack, "")
            LDataPack.writeDouble(pack, 0)
            LDataPack.writeChar(pack, 0)
            LDataPack.writeChar(pack, 0)
        end
    end
    LDataPack.flush(pack)
end

--91-3 请求投注信息
local function c2sReqBetInfo(actor, packet)
    local index = LDataPack.readChar(packet)
    s2cResBetInfo(actor, index)
end

--91-3 返回投注信息
function s2cResBetInfo(actor, idx)
    if not isHFCupOpen() then return end
    local info = getGameInfo(idx)
    if not info then return end
    local actorid = LActor.getActorId(actor)
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_ResBetInfo)
    if pack == nil then return end
    LDataPack.writeChar(pack, idx)
    
    local tmp = 0
    for betActorid, bInfo in pairs(info.betList) do
        if bInfo[actorid] then
            tmp = betActorid
        end
    end
    LDataPack.writeInt(pack, tmp)
    LDataPack.writeChar(pack, GAME_ACTOR_COUNT)
    for i = 1, GAME_ACTOR_COUNT do
        local fInfo = info.fightList[i]
        if fInfo then
            local betActorid = fInfo.actorid
            LDataPack.writeInt(pack, betActorid)
            local aInfo = getActorInfo(betActorid)
            LDataPack.writeString(pack, aInfo.name)
            LDataPack.writeByte(pack, aInfo.job)
            LDataPack.writeDouble(pack, aInfo.power)
        else
            LDataPack.writeInt(pack, 0)
            LDataPack.writeString(pack, "")
            LDataPack.writeByte(pack, 0)
            LDataPack.writeDouble(pack, 0)
        end
    end
    LDataPack.flush(pack)
end

--91-4 请求战力排行
local function c2sReqPowerRank(actor)
    s2cResPowerRank(actor)
end

--91-4 返回战力排行
function s2cResPowerRank(actor)
    if not isHFCupOpen() then return end
    if System.isBattleSrv() then
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_ResPowerRank)
        if pack == nil then return end
        
        local actorid = LActor.getActorId(actor)
        local info = getActorInfo(actorid)
        local myrank = 0
        local mypower = info and info.power or 0
        
        local data = getSystemVar()
        local rank = data.powerRank
        LDataPack.writeShort(pack, #rank)
        for idx, info in ipairs(rank) do
            if info.actorid == actorid then
                myrank = idx
            end
            local aInfo = getActorInfo(info.actorid)
            LDataPack.writeInt(pack, info.actorid)
            LDataPack.writeString(pack, aInfo.name)
            LDataPack.writeChar(pack, aInfo.job)
            LDataPack.writeDouble(pack, info.power)
        end
        LDataPack.writeShort(pack, myrank)
        LDataPack.writeDouble(pack, mypower)
        LDataPack.writeDouble(pack, rank[1] and rank[1].power or 0)
        LDataPack.writeDouble(pack, rank[MAX_ENROLL_COUNT] and rank[MAX_ENROLL_COUNT].power or 0)
        LDataPack.flush(pack)
    else
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_PowerRank)
        LDataPack.writeInt(pack, LActor.getActorId(actor))
        System.sendPacketToAllGameClient(pack, 0)
    end
end

--91-6 请求我的战绩
local function c2sReqMyGameInfo(actor, packet)
    s2cResMyGameInfo(actor)
end

--91-6 返回我的战绩
function s2cResMyGameInfo(actor)
    if not isHFCupOpen() then return end
    local actorid = LActor.getActorId(actor)
    local info = getActorInfo(actorid)
    if not info then return end
    local fightRecord = info.fightRecord
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_ResMyGameInfo)
    if pack == nil then return end
    LDataPack.writeChar(pack, #fightRecord)
    for _, fInfo in ipairs(fightRecord) do
        LDataPack.writeString(pack, fInfo.myName)
        LDataPack.writeString(pack, fInfo.ravilName)
        LDataPack.writeChar(pack, fInfo.idx)
        LDataPack.writeChar(pack, fInfo.round)
        LDataPack.writeChar(pack, fInfo.group)
        LDataPack.writeChar(pack, fInfo.iswin)
    end
    LDataPack.flush(pack)
end

--91-7 请求我的投注
local function c2sReqMyBetInfo(actor, packet)
    s2cResMyBetInfo(actor)
end

--91-7 返回我的投注
function s2cResMyBetInfo(actor)
    if not isHFCupOpen() then return end
    if System.isBattleSrv() then
        local actorid = LActor.getActorId(actor)
        local betRecord = getActorBetRecord(actorid)
        if not betRecord then return end
        
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_ResMyBetInfo)
        if pack == nil then return end
        LDataPack.writeChar(pack, #betRecord)
        for _, bInfo in ipairs(betRecord) do
            LDataPack.writeString(pack, bInfo.winnerName)
            LDataPack.writeString(pack, bInfo.loserName)
            LDataPack.writeString(pack, bInfo.betName)
            LDataPack.writeChar(pack, bInfo.idx)
            LDataPack.writeChar(pack, bInfo.round)
            LDataPack.writeChar(pack, bInfo.group)
            LDataPack.writeInt(pack, bInfo.betCount)
        end
        LDataPack.flush(pack)
    else
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_MyBetInfo)
        LDataPack.writeInt(pack, LActor.getActorId(actor))
        System.sendPacketToAllGameClient(pack, 0)
    end
end

--91-8 请求报名
local function c2sEnroll(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.hfcup) then return end
    if not isHFCupEnroll() then return end
    local var = getActorVar(actor)
    if var.isEnroll == 1 then return end
    var.isEnroll = 1
    enrollCup(actor)
    actoritem.addItems(actor, HefuCupCommonConfig.enrollRewards, "hefucup enroll rewards")
    s2cUpdateEnroll(actor)
end

--91-8 更新报名状态
function s2cUpdateEnroll(actor)
    local var = getActorVar(actor)
    if not var then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_UpdateEnroll)
    if pack == nil then return end
    LDataPack.writeChar(pack, var.isEnroll)
    LDataPack.flush(pack)
end

--91-9 请求投注
local function c2sBetGame(actor, packet)
    local index = LDataPack.readChar(packet)
    local betActorid = LDataPack.readInt(packet)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.hfcup) then return end
    hfCupBetGame(actor, index, betActorid)
end

--91-9 返回投注次数
function s2cUpdateBets(actor, index)
    local var = getActorVar(actor)
    local info = getGameInfo(index)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_UpdateBets)
    if pack == nil then return end
    LDataPack.writeChar(pack, index)
    LDataPack.writeChar(pack, MAX_ROUND_COUNT)
    for stage = stage_Type.top32, stage_Type.champion_final do
        LDataPack.writeChar(pack, var.bets[stage] or 0)
    end
    LDataPack.flush(pack)
end

--91-10 请求膜拜
local function c2sHFCupWorship(actor)
    if not System.isBattleSrv() then return end
    if not isHFCupOpen() then return end
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.hfcup) then return end
    local var = getActorVar(actor)
    if not var then return end
    local data = getSystemVar()
    if var.worshipCount >= HefuCupCommonConfig.worshiptimes then return end
    var.worshipCount = var.worshipCount + 1
    data.champion.count = (data.champion.count or 0) + 1
    actoritem.addItems(actor, HefuCupCommonConfig.worshipRewards, "hefucup worship rewards")
    s2cHFCupWorship(actor)
end

--91-10 返回膜拜信息
function s2cHFCupWorship(actor)
    if not isHFCupOpen() then return end
    if System.isBattleSrv() then
        local var = getActorVar(actor)
        if not var then return end
        local data = getSystemVar()
        local champion = data.champion
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_Worship)
        if pack == nil then return end
        LDataPack.writeChar(pack, var.worshipCount)
        LDataPack.writeInt(pack, champion.count or 0) --被膜拜次数
        LDataPack.writeString(pack, champion.name or "") --雕像名字
        LDataPack.writeChar(pack, champion.job or 0)--雕像职业
        LDataPack.writeInt(pack, champion.shenzhuang or 0)--雕像神装
        LDataPack.writeInt(pack, champion.shenqi or 0)--雕像神器
        LDataPack.writeInt(pack, champion.wing or 0)--雕像翅膀
        LDataPack.writeInt(pack, champion.shengling or 0)--雕像圣灵
        LDataPack.writeInt(pack, champion.meilin or 0)--雕像梅林
        LDataPack.flush(pack)
    else
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_WorshipInfo)
        LDataPack.writeInt(pack, LActor.getActorId(actor))
        System.sendPacketToAllGameClient(pack, 0)
    end
end

--91-11 玩家模型
local function c2sReqActorCache(actor, packet)
    if not isHFCupOpen() then return end
    local aid = LDataPack.readInt(packet)
    if aid == 0 then return end
    if System.isBattleSrv() then
        s2cResActorCache(actor, aid)
    else
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_ActorCache)
        
        LDataPack.writeInt(pack, LActor.getActorId(actor))
        LDataPack.writeInt(pack, aid)
        System.sendPacketToAllGameClient(pack, 0)
    end
end

--91-11 返回玩家模型
function s2cResActorCache(actor, actorid)
    if not isHFCupOpen() then return end
    local aInfo = getActorInfo(actorid)
    if not aInfo then return end
    local cache = aInfo and aInfo.modelCache or {}
    local name = aInfo and aInfo.name or ""
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_resActorCache)
    if pack == nil then return end
    LDataPack.writeInt(pack, actorid)
    LDataPack.writeString(pack, name or 0)
    LDataPack.writeChar(pack, aInfo.job or 0)
    LDataPack.writeInt(pack, cache.shenzhuang or 0)
    LDataPack.writeInt(pack, cache.shenqi or 0)
    LDataPack.writeInt(pack, cache.wing or 0)
    LDataPack.writeInt(pack, cache.shengling or 0)
    LDataPack.writeInt(pack, cache.meilin or 0)
    LDataPack.flush(pack)
end

--91-12 广播每轮比赛结束
function broadHFCupStageFinish()
    if System.isCommSrv() then
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, Protocol.CMD_HeFu)
        LDataPack.writeByte(pack, Protocol.sHFCupCmd_stageFinish)
        System.broadcastData(pack)
    else
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_broadStageFinish)
        System.sendPacketToAllGameClient(pack, 0)
    end
end

----------------------------------------------------------------------------------
--事件处理

local function onLogin(actor)
    if not isHFCupOpen() then return end
    s2cHFCupInfo(actor)
    s2cUpdateEnroll(actor)
    s2cHFCupWorship(actor)
    
    local actorid = LActor.getActorId(actor)
    if System.isBattleSrv() then
        local aInfo = getActorInfo(actorid)
        if aInfo and aInfo.rank == 1 then
            local data = getSystemVar()
            data.champion = {
                name = LActor.getActorName(actorid),
                job = LActor.getActorJob(actorid),
                shenzhuang = shenzhuangsystem.getActorVar(actor).choose,
                shenqi = shenqisystem.getActorVar(actor).choose,
                wing = wingsystem.getWingId(actor),
                shengling = getShengLingId(actor),
                meilin = meilinsystem.getActorVar(actor).choose,
            }
        end
    else
        local data = getSystemVar()
        for idx, aid in ipairs(data.notices) do
            if actorid == aid then
                local noticeId = HefuCupCommonConfig.notices[idx]
                if noticeId then
                    noticesystem.broadLoginNotice(actor, noticeId)
                end
            end
        end
    end
end

local function onNewDay(actor, login)
    local data = getSystemVar()
    if data.hfTime == 0 then return end
    local var = getActorVar(actor)
    if var.hfTime ~= data.hfTime then
        var.hfTime = data.hfTime
        var.isEnroll = 0
        var.bets = {}
    end
    var.worshipCount = 0
    if not login then
        s2cHFCupInfo(actor)
        s2cUpdateEnroll(actor)
        s2cHFCupWorship(actor)
    end
end

function onHFCupResult(actorid, gameInfo, isWin)
    local nextIdx = isWin and gameInfo.nextwin or gameInfo.nextlose
    if nextIdx ~= 0 then
        local nextInfo = getGameInfo(nextIdx)
        table.insert(nextInfo.fightList, {actorid = actorid, results = {}, wincnt = 0})
        nextInfo.betList[actorid] = {}
        sendSCHFSyncGameInfo(nextIdx, 0)
    end
    
    local fightList = gameInfo.fightList
    local myName = ""
    local ravilName = ""
    local winnerName = ""
    local loserName = ""
    local betName = ""
    for _, fInfo in ipairs(fightList) do
        local aInfo = getActorInfo(fInfo.actorid)
        if fInfo.actorid == actorid then
            fInfo.power = aInfo.power
            myName = aInfo.name
            betName = aInfo.name
            if isWin then
                winnerName = aInfo.name
            else
                loserName = aInfo.name
            end
        else
            if isWin then
                loserName = aInfo.name
            else
                winnerName = aInfo.name
            end
            ravilName = aInfo.name
        end
    end
    local record = {
        myName = myName,
        ravilName = ravilName,
        idx = gameInfo.idx,
        round = gameInfo.round,
        group = gameInfo.group,
        iswin = isWin and 1 or 0,
    }
    local aInfo = getActorInfo(actorid)
    table.insert(aInfo.fightRecord, record)
    
    local config = HefuCupFubenConfig[gameInfo.stage]
    if not config then
        print("onHFCupWin not find HefuCupFubenConfig idx =", gameInfo.idx, "stage =", gameInfo.stage)
        return
    end
    local betList = gameInfo.betList
    local context = ""
    local count = 0
    local bet = 0
    local rewards
    if isWin then
        bet = config.winBetCount - config.betCount
        count = config.winBetCount
        rewards = utils.table_clone(config.winBetRewards)
        table.insert(rewards, 1, {type = 0, id = NumericType_YuanBao, count = count})
    else
        bet = config.loseBetCount - config.betCount
        count = config.loseBetCount
        rewards = utils.table_clone(config.loseBetrewards)
        table.insert(rewards, 1, {type = 0, id = NumericType_YuanBao, count = count})
    end
    local mailData = {
        head = config.betMailTitle,
        context = isWin and config.betWinlContent or config.betLoselContent,
        tAwardList = rewards,
    }
    local data = getSystemVar()
    local betRecord = data.betRecord
    for aid, sid in pairs(betList[actorid]) do
        if not betRecord[aid] then betRecord[aid] = {} end
        local record = {
            winnerName = winnerName,
            loserName = loserName,
            betName = betName,
            idx = gameInfo.idx,
            round = gameInfo.round,
            group = gameInfo.group,
            betCount = bet
        }
        table.insert(betRecord[aid], record)
        mailsystem.sendMailById(aid, mailData, sid)
    end
    sendResultMail(actorid, ravilName, gameInfo, isWin)
    sendSCHFSyncGameInfo(gameInfo.idx, 0)
    if isWin then
        broadHFCupNotice(myName, gameInfo.group, gameInfo.stage)
    end
end

function sendResultMail(actorid, ravilName, gameInfo, isWin)
    local aInfo = getActorInfo(actorid)
    local config = HefuCupFubenConfig[gameInfo.stage]
    local mailData = {
        head = config.MailTitle,
        context = string.format(isWin and config.winMailContent or config.loseMailContent, ravilName),
        tAwardList = {},
    }
    if ravilName == "" then
        mailData.context = config.mailContent
    end
    mailsystem.sendMailById(actorid, mailData, aInfo.serverid)
end

function onHFCupFinish()
    local data = getSystemVar()
    if data.stage == stage_Type.champion_final then
        local firstAid = -1
        local firstSid = -1
        for _, aInfo in pairs(data.actorList) do
            if aInfo.rank == 1 then
                firstAid = aInfo.actorid
                firstSid = aInfo.serverid
            end
            if aInfo.isSend ~= 1 and aInfo.rank > 0 then
                local config = HefuCupRankRewardConfig[aInfo.rank]
                if config then
                    local mailData = {
                        head = config.mailTitle,
                        context = config.mailContent,
                        tAwardList = config.rewards,
                    }
                    mailsystem.sendMailById(aInfo.actorid, mailData, aInfo.serverid)
                end
                aInfo.isSend = 1
            end
        end
        if firstAid ~= -1 then
            sendSCHFCupWorshipData(firstAid, firstSid)
        end
        
        data.status = status_Type.finish
        for rank = 1, #HefuCupCommonConfig.notices do
            for _, aInfo in pairs(data.actorList) do
                if rank == aInfo.rank then
                    data.notices[rank] = aInfo.actorid
                    break
                end
            end
        end
        hefucuprank.sendfansRankReward()
        sendSCHFCupNoticeInfo()
    end
end

function broadHFCupNotice(name, group, stage)
    local noticeId
    if stage == stage_Type.top4 then
        noticeId = noticesystem.NTP.hfcup1
    elseif stage == stage_Type.semi_final then
        noticeId = noticesystem.NTP.hfcup2
    elseif stage == stage_Type.champion_final then
        noticeId = noticesystem.NTP.hfcup3
    end
    if noticeId then
        noticesystem.broadCastNotice(noticeId, name, HefuCupCommonConfig.groupNames[group])
    end
end

----------------------------------------------------------------------------------
--跨服协议

--将对局信息写入数据包
local function writePackGameInfo(pack, info)
    LDataPack.writeChar(pack, info.idx)
    LDataPack.writeChar(pack, info.stage)
    LDataPack.writeChar(pack, info.group)
    LDataPack.writeChar(pack, info.round)
    local count = #info.fightList
    LDataPack.writeChar(pack, count)
    for _, fInfo in ipairs(info.fightList) do
        LDataPack.writeInt(pack, fInfo.actorid)
        LDataPack.writeDouble(pack, fInfo.power or 0)
        LDataPack.writeChar(pack, #fInfo.results)
        for __, result in ipairs(fInfo.results) do
            LDataPack.writeChar(pack, result)
        end
    end
    LDataPack.writeChar(pack, count)
    for actorid, bInfo in pairs(info.betList) do
        LDataPack.writeInt(pack, actorid)
        local cnt = 0
        local pos = LDataPack.getPosition(pack)
        LDataPack.writeShort(pack, cnt)
        for aid, sid in pairs(bInfo) do
            LDataPack.writeInt(pack, aid)
            LDataPack.writeInt(pack, sid)
            cnt = cnt + 1
        end
        local pos2 = LDataPack.getPosition(pack)
        LDataPack.setPosition(pack, pos)
        LDataPack.writeShort(pack, cnt)
        LDataPack.setPosition(pack, pos2)
    end
end

--跨服请求雕像数据
function sendSCHFCupWorshipData(firstAid, firstSid)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_WorshipData)
    LDataPack.writeInt(pack, firstAid)
    System.sendPacketToAllGameClient(pack, firstSid)
end

--跨服收到普通服报名
local function onSCHFCupEnroll(sId, sType, dp)
    if not System.isBattleSrv() then return end
    local actorData = {}
    actorid = LDataPack.readInt(dp)
    actorData.job = LDataPack.readByte(dp)
    actorData.total_power = LDataPack.readDouble(dp)
    actorData.actor_name = LDataPack.readString(dp)
    actorData.shenzhuangchoose = LDataPack.readInt(dp)
    actorData.shenqichoose = LDataPack.readInt(dp)
    actorData.wingchoose = LDataPack.readInt(dp)
    actorData.shengling_id = LDataPack.readInt(dp)
    actorData.meilinchoose = LDataPack.readInt(dp)
    
    enrollByInfo(actorid, sId, actorData)
end

--跨服收到普通服投注
local function onSCHFCupBetGame(sId, sType, dp)
    if not System.isBattleSrv() then return end
    local actorid = LDataPack.readInt(dp)
    local idx = LDataPack.readChar(dp)
    local betActorid = LDataPack.readInt(dp)
    
    local gameInfo = getGameInfo(idx)
    gameInfo.betList[betActorid][actorid] = sId
    local aInfo = getActorInfo(betActorid)
    local count = HefuCupFubenConfig[gameInfo.stage].betCount
    hefucuprank.setFansRankScore(aInfo.actorid, aInfo.serverid, aInfo.name, count)
end

--跨服收到普通服的雕像信息
local function onSCHFCupWorshipData(sId, sType, dp)
    if System.isCommSrv() then
        local actorid = LDataPack.readInt(dp)
        local actor = LActor.getActorById(actorid)
        if actor then--先暴力处理
            offlinedatamgr.CallEhLogout(actor) --保存离线数据
        end
        local actorData = offlinedatamgr.GetDataByOffLineDataType(actorid, offlinedatamgr.EOffLineDataType.EBasic)
        if not actorData == nil then return end
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_WorshipData)
        
        LDataPack.writeString(pack, actorData.actor_name)
        LDataPack.writeChar(pack, actorData.job)
        LDataPack.writeInt(pack, actorData.shenzhuangchoose)
        LDataPack.writeInt(pack, actorData.shenqichoose)
        LDataPack.writeInt(pack, actorData.wingchoose)
        LDataPack.writeInt(pack, actorData.shengling_id)
        LDataPack.writeInt(pack, actorData.meilinchoose)
        System.sendPacketToAllGameClient(pack, 0)
    else
        local data = getSystemVar()
        data.champion = {
            name = LDataPack.readString(dp),
            job = LDataPack.readChar(dp),
            shenzhuang = LDataPack.readInt(dp),
            shenqi = LDataPack.readInt(dp),
            wing = LDataPack.readInt(dp),
            shengling = LDataPack.readInt(dp),
            meilin = LDataPack.readInt(dp),
        }
    end
end

--普通服收到跨服战力排行
local function onSCHFCupPowerRank(sId, sType, dp)
    if System.isBattleSrv() then
        local actorid = LDataPack.readInt(dp)
        local info = getActorInfo(actorid)
        local myrank = 0
        local mypower = info and info.power or 0
        local data = getSystemVar()
        local rank = data.powerRank
        
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_PowerRank)
        
        LDataPack.writeInt(pack, actorid)
        LDataPack.writeShort(pack, #rank)
        for idx, info in ipairs(rank) do
            if info.actorid == actorid then
                myrank = idx
            end
            local aInfo = getActorInfo(info.actorid)
            LDataPack.writeInt(pack, info.actorid)
            LDataPack.writeString(pack, aInfo.name)
            LDataPack.writeChar(pack, aInfo.job)
            LDataPack.writeDouble(pack, info.power)
        end
        LDataPack.writeShort(pack, myrank)
        LDataPack.writeDouble(pack, mypower)
        LDataPack.writeDouble(pack, rank[1] and rank[1].power or 0)
        LDataPack.writeDouble(pack, rank[MAX_ENROLL_COUNT] and rank[MAX_ENROLL_COUNT].power or 0)
        System.sendPacketToAllGameClient(pack, sId)
    else
        local actorid = LDataPack.readInt(dp)
        local actor = LActor.getActorById(actorid)
        if not actor then return end
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_ResPowerRank)
        if pack == nil then return end
        
        local count = LDataPack.readShort(dp)
        LDataPack.writeShort(pack, count)
        for i = 1, count do
            LDataPack.writeInt(pack, LDataPack.readInt(dp))
            LDataPack.writeString(pack, LDataPack.readString(dp))
            LDataPack.writeChar(pack, LDataPack.readChar(dp))
            LDataPack.writeDouble(pack, LDataPack.readDouble(dp))
        end
        LDataPack.writeShort(pack, LDataPack.readShort(dp))
        LDataPack.writeDouble(pack, LDataPack.readDouble(dp))
        LDataPack.writeDouble(pack, LDataPack.readDouble(dp))
        LDataPack.writeDouble(pack, LDataPack.readDouble(dp))
        LDataPack.flush(pack)
    end
end

--普通服收到跨服我的投注信息
local function onSCHFCupMyBetInfo(sId, sType, dp)
    if System.isBattleSrv() then
        local actorid = LDataPack.readInt(dp)
        local betRecord = getActorBetRecord(actorid)
        if not betRecord then return end
        
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_MyBetInfo)
        
        LDataPack.writeInt(pack, actorid)
        LDataPack.writeChar(pack, #betRecord)
        for _, bInfo in ipairs(betRecord) do
            LDataPack.writeString(pack, bInfo.winnerName)
            LDataPack.writeString(pack, bInfo.loserName)
            LDataPack.writeString(pack, bInfo.betName)
            LDataPack.writeChar(pack, bInfo.idx)
            LDataPack.writeChar(pack, bInfo.round)
            LDataPack.writeChar(pack, bInfo.group)
            LDataPack.writeInt(pack, bInfo.betCount)
        end
        System.sendPacketToAllGameClient(pack, sId)
    else
        local actorid = LDataPack.readInt(dp)
        local actor = LActor.getActorById(actorid)
        if not actor then return end
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_ResMyBetInfo)
        if pack == nil then return end
        
        local count = LDataPack.readChar(dp)
        LDataPack.writeChar(pack, count)
        for i = 1, count do
            LDataPack.writeString(pack, LDataPack.readString(dp))
            LDataPack.writeString(pack, LDataPack.readString(dp))
            LDataPack.writeString(pack, LDataPack.readString(dp))
            LDataPack.writeChar(pack, LDataPack.readChar(dp))
            LDataPack.writeChar(pack, LDataPack.readChar(dp))
            LDataPack.writeChar(pack, LDataPack.readChar(dp))
            LDataPack.writeInt(pack, LDataPack.readInt(dp))
        end
        LDataPack.flush(pack)
    end
end

--普通服收到跨服雕像信息
local function onSCHFCupWorshipInfo(sId, sType, dp)
    if System.isBattleSrv() then
        local actorid = LDataPack.readInt(dp)
        local data = getSystemVar()
        local champion = data.champion
        
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_WorshipInfo)
        
        LDataPack.writeInt(pack, actorid)
        LDataPack.writeInt(pack, champion.count or 0) --被膜拜次数
        LDataPack.writeString(pack, champion.name or "") --雕像名字
        LDataPack.writeChar(pack, champion.job or 0)--雕像职业
        LDataPack.writeInt(pack, champion.shenzhuang or 0)--雕像神装
        LDataPack.writeInt(pack, champion.shenqi or 0)--雕像神器
        LDataPack.writeInt(pack, champion.wing or 0)--雕像翅膀
        LDataPack.writeInt(pack, champion.shengling or 0)--雕像圣灵
        LDataPack.writeInt(pack, champion.meilin or 0)--雕像梅林
        System.sendPacketToAllGameClient(pack, sId)
    else
        local actorid = LDataPack.readInt(dp)
        local actor = LActor.getActorById(actorid)
        if not actor then return end
        local var = getActorVar(actor)
        if not var then return end
        
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_Worship)
        if pack == nil then return end
        
        LDataPack.writeChar(pack, var.worshipCount)
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.writeString(pack, LDataPack.readString(dp))
        LDataPack.writeChar(pack, LDataPack.readChar(dp))
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.flush(pack)
    end
end

--普通服收到跨服公告信息
function sendSCHFCupNoticeInfo(serverid)
    if not System.isBattleSrv() then return end
    local data = getSystemVar()
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_NoticeInfo)
    
    LDataPack.writeChar(pack, #data.notices)
    for _, actorid in ipairs(data.notices) do
        LDataPack.writeInt(pack, actorid)
    end
    System.sendPacketToAllGameClient(pack, serverid or 0)
end

--普通服收到跨服公告信息
local function onSCHFCupNoticeInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local data = getSystemVar()
    data.notices = {}
    local count = LDataPack.readChar(dp)
    for i = 1, count do
        data.notices[i] = LDataPack.readInt(dp)
    end
end

--跨服给普通服同步对局信息
function sendSCHFSyncGameInfo(idx, serverid)
    if not System.isBattleSrv() then return end
    local data = getSystemVar()
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_SyncGameInfo)
    
    if idx == 0 then --同步所有对局
        local data = getSystemVar()
        LDataPack.writeChar(pack, #data.gameInfo)
        for _, gInfo in ipairs(data.gameInfo) do
            writePackGameInfo(pack, gInfo)
        end
    else
        local gameInfo = getGameInfo(idx)
        if not gameInfo then return end
        LDataPack.writeChar(pack, 1)
        writePackGameInfo(pack, gameInfo)
    end
    System.sendPacketToAllGameClient(pack, serverid or 0)
end

--普通服收到跨服同步对局信息
local function onSCHFCupSyncGameInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local data = getSystemVar()
    local gameInfo = data.gameInfo
    
    local count = LDataPack.readChar(dp)
    for i = 1, count do
        local idx = LDataPack.readChar(dp)
        gameInfo[idx] = {
            stage = LDataPack.readChar(dp),
            group = LDataPack.readChar(dp),
            round = LDataPack.readChar(dp),
            fightList = {},
            betList = {},
        }
        local count = LDataPack.readChar(dp)
        for i = 1, count do
            local fInfo = {}
            fInfo.actorid = LDataPack.readInt(dp)
            local power = LDataPack.readDouble(dp)
            if power > 0 then
                fInfo.power = power
            end
            fInfo.results = {}
            local cnt = LDataPack.readChar(dp)
            for i = 1, cnt do
                fInfo.results[i] = LDataPack.readChar(dp)
            end
            table.insert(gameInfo[idx].fightList, fInfo)
        end
        
        count = LDataPack.readChar(dp)
        local bInfo = gameInfo[idx].betList
        for i = 1, count do
            local actorid = LDataPack.readInt(dp)
            bInfo[actorid] = {}
            
            local cnt = LDataPack.readShort(dp)
            for i = 1, cnt do
                local aid = LDataPack.readInt(dp)
                local sid = LDataPack.readInt(dp)
                bInfo[actorid][aid] = sid
            end
        end
    end
end

--跨服给普通服同步赛季信息
function sendSCHFSyncDataInfo(serverid)
    if not System.isBattleSrv() then return end
    local data = getSystemVar()
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_SyncDataInfo)
    
    LDataPack.writeInt(pack, data.hfTime)
    LDataPack.writeChar(pack, data.status)
    LDataPack.writeChar(pack, data.stage)
    LDataPack.writeChar(pack, data.round)
    
    for stage = stage_Type.enroll_begin, stage_Type.champion_final do
        LDataPack.writeInt(pack, data.timeInfo[stage] or 0)
    end
    System.sendPacketToAllGameClient(pack, serverid or 0)
end

--普通服收到跨服同步赛季信息
local function onSCHFCupSyncDataInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local data = getSystemVar()
    data.hfTime = LDataPack.readInt(dp)
    data.status = LDataPack.readChar(dp)
    data.stage = LDataPack.readChar(dp)
    data.round = LDataPack.readChar(dp)
    
    for stage = stage_Type.enroll_begin, stage_Type.champion_final do
        data.timeInfo[stage] = LDataPack.readInt(dp)
    end
    broadHFCupInfo()
end

--跨服给普通服同步比赛玩家信息
function sendSCHFSyncActorInfo(serverid)
    if not System.isBattleSrv() then return end
    local data = getSystemVar()
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_SyncActorInfo)
    
    local actorList = data.actorList
    local powerRank = data.powerRank
    local count = #powerRank
    LDataPack.writeChar(pack, #powerRank)
    for _, rank in ipairs(powerRank) do
        local actorid = rank.actorid
        LDataPack.writeInt(pack, actorid)
        LDataPack.writeDouble(pack, rank.power)
        local aInfo = getActorInfo(actorid)
        LDataPack.writeChar(pack, aInfo.rank)
        LDataPack.writeChar(pack, aInfo.group)
        LDataPack.writeInt(pack, aInfo.actorid)
        LDataPack.writeInt(pack, aInfo.serverid)
        LDataPack.writeChar(pack, aInfo.job)
        LDataPack.writeDouble(pack, aInfo.power)
        LDataPack.writeString(pack, aInfo.name)
        LDataPack.writeChar(pack, #aInfo.fightRecord)
        for _, fInfo in ipairs(aInfo.fightRecord) do
            LDataPack.writeString(pack, fInfo.myName)
            LDataPack.writeString(pack, fInfo.ravilName)
            LDataPack.writeChar(pack, fInfo.idx)
            LDataPack.writeChar(pack, fInfo.round)
            LDataPack.writeChar(pack, fInfo.group)
            LDataPack.writeChar(pack, fInfo.iswin)
        end
    end
    System.sendPacketToAllGameClient(pack, serverid or 0)
end

--普通服收到跨服同步比赛玩家信息
local function onSCHFCupSyncActorInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local data = getSystemVar()
    local actorList = data.actorList
    local powerRank = data.powerRank
    
    local count = LDataPack.readChar(dp)
    for i = 1, count do
        local actorid = LDataPack.readInt(dp)
        powerRank[i] = {
            actorid = actorid,
            power = LDataPack.readDouble(dp),
        }
        actorList[actorid] = {
            rank = LDataPack.readChar(dp),
            group = LDataPack.readChar(dp),
            actorid = LDataPack.readInt(dp),
            serverid = LDataPack.readInt(dp),
            job = LDataPack.readChar(dp),
            power = LDataPack.readDouble(dp),
            name = LDataPack.readString(dp),
            fightRecord = {},
        }
        local cnt = LDataPack.readChar(dp)
        for i = 1, cnt do
            local record = {
                myName = LDataPack.readString(dp),
                ravilName = LDataPack.readString(dp),
                idx = LDataPack.readChar(dp),
                round = LDataPack.readChar(dp),
                group = LDataPack.readChar(dp),
                iswin = LDataPack.readChar(dp),
            }
            table.insert(actorList[actorid].fightRecord, record)
        end
    end
end

--普通服收到跨服比赛玩家模型
local function onSCHFCupActorCache(sId, sType, dp)
    if System.isBattleSrv() then
        local actorid = LDataPack.readInt(dp)
        local aid = LDataPack.readInt(dp)
        local aInfo = getActorInfo(aid)
        if not aInfo then return end
        local cache = aInfo and aInfo.modelCache or {}
        local name = aInfo and aInfo.name or ""
        
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_ActorCache)
        
        LDataPack.writeInt(pack, actorid)
        LDataPack.writeInt(pack, aid)
        LDataPack.writeString(pack, name or 0)
        LDataPack.writeChar(pack, aInfo.job or 0)
        LDataPack.writeInt(pack, cache.shenzhuang or 0)
        LDataPack.writeInt(pack, cache.shenqi or 0)
        LDataPack.writeInt(pack, cache.wing or 0)
        LDataPack.writeInt(pack, cache.shengling or 0)
        LDataPack.writeInt(pack, cache.meilin or 0)
        System.sendPacketToAllGameClient(pack, sId)
    else
        local actorid = LDataPack.readInt(dp)
        local actor = LActor.getActorById(actorid)
        if not actor then return end
        
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_HeFu, Protocol.sHFCupCmd_resActorCache)
        if pack == nil then return end
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.writeString(pack, LDataPack.readString(dp))
        LDataPack.writeChar(pack, LDataPack.readChar(dp))
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.writeInt(pack, LDataPack.readInt(dp))
        LDataPack.flush(pack)
    end
end

--跨服请求普通服玩家的战斗力
function syncHFCupActorPower(actorid, serverId)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_SyncActorPower)
    
    LDataPack.writeInt(pack, actorid)
    LDataPack.writeInt(pack, serverId)
    System.sendPacketToAllGameClient(pack, serverId)
end

--普通服收到跨服同步比赛玩家信息
local function onSyncHFCupActorPower(sId, sType, dp)
    if System.isCommSrv() then
        local actorid = LDataPack.readInt(dp)
        local actor = LActor.getActorById(actorid)
        if actor then
            local pack = LDataPack.allocPacket()
            LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
            LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_SyncActorPower)
            
            LDataPack.writeInt(pack, actorid)
            LDataPack.writeDouble(pack, LActor.getActorPower(actorid))
            System.sendPacketToAllGameClient(pack, 0)
        else
            local actorData = offlinedatamgr.GetDataByOffLineDataType(actorid, offlinedatamgr.EOffLineDataType.EBasic)
            if not actorData then return end
            local pack = LDataPack.allocPacket()
            LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
            LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_SyncActorPower)
            
            LDataPack.writeInt(pack, actorid)
            LDataPack.writeDouble(pack, actorData.total_power)
            System.sendPacketToAllGameClient(pack, 0)
        end
    else
        local actorid = LDataPack.readInt(dp)
        local power = LDataPack.readDouble(dp)
        
        local aInfo = getActorInfo(actorid)
        if not aInfo then return end
        aInfo.power = power
        updatePowerRank(actorid, power)
        sendSCUpdateActorPower(actorid, power)
    end
end

--普通服收到跨服切换阶段
local function onBroadInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    broadHFCupInfo()
end

--普通服收到跨服切换阶段
local function onBroadStageFinish(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    broadHFCupStageFinish()
end

--跨服通知普通服更新战斗力
function sendSCUpdateActorPower(actorid, power)
    if not System.isBattleSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCHeFu)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCHFCupCmd_UpdateActorPower)
    
    LDataPack.writeInt(pack, actorid)
    LDataPack.writeDouble(pack, power)
    System.sendPacketToAllGameClient(pack, 0)
end

--普通服收到跨服更新战斗力
local function onUpdateActorPower(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local actorid = LDataPack.readInt(dp)
    local power = LDataPack.readDouble(dp)
    local aInfo = getActorInfo(actorid)
    if not aInfo then return end
    aInfo.power = power
end

--跨服连接事件
local function onHFCupConnected(serverId, serverType)
    if not System.isBattleSrv() then return end
    sendSCHFSyncDataInfo(serverId)
    sendSCHFSyncActorInfo(serverId)
    sendSCHFSyncGameInfo(0, serverId)
    sendSCHFCupNoticeInfo(serverId)
end

----------------------------------------------------------------------------------
--inicialização
local function init()
    --if System.isCommSrv() then return end
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
    
    for idx, conf in ipairs(HefuCupStageConfig) do
        if conf.stage == stage_Type.top32 then
            table.insert(GAMEG_TOP32_GROUP, idx)
        end
    end
    table.sort(GAMEG_TOP32_GROUP, function (a, b) return HefuCupStageConfig[a].priority < HefuCupStageConfig[b].priority end)
    
    loadHFCupTime()
    checkHFCupTime()
    
    engineevent.regGameStopEvent(clearHFTimeEvent)
    actorevent.reg(aeNewDayArrive, onNewDay)
    actorevent.reg(aeUserLogin, onLogin)
    
    csbase.RegConnected(onHFCupConnected)
    
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_Enroll, onSCHFCupEnroll)
    --csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_Worship, onSCHFCupWorship)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_BetGame, onSCHFCupBetGame)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_WorshipData, onSCHFCupWorshipData)
    
    -- csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_Info, onSCHFCupInfo)
    -- csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_GameInfo, onSCHFCupGameInfo)
    -- csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_BetInfo, onSCHFCupBetInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_PowerRank, onSCHFCupPowerRank)
    -- csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_MyGameInfo, onSCHFCupMyGameInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_MyBetInfo, onSCHFCupMyBetInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_WorshipInfo, onSCHFCupWorshipInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_NoticeInfo, onSCHFCupNoticeInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_SyncGameInfo, onSCHFCupSyncGameInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_SyncDataInfo, onSCHFCupSyncDataInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_SyncActorInfo, onSCHFCupSyncActorInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_ActorCache, onSCHFCupActorCache)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_SyncActorPower, onSyncHFCupActorPower)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_broadInfo, onBroadInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_broadStageFinish, onBroadStageFinish)
    csmsgdispatcher.Reg(CrossSrvCmd.SCHeFu, CrossSrvSubCmd.SCHFCupCmd_UpdateActorPower, onUpdateActorPower)
    
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cHFCupCmd_ReqGameInfo, c2sReqGameInfo)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cHFCupCmd_ReqBetInfo, c2sReqBetInfo)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cHFCupCmd_ReqPowerRank, c2sReqPowerRank)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cHFCupCmd_ReqMyGameInfo, c2sReqMyGameInfo)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cHFCupCmd_ReqMyBetInfo, c2sReqMyBetInfo)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cHFCupCmd_Enroll, c2sEnroll)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cHFCupCmd_BetGame, c2sBetGame)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cHFCupCmd_Worship, c2sHFCupWorship)
    netmsgdispatcher.reg(Protocol.CMD_HeFu, Protocol.cHFCupCmd_reqActorCache, c2sReqActorCache)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
function gmHFCupUpdate(stage)
    local data = getSystemVar()
    if stage > data.stage then
        print("stage err stage =", stage, "data.stage =", data.stage)
    end
    updateHFCupStage(nil, stage, true)
end

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.hfcup = function (actor, args)
    if System.isCommSrv() then
        SCTransferGM("hfcup", args)
    else
        local stage = tonumber(args[1])
        updateHFCupStage(nil, stage)
    end
end

gmCmdHandlers.hfgameInfo = function (actor, args)
    local index = tonumber(args[1]) or 0
    print("index = ", index)
    if index > 0 then
        local info = getGameInfo(index)
        print("====index====")
        utils.printTable(info)
        print("==================")
    else
        local data = getSystemVar()
        print("====hfgameInfo====")
        utils.printTable(data)
        print("==================")
    end
end

gmCmdHandlers.hfcupClear = function (actor, args)
    local var = System.getStaticHefuCupVar()
    var.hefucup = nil
end

gmCmdHandlers.hfcupEnroll = function (actor, args)
    c2sEnroll(actor)
end

gmCmdHandlers.hfcupAllEnroll = function (actor, args)
    local actors = System.getOnlineActorList()
    if actors then
        for _, actor in ipairs(actors) do
            c2sEnroll(actor)
        end
    end
end

gmCmdHandlers.gamegroup = function (actor, args)
    print("====GAMEGROUP====")
    utils.printTable(GAMEG_TOP32_GROUP)
    print("==================")
end

gmCmdHandlers.gmHFCup91_4 = function (actor, args)
    c2sReqPowerRank(actor)
end

gmCmdHandlers.gmHFCup91_3 = function (actor, args)
    local idx = tonumber(args[1]) or 0
    s2cResBetInfo(actor, idx)
end

gmCmdHandlers.clearHFcupActorVar = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.hefucup = nil
    s2cHFCupInfo(actor)
    s2cUpdateEnroll(actor)
    s2cHFCupWorship(actor)
end
