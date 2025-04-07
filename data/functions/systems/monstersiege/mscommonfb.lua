module("mscommonfb", package.seeall)
--普通副本逻辑
local msWaveConf = MonSiegeWaveConf
local fbType = MonSiegeDef.ftCommon
local globalConf = MonSiegeConf
local msFBConf = MonSiegeFBConf

local fbStar = 1
local fbEnd = 0
local GRIDSIZE = 64
local randTbl = {{0,0},{0,1},{0,2},{1,0},{1,1},{1,2},{2,0},{2,1},{2,2}}
local hpInterval = 1

-- local canChallenge = 0 --可挑战
-- local waitRunAway = 1 --等待逃跑
-- local resurrection = 2 --复活

function initFB(ins, actor, bIdx, bConf)
	ins.data.waveNum = 1
	ins.data.param = bConf.param
	ins.data.state = fbStar
	ins.data.bIdx = bIdx

	local monName = MonstersConfig[bConf.monsterId].name
	ins.data.bossName = string.format(globalConf.nameStr, monName, bConf.monsterName)
	ins.data.actorId = LActor.getActorId(actor)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if bVar.state == MonSiegeDef.canChallenge then
		bVar.state = MonSiegeDef.waitRunAway
		bVar.starNum = bVar.starNum + 1
		ins.data.starNum = bVar.starNum
		runAwayTimingStarts(ins)
	else
		ins.data.starNum = bVar.starNum
	end

	if bVar.runAway < ins:getEndTime() then
		ins:setEndTime(bVar.runAway)
	end

	--特殊处理发送怪物配置
	local monIdList = {}
	local waveConfs = msWaveConf[ins.data.param]
	for i = 1, #waveConfs do
		local mons = waveConfs[i].mons
		for j = 1, #mons do
			local mon = mons[j]
			monIdList[#monIdList + 1] = mon[1]
		end
	end
	slim.s2cMonsterConfig(actor, monIdList)

	refreshWaveMonster(ins)
end

--逃跑倒计时开始
function runAwayTimingStarts(ins)
	local bVar = monstersiegesys.getBVarByIdx(ins.data.bIdx)
	local now_t = System.getNowTime()
	bVar.runAway = now_t + globalConf.runAway
	LActor.postScriptEventLite(nil, globalConf.runAway * 1000, function() onRunAwayCallBack(bVar.starNum, ins.data.bIdx) end)
end

function getDieMonList(ins)
	if ins.data.dieMons == nil then
		ins.data.dieMons = {}
	end
	return ins.data.dieMons
end

function clearDieMonList(ins)
	ins.data.dieMons = {}
end

function refreshWaveMonster(ins)
	local waveConf = msWaveConf[ins.data.param][ins.data.waveNum]
	clearDieMonList(ins)
	local list = getDieMonList(ins)
	local hScene = ins.scene_list[1]
	local pMon
	local pos
	local posX = 0
	local posY = 0
	
	for k,v in ipairs(waveConf.mons) do
		local randIdx = {1,2,3,4,5,6,7,8,9}
		for i=1, v[2] do
			pos = waveConf.posList[k] or {}
			local idx = System.getRandomNumber(#randIdx) + 1
			posX = pos[1] - 1 + randTbl[randIdx[idx]][1]
			posY = pos[2] - 1 + randTbl[randIdx[idx]][2]

			randIdx[idx] = randIdx[#randIdx]
			randIdx[#randIdx] = nil

			pMon = Fuben.createMonster(hScene, v[1], posX, posY)
			if pMon then
				list[v[1]] = (list[v[1]] or 0) + 1
			end
		end
	end
end

function onRunAwayCallBack(flag, bIdx)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if bVar.starNum ~= flag then
		return
	end

	if bVar.state == MonSiegeDef.waitRunAway then
		--怪物要逃跑了就切换状态
		bVar.state = MonSiegeDef.resurrection
		local now_t = System.getNowTime()
		local bConf = monstersiegefb.getBattleConf(bIdx)
		bVar.resurrection = now_t + bConf.resurrection
		--如果时间大于今天的活动时间就无需要再往后做逻辑了
		--现在先不处理这个问题
		settlementRank(bIdx)
		LActor.postScriptEventLite(nil, bConf.resurrection * 1000, function() resurrectionCallBack(flag, bIdx) end)
		monstersiegesys.updateSysInfo(bIdx)
	end
end

function nextWave(flag, hdl)
	local ins = instancesystem.getInsByHdl(hdl)
	if ins == nil or ins.is_end == true then
		return
	end
	if flag ~= ins.data.starNum then
		return 
	end

	refreshWaveMonster(ins)
end

function finishOneWave(ins)
	local curWaveNum = ins.data.waveNum
	local nextWaveNum = curWaveNum + 1
	ins.data.waveNum = nextWaveNum
	if nextWaveNum > #msWaveConf[ins.data.param] then
		--打完了
		--print("------------finishOneWave-------打完了------")
		ins:win()
	else
		--延时刷出下一波怪
		local conf = msWaveConf[ins.data.param][curWaveNum]
		LActor.postScriptEventLite(nil, conf.interval, function() nextWave(ins.data.starNum, ins.handle) end)
	end
end

--怪物死掉
function onMonsterDie(ins, mon, hKiller)
	local bConf = monstersiegefb.getBattleConf(ins.data.bIdx)
	if bConf.fbType ~= fbType then
		return
	end

	local monId = Fuben.getMonsterId(mon)
	local list = getDieMonList(ins)
	if list[monId] == nil then return end

	list[monId] = list[monId] - 1
	local isNotMon = true
	for k,v in pairs(list) do
		if v > 0 then
			isNotMon = false
			break
		end
	end

	if isNotMon == true then
		finishOneWave(ins)
	end
end

function checkBattleFilled(bIdx)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if #bVar.attriList >= globalConf.challengeNum then
		for i=1, #bVar.attriList do
			if bVar.attriList[i].state ~= MonSiegeDef.aafbtEnd then return false end
		end
		return true
	end
	return false
end

--玩家结算处理
function ActorSettlement(actor, isWin, bossName, damage, awards, isSend)
	actoritem.addItemsByMail(actor, awards, "mscommon settlement", 0, "msfbsettle")
	mschallengelog.addLog(actor, 1, bossName, damage, awards)
	if isSend then
		monstersiegesys.sendSettlementInfo(actor, MonSiegeDef.ftCommon, 1, damage, awards)
	end
end

--离线结算处理
function OffMsgActorSettlement(actor, offmsg)
	local bossName = LDataPack.readString(offmsg)
	local damage = LDataPack.readInt64(offmsg)
	local awardsString = LDataPack.readString(offmsg)
	local awards = utils.unserialize(awardsString)
	
	ActorSettlement(actor, 1, bossName, damage, awards)
	LActor.log(actor,  "monstersiegefb.OffMsgActorSettlement")
end

--结算
function onSettlement(ins)
	if ins.data.state == fbEnd then
		return
	end
	ins.data.state = fbEnd
	local bIdx = ins.data.bIdx
	local actorId = ins.data.actorId

	local attriData = monstersiegesys.getAttriData(bIdx, actorId)
	if not attriData then return end
	attriData.state = MonSiegeDef.aafbtEnd

	local conf = monstersiegefb.getBattleConf(bIdx)
	local awards = drop.dropGroup(conf.baseAward)
	local actor = LActor.getActorById(actorId)
	if actor then
		ActorSettlement(actor, 1, ins.data.bossName, attriData.damage, awards, true)
	else
		local npack = LDataPack.allocPacket()
		LDataPack.writeString(npack, ins.data.bossName)
		LDataPack.writeInt64(npack, attriData.damage)
		LDataPack.writeString(npack, utils.serialize(awards))
		System.sendOffMsg(actorId, 0, OffMsgType_MsCommonSettlement, npack)
	end

	if checkBattleFilled(bIdx) then
		--三个都打完了就切换状态
		local bVar = monstersiegesys.getBVarByIdx(bIdx)
		if bVar.state == MonSiegeDef.waitRunAway then
			bVar.state = MonSiegeDef.resurrection
			local now_t = System.getNowTime()
			local bConf = monstersiegefb.getBattleConf(bIdx)
			bVar.resurrection = now_t + bConf.resurrection
			--如果时间大于今天的活动时间就无需要再往后做逻辑了
			--现在先不处理这个问题
			settlementRank(bIdx)
			LActor.postScriptEventLite(nil, bConf.resurrection * 1000, function() resurrectionCallBack(bVar.starNum, bIdx) end)
			monstersiegesys.updateSysInfo(bIdx)
		end
	end
end

--副本内排行，给积分
--"你在击退怪物攻城s%中获得了第s%名，这是你的奖励"
function settlementRank(bIdx)
	local conf = monstersiegefb.getBattleConf(bIdx)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)

	local monName = MonstersConfig[conf.monsterId].name
	monName = string.format(globalConf.nameStr, monName, conf.monsterName)

	for i=1, #bVar.attriList do
		local actorId = bVar.attriList[i].aId
		local dropId = conf.rankAward[i]
		local awards = drop.dropGroup(dropId)
		
		--积分不能发邮件
		local actor = LActor.getActorById(actorId)
		if actor then
			actoritem.changeSpeCurrency(actor, NumericType_SiegeScore, conf.rankScore[i], "mscommon settlementRank" .. i)
		else
			local offItems = {{type = 0, id = NumericType_SiegeScore, count = conf.rankScore[i]}}
			actoritem.SendAddItemsOffMsg(actorId, offItems, "mscommon settlementRank" .. i)
		end

		local mailData = { head=globalConf.giftRankTitle, context="", tAwardList=awards }
		mailData.context = string.format(globalConf.giftRankCont, monName, globalConf.rankStr[i], conf.rankScore[i])
		mailsystem.sendMailById(actorId, mailData)
	end
end

function resurrectionCallBack(flag, bIdx)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if bVar.starNum ~= flag then
		return
	end

	if bVar.state == MonSiegeDef.resurrection then
		bVar.state = MonSiegeDef.canChallenge
		monstersiegesys.resetBattleData(bIdx)
		monstersiegesys.updateSysInfo(bIdx)
	end
end

function onActorDie(ins,actor,hKiller)
	local bConf = monstersiegefb.getBattleConf(ins.data.bIdx)
	if bConf.fbType ~= fbType then
		return
	end
	ins:win()
end

function onWin(ins)
	System.log("mscommonfb", "onWin", "fuben time out")
	--时间到的
	local bConf = monstersiegefb.getBattleConf(ins.data.bIdx)
	if bConf.fbType ~= fbType then
		return
	end

	onSettlement(ins)
end

local function broadcastHp(bIdx)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if not bVar then return end

	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
	LDataPack.writeByte(npack, Protocol.sFubenCmd_InsBossHp)

	local attriList = bVar.attriList
	LDataPack.writeInt(npack, 0)
	LDataPack.writeDouble(npack,0)
	LDataPack.writeInt64(npack, 0)
	LDataPack.writeInt64(npack, 0)
	if attriList == nil then
		LDataPack.writeShort(npack, 0)
	else
		LDataPack.writeShort(npack, #attriList)
		for i=1,#attriList do
			LDataPack.writeInt(npack, attriList[i].aId)
			LDataPack.writeString(npack, attriList[i].aName)
			LDataPack.writeDouble(npack, attriList[i].damage)
		end
	end
	LDataPack.writeInt(npack, 0)
	LDataPack.writeString(npack, "")
	LDataPack.writeString(npack, "")
	LDataPack.writeInt(npack, 0)
	LDataPack.writeDouble(npack, 0)

	for i=1, #bVar.hfbList do
		local hfb = bVar.hfbList[i]
		local ins = instancesystem.getInsByHdl(hfb)
		if ins then
			Fuben.sendData(hfb, npack)
		end
	end
end

--副本伤害事件
local function onMonserDamage(ins, monster, value, attacker)
	local bConf = monstersiegefb.getBattleConf(ins.data.bIdx)
	if bConf.fbType ~= fbType then
		return
	end

	if not attacker then
		return
	end
	local actor = LActor.getActor(attacker)
	if not actor then return end

	local attr = monstersiegesys.getAttriData(ins.data.bIdx, LActor.getActorId(actor))
	if attr then
		attr.damage = attr.damage + value
		local bVar = monstersiegesys.getBVarByIdx(ins.data.bIdx)
		table.sort(bVar.attriList, function(a,b) return a.damage > b.damage end )

		local now_t = System.getNowTime()
		if bVar.commonHpTimer <= now_t then
			bVar.commonHpTimer = now_t + hpInterval
			broadcastHp(ins.data.bIdx)	
		end
	end
end

function sendDamageRank(actor, bIdx)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	local count = #bVar.attriList

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_CommonRank)
	if npack == nil then return end
	LDataPack.writeChar(npack, bIdx)
	LDataPack.writeChar(npack, count)
	for i=1, #bVar.attriList do
		local tbl = bVar.attriList[i]
		LDataPack.writeInt(npack, tbl.aId)
		LDataPack.writeString(npack, tbl.aName)
		LDataPack.writeInt(npack, tbl.damage)
	end
	LDataPack.flush(npack)
end

function gameStart()
	if System.isBattleSrv() then return end
	local weekDay = monstersiegesys.getWeekDay()
	local weekConf = msFBConf[weekDay]
	local now_t = System.getNowTime()
	local oTime = 0
	for k,v in ipairs(weekConf) do
		if v.fbType == fbType then
			local bVar = monstersiegesys.getBVarByIdx(v.idx)
			if bVar.state == MonSiegeDef.canChallenge then
				--可挑战
			elseif bVar.state == MonSiegeDef.waitRunAway then
				--等待逃跑
				oTime = bVar.runAway - now_t
				if oTime > 0 then
					LActor.postScriptEventLite(nil, oTime * 1000, function() onRunAwayCallBack(bVar.starNum, v.idx) end)
				else
					onRunAwayCallBack(bVar.starNum, v.idx)
				end

			elseif bVar.state == MonSiegeDef.resurrection then
				----复活
				oTime = bVar.resurrection - now_t
				if oTime > 0 then
					LActor.postScriptEventLite(nil, oTime * 1000, function() resurrectionCallBack(bVar.starNum, v.idx) end)
				else
					resurrectionCallBack(bVar.starNum, v.idx)
				end
			end
		end
	end
end

function enterFBBefore(ins, actor)
	--特殊处理发送怪物配置
	if not ins.data.param then return end
	local monIdList = {}
	local waveConfs = msWaveConf[ins.data.param]
	for i = 1, #waveConfs do
		local mons = waveConfs[i].mons
		for j = 1, #mons do
			local mon = mons[j]
			monIdList[#monIdList + 1] = mon[1]
		end
	end
	slim.s2cMonsterConfig(actor, monIdList)
end

function exitFB(ins)
	if not ins then return end
	local bConf = monstersiegefb.getBattleConf(ins.data.bIdx)
	if not bConf or bConf.fbType ~= fbType then
		return
	end
	ins:win()
end

msgsystem.regHandle(OffMsgType_MsCommonSettlement, OffMsgActorSettlement)

function init()
	local tbl = {}
	for _,v in pairs(msFBConf) do
		for _,v1 in pairs(v) do
			if v1.fbType == fbType and tbl[v1.fbId] == nil then
				tbl[v1.fbId] = 1
				insevent.registerInstanceMonsterDie(v1.fbId, onMonsterDie)
				insevent.registerInstanceActorDie(v1.fbId, onActorDie)
				insevent.registerInstanceWin(v1.fbId, onWin)
				insevent.registerInstanceLose(v1.fbId, onWin)
				insevent.registerInstanceMonsterDamage(v1.fbId, onMonserDamage)
				insevent.registerInstanceEnterBefore(v1.fbId, enterFBBefore)
				insevent.registerInstanceExit(v1.fbId, exitFB)
			end
		end
	end
end

table.insert(InitFnTable, init)

engineevent.regGameStartEvent(gameStart)

