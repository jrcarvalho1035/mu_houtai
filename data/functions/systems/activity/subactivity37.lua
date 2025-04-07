module("subactivity37", package.seeall)

local subType = 37





local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    LDataPack.writeInt(npack, 0)
end




table.insert(InitFnTable, init)
subactivitymgr.regWriteRecordFunc(subType, writeRecord)
