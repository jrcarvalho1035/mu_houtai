module("msscoreaward", package.seeall)
--积分奖励
local msScoreAwardConf = MSScoreAwardConf
local rankMaxNum = 100
local langScript = ScriptTips

function getSysVar()
	local var = monstersiegesys.getSysVar()
	if var.scoreAward == nil then
		var.scoreAward = {}
	end
	return var
end

function resetActorVar(actor, flag)
	local var = monstersiegesys.getActorVar(actor)
	var.awardCode = 0
	var.score = 0
	var.Timerflag = flag
	actoritem.reduceItem(actor, NumericType_SiegeScore, var.score , "msscoreaward reset")
end

function addScore(actor, val, log)
	if not monstersiegesys.sysIsOpen() then return end
	if val == 0 then return end
	local var = monstersiegesys.getActorVar(actor)
	var.score = var.score + val

	setActorScoreRank(actor, var.score)
end

function getScore(actor)
	local var = monstersiegesys.getActorVar(actor)
	return var.score or 0
end

--无用，通过货币协议下发
function sendScore(actor)
	local var = monstersiegesys.getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_UpdateScore)
	if npack == nil then return end
	LDataPack.writeInt(npack, var.score)
	LDataPack.flush(npack)
end

function getSysAwardCode()
	local sysVar = getSysVar()
	return sysVar.scoreAward
end

function getActorAwardCode(actor)
	local var = monstersiegesys.getActorVar(actor)
	return var.awardCode
end

function onGetScoreAward(actor, pack)
	local idx = LDataPack.readByte(pack)
	local conf = msScoreAwardConf[idx]
	if not conf then return end

	local var = monstersiegesys.getActorVar(actor)
	if var.score < conf.score then
		-- print("当前积分不足，无法领取奖励")
		LActor.sendTipmsg(actor, langScript.mssys003, ttMessage)
		return
	end

	local sysVar = getSysVar()
	if sysVar.scoreAward[idx] == nil then
		sysVar.scoreAward[idx] = 0
	end

	if sysVar.scoreAward[idx] >= conf.count then
		-- print("礼包剩余数量不足")
		LActor.sendTipmsg(actor, langScript.mssys004, ttMessage)
		sendServerScoreInfo(actor)
		return
	end

	if System.bitOPMask(var.awardCode, idx) then
		-- print("此奖励已领取过，不能重复领取")
		LActor.sendTipmsg(actor, langScript.mssys005, ttMessage)
		return
	end

	if not actoritem.checkEquipBagSpace(actor, conf.award) then
		print("msscoreaward.onGetScoreAward checkEquipBagSpace fail")
		return
	end

	var.awardCode = System.bitOpSetMask(var.awardCode, idx, true)
	sysVar.scoreAward[idx] = sysVar.scoreAward[idx] + 1
	actoritem.addItems(actor, conf.award, "msscoreaward")
	sendSelfScoreInfo(actor)
	sendServerScoreInfo(actor)
end


--更新个人积分奖励信息
function sendSelfScoreInfo(actor)
	local var = monstersiegesys.getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_SelfScoreAwardInfo)
	if npack == nil then return end
	LDataPack.writeInt(npack, var.awardCode or 0)
	LDataPack.flush(npack)
end

--更新全服积分礼包信息
function sendServerScoreInfo(actor)
	local sysVar = getSysVar()
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_ServerScoreAwardInfo)
	if npack == nil then return end

	LDataPack.writeByte(npack, #msScoreAwardConf)
	for i=1, #msScoreAwardConf do
		LDataPack.writeShort(npack, sysVar.scoreAward[i] or 0)
	end
	LDataPack.flush(npack)
end

function getScoreRank()
	local rankName = "msscorerank"
	local rank = Ranking.getRanking(rankName)
	if rank then return rank end
	local rankFile = "msscorerank.rank"
	local coloumns = {"name"}

	rank = utils.rankfunc.InitRank(rankName, rankFile, rankMaxNum, coloumns, false)
	-- Ranking.setAutoSave(rank, true)
	Ranking.save(rank, rankFile)
	Ranking.setAutoSave(rank, true)

	return rank
end

function setActorScoreRank(actor, score)
	local rank = getScoreRank()
	if not rank then return nil end
	local id = LActor.getActorId(actor)
	local item = Ranking.getItemPtrFromId(rank, id)
	if item then
		item = Ranking.setItem(rank, id, score)
	else
		item = Ranking.addItem(rank, id, score)
		Ranking.setSub(item, 0, LActor.getName(actor))
	end
end

function onScoreRank(actor, pack)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_ReqScoreRank)
	if npack == nil then return end

	local rank = getScoreRank()
	local count = Ranking.getRankItemCount(rank)
	count = (count < rankMaxNum) and count or rankMaxNum
	LDataPack.writeShort(npack, count)
	for i=1, count do
		local item = Ranking.getItemFromIndex(rank, i-1)
		LDataPack.writeInt(npack, Ranking.getId(item))
		LDataPack.writeString(npack, Ranking.getSub(item, 0))
		LDataPack.writeInt(npack, Ranking.getPoint(item))
	end
	LDataPack.flush(npack)
end

function onLogin(actor)
	if System.isBattleSrv() then return end
	local sysVar = monstersiegesys.getSysVar()
	local var = monstersiegesys.getActorVar(actor)

	local now_t = System.getNowTime()
	if var.Timerflag == nil then
		var.Timerflag = now_t
	end

	if not System.isSameWeek(now_t, var.Timerflag) then
		resetActorVar(actor, now_t)
	end

	--因为合服，所以有下面这段代码
	local rank = getScoreRank()
	if not rank then return nil end
	local var = monstersiegesys.getActorVar(actor)
	if var.score and var.score > 0 then
		local id = LActor.getActorId(actor)
		local item = Ranking.getItemPtrFromId(rank, id)
		if not item then
			item = Ranking.addItem(rank, id, var.score)
			Ranking.setSub(item, 0, LActor.getName(actor))
		end
	end

	sendSelfScoreInfo(actor)
	sendServerScoreInfo(actor)
end

function onNewDay(actor, isLogin)
	if System.isBattleSrv() then return end
	if isLogin then return end
	onLogin(actor)
end


onChangeName = function(actor, res, name, rawName, way)
	local rank = Ranking.getRanking("msscorerank")
	if rank then
		local actorId = LActor.getActorId(actor)
		local item = Ranking.getItemPtrFromId(rank, actorId)
		if item then
			Ranking.setSub(item, 0, name)
		end
	end
end

actorevent.reg(aeChangeName, onChangeName)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)

netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_GetScoreAward, onGetScoreAward)
netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_ReqScoreRank, onScoreRank)





