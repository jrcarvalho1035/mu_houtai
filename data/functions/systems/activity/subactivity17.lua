--寻宝活动
module("subactivity17", package.seeall)

local subType = 17
local First_Draw_Mutli = 1 --首次连抽时
local Draw_Mutli = 2 --连抽X次时

Total_Record = Total_Record or {}
Self_Record = Self_Record or {}
local Max_Self_Record = 20
local Max_All_Record = 20

local function getActorVar(actor, id)
	local var = activitymgr.getSubVar(actor, id)
	if (var == nil) then return end
	var = var.data
	if not var.times then var.times = 0 end
	return var
end

--记录数据
local function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	LDataPack.writeInt(npack, 0)
end

--获取记录
function c2sGetRecord(actor, pack)
    if System.isBattleSrv() then return end
    local id = LDataPack.readInt(pack)
    local type = LDataPack.readChar(pack)
    if not ActivityType17Config[id] then return end
    s2cRecordInfo(actor, id, type)
end

function s2cRecordInfo(actor, id, type)    
    if type == 0 then
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_SendXunbaoRecord)
        LDataPack.writeInt(npack, id)
        LDataPack.writeChar(npack, type)
        local actorid = LActor.getActorId(actor)
        if not Self_Record[id] then Self_Record[id] = {} end
        if not Self_Record[id][actorid] then Self_Record[id][actorid] = {} end
        LDataPack.writeChar(npack, #Self_Record[id][actorid])
        for k, v in ipairs(Self_Record[id][actorid]) do
            LDataPack.writeString(npack, v.name)
            LDataPack.writeInt(npack, v.id)
            LDataPack.writeDouble(npack, v.count)
        end
        LDataPack.flush(npack)
    else
        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, CrossSrvCmd.SCActiivityCmd)
        LDataPack.writeByte(npack, CrossSrvSubCmd.SCActiivityCmd_GetXunbaoRecord)        
        LDataPack.writeInt(npack, LActor.getActorId(actor))
        LDataPack.writeInt(npack, id)
        System.sendPacketToAllGameClient(npack, 0)
        -- if not Total_Record[id] then Total_Record[id] = {} end
        -- LDataPack.writeChar(npack, #Total_Record[id])
        -- for k, v in ipairs(Total_Record[id]) do
        --     LDataPack.writeString(npack, v.name)
        --     LDataPack.writeInt(npack, v.id)
        --     LDataPack.writeInt(npack, v.count)
        -- end
    end    
end

local function onGetRecord(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local id = LDataPack.readInt(cpack)
    if not Total_Record[id] then Total_Record[id] = {} end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCActiivityCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCActiivityCmd_SendXunbaoRecord)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, #Total_Record[id])
    for k, v in ipairs(Total_Record[id]) do
        LDataPack.writeString(npack, v.name)
        LDataPack.writeInt(npack, v.id)
        LDataPack.writeDouble(npack, v.count)
    end
    System.sendPacketToAllGameClient(npack, sId)
end

function onSendRecord(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_SendXunbaoRecord)
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeChar(npack, 1)
    local count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count)
    for i=1,count do
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
    end
    LDataPack.flush(npack)
end

function getConfig(id)
    if id == 1 then
        return XunbaoEquipConfig, subactivity12.minType.equipXB
    elseif id == 2 then
        return XunbaoHunqiConfig, subactivity12.minType.hunqiXB
    elseif id == 3 then
        return XunbaoElementConfig, subactivity12.minType.fuwenXB
    elseif id == 4 then
        return XunbaoDianfengConfig, subactivity12.minType.dianfengXB
    elseif id == 5 then
        return XunbaoZhizhunConfig, subactivity12.minType.zhizunXB
    end
end

local function onAddRecord(sId, sType, cpack)
    local id = LDataPack.readInt(cpack)
    if not Total_Record[id] then Total_Record[id] = {} end
    table.insert(Total_Record[id], 1, {name = LDataPack.readString(cpack), id = LDataPack.readInt(cpack), count = LDataPack.readDouble(cpack)})
    if #Total_Record[id] > Max_All_Record then
        table.remove(Total_Record[id])
    end
end

--获取抽奖道具
function addRecord(actor, id, item)
    local actorid = LActor.getActorId(actor)
    local name = LActor.getName(actor)
    if not Self_Record[id] then Self_Record[id] = {} end
    if not Self_Record[id][actorid] then Self_Record[id][actorid] = {} end
    table.insert(Self_Record[id][actorid], 1, {name = name, id = item.id, count = item.count})
    if #Self_Record[id][actorid] > Max_Self_Record then
        table.remove(Self_Record[id][actorid])
    end

    if item.isbro == 1 then
        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, CrossSrvCmd.SCActiivityCmd)
        LDataPack.writeByte(npack, CrossSrvSubCmd.SCActiivityCmd_AddXunbaoRecord)
        LDataPack.writeInt(npack, id)
        LDataPack.writeString(npack, name)
        LDataPack.writeInt(npack, item.id)
        LDataPack.writeDouble(npack, item.count)
        System.sendPacketToAllGameClient(npack, 0)
        -- table.insert(Total_Record[id], 1, {name = name, id = config[k].item.id, count = config[k].item.count})
        -- if #Total_Record[id] > Max_All_Record then
        --     table.remove(Total_Record[id])
        -- end
    end
end

--抽奖
function onGetReward(actor, config, id, idx, record, packet)
    if System.isBattleSrv() then return end
    local config = config[id]
    local index = LDataPack.readChar(packet)
    index = index + 1
    if not config then return end
    config = config[1]
    if not config.costcount[index] then return end
    
    if not actoritem.checkItem(actor, config.costid, config.costcount[index]) then return end
    actoritem.reduceItem(actor, config.costid, config.costcount[index], "act17 draw")
    
    local var = getActorVar(actor, id)

    local times = config.drawtimes[index]
    local items = {}
    for i=1, times do
        var.times = var.times + 1    
        local rewards = config.rewards[var.times] or config.rewards[1]
        local rand = math.random(1, 10000)
        local total = 0        
        for k,v in ipairs(rewards) do
            total = total + v.per
            if rand <= total then            
                table.insert(items, {type = v.type, id = v.id, count = v.count})
                addRecord(actor, id, v)
                break
            end
        end
    end

    local score = config.addscore * times

    subactivity33.addXunbaoScore(actor, score)
    subactivity1.addXunbaoScore(actor, config.dabiaoid, score)
    --发送奖励
    actoritem.addItems(actor, items, "act17 draw", 1)
    --发送前端
    -- local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_Reward)
	-- LDataPack.writeByte(npack, 1)
	-- LDataPack.writeInt(npack, id)
	-- LDataPack.writeShort(npack, idx)
	-- LDataPack.writeInt(npack, 0)
    -- LDataPack.flush(npack)
    sendGetItems(actor, id, items)
    
    s2cRecordInfo(actor, id, 0)
end

function sendGetItems(actor, id, items)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_XunbaoItems)
	LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, #items)
    for k,v in ipairs(items) do
        LDataPack.writeInt(npack, v.id)
        LDataPack.writeDouble(npack, v.count)
    end
    LDataPack.flush(npack)    
end


netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_GetXunbaoRecord, c2sGetRecord)

csmsgdispatcher.Reg(CrossSrvCmd.SCActiivityCmd, CrossSrvSubCmd.SCActiivityCmd_AddXunbaoRecord, onAddRecord)
csmsgdispatcher.Reg(CrossSrvCmd.SCActiivityCmd, CrossSrvSubCmd.SCActiivityCmd_GetXunbaoRecord, onGetRecord)
csmsgdispatcher.Reg(CrossSrvCmd.SCActiivityCmd, CrossSrvSubCmd.SCActiivityCmd_SendXunbaoRecord, onSendRecord)

subactivitymgr.regWriteRecordFunc(subType, writeRecord)
subactivitymgr.regGetRewardFunc(subType, onGetReward)

