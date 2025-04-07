--@rancho 20170425
--不好区分系统的通用接口可以放这里
module("actorcommon", package.seeall)

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var then return end
    if not var.commonData then
        var.commonData = {}
    end
    return var.commonData
end

--返回加成经验属性，
function getActorDropExpRate(actor)
    local attr = LActor.getRoleAttrsBasic(actor)
    return attr[Attribute.atDropExpPer]
end

--返回加成经验属性，
function getActorDropGoldRate(actor)
    local attr = LActor.getRoleAttrsBasic(actor)
    return attr[Attribute.atDropGoldPer]
end

function getDropGoldRate(actor)
    --属性加成
    local attrRate = getActorDropGoldRate(actor) / 10000
    
    local rate = attrRate
    return rate
end


function getDropExpRate(actor)
    --属性加成
    local attrRate = getActorDropExpRate(actor) / 10000
    
    --双倍卡加成
    local doubleRate = item.getExpCoe(actor)
    
    local rate = attrRate + doubleRate
    return rate
end

--求技能id
function getSkillId(job, idx)
    return job * 100 + idx
end

function getVipShow(actor, svip, vip)
    if actor or svip or vip then
        svip = svip or LActor.getSVipLevel(actor)
        if svip > 0 then
            return "|C:0xf01414&T:[SVIP"..svip.."]|"
        else
            vip = vip or LActor.getVipLevel(actor)
            return "|C:0xDD6717&T:[VIP"..vip.."]|"
        end
    else
        return "|C:0xDD6717&T:[VIP1]|"
    end
end

function isActor(entitytype)
    return EntityType_Actor == entitytype or EntityType_Role == entitytype or EntityType_RoleSuper == entitytype or EntityType_Yonbing == entitytype
end

--获取创建克隆人的数据
function getCloneData(actorId)
    local roleCloneData = nil
    local actorCloneData = nil
    local roleSuperData = nil
    local actor = LActor.getActorById(actorId)
    if actor then --玩家在线
        local actorData = LActor.getActorData(actor)
        local attrsData = LActor.getRoleAttrsBasic(actor)
        
        actorCloneData = RobotActorData:new_local()
        actorCloneData.meilinchoose = meilinsystem.getActorVar(actor).choose
        local yonbingvar = yongbingsystem.getActorVar(actor)
        actorCloneData.yongbingchoose = yonbingvar.yongbingchoose
        actorCloneData.yonbingfazhen = yonbingvar.mozhenchoose
        local yongbingskilllv = passiveskill.getSkillLv(actor, YongbingConstConfig.levelskills[1])
        actorCloneData.yongbingskill = SkillPassiveConfig[YongbingConstConfig.levelskills[1]][yongbingskilllv].other
        local damonvar = damonsystem.getActorVar(actor)
        actorCloneData.damonchoose = damonvar.damonchoose
        actorCloneData.damonfazhen = damonvar.mozhenchoose
        actorCloneData.passive_count = actorData.passive_count
        actorCloneData.serverId = actorData.server_index
        actorCloneData.shield_id = getShenYouShieldId(actor) -- 神佑护盾幻化id
        for i = 0, actorCloneData.passive_count - 1 do
            actorCloneData.passiveskillsid[i] = actorData.passiveskills[i].id
            actorCloneData.passiveskillslevel[i] = actorData.passiveskills[i].level
        end
        
        local d = RobotData:new_local()
        d.name = actorData.actor_name
        d.level = actorData.level
        d.job = actorData.job
        d.title = titlesystem.getRoleTitle(actor) or 0
        d.guildId = actorData.guild_id_
        d.guildName = guildcommon.getGuilNameById(actorData.guild_id_) or ''
        d.guildPos = LActor.getGuildPos(actor)
        d.touxian = touxiansystem.getTouxianStage(actor)
        d.junxian = liliansystem.getJunxianStage(actor)
        d.shenqichoose = shenqisystem.getActorVar(actor).choose
        d.shenzhuangchoose = shenzhuangsystem.getActorVar(actor).choose
        d.wingchoose = wingsystem.getWingId(actor)
        d.attrs:Reset()
        d.total_power = actorData.total_power
        d.mozhen = shenmosystem.getShenmoFazhen(actor)
        --d.plunderCnt = actoritem.getItemCount(actor, PkConstConfig.itemId) or 0  --野外pk抢夺物品数量
        for j = Attribute.atHp, Attribute.atCount - 1 do
            d.attrs:Set(j, attrsData[j])
        end
        for j = 1, SkillsLen_Max do
            d.skills[j - 1] = getSkillId(actorData.job, j)
            d.skillLevels[j - 1] = actorData.skills[j - 1].skill_level
        end
        d.ai = FubenConstConfig.jobAi[actorData.job]
        d.shengling_id = getShengLingId(actor)
        d.shield_skill_id = LActor.getShenyouShieldSkillId(actor) -- 护盾技能
        d.shield_use_skill_id = shenyousystem.getShieldUseSkill(actor) -- 盾爆技能
        d.shield_tag_skill_id = LActor.getShenyouTagSkillId(actor) -- 印记技能
        
        roleCloneData = d
        roleSuperData = shenmosystem.getChangeInfo(actor)
    else --玩家不在线
        local actorData = offlinedatamgr.GetDataByOffLineDataType(actorId, offlinedatamgr.EOffLineDataType.EBasic)
        --local tData = offlinedatamgr.GetDataByOffLineDataType(actorId, offlinedatamgr.EOffLineDataType.EOperable)
        if not actorData then
            print("actorcommon.getCloneData not actordata actorId:" .. actorId)
            return createRobotClone(JjcRobotConfig, 1000)
        end
        actorCloneData = RobotActorData:new_local()
        actorCloneData.meilinchoose = actorData.meilinchoose
        actorCloneData.yongbingchoose = actorData.yongbingchoose
        actorCloneData.yonbingfazhen = actorData.yonbingfazhen
        actorCloneData.yongbingskill = actorData.yongbingskill
        actorCloneData.damonchoose = actorData.damonchoose
        actorCloneData.damonfazhen = actorData.damonfazhen
        actorCloneData.passive_count = actorData.passive_count
        actorCloneData.serverId = actorData.serverId
        actorCloneData.shield_id = actorData.shield_id or 0;
        for i = 0, actorCloneData.passive_count - 1 do
            actorCloneData.passiveskillsid[i] = actorData.passiveskills[i].id
            actorCloneData.passiveskillslevel[i] = actorData.passiveskills[i].level
        end
        
        local d = RobotData:new_local()
        d.name = actorData.actor_name
        d.level = actorData.level
        d.job = actorData.job
        d.title = actorData.title or 0
        d.guildId = actorData.guild_id_
        d.guildName = guildcommon.getGuilNameById(actorData.guild_id_)
        d.guildPos = actorData.guild_pos or 0
        d.touxian = actorData.touxian
        d.junxian = actorData.junxian
        d.mozhen = actorData.mozhen
        d.shenqichoose = actorData.shenqichoose
        d.shenzhuangchoose = actorData.shenzhuangchoose
        d.wingchoose = actorData.wingchoose
        d.attrs:Reset()
        d.total_power = actorData.total_power
        d.serverId = actorData.serverId
        --d.plunderCnt = tData.plunderCnt or 0  --野外pk抢夺物品数量
        
        d.attrs:Reset()
        for j = Attribute.atHp, Attribute.atCount - 1 do
            d.attrs:Set(j, actorData.attrs[j] or 0)
        end
        for j = 0, SkillsLen_Max - 1 do
            d.skills[j] = getSkillId(actorData.job, j + 1) or 0
            d.skillLevels[j] = actorData.skills[j]
        end
        d.ai = FubenConstConfig.jobAi[actorData.job]
        d.shengling_id = actorData.shengling_id or 0
        d.shield_skill_id = actorData.shield_skill_id or 0 -- 护盾技能
        d.shield_use_skill_id = actorData.shield_use_skill_id or 0 -- 盾爆技能
        d.shield_tag_skill_id = actorData.shield_tag_skill_id or 0 -- 印记技能
        
        roleCloneData = d
        roleSuperData = shenmosystem.getChangeInfoById(actorData.shenmochoose)
    end
    return roleCloneData, actorCloneData, roleSuperData
end

function createRobotClone(conf, index, servername, cloneName)
    local roleCloneData = {}
    local damonData = nil
    local rconf = conf[index]
    if not rconf then return end
    local v = rconf
    local d = RobotData:new_local()
    d.name = cloneName or ((servername or (chatcommon.getServerConfName() .. "."))..v.name)
    d.level = v.level
    d.job = v.job
    d.shenzhuangchoose = v.shenzhuang
    d.shenqichoose = v.shenqi
    d.wingchoose = v.wing or 0
    d.touxian = 0
    d.junxian = 0
    d.guildId = 0
    d.guildName = ""
    d.guildPos = 0
    d.serverId = 0
    d.mozhen = 0
    d.attrs:Reset()
    d.total_power = v.power
    
    local actorCloneData = RobotActorData:new_local()
    actorCloneData.yongbingchoose = v.yongbing
    actorCloneData.yongbingai = v.yongbingAi or actorCloneData.yongbingai
    actorCloneData.damonchoose = v.damon or 0
    actorCloneData.damonfazhen = 0
    actorCloneData.meilinchoose = v.meilin or 0
    
    local attrPer = 1
    if rconf.attrRand then
    	local rand = math.random(rconf.attrRand[1] or 100, rconf.attrRand[2] or 100)
    	attrPer = rand / 100
    end
    for j, jv in pairs(v.attrs) do
        d.attrs:Set(jv.type, jv.value * attrPer)
    end
    for j, jv in pairs(v.skills) do
        d.skills[j - 1] = jv
        d.skillLevels[j - 1] = 1
    end
    d.ai = v.ai
    d.shengling_id = v.shengling_id or 0
    d.shield_skill_id = v.shield_skill_id or 0 -- 护盾技能
    d.shield_use_skill_id = v.shield_use_skill_id or 0 -- 盾爆技能
    d.shield_tag_skill_id = v.shield_tag_skill_id or 0 -- 印记技能
    
    roleCloneData = d
    local roleSuperData = shenmosystem.getChangeInfoById(v.shenmoid)
    
    return roleCloneData, actorCloneData, roleSuperData
end

--####
function getCloneDataByOffLineData(actorData)
    if not actorData then return end
    if not actorData.actor_name then return end
    
    local roleCloneData = {}
    local actorCloneData = nil
    local roleSuperData = nil
    if not actorData then
        print("actorcommon.getCloneData not actordata actorId:")
        return createRobotClone(JjcRobotConfig, 1000)
    end
    actorCloneData = RobotActorData:new_local()
    actorCloneData.meilinchoose = actorData.meilinchoose
    actorCloneData.yongbingchoose = actorData.yongbingchoose
    actorCloneData.yonbingfazhen = actorData.yonbingfazhen
    actorCloneData.yongbingskill = actorData.yongbingskill
    actorCloneData.damonchoose = actorData.damonchoose
    actorCloneData.damonfazhen = actorData.damonfazhen
    actorCloneData.passive_count = actorData.passive_count
    actorCloneData.mozhen = actorData.mozhen
    actorCloneData.serverId = actorData.serverId
    for i = 0, actorCloneData.passive_count - 1 do
        actorCloneData.passiveskillsid[i] = actorData.passiveskills[i].id
        actorCloneData.passiveskillslevel[i] = actorData.passiveskills[i].level
    end
    
    local d = RobotData:new_local()
    d.name = actorData.actor_name
    d.level = actorData.level
    d.job = actorData.job
    d.title = actorData.title or 0
    d.guildId = actorData.guild_id_
    d.guildName = actorData.guild_name_
    d.guildPos = actorData.guild_pos
    d.touxian = actorData.touxian
    d.junxian = actorData.junxian
    d.shenqichoose = actorData.shenqichoose
    d.shenzhuangchoose = actorData.shenzhuangchoose
    d.wingchoose = actorData.wingchoose
    d.attrs:Reset()
    d.total_power = actorData.total_power
    --d.plunderCnt = tData.plunderCnt or 0  --野外pk抢夺物品数量
    
    d.attrs:Reset()
    for j = Attribute.atHp, Attribute.atCount - 1 do
        d.attrs:Set(j, actorData.attrs[j] or 0)
    end
    for j = 0, SkillsLen_Max - 1 do
        if actorData.skills[j] > 0 then
            d.skills[j] = getSkillId(actorData.job, j + 1) or 0
            d.skillLevels[j] = actorData.skills[j]
        end
    end
    d.ai = FubenConstConfig.jobAi[actorData.job]
    d.shield_skill_id = actorData.shield_skill_id or 0
    d.shield_use_skill_id = actorData.shield_use_skill_id or 0
    d.shield_tag_skill_id = actorData.shield_tag_skill_id or 0
    roleCloneData = d
    roleSuperData = shenmosystem.getChangeInfoById(actorData.shenmochoose)
    
    return roleCloneData, actorCloneData, roleSuperData
end

function setTeamId(actor, id)
    local var = getActorVar(actor)
    var.teamId = id
end

function getTeamId(actor)
    local var = getActorVar(actor)
    return var.teamId or 0
end
_G.getTeamId = getTeamId

function setSkillParam(actor, roleId, skillId, skillParam, skillPlus)
    refreshSkillParam(actor, roleId, skillId, nil, skillPlus, skillParam)
end

function refreshSkillParam(actor, roleId, skillId, sysId, skillPlus, skillParam)
    if not skillPlus then
        return
    end
    if skillParam == nil then
        skillParam = LActor.getRoleSysSkillParam(actor, roleId, skillId, sysId)
        if not skillParam then return end
    end
    
    skillParam:Reset()
    
    skillParam.a = skillPlus.a or 0
    skillParam.b = skillPlus.b or 0
    
    if skillPlus.selfAttr then
        local attr = skillParam:CreateSelfAttr()
        local addAttr = skillPlus.selfAttr
        for k = 1, #addAttr do
            attr:Set(addAttr[k].type, addAttr[k].value)
        end
    end
    
    if skillPlus.targetAttr then
        local attr = skillParam:CreateTargetAttr()
        local addAttr = skillPlus.targetAttr
        for k = 1, #addAttr do
            attr:Set(addAttr[k].type, addAttr[k].value)
        end
    end
    
    if skillPlus.selfEffectIdVec then
        local effectIdVec = skillPlus.selfEffectIdVec
        for k = 1, #effectIdVec do
            skillParam:AddSelfEffectId(effectIdVec[k])
        end
    end
    
    if skillPlus.targetEffectIdVec then
        local effectIdVec = skillPlus.targetEffectIdVec
        for k = 1, #effectIdVec do
            skillParam:AddTargetEffectId(effectIdVec[k])
        end
    end
    
    if skillPlus.effectPlusMap then
        local effectPlusMap = skillPlus.effectPlusMap
        for effectId, effectArgsConf in pairs(effectPlusMap) do
            local effectParam = EffectParam:new_local()
            effectParam.effectId = effectId
            local effectArgs = effectParam.effectArgs
            effectArgs.a = effectArgsConf.a or 0
            effectArgs.c = effectArgsConf.c or 0
            skillParam:SetEffectPlus(effectParam)
        end
    end
end
