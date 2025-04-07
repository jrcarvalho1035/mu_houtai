module("dartsystem", package.seeall)

function getActorVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.dart then
        var.dart = {} ----命名空间
        var.dart.buytimes = 0
        var.dart.scorestatus = 0
        var.dart.stores = {} --商城限购
        var.dart.refreshcount = 0 --已刷新次数
        var.dart.refresh_week_time = 0
        var.dart.nextplundertime = 0 --下一次可夺镖时间
    end
    return var.dart
end

function canChange(index)
    local starthour, startMin = DartConstConfig.startTimes[index][1], DartConstConfig.startTimes[index][2]
    local curhour, curmin, sec = System.getTime()
    if startMin == 0 and (curhour < (starthour - 1) or ((starthour - curhour == 1) and curmin < 55)) then
        return true
    elseif startMin ~= 0 and (curhour < starthour or ((curhour == starthour) and curmin < startMin - 5)) then
        return true
    end
    return false
end

function c2sChooseCar(actor, pack)
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then return end
    local index = LDataPack.readChar(pack)
    local starthour = DartConstConfig.startTimes[index]
    if not starthour then return end    
    local curhour, min, sec = System.getTime() 
    if canChange(index) then --开车前五分钟不可变更
        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
        LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_ChooseCar)    
        LDataPack.writeChar(npack, index)
        LDataPack.writeInt(npack, guildId)
        local actorid = LActor.getActorId(actor)
        LDataPack.writeInt(npack, actorid)
        LDataPack.writeInt(npack, LActor.getLevel(actor))
        LDataPack.writeDouble(npack, LActor.getActorPower(actorid))
        LDataPack.writeString(npack, LActor.getName(actor))
        System.sendPacketToAllGameClient(npack, 0)
    end
end

local function onChooseCarRet(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_ChooseCar)
    local choose1 = LDataPack.readChar(cpack)
    local choose2 = LDataPack.readChar(cpack) 
    LDataPack.writeChar(npack, choose1)
    LDataPack.writeChar(npack, choose2)
    LDataPack.flush(npack)
end

local function onSendCarList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_SendMyCarList)
    local count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        local peoplecount = LDataPack.readChar(cpack)
        LDataPack.writeChar(npack, peoplecount)
        for j=1, peoplecount do
            LDataPack.writeString(npack, LDataPack.readString(cpack))
            LDataPack.writeInt(npack, LDataPack.readInt(cpack))
            LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
        end
    end
    LDataPack.flush(npack)
end


function c2sGetMyCarList(actor, pack)
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then return end
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_GetCarList)
    LDataPack.writeInt(npack, guildId)
    local actorid = LActor.getActorId(actor)
    LDataPack.writeInt(npack, actorid)
    System.sendPacketToAllGameClient(npack, 0)
end

--购买押镖令
function c2sBuyTime(actor, pack)
    local var = getActorVar(actor)
    if var.buytimes >= DartConstConfig.buyChallengeCount then
        return
    end
    if not actoritem.checkItem(actor, NumericType_YuanBao, DartConstConfig.buyChallengeMoney) then
        return
    end
    actoritem.reduceItem(actor, NumericType_YuanBao, DartConstConfig.buyChallengeMoney, "dart buy times")
    actoritem.addItem(actor, NumericType_DartToken, 1, "dart buy times")
    var.buytimes = (var.buytimes or 0) + 1

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_SendTime)
    LDataPack.writeChar(npack, var.buytimes)
    LDataPack.flush(npack)
end

function c2sGetReward(actor, pack)
    local index = LDataPack.readChar(pack)
    local conf = DartJifenConfig[index]
    if not conf then return end
    local var = getActorVar(actor)
    if actoritem.getItemCount(actor, NumericType_DartScore) < conf.jifen then
        return
    end

    if System.bitOPMask(var.scorestatus, index) then --已领取
		return false
	end

    actoritem.addItems(actor, conf.reward, "dart jifen get reward")
    var.scorestatus = System.bitOpSetMask(var.scorestatus, index, true)
    
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_GetRewardRet)
    LDataPack.writeInt(npack, var.scorestatus)
    LDataPack.flush(npack)
end

--查看个人排行
function c2sGetSelfRank(actor, pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_GetSelfRankList)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

function onSendSelfRankList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_SendSelfRank)
    if npack == nil then return end
    local count = LDataPack.readShort(cpack)
    LDataPack.writeShort(npack, count)
    for i=1, count do
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    end
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeShort(npack, LDataPack.readShort(cpack))    
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	LDataPack.flush(npack)
end

--查看公会排行
function c2sGetGuildRank(actor, pack)
    local guildId = LActor.getGuildId(actor)
    if guildId == 0 then return end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_GetGuildRankList)
    LDataPack.writeInt(npack, guildId)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

function onSendGuildRankList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_SendGuildRank)
    if npack == nil then return end
    local count = LDataPack.readShort(cpack)
    LDataPack.writeShort(npack, count)
    for i=1, count do
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    end
    LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    LDataPack.writeShort(npack, LDataPack.readShort(cpack))    
    LDataPack.flush(npack)
end

--查看公会记录
function c2sGetGuildRecord(actor, pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_GetGuildRecordList)
    LDataPack.writeInt(npack, LActor.getGuildId(actor))
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

local function onSendGuildRecordList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_SendGuildRecord)
    if npack == nil then return end
    local count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        local type = LDataPack.readChar(cpack)
        LDataPack.writeChar(npack, type)
        if type == 1 then --出发
            LDataPack.writeChar(npack, LDataPack.readChar(cpack))
            LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        elseif type == 2 then
            LDataPack.writeChar(npack, LDataPack.readChar(cpack))
            LDataPack.writeChar(npack, LDataPack.readChar(cpack))
            LDataPack.writeShort(npack, LDataPack.readShort(cpack))
            LDataPack.writeShort(npack, LDataPack.readShort(cpack))
        else
            LDataPack.writeString(npack, LDataPack.readString(cpack))
            LDataPack.writeString(npack, LDataPack.readString(cpack))
        end
    end 
    LDataPack.flush(npack)
end

--查看个人记录
function c2sGetSelfRecord(actor, pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_GetSelfRecordList)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

local function onSendSelfRecordList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_SendSelfRecord)
    if npack == nil then return end
    local count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        local type = LDataPack.readChar(cpack)
        LDataPack.writeChar(npack, type)
        if type == 1 then --出发
            LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        elseif type == 2 then
            LDataPack.writeChar(npack, LDataPack.readChar(cpack))
            LDataPack.writeShort(npack, LDataPack.readShort(cpack))
            LDataPack.writeShort(npack, LDataPack.readShort(cpack))
        else
            LDataPack.writeChar(npack, LDataPack.readChar(cpack))
            LDataPack.writeString(npack, LDataPack.readString(cpack))
            LDataPack.writeString(npack, LDataPack.readString(cpack))
            LDataPack.writeChar(npack, LDataPack.readChar(cpack))
            LDataPack.writeShort(npack, LDataPack.readShort(cpack))
            LDataPack.writeShort(npack, LDataPack.readShort(cpack))
        end
    end 
    LDataPack.flush(npack)
end

--请求刷新可掠夺车队列表
function c2sRefreshPlunderList(actor, pack)
    local type = LDataPack.readChar(pack)
    local var = getActorVar(actor)
    
    if type == 1 then
        if var.refreshcount >= DartConstConfig.refreshListCount then
            if not actoritem.checkItem(actor, NumericType_YuanBao, DartConstConfig.buyRefreshListMoney) then
                return
            end
            actoritem.reduceItem(actor, NumericType_YuanBao, DartConstConfig.buyRefreshListMoney, "dart buy times")
        end
        var.refreshcount = var.refreshcount + 1
    end
    

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_RefreshPlunerList)
    LDataPack.writeChar(npack, type)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

function onRetRefreshPlunderList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end
    local var = getActorVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_RefreshPlunderList)
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    if npack == nil then return end
    local count = LDataPack.readChar(cpack)
    LDataPack.writeChar(npack, math.max(0, DartConstConfig.refreshListCount - var.refreshcount))
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    end 
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    LDataPack.flush(npack)
end

--请求车队列表
function c2sGetPlunderList(actor, pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_GetPlunerList)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

function onSendPlunderList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then return end

    local var = getActorVar(actor)
    local curhour, min, sec = System.getTime() 
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_PlunderList)
    if npack == nil then return end    
    LDataPack.writeInt(npack, var.scorestatus)    
    --镖车信息
    local count = LDataPack.readChar(cpack)   
    LDataPack.writeChar(npack, count)
    for i=1, count do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    end 
    LDataPack.writeChar(npack, var.buytimes)
    LDataPack.writeChar(npack, math.max(0, DartConstConfig.refreshListCount - var.refreshcount)) --剩余免费刷新次数    
    LDataPack.writeShort(npack, math.max(0, var.nextplundertime - System.getNowTime())) --劫镖冷却剩余秒数
    LDataPack.writeChar(npack, LDataPack.readChar(cpack))
    LDataPack.flush(npack)
end

function onLogin(actor)
end

function onNewDay(actor)
    local var = getActorVar(actor)    
    var.buytimes = 0
    local now = System.getNowTime()
    local isSameWeek = System.isSameWeek(now, var.refresh_week_time)
    if not isSameWeek then
        local count = actoritem.getItemCount(actor, NumericType_DartToken)
        if count ~= 0 then
            actoritem.reduceItem(actor, NumericType_DartToken, count, "dart newday add", 1) --跨周清空
        end
        actoritem.reduceItem(actor, NumericType_DartScore, actoritem.getItemCount(actor, NumericType_DartScore), "dart newday clear")
        var.scorestatus = 0
    end
    if actorexp.checkLevelCondition(actor, actorexp.LimitTp.dart) then
        actoritem.addItem(actor, NumericType_DartToken, DartConstConfig.challengeCount, "dart newday add", 1)
    end
    var.refreshcount = 0
    var.refresh_week_time = now
end

function onSystemOpen(actor, isNewday)
    if not isNewday then --如果是因跨天开启的，onNewday已经给了，会多给一次
        actoritem.addItem(actor, NumericType_DartToken, DartConstConfig.challengeCount, "dart open add", 1)
    end
end

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)

function onInit()
    newsystem.regSystemOpenFuncs(actorexp.LimitTp.dart, onSystemOpen)

    if System.isCrossWarSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Dart, Protocol.cDartCmd_GetReward, c2sGetReward) --获取个人达标奖励
	netmsgdispatcher.reg(Protocol.CMD_Dart, Protocol.cDartCmd_GetGuildRecord, c2sGetGuildRecord) --查看公会记录
	netmsgdispatcher.reg(Protocol.CMD_Dart, Protocol.cDartCmd_GetSelfRecord, c2sGetSelfRecord)  --查看个人记录
	netmsgdispatcher.reg(Protocol.CMD_Dart, Protocol.cDartCmd_BuyTime, c2sBuyTime) --购买押镖令
    netmsgdispatcher.reg(Protocol.CMD_Dart, Protocol.cDartCmd_RefreshPlunderList, c2sRefreshPlunderList) --刷新车队
    netmsgdispatcher.reg(Protocol.CMD_Dart, Protocol.cDartCmd_GetMyCarList, c2sGetMyCarList) --查看我方车队
	netmsgdispatcher.reg(Protocol.CMD_Dart, Protocol.cDartCmd_GetSelfRank, c2sGetSelfRank) --查看个人排行
	netmsgdispatcher.reg(Protocol.CMD_Dart, Protocol.cDartCmd_GetGuildRank, c2sGetGuildRank) --查看公会排行
    netmsgdispatcher.reg(Protocol.CMD_Dart, Protocol.cDartCmd_ChoosCar, c2sChooseCar)--选择一辆车
    netmsgdispatcher.reg(Protocol.CMD_Dart, Protocol.cDartCmd_PlunderList, c2sGetPlunderList)--请求镖车列表
end
table.insert(InitFnTable, onInit)

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_ChooseCarRet, onChooseCarRet)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_SendCarList, onSendCarList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_SendSelfRankList, onSendSelfRankList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_SendGuildRankList, onSendGuildRankList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_SendSelfRecordList, onSendSelfRecordList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_SendGuildRecordList, onSendGuildRecordList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_RefreshPlunerListRet, onRetRefreshPlunderList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_SendPlunerList, onSendPlunderList)

