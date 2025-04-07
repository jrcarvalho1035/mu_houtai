module("msbossfb", package.seeall)
--boss副本逻辑
--BOSS副本等级配置
local bossFBConf = MSBossLvlConf
local globalConf = MonSiegeConf
local msFBConf = MonSiegeFBConf
local fbType = MonSiegeDef.ftBoss
local rankMaxNum = 100

local ubTimer = 0
local ubInterval = 5

-- local fbDefault = 0 --
-- local fbChallenge = 1 --挑战中
-- local fbOccupied = 2 --占领后
-- local fbEnd = 3 --结束后

function initBossFB(actor, ins, bIdx, bossConf)
	ins.data.confId = bossConf.id
	local bConf = monstersiegefb.getBattleConf(bIdx)

	ins.data.bossLvl = bossConf.lvl
	ins.data.bIdx = bIdx
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if bVar.publicHP < 0 or bVar.state == MonSiegeDef.bfbEnd then
		bVar.publicHP = bossConf.hp

	end
	ins.data.maxHp = bossConf.hp
	bVar.challengeCount = bVar.challengeCount + 1
	if bVar.settlement > 0 and bVar.settlement < ins:getEndTime() then
		ins:setEndTime(bVar.settlement)
	end
	local aId = LActor.getActorId(actor)
	ins.data.actorId = aId

	--特殊处理发送怪物配置
	local monIdList = {bossConf.monId}
	slim.s2cMonsterConfig(actor, monIdList)

	local monName = MonstersConfig[bConf.monsterId].name
	ins.data.bossName = string.format(globalConf.nameStr, monName, bConf.monsterName)
	createMonster(ins)
end

function initImageFB(actor, ins, bIdx, bConf, imageInfo)
	ins.data.confId = bConf.id
	ins.data.bIdx = bIdx
	local aId = LActor.getActorId(actor)
	ins.data.actorId = aId

	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if bVar.attriTime < ins:getEndTime() then
		ins:setEndTime(bVar.attriTime)
	end
	ins.data.imageName = imageInfo.aName

	local actorId = imageInfo.id
	local roleCloneDatas, damonData, roleSuperData = actorcommon.getCloneData(actorId)
	
	local roleCloneDataCount = #roleCloneDatas
	if roleCloneDataCount < 0 or roleCloneDataCount > MAX_ROLE then
		return
	end

	for i = 1, roleCloneDataCount do
		local roleCloneData = roleCloneDatas[i]
		roleCloneData.ai = FubenConstConfig.jobAi[roleCloneData.job]
	end
	if damonData then
		damonData.ai = FubenConstConfig.damonAi
		local damonConf = DamonConfig[damonData.id]
		if damonConf then
			damonData.speed = damonConf.MvSpeed
		end
	end

	if roleSuperData then 
		roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1],FubenConstConfig.randChangeTime[2])
		roleSuperData.aiId = FubenConstConfig.roleSuperAi
    end

	local sceneHandle = ins.scene_list[1]
	local actorClone = LActor.createActorCloneWithData(actorId, sceneHandle, bConf.posX, bConf.posY, roleCloneDatas, damonData, roleSuperData) 

end

function checkIsStarTime()
	local now_t = System.getNowTime()
	local year, month, day, _, _, _ = System.timeDecode(now_t)
	local tTbl = globalConf.bossRsfTime
	local sTime = System.timeEncode(year, month, day, tTbl[1], tTbl[2], tTbl[3])
	if now_t <= sTime or now_t >= sTime + globalConf.bossKeepTime then
		return false
	end
	return true
end

function createMonster(ins)
	local conf = bossFBConf[ins.data.confId][ins.data.bossLvl]
	local hScene = ins.scene_list[1]
	local pMon = Fuben.createMonster(hScene, conf.monId, conf.posX, conf.posY)
end

--副本伤害事件
local function onBossDamage(ins, monster, value, attacker)
	if not attacker then
		return
	end
	local actor = LActor.getActor(attacker)
	if not actor then return end
	local bIdx = ins.data.bIdx
	local bConf = monstersiegefb.getBattleConf(bIdx)
	if bConf.fbType ~= fbType then
		return
	end
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if bVar.state > MonSiegeDef.bfbChallenge then
		return
	end
	if bVar.publicHP <= 0 then
		return
	end
	value = (bVar.publicHP >= value) and value or bVar.publicHP
	bVar.publicHP = bVar.publicHP - value
	msbossdamageinfo.onDamage(bIdx, value, actor)
	if bVar.publicHP <= 0 then

		local tbl = globalConf.bossAddLvl
		if bVar.challengeCount >= tbl[#tbl].count then
			bVar.curLvl = bVar.curLvl + tbl[#tbl].lvl
		else
			for k,v in ipairs(tbl) do
				if bVar.challengeCount <= v.count then
					bVar.curLvl = bVar.curLvl + v.lvl
					break
				end
			end
		end
		if not bossFBConf[bConf.param][bVar.curLvl] then
			bVar.curLvl = #bossFBConf[bConf.param]
		end
		ins:win()
		for i=1, #bVar.hfbList do
			local hfb = bVar.hfbList[i]
			local tempIns = instancesystem.getInsByHdl(hfb)
			if tempIns and ins ~= tempIns and not tempIns.is_end then
				tempIns:lose()
			end
		end
		onAttriSettlement(bIdx)
	end
end

local function onCloneRoleDamage(ins, monster, value, attacker)
	if not attacker then
		return
	end
	ins.data.cloneRoleMaxHp = LActor.getCloneRoleTotalMaxHP(ins.scene_list[1])
	if ins.data.cloneRoleCurHp == nil then
		ins.data.cloneRoleCurHp = ins.data.cloneRoleMaxHp
	end
	ins.data.cloneRoleCurHp = ins.data.cloneRoleCurHp - value
end

function sendDamageRank(actor, bIdx)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_DamageRank)
	if npack == nil then return end

	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	msbossdamageinfo.getRankPack(bVar.bossData, npack, rankMaxNum)
	LDataPack.flush(npack)
end

_G.monsterSiegeBossStart = function()
	if System.isBattleSrv() then return end
	if not actorexp.checkLevelCondition1(actorexp.LimitTp.siege) then
		return
	end

	local weekDay = monstersiegesys.getWeekDay()
	local weekConf = msFBConf[weekDay]
	local now_t = System.getNowTime()
	for k,v in ipairs(weekConf) do
		if v.fbType == fbType then
			local bVar = monstersiegesys.getBVarByIdx(v.idx)

			bVar.settlement = now_t + globalConf.bossKeepTime
			bVar.state = MonSiegeDef.bfbChallenge
			LActor.postScriptEventLite(nil, globalConf.bossKeepTime * 1000, function() onAttriSettlement(v.idx) end)
		end
	end
	monstersiegesys.sendSysInfo()
	noticesystem.broadCastNotice(noticesystem.NTP.monSiege3)
end

--时间到和BOSS死掉都需要回调
function onAttriSettlement(bIdx)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if bVar.state >= MonSiegeDef.bfbOccupied then
		return
	end
	if bVar.settlement <= 0 then return end
	local now_t = System.getNowTime()
	bVar.settlement = 0
	bVar.publicHP = 0


	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	local tbl = msbossdamageinfo.getFirstRankPlayer(bVar.bossData)
	local hasImage = tbl.aName and true or false
	
	--广播
	if hasImage then
		noticesystem.broadCastNotice(noticesystem.NTP.monSiege4, tbl.aName)
		-- "玩家XXX在阻止BOSSXXX中伤害最高，获得丰厚奖励，BOSS狼狈的逃走，留下稀有宝贝，各位勇士可前去抢夺！"
		if tbl.id and tbl.id ~= 0 then
			local mailData = { head=globalConf.imageGiftTitle, context=globalConf.imageGiftCont, tAwardList=globalConf.imageGiftItem }
			mailsystem.sendMailById(tbl.id, mailData)
		end
	else
		noticesystem.broadCastNotice(noticesystem.NTP.monSiege8, tbl.aName)
	end

	--镜像
	if hasImage then
		bVar.state = MonSiegeDef.bfbOccupied
		local tTbl = globalConf.imageKeepTime
		local y, m, d, _, _, _ = System.timeDecode(now_t)
		bVar.attriTime = System.timeEncode(y, m, d, tTbl[1], tTbl[2], tTbl[3])
		local overTime = bVar.attriTime - now_t
		LActor.postScriptEventLite(nil, overTime * 1000, function() onImageEnd(bIdx) end)
	else
		bVar.state = MonSiegeDef.bfbEnd
	end

	monstersiegesys.updateSysInfo(bIdx)
end

function settlementAnno(bIdx)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	local tbl = msbossdamageinfo.getFirstRankPlayer(bVar.bossData)
	if tbl.aName then
		noticesystem.broadCastNotice(noticesystem.NTP.monSiege4, tbl.aName)
		-- "玩家XXX在阻止BOSSXXX中伤害最高，获得丰厚奖励，BOSS狼狈的逃走，留下稀有宝贝，各位勇士可前去抢夺！"
		if tbl.id and tbl.id ~= 0 then
			local mailData = { head=globalConf.imageGiftTitle, context=globalConf.imageGiftCont, tAwardList=globalConf.imageGiftItem }
			mailsystem.sendMailById(tbl.id, mailData)
		end
	else
		noticesystem.broadCastNotice(noticesystem.NTP.monSiege8, tbl.aName)
	end
end

--时间到和奖励领完都需要回调
function onImageEnd(bIdx)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if bVar.state >= MonSiegeDef.bfbEnd then return end
	bVar.state = MonSiegeDef.bfbEnd

	local tbl = msbossdamageinfo.getFirstRankPlayer(bVar.bossData)
	if tbl.id and tbl.id ~= 0 then
		--有归属才发奖励
		msimagerankaward.imageAwardSettlement(tbl.id)
		noticesystem.broadCastNotice(noticesystem.NTP.monSiege7, tbl.aName or "")
	end

	monstersiegesys.resetBattleData(bIdx)
	monstersiegesys.updateSysInfo(bIdx)
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
			if bVar.state == MonSiegeDef.bfbEnd or bVar.state < MonSiegeDef.bfbChallenge then
				if checkIsStarTime() then

					local year, month, day, _, _, _ = System.timeDecode(now_t)
					local tTbl = globalConf.bossRsfTime
					local sTime = System.timeEncode(year, month, day, tTbl[1], tTbl[2], tTbl[3])

					bVar.settlement = sTime + globalConf.bossKeepTime
					bVar.state = MonSiegeDef.bfbChallenge
					local t = bVar.settlement - now_t
					LActor.postScriptEventLite(nil, t * 1000, function() onAttriSettlement(v.idx) end)
				end
			elseif bVar.state >= MonSiegeDef.bfbChallenge and bVar.state < MonSiegeDef.bfbOccupied then
				oTime = bVar.settlement - now_t
				if oTime > 0 then
					LActor.postScriptEventLite(nil, oTime * 1000, function() onAttriSettlement(v.idx) end)
				else
					onAttriSettlement(v.idx)
				end
			elseif bVar.state >= MonSiegeDef.bfbOccupied and bVar.state < MonSiegeDef.bfbEnd then
				oTime = bVar.attriTime - now_t
				if oTime > 0 then
					LActor.postScriptEventLite(nil, oTime * 1000, function() onImageEnd(v.idx) end)
				else
					onImageEnd(v.idx)
				end
			elseif bVar.state >= MonSiegeDef.bfbEnd then
			end
		end
	end

end

local function onActorDie(ins,actor)
	if not ins then return end
	local bConf = monstersiegefb.getBattleConf(ins.data.bIdx)
	if bConf.fbType ~= fbType then
		return
	end
	ins:lose()
end

local function onActorCloneDie(ins)
	if not ins then
		return
	end
	local actor = ins:getActorList()[1]
	if actor == nil then
		return
	end
	local bConf = monstersiegefb.getBattleConf(ins.data.bIdx)
	if bConf.fbType ~= fbType then
		return
	end
	ins:win()
end

function onWin(ins)
	local bIdx = ins.data.bIdx
	local bVar = monstersiegesys.getBVarByIdx(bIdx)

	if bVar.state == MonSiegeDef.bfbChallenge then
		--挑战中
		local actorId = ins.data.actorId
		local hurt = msbossdamageinfo.getActorHurt(bVar.bossData, actorId)
		msbossdamageinfo.sortDamage(bVar.bossData.bossInfo)

		local conf = bossFBConf[ins.data.confId][ins.data.bossLvl]
		local awards = drop.dropGroup(conf.dropId)
		local actor = LActor.getActorById(actorId)
		if actor then
			ActorChallengeFBEnd(actor, 1, ins.data.bossName, hurt, awards, true)
		else
			local npack = LDataPack.allocPacket()
			LDataPack.writeByte(npack, 1)
			LDataPack.writeString(npack, ins.data.bossName)
			LDataPack.writeInt64(npack, hurt)
			LDataPack.writeString(npack, utils.serialize(awards))
			System.sendOffMsg(actorId, 0, OffMsgType_MsBossChallenge, npack)
		end
		monstersiegesys.updateSysInfo(bIdx)
	elseif bVar.state == MonSiegeDef.bfbOccupied then
		--占领后，镜象状态
		local actorId = ins.data.actorId
		local actor = LActor.getActorById(actorId)
		local aName = ""
		if actor then
			aName = LActor.getName(actor)
		else
			local EBasicData = GetDataByOffLineDataType(actorId, EOffLineDataType.EBasic)
			if EBasicData then
				aName = EBasicData.actor_name
			end
		end
		local maxHp = ins.data.cloneRoleMaxHp or 0

		local hasWinAwards, awards = msimagerankaward.imageHurtAward(aName, 100)
		if hasWinAwards then
			local tbl = msbossdamageinfo.getFirstRankPlayer(bVar.bossData)
			noticesystem.broadCastNotice(noticesystem.NTP.monSiege6, aName, tbl.aName or "")
		end

		if actor then
			ActorOccupiedFBEnd(actor, 1, ins.data.imageName, maxHp, awards, true)
		else
			local npack = LDataPack.allocPacket()
			LDataPack.writeByte(npack, 1)
			LDataPack.writeString(npack, ins.data.imageName)
			LDataPack.writeInt64(npack, maxHp)
			LDataPack.writeString(npack, utils.serialize(awards))
			System.sendOffMsg(actorId, 0, OffMsgType_MsBossOccupied, npack)
		end
	end
end

function onLose(ins)
	local bIdx = ins.data.bIdx
	local bVar = monstersiegesys.getBVarByIdx(bIdx)

	if bVar.state == MonSiegeDef.bfbChallenge then
		--挑战中
		local actorId = ins.data.actorId
		local hurt = msbossdamageinfo.getActorHurt(bVar.bossData, actorId)
		msbossdamageinfo.sortDamage(bVar.bossData.bossInfo)

		local conf = bossFBConf[ins.data.confId][ins.data.bossLvl]
		local awards = drop.dropGroup(conf.dropId)
		local actor = LActor.getActorById(actorId)
		if actor then
			ActorChallengeFBEnd(actor, 0, ins.data.bossName, hurt, awards, true)
		else
			local npack = LDataPack.allocPacket()
			LDataPack.writeByte(npack, 0)
			LDataPack.writeString(npack, ins.data.bossName)
			LDataPack.writeDouble(npack, hurt)
			LDataPack.writeString(npack, utils.serialize(awards))
			System.sendOffMsg(actorId, 0, OffMsgType_MsBossChallenge, npack)
		end
		monstersiegesys.updateSysInfo(bIdx)
	elseif bVar.state == MonSiegeDef.bfbOccupied then
		--占领后，镜象状态
		local actorId = ins.data.actorId
		local actor = LActor.getActorById(actorId)

		local maxHp = ins.data.cloneRoleMaxHp or 0
		local curHp = ins.data.cloneRoleCurHp or maxHp
		local percent = 0
		local hurt = 0
		if maxHp and maxHp > 0 then
			maxHp = (maxHp <= 0) and 1 or maxHp
			percent = 100 - math.floor((curHp / maxHp) * 100)
			if percent < 0 then
				percent = 0
			end
			if percent > 100 then
				percent = 100
			end
			
			hurt = maxHp - curHp
		end

		local aName = ""
		if actor then
			aName = LActor.getName(actor)
		else
			local EBasicData = GetDataByOffLineDataType(actorId, EOffLineDataType.EBasic)
			if EBasicData then
				aName = EBasicData.actor_name
			end
		end
		
		local hasWinAwards, awards = msimagerankaward.imageHurtAward(aName, percent)
		if hasWinAwards then
			local tbl = msbossdamageinfo.getFirstRankPlayer(bVar.bossData)
			noticesystem.broadCastNotice(noticesystem.NTP.monSiege6, aName, tbl.aName or "")
		end

		if actor then
			ActorOccupiedFBEnd(actor, 0, ins.data.imageName, hurt, awards, true)
		else
			local npack = LDataPack.allocPacket()
			LDataPack.writeByte(npack, 0)
			LDataPack.writeString(npack, ins.data.imageName)
			LDataPack.writeDouble(npack, maxHp)
			LDataPack.writeString(npack, utils.serialize(awards))
			System.sendOffMsg(actorId, 0, OffMsgType_MsBossOccupied, npack)
		end
	end
end

function ActorChallengeFBEnd(actor, isWin, bossName, hurt, awards, isSend)
	actoritem.addItemsByMail(actor, awards, "msBossFB challengeAward", 0, "msfbfight")
	mschallengelog.addLog(actor, isWin, bossName, hurt, awards)
	utils.logCounter(actor, "msBossFB", tostring(hurt), "", (isWin == 0) and "lose" or "win")
	if isSend then
		monstersiegesys.sendSettlementInfo(actor, MonSiegeDef.ftBoss, isWin, hurt, awards)
	end
end

function OffMsgActorChallengeFBEnd(actor, offmsg)
	local isWin = LDataPack.readByte(offmsg)
	local bossName = LDataPack.readString(offmsg)
	local hurt = LDataPack.readInt64(offmsg)
	local awardsString = LDataPack.readString(offmsg)
	local awards = utils.unserialize(awardsString)
	ActorChallengeFBEnd(actor, isWin, bossName, hurt, awards)
end

function ActorOccupiedFBEnd(actor, isWin, bossName, hurt, awards, isSend)
	actoritem.addItemsByMail(actor, awards, "msBossFB occupiedAward", 0, "msfboccup")
	mschallengelog.addLog(actor, isWin, bossName, hurt, awards)
	if isSend then
		monstersiegesys.sendSettlementInfo(actor, MonSiegeDef.ftImage, isWin, hurt, awards)
	end
end

function OffMsgActorOccupiedFBEnd(actor, offmsg)
	local isWin = LDataPack.readByte(offmsg)
	local bossName = LDataPack.readString(offmsg)
	local hurt = LDataPack.readInt64(offmsg)
	local awardsString = LDataPack.readString(offmsg)
	local awards = utils.unserialize(awardsString)
	ActorOccupiedFBEnd(actor, isWin, bossName, hurt, awards)
end

function enterFBBefore(ins, actor)
	--特殊处理发送怪物配置
	if not ins.data.confId  then return end
	local bossConf = bossFBConf[ins.data.confId][ins.data.bossLvl]
	local monIdList = {bossConf.monId}
	slim.s2cMonsterConfig(actor, monIdList)
end

function exitFB(ins)
	if not ins then return end
	local bConf = monstersiegefb.getBattleConf(ins.data.bIdx)
	if not bConf or bConf.fbType ~= fbType then
		return
	end
	ins:lose()
end

msgsystem.regHandle(OffMsgType_MsBossChallenge, OffMsgActorChallengeFBEnd)
msgsystem.regHandle(OffMsgType_MsBossOccupied, OffMsgActorOccupiedFBEnd)

function init()
	local tbl = {}
	for _,v in pairs(msFBConf) do
		for _,v1 in pairs(v) do
			if v1.fbType == fbType and tbl[v1.fbId] == nil then
				tbl[v1.fbId] = 1
				insevent.registerInstanceActorDie(v1.fbId, onActorDie)
				insevent.regActorCloneDie(v1.fbId, onActorCloneDie)
				insevent.registerInstanceMonsterDamage(v1.fbId, onBossDamage)
				insevent.registerInstanceRoleCloneDamage(v1.fbId, onCloneRoleDamage)
				insevent.registerInstanceWin(v1.fbId, onWin)
				insevent.registerInstanceLose(v1.fbId, onLose)
				insevent.registerInstanceEnterBefore(v1.fbId, enterFBBefore)
				insevent.registerInstanceExit(v1.fbId, exitFB)
			end
		end
	end
end

table.insert(InitFnTable, init)

engineevent.regGameStartEvent(gameStart)

