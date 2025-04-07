require "scene.fuben"

local fuben_cfg = FubenConfig

module("taskevent", package.seeall)

--[[
  任务条件记录
  taskEventRecord = {
type: value number  -- (type: taskcommon.taskType  value:条件累积值
  }
--]]

--外部接口
function getRecord(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then
        print("get taskevent static data error")
        return nil
    end
    
    if var.taskEventRecord == nil then
        var.taskEventRecord = {}
        --此处不做初始化, 防止类型扩展时初始化不到
    end
    return var.taskEventRecord
end

function needParam(type)
    if type == taskcommon.taskType.emEquipEnhanceCount
        or type == taskcommon.taskType.emEquipEnhanceLevel
        or type == taskcommon.taskType.emEquipAppendLevel
        or type == taskcommon.taskType.emEquipQuality
        or type == taskcommon.taskType.emEquipRank
        or type == taskcommon.taskType.emEnterDespair
        or type == taskcommon.taskType.emMonsterCount
        or type == taskcommon.taskType.emPassDup
        or type == taskcommon.taskType.emPassTypeDup
        or type == taskcommon.taskType.emFinishDup
        or type == taskcommon.taskType.emFinishTypeDup
        or type == taskcommon.taskType.emElementQuality
        or type == taskcommon.taskType.emInterGuajifu
        or type == taskcommon.taskType.emSkillLearn
        or type == taskcommon.taskType.emDespairBoss
        or type == taskcommon.taskType.emBeatCustom
        or type == taskcommon.taskType.emSaoDangDup
        or type == taskcommon.taskType.emSaoDangTypeDup
        or type == taskcommon.taskType.emComposeItem
        or type == taskcommon.taskType.emCostItem
        or type == taskcommon.taskType.emFruitEat
        or type == taskcommon.taskType.emTalentUp
        or type == taskcommon.taskType.emBeatShilian
        or type == taskcommon.taskType.emTujianOpen
        or type == taskcommon.taskType.emEnterFubenTpAdd
        or type == taskcommon.taskType.emFinishFubenTpAdd
        or type == taskcommon.taskType.emActiveFubenAdd
        or type == taskcommon.taskType.emEnterKalima
        or type == taskcommon.taskType.emEquipGoodNum
        or type == taskcommon.taskType.emDamonQuality
        or type == taskcommon.taskType.emElementCnt
        or type == taskcommon.taskType.emEnhanceLv
        or type == taskcommon.taskType.emSMUpgradeCnt
        or type == taskcommon.taskType.emBuyStoreItem
        or type == taskcommon.taskType.emShenmoId
        or type == taskcommon.taskType.emShenhun
        or type == taskcommon.taskType.emEnhanceEquipCount
        or type == taskcommon.taskType.emEnterDespireBoss
        or type == taskcommon.taskType.emSuitId
        or type == taskcommon.taskType.emShenqiFacade
        or type == taskcommon.taskType.emShenzhuangFacade
        or type == taskcommon.taskType.emWingFacade
        or type == taskcommon.taskType.emMeilinFacade
        or type == taskcommon.taskType.emFacade
        or type == taskcommon.taskType.emEquipStarCount
        or type == taskcommon.taskType.emWXZhuangshenglvAdd
        or type == taskcommon.taskType.emWXSViplvAdd
        or type == taskcommon.taskType.emWXZhuangshenglv
        or type == taskcommon.taskType.emWXSViplv
        or type == taskcommon.taskType.emLHKillMonsterAdd
        or type == taskcommon.taskType.emYuanSuLevelUpAdd
        or type == taskcommon.taskType.emShenlingSatgeAdd
        then
        return true
    else
        return false
    end
end

local initRecordFuncs = {
}
--initRecordFuncs[taskcommon.taskType.emChapterLevel] = LActor.getChapterLevel

--后面扩展的任务类型才需要,前面的任务不需要初始化功能
function initRecord(type, actor)
    if initRecordFuncs[type] then
        return initRecordFuncs[type](actor)
    else
        return 0
    end
end

--战斗服通知普通服触发事件
function transferEvent(actorId, serverId, eventType, param, count)
    if System.isCommSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCrossNetCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCrossNetCmd_TransferEvent)
    LDataPack.writeInt(pack, actorId)
    LDataPack.writeInt(pack, eventType)
    LDataPack.writeInt(pack, param)
    LDataPack.writeInt(pack, count)
    System.sendPacketToAllGameClient(pack, serverId)
end

local function onTransferEvent(sId, sType, dp)
    if System.isCrossWarSrv() then return end
    local actorId = LDataPack.readInt(dp)
    local eventType = LDataPack.readInt(dp)
    local param = LDataPack.readInt(dp)
    local count = LDataPack.readInt(dp)
    
    local actor = LActor.getActorById(actorId)
    if actor then
        actorevent.onEvent(actor, eventType, param, count)
    else
        sendTaskEventOffMsg(actorId, eventType, param, count)
    end
end

function sendTaskEventOffMsg(actorId, eventType, param, count)
    if System.isCrossWarSrv() then return end
    local pack = LDataPack.allocPacket()
    LDataPack.writeInt(pack, eventType)
    LDataPack.writeInt(pack, param)
    LDataPack.writeDouble(pack, count)
    System.sendOffMsg(actorId, 0, OffMsgType_TASKEVENT, pack)
end

function OffMsgTASKEVENT(actor, offmsg)
    local eventType = LDataPack.readInt(offmsg)
    local param = LDataPack.readInt(offmsg)
    local count = LDataPack.readDouble(offmsg)
    print(string.format("OffMsgTASKEVENT actorId:%d eventType:%d param:%d count:%d", LActor.getActorId(actor), eventType, param, count))
    actorevent.onEvent(actor, eventType, param, count)
end

local function updateTask(actor, type, param, count)
    if type == taskcommon.taskType.emMonsterCount then
        adventure.updateTaskValue(actor, type, param, count)
    elseif type == taskcommon.taskType.emCustomWave then
        maintask.updateTaskValue(actor, type, param, count)
    else
        maintask.updateTaskValue(actor, type, param, count)
        agreementtask.updateTaskValue(actor, type, param, count)
        touxiansystem.updateTaskValue(actor, type, param, count)
        subactivity3.updateTaskValue(actor, type, param, count)
        subactivity15.updateTaskValue(actor, type, param, count)
        zhuansheng.updateTaskValue(actor, type, param, count)
        liliansystem.updateTaskValue(actor, type, param, count)
        adventure.updateTaskValue(actor, type, param, count)
        yongzhe.updateTaskValue(actor, type, param, count)
        subactivity39.updateTaskValue(actor, type, param, count)
        dashisystem.updateTaskValue(actor, type, param, count)
    end
end

function onSmeltEquip(actor, count)
    --local record = getRecord(actor)
    --record[taskcommon.taskType.emSmeltEquip] = (record[taskcommon.taskType.emSmeltEquip] or 0) + count
    updateTask(actor, taskcommon.taskType.emSmeltEquip, 0, count)
end

function onLevelUp(actor, level)
    local record = getRecord(actor)
    record[taskcommon.taskType.emActorLevel] = level
    updateTask(actor, taskcommon.taskType.emActorLevel, 0, level)
end

function onFightPower(actor, fightPower)
    local ins = instancesystem.getActorIns(actor)
    if not ins then return end
    if FubenGroupAlias[FubenConfig[ins.id].group] and FubenGroupAlias[FubenConfig[ins.id].group].isCalcPower == 0 then
        return
    end
    
    local record = getRecord(actor)
    local recordPower = record[taskcommon.taskType.emFightPower] or 0
    if fightPower > recordPower then
        record[taskcommon.taskType.emFightPower] = fightPower
    end
    updateTask(actor, taskcommon.taskType.emFightPower, 0, fightPower)
end

function onOpenRole(actor, roleId)
    local record = getRecord(actor)
    record[taskcommon.taskType.emRoleCount] = roleId + 1
    updateTask(actor, taskcommon.taskType.emRoleCount, 0, roleId + 1)
end

function onZhuansheng(actor, zhuanshengLevel)
    local record = getRecord(actor)
    local config = ZhuanShengLevelConfig[zhuanshengLevel]
    record[taskcommon.taskType.emZhuanshengLevel] = zhuanshengLevel
    updateTask(actor, taskcommon.taskType.emZhuanshengLevel, 0, zhuanshengLevel)
end

function onWingTrainCount(actor, count)
    --local record = getRecord(actor)
    --record[taskcommon.taskType.emWingTrainCount] = (record[taskcommon.taskType.emWingTrainCount] or 0) + count
    updateTask(actor, taskcommon.taskType.emWingTrainCount, 0, count)
end

function onWingStarUp(actor, roleId, starUpCount, star)
    --local record = getRecord(actor)
    --record[taskcommon.taskType.emWingStarUpCount] = (record[taskcommon.taskType.emWingStarUpCount] or 0) + starUpCount
    updateTask(actor, taskcommon.taskType.emWingStarUpCount, 0, starUpCount)
    
    local record = getRecord(actor)
    local recordStar = record[taskcommon.taskType.emWingStarUp] or 0
    if recordStar < star then
        record[taskcommon.taskType.emWingStarUp] = star
        updateTask(actor, taskcommon.taskType.emWingStarUp, 0, star)
    end
end

function onWingLevelUp(actor, level)
    local record = getRecord(actor)
    local recordLevel = record[taskcommon.taskType.emWingLevel] or 0
    if level > recordLevel then
        record[taskcommon.taskType.emWingLevel] = level
        updateTask(actor, taskcommon.taskType.emWingLevel, 0, level)
    end
end

--强化
function onEquipEnhanceUpLevel(actor, slot, level)
    local record = getRecord(actor)
    record[taskcommon.taskType.emEquipEnhanceAll] = (record[taskcommon.taskType.emEquipEnhanceAll] or 0) + 1
    updateTask(actor, taskcommon.taskType.emEquipEnhanceAll, 0, record[taskcommon.taskType.emEquipEnhanceAll])
    local recordLevel = record[taskcommon.taskType.emEnhanceXLevel] or 0
    local minlevel = enhancesystem.getMinLevel(actor, 8)
    if minlevel > recordLevel then
        record[taskcommon.taskType.emEnhanceXLevel] = minlevel
        updateTask(actor, taskcommon.taskType.emEnhanceXLevel, 0, minlevel)
    end
    
    updateTask(actor, taskcommon.taskType.emEnhanceCount, 0, 1)
end

function onEquipAppendUpLevel(actor, slot, level)
    local record = getRecord(actor)
    
    local recordSum = record[taskcommon.taskType.emEquipAppendAll] or 0
    record[taskcommon.taskType.emEquipAppendAll] = recordSum + 1
    updateTask(actor, taskcommon.taskType.emEquipAppendAll, 0, recordSum + 1)
end

function onEquipCulture(actor, slot, times)
    local record = getRecord(actor)
    record[taskcommon.taskType.emEquipCulture] = (record[taskcommon.taskType.emEquipCulture] or 0) + times
    updateTask(actor, taskcommon.taskType.emEquipCulture, 0, record[taskcommon.taskType.emEquipCulture])
    
    updateTask(actor, taskcommon.taskType.emEquipCultureAdd, 0, times)
end

function onEquip(actor, beforeid, newid)
    local beforeconf = ItemConfig[beforeid]
    local newconf = ItemConfig[newid]
    local record = getRecord(actor)
    
    --穿戴X件Y品质以上装备（0为任意品质）
    if not record[taskcommon.taskType.emEquipQuality] then
        record[taskcommon.taskType.emEquipQuality] = {}
    end
    for quality = (beforeconf and beforeconf.quality or 0), newconf.quality do --品质有6个
        local recordQua = record[taskcommon.taskType.emEquipQuality][quality] or 0
        local count = equipsystem.getEquipCountQuality(actor, quality)
        if recordQua < count then
            record[taskcommon.taskType.emEquipQuality][quality] = count
            updateTask(actor, taskcommon.taskType.emEquipQuality, quality, count)
        end
    end
    
    --穿戴X件Y星以上装备
    if not record[taskcommon.taskType.emEquipStarCount] then
        record[taskcommon.taskType.emEquipStarCount] = {}
    end
    for star = (beforeconf and beforeconf.star or 1), newconf.star do --星级有4个
        local recordQua = record[taskcommon.taskType.emEquipStarCount][star] or 0
        local count = equipsystem.getEquipCountStar(actor, star)
        if recordQua < count then
            record[taskcommon.taskType.emEquipStarCount][star] = count
            updateTask(actor, taskcommon.taskType.emEquipStarCount, star, count)
        end
    end
    
    --穿戴X件Y阶以上装备
    if not record[taskcommon.taskType.emEquipRank] then
        record[taskcommon.taskType.emEquipRank] = {}
    end
    for rank = (beforeconf and beforeconf.rank or 1), newconf.rank do --品阶有13个
        local recordCount = record[taskcommon.taskType.emEquipRank][rank] or 0
        local count = equipsystem.getEquipCountRank(actor, rank)
        if recordCount < count then
            record[taskcommon.taskType.emEquipRank][rank] = count
            updateTask(actor, taskcommon.taskType.emEquipRank, rank, count)
        end
    end
    
    --穿戴x件Y阶或以上的紫色装备
    if not record[taskcommon.taskType.emEquipGoodNum] then
        record[taskcommon.taskType.emEquipGoodNum] = {}
    end
    for rank = (beforeconf and beforeconf.rank or 1), newconf.rank do --品阶有13个
        local recordRank = record[taskcommon.taskType.emEquipGoodNum][rank] or 0
        local count = equipsystem.getGoodEquipCount(actor, rank)
        if recordRank < count then
            record[taskcommon.taskType.emEquipGoodNum][rank] = count
            updateTask(actor, taskcommon.taskType.emEquipGoodNum, rank, count)
        end
    end
end

function onDamonFight(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emDamonFight] = 1
    updateTask(actor, taskcommon.taskType.emDamonFight, 0, 1)
end

function onSkillUp(actor, index, level)
    local record = getRecord(actor)
    local new = LActor.getTotalSkillLv(actor)
    if new > (record[taskcommon.taskType.emSkillLevelTotal] or 1) then
        record[taskcommon.taskType.emSkillLevelTotal] = new
        updateTask(actor, taskcommon.taskType.emSkillLevelTotal, 0, new)
    end
    
    updateTask(actor, taskcommon.taskType.emSkillLearn, 0, 1)
end

function onMonsterDie(actor, monsterId, count)
    -- local record = getRecord(actor)
    -- if not record[taskcommon.taskType.emMonsterCount] then
    -- record[taskcommon.taskType.emMonsterCount] = {}
    -- end
    -- record[taskcommon.taskType.emMonsterCount][monsterId] = (record[taskcommon.taskType.emMonsterCount][monsterId] or 0) + count
    --updateTask(actor, taskcommon.taskType.emKillMonster, 0, count)
    
    updateTask(actor, taskcommon.taskType.emMonsterCount, monsterId, count)
end

function onEnterFuben(actor, fubenId, isLogin, iscw)
    if not iscw and isLogin then return end --只有在普通服登录才不计算
    local config = fuben_cfg[fubenId]
    local record = getRecord(actor)
    local count = neigua.getNeiguaFightCount(actor, config.group)
    
    if FubenGroupAlias[config.group] and FubenGroupAlias[config.group].taskid ~= 0 then
        if record[FubenGroupAlias[config.group].taskid] == nil then
            record[FubenGroupAlias[config.group].taskid] = {}
        end
        record[FubenGroupAlias[config.group].taskid][fubenId] = (record[FubenGroupAlias[config.group].taskid][fubenId] or 0) + count
        updateTask(actor, FubenGroupAlias[config.group].taskid, fubenId, record[FubenGroupAlias[config.group].taskid][fubenId])
    end
    
    updateTask(actor, taskcommon.taskType.emPassDup, fubenId, count)
    
    if record[taskcommon.taskType.emPassTypeDup] == nil then
        record[taskcommon.taskType.emPassTypeDup] = {}
    end
    record[taskcommon.taskType.emPassTypeDup][config.group] = (record[taskcommon.taskType.emPassTypeDup][config.group] or 0) + count
    updateTask(actor, taskcommon.taskType.emPassTypeDup, config.group, record[taskcommon.taskType.emPassTypeDup][config.group])
    
    updateTask(actor, taskcommon.taskType.emEnterFubenTpAdd, config.group, count)
end

function onFinishFuben(actor, fubenId, fbTp)
    local config = fuben_cfg[fubenId]
    if config == nil then return end
    local count = neigua.getNeiguaFightCount(actor, config.group)
    
    updateTask(actor, taskcommon.taskType.emFinishDup, fubenId, count)
    
    local record = getRecord(actor)
    if record[taskcommon.taskType.emFinishTypeDup] == nil then
        record[taskcommon.taskType.emFinishTypeDup] = {}
    end
    record[taskcommon.taskType.emFinishTypeDup][config.group] = (record[taskcommon.taskType.emFinishTypeDup][config.group] or 0) + count
    updateTask(actor, taskcommon.taskType.emFinishTypeDup, config.group, record[taskcommon.taskType.emFinishTypeDup][config.group])
    
    updateTask(actor, taskcommon.taskType.emFinishFubenTpAdd, config.group, count)
end

function onActiveFuben(actor, fubenId, isInActivity)--用来区分赤色堡垒的竞技模式
    local config = fuben_cfg[fubenId]
    if config == nil then return end
    updateTask(actor, taskcommon.taskType.emActiveFubenAdd, config.group, 1)
    if isInActivity then
        updateTask(actor, taskcommon.taskType.emFortFight, 0, 1)
    end
end

function onWanmoFuben(actor, idx)
    local record = getRecord(actor)
    local recordIdx = record[taskcommon.taskType.emWanmoFuben] or 0
    if recordIdx < idx then
        record[taskcommon.taskType.emWanmoFuben] = idx
    end
    updateTask(actor, taskcommon.taskType.emWanmoFuben, 0, idx)
end

function onHeianFuben(actor, idx)
    local record = getRecord(actor)
    local recordIdx = record[taskcommon.taskType.emHeianFuben] or 0
    if recordIdx < idx then
        record[taskcommon.taskType.emHeianFuben] = idx
    end
    updateTask(actor, taskcommon.taskType.emHeianFuben, 0, idx)
end

function onDespairBoss(actor, bossId, count)
    updateTask(actor, taskcommon.taskType.emDespairBoss, bossId, count)
end

function onShopConsume(actor)
    -- local record = getRecord(actor)
    -- record[taskcommon.taskType.emShopConsume] = (record[taskcommon.taskType.emShopConsume] or 0) + 1
    -- updateTask(actor, taskcommon.taskType.emShopConsume, 0, record[taskcommon.taskType.emShopConsume])
end

function onStarsoulUpStage(actor, stage)
    local record = getRecord(actor)
    local recordStage = record[taskcommon.taskType.emStarsoulLevel] or 0
    if recordStage < stage then
        record[taskcommon.taskType.emStarsoulLevel] = stage
        updateTask(actor, taskcommon.taskType.emStarsoulLevel, 0, stage)
    end
    updateTask(actor, taskcommon.taskType.emStarsoul, 0, 1)
end

function onTalismanUpLevel(actor, level)
    local record = getRecord(actor)
    local recordLevel = record[taskcommon.taskType.emHuFuLevel] or 0
    if recordLevel < level then
        record[taskcommon.taskType.emHuFuLevel] = level
        updateTask(actor, taskcommon.taskType.emHuFuLevel, 0, level)
    end
    updateTask(actor, taskcommon.taskType.emHuFuLevelAdd, 0, 1)
end

--精灵培养
function onDamonLevel(actor, level, count)
    local record = getRecord(actor)
    local old = record[taskcommon.taskType.emDamonLevel] or 0
    if old < level then
        record[taskcommon.taskType.emDamonLevel] = level
        updateTask(actor, taskcommon.taskType.emDamonLevel, 0, level)
    end
    if not record[taskcommon.taskType.emDamonTrainTotal] then
        record[taskcommon.taskType.emDamonTrainTotal] = 0
    end
    record[taskcommon.taskType.emDamonTrainTotal] = record[taskcommon.taskType.emDamonTrainTotal] + count
    updateTask(actor, taskcommon.taskType.emDamonTrainTotal, 0, record[taskcommon.taskType.emDamonTrainTotal])
    updateTask(actor, taskcommon.taskType.emDamonTrain, 0, count)
end

--精灵进阶
function onDamonStage(actor, stage, count)
    local record = getRecord(actor)
    local old = record[taskcommon.taskType.emDamonStage] or 0
    if old < stage then
        record[taskcommon.taskType.emDamonStage] = stage
        updateTask(actor, taskcommon.taskType.emDamonStage, 0, stage)
    end
    if not record[taskcommon.taskType.emDamonJinjieTotal] then
        record[taskcommon.taskType.emDamonJinjieTotal] = 0
    end
    record[taskcommon.taskType.emDamonJinjieTotal] = record[taskcommon.taskType.emDamonJinjieTotal] + count
    updateTask(actor, taskcommon.taskType.emDamonJinjieTotal, 0, record[taskcommon.taskType.emDamonJinjieTotal])
end

--佣兵培养
function onYongbingLevel(actor, level, count)
    local record = getRecord(actor)
    local old = record[taskcommon.taskType.emYongbingLevel] or 0
    if old < level then
        record[taskcommon.taskType.emYongbingLevel] = level
        updateTask(actor, taskcommon.taskType.emYongbingLevel, 0, level)
    end
    if not record[taskcommon.taskType.emYongbingTrainTotal] then
        record[taskcommon.taskType.emYongbingTrainTotal] = 0
    end
    record[taskcommon.taskType.emYongbingTrainTotal] = record[taskcommon.taskType.emYongbingTrainTotal] + count
    updateTask(actor, taskcommon.taskType.emYongbingTrainTotal, 0, record[taskcommon.taskType.emYongbingTrainTotal])
    updateTask(actor, taskcommon.taskType.emYongbingTrain, 0, count)
end

--佣兵进阶
function onYongbingStage(actor, stage, count)
    local record = getRecord(actor)
    local old = record[taskcommon.taskType.emYongbingStage] or 0
    if old < stage then
        record[taskcommon.taskType.emYongbingStage] = stage
        updateTask(actor, taskcommon.taskType.emYongbingStage, 0, stage)
    end
    if not record[taskcommon.taskType.emYongbingJinjieTotal] then
        record[taskcommon.taskType.emYongbingJinjieTotal] = 0
    end
    record[taskcommon.taskType.emYongbingJinjieTotal] = record[taskcommon.taskType.emYongbingJinjieTotal] + count
    updateTask(actor, taskcommon.taskType.emYongbingJinjieTotal, 0, record[taskcommon.taskType.emYongbingJinjieTotal])
end

--神魔升级
function onShenmoLevel(actor, level, count)
    local record = getRecord(actor)
    local old = record[taskcommon.taskType.emShenmoTrainLv] or 0
    if old < level then
        record[taskcommon.taskType.emShenmoTrainLv] = level
        updateTask(actor, taskcommon.taskType.emShenmoTrainLv, 0, level)
    end
    record[taskcommon.taskType.emShenmoTrainHistory] = (record[taskcommon.taskType.emShenmoTrainHistory] or 0) + count
    updateTask(actor, taskcommon.taskType.emShenmoTrainHistory, 0, record[taskcommon.taskType.emShenmoTrainHistory])
    updateTask(actor, taskcommon.taskType.emShenmoTrain, 0, count)
end

--神魔升阶
function onShenmoStage(actor, stage, count)
    local record = getRecord(actor)
    local old = record[taskcommon.taskType.emShenmoStageLv] or 0
    if old < stage then
        record[taskcommon.taskType.emShenmoStageLv] = stage
        updateTask(actor, taskcommon.taskType.emShenmoStageLv, 0, stage)
    end
    
    local old = record[taskcommon.taskType.emShenmoJinjieTotal] or 0
    record[taskcommon.taskType.emShenmoJinjieTotal] = (record[taskcommon.taskType.emShenmoJinjieTotal] or 0) + count
    updateTask(actor, taskcommon.taskType.emShenmoJinjieTotal, 0, record[taskcommon.taskType.emShenmoJinjieTotal])
end

--魂器升级
function onHunqiLevel(actor, level, quality, awakelevel)
    local record = getRecord(actor)
    if level == 1 then
        record[taskcommon.taskType.emHunqiCount] = (record[taskcommon.taskType.emHunqiCount] or 0) + 1
        updateTask(actor, taskcommon.taskType.emHunqiCount, 0, record[taskcommon.taskType.emHunqiCount])
        if quality == 4 then
            record[taskcommon.taskType.emSSHunqiCount] = (record[taskcommon.taskType.emSSHunqiCount] or 0) + 1
            updateTask(actor, taskcommon.taskType.emSSHunqiCount, 0, record[taskcommon.taskType.emSSHunqiCount])
        end
    end
    record[taskcommon.taskType.emHunqiLevelCount] = (record[taskcommon.taskType.emHunqiLevelCount] or 0) + 1
    updateTask(actor, taskcommon.taskType.emHunqiLevelCount, 0, record[taskcommon.taskType.emHunqiLevelCount])
    
    local record = getRecord(actor)
    local old = record[taskcommon.taskType.emHunqiAwake] or 0
    if old < awakelevel then
        record[taskcommon.taskType.emHunqiAwake] = awakelevel
        updateTask(actor, taskcommon.taskType.emHunqiAwake, 0, awakelevel)
    end
end

function onElementLevel(actor, level)
    local record = getRecord(actor)
    local old = record[taskcommon.taskType.emElementLevel] or 0
    if old < level then
        record[taskcommon.taskType.emElementLevel] = level
        updateTask(actor, taskcommon.taskType.emElementLevel, 0, level)
    end
    
    local old = record[taskcommon.taskType.emElementOrangeCount] or 0
    local current = elementsystem.getElementLevelCount(actor)
    if current > old then
        record[taskcommon.taskType.emElementOrangeCount] = current
        updateTask(actor, taskcommon.taskType.emElementOrangeCount, 0, current)
    end
end

function onElementEquip(actor, quality, type)
    local record = getRecord(actor)
    local old = record[taskcommon.taskType.emElementEquip] or 0
    local count = elementsystem.getElementCount(actor)
    if old < count then
        record[taskcommon.taskType.emElementEquip] = count
        updateTask(actor, taskcommon.taskType.emElementEquip, 0, count)
    end
    
    local tlv = elementsystem.getElementTotalLevel(actor)
    local old = record[taskcommon.taskType.emElementTotal] or 0
    if old < tlv then
        record[taskcommon.taskType.emElementTotal] = tlv
        updateTask(actor, taskcommon.taskType.emElementTotal, 0, tlv)
    end
    
    if not record[taskcommon.taskType.emElementQuality] then
        record[taskcommon.taskType.emElementQuality] = {}
    end
    for i = 0, 4 do
        if i <= quality then
            record[taskcommon.taskType.emElementQuality][i] = (record[taskcommon.taskType.emElementQuality][i] or 0) + type
            updateTask(actor, taskcommon.taskType.emElementQuality, i, record[taskcommon.taskType.emElementQuality][i])
        end
    end
    
    local old = record[taskcommon.taskType.emElementOrangeCount] or 0
    local current = elementsystem.getElementLevelCount(actor)
    if current > old then
        record[taskcommon.taskType.emElementOrangeCount] = current
        updateTask(actor, taskcommon.taskType.emElementOrangeCount, 0, current)
    end
end

function onPassGuajifu(actor, fubenId)
    local record = getRecord(actor)
    if record[taskcommon.taskType.emInterGuajifu] == nil then
        record[taskcommon.taskType.emInterGuajifu] = {}
    end
    record[taskcommon.taskType.emInterGuajifu][fubenId] = 1
    updateTask(actor, taskcommon.taskType.emInterGuajifu, fubenId, 1)
end

function onBeatCustom(actor, id)
    local record = getRecord(actor)
    updateTask(actor, taskcommon.taskType.emBeatCustomCount, 0, 1)
    
    if not record[taskcommon.taskType.emBeatCustom] then
        record[taskcommon.taskType.emBeatCustom] = {}
    end
    record[taskcommon.taskType.emBeatCustom][id] = (record[taskcommon.taskType.emBeatCustom][id] or 0) + 1
    updateTask(actor, taskcommon.taskType.emBeatCustom, id, record[taskcommon.taskType.emBeatCustom][id])
end

function onBeatRelic(actor, idx)
    local record = getRecord(actor)
    record[taskcommon.taskType.emBeatRelicCount] = (record[taskcommon.taskType.emBeatRelicCount] or 0) + 1
    updateTask(actor, taskcommon.taskType.emBeatRelicCount, 0, record[taskcommon.taskType.emBeatRelicCount])
end

function onSaoDang(actor, fubenId, count)
    if count < 0 then return end
    local config = fuben_cfg[fubenId]
    local record = getRecord(actor)
    
    if record[taskcommon.taskType.emSaoDangDup] == nil then
        record[taskcommon.taskType.emSaoDangDup] = {}
    end
    record[taskcommon.taskType.emSaoDangDup][fubenId] = (record[taskcommon.taskType.emSaoDangDup][fubenId] or 0) + count
    updateTask(actor, taskcommon.taskType.emSaoDangDup, fubenId, record[taskcommon.taskType.emSaoDangDup][fubenId])
    
    if record[taskcommon.taskType.emSaoDangTypeDup] == nil then
        record[taskcommon.taskType.emSaoDangTypeDup] = {}
    end
    record[taskcommon.taskType.emSaoDangTypeDup][config.group] = (record[taskcommon.taskType.emSaoDangTypeDup][config.group] or 0) + count
    updateTask(actor, taskcommon.taskType.emSaoDangTypeDup, config.group, record[taskcommon.taskType.emSaoDangTypeDup][config.group])
    
    if DailyFubenConfig[config.group] then
        record[taskcommon.taskType.emSaoDangDaily] = (record[taskcommon.taskType.emSaoDangDaily] or 0) + count
        updateTask(actor, taskcommon.taskType.emSaoDangDaily, 0, record[taskcommon.taskType.emSaoDangDaily])
    end
    
    --扫荡计入副本挑战与通关的次数
    updateTask(actor, taskcommon.taskType.emPassDup, fubenId, count)
    updateTask(actor, taskcommon.taskType.emEnterFubenTpAdd, config.group, count)
    updateTask(actor, taskcommon.taskType.emFinishDup, fubenId, count)
    updateTask(actor, taskcommon.taskType.emFinishFubenTpAdd, config.group, count)
    
    if record[taskcommon.taskType.emPassTypeDup] == nil then record[taskcommon.taskType.emPassTypeDup] = {} end
    record[taskcommon.taskType.emPassTypeDup][config.group] = (record[taskcommon.taskType.emPassTypeDup][config.group] or 0) + count
    updateTask(actor, taskcommon.taskType.emPassTypeDup, config.group, record[taskcommon.taskType.emPassTypeDup][config.group])
    if record[taskcommon.taskType.emFinishTypeDup] == nil then record[taskcommon.taskType.emFinishTypeDup] = {} end
    record[taskcommon.taskType.emFinishTypeDup][config.group] = (record[taskcommon.taskType.emFinishTypeDup][config.group] or 0) + count
    updateTask(actor, taskcommon.taskType.emFinishTypeDup, config.group, record[taskcommon.taskType.emFinishTypeDup][config.group])
end

function onComposeItem(actor, itemId)
    local record = getRecord(actor)
    if record[taskcommon.taskType.emComposeItem] == nil then
        record[taskcommon.taskType.emComposeItem] = {}
    end
    record[taskcommon.taskType.emComposeItem][itemId] = (record[taskcommon.taskType.emComposeItem][itemId] or 0) + 1
    updateTask(actor, taskcommon.taskType.emComposeItem, itemId, record[taskcommon.taskType.emComposeItem][itemId])
end

function onEleMentDraw(actor)
    updateTask(actor, taskcommon.taskType.emElemenDraw, 0, 1)
end

function onFastFight(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emFastFightHistory] = (record[taskcommon.taskType.emFastFightHistory] or 0) + 1
    updateTask(actor, taskcommon.taskType.emFastFightHistory, 0, record[taskcommon.taskType.emFastFightHistory])
    updateTask(actor, taskcommon.taskType.emFastFight, 0, 1)
end

function onAllotPoint(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emAllotPoint] = (record[taskcommon.taskType.emAllotPoint] or 0) + 1
    updateTask(actor, taskcommon.taskType.emAllotPoint, 0, record[taskcommon.taskType.emAllotPoint])
    
    updateTask(actor, taskcommon.taskType.emAllotPointCount, 0, 1)
end

function onCostItem(actor, itemid, itemcount)
    updateTask(actor, taskcommon.taskType.emCostItem, itemid, itemcount)
end

function onFruitEat(actor, fruitId, count)
    local record = getRecord(actor)
    if record[taskcommon.taskType.emFruitEat] == nil then
        record[taskcommon.taskType.emFruitEat] = {}
    end
    record[taskcommon.taskType.emFruitEat][fruitId] = (record[taskcommon.taskType.emFruitEat][fruitId] or 0) + count
    updateTask(actor, taskcommon.taskType.emFruitEat, fruitId, record[taskcommon.taskType.emFruitEat][fruitId])
    
    record[taskcommon.taskType.emFruitEat][0] = (record[taskcommon.taskType.emFruitEat][0] or 0) + count --记录吃过的果实总数
    updateTask(actor, taskcommon.taskType.emFruitEat, 0, record[taskcommon.taskType.emFruitEat][0])
end

function onTalentUp(actor, talentId, level)
    local record = getRecord(actor)
    if record[taskcommon.taskType.emTalentUp] == nil then
        record[taskcommon.taskType.emTalentUp] = {}
    end
    if level > (record[taskcommon.taskType.emTalentUp][talentId] or 0) then --不同角色的天赋等级不一样
        record[taskcommon.taskType.emTalentUp][talentId] = level
        updateTask(actor, taskcommon.taskType.emTalentUp, talentId, level)
        
        local lv = talentsystem.getMaxTalentLevel(actor)
        record[taskcommon.taskType.emTalentUp][0] = lv
        updateTask(actor, taskcommon.taskType.emTalentUp, 0, lv)
    end
end

function onBeatShilian(actor, id)
    local record = getRecord(actor)
    if record[taskcommon.taskType.emBeatShilian] == nil then
        record[taskcommon.taskType.emBeatShilian] = {}
    end
    record[taskcommon.taskType.emBeatShilian][id] = (record[taskcommon.taskType.emBeatShilian][id] or 0) + 1
    updateTask(actor, taskcommon.taskType.emBeatShilian, id, record[taskcommon.taskType.emBeatShilian][id])
end

function onWorship(actor, index)
    updateTask(actor, taskcommon.taskType.emWorship, 0, 1)
    
    local record = getRecord(actor)
    record[taskcommon.taskType.emWorshipCover] = (record[taskcommon.taskType.emWorshipCover] or 0) + 1
    updateTask(actor, taskcommon.taskType.emWorshipCover, 0, record[taskcommon.taskType.emWorshipCover])
end

function onRecharge(actor, count, itemid)
    local record = getRecord(actor)
    local recordCount = record[taskcommon.taskType.emRecharge] or 0
    local data = LActor.getActorData(actor)
    if data.recharge > recordCount then
        record[taskcommon.taskType.emRecharge] = data.recharge
        updateTask(actor, taskcommon.taskType.emRecharge, 0, record[taskcommon.taskType.emRecharge])
    end
    local record = getRecord(actor)
    
    if not record[taskcommon.taskType.emFirstRecharge] then
        record[taskcommon.taskType.emFirstRecharge] = 1
        updateTask(actor, taskcommon.taskType.emFirstRecharge, 0, record[taskcommon.taskType.emFirstRecharge])
    end
    
    if itemid == MonthCardConfig.money and not record[taskcommon.taskType.emBuyMonthCard] then --买月卡
        record[taskcommon.taskType.emBuyMonthCard] = 1
        updateTask(actor, taskcommon.taskType.emBuyMonthCard, 0, 1)
    end
    
    updateTask(actor, taskcommon.taskType.emRechargeAdd, 0, count)
    updateTask(actor, taskcommon.taskType.emChongzhiCnt, 0, 1)
    local rmb = rechargesystem.getRmbByPf(actor, itemid)
    updateTask(actor, taskcommon.taskType.emChongzhiRMB, 0, rmb)
end

function onMonthCard(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emMonthcard] = 1
    updateTask(actor, taskcommon.taskType.emMonthcard, 0, record[taskcommon.taskType.emMonthcard])
end

function onFinishLoop(actor, cnt)
    local record = getRecord(actor)
    record[taskcommon.taskType.emLoopFinish] = (record[taskcommon.taskType.emLoopFinish] or 0) + cnt
    updateTask(actor, taskcommon.taskType.emLoopFinish, 0, record[taskcommon.taskType.emLoopFinish])
    updateTask(actor, taskcommon.taskType.emLoopFinishAdd, 0, cnt)
end

--领取首冲奖励
function onFirstChargetReward(actor)
    local record = getRecord(actor)
    local recordCount = record[taskcommon.taskType.emFirstReward] or 0
    record[taskcommon.taskType.emFirstReward] = 1
    updateTask(actor, taskcommon.taskType.emFirstReward, 1, 1)
end

--登录
function onLogin(actor)
    updateTask(actor, taskcommon.taskType.emTodayLogin, 0, 1)--今日登陆次数+1
end

--新的一天
function onNewDay(actor, login)
    local record = getRecord(actor)
    local recordCount = record[taskcommon.taskType.emLoginDay] or 0
    record[taskcommon.taskType.emLoginDay] = recordCount + 1
    updateTask(actor, taskcommon.taskType.emLoginDay, 0, record[taskcommon.taskType.emLoginDay])
    updateTask(actor, taskcommon.taskType.emLoginDayAdd, 0, 1)
end

--创建新角色
function onCreateRole(actor)
    local count = 1
    local record = getRecord(actor)
    record[taskcommon.taskType.emOpenRoleCnt] = count
    updateTask(actor, taskcommon.taskType.emOpenRoleCnt, 0, count)
end

--初始化人物
function onInit(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emOpenRoleCnt] = 1
end

--SVip等级变更
function onVipLevel(actor, level)
    local record = getRecord(actor)
    local recordCount = record[taskcommon.taskType.emSVipLv] or 0
    record[taskcommon.taskType.emSVipLv] = level
    updateTask(actor, taskcommon.taskType.emSVipLv, 0, level)
end

--圣灵等级变更
function onGhostLv(actor, level)
    local record = getRecord(actor)
    local recordCount = record[taskcommon.taskType.emGhostLv] or 0
    record[taskcommon.taskType.emGhostLv] = level
    updateTask(actor, taskcommon.taskType.emGhostLv, 0, level)
end

--头衔提升至xx
function onTouxianLv(actor, type)
    local record = getRecord(actor)
    local recordCount = record[taskcommon.taskType.emTouxianLv] or 0
    record[taskcommon.taskType.emTouxianLv] = type
    updateTask(actor, taskcommon.taskType.emTouxianLv, 0, type)
end

--元素喜+1
function onElementCreate(actor, quality)
    local record = getRecord(actor)
    for i = 1, 5 do
        if quality >= i then
            if record[taskcommon.taskType.emElementCnt] == nil then
                record[taskcommon.taskType.emElementCnt] = {}
            end
            local recordCount = record[taskcommon.taskType.emElementCnt][quality] or 0
            record[taskcommon.taskType.emElementCnt][quality] = recordCount + 1
            updateTask(actor, taskcommon.taskType.emDamonQemElementCntuality, quality, record[taskcommon.taskType.emElementCnt][quality])
        end
    end
end

--神装激活数+1
function onGodEquipCnt(actor)
    local record = getRecord(actor)
    local recordCount = record[taskcommon.taskType.emGodEquipCnt] or 0
    record[taskcommon.taskType.emGodEquipCnt] = recordCount + 1
    updateTask(actor, taskcommon.taskType.emGodEquipCnt, 0, record[taskcommon.taskType.emGodEquipCnt])
end

--精炼装备
function onPurifyEquip(actor)
    local record = getRecord(actor)
    local recordCount = record[taskcommon.taskType.emPurifyCnt] or 0
    record[taskcommon.taskType.emPurifyCnt] = recordCount + 1
    updateTask(actor, taskcommon.taskType.emPurifyCnt, 0, record[taskcommon.taskType.emPurifyCnt])
    
    local recordlv = record[taskcommon.taskType.emPurifyTotalLv] or 0
    local curlv = purifysystem.getPurifyTotalLv(actor)
    if curlv > recordlv then
        record[taskcommon.taskType.emPurifyTotalLv] = curlv
        updateTask(actor, taskcommon.taskType.emPurifyTotalLv, 0, curlv)
    end
end

--神魔激活
function onShenmoActive(actor, id)
    local record = getRecord(actor)
    local recordCount = record[taskcommon.taskType.emShenmoCnt] or 0
    record[taskcommon.taskType.emShenmoCnt] = recordCount + 1
    updateTask(actor, taskcommon.taskType.emShenmoCnt, 0, record[taskcommon.taskType.emShenmoCnt])
    if not record[taskcommon.taskType.emShenmoId] then
        record[taskcommon.taskType.emShenmoId] = {}
    end
    record[taskcommon.taskType.emShenmoId][id] = 1
    updateTask(actor, taskcommon.taskType.emShenmoId, id, 1)
end

--赤色要塞层数
function onFortFloor(actor, floor)
    local record = getRecord(actor)
    local recordFloor = record[taskcommon.taskType.emFortFloor] or 0
    if floor > recordFloor then
        record[taskcommon.taskType.emFortFloor] = floor
        updateTask(actor, taskcommon.taskType.emFortFloor, 0, floor)
    end
    updateTask(actor, taskcommon.taskType.emFortFloorAdd, 0, floor)
end

--水晶环境采集怪物
function onMineMonsterCnt(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emMineMonsterCnt] = (record[taskcommon.taskType.emMineMonsterCnt] or 0) + 1
    updateTask(actor, taskcommon.taskType.emMineMonsterCnt, 0, record[taskcommon.taskType.emMineMonsterCnt])
    updateTask(actor, taskcommon.taskType.emMineMonsterCntAdd, 0, 1)
end

--神魔升级次数
function onSMUpgradeCnt(actor, shenmoid)
    local record = getRecord(actor)
    if not record[taskcommon.taskType.emSMUpgradeCnt] then
        record[taskcommon.taskType.emSMUpgradeCnt] = {}
    end
    record[taskcommon.taskType.emSMUpgradeCnt][shenmoid] = (record[taskcommon.taskType.emSMUpgradeCnt][shenmoid] or 0) + 1
    record[taskcommon.taskType.emSMUpgradeCnt][0] = (record[taskcommon.taskType.emSMUpgradeCnt][0] or 0) + 1
    updateTask(actor, taskcommon.taskType.emSMUpgradeCnt, shenmoid, record[taskcommon.taskType.emSMUpgradeCnt][shenmoid])
    updateTask(actor, taskcommon.taskType.emSMUpgradeCnt, 0, record[taskcommon.taskType.emSMUpgradeCnt][0])
end

--套装升级
function onSuitLevelUp(actor, slot, nextLevel)
    local record = getRecord(actor)
    local recordLevel = record[taskcommon.taskType.emSuitLv] or 0
    if nextLevel > recordLevel then
        record[taskcommon.taskType.emSuitLv] = nextLevel
        updateTask(actor, taskcommon.taskType.emSuitLv, 0, nextLevel)
    end
end

--宝石升级
function onStoneInlay(actor)
    local record = getRecord(actor)
    local recordlv = record[taskcommon.taskType.emStoneTotalLv] or 0
    local curlv = stonesystem.getStoneTotalLv(actor)
    if curlv > recordlv then
        record[taskcommon.taskType.emStoneTotalLv] = curlv
        updateTask(actor, taskcommon.taskType.emStoneTotalLv, 0, curlv)
    end
end

--旗帜激活
function onBannerActive(actor)
    local record = getRecord(actor)
    local recordlv = record[taskcommon.taskType.emBannerTotalLv] or 0
    local curlv = bannersystem.getBannerTotalLv(actor)
    if curlv > recordlv then
        record[taskcommon.taskType.emBannerTotalLv] = curlv
        updateTask(actor, taskcommon.taskType.emBannerTotalLv, 0, curlv)
    end
end

--旗帜升星
function onBannerStarUp(actor)
    local record = getRecord(actor)
    local recordlv = record[taskcommon.taskType.emBannerTotalLv] or 0
    local curlv = bannersystem.getBannerTotalLv(actor)
    if curlv > recordlv then
        record[taskcommon.taskType.emBannerTotalLv] = curlv
        updateTask(actor, taskcommon.taskType.emBannerTotalLv, 0, curlv)
    end
end

--聚魂升级
function onJuSoulUp(actor)
    local record = getRecord(actor)
    local recordCount = record[taskcommon.taskType.emGatherCount] or 0
    local curCount = gathersystem.getGatherEffectCount(actor)
    if curCount > recordCount then
        record[taskcommon.taskType.emGatherCount] = curCount
        updateTask(actor, taskcommon.taskType.emGatherCount, 0, curCount)
    end
end

--完成契约任务
function onAgreementTask(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emAgreementTask] = (record[taskcommon.taskType.emAgreementTask] or 0) + 1
    updateTask(actor, taskcommon.taskType.emAgreementTask, 0, record[taskcommon.taskType.emAgreementTask])
end

--购买商店物品
function onBuyStoreItem(actor, itemid)
    local record = getRecord(actor)
    if not record[taskcommon.taskType.emBuyStoreItem] then
        record[taskcommon.taskType.emBuyStoreItem] = {}
    end
    record[taskcommon.taskType.emBuyStoreItem][itemid] = (record[taskcommon.taskType.emBuyStoreItem][itemid] or 0) + 1
    updateTask(actor, taskcommon.taskType.emBuyStoreItem, itemid, record[taskcommon.taskType.emBuyStoreItem][itemid])
end

--主线任务完成
function ehMainTaskFinish(actor, taskid)
    local record = getRecord(actor)
    record[taskcommon.taskType.emMaintask] = (record[taskcommon.taskType.emMaintask] or 0) + 1
    updateTask(actor, taskcommon.taskType.emMaintask, 0, record[taskcommon.taskType.emMaintask])
end

--竞技场达到X名
function onJjcRank(actor, rank)
    local record = getRecord(actor)
    if (record[taskcommon.taskType.emJJCRank] or #JjcRobotConfig) > rank then
        record[taskcommon.taskType.emJJCRank] = rank
        updateTask(actor, taskcommon.taskType.emJJCRank, 0, rank)
    end
end

--创建战盟
function onCreateGuild(actor)
    local record = getRecord(actor)
    if (record[taskcommon.taskType.emCreateGuild] or 0) > 0 then return end
    record[taskcommon.taskType.emCreateGuild] = 1
    updateTask(actor, taskcommon.taskType.emCreateGuild, 0, 1)
end

--加入战盟
function onJoinGuild(actor)
    local record = getRecord(actor)
    if (record[taskcommon.taskType.emJoinGuild] or 0) > 0 then return end
    record[taskcommon.taskType.emJoinGuild] = 1
    updateTask(actor, taskcommon.taskType.emJoinGuild, 0, 1)
end

function onEnterXuese(actor, cnt)--进入血色
    local record = getRecord(actor)
    record[taskcommon.taskType.emEnterXuese] = (record[taskcommon.taskType.emEnterXuese] or 0) + cnt
    updateTask(actor, taskcommon.taskType.emEnterXuese, 0, record[taskcommon.taskType.emEnterXuese])
    
    updateTask(actor, taskcommon.taskType.emEnterXuese1, 0, cnt)
end

function onEnterDevil(actor, cnt) --进入恶魔
    local record = getRecord(actor)
    record[taskcommon.taskType.emEnterDevil] = (record[taskcommon.taskType.emEnterDevil] or 0) + cnt
    updateTask(actor, taskcommon.taskType.emEnterDevil, 0, record[taskcommon.taskType.emEnterDevil])
    
    updateTask(actor, taskcommon.taskType.emEnterDevil1, 0, cnt)
end

function onEnterDespire(actor, cnt, bossId) --进入全民
    local record = getRecord(actor)
    record[taskcommon.taskType.emEnterDespire] = (record[taskcommon.taskType.emEnterDespire] or 0) + cnt
    updateTask(actor, taskcommon.taskType.emEnterDespire, 0, record[taskcommon.taskType.emEnterDespire])
    
    updateTask(actor, taskcommon.taskType.emEnterDespire1, 0, cnt)
    
    if not record[taskcommon.taskType.emEnterDespireBoss] then
        record[taskcommon.taskType.emEnterDespireBoss] = {}
    end
    record[taskcommon.taskType.emEnterDespireBoss][bossId] = (record[taskcommon.taskType.emEnterDespireBoss][bossId] or 0) + cnt
    updateTask(actor, taskcommon.taskType.emEnterDespireBoss, bossId, record[taskcommon.taskType.emEnterDespireBoss][bossId])
    
end

function onEnterJjc(actor, cnt) --进入竞技场
    local record = getRecord(actor)
    record[taskcommon.taskType.emEnterJjc] = (record[taskcommon.taskType.emEnterJjc] or 0) + cnt
    updateTask(actor, taskcommon.taskType.emEnterJjc, 0, record[taskcommon.taskType.emEnterJjc])
    
    updateTask(actor, taskcommon.taskType.emEnterJjc1, 0, cnt)
end

--消耗元宝
function onConsumeYuanbao(actor, count, log)
    if log == "diral draw" then return end
    local record = getRecord(actor)
    record[taskcommon.taskType.emYuanbaoCostHistory] = (record[taskcommon.taskType.emYuanbaoCostHistory] or 0) + count
    updateTask(actor, taskcommon.taskType.emYuanbaoCostHistory, 0, record[taskcommon.taskType.emYuanbaoCostHistory])
    
    updateTask(actor, taskcommon.taskType.emYuanbaoCost, 0, count)
end

--聊天
function onChat(actor, channel)
    updateTask(actor, taskcommon.taskType.emChat, 0, 1)
end

--军衔变更
function onJunxianLv(actor, level)
    local record = getRecord(actor)
    record[taskcommon.taskType.emJunxianLv] = level
    updateTask(actor, taskcommon.taskType.emJunxianLv, 0, record[taskcommon.taskType.emJunxianLv])
end

function onXunbao(actor, id, times)
    if id == 1 then
        updateTask(actor, taskcommon.taskType.emEquipXunbao, 0, times)
        local record = getRecord(actor)
        record[taskcommon.taskType.emEquipXunbaoHistory] = (record[taskcommon.taskType.emEquipXunbaoHistory] or 0) + times
        updateTask(actor, taskcommon.taskType.emEquipXunbaoHistory, 0, record[taskcommon.taskType.emEquipXunbaoHistory])
    elseif id == 2 then
        updateTask(actor, taskcommon.taskType.emHunqiXunbao, 0, times)
    elseif id == 3 then
        updateTask(actor, taskcommon.taskType.emElementXunbao, 0, times)
    elseif id == 4 then
        updateTask(actor, taskcommon.taskType.emDianfengXunbao, 0, times)
    elseif id == 5 then
        updateTask(actor, taskcommon.taskType.emZhizunXunbao, 0, times)
    end
    updateTask(actor, taskcommon.taskType.emXunbaoAdd, 0, times)
end

function onAoyiCount(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emAoyiCount] = (record[taskcommon.taskType.emAoyiCount] or 0) + 1
    updateTask(actor, taskcommon.taskType.emAoyiCount, 0, record[taskcommon.taskType.emAoyiCount])
end

function onShenzhuangLv(actor, level)
    local record = getRecord(actor)
    record[taskcommon.taskType.emShenzhuangLv] = level
    updateTask(actor, taskcommon.taskType.emShenzhuangLv, 0, record[taskcommon.taskType.emShenzhuangLv])
end

function onShenqiLv(actor, level)
    local record = getRecord(actor)
    record[taskcommon.taskType.emShenqiLv] = level
    updateTask(actor, taskcommon.taskType.emShenqiLv, 0, record[taskcommon.taskType.emShenqiLv])
end

function onMeilinLv(actor, level)
    local record = getRecord(actor)
    record[taskcommon.taskType.emMeilinLv] = level
    updateTask(actor, taskcommon.taskType.emMeilinLv, 0, record[taskcommon.taskType.emMeilinLv])
end

--击杀一波怪物
function onCumstomWave(actor)
    updateTask(actor, taskcommon.taskType.emCustomWave, 0, 1)
end

--通关第X关
function onCumstomChange(actor, custom, old)
    local record = getRecord(actor)
    record[taskcommon.taskType.emCustomChange] = custom
    updateTask(actor, taskcommon.taskType.emCustomChange, 0, custom)
end

function onShengwuActive(actor, id)
    local record = getRecord(actor)
    record[taskcommon.taskType.emShengwuCount] = (record[taskcommon.taskType.emShengwuCount] or 0) + 1
    updateTask(actor, taskcommon.taskType.emShengwuCount, 0, record[taskcommon.taskType.emShengwuCount])
end

--套装激活
function onSuitActive(actor, suitid)
    local record = getRecord(actor)
    if not record[taskcommon.taskType.emSuitId] then record[taskcommon.taskType.emSuitId] = {} end
    record[taskcommon.taskType.emSuitId][suitid] = 1
    updateTask(actor, taskcommon.taskType.emSuitId, suitid, 1)
end

--外观激活（1精灵，2佣兵，3神魔，4神器，5翅膀，6神装，7梅林）
function onFacadeActive(actor, type, quality)
    local record = getRecord(actor)
    local taskType = 0
    if type == 1 then
        --taskType = taskcommon.taskType.
    elseif type == 2 then
        --taskType = taskcommon.taskType.
    elseif type == 3 then
        --taskType = taskcommon.taskType.
    elseif type == 4 then
        taskType = taskcommon.taskType.emShenqiFacade
    elseif type == 5 then
        taskType = taskcommon.taskType.emWingFacade
    elseif type == 6 then
        taskType = taskcommon.taskType.emShenzhuangFacade
    elseif type == 7 then
        taskType = taskcommon.taskType.emMeilinFacade
    end
    if taskType ~= 0 then
        for i = 0, 5 do
            if quality >= i then
                if record[taskType] == nil then
                    record[taskType] = {}
                end
                local recordCount = record[taskType][i] or 0
                record[taskType][i] = recordCount + 1
                updateTask(actor, taskType, i, record[taskType][i])
            end
        end
    end
    for i = 0, 5 do
        if quality >= i then
            if record[taskcommon.taskType.emFacade] == nil then
                record[taskcommon.taskType.emFacade] = {}
            end
            local recordCount = record[taskcommon.taskType.emFacade][i] or 0
            record[taskcommon.taskType.emFacade][i] = recordCount + 1
            updateTask(actor, taskcommon.taskType.emFacade, i, record[taskcommon.taskType.emFacade][i])
        end
    end
end

function onPrivilegeBuy(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emPrivilegeBuy] = 1
    updateTask(actor, taskcommon.taskType.emPrivilegeBuy, 0, 1)
end

function onLilianTask(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emFinishLilianHistory] = (record[taskcommon.taskType.emFinishLilianHistory] or 0) + 1
    updateTask(actor, taskcommon.taskType.emFinishLilianHistory, 0, record[taskcommon.taskType.emFinishLilianHistory])
    updateTask(actor, taskcommon.taskType.emFinishLilian, 0, 1)
end

function onCustomFight(actor)
    updateTask(actor, taskcommon.taskType.emCustomFight, 0, 1)
end

function onCrossBossDie(actor)
    updateTask(actor, taskcommon.taskType.emCrossBossAdd, 0, 1)
end

function onShenmoBossDie(actor)
    updateTask(actor, taskcommon.taskType.emShenmoBossAdd, 0, 1)
end

function onAdventure(actor)
    updateTask(actor, taskcommon.taskType.emAdventureAdd, 0, 1)
end

function onCrossBossBelong(actor)
    --local record = getRecord(actor)
    --record[taskcommon.taskType.emCrossBossBelong] = (record[taskcommon.taskType.emCrossBossBelong] or 0) + 1
    updateTask(actor, taskcommon.taskType.emCrossBossBelong, 0, 1)
end

function onDropBox(actor)
    updateTask(actor, taskcommon.taskType.emDropBoxCountAdd, 0, 1)
end

function onMoLianRest(actor)
    updateTask(actor, taskcommon.taskType.emMoLianRestCountAdd, 0, 1)
end

function onYYMSBuy(actor)
    updateTask(actor, taskcommon.taskType.emYYMSBuyAdd, 0, 1)
end

function onZSMSBuy(actor)
    updateTask(actor, taskcommon.taskType.emZSMSBuyAdd, 0, 1)
end

function onSvipMSBuy(actor)
    updateTask(actor, taskcommon.taskType.emSvipMSBuyAdd, 0, 1)
end

function onAct35Draw(actor, count)
    updateTask(actor, taskcommon.taskType.emAct35DrawAdd, 0, count)
end

function onEnterMolong(actor, count)
    updateTask(actor, taskcommon.taskType.emEnterMolongAdd, 0, count)
end

function onSecretStarUp(actor, count)
    updateTask(actor, taskcommon.taskType.emSecretStarUpAdd, 0, count)
end

function onShenShouDraw(actor, count)
    updateTask(actor, taskcommon.taskType.emShenShouDrawAdd, 0, count)
end

function onShenyuLevel(actor, count)
    updateTask(actor, taskcommon.taskType.emShenyuLevelAdd, 0, count)
end

function onShenlingLevel(actor, count)
    updateTask(actor, taskcommon.taskType.emShenlingLevelAdd, 0, count)
end

function onShenyouLevel(actor, stage)
    local record = getRecord(actor)
    local recordLevel = record[taskcommon.taskType.emShenyouStage] or 0
    if recordLevel < stage then
        record[taskcommon.taskType.emShenyouStage] = stage
        updateTask(actor, taskcommon.taskType.emShenyouStage, 0, stage)
    end

    updateTask(actor, taskcommon.taskType.emShenyouLevelAdd, 0, 1)
end

function onDarkBossKill(actor, count)
    updateTask(actor, taskcommon.taskType.emDarkBossKillAdd, 0, count)
end

function onPurifyLevel(actor, count)
    updateTask(actor, taskcommon.taskType.emPurifyLevelAdd, 0, count)
end

function onZHBossSummon(actor, param, count)
    local record = getRecord(actor)
    local value = (record[taskcommon.taskType.emZHBossSummon] or 0) + count
    record[taskcommon.taskType.emZHBossSummon] = value
    
    zhenhongtask.updateTaskValue(actor, taskcommon.taskType.emZHBossSummon, 0, value)
    zhenhongtask.updateTaskValue(actor, taskcommon.taskType.emZHBossSummonAdd, 0, count)
end

function onZHBossKill(actor, param, count)
    local record = getRecord(actor)
    local value = (record[taskcommon.taskType.emZHBossKill] or 0) + count
    record[taskcommon.taskType.emZHBossKill] = value
    
    zhenhongtask.updateTaskValue(actor, taskcommon.taskType.emZHBossKill, 0, value)
    zhenhongtask.updateTaskValue(actor, taskcommon.taskType.emZHBossKillAdd, 0, count)
end

function onLHBelong(actor, count)
    local record = getRecord(actor)
    local value = (record[taskcommon.taskType.emLHBelong] or 0) + count
    record[taskcommon.taskType.emLHBelong] = value
    
    langhuntask.updateCJTaskValue(actor, taskcommon.taskType.emLHBelong, 0, value)
    langhuntask.updateDBTaskValue(actor, taskcommon.taskType.emLHBelongAdd, 0, count)
end

function onLHAddWolf(actor, count)
    local record = getRecord(actor)
    local value = (record[taskcommon.taskType.emLHAddWolf] or 0) + count
    record[taskcommon.taskType.emLHAddWolf] = value
    
    langhuntask.updateCJTaskValue(actor, taskcommon.taskType.emLHAddWolf, 0, value)
    langhuntask.updateDBTaskValue(actor, taskcommon.taskType.emLHAddWolfAdd, 0, count)
end

function onLHKillActor(actor, count)
    local record = getRecord(actor)
    local value = (record[taskcommon.taskType.emLHKillActor] or 0) + count
    record[taskcommon.taskType.emLHKillActor] = value
    
    langhuntask.updateCJTaskValue(actor, taskcommon.taskType.emLHKillActor, 0, value)
    langhuntask.updateDBTaskValue(actor, taskcommon.taskType.emLHKillActorAdd, 0, count)
end

function onLHKillMonster(actor, param, count)
    local record = getRecord(actor)
    local value = (record[taskcommon.taskType.emLHKillMonster] or 0) + count
    record[taskcommon.taskType.emLHKillMonster] = value
    
    langhuntask.updateCJTaskValue(actor, taskcommon.taskType.emLHKillMonster, 0, value)
    langhuntask.updateDBTaskValue(actor, taskcommon.taskType.emLHKillMonsterAdd, param, count)
end

function onLHExchange(actor, count)
    local record = getRecord(actor)
    local value = (record[taskcommon.taskType.emLHExchange] or 0) + count
    record[taskcommon.taskType.emLHExchange] = value
    
    langhuntask.updateCJTaskValue(actor, taskcommon.taskType.emLHExchange, 0, value)
    langhuntask.updateDBTaskValue(actor, taskcommon.taskType.emLHExchangeAdd, 0, count)
end

function onLHFirstBlood(actor, count)
    local record = getRecord(actor)
    local value = (record[taskcommon.taskType.emLHFirstBlood] or 0) + count
    record[taskcommon.taskType.emLHFirstBlood] = value
    
    langhuntask.updateCJTaskValue(actor, taskcommon.taskType.emLHFirstBlood, 0, value)
    --langhuntask.updateDBTaskValue(actor, taskcommon.taskType.emLHFirstBloodAdd, 0, count)
end

function onLHSerialKill(actor, count)
    local record = getRecord(actor)
    local value = (record[taskcommon.taskType.emLHSerialKill] or 0)
    if value < count then
        value = count
    end
    record[taskcommon.taskType.emLHSerialKill] = value
    
    langhuntask.updateCJTaskValue(actor, taskcommon.taskType.emLHSerialKill, 0, value)
    --langhuntask.updateDBTaskValue(actor, taskcommon.taskType.emLHSerialKillAdd, 0, count)
end

function onLHFirstRank(actor, param, count)
    local record = getRecord(actor)
    local value = (record[taskcommon.taskType.emLHFirstRank] or 0) + count
    record[taskcommon.taskType.emLHFirstRank] = value
    
    langhuntask.updateCJTaskValue(actor, taskcommon.taskType.emLHFirstRank, 0, value)
    --langhuntask.updateDBTaskValue(actor, taskcommon.taskType.emLHFirstRankAdd, 0, count)
end

function onConsumeDiamond(actor, count)
    updateTask(actor, taskcommon.taskType.emConsumeDiamondAdd, 0, count)
end

function onTujianActive(actor, count)
    updateTask(actor, taskcommon.taskType.emTujianActiveAdd, 0, count)
end

function onAngelshield(actor, stage)
    local record = getRecord(actor)
    local recordStage = record[taskcommon.taskType.emAngelshield] or 0
    if recordStage < stage then
        record[taskcommon.taskType.emAngelshield] = stage
        updateTask(actor, taskcommon.taskType.emAngelshield, 0, stage)
    end
    updateTask(actor, taskcommon.taskType.emAngelshieldAdd, 0, 1)
end

function onSMZLLevelUp(actor, stage)
    local record = getRecord(actor)
    local recordLevel = record[taskcommon.taskType.emSMZLLevel] or 0
    if recordLevel < stage then
        record[taskcommon.taskType.emSMZLLevel] = stage
        updateTask(actor, taskcommon.taskType.emSMZLLevel, 0, stage)
    end
    updateTask(actor, taskcommon.taskType.emSMZLLevelUpAdd, 0, 1)
end

function onYuanSuLevelUp(actor, id, count)
    updateTask(actor, taskcommon.taskType.emYuanSuLevelUpAdd, id, count)
end

function onZhenHongStageUp(actor, count)
    local record = getRecord(actor)
    local level = record[taskcommon.taskType.emZhenHongStage] or 0
    if not record[taskcommon.taskType.emZhenHongStage] then
        level = initRecord(taskcommon.taskType.emZhenHongStage, actor)
    else
        level = level + 1
    end
    record[taskcommon.taskType.emZhenHongStage] = level
    updateTask(actor, taskcommon.taskType.emZhenHongStage, 0, level)
    updateTask(actor, taskcommon.taskType.emZhenHongStageUpAdd, 0, count)
end

function onLingQiStageUp(actor, count)
    local record = getRecord(actor)
    local level = record[taskcommon.taskType.emLingQiStage] or 0
    if not record[taskcommon.taskType.emLingQiStage] then
        level = initRecord(taskcommon.taskType.emLingQiStage, actor)
    else
        level = level + count
    end
    record[taskcommon.taskType.emLingQiStage] = level
    updateTask(actor, taskcommon.taskType.emLingQiStage, 0, level)
    updateTask(actor, taskcommon.taskType.emLingQiStageUpAdd, 0, count)
end

function onShenShouLevelUp(actor, count)
    local record = getRecord(actor)
    local level = record[taskcommon.taskType.emShenShouLevel] or 0
    if not record[taskcommon.taskType.emShenShouLevel] then
        level = initRecord(taskcommon.taskType.emShenShouLevel, actor)
    else
        level = level + count
    end
    record[taskcommon.taskType.emShenShouLevel] = level
    updateTask(actor, taskcommon.taskType.emShenShouLevel, 0, level)
    updateTask(actor, taskcommon.taskType.emShenShouLevelUpAdd, 0, count)
end

function onShenlingSatge(actor, idx, count)
    local record = getRecord(actor)
    local allStage = record[taskcommon.taskType.emShenlingStage] or 0
    if not record[taskcommon.taskType.emShenlingStage] then
        allStage = initRecord(taskcommon.taskType.emShenlingStage, actor)
    else
        allStage = allStage + count
    end
    record[taskcommon.taskType.emShenlingStage] = allStage
    updateTask(actor, taskcommon.taskType.emShenlingStage, 0, allStage)
    updateTask(actor, taskcommon.taskType.emShenlingSatgeAdd, idx, count)
end

function onShenPanLevelUp(actor, count)
    local record = getRecord(actor)
    local recordStage = record[taskcommon.taskType.emShenPanStage] or 0
    local allStage = shenpansystem.getShenPanStage(actor)
    if recordStage < allStage then
        record[taskcommon.taskType.emShenPanStage] = allStage
        updateTask(actor, taskcommon.taskType.emShenPanStage, 0, allStage)
    end
    updateTask(actor, taskcommon.taskType.emShenPanLevelUpAdd, 0, count)
end

function onWarcraftStage(actor, stage)
    local record = getRecord(actor)
    local recordLevel = record[taskcommon.taskType.emWarcraftStage] or 0
    if recordLevel < stage then
        record[taskcommon.taskType.emWarcraftStage] = stage
        updateTask(actor, taskcommon.taskType.emWarcraftStage, 0, stage)
    end
end

function onYSEquipPutUp(actor)
    local record = getRecord(actor)
    local allStar = yuansusystem.getYSEquipStar(actor)
    record[taskcommon.taskType.emYSEquipStar] = allStar
    updateTask(actor, taskcommon.taskType.emYSEquipStar, 0, allStar)
end

function onZhenHongActive(actor)
    local record = getRecord(actor)
    local count = record[taskcommon.taskType.emZhenHongActive] or 0
    if not record[taskcommon.taskType.emZhenHongActive] then
        count = initRecord(taskcommon.taskType.emZhenHongActive, actor)
    else
        count = count + 1
    end
    record[taskcommon.taskType.emZhenHongActive] = count
    updateTask(actor, taskcommon.taskType.emZhenHongActive, 0, count)
end

function onLingQiActive(actor)
    local record = getRecord(actor)
    local count = record[taskcommon.taskType.emLingQiActive] or 0
    if not record[taskcommon.taskType.emLingQiActive] then
        count = initRecord(taskcommon.taskType.emLingQiActive, actor)
    else
        count = count + 1
    end
    record[taskcommon.taskType.emLingQiActive] = count
    updateTask(actor, taskcommon.taskType.emLingQiActive, 0, count)
end

function onShenShouActive(actor)
    local record = getRecord(actor)
    local count = record[taskcommon.taskType.emShenShouActive] or 0
    if not record[taskcommon.taskType.emShenShouActive] then
        count = initRecord(taskcommon.taskType.emShenShouActive, actor)
    else
        count = count + 1
    end
    record[taskcommon.taskType.emShenShouActive] = count
    updateTask(actor, taskcommon.taskType.emShenShouActive, 0, count)
end

csmsgdispatcher.Reg(CrossSrvCmd.SCrossNetCmd, CrossSrvSubCmd.SCrossNetCmd_TransferEvent, onTransferEvent)
msgsystem.regHandle(OffMsgType_TASKEVENT, OffMsgTASKEVENT)

actorevent.reg(aeSuitActive, onSuitActive)
actorevent.reg(aeShengwu, onShengwuActive)
actorevent.reg(aeCustomChange, onCumstomChange)
actorevent.reg(aeCustomWave, onCumstomWave)
actorevent.reg(aeConsumeYuanbao, onConsumeYuanbao)
actorevent.reg(aeSmeltEquip, onSmeltEquip)
actorevent.reg(aeLevel, onLevelUp)
actorevent.reg(aeFightPower, onFightPower)
actorevent.reg(aeZhuansheng, onZhuansheng)
actorevent.reg(aeWingLevelUp, onWingLevelUp)
actorevent.reg(aeEnhanceEquip, onEquipEnhanceUpLevel)
actorevent.reg(aeAppendEquip, onEquipAppendUpLevel)
actorevent.reg(aeCultureEquip, onEquipCulture)
actorevent.reg(aePutEquip, onEquip)
--actorevent.reg(aeDamonFight, onDamonFight)
actorevent.reg(aeSkillLevelup, onSkillUp)
actorevent.reg(aeMonsterDie, onMonsterDie)
actorevent.reg(aeEnterFuben, onEnterFuben)
actorevent.reg(aeFinishFuben, onFinishFuben)
actorevent.reg(aeActiveFuben, onActiveFuben)
actorevent.reg(aeWanmoFuben, onWanmoFuben)
actorevent.reg(aeHeianFuben, onHeianFuben)
actorevent.reg(aeDespairBoss, onDespairBoss)
actorevent.reg(aeBeatMapBoss, onBeatCustom)
actorevent.reg(aeStoreCost, onShopConsume)
actorevent.reg(aeStarsoulUpStage, onStarsoulUpStage)
actorevent.reg(aeTalismanUpLevel, onTalismanUpLevel)
actorevent.reg(aeDamonLevel, onDamonLevel)
actorevent.reg(aeDamonStage, onDamonStage)
actorevent.reg(aeShenmoLevel, onShenmoLevel)
actorevent.reg(aeShenmoStage, onShenmoStage)
actorevent.reg(aeElementLevel, onElementLevel)
actorevent.reg(aeElementEquip, onElementEquip)
actorevent.reg(aeInterGuajifu, onPassGuajifu)
actorevent.reg(aeBeatRelicCount, onBeatRelic)
actorevent.reg(aeSaoDang, onSaoDang)
actorevent.reg(aeComposeItem, onComposeItem)
actorevent.reg(aeElemenDraw, onEleMentDraw)
actorevent.reg(aeFastFight, onFastFight)
actorevent.reg(aeAllotPoint, onAllotPoint)
actorevent.reg(aeCostItem, onCostItem)
actorevent.reg(aeFruitEat, onFruitEat)
actorevent.reg(aeTalentUp, onTalentUp)
--actorevent.reg(aeBeatShilianBoss, onBeatShilian)
actorevent.reg(aeWorship, onWorship)
actorevent.reg(aeRecharge, onRecharge)
actorevent.reg(aeMonthCardReward, onMonthCard)
actorevent.reg(aeFinishLoop, onFinishLoop)
actorevent.reg(aeFirstRechargeReward, onFirstChargetReward)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeCreateRole, onCreateRole)
actorevent.reg(aeSVipLevel, onVipLevel)
actorevent.reg(aeGhostLevel, onGhostLv)
actorevent.reg(aeTouxianLevel, onTouxianLv)
actorevent.reg(aeElementCreate, onElementCreate)
actorevent.reg(aeGodEquipCnt, onGodEquipCnt)
actorevent.reg(aePurifyEquip, onPurifyEquip)
actorevent.reg(aeFortFloor, onFortFloor)
actorevent.reg(aeMineMonsterCnt, onMineMonsterCnt)
actorevent.reg(aeSMUpgradeCnt, onSMUpgradeCnt)
--actorevent.reg(aeSuitLevelUp, onSuitLevelUp)
actorevent.reg(aeStoneInlay, onStoneInlay)
actorevent.reg(aeBannerActive, onBannerActive)
actorevent.reg(aeBannerStarUp, onBannerStarUp)
actorevent.reg(aeJuSoulUp, onJuSoulUp)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeAgreementTask, onAgreementTask)
actorevent.reg(aeBuyStoreItem, onBuyStoreItem)
actorevent.reg(aeMainTaskFinish, ehMainTaskFinish) --主线任务完成
actorevent.reg(aeJjcRank, onJjcRank)
actorevent.reg(aeGuildCreate, onCreateGuild)
actorevent.reg(aeJoinGuild, onJoinGuild)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeEnterXuese, onEnterXuese)--进入血色
actorevent.reg(aeEnterDevil, onEnterDevil) --进入恶魔
actorevent.reg(aeEnterDespire, onEnterDespire) --进入全民
actorevent.reg(aeEnterJjc, onEnterJjc) --进入竞技场
actorevent.reg(aeChat, onChat)--聊天
actorevent.reg(aeYongbingLevel, onYongbingLevel)--佣兵升级
actorevent.reg(aeYongbingStage, onYongbingStage)--佣兵进阶
actorevent.reg(aeHunqiLevel, onHunqiLevel)--魂器升级
actorevent.reg(aeXunbao, onXunbao)--寻宝
actorevent.reg(aeJunxianLevel, onJunxianLv)--军衔等级
actorevent.reg(aeAoyiLevelUp, onAoyiCount)--奥义升级
actorevent.reg(aeMeilinLevelUp, onMeilinLv)--梅林升级
actorevent.reg(aeShenqiLevelUp, onShenqiLv)--神器升级
actorevent.reg(aeShenzhuangLevelUp, onShenzhuangLv)--神装升级
actorevent.reg(aeFacadeActive, onFacadeActive) --外观激活
actorevent.reg(aePrivilegeBuy, onPrivilegeBuy) --购买特权卡
actorevent.reg(aeLilianTaskFinish, onLilianTask) --历练任务完成
actorevent.reg(aeCustomFight, onCustomFight)
actorevent.reg(aeCrossBoss, onCrossBossDie) --参与击杀跨服boss（非历史类）
actorevent.reg(aeShenmoBoss, onShenmoBossDie)--参与击杀圣殿boss（非历史类）
actorevent.reg(aeAdventure, onAdventure)--完成一次探秘事件（非历史类）
actorevent.reg(aeCrossBossBelong, onCrossBossBelong)--跨服boss获取次数
actorevent.reg(aeDropBox, onDropBox)--全民夺宝采集次数
actorevent.reg(aeMoLianRest, onMoLianRest)--魔炼之地重置事件
actorevent.reg(aeYYMSBuy, onYYMSBuy)--一元秒杀购买事件
actorevent.reg(aeZSMSBuy, onZSMSBuy)--转生秒杀购买事件(yyms2)
actorevent.reg(aeSvipMSBuy, onSvipMSBuy)--SVIP秒杀购买事件
actorevent.reg(aeAct35Draw, onAct35Draw)--活动35超级转盘抽奖事件
actorevent.reg(aeEnterMolong, onEnterMolong)--挑战魔龙事件
actorevent.reg(aeSecretStarUp, onSecretStarUp)--密语升星事件
actorevent.reg(aeShenShouDraw, onShenShouDraw)--神兽抽奖事件
actorevent.reg(aeShenyuLevel, onShenyuLevel)--神羽升级事件
actorevent.reg(aeShenlingLevel, onShenlingLevel)--圣灵升级事件
actorevent.reg(aeShenyouLevel, onShenyouLevel)--神佑升级事件
actorevent.reg(aeDarkBossKill, onDarkBossKill)--暗黑圣殿boss击杀
actorevent.reg(aePurifyLevel, onPurifyLevel)--精炼升级事件
actorevent.reg(aeZHBossSummon, onZHBossSummon)--真红boss召唤事件
actorevent.reg(aeZHBossKill, onZHBossKill)--真红boss击杀事件
actorevent.reg(aeLHBelong, onLHBelong)--获得一次狼魂归属
actorevent.reg(aeLHAddWolf, onLHAddWolf)--获得狼魂值
actorevent.reg(aeLHKillActor, onLHKillActor)--狼魂要塞中击杀玩家
actorevent.reg(aeLHKillMonster, onLHKillMonster)--狼魂要塞中击杀怪物
actorevent.reg(aeLHExchange, onLHExchange)--转换狼魂值
actorevent.reg(aeLHFirstBlood, onLHFirstBlood)--狼魂第一滴血
actorevent.reg(aeLHSerialKill, onLHSerialKill)--狼魂连杀
actorevent.reg(aeLHFirstRank, onLHFirstRank)--狼魂获得第一名
actorevent.reg(aeConsumeDiamond, onConsumeDiamond) --消费点券
actorevent.reg(aeTujianActive, onTujianActive) --魔兽宝典激活
actorevent.reg(aeAngelshield, onAngelshield) --天使圣盾提升
actorevent.reg(aeSMZLLevelUp, onSMZLLevelUp) --暗黑魔灵升级
actorevent.reg(aeYuanSuLevelUp, onYuanSuLevelUp) --元素升级
actorevent.reg(aeZhenHongStageUp, onZhenHongStageUp) --真红套装升级
actorevent.reg(aeLingQiStageUp, onLingQiStageUp) --灵器升级
actorevent.reg(aeShenShouLevelUp, onShenShouLevelUp) --神兽升级
actorevent.reg(aeShenlingSatge, onShenlingSatge) --圣灵进阶
actorevent.reg(aeShenPanLevelUp, onShenPanLevelUp) --审判打造
actorevent.reg(aeWarcraftStage, onWarcraftStage) --魔兽宝典进阶
actorevent.reg(aeYSEquipPutUp, onYSEquipPutUp) --元素装备穿戴
actorevent.reg(aeZhenHongActive, onZhenHongActive) --真红装备激活
actorevent.reg(aeLingQiActive, onLingQiActive) --真红装备激活
actorevent.reg(aeShenShouActive, onShenShouActive) --神兽激活

----------------------------------------------------------------------------------
--初始化
local function init()
    initRecordFuncs[taskcommon.taskType.emHuFuLevel] = equipsystem.getHufuLevel
    initRecordFuncs[taskcommon.taskType.emWarcraftStage] = warcraftsystem.getWarcraftStage
    initRecordFuncs[taskcommon.taskType.emShenPanStage] = shenpansystem.getShenPanStage
    initRecordFuncs[taskcommon.taskType.emAngelshield] = angelshieldsystem.getAngelshieldStage
    initRecordFuncs[taskcommon.taskType.emShenlingStage] = shenglingsystem.getShengLingStage
    initRecordFuncs[taskcommon.taskType.emShenyouStage] = shenyousystem.getShenYouStage
    initRecordFuncs[taskcommon.taskType.emSMZLLevel] = smzlsystem.getSMZLLevel
    initRecordFuncs[taskcommon.taskType.emZhenHongStage] = zhenhongsystem.getZhenHongSuit
    initRecordFuncs[taskcommon.taskType.emLingQiStage] = lingqisystem.getLingQiStage
    initRecordFuncs[taskcommon.taskType.emShenShouLevel] = shenshousystem.getShenShouTotalLevel
    initRecordFuncs[taskcommon.taskType.emYSEquipStar] = yuansusystem.getYSEquipStar
    initRecordFuncs[taskcommon.taskType.emZhenHongActive] = zhenhongsystem.getZhenHongActive
    initRecordFuncs[taskcommon.taskType.emLingQiActive] = lingqisystem.getLingQiActive
    initRecordFuncs[taskcommon.taskType.emShenShouActive] = shenshousystem.getShenShouActive
end
table.insert(InitFnTable, init)

----------------------------------------------------------------------------------
--GM命令
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.clearRecord = function(actor, args)
    local taskType = tonumber(args[1])
    if not taskType then return end
    local record = getRecord(actor)
    record[taskType] = nil
    return true
end
