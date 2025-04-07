--圣魂神殿

module("shenghun", package.seeall)

SHENGHUN_TEAM = SHENGHUN_TEAM or {}

function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
    if not var.shenghun then 
        var.shenghun = {
            fightcount = 0, --今日挑战次数
            helpcount = 0, --今日帮助次数
            entercount = 0, --进入副本次数（用来获取不同奖励）
            infuben_hfuben = 0, --进入的副本
            atkAdd = 0, 	--攻击加成
            inspiretimes = 0, --鼓舞次数
            buytimes = 0,    --购买挑战次数
        }
    end
    return var.shenghun 
end


--邀请玩家
function c2sShenghunInvite(actor, pack)
    local var = getActorVar(actor)
    local hfuben = var.infuben_hfuben
    if hfuben == 0 or not SHENGHUN_TEAM[hfuben] or SHENGHUN_TEAM[hfuben].starttime ~= 0 then
        return
    end
    local type = LDataPack.readChar(pack)
    sendInvite(actor, type, hfuben)
end

function getConfig(actor)
    local level = LActor.getLevel(actor)
    for k,v in ipairs(ShenghunFubenConfig) do
        if v.level > level then
            return ShenghunFubenConfig[k-1]
        end
    end
    if level > #ShenghunFubenConfig then
        return ShenghunFubenConfig[#ShenghunFubenConfig]
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
    SHENGHUN_TEAM[hfuben] = {}
    SHENGHUN_TEAM[hfuben].entertime = System.getNowTime()
    SHENGHUN_TEAM[hfuben].starttime = 0
    SHENGHUN_TEAM[hfuben].refreshtime = 0
    SHENGHUN_TEAM[hfuben].killcount = 0
    SHENGHUN_TEAM[hfuben].conf = conf
    SHENGHUN_TEAM[hfuben].usetimes = usetimes
    SHENGHUN_TEAM[hfuben].angelHpPer = 100
    SHENGHUN_TEAM[hfuben].actors = {}
    SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors + 1] = {}
    SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].actorid = actorid
    SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].isinvite = 1
    SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].damage = 0
    SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].entercount = 0
    SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].isclone = 0
end

--申请进入
function c2sShenghunFight(actor, pack)    
    local hfuben = LDataPack.readUInt(pack)
    local var = getActorVar(actor)
    if hfuben == 0 then
        local conf = getConfig(actor)
        if var.fightcount >= ShenghunCommonConfig.fightcount + var.buytimes then return end
        local actorid = LActor.getActorId(actor)

        local x,y = utils.getSceneEnterCoor(conf.fbId)
        local hfuben = instancesystem.createFuBen(conf.fbId)
        local ins = instancesystem.getInsByHdl(hfuben)
        var.infuben_hfuben = hfuben
        var.inspiretimes = 0
        var.atkAdd = 0
        initGlobal(hfuben, actorid, conf)
        LActor.enterFuBen(actor, hfuben, 0, x, y)
        --刷出大天使        
        SHENGHUN_TEAM[hfuben].angel = Fuben.createMonster(ins.scene_list[1], conf.guard, conf.guardpos[1], conf.guardpos[2])
        LActor.addSkillEffect(SHENGHUN_TEAM[hfuben].angel, ShenghunCommonConfig.buffer)
  
        SHENGHUN_TEAM[hfuben].team_eid = LActor.postScriptEventLite(nil, ShenghunCommonConfig.teamcd*1000, beforeStart, hfuben)
        sendFubenInfo(nil, hfuben)
    else
        if var.fightcount >= ShenghunCommonConfig.fightcount + var.buytimes and var.helpcount >= ShenghunCommonConfig.helpcount then return end
        if not SHENGHUN_TEAM[hfuben]  then
            sendEnterResult(actor, 2)
            return
        end
        if LActor.getLevel(actor) < SHENGHUN_TEAM[hfuben].conf.level then
            sendEnterResult(actor, 5)
            return
        end

        if SHENGHUN_TEAM[hfuben].starttime ~= 0 or #SHENGHUN_TEAM[hfuben].actors >= 3 then
            sendEnterResult(actor, 3)
            return
        end
        for i=1, #SHENGHUN_TEAM[hfuben].actors do
            if SHENGHUN_TEAM[hfuben].actors[i].actorid == LActor.getActorId(actor) then
                return
            end
        end
        var.inspiretimes = 0
        var.atkAdd = 0
        var.infuben_hfuben = hfuben
        sendEnterResult(actor, 4)
        SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors + 1] = {}
        SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].actorid = LActor.getActorId(actor)
        SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].damage = 0
        SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].isclone = 0        
        SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].entercount = 0
        if var.fightcount < ShenghunCommonConfig.fightcount + var.buytimes then
            SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].isinvite = 1 --挑战者奖励
        else
            SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].isinvite = 2 --助战者奖励
        end
        local x,y = utils.getSceneEnterCoor(SHENGHUN_TEAM[hfuben].conf.fbId)
        LActor.enterFuBen(actor, hfuben, 0, x, y)
        
        if #SHENGHUN_TEAM[hfuben].actors == 3 then
            LActor.cancelScriptEvent(nil, SHENGHUN_TEAM[hfuben].team_eid)
            SHENGHUN_TEAM[hfuben].entertime = 0
            SHENGHUN_TEAM[hfuben].starttime = System.getNowTime()            
            beforeStart(nil, hfuben)
        end        
    end    
end

--鼓舞
function c2sShenghunInspire(actor, pack)
    local type = LDataPack.readShort(pack)    
    local var = getActorVar(actor)
    local hfuben = LActor.getFubenHandle(actor)
    if not SHENGHUN_TEAM[hfuben] or SHENGHUN_TEAM[hfuben].starttime == 0 then return end

	local conf = ShenghunInspireConfig[type]

	local temp = {} --参与增加的属性
	for k, v in pairs(conf.attrs) do
		if var.atkAdd < conf.attMax then
			table.insert(temp, v)
		end
    end    
	if #temp <= 0 then return false end --已加成到最大值

	--鼓舞消耗
    local items = type==1 and SHENGHUN_TEAM[hfuben].conf.goldSp or SHENGHUN_TEAM[hfuben].conf.diamondSp
    if not actoritem.checkItems(actor, items) then
        return 
    end
    actoritem.reduceItems(actor, items, "shenhun inspire in")

    --加成属性
    local v = temp[math.random(1, #temp)]
    var.atkAdd = var.atkAdd + v.value
    var.inspiretimes = var.inspiretimes + 1
    updateAttr(actor)

	s2cXueseInspire(actor, type)
end

--购买挑战次数
function c2sShenghunBuy(actor)
    local vip = LActor.getVipLevel(actor)
    local var = getActorVar(actor)
    if var.buytimes >= VipConfig[vip].shenghunbuy then return end
    if not actoritem.checkItem(actor, NumericType_YuanBao, ShenghunCommonConfig.needdiamond[var.buytimes + 1]) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, ShenghunCommonConfig.needdiamond[var.buytimes + 1], "buy shenhun fightTimes")
    
    var.buytimes = var.buytimes + 1
    sendFightTimes(actor)
end

--副本开始刷怪
function startFuben(_, hfuben)
    if not SHENGHUN_TEAM[hfuben] then return end
    local ins = instancesystem.getInsByHdl(hfuben)
    refreshmonsterapi.init(ins, true)
    local now = System.getNowTime()
    SHENGHUN_TEAM[hfuben].refreshtime = now
    ins:setEndTime(now + FubenConfig[SHENGHUN_TEAM[hfuben].conf.fbId].totalTime)
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
        for i=1, #SHENGHUN_TEAM[hfuben].actors do            
            if SHENGHUN_TEAM[hfuben].actors[i].actorid == selfactorid then
                SHENGHUN_TEAM[hfuben].actors[i].damage = SHENGHUN_TEAM[hfuben].actors[i].damage + value
                break
            end
        end
    elseif EntityType_Role == attacker_type or EntityType_RoleSuper == attacker_type then
        local actor = LActor.getActor(attacker)
        local selfactorid = LActor.getActorId(actor)
        for i=1, #SHENGHUN_TEAM[hfuben].actors do
            if SHENGHUN_TEAM[hfuben].actors[i].actorid == selfactorid then
                SHENGHUN_TEAM[hfuben].actors[i].damage = SHENGHUN_TEAM[hfuben].actors[i].damage + value
                break
            end
        end
    end

    local monId = Fuben.getMonsterId(monster)
    if not SHENGHUN_TEAM[hfuben].istalk1 and MonstersConfig[monId].type == ShenghunNpcConfig[1].condition[1] then --守卫受伤了
        sendAngelTalk(hfuben, 1)
        SHENGHUN_TEAM[hfuben].istalk1 = true
    end
    if not SHENGHUN_TEAM[hfuben].istalk4 and MonstersConfig[monId].type == 5 and         
        LActor.getHp(SHENGHUN_TEAM[hfuben].angel)/MonstersConfig[SHENGHUN_TEAM[hfuben].conf.guard].HpMax * 100 < ShenghunNpcConfig[4].condition[1] then
        sendAngelTalk(hfuben, 4)
        SHENGHUN_TEAM[hfuben].istalk4 = true
    end
    if not SHENGHUN_TEAM[hfuben].istalk5 and MonstersConfig[monId].type == 5 and    
        LActor.getHp(SHENGHUN_TEAM[hfuben].angel)/MonstersConfig[SHENGHUN_TEAM[hfuben].conf.guard].HpMax * 100 < ShenghunNpcConfig[5].condition[1] then
        sendAngelTalk(hfuben, 5)
        SHENGHUN_TEAM[hfuben].istalk5 = true
    end
end

--怪物创建
function onMonsterCreate(ins, mon)
    local hfuben = ins.handle
    local monId = Fuben.getMonsterId(mon)
    if MonstersConfig[monId].type ~= 5 then
        LActor.setAITarget(mon, SHENGHUN_TEAM[hfuben].angel)
    end
    if not SHENGHUN_TEAM[hfuben].istalk2 and ins.monster_cnt > ShenghunNpcConfig[2].condition[1] then
        sendAngelTalk(hfuben, 2)
        SHENGHUN_TEAM[hfuben].istalk2 = true
    end
end

--怪物死亡
local function onMonsterDie(ins, mon, killHdl)
    if ins.is_end then return end
    local hfuben = ins.handle
    local monId = Fuben.getMonsterId(mon)    
    if SHENGHUN_TEAM[hfuben] and monId == SHENGHUN_TEAM[hfuben].conf.guard then --守卫死亡，副本结束
        SHENGHUN_TEAM[hfuben].angelHpPer = 0
        sendAngelTalk(hfuben, 6)
        ins:win()
    else
        SHENGHUN_TEAM[hfuben].killcount = SHENGHUN_TEAM[hfuben].killcount + 1
    end
end

function refreshMonster(ins)
    local hfuben = ins.handle
    for k,v in ipairs(ShenghunNpcConfig[3].condition) do
        if ins.refresh_monster_idx == v then
            sendAngelTalk(hfuben, 3)
        end
    end
    sendFubenInfo(nil, hfuben, true)
end

--一波怪物死完
function onMonsterAllDie(ins)
    local hfuben = ins.handle
    if not SHENGHUN_TEAM[hfuben] or not SHENGHUN_TEAM[hfuben].angel or LActor.getHp(SHENGHUN_TEAM[hfuben].angel) <= 0 then return end
    if ins.refresh_monster_idx >= ShenghunCommonConfig.monstermaxcount then --副本怪物死完
        SHENGHUN_TEAM[hfuben].angelHpPer = LActor.getHp(SHENGHUN_TEAM[hfuben].angel)/MonstersConfig[SHENGHUN_TEAM[hfuben].conf.guard].HpMax * 100
        ins:win()
    end
end

function getRewardIndex(conf, killcount)
    for k,v in ipairs(conf.grade) do
        if killcount < v then
            return k - 1
        end
    end
    if killcount >= conf.grade[#conf.grade] then
        return #conf.grade
    end
    return 1
end

--结算
local function onWin(ins)
    local hfuben = ins.handle
    sendFubenInfo(nil, hfuben, true)
    local conf = SHENGHUN_TEAM[hfuben].conf
    local id = 1
    for k,v in ipairs(SHENGHUN_TEAM[hfuben].actors) do
        if v.isclone == 0 then            
            local items = {}
            for i=0, v.usetimes - 1 do
                local count = 0
                if v.isinvite == 1 then                
                    local tmp = v.entercount - i
                    if tmp <= 0 then
                        tmp = #ShenghunCommonConfig.timesrewardid + tmp
                    end
                    id = ShenghunCommonConfig.timesrewardid[tmp]
                    count = conf.rewardcount[getRewardIndex(conf, SHENGHUN_TEAM[hfuben].killcount)]
                else
                    id = ShenghunCommonConfig.helprewardid
                    count = conf.helpcount[getRewardIndex(conf, SHENGHUN_TEAM[hfuben].killcount)]            
                end
                table.insert(items, {id = id, count = count})           
            end
            
            local actor = LActor.getActorById(v.actorid)
            if actor and v.isleave ~= 1 then
                local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SHResult)
                LDataPack.writeShort(pack, SHENGHUN_TEAM[hfuben].refreshtime + FubenConfig[conf.fbId].totalTime - System.getNowTime())
                LDataPack.writeShort(pack, SHENGHUN_TEAM[hfuben].angelHpPer)--大天使血量百分比
                LDataPack.writeShort(pack, SHENGHUN_TEAM[hfuben].killcount)
                LDataPack.writeChar(pack, #items)
                for i=1, #items do
                    LDataPack.writeInt(pack, items[i].id)
                    LDataPack.writeInt(pack, items[i].count)
                end
                LDataPack.writeInt(pack, conf.fbId)
                LDataPack.flush(pack)
                actoritem.addItems(actor, items, "shenhun reward")                
            else
                sendMail(v.actorid, items)
            end            
        end
    end
    LActor.setHp(SHENGHUN_TEAM[hfuben].angel, 0)
    SHENGHUN_TEAM[hfuben] = nil
end

function sendMail(actorid, items)
    local mail_data = {}
    mail_data.head       = ShenghunCommonConfig.mailtitle
    mail_data.context    = ShenghunCommonConfig.mailcontent
    mail_data.tAwardList = items
    mailsystem.sendMailById(actorid, mail_data)
end

local function onLose(ins)
    local hfuben = ins.handle
    LActor.setHp(SHENGHUN_TEAM[hfuben].angel, 0)
    SHENGHUN_TEAM[hfuben] = nil
end

--进入副本前
function onEnterBefore(ins, actor)
    local hfuben = ins.handle
    if not SHENGHUN_TEAM[hfuben] then         
        return
    end
    sendAngelInfo(actor, hfuben)        
    sendBeforeEnter(actor)
    for k,v in ipairs(SHENGHUN_TEAM[hfuben].actors) do
        if v.actorid == LActor.getActorId(actor) then
            v.isleave = 0
        end
    end
    actorcommon.setTeamId(actor, 1)
    actorevent.onEvent(actor, aeNotifyFacade, -1)
end

--进入副本
local function onEnterFb(ins, actor, islogin)
    local hfuben = ins.handle
    if not SHENGHUN_TEAM[hfuben] then
        LActor.exitFuben(actor)
        return
    end
    updateAttr(actor)
    sendTeamCD(actor)
    sendFubenInfo(nil, hfuben, true)
    local var = getActorVar(actor)
    local pos = ShenghunCommonConfig.pos[#SHENGHUN_TEAM[hfuben].actors]
    local roleCount = LActor.getRoleCount(actor)
	for i = 0, roleCount - 1 do
		local role = LActor.getRole(actor, i)
        LActor.setEntityScenePos(role, pos[i+1][1], pos[i+1][2])        
    end
    LActor.setCamp(actor, CampType_Player)--设置阵营为普通模式
end

--离线处理
local function onOffline(ins, actor)
    actorcommon.setTeamId(actor, 0)
    local hfuben = ins.handle    
    if not SHENGHUN_TEAM[hfuben] then return end

    if SHENGHUN_TEAM[hfuben].starttime == 0 then --副本未开始
        local var = getActorVar(actor)
        var.infuben_hfuben = 0
        local actors = Fuben.getAllActor(hfuben)
        if not actors or #actors <= 1 then
            ins:lose()
        else
            local selfid = LActor.getActorId(actor)
            for i=1, #SHENGHUN_TEAM[hfuben].actors do
                if selfid == SHENGHUN_TEAM[hfuben].actors[i].actorid then
                    table.remove(SHENGHUN_TEAM[hfuben].actors, i)
                    break
                end
            end            
        end
        staticfuben.returnToGuajiFuben(actor)
        sendFubenInfo(nil, hfuben, true)
    else
        local selfid = LActor.getActorId(actor)
        for i=1, #SHENGHUN_TEAM[hfuben].actors do
            if selfid == SHENGHUN_TEAM[hfuben].actors[i].actorid then
                SHENGHUN_TEAM[hfuben].actors[i].isleave = 1
                break
            end
        end
        local actors = Fuben.getAllActor(hfuben)
        if not actors or #actors <= 1 then
            SHENGHUN_TEAM[hfuben].angelHpPer = LActor.getHp(SHENGHUN_TEAM[hfuben].angel)/MonstersConfig[SHENGHUN_TEAM[hfuben].conf.guard].HpMax * 100
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
    if not SHENGHUN_TEAM[hfuben] then return end
    if SHENGHUN_TEAM[hfuben].starttime == 0 then --副本未开始        
        local actors = Fuben.getAllActor(hfuben)
        if not actors or #actors <= 1 then
            ins:lose()
        else
            local selfid = LActor.getActorId(actor)
            for i=1, #SHENGHUN_TEAM[hfuben].actors do
                if selfid == SHENGHUN_TEAM[hfuben].actors[i].actorid then
                    table.remove(SHENGHUN_TEAM[hfuben].actors, i)
                    break
                end
            end
            sendFubenInfo(nil, hfuben, true)
        end
    else
        local selfid = LActor.getActorId(actor)
        for i=1, #SHENGHUN_TEAM[hfuben].actors do
            if selfid == SHENGHUN_TEAM[hfuben].actors[i].actorid then
                SHENGHUN_TEAM[hfuben].actors[i].isleave = 1
                break
            end
        end            
        local actors = Fuben.getAllActor(hfuben)
        if not actors or #actors <= 1 then
            SHENGHUN_TEAM[hfuben].angelHpPer = LActor.getHp(SHENGHUN_TEAM[hfuben].angel)/MonstersConfig[SHENGHUN_TEAM[hfuben].conf.guard].HpMax * 100
            ins:win()
        end
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
            roleCloneData.ai = FubenConstConfig.jobAi[roleCloneData.job]
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
        roleSuperData.randChangeTime = math.random(ShenghunCommonConfig.randChangeTime[1],ShenghunCommonConfig.randChangeTime[2])
        roleSuperData.aiId = FubenConstConfig.roleSuperAi
    end
    SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors + 1] = {}
    SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].actorid = actorData.actor_id
    SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].damage = 0
    SHENGHUN_TEAM[hfuben].actors[#SHENGHUN_TEAM[hfuben].actors].isclone = 1

    local pos = ShenghunCommonConfig.pos[#SHENGHUN_TEAM[hfuben].actors]
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
    
    if #SHENGHUN_TEAM[hfuben].actors == 3 then
        return true
    end
    return false
end

function isInFuben(actorData, hfuben)
    for k,v in ipairs(SHENGHUN_TEAM[hfuben].actors) do
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
    if #SHENGHUN_TEAM[hfuben].actors < 3 then
        for i=1, 3-#SHENGHUN_TEAM[hfuben].actors do
            local actorData = Ranking.getSDataFromIdx(rank, rankindex + i)
            if actorData and not isInFuben(actorData, hfuben) then
                setMirror(hfuben, actorData)
            end
        end
    end
    if #SHENGHUN_TEAM[hfuben].actors < 3 then
        for i=1, 3-#SHENGHUN_TEAM[hfuben].actors do
            local actorData = Ranking.getSDataFromIdx(rank, rankindex - i - 1)
            if actorData and not isInFuben(actorData, hfuben) then
                setMirror(hfuben, actorData)
            end
        end
    end
end

--副本开始前处理
function beforeStart(_, hfuben)
    if not SHENGHUN_TEAM[hfuben] then return end
    local selfdata = LActor.getActorDataById(SHENGHUN_TEAM[hfuben].actors[1].actorid)
    local total_power = selfdata.total_power

    --添加镜像
    if #SHENGHUN_TEAM[hfuben].actors < 3 then
        local rank = Ranking.getStaticRank(RankingType_Power)
        if rank then
            local rankindex = Ranking.getSRIndexFromId(rank, SHENGHUN_TEAM[hfuben].actors[1].actorid)
            if #SHENGHUN_TEAM[hfuben].actors == 2 then
                local selfdata1 = LActor.getActorDataById(SHENGHUN_TEAM[hfuben].actors[2].actorid)
                rankindex = math.min((rankindex + Ranking.getSRIndexFromId(rank, SHENGHUN_TEAM[hfuben].actors[2].actorid))/2)
                total_power = math.floor((total_power + selfdata1.total_power)/2)
            end

            local conf = SHENGHUN_TEAM[hfuben].conf
            for k,v in ipairs(ShenghunMatchConfig) do
                if total_power >= conf.needpower * v.spowerper[1] / 100 and total_power <= conf.needpower * v.spowerper[2] / 100 then
                    setRankMirror(rank, hfuben, total_power, rankindex, v.needpowerper)
                end
            end
        end
    end
    
    for k,v in ipairs(SHENGHUN_TEAM[hfuben].actors) do        
        if v.isclone == 0 then
            local actor = LActor.getActorById(v.actorid)
            local var = getActorVar(actor)
            if v.isinvite == 1 then
                v.usetimes = math.min(neigua.checkOpenNeigua(actor, fubencommon.shenghun), ShenghunCommonConfig.fightcount + var.buytimes - var.fightcount)
                var.fightcount = var.fightcount + v.usetimes
                var.entercount = var.entercount + v.usetimes
                if var.entercount > #ShenghunCommonConfig.timesrewardid then
                    var.entercount = 1
                end
                v.entercount = var.entercount
                actorevent.onEvent(actor, aeEnterShenghun, v.usetimes)
            else
                v.usetimes = math.min(neigua.checkOpenNeigua(actor, fubencommon.shenghun), ShenghunCommonConfig.helpcount - var.helpcount)
                var.helpcount = var.helpcount + v.usetimes
            end            
            sendFightTimes(actor)
        end        
    end
         
    sendFubenInfo(nil, hfuben, true)
    SHENGHUN_TEAM[hfuben].starttime = System.getNowTime()    
    sendStartCD(hfuben)
    LActor.postScriptEventLite(nil, ShenghunCommonConfig.startcd*1000, startFuben, hfuben)
end

--副本进入结果
function sendEnterResult(actor, result)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SHFight)
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
    LDataPack.writeByte(pack, Protocol.sFubenCmd_SHInvite)
    LDataPack.writeChar(pack, type)
    LDataPack.writeUInt(pack, hfuben)
    LDataPack.writeString(pack, LActor.getName(actor))
    LDataPack.writeInt(pack, SHENGHUN_TEAM[hfuben].conf.fbId)
    if type == 1 then
        System.broadcastData(pack)
    else        
        LGuild.broadcastData(guild, pack)
    end   
end

--副本内信息
function sendFubenInfo(_, hfuben, notTimer)
    if not SHENGHUN_TEAM[hfuben] then return end    
    local conf = SHENGHUN_TEAM[hfuben].conf
    local ins = instancesystem.getInsByHdl(hfuben)
    if not ins then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_AllFuben2)
    LDataPack.writeByte(pack, Protocol.sFubenCmd_SHInfo)
    LDataPack.writeChar(pack, ins.refresh_monster_idx <= ShenghunCommonConfig.monstermaxcount and ins.refresh_monster_idx or ShenghunCommonConfig.monstermaxcount)
    LDataPack.writeInt(pack, SHENGHUN_TEAM[hfuben].killcount)
    LDataPack.writeChar(pack, #SHENGHUN_TEAM[hfuben].actors)
    for i=1, #SHENGHUN_TEAM[hfuben].actors do
        LDataPack.writeDouble(pack, SHENGHUN_TEAM[hfuben].actors[i].damage)
        local roleCloneData = actorcommon.getCloneData(SHENGHUN_TEAM[hfuben].actors[i].actorid)
        LDataPack.writeString(pack, roleCloneData[1].name)
        LDataPack.writeChar(pack, roleCloneData[1].job)
    end
    local nexttime = (ins.next_refresh_time[refreshmonsterapi.MonRefreshTypes.tp6] or 0) - System.getNowTime()
    LDataPack.writeShort(pack, nexttime > 0 and nexttime or 0)    

    Fuben.sendData(hfuben, pack)
    if not notTimer then
        LActor.postScriptEventLite(nil, 2*1000, sendFubenInfo, hfuben)
    end
end

--发送大天使信息
function sendAngelInfo(actor, hfuben)
    local monIdList = {}	
    table.insert(monIdList, SHENGHUN_TEAM[hfuben].conf.guard)	
    slim.s2cMonsterConfig(actor, monIdList)    
end

--玩家副本开始剩余时间
function sendStartCD(hfuben)
	local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_AllFuben2)
    LDataPack.writeByte(pack, Protocol.sFubenCmd_SHStartCD)
    local remaintime = ShenghunCommonConfig.startcd - (System.getNowTime() - SHENGHUN_TEAM[hfuben].starttime)
    LDataPack.writeShort(pack, remaintime > 0 and remaintime or 0)
    Fuben.sendData(hfuben, pack)
end

--玩家组队剩余时间
function sendTeamCD(actor)
    local hfuben = LActor.getFubenHandle(actor)
    if not SHENGHUN_TEAM[hfuben] then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SHTeamCD)
    local remaintime = ShenghunCommonConfig.teamcd - (System.getNowTime() - SHENGHUN_TEAM[hfuben].entertime)
    LDataPack.writeShort(pack, remaintime > 0 and remaintime or 0)
    LDataPack.writeByte(pack, LActor.getActorId(actor) == SHENGHUN_TEAM[hfuben].actors[1].actorid and 1 or 2)
    LDataPack.flush(pack)
end

--玩家挑战信息
function sendFightTimes(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SHFightTimes)
    LDataPack.writeChar(pack, var.fightcount)
    LDataPack.writeChar(pack, var.buytimes)
    LDataPack.writeChar(pack, ShenghunCommonConfig.helpcount - var.helpcount)
	LDataPack.flush(pack)
end

function getFubenInvite(hfuben, actorid)
    for k,v in ipairs(SHENGHUN_TEAM[hfuben].actors) do
        if v.actorid == actorid then
            return v.isinvite
        end
    end
end

--圣魂神殿进入副本前信息
function sendBeforeEnter(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SHBeforEnter)
    local hfuben = var.infuben_hfuben
    if not SHENGHUN_TEAM[hfuben] or not SHENGHUN_TEAM[hfuben].conf then return end
    LDataPack.writeChar(pack, getFubenInvite(hfuben, LActor.getActorId(actor)))
    local conf = SHENGHUN_TEAM[hfuben].conf
    local refreshtime = SHENGHUN_TEAM[hfuben].refreshtime
    LDataPack.writeShort(pack, refreshtime == 0 and - 1 or refreshtime + FubenConfig[conf.fbId].totalTime - System.getNowTime())
    LDataPack.writeInt(pack, conf.fbId)
	LDataPack.flush(pack)
end

--圣魂神殿鼓舞信息
function s2cXueseInspire(actor, type)
    local var = getActorVar(actor)
    if var.inspiretimes <= 0 then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SHInspire)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.atkAdd)
	LDataPack.writeChar(pack, type)
	LDataPack.writeByte(pack, var.inspiretimes)
	LDataPack.flush(pack)
end

--圣魂神殿通知客户端清鼓舞信息
function s2cXueseInspireClear(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SHInspire)
	if pack == nil then return end
	LDataPack.writeInt(pack, 0)
	LDataPack.writeChar(pack, 1)
	LDataPack.writeByte(pack, 0)
	LDataPack.flush(pack)
end

--守卫说话
function sendAngelTalk(hfuben, index)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_AllFuben2)
    LDataPack.writeByte(pack, Protocol.cFubenCmd_SHNPCTalk)
    LDataPack.writeByte(pack, index)
    LDataPack.writeDouble(pack, LActor.getHandle(SHENGHUN_TEAM[hfuben].angel))
    Fuben.sendData(hfuben, pack)
end

function onLogin(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenghun) then return end
    sendFightTimes(actor)
    s2cXueseInspire(actor, 1)
    local var = getActorVar(actor)
    if var.infuben_hfuben ~= 0 and not SHENGHUN_TEAM[var.infuben_hfuben] then
        var.infuben_hfuben = 0
        --staticfuben.returnToGuajiFuben(actor)
    end    
end

local function onLevelUp(actor, level, oldLevel)
    local lv = actorexp.getLimitLevel(nil, actorexp.LimitTp.shenghun)
	if lv > oldLevel and lv <= level then
		sendFightTimes(actor)
	end
end

function onNewDay(actor, login)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shenghun) then return end
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
    
	
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_SHInvite, c2sShenghunInvite)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_SHFight, c2sShenghunFight)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_SHInspire, c2sShenghunInspire)
    netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_SHBuyTimes, c2sShenghunBuy)
    

	--注册相关回调
    for _, conf in pairs(ShenghunFubenConfig) do
        insevent.registerInstanceMonsterCreate(conf.fbId, onMonsterCreate)
        insevent.registerInstanceEnterBefore(conf.fbId, onEnterBefore)
        insevent.registerInstanceWin(conf.fbId, onWin)
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceExit(conf.fbId, onExitFb)
        insevent.registerInstanceOffline(conf.fbId, onOffline)
		insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
        insevent.registerInstanceMonsterDamage(conf.fbId, onDamage)
        insevent.registerInstanceLose(conf.fbId, onLose)
	end
end
table.insert(InitFnTable, init)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.shwin = function (actor, args)
    local ins = instancesystem.getActorIns(actor)
    ins:win()
	return true
end
