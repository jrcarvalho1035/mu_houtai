--灵器副本
module("lingqi", package.seeall)

LINGQI_TEAM = LINGQI_TEAM or {}

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.lingqifb then
        var.lingqifb = {
            fightcount = 0, --今日挑战次数
            helpcount = 0, --今日帮助次数
            atkAdd = 0, --攻击加成
            inspiretimes = 0, --鼓舞次数
            buytimes = 0, --购买挑战次数
            allTimes = 0, --历史挑战次数,用来做剧情掉落
            infuben_hfuben = 0, --标记玩家参与的副本
        }
    end
    if not var.lingqifb.infuben_hfuben then var.lingqifb.infuben_hfuben = 0 end
    return var.lingqifb
end

function getConfig(zslevel)
    local fbId = 0
    for id, conf in ipairs(LingQiFubenConfig) do
        if zslevel >= conf.zslevel then
            fbId = id
        else
            break
        end
    end
    return LingQiFubenConfig[fbId]
end

function getFubenInvite(hfuben, actorid)
    if not LINGQI_TEAM[hfuben] then return end
    for k, v in ipairs(LINGQI_TEAM[hfuben].actors) do
        if v.actorid == actorid then
            return v.isinvite
        end
    end
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
    LINGQI_TEAM[hfuben] = {}
    LINGQI_TEAM[hfuben].entertime = System.getNowTime()
    LINGQI_TEAM[hfuben].starttime = 0
    LINGQI_TEAM[hfuben].refreshtime = 0
    LINGQI_TEAM[hfuben].alivecount = 0
    LINGQI_TEAM[hfuben].killcount = 0 --击杀数量
    LINGQI_TEAM[hfuben].conf = conf
    LINGQI_TEAM[hfuben].actors = {}
end

function joinTeam(actor, hfuben)
    if not LINGQI_TEAM[hfuben] then return end
    local teamer = {}
    local var = getActorVar(actor)
    teamer.actorid = LActor.getActorId(actor)
    teamer.isinvite = var.fightcount < LingQiCommonConfig.fightcount + var.buytimes and 1 or 2
    teamer.isclone = 0
    teamer.serverid = LActor.getServerId(actor)
    teamer.name = LActor.getName(actor)
    teamer.job = LActor.getJob(actor)
    teamer.allTimes = var.allTimes + 1
    teamer.fightTimes = 1
    teamer.damage = 0
    table.insert(LINGQI_TEAM[hfuben].actors, teamer)
end

--副本开始刷怪
function startFuben(_, hfuben)
    if not LINGQI_TEAM[hfuben] then return end
    local ins = instancesystem.getInsByHdl(hfuben)
    ins:postponeStart()
    local now = System.getNowTime()
    LINGQI_TEAM[hfuben].refreshtime = now
    ins:setEndTime(now + FubenConfig[LINGQI_TEAM[hfuben].conf.fbId].totalTime)
    
    for i, v in ipairs(LINGQI_TEAM[hfuben].actors) do
        local actor = LActor.getActorById(v.actorid)
        if actor then
            s2cLQBeforeEnter(actor)
        end
    end
    broadFubenInfo(nil, hfuben, true)
end

function getRewardIndex(conf, killcount)
    for k, v in ipairs(conf.grade) do
        if killcount < v then
            return k - 1
        end
    end
    if killcount >= conf.grade[#conf.grade] then
        return #conf.grade
    end
    return 1
end

--创建镜像玩家配打
function setMirror(hfuben, actorid, roleCloneData, actorCloneData, roleSuperData)
    if not LINGQI_TEAM[hfuben] then return end
    if #LINGQI_TEAM[hfuben].actors >= 3 then return end
    roleCloneData.teamId = 1
    local ins = instancesystem.getInsByHdl(hfuben)
    local hScene = ins.scene_list[1]
    if roleSuperData then
        roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
        roleSuperData.aiId = FubenConstConfig.roleSuperAi
    end
    
    LINGQI_TEAM[hfuben].actors[#LINGQI_TEAM[hfuben].actors + 1] = {}
    LINGQI_TEAM[hfuben].actors[#LINGQI_TEAM[hfuben].actors].actorid = actorid
    LINGQI_TEAM[hfuben].actors[#LINGQI_TEAM[hfuben].actors].damage = 0
    LINGQI_TEAM[hfuben].actors[#LINGQI_TEAM[hfuben].actors].isclone = 1
    LINGQI_TEAM[hfuben].actors[#LINGQI_TEAM[hfuben].actors].name = roleCloneData.name
    LINGQI_TEAM[hfuben].actors[#LINGQI_TEAM[hfuben].actors].job = roleCloneData.job
    local pos = LingQiCommonConfig.pos[#LINGQI_TEAM[hfuben].actors]
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

--副本开始前处理
function beforeStart(_, hfuben)
    if not LINGQI_TEAM[hfuben] then return end
    local ins = instancesystem.getInsByHdl(hfuben)
    if #LINGQI_TEAM[hfuben].actors == 0 then
        ins:release()
        return
    end
    if LINGQI_TEAM[hfuben].starttime ~= 0 then return end
    local actorid = LINGQI_TEAM[hfuben].actors[1].actorid
    local actor = LActor.getActorById(actorid)
    local need = 3 - #LINGQI_TEAM[hfuben].actors
    --添加镜像
    while need > 0 do
        --先从战盟里找成员镜像
        local guildId = LActor.getGuildId(actor)
        local guild = LGuild.getGuildById(guildId)
        if guild then
            local members = LGuild.getMemberIdList(guild)
            --从战盟成员列表中删除队伍中已有的成员，防止匹配到同名镜像
            local members_clone = utils.table_clone(members)
            for _, teamer in ipairs(LINGQI_TEAM[hfuben].actors) do
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
                    LDataPack.writeByte(npack, CrossSrvCmd.SCLingQiCmd)
                    LDataPack.writeByte(npack, CrossSrvSubCmd.SCLingQiCmd_ReqActorInfo)
                    LDataPack.writeInt(npack, members_clone[index])
                    LDataPack.writeInt64(npack, hfuben)
                    System.sendPacketToAllGameClient(npack, 0)
                    need = need - 1
                end
            end
        end
        
        if need <= 0 then break end
        --如果战盟镜像不足，则匹配机器人
        local rotCount = #LingQiRobotConfig
        if rotCount > 0 then
            local randRots = utils.getRandomIndexs(1, rotCount, math.min(need, rotCount))
            for _, index in ipairs(randRots) do
                local roleCloneData, actorData, roleSuperData = actorcommon.createRobotClone(LingQiRobotConfig, index, LActor.getServerName(actor) .. ".")
                --机器人属性是玩家属性的百分比
                if actor then
                    local roleAttr = LActor.getRoleAttrsBasic(actor)
                    roleCloneData.attrs:Reset()
                    for j = Attribute.atHp, Attribute.atCount - 1 do
                        if j == Attribute.atShenYouShieldTagNum then
                        elseif j ~= Attribute.atMvSpeed then
                            roleCloneData.attrs:Set(j, roleAttr[j] * LingQiCommonConfig.robotpercent)
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
            print ("lingqi.beforeStart team can't find more mirrors still need: "..need)
        end
        break --匹配完成了，不再继续循环了
    end
    
    for k, v in ipairs(LINGQI_TEAM[hfuben].actors) do
        if v.isclone == 0 then
            local actor = LActor.getActorById(v.actorid)
            if actor then
                local var = getActorVar(actor)
                local exCount = 0
                if v.isinvite == 1 then
                    exCount = neigua.checkOpenNeigua(actor, ins.config.group, LingQiCommonConfig.fightcount + var.buytimes - var.fightcount)
                    var.fightcount = var.fightcount + exCount
                    var.allTimes = (var.allTimes or 0) + exCount
                    v.fightTimes = exCount
                else
                    exCount = neigua.checkOpenNeigua(actor, ins.config.group, LingQiCommonConfig.helpcount - var.helpcount)
                    var.helpcount = var.helpcount + exCount
                    v.fightTimes = exCount
                end
                s2cFightInfo(actor)
                --actorevent.onEvent(actor, aeEnterLingQi, exCount)
            else
                print("lingqifb.beforeStart can't find actor by actorid: ", v.actorid)
            end
        end
    end
    
    LINGQI_TEAM[hfuben].starttime = System.getNowTime()
    LINGQI_TEAM[hfuben].entertime = 0
    LINGQI_TEAM[hfuben].alivecount = #LINGQI_TEAM[hfuben].actors
    broadLQStartCD(hfuben)
    broadFubenInfo(nil, hfuben, true)
    LActor.postScriptEventLite(nil, LingQiCommonConfig.startcd * 1000, startFuben, hfuben)
end

----------------------------------------------------------------------------------
--协议处理
--85-110 灵器界域进入
local function c2sLingQiFight(actor, pack)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.lingqifb) then return end
    if not actorlogin.checkCanEnterCross(actor) then return end
    local hfuben = LDataPack.readUInt(pack)
    local var = getActorVar(actor)
    if var.infuben_hfuben ~= 0 then return end--申请进入副本时，已有队伍
    if hfuben == 0 then
        local zslevel = LActor.getZhuansheng(actor)
        local conf = getConfig(zslevel)
        if not conf then return end
        if var.fightcount >= LingQiCommonConfig.fightcount + var.buytimes then return end
        local actorid = LActor.getActorId(actor)
        var.inspiretimes = 0
        var.atkAdd = 0
        
        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, CrossSrvCmd.SCLingQiCmd)
        LDataPack.writeByte(npack, CrossSrvSubCmd.SCLingQiCmd_GetFubenHdl)
        LDataPack.writeInt(npack, LActor.getActorId(actor))
        LDataPack.writeInt(npack, zslevel)
        System.sendPacketToAllGameClient(npack, 0)
    else
        if var.fightcount >= LingQiCommonConfig.fightcount + var.buytimes and var.helpcount >= LingQiCommonConfig.helpcount then return end
        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, CrossSrvCmd.SCLingQiCmd)
        LDataPack.writeByte(npack, CrossSrvSubCmd.SCLingQiCmd_CheckCanEnter)
        LDataPack.writeInt(npack, LActor.getActorId(actor))
        LDataPack.writeInt(npack, LActor.getZhuansheng(actor))
        LDataPack.writeInt64(npack, hfuben)
        System.sendPacketToAllGameClient(npack, 0)
    end
    var.infuben_hfuben = 1 --由于跨服请求异步处理，需要在本服先行记录，防止进入两支队伍
end

--85-110 副本进入结果
function s2cLingQiFight(actor, result)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sLingQiFuBen_Fight)
    LDataPack.writeChar(pack, result)
    LDataPack.flush(pack)
end

--85-111 邀请玩家
local function c2sLingQiInvite(actor, pack)
    local var = getActorVar(actor)
    local hfuben = var.infuben_hfuben
    if hfuben == 0 then return end
    local type = LDataPack.readChar(pack)
    sendInvite(actor, type, hfuben)
end

--85-111 邀请玩家(发给自己)
function sendInviteToSelf(actor, type, hfuben)
    if not actor then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sLingQiFuBen_Invite)
    if not pack then return end
    LDataPack.writeChar(pack, type)
    LDataPack.writeUInt(pack, hfuben)
    LDataPack.writeString(pack, LActor.getName(actor))
    LDataPack.writeInt(pack, LINGQI_TEAM[hfuben].conf.fbId)
    LDataPack.flush(pack)
end

--85-112 鼓舞
function c2sLingQiInspire(actor, pack)
    local type = LDataPack.readShort(pack)
    local var = getActorVar(actor)
    local hfuben = LActor.getFubenHandle(actor)
    
    if not LINGQI_TEAM[hfuben] or LINGQI_TEAM[hfuben].starttime == 0 then return end
    
    local conf = LingQiInspireConfig[type]
    
    local temp = {} --参与增加的属性
    for k, v in pairs(conf.attrs) do
        if var.atkAdd < conf.attMax then
            table.insert(temp, v)
        end
    end
    if #temp <= 0 then return false end --已加成到最大值
    
    --鼓舞消耗
    local items = type == 1 and LINGQI_TEAM[hfuben].conf.goldSp or LINGQI_TEAM[hfuben].conf.diamondSp
    if not actoritem.checkItems(actor, items) then
        return
    end
    actoritem.reduceItems(actor, items, "lingqifb inspire in")
    
    --加成属性
    local v = temp[math.random(1, #temp)]
    var.atkAdd = var.atkAdd + v.value
    var.inspiretimes = var.inspiretimes + 1
    updateAttr(actor)
    
    s2cXueseInspire(actor, type)
end

--85-112 返回鼓舞信息
function s2cXueseInspire(actor, type)
    local var = getActorVar(actor)
    if var.inspiretimes <= 0 then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sLingQiFuBen_Inspire)
    if pack == nil then return end
    LDataPack.writeInt(pack, var.atkAdd)
    LDataPack.writeChar(pack, type)
    LDataPack.writeByte(pack, var.inspiretimes)
    LDataPack.flush(pack)
end

--85-112 知客户端清鼓舞信息
function s2cXueseInspireClear(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sLingQiFuBen_Inspire)
    if pack == nil then return end
    LDataPack.writeInt(pack, 0)
    LDataPack.writeChar(pack, 1)
    LDataPack.writeByte(pack, 0)
    LDataPack.flush(pack)
end

--85-113 购买挑战次数
local function c2sLingQiBuy(actor)
    local svip = LActor.getSVipLevel(actor)
    local var = getActorVar(actor)
    if var.buytimes >= SVipConfig[svip].lingqifbbuy then return end
    local needCount = LingQiCommonConfig.needdiamond[var.buytimes + 1]
    if not needCount then return end
    if not actoritem.checkItem(actor, NumericType_YuanBao, needCount) then
        return
    end
    actoritem.reduceItem(actor, NumericType_YuanBao, needCount, "buy lingqifb fightTimes")
    
    var.buytimes = var.buytimes + 1
    s2cFightInfo(actor)
end

--85-113 玩家挑战信息
function s2cFightInfo(actor)
    local var = getActorVar(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sLingQiFuBen_FightTimes)
    LDataPack.writeChar(pack, var.fightcount)
    LDataPack.writeChar(pack, var.buytimes)
    LDataPack.writeChar(pack, LingQiCommonConfig.helpcount - var.helpcount)
    LDataPack.flush(pack)
end

--85-114 副本内信息
function broadFubenInfo(_, hfuben, notTimer)
    if not LINGQI_TEAM[hfuben] then return end
    local conf = LINGQI_TEAM[hfuben].conf
    local ins = instancesystem.getInsByHdl(hfuben)
    if not ins then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Cross)
    LDataPack.writeByte(pack, Protocol.sLingQiFuBen_Info)
    LDataPack.writeChar(pack, ins.refresh_monster_idx)
    LDataPack.writeInt(pack, ins.kill_monster_cnt)
    LDataPack.writeChar(pack, #LINGQI_TEAM[hfuben].actors)
    for i = 1, #LINGQI_TEAM[hfuben].actors do
        LDataPack.writeDouble(pack, LINGQI_TEAM[hfuben].actors[i].damage)
        LDataPack.writeString(pack, LINGQI_TEAM[hfuben].actors[i].name)
        LDataPack.writeChar(pack, LINGQI_TEAM[hfuben].actors[i].job)
    end
    LDataPack.writeShort(pack, LINGQI_TEAM[hfuben].refreshtime == 0 and - 1 or LINGQI_TEAM[hfuben].refreshtime + FubenConfig[conf.fbId].totalTime - System.getNowTime())
    
    Fuben.sendData(hfuben, pack)
    if not notTimer then
        LActor.postScriptEventLite(nil, 2 * 1000, broadFubenInfo, hfuben)
    end
end

--85-115 副本结算
function s2cLingQiResult(actor, usetime, killcount, items, conf)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sLingQiFuBen_Result)
    LDataPack.writeShort(pack, usetime)
    LDataPack.writeShort(pack, killcount)
    LDataPack.writeChar(pack, #items)
    for _, rconf in ipairs(items) do
        LDataPack.writeInt(pack, rconf.id)
        LDataPack.writeInt(pack, rconf.count)
        --LDataPack.writeByte(pack, double == 2 and 1 or 0)
        LDataPack.writeByte(pack, 0)
    end
    LDataPack.writeInt(pack, conf.fbId)
    LDataPack.flush(pack)
end

--85-116 玩家组队剩余时间
function s2cLingQiTeamCD(actor)
    local hfuben = LActor.getFubenHandle(actor)
    if not LINGQI_TEAM[hfuben] then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sLingQiFuBen_TeamCD)
    local remaintime = LingQiCommonConfig.teamcd - (System.getNowTime() - LINGQI_TEAM[hfuben].entertime)
    LDataPack.writeShort(pack, remaintime > 0 and remaintime or 0)
    LDataPack.writeByte(pack, LActor.getActorId(actor) == LINGQI_TEAM[hfuben].actors[1].actorid and 1 or 2)
    LDataPack.flush(pack)
end

--85-117 玩家副本开始剩余时间
function broadLQStartCD(hfuben)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Cross)
    LDataPack.writeByte(pack, Protocol.sLingQiFuBen_StartCD)
    local remaintime = LingQiCommonConfig.startcd - (System.getNowTime() - LINGQI_TEAM[hfuben].starttime)
    LDataPack.writeShort(pack, remaintime > 0 and remaintime or 0)
    Fuben.sendData(hfuben, pack)
end

--85-118 灵器界域进入副本前信息
function s2cLQBeforeEnter(actor)
    local var = getActorVar(actor)
    if not var then return end
    local hfuben = var.infuben_hfuben
    local invite = getFubenInvite(hfuben, LActor.getActorId(actor))
    if not invite then return end
    if not LINGQI_TEAM[hfuben] or not LINGQI_TEAM[hfuben].conf then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sLingQiFuBen_BeforEnter)
    LDataPack.writeChar(pack, invite)
    local conf = LINGQI_TEAM[hfuben].conf
    local refreshtime = LINGQI_TEAM[hfuben].refreshtime
    LDataPack.writeShort(pack, refreshtime == 0 and - 1 or refreshtime + FubenConfig[conf.fbId].totalTime - System.getNowTime())
    LDataPack.writeInt(pack, conf.fbId)
    LDataPack.flush(pack)
end

----------------------------------------------------------------------------------
--跨服协议
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
    LDataPack.writeByte(npack, CrossSrvCmd.SCLingQiCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCLingQiCmd_SendActorInfo)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeInt64(npack, LDataPack.readInt64(cpack))
    LDataPack.writeUserData(npack, actorDataUd)
    
    System.sendPacketToAllGameClient(npack, 0)
end

--发送邀请
function sendInvite(actor, type, hfuben)
    local guildId = LActor.getGuildId(actor)
    if type ~= 1 and guildId == 0 then return end
    if not LINGQI_TEAM[hfuben] then return end
    sendInviteToSelf(actor, type, hfuben)
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCLingQiCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCLingQiCmd_InviteActor)
    LDataPack.writeChar(npack, type)
    LDataPack.writeUInt(npack, hfuben)
    LDataPack.writeString(npack, LActor.getName(actor))
    LDataPack.writeInt(npack, LINGQI_TEAM[hfuben].conf.fbId)
    LDataPack.writeInt(npack, guildId)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onGetFubenHdl(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local zslevel = LDataPack.readInt(cpack)
    local conf = getConfig(zslevel)
    if not conf then return end
    
    local hfuben = instancesystem.createFuBen(conf.fbId)
    if LINGQI_TEAM[hfuben] then return end
    local ins = instancesystem.getInsByHdl(hfuben)
    initGlobal(hfuben, conf)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCLingQiCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCLingQiCmd_SendFubenHdl)
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
    
    s2cLingQiFight(actor, 4)
    actorcommon.setTeamId(actor, 1)
    --broadFubenInfo(nil, hfuben)
    s2cFightInfo(actor)
    
    local crossId = csbase.getCrossServerId()
    local x, y = utils.getSceneEnterCoor(fbId)
    LActor.loginOtherServer(actor, crossId, hfuben, 0, x, y, "cross")
end

local function onGetInviteActor(sId, sType, cpack)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_Cross)
    LDataPack.writeByte(pack, Protocol.sLingQiFuBen_Invite)
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

local function onCheckCanEnter(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local zslevel = LDataPack.readInt(cpack)
    local hfuben = LDataPack.readInt64(cpack)
    
    if not LINGQI_TEAM[hfuben] then
        sendErrorTip(actorid, sId, 2)
        return
    end
    local conf = LINGQI_TEAM[hfuben].conf
    if zslevel < conf.zslevel then
        sendErrorTip(actorid, sId, 5)
        return
    end
    
    if LINGQI_TEAM[hfuben].starttime ~= 0 or LINGQI_TEAM[hfuben].refreshtime ~= 0 or #LINGQI_TEAM[hfuben].actors >= 3 then
        sendErrorTip(actorid, sId, 3)
        return
    end
    
    if #LINGQI_TEAM[hfuben].actors == 0 then return end--队员要等队长进入之后才可以进入
    for i = 1, #LINGQI_TEAM[hfuben].actors do
        if LINGQI_TEAM[hfuben].actors[i].actorid == actorid then return end
    end
    sendErrorTip(actorid, sId, 4, conf.fbId, hfuben)
end

function sendErrorTip(actorid, sId, errorid, fbId, hfuben)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCLingQiCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCLingQiCmd_SendErrorTip)
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
        s2cLingQiFight(actor, 2)
        return
    end
    if errorid == 5 then
        var.infuben_hfuben = 0
        s2cLingQiFight(actor, 5)
        return
    end
    
    if errorid == 3 then
        var.infuben_hfuben = 0
        s2cLingQiFight(actor, 3)
        return
    end
    
    actorcommon.setTeamId(actor, 1)
    s2cLingQiFight(actor, 4)
    
    var.infuben_hfuben = hfuben
    var.inspiretimes = 0
    var.atkAdd = 0
    
    local crossId = csbase.getCrossServerId()
    local x, y = utils.getSceneEnterCoor(fbId)
    LActor.loginOtherServer(actor, crossId, hfuben, 0, x, y, "cross")
    s2cFightInfo(actor)
end

----------------------------------------------------------------------------------
--事件处理

local function onLose(ins)
    local hfuben = ins.handle
    LINGQI_TEAM[hfuben] = nil
end

--结算
local function onWin(ins)
    local hfuben = ins.handle
    broadFubenInfo(nil, hfuben, true)
    if not LINGQI_TEAM[hfuben] then return end
    local conf = LINGQI_TEAM[hfuben].conf
    local double = 1
    -- if subactivity12.checkIsStart() then
    --     double = 2
    -- end
    local usetime = System.getNowTime() - LINGQI_TEAM[hfuben].refreshtime
    local killcount = LINGQI_TEAM[hfuben].killcount
    for k, v in ipairs(LINGQI_TEAM[hfuben].actors) do
        if v.isclone == 0 then
            local items = {}
            for _ = 1, v.fightTimes do
                local dropId = 0
                if v.isinvite == 1 then
                    if v.allTimes <= #LingQiCommonConfig.juqingDrop then
                        dropId = LingQiCommonConfig.juqingDrop[v.allTimes]
                    else
                        dropId = conf.rewardDrop[getRewardIndex(conf, killcount)]
                    end
                else
                    dropId = conf.helpDrop[getRewardIndex(conf, killcount)]
                end
                local rewards = drop.dropGroup(dropId)
                for _, item in ipairs(rewards) do
                    table.insert(items, {type = item.type, id = item.id, count = item.count * double})
                end
            end
            
            local actor = LActor.getActorById(v.actorid)
            if actor and LActor.getFubenHandle(actor) == hfuben then
                actoritem.addItems(actor, items, "lingqifb reward")
                s2cLingQiResult(actor, usetime, killcount, items, conf)
            else
                local mail_data = {}
                mail_data.head = LingQiCommonConfig.mailtitle
                mail_data.context = LingQiCommonConfig.mailcontent
                mail_data.tAwardList = items
                mailsystem.sendMailById(v.actorid, mail_data, v.serverid)
            end
        end
    end
    LINGQI_TEAM[hfuben] = nil
end

--进入副本
local function onEnterFb(ins, actor, islogin)
    local hfuben = ins.handle
    local actors = ins:getActorList()
    if not LINGQI_TEAM[hfuben] then LActor.exitFuben(actor) return end
    if LINGQI_TEAM[hfuben].starttime ~= 0 then return end
    if not LINGQI_TEAM[hfuben].team_eid then
        LINGQI_TEAM[hfuben].team_eid = LActor.postScriptEventLite(nil, LingQiCommonConfig.teamcd * 1000, beforeStart, hfuben)
    end
    
    if #LINGQI_TEAM[hfuben].actors == 3 then
        LActor.cancelScriptEvent(nil, LINGQI_TEAM[hfuben].team_eid)
        beforeStart(nil, hfuben)
    end
    
    local var = getActorVar(actor)
    var.infuben_hfuben = hfuben
    updateAttr(actor)
    s2cLingQiTeamCD(actor)
    broadFubenInfo(nil, hfuben, false)--false表示循环发送副本信息
    local pos = LingQiCommonConfig.pos[#LINGQI_TEAM[hfuben].actors]
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
    if not LINGQI_TEAM[hfuben] or #LINGQI_TEAM[hfuben].actors >= 3 or LINGQI_TEAM[hfuben].starttime ~= 0 then
        LActor.exitFuben(actor)
        return
    end
    
    joinTeam(actor, hfuben)
    local var = getActorVar(actor)
    var.infuben_hfuben = hfuben
    s2cLQBeforeEnter(actor)
    actorcommon.setTeamId(actor, 1)
    actorevent.onEvent(actor, aeNotifyFacade, -1)
end

--离线处理
local function onOffline(ins, actor)
    actorcommon.setTeamId(actor, 0)
    local hfuben = ins.handle
    if not LINGQI_TEAM[hfuben] then return end
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
    
    if not LINGQI_TEAM[hfuben] then return end
    if LINGQI_TEAM[hfuben].starttime == 0 then --副本未开始
        local actors = Fuben.getAllActor(hfuben)
        if not actors or #actors <= 1 then
            ins:lose()
        else
            local selfid = LActor.getActorId(actor)
            for i = 1, #LINGQI_TEAM[hfuben].actors do
                if selfid == LINGQI_TEAM[hfuben].actors[i].actorid then
                    table.remove(LINGQI_TEAM[hfuben].actors, i)
                    break
                end
            end
            broadFubenInfo(nil, hfuben, true)
        end
    else
        local actors = Fuben.getAllActor(hfuben)
        if not actors or #actors <= 1 then
            ins:win()
        end
        --s2cXueseInspireClear(actor)
    end
end

--造成伤害
local function onDamage(ins, monster, value, attacker, res)
    local hfuben = ins.handle
    local attacker_type = LActor.getEntityType(attacker)
    if EntityType_RoleClone == attacker_type or EntityType_RoleSuperClone == attacker_type then
        local actorClone = LActor.getActorClone(attacker)
        local selfactorid = LActor.getActorIdClone(actorClone)
        for i = 1, #LINGQI_TEAM[hfuben].actors do
            if LINGQI_TEAM[hfuben].actors[i].actorid == selfactorid then
                LINGQI_TEAM[hfuben].actors[i].damage = LINGQI_TEAM[hfuben].actors[i].damage + value
                break
            end
        end
    elseif EntityType_Role == attacker_type or EntityType_RoleSuper == attacker_type then
        local actor = LActor.getActor(attacker)
        local selfactorid = LActor.getActorId(actor)
        for i = 1, #LINGQI_TEAM[hfuben].actors do
            if LINGQI_TEAM[hfuben].actors[i].actorid == selfactorid then
                LINGQI_TEAM[hfuben].actors[i].damage = LINGQI_TEAM[hfuben].actors[i].damage + value
                break
            end
        end
    end
end

local function onMonsterDie(ins, mon, killHdl)
    if ins.is_end then return end
    local hfuben = ins.handle
    local killcount = LINGQI_TEAM[hfuben].killcount + 1
    LINGQI_TEAM[hfuben].killcount = killcount
    if killcount >= LingQiCommonConfig.monstermaxcount then
        ins:win()
    end
end

function onLogin(actor)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.lingqifb) then return end
    s2cFightInfo(actor)
    s2cXueseInspire(actor, 1)
    local var = getActorVar(actor)
    var.infuben_hfuben = 0
end

function onNewDay(actor, login)
    --if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.lingqifb) then return end
    local var = getActorVar(actor)
    var.fightcount = 0
    var.helpcount = 0
    var.buytimes = 0
    if not login then
        s2cFightInfo(actor)
    end
end

----------------------------------------------------------------------------------
--初始化
local function init()
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewDay)
    
    if System.isLianFuSrv() then return end
    csmsgdispatcher.Reg(CrossSrvCmd.SCLingQiCmd, CrossSrvSubCmd.SCLingQiCmd_GetFubenHdl, onGetFubenHdl)
    csmsgdispatcher.Reg(CrossSrvCmd.SCLingQiCmd, CrossSrvSubCmd.SCLingQiCmd_SendFubenHdl, onSendFubenHdl)
    csmsgdispatcher.Reg(CrossSrvCmd.SCLingQiCmd, CrossSrvSubCmd.SCLingQiCmd_CheckCanEnter, onCheckCanEnter)
    csmsgdispatcher.Reg(CrossSrvCmd.SCLingQiCmd, CrossSrvSubCmd.SCLingQiCmd_SendErrorTip, onSendErrorTip)
    csmsgdispatcher.Reg(CrossSrvCmd.SCLingQiCmd, CrossSrvSubCmd.SCLingQiCmd_InviteActor, onGetInviteActor)
    csmsgdispatcher.Reg(CrossSrvCmd.SCLingQiCmd, CrossSrvSubCmd.SCLingQiCmd_ReqActorInfo, onReqActorInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCLingQiCmd, CrossSrvSubCmd.SCLingQiCmd_SendActorInfo, onSendActorInfo)
    
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cLingQiFuBen_Invite, c2sLingQiInvite)
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cLingQiFuBen_Inspire, c2sLingQiInspire)
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cLingQiFuBen_BuyTimes, c2sLingQiBuy)
    
    --注册相关回调
    for _, conf in pairs(LingQiFubenConfig) do
        insevent.registerInstanceEnterBefore(conf.fbId, onBeforeEnterFb)
        insevent.registerInstanceEnter(conf.fbId, onEnterFb)
        insevent.registerInstanceMonsterDamage(conf.fbId, onDamage)
        insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
        insevent.registerInstanceExit(conf.fbId, onExitFb)
        insevent.registerInstanceOffline(conf.fbId, onOffline)
        insevent.registerInstanceWin(conf.fbId, onWin)
        insevent.registerInstanceLose(conf.fbId, onLose)
    end
    if System.isBattleSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cLingQiFuBen_Fight, c2sLingQiFight)
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.lqfight = function (actor, args)
    local pack = LDataPack.allocPacket()
    LDataPack.writeUInt(pack, 0)
    LDataPack.setPosition(pack, 0)
    c2sLingQiFight(actor, pack)
end

