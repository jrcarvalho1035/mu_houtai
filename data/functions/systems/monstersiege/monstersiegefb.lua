module("monstersiegefb", package.seeall)
--副本逻辑
--全局配置
local msWaveConf = MonSiegeWaveConf
--副本总配置
local globalConf = MonSiegeConf
--普通副本波数配置
local msFBConf = MonSiegeFBConf
--BOSS副本等级配置
local bossFBConf = MSBossLvlConf
local langScript = ScriptTips

siegeLogic = {}

function getBattleConf(bIdx)
	local weekDay = monstersiegesys.getWeekDay()
	local weekConf = msFBConf[weekDay]
	return weekConf[bIdx]
end

function onSiege(actor, bIdx, ...)
	LActor.log(actor,  "monstersiegefb.onSiege", "call", bIdx)

	local bConf = getBattleConf(bIdx)
	local lastLoginCount = monstersiegesys.getLastLoginCount()
	if lastLoginCount > 0 and lastLoginCount < bConf.login then
		LActor.log(actor,  "monstersiegefb.onSiege", "last login actor count inadequate", bIdx)
		return
	end
	if bConf then
		local func = siegeLogic[bConf.fbType]
		if func then
			func(actor, bIdx, bConf, ...)
		end
	end
end

siegeLogic[MonSiegeDef.ftCommon] = function(actor, bIdx, bConf, ...)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	if (#bVar.attriList) >= globalConf.challengeNum then
		LActor.sendTipmsg(actor, langScript.mssys012, ttMessage)
		return
	end

	if bVar.state == MonSiegeDef.resurrection then
		LActor.sendTipmsg(actor, langScript.mssys015, ttMessage)
		return
	end

	if msfbcountrestore.getFBCount(actor) <= 0 then
		LActor.sendTipmsg(actor, langScript.mssys009, ttMessage)
		return
	end

	local aId = LActor.getActorId(actor)
	local tbl = monstersiegesys.getAttriData(bIdx, aId)
	if tbl then
		-- print("你已挑战过此副本，无法重复再挑战:"..bIdx)
		LActor.sendTipmsg(actor, langScript.mssys007, ttMessage)
		return
	end

	local hfb = instancesystem.createFuBen(bConf.fbId)
	local ins = instancesystem.getInsByHdl(hfb)
		if not ins then
		System.log("monstersiegefb", "siegeLogic", "not ins", bIdx, hfb)
		return
	end
	
	bVar.hfbList[#bVar.hfbList + 1] = hfb
	if LActor.enterFuBen(actor, hfb) then
		mscommonfb.initFB(ins, actor, bIdx, bConf)

		local idx = (#bVar.attriList) + 1
		bVar.attriList[idx] = {}
		tbl = bVar.attriList[idx]

		tbl.aId = aId
		tbl.aName = LActor.getName(actor)
		tbl.damage = 0
		tbl.sex = LActor.getSex(actor)
		tbl.job = LActor.getJob(actor)
		tbl.state = MonSiegeDef.aafbtStar
		msfbcountrestore.changeFBCount(actor, -1)
		monstersiegesys.updateSysInfo(bIdx)
	else
		LActor.log(actor,  "monstersiegefb.siegeLogic", "enter common FuBen error", hfb, bIdx)
		return
	end
end

siegeLogic[MonSiegeDef.ftBoss] = function(actor, bIdx, bConf, ...)
	local bVar = monstersiegesys.getBVarByIdx(bIdx)
	local bt = arg[1]
	if bt == 0 then
		--BOSS
		if bVar.state == MonSiegeDef.bfbOccupied then
			LActor.sendTipmsg(actor, langScript.mssys013, ttMessage)
			monstersiegesys.getSysInfo(actor, nil)
			return
		end
	else
		--镜象
		if bVar.state == MonSiegeDef.bfbEnd then
			LActor.sendTipmsg(actor, langScript.mssys014, ttMessage)
			monstersiegesys.getSysInfo(actor, nil)
			return
		end
	end

	if bVar.state < MonSiegeDef.bfbOccupied then
		if not msbossfb.checkIsStarTime() then
			LActor.log(actor,  "monstersiegefb.siegeLogic", "not in the boss opening time range", bIdx)
			return
		end

		--开始后,占领前
		local aId = LActor.getActorId(actor)
		if bVar.bossActors[aId] then
			-- print("BOSS挑战次数已满")
			LActor.sendTipmsg(actor, langScript.mssys008, ttMessage)
			return
		end
		local hfb = instancesystem.createFuBen(bConf.fbId)
		local ins = instancesystem.getInsByHdl(hfb)
		if ins then
			bVar.weekDay = monstersiegesys.getWeekDay()
			msbossfb.initBossFB(actor, ins, bIdx, bossFBConf[bConf.param][bVar.curLvl])
		else
			LActor.log(actor,  "monstersiegefb.siegeLogic", "create boss FuBen error", bIdx)
			return 
		end
		bVar.hfbList[#bVar.hfbList + 1] = hfb
		if not LActor.enterFuBen(actor, hfb) then
			LActor.log(actor,  "monstersiegefb.siegeLogic", "enter boss FuBen error", hfb, bIdx)
			return
		end
		local var = monstersiegesys.getActorVar(actor)
		bVar.bossActors[aId] = 1
		bVar.bossActorsCount = bVar.bossActorsCount + 1
	elseif bVar.state < MonSiegeDef.bfbEnd then
		local aId = LActor.getActorId(actor)
		if bVar.imageActors[aId] then
			LActor.sendTipmsg(actor, langScript.mssys009, ttMessage)
			return
		end
		local tbl = msbossdamageinfo.getFirstRankPlayer(bVar.bossData)
		if tbl.id and tbl.id ~= 0 then
			--占领后,结束前,打镜象
			local hfb = instancesystem.createFuBen(globalConf.imageFB)
			local ins = instancesystem.getInsByHdl(hfb)

			if not LActor.enterFuBen(actor, hfb) then
				LActor.log(actor,  "monstersiegefb.siegeLogic", "enter boss FuBen error", hfb, bIdx)
				return
			end
			msbossfb.initImageFB(actor, ins, bIdx, bossFBConf[bConf.param][bVar.curLvl], tbl)
			bVar.imageActors[aId] = 1
			bVar.imageActorsCount = bVar.imageActorsCount + 1
		end
	end
end
