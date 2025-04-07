--植树节抽奖活动

module("subactivity16", package.seeall)

local subType = 16

local function getActorVar(actor, id)
    local var = activitymgr.getSubVar(actor, id)
    if (var == nil) then return end
    var = var.data
    if not var.gettimes then var.gettimes = 0 end --奖池领奖状态
    if not var.jiangchi then var.jiangchi = 1 end --奖池个数
    return var
end

--记录数据
local function writeRecord(npack, record, config, id, actor)
    if npack == nil then return end
    LDataPack.writeInt(npack, 0)
end


--领取奖励
local function c2sDraw(actor, pack)
    local id = LDataPack.readInt(pack)
    if activitymgr.activityTimeIsEnd(id) then return end
	local config = ActivityType16Config[id]
    if not config then return end
    local var = getActorVar(actor, id)
    if not config[var.jiangchi] and not config[var.jiangchi + 1] then return end
	if not actoritem.checkItems(actor, config[1][1].costitem) then
		return
    end	
    actoritem.reduceItems(actor, config[1][1].costitem, "activity type16 rewards")

    
    var.gettimes = var.gettimes + 1
    for k,v in ipairs(config[var.jiangchi]) do
        if var.gettimes == v.gettimes then
            jiangchiconfig = config[var.jiangchi][k]
        end
    end
    local before = var.jiangchi
    if #config[var.jiangchi] == var.gettimes and config[var.jiangchi+1] then
        var.jiangchi = var.jiangchi + 1
        var.gettimes = 0
    end
    actoritem.addItems(actor, jiangchiconfig.rewards, "activity type16 rewards", 1)
    updateInfo(actor, id, jiangchiconfig.index)
    if before ~= var.jiangchi then
        sendZhishuDraw(actor, id)
    end
end

function updateInfo(actor, id, index)
    local var = getActorVar(actor, id)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_UpdateZhishuDraw)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, var.jiangchi)
    LDataPack.writeChar(npack, index)
    LDataPack.writeChar(npack, 1)
	LDataPack.flush(npack)
end

function sendZhishuDraw(actor, id)
    local var = getActorVar(actor, id)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_SendZhishuReward)
    LDataPack.writeInt(npack, id)
    LDataPack.writeChar(npack, var.jiangchi)
    LDataPack.writeChar(npack, #ActivityType16Config[id][var.jiangchi])
    for i=1, #ActivityType16Config[id][var.jiangchi] do
        if ActivityType16Config[id][var.jiangchi][i].gettimes <= var.gettimes then
            LDataPack.writeChar(npack, 1)
        else
            LDataPack.writeChar(npack, 0)
        end
    end
	LDataPack.flush(npack)
end

subactivitymgr.actorLoginFuncs[subType] = function(actor, type, id)
    if activitymgr.activityTimeIsOver(id) then return end
    sendZhishuDraw(actor, id)
end

function onAfterNewDay(actor, id)
    if activitymgr.activityTimeIsOver(id) then return end
    sendZhishuDraw(actor, id)
end

-- function onTimeOut(id, config, actor, record)
--     local var = getActorVar(actor, id)
--     local itemid = ActivityType16Config[id][1][1].costitem.id
--     actoritem.reduceItem(actor, itemid, actoritem.getItemCount(actor, itemid), "activity16 recycled:"..id)
-- end

-- function onActivityFinish(id)
-- 	local config = ActivityType16Config
-- 	local actors = System.getOnlineActorList()
-- 	if actors then
-- 		for i = 1, #actors do
-- 			local actor = actors[i]
-- 			local var = activitymgr.getStaticData(actor)
-- 			local record = var.records[id]
-- 			onTimeOut(id, config, actor, record)
-- 		end
-- 	end	
-- end

--subactivitymgr.regTimeOut(subType, onTimeOut)
subactivitymgr.regWriteRecordFunc(subType, writeRecord)
subactivitymgr.regGetRewardFunc(subType, onGetReward)
subactivitymgr.regNewDayAfterFunc(subType, onAfterNewDay)
--subactivitymgr.regActivityFinish(subType, onActivityFinish)

netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_ZhishuDraw, c2sDraw)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.zhishuclear = function (actor, args)
    for id,v in pairs(ActivityType16Config) do
        local var = getActorVar(actor, id)
        var.gettimes = 11
        var.jiangchi = 1
        sendZhishuDraw(actor, id)
    end
	return true
end

