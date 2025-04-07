--怪物掉落
module("monsterdrop", package.seeall)

local MonstersConfig = MonstersConfig

function getRandomNumber(min, max)
    return math.random(min, max)
end

--怪物死亡，产生掉落
function onMonsterDie(ins, mon, killerHdl)
    if not ins or not mon or not killerHdl then return end
    if ins.is_end then return end --已经结束的副本领不了奖励
    
    local monId = LActor.getId(mon)
    
    local actor = LActor.getActor(LActor.getEntity(killerHdl))
    if not actor or not MonstersConfig[monId] then return end
    
    local actorId = LActor.getActorId(actor)
    
    if MonstersConfig[monId].exp > 0 then
        local addper = actorcommon.getDropExpRate(actor) + (1 * getRandomNumber(1, 10)) + actorexp.getWLExpPer(actor)
        local exp = math.floor(MonstersConfig[monId].exp * addper)
        LActor.addExp(actor, exp, "drop_"..monId, true, false, 1, addper)
        ins:addPickExp(actorId, exp)
    end
    
    local moneyRate = actorcommon.getDropGoldRate(actor) + 1
    local result = randomDropResult(monId, moneyRate, actor)
    
    if #result > 0 then
        local monPosX, monPosY = LActor.getEntityScenePoint(mon)
        ins:addDropBagItem(actor, result, 100, monPosX, monPosY)
    end
end

--随机掉落
function randomDropResult(monId, moneyRate, actor)
    local config = MonstersConfig[monId]
    
    if not moneyRate then moneyRate = 1 end
    if moneyRate >= 10 then moneyRate = 10 end
    
    local result = {}
    if config.drop ~= 0 then
        for k, v in ipairs(drop.dropGroup(config.drop)) do
            if v.id == NumericType_Gold then
                table.insert(result, {type = v.type, id = v.id, count = v.count * moneyRate})
            else
                table.insert(result, {type = v.type, id = v.id, count = v.count})
            end
        end
    end
    return result
end

--通过怪物数量来计算掉落的物品（怪物数量足够大时用）
function addDropItems(dropItems, monId, count, moneyRate, isFast)
    local config = MonstersConfig[monId]
    moneyRate = moneyRate or 1
    if config.drop ~= 0 then
        for _, v in ipairs(DropGroupConfig[config.drop].group) do
            for __, conf in ipairs(DropTableConfig[v.id].rewards) do
                repeat
                    local icount, fcount = math.modf(conf.count * v.rate / 100 * conf.rate / 100 * count)
                    if icount > 0 then--整数部分直接给
                        if conf.id == NumericType_Gold then icount = math.floor(icount * moneyRate) end
                        table.insert(dropItems, {type = conf.type, id = conf.id, count = icount})
                    end
                    if isFast then break end--策划要求快速战斗只取整数部分
                    if fcount > 0 and fcount < 1 then--小数部分走随机
                        if math.random() <= fcount then
                            fcount = 1
                            if conf.id == NumericType_Gold then fcount = math.floor(fcount * moneyRate) end
                            table.insert(dropItems, {type = conf.type, id = conf.id, count = fcount})
                        end
                    end
                until true
            end
        end
    end
end

--挂机副本计算掉落（怪物数量小时用）
function guajiDropItems(dropItems, monId, count, moneyRate)
    local config = MonstersConfig[monId]
    moneyRate = moneyRate or 1
    if config.drop ~= 0 then
        if config.drop ~= 0 then
            for k,v in ipairs(drop.dropGroup(config.drop)) do
                if v.id == NumericType_Gold then
                    table.insert(dropItems, {type = v.type, id = v.id, count = v.count * moneyRate * count})
                else
                    table.insert(dropItems, {type = v.type, id = v.id, count = v.count * count})
                end
            end
        end
    end
end

--拾取
function lootItemBag(actor, packet)
    if not actor or not packet then return end
    
    local key = LDataPack.readInt(packet)
    local ins = instancesystem.getActorIns(actor)
    if not ins then return end
    
    ins:removeDropBagItem(actor, key)
end

function onActorLogin(actor)
    local ins = instancesystem.getActorIns(actor)
    if not ins then return end
    
    local fbId = LActor.getFubenId(actor)
    if not FubenConfig[fbId] or FubenConfig[fbId].type == 1 then return end
    
    local posX, posY = LActor.getEntityScenePos(actor)
    ins:sendDropBagInfo(actor, 1, posX, posY)
end

netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.cBaseCmd_LootItem, lootItemBag)

actorevent.reg(aeUserLogin, onActorLogin)
