module("insevent", package.seeall)


local insWinCallBack = {}
local insLoseCallBack = {}
local insInitCallBack = {}

local insEnterBeforeCallBack = {}
local insEnterCallBack = {}
local insExitCallBack = {}
local insOfflineCallBack = {}

local insActorDieCallBack = {}
local insMonsterDieCallBack = {}
local insMonsterAllDieCallBack = {}

local insMonDamCallBack = {}
local insMonCreateCallBack = {}
local insSpecialVariantCallBack = {}
local insGetRewardsCallBack = {}
local insMonAiResetCallBack = {}

local insActorCloneDie = {}
local insCloneRoleDie = {}
local insRoleCloneDamCallBack = {}
local insShieldOutputCallBack = {}
local insRealDamageCallBack = {}
local insFubenShieldUpdate = {}

local insCustomFunc = {}

local insRoleDie = {}
local insPickItemCallBack = {}

local insGatherMonsterCreate = {}
local insGatherMonsterCheck = {}
local insGatherMonsterUpdate = {}

local insEnerBossAreaCallBack = {}
local insExitBossAreaCallBack = {}

local function regFbEvent(tbl, fbId, func)
	if fbId == nil then
		print("register ins event failed. fbId is nil")
		print( debug.traceback() )
		return
	end
	if tbl[fbId] == nil then tbl[fbId] = {} end
	if tbl[fbId][func] ~= nil then
		if tbl[fbId][func] == 1 then
			error( "function has registed for id:"..fbId )

			-- print( "不同难度的副本不要用相同id。")
		end
		tbl[fbId][func] = tbl[fbId][func] + 1
	else
		tbl[fbId][func] = 1
	end
end

-- 注册回调
function registerInstanceWin(fbId, func)
	regFbEvent(insWinCallBack, fbId, func)
end

function registerInstanceLose(fbId, func)
	regFbEvent(insLoseCallBack, fbId, func)
end

function registerInstanceInit(fbId, func)
	regFbEvent(insInitCallBack, fbId, func)
end

--func(ins, actor)
function registerInstanceEnterBefore(fbId, func) --actor enter instance
	regFbEvent(insEnterBeforeCallBack, fbId, func)
end

--func(ins, actor)
function registerInstanceEnter(fbId, func) --actor enter instance
	regFbEvent(insEnterCallBack, fbId, func)
end

function registerInstanceExit(fbId, func)
	regFbEvent(insExitCallBack, fbId, func) --actor exit
end
--下线/掉线回调 是否需要？
function registerInstanceOffline(fbId, func) --actor leave instance
	regFbEvent(insOfflineCallBack, fbId, func)
end

function registerInstanceMonsterDie(fbId, func)
	regFbEvent(insMonsterDieCallBack, fbId, func)
end
function registerInstanceMonsterAllDie(fbId, func)
	regFbEvent(insMonsterAllDieCallBack, fbId, func)
end
--func(ins, actor, killerHdl)
function registerInstanceActorDie(fbId, func)
	regFbEvent(insActorDieCallBack, fbId, func)
end

--func(ins, monster, value, attacker)
function registerInstanceMonsterDamage(fbId, func)
	System.regInstanceMonsterDamage(fbId)
	regFbEvent(insMonDamCallBack, fbId, func)
end
--func(ins, monster)
function registerInstanceMonsterCreate(fbId, func)
	regFbEvent(insMonCreateCallBack, fbId, func)
end
--func(ins, name, value)
function registerInstanceSpecialVariant(fbId, func)
	regFbEvent(insSpecialVariantCallBack, fbId, func)
end
--func(ins, actor)
function registerInstanceGetRewards(fbId, func)
	regFbEvent(insGetRewardsCallBack, fbId, func)
end

function regActorCloneDie(fbId,func)
	regFbEvent(insActorCloneDie,fbId,func)
end

function regCloneRoleDie(fbId,func)
	regFbEvent(insCloneRoleDie,fbId,func)
end

function registerInstanceRoleCloneDamage(fbId, func)
	System.regInstanceRoleCloneDamage(fbId)
	regFbEvent(insRoleCloneDamCallBack, fbId, func)
end

function registerInstanceShieldOutput(fbId, func)
	regFbEvent(insShieldOutputCallBack, fbId, func)
end

function registerInstanceRealDamage(fbId, func)
	regFbEvent(insRealDamageCallBack, fbId, func)
end

function registerInstanceFubenShieldUpdate( fbId, func )
	regFbEvent(insFubenShieldUpdate, fbId, func)
end

function regRoleDie(fbId, func)
	regFbEvent(insRoleDie, fbId, func)
end

function registerInstancePickItem(fbId, func)
	regFbEvent(insPickItemCallBack, fbId, func)
end

function registerInstanceGatherMonsterCreate(fbId, func)
	regFbEvent(insGatherMonsterCreate, fbId, func)
end

function registerInstanceGatherMonsterCheck(fbId, func)
	regFbEvent(insGatherMonsterCheck, fbId, func)
end

function registerInstanceGatherMonsterUpdate( fbId, func )
	regFbEvent(insGatherMonsterUpdate, fbId, func)
end

function registerInstanceMonsterAiReset(fbId, func)
	regFbEvent(insMonAiResetCallBack, fbId, func)
end

function registerInstanceEnerBossArea(fbId, func)
	regFbEvent(insEnerBossAreaCallBack, fbId, func)
end

function registerInstanceExitBossArea(fbId, func)
	regFbEvent(insExitBossAreaCallBack, fbId, func)
end

local function call(funcs, ins, ...)
	if funcs[ins.id] ~= nil then
		local ret
		for func,_ in pairs(funcs[ins.id]) do
			ret = func(ins, ...) and ret
		end
		return ret
	end
end

function onWin(ins)
	--结束之前的处理
	call(insWinCallBack, ins)
	--通关事件
	local actors = ins:getActorList()
	for _, actor in ipairs(actors) do
		actorevent.onEvent(actor, aeFinishFuben, ins:getFid(), ins:getType())
	end
end

function onLose(ins)
	call(insLoseCallBack, ins)
end

function onInitFuben(ins)
	call(insInitCallBack, ins)
end

function onEnterBefore(ins, actor, isLogin)
	call(insEnterBeforeCallBack, ins, actor, isLogin)
end

function onEnter(ins, actor, isLogin, isCw)
	print("onEnter event fid:"..tostring(ins:getFid()).." aid:".. tostring(LActor.getActorId(actor)))
	call(insEnterCallBack, ins, actor, isLogin, isCw)

	actorevent.onEvent(actor, aeEnterFuben, ins:getFid(), isLogin, isCw)
end

function onExit(ins, actor)
	print("onExit event fid:"..tostring(ins:getFid()).." aid:".. tostring(LActor.getActorId(actor)))
	call(insExitCallBack, ins, actor)
	--自动退队
	--LActor.exitTeam(actor)
end

function onOffline(ins, actor)
	print("onOffline event fid:"..tostring(ins:getFid()).." aid:".. tostring(LActor.getActorId(actor)))
	call(insOfflineCallBack, ins, actor)
end

function onMonsterDie(ins, mon, killerHdl)
	call(insMonsterDieCallBack, ins, mon, killerHdl)
end

function onMonsterAllDie(ins, mon, actor)
	call(insMonsterAllDieCallBack, ins, mon, actor)
end

function onActorDie(ins, actor, killerHdl, killActorId, killHpper)
	call(insActorDieCallBack, ins, actor, killerHdl, killActorId, killHpper)
end

function onMonsterDamage(ins, monster, value, attacker, ret)
	local res = {ret=ret}
	call(insMonDamCallBack, ins, monster, value, attacker, res)
	return res.ret
end

function onMonsterCreate(ins, monster)
	call(insMonCreateCallBack, ins, monster)
end

function onVariantChange(ins, name, value)
	call(insSpecialVariantCallBack, ins, name, value)
end

function onGetRewards(ins, actor)
	call(insGetRewardsCallBack, ins, actor)
end

function onActorCloneDie(ins, killerHdl, actorClone)
	call(insActorCloneDie,ins, killerHdl, actorClone)
end

function onCloneRoleDie(ins)
	call(insCloneRoleDie,ins)
end

function onRoleCloneDamage(ins, monster, value, attacker, ret)
	local res = {ret=ret}
	call(insRoleCloneDamCallBack, ins, monster, value, attacker, res)
	return res.ret
end

function onShieldOutput(ins, monster, value, attacker, ret)
	local res = {ret=ret}
	call(insShieldOutputCallBack, ins, monster, value, attacker, res)
	return res.ret
end

function onRealDamage(ins, monster, value, attacker)
	call(insRealDamageCallBack, ins, monster, value, attacker)
end

function onFubenShieldUpdate(ins, et, effectId, value)
	call(insFubenShieldUpdate, ins, et, effectId, value)
end

function onRoleDie(ins,role,killer_hdl)
	call(insRoleDie,ins,role,killer_hdl)
end

function onPickItem(ins, actor, tp, id, count)
	call(insPickItemCallBack, ins, actor, tp, id, count)
end

function onGatherMonsterCreate(ins, gatherMonster)
	call(insGatherMonsterCreate, ins, gatherMonster)
end

function onGatherMonsterCheck(ins, gatherMonster, actor)
	call(insGatherMonsterCheck, ins, gatherMonster, actor)
end

function onGatherMonsterUpdate( ins, gatherMonster, actor )
	call(insGatherMonsterUpdate, ins, gatherMonster, actor)
end

function onMonsterAiReset(ins, monster)
	call(insMonAiResetCallBack, ins, monster)
end

function onEnerBossArea(ins, actor, bossId)
	call(insEnerBossAreaCallBack, ins, actor, bossId)
end

function onExitBossArea(ins, actor, bossId)
	call(insExitBossAreaCallBack, ins, actor, bossId)
end


--********************************************************************************--
--注册用户自定义函数
--********************************************************************************--
function regCustomFunc(fbId, func, name)
  if insCustomFunc[fbId] == nil then insCustomFunc[fbId] = {} end
  if insCustomFunc[fbId][name] ~= nil then
		--print("该函数名已经注册了")
		return
  else
		--print(fbId.."注册函数:"..name)
		insCustomFunc[fbId][name] = func
  end
end

--********************************************************************************--
--调用用户自定义函数
--********************************************************************************--
function callCustomFunc(ins, name)
  if not insCustomFunc[ins.id] or not insCustomFunc[ins.id][name] then
	print("fb:"..ins.id.." can't find func:"..name)
	return
  end
  return insCustomFunc[ins.id][name](ins)
end
