module("mschallengelog", package.seeall)
--挑战日志处理
local globalConf = MonSiegeConf

function copyLogTbl(raw, tar)
	raw.awards = {}
	for i=1, tar.awardNum do
		raw.awards[i] = {}
		raw.awards[i].type = tar.awards[i].type
		raw.awards[i].id = tar.awards[i].id
		raw.awards[i].count = tar.awards[i].count
	end
	raw.awardNum = tar.awardNum
	raw.t = tar.t
	raw.tarName = tar.tarName
	raw.isWin = tar.isWin
	raw.hurt = tar.hurt
end

function addLog(actor, isWin, targetName, hurt, awards)
	local var = monstersiegesys.getActorVar(actor)
	if var.challengeLog == nil then var.challengeLog = {} end
	if var.logCount == nil then var.logCount = 0 end
	local now_t = System.getNowTime()
	local num = var.logCount
	if num >= globalConf.maxChallengeLog then
		for i=1, num-1 do
			local curTbl = var.challengeLog[i]
			local nextTbl = var.challengeLog[i+1]
			copyLogTbl(curTbl, nextTbl)
		end
		var.challengeLog[num] = nil
		var.logCount = var.logCount - 1
	end
	num = var.logCount + 1
	var.challengeLog[num] = {}
	local tbl = var.challengeLog[num]
	tbl.t = now_t
	tbl.isWin = isWin
	tbl.tarName = targetName
	tbl.awards = {}
	tbl.hurt = hurt or 0

	for k,v in pairs(awards) do
		tbl.awards[k] = {}
		tbl.awards[k].type = v.type
		tbl.awards[k].id = v.id
		tbl.awards[k].count = v.count
	end
	tbl.awardNum = #awards
	var.logCount = num
end

--获取攻城记录
function getMSLog(actor, pack)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_GetMSLog)
	if npack == nil then return end
	local var = monstersiegesys.getActorVar(actor)
	if var.challengeLog == nil then var.challengeLog = {} end
	if var.logCount == nil then var.logCount = 0 end
	LDataPack.writeChar(npack, var.logCount)
	local award
	local tbl
	for i=1, var.logCount do
		tbl = var.challengeLog[i]
		LDataPack.writeUInt(npack, tbl.t)
		LDataPack.writeString(npack, tbl.tarName)
		LDataPack.writeChar(npack, tbl.isWin)
		LDataPack.writeDouble(npack, tbl.hurt)
		LDataPack.writeChar(npack, #tbl.awards)
		for j=1, #tbl.awards do
			award = tbl.awards[j]
			LDataPack.writeInt(npack, award.type)
			LDataPack.writeInt(npack, award.id)
			LDataPack.writeInt(npack, award.count)
		end
	end
	LDataPack.flush(npack)
end

function clearLog(actor)
	local var = monstersiegesys.getActorVar(actor)
	var.challengeLog = {}
	var.logCount = 0
end


netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_GetMSLog, getMSLog)