--魔物围城
module("monstersiege", package.seeall)

MonsterSiege_Status = MonsterSiege_Status or 0

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.monstersiege then
        var.monstersiege = {
            challengetime = 0, --挑战次数
            challengerefresh = 0, --挑战刷新次数
            scorestatus = 0,--积分奖励是否领取
            score = 0, --我的积分
            msid = 0, --进入的怪物id
            recordcount = 0, --记录个数
            record = {}, --记录
            refresh_week_time = 0,
        }
    end

    return var.monstersiege
end

function getGlobalData()
    local data = System.getStaticVar()
	if not data then return end
	if not data.monstersiege then 
		data.monstersiege = {
            rank = {},
            monsters = {},
            job = 0,
            shenzhuang = 0,
            shenqi = 0,
            wing = 0,
            shengling = 0,
            meilin = 0,
        }
	end
	return data.monstersiege
end

function isDouble()
    local week = System.getDayOfWeek()
    for i=1, #MSCommonConfig.scoredouble do
        if MSCommonConfig.scoredouble[i] == week then
            return 2
        end
    end
    return 1
end

function sendInfo(actor)
    local var = getActorVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_Info)
    if not npack then return end
    LDataPack.writeChar(npack, MonsterSiege_Status)
    LDataPack.writeChar(npack, isDouble())
    LDataPack.writeChar(npack, var.challengetime)
    LDataPack.writeInt(npack, math.max(0, MSCommonConfig.recovertimes - (System.getNowTime() - var.challengerefresh)))
    LDataPack.writeInt(npack, var.scorestatus)
    LDataPack.writeChar(npack, var.recordcount)
    for i=1, var.recordcount do
        LDataPack.writeChar(npack, var.record[i].id)
        LDataPack.writeInt(npack, var.record[i].endtime)
        LDataPack.writeDouble(npack, var.record[i].hurt)
    end
    LDataPack.flush(npack)
end

local function reqInfo(actor, pack)
    sendInfo(actor)
end

local function reqRank(actor, pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCMonsterSiege)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCMSCmd_ReqRankInfo)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

local function onReqRank(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local data = getGlobalData()
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCMonsterSiege)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCMSCmd_SendRankInfo)
    LDataPack.writeInt(npack, actorid)
    local count = math.min(#data.rank, #MSRankConfig)
    LDataPack.writeShort(npack, count)
    local myRank = 0
    for k,v in ipairs(data.rank) do
        if v.actorid == actorid then
            myRank = k
        end
        if k <= count then
            LDataPack.writeString(npack, v.name)
            LDataPack.writeInt(npack, v.score)
        end
    end
    LDataPack.writeShort(npack, myRank)
    LDataPack.writeChar(npack, data.job)
    LDataPack.writeInt(npack, data.shenzhuang)
    LDataPack.writeInt(npack, data.shenqi)
    LDataPack.writeInt(npack, data.wing)
    LDataPack.writeInt(npack, data.shengling)
    LDataPack.writeInt(npack, data.meilin)
    System.sendPacketToAllGameClient(npack, sId)
end

local function onSendRank(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end
    local var = getActorVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_RankInfo)
    if not npack then return end
    local count = LDataPack.readShort(cpack)
    LDataPack.writeShort(npack, count)
    for i=1, count do
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    end
    LDataPack.writeShort(npack, LDataPack.readShort(cpack))
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.flush(npack)
end

local function reqOneMonster(actor, pack)
    local id = LDataPack.readChar(pack)
    if not MSMonsterConfig[id] then
        return
    end

    local data = getGlobalData()
    if not data.monsters[id] then
        return
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_SendOneMonster)
    if not npack then return end    
    LDataPack.writeChar(npack, id)
    LDataPack.writeChar(npack, data.monsters[id].remaintimes or MSCommonConfig.monstertimes)
    LDataPack.writeInt(npack, math.max(0, MSCommonConfig.refreshtime - (System.getNowTime() - (data.monsters[id].dietime or 0))))
    if data.monsters[id].hurtrank then
        LDataPack.writeChar(npack, #data.monsters[id].hurtrank)
        for k,v in ipairs(data.monsters[id].hurtrank) do
            LDataPack.writeInt(npack, v.actorid)
            LDataPack.writeString(npack, v.name)
            LDataPack.writeDouble(npack, v.hurt)
        end
    else
        LDataPack.writeChar(npack, 0)
    end
    LDataPack.flush(npack)
end

local function fBGetScoreReward(actor, pack)
    local index = LDataPack.readChar(pack)
    local ins = instancesystem.getActorIns(actor)
    if not ins.data.msid then return end
    local conf = MSDabiaoConfig[MSMonsterConfig[ins.data.msid].monsterid]
    if not conf then return end
    conf = conf[index]
    if not conf then return end
    if System.bitOPMask(ins.data.status, index) then return end

    if ins.data.hurt < conf.hurt then return end
    
    ins.data.status = System.bitOpSetMask(ins.data.status, index, true)
    actoritem.addItems(actor, conf.reward, "monstersiege fbreward")

    ins.data.msrewards = ins.data.msrewards or {}
    table.insert(ins.data.msrewards, conf.reward[1])
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_FBScoreStatus)
    if not npack then return end    
    LDataPack.writeInt(npack, ins.data.status)
    LDataPack.flush(npack)
end

local function getScoreReward(actor, pack)
    local index = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    local conf = MSScoreConfig[index]
    if not conf then return end

    if System.bitOPMask(var.scorestatus, index) then return end
    if not actoritem.checkItem(actor, NumericType_SiegeScore, conf.score)  then return end
    
    var.scorestatus = System.bitOpSetMask(var.scorestatus, index, true)
    actoritem.addItems(actor, conf.reward, "monstersiege dabiao")

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_ScoreStatus)
    if not npack then return end    
    LDataPack.writeInt(npack, var.scorestatus)
    LDataPack.flush(npack)
end

--怪物刷新

function rebornMonster(_, id)
    if MonsterSiege_Status == 0 then return end
    local data = getGlobalData()
    data.monsters[id].dietime = 0
    data.monsters[id].calctime = 0
    data.monsters[id].remaintimes = MSCommonConfig.monstertimes
    data.monsters[id].hurtrank = {}
    data.monsters[id].isdie = false
    updateMonsterInfo(data, id)
end

--伤害排名发放
function calcHurtRank(_, id, isend)
    if MonsterSiege_Status == 0 then return end
    local data = getGlobalData()
    if data.monsters[id].dietime and data.monsters[id].dietime ~= 0 then return end    
    local mutli = isDouble()
    
    for k,v in ipairs(data.monsters[id].hurtrank) do
        local conf = MSHurtRankConfig[MSMonsterConfig[id].monsterid][k]
        if conf then
            local rewards = {}
            for kk,vv in ipairs(conf.reward) do
                table.insert(rewards, {type = vv.type, id = vv.id, count = vv.count})
            end
            for kk,vv in ipairs(conf.doubleReward) do
                table.insert(rewards, {type = vv.type, id = vv.id, count = vv.count * mutli})
            end
            local str = string.format(MSCommonConfig.hurtrankcontext, MSMonsterConfig[id].monsterName, MSMonsterConfig[id].monstrColor, k)
            local mailData = {head = MSCommonConfig.hurtrankhead, context = str, tAwardList= rewards}
            mailsystem.sendMailById(v.actorid, mailData, v.serverid)
        end
    end
    data.monsters[id].dietime = System.getNowTime()
    if not isend then
        data.monsters[id].remaintimes = 0
        LActor.postScriptEventLite(nil, MSCommonConfig.refreshtime * 1000, rebornMonster, id)
        data.monsters[id].isdie = true
        updateMonsterInfo(data, id)
    else
        data.monsters[id] = {}
    end
end

local function recoverTimes(actor)
    local var = getActorVar(actor)
    if var.challengetime >= MSCommonConfig.maxtimes then return end
    var.challengetime = var.challengetime + 1    
    var.challengerefresh = System.getNowTime()    
    if var.challengetime < MSCommonConfig.maxtimes then
        LActor.postScriptEventLite(actor, MSCommonConfig.recovertimes * 1000, recoverTimes)
    end
end

function updateSelfInfo(actor)    
    local var = getActorVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_UpdateSelfInfo)
    if not npack then return end
    LDataPack.writeChar(npack, var.challengetime)
    LDataPack.writeInt(npack, math.max(0, MSCommonConfig.recovertimes - (System.getNowTime() - var.challengerefresh)))
    LDataPack.flush(npack)    
end

local function reqEnter(actor, pack)
    if System.isCommSrv() then return end
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.monstersiege) then return end
    local id = LDataPack.readChar(pack)
    local conf = MSMonsterConfig[id]
    if not conf then return end
    local data = getGlobalData()
    if not data.monsters[id] then return end
    if data.monsters[id].remaintimes <= 0 then return end
    for i=1, #data.monsters[id].hurtrank do
        if actorid == LActor.getActorId(actor) then --不能重复打
            return
        end
    end
    
    local hfuben = instancesystem.createFuBen(conf.fbid)
    if hfuben == 0 then return end
    
    local var = getActorVar(actor)
    if var.challengetime <= 0 then return end    
    if var.challengetime == MSCommonConfig.maxtimes then
        var.challengerefresh = System.getNowTime()
        LActor.postScriptEventLite(actor, MSCommonConfig.recovertimes * 1000, recoverTimes)
    end
    var.challengetime = var.challengetime - 1
    var.msid = id
    local x,y = utils.getSceneEnterCoor(conf.fbid)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
    data.monsters[id].remaintimes = data.monsters[id].remaintimes - 1
    if data.monsters[id].remaintimes + 1 == MSCommonConfig.monstertimes then
        data.monsters[id].calctime = System.getNowTime()
        data.monsters[id].eid = LActor.postScriptEventLite(nil, MSCommonConfig.calctime * 1000, calcHurtRank, id)
    end
    updateSelfInfo(actor)
    updateMonsterInfo(data, id)

    local ins = instancesystem.getInsByHdl(hfuben)
    if not data.monsters[ins.data.msid].isdie and data.monsters[ins.data.msid].remaintimes <= 0 then
        if data.monsters[ins.data.msid].eid then
            LActor.cancelScriptEvent(nil, data.monsters[ins.data.msid].eid)
        end
        data.monsters[ins.data.msid].eid = nil        
    end
end

function updateMonsterInfo(data, id)
    local npack = LDataPack.allocPacket()
	if npack == nil then return end
    LDataPack.writeByte(npack,Protocol.CMD_MonSiege)
    LDataPack.writeByte(npack,Protocol.sMonSiegeCmd_UpdateMonsterHp)
    LDataPack.writeChar(npack, id)
    LDataPack.writeChar(npack, data.monsters[id].remaintimes)
    local now = System.getNowTime()
    if data.monsters[id].remaintimes == 0 then
        LDataPack.writeInt(npack, math.max(0, MSCommonConfig.refreshtime - (now - data.monsters[id].dietime)))
    else
        LDataPack.writeInt(npack, math.max(0, MSCommonConfig.calctime - (now - data.monsters[id].calctime)))
    end
    System.broadcastData(npack)
end

function sendFBInfo(actor, ins)
    if MonsterSiege_Status == 0 then return end
    if not actor or ins.is_end then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_FubenInfo)
    if not npack then return end
    local data = getGlobalData()
    if not data.monsters[ins.data.msid].hurtrank then data.monsters[ins.data.msid].hurtrank = {} end
    LDataPack.writeChar(npack, #data.monsters[ins.data.msid].hurtrank)
    for k,v in ipairs(data.monsters[ins.data.msid].hurtrank) do
        LDataPack.writeInt(npack, v.actorid)
        LDataPack.writeString(npack, v.name)
        LDataPack.writeDouble(npack, v.hurt)
    end

    LDataPack.writeDouble(npack, ins.data.hurt)
    LDataPack.flush(npack)
    LActor.postScriptEventLite(actor, 2000, sendFBInfo, ins) --发送副本信息
end

local function onEnterBefore(ins, actor)
    local var = getActorVar(actor)
    local monIdList = {var.msid}
    slim.s2cMonsterConfig(actor, monIdList)
end

local function onFinish(ins, actor)    
    local actor = ins:getActorList()[1]
    if not actor then return end
    local var = getActorVar(actor)
    if not var then return end
    for i=math.min(var.recordcount, 2), 1, -1 do
        var.record[i+1] = {}
        var.record[i+1].id = var.record[i].id
        var.record[i+1].endtime = var.record[i].endtime
        var.record[i+1].hurt = var.record[i].hurt
    end
    var.record[1] = {id = ins.data.msid, endtime = System.getNowTime(), hurt = ins.data.hurt}    
    if var.recordcount < 3 then
        var.recordcount = var.recordcount + 1
    end
    ins.data.msrewards = ins.data.msrewards or {}
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end

local function onExit(ins, actor)
    local conf = MSDabiaoConfig[MSMonsterConfig[ins.data.msid].monsterid]
    local reward = {}
    for k,v in ipairs(conf) do
        if ins.data.hurt >= v.hurt and not System.bitOPMask(ins.data.status, k) then
            for kk,vv in ipairs(v.reward) do
                table.insert(reward, {type=vv.type, id = vv.id, count = vv.count})
            end
        end
    end
    if #reward > 0 then
        local mailData = {head = MSCommonConfig.dabiaohead, context = MSCommonConfig.dabiaocontext, tAwardList=reward}
        mailsystem.sendMailById(LActor.getActorId(actor), mailData, LActor.getServerId(actor))
    end

    onFinish(ins, actor)
    if MonsterSiege_Status == 0 then return end
    local data = getGlobalData()
    data.monsters[ins.data.msid].fightcount = (data.monsters[ins.data.msid].fightcount or 0) - 1
    if data.monsters[ins.data.msid].remaintimes <= 0 and data.monsters[ins.data.msid].fightcount <= 0 then
        calcHurtRank(nil, ins.data.msid)
    end
end

local function onWin(ins)
    if MonsterSiege_Status == 0 then return end
    local actor = ins:getActorList()[1]    
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_FubenInfo)
    if not npack then return end
    local data = getGlobalData()
    if not data.monsters[ins.data.msid].hurtrank then data.monsters[ins.data.msid].hurtrank = {} end
    LDataPack.writeChar(npack, #data.monsters[ins.data.msid].hurtrank)
    for k,v in ipairs(data.monsters[ins.data.msid].hurtrank) do
        LDataPack.writeInt(npack, v.actorid)
        LDataPack.writeString(npack, v.name)
        LDataPack.writeDouble(npack, v.hurt)
    end

    LDataPack.writeDouble(npack, ins.data.hurt)
    LDataPack.flush(npack)

    ins.data.msrewards = ins.data.msrewards or {}
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_Result)
    if not npack then return end
    LDataPack.writeInt(npack, System.getNowTime() - ins.start_time[0])
    LDataPack.writeDouble(npack, ins.data.hurt)
    local rank = 0
    for k,v in ipairs(data.monsters[ins.data.msid].hurtrank) do
        if v.actorid == LActor.getActorId(actor) then
            rank = k
        end
    end
    LDataPack.writeChar(npack, rank)
    LDataPack.writeChar(npack, #ins.data.msrewards)
    for i=1, #ins.data.msrewards do
        LDataPack.writeInt(npack, ins.data.msrewards[i].id)
        LDataPack.writeDouble(npack, ins.data.msrewards[i].count)
    end
    LDataPack.flush(npack)
end

local function addHurtRank(actor, data, ins, value)
    local actorid = LActor.getActorId(actor)
    local name = LActor.getName(actor)
    local serverid = LActor.getServerId(actor)
    local ishave = false
    for k,v in ipairs(data.monsters[ins.data.msid].hurtrank) do
        if v.actorid == actorid then
            v.hurt = v.hurt + value
            ishave = true
            break
        end
    end
    if not ishave then
        table.insert(data.monsters[ins.data.msid].hurtrank, {name = name, actorid = actorid, serverid = serverid, hurt = value})
    end
    table.sort(data.monsters[ins.data.msid].hurtrank, function(a,b) return a.hurt > b.hurt end)
end

local function addRankScore(actorid, score, name, serverid, job, shenzhuang, shenqi, wing, shengling, meilin)
    local data = getGlobalData()
    local beforeid = data.rank[1] and data.rank[1].actorid or 0
    ishave = false
    for k,v in ipairs(data.rank) do
        if v.actorid == actorid then
            v.score = v.score + score
            ishave = true
            break
        end
    end
    if not ishave then
        table.insert(data.rank, {name = name, actorid = actorid, serverid = serverid, score = score})
    end
    table.sort(data.rank, function(a,b) return a.score > b.score end)
    if beforeid ~= data.rank[1].actorid then
        data.job = job
        data.shenzhuang = shenzhuang
        data.shenqi = shenqi
        data.wing = wing
        data.shengling = shengling
        data.meilin = meilin
    end
end

local function onAddScore(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local score = LDataPack.readInt(cpack)
    local name = LDataPack.readString(cpack)
    local serverid = LDataPack.readInt(cpack)
    local job = LDataPack.readChar(cpack)
    local shenzhuang = LDataPack.readInt(cpack)
    local shenqi = LDataPack.readInt(cpack)
    local wing = LDataPack.readInt(cpack)
    local shengling = LDataPack.readInt(cpack)
    local meilin = LDataPack.readInt(cpack)
    addRankScore(actorid, score, name, serverid, job, shenzhuang, shenqi, wing, shengling, meilin)
end

function addScore(actor, score)
    if score <= 0 then return end
    if System.isCommSrv() then
        local pack = LDataPack.allocPacket()
        LDataPack.writeByte(pack, CrossSrvCmd.SCMonsterSiege)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCMSCmd_AddScore)
        LDataPack.writeInt(pack, LActor.getActorId(actor))
        LDataPack.writeInt(pack, score)
        LDataPack.writeString(pack, LActor.getName(actor))
        LDataPack.writeInt(pack, LActor.getServerId(actor))
        LDataPack.writeChar(pack, LActor.getJob(actor))
        LDataPack.writeInt(pack, shenzhuangsystem.getShenzhuangId(actor))
        LDataPack.writeInt(pack, shenqisystem.getShenqiId(actor))
        LDataPack.writeInt(pack, wingsystem.getWingId(actor))
        LDataPack.writeInt(pack, getShengLingId(actor))
        LDataPack.writeInt(pack, meilinsystem.getActorVar(actor).choose)
        System.sendPacketToAllGameClient(pack, 0)
    end
end

local function onDamage(ins, monster, value, attacker, res)
    if ins.is_end then return end
    if MonsterSiege_Status == 0 then return end
    local actor = LActor.getActor(attacker)
    if not actor then return end
    local var = getActorVar(actor)
    ins.data.hurt = ins.data.hurt + value
    local data = getGlobalData()
    addHurtRank(actor, data, ins, value)
end

local function onMonsterAllDie(ins)
    if ins.refresh_monster_idx >= MSCommonConfig.monstermaxindex then --副本怪物死完
        ins:win()
    end
end

local function onEnterFb(ins, actor)
    local var = getActorVar(actor)
    ins.data.msid = var.msid
    ins.data.status = 0
    ins.data.hurt = 0
    local data = getGlobalData()
    data.monsters[ins.data.msid].fightcount = (data.monsters[ins.data.msid].fightcount or 0) + 1
    addHurtRank(actor, data, ins, 0)
    LActor.postScriptEventLite(actor, 2000, sendFBInfo, ins) --发送副本信息

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_ReqEnterReturn)
    if not npack then return end
    LDataPack.writeChar(npack, ins.data.msid)
    LDataPack.writeInt(npack, ins.data.status)
    LDataPack.flush(npack)
end

function onEnterMain(ins, actor)
    local data = getGlobalData()
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_SendMonsterInfo)
    if not npack then return end
    local now = System.getNowTime()
    local count = MonsterSiege_Status == 0 and 0 or #MSMonsterConfig
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeChar(npack, i)
        LDataPack.writeChar(npack, data.monsters[i].remaintimes or MSCommonConfig.monstertimes)
        if data.monsters[i].remaintimes == 0 then
            LDataPack.writeInt(npack, math.max(0, MSCommonConfig.refreshtime - (now - data.monsters[i].dietime)))
        else
            LDataPack.writeInt(npack, math.max(0, MSCommonConfig.calctime - (now - data.monsters[i].calctime)))
        end
    end
    LDataPack.flush(npack)
end

function onEnterMainBefore(ins, actor)
    local monIdList = {}
    for k,v in pairs(MSMonsterConfig) do
        if k==1 or (k>1 and v.monsterid ~= MSMonsterConfig[k-1].monsterid) then            
            table.insert(monIdList, v.monsterid)
        end
    end
    slim.s2cMonsterConfig(actor, monIdList)
end

function broMonsterSiege()
    local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_MonSiege)
	LDataPack.writeByte(npack, Protocol.sMonSiegeCmd_BroStatus)
	LDataPack.writeByte(npack, MonsterSiege_Status)
    System.broadcastData(npack)
end

local function monsterSiegeStart(isstart)
    local data = getGlobalData()
    for k,v in ipairs(MSMonsterConfig) do
        data.monsters = {}
        for i=1, #MSMonsterConfig do
            data.monsters[i] ={
                remaintimes = MSCommonConfig.monstertimes,
                dietime = 0,
                calctime = 0,
                fightcount = 0,
                hurtrank = {},
            }
        end
    end
    
    local now = System.getNowTime()
    --发送怪物信息
    local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_MonSiege)
	LDataPack.writeByte(npack, Protocol.sMonSiegeCmd_SendMonsterInfo)
    LDataPack.writeChar(npack, #MSMonsterConfig)
    for i=1, #MSMonsterConfig do
        LDataPack.writeChar(npack, i)
        LDataPack.writeChar(npack, data.monsters[i].remaintimes or MSCommonConfig.monstertimes)
        if data.monsters[i].remaintimes == 0 then
            LDataPack.writeInt(npack, math.max(0, MSCommonConfig.refreshtime - (now - data.monsters[i].dietime)))
        else
            LDataPack.writeInt(npack, math.max(0, MSCommonConfig.calctime - (now - data.monsters[i].calctime)))
        end
    end
    mainscenefuben.sendData(npack)
end

local function startMonsterSiege()
    MonsterSiege_Status = 1
    broMonsterSiege()
    if not System.isBattleSrv() then return end
    monsterSiegeStart()
end

local function settlementMonsterSiege()
    print("settlementMonsterSiege start")
    local data = getGlobalData()
    for k,v in ipairs(data.rank) do
        if MSRankConfig[k] then
            print("settlementMonsterSiege", data.rank[k].actorid, k,  data.rank[k].serverid)
            local mailData = {head = MSCommonConfig.rankhead, context = string.format(MSCommonConfig.rankcontext, k), tAwardList= MSRankConfig[k].reward}
            mailsystem.sendMailById(data.rank[k].actorid, mailData, data.rank[k].serverid)
        end
    end
    data.monsters = {}
end

local function stopMonsterSiege()        
    if System.isBattleSrv() then          
        for k,v in ipairs(MSMonsterConfig) do
            calcHurtRank(nil, k, true)
        end
        local data = getGlobalData()
        data.monsters = {}
    end
    MonsterSiege_Status = 0
    broMonsterSiege()
end

local function onActorDie(ins, actor)
    ins:win()
end

local function onLogin(actor)    
    local var = getActorVar(actor)
    local now = System.getNowTime()
    local before = var.challengetime
    if before < MSCommonConfig.maxtimes then
        if now - var.challengerefresh > MSCommonConfig.recovertimes then            
            var.challengetime = var.challengetime + math.floor((now - var.challengerefresh)/MSCommonConfig.recovertimes)
            var.challengerefresh = var.challengerefresh + MSCommonConfig.recovertimes * (var.challengetime - before)
        end
        if var.challengetime >= MSCommonConfig.maxtimes then
            var.challengetime = MSCommonConfig.maxtimes
            var.challengerefresh = 0
        end
        if var.challengetime < MSCommonConfig.maxtimes then
            LActor.postScriptEventLite(actor, math.max(MSCommonConfig.recovertimes - (System.getNowTime() - var.challengerefresh), 0) * 1000, recoverTimes)
        end
    else
        var.challengerefresh = 0
    end
    sendInfo(actor)
end

local function OnGameStart( ... )
    local hour, min, _ = System.getTime()
    if hour >= MSCommonConfig.startTime[1] and hour < MSCommonConfig.endTime[1] then
        MonsterSiege_Status = 1
        monsterSiegeStart(true)
    end
end

local function monsterSiegeClear()
    if not System.isBattleSrv() then return end
    local data = getGlobalData()
    data.rank = {}
    data.job = 0
    data.shenzhuang = 0
    data.shenqi = 0
    data.wing = 0
    data.shengling = 0
    data.meilin = 0
end

local function onNewDay(actor, login)
    local var = getActorVar(actor)
    var.challengetime = MSCommonConfig.maxtimes
    var.challengerefresh = 0
    local now = System.getNowTime()
    if not System.isSameWeek(now, var.refresh_week_time or 0) then
        var.recordcount = 0
        var.scorestatus = 0
        actoritem.reduceItem(actor, NumericType_SiegeScore, actoritem.getItemCount(actor, NumericType_SiegeScore), "monster siege newday", 1) --跨周清空
    end
    var.refresh_week_time = now
    if not login then
        sendInfo(actor)
    end
end

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)

local function onInitFuben()
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_ReqRank, reqRank)
    netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_ReqOneMonster, reqOneMonster)
    netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_FBGetScoreReward, fBGetScoreReward)
    netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_GetScoreReward, getScoreReward)
    netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_ReqEnter, reqEnter)
    netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_ReqInfo, reqInfo)   
     

    csmsgdispatcher.Reg(CrossSrvCmd.SCMonsterSiege, CrossSrvSubCmd.SCMSCmd_ReqRankInfo, onReqRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCMonsterSiege, CrossSrvSubCmd.SCMSCmd_SendRankInfo, onSendRank)
    csmsgdispatcher.Reg(CrossSrvCmd.SCMonsterSiege, CrossSrvSubCmd.SCMSCmd_AddScore, onAddScore)
    

    for k,v in pairs(MSMonsterConfig) do
        if k==1 or (k>1 and v.fbid ~= MSMonsterConfig[k-1].fbid) then
            insevent.registerInstanceEnter(v.fbid, onEnterFb)
            --insevent.registerInstanceEnterBefore(v.fbid, onEnterBefore)
            insevent.registerInstanceExit(v.fbid, onExit)
            insevent.registerInstanceWin(v.fbid, onWin)            
            insevent.registerInstanceLose(v.fbid, onWin)
            insevent.registerInstanceOffline(v.fbid, onOffline)
            insevent.registerInstanceMonsterAllDie(v.fbid, onMonsterAllDie)
            insevent.registerInstanceActorDie(v.fbid, onActorDie)
            insevent.registerInstanceMonsterDamage(v.fbid, onDamage)
        end
    end
    insevent.registerInstanceEnter(0, onEnterMain)
    insevent.registerInstanceEnterBefore(0, onEnterMainBefore)
end
table.insert(InitFnTable, onInitFuben)

_G.startMonsterSiege = startMonsterSiege
_G.stopMonsterSiege = stopMonsterSiege
_G.settlementMonsterSiege = settlementMonsterSiege
_G.monsterSiegeClear = monsterSiegeClear

engineevent.regGameStartEvent(OnGameStart)


local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.msfbscore = function (actor, args)
    if not System.isBattleSrv() then return end
    local ins = instancesystem.getActorIns(actor)
    ins.data.hurt = tonumber(args[1])
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_FubenInfo)
    if not npack then return end
    LDataPack.writeDouble(npack, ins.data.hurt)
    LDataPack.flush(npack)
	return true
end

gmCmdHandlers.msrsclear = function (actor, args)
    local var = getActorVar(actor)
    var.recordcount = tonumber(args[1])
	return true	
end

gmCmdHandlers.msstart = function (actor, args)
    startMonsterSiege()
	return true	
end

gmCmdHandlers.msend = function (actor, args)
    stopMonsterSiege()
	return true	
end


gmCmdHandlers.mssettle = function (actor, args)
    settlementMonsterSiege()
	return true	
end

gmCmdHandlers.msshow = function (actor, args)
    local id = tonumber(args[1])
    local data = getGlobalData()
    if not data.monsters[id] then
        print("xxxxxxxxxxxxxxxxxx id error")
        return
    end

    if data.monsters[id].hurtrank then
        for k,v in ipairs(data.monsters[id].hurtrank) do
            print("xxxxxxxxxxxxxxxxx", v.name, v.hurt)
        end
    end
	return true	
end

