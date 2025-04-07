module("cstiantirankmgr" , package.seeall)
--跨服天梯所有排行榜的管理

local P = Protocol
local cmd = CrossSrvCmd
local subCmd = CrossSrvSubCmd
local def = csTianTi

local SECOND = 10 --排行榜刷新CD
local CACHE_LEN = 3
local LAST_CS_RANK_INDEX = 1 --上一届跨服排行榜索引
local LAST_COM_RANK_INDEX = 2	--上一届普通服排行榜索引


--找上一届排行榜
function getPreviousRank()
	local dvar = cstiantifb.getSystemVar()
	local preSeason = dvar.preSeason
	if preSeason == 0 then return end
	return getWinpoingRank(preSeason)
end


--根据赛季获取赛季排行榜
function getWinpoingRank(season)
	if season == 0 then return end

	local rankName = string.format(def.winpointRankName, season, CsttComConfig.firstDan)
	local rank = Ranking.getRanking(rankName)
	if rank then return rank end

	local rankFile = string.format(def.winpointRankFile, season, CsttComConfig.firstDan)
	rank = utils.rankfunc.InitRank(rankName, rankFile, def.rankingListMaxSize, def.winpointRankColumns, true)
	Ranking.setAutoSave(rank, true)
	
	return rank
end

--根据赛季获取每日胜点排行榜
function getDailyWinpointRank(season)
	if season == 0 then return end

	local rankName = string.format(def.dailyWinpointRankName, season)
	local rank = Ranking.getRanking(rankName)
	if rank then return rank end

	local rankFile = string.format(def.dailyWinpointRankFile, season)
	if System.isCommSrv() then
		--普通服不保存，每次启动请求跨服获取
		rank = utils.rankfunc.InitRank(rankName, rankFile, def.rankingListMaxSize, def.winpointRankColumns, false)
		Ranking.setAutoSave(rank, false)
	else
		rank = utils.rankfunc.InitRank(rankName, rankFile, def.rankingListMaxSize, def.winpointRankColumns, true)
		Ranking.setAutoSave(rank, true)
	end
	return rank
end

--获取赛季排行榜排名
function getNowRank(actor)
	local sysVar = cstiantisys.getSysStaticVar()
	local rank = getWinpoingRank(sysVar.session)
	if not rank then return 0 end
	local index = Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
	-- if index >= def.totalRankingBroadSize then
	-- 	return 0
	-- end
	return index
end

--获取上届排行榜第一 item
function getPreRankFirstItem()
	local rank = getPreviousRank()
	if not rank then return end
	return Ranking.getItemFromIndex(rank, 0)
end

function releaseRankingList()
	local sysVar = cstiantisys.getSysStaticVar()
	local rank = getWinpoingRank(sysVar.session)
	if rank then
		local rankFile = string.format(def.winpointRankFile, sysVar.session, CsttComConfig.firstDan)
		Ranking.save(rank, rankFile)
		Ranking.release(rank)
	end
	local drank = getDailyWinpointRank(sysVar.session)
	if drank and not System.isCommSrv() then
		local rankFile = string.format(def.dailyWinpointRankFile, sysVar.session)
	    Ranking.save(drank, rankFile)
	    Ranking.release(drank)
	end
	local sRank = getScoreRank()
	if sRank and not System.isCommSrv() then
		Ranking.save(sRank, def.srFile)
		Ranking.release(sRank)
	end
end

--获取玩家积分排行榜
function getScoreRank()
	local rName = def.srName
	local rank = Ranking.getRanking(rName)
	if rank then return rank end

	rank = utils.rankfunc.InitRank(rName, def.srFile, def.srMaxSize, def.srColumns, true)
	Ranking.setAutoSave(rank, true)
	
	return rank
end

--更新积分排行榜
function actorChangeScore(aId, score, dan)
	if aId == nil or aId == 0 then return end

	local rank = getScoreRank()
	if not rank then return end
	
	local item = Ranking.getItemPtrFromId(rank, aId)
	if item then
		item = Ranking.setItem(rank, aId, score)
	else
		item = Ranking.addItem(rank, aId, score)
	end
	Ranking.setSubInt(item, 0, dan)
end

function clearScoreRank()
	local rank = getScoreRank()
	Ranking.clearRanking(rank)
	Ranking.save(rank, def.srFile)
end

--更新赛季排行榜
function updateWinpointRank(actor)
	if not System.isBattleSrv() then return end
	local actorId = LActor.getActorId(actor)
	local sysVar = cstiantisys.getSysStaticVar()
	local cvar = cstiantifb.getActorCrossVar(actor)
	local var = cstiantisys.getVar(actor)
	local nowDanConf = CsttDanConfig[var.dan]
	local preDanConf = CsttDanConfig[cvar.preDan]
	local rank = getWinpoingRank(sysVar.session)
	if not rank then return end

	local srvId = LActor.getServerId(actor)
	local actorName = LActor.getName(actor)
	if nowDanConf.danRange < CsttComConfig.firstDan then --最低那个段位不上榜
		if preDanConf.danRange == CsttComConfig.firstDan then
			--退出总榜
			local item = Ranking.getItemPtrFromId(rank, actorId)
			if item then
				Ranking.removeId(rank, actorId)
			end
		end
		sendWinpointRank(0) --同步到普通服
	else
		local winPoint = cvar.winPoint
		utils.rankfunc.setRank(rank, actorId, winPoint, srvId, actorName, tostring(LActor.getActorPower(actorId)), var.dan)

		local now_sec = System.getNowTime()
		local sdvar = cstiantifb.getSystemDVar()
		if now_sec >= sdvar.tRankSec then
			sdvar.tRankSec = now_sec + SECOND
			sendWinpointRank(0) --同步到普通服
		end
	end
	updateTopThreeCache(actor, rank, srvId, actorName)--更新排行榜前三名形象缓存数据
end

--更新每日胜点排行榜
function updateDailyRank(actor, dailyWinpoint)
	local sysVar = cstiantisys.getSysStaticVar()
	local var = cstiantisys.getVar(actor)
	local rank = getDailyWinpointRank(sysVar.session)
	if not rank then return end

	local actorId = LActor.getActorId(actor)
	local power = tostring(LActor.getActorPower(actorId))
	utils.rankfunc.setRank(rank, actorId, dailyWinpoint, LActor.getServerId(actor), LActor.getName(actor), power, var.dan)

	local now_sec = System.getNowTime()
	local sdvar = cstiantifb.getSystemDVar()
	if now_sec >= sdvar.tDailyRankSec then
		sdvar.tDailyRankSec = now_sec + SECOND
		sendDailyWinpointRank(0)
	end
end

--更新排行榜前三名形象缓存数据
function updateTopThreeCache(actor, rank, serverId, actorName)
	local actorId = LActor.getActorId(actor)
	local index = Ranking.getItemIndexFromId(rank, actorId) + 1
	if index > CACHE_LEN then return end --排名超过5，不保存
	if index == 0 then
		--不在排行榜，检测是否缓存了数据，有的话则删除
		removeCacheData(actorId)
		return
	end

	local svar = cstiantifb.getSystemVar()
	local firTb = svar.topThreeCache[1] or {}
	local firId = firTb.actorId or 0
	if index == 1 and firId ~= 0 and firId ~= actorId then
		--第一变动广播
		cstiantisegment.sendCsttNotice(csTianTi.bcType4, serverId, actorName, 0)
	end

	removeCacheData(actorId)

	--保存形像信息
	local tb = {}
	local role = LActor.getRole(actor, 0)
	if not role then return end
	tb.actorId = actorId
	tb.job = LActor.getJob(role)
	tb.coat = LActor.getEquipId(role, EquipSlotType_Coat)
	tb.weapon = LActor.getEquipId(role, EquipSlotType_Weapon)
	local wingLevel, _, _, status = LActor.getWingInfo(actor, 0)
	tb.wingLevel = wingLevel
	tb.shineWeapon = LActor.getRoleShineWeapon(actor, 0)
	tb.shineArmor = LActor.getRoleShineArmor(actor, 0)
	tb.illusionWeaponId = 0
	tb.nirvanaWeap = nirvanasystem.getCrossNWeap(actor)
	tb.nirvanaCoat = nirvanasystem.getCrossNCoat(actor)
	tb.damonId = LActor.getDamonId(actor)
	table.insert(svar.topThreeCache, index, tb)
	local nlen = #svar.topThreeCache
	if nlen > CACHE_LEN then
		svar.topThreeCache[nlen] = nil
	end

	a2sTopThreeData(0) --向所有普通服发送展示数据
end

--删除缓存数据
function removeCacheData(actorId)
	local svar = cstiantifb.getSystemVar()
	local key
	for index, tb in ipairs(svar.topThreeCache) do
		if tb.actorId == actorId then
			key = index
			break
		end
	end
	if key then
		table.remove(svar.topThreeCache, key)
	end

	a2sTopThreeData(0)
end

--保存赛季排行榜
function saveRankingList()
	local sysVar = cstiantisys.getSysStaticVar()
	local rank = getWinpoingRank(sysVar.session)
	if rank then
		local rankFile = string.format(def.winpointRankFile, sysVar.session, CsttComConfig.firstDan)
		Ranking.save(rank, rankFile)
	end
end

--跨服同步赛季总排行榜到本服
function sendWinpointRank(serverId)
	a2sRankData(RankingType_CsttRank, serverId)
end

--跨服同步每日胜点排行榜到本服
function sendDailyWinpointRank(serverId)
	a2sRankData(RankingType_CsttDaily, serverId)
end

---------------------------------------------------------------------------------------
--跨服向普通服发送排行榜数据
function a2sRankData(rankType, serverId)
	if not System.isBattleSrv() then return end
	local sysVar = cstiantisys.getSysStaticVar()

	local csRank
	local broadSize = 0
	if rankType == RankingType_CsttRank then
		csRank = getWinpoingRank(sysVar.session)
		broadSize = def.totalRankingBroadSize
	elseif rankType == RankingType_CsttDaily then
		csRank = getDailyWinpointRank(sysVar.session)
		broadSize = def.dailyRankingBroadSize
	end

	if not csRank then return end

	local rankTb = Ranking.getRankingItemList(csRank, broadSize)
	if rankTb == nil then rankTb = {} end

	local pack = LDataPack.allocPacket()
	if not pack then return end

	LDataPack.writeByte(pack, cmd.SCTianTiCmd)
	LDataPack.writeByte(pack, subCmd.SCTianTiCmd_UpdateRankData)
	LDataPack.writeByte(pack, rankType)
	LDataPack.writeWord(pack, #rankTb)

	for _, item in ipairs(rankTb) do
		LDataPack.writeInt(pack, Ranking.getId(item))--id
		LDataPack.writeInt(pack, Ranking.getPoint(item))--胜点
		LDataPack.writeInt(pack, Ranking.getSubInt(item, 0))--服务器id
		LDataPack.writeString(pack, Ranking.getSub(item, 1))--名字
		LDataPack.writeInt64(pack, Ranking.getSubInt(item, 2))--战力
		LDataPack.writeInt(pack, Ranking.getSubInt(item, 3))--段位
	end

	System.sendPacketToAllGameClient(pack, serverId)
end

--普通服收到跨服的排行榜数据
function a4sRankData(serverId, sType, dp)
	if not System.isCommSrv() then return end
	local sysVar = cstiantisys.getSysStaticVar()
	local rankType = LDataPack.readByte(dp)

	local comRank
	if rankType == RankingType_CsttRank then
		comRank = getWinpoingRank(sysVar.session)
	elseif rankType == RankingType_CsttDaily then
		comRank = getDailyWinpointRank(sysVar.session)
	end
	if not comRank then return end

	--每次跨服同步排行榜数据时先把普通服排行榜数据清空
	Ranking.clearRanking(comRank)

	local rankLen = LDataPack.readWord(dp)
	for i = 1, rankLen do
		local actorId = LDataPack.readInt(dp)
		local winPoint = LDataPack.readInt(dp)
		local sId = LDataPack.readInt(dp)
		local name = LDataPack.readString(dp)
		local power = LDataPack.readInt64(dp)
		local dan = LDataPack.readInt(dp)
		utils.rankfunc.setRank(comRank, actorId, winPoint, sId, name, power, dan)
	end
end

--跨服同步前三名数据到普通服
function a2sTopThreeData(serverId)
	if not System.isBattleSrv() then return end
	local svar = cstiantifb.getSystemVar()
	local pack = LDataPack.allocPacket()
	if not pack then return end

	LDataPack.writeByte(pack, cmd.SCTianTiCmd)
	LDataPack.writeByte(pack, subCmd.SCTianTiCmd_UpdateTopThreeCache)
	writeTopThreeData(svar, pack)
	System.sendPacketToAllGameClient(pack, serverId)
end

function writeTopThreeData(var, pack)
	local topThreeCache = var.topThreeCache or {}
	local nlen = #topThreeCache
	if nlen > 3 then nlen = 3 end
	LDataPack.writeByte(pack, nlen)

	for i = 1, nlen do
		tb = topThreeCache[i]
		LDataPack.writeChar(pack, i)					--排名
		LDataPack.writeInt(pack, tb.actorId)			--actorId
		LDataPack.writeByte(pack, tb.job)				--职业
		LDataPack.writeInt(pack, tb.coat)				--衣服
		LDataPack.writeInt(pack, tb.weapon)				--武器
		LDataPack.writeInt(pack, tb.illusionWeaponId)	--幻化武器
		LDataPack.writeInt(pack, wingsystem.getWingIdByLevel(actor, tb.job, tb.wingLevel))
		LDataPack.writeByte(pack, tb.shineWeapon)		--武器发光
		LDataPack.writeByte(pack, tb.shineArmor)		--防具发光
		LDataPack.writeInt(pack, tb.damonId) 			--精灵
	end
end

--更新本服前三名缓存数据
local function onUpdateTopThreeCache(sid, sType, dp)
	if not System.isCommSrv() then return end

	local dvar = cstiantifb.getSystemVar()
	dvar.topThreeCache = {}
	local nlen = LDataPack.readByte(dp)

	for i = 1, nlen do
		local tb = {}
		LDataPack.readChar(dp)							--跳过第一个数据
		tb.actorId = LDataPack.readInt(dp)				--角色ID
		tb.job = LDataPack.readByte(dp)					--职业
		tb.coat = LDataPack.readInt(dp)					--衣服
		tb.weapon = LDataPack.readInt(dp)				--武器
		tb.illusionWeaponId = LDataPack.readInt(dp)		--幻化武器
		tb.wingId = LDataPack.readInt(dp)			--翅膀等级
		tb.shineWeapon = LDataPack.readByte(dp)			--武器发光
		tb.shineArmor = LDataPack.readByte(dp)			--防具发光
		tb.damonId = LDataPack.readInt(dp)				--精灵

		table.insert(dvar.topThreeCache, tb)
	end
end

--跨服发送赛季给普通服
function a2sSeasonData(serverId)
	if not System.isBattleSrv() then return end
	local svar = cstiantifb.getSystemVar()
	local pack = LDataPack.allocPacket()
	if not pack then return end
	LDataPack.writeByte(pack, cmd.SCTianTiCmd)
	LDataPack.writeByte(pack, subCmd.SCTianTiCmd_UpdateSeason)
	LDataPack.writeInt(pack, svar.preSeason)
	System.sendPacketToAllGameClient(pack, serverId)
end

--普通服收到跨服发送的赛季
local function a4sSeasonData(sid, sType, dp)
	if not System.isCommSrv() then return end

	local preSeason = LDataPack.readInt(dp)
	local dvar = cstiantifb.getSystemVar()
	dvar.isSyncData = 1
	if dvar.preSeason == preSeason then return end

	dvar.preSeason = preSeason
	local  actors = System.getOnlineActorList()
	if actors ~= nil then
		for i = 1, #actors do
			local actor = actors[i]
			s2cActorRecord(actor, preSeason, true)
		end
	end
end

---------------------------------------------------------------------
--下发奖励标记
function s2cActorRecord(actor, season, needSync)
	if not actor then return end
	local var = cstiantifb.getActorVar(actor)
	local cvar = cstiantifb.getActorCrossVar(actor)

	if var.calcSeason == season then return end
	var.calcSeason = season
	var.record1 = 0
	var.record2 = 0
	var.preWinPoint = cvar.winPoint

	local rank = getPreviousRank()
	if rank then
		local index = Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
		if index > 0 and index <= def.totalRankingBroadSize then
			var.record1 = 1
		end
	end

	for _, conf in pairs(CsttReward2Config) do
		if var.preWinPoint >= conf.needPoint then
			var.record2 = 1
			break
		end
	end

	if not needSync then return end
	local pack = LDataPack.allocPacket(actor, P.CMD_Cross, P.sCsTianti_RewardFlag)
	if not pack then return end
	LDataPack.writeByte(pack, var.record1)
	LDataPack.writeByte(pack, var.record2)
	LDataPack.flush(pack)
end

--排行榜内容协议包
function writeWinpointRankData(rank, pack, rankType)
	local rankTb = Ranking.getRankingItemList(rank, def.totalRankingBroadSize)
	if rankTb == nil then rankTb = {} end
	LDataPack.writeShort(pack, rankType)
	LDataPack.writeShort(pack, #rankTb)
	for i, item in pairs(rankTb) do
		LDataPack.writeShort(pack, i) 							--排名
		LDataPack.writeInt(pack, Ranking.getId(item)) 			--id
		LDataPack.writeInt(pack, Ranking.getPoint(item)) 		--胜点
		LDataPack.writeInt(pack, Ranking.getSubInt(item, 0)) 	--服务器id
		LDataPack.writeString(pack, Ranking.getSub(item, 1)) 	--名字
		LDataPack.writeDouble(pack, Ranking.getSubInt(item, 2)) --战力
		LDataPack.writeInt(pack, Ranking.getSubInt(item, 3)) 	--段位
	end
end

--返回赛季排行榜信息
local function s2cWinpointRank(actor)
	if not System.isCommSrv() then return end

	local sysVar = cstiantisys.getSysStaticVar()
	local dvar = cstiantifb.getSystemVar()
	local rank = getWinpoingRank(sysVar.session)
	if not rank then return end

	local pack = LDataPack.allocPacket(actor, P.CMD_Cross, P.sCsTianti_SeasonRank)
	if not pack then return end

	writeWinpointRankData(rank, pack, RankingType_CsttRank)
	writeTopThreeData(dvar, pack)
	LDataPack.writeShort(pack, getNowRank(actor))

	LDataPack.flush(pack)
end

--返回每日排行榜信息
local function s2cDailyWinpointRank(actor)
	if not System.isCommSrv() then return end
	local sysVar = cstiantisys.getSysStaticVar()

	local rank = getDailyWinpointRank(sysVar.session)
	if not rank then return end

	local pack = LDataPack.allocPacket(actor, P.CMD_Cross, P.sCsTianti_PointRank)
	if not pack then return end

	writeWinpointRankData(rank, pack, RankingType_CsttDaily)
	LDataPack.flush(pack)
end

--请求上一届排行榜
local function c2sPreviousRank(actor)
	local var = cstiantifb.getActorVar(actor)
	local rank = getPreviousRank()
	if not rank then return end

	local pack = LDataPack.allocPacket(actor, P.CMD_Cross, P.sCsTianti_LastRank)
	if not pack then return end

	LDataPack.writeInt(pack, var.preWinPoint)
	local index = Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
	if index > def.totalRankingBroadSize then
		index = 0
	end
	LDataPack.writeWord(pack, index)
	writeWinpointRankData(rank, pack, RankingType_CsttRank)

	LDataPack.flush(pack)
end

--领取排名奖励
local function c2sGetRankReward(actor)
	local var = cstiantifb.getActorVar(actor)
	if var.record1 ~= 1 then return end
	local rank = getPreviousRank()
	if not rank then return end
	local index = Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
	if index <= 0 then return end

	local rewards
	for _, conf in pairs(CsttReward1Config) do
		if conf.range[1] <= index and index <= conf.range[2] then
			rewards = conf.rewards
		end
	end
	if not rewards then return end

	var.record1 = 2
	actoritem.addItems(actor, rewards, "cstianti rank awards")

	local pack = LDataPack.allocPacket(actor, P.CMD_Cross, P.sCsTianti_RankReward)
	if not pack then return end
	LDataPack.writeByte(pack, var.record1)
	LDataPack.flush(pack)
end

--领取达标奖励
local function c2sGetTargetReward(actor)
	local var = cstiantifb.getActorVar(actor)
	if var.record2 ~= 1 then return end

	local rewards
	local winpoint = var.preWinPoint
	for _, conf in ipairs(CsttReward2Config) do
		if winpoint >= conf.needPoint then
			rewards = conf.rewards
			break
		end
	end
	if not rewards then return end

	var.record2 = 2
	actoritem.addItems(actor, rewards, "cstianti target awards")

	local pack = LDataPack.allocPacket(actor, P.CMD_Cross, P.sCsTianti_ReachReward)
	if not pack then return end
	LDataPack.writeByte(pack, var.record2)
	LDataPack.flush(pack)
end

local function onNewDay()
	local sysVar = cstiantisys.getSysStaticVar()
	local rank = getDailyWinpointRank(sysVar.session)
	if not rank then return end
	Ranking.clearRanking(rank)
end


--合服回调
function hefuCallBack(master, slaveTbl, ...)
	if not cstianticontrol.checkCommSrvSysIsOpen() then return end
	if System.isBattleSrv() then
		local sysVar = cstiantisys.getSysStaticVar()
		modifyRankServerId(RankingType_CsttRank, def.totalRankingBroadSize, master, slaveTbl, sysVar.session)
		modifyRankServerId(RankingType_CsttDaily, def.dailyRankingBroadSize, master, slaveTbl, sysVar.session)
		modifyRankServerId(LAST_CS_RANK_INDEX, def.totalRankingBroadSize, master, slaveTbl, sysVar.session)
		sendWinpointRank(0)
		sendDailyWinpointRank(0)
	else
		modifyRankServerId(LAST_COM_RANK_INDEX, def.totalRankingBroadSize, master, slaveTbl)
	end
end

--合服时修正从服服务器id
function modifyRankServerId(rankType, broadSize, master, slaveTbl, session)
	local rank
	if rankType == RankingType_CsttRank then
		--修正总榜从服服务器id
		rank = getWinpoingRank(session)
	elseif rankType == RankingType_CsttDaily then
		--修正每日排行榜从服服务器id
		rank = getDailyWinpointRank(session)
	elseif rankType == LAST_CS_RANK_INDEX then
		--修正跨服上一届排行榜从服服务器id
		rank = getWinpoingRank(session - 1)
	elseif rankType == LAST_COM_RANK_INDEX then
		--修正本服上一届排行榜从服服务器id
		rank = getPreviousRank()
	end
	if not rank then return end
	local rankTb = Ranking.getRankingItemList(rank, broadSize)
	if not rankTb or not next(rankTb) then return end
	for _, item in ipairs(rankTb) do
		repeat
			local sid = Ranking.getSubInt(item, 0)
			for _, slaveId in ipairs(slaveTbl) do
				if sid == slaveId then
					Ranking.setSub(item, 0, master)
					break
				end
			end
		until(true)
	end
end

--------------------------------------------------------------------------------------------------


engineevent.regNewDay(onNewDay)
engineevent.regGameStopEvent(releaseRankingList)

csmsgdispatcher.Reg(cmd.SCTianTiCmd, subCmd.SCTianTiCmd_UpdateRankData, a4sRankData)
csmsgdispatcher.Reg(cmd.SCTianTiCmd, subCmd.SCTianTiCmd_UpdateTopThreeCache, onUpdateTopThreeCache)
csmsgdispatcher.Reg(cmd.SCTianTiCmd, subCmd.SCTianTiCmd_UpdateSeason, a4sSeasonData)

netmsgdispatcher.reg(P.CMD_Cross, P.cCsTianti_SeasonRank, s2cWinpointRank)
netmsgdispatcher.reg(P.CMD_Cross, P.cCsTianti_PointRank, s2cDailyWinpointRank)
netmsgdispatcher.reg(P.CMD_Cross, P.cCsTianti_LastRank, c2sPreviousRank)
netmsgdispatcher.reg(P.CMD_Cross, P.cCsTianti_RankReward, c2sGetRankReward)
netmsgdispatcher.reg(P.CMD_Cross, P.cCsTianti_ReachReward, c2sGetTargetReward)
hefuevent.reg(hefuCallBack)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.csttseasonrank = function (actor, args)
	s2cWinpointRank(actor)
	return true
end

gmCmdHandlers.csttdailyrank = function (actor, args)
	s2cDailyWinpointRank(actor)
	return true
end

gmCmdHandlers.csttpreviousrank = function (actor, args)
	c2sPreviousRank(actor)
	return true
end

gmCmdHandlers.csttrankreward = function (actor, args)
	c2sGetRankReward(actor)
	return true
end

gmCmdHandlers.cstttargetreward = function (actor, args)
	c2sGetTargetReward(actor)
	return true
end

------------------------------- 2018/5/28 增加跨服合并清除数据和领取奖励指令
local function gmonGetRankReward(actor)
	local var = cstiantifb.getActorVar(actor)
	local awards = gmgetAwards(actor, var)
	if not awards then return end

	var.record1 = 2

	return awards
end

function gmgetAwards(actor, var)
	if var.record1 ~= 1 then return end

	local rank = getPreviousRank()
	if not rank then return end

	local index = Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
	if index <= 0 then return end

	for _, conf in pairs(CsttReward1Config) do
		if conf.range[1] <= index and index <= conf.range[2] then
			return conf.awards
		end
	end
end

local function gmonGetTargetReward(actor)
	local var = cstiantifb.getActorVar(actor)
	if var.record2 ~= 1 then return end

	local awards
	local winpoint = var.preWinPoint
	for _, conf in ipairs(CsttReward2Config) do
		if winpoint >= conf.needPoint then
			awards = conf.awards
			break
		end
	end

	if not awards then return end

	var.record2 = 2
	return awards
end

local function setResetFlag(actor)
	--设置清除标记，登录时根据标记来清除数据
	local var1 = cstiantifb.getActorVar(actor)
	var1.gmReset = 1
	var1.gmCalc = 1
	var1.gmSeason = 1

	local var2 = csgbsubawards.getCsgbsubVar(actor)
	var2.gmAward = 1

	LActor.saveDb(actor)
end

function resetActorData(actor)
	local var = cstiantifb.getActorVar(actor)
	if (var.gmReset or 0) ~= 1 then return end

	--清除上一届胜点
	local data = cstiantifb.getActorCrossVar(actor)
	data.winPoint = 0

	--重置所有数据
	local sysVar = cstiantisys.getSysStaticVar()
	local var = cstiantifb.getActorVar(actor)
	cstiantifb.initActorVar(var)
	var.preWinPoint = 0
	local cvar = LActor.getCrossVar(actor)
	cstiantifb.initCSTianTiVar(cvar)

	cstiantisys.resetActorData(actor)
	avar = cstiantisys.getVar(actor)
	avar.session = sysVar.session

	var.gmReset = 0
end

function asynAutoGetAward(actor)
	local dvar = cstiantifb.getSystemVar()
	if dvar.isSyncData ~= 1 then return end

	--如果执行指令时镜像在线则不会跑 cstiantifb.onInit 导致没有计算奖励标记位
	s2cActorRecord(actor, dvar.preSeason)

	local awards1 = gmonGetTargetReward(actor)
	if awards1 then
		LActor.log(actor, "cstiantirankmgr.asynAutoGetAward", "mark1")
		local tMailData = {head=ScriptContents.crosshead, context=ScriptContents.crosscontent, tAwardList=awards1}
		mailsystem.sendMailById(LActor.getActorId(actor), tMailData)
	end


	local awards2 = gmonGetRankReward(actor)
	if awards2 then 
		LActor.log(actor, "cstiantirankmgr.asynAutoGetAward", "mark2")
		local tMailData = {head=ScriptContents.crosshead, context=ScriptContents.crosscontent, tAwardList=awards2}
		mailsystem.sendMailById(LActor.getActorId(actor), tMailData)
	end

	--设置标记一定要放在后面，因为拉镜像上线会在 cstiantifb.onInit 里设置奖励标记位，而里面用到了要设置的标记位
	setResetFlag(actor)
end


function autoGetAward()
	local t =  System.timeEncode(2018,2,28,0,0,0)
	local actorDatas = System.getAllActorData()
	for _, data in ipairs(actorDatas) do
	    local actorData = toActorBasicData(data)
	    if actorData.zhuansheng_lv >= 3 and actorData.last_online_time >= t and actorData.cs_tianti_score > 0 then
	    	asynevent.reg(actorData.actor_id, asynAutoGetAward)
	    end
	end
end

function onCrossChangeName(sId, sType, dp)
	local actorId = LDataPack.readInt(dp)
	local name = LDataPack.readString(dp)
	local sysVar = cstiantisys.getSysStaticVar()
	local rank = getWinpoingRank(sysVar.session)
	if not rank then return end
	local item = Ranking.getItemPtrFromId(rank, actorId)
	if item then		
		Ranking.setSub(item, 1, name)
	end
	sendWinpointRank(0) --同步到普通服

	local rank1 = getDailyWinpointRank(sysVar.session)
	if not rank1 then return end
	local item = Ranking.getItemPtrFromId(rank1, actorId)
	if item then
		Ranking.setSub(item, 1, name)
	end
	local now_sec = System.getNowTime()
	local sdvar = cstiantifb.getSystemDVar()
	sdvar.tDailyRankSec = now_sec + SECOND
	sendDailyWinpointRank(0)

	-- for k,v in ipairs(svar.topThreeCache) do
	-- 	if v.name 
	-- end

	-- updateTopThreeCache(actor, rank, srvId, actorName)--更新排行榜前三名形象缓存数据
end


onChangeName = function(actor, res, name, rawName, way)
	--跨服天梯排行榜修改
	local cvar = cstiantifb.getActorCrossVar(actor)
	local addWinPoint = 0
	cvar.dailyWinPoint = cvar.dailyWinPoint + addWinPoint
	cvar.winPoint = cvar.winPoint + addWinPoint
	cstiantitask.csTianTiTaskUpdate(actor, cstiantitask.gwinPoint, addWinPoint)

	
	local pack = LDataPack.allocPacket()
	if not pack then return end

	LDataPack.writeByte(pack, cmd.SCTianTiCmd)
	LDataPack.writeByte(pack, subCmd.SCTianTiCmd_ChangeName)
	LDataPack.writeInt(pack, LActor.getActorId(actor))
	LDataPack.writeString(pack, name)
	local crossId = csbase.getCrossServerId()
	System.sendPacketToAllGameClient(pack, crossId)
	
	updateDailyRank(actor, cvar.dailyWinPoint)
end

actorevent.reg(aeChangeName, onChangeName)
csmsgdispatcher.Reg(cmd.SCTianTiCmd, subCmd.SCTianTiCmd_ChangeName, onCrossChangeName)

--------------------------------------------------------------------------------------------------