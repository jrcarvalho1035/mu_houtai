module("adventurepk", package.seeall)




function fight(actor, evConf)
    local hfuben = instancesystem.createFuBen(evConf.fbid)
    local x,y = utils.getSceneEnterCoor(evConf.fbid)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
end


function onEnterFuBen(ins, actor)
    local myPos = AdventureCommonConfig.myPos
	local role = LActor.getRole(actor)
	LActor.setEntityScenePos(role, myPos[1][1], myPos[1][2])
	local yongbing = LActor.getYongbing(actor)
	if yongbing then
		LActor.setEntityScenePos(yongbing, myPos[2][1], myPos[2][2])
	end

	LActor.ClearCD(actor)
	local touxian = touxiansystem.getTouxianStage(actor)
	local random = math.random(1, #AdventureRobotConfig[touxian])
	print("adventurepk onEnterFuBen touxian:", touxian, " robot id:", random)
	local conf = AdventureRobotConfig[touxian]
	local robotConf = conf[random]
	ins.data.dropId = robotConf.dropId -- 发奖励
	ins.data.actRewards = AdventureCommonConfig.actRewards

    local roleCloneData, actorData, roleSuperData = actorcommon.createRobotClone(conf, random)
    if roleSuperData then
		roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
		roleSuperData.aiId = FubenConstConfig.roleSuperAi
	end

	local tarPos = AdventureCommonConfig.tarPos
	local sceneHandle = ins.scene_list[1]
	local x = tarPos[1][1]
	local y = tarPos[1][2]
	local actorClone = LActor.createActorCloneWithData(random, sceneHandle, x, y, actorData, roleCloneData, roleSuperData)

	local roleClone = LActor.getRole(actorClone)
	if roleClone then
		local pos = tarPos[1]
		LActor.setEntityScenePos(roleClone, pos[1], pos[2])
	end
	local yongbing = LActor.getYongbing(actorClone)
	if yongbing then
		local pos = tarPos[2]
		LActor.setEntityScenePos(yongbing, pos[1], pos[2])
	end

	--定身
	LActor.addSkillEffect(actorClone, AdventureCommonConfig.bindEffectId)
	LActor.addSkillEffect(actor, AdventureCommonConfig.bindEffectId)
	instancesystem.s2cFightCountDown(actor, 5)
end

local function onActorDie(ins, actor)
	ins:lose()
end

local function onExitFb(ins, actor)
	-- ins:lose()
end

local function onActorCloneDie(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end
	ins:win()
end

local function onWin(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end
    adventure.onFbResult(ins, adventure.EVENT_5, true)
end

local function onLose(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end

    adventure.onFbResult(ins, adventure.EVENT_5, false)
end


local function fuBenInit()
    if System.isCrossWarSrv() then return end

    local fubenId = AdventureEventConfig[adventure.EVENT_5].fbid
    insevent.registerInstanceEnter(fubenId, onEnterFuBen)
    -- insevent.registerInstanceExit(fubenId, onExitFb)
    insevent.registerInstanceWin(fubenId, onWin)
    insevent.registerInstanceLose(fubenId, onLose)
    insevent.registerInstanceActorDie(fubenId, onActorDie)
    insevent.regActorCloneDie(fubenId, onActorCloneDie)
end
table.insert(InitFnTable, fuBenInit)
