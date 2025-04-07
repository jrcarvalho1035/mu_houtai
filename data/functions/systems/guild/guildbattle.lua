--领地争夺战
module("guildbattle", package.seeall)


local ShieldType = {
    bossShield = "bossShield",
    guardShield = "guardShield",
}

local function getFightType()
    local now = System.getNowTime()
    if now < guildbattlesystem.BATTLE_STAGE_TIME[4]+60 then
        return 1
    end
    return 2
end

local function getEffectsByOpenDay()
    local openDay = System.getOpenServerDay()
    for index, conf in ipairs(GBEffectConfig) do
        if openDay >= conf.opendays[1] and openDay <= conf.opendays[2] then
            return conf.effects
        end
    end
    return GBEffectConfig[#GBEffectConfig].effects
end 

local function getAddHpByOpenDay()
    local openDay = System.getOpenServerDay()
    for index, conf in ipairs(GBEffectConfig) do
        if openDay >= conf.opendays[1] and openDay <= conf.opendays[2] then
            return conf.addHpMax
        end
    end
    return GBEffectConfig[#GBEffectConfig].addHpMax
end 

local function onMonsterCreate(ins, monster)
    local conf = getEffectsByOpenDay()
    if LActor.isBoss(monster) then
        for __, extraEffectId in ipairs(conf) do
            LActor.addSkillEffect(monster, extraEffectId)
        end
    end
end

--求下一个护盾
local function getNextShield(sType, hp)
    if nil == hp then hp = 101 end
    local conf = GBConstConfig[sType]
    if nil == conf then return nil end
    for i, s in ipairs(conf) do
        if s.hp < hp then return s end
    end
    return nil
end

local function getFinalType(ins)
    if ins.data.fighttype == 1 then return 1 end
    local gvar = guildbattlesystem.getGlobalData(gvar)
    for k,v in pairs(ins.data.gbInfo) do
        local finalindex1 = gvar.final[ins.data.manorindex][1]
        if finalindex1 and gvar.applyssorts[ins.data.manorindex][finalindex1] and gvar.applyssorts[ins.data.manorindex][finalindex1].guildId == k then
            return 3
        end
    end
    return 2
end

local function getScoreAdd(ins)
    return GBManorIndexConfig[ins.data.manorindex].manoradd * GBConstConfig["scoreadd"..getFinalType(ins)]
end

--护盾结束
function finishShield(_, ins, monid)
    if not ins then return end
    local info = ins.data.bossinfo[monid]
    info.shield = 0
    local handle = ins.scene_list[1]
    local scene = Fuben.getScenePtr(handle)
    local monster = Fuben.getSceneMonsterById(scene, monid)
    local x, y = LActor.getEntityScenePos(info.monster)
    instancesystem.s2cShieldInfo(ins.handle, 1, 0, info.curShield.shield, nil, x, y)
end

local function onEnterFb(ins, actor)
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then return end
    local otherGuildId = 0
    for k in pairs(ins.data.gbInfo) do
        if k ~= guildId then
            otherGuildId = k
        end
    end
    local var = guildbattlesystem.getActorVar(actor)
    local gvar = guildbattlesystem.getGlobalData()

    updateAttr(actor, ins)
    --发送鼓舞信息
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_InspireInfo)
    if not npack then return end
    LDataPack.writeChar(npack, ins.data.inspiretimes[LActor.getActorId(actor)])
    LDataPack.writeString(npack, LGuild.getGuilNameById(guildId))
    LDataPack.writeChar(npack, #ins.data.gbInfo[guildId].inspirePeoples)
    for k,v in ipairs(ins.data.gbInfo[guildId].inspirePeoples) do
        LDataPack.writeString(npack, v)
    end
    LDataPack.writeString(npack, LGuild.getGuilNameById(otherGuildId))
    LDataPack.writeChar(npack, #ins.data.gbInfo[otherGuildId].inspirePeoples)    
    for k,v in ipairs(ins.data.gbInfo[otherGuildId].inspirePeoples) do
        LDataPack.writeString(npack, v)
    end
    LDataPack.flush(npack)
    LActor.setCamp(actor, guildId)--设置阵营为战盟模式
    guildbattlesystem.sendSelfScore(actor)
end

function onEnerBossArea(ins, actor, monid)
    local info = ins.data.bossinfo and ins.data.bossinfo[monid]
    if not info then return end

    --护盾信息
    if info.curShield then
        nowShield = info.shield
        if (info.curShield.type or 0) == 1 then
            nowShield = nowShield - System.getNowTime()
            if nowShield < 0 then
                nowShield = 0
            end
        end

        instancesystem.s2cShieldInfo(ins.handle, info.curShield.type, nowShield, info.curShield.shield, actor)
    else
        -- instancesystem.s2cShieldInfo(info.hfuben, 1, 0, config.shield[1].shield, actor)
    end
end

function broadCastWin(ins, winGuildId, winScore, otherGuildId, otherScore)
    local tmp = {}
    tmp[winGuildId] = {}
    tmp[otherGuildId] = {}
    for k,v in pairs(ins.data.selfscore) do
        tmp[v.guildId][#tmp[v.guildId]+1] = v
    end
    table.sort(tmp[winGuildId], function(a,b) return a.score > b.score end)
    table.sort(tmp[otherGuildId], function(a,b) return a.score > b.score end)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_GuildBattle)
    LDataPack.writeByte(npack, Protocol.sGuildBattleCmd_FightResult)
    if not npack then return end
    LDataPack.writeInt(npack, winGuildId)
    LDataPack.writeInt(npack, winScore)
    LDataPack.writeString(npack, LGuild.getGuilNameById(winGuildId))
    local count = math.min(3, #tmp[winGuildId])
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeString(npack, tmp[winGuildId][i].name)
        LDataPack.writeInt(npack, tmp[winGuildId][i].score)
        LDataPack.writeChar(npack, tmp[winGuildId][i].job)
    end
    LDataPack.writeInt(npack, otherGuildId > GBConstConfig.manorcount and otherGuildId or 0)
    LDataPack.writeInt(npack, otherScore)
    LDataPack.writeString(npack, LGuild.getGuilNameById(otherGuildId) or "")
    local count = math.min(3, #tmp[otherGuildId])
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeString(npack, tmp[otherGuildId][i].name)
        LDataPack.writeInt(npack, tmp[otherGuildId][i].score)
        LDataPack.writeChar(npack, tmp[otherGuildId][i].job)
    end
    Fuben.sendData(ins.handle, npack)
end

local function onWin(ins)
    if not ins.data.fighttype then
        ins.data.fighttype = getFightType()
    end
    print("guildbattle onwin start", ins.data.fighttype, ins.data.manorindex, ins.handle, ins.data.scores)
    local gvar = guildbattlesystem.getGlobalData()
    local winGuildId = 0
    local winScore = -1
    local otherScore = 999999999
    local otherGuildId = 0
    local manorindex = ins.data.manorindex
    if ins.data.scores then --如果有人参加
        for k,v in pairs(ins.data.scores) do
            if (v.totalscore or 0) > winScore and k > GBConstConfig.manorcount then
                winGuildId = k
                winScore = v.totalscore or 0
            end
        end
        for k,v in pairs(ins.data.scores) do
            if k ~= winGuildId then
                otherScore = v.totalscore or 0
                otherGuildId = k
                break
            end
        end
        broadCastWin(ins, winGuildId, winScore, otherGuildId, otherScore)
    else --如果没人参加
        if not gvar.fbinfo[ins.handle] then
            return
        end
        winGuildId = gvar.fbinfo[ins.handle][1]
        otherGuildId = gvar.fbinfo[ins.handle][2]        
    end
    if not manorindex then
        manorindex = gvar.fightinfo[winGuildId].manorindex
    end
    if not manorindex then
        return
        --manorindex = 6
    end
    
    if ins.data.fighttype == 1 then --半决赛胜利进入决赛        
        for k,v in ipairs(gvar.applyssorts[manorindex]) do
            if v.guildId == winGuildId and winGuildId > GBConstConfig.manorcount then
                if not gvar.final[manorindex][1] or gvar.final[manorindex][1] == 0 then
                    gvar.final[manorindex][1] = k
                else
                    gvar.final[manorindex][2] = k
                end
                gvar.applyssorts[manorindex][k].iswin = 1
                if otherGuildId > GBConstConfig.manorcount then
                    local str = string.format(GBConstConfig.resultbro1, GBManorIndexConfig[manorindex].name, LGuild.getGuilNameById(winGuildId), LGuild.getGuilNameById(otherGuildId))
                    noticesystem.broadAllServerContent(1, str)
                else
                    local str = string.format(GBConstConfig.resultbro2, GBManorIndexConfig[manorindex].name, LGuild.getGuilNameById(winGuildId))
                    noticesystem.broadAllServerContent(1, str)
                end
            end
            
            if v.guildId == otherGuildId and otherGuildId > GBConstConfig.manorcount then
                if not gvar.final[manorindex][3] or gvar.final[manorindex][3] == 0 then
                    gvar.final[manorindex][3] = k
                else
                    gvar.final[manorindex][4] = k
                end             
                gvar.applyssorts[manorindex][k].iswin = 0
            end
        end
        guildbattlecross.sendJoinFinalMail(winGuildId)
        guildbattlecross.sendJoinFinalMail(otherGuildId)
    else--决赛胜利，发送奖励
        local finalindex1 = gvar.final[manorindex][1]
        local finalindex2 = gvar.final[manorindex][2]
        local finalindex3 = gvar.final[manorindex][3]
        local finalindex4 = gvar.final[manorindex][4]
        if (finalindex3 and gvar.applyssorts[manorindex][finalindex3] and gvar.applyssorts[manorindex][finalindex3].guildId == winGuildId) or 
            (finalindex4 and gvar.applyssorts[manorindex][finalindex4] and gvar.applyssorts[manorindex][finalindex4].guildId == winGuildId) then --第三四名
            gvar.winguidlids[manorindex][3] = winGuildId
            gvar.guildResult[winGuildId] = {}
            gvar.guildResult[winGuildId].manorindex = manorindex
            gvar.guildResult[winGuildId].rank = 3
            gvar.guildResult[winGuildId].hongbaoflag = 1
            gvar.hongbao[winGuildId] = {}            
            gvar.hongbao[winGuildId].remainmoney = GBManorConfig[GBManorIndexConfig[manorindex].level][3].hongbao            
            guildbattlesystem.sendRankReward(winGuildId, manorindex, 3)
            if otherGuildId > GBConstConfig.manorcount then
                gvar.winguidlids[manorindex][4] = otherGuildId
                gvar.guildResult[otherGuildId] = {}
                gvar.guildResult[otherGuildId].manorindex = manorindex
                gvar.guildResult[otherGuildId].rank = 4
                gvar.guildResult[otherGuildId].hongbaoflag = 1
                gvar.hongbao[otherGuildId] = {}
                gvar.hongbao[otherGuildId].remainmoney = GBManorConfig[GBManorIndexConfig[manorindex].level][4].hongbao
                guildbattlesystem.sendRankReward(otherGuildId, manorindex, 4)
                local str = string.format(GBConstConfig.resultbro3, GBManorIndexConfig[manorindex].name, LGuild.getGuilNameById(winGuildId), LGuild.getGuilNameById(otherGuildId),3)
                noticesystem.broadAllServerContent(1, str)
            else
                local str = string.format(GBConstConfig.resultbro4, GBManorIndexConfig[manorindex].name, LGuild.getGuilNameById(winGuildId),3)
                noticesystem.broadAllServerContent(1, str)
            end            
        elseif (finalindex1 and gvar.applyssorts[manorindex][finalindex1] and gvar.applyssorts[manorindex][finalindex1].guildId == winGuildId) or 
        (finalindex2 and gvar.applyssorts[manorindex][finalindex2] and gvar.applyssorts[manorindex][finalindex2].guildId == winGuildId) then --第三四名
            gvar.winguidlids[manorindex][1] = winGuildId
            gvar.guildResult[winGuildId] = {}
            gvar.guildResult[winGuildId].manorindex = manorindex
            gvar.guildResult[winGuildId].rank = 1
            gvar.guildResult[winGuildId].hongbaoflag = 1
            gvar.hongbao[winGuildId] = {}
            gvar.hongbao[winGuildId].remainmoney = GBManorConfig[GBManorIndexConfig[manorindex].level][1].hongbao
            guildbattlesystem.sendRankReward(winGuildId, manorindex, 1)
            if otherGuildId > GBConstConfig.manorcount then
                gvar.winguidlids[manorindex][2] = otherGuildId
                gvar.guildResult[otherGuildId] = {}
                gvar.guildResult[otherGuildId].manorindex = manorindex
                gvar.guildResult[otherGuildId].rank = 2
                gvar.guildResult[otherGuildId].hongbaoflag = 1
                gvar.hongbao[otherGuildId] = {}
                gvar.hongbao[otherGuildId].remainmoney = GBManorConfig[GBManorIndexConfig[manorindex].level][2].hongbao
                guildbattlesystem.sendRankReward(otherGuildId, manorindex, 2)
                local str = string.format(GBConstConfig.resultbro3, GBManorIndexConfig[manorindex].name, LGuild.getGuilNameById(winGuildId), LGuild.getGuilNameById(otherGuildId),1)
                noticesystem.broadAllServerContent(1, str)
            else
                local str = string.format(GBConstConfig.resultbro4, GBManorIndexConfig[manorindex].name, LGuild.getGuilNameById(winGuildId),1)
                noticesystem.broadAllServerContent(1, str)
            end
            if manorindex == 1 then
                guildbattlesystem.getFirstGuildLeaderInfo(winGuildId)
            end
        end        
    end
    table.sort(gvar.selfrank, function(a,b) return a.score > b.score end) --排序一下排行榜，要不然最后一个获得积分的玩家的排行不会刷新
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildFight)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildFightCmd_UpdateGuildSemiWin)
    LDataPack.writeInt(npack, winGuildId)
    LDataPack.writeInt(npack, otherGuildId)
    System.sendPacketToAllGameClient(npack, 0)
    print("guildbattle onwin end", manorindex, winGuildId, otherGuildId)
end

local function onExitFb(ins, actor)
    local actorid = LActor.getActorId(actor)
    ins.data.killnum[actorid] = 0
    updateAttr(actor, ins)
    broKillInfo(ins, actor, nil, 0)
    --发送个人未领取达标奖励
    sendSelfReward(actor, ins)
end

function sendSelfReward(actor, ins)
    local rewards = {}
    local gvar = guildbattlesystem.getGlobalData()
    local actorid = LActor.getActorId(actor)
    local index = 0
    for i=1, #gvar.selfrank do
        if gvar.selfrank[i].actorid == actorid then
            index = i
            break
        end
    end
    if index == 0 then
        return
    end
    local selfinfo = gvar.selfrank[index]
    for i, conf in ipairs(GBDabiaoRewardConfig) do
        if not System.bitOPMask(selfinfo.scorestatus, i) then
            if selfinfo.score >= conf.score then
                selfinfo.scorestatus = System.bitOpSetMask(selfinfo.scorestatus, i, true)
                for _, reward in ipairs(conf.reward) do
                    table.insert(rewards, reward)
                end
            end
        end
    end
    if #rewards > 0 then
        local context = string.format(GBConstConfig.selfscorecontext, GBManorIndexConfig[ins.data.manorindex].name)
        local mailData = {head = GBConstConfig.selfscorehead, context = context, tAwardList=rewards}
        mailsystem.sendMailById(LActor.getActorId(actor), mailData, LActor.getServerId(actor))
    end
end

local function onOffline(ins, actor)
    --LActor.exitFuben(actor)
end

local function onBeforeEnterFb(ins, actor)
    if not ins.data.fighttype then
        ins.data.fighttype = getFightType()
    end
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then return end
    local gvar = guildbattlesystem.getGlobalData()
    if not gvar.fightinfo[guildId] then return end
        
    local index = gvar.fightinfo[guildId].index
    local level = gvar.fightinfo[guildId].level
    local actorid = LActor.getActorId(actor)
    if not ins.data.killnum then ins.data.killnum = {} end
    if not ins.data.killnum[actorid] then ins.data.killnum[actorid] = 0 end
    if not ins.data.inspiretimes then ins.data.inspiretimes = {} end
    if not ins.data.inspiretimes[actorid] then ins.data.inspiretimes[actorid] = 0 end
    if not ins.data.gbInfo then ins.data.gbInfo = {} end
    if not ins.data.gbInfo[guildId] then ins.data.gbInfo[guildId] = {} end
    if not ins.data.gbInfo[guildId].level then ins.data.gbInfo[guildId].level = level end
    if not ins.data.gbInfo[guildId].inspirePeoples then ins.data.gbInfo[guildId].inspirePeoples = {} end
    if not ins.data.scores then ins.data.scores = {} end
    if not ins.data.selfscore then ins.data.selfscore = {} end
    if not ins.data.selfscore[actorid] then 
        ins.data.selfscore[actorid] = {} 
        ins.data.selfscore[actorid].job = LActor.getJob(actor)
        ins.data.selfscore[actorid].name = LActor.getName(actor)
        ins.data.selfscore[actorid].score = 0
        ins.data.selfscore[actorid].guildId = LActor.getGuildId(actor)
    end

    actorcommon.setTeamId(actor, guildId)

    local guardid1 = GBConstConfig.guardid1[level]
    local guardid2 = GBConstConfig.guardid2[level]
    local bossid = GBConstConfig.bossid[level]
    if not ins.data.iscreate then
        if not ins.data.bossinfo then ins.data.bossinfo = {} end
        
        local oindex = index % 2 + 1
        local otherGuildId = gvar.fbinfo[ins.handle][oindex]
        if not ins.data.gbInfo[otherGuildId] then ins.data.gbInfo[otherGuildId] = {} end
        if not ins.data.gbInfo[otherGuildId].inspirePeoples then ins.data.gbInfo[otherGuildId].inspirePeoples = {} end
        if index == 1 then
            guildid1 = guildId
            guildid2 = otherGuildId
        else
            guildid1 = otherGuildId
            guildid2 = guildId
        end
        if index == 1 then
            guildid1 = guildId
            guildid2 = otherGuildId
        else
            guildid1 = otherGuildId
            guildid2 = guildId
        end
        --守护        
        ins.data.bossinfo[guardid1] = {}
        ins.data.bossinfo[guardid1].guildId = guildid1
        ins.data.bossinfo[guardid1].hpper = 100
        ins.data.bossinfo[guardid1].reborntime = 0
        ins.data.bossinfo[guardid1].sType = ShieldType.guardShield
        ins.data.bossinfo[guardid1].shield = 0
        ins.data.bossinfo[guardid1].curShield = nil
        ins.data.bossinfo[guardid1].nextShield = getNextShield(ShieldType.guardShield)
        ins.data.bossinfo[guardid1].posx = GBConstConfig.guardpos[1][1]
        ins.data.bossinfo[guardid1].posy = GBConstConfig.guardpos[1][2]
        Fuben.createMonster(ins.scene_list[1], guardid1, GBConstConfig.guardpos[1][1], GBConstConfig.guardpos[1][2],0,0,0,guildid1)
        
        ins.data.bossinfo[guardid2] = {}
        ins.data.bossinfo[guardid2].guildId = guildid2
        ins.data.bossinfo[guardid2].hpper = 100
        ins.data.bossinfo[guardid2].reborntime = 0
        ins.data.bossinfo[guardid2].sType = ShieldType.guardShield
        ins.data.bossinfo[guardid2].shield = 0
        ins.data.bossinfo[guardid2].curShield = nil
        ins.data.bossinfo[guardid2].nextShield = getNextShield(ShieldType.guardShield)
        ins.data.bossinfo[guardid2].posx = GBConstConfig.guardpos[2][1]
        ins.data.bossinfo[guardid2].posy = GBConstConfig.guardpos[2][2]
        Fuben.createMonster(ins.scene_list[1], guardid2, GBConstConfig.guardpos[2][1], GBConstConfig.guardpos[2][2],0,0,0,guildid2)

        --boss        
        ins.data.bossinfo[bossid] = {}
        ins.data.bossinfo[bossid].guildId = 0
        ins.data.bossinfo[bossid].hpper = 100
        ins.data.bossinfo[bossid].reborntime = 0
        ins.data.bossinfo[bossid].sType = ShieldType.bossShield
        ins.data.bossinfo[bossid].shield = 0
        ins.data.bossinfo[bossid].curShield = nil
        ins.data.bossinfo[bossid].nextShield = getNextShield(ShieldType.bossShield)
        ins.data.bossinfo[bossid].posx = GBConstConfig.bosspos[1]
        ins.data.bossinfo[bossid].posy = GBConstConfig.bosspos[2]
        Fuben.createMonster(ins.scene_list[1], bossid, GBConstConfig.bosspos[1], GBConstConfig.bosspos[2]) 

        if not ins.data.scores[guildId] then ins.data.scores[guildId] = {} end
        if not ins.data.scores[otherGuildId] then ins.data.scores[otherGuildId] = {} end
        ins.data.manorindex = gvar.fightinfo[guildId].manorindex
        ins.data.iscreate = true
    end

    local monIdList = {guardid1, guardid2, bossid}
    for monid in pairs(GbRefreshMonsterConfig) do
        table.insert(monIdList, monid)
    end
    slim.s2cMonsterConfig(actor, monIdList) --进入副本前先发送里面BOSS和小怪的信息

    --所有玩家连杀数
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_KillNumList)
    if not npack then return end
    local actors = Fuben.getAllActor(ins.handle)
    if actors ~= nil then
        LDataPack.writeChar(npack, #actors)
        for i = 1,#actors do
            LDataPack.writeDouble(npack, LActor.getHandle(actors[i]))
            LDataPack.writeInt(npack, ins.data.killnum[LActor.getActorId(actors[i])])
        end
    else
        LDataPack.writeChar(npack, 0)        
    end
    LDataPack.writeChar(npack, ins.data.manorindex)
    LDataPack.writeChar(npack, getFinalType(ins))
    LDataPack.flush(npack)

    --副本信息
    sendFubenInfo(ins, actor)

    if not ins.data.bro_eid then
        ins.data.bro_eid = LActor.postScriptEventLite(nil, 2000, broFubenInfo, ins)
    end

    local guild = LGuild.getGuildById(guildId)
    guildchat.sendAndBroNotice(guild, string.format(GBConstConfig.gbtip1, LActor.getName(actor)), enGuildChatNew)
end

function sendFubenInfo(ins, actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_FubenInfo)
    if not npack then return end
    LDataPack.writeChar(npack, 3)
    for k,v in pairs(ins.data.bossinfo) do
        LDataPack.writeInt(npack, k)
        LDataPack.writeShort(npack, v.hpper)
        LDataPack.writeInt(npack, v.guildId)
        LDataPack.writeInt(npack, v.reborntime > System.getNowTime() and v.reborntime or 0)
        LDataPack.writeShort(npack, v.posx)
        LDataPack.writeShort(npack, v.posy)
    end

    LDataPack.writeChar(npack, 2)
    for k,v in pairs(ins.data.scores) do
        LDataPack.writeInt(npack, k)
        LDataPack.writeInt(npack, v.totalscore or 0)
    end
    
    LDataPack.flush(npack)
end

function broFubenInfo(_, ins)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_GuildBattle)
    LDataPack.writeByte(npack, Protocol.sGuildBattleCmd_FubenInfo)
    if not npack then return end
    LDataPack.writeChar(npack, 3)
    for k,v in pairs(ins.data.bossinfo) do
        LDataPack.writeInt(npack, k)
        LDataPack.writeShort(npack, v.hpper)
        LDataPack.writeInt(npack, v.guildId)
        LDataPack.writeInt(npack, v.reborntime > System.getNowTime() and v.reborntime or 0)
        LDataPack.writeShort(npack, v.posx)
        LDataPack.writeShort(npack, v.posy)
    end

    LDataPack.writeChar(npack, 2)
    for k,v in pairs(ins.data.scores) do
        LDataPack.writeInt(npack, k)
        LDataPack.writeInt(npack, v.totalscore or 0)
    end

    Fuben.sendData(ins.handle, npack)
    ins.data.bro_eid = LActor.postScriptEventLite(nil, 2000, broFubenInfo, ins)
end

function refreshMonster(_, ins, monid, level, index)
    local gvar = guildbattlesystem.getGlobalData()
    local guardid1 = GBConstConfig.guardid1[level]
    local guardid2 = GBConstConfig.guardid2[level]
    local bossid = GBConstConfig.bossid[level]

    if bossid == monid then
        Fuben.createMonster(ins.scene_list[1], monid, GBConstConfig.bosspos[1], GBConstConfig.bosspos[2])
        ins.data.bossinfo[monid].sType = ShieldType.guardShield
        ins.data.bossinfo[monid].shield = 0
        ins.data.bossinfo[monid].curShield = nil
        ins.data.bossinfo[monid].nextShield = getNextShield(ShieldType.guardShield)
        ins.data.bossinfo[monid].hpper = 100
    elseif guardid1 == monid then
        Fuben.createMonster(ins.scene_list[1], monid, GBConstConfig.guardpos[1][1], GBConstConfig.guardpos[1][2],0,0,0,gvar.fbinfo[ins.handle][1])
        ins.data.bossinfo[monid].sType = ShieldType.guardShield
        ins.data.bossinfo[monid].shield = 0
        ins.data.bossinfo[monid].curShield = nil
        ins.data.bossinfo[monid].nextShield = getNextShield(ShieldType.guardShield)
        ins.data.bossinfo[monid].hpper = 100
    elseif guardid2 == monid then
        Fuben.createMonster(ins.scene_list[1], monid, GBConstConfig.guardpos[2][1], GBConstConfig.guardpos[2][2],0,0,0,gvar.fbinfo[ins.handle][2])
        ins.data.bossinfo[monid].sType = ShieldType.guardShield
        ins.data.bossinfo[monid].shield = 0
        ins.data.bossinfo[monid].curShield = nil
        ins.data.bossinfo[monid].nextShield = getNextShield(ShieldType.guardShield)
        ins.data.bossinfo[monid].hpper = 100
    else
        local conf = GbRefreshMonsterConfig[monid]
        if conf then
            Fuben.createMonster(ins.scene_list[1], monid, conf.position.x, conf.position.y)
        end
    end    
end

local function onBossDamage(ins, monster, value, attacker, res)
    local monid = Fuben.getMonsterId(monster)
    if not ins.data.bossinfo or not ins.data.bossinfo[monid] then return end
    local info = ins.data.bossinfo[monid]
    local oldhp = LActor.getHp(monster)
    local hp = oldhp - value
	if hp < 0 then hp = 0 end

	hp = hp / LActor.getHpMax(monster) * 100
    info.hpper = math.ceil(hp)
    local guildId = ins.data.bossinfo[monid].guildId
    --护盾判断
    if 0 == info.shield then --现在没有护盾
        if info.nextShield and 0 ~= info.nextShield.hp and hp < info.nextShield.hp then --从预备护盾里取护盾
            info.curShield = info.nextShield
            info.nextShield = getNextShield(info.sType, info.curShield.hp) --再取下一个预备护盾
            
            res.ret = math.floor(LActor.getHpMax(monster) * info.curShield.hp / 100) --避免一招秒而不触发护盾，这里要恢复血量
            info.hpper = info.curShield.hp --要把血量设置回原值
            LActor.setInvincible(monster, info.curShield.shield * 1000) --设无敌状态
            info.shield = info.curShield.shield + System.getNowTime()
            local x, y = LActor.getEntityScenePos(monster)
            instancesystem.s2cShieldInfo(ins.handle, 1, info.curShield.shield, info.curShield.shield, nil, x, y)
            --注册护盾结束定时器
            info.shieldEid = LActor.postScriptEventLite(nil, info.curShield.shield * 1000, finishShield, ins, monid)
            noticesystem.fubenCastNotice(ins.handle, noticesystem.NTP.homeShield)
            if guildId ~= 0 then
                local guild = LGuild.getGuildById(guildId)
                if guild then
                    guildchat.sendAndBroNotice(guild, GBConstConfig.gbtip3, enGuildChatNew)
                end
            else
                for k,v in pairs(ins.data.bossinfo) do
                    if v.guildId ~= 0 then
                        local guild = LGuild.getGuildById(v.guildId)
                        if guild then
                            guildchat.sendAndBroNotice(guild, GBConstConfig.gbtip5, enGuildChatNew)
                        end
                    end
                end                
            end
        end
    end

    if oldhp == LActor.getHpMax(monster) and guildId ~= 0 then --守护
        local actor = LActor.getActor(attacker)
        local guild = LGuild.getGuildById(guildId)
        if actor and guild then
            guildchat.sendAndBroNotice(guild, string.format(GBConstConfig.gbtip2, LActor.getName(actor)), enGuildChatNew)
        end
    elseif oldhp == LActor.getHpMax(monster) and guildId == 0 then
        local actor = LActor.getActor(attacker)
        local attackerGuildId = LActor.getGuildId(actor)
        for k,v in pairs(ins.data.bossinfo) do            
            if v.guildId ~= attackerGuildId then
                local guild = LGuild.getGuildById(v.guildId)
                if guild then
                    guildchat.sendAndBroNotice(guild, GBConstConfig.gbtip4, enGuildChatNew)
                end
            end
        end
    end
end

local function addSelfScore(ins, gvar, actor, score)
    local actorid = LActor.getActorId(actor)
    ins.data.selfscore[actorid].score = (ins.data.selfscore[actorid].score or 0) + score
    local myscore = 0
    for i=1, #gvar.selfrank do
        if gvar.selfrank[i].actorid == actorid then
            gvar.selfrank[i].score = gvar.selfrank[i].score + score
            myscore = gvar.selfrank[i].score
        end
    end
    if myscore == 0 then
        local guildId = LActor.getGuildId(actor)
        table.insert(gvar.selfrank, {actorid = actorid, score = score, actorname = LActor.getName(actor), 
        guildname = LGuild.getGuilNameById(guildId), sId = LActor.getServerId(actor), scorestatus = 0, manorindex = ins.data.manorindex})
    end

    --两秒刷新一次排行榜
    local now = System.getNowTime()
    if now >= gvar.sorttime + 2 then
        local firstselfactorid = gvar.selfrank[1].actorid
        table.sort(gvar.selfrank, function(a,b) return a.score > b.score end)
        gvar.sorttime = now
    end
    guildbattlesystem.sendSelfScore(actor)
end

local function onMonsterDie(ins, monster, killHdl)
    local et = LActor.getEntity(killHdl)
    local actor = LActor.getActor(et)
    local guildId = LActor.getGuildId(actor)

    local gvar = guildbattlesystem.getGlobalData()
    if not gvar.fightinfo[guildId] then
        return
    end

    local level = gvar.fightinfo[guildId].level
    local index = gvar.fightinfo[guildId].index    
    local monid = Fuben.getMonsterId(monster)
    local oindex = index % 2 + 1
    local score = 0 

    local guardid1 = GBConstConfig.guardid1[level]
    local guardid2 = GBConstConfig.guardid2[level]
    local bossid = GBConstConfig.bossid[level]
    if bossid == monid then
        score = GBConstConfig.bossscore * getScoreAdd(ins)
        ins.data.bossinfo[monid].reborntime = System.getNowTime() + GBConstConfig.bossreborntime
        ins.data.scores[guildId].bossscore = (ins.data.scores[guildId].bossscore or 0) + score
        LActor.postScriptEventLite(nil, GBConstConfig.bossreborntime * 1000, refreshMonster, ins, monid, level, 0)
        broKillBossInfo(actor, ins)
    elseif guardid1 == monid then
        score = GBConstConfig.killguardscore * getScoreAdd(ins)
        ins.data.scores[guildId].guardscore = (ins.data.scores[guildId].guardscore or 0) + score
        ins.data.bossinfo[monid].reborntime = System.getNowTime() + GBConstConfig.guardreborntime
        LActor.postScriptEventLite(nil, GBConstConfig.guardreborntime * 1000, refreshMonster, ins, monid, level, index)
        broKillGuardInfo(guildId, LActor.getName(actor), ins)
    elseif guardid2 == monid then
        score = GBConstConfig.killguardscore * getScoreAdd(ins)
        ins.data.scores[guildId].guardscore = (ins.data.scores[guildId].guardscore or 0) + score
        ins.data.bossinfo[monid].reborntime = System.getNowTime() + GBConstConfig.guardreborntime
        LActor.postScriptEventLite(nil, GBConstConfig.guardreborntime * 1000, refreshMonster, ins, monid, level, oindex)
        broKillGuardInfo(guildId, LActor.getName(actor), ins)
    else
        score = GBConstConfig.killmonsterscore * getScoreAdd(ins)
        ins.data.scores[guildId].monsterscore = (ins.data.scores[guildId].monsterscore or 0) + score
        local conf = GbRefreshMonsterConfig[monid]
        if conf then
            LActor.postScriptEventLite(nil, conf.refreshTime * 1000, refreshMonster, ins, monid, level, oindex)
        end
    end
    --加积分
    gvar.fightinfo[guildId].score = (gvar.fightinfo[guildId].score or 0) + score
    ins.data.scores[guildId].totalscore = (ins.data.scores[guildId].totalscore or 0) + score
    addSelfScore(ins, gvar, actor, score)

    if ins.data.fighttype == 1 and ins.data.scores[guildId].totalscore >= GBConstConfig.semifinalscore then
        ins:win()
    elseif ins.data.fighttype == 2 and ins.data.scores[guildId].totalscore >= GBConstConfig.finalscore then
        ins:win()
    end
end

function broKillGuardInfo(guildId, actorname, ins)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_GuildBattle)
    LDataPack.writeByte(npack, Protocol.sGuildBattleCmd_KillGuardBro)
    LDataPack.writeInt(npack, guildId)
    LDataPack.writeString(npack, actorname)
    Fuben.sendData(ins.handle, npack)
end

function broKillBossInfo(actor, ins)
    local str = string.format(GBConstConfig.killbossbro, actor and LActor.getName(actor) or "", GBManorIndexConfig[ins.data.manorindex].name, GBConstConfig.bossscore * getScoreAdd(ins))
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_Notice)
    LDataPack.writeByte(npack, Protocol.sNoticeCmd_NoticeSync)
    LDataPack.writeShort(npack, 1)
    LDataPack.writeString(npack, str)
    LDataPack.writeByte(npack, 0)
    LDataPack.writeChar(npack, 0) --超链接id
    LDataPack.writeInt(npack, System.getNowTime())
    Fuben.sendData(ins.handle, npack)
end

function broKillInfo(ins, killactor, beactor, killnum)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_GuildBattle)
    LDataPack.writeByte(npack, Protocol.sGuildBattleCmd_KillNum)
    LDataPack.writeDouble(npack, LActor.getHandle(killactor))
    LDataPack.writeInt(npack, killnum)
    LDataPack.writeChar(npack, killactor and LActor.getJob(killactor) or 0)
    LDataPack.writeString(npack, killactor and LActor.getName(killactor) or "")    
    LDataPack.writeString(npack, beactor and LActor.getName(beactor) or "")
    LDataPack.writeChar(npack, beactor and LActor.getJob(beactor) or 0)
    Fuben.sendData(ins.handle, npack)
end

local function onActorDie(ins, actor, killHdl)
    local actorid = LActor.getActorId(actor)
    if not ins.data.killnum then ins.data.killnum = {} end
    local killnum = ins.data.killnum[actorid]
    local actorpower = LActor.getActorData(actor).total_power
    ins.data.killnum[actorid] = 0
    if killnum ~= 0 then
        broKillInfo(ins, actor, nil, 0)
    end
    
    local score = GBConstConfig.killpeoplescore
    local et = LActor.getEntity(killHdl)
    local killactor = LActor.getActor(et)
    local killname = ""
    if killactor then
        killname = LActor.getName(killactor)
        local killactorid = LActor.getActorId(killactor)
        ins.data.killnum[killactorid] = (ins.data.killnum[killactorid] or 0) + 1
        local killGuildId = LActor.getGuildId(killactor)

        local killactorpower = LActor.getActorData(killactor).total_power
        local diff = math.floor(killactorpower / actorpower) * 100

        --战力差增加额外倍数
        for k,v in ipairs(GBSelfPowerConfig) do
            if v.difference[1] <= diff and v.difference[2] >= diff then
                score = math.floor(score * v.mutli)
                break
            end
        end
        --连杀增加倍数
        for k,v in ipairs(GBMutliKillConfig) do
            if v.diff[1] <= ins.data.killnum[killactorid] and v.diff[2] >= ins.data.killnum[killactorid] then
                score = math.floor(score * v.mutli)
            end
        end
        --终结连杀额外增加倍数
        for k,v in ipairs(GBMutliKillConfig) do
            if v.diff[1] <= killnum and v.diff[2] >= killnum then
                score = score + v.score
            end
        end
        score = score * getScoreAdd(ins)
        broKillInfo(ins, killactor, actor, ins.data.killnum[killactorid])
        ins.data.scores[killGuildId].peoplescore = (ins.data.scores[killGuildId].peoplescore or 0) + score
        ins.data.scores[killGuildId].totalscore = (ins.data.scores[killGuildId].totalscore or 0) + score
        local gvar = guildbattlesystem.getGlobalData()
        addSelfScore(ins, gvar, killactor, score)

        if ins.data.fighttype == 1 and ins.data.scores[killGuildId].totalscore >= GBConstConfig.semifinalscore then
            ins:win()
        elseif ins.data.fighttype == 2 and ins.data.scores[killGuildId].totalscore >= GBConstConfig.finalscore then
            ins:win()
        end

        if killnum >= GBConstConfig.needmutlikill then
            local npack = LDataPack.allocPacket()
            LDataPack.writeByte(npack, Protocol.CMD_GuildBattle)
            LDataPack.writeByte(npack, Protocol.sGuildBattleCmd_EndUpDoubleKill)
            LDataPack.writeString(npack, killname)
            LDataPack.writeString(npack, LActor.getName(actor))
            LDataPack.writeShort(npack, killnum)
            Fuben.sendData(ins.handle, npack)
        end
    else
        local monsterid = Fuben.getMonsterId(et)
        killname = MonstersConfig[monsterid].name
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_KillName)
    if not npack then return end
    LDataPack.writeString(npack, killname)
    LDataPack.flush(npack)    
    
    LActor.postScriptEventLite(actor, GBConstConfig.rebornactor * 1000, rebornActor)
end

function rebornActor(actor)
    local ins = instancesystem.getActorIns(actor)
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then
        LActor.exitFuben(actor)
    end
    local gvar = guildbattlesystem.getGlobalData()    
    local x, y = utils.getSceneEnterByIndex(ins.config.fbid, gvar.fightinfo[guildId].index)
    LActor.reborn(actor, x, y)
    LActor.addSkillEffect(actor, GBConstConfig.rebornbuffer)
end

--更新属性
function updateAttr(actor, ins)
	local var = guildbattlesystem.getActorVar(actor)
	if not var then	return end
	local addAttrs = {}
	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Fuben)
    attr:Reset()
    if ins then
        local actorid = LActor.getActorId(actor)
        if ins.data.inspiretimes[actorid] > 0 then
            for k,v in ipairs(GBInspireConfig[1].attrs) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + (v.value * ins.data.inspiretimes[actorid])
            end
        end
        local guildId = LActor.getGuildId(actor)
        if #ins.data.gbInfo[guildId].inspirePeoples > 0 then
            for k,v in ipairs(GBInspireConfig[2].attrs) do
                addAttrs[v.type] = (addAttrs[v.type] or 0) + (v.value * #ins.data.gbInfo[guildId].inspirePeoples)
            end
        end
    end
    
    for k, v in pairs(addAttrs) do
        attr:Set(k, v)
    end	
	LActor.reCalcAttr(actor)
end

--鼓舞
local function handleInspire(actor, pack)
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then return end
    local ins = instancesystem.getActorIns(actor)
    if not ins.data.gbInfo or not ins.data.gbInfo[guildId] then return end
    local otherGuildId = 0
    for k in pairs(ins.data.gbInfo) do
        if k ~= guildId then
            otherGuildId = k
        end
    end
    local type = LDataPack.readChar(pack)
    local config = GBInspireConfig[type]
    if not config then return end
    local var = guildbattlesystem.getActorVar(actor)
    local actorid = LActor.getActorId(actor)
    if type == 1 then                
        if ins.data.inspiretimes[actorid] >= config.count then
            return
        end
        local inspairecost = config.needyuanbao[ins.data.inspiretimes[actorid] + 1]
        if not actoritem.checkItem(actor, inspairecost.id, inspairecost.count) then
            return
        end
        actoritem.reduceItem(actor, inspairecost.id, inspairecost.count, "guild battle inspire")
        ins.data.inspiretimes[actorid] = ins.data.inspiretimes[actorid] + 1
    else
        if #ins.data.gbInfo[guildId].inspirePeoples >= config.count then
            return
        end

        local inspairecost = config.needyuanbao[#ins.data.gbInfo[guildId].inspirePeoples + 1]
        if not actoritem.checkItem(actor, inspairecost.id, inspairecost.count) then
            return
        end
        actoritem.reduceItem(actor, inspairecost.id, inspairecost.count, "guild battle inspire")
        ins.data.gbInfo[guildId].inspirePeoples[#ins.data.gbInfo[guildId].inspirePeoples + 1] = LActor.getName(actor)

        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, Protocol.CMD_GuildBattle)
        LDataPack.writeByte(npack, Protocol.cGuildBattleCmd_GuildInspireBro)
        LDataPack.writeInt(npack, guildId)
        LDataPack.writeString(npack, LActor.getName(actor))
        LDataPack.writeChar(npack, #ins.data.gbInfo[guildId].inspirePeoples)
        for k,v in ipairs(ins.data.gbInfo[guildId].inspirePeoples) do
            LDataPack.writeString(npack, v)
        end
        Fuben.sendData(ins.handle, npack)
    end
    updateAttr(actor, ins)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_InspireRet)
    if not npack then return end
    LDataPack.writeChar(npack, type)
    LDataPack.writeChar(npack, ins.data.inspiretimes[actorid])
    LDataPack.writeChar(npack, #ins.data.gbInfo[guildId].inspirePeoples)
    for k,v in ipairs(ins.data.gbInfo[guildId].inspirePeoples) do
        LDataPack.writeString(npack, v)
    end
    LDataPack.writeChar(npack, #ins.data.gbInfo[otherGuildId].inspirePeoples)
    for k,v in ipairs(ins.data.gbInfo[otherGuildId].inspirePeoples) do
        LDataPack.writeString(npack, v)
    end
    LDataPack.flush(npack)
end

local function handleDetailScore(actor, pack)
    local ins = instancesystem.getActorIns(actor)
    if not ins.data.scores then return end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SendDetailScore)
    if not npack then return end
    LDataPack.writeChar(npack, 2)
    for k,v in pairs(ins.data.scores) do
        LDataPack.writeInt(npack, k)
        LDataPack.writeString(npack, LGuild.getGuilNameById(k))
        LDataPack.writeInt(npack, v.totalscore or 0)
        LDataPack.writeInt(npack, v.monsterscore or 0)
        LDataPack.writeInt(npack, v.peoplescore or 0)
        LDataPack.writeInt(npack, v.guardscore or 0)
        LDataPack.writeInt(npack, v.bossscore or 0)
    end    
    LDataPack.flush(npack)
end

local function init()
    if not System.isBattleSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_Inspire, handleInspire)
    netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetDetailScore, handleDetailScore)
    --注册相关回调
    for _, fbId in pairs(GBConstConfig.fbId) do
        insevent.registerInstanceWin(fbId, onWin)
        insevent.registerInstanceLose(fbId, onWin)
        insevent.registerInstanceEnter(fbId, onEnterFb)
        insevent.registerInstanceExit(fbId, onExitFb)
        insevent.registerInstanceOffline(fbId, onOffline)
        insevent.registerInstanceMonsterDie(fbId, onMonsterDie)
        insevent.registerInstanceActorDie(fbId, onActorDie)
        insevent.registerInstanceMonsterCreate(fbId, onMonsterCreate)
        insevent.registerInstanceMonsterDamage(fbId, onBossDamage)
        --insevent.registerInstanceMonsterAllDie(fbId, onMonsterAllDie)
        insevent.registerInstanceEnterBefore(fbId, onBeforeEnterFb)
        -- insevent.registerInstanceLose(fbId, onLose)
        insevent.registerInstanceEnerBossArea(fbId, onEnerBossArea)
        --insevent.registerInstanceExitBossArea(fbId, onExitBossArea)
    end
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers

function gmCmdHandlers.gbscore(actor, args)
    local score = tonumber(args[1])
    local ins = instancesystem.getActorIns(actor)
    local guildId = LActor.getGuildId(actor)
    ins.data.scores[guildId].totalscore = score

    if ins.data.fighttype == 1 and ins.data.scores[guildId].totalscore >= GBConstConfig.semifinalscore then
        ins:win()
    elseif ins.data.fighttype == 2 and ins.data.scores[guildId].totalscore >= GBConstConfig.finalscore then
        ins:win()
    end
    broFubenInfo(nil, ins)
end












