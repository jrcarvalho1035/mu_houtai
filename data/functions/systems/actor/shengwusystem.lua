--圣物系统
module("shengwusystem", package.seeall)

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.shengwu then var.shengwu = {} end
    for k,v in ipairs(ShengwuConfig) do
        if not var.shengwu[k] then var.shengwu[k] = {} end
        if not var.shengwu[k].level then var.shengwu[k].level = 0 end
        if not var.shengwu[k].fragment then var.shengwu[k].fragment = {} end
    end
    return var.shengwu
end

function updateAttr(actor, calc)
    local addAttrs = {}
	local var = getActorVar(actor)

    for i=1, #ShengwuConfig do
		if var[i].level ~= 0 then
			for k, attr in pairs(ShengwuConfig[i].attrs) do
				addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
			end
        end
        for k,v in ipairs(ShengwuConfig[i].needitem) do
            if var[i].fragment[k] and var[i].fragment[k] ~= 0 then                
                for kk, attr in ipairs(ShengwuFragmentConfig[v].attrs) do
                    addAttrs[attr.type] = (addAttrs[attr.type] or 0) + attr.value
                end
            end
        end
	end

	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Shengwu)
	attr:Reset()
    for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

--激活圣物
function activeShengwu(actor, pack)
    local id = LDataPack.readChar(pack)
    local conf = ShengwuConfig[id]
    if not conf then return end
    local var = getActorVar(actor)
    if var[id].level and var[id].level == 1 then return end
    
    for i=1, #ShengwuConfig[id].needitem do
        if not var[id].fragment or var[id].fragment[i] == 0 then
            return
        end
    end
    var[id].level = 1
    updateAttr(actor, true)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_ActiveShengwu)
    LDataPack.writeChar(npack, id)
    LDataPack.flush(npack)
    actorevent.onEvent(actor, aeShengwu, id)
end

--放入碎片
function putFragment(actor, pack)
    local id = LDataPack.readChar(pack)
    local index = LDataPack.readChar(pack)
    if not ShengwuConfig[id] then return end
    local fragmentid = ShengwuConfig[id].needitem[index + 1] 
    if not fragmentid then return end
    local conf = ShengwuFragmentConfig[fragmentid]
    local var = getActorVar(actor)
    if var[id].level and var[id].level == 1 then return end
    if var[id].fragment[index + 1] and var[id].fragment[index + 1] == 1 then return end
    if not actoritem.checkItems(actor, conf.needitem) then return end
    actoritem.reduceItems(actor, conf.needitem,  "shengwu put fragment")

    var[id].fragment[index + 1] = 1
    updateAttr(actor, true)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_PutFragment)
    LDataPack.writeChar(npack, id)
    LDataPack.writeChar(npack, index)
    LDataPack.flush(npack)
end

function sendTotalInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_ShengwuList)
    if not pack then return end
    local var = getActorVar(actor)    
    LDataPack.writeChar(pack, #ShengwuConfig)
    for k,v in ipairs(ShengwuConfig) do
        LDataPack.writeChar(pack, k)
        LDataPack.writeChar(pack, var[k].level or 0)
        for i=1, #v.needitem do
            LDataPack.writeChar(pack, var[k].fragment[i] or 0)
        end
    end
    LDataPack.flush(pack)    
end


function onLogin(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.touxian) then return end
    sendTotalInfo(actor)
end


function onInit(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.touxian) then return end
    updateAttr(actor)
end

function onCustomChange(actor, custom, oldcustom)
    if LimitConfig[actorexp.LimitTp.shengwu].custom > oldcustom and LimitConfig[actorexp.LimitTp.shengwu].custom <= custom then
        sendTotalInfo(actor)
    end
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)

local function init()
    --if System.isBattleSrv() then return end
    if System.isLianFuSrv() then return end
    actorevent.reg(aeCustomChange, onCustomChange)
    netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.cBagCmd_ActiveShengwu, activeShengwu)
    netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.cBagCmd_PutFragment, putFragment)
end

table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.shengwulAll = function (actor, args)
    local IsChange = false
    local var = getActorVar(actor)
    for id in pairs(ShengwuConfig) do
        for index in pairs(ShengwuFragmentConfig) do
            var[id].fragment[index] = 1
        end
        var[id].level = 1
        actorevent.onEvent(actor, aeShengwu, id)
    end
    updateAttr(actor, true)
    onLogin(actor)
end
