--魔龙之城
module("molong", package.seeall)

MOLONG_TEAM = MOLONG_TEAM or {}

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.molong then
        var.molong = {
            fightcount = 0, --今日挑战次数
            helpcount = 0, --今日帮助次数
            atkAdd = 0, --攻击加成
            inspiretimes = 0, --鼓舞次数
            buytimes = 0, --购买挑战次数
            allTimes = 0, --历史挑战次数,用来做剧情掉落
        }
    end
    if not var.molong.infuben_hfuben then var.molong.infuben_hfuben = 0 end
    return var.molong
end

--邀请玩家
function c2sMolongInvite(actor, pack)
    local var = getActorVar(actor)
    local hfuben = var.infuben_hfuben
    if hfuben == 0 then return end
    local type = LDataPack.readChar(pack)
    sendInvite(actor, type, hfuben)
end

function getConfig(zslevel)
    local fbId = 0
    for id, conf in ipairs(MolongFubenConfig) do
        if zslevel >= conf.zslevel then
            fbId = id
        else
            break
        end
    end
    return MolongFubenConfig[fbId]
end

--更新属性
function updateAttr(actor)
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Fuben)
    attr:Reset()
    local var = getActorVar(actor)
    if not var then return end
    if var.atkAdd > 0 then
        attr:Add(Attribute.atAtkPer, var.atkAdd)
    end
    
    LActor.reCalcAttr(actor)
end

function initGlobal(hfuben, conf)
    MOLONG_TEAM[hfuben] = {}
    MOLONG_TEAM[hfuben].entertime = System.getNowTime()
    MOLONG_TEAM[hfuben].starttime = 0
    MOLONG_TEAM[hfuben].refreshtime = 0
    MOLONG_TEAM[hfuben].alivecount = 0
    MOLONG_TEAM[hfuben].extratime = 0 --额外时间，如果中途退出，则获得最小奖励
    MOLONG_TEAM[hfuben].conf = conf
    MOLONG_TEAM[hfuben].actors = {}
end

function joinTeam(actor, hfuben)
    if not MOLONG_TEAM[hfuben] then return end
    local teamer = {}
    local var = getActorVar(actor)
    teamer.actorid = LActor.getActorId(actor)
    teamer.isinvite = var.fightcount < MolongCommonConfig.fightcount + var.buytimes and 1 or 2
    teamer.isclone = 0
    teamer.serverid = LActor.getServerId(actor)
    teamer.name = LActor.getName(actor)
    teamer.job = LActor.getJob(actor)
    teamer.allTimes = var.allTimes + 1
    teamer.fightTimes = 1
    teamer.damage = 0
    table.insert(MOLONG_TEAM[hfuben].actors, teamer)
end

local function onGetFubenHdl(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local zslevel = LDataPack.readInt(cpack)
    local conf = getConfig(zslevel)
    if not conf then return end
    
    local hfuben = instancesystem.createFuBen(conf.fbId)
    if MOLONG_TEAM[hfuben] then return end
    local ins = instancesystem.getInsByHdl(hfuben)
    initGlobal(hfuben, conf)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCMolongCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCMolongCmd_SendFubenHdl)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeInt(npack, conf.fbId)
    LDataPack.writeInt64(npack, hfuben)
    System.sendPacketToAllGameClient(npack, sId)
end

local function onSendFubenHdl(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local fbId = LDataPack.readInt(cpack)
    local hfuben = LDataPack.readInt64(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    
    sendEnterResult(actor, 4)
    actorcommon.setTeamId(actor, 1)
    --sendFubenInfo(nil, hfuben)
    sendFightTimes(actor)
    
    local crossId = csbase.getCrossServerId()
    local x, y = utils.getSceneEnterCoor(fbId)
    LActor.loginOtherServer(actor, crossId, hfuben, 0, x, y, "cross")
end

local function onCheckCanEnter(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local zslevel = LDataPack.readInt(cpack)
    local hfuben = LDataPack.readInt64(cpack)
    
    if not MOLONG_TEAM[hfuben] then
        sendErrorTip(actorid, sId, 2)
        return
    end
    local conf = MOLONG_TEAM[hfuben].conf
    if zslevel < conf.zslevel then
        sendErrorTip(actorid, sId, 5)
        return
    end
    
    if MOLONG_TEAM[hfuben].starttime ~= 0 or MOLONG_TEAM[hfuben].refreshtime ~= 0 or #MOLONG_TEAM[hfuben].actors >= 3 then
        sendErrorTip(actorid, sId, 3)
        return
    end
    
    if #MOLONG_TEAM[hfuben].actors == 0 then return end--队员要等队长进入之后才可以进入
    for i = 1, #MOLONG_TEAM[hfuben].actors do
        if MOLONG_TEAM[hfuben].actors[i].actorid == actorid then return end
    end
    sendErrorTip(actorid, sId, 4, conf.fbId, hfuben)
end

function sendErrorTip(actorid, sId, errorid, fbId, hfuben)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCMolongCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCMolongCmd_SendErrorTip)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, errorid)
    LDataPack.writeInt(npack, fbId or 0)
    LDataPack.writeInt64(npack, hfuben or 0)
    System.sendPacketToAllGameClient(npack, sId)
end

local function onSendErrorTip(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local errorid = LDataPack.readChar(cpack)
    local fbId = LDataPack.readInt(cpack)
    local hfuben = LDataPack.readInt64(cpack)
    
    local var = getActorVar(actor)
    --当无法加入队伍时，要清除副本handle
    if errorid == 2 then
        var.infuben_hfuben = 0
        sendEnterResult(actor, 2)
        return
    end
    if errorid == 5 then
        var.infuben_hfuben = 0
        sendEnterResult(actor, 5)
        return
    end
    
    if errorid == 3 then
        var.infuben_hfuben = 0
        sendEnterResult(actor, 3)
        return
    end
    
    actorcommon.setTeamId(actor, 1)
    sendEnterResult(actor, 4)
    
    var.infuben_hfuben = hfuben
    var.inspiretimes = 0
    var.atkAdd = 0
    
    local crossId = csbase.getCrossServerId()
    local x, y = utils.getSceneEnterCoor(fbId)
    LActor.loginOtherServer(actor, crossId, hfuben, 0, x, y, "cross")
    sendFightTimes(actor)
end

--申请进入
function c2sMolongFight(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.molong) then return end
    if not actorlogin.checkCanEnterCross(actor) then return end
    local hfuben = LDataPack.readUInt(pack)
    local var = getActorVar(actor)
    if var.infuben_hfuben ~= 0 then return end--申请进入副本时，已有队伍
    if hfuben == 0 then
        local zslevel = LActor.getZhuansheng(actor)
        local conf = getConfig(zslevel)
        if not conf then return end
        if var.fightcount >= MolongCommonConfig.fightcount + var.buytimes then return end
        local actorid = LActor.getActorId(actor)
        var.inspiretimes = 0
        var.atkAdd = 0
        
        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, CrossSrvCmd.SCMolongCmd)
        LDataPack.writeByte(npack, CrossSrvSubCmd.SCMolongCmd_GetFubenHdl)
        LDataPack.writeInt(npack, LActor.getActorId(actor))
        LDataPack.writeInt(npack, zslevel)
        System.sendPacketToAllGameClient(npack, 0)
    else
        if var.fightcount >= MolongCommonConfig.fightcount + var.buytimes and var.helpcount >= MolongCommonConfig.helpcount then return end
        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, CrossSrvCmd.SCMolongCmd)
        LDataPack.writeByte(npack, CrossSrvSubCmd.SCMolongCmd_CheckCanEnter)
        LDataPack.writeInt(npack, LActor.getActorId(actor))
        LDataPack.writeInt(npack, LActor.getZhuansheng(actor))
        LDataPack.writeInt64(npack, hfuben)
        System.sendPacketToAllGameClient(npack, 0)
    end
    var.infuben_hfuben = 1 --由于跨服请求异步处理，需要在本服先行记录，防止进入两支队伍
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
    local items = type == 1 and MOLONG_TEAM[hfuben].conf.goldSp or MOLONG_TEAM[hfuben].conf.diamondSp
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
    local svip = LActor.getSVipLevel(actor)
    local var = getActorVar(actor)
    if var.buytimes >= SVipConfig[svip].molongbuy then return end
    local needCount = MolongCommonConfig.needdiamond[var.buytimes + 1]
    if not needCount then return end
    if not actoritem.checkItem(actor, NumericType_YuanBao, needCount) then
        return
    end
    actoritem.reduceItem(actor, NumericType_YuanBao, needCount, "buy molong fightTimes")
    
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
    ins:setEndTime(now + FubenConfig[MOLONG_TEAM[hfuben].conf.fbId].totalTime)
    
    for i, v in ipairs(MOLONG_TEAM[hfuben].actors) do
        local actor = LActor.getActorById(v.actorid)
        if actor then
            sendBeforeEnter(actor)
        end
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
        for i = 1, #MOLONG_TEAM[hfuben].actors do
            if MOLONG_TEAM[hfuben].actors[i].actorid == selfactorid then
                MOLONG_TEAM[hfuben].actors[i].damage = MOLONG_TEAM[hfuben].actors[i].damage + value
                break
            end
        end
    elseif EntityType_Role == attacker_type or EntityType_RoleSuper == attacker_type then
        local actor = LActor.getActor(attacker)
        local selfactorid = LActor.getActorId(actor)
        for i = 1, #MOLONG_TEAM[hfuben].actors do
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
    for k, v in ipairs(conf.grade) do
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
    if not MOLONG_TEAM[hfuben] then return end
    local conf = MOLONG_TEAM[hfuben].conf
    local double = 1
    if subactivity12.checkIsStart() then
        double = 2
    end
    local usetime = System.getNowTime() - MOLONG_TEAM[hfuben].refreshtime + MOLONG_TEAM[hfuben].extratime
    for k, v in ipairs(MOLONG_TEAM[hfuben].actors) do
        if v.isclone == 0 then
            local items = {}
            for _ = 1, v.fightTimes do
                local dropId = 0
                if v.isinvite == 1 then
                    if v.allTimes <= #MolongCommonConfig.juqingDrop then
                        dropId = MolongCommonConfig.juqingDrop[v.allTimes]
                    else
                        dropId = conf.rewardDrop[getRewardIndex(conf, usetime)]
                    end
                else
                    dropId = conf.helpDrop[getRewardIndex(conf, usetime)]
                end
                local rewards = drop.dropGroup(dropId)
                for _, item in ipairs(rewards) do
                    table.insert(items, {type = item.type, id = item.id, count = item.count * double})
                end
            end
            
            local actor = LActor.getActorById(v.actorid)
            if actor and LActor.getFubenHandle(actor) == hfuben then
                local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_MLResult)
                LDataPack.writeShort(pack, usetime)
                LDataPack.writeChar(pack, #items)
                for _, rconf in ipairs(items) do
                    LDataPack.writeInt(pack, rconf.id)
                    LDataPack.writeInt(pack, rconf.count)
                    LDataPack.writeByte(pack, double == 2 and 1 or 0)
                end
                LDataPack.writeInt(pack, conf.fbId)
                LDataPack.flush(pack)
                
                actoritem.addItems(actor, items, "molong reward")
            else
                local mail_data = {}
                mail_data.head = MolongCommonConfig.mailtitle
                mail_data.context = MolongCommonConfig.mailcontent
                mail_data.tAwardList = items
                mailsystem.sendMailById(v.actorid, mail_data, v.serverid)
            end
        end
    end
    MOLONG_TEAM[hfuben] = nil
end

--进入副本
local function onEnterFb(ins, actor, islogin)
    local hfuben = ins.handle
    local actors = ins:getActorList()
    if not MOLONG_TEAM[hfuben] then LActor.exitFuben(actor) return end
    if MOLONG_TEAM[hfuben].starttime ~= 0 then return end
    if not MOLONG_TEAM[hfuben].team_eid then
        MOLONG_TEAM[hfuben].team_eid = LActor.postScriptEventLite(nil, MolongCommonConfig.teamcd * 1000, beforeStart, hfuben)
    end
    
    if #MOLONG_TEAM[hfuben].actors == 3 then
        LActor.cancelScriptEvent(nil, MOLONG_TEAM[hfuben].team_eid)
        beforeStart(nil, hfuben)
    end
    
    local var = getActorVar(actor)
    var.infuben_hfuben = hfuben
    updateAttr(actor)
    sendTeamCD(actor)
    sendFubenInfo(nil, hfuben, false)--false表示循环发送副本信息
    local pos = MolongCommonConfig.pos[#MOLONG_TEAM[hfuben].actors]
    local role = LActor.getRole(actor)
    LActor.setEntityScenePos(role, pos[1][1], pos[1][2])
    local yongbing = LActor.getYongbing(actor)
    if yongbing then
        LActor.setEntityScenePos(yongbing, pos[2][1], pos[2][2])
    end
    
    --actorevent.onEvent(actor, aeEnterFuben, ins.config.fbid, false)
end

local function onBeforeEnterFb(ins, actor, islogin)
    local hfuben = ins.handle
    if not MOLONG_TEAM[hfuben] or #MOLONG_TEAM[hfuben].actors >= 3 or MOLONG_TEAM[hfuben].starttime ~= 0 then
        LActor.exitFuben(actor)
        return
    end
    
    joinTeam(actor, hfuben)
    local var = getActorVar(actor)
    var.infuben_hfuben = hfuben
    sendBeforeEnter(actor)
    actorcommon.setTeamId(actor, 1)
    actorevent.onEvent(actor, aeNotifyFacade, -1)
end

--离线处理
local function onOffline(ins, actor)
    actorcommon.setTeamId(actor, 0)
    local hfuben = ins.handle
    if not MOLONG_TEAM[hfuben] then return end
    LActor.exitFuben(actor)
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
            for i = 1, #MOLONG_TEAM[hfuben].actors do
                if selfid == MOLONG_TEAM[hfuben].actors[i].actorid then
                    table.remove(MOLONG_TEAM[hfuben].actors, i)
                    break
                end
            end
            sendFubenInfo(nil, hfuben, true)
        end
    else
        local actors = Fuben.getAllActor(hfuben)
        if not actors or #actors <= 1 then
            MOLONG_TEAM[hfuben].extratime = 9999
            ins:win()
        end
        --s2cXueseInspireClear(actor)
    end
end

--创建镜像玩家配打
function setMirror(hfuben, actorid, roleCloneData, actorCloneData, roleSuperData)
    if not MOLONG_TEAM[hfuben] then return end
    if #MOLONG_TEAM[hfuben].actors >= 3 then return end
    roleCloneData.teamId = 1
    local ins = instancesystem.getInsByHdl(hfuben)
    local hScene = ins.scene_list[1]
    if roleSuperData then
        roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
        roleSuperData.aiId = FubenConstConfig.roleSuperAi
    end
    
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors + 1] = {}
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].actorid = actorid
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].damage = 0
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].isclone = 1
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].name = roleCloneData.name
    MOLONG_TEAM[hfuben].actors[#MOLONG_TEAM[hfuben].actors].job = roleCloneData.job
    local pos = MolongCommonConfig.pos[#MOLONG_TEAM[hfuben].actors]
    local actorClone = LActor.createActorCloneWithData(actorid, hScene, pos[1][1], pos[1][2], actorCloneData, roleCloneData, roleSuperData)
    local roleClone = LActor.getRole(actorClone)
    if roleClone then
        LActor.setEntityScenePos(roleClone, pos[1][1], pos[1][2])
    end
    local yongbing = LActor.getYongbing(actorClone)
    if yongbing then
        LActor.setEntityScenePos(yongbing, pos[2][1], pos[2][2])
    end
    
    LActor.setCamp(actorClone, CampType_Player)--设置阵营为普通模式
end

local function onSendActorInfo(sId, sType, cpack)
    if System.isCommSrv() then
        return
    end
    local actorid = LDataPack.readInt(cpack)
    local hfuben = LDataPack.readInt64(cpack)
    local actorDataUd = LDataPack.readUserData(cpack)
    local offlinedata = bson.decode(actorDataUd)
    local roleCloneData, actorCloneData, roleSuperData = actorcommon.getCloneDataByOffLineData(offlinedata)
    setMirror(hfuben, actorid, roleCloneData, actorCloneData, roleSuperData)
end

function onReqActorInfo(sId, sType, cpack)
    if System.isCrossWarSrv() then return end
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if actor then--先暴力处理
        offlinedatamgr.CallEhLogout(actor) --保存离线数据
    end
    local actorData = offlinedatamgr.GetDataByOffLineDataType(actorid, offlinedatamgr.EOffLineDataType.EBasic)
    if actorData == nil then
        return
    end
    
    local actorDataUd = bson.encode(actorData)
    
    local npack = LDataPack.allocPacket()
    if npack == nil then return end
    LDataPack.writeByte(npack, CrossSrvCmd.SCMolongCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCMolongCmd_SendActorInfo)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeInt64(npack, LDataPack.readInt64(cpack))
    LDataPack.writeUserData(npack, actorDataUd)
    
    System.sendPacketToAllGameClient(npack, 0)
end

--副本开始前处理
function beforeStart(_, hfuben)
    if not MOLONG_TEAM[hfuben] then return end
    local ins = instancesystem.getInsByHdl(hfuben)
    if #MOLONG_TEAM[hfuben].actors == 0 then
        ins:release()
        return
    end
    if MOLONG_TEAM[hfuben].starttime ~= 0 then return end
    local actorid = MOLONG_TEAM[hfuben].actors[1].actorid
    local actor = LActor.getActorById(actorid)
    local need = 3 - #MOLONG_TEAM[hfuben].actors
    --添加镜像
    while need > 0 do
        --先从战盟里找成员镜像
        local guildId = LActor.getGuildId(actor)
        local guild = LGuild.getGuildById(guildId)
        if guild then
            local members = LGuild.getMemberIdList(guild)
            --从战盟成员列表中删除队伍中已有的成员，防止匹配到同名镜像
            local members_clone = utils.table_clone(members)
            for _, teamer in ipairs(MOLONG_TEAM[hfuben].actors) do
                for idx, Aid in ipairs(members_clone) do
                    if Aid == teamer.actorid then
                        table.remove(members_clone, idx)
                    end
                end
            end
            local memberCount = #members_clone
            if memberCount > 0 then
                local randGuilds = utils.getRandomIndexs(1, memberCount, math.min(need, memberCount))
                for i, index in ipairs(randGuilds) do
                    local npack = LDataPack.allocPacket()
                    LDataPack.writeByte(npack, CrossSrvCmd.SCMolongCmd)
                    LDataPack.writeByte(npack, CrossSrvSubCmd.SCMolongCmd_ReqActorInfo)
                    LDataPack.writeInt(npack, members_clone[index])
                    LDataPack.writeInt64(npack, hfuben)
                    System.sendPacketToAllGameClient(npack, 0)
                    need = need - 1
                end
            end
        end
        
        if need <= 0 then break end
        --如果战盟镜像不足，则匹配机器人
        local rotCount = #MolongRobotConfig
        if rotCount > 0 then
            local randRots = utils.getRandomIndexs(1, rotCount, math.min(need, rotCount))
            for _, index in ipairs(randRots) do
                local roleCloneData, actorData, roleSuperData = actorcommon.createRobotClone(MolongRobotConfig, index, LActor.getServerName(actor) .. ".")
                --机器人属性是玩家属性的百分比
                if actor then
                    local roleAttr = LActor.getRoleAttrsBasic(actor)
                    roleCloneData.attrs:Reset()
                    for j = Attribute.atHp, Attribute.atCount - 1 do
                        if j == Attribute.atShenYouShieldTagNum then
                        elseif j ~= Attribute.atMvSpeed then
                            roleCloneData.attrs:Set(j, roleAttr[j] * MolongCommonConfig.robotpercent)
                        else
                            roleCloneData.attrs:Set(j, roleAttr[j])
                        end
                    end
                end
                setMirror(hfuben, index, roleCloneData, actorData, roleSuperData)
                need = need - 1
            end
        end
        
        if need > 0 then
            print ("milong.beforeStart team can't find more mirrors still need: "..need)
        end
        break --匹配完成了，不再继续循环了
    end
    
    for k, v in ipairs(MOLONG_TEAM[hfuben].actors) do
        if v.isclone == 0 then
            local actor = LActor.getActorById(v.actorid)
            if actor then
                local var = getActorVar(actor)
                local exCount = 0
                if v.isinvite == 1 then
                    exCount = neigua.checkOpenNeigua(actor, ins.config.group, MolongCommonConfig.fightcount + var.buytimes - var.fightcount)
                    var.fightcount = var.fightcount + exCount
                    var.allTimes = (var.allTimes or 0) + exCount
                    v.fightTimes = exCount
                else
                    exCount = neigua.checkOpenNeigua(actor, ins.config.group, MolongCommonConfig.helpcount - var.helpcount)
                    var.helpcount = var.helpcount + exCount
                    v.fightTimes = exCount
                end
                sendFightTimes(actor)
                actorevent.onEvent(actor, aeEnterMolong, exCount)
            else
                print("molong.beforeStart can't find actor by actorid: ", v.actorid)
            end
        end
    end
    
    MOLONG_TEAM[hfuben].starttime = System.getNowTime()
    MOLONG_TEAM[hfuben].entertime = 0
    MOLONG_TEAM[hfuben].alivecount = #MOLONG_TEAM[hfuben].actors
    sendStartCD(hfuben)
    sendFubenInfo(nil, hfuben, true)
    LActor.postScriptEventLite(nil, MolongCommonConfig.startcd * 1000, startFuben, hfuben)
end

--副本进入结果
function sendEnterResult(actor, result)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_MLFight)
    LDataPack.writeChar(pack, result)
    LDataPack.flush(pack)
end

local function onGetInviteActor(sId, sType, cpack)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_AllFuben2)
    LDataPack.writeByte(pack, Protocol.sFubenCmd_MLInvite)
    local type = LDataPack.readChar(cpack)
    LDataPack.writeChar(pack, type)
    LDataPack.writeUInt(pack, LDataPack.readUInt(cpack))
    LDataPack.writeString(pack, LDataPack.readString(cpack))
    LDataPack.writeInt(pack, LDataPack.readInt(cpack))
    local guildId = LDataPack.readInt(cpack)
    if type == 1 then
        System.broadcastData(pack)
    else
        LGuild.broadcastData(guildId, pack)
    end
end

--发送邀请
function sendInvite(actor, type, hfuben)
    local guildId = LActor.getGuildId(actor)
    if type ~= 1 and guildId == 0 then return end
    if not MOLONG_TEAM[hfuben] then return end
    sendInviteToSelf(actor, type, hfuben)
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCMolongCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCMolongCmd_InviteActor)
    LDataPack.writeChar(npack, type)
    LDataPack.writeUInt(npack, hfuben)
    LDataPack.writeString(npack, LActor.getName(actor))
    LDataPack.writeInt(npack, MOLONG_TEAM[hfuben].conf.fbId)
    LDataPack.writeInt(npack, guildId)
    System.sendPacketToAllGameClient(npack, 0)
end

function sendInviteToSelf(actor, type, hfuben)
    if not actor then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_MLInvite)
    if not pack then return end
    LDataPack.writeChar(pack, type)
    LDataPack.writeUInt(pack, hfuben)
    LDataPack.writeString(pack, LActor.getName(actor))
    LDataPack.writeInt(pack, MOLONG_TEAM[hfuben].conf.fbId)
    LDataPack.flush(pack)
end

--副本内信息
function sendFubenInfo(_, hfuben, notTimer)
    if not MOLONG_TEAM[hfuben] then return end
    local conf = MOLONG_TEAM[hfuben].conf
    local ins = instancesystem.getInsByHdl(hfuben)
    if not ins then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_AllFuben2)
    LDataPack.writeByte(pack, Protocol.sFubenCmd_MLInfo)
    LDataPack.writeChar(pack, ins.refresh_monster_idx)
    LDataPack.writeInt(pack, ins.kill_monster_cnt)
    LDataPack.writeChar(pack, #MOLONG_TEAM[hfuben].actors)
    for i = 1, #MOLONG_TEAM[hfuben].actors do
        LDataPack.writeDouble(pack, MOLONG_TEAM[hfuben].actors[i].damage)
        LDataPack.writeString(pack, MOLONG_TEAM[hfuben].actors[i].name)
        LDataPack.writeChar(pack, MOLONG_TEAM[hfuben].actors[i].job)
    end
    LDataPack.writeShort(pack, MOLONG_TEAM[hfuben].refreshtime == 0 and - 1 or MOLONG_TEAM[hfuben].refreshtime + FubenConfig[conf.fbId].totalTime - System.getNowTime())
    
    Fuben.sendData(hfuben, pack)
    if not notTimer then
        LActor.postScriptEventLite(nil, 2 * 1000, sendFubenInfo, hfuben)
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
    LDataPack.writeChar(pack, var.fightcount)
    LDataPack.writeChar(pack, var.buytimes)
    LDataPack.writeChar(pack, MolongCommonConfig.helpcount - var.helpcount)
    LDataPack.flush(pack)
end

function getFubenInvite(hfuben, actorid)
    if not MOLONG_TEAM[hfuben] then return end
    for k, v in ipairs(MOLONG_TEAM[hfuben].actors) do
        if v.actorid == actorid then
            return v.isinvite
        end
    end
end

--魔龙之城进入副本前信息
function sendBeforeEnter(actor)
    local var = getActorVar(actor)
    if not var then return end
    local hfuben = var.infuben_hfuben
    local invite = getFubenInvite(hfuben, LActor.getActorId(actor))
    if not invite then return end
    if not MOLONG_TEAM[hfuben] or not MOLONG_TEAM[hfuben].conf then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_MLBeforEnter)
    LDataPack.writeChar(pack, invite)
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
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.molong) then return end
    sendFightTimes(actor)
    s2cXueseInspire(actor, 1)
    local var = getActorVar(actor)
    var.infuben_hfuben = 0
end

function onNewDay(actor, login)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.molong) then return end
    local var = getActorVar(actor)
    var.fightcount = 0
    var.helpcount = 0
    var.buytimes = 0
    if not login then
        sendFightTimes(actor)
    end
end

csmsgdispatcher.Reg(CrossSrvCmd.SCMolongCmd, CrossSrvSubCmd.SCMolongCmd_GetFubenHdl, onGetFubenHdl)
csmsgdispatcher.Reg(CrossSrvCmd.SCMolongCmd, CrossSrvSubCmd.SCMolongCmd_SendFubenHdl, onSendFubenHdl)
csmsgdispatcher.Reg(CrossSrvCmd.SCMolongCmd, CrossSrvSubCmd.SCMolongCmd_CheckCanEnter, onCheckCanEnter)
csmsgdispatcher.Reg(CrossSrvCmd.SCMolongCmd, CrossSrvSubCmd.SCMolongCmd_SendErrorTip, onSendErrorTip)
csmsgdispatcher.Reg(CrossSrvCmd.SCMolongCmd, CrossSrvSubCmd.SCMolongCmd_InviteActor, onGetInviteActor)
csmsgdispatcher.Reg(CrossSrvCmd.SCMolongCmd, CrossSrvSubCmd.SCMolongCmd_ReqActorInfo, onReqActorInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCMolongCmd, CrossSrvSubCmd.SCMolongCmd_SendActorInfo, onSendActorInfo)

local function init()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_MLInvite, c2sMolongInvite)
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
    if System.isBattleSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_MLFight, c2sMolongFight)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.molongRobot = function (actor, args)
    local hfuben = LActor.getFubenHandle(actor)
    local rand = math.random(1, #MolongRobotConfig)
    local roleCloneData, actorData, roleSuperData = actorcommon.createRobotClone(MolongRobotConfig, rand, LActor.getServerName(actor) .. ".")
    --机器人属性是玩家属性的百分比
    if actor then
        local roleAttr = LActor.getRoleAttrsCache(actor)
        roleCloneData.attrs:Reset()
        for j = Attribute.atHp, Attribute.atCount - 1 do
            if j ~= Attribute.atMvSpeed and j ~= Attribute.atShenYouShieldTagNum then
                roleCloneData.attrs:Set(j, roleAttr[j] * MolongCommonConfig.robotpercent)
            else
                roleCloneData.attrs:Set(j, roleAttr[j])
            end
        end
    end
    setMirror(hfuben, rand, roleCloneData, actorData, roleSuperData)
end

