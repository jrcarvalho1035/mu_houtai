-- 点券放送
module("subactivity19", package.seeall)

local subType = 19

local function onRecharge(actor, count, itemid)
    for id, conf in pairs(ActivityType19Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local pay_conf = PayItemsConfig[itemid]
            if pay_conf then
                local diamond = rechargesystem.getDiamondByPf(actor, itemid)
                if diamond > 0 then
                    local value = math.floor(diamond * conf.arg)
                    actoritem.addItem(actor, NumericType_Diamond, value, 'type19')
                end
            end
        end
	end
end

function isOpen()
    for id, conf in pairs(ActivityType19Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            return true
        end
    end
    return false
end

local function initGlobalData()
    actorevent.reg(aeRecharge, onRecharge)
end
table.insert(InitFnTable, initGlobalData)
