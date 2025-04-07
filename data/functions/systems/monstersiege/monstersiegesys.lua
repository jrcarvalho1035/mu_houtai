module("monstersiegesys", package.seeall)

--@rancho 20171106
--移植过来，修改后代码非常乱
--修改和参考需谨慎

--怪物攻城
local globalConf = MonSiegeConf
local msfbConf = MonSiegeFBConf
local dailyOpen = false
--普通副本波数配置
local msFBConf = MonSiegeFBConf
local msScoreAwardConf = MSScoreAwardConf
local langScript = ScriptTips

--把0123456转成7123456
function getWeekDay()
	local weekDay = System.getDayOfWeek()
	return math.floor((weekDay+7-1)%7) + 1
end

function getBattleConf(bIdx)
	local weekDay = monstersiegesys.getWeekDay()
	local weekConf = msFBConf[weekDay]
	return weekConf[bIdx]
end

function sysIsOpen(actor)
	if dailyOpen == false then
		return false
	end
	return actorexp.checkLevelCondition1(actorexp.LimitTp.siege)
end

--获取系统信息
function getSysInfo(actor, pack)
	sendSysInfo(actor)
end

function sendSysInfo(actor)
	local aId = actor and LActor.getActorId(actor) or 0
	local npack
	if aId ~= 0 then
		npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_Data)
	else
		npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_MonSiege)
		LDataPack.writeByte(npack, Protocol.sMonSiegeCmd_Data)
	end
	if npack == nil then return end

	local weekDay = getWeekDay()
	local weekConf = msFBConf[weekDay]
	local sysVar = getSysVar()
	LDataPack.writeInt(npack, sysVar.lastLoginCount)
	LDataPack.writeByte(npack, #weekConf)
	print("monstersiegesys.sendSysInfo weekDay:" .. weekDay)
	print("monstersiegesys.sendSysInfo #weekConf:" .. #weekConf)
	local tbl
	local now_t = System.getNowTime()
	for _, v in ipairs(weekConf) do
		local var = getBVarByIdx(v.idx)
		LDataPack.writeByte(npack, v.idx)
		LDataPack.writeString(npack, var.monName)
		LDataPack.writeString(npack, var.monHead)
		LDataPack.writeInt(npack, var.monModel)
		LDataPack.writeByte(npack, var.state)
		if v.fbType == MonSiegeDef.ftCommon then
			if var.state == MonSiegeDef.waitRunAway then
				local restTime = var.runAway - now_t
				LDataPack.writeUInt(npack, restTime > 0 and restTime or 0)
			elseif var.state == MonSiegeDef.resurrection then
				local restTime = var.resurrection - System.getNowTime()
				LDataPack.writeUInt(npack, restTime > 0 and restTime or 0)
			end
			LDataPack.writeChar(npack, #var.attriList)
			for i=1, #var.attriList do
				tbl = var.attriList[i]
				LDataPack.writeInt(npack, tbl.aId)
				LDataPack.writeString(npack, tbl.aName)
				LDataPack.writeChar(npack, tbl.sex)
				LDataPack.writeChar(npack, tbl.job)
			end
		elseif v.fbType == MonSiegeDef.ftBoss then
			tbl = msbossdamageinfo.getFirstRankPlayer(var.bossData)
			LDataPack.writeInt(npack, tbl.id or 0)
			local actorIds = {}
			local count = 0
			local restTime = 0
			if var.state == MonSiegeDef.bfbDefault or var.state == MonSiegeDef.bfbChallenge then
				LDataPack.writeDouble(npack, var.publicHP)
				LDataPack.writeDouble(npack, var.maxHp)
				restTime = var.settlement - now_t
			end

			if var.state == MonSiegeDef.bfbChallenge then
				actorIds = var.bossActors
				count = var.bossActorsCount
			elseif var.state ==  MonSiegeDef.bfbOccupied then
				actorIds = var.imageActors
				count = var.imageActorsCount
				restTime = var.attriTime - now_t
			end
			LDataPack.writeUInt(npack, restTime >= 0 and restTime or 0)
			LDataPack.writeChar(npack, count)
			for k, v in pairs(actorIds) do
				LDataPack.writeInt(npack, k)
			end
			LDataPack.writeString(npack, tbl.aName or "")
			LDataPack.writeByte(npack, tbl.job or 0)
			LDataPack.writeInt(npack, tbl.level or 1)
			LDataPack.writeInt(npack, tbl.clothesId or 0)
			LDataPack.writeInt(npack, tbl.weaponId or 0)
			LDataPack.writeInt(npack, tbl.illusionWeaponId or 0)
			LDataPack.writeInt(npack, wingsystem.getWingIdByLevel(nil, tbl.job or 1, tbl.wingLevel or 0))
			LDataPack.writeInt(npack, tbl.title or 0)
			LDataPack.writeInt(npack, tbl.guildId or 0)
			LDataPack.writeString(npack, tbl.guildName or "")
			LDataPack.writeByte(npack, tbl.footShowStage or 0)
			LDataPack.writeByte(npack, tbl.shineWeapon or 0)
			LDataPack.writeByte(npack, tbl.shineArmor or 0)
			LDataPack.writeInt(npack, tbl.teamId or 0)
			LDataPack.writeInt(npack, tbl.guildPos or 0)
		end
	end

	if aId ~= 0 then
		LDataPack.flush(npack)
	else
		mainscenefuben.sendData(npack)
	end
end

function updateSysInfo(bIdx, actor)
	local aId = actor and LActor.getActorId(actor) or 0
	local npack
	if aId ~= 0 then
		npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_UpdateSysInfo)
	else
		npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_MonSiege)
		LDataPack.writeByte(npack, Protocol.sMonSiegeCmd_UpdateSysInfo)
	end
	if npack == nil then return end

	local var = getBVarByIdx(bIdx)
	local bConf = getBattleConf(bIdx)
	local now_t = System.getNowTime()
	LDataPack.writeByte(npack, bIdx)
	LDataPack.writeString(npack, var.monName)
	LDataPack.writeString(npack, var.monHead)
	LDataPack.writeInt(npack, var.monModel)
	LDataPack.writeByte(npack, var.state)
	if bConf.fbType == MonSiegeDef.ftCommon then
		if var.state == MonSiegeDef.waitRunAway then
			local restTime = var.runAway - now_t
			LDataPack.writeUInt(npack, restTime > 0 and restTime or 0)
		elseif var.state == MonSiegeDef.resurrection then
			local restTime = var.resurrection - now_t
			LDataPack.writeUInt(npack, restTime > 0 and restTime or 0)
		end
		LDataPack.writeChar(npack, #var.attriList)
		for i=1, #var.attriList do
			tbl = var.attriList[i]
			LDataPack.writeInt(npack, tbl.aId)
			LDataPack.writeString(npack, tbl.aName)
			LDataPack.writeChar(npack, tbl.sex)
			LDataPack.writeChar(npack, tbl.job)
		end
	elseif bConf.fbType == MonSiegeDef.ftBoss then
		tbl = msbossdamageinfo.getFirstRankPlayer(var.bossData)
		LDataPack.writeInt(npack, tbl.id or 0)
		local actorIds = {}
		local count = 0
		local restTime = 0
		if var.state == MonSiegeDef.bfbDefault or var.state == MonSiegeDef.bfbChallenge then
			LDataPack.writeDouble(npack, var.publicHP)
			LDataPack.writeDouble(npack, var.maxHp)
			restTime = var.settlement - now_t
		end

		if var.state == MonSiegeDef.bfbChallenge then
			actorIds = var.bossActors
			count = var.bossActorsCount
		elseif var.state ==  MonSiegeDef.bfbOccupied then
			actorIds = var.imageActors
			count = var.imageActorsCount
			restTime = var.attriTime - now_t
		end
		LDataPack.writeUInt(npack, restTime >= 0 and restTime or 0)
		LDataPack.writeChar(npack, count)
		for k, v in pairs(actorIds) do
			LDataPack.writeInt(npack, k)
		end
		LDataPack.writeString(npack, tbl.aName or "")
		LDataPack.writeByte(npack, tbl.job or 0)
		LDataPack.writeInt(npack, tbl.level or 1)
		LDataPack.writeInt(npack, tbl.clothesId or 0)
		LDataPack.writeInt(npack, tbl.weaponId or 0)
		LDataPack.writeInt(npack, tbl.illusionWeaponId or 0)
		LDataPack.writeInt(npack, wingsystem.getWingIdByLevel(nil, tbl.job or 1, tbl.wingLevel or 0))
		LDataPack.writeInt(npack, tbl.title or 0)
		LDataPack.writeInt(npack, tbl.guildId or 0)
		LDataPack.writeString(npack, tbl.guildName or "")
		LDataPack.writeByte(npack, tbl.footShowStage or 0)
		LDataPack.writeByte(npack, tbl.shineWeapon or 0)
		LDataPack.writeByte(npack, tbl.shineArmor or 0)
		LDataPack.writeInt(npack, tbl.teamId or 0)
		LDataPack.writeInt(npack, tbl.guildPos or 0)
	end

	if aId ~= 0 then
		LDataPack.flush(npack)
	else
		mainscenefuben.sendData(npack)
	end
end

function checkIsPlay(actor)
	if LActor.getLevel(actor) >= globalConf.lvlLimit then
		return true
	end
	return false
end

--系统静态数据
function getSysVar()
	local var = System.getStaticVar()
	if var.monSiegeData == nil then
		var.monSiegeData = {}
		local tempVar = var.monSiegeData
		tempVar.battle = {}
		tempVar.flag = 1
		tempVar.lastLoginCount = 0
		tempVar.loginTime = 0
	end
	local monSiegeData = var.monSiegeData
	if not monSiegeData.todayInitTime then monSiegeData.todayInitTime = 0 end 
	return monSiegeData
end

function getLastLoginCount()
	local sysVar = monstersiegesys.getSysVar()
	return sysVar.lastLoginCount
end

--系统动态数据
function getSysDVar()
	local var = System.getDyanmicVar()
	if var.monSiegeData == nil then
		var.monSiegeData = {}
	end
	return var.monSiegeData
end

--玩家静态数据
function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if var.monSiegeData == nil then
		var.monSiegeData = {}
		var.monSiegeData.score = 0
		var.monSiegeData.awardCode = 0
	end
	return var.monSiegeData
end

function getBVarByIdx(bIdx)
	local var = getSysVar()
	local weekDay = getWeekDay()
	if var.battle[bIdx] == nil or var.battle[bIdx].weekDay ~= weekDay then
		var.battle[bIdx] = {}
		local tempVar = var.battle[bIdx]
		tempVar.bIdx = bIdx
		--只有普通副本类型才有用star
		tempVar.attriList = {}
		tempVar.commonHpTimer = 0
		--下次复活时间
		tempVar.resurrection = 0
		--只有普通副本类型才有用end


		--只有boss副本类型才有用star
		-- tempVar.hfb = 0
		tempVar.bossActors = {}
		tempVar.bossActorsCount = 0
		tempVar.imageActors = {}
		tempVar.imageActorsCount = 0
		tempVar.curLvl = 1
		tempVar.curHp = 0
		tempVar.weekDay = weekDay
		tempVar.publicHP = -1
		tempVar.maxHp = -1
		tempVar.monHead = 0
		tempVar.monModel = 0
		tempVar.monName = ""
		tempVar.hfbList = {}
		tempVar.state = 0
		tempVar.starNum = 0
		--boss结算时间
		tempVar.settlement = 0
		--boss归属时间
		tempVar.attriTime = 0
		--逃跑时间
		tempVar.runAway = 0
		tempVar.challengeCount = 0
		tempVar.bossData = {}
		--只有boss副本类型才有用end
	end
	if var.battle[bIdx].bossData == nil then
		var.battle[bIdx].bossData = {}
	end
	return var.battle[bIdx]
end

function getAttriData(bIdx, actorId)
	local bVar = getBVarByIdx(bIdx)
	for i=1, #bVar.attriList do
		local attri = bVar.attriList[i]
		if attri.aId == actorId then
			return attri
		end
	end
	return nil
end

function resetBattleData(bIdx)
	local bVar = getBVarByIdx(bIdx)
	bVar.attriList = {}
	bVar.resurrection = 0
	bVar.bossActors = {}
	bVar.bossActorsCount = 0
	bVar.imageActors = {}
	bVar.imageActorsCount = 0
	bVar.publicHP = -1
	bVar.hfbList = {}
	bVar.challengeCount = 0
end

--请求攻城
function onReqSiege(actor, pack)
	-- print("-------------------------请求攻城")
	LActor.log(actor,  "monstersiegesys.onReqSiege", "call")

	if not sysIsOpen(actor) then
		LActor.sendTipmsg(actor, langScript.mssys011, ttMessage)
		return 
	end
	if not checkIsPlay(actor) then
		-- print("等级不足，无法参加活动")
		LActor.sendTipmsg(actor, langScript.mssys001, ttMessage)
		return 
	end

	local fbId = LActor.getFubenId(actor)
	if fbId ~= 0 then
		LActor.sendTipmsg(actor, langScript.mssys002, ttMessage)
		-- print("你已在其他副本中，不能攻城")
		return
	end

	local weekDay = getWeekDay()
	local weekConf = msfbConf[weekDay]
	if not weekConf then
		-- print("今天并没有战场可以被挑战")
		LActor.log(actor,  "monstersiegesys.onReqSiege", "not week conf")
		return
	end
	local bIdx = LDataPack.readByte(pack)
	if not weekConf[bIdx] then
		-- print("找不到当前战场，不能进行攻城挑战:"..bIdx)
		LActor.log(actor,  "monstersiegesys.onReqSiege", "not battle conf", bIdx)
		return
	end
	local bt = LDataPack.readChar(pack)
	monstersiegefb.onSiege(actor, bIdx, bt)
end

function onGetBattleIdx(actor, pack)
	local ins = instancesystem.getActorIns(actor)
	if not ins or not ins.data.bIdx then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_GetBattleIdx)
	if npack == nil then return end
	LDataPack.writeInt(npack, ins.data.bIdx)
	LDataPack.flush(npack)

	enterFBResult(actor, ins:getFid(), ins:getEndTime())
end

--获取伤害排行榜
function getBossDamageRank(actor, pack)
	local fbType = MonSiegeDef.ftBoss
	for k,weekConf in pairs(msFBConf) do
		for _,v in ipairs(weekConf) do
			if v.fbType == fbType then
				msbossfb.sendDamageRank(actor, v.idx)
				--只发一个吧,前端也不支持多个的
				break
			end
		end
	end
end

function getCommonDamageRank(actor, pack)
	local bIdx = LDataPack.readChar(pack)
	mscommonfb.sendDamageRank(actor, bIdx)
end

function init()
	if System.isBattleSrv() then return end
	if not actorexp.checkLevelCondition1(actorexp.LimitTp.siege) then return end
	local now_t = System.getNowTime()
	local year, month, day, _, _, _ = System.timeDecode(now_t)
	local tTbl = globalConf.starTime
	local sTime = System.timeEncode(year, month, day, tTbl[1], tTbl[2], tTbl[3])
	tTbl = globalConf.endTime
	local eTime = System.timeEncode(year, month, day, tTbl[1], tTbl[2], tTbl[3])
	if now_t >= sTime and now_t <= eTime then
		dailyOpen = true
	else
		dailyOpen = false
	end
	
	local sysVar = getSysVar()
	local now = System.getNowTime()
	if dailyOpen and not System.isSameDay(sysVar.todayInitTime, now) then
		startInit()
	end
end

function startInit()
	
	local weekDay = getWeekDay()
	local weekConf = msFBConf[weekDay]
	local sysVar = getSysVar()
	local tbl
	local now_t = System.getNowTime()
	for _, bConf in ipairs(weekConf) do
		local bVar = getBVarByIdx(bConf.idx)
		local monster = MonstersConfig[bConf.monsterId]
		bVar.monHead = monster.head
		--print("###monster.head:" .. monster.head)
		bVar.monModel = monster.avatar
		--print("###monster.avatar:" .. monster.avatar)
		bVar.monName = string.format(globalConf.nameStr, monster.name, bConf.monsterName)
		if bConf.fbType == 2 then
			local bossConfig = MSBossLvlConf[bConf.param][bVar.curLvl]
			bVar.publicHP = bossConfig.hp
			bVar.maxHp = bossConfig.hp
			msbossdamageinfo.initBossCache(bVar.bossData, bConf.monsterId, bossConfig.hp, 1)
		end
	end
	sysVar.todayInitTime = now_t
end

function sendMsEnd()
	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_MonSiege)
	LDataPack.writeByte(npack, Protocol.sMonSiegeCmd_End)	
	mainscenefuben.sendData(npack)
end

function sendMsStart()
	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_MonSiege)
	LDataPack.writeByte(npack, Protocol.sMonSiegeCmd_Start)	
	System.broadcastData(npack)
end

function setDailyOpen(state)
	dailyOpen = state
	if state then
		startInit()
		sendSysInfo()
		sendMsStart()
	else
		sendMsEnd()
	end
end

_G.setMonsterSiegeDailyState = function(t, state)
	if System.isBattleSrv() then return end
	if not actorexp.checkLevelCondition1(actorexp.LimitTp.siege) then
		return
	end
	System.log("monstersiegesys", "setMonsterSiegeDailyState", "call", state)
	monstersiegesys.setDailyOpen(state)
	activityAnno(state)
end

function activityAnno(state)
	if state then
		-- "怪物攻城玩法已经开启，各位勇士速去击退怪物！"
		noticesystem.broadCastNotice(noticesystem.NTP.monSiege1)
	else
		-- "经过大家的努力，有效的阻止了怪物攻城！"
		noticesystem.broadCastNotice(noticesystem.NTP.monSiege2)
	end
end

function resetSysData()
	local sysVar = getSysVar()
	sysVar.flag = sysVar.flag + 1
	sysVar.scoreAward = {}
	sysVar.resetDatatime = System.getNowTime()

	local  actors = System.getOnlineActorList()
	if actors ~= nil then
		for i =1,#actors do
			msscoreaward.resetActorVar(actors[i], flag)
		end
	end
	msimagerankaward.clearSys()

	rank = msscoreaward.getScoreRank()
	if rank then
		_G.rank_backup(rank)
		Ranking.clearRanking(rank)
	end
end

_G.monsterSiegeReset = function()
	if System.isBattleSrv() then return end
	if not actorexp.checkLevelCondition1(actorexp.LimitTp.siege) then
		return
	end
	resetSysData()
end

function gameStart()
	if System.isBattleSrv() then return end
	local sysVar = getSysVar()
	local now_t = System.getNowTime()
	if dailyOpen and not System.isSameDay(sysVar.todayInitTime, now_t) then
		startInit()
	end
	if sysVar.resetDatatime == nil then
		sysVar.resetDatatime = now_t
	end
	if System.isSameWeek(sysVar.resetDatatime, now_t) then
		return
	end
	resetSysData()
end

function sendSettlementInfo(actor, fbType, isWin, val, totalAward)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_SettlementInfo)
	if npack == nil then return end
	totalAward = totalAward or {}
	LDataPack.writeChar(npack, fbType)
	LDataPack.writeByte(npack, isWin)
	LDataPack.writeDouble(npack, val)
	LDataPack.writeShort(npack, #totalAward)
	for _, v in ipairs(totalAward) do
		LDataPack.writeInt(npack, v.type or 0)
		LDataPack.writeInt(npack, v.id or 0)
		LDataPack.writeInt(npack, v.count or 0)
	end
	LDataPack.flush(npack)
end

function onNewDayLogin(actor, isLogin)
	if System.isBattleSrv() then return end
	local now_t = System.getNowTime()
	local var = getSysVar()
	if not System.isSameDay(var.loginTime, now_t) then
		var.lastLoginCount = 0
		var.loginTime = now_t
	end

	var.lastLoginCount = var.lastLoginCount + 1
end

function onLogin(actor)
	if dailyOpen then
		local pack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_Start)
		LDataPack.flush(pack)
	end
end

function enterFBResult(actor, fbId, endTime)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_EnterRes)
	if npack == nil then return end
	LDataPack.writeInt(npack, fbId)
	LDataPack.writeUInt(npack, endTime)
	LDataPack.flush(npack)
end

function ehEnterMainFuben(ins, actor)
	if System.isBattleSrv() then return end
	if not sysIsOpen(actor) then return end
	sendSysInfo(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDayLogin)
--主城
insevent.registerInstanceEnter(0, ehEnterMainFuben)

netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_Data, getSysInfo)
netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_Siege, onReqSiege)
netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_GetBattleIdx, onGetBattleIdx)
netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_DamageRank, getBossDamageRank)
netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_CommonRank, getCommonDamageRank)

table.insert(InitFnTable, init)

engineevent.regGameStartEvent(gameStart)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.msresetcount = function (actor, args)
	local weekDay = getWeekDay()
	local weekConf = msFBConf[weekDay]
	for _, v in ipairs(weekConf) do
		local var = getBVarByIdx(v.idx)
		var.bossActors = {}
		var.bossActorsCount = 0
		var.imageActors = {}
		var.imageActorsCount = 0
	end
	sendSysInfo()
	return true
end

gmCmdHandlers.msbtest1 = function (actor, args)
	noticesystem.broadCastNotice(60)
	return true
end
