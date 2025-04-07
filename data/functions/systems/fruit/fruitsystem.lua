-- @system	果实系统

module("fruitsystem", package.seeall)

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor) --在init时与登录后var的取值居然是不一样的
	if not var then return end
	if not var.fruit then var.fruit = {} end
	if not var.fruit.usecount then var.fruit.usecount = {} end
	if not var.fruit.dailyuse then var.fruit.dailyuse = {} end
	return var.fruit
end


--更新属性
function updateAttr(actor, calc)
	local addAttrs = {}
	local var = getActorVar(actor)
	if not var then	return end
	for k, v in pairs(FruitConfig) do
		if (var.usecount[k] or 0) > 0 then
			for k2, v2 in pairs(v.attrs) do
				addAttrs[v2.type] = (addAttrs[v2.type] or 0) + v2.value*var.usecount[k]
			end
		end
	end

	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Fruit)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end


function onInit(actor)
	updateAttr(actor, false)
end

function onLogin(actor)
	s2cFruitInfo(actor)
end

local function onNewDay(actor, login)
	local var = getActorVar(actor)
	var.dailyuse = {}
	if not login then
		s2cFruitInfo(actor)
	end
end


function getEatMax(actor, conf)
	local level = LActor.getLevel(actor)
	local num = 0
	for k, v in pairs(conf.maxEat) do
		if level >= k and num < v then
			num = v
		end
	end
	return num
end

----------------------------------------------------------------------------------------------
function updateFruitInfo(actor, fruittype)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Fruit, Protocol.sFruitCmd_Update)
	LDataPack.writeChar(pack, fruittype)
	LDataPack.writeShort(pack, var.dailyuse[fruittype] or 0)
	LDataPack.writeChar(pack, #FruitTypeConfig[fruittype].fruitIds)
	for kk,vv in ipairs(FruitTypeConfig[fruittype].fruitIds) do
		LDataPack.writeInt(pack, vv)
		LDataPack.writeInt(pack, var.usecount[vv] or 0)
	end
	LDataPack.flush(pack)
end

function s2cFruitInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Fruit, Protocol.sFruitCmd_Info)
	if pack == nil then return end
	local var = getActorVar(actor)
	LDataPack.writeChar(pack, #FruitTypeConfig)
	for k,v in ipairs(FruitTypeConfig) do
		LDataPack.writeChar(pack, k)
		LDataPack.writeShort(pack, var.dailyuse[k] or 0)
		LDataPack.writeChar(pack, #v.fruitIds)
		for kk,vv in ipairs(v.fruitIds) do
			LDataPack.writeInt(pack, vv)
			LDataPack.writeInt(pack, var.usecount[vv] or 0)
		end		
	end
	LDataPack.flush(pack)
end

--吃果实
function c2sFruitEatAll(actor, packet)	
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.fruit) then return end
	local fruittype = LDataPack.readChar(packet)
	local var = getActorVar(actor)

	for i=#FruitTypeConfig[fruittype].fruitIds, 1, -1 do
		repeat
			local id = FruitTypeConfig[fruittype].fruitIds[i]
			local cnt = actoritem.getItemCount(actor, id)
			if cnt <= 0 then 
				break 
			end

			local mId = utils.matchingLevel(actor, FruitConfig[id].maxEat)
			cnt = math.min(cnt, FruitConfig[id].maxEat[mId] - (var.usecount[id] or 0))
			if cnt <= 0 then
				break
			end
			actoritem.reduceItem(actor, id, cnt, "eat fruit")
			var.usecount[id] = (var.usecount[id] or 0) + cnt
			var.dailyuse[fruittype] = (var.dailyuse[fruittype] or 0) + cnt
			actorevent.onEvent(actor, aeFruitEat, id, cnt)
		until(true)
	end

	updateAttr(actor, true)
	updateFruitInfo(actor, fruittype)	
end

local function init()
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeUserLogin, onLogin)

	if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Fruit, Protocol.cFruitCmd_EatAll, c2sFruitEatAll)
end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.fruit = function (actor, args)
	local var = getActorVar(actor, 0)		
	for k, v in pairs(FruitConfig) do
		local mId = utils.matchingLevel(actor, v.maxEat)
		var[k] = v.maxEat[mId]
	end
end

gmCmdHandlers.fruitAll = function (actor, args)
    local var = getActorVar(actor)
    for id, conf in pairs(FruitConfig) do
        local mId = utils.matchingLevel(actor, conf.maxEat)
        local max = FruitConfig[id].maxEat[mId]
        var.usecount[id] = max
        actorevent.onEvent(actor, aeFruitEat, id, max)
    end
    updateAttr(actor, true)
    onLogin(actor)
end
