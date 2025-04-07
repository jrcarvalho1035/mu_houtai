module("smzlsystem", package.seeall)

--魔灵觉醒技能升级条件([升级类型]=魔灵id)
MLLevelType = {
    [87] = 1,
    [88] = 2,
    [89] = 3,
    [90] = 4,
    [91] = 5,
    [92] = 6,
    [93] = 7,
    [94] = 8,
    [95] = 9,
    [96] = 10,
    [97] = 11,
    [98] = 12,
    [99] = 13,
    [100] = 14,
    [101] = 15,
    [102] = 16,
    [103] = 17,
    [104] = 18,
    [105] = 19,
    [106] = 20,
    [107] = 21,
    [108] = 22,
    [109] = 23,
    [110] = 24,
    [111] = 25,
    [112] = 26,
    [113] = 27,
    [114] = 28,
    [115] = 29,
    [116] = 30,
}

function getVar(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then return end
    if var.smzl == nil then var.smzl = {} end
    
    if not var.smzl.level then var.smzl.level = 0 end
    if not var.smzl.exp then var.smzl.exp = 0 end
    if not var.smzl.pill then var.smzl.pill = {} end
    if not var.smzl.rewardsRecord then var.smzl.rewardsRecord = 0 end
    if not var.smzl.drawtimes then var.smzl.drawtimes = 0 end
    if not var.smzl.power then var.smzl.power = 0 end
    if not var.smzl.wakes then var.smzl.wakes = {} end
    return var.smzl
end

function checkMLLevel(actor, typeUp, needLv)
    local id = MLLevelType[typeUp]
    if not id then return end
    local var = getVar(actor)
    return (var.wakes[id] or 0) >= needLv
end

function getSMZLLevel(actor)
    local var = getVar(actor)
    return math.ceil((var.level + 1) / 11)
end

local function tableAddMulit(t, attrs, n)
    for _, v in ipairs(attrs) do
        t[v.type] = (t[v.type] or 0) + (v.value * n)
    end
end

local function isEndLevel(level)
    if level == #SMSpiritStarConfig then
        return false
    end
    return SMSpiritStarConfig[level].exp == 0
end

function calcAttr(actor, isCalc)
    local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_SMZL)
    attr:Reset()
    
    local var = getVar(actor)
    local baseAttrs = {}
    local totalAttrs = {}
    local power = 0
    if var.level > 0 then
        --tableAddMulit(totalAttrs, SMSpiritStarConfig[var.level].attr, 1)
        -- local addper = 1 + (SMSpiritPillConfig[3].per * (var.pill[3] or 0) / 10000)
        -- for type in pairs(totalAttrs) do
        --     totalAttrs[type] = math.floor(totalAttrs[type] * addper)
        -- end
        baseAttrs = SMSpiritStarConfig[var.level].attr
        tableAddMulit(totalAttrs, SMSpiritStarConfig[var.level].exattr, 1)
    end
    
    local stage = math.ceil((var.level + 1) / 11)
    power = power + SMSpiritStageConfig[stage].power
    
    for i = 1, #SMSpiritPillConfig do
        tableAddMulit(totalAttrs, SMSpiritPillConfig[i].attr, var.pill[i] or 0)
        power = power + SMSpiritPillConfig[i].power * (var.pill[i] or 0)
    end

    --魔灵觉醒属性
    for id, conf in ipairs(DiabloWakeConfig) do
        local level = var.wakes[id] or 0
        if level > 0 then
            tableAddMulit(totalAttrs, conf.attrs, level)
        end

        local skillId = conf.skillId
        local level = passiveskill.getSkillLv(actor, skillId)
        local skillConf = SkillPassiveConfig[skillId][level]
        if skillConf.type == 1 then
            tableAddMulit(totalAttrs, skillConf.addattr, 1)
        end
        power = power + skillConf.power
    end

    --按万分比增加魔灵升级属性
    local mlLevelPer = 1 + (totalAttrs[Attribute.atMLLevelPer] or 0) / 10000
    for _,v in ipairs(baseAttrs) do
        totalAttrs[v.type] = (totalAttrs[v.type] or 0) + math.floor(v.value * mlLevelPer)
    end

    for k, v in pairs(totalAttrs) do
        attr:Set(k, v)
    end
    if power > 0 then
        attr:SetExtraPower(power)
    end
    
    if isCalc then
        LActor.reCalcAttr(actor)
        var.power = (utils.getAttrPower0(totalAttrs) + power)
    end
end

function getPower(actor)
    local var = getVar(actor)
    return var.power
end

function onSMZLLevelUp(actor, pack)
    local var = getVar(actor)
    local stage = math.ceil((var.level + 1) / 11)
    local conf = SMSpiritStageConfig[stage]
    if SMSpiritStarConfig[var.level].exp == 0 then return end
    if not SMSpiritStarConfig[var.level + 1] then return end
    
    if not actoritem.checkItem(actor, conf.feeditem.id, conf.feeditem.count) then
        return
    end
    actoritem.reduceItem(actor, conf.feeditem.id, conf.feeditem.count, "smzl level up")
    local oldLevel = var.level
    var.exp = var.exp + conf.addexp
    while(var.exp >= SMSpiritStarConfig[var.level].exp and SMSpiritStarConfig[var.level + 1]) do
        var.exp = var.exp - SMSpiritStarConfig[var.level].exp
        var.level = var.level + 1
        if isEndLevel(var.level) then
            break
        end
    end
    
    local newStage = math.ceil((var.level + 1) / 11)
    actorevent.onEvent(actor, aeSMZLLevelUp, newStage)
    if oldLevel < var.level then
        calcAttr(actor, true)
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMZLLevelUp)
    LDataPack.writeShort(npack, var.level)
    LDataPack.writeInt(npack, var.exp)
    LDataPack.writeShort(npack, conf.addexp)
    LDataPack.flush(npack)
end

function onStageUp(actor, pack)
    local var = getVar(actor)
    local stage = math.ceil((var.level + 1) / 11)
    local conf = SMSpiritStageConfig[stage]
    if SMSpiritStarConfig[var.level].exp ~= 0 then return end
    if not SMSpiritStarConfig[var.level + 1] then return end
    
    if not actoritem.checkItem(actor, conf.needitem.id, conf.needitem.count) then
        return
    end
    actoritem.reduceItem(actor, conf.needitem.id, conf.needitem.count, "smzl stage up")
    
    var.level = var.level + 1
    while(var.exp >= SMSpiritStarConfig[var.level].exp and SMSpiritStarConfig[var.level + 1]) do
        var.exp = var.exp - SMSpiritStarConfig[var.level].exp
        var.level = var.level + 1
        if isEndLevel(var.level) then
            break
        end
    end

    local newStage = math.ceil((var.level + 1) / 11)
    actorevent.onEvent(actor, aeSMZLLevelUp, newStage)
    dark.onSMZLStageUp(actor, stage, newStage)
    calcAttr(actor, true)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMZLStageUp)
    LDataPack.writeShort(npack, var.level)
    LDataPack.writeShort(npack, var.exp)
    LDataPack.flush(npack)
end

function onUsePill(actor, pack)
    local index = LDataPack.readChar(pack)
    local var = getVar(actor)
    if not var.pill[index] then
        var.pill[index] = 0
    end
    local stage = math.ceil((var.level + 1) / 11)
    if SMSpiritStageConfig[stage].maxpill[index] <= var.pill[index] then
        return
    end
    
    if not actoritem.checkItem(actor, SMSpiritPillConfig[index].itemid, 1) then
        return
    end
	
	--função para chamar ID e contar a quantidade de itens
	local idz = SMSpiritPillConfig[index].itemuse[1]
	count = actoritem.getItemCount(actor, idz)
	
	if count + (var.pill[index] or 0) >= SMSpiritStageConfig[stage].maxpill[index] then
		count = SMSpiritStageConfig[stage].maxpill[index] - (var.pill[index] or 0)
	end
	
	---
	
    actoritem.reduceItem(actor, SMSpiritPillConfig[index].itemid, count, "smzl pill use")
    
    var.pill[index] = var.pill[index] + count
    calcAttr(actor, true)
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMZLUsePill)
    LDataPack.writeChar(npack, #SMSpiritPillConfig)
    for i = 1, #SMSpiritPillConfig do
        LDataPack.writeInt(npack, var.pill[i] or 0)
    end
    LDataPack.flush(npack)
end

function onStartDraw(actor, pack)
    local var = getVar(actor)
    local conf = SMSecretConfig[var.drawtimes + 1]
    if not conf then return end
    
    if not actoritem.checkItem(actor, conf.needitem.id, conf.needitem.count) then
        return
    end
    actoritem.reduceItem(actor, conf.needitem.id, conf.needitem.count, "smzl secret draw")
    
    local total = 0
    local multipleindex = 1
    local rand = math.random(1, 10000)
    for k, v in ipairs(conf.multiple) do
        total = total + v[1]
        if rand < total then
            multipleindex = k
            break
        end
    end
    
    total = 0
    local countindex = 1
    rand = math.random(1, 10000)
    for k, v in ipairs(conf.count) do
        total = total + v[1]
        if rand < total then
            countindex = k
            break
        end
    end
    
    var.drawtimes = var.drawtimes + 1
    
    actoritem.addItem(actor, conf.itemid, math.floor(conf.count[countindex][2] * conf.multiple[multipleindex][2] * 10), "smzl draw", 1)
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMZLDrawReturn)
    LDataPack.writeChar(npack, multipleindex)
    LDataPack.writeChar(npack, countindex)
    LDataPack.writeChar(npack, var.drawtimes)
    LDataPack.flush(npack)
end

function onGetBoxReward(actor, pack)
    local index = LDataPack.readChar(pack)

    local config = SMSecretBoxConfig[index]
    if not config then return end
    
    local var = getVar(actor)
    if var.drawtimes < config.count then return end
    if System.bitOPMask(var.rewardsRecord, index) then return end

    var.rewardsRecord = System.bitOpSetMask(var.rewardsRecord, index, true)
    actoritem.addItems(actor, config.rewards, "smzl box rewards")

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMZLGetBox)
    LDataPack.writeInt(npack, var.rewardsRecord)
    LDataPack.flush(npack)
end

function onSMZLWakeUp(actor, pack)
    local id = LDataPack.readChar(pack)
    local config = DiabloWakeConfig[id]
    if not config then return end

    local var = getVar(actor)
    local level = var.wakes[id] or 0
    if level >= config.maxStage then return end

    if not actoritem.checkItems(actor, config.needItem) then
        return
    end
    actoritem.reduceItems(actor, config.needItem, "moling wake up")

    level = level + 1
    var.wakes[id] = level
    calcAttr(actor, true)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMZLWakeUp)
    LDataPack.writeChar(npack, id)
    LDataPack.writeShort(npack, level)
    LDataPack.flush(npack)
end

function sendDrawInfo(actor)
    local var = getVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMZLDrawInfo)
    LDataPack.writeChar(npack, var.drawtimes)
    LDataPack.writeInt(npack, var.rewardsRecord)
    LDataPack.flush(npack)
end

function onLevelChange(actor, pid)
    local var = getVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, pid)
    LDataPack.writeShort(npack, var.level)
    LDataPack.writeShort(npack, var.exp)
    LDataPack.flush(npack)
end

function sendSMZLInfo(actor)
    local var = getVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMZLInfo)
    LDataPack.writeShort(npack, var.level)
    LDataPack.writeShort(npack, var.exp)
    LDataPack.writeChar(npack, #SMSpiritPillConfig)
    for k, v in ipairs(SMSpiritPillConfig) do
        LDataPack.writeInt(npack, var.pill[k] or 0)
    end
    LDataPack.flush(npack)
end

function sendMLWakeInfo(actor)
    local var = getVar(actor)
    if not var then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Shenmo, Protocol.sShenmoCmd_SMZLWakeInfo)
    if not npack then return end

    LDataPack.writeChar(npack, #DiabloWakeConfig)
    for id in ipairs(DiabloWakeConfig) do
        LDataPack.writeChar(npack, id)
        LDataPack.writeShort(npack, var.wakes[id] or 0)
    end
    LDataPack.flush(npack)
end

function onSystemOpen(actor)
    sendSMZLInfo(actor)
    sendDrawInfo(actor)
    sendMLWakeInfo(actor)
end

local function onInit(actor)
    calcAttr(actor, false)
end

local function onLogin(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.smzl) then return end
    sendSMZLInfo(actor)
    sendDrawInfo(actor)
    sendMLWakeInfo(actor)
end

local function onNewDayArrive(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.smzl) then return end
    local var = getVar(actor)
    var.drawtimes = 0
    var.rewardsRecord = 0
    sendDrawInfo(actor)
end

local function init()
    actorevent.reg(aeNewDayArrive, onNewDayArrive)
    actorevent.reg(aeInit, onInit)
    actorevent.reg(aeUserLogin, onLogin)
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.smzl, onSystemOpen)

    if System.isLianFuSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Shenmo, Protocol.cShenmoCmd_SMZLLevelUp, onSMZLLevelUp)
    netmsgdispatcher.reg(Protocol.CMD_Shenmo, Protocol.cShenmoCmd_SMZLStageUp, onStageUp)
    netmsgdispatcher.reg(Protocol.CMD_Shenmo, Protocol.cShenmoCmd_SMZLUsePill, onUsePill)
    netmsgdispatcher.reg(Protocol.CMD_Shenmo, Protocol.cShenmoCmd_SMZLStartDraw, onStartDraw)
    netmsgdispatcher.reg(Protocol.CMD_Shenmo, Protocol.cShenmoCmd_SMZLGetBox, onGetBoxReward)
    netmsgdispatcher.reg(Protocol.CMD_Shenmo, Protocol.cShenmoCmd_SMZLWakeUp, onSMZLWakeUp)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.smzl = function (actor, args)
    local level = tonumber(args[1])
    local var = getVar(actor)
    var.level = level
    sendSMZLInfo(actor)
    return true
end

gmCmdHandlers.smzlAll = function (actor, args)
    local maxlevel = #SMSpiritStarConfig
    local var = getVar(actor)
    if var.level < maxlevel then
        var.level = maxlevel
    end
    for index = 1, #SMSpiritPillConfig do
        var.pill[index] = SMSpiritStageConfig[#SMSpiritStageConfig].maxpill[index]
    end
    for id, conf in pairs(DiabloWakeConfig) do
        var.wakes[id] = conf.maxStage
    end
    calcAttr(actor, true)
    sendSMZLInfo(actor)
    return true
end

gmCmdHandlers.mlwake = function (actor, args)
    local id = tonumber(args[1]) or 0
    local pack = LDataPack.allocPacket()
    LDataPack.writeChar(pack, id)
    LDataPack.setPosition(pack, 0)
    onSMZLWakeUp(actor, pack)
    return true
end

