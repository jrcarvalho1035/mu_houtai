--魔龙之城
module("molong", package.seeall)

MOLONG_TEAM = MOLONG_TEAM or {}


function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
    if not var.molong then 
        var.molong = { 
            fightcount = 0, --今日挑战次数
            helpcount = 0, --今日帮助次数
            atkAdd = 0, 	--攻击加成
            inspiretimes = 0, --鼓舞次数
            buytimes = 0,    --购买挑战次数
        }
    end
    if not var.molong.infuben_hfuben then var.molong.infuben_hfuben = 0 end
    return var.molong 
end


--邀请玩家
function c2sMolongInvite(actor, pack)
    local var = getActorVar(actor)
    local hfuben = var.infuben_hfuben
    if not MOLONG_TEAM[hfuben] or MOLONG_TEAM[hfuben].starttime ~= 0 then
        return
    end
    local type = LDataPack.readChar(pack)
    sendInvite(actor, type, hfuben)
end

function getConfig(actor)
    local level = LActor.getLevel(actor)
    for k,v in ipairs(MolongFubenConfig) do
        if v.level > level then
            return MolongFubenConfig[k-1]            
        end
    end
    if level > #MolongFubenConfig then
        return MolongFubenConfig[#MolongFubenConfig]
    end
end

--更新属性
function updateAttr(actor)
    local attr = LActor.getActorSystemAttrs(actor, AttrActorSysId_Fuben)
	attr:Reset()
	local var = getActorVar(actor)
	if not var then	return end
	if var.atkAdd > 0 then
		attr:Add(Attribute.atAtkPer, var.atkAdd)
	end

	LActor.reCalcAttr(actor)
end

function initGlobal(hfuben, actorid, conf)
    MOLONG_TEAM[hfuben] = {}
    MOLONG_TEAM[hfuben].isInvite = 1
    MOLONG_TEAM[hfuben].entertime = System.getNowTime()
    MOLONG_TEAM[hfuben].starttime = 0
    MOLONG_TEAM[hfuben].refreshtime = 0
    MOLONG_TEAM[hfuben].alivecount = 0
    MOLONG_TEAM[hfuben].extratime = 0 --额外时间，如果中途退出，则获得最小奖励
    MOLONG_TEAM[hfuben].conf = conf
    MOLONG_TEAM[hfuben].usetimes = 0
    MOLONG_TEAM[hfuben].actors = {}
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors + 1] = {}
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].actorid = actorid
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].damage = 0
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].isinvite = 1
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].isclone = 0
end

--申请进入
function c2sMolongFight(actor, pack)    
    local hfuben = LDataPack.readUInt(pack)  

    local var = getActorVar(actor)
    if hfuben == 0 then
        local conf = getConfig(actor)
        if LActor.getLevel(actor) < conf.level then return end
        if var.fightcount >= MolongCommonConfig.fightcount + var.buytimes then return end
        local actorid = LActor.getActorId(actor)
        if MOLONG_TEAM[hfuben] then return end        
        local x,y = utils.getSceneEnterCoor(conf.fbId)
        local hfuben = instancesystem.createFuBen(conf.fbId)
        local ins = instancesystem.getInsByHdl(hfuben)
        var.infuben_hfuben = hfuben
        var.inspiretimes = 0
        var.atkAdd = 0
        initGlobal(hfuben, actorid, conf)
        LActor.enterFuBen(actor, hfuben, 0, x, y)

        sendEnterResult(actor, 4)
        actorcommon.setTeamId(actor, 1)

        MOLONG_TEAM[hfuben].team_eid = LActor.postScriptEventLite(nil, MolongCommonConfig.teamcd*1000, beforeStart, hfuben)
        sendFubenInfo(nil, hfuben)
    else
        if var.fightcount >= MolongCommonConfig.fightcount + var.buytimes and var.helpcount >= MolongCommonConfig.helpcount then return end
        if not MOLONG_TEAM[hfuben]  then
            sendEnterResult(actor, 2)
            return
        end
        if LActor.getLevel(actor) < MOLONG_TEAM[hfuben].conf.level then
            sendEnterResult(actor, 5)
            return
        end

        if MOLONG_TEAM[hfuben].starttime ~= 0 or MOLONG_TEAM[hfuben].refreshtime ~= 0 or #MOLONG_TEAM[hfuben].actors >= 3 then
            sendEnterResult(actor, 3)
            return
        end
        for i=1, #MOLONG_TEAM[hfuben].actors do
            if MOLONG_TEAM[hfuben].actors[i].actorid == LActor.getActorId(actor) then
                return
            end
        end
        actorcommon.setTeamId(actor, 1)
        sendEnterResult(actor, 4)
        var.infuben_hfuben = hfuben
        var.inspiretimes = 0
        var.atkAdd = 0
        
        MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors + 1] = {}
        MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].actorid = LActor.getActorId(actor)
        MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].damage = 0
        MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].isclone = 0
        if var.fightcount < MolongCommonConfig.fightcount + var.buytimes then
            MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].isinvite = 1 --挑战者奖励
        else
            MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].isinvite = 2 --助战者奖励
        end
        local x,y = utils.getSceneEnterCoor(MOLONG_TEAM[hfuben].conf.fbId)
        LActor.enterFuBen(actor, hfuben, 0, x, y)
        if #MOLONG_TEAM[hfuben].actors == 3 then
            LActor.cancelScriptEvent(nil, MOLONG_TEAM[hfuben].team_eid)
            MOLONG_TEAM[hfuben].entertime = 0
            MOLONG_TEAM[hfuben].starttime = System.getNowTime()
            beforeStart(nil, hfuben)
            return
        end        
    end
    sendFightTimes(actor)
end

--鼓舞
function c2sMolongInspire(actor, pack)
    local type = LDataPack.readShort(pack)    
    local var = getActorVar(actor)
    local hfuben = LActor.getFubenHandle(actor)
    
    if not MOLONG_TEAM[hfuben] or MOLONG_TEAM[hfuben].starttime == 0 then return end
    
	local conf = MolongInspireConfig[type]

	local temp = {} --参与增加的属性
	for k, v in pairs(conf.attrs) do
		if var.atkAdd < conf.attMax then
			table.insert(temp, v)
		end
    end    
	if #temp <= 0 then return false end --已加成到最大值

	--鼓舞消耗
    local items = type==1 and MOLONG_TEAM[hfuben].conf.goldSp or MOLONG_TEAM[hfuben].conf.diamondSp
    if not actoritem.checkItems(actor, items) then
        return 
    end
    actoritem.reduceItems(actor, items, "molong inspire in")

    --加成属性
    local v = temp[math.random(1, #temp)]
    var.atkAdd = var.atkAdd + v.value
    var.inspiretimes = var.inspiretimes + 1
    updateAttr(actor)

	s2cXueseInspire(actor, type)
end

--购买挑战次数
function c2sMolongBuy(actor)
    local vip = LActor.getVipLevel(actor)
    local var = getActorVar(actor)
    if var.buytimes >= VipConfig[vip].molongbuy then return end
    if not actoritem.checkItem(actor, NumericType_YuanBao, MolongCommonConfig.needdiamond[var.buytimes + 1]) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, MolongCommonConfig.needdiamond[var.buytimes + 1], "buy molong fightTimes")
    
    var.buytimes = var.buytimes + 1
    sendFightTimes(actor)
end

--副本开始刷怪
function startFuben(_, hfuben)
    if not MOLONG_TEAM[hfuben] then return end
    local ins = instancesystem.getInsByHdl(hfuben)
    refreshmonsterapi.init(ins, true)
    local now = System.getNowTime()
    MOLONG_TEAM[hfuben].refreshtime = now
    ins:setEndTime(now + FubenConfig[MOLONG_TEAM[hfuben].conf.fbId].totalTime + 30)
    local actors = Fuben.getAllActor(hfuben)
    if not actors then return end
    for i=1, #actors do
        sendBeforeEnter(actors[i])
    end
    sendFubenInfo(nil, hfuben, true)
end

--造成伤害
local function onDamage(ins, monster, value, attacker, res)
    local hfuben = ins.handle
    local attacker_type = LActor.getEntityType(attacker)
    if EntityType_RoleClone == attacker_type or EntityType_RoleSuperClone == attacker_type then
        local actorClone = LActor.getActorClone(attacker)
        local selfactorid = LActor.getActorIdClone(actorClone)   
        for i=1, #MOLONG_TEAM[hfuben].actors do            
            if MOLONG_TEAM[hfuben].actors[i].actorid == selfactorid then
                MOLONG_TEAM[hfuben].actors[i].damage = MOLONG_TEAM[hfuben].actors[i].damage + value
                break
            end
        end
    elseif EntityType_Role == attacker_type or EntityType_RoleSuper == attacker_type then
        local actor = LActor.getActor(attacker)
        local selfactorid = LActor.getActorId(actor)
        for i=1, #MOLONG_TEAM[hfuben].actors do
            if MOLONG_TEAM[hfuben].actors[i].actorid == selfactorid then
                MOLONG_TEAM[hfuben].actors[i].damage = MOLONG_TEAM[hfuben].actors[i].damage + value
                break
            end
        end
    end
end

function onMonsterAllDie(ins)
    if ins.refresh_monster_idx >= MolongCommonConfig.monstermaxcount then --副本怪物死完
        ins:win()
    end
end

local function onMonsterDie(ins, mon, killHdl)
    local hfuben = ins.handle
    if ins.is_end then return end
end

function getRewardIndex(conf, usetime)
    for k,v in ipairs(conf.grade) do
        if usetime >= v then
            return k
        end
    end
    if usetime < conf.grade[#conf.grade] then
        return #conf.grade
    end
    return 1
end

local function onLose(ins)
    local hfuben = ins.handle
    MOLONG_TEAM[hfuben] = nil
end

--结算
local function onWin(ins)
    local hfuben = ins.handle
    sendFubenInfo(nil, hfuben, true)
    local conf = MOLONG_TEAM[hfuben].conf
    local id = MolongCommonConfig.itemid
    
    for k, v in ipairs(MOLONG_TEAM[hfuben].actors) do
        if v.isclone == 0 then
            local count = 1
            if v.isinvite == 1 then        
                count = conf.rewardcount[getRewardIndex(conf, System.getNowTime() - MOLONG_TEAM[hfuben].refreshtime + MOLONG_TEAM[hfuben].extratime)]
            else
                count = conf.helpcount[getRewardIndex(conf, System.getNowTime() - MOLONG_TEAM[hfuben].refreshtime + MOLONG_TEAM[hfuben].extratime)]
            end
            count = count * v.usetimes
            local actor = LActor.getActorById(v.actorid)
            if actor and v.isleave ~= 1 then   
                local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_MLResult)
                LDataPack.writeShort(pack, System.getNowTime() - MOLONG_TEAM[hfuben].refreshtime)
                LDataPack.writeChar(pack, 1)                
                LDataPack.writeInt(pack, id)
                LDataPack.writeInt(pack, count)
                LDataPack.writeInt(pack, conf.fbId)
                LDataPack.flush(pack)
                
                actoritem.addItem(actor, id, count, "molong reward")
            else
                sendMail(v.actorid, id, count)
            end
        end
    end
    MOLONG_TEAM[hfuben] = nil
end

function sendMail(actorid, id, count)
    local mail_data = {}
    mail_data.head       = MolongCommonConfig.mailtitle
    mail_data.context    = MolongCommonConfig.mailcontent
    mail_data.tAwardList = {{id = id, count = count}}
    mailsystem.sendMailById(actorid, mail_data)
end

--进入副本
local function onEnterFb(ins, actor, islogin)
    local hfuben = ins.handle
    if not MOLONG_TEAM[hfuben] then 
        LActor.exitFuben(actor)
        return
    end
    updateAttr(actor)
    sendTeamCD(actor)
    sendFubenInfo(nil, hfuben, true)
    local pos = MolongCommonConfig.pos[#MOLONG_TEAM[hfuben].actors]
    local roleCount = LActor.getRoleCount(actor)
	for i = 0, roleCount - 1 do
		local role = LActor.getRole(actor, i)
        LActor.setEntityScenePos(role, pos[i+1][1], pos[i+1][2])        
    end
end

local function onBeforeEnterFb(ins, actor, islogin)
    local hfuben = ins.handle
    if not MOLONG_TEAM[hfuben] then 
        return
    end
    sendBeforeEnter(actor)
    for k,v in ipairs(MOLONG_TEAM[hfuben].actors) do
        if v.actorid == LActor.getActorId(actor) then
            v.isleave = 0
        end
    end
    actorcommon.setTeamId(actor, 1)
    actorevent.onEvent(actor, aeNotifyFacade, -1)
end

--离线处理
local function onOffline(ins, actor)
    actorcommon.setTeamId(actor, 0)
    local hfuben = ins.handle    
    if not MOLONG_TEAM[hfuben] then return end

    if MOLONG_TEAM[hfuben].starttime == 0 then --副本未开始
        local var = getActorVar(actor)
        var.infuben_hfuben = 0
        local actors = Fuben.getAllActor(hfuben)
        if not actors or #actors <= 1 then
            ins:lose()
        else
            local selfid = LActor.getActorId(actor)
            for i=1, #MOLONG_TEAM[hfuben].actors do
                if selfid == MOLONG_TEAM[hfuben].actors[i].actorid then
                    table.remove(MOLONG_TEAM[hfuben].actors, i)
                    break
                end
            end            
        end
        staticfuben.returnToGuajiFuben(actor)
        sendFubenInfo(nil, hfuben, true)
    else
        local selfid = LActor.getActorId(actor)
        for i=1, #MOLONG_TEAM[hfuben].actors do
            if selfid == MOLONG_TEAM[hfuben].actors[i].actorid then
                MOLONG_TEAM[hfuben].actors[i].isleave = 1
                break
            end
        end
        local actors = Fuben.getAllActor(hfuben)
        if not actors or #actors <= 1 then
            MOLONG_TEAM[hfuben].extratime = 9999
            ins:win()
        end        
    end    
end

--退出副本处理
local function onExitFb(ins, actor)
    actorcommon.setTeamId(actor, 0)
    local var = getActorVar(actor)
    var.infuben_hfuben = 0
    var.inspiretimes = 0
    var.atkAdd = 0
    updateAttr(actor)
    local hfuben = ins.handle

    if not MOLONG_TEAM[hfuben] then return end
    if MOLONG_TEAM[hfuben].starttime == 0 then --副本未开始        
        local actors = Fuben.getAllActor(hfuben)
        if not actors or #actors <= 1 then
            ins:lose()
        else
            local selfid = LActor.getActorId(actor)
            for i=1, #MOLONG_TEAM[hfuben].actors do
                if selfid == MOLONG_TEAM[hfuben].actors[i].actorid then
                    table.remove(MOLONG_TEAM[hfuben].actors, i)
                    break
                end
            end
            sendFubenInfo(nil, hfuben, true)
        end
    else
        local selfid = LActor.getActorId(actor)
        for i=1, #MOLONG_TEAM[hfuben].actors do
            if selfid == MOLONG_TEAM[hfuben].actors[i].actorid then
                MOLONG_TEAM[hfuben].actors[i].isleave = 1
                break
            end
        end
        local actors = Fuben.getAllActor(hfuben)
        if not actors or #actors <= 1 then
            MOLONG_TEAM[hfuben].extratime = 9999
            ins:win()
        end
        --s2cXueseInspireClear(actor)
    end
end

--创建镜像玩家配打
function setMirror(hfuben, actorData)
    local ins = instancesystem.getInsByHdl(hfuben)
    local hScene = ins.scene_list[1]
    
    local roleCloneDatas, damonData, roleSuperData = actorcommon.getCloneData(actorData.actor_id)
    if roleCloneDatas then
        for i = 1, #roleCloneDatas do
            local roleCloneData = roleCloneDatas[i]
            roleCloneData.ai = MolongCommonConfig.ai[roleCloneData.job]
            roleCloneData.teamId = 1
        end
        if damonData then
            damonData.ai = FubenConstConfig.damonAi
        end
    else
        return false  ---找不到玩家
    end
    local roleCloneDataCount = #roleCloneDatas
    if roleCloneDataCount < 0 or roleCloneDataCount > MAX_ROLE then
        return
    end

    if damonData then
        local damonConf = DamonConfig[damonData.id]
        if damonConf then
            damonData.speed = damonConf.MvSpeed
        end
    end

    if roleSuperData then 
        roleSuperData.randChangeTime = math.random(MolongCommonConfig.randChangeTime[1],MolongCommonConfig.randChangeTime[2])
        roleSuperData.aiId = MolongCommonConfig.roleSuperAi
    end
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors + 1] = {}
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].actorid = actorData.actor_id
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].damage = 0
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].isclone = 1
    local pos = MolongCommonConfig.pos[#MOLONG_TEAM[hfuben].actors]
    local actorClone = LActor.createActorCloneWithData(actorData.actor_id, hScene, pos[1][1], pos[1][2], roleCloneDatas, damonData, roleSuperData)
    LActor.setCamp(actorClone, CampType_Player)--设置阵营为普通模式
    --设置进入位置
    local roleCloneCount = LActor.getRoleCount(actorClone)
	for i = 0, roleCloneCount - 1 do
		local roleClone = LActor.getRole(actorClone,i)
		if roleClone then
            LActor.setEntityScenePos(roleClone, pos[i+1][1], pos[i+1][2])
		end
    end
    
    if #MOLONG_TEAM[hfuben].actors == 3 then
        return true
    end
    return false
end

function isInFuben(actorData, hfuben)
    for k,v in ipairs(MOLONG_TEAM[hfuben].actors) do
        if actorData.actor_id == v.actorid then
            return true
        end
    end
    return false
end

function setRankMirror(rank, hfuben, power, rankindex, percent)
    for i=1, rankindex+1000, 2 do
        local actorData = Ranking.getSDataFromIdx(rank, i - 1)
        if actorData and not isInFuben(actorData, hfuben) and actorData.total_power < (power * percent / 100)  then
            if setMirror(hfuben, actorData) then
                return
            end
        end
    end
    if #MOLONG_TEAM[hfuben].actors < 3 then
        for i=1, 3-#MOLONG_TEAM[hfuben].actors do
            local actorData = Ranking.getSDataFromIdx(rank, rankindex + i)
            if actorData and not isInFuben(actorData, hfuben) then
                setMirror(hfuben, actorData)
            end
        end
    end
    if #MOLONG_TEAM[hfuben].actors < 3 then
        for i=1, 3-#MOLONG_TEAM[hfuben].actors do
            local actorData = Ranking.getSDataFromIdx(rank, rankindex - i - 1)
            if actorData and not isInFuben(actorData, hfuben) then
                setMirror(hfuben, actorData)
            end
        end
    end
end

--副本开始前处理
function beforeStart(_, hfuben)
    if not MOLONG_TEAM[hfuben] then return end
    local selfdata = LActor.getActorDataById(MOLONG_TEAM[hfuben].actors[1].actorid)
    local total_power = selfdata.total_power

    --添加镜像
    if #MOLONG_TEAM[hfuben].actors < 3 then
        local rank = Ranking.getStaticRank(RankingType_Power)
        if rank then
            local rankindex = Ranking.getSRIndexFromId(rank, MOLONG_TEAM[hfuben].actors[1].actorid)
            if #MOLONG_TEAM[hfuben].actors == 2 then
                local selfdata1 = LActor.getActorDataById(MOLONG_TEAM[hfuben].actors[2].actorid)
                rankindex = math.max(rankindex, Ranking.getSRIndexFromId(rank, MOLONG_TEAM[hfuben].actors[2].actorid))
                total_power = math.floor((total_power + selfdata1.total_power)/2)
            end

            local conf = MOLONG_TEAM[hfuben].conf
            for k,v in ipairs(MolongMatchConfig) do
                if total_power >= conf.needpower * v.spowerper[1] / 100 and total_power <= conf.needpower * v.spowerper[2] / 100 then
                    setRankMirror(rank, hfuben, total_power, rankindex, v.needpowerper)
                end
            end
        end
    end
    
    for k,v in ipairs(MOLONG_TEAM[hfuben].actors) do        
        if v.isclone == 0 then
            local actor = LActor.getActorById(v.actorid)
            local var = getActorVar(actor)
            if v.isinvite == 1 then
                v.usetimes = math.min(neigua.checkOpenNeigua(actor, fubencommon.molong), MolongCommonConfig.fightcount + var.buytimes - var.fightcount)
                var.fightcount = var.fightcount + v.usetimes
                actorevent.onEvent(actor, aeEnterMolong, v.usetimes)
            else
                v.usetimes = math.min(neigua.checkOpenNeigua(actor, fubencommon.molong), MolongCommonConfig.helpcount - var.helpcount)
                var.helpcount = var.helpcount + v.usetimes
            end
            sendFightTimes(actor)
        end
    end

    MOLONG_TEAM[hfuben].starttime = System.getNowTime()    
    MOLONG_TEAM[hfuben].alivecount = #MOLONG_TEAM[hfuben].actors
    sendStartCD(hfuben)
    sendFubenInfo(nil, hfuben, true)
    LActor.postScriptEventLite(nil, MolongCommonConfig.startcd*1000, startFuben, hfuben)
end

--副本进入结果
function sendEnterResult(actor, result)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_MLFight)
    LDataPack.writeChar(pack, result)
    LDataPack.flush(pack)
end

--发送邀请
function sendInvite(actor, type, hfuben)
    local guild
    if type ~= 1 then
        guild = LActor.getGuildPtr(actor)
        if not guild then return end
    end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_AllFuben2)
    LDataPack.writeByte(pack, Protocol.sFubenCmd_MLInvite)
    local conf = getConfig(actor)
    LDataPack.writeChar(pack, type)
    LDataPack.writeUInt(pack, hfuben)
    LDataPack.writeString(pack, LActor.getName(actor))
    LDataPack.writeInt(pack, MOLONG_TEAM[hfuben].conf.fbId)
    if type == 1 then
        System.broadcastData(pack)
    else        
        LGuild.broadcastData(guild, pack)
    end   
end

--副本内信息
function sendFubenInfo(_, hfuben, notTimer)
    if not MOLONG_TEAM[hfuben] then return end    
    local conf = MOLONG_TEAM[hfuben].conf
    local ins = instancesystem.getInsByHdl(hfuben)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_AllFuben2)
    LDataPack.writeByte(pack, Protocol.sFubenCmd_MLInfo)
    LDataPack.writeChar(pack, ins.refresh_monster_idx)
    LDataPack.writeInt(pack, ins.kill_monster_cnt)
    LDataPack.writeChar(pack, #MOLONG_TEAM[hfuben].actors)
    for i=1, #MOLONG_TEAM[hfuben].actors do
        LDataPack.writeDouble(pack, MOLONG_TEAM[hfuben].actors[i].damage)
        local roleCloneData = actorcommon.getCloneData(MOLONG_TEAM[hfuben].actors[i].actorid)
        LDataPack.writeString(pack, roleCloneData[1].name)
        LDataPack.writeChar(pack, roleCloneData[1].job)
    end
    LDataPack.writeShort(pack, MOLONG_TEAM[hfuben].refreshtime == 0 and -1 or MOLONG_TEAM[hfuben].refreshtime + FubenConfig[conf.fbId].totalTime - System.getNowTime())

    Fuben.sendData(hfuben, pack)
    if not notTimer then
        LActor.postScriptEventLite(nil, 2*1000, sendFubenInfo, hfuben)
    end
end

--玩家副本开始剩余时间
function sendStartCD(hfuben)
	local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_AllFuben2)
    LDataPack.writeByte(pack, Protocol.sFubenCmd_MLStartCD)
    local remaintime = MolongCommonConfig.startcd - (System.getNowTime() - MOLONG_TEAM[hfuben].starttime)
    LDataPack.writeShort(pack, remaintime > 0 and remaintime or 0)
    Fuben.sendData(hfuben, pack)
end

--玩家组队剩余时间
function sendTeamCD(actor)
    local hfuben = LActor.getFubenHandle(actor)
    if not MOLONG_TEAM[hfuben] then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_MLTeamCD)
    local remaintime = MolongCommonConfig.teamcd - (System.getNowTime() - MOLONG_TEAM[hfuben].entertime)
    LDataPack.writeShort(pack, remaintime > 0 and remaintime or 0)
    LDataPack.writeByte(pack, LActor.getActorId(actor) == MOLONG_TEAM[hfuben].actors[1].actorid and 1 or 2)
    LDataPack.flush(pack)
end

--玩家挑战信息
function sendFightTimes(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_MLFightTimes)
    local conf = getConfig(actor)
    local hfuben = var.infuben_hfuben
    if MOLONG_TEAM[hfuben] then
        conf = MOLONG_TEAM[hfuben].conf
    end
    LDataPack.writeChar(pack, var.fightcount)
    LDataPack.writeChar(pack, var.buytimes)
    LDataPack.writeChar(pack, MolongCommonConfig.helpcount - var.helpcount)
	LDataPack.flush(pack)
end

function getFubenInvite(hfuben, actorid)
    for k,v in ipairs(MOLONG_TEAM[hfuben].actors) do
        if v.actorid == actorid then
            return v.isinvite
        end
    end
end

--魔龙之城进入副本前信息
function sendBeforeEnter(actor)
    local var = getActorVar(actor)    
    local hfuben = var.infuben_hfuben
    if not MOLONG_TEAM[hfuben] or not MOLONG_TEAM[hfuben].conf then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_MLBeforEnter)
    LDataPack.writeChar(pack, getFubenInvite(hfuben, LActor.getActorId(actor)))
    local conf = MOLONG_TEAM[hfuben].conf
    local refreshtime = MOLONG_TEAM[hfuben].refreshtime
    LDataPack.writeShort(pack, refreshtime == 0 and - 1 or refreshtime + FubenConfig[conf.fbId].totalTime - System.getNowTime())
    LDataPack.writeInt(pack, conf.fbId)
	LDataPack.flush(pack)
end


--魔龙之城鼓舞信息
function s2cXueseInspire(actor, type)
    local var = getActorVar(actor)
    if var.inspiretimes <= 0 then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_MLInspire)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.atkAdd)
	LDataPack.writeChar(pack, type)
	LDataPack.writeByte(pack, var.inspiretimes)
	LDataPack.flush(pack)
end

--魔龙之城通知客户端清鼓舞信息
function s2cXueseInspireClear(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_MLInspire)
	if pack == nil then return end
	LDataPack.writeInt(pack, 0)
	LDataPack.writeChar(pack, 1)
	LDataPack.writeByte(pack, 0)
	LDataPack.flush(pack)
end

function onLogin(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.molong) then return end
    sendFightTimes(actor)
    s2cXueseInspire(actor, 1)
    local var = getActorVar(actor)
    if var.infuben_hfuben ~= 0 and not MOLONG_TEAM[var.infuben_hfuben] then
        var.infuben_hfuben = 0
        --staticfuben.returnToGuajiFuben(actor)
    end
end

local function onLevelUp(actor, level, oldLevel)
    local lv = actorexp.getLimitLevel(nil, actorexp.LimitTp.molong)
	if lv > oldLevel and lv <= level then
		sendFightTimes(actor)
	end
end

function onNewDay(actor, login)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.molong) then return end
    local var = getActorVar(actor)
    var.fightcount = 0
    var.helpcount = 0
    var.buytimes = 0
    if not login then
        sendFightTimes(actor)
    end
end

local function init()
	if System.isBattleSrv() then return end
	actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    actorevent.reg(aeLevel, onLevelUp)
	
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_MLInvite, c2sMolongInvite)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_MLFight, c2sMolongFight)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_MLInspire, c2sMolongInspire)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_MLBuyTimes, c2sMolongBuy)
    

	--注册相关回调
    for _, conf in pairs(MolongFubenConfig) do
        insevent.registerInstanceWin(conf.fbId, onWin)
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceExit(conf.fbId, onExitFb)
		insevent.registerInstanceOffline(conf.fbId, onOffline)
        insevent.registerInstanceMonsterDamage(conf.fbId, onDamage)
        insevent.registerInstanceMonsterAllDie(conf.fbId, onMonsterAllDie)
        insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
        insevent.registerInstanceEnterBefore(conf.fbId, onBeforeEnterFb)
        insevent.registerInstanceLose(conf.fbId, onLose)
	end
end
table.insert(InitFnTable, init)
