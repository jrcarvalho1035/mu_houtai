--活动掉落
module("subactivity12", package.seeall)

local subType = 12

minType = {
    default = 1, --Quedas de eventos
    dropBox = 2, --Baú do tesouro do céu
    equipXB = 3, --Caça ao tesouro de equipamentos
    hunqiXB = 4, --Caça ao Tesouro Horcrux
    fuwenXB = 5, --Caça ao tesouro rúnico
    dianfengXB = 6, --Pico da caça ao tesouro
    zhizunXB = 7, --A caça ao tesouro de Deus
}

--记录数据
local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    LDataPack.writeInt(npack, 0)
end

function checkIsStart(acttype)
    acttype = acttype or minType.default
    local dropindexs = {}
    for id, conf in pairs(ActivityType12Config) do
        if not activitymgr.activityTimeIsEnd(id) and conf[1].sType == acttype then
            local ishave = false
            for i=1, #dropindexs do
                if dropindexs[i] == conf[1].dropindex then
                    ishave = true
                end
            end
            if not ishave then
                table.insert(dropindexs, conf[1].dropindex)
            end
        end
    end
    if #dropindexs > 0 then
        return true, dropindexs
    end
    return false, dropindexs
end

function getDropIndex()
    for id, conf in pairs(ActivityType12Config) do
        if not activitymgr.activityTimeIsEnd(id) and conf[1].sType == minType.default then
            return conf[1].dropindex
        end
    end
    return 1
end

function dropList(drop_ids, toList)    
    if checkIsStart(minType.default) then
        local isopen, dropindexs = checkIsStart()
        if isopen then
            for i=1, #dropindexs do
                local drop_id = drop_ids[dropindexs[i]]
                if drop_id and 0 < drop_id then
                    local list = drop.dropGroup(drop_id)
                    for _, t in ipairs(list) do
                        table.insert(toList, t)
                    end
                end
            end
        end
    end
end

subactivitymgr.regWriteRecordFunc(subType, writeRecord)
