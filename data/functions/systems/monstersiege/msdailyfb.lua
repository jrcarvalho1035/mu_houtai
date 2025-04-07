module("msdailyfb", package.seeall)
--怪物攻城每日副本（其实跟怪物攻城系统毛线关系没有，只是放在同一个介面）
local msConf = MSDailyFBConf

function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if var.msdailyfb == nil then
		var.msdailyfb = {}
		var.msdailyfb.challenge = 0
	end
	return var.msdailyfb
end

function getInfo(actor, pack)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_MonSiege, Protocol.sMonSiegeCmd_ReqDailyFBInfo)
	if npack == nil then return end
	LDataPack.writeChar(npack, var.challenge)
	LDataPack.flush(npack)
end

function onEnterFuBen(actor, pack)
	local var = getActorVar(actor)
	if var.challenge >= msConf.limit then
		LActor.log(actor,  "msdailyfb.onEnterFuBen", "enter error, not challenge count", var.challenge)
		return
	end

	if not actoritem.checkItem(actor, NumericType_YuanBao, msConf.cost) then
    	LActor.log(actor,  "msdailyfb.onEnterFuBen", "enter error, yuanBao insufficient")
		return
	end

	actoritem.reduceItem(actor, NumericType_YuanBao, msConf.cost, "msDailyEnter")

	local hfb = instancesystem.createFuBen(msConf.fbId)
	local ins = instancesystem.getInsByHdl(hfb)
	if not ins then
		System.log("msdailyfb", "onEnterFuBen", "create ins error", msConf.fbId)
		return
	end
	
	if not LActor.enterFuBen(actor, hfb) then
		LActor.log(actor,  "msdailyfb.onEnterFuBen", "enter fuben error", msConf.fbId)
		return
	end

	var.challenge = var.challenge + 1
end

function onMonsterDie(ins, mon, hKiller)

	local actor = ins:getActorList()[1]
	if not actor then 
		LActor.log(actor,"juexingBoss.onBossDie","actor error")
		return 
	end

	ins:win()
end

function onActorDie(ins,actor)
	if not ins then return end
	ins:lose()
end

function onWin(ins)
	local actors = Fuben.getAllActor(ins.handle)
	if not actors or not actors[1] then
		System.log("msdailyfb", "onWin", "not actor")
		return
	end
	local actor = actors[1]

	actoritem.addItemsByMail(actor, msConf.awards, "msdailyfb", 0, "msfbdaily")
	monstersiegesys.sendSettlementInfo(actor, MonSiegeDef.ftDaily, 1, 0, msConf.awards)
end

function onLose(ins)
	local actors = Fuben.getAllActor(ins.handle)
	if not actors or not actors[1] then
		System.log("msdailyfb", "onLose", "not actor")
		return
	end
	local actor = actors[1]
	monstersiegesys.sendSettlementInfo(actor, MonSiegeDef.ftDaily, 0, 0, nil)
end

function onNewDayLogin(actor)
	if System.isBattleSrv() then return end
	local var = getActorVar(actor)
	var.challenge = 0
end

insevent.registerInstanceMonsterDie(msConf.fbId, onMonsterDie)
insevent.registerInstanceActorDie(msConf.fbId, onActorDie)
insevent.registerInstanceWin(msConf.fbId, onWin)
insevent.registerInstanceLose(msConf.fbId, onLose)

actorevent.reg(aeNewDayArrive, onNewDayLogin)
netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_ReqDailyFBInfo, getInfo)
netmsgdispatcher.reg(Protocol.CMD_MonSiege, Protocol.cMonSiegeCmd_EnterDailyFB, onEnterFuBen)
