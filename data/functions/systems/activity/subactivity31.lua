--钻石夺宝
module("subactivity31", package.seeall)

ACT31_RECORD = ACT31_RECORD or {}
ACT31_SELF_RECORD = ACT31_SELF_RECORD or {}
local MAX_RECORD = 20
local subType = 31

function getSystemVar(id)
    local var = activitymgr.getGlobalVar(id)
    if not var then return end
    if not var.jackpot then var.jackpot = 0 end
	return var
end

function c2sDraw(actor, pack)    
    if System.isBattleSrv() then return end 
    local id = LDataPack.readInt(pack)
    if activitymgr.activityTimeIsEnd(id) then return end
	local times = LDataPack.readChar(pack)
    if activitymgr.activityTimeIsEnd(id) then return end
	if not ActivityType31Config[id] then
		return
	end
	local index = 0
	local config = ActivityType31Config[id][1]
	for i=1, #config.drawcount do
		if config.drawcount[i][1] == times then
			index = i
			break
		end
	end
	if index == 0 then
		return
	end
	local cost = config.drawcount[index][2]
	if not actoritem.checkItem(actor, NumericType_YuanBao, cost) then
		return
    end
    local svar = getSystemVar(id)
	actoritem.reduceItem(actor, NumericType_YuanBao, cost, "activity type31 cost")
    local items = {}
    local broitems = {}
	local total = 0
	for i=1, times do
		local rand = System.getRandomNumber(10000) + 1
		total = 0
		for k,v in ipairs(config.rewards) do
			total = total + v.per
			if rand <= total then
				items[#items + 1] = config.rewards[k]
				index = k
				--记录数据
				local actorid = LActor.getActorId(actor)
				if not ACT31_SELF_RECORD[id] then ACT31_SELF_RECORD[id] = {} end
				if not ACT31_SELF_RECORD[id][actorid] then ACT31_SELF_RECORD[id][actorid] = {} end
				table.insert(ACT31_SELF_RECORD[id][actorid], 1, {name = LActor.getName(actor), id = config.rewards[k].id, count = config.rewards[k].count})
				if #ACT31_SELF_RECORD[id][actorid] > MAX_RECORD then
					table.remove(ACT31_SELF_RECORD[id][actorid])
				end
				if config.rewards[k].isbro == 1 then --如果要加入记录
                    table.insert(broitems, {id = config.rewards[k].id, count = config.rewards[k].count})
				end
				break
			end
		end
	end
    local jackpotupdate = 0
    for k,v in ipairs(items) do
        if ItemConfig[v.id].type == ItemType_YuanbaoDraw then
            local addcount = math.floor(v.beishu/100 * svar.jackpot)
            actoritem.addItem(actor, NumericType_YuanBao, addcount, "activity type31 rewards", 1)
            jackpotupdate = jackpotupdate - addcount
        else
            actoritem.addItem(actor, v.id, v.count, "activity type31 rewards", 1)
        end        
    end
    actorevent.onEvent(actor, aeYuanbaoDrawScore, config.score * times, config.actId)

    
    jackpotupdate = jackpotupdate + math.floor(cost * 0.2)
    svar.jackpot = svar.jackpot + jackpotupdate
    if svar.jackpot < 0 then
        svar.jackpot = 0
    end
    updateCrossJackpot(id, LActor.getActorId(actor), LActor.getName(actor), jackpotupdate, broitems, config.score * times)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_YuanbaoDraw)
	LDataPack.writeInt(npack, id)
	LDataPack.writeChar(npack, #items)
	for k,v in ipairs(items) do
		LDataPack.writeInt(npack, v.id)
		LDataPack.writeInt(npack, v.count)
	end
	LDataPack.writeChar(npack, index)
	LDataPack.flush(npack)
	s2cRecordInfo(actor, id, 1)
end

--向跨服发送奖池信息
--actorid, actorname, 总奖池， 抽奖道具， 个人积分
function updateCrossJackpot(id, actorid, actorname, jackpot, broitems, selfaddscore)    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCYuanbaoDrawCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCYuanbaoDrawCmd_UpdateCrossInfo)
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, actorid)
    LDataPack.writeString(pack, actorname)
    LDataPack.writeInt(pack, jackpot)
    LDataPack.writeChar(pack, #broitems)
    for k,v in ipairs(broitems) do
        LDataPack.writeInt(pack, v.id)
        LDataPack.writeInt(pack, v.count)
    end
    LDataPack.writeInt(pack, selfaddscore)
    System.sendPacketToAllGameClient(pack, 0)
end

--跨服收到玩家抽奖信息
function onSyncRecvDrawInfo(sId, sType, cpack)
    if System.isCommSrv() then return end
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local actorname = LDataPack.readString(cpack)
    local jackpotupdate = LDataPack.readInt(cpack)
    local count = LDataPack.readChar(cpack)
    if not ACT31_RECORD[id] then ACT31_RECORD[id] = {} end    
    
    for i=1, count do
        table.insert(ACT31_RECORD[id], 1, {name = actorname, id = LDataPack.readInt(cpack), count = LDataPack.readInt(cpack)})
        if #ACT31_RECORD[id] > MAX_RECORD then
            table.remove(ACT31_RECORD[id])
        end
    end
    
    local selfaddscore = LDataPack.readInt(cpack)

    --更新跨服排行榜信息
    subactivity30.updateActorScore(ActivityType31Config[id][1].subType, actorid, actorname, selfaddscore, sId)
    subactivity32.updateServerScore(ActivityType31Config[id][1].subType, sId, selfaddscore)

    --同步普通服记录
    

    local svar = getSystemVar(id)
    svar.jackpot = svar.jackpot + jackpotupdate
    if svar.jackpot < 0 then
        svar.jackpot = 0
    end

    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCYuanbaoDrawCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCYuanbaoDrawCmd_UpdateCommonInfo)
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, actorid)
    LDataPack.writeInt(pack, svar.jackpot)
    LDataPack.writeChar(pack, #ACT31_RECORD[id])
    for k,v in ipairs(ACT31_RECORD[id]) do
        LDataPack.writeString(pack, v.name)
        LDataPack.writeInt(pack, v.id)
        LDataPack.writeInt(pack, v.count)
    end
    System.sendPacketToAllGameClient(pack, 0)    
end

--普通服收到跨服的更新
function onSyncRecvCrossInfo(sId, sType, cpack)
    print("... onSyncRecvCrossInfo start")
    if System.isBattleSrv() then return end    
    local id = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    local svar = getSystemVar(id)
    svar.jackpot = LDataPack.readInt(cpack)
    local count = LDataPack.readChar(cpack)
    if not ACT31_RECORD[id] then ACT31_RECORD[id] = {} end
    for i=1, count do
        ACT31_RECORD[id][i] = {}
        ACT31_RECORD[id][i].name = LDataPack.readString(cpack)
        ACT31_RECORD[id][i].id = LDataPack.readInt(cpack)
        ACT31_RECORD[id][i].count = LDataPack.readInt(cpack)
    end
    if actor then
        s2cRecordInfo(actor, id, 2)
        s2cJackpotInfo(actor, id)
    end    
end

function c2sRecord(actor, pack)
	local id = LDataPack.readInt(pack)
	local type = LDataPack.readChar(pack)
	if not ActivityType31Config[id] then
		return
	end
	s2cRecordInfo(actor, id, type)
end

function s2cJackpotInfo(actor, id)
    local svar = getSystemVar(id)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_YuanbaoDrawJackpot)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, svar.jackpot)
	LDataPack.flush(npack)
end

function c2sJackpotInfo(actor, pack)
    local id = LDataPack.readInt(pack)
	if not ActivityType31Config[id] then
		return
    end
    s2cJackpotInfo(actor, id)
end

function s2cRecordInfo(actor, id, type)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_YuanbaoDrawRecord)
	LDataPack.writeInt(npack, id)
	LDataPack.writeChar(npack, type)
	if type == 1 then
		local actorid = LActor.getActorId(actor)
		if not ACT31_SELF_RECORD[id] then ACT31_SELF_RECORD[id] = {} end
		if not ACT31_SELF_RECORD[id][actorid] then ACT31_SELF_RECORD[id][actorid] = {} end
		LDataPack.writeChar(npack, #ACT31_SELF_RECORD[id][actorid])
		for k,v in ipairs(ACT31_SELF_RECORD[id][actorid]) do
			LDataPack.writeString(npack, v.name)
			LDataPack.writeInt(npack, v.id)
			LDataPack.writeInt(npack, v.count)
		end
	else
		if not ACT31_RECORD[id] then ACT31_RECORD[id] = {} end
		LDataPack.writeChar(npack, #ACT31_RECORD[id])
		for k,v in ipairs(ACT31_RECORD[id]) do
			LDataPack.writeString(npack, v.name)
			LDataPack.writeInt(npack, v.id)
			LDataPack.writeInt(npack, v.count)
		end
	end
	LDataPack.flush(npack)
end

function onConnected(sId, sType)
    if System.isCommSrv() then return end
    for id,v in pairs(ActivityType31Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local svar = getSystemVar(id)
            local pack = LDataPack.allocPacket()
            LDataPack.writeByte(pack, CrossSrvCmd.SCYuanbaoDrawCmd)
            LDataPack.writeByte(pack, CrossSrvSubCmd.SCYuanbaoDrawCmd_UpdateCommonInfo)
            LDataPack.writeInt(pack, id)
            LDataPack.writeInt(pack, 0)
            LDataPack.writeInt(pack, svar.jackpot)
            if not ACT31_RECORD[id] then ACT31_RECORD[id] = {} end
            LDataPack.writeChar(pack, #ACT31_RECORD[id])
            for k,v in ipairs(ACT31_RECORD[id]) do
                LDataPack.writeString(pack, v.name)
                LDataPack.writeInt(pack, v.id)
                LDataPack.writeInt(pack, v.count)
            end
            System.sendPacketToAllGameClient(pack, 0)  
        end
    end      
end

function checkNeedInit()
    for id,v in pairs(ActivityType31Config) do
        if not activitymgr.activityTimeIsEnd(id) then
            local svar = getSystemVar(id)
            if not svar.isinit then 
                svar.isinit = true
                svar.jackpot = math.random(v[1].init[1], v[1].init[2]) 
            end
        end
    end
end

function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	local v = record and record.data and record.data.rewardsRecord or 0
	LDataPack.writeInt(npack, v)
end

function onActivityFinish(id)
	local config = ActivityType3Config
    local svar = getSystemVar(id)
    svar.isinit = nil
    svar.jackpot = 0
end


function OnGameStart(...)
    if System.isCommSrv() then return end    
    checkNeedInit()
end

local function init()
    csbase.RegConnected(onConnected)    
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_YuanbaoDraw, c2sDraw)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_YuanbaoDrawRecord, c2sRecord)
    netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_YuanbaoDrawJackpot, c2sJackpotInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCYuanbaoDrawCmd, CrossSrvSubCmd.SCYuanbaoDrawCmd_UpdateCrossInfo, onSyncRecvDrawInfo)
    csmsgdispatcher.Reg(CrossSrvCmd.SCYuanbaoDrawCmd, CrossSrvSubCmd.SCYuanbaoDrawCmd_UpdateCommonInfo, onSyncRecvCrossInfo)    
end

table.insert(InitFnTable, init)

engineevent.regGameStartEvent(OnGameStart)
--subactivitymgr.regActivityFinish(subType, onActivityFinish)
subactivitymgr.regWriteRecordFunc(subType, writeRecord)


