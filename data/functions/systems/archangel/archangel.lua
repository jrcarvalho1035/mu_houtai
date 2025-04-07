-- --大天使系统
-- --@rancho 20170623
-- module("archangel", package.seeall)

-- local RankingType_Power = RankingType_Power

-- function getSystemVar()
-- 	local ssvar = System.getStaticVar()
-- 	if ssvar == nil then return end
-- 	if not ssvar.archangel then ssvar.archangel = {} end
-- 	local archangel = ssvar.archangel
-- 	if not archangel.rankDatas then archangel.rankDatas = {} end
-- 	local rankDatas = archangel.rankDatas
-- 	for i = 1, #ArchangelConfig do
-- 		local rankData = rankDatas[i]
-- 		if not rankData then
-- 			rankData = {}
-- 			rankData.actor_id = 0
-- 			rankData.actor_name = ""
-- 			rankData.actor_job = -1
-- 			rankDatas[i] = rankData
-- 		end
-- 	end
-- 	if not archangel.isfirst then archangel.isfirst = 0 end --是否执行首次开服第三天的结算

-- 	return archangel
-- end

-- function getActorVar(actor)
-- 	if not actor then return end

-- 	local asvar = LActor.getStaticVar(actor)
-- 	if not asvar then return end

-- 	if not asvar.archangel then asvar.archangel = {} end
-- 	local archangel = asvar.archangel
	
-- 	if not archangel.roleRankDatas then archangel.roleRankDatas = {} end
-- 	local roleRankDatas = archangel.roleRankDatas
	
-- 	for i = 1, 1 do
-- 		local roleRankData = roleRankDatas[i]
-- 		if not roleRankData then
-- 			roleRankData = {}
-- 			roleRankDatas[i] = roleRankData 
-- 		end
-- 		if not roleRankData.rankIndex then roleRankData.rankIndex = -1 end
-- 		if not roleRankData.showModel then roleRankData.showModel = 0 end
-- 	end

-- 	return archangel
-- end

-- function getActorCrossVar(actor)
-- 	local cvar = LActor.getCrossVar(actor)
-- 	if not cvar.archangeldata then
-- 		cvar.archangeldata = {
-- 			arcId = 0,
-- 		}
-- 	end
-- 	return cvar.archangeldata
-- end

-- function checkRankType(rId)
-- 	if rId == RankingType_Power then
-- 		return true
-- 	end
-- 	return false
-- end

-- local function getDayDiffForWeek(week1, week2)
-- 	--print("开启公会战2")
-- 	local tmpNum = 0
-- 	for i=1, 7 do
-- 		week1 = math.floor((week1 + 7 +1) % 7)
-- 		tmpNum = tmpNum + 1
-- 		if week1 == week2 then
-- 			break
-- 		end
-- 	end
-- 	return tmpNum
-- end

-- function getNextRemain()
-- 	local osTime = System.getOpenServerStartDateTime()
-- 	local now_t = System.getNowTime()
	
-- 	local osDay = System.getOpenServerDay() + 1
-- 	local ogTime = 0
-- 	local open = {}
-- 	for _, info in ipairs(TimerConfig) do		
-- 		if info.func == "updateArchangel1" then
-- 			ogTime = osTime + (((info.day - 1) * 86400) + info.hour * 60 * 60) + info.minute * 60
-- 		end
-- 		if info.func == "updateArchangel" then
-- 			open.week = info.week
-- 			open.hour = info.hour
-- 			open.minute = info.minute
-- 		end
-- 	end	
-- 	if osDay <= 7 then		
-- 		if now_t < ogTime then
-- 			return ogTime - now_t
-- 		else
-- 			local year, month, day, hour, minute, sec = 0, 0, 0, 0, 0, 0
-- 			year, month, day, hour, minute, sec = System.timeDecode((osTime + (7 - 1) * 86400), year, month, day, hour, minute, sec)
-- 			local tmpWeek = System.getWeekDataTime(year, month, day)
-- 			local tmpNum = getDayDiffForWeek(tmpWeek, open.week)
-- 			return osTime + (7-1) * 86400 + (tmpNum * 86400) + (open.hour * 60 * 60) + (open.minute * 60) - now_t			
-- 		end
-- 	end
-- 	--同一天
-- 	local wDay = System.getDayOfWeek()
-- 	local todayDateTime = System.getToday()
-- 	local todayOpenTime = todayDateTime + (open.hour * 60 * 60) + (open.minute * 60)
-- 	if wDay == open.week and  now_t < todayOpenTime then
-- 		return todayOpenTime - now_t
-- 	end
-- 	--非同一天
-- 	local tmpNum = getDayDiffForWeek(wDay, open.week)
-- 	return todayDateTime + tmpNum * 86400 + (open.hour * 60 * 60) + (open.minute * 60) - now_t
-- end

-- function sendArchangelInfo(actor)
-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_ArchangelInfo)
-- 	if not pack then return end

-- 	local ssvar = getSystemVar()
-- 	if ssvar == nil then return end

-- 	local rankDatas = ssvar.rankDatas
-- 	local rankCount = #rankDatas
-- 	LDataPack.writeByte(pack, rankCount)
-- 	for i = 1, rankCount do
-- 		local rankData = rankDatas[i]
-- 		LDataPack.writeInt(pack, rankData.actor_id)
-- 		LDataPack.writeString(pack, rankData.actor_name)
-- 		LDataPack.writeByte(pack, rankData.actor_job)
-- 	end
	
-- 	local asvar = getActorVar(actor)
-- 	local roleRankDatas = asvar.roleRankDatas
-- 	local roleRankCount = #roleRankDatas
-- 	LDataPack.writeByte(pack, roleRankCount)
-- 	for i = 1, roleRankCount do
-- 		local roleRankData = roleRankDatas[i]
-- 		LDataPack.writeByte(pack, roleRankData.rankIndex == -1 and 0 or 1)
-- 		LDataPack.writeByte(pack, roleRankData.showModel)
-- 	end
-- 	local time = getNextRemain()
-- 	LDataPack.writeInt(pack, time)

-- 	LDataPack.flush(pack)
-- end

-- function handleChangeModel(actor, pack)
-- 	if System.isBattleSrv() then return end
-- 	local roleId = LDataPack.readByte(pack)
-- 	local showModel = LDataPack.readByte(pack)

-- 	local asvar = getActorVar(actor)
-- 	local roleRankDatas = asvar.roleRankDatas
-- 	local roleRankCount = #roleRankDatas

-- 	if (roleId + 1) <= 0 or (roleId + 1) > roleRankCount then return end
-- 	if showModel < 0 or showModel > 1 then return end

-- 	local roleRankData = roleRankDatas[roleId + 1]
-- 	if roleRankData.rankIndex == -1 then return end
-- 	if roleRankData.showModel == showModel then return end

-- 	roleRankData.showModel = showModel

-- 	local sendPack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_ResChangeArchangelModel)
-- 	if not sendPack then return end
-- 	LDataPack.writeByte(sendPack, roleId)
-- 	LDataPack.writeByte(sendPack, roleRankData.rankIndex == -1 and 0 or 1)
-- 	LDataPack.writeByte(sendPack, roleRankData.showModel)
-- 	LDataPack.flush(sendPack)
-- 	LActor.RefreshArchangel(actor)
-- 	--刷新外观
-- 	actorevent.onEvent(actor, aeNotifyFacade, roleId)
-- end

-- function resetArchangel(actor)
-- 	local roleId = 0

-- 	local asvar = getActorVar(actor)
-- 	if asvar == nil then return end
-- 	local roleRankData = asvar.roleRankDatas[roleId + 1]
-- 	if roleRankData == nil then return end
-- 	roleRankData.rankIndex = -1
-- 	roleRankData.showModel = 0
-- end

-- function clearArchangel(actor)
-- 	local roleId = 0

-- 	--设置玩家数据
-- 	local asvar = getActorVar(actor)
-- 	if asvar == nil then return end
-- 	local roleRankData = asvar.roleRankDatas[roleId + 1]
-- 	if roleRankData == nil then return end
-- 	roleRankData.rankIndex = -1
-- 	roleRankData.showModel = 0

-- 	--获取属性
-- 	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Archangel)
-- 	if attr == nil then return end
-- 	--清空属性
-- 	attr:Reset()
-- 	LActor.reCalcAttr(actor, roleId)

-- 	--刷新外观
-- 	actorevent.onEvent(actor, aeNotifyFacade, roleId)
-- end

-- function addArchangel(actor, i, calc)
-- 	local roleId = 0

-- 	local asvar = getActorVar(actor)
-- 	if asvar == nil then return end
-- 	local roleRankData = asvar.roleRankDatas[roleId + 1]
-- 	if roleRankData == nil then return end
-- 	roleRankData.rankIndex = i


-- 	--属性
-- 	local roleData = LActor.getRoleData(actor)
-- 	if not roleData then return end
-- 	local job = roleData.job
-- 	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Archangel)
-- 	if attr == nil then return end
-- 	attr:Reset()
-- 	local equipId = ArchangelConfig[i][job].equipid
-- 	local attrConf = equipsystem.getEquipConfigAttrs(equipId)
-- 	if attrConf == nil then return end
-- 	for k,v in pairs(attrConf) do
-- 		if v > 0 then
-- 			attr:Set(k, v)
-- 		end
-- 	end
-- 	if calc then
-- 		LActor.reCalcAttr(actor, roleId)
-- 	end
-- end

-- --更新属性
-- local function updateAttr(actor, roleId, calc)
-- 	local roleData = LActor.getRoleData(actor)
-- 	if not roleData then return end
-- 	local job = roleData.job
-- 	local cvar = getActorCrossVar(actor)
-- 	if not ArchangelConfig[cvar.arcId] then return end
-- 	local equipId = ArchangelConfig[cvar.arcId][job].equipid
-- 	local attrConf = equipsystem.getEquipConfigAttrs(equipId)
-- 	if attrConf == nil then return end
-- 	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Archangel)
-- 	if attr == nil then return end
-- 	attr:Reset()
-- 	for k,v in pairs(attrConf) do
-- 		if v > 0 then
-- 			attr:Set(k, v)
-- 		end
-- 	end
-- 	if calc then
-- 		LActor.reCalcAttr(actor, roleId)
-- 	end
-- end


-- function sRankUpdateBefore(rId)
	
-- end

-- function sRankUpdateAfter(rId)
-- 	print("sRankUpdateAfter rId:" .. rId)
-- 	if not checkRankType(rId) then return end
-- 	local ssvar = getSystemVar()
-- 	if ssvar == nil then return end

-- 	local rank = Ranking.getStaticRank(rId)
-- 	if rank == nil then return end
	
-- 	--粗暴点，先删后增
-- 	local rankDatas = ssvar.rankDatas
-- 	for i = 1, #rankDatas do
-- 		local rankData = rankDatas[i]
-- 		local oldActorId = rankData.actor_id
-- 		local oldActor = LActor.getActorById(oldActorId)
-- 		if oldActor then
-- 			clearArchangel(oldActor, i)
-- 		else
-- 			offlinedatamgr.DelArchangelEquipId(oldActorId, i)
-- 		end
-- 	end

-- 	for i = 1, #ArchangelConfig do
-- 		local actorData = Ranking.getSDataFromIdx(rank, i - 1)
-- 		if actorData then
-- 			local curActorId = actorData.actor_id
-- 			local curActor= LActor.getActorById(curActorId)
-- 			if curActor then
-- 				addArchangel(curActor, i, true)
-- 			end
-- 			local rankData = rankDatas[i]
-- 			rankData.actor_id = curActorId
-- 			rankData.actor_name = actorData.actor_name
-- 			rankData.actor_job = actorData.job

-- 			local logStr = "archangel i:%d, actor_id:%d, actor_name:%s, actor_job:%d, actor_power:%d"
-- 			print(string.format(logStr, i, rankData.actor_id, rankData.actor_name, rankData.actor_job, actorData.total_power))
-- 		end
-- 	end
-- end

-- function BroadCastArchangel( ... )
-- 	local actors = System.getOnlineActorList()
-- 	if actors == nil then return end
-- 	for i = 1, #actors do
-- 		local actor = actors[i]
-- 		if actor then
-- 			sendArchangelInfo(actor)
-- 		end
-- 	end
-- end

-- function updateArchangel( ... )
-- 	if System.isBattleSrv() then return end
-- 	if not actorexp.checkLevelCondition1(actorexp.LimitTp.archangel) then return end

-- 	local ssvar = getSystemVar()
-- 	if ssvar.isfirst == 0 then
-- 		return
-- 	end
	
-- 	local osDay = System.getOpenServerDay() + 1
-- 	if osDay <= 7 then
-- 		return
-- 	end

-- 	sRankUpdateAfter(RankingType_Power)
-- 	BroadCastArchangel()
-- 	utils.rankfunc.updateStaticFirstCache()
-- end

-- --第一次计算必定是开服三天的结算
-- function updateArchangel1(...)
-- 	local ssvar = getSystemVar()
-- 	ssvar.isfirst = 1

-- 	sRankUpdateAfter(RankingType_Power)
-- 	BroadCastArchangel()
-- 	utils.rankfunc.updateStaticFirstCache()
-- end

-- function getRoleArchangelEquipId(actor, roleId)
-- 	if System.isBattleSrv() then return 0 end

-- 	if xuese.checkShow(actor) == 1 then
-- 		local roleData = LActor.getRoleData(actor)
-- 		if not roleData then return 0 end
-- 		return ArchangelConfig[1][roleData.job].equipid
-- 	end

-- 	local asvar = getActorVar(actor)
-- 	local roleRankDatas = asvar.roleRankDatas
-- 	local roleRankData = roleRankDatas[roleId + 1]
-- 	if roleRankData == nil then return 0 end
-- 	if roleRankData.rankIndex == -1 then return 0 end
-- 	if roleRankData.showModel == 1 then
-- 		local roleData = LActor.getRoleData(actor)
-- 		if not roleData then return 0 end
-- 		return ArchangelConfig[roleRankData.rankIndex][roleData.job].equipid
-- 	else		
-- 		return 0
-- 	end
-- end

-- function ehInit(actor, arg)
-- 	--普通服时记录下大天使武器的名次，在跨服时直接使用记录下的大天使名次属性
-- 	if System.isCommSrv() then 
-- 		local actorid = LActor.getActorId(actor)
-- 		local  ssvar = getSystemVar()
-- 		if ssvar == nil then return end
-- 		local rankDatas = ssvar.rankDatas
-- 		local isIn = false
-- 		local cvar = getActorCrossVar(actor)
-- 		for i, rankData in ipairs(rankDatas) do
-- 			if actorid == rankData.actor_id then
-- 				cvar.arcId = i --记录下跨服的大天使武器
-- 				addArchangel(actor, i, false)
-- 				isIn = true
-- 			end
-- 		end
-- 		if not isIn then
-- 			resetArchangel(actor)
-- 			cvar.arcId = 0
-- 		end
-- 	else
-- 		updateAttr(actor, 0, false)
-- 	end
-- end

-- -- function ehLogin(actor, arg)
-- -- 	if System.isBattleSrv() then return end
-- -- 	sendArchangelInfo(actor)
-- -- end

-- _G.updateArchangel1 = updateArchangel1
-- _G.updateArchangel = updateArchangel
-- _G.getRoleArchangelEquipId = getRoleArchangelEquipId



-- onChangeName = function(actor, res, name, rawName, way)
-- 	local ssvar = getSystemVar()
-- 	if ssvar == nil then return end
-- 	local rankDatas = ssvar.rankDatas
-- 	local rankCount = #rankDatas
-- 	for i = 1, rankCount do
-- 		if rankDatas[i].actor_name == rawName then
-- 			rankDatas[i].actor_name = name
-- 		end
-- 	end
-- end

-- -- actorevent.reg(aeChangeName, onChangeName)
-- -- actorevent.reg(aeInit, ehInit)
-- -- actorevent.reg(aeUserLogin, ehLogin)

-- netmsgdispatcher.reg(Protocol.CMD_Ranking, Protocol.cRankingCmd_ReqChangeArchangelModel, handleChangeModel)

-- --GM
-- local gmCmdHandlers = gmsystem.gmCmdHandlers
-- gmCmdHandlers.updatearc = function (actor, arg)
-- 	updateArchangel()
-- 	return true
-- end
