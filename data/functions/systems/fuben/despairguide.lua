-- @version	1.0
-- @author	qianmeng
-- @date	2018-5-7 17:26:58.
-- @system	despairguide

module("despairguide", package.seeall)

local function getDyanmicVar(actor)
	local var = LActor.getGlobalDyanmicVar(actor)
	if not var.despairguideData then
		var.despairguideData = {
			damage = {},
		}
	end
	return var.despairguideData
end

local function finishFuben(actor)
	local actorId = LActor.getActorId(actor)
	local var = getDyanmicVar(actor)
	var.clonecount = 0
	local reward = drop.dropGroup(DespairBossCommonConfig.juqingdrop)
	local fbId = DespairBossCommonConfig.guideFuben
	local name = LActor.getActorName(actorId)
	local lv = LActor.getActorLevel(actorId)
	despairboss.s2cGiveReward(fbId, DespairBossConfig[1], actorId, name, lv, 1, reward, reward, var.damageList[LActor.getActorId(actor)])
	if var.eid then
		LActor.cancelScriptEvent(actor,var.eid)
	end
	actorevent.onEvent(actor,aeDespairBoss, DespairBossConfig[1].bossId, 1)
end

function onTimer(actor)
	local now_t = System.getNowTime()
	local conf = DespairBossConfig[1]
	local var = getDyanmicVar(actor)
	
	if var.clonecount >= DespairBossCommonConfig.matchmax then
		return
	end
	--定时刷机器人
	if (var.robotRefreshTimer or 0) > now_t then
		return
	end
	var.robotRefreshTimer = now_t + math.random(DespairBossCommonConfig.matchtime[1], DespairBossCommonConfig.matchtime[2])

	local robot = 0
	for i=1, #DespairRobotConfig do		
		robot = math.random(1, #DespairRobotConfig)
		if not var.damageList[robot] then
			break
		end
	end
	if robot == 0 then
		return
	end
	local roleCloneData, actorData, roleSuperData = actorcommon.createRobotClone(DespairRobotConfig, robot)

	--机器人属性是玩家属性的百分比
	local roleAttr = LActor.getRoleAttrsCache(actor)
	roleCloneData.attrs:Reset()
	for j = Attribute.atHp, Attribute.atCount - 1 do
		if j == Attribute.atShenYouShieldTagNum then
		elseif j ~= Attribute.atMvSpeed then
			roleCloneData.attrs:Set(j, roleAttr[j] * DespairBossCommonConfig.robotpercent)
		else
			roleCloneData.attrs:Set(j, roleAttr[j])
		end
	end

	if roleSuperData then 
		roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1],FubenConstConfig.randChangeTime[2])
		roleSuperData.aiId = FubenConstConfig.roleSuperAi
	end

	local ins = instancesystem.getActorIns(actor)
	local x,y = utils.getSceneEnterCoor(DespairBossCommonConfig.guideFuben)
	local actorClone = LActor.createActorCloneWithData(robot, ins.scene_list[1], x, y, actorData, roleCloneData, roleSuperData)
	var.clonecount = (var.clonecount or 0) + 1

	--local boss = Fuben.getSceneMonsterById(scene, conf.bossId)
	--LActor.setAITarget(actorClone, boss)
	LActor.setCamp(actorClone, CampType_Normal)--设置阵营为普通模式
end


--绝望BOSS引导副本挑战
function fightDespairGuide(actor)
	if not utils.checkFuben(actor, DespairBossCommonConfig.guideFuben) then return end

	local hfuben = instancesystem.createFuBen(DespairBossCommonConfig.guideFuben)
	if hfuben == 0 then return end

	local var = getDyanmicVar(actor)
	var.damageList = {}
	var.hfuben = hfuben
	var.clonecount = 0
	var.shield = 0
	var.curShield = nil
	var.nextShield = despairboss.getNextShield(1)

	local x,y = utils.getSceneEnterCoor(DespairBossCommonConfig.guideFuben)
	LActor.enterFuBen(actor, hfuben, 0, x, y)

	var.eid = LActor.postScriptEventEx(actor, 1000, function(actor) onTimer(actor) end, 5000, -1, actor)
end

local function onBossDie(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end
	local var = getDyanmicVar(actor)
	var.damageList[LActor.getActorId(actor)] = var.damageList[LActor.getActorId(actor)] or 0
	finishFuben(actor)	
end

--记录对BOSS的伤害
local function onBossDamage(ins, monster, value, attacker, res)
	local actors = Fuben.getAllActor(ins.handle)
	if not actors then return end
	local actor = actors[1]
	local var = getDyanmicVar(actor)	

	local oldhp = LActor.getHp(monster)
	if oldhp <= 0 then return end

	local hp = oldhp - value
	if hp < 0 then hp = 0 end

	hp = hp / LActor.getHpMax(monster) * 100	
	--更新伤害信息	
	local actorId = LActor.getEntityActorId(attacker)
	if actorId == -1 then return end
	var.damageList[actorId] = (var.damageList[actorId] or 0) + value

	var.monster = monster --记录BOSS实体

	--护盾判断
	if 0 == var.shield then --现在没有护盾
		if var.nextShield and 0 ~= var.nextShield.hp and hp < var.nextShield.hp then --从预备护盾里取护盾
			var.curShield = var.nextShield
			var.nextShield = despairboss.getNextShield(ins.data.pbossid, var.curShield.hp) --再取下一个预备护盾
			
			res.ret = math.floor(LActor.getHpMax(monster) * var.curShield.hp / 100) --避免一招秒而不触发护盾，这里要恢复血量
			var.hpPercent = var.curShield.hp --要把血量设置回原值
			LActor.setInvincible(monster, var.curShield.shield*1000) --设无敌状态
			var.shield = var.curShield.shield + System.getNowTime()
			instancesystem.s2cShieldInfo(var.hfuben, 1, var.curShield.shield, var.curShield.shield)
			--注册护盾结束定时器
			var.shieldEid = LActor.postScriptEventLite(nil, var.curShield.shield*1000, finishShield, var)
			noticesystem.fubenCastNotice(var.hfuben, noticesystem.NTP.homeShield)
		end
	end
end

local function onEnterFb(ins, actor)
	LActor.setCamp(actor, CampType_Normal)--设置阵营为普通模式
end

--护盾结束
function finishShield(_, bossData)
	bossData.shield = 0
	instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, bossData.curShield.shield)
end

local function onExitFb(ins, actor)
	if not ins.is_win then
		local var = getDyanmicVar(actor)
		var.damageList[LActor.getActorId(actor)] = var.damageList[LActor.getActorId(actor)] or 0
		finishFuben(actor)
	end
	despairboss.changeCd(actor)
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end

-------------------------------------------------------------------------------------------------------
local function init()
	if System.isCrossWarSrv() then return end
	--注册事件
	local fbId = DespairBossCommonConfig.guideFuben
	insevent.registerInstanceEnter(fbId, onEnterFb)
	insevent.registerInstanceWin(fbId, onBossDie)
	insevent.registerInstanceExit(fbId, onExitFb)
	insevent.registerInstanceMonsterDamage(fbId, onBossDamage)
	insevent.registerInstanceOffline(fbId, onOffline)
end
table.insert(InitFnTable, init)
