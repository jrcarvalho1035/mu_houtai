module("tianticross", package.seeall)
TiantiMatchs = TiantiMatchs or {}

function matchingActor(actor, var)
    print("......  matchingActor start"..var.level)
    if var.level == 1 then return 0 end
    local findActorId = LActor.findTiantiActor(actor)
    if 0 == findActorId then
        local npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, CrossSrvCmd.SCTianTiCmd)
        LDataPack.writeByte(npack, CrossSrvSubCmd.SCTianTiCmd_MatchActor)
        LDataPack.writeInt(npack, LActor.getServerId(actor))
        LDataPack.writeInt(npack, LActor.getActorId(actor))        
        LDataPack.writeInt(npack, var.level)
        System.sendPacketToAllGameClient(npack, 0)
    end
    return findActorId
end

--跨服匹配人
function onSyncFindActor(sId, sType, cpack)    
    local serverid = LDataPack.readInt(cpack)
    print("........ onSyncFindActor start serverid:"..System.getServerId())
    if System.isBattleSrv() then
        local connList = csbase.getConnectList()        
        local rands = utils.getRandomIndexs(1, #connList, 1)
        print("onSyncFindActor find serverid ", rands[1], connList[rands[1]])
        local findServerId = connList[rands[1]]
        System.sendPacketToAllGameClient(cpack, findServerId)
        return
    end
    local actorid = LDataPack.readInt(cpack)
    local level = LDataPack.readInt(cpack)

    local findActorid = 0
    for i=level, 1, -1 do
        findActorid = System.findTiantiActor(actorid, i)
        if findActorid ~= 0 then
            break
        end
    end
    
    local findServerId = System.getServerId()
    local basic_data = nil
    if findActorid then
        basic_data = LActor.getActorDataById(findActorid)
    end
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCTianTiCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCTianTiCmd_FindActorResult)
    LDataPack.writeInt(npack, serverid)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeInt(npack, findActorid)
    LDataPack.writeInt(npack, findServerId)
    LDataPack.writeString(npack, basic_data and basic_data.actor_name or "")
    LDataPack.writeChar(npack, basic_data and basic_data.job or 0)
    LDataPack.writeInt(npack, basic_data and basic_data.tianti_level or 0)
    LDataPack.writeInt(npack, basic_data and basic_data.tianti_dan or 0)
    System.sendPacketToAllGameClient(npack, 0)
end

--匹配返回
local function onSyncFindActorResult(sId, sType, cpack)    
    local serverid = LDataPack.readInt(cpack)
    print("........ onSyncFindActorResult start serverid:", serverid)
    if System.isBattleSrv() then
        System.sendPacketToAllGameClient(cpack, serverid)
        return
    end    
    local actorid = LDataPack.readInt(cpack)
    local findActorid = LDataPack.readInt(cpack)
    local findServerId = LDataPack.readInt(cpack)
    local name = LDataPack.readString(cpack)
    local job = LDataPack.readChar(cpack)
    local level = LDataPack.readInt(cpack)
    local dan = LDataPack.readInt(cpack)
    tianti.onCrossMatch(actorid, findActorid, findServerId, name, job, level, dan)
end

function reqCloneInfo(matchActorId, cloneActorId, cloneServerId, sceneHandle, mathchaServerId)
    print("...... reqCloneInfo start")
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCTianTiCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCTianTiCmd_ReqCloneInfo)
    LDataPack.writeInt(npack, cloneServerId)
    LDataPack.writeInt(npack, mathchaServerId)
    LDataPack.writeInt(npack, matchActorId)
    LDataPack.writeInt(npack, cloneActorId)
    LDataPack.writeDouble(npack, sceneHandle)    
    System.sendPacketToAllGameClient(npack, 0)
end

function getCloneInfo(sId, sType, cpack)
    print("...... getCloneInfo start")
    local cloneServerId = LDataPack.readInt(cpack)
    if System.isBattleSrv() then
        System.sendPacketToAllGameClient(cpack, cloneServerId)
        return
    end
    local mathchaServerId = LDataPack.readInt(cpack)
    local matchActorId = LDataPack.readInt(cpack)
    local cloneActorId = LDataPack.readInt(cpack)
    local sceneHandle = LDataPack.readDouble(cpack)    
	local actor = LActor.getActorById(cloneActorId)
    local basic_data = LActor.getActorDataById(cloneActorId)

	if actor then--先暴力处理
		offlinedatamgr.CallEhLogout(actor) --保存离线数据
	end

	local actorData = offlinedatamgr.GetDataByOffLineDataType(cloneActorId, offlinedatamgr.EOffLineDataType.EBasic)
	if actorData==nil then
		local pack = LDataPack.allocPacket()
		if pack == nil then return end
		LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_ResCloneInfo)
		LDataPack.writeInt(pack, mathchaServerId)
        LDataPack.writeInt(pack, matchActorId)
        LDataPack.writeString(pack, basic_data.actor_name)
        LDataPack.writeDouble(pack, sceneHandle)
		LDataPack.writeUserData(pack, bson.encode({}))
		System.sendPacketToAllGameClient(pack, 0)
		return
	end
	local actorDataUd = bson.encode(actorData)

	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_ResCloneInfo)
    LDataPack.writeInt(pack, mathchaServerId)
	LDataPack.writeInt(pack, matchActorId)
    LDataPack.writeString(pack, basic_data.actor_name)
	LDataPack.writeDouble(pack, sceneHandle)
	LDataPack.writeUserData(pack, actorDataUd)

	System.sendPacketToAllGameClient(pack, 0)
end


function resCloneInfo(sId, sType, cpack)
    local mathchaServerId = LDataPack.readInt(cpack)
    print("...... resCloneInfo start mathchaServerId : ".. mathchaServerId)
    if System.isBattleSrv() then
        System.sendPacketToAllGameClient(cpack, mathchaServerId)
        return
    end
	local actorid = LDataPack.readInt(cpack)
    local cloneActor_name = LDataPack.readString(cpack)
	local sceneHandle = LDataPack.readDouble(cpack)
	local actorDataUd = LDataPack.readUserData(cpack)
	local offlinedata = bson.decode(actorDataUd)    
	tianti.setClone(actorid, cloneActor_name, offlinedata, sceneHandle)
end


function updateRankingList(actor, wincount)
    print("...... updateRankingList wincount :"..wincount)
    local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_UpdateRank)
    LDataPack.writeInt(pack, LActor.getActorId(actor))
    LDataPack.writeInt(pack, tianti.getLevel(actor))
    LDataPack.writeInt(pack, tianti.getId(actor))
    LDataPack.writeString(pack, LActor.getName(actor))
    LDataPack.writeShort(pack, wincount)
    LDataPack.writeInt(pack, LActor.getLevel(actor))
    LDataPack.writeByte(pack, LActor.getSVipLevel(actor))
    LDataPack.writeInt(pack, LActor.getServerId(actor))
	System.sendPacketToAllGameClient(pack, 0)
end

function onUpdateRankList(sId, sType, cpack)
    print("...... onUpdateRankList ")
    if not System.isBattleSrv() then return end
    local actorid = LDataPack.readInt(cpack)
    local tiantilevel = LDataPack.readInt(cpack)
    local tiantiid = LDataPack.readInt(cpack)
    local name = LDataPack.readString(cpack)
    local wincount = LDataPack.readShort(cpack)
    local level = LDataPack.readInt(cpack)
    local svip = LDataPack.readByte(cpack)
    local serverid = LDataPack.readInt(cpack)
    tiantirank.updateRankingList(actorid, tiantilevel, tiantiid, name, wincount, level, svip, serverid)
end

function getRankList(actor)
    local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_GetRankList)
    LDataPack.writeInt(pack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(pack, 0)
end

function onGetRankList(sId, sType, cpack)
    print("...... onGetRankList ")
    if not System.isBattleSrv() then return end
    local actorid = LDataPack.readInt(cpack)
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_GetRankListReturn)
    LDataPack.writeInt(pack, actorid)
    tiantirank.getRankingList(actorid, pack)
    System.sendPacketToAllGameClient(pack, sId)
end

function onGetRankListReturn(sId, sType, cpack)
    print("...... onGetRankListReturn ")
    if System.isCrossWarSrv() then return end
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)

    if not actor then return end
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Tianti, Protocol.sTiantiCmd_RankData)
    tiantirank.setPacket(pack, cpack)
    --LDataPack.writePacket(pack, cpack)
    LDataPack.flush(pack)
end

function getLastWeekFirstActorName(isstart)
    if not System.isBattleSrv() then return end
    local name = tiantirank.getLastWeekFirstActorName()
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_GetFirstNameReturn)
    LDataPack.writeByte(pack, isstart)
    LDataPack.writeString(pack, name or "")
    System.sendPacketToAllGameClient(pack, 0)
end

function onGetFistNameReturn(sId, sType, cpack)
    print("...... onGetFistNameReturn ")
    if System.isCrossWarSrv() then return end
    local isstart = LDataPack.readByte(cpack)
    local name = LDataPack.readString(cpack)
    if isstart == 0 then
        tianti.onEndotice(name)
    else
        tianti.onStartNotice(name)
    end
end


csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_MatchActor, onSyncFindActor)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_FindActorResult, onSyncFindActorResult)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_ReqCloneInfo, getCloneInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_ResCloneInfo, resCloneInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_UpdateRank, onUpdateRankList)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_GetRankList, onGetRankList)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_GetRankListReturn, onGetRankListReturn)
--csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_GetFirstName, onGetFistName)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_GetFirstNameReturn, onGetFistNameReturn)
