
module("shenmoboss", package.seeall)

SHENMOBOSS_DATA = SHENMOBOSS_DATA or {}
local function getShenmoBossData()
	return SHENMOBOSS_DATA
end

local function getVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.shenmoboss then
		var.shenmoboss = {}
        var.shenmoboss.remind = 0
		var.shenmoboss.belongtimes = 0
		var.shenmoboss.challengeCd = 0
	end
	return var.shenmoboss
end

local function getBossData(id)
	return SHENMOBOSS_DATA[id]
end

local function getConfigBybossId(bossId)
    for k,v in ipairs(ShenmoFubenConfig) do
        if v.bossId == bossId then
            return v
        end
    end
end

--求下一个护盾
local function getNextShield(id, hp)
	if nil == hp then hp = 101 end

	local conf = ShenmoFubenConfig[id]
	if nil == conf then return nil end
	for i, s in ipairs(conf.shield) do
		if s.hp < hp then return s end
	end
	return nil
end


local function getMonsterName(bossId)
	if MonstersConfig[bossId] then
		return tostring(MonstersConfig[bossId].name)
	end
	return "nil"
end

--清空归属者
local function clearBelongInfo(ins, actor, bossData)
	if actor == bossData.belong then
        local x, y = LActor.getEntityScenePos(actor)
        instancesystem.s2cBelongListClear(bossData.hfuben, x, y)
		bossData.belong = nil
		onBelongChange(bossData, actor, bossData.belong, x, y)		
	end
end

--归属者改变处理
function onBelongChange(bossData, oldBelong, newBelong, x, y)
	if oldBelong then
		LActor.setCamp(oldBelong, CampType_Normal)
	end
	if newBelong then
		LActor.setCamp(newBelong, CampType_Belong)
	end
	--广播归属者信息
    instancesystem.s2cBelongData(nil, oldBelong, bossData.belong, bossData.hfuben, x, y) ---归属者信息    
end

--重置副本，如果boss死了就创建新副本，如果没死就满血
local function refreshBoss(_, id)
	local bossData = getBossData(id)
	local ins = instancesystem.getInsByHdl(bossData.hfuben)
	local handle = ins.scene_list[1]
	local scene = Fuben.getScenePtr(handle)
	local refreshConf = RefreshMonsters[ins.config.refreshMonster]
	local position = refreshConf.position[ShenmoFubenConfig[bossData.id].index]
	local boss = ins:insCreateMonster(handle, bossData.bossId, position.x, position.y)
	bossData.hpPercent = 100
	bossData.damageList = {}
	bossData.nextShield = getNextShield(id)
	bossData.curShield = nil
	bossData.shield = 0
	bossData.refreshtime = 0
	if bossData.shieldEid then
		LActor.cancelScriptEvent(nil, bossData.shieldEid)
		bossData.shieldEid = nil
	end
	bossinfo.createBossInfo(ins, bossData.bossId, boss)
	s2cShenmoBossUpdate(id, bossData.bossId)
end

--护盾结束
function finishShield(_, bossData)
	bossData.shieldEid = nil
    bossData.shield = 0
    local x, y = LActor.getEntityScenePos(bossData.monster)
	LActor.setInvincible(bossData.monster, false)
	instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, bossData.curShield.shield, nil, x, y)
end

-------------------------------------------------------------------------------------------------------

--神魔圣殿列表查看
function c2sShenmoBossList(actor)
	s2cShenmoBossList(actor)
end

--神魔圣殿列表
function s2cShenmoBossList(actor)
	local bossDatas = getShenmoBossData()
    local var = getVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SMInfo)
	if npack == nil then return end
	LDataPack.writeChar(npack, #ShenmoFubenConfig)
	for id, boss in pairs(bossDatas) do
		local ins = instancesystem.getInsByHdl(boss.hfuben)
		local count = ins and ins.actor_list_count or 0 		--挑战者数量
		LDataPack.writeChar(npack, id)
		LDataPack.writeString(npack, MonstersConfig[boss.bossId].name)
        LDataPack.writeString(npack, MonstersConfig[boss.bossId].head)
        LDataPack.writeShort(npack, MonstersConfig[boss.bossId].avatar)
        LDataPack.writeByte(npack, #boss.damageList > 0 and 1 or 0)
		LDataPack.writeChar(npack, boss.hpPercent)
		LDataPack.writeInt(npack, boss.refreshtime)
	end
	LDataPack.writeChar(npack, var.belongtimes)
	LDataPack.writeShort(npack, math.max(var.challengeCd-System.getNowTime(), 0))
	LDataPack.flush(npack)
end

function updateBelong(actor, belongtimes)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SMUpdateBelong)
	if not npack then return end
	LDataPack.writeChar(npack, belongtimes)
	LDataPack.flush(npack)
end

--神魔圣殿提醒设置
function c2sShenmoBossRemind(actor, pack)
	local remind = LDataPack.readInt(pack)
	local var = getVar(actor)
    var.remind = remind
    sendShenmoBossRemind(actor)
end

--神魔圣殿发送提醒设置
function sendShenmoBossRemind(actor)
    local var = getVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SMRemindInfo)
    LDataPack.writeInt(pack, var.remind)
    LDataPack.flush(pack)
end

--神魔圣殿挑战
function c2sShenmoBossFight(actor, pack)
	--if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.home) then return end
	local index = LDataPack.readChar(pack)
	local conf = ShenmoFubenConfig[index]
	if not conf then return end

    local bossData = getBossData(index)	
	
	local var = getVar(actor)
	if System.getNowTime() < (var.challengeCd or 0) then --检查cd
		return
	end

	if not utils.checkFuben(actor, conf.fbId) then return end

	--处理进入
	local x,y = utils.getSceneEnterCoor(conf.fbId)
	local ret = LActor.enterFuBen(actor, bossData.hfuben, 0, x, y)
	if not ret then
		print("Error bosshome enterFuben failed.. aid:"..LActor.getActorId(actor))
	end
	--local lv, zhuansheng = zhuanshengsystem.getZhuanSheng( MonstersConfig[conf.bossId].level)
	noticesystem.broadCastNotice(noticesystem.NTP.smbossenter, LActor.getName(actor), conf.scenename)
end

--神魔圣殿单个信息更新
function s2cShenmoBossUpdate(id, bossId, handle)
	local bossData = getBossData(id)
	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_AllFuben2)
	LDataPack.writeByte(npack, Protocol.sFubenCmd_SMUpdateInfo)

	LDataPack.writeChar(npack, id)
    LDataPack.writeChar(npack, bossData.hpPercent)
    LDataPack.writeInt(npack, bossData.refreshtime)
    LDataPack.writeChar(npack, #bossData.damageList > 0 and 1 or 0)

	if handle then
		Fuben.sendData(handle, pack)
	else
		System.broadcastData(npack) --向所有人广播信息		
	end
end

--登录事件
local function onLogin(actor)
    if System.isBattleSrv() then return end
	s2cShenmoBossList(actor)
	sendShenmoBossRemind(actor)
end

local function onBossDie(ins, monster, killHdl)
    local bossId = Fuben.getMonsterId(monster)
    local config = getConfigBybossId(bossId)
	local index = config.id
	local bossData = getBossData(index)
	local belongId = LActor.getActorId(bossData.belong) 
	local bName = LActor.getActorName(belongId)
	local bJob = LActor.getJob(bossData.belong)
	
	if not config then return end
	for actorId, v in pairs(bossData.damageList) do
		if actorId == belongId then --归属者
            local rewards = drop.dropGroup(config.belongDrop)
			local posX, posY = LActor.getEntityScenePoint(monster)

			for k,v in ipairs(rewards) do
				if ItemConfig[v.id].type == 54 then
					noticesystem.broadCastNotice(noticesystem.NTP.smbossdrop, LActor.getActorName(actorId), config.scenename, getMonsterName(config.bossId), ItemConfig[v.id].name)
				end
			end

            ins:addDropBagItem(bossData.belong, rewards, 10, posX, posY, true)
            local var = getVar(bossData.belong)
			var.belongtimes = var.belongtimes - 1
			updateBelong(bossData.belong, var.belongtimes)
		end
	end
	--boss信息重置
	bossData.hpPercent = 0
    bossData.refreshtime = ShenmoFubenConfig[index].refreshtime + System.getNowTime()
    bossData.damageList = {}
	clearBelongInfo(ins, bossData.belong, bossData) --清除归属者
	bossData.belong = nil
	s2cShenmoBossUpdate(index, bossData.bossId)
    LActor.postScriptEventLite(nil, ShenmoFubenConfig[index].refreshtime*1000, refreshBoss, bossData.id)
end

function enterShenmoBossArea(hfuben, actor, bossId)
	local ins = instancesystem.getInsByHdl(hfuben)
    local config = getConfigBybossId(bossId)
    local bossData = getBossData(config.id)
    local actorId = LActor.getActorId(actor)

	local handle = ins.scene_list[1]
	local scene = Fuben.getScenePtr(handle)
	local monster = Fuben.getSceneMonsterById(scene, bossData.bossId)
	--护盾信息
	if bossData.curShield then
        nowShield = bossData.shield
		if (bossData.curShield.type or 0) == 1 then
			nowShield = nowShield - System.getNowTime()
			if nowShield < 0 then nowShield = 0 end
        end
        
		instancesystem.s2cShieldInfo(ins.handle, bossData.curShield.type, nowShield, bossData.curShield.shield, actor)
	else
		instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, config.shield[1].shield, actor)
    end
	instancesystem.s2cBelongData(actor, nil, bossData.belong, bossData.hfuben)
    if ins.boss_info and ins.boss_info[bossId] then
		bossinfo.notify(ins, actor, ins.boss_info[bossId])
	else
		bossinfo.createBossInfo(ins, bossId, monster)
		bossinfo.notify(ins, actor, ins.boss_info[bossId])
	end
	LActor.setCamp(actor, CampType_Normal)--设置阵营为普通模式
end

local function onEnterFb(ins, actor)
	LActor.setCamp(actor, CampType_Normal)--设置阵营为普通模式
end

function hpNotice(monster, monId)
	local config = getConfigBybossId(monId)
	if config then
		local bossData = getBossData(config.id)
		if not bossData then return end
		local ins = instancesystem.getInsByHdl(bossData.hfuben)
		if not ins.boss_info[monId] then return end
		ins.boss_info[monId].hp = LActor.getHp(monster)		
		ins.boss_info[monId].need_update = true
		s2cShenmoBossUpdate(config.id, monId, bossData.hfuben)
	end
end

local function onBossDamage(ins, monster, value, attacker, res)
    local bossId = Fuben.getMonsterId(monster)
    local config = getConfigBybossId(bossId)

	local index = config.id
	local bossId = Fuben.getMonsterId(monster)
    local bossData = getBossData(index)    
    local actor = LActor.getActor(attacker)
	local var = getVar(actor)
	local actorId = LActor.getActorId(actor)
	
	bossData.damageList[actorId] = bossData.damageList[actorId] or 0

	--第一下攻击者为boss归属者
	if nil == bossData.belong and bossData.hfuben == LActor.getFubenHandle(attacker) and actor and var.belongtimes > 0 then 
		if LActor.isDeath(actor) == false and bossId == Fuben.getBossIdInArea(actor) then 
			local oldBelong = bossData.belong
            bossData.belong = actor
            local x, y = LActor.getEntityScenePos(monster)
			onBelongChange(bossData, oldBelong, actor, x, y)
			--使怪物攻击归属者
			--LActor.setAITarget(monster, LActor.getBattleLiveByOrder(actor))
		end
	end

	--更新boss血量信息
	local oldhp = LActor.getHp(monster)
	if oldhp <= 0 then return end

	local hp = oldhp - value
	if hp < 0 then hp = 0 end

	hp = hp / LActor.getHpMax(monster) * 100
	bossData.hpPercent = math.ceil(hp)

	bossData.monster = monster --记录BOSS实体

    --护盾判断
    if oldhp == LActor.getHpMax(monster) then
		bossData.nextShield = getNextShield(bossData.id)
		bossData.shield = 0
		bossData.curShield = nil
	elseif 0 == bossData.shield then --现在没有护盾
		if bossData.nextShield and 0 ~= bossData.nextShield.hp and hp < bossData.nextShield.hp then --从预备护盾里取护盾
			bossData.curShield = bossData.nextShield
			bossData.nextShield = getNextShield(bossData.id, bossData.curShield.hp) --再取下一个预备护盾
			
			res.ret = math.floor(LActor.getHpMax(monster) * bossData.curShield.hp / 100) --避免一招秒而不触发护盾，这里要恢复血量
			bossData.hpPercent = bossData.curShield.hp --要把血量设置回原值
			LActor.setInvincible(monster, true) --设无敌状态
            bossData.shield = bossData.curShield.shield + System.getNowTime()
            local x, y = LActor.getEntityScenePos(monster)
			instancesystem.s2cShieldInfo(bossData.hfuben, 1, bossData.curShield.shield, bossData.curShield.shield, nil, x, y)
			--注册护盾结束定时器
			bossData.shieldEid = LActor.postScriptEventLite(nil, bossData.curShield.shield*1000, finishShield, bossData)
			noticesystem.fubenAreaCastNotice(bossData.hfuben, noticesystem.NTP.homeShield, bossData.bossId)
		end
	end
	s2cShenmoBossUpdate(bossData.id, bossData.bossId, ins.handle)
end

local function onExitFb(ins, actor)
	local var = getVar(actor)
	var.challengeCd = System.getNowTime() + SMFBCommonConfig.entercd
    local bossId = Fuben.getBossIdInArea(actor)
	if bossId == 0 then return end	
    exitShenmoBossArea(nil, actor, bossId, ins)
end

function exitShenmoBossArea(hfuben, actor, bossId, ins)
	local ins = ins or instancesystem.getInsByHdl(hfuben)
    local config = getConfigBybossId(bossId)
    local data = getVar(actor)
    
	LActor.setCamp(actor, CampType_Normal) --退出变回正常阵营，此行影响s2cAttackList里的攻击者数量	
	local bossData = getBossData(config.id)

	instancesystem.s2cBelongData(actor, nil, nil, bossData.hfuben)
    clearBelongInfo(ins, actor, bossData) --清除归属者

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SMBossDisappear)
    LDataPack.writeByte(pack, config.id)
    LDataPack.flush(pack)
end

local function onOffline(ins, actor)
	local var = getVar(actor)
    local bossId = Fuben.getBossIdInArea(actor)
	if bossId == 0 then return end	
    exitShenmoBossArea(nil, actor, bossId, ins)
end

local function onActorDie(ins, actor, killHdl)
	local data = getVar(actor)
	local et = LActor.getEntity(killHdl)
	if not et then return end
    local attacker = LActor.getEntityType(et)
	local bossId = Fuben.getBossIdInArea(actor)
	local config = getConfigBybossId(bossId)
	if not config then return end
	local bossData = getBossData(config.id)
    if nil == bossData then return end    
    local x,y = LActor.getEntityScenePos(actor)

	if actor == bossData.belong then
		instancesystem.s2cBelongListClear(bossData.hfuben, x, y)
		--归属者被玩家打死，该玩家是新归属者
		if EntityType_Actor == attacker or EntityType_Role == attacker or EntityType_RoleSuper == attacker then 
            local newactor = LActor.getActor(et)
            local var = getVar(newactor)
            if var.belongtimes > 0 then
                bossData.belong = newactor
            else
                bossData.belong = nil
            end
			--怪物攻击新的归属者
			local handle = ins.scene_list[1]
			local scene = Fuben.getScenePtr(handle)
			local monster = Fuben.getSceneMonsterById(scene, bossData.bossId)
			if not monster then
				print("Error monster in actor belong die")
			end
			LActor.setAITarget(monster, et)
			--noticesystem.fubenCastNotice(bossData.hfuben, noticesystem.NTP.homeBelong, LActor.getName(bossData.belong), LActor.getName(actor))
		elseif EntityType_Monster == attacker then --归属者被怪物打死，怪物无归属
			bossData.belong = nil
		end
        local x, y = LActor.getEntityScenePos(bossData.belong)
		--广播归属者信息
		onBelongChange(bossData, actor, bossData.belong, x, y)
	else
		--不是归属者,死亡时候切换回正常阵营
		if LActor.getCamp(actor) == CampType_Attack then
			LActor.setCamp(actor, CampType_Normal)
		end
	end
end

--注册事件
local function onNewDay(actor, login)
	local var = getVar(actor)
	
	var.belongtimes = var.belongtimes + SMFBCommonConfig.belongtimes
	if var.belongtimes > SMFBCommonConfig.belongtimes * 2 then
		var.belongtimes = SMFBCommonConfig.belongtimes * 2
	end
	if not login then
		updateBelong(actor, var.belongtimes)
	end
end

local function initGlobalData()
	if System.isBattleSrv() then return end	
	
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeUserLogin, onLogin)
	for _, conf in pairs(ShenmoFubenConfig) do
		if conf.id%7 == 1 then
			insevent.registerInstanceMonsterDie(conf.fbId, onBossDie)
			insevent.registerInstanceEnter(conf.fbId, onEnterFb)
			insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
			insevent.registerInstanceExit(conf.fbId, onExitFb)
			insevent.registerInstanceOffline(conf.fbId, onOffline)
			insevent.registerInstanceActorDie(conf.fbId, onActorDie)
		end
	end


	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_SMGetInfo, c2sShenmoBossList)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_SMSetRemind, c2sShenmoBossRemind)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben2, Protocol.cFubenCmd_SMFight, c2sShenmoBossFight)
	if next(SHENMOBOSS_DATA) then return end
    local hfubenlist = {}
	for id, conf in pairs(ShenmoFubenConfig) do
        if not SHENMOBOSS_DATA[id] then
            if not hfubenlist[conf.stage] then
                hfubenlist[conf.stage] = instancesystem.createFuBen(conf.fbId)
			end
			local hfuben = hfubenlist[conf.stage]
			SHENMOBOSS_DATA[id] = {				
				id = conf.id,
				hpPercent = 100,
				hfuben = hfuben,
				shield = 0,
				curShield = nil,
				nextShield = getNextShield(conf.id),
				belong = nil,
				damageList = {},
				bossId = conf.bossId,
				refreshtime = 0,
			}
			local ins = instancesystem.getInsByHdl(hfuben)
            if ins then
                if not ins.data.smbossindex then
                    ins.data.smbossindex = {}
                    ins.data.smbossid = {}
                end
                ins.data.smbossindex[#ins.data.smbossindex+1] = id
                ins.data.smbossid[#ins.data.smbossid+1] = conf.bossId                
			end
		end
	end
end
table.insert(InitFnTable, initGlobalData)

_G.EnterShenmoBossArea = enterShenmoBossArea
_G.ExitShenmoBossArea = exitShenmoBossArea

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.fulshShenmo = function (actor, args)
	local id = tonumber(args[1])
	refreshBoss(nil, id)
	return true
end
