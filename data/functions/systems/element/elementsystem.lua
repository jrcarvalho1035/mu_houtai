-- @system	符文系统

module( "elementsystem", package.seeall )


-- element = {
-- 	lib = 1, --当前的库
--  good = 0, --是否有买过库
-- }

local ELEMENT_GRID = 8 --元素格子数

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.element then 
		var.element = {}
		for i=0, ELEMENT_GRID -1 do
			var.element[i] = 0
		end
	end
	return var.element	
end

local function getDyanmicVar(actor)
	local var = LActor.getGlobalDyanmicVar(actor)
	if not var.element then
		var.element = {
			totalCount = 0,
			totalLevel = 0,
		}
	end
	return var.element
end

function getPower(actor)
	local var = getActorVar(actor)
	if not var then return 0 end
	local power = 0	
	power = power + (var.powers[0] or 0)	
	return power
end

function updateAttr(actor, calc)
    local addAttrs = {}
	local var = getActorVar(actor)

	for i=0, ELEMENT_GRID - 1 do
		if var[i] ~= 0 then		
			for kk, attr in pairs(ElementLevelConfig[var[i]].attr) do
				addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
			end
        end
	end
	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Element)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

--随机元素奖励
local function getRankElement(rewards)
	local weight = 0 --总权值
	for k, v in pairs(rewards) do
		weight = weight + v[2]
	end

	local num = math.random(1, weight)
	local count = 0
	for k, v in ipairs(rewards) do
		count = count + v[2]
		if count >= num then
			return v[1]
		end
	end
	return 0
end

--库升降判断
local function getRankLib(prob)
	local num = math.random(1, 100)
	local count = 0
	for k, v in ipairs(prob) do
		count = count + v
		if count >= num then
			return k
		end
	end
	return 0
end

local function elementRefine(actor)
	local var = getActorVar(actor)
	local conf = ElementLibraryConfig[var.lib or 1]
	if conf then
		if not actoritem.checkItem(actor, NumericType_Powder, conf.huntOnce) then
			return 0
		end
		actoritem.reduceItem(actor, NumericType_Powder, conf.huntOnce, "element Refine")

		local rewards = (var.good or 0) > 0 and conf.goodrew or conf.rewards --凭是否购买库判断使用哪个库
		local id = getRankElement(rewards)
		if ElementBaseConfig[id].quality == 0 then --白色品质的元素直接化为精华
			local num = ElementLevelConfig[ElementBaseConfig[id].soleid].clearGain
			actoritem.addItem(actor, NumericType_Cream, num, "element refine")
		else
			actoritem.addItem(actor, ElementBaseConfig[id].soleid, 1, "element Refine add") --生成元素
			actorevent.onEvent(actor, aeElementCreate, ElementBaseConfig[id].quality)
		end

		local pro = (var.good or 0) > 0 and conf.goodpro or conf.prob
		local idx = getRankLib(pro) --库的升降控制
		if idx == 2 then --升库时每次升1级
			var.lib = (var.lib or 1) + 1
		elseif idx == 3 then --掉库时掉到最低
			var.lib = 1
		end
		if not ElementLibraryConfig[var.lib or 1] then --预防溢出
			var.lib = next(ElementLibraryConfig)
		end
		if idx ~= 2 then --在买库且库在上升的状态下，金主状态不会消失
			var.good = 0
		end
		actorevent.onEvent(actor, aeElemenDraw)
		utils.logCounter(actor, "element refine", id, var.lib or 1)
		return id
	end
	return 0
end

function getElementCount(actor)
	local var = getActorVar(actor)
	local count = 0
	for i=0, ELEMENT_GRID - 1 do
		if var[i] and var[i] > 0 then
			count = count + 1
		end
	end

	return count
end

--20等级的橙色符文有X个
function getElementLevelCount(actor)
	local var = getActorVar(actor)
	local count = 0
	for i=0, ELEMENT_GRID - 1 do
		if var[i] ~= 0 and ElementBaseConfig[ElementLevelConfig[var[i]].id].quality >= 4 and ElementLevelConfig[var[i]].level >= 20 then
			count = count + 1
		end
	end

	return count
end

function getElementTotalLevel(actor)
	local var = getActorVar(actor)
	local total = 0
	for i=0, ELEMENT_GRID - 1 do
		if var[i] ~= 0 then
			total = total + ElementLevelConfig[var[i]].level 	
		end
	end
	return total
end

------------------------------------------------------------------------------------------------------
--佩戴元素升级
function c2sElementCulture(actor, packet)
	if not actorexp.checkLevelCondition(actor,actorexp.LimitTp.element) then return end
	local slot = LDataPack.readChar(packet)
	if slot < 0 and slot >= ELEMENT_GRID then return end
	local var = getActorVar(actor)
	if not ElementLevelConfig[var[slot] + 1] then return end
	local num = ElementLevelConfig[var[slot]].upLevelConsu
	if not actoritem.checkItem(actor, NumericType_Cream, num) then return end
	actoritem.reduceItem(actor, NumericType_Cream, num, "element up level:")

	var[slot] = var[slot] + 1

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Element, Protocol.sElementCmd_Culture)
	if not pack then return end
	LDataPack.writeChar(pack, slot)
	LDataPack.writeInt(pack, var[slot])
	LDataPack.flush(pack)

	updateAttr(actor, true)
	actorevent.onEvent(actor, aeElementLevel, var[slot])
	--utils.logCounter(actor, "element culture", id, level+1)
end

--背包元素分解
function c2sElementDevour(actor, packet)
	local foods = {}  --被分解的元素
	local count = LDataPack.readInt(packet)
	local sum = 0 --吞噬的元素所提供的精华
	for i=1, count do
		local elementid = LDataPack.readInt(packet)
		if not ElementLevelConfig[elementid] then return end
		if not actoritem.checkItem(actor, elementid, 1) then
			break
		end
		sum = sum + ElementLevelConfig[elementid].clearGain
		actoritem.reduceItem(actor, elementid, 1, "devour element")
	end 
	
	actoritem.addItem(actor, NumericType_Cream, sum, "element devour")
end

--抽取元素
function c2sElementRefine(actor, packet)
	local times = LDataPack.readInt(packet)
	if times <= 0 then return end

	local space = LActor.getElementBagSpace(actor)
	if space < times then return end --空间不足时不抽元素

	local rets = {}
	for i=1, times do
		local id = elementRefine(actor) --抽取
		if ElementBaseConfig[id] then
			table.insert(rets, id)
		end
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Element, Protocol.sElementCmd_Refine)
	if not pack then return end
	LDataPack.writeChar(pack, #rets)
	for k, v in ipairs(rets) do
		LDataPack.writeInt(pack, ElementBaseConfig[v].soleid)
	end
	LDataPack.flush(pack)

	s2cElementLibUpdate(actor, 1)
end

--买元素库
function c2sElementBuyLib(actor, packet)
	local id = LDataPack.readChar(packet)
	local conf = ElementLibraryConfig[id]
	if not conf then return end
	local var = getActorVar(actor)
	if (var.lib or 1) >= id then
		return
	end
	if conf.cost <= 0 then return end --不能买这个库
	if not actoritem.checkItem(actor, NumericType_YuanBao, conf.cost) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, conf.cost, "element buy lib")
	var.lib = id
	var.good = 1

	s2cElementLibUpdate(actor, 2)
end

--元素库更新
function s2cElementLibUpdate(actor, tp)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Element, Protocol.sElementCmd_BuyLib)
	if not pack then return end
	LDataPack.writeInt(pack, var.lib or 1)
	LDataPack.writeInt(pack, tp)
	LDataPack.flush(pack)
end

--元素佩戴
function c2sElementAdorn(actor, packet)
	if not actorexp.checkLevelCondition(actor,actorexp.LimitTp.element) then return end
	local slot = LDataPack.readChar(packet)
	if slot < 0 or slot >= ELEMENT_GRID then return end	
	local elementid = LDataPack.readInt(packet)
	if not ElementLevelConfig[elementid] then return end
	if not actoritem.checkItem(actor, elementid, 1) then return end
	local var = getActorVar(actor)
	for i=0, ELEMENT_GRID - 1 do
		if var[i] ~= 0 and i ~= slot and ElementBaseConfig[math.floor(var[i]/1000)].type == ElementBaseConfig[math.floor(elementid/1000)].type then
			return
		end
	end
	if var[slot] ~= 0 then
		if LActor.getElementBagSpace(actor) < 1 then--符文背包空间不足
			LActor.sendTipmsg(actor, string.format(ScriptTips.bag01), ttScreenCenter)
			return 
		else
			actoritem.addItem(actor, var[slot], 1, "element put")
		end
	end
	actoritem.reduceItem(actor, elementid, 1, "element put")
	var[slot] = elementid

	updateAttr(actor, true)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Element, Protocol.sElementCmd_Adorn)
	if not pack then return end
	LDataPack.writeChar(pack, slot)
	LDataPack.writeInt(pack, var[slot])
	LDataPack.flush(pack)
	actorevent.onEvent(actor, aeElementEquip, ElementBaseConfig[ElementLevelConfig[var[slot]].id].quality, 1)
end

--元素卸下
function c2sElementUnadorn(actor, packet)
	if not actorexp.checkLevelCondition(actor,actorexp.LimitTp.element) then return end
	local slot = LDataPack.readChar(packet)
	if slot < 0 or slot >= ELEMENT_GRID then return end
	local var = getActorVar(actor)
	if var[slot] == 0 then return end
	if LActor.getElementBagSpace(actor) < 1 then--符文背包空间不足
		LActor.sendTipmsg(actor, string.format(ScriptTips.bag01), ttScreenCenter)
		return 
	end
	actoritem.addItem(actor, var[slot], 1, "element")
	local before = var[slot]
	var[slot] = 0
	updateAttr(actor, true)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Element, Protocol.sElementCmd_Unadorn)
	if not pack then return end
	LDataPack.writeChar(pack, slot)
	LDataPack.writeInt(pack, before)
	LDataPack.flush(pack)
	--actorevent.onEvent(actor, aeElementEquip, ElementBaseConfig[eIds[slot+1]].quality, -1)
end

--身上装备的元素
function s2cEquipElement(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Element, Protocol.sElementCmd_EquipElement)
	if not pack then return end
	local var = getActorVar(actor)
	LDataPack.writeChar(pack, ELEMENT_GRID)
	for i=0, ELEMENT_GRID - 1 do
		LDataPack.writeInt(pack, var[i])
	end
	LDataPack.flush(pack)
end

function onLogin(actor)
	s2cEquipElement(actor)
	s2cElementLibUpdate(actor, 1)
end

function onInit(actor)
	updateAttr(actor, false)
end


local function init()
	--if System.isBattleSrv() then return end
	if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Element, Protocol.cElementCmd_Culture, c2sElementCulture)
	netmsgdispatcher.reg(Protocol.CMD_Element, Protocol.cElementCmd_Devour, c2sElementDevour)
	netmsgdispatcher.reg(Protocol.CMD_Element, Protocol.cElementCmd_Refine, c2sElementRefine)
	netmsgdispatcher.reg(Protocol.CMD_Element, Protocol.cElementCmd_BuyLib, c2sElementBuyLib)
	netmsgdispatcher.reg(Protocol.CMD_Element, Protocol.cElementCmd_Adorn, c2sElementAdorn)
	netmsgdispatcher.reg(Protocol.CMD_Element, Protocol.cElementCmd_Unadorn, c2sElementUnadorn)
	
end

table.insert(InitFnTable, init)

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.elementRefine = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sElementRefine(actor, pack)
	return true
end

gmCmdHandlers.elementTest = function (actor, args)
	updateAttr(actor, 0)
	return true
end

gmCmdHandlers.elementbuylib = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sElementBuyLib(actor, pack)
	return true
end

gmCmdHandlers.elementAll = function (actor, args)
    local var = getActorVar(actor)
    local tab_1 = {}
    for element, conf in pairs(ElementBaseConfig) do
        if not tab_1[conf.type] then
            tab_1[conf.type] = {
                id = element,
                quality = conf.quality
            }
        end
        if conf.quality > tab_1[conf.type].quality then
            tab_1[conf.type].id = element
            tab_1[conf.type].quality = conf.quality
        end
    end
    local tab_2 = {}
    for k, v in pairs(tab_1) do
        tab_2[v.id] = 1
    end
    local tab_3 = {}
    for element, conf in pairs(ElementLevelConfig) do
        repeat
            if not tab_2[conf.id] then
                break
            end
            if not tab_3[conf.id] then
                tab_3[conf.id] = {
                    id = element,
                    level = conf.level
                }
            end
            if conf.level > tab_3[conf.id].level then
                tab_3[conf.id].id = element
                tab_3[conf.id].level = conf.level
            end
            
        until true
    end
    
    local tab_4 = {}
    for k, v in pairs(tab_3) do
        tab_4[#tab_4 + 1] = v.id
    end
    for slot in pairs(ElementLockPosConfig) do
        local maxElement = tab_4[slot + 1] or 0
        var[slot] = maxElement
        actorevent.onEvent(actor, aeElementEquip, ElementBaseConfig[ElementLevelConfig[var[slot]].id].quality, 1)
        actorevent.onEvent(actor, aeElementLevel, var[slot])
    end
    updateAttr(actor, true)
    onLogin(actor)
end

gmCmdHandlers.elementclear = function (actor, args)
    local var = LActor.getStaticVar(actor)
    var.element = nil
    return true
end

