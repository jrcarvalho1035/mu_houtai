module("cstiantisegment" , package.seeall)
--跨服天梯段位匹配逻辑

function getDanList(dan)
	local sysVar = cstiantisys.getSysStaticVar()
	if sysVar.danData[dan] == nil then sysVar.danData[dan] = {} end
	return sysVar.danData[dan]
end

--把玩家加入段位表
function addActorToDanList(aId, name, sId, dan, job, lvl)
	local dData = getDanList(dan)
	if dData.map == nil then dData.map = {} end
	if dData.list == nil then dData.list = {} end

	if dData.map[aId] then
		tb = dData.map[aId]
		tb.lvl = lvl
	else
		local idx = #dData.list + 1
		dData.list[idx] = aId
		dData.map[aId] = {
			id=idx,
			aId=aId,
			aName=name,
			sId=sId,
			dan=dan,
			job=job,
			lvl=lvl,
		}
		addDanCount(aId)
	end

	local sysVar = cstiantisys.getSysStaticVar()
	local danCountTbl = sysVar.danCountTbl
	local num = danCountTbl[aId] or 0
	if num > 1 then --删除重复的匹配数据
		delRepeatSegment(aId, dan)
	end
end

--把玩家从段位表删除
function delActorToDanList(aId, dan)
	local dData = getDanList(dan)
	if not dData.map or not dData.list then
		return
	end
	local info = dData.map[aId]
	if not info then return end
	delDanCount(aId)

	--把末位的数据复制到aId的位置，把末位删除
	local endIdx = #dData.list
	local endAId = dData.list[endIdx]
	if endIdx <= 1 then
		dData.list = {}
		dData.map = {}
		return
	end

	dData.list[info.id] = endAId
	dData.map[endAId].id = info.id
	dData.map[aId] = nil
	table.remove(dData.list, endIdx)
end

--升段时如果DB延时会导致回本服拿到的还是旧段位，导致匹配信息重复，因此添加一个Tbl确保每个玩家匹配信息只有1份
function initDanCountTbl()
	if not System.isBattleSrv() then return end

	local sysVar = cstiantisys.getSysStaticVar()
	local danData = sysVar.danData
	sysVar.danCountTbl = {}
	local danCountTbl = sysVar.danCountTbl
	for dan = 1, #CsttDanConfig do
		local data = danData[dan]
		repeat
			if not data or not data.map or not data.list then break end
			for aId in pairs(data.map) do
				danCountTbl[aId] = (danCountTbl[aId] or 0) + 1
			end
		until true
	end
end

function addDanCount(aId)
	local sysVar = cstiantisys.getSysStaticVar()
	local danCountTbl = sysVar.danCountTbl
	danCountTbl[aId] = (danCountTbl[aId] or 0) + 1
end

function delDanCount(aId)
	local sysVar = cstiantisys.getSysStaticVar()
	local danCountTbl = sysVar.danCountTbl
	local num = (danCountTbl[aId] or 0) - 1
	if num <= 0 then
		danCountTbl[aId] = nil
	else
		danCountTbl[aId] = num
	end
end

--删除段位表里除aDan外其他段的aId的数据
function delRepeatSegment(aId, aDan)
	local sysVar = cstiantisys.getSysStaticVar()
	local danData = sysVar.danData
	for dan = 1, #CsttDanConfig do
		local data = danData[dan]
		repeat
			if aDan == dan or not data or not data.map or not data.list then break end
			if data.map[aId] then
				delActorToDanList(aId, dan)
			end
		until true
	end
end
----------------------------------------------

function clearDanList()
	local sysVar = cstiantisys.getSysStaticVar()
	sysVar.danData = {}
end

--通过玩家ID获取玩家匹配用的段位信息
function getADanInfo(dan, aId)
	local dData = getDanList(dan)
	if not dData.map or not dData.list then return nil end
	return dData.map[aId]
end

--通过序列ID获取玩家匹配用的段位信息
function getADanInfoById(dan, id)
	local dData = getDanList(dan)
	if not dData.map or not dData.list then return nil end
	local aId = dData.list[id] or 0
	return dData.map[aId]
end

--获取当前段位的人数
function getADanCount(dan)
	local dData = getDanList(dan)
	if not dData.map or not dData.list then return 0 end
	return #dData.list
end

local function getSysDyanmicVar()
	local var = System.getDyanmicVar()
	if var.csTianTiSegment == nil then
		var.csTianTiSegment = {}
		var.csTianTiSegment.pkInfoList = {} --正在挑战中的玩家
	end
	return var.csTianTiSegment
end

function getPKList()
	local dVar = getSysDyanmicVar()
	return dVar.pkInfoList
end

function getPkInfo(aId)
	local list = getPKList()
	return list[aId]
end

function addPKInfo(aId, mInfo)
	local list = getPKList()
	list[aId] = mInfo
end

function delPKInfo(aId)
	local list = getPKList()
	list[aId] = nil
end

-- function asynRoleEnterFB(target, aId, hfb)
-- 	local res = cstiantifb.imageEnterFb(target, hfb)
-- 	if res then
-- 		local mInfo = getPkInfo(aId)
-- 		if not mInfo then
-- 			return
-- 		end
-- 		mInfo.state = csTianTi.msWaitActor
-- 		a2sMatchRes(mInfo.sId, 1, mInfo)
-- 	else
-- 		delPKInfo(aId)
-- 		a2sMatchRes(mInfo.sId, 0, mInfo)
-- 	end
-- end

--匹配对手
function matchRole(sId, aId, dan)
	local mInfo = {
		aId = aId, sId = sId, tSid = 0, tAid = 0, tName = "",
		dan = 0, hfb = 0, state = csTianTi.msWaitImage,
		job=0, lvl=0,
	}
	local sysVar = cstiantisys.getSysStaticVar()
	local conf = CsttControlConfig[sysVar.stage]
	if not conf or conf.type ~= csTianTi.csStar then --未开放挑战
		print("not open")
		a2sMatchRes(sId, 0, mInfo)
		return
	end

	if getPkInfo(aId) then --正在挑战中
		print("now fighting")
		a2sMatchRes(sId, 0, mInfo)
		return
	end

	local rank = cstiantirankmgr.getScoreRank()
	local tarId = 0
	--把积分排行榜前后二十位的玩家放入idxList，再随机出一个
	if rank then
		local idx = Ranking.getItemIndexFromId(rank, aId) --积分排名
		local danConf = CsttDanConfig[dan]
		local idxList = {}
		if idx >= 0 then
			local endIdx = idx - danConf.beforeCount --匹配前面的玩家数量
			endIdx = endIdx >= 0 and endIdx or 0
			for i=idx-1, endIdx, -1 do
				table.insert(idxList, i)
			end

			endIdx = idx + danConf.afterCount --匹配后面的玩家数量
			local totalCount = Ranking.getRankItemCount(rank)
			endIdx = endIdx >= totalCount-1 and totalCount-1 or endIdx

			for i=idx+1, endIdx do
				table.insert(idxList, i)
			end

			if #idxList > 0 then
				local rIdx = math.random(1, #idxList)
				local item = Ranking.getItemFromIndex(rank, (idxList[rIdx]) or -1)
				if item then
					tarId = Ranking.getId(item)
					dan = Ranking.getSubInt(item, 0)
				end
				utils.printInfo("#### matchRole", #idxList, rIdx, item)
			end
		end
	end

	local isFindActor = false
	if tarId ~= 0 then
		local item = getADanInfo(dan, tarId)
		utils.printInfo("#### find actor", tarId, item)
		if item then
			mInfo.tSid = item.sId
			mInfo.tAid = item.aId
			mInfo.tName = item.aName
			mInfo.dan = item.dan
			mInfo.job = item.job
			mInfo.lvl = item.lvl
			cstiantifb.setRivalId(aId, tarId)
			isFindActor = true
		end
	end
	if not isFindActor then --没找到合适对手，用机器人
		tarId = math.random(1,#CSTianTiRobotConfig)
		utils.printInfo("#### find robot", tarId)
		local conf = CSTianTiRobotConfig[tarId][0]
		mInfo.tSid = sId
		mInfo.tAid = tarId
		mInfo.tName = conf.name
		mInfo.dan = conf.TianTiDan
		mInfo.job = conf.job
		mInfo.lvl = conf.level
		cstiantifb.setRivalId(aId, tarId)
	end
	local ins = cstiantifb.createBattlefield()
	if ins then
		mInfo.hfb = ins.handle

		local roleCloneDatas = nil
		local damonData = nil
		local roleSuperData = nil
		if not isFindActor then --机器人处理
			roleCloneDatas, damonData, roleSuperData = actorcommon.createRobotClone(CSTianTiRobotConfig, tarId)
			cstiantifb.setCloneData(roleCloneDatas, damonData, roleSuperData)
			cstiantifb.fubenCreateClone(tarId, ins, roleCloneDatas, damonData, roleSuperData)
		else  --玩家的处理
			roleCloneDatas, damonData, roleSuperData = actorcommon.getCloneData(mInfo.tAid)
			if roleCloneDatas then		
				cstiantifb.setCloneData(roleCloneDatas, damonData, roleSuperData)
				cstiantifb.fubenCreateClone(tarId, ins, roleCloneDatas, damonData, roleSuperData)
			else --跨服没有离线数据就去请求普通服发过来
				a2sGetCloneInfo(mInfo.tSid, tarId, mInfo.hfb) 
			end
		end

		addPKInfo(aId, mInfo)
		mInfo.state = csTianTi.msWaitActor
		a2sMatchRes(sId, 1, mInfo)
		--asynevent.csReg(mInfo.tAid, asynRoleEnterFB, mInfo.tSid, aId, ins.handle)
	else
		print("Fail to create cstt fuben")
		a2sMatchRes(sId, 0, mInfo)
	end
end

----------------------------------------------------------------------------------
--跨服收到普通服发来的玩家信息
function s4aSyncActorInfo(sId, sType, dp)
	if not System.isBattleSrv() then return end

	local aId = LDataPack.readInt(dp)
	local aName = LDataPack.readString(dp)
	local dan = LDataPack.readInt(dp)
	local score = LDataPack.readInt(dp)

	local job = LDataPack.readChar(dp)
	local lvl = LDataPack.readInt(dp)
	--sId 存在着0的情况，导致镜像找不到，因此把 sId 也发过来
	local sId = LDataPack.readInt(dp)
	--同一个actor是添加不进去的
	addActorToDanList(aId, aName, sId, dan, job, lvl)
	cstiantirankmgr.actorChangeScore(aId, score, dan)
	local sysVar = cstiantisys.getSysStaticVar()
	if sysVar.serverActors[sId] == nil then
		sysVar.serverActors[sId] = {}
	end
	sysVar.serverActors[sId][aId] = dan
end

--普通服向跨服请求匹配
function s2aReqMatch(actor, tId, dan)
	if not System.isCommSrv() then return end
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_ReqMatch)
	LDataPack.writeInt(pack, LActor.getActorId(actor))
	LDataPack.writeInt(pack, dan)
	System.sendPacketToAllGameClient(pack, tId)
end

--跨服收到普通服的匹配请求
function s4aReqMatch(sId, sType, dp)
	if not System.isBattleSrv() then return end
	local aId = LDataPack.readInt(dp)
	local dan = LDataPack.readInt(dp)
	matchRole(sId, aId, dan)
end

--跨服收到普通服的删除匹配
function s4aDelMatch(sId, sType, dp)
	if not System.isBattleSrv() then return end
	local aId = LDataPack.readInt(dp)
	local flag = LDataPack.readInt(dp)
	delPKInfo(aId)
end

--普通服向跨服发送第一名登录信息
function s2aCsttFirstLogin(actor)
	if not System.isCommSrv() then return end
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_FirstDanLogin)

	LDataPack.writeString(pack, LActor.getName(actor))
	System.sendPacketToAllGameClient(pack, csbase.getCrossServerId())
end

--跨服收到普通服的第一名登录信息
function s4aCsttFirstLogin(sId, sType, dp)
	if not System.isBattleSrv() then return end
	local aName = LDataPack.readString(dp)
	sendCsttNotice(csTianTi.bcType5, sId, aName, 0)
end

--发送多服跨服天梯广播
function sendCsttNotice(bcType, sId, aName, value)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_DanAnno)
	LDataPack.writeInt(pack, bcType)
	LDataPack.writeInt(pack, sId)
	LDataPack.writeString(pack, aName)
	LDataPack.writeInt(pack, value or 0)
	System.sendPacketToAllGameClient(pack, 0)
end

--跨服与普通服都收到公告请求
function onDanAnno(sId, sType, dp)
	if not cstianticontrol.checkCommSrvSysIsOpen() then return end
	local pos = LDataPack.getPosition(dp)
	local annoType = LDataPack.readInt(dp)
	local rsId = LDataPack.readInt(dp)
	local aName = LDataPack.readString(dp)

	if annoType == csTianTi.bcType1 then
		local wins = LDataPack.readInt(dp)
		--xxx[xx服]在跨服天梯联赛中大杀四方达到n连胜，成就霸绝天下！
		noticesystem.broadCastNotice(noticesystem.NTP.cstt1, rsId, aName, wins)
	elseif annoType == csTianTi.bcType2 then
		--xxx[xx服]在跨服天梯联赛中达到XXXXXX，问鼎巅峰独孤求败！
		local showDan = LDataPack.readInt(dp)
		local danConf = CsttDanConfig[showDan]
		noticesystem.broadCastNotice(noticesystem.NTP.cstt2, rsId, aName, danConf.name)
	elseif annoType == csTianTi.bcType3 then
		--xxx[xx服]在跨服天梯联赛中首个达成XXXX，全服排名第1，试问谁能超越！
		local showDan = LDataPack.readInt(dp)
		local danConf = CsttDanConfig[showDan]
		noticesystem.broadCastNotice(noticesystem.NTP.cstt3, rsId, aName, danConf.name)
	elseif annoType == csTianTi.bcType4 then
		--xxx[xx服]在跨服天梯联赛击败强敌夺下全服第1，试问谁能超越！
		noticesystem.broadCastNotice(noticesystem.NTP.cstt4, rsId, aName)
	elseif annoType == csTianTi.bcType5 then
		--天梯联赛巅峰王者xxx[xx服]上线了，全民顶礼膜拜!
		--if System.isCommSrv() then return end
		noticesystem.broadCastNotice(noticesystem.NTP.cstt5, aName, rsId)
	end
end

--跨服向普通服发送匹配对象
function a2sMatchRes(sId, res, info)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_RetMatchInfo)

	LDataPack.writeChar(pack, res)
	LDataPack.writeInt(pack, info.aId)
	LDataPack.writeInt(pack, info.tSid)
	LDataPack.writeInt(pack, info.tAid)
	LDataPack.writeString(pack, info.tName)
	LDataPack.writeInt(pack, info.dan)
	LDataPack.writeInt64(pack, info.hfb)
	LDataPack.writeChar(pack, info.job)
	LDataPack.writeInt(pack, info.lvl)

	System.sendPacketToAllGameClient(pack, sId)
end

--普通服收到跨服返回的匹配对象
function a4sReqMatch(sId, sType, dp)
	if not System.isCommSrv() then return end
	local res = LDataPack.readChar(dp)
	local aId = LDataPack.readInt(dp)
	local tSid = LDataPack.readInt(dp)
	local tAid = LDataPack.readInt(dp)
	local tName = LDataPack.readString(dp)
	local dan = LDataPack.readInt(dp)
	local hfb = LDataPack.readInt64(dp)
	local job = LDataPack.readChar(dp)
	local lvl = LDataPack.readInt(dp)

	local actor = LActor.getActorById(aId)
	if actor then
		local mInfo = cstiantisys.getTarget(actor)
		if res == 1 then
			mInfo.tId = tAid
			mInfo.hfb = hfb
			cstiantifb.changeChallengeNum(actor)
		else
			--清除匹配状态和记录匹配失败
			cstiantisys.resetMatchInfo(actor)
		end
		s2cReqMatch(actor, res, tName, tSid, dan, job, lvl)
	end
end

--跨服向普通服发送获取玩家离线信息的请求
function a2sGetCloneInfo(sId, aId, hfb)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_GetCloneInfo)
	LDataPack.writeInt(pack, aId)
	LDataPack.writeInt64(pack, hfb)
	System.sendPacketToAllGameClient(pack, sId)
end

--普通服收到跨服的玩家离线数据请求
function getCloneInfo(sId, sType, dp)
	if not System.isCommSrv() then return end
	local actorId = LDataPack.readInt(dp)
	local fbHandle = LDataPack.readInt64(dp)
	local actor = LActor.getActorById(actorId)

	if actor then--先暴力处理
		offlinedatamgr.CallEhLogout(actor) --保存离线数据
	end

	local actorData = offlinedatamgr.GetDataByOffLineDataType(actorId, offlinedatamgr.EOffLineDataType.EBasic)
	local roleDatas = offlinedatamgr.GetDataByOffLineDataType(actorId, offlinedatamgr.EOffLineDataType.ERoles)
	if actorData==nil or roleDatas==nil then
		local pack = LDataPack.allocPacket()
		if pack == nil then return end
		LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_RetCloneInfo)
		LDataPack.writeInt(pack, actorId)
		LDataPack.writeInt64(pack, fbHandle)
		LDataPack.writeUserData(pack, bson.encode({}))
		LDataPack.writeUserData(pack, bson.encode({}))

		System.sendPacketToAllGameClient(pack, sId)
		return
	end
	local actorDataUd = bson.encode(actorData)
	local roleDatasUd = bson.encode(roleDatas)

	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCTianTiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCTianTiCmd_RetCloneInfo)
	LDataPack.writeInt(pack, actorId)
	LDataPack.writeInt64(pack, fbHandle)
	LDataPack.writeUserData(pack, actorDataUd)
	LDataPack.writeUserData(pack, roleDatasUd)

	System.sendPacketToAllGameClient(pack, sId)
end

--跨服收到普通服发的玩家离线数据
function retCloneInfo(sId, sType, dp)
	if System.isCommSrv() then return end
	local actorId = LDataPack.readInt(dp)
	local fbHandle = LDataPack.readInt64(dp)
	local actorDataUd = LDataPack.readUserData(dp)
	local roleDatasUd = LDataPack.readUserData(dp)

	local actorData = bson.decode(actorDataUd)
	local roleDatas = bson.decode(roleDatasUd)

	local roleCloneDatas = nil
	local damonData = nil
	local roleSuperData = nil
	roleCloneDatas, damonData, roleSuperData = actorcommon.getCloneDataByOffLineData(actorData, roleDatas)
	local ins = instancesystem.getInsByHdl(fbHandle)
	if not ins then utils.printInfo("Error not ins on cstt", actorId, fbHandle) return end
	if roleCloneDatas then
		cstiantifb.setCloneData(roleCloneDatas, damonData, roleSuperData)
	else 
		roleCloneDatas, damonData, roleSuperData = actorcommon.createRobotClone(CSTianTiRobotConfig, 1)
		cstiantifb.setCloneData(roleCloneDatas, damonData, roleSuperData)
	end
	cstiantifb.fubenCreateClone(actorId, ins, roleCloneDatas, damonData, roleSuperData)
end

-----------------------------------------------------------------------------
--服务端下发匹配信息
function s2cReqMatch(actor, res, tName, tSid, dan, job, lvl)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsTianti_Matching)
	if npack == nil then return end
	LDataPack.writeChar(npack, res)
	LDataPack.writeString(npack, tName)
	LDataPack.writeInt(npack, tSid)
	LDataPack.writeInt(npack, dan)
	LDataPack.writeChar(npack, job)
	LDataPack.writeInt(npack, lvl)
	LDataPack.flush(npack)
end


--普通服断开了
function OnDisConnToCrossServer(serverId, serverType)
	if not System.isBattleSrv() then return end
	--要把一个服的所有玩家都从段位匹配表中删除

	local sysVar = cstiantisys.getSysStaticVar()
	local tbl = sysVar.serverActors[serverId] or {}
	for k,v in pairs(tbl) do
		delActorToDanList(k, v)
	end
	sysVar.serverActors[serverId] = {}
end


csbase.RegDisconnect(OnDisConnToCrossServer)
engineevent.regGameStartEvent(initDanCountTbl)

csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_SyncActor, s4aSyncActorInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_ReqMatch, s4aReqMatch)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_DelMatch, s4aDelMatch)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_DanAnno, onDanAnno)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_RetMatchInfo, a4sReqMatch)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_FirstDanLogin, s4aCsttFirstLogin)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_GetCloneInfo, getCloneInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCTianTiCmd, CrossSrvSubCmd.SCTianTiCmd_RetCloneInfo, retCloneInfo)

