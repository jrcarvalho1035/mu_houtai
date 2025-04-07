--狼魂要塞

module("langhun", package.seeall)

LANGHUN_BOSS_MAX = 3 --O número máximo de chefes na cena
LANGHUN_UPDATE_RANK_TIME = LANGHUN_UPDATE_RANK_TIME or 0 --Você precisa atualizar as classificações?(Carimbo de data e hora)
lhStatusType = {
    default = 0,
    open = 1,
    close = 2,
}

lhScoreUpdateType = 
{
    default = 0,
    belong = 1,
}

--[[
本玩法中ins包含的数据
ins.data.floor = 1  --此副本所属层数
ins.data.bossId = 1 --此副本首领id
 
--此副本首领归属信息
ins.data.belongInfo = {
    oldHandle = 0, --上任玩家master handle
    handle = 0, --玩家master handle
    actorid = 0, --玩家id
    job = 0, --玩家职业
    name = 0, --玩家名字
    endTime = 0, --获得归属的时间戳
} 
 
--此副本首领血量及复活信息
ins.data.bossInfo = {
    [id] = {
        hp = 100, --剩余血量百分比
        refreshTime = 0, --复活时间戳
    },
}
]]

local function getActorVar(actor)
    if not actor then return end
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.langhun then
        var.langhun = {
            score = 0, --Valor ilimitado da alma do lobo
            bindScore = 0, --Vincule o valor da alma do lobo
            killCount = 0, --Número de mortes por nível,
            serialKill = 0, --Número de mortes consecutivas
            serialDie = 0, --Número de mortes consecutivas
            totalKill = 0, --Número acumulado de mortes no evento
            floor = 1, --O número da camada atual, o padrão é a primeira camada
            isUpper = 0, --Registre se o jogador entra no próximo nível
        }
    end
    return var.langhun
end

--Atualizar propriedades
local function updateAttr(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Fuben)
    attrs:Reset()
    
    local serialDie = math.min(var.serialDie, #LangHunDieConfig)
    if serialDie > 0 then
        local attrsConf = LangHunDieConfig[serialDie]
        if not attrsConf then return end
        
        for _, attr in ipairs(attrsConf.attrs) do
            attrs:Set(attr.type, attr.value)
        end
    end
    LActor.reCalcAttr(actor)
end

local function getSystemVar()
    local var = System.getStaticVar()
    if not var then return end
    if not var.langhun then
        local weekTime = System.getWeekFistTime()
        local sd, sh, sm = string.match(LangHunCommonConfig.startTime, "(%d+)-(%d+):(%d+)")
        local startTime = weekTime + sd * 24 * 3600 + sh * 3600 + sm * 60
        local ed, eh, em = string.match(LangHunCommonConfig.endTime, "(%d+)-(%d+):(%d+)")
        local endTime = weekTime + ed * 24 * 3600 + eh * 3600 + em * 60
        var.langhun = {
            status = 0,
            minute = 0,
            nextTime = weekTime + sd * 24 * 3600 + 604800,
            startTime = startTime,
            endTime = endTime,
        }
    end
    return var.langhun
end

local function getSystemDynamicVar()
    local dvar = System.getDyanmicVar()
    if not dvar then return end
    if not dvar.langhun then
        dvar.langhun = {}
    end
    return dvar.langhun
end

local function reSetLHActor(actor)
    local var = LActor.getStaticVar(actor)
    var.langhun = nil
end

local function checkLHOpen()
    local data = getSystemVar()
    return data.status == lhStatusType.open
end

local function getLanghunFuben(floor)
    local floorConfig = LangHunFuBenConfig[floor]
    if not floorConfig then return end
    
    local langhunInfo = getSystemDynamicVar()
    if not langhunInfo[floor] then
        langhunInfo[floor] = {}
    end
    
    local floorInfo = langhunInfo[floor]
    local maxPeople = LangHunCommonConfig.people
    for _, hfuben in ipairs(floorInfo) do
        local ins = instancesystem.getInsByHdl(hfuben)
        if ins and ins.actor_list_count < maxPeople then
            return hfuben
        end
    end
    
    --Quando o número de pessoas estiver cheio, uma nova instância será aberta.
    local hfuben = instancesystem.createFuBen(floorConfig.fbId)
    if hfuben == 0 then return end
    local ins = instancesystem.getInsByHdl(hfuben)
    ins.data.floor = floor
    initLHFuben(ins, floorConfig)
    table.insert(floorInfo, hfuben)
    return hfuben
end

local function checkLHCondition(actor)
    local var = getActorVar(actor)
    if not var then return end
    if not LangHunFuBenConfig[var.floor + 1] then return end
    
    local condition = LangHunFuBenConfig[var.floor].condition
    if var.killCount >= condition.kill and var.bindScore + var.score >= condition.score then
        lhUpper(actor)
    end
end

--Obtenha o valor da alma do lobo
local function getActorWorlf(actor)
    if LActor.getFubenGroup(actor) ~= LangHunCommonConfig.groupId then return - 1 end
    local var = getActorVar(actor)
    if not var then return - 1 end
    if not (var.score and var.bindScore) then return - 1 end
    return var.score + var.bindScore
end

--Alterar pontos não vinculados
function changeLHScore(actor, value, sType)
    if value == 0 then return end
    
    local var = getActorVar(actor)
    if not var then return end
    
    var.score = var.score + value
    langhunrank.addLHRankScore(LActor.getActorId(actor), LActor.getServerId(actor), LActor.getName(actor), value)
    checkLHCondition(actor)
    actorevent.onEvent(actor, aeLHAddWolf, value)
    s2cLHScoreInfo(actor, value, sType)
    LActor.notifyWolfValue(actor)
    LANGHUN_UPDATE_RANK_TIME = System.getNowTime()
end

--Aumentar os pontos de ligação (reservar uma interface para aumentar diretamente os pontos de ligação, atualmente os pontos de ligação são convertidos)
function addLHBindScore(actor, value)
    if value == 0 then return end
    
    local var = getActorVar(actor)
    if not var then return end
    
    var.bindScore = var.bindScore + value
    langhunrank.addLHRankScore(LActor.getActorId(actor), LActor.getServerId(actor), LActor.getName(actor), value)
    checkLHCondition(actor)
    s2cLHScoreInfo(actor)
    --actorevent.onEvent(actor, aeNotifyFacade)
end

--Pontos vinculados de conversão não consolidados
function exchangeLHScore(actor, floor)
    local var = getActorVar(actor)
    if not var then return end
    if var.floor ~= floor then return end
    local floorConfig = LangHunFuBenConfig[floor]
    if not floorConfig then return end
    
    --Registrar o próximo cronômetro de conversão
    LActor.postScriptEventLite(actor, floorConfig.exchange.time * 1000, exchangeLHScore, floor)
    
    local bindScore = var.bindScore
    local score = var.score
    
    local addScore = math.ceil(score * floorConfig.exchange.rate / 10000) + floorConfig.exchange.score
    if addScore > score then
        addScore = score
    end
    var.score = score - addScore
    var.bindScore = bindScore + addScore
    actorevent.onEvent(actor, aeLHExchange, addScore)
    s2cLHScoreInfo(actor)
    LActor.notifyWolfValue(actor)
    --actorevent.onEvent(actor, aeNotifyFacade)
end

--Insira a cópia
function lhFight(actor)
    if not checkLHOpen() then return end
    if LActor.getFubenGroup(actor) == LangHunCommonConfig.groupId then return end
    
    local var = getActorVar(actor)
    if not var then return end
    local floor = var.floor
    
    local hfuben = getLanghunFuben(floor)
    if not hfuben then return end
    
    local config = LangHunFuBenConfig[floor]
    local x, y = utils.getSceneEnterCoor(config.fbId)
    LActor.enterFuBen(actor, hfuben, 0, x, y)
    return true
end

--Vá para o próximo nível
function lhUpper(actor)
    if not checkLHOpen() then return end
    
    local var = getActorVar(actor)
    if not var then return end
    
    local floor = var.floor + 1
    local config = LangHunFuBenConfig[floor]
    if not config then return end
    
    local hfuben = getLanghunFuben(floor)
    if not hfuben then return end
    
    var.floor = floor
    var.isUpper = 1
    local x, y = utils.getSceneEnterCoor(config.fbId)
    LActor.enterFuBen(actor, hfuben, 0, x, y)
    return true
end

function clearLHFuben()
    local langhunInfo = getSystemDynamicVar()
    for _, floorInfo in pairs(langhunInfo) do
        for __, hfuben in ipairs(floorInfo) do
            local ins = instancesystem.getInsByHdl(hfuben)
            if ins then
                ins:release()
            end
        end
    end
end

function sendLHRankMail(actorid, serverid, myrank, myscore)
    local mailData = {
        head = LangHunCommonConfig.rankMailTitle,
        context = string.format(LangHunCommonConfig.rankMailContent, myscore, myrank),
        tAwardList = {},
    }
    mailsystem.sendMailById(actorid, mailData, serverid)
end

function addLHBelongBuff(actor)
    if not actor then return end
    local role = LActor.getRole(actor)
    for _, buffId in ipairs(LangHunCommonConfig.belongBuffs) do
        LActor.addSkillEffect(role, buffId)
    end
end

function clearLHBelongBuff(actor)
    if not actor then return end
    local role = LActor.getRole(actor)
    for _, buffId in ipairs(LangHunCommonConfig.belongBuffs) do
        LActor.delSkillEffect(role, buffId)
    end
end

----------------------------------------------------------------------------------
--evento de tempo ativo
--Detectar tempo de atividade
local function checkLHTime()
    local now = System.getNowTime()
    local data = getSystemVar()
    if data.status ~= lhStatusType.open and now >= data.startTime and now < data.endTime then
        langhunStart()
    elseif data.status ~= lhStatusType.close and now >= data.endTime then
        langhunStop()
    elseif now >= data.nextTime then
        resetLanghun()
    end
end

--Redefinir dados de atividade
function resetLanghun()
    local var = System.getStaticVar()
    var.langhun = nil
    langhunrank.clearLangHunRankVar()
end

--Início do evento
function langhunStart()
    if not System.isLianFuSrv() then return end
    local data = getSystemVar()
    data.status = lhStatusType.open
    
    sendSCLanghunInfo()
    broadLanghunInfo()
    --LActor.postScriptEventLite(nil, 60000, langhunExchange)
end

--O evento termina
function langhunStop()
    if not System.isLianFuSrv() then return end
    local data = getSystemVar()
    data.status = lhStatusType.close
    
    langhunrank.sendLHRankReward()
    clearLHFuben()
    sendSCLanghunInfo()
    broadLanghunInfo()
end

--非绑转换绑定积分
-- function langhunExchange()
--     if not checkLHOpen() then return end
--     local data = getSystemVar()
--     minute = data.minute + 1
--     data.minute = minute

--     local config = LangHunExchangeConfig[minute] or LangHunExchangeConfig[#LangHunExchangeConfig]
--     local rate = config.rate

--     print("on langhunExchange minute =", minute, "rate =", rate)
--     local actors = System.getOnlineActorList()
--     if actors then
--         for i = 1, #actors do
--             local actor = actors[i]
--             if actor and LActor.getFubenGroup(actor) == LangHunCommonConfig.groupId then
--                 exchangeLHScore(actor, rate)
--             end
--         end
--     end
--     LActor.postScriptEventLite(nil, 60000, langhunExchange)
-- end

----------------------------------------------------------------------------------
--Processamento de protocolo
--Transmitir informações do evento
function broadLanghunInfo()
    local actors = System.getOnlineActorList()
    if actors then
        for i = 1, #actors do
            local actor = actors[i]
            if actor then
                s2cLanghunInfo(actor)
            end
        end
    end
end

-- Transmita informações sobre a saúde do chefe
function broadLHBossInfo(ins)
    local bossInfo = ins.data.bossInfo
    local bossId = ins.data.bossId
    
    local bInfo = bossInfo[bossId]
    if not bInfo.needUpdate then return end
    local actors = ins:getActorList()
    for _, actor in ipairs(actors) do
        local bossId = Fuben.getBossIdInArea(actor)
        if bossId == bInfo.id then
            bossinfo.notify(ins, actor, bInfo)
        end
    end
    bInfo.needUpdate = false
end

-- Informações de informações de classificação de transmissão
function broadLHRankInfo(ins)
    if LANGHUN_UPDATE_RANK_TIME < (ins.data.updateRankTime or 0) then return end
    local actors = ins:getActorList()
    for _, actor in ipairs(actors) do
        langhunrank.s2cLHRankInfo(actor)
    end
    ins.data.updateRankTime = System.getNowTime()
end

--92-14 Distribuir informações de atividades
function s2cLanghunInfo(actor)
    local data = getSystemVar()
    if not data then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sLanghunCmd_Info)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, data.status)
    LDataPack.writeInt(pack, data.startTime)
    LDataPack.writeInt(pack, data.endTime)
    LDataPack.flush(pack)
end

--92-15 Transmitir informações de cópia
function broadLHFubenInfo(ins)
    local bossInfo = ins and ins.data.bossInfo
    if not bossInfo then return end
    
    local pack = LDataPack.allocPacket()
    if pack == nil then return end
    
    LDataPack.writeByte(pack, Protocol.CMD_ZhanQu)
    LDataPack.writeByte(pack, Protocol.sLanghunCmd_FubenInfo)
    
    LDataPack.writeChar(pack, ins.data.floor)
    LDataPack.writeChar(pack, ins.data.bossCount)
    for id, info in pairs(bossInfo) do
        LDataPack.writeInt(pack, info.id)
        LDataPack.writeChar(pack, info.hpPercent)
        LDataPack.writeInt(pack, info.refreshTime)
    end
    Fuben.sendData(ins.handle, pack)
end

--92-15 Distribuir informações do copy boss
function s2cLHFubenInfo(actor, ins)
    local bossInfo = ins and ins.data.bossInfo
    if not bossInfo then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sLanghunCmd_FubenInfo)
    if pack == nil then return end
    
    LDataPack.writeChar(pack, ins.data.floor)
    LDataPack.writeChar(pack, ins.data.bossCount)
    for id, info in pairs(bossInfo) do
        LDataPack.writeInt(pack, info.id)
        LDataPack.writeChar(pack, info.hpPercent)
        LDataPack.writeInt(pack, info.refreshTime)
    end
    LDataPack.flush(pack)
end

--92-16 Solicitar entrada
local function c2sLHFight(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.langhun) then return end
    local ret = lhFight(actor)
    s2cLHFight(actor, ret)
end

--92-16 Voltar para entrar
function s2cLHFight(actor, ret)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sLanghunCmd_Fight)
    if pack == nil then return end
    LDataPack.writeChar(pack, ret and 1 or 0)
    LDataPack.flush(pack)
end

--92-17 Atualizar informações da camada
function s2cLHFloorInfo(actor)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sLanghunCmd_FloorInfo)
    if pack == nil then return end
    LDataPack.writeShort(pack, var.serialKill)
    LDataPack.writeShort(pack, var.serialDie)
    LDataPack.writeShort(pack, var.killCount)
    LDataPack.writeShort(pack, var.totalKill)
    LDataPack.flush(pack)
end

--92-18 Atualizar informações de pontos
function s2cLHScoreInfo(actor, value, sType)
    local var = getActorVar(actor)
    if not var then return end
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sLanghunCmd_UpdateScore)
    if pack == nil then return end
    LDataPack.writeInt(pack, var.score)
    LDataPack.writeInt(pack, var.bindScore)
    LDataPack.writeByte(pack, sType or lhScoreUpdateType.default)
    LDataPack.writeInt(pack, value or 0)
    LDataPack.flush(pack)
end

--92-19 informações de propriedade de transmissão
function broadLHBelongInfo(ins)
    local belongInfo = ins and ins.data.belongInfo
    if not belongInfo then return end
    local pack = LDataPack.allocPacket()
    if pack == nil then return end
    LDataPack.writeByte(pack, Protocol.CMD_ZhanQu)
    LDataPack.writeByte(pack, Protocol.sLanghunCmd_Belong)
    LDataPack.writeDouble(pack, belongInfo.oldHandle)
    LDataPack.writeDouble(pack, belongInfo.handle)
    LDataPack.writeInt(pack, belongInfo.actorid)
    LDataPack.writeByte(pack, belongInfo.job)
    LDataPack.writeString(pack, belongInfo.name)
    LDataPack.writeInt(pack, belongInfo.endTime)
    Fuben.sendData(ins.handle, pack)
end

--92-19 Distribuir informações de propriedade
function s2cLHBelongInfo(actor, ins)
    local belongInfo = ins and ins.data.belongInfo
    if not belongInfo then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sLanghunCmd_Belong)
    if not pack then return end
    
    LDataPack.writeDouble(pack, belongInfo.oldHandle)
    LDataPack.writeDouble(pack, belongInfo.handle)
    LDataPack.writeInt(pack, belongInfo.actorid)
    LDataPack.writeByte(pack, belongInfo.job)
    LDataPack.writeString(pack, belongInfo.name)
    LDataPack.writeInt(pack, belongInfo.endTime)
    LDataPack.flush(pack)
end

--92-20 Liquidação de batalha
function s2cLHResult(actorid, serverid, rank, myrank, myscore, rewards)
    local actor = LActor.getActorById(actorid)
    if myrank == 1 then
        if actor then
            actorevent.onEvent(actor, aeLHFirstRank, -1 ,1)
        else
            taskevent.transferEvent(actorid, serverid, aeLHFirstRank, -1, 1)
        end
    end
    
    if actor and LActor.getFubenGroup(actor) == LangHunCommonConfig.groupId then
        local var = getActorVar(actor)
        if not var then return end
        
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_ZhanQu, Protocol.sLanghunCmd_Result)
        if pack == nil then return end
        
        LDataPack.writeShort(pack, #rank)
        for idx, info in ipairs(rank) do
            LDataPack.writeString(pack, info.name)
            LDataPack.writeInt(pack, info.score)
        end
        
        LDataPack.writeShort(pack, myrank)
        LDataPack.writeInt(pack, myscore)
        LDataPack.writeChar(pack, var.floor)
        
        LDataPack.writeChar(pack, #rewards)
        for _, v in ipairs(rewards) do
            LDataPack.writeInt(pack, v.id)
            LDataPack.writeInt(pack, v.count)
        end
        LDataPack.flush(pack)
    end
end

----------------------------------------------------------------------------------
--Acordo entre servidores

--Sincronize dados da zona de guerra para o servidor normal
function sendSCLanghunInfo(serverid)
    if not System.isLianFuSrv() then return end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCLangHunCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCLangHunCmd_SyncInfo)
    
    local data = getSystemVar()
    LDataPack.writeChar(pack, data.status)
    LDataPack.writeInt(pack, data.startTime)
    LDataPack.writeInt(pack, data.endTime)
    System.sendPacketToAllGameClient(pack, serverid or 0)
end

--Servidor normal recebe dados de sincronização da zona de guerra
local function onSCLanghunInfo(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local data = getSystemVar()
    data.status = LDataPack.readChar(dp)
    data.startTime = LDataPack.readInt(dp)
    data.endTime = LDataPack.readInt(dp)
    broadLanghunInfo()
end

----------------------------------------------------------------------------------
--事件处理

--Inicializar evento de cópia
function initLHFuben(ins, floorConfig)
    setLHBelongInfo(ins)
    local bossId = floorConfig.bossId
    ins.data.bossId = bossId
    ins.data.bossCount = 1
    
    local refreshConfig = LangHunMonsterConfig[bossId]
    ins.data.bossInfo = {
        [bossId] = {
            id = bossId,
            hpPercent = 100,
            hp = 0,
            refreshTime = 0,--System.getNowTime() + refreshConfig.refreshTime,
        },
    }
    
    local bossInfo = ins.data.bossInfo
    for _, guardId in ipairs(floorConfig.guardIds) do
        if not bossInfo[guardId] then
            bossInfo[guardId] = {
                id = guardId,
                hpPercent = 100,
                hp = 0,
                refreshTime = 0,
            }
            ins.data.bossCount = ins.data.bossCount + 1
        end
    end
    
    for monsterId, conf in pairs(LangHunMonsterConfig) do
        --if monsterId ~= bossId and ins.data.floor == conf.floor then
        if ins.data.floor == conf.floor then
            Fuben.createMonster(ins.scene_list[1], monsterId, conf.position.x, conf.position.y, 0, 0, 0, 0, conf.score)
        end
    end
    --LActor.postScriptEventLite(nil, refreshConfig.refreshTime * 1000, refreshLHMonster, ins.handle, bossId)
end

function setLHBelongInfo(ins, belong)
    if not ins then return end
    if not ins.data.belongInfo then
        ins.data.belongInfo = {
            oldHandle = 0,
            handle = 0,
            actorid = 0,
            job = 0,
            name = "",
            endTime = 0,
        }
    end
    
    local belongInfo = ins.data.belongInfo
    local oldHandle = belongInfo.handle
    belongInfo.oldHandle = oldHandle
    
    --Se houver um novo proprietário
    if belong then
        belongInfo.handle = LActor.getHandle(belong)
        belongInfo.actorid = LActor.getActorId(belong)
        belongInfo.job = LActor.getJob(belong)
        belongInfo.name = LActor.getName(belong)
        belongInfo.endTime = System.getNowTime() + LangHunCommonConfig.belongTime
    else
        belongInfo.handle = 0
        belongInfo.actorid = 0
        belongInfo.job = 0
        belongInfo.name = ""
        belongInfo.endTime = 0
    end
    broadLHBelongInfo(ins)
end

function refreshLHMonster(_, hfuben, monsterId)
    local ins = instancesystem.getInsByHdl(hfuben)
    if not ins then return end
    if ins.is_end then return end
    
    --Depois que o líder for ressuscitado, as informações de propriedade da cópia atual serão redefinidas imediatamente.
    if monsterId == ins.data.bossId then
        setLHBelongInfo(ins)
    end
    
    local refreshConfig = LangHunMonsterConfig[monsterId]
    if not refreshConfig then return end
    Fuben.createMonster(ins.scene_list[1], monsterId, refreshConfig.position.x, refreshConfig.position.y, 0, 0, 0, 0, refreshConfig.score)
    
    local bInfo = ins.data.bossInfo[monsterId]
    if bInfo then
        bInfo.hpPercent = 100
        bInfo.refreshTime = 0
        broadLHFubenInfo(ins)
    end
end

--Lidar com eventos de eliminação
function onLHActorKill(actor)
    local var = getActorVar(actor)
    local floor = var.floor
    var.killCount = var.killCount + 1
    var.serialDie = 0
    
    local totalKill = var.totalKill + 1
    var.totalKill = totalKill
    local serialKill = var.serialKill + 1
    var.serialKill = serialKill
    
    --Ganhe pontos por sequências de mortes
    local maxSerialKill = math.min(serialKill, #LangHunKillConfig)
    local addScore = LangHunKillConfig[maxSerialKill].floorScore[floor] or 0
    --Ganhe pontos pela primeira morte
    if totalKill == 1 then
        addScore = addScore + LangHunCommonConfig.firstKillScore
        actorevent.onEvent(actor, aeLHFirstBlood, 1)
    end
    changeLHScore(actor, addScore)
    actorevent.onEvent(actor, aeLHKillActor, 1)
    actorevent.onEvent(actor, aeLHSerialKill, serialKill)
    
    local noticeId = LangHunKillConfig[serialKill] and LangHunKillConfig[serialKill].noticeId or 0
    if noticeId ~= 0 then
        noticesystem.broadCastCrossNotice(noticeId, LActor.getName(actor), serialKill)
    end
    updateAttr(actor)
    checkLHCondition(actor)
    s2cLHFloorInfo(actor)
    --actorevent.onEvent(actor, aeNotifyFacade)
end

--Lidando com mortes
function onLHActorDie(actor, kiilerName)
    local var = getActorVar(actor)
    if var.serialKill >= LangHunCommonConfig.endKillCount then
        noticesystem.broadCastCrossNotice(LangHunCommonConfig.endKillNotice, LActor.getName(actor), var.serialKill, kiilerName)
    end
    
    var.serialKill = 0
    var.serialDie = var.serialDie + 1
    updateAttr(actor)
    s2cLHFloorInfo(actor)
    --actorevent.onEvent(actor, aeNotifyFacade)
end

--A seguir está o evento de retorno de chamada de cópia
--Detecção regular
local function onTimeCheck(ins)
    local now = System.getNowTime()
    local belongInfo = ins.data.belongInfo
    if belongInfo.endTime ~= 0 then
        if now > belongInfo.endTime then
            local actor = LActor.getActorById(belongInfo.actorid)
            if actor and LActor.getFubenGroup(actor) == LangHunCommonConfig.groupId then
                local refreshConfig = LangHunMonsterConfig[ins.data.bossId]
                changeLHScore(actor, refreshConfig.score, lhScoreUpdateType.belong)
                actorevent.onEvent(actor, aeLHBelong, 1)
                clearLHBelongBuff(actor)
            end
            setLHBelongInfo(ins)
        end
        --Quando há um proprietário, as informações do proprietário são transmitidas regularmente
        broadLHBelongInfo(ins)
    end
    broadLHBossInfo(ins)
    broadLHRankInfo(ins)
end

--Jogador morre
local function onActorDie(ins, actor, killHdl)
    if ins.is_end then return end
    local et = LActor.getEntity(killHdl)
    local killer_actor = LActor.getActor(et)
    local belongInfo = ins.data.belongInfo
    
    --Aqueles que forem mortos terão pontos não vinculativos deduzidos.
    local var = getActorVar(actor)
    local addScore = math.ceil(var.score * LangHunCommonConfig.killPercent / 10000)
    changeLHScore(actor, -addScore)
    onLHActorDie(actor, LActor.getName(et))
    
    --O assassino ganha pontos por saquear
    if killer_actor then
        changeLHScore(killer_actor, addScore)
        onLHActorKill(killer_actor)
    end
    
    --Se quem é morto é o dono
    if LActor.getActorId(actor) == belongInfo.actorid then
        setLHBelongInfo(ins, killer_actor)
        --O proprietário original exclui o buff
        clearLHBelongBuff(actor)
        --Adicionar buff ao proprietário atual
        addLHBelongBuff(killer_actor)
    end
end

--副本内创建怪物
local function onMonsterCreate(ins, monster)
    if ins.is_end then return end
    local monsterId = Fuben.getMonsterId(monster)
    if monsterId == ins.data.bossId then
        local bInfo = ins.data.bossInfo[monsterId]
        bInfo.hp = LActor.getHp(monster)
        bInfo.needUpdate = true
    end
    -- local refreshConfig = LangHunMonsterConfig[monsterId]
    -- if not refreshConfig then return end
    -- Fuben.SetMonsterWorlf(monster, refreshConfig.score)
end

--副本内对怪物造成伤害
local function onMonsterDamage(ins, monster, value, attacker, res)
    local bossInfo = ins.data.bossInfo
    local monsterId = Fuben.getMonsterId(monster)
    
    local refreshConfig = LangHunMonsterConfig[monsterId]
    if not refreshConfig then return end
    
    local oldhp = LActor.getHp(monster)
    if oldhp <= 0 then return end
    
    local hp = oldhp - math.min(value, refreshConfig.maxDamage)
    if hp <= 0 then hp = 0 end
    res.ret = hp
    
    bInfo = bossInfo[monsterId]
    if bInfo then
        bInfo.hp = hp
        bInfo.hpPercent = math.ceil(hp / LActor.getHpMax(monster) * 100)
        bInfo.needUpdate = true
    end
end

--Mate monstros na cópia
local function onMonsterDie(ins, monster, killer_hdl)
    if ins.is_end then return end
    
    local bossId = ins.data.bossId
    local et = LActor.getEntity(killer_hdl)
    local killer_actor = LActor.getActor(et)
    local monsterId = Fuben.getMonsterId(monster)
    
    --Registre eventos de ressurreição com antecedência para evitar que monstros não sejam ressuscitados devido a relatórios de erros
    local refreshConfig = LangHunMonsterConfig[monsterId]
    local refreshTime = refreshConfig.refreshTime
    LActor.postScriptEventLite(nil, refreshTime * 1000, refreshLHMonster, ins.handle, monsterId)
    
    if killer_actor then
        actorevent.onEvent(killer_actor, aeLHKillMonster, refreshConfig.mType, 1)
    end
    
    if monsterId == bossId then
        setLHBelongInfo(ins, killer_actor)
        if killer_actor then
            addLHBelongBuff(killer_actor)
            noticesystem.broadCastCrossNotice(LangHunCommonConfig.killBossNotice, LActor.getName(killer_actor), utils.getMonsterName(monsterId))
        end
    else
        local value = LangHunMonsterConfig[monsterId].score
        changeLHScore(killer_actor, value)
    end
    
    local bInfo = ins.data.bossInfo[monsterId]
    if bInfo then
        bInfo.hpPercent = 0
        bInfo.refreshTime = System.getNowTime() + refreshTime
        broadLHFubenInfo(ins)
    end
end

local function onEnerBossArea(ins, actor, bossId)
    local bInfo = ins.data.bossInfo[bossId]
    if not bInfo then return end
    bossinfo.notify(ins, actor, bInfo)
end

local function onExitBossArea(ins, actor, bossId)
    bossinfo.notify(ins, actor, {id = bossId, hp = 0})
end

local function onEnterBefore(ins, actor)
    if not actor then return end
    local monIdList = {}
    for id, conf in pairs(LangHunMonsterConfig) do
        if ins.data.floor == conf.floor then
            table.insert(monIdList, id)
        end
    end
    slim.s2cMonsterConfig(actor, monIdList)
    s2cLHFubenInfo(actor, ins)
    s2cLHFloorInfo(actor)
end

local function onEnterFb(ins, actor)
    if not actor then return end
    local var = getActorVar(actor)
    var.isUpper = 0
    local floor = var.floor
    local floorConfig = LangHunFuBenConfig[floor]
    if floorConfig then
        LActor.postScriptEventLite(actor, floorConfig.exchange.time * 1000, exchangeLHScore, floor)
    end
    
    titlesystem.setTempTitle(actor, 0)
    s2cLHScoreInfo(actor)
    s2cLHBelongInfo(actor, ins)
end

local function onExitFb(ins, actor)
    if not actor then return end
    local var = getActorVar(actor)
    if var.isUpper == 0 then
        var.serialKill = 0
    end
    if var.isUpper == 1 then
        var.killCount = 0
    end
    var.serialDie = 0
    updateAttr(actor)
    
    --归属者退出副本清空归属信息
    local belongInfo = ins.data.belongInfo
    if LActor.getActorId(actor) == belongInfo.actorid then
        setLHBelongInfo(ins)
    end
    
    --离开副本删除buff
    clearLHBelongBuff(actor)
    
    --一定要放在最后,否则可能又被设置成0
    titlesystem.clearTempTitle(actor)
end

local function onOffline(ins, actor)
    LActor.exitFuben(actor)
end

local function onLogin(actor)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.langhun) then return end
    s2cLanghunInfo(actor)
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    reSetLHActor(actor)
    if not login then
        s2cLanghunInfo(actor)
    end
end

--连接跨服事件
local function onLHConnected(serverId, serverType)
    sendSCLanghunInfo(serverId)
end

----------------------------------------------------------------------------------
--初始化
local function init()
    if System.isBattleSrv() then return end
    --if System.isLianFuSrv() then return end
    
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    csbase.RegConnected(onLHConnected)
    csmsgdispatcher.Reg(CrossSrvCmd.SCLangHunCmd, CrossSrvSubCmd.SCLangHunCmd_SyncInfo, onSCLanghunInfo)
    
    if System.isCommSrv() then return end
    
    for _, conf in ipairs(LangHunFuBenConfig) do
        local fbId = conf.fbId
        insevent.regCustomFunc(fbId, onTimeCheck, "onTimeCheck")
        --insevent.registerInstanceInit(fbId, onInitFuben)
        insevent.registerInstanceMonsterCreate(fbId, onMonsterCreate)
        insevent.registerInstanceMonsterDamage(fbId, onMonsterDamage)
        insevent.registerInstanceMonsterDie(fbId, onMonsterDie)
        insevent.registerInstanceActorDie(fbId, onActorDie)
        insevent.registerInstanceEnterBefore(fbId, onEnterBefore)
        insevent.registerInstanceEnter(fbId, onEnterFb)
        insevent.registerInstanceExit(fbId, onExitFb)
        insevent.registerInstanceOffline(fbId, onOffline)
        insevent.registerInstanceEnerBossArea(conf.fbId, onEnerBossArea)
        insevent.registerInstanceExitBossArea(conf.fbId, onExitBossArea)
    end
    
    netmsgdispatcher.reg(Protocol.CMD_ZhanQu, Protocol.cLanghunCmd_Fight, c2sLHFight)
    
    engineevent.regGameStartEvent(checkLHTime)
end
table.insert(InitFnTable, init)

_G.ResetLanghun = resetLanghun
_G.LanghunStart = langhunStart
_G.LanghunStop = langhunStop
--_G.LanghunExchange = langhunExchange

_G.GetActorWorlf = getActorWorlf

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.lhfight = function (actor, args)
    if not System.isLianFuSrv() then return end
    lhFight(actor)
    return true
end

gmCmdHandlers.lhupper = function (actor, args)
    if not System.isLianFuSrv() then return end
    lhUpper(actor)
    return true
end

gmCmdHandlers.lhreset = function (actor, args)
    if System.isBattleSrv() then return end
    if System.isCommSrv() then
        SCTransferGM("lhreset", args, true)
    end
    resetLanghun()
    return true
end

gmCmdHandlers.lhstart = function (actor, args)
    if System.isBattleSrv() then return end
    if System.isCommSrv() then
        SCTransferGM("lhstart", args, true)
        return
    end
    local data = getSystemVar()
    if data.status ~= lhStatusType.open then
        langhunStart()
    end
    return true
end

gmCmdHandlers.lhstop = function (actor, args)
    if System.isBattleSrv() then return end
    if System.isCommSrv() then
        SCTransferGM("lhstop", args, true)
        return
    end
    local data = getSystemVar()
    if data.status ~= lhStatusType.close then
        langhunStop()
    end
    return true
end

-- gmCmdHandlers.lhexchange = function (actor, args)
--     local rate = (tonumber(args[1]) or 10)
--     langhunExchange(nil, rate)
--     if System.isCommSrv() then
--         SCTransferGM("lhexchange", args)
--         return
--     end
--     return true
-- end

gmCmdHandlers.lhprint = function (actor, args)
    local var = getActorVar(actor)
    print("floor =", var.floor)
    print("score =", var.score)
    print("bindScore =", var.bindScore)
    print("killCount =", var.killCount)
    print("serialKill =", var.serialKill)
    print("serialDie =", var.serialDie)
    print("totalKill =", var.totalKill)
    return true
end

gmCmdHandlers.lhfbprint = function (actor, args)
    if not System.isLianFuSrv() then return end
    print("now =", System.getNowTime())
    local fbhl = LActor.getFubenHandle(actor)
    local ins = instancesystem.getInsByHdl(fbhl)
    if ins then
        utils.printTable(ins.data)
    end
    return true
end

gmCmdHandlers.lhrefresh = function (actor, args)
    local monsterId = tonumber(args[1])
    if not monsterId then return end
    refreshLHMonster(nil, LActor.getFubenHandle(actor), monsterId)
    return true
end

gmCmdHandlers.lhaddBuff = function (actor, args)
    addLHBelongBuff(actor)
    return true
end

gmCmdHandlers.lhclearBuff = function (actor, args)
    clearLHBelongBuff(actor)
    return true
end

