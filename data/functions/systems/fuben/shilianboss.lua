--装备副本
module("shilianboss", package.seeall)

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.shilianboss then var.shilianboss = {} end
	if not var.shilianboss.fightcount then var.shilianboss.fightcount = {} end
	if not var.shilianboss.refreshtime then var.shilianboss.refreshtime = {} end
	return var.shilianboss
end

--进入副本
function onEnterFuben(actor, idx)
	local conf = ShilianBossConfig[idx]
	if not conf then return end
	if LActor.getLevel(actor) < conf.level then return end
	if not zhuansheng.checkZSLevel(actor, conf.zsLevel) then
		print("shilian boss req failed.. zslevel. aid:"..LActor.getActorId(actor))
		return
	end
	local var = getActorVar(actor)
	local now = System.getNowTime()
	if var.refreshtime[idx] and var.refreshtime[idx] ~= 0 and var.refreshtime[idx] > now then return end --未到刷新时间
	if (var.fightcount[idx] or 0) >= ShilianCommonConfig.maxCount then return end
	if not utils.checkFuben(actor, conf.fbId) then return end
	local fbHandle = instancesystem.createFuBen(conf.fbId)
	if not fbHandle or fbHandle == 0 then return end

	updateBossInfo(actor, {[1]=idx})
	local x, y = utils.getSceneEnterCoor(conf.fbId)
	LActor.enterFuBen(actor, fbHandle, 0, x, y)
end

function updateBossInfo(actor, idxs)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_ShilianUpdate)
	LDataPack.writeShort(pack, #idxs)
	for i=1, #idxs do
		LDataPack.writeShort(pack, idxs[i])
		LDataPack.writeShort(pack, ShilianCommonConfig.maxCount - (var.fightcount[idxs[i]] or 0))
		local now = System.getNowTime()
		LDataPack.writeInt(pack, (var.refreshtime[idxs[i]] or 0) - now > 0 and (var.refreshtime[idxs[i]] or 0) - now or 0)
	end
	LDataPack.flush(pack)
end

function onEnterFb(ins, actor, isLogin)
	if not isLogin then --登录重进副本不刷新
		ins:postponeStart()
	end
end

function onMonsterDie(ins, mon, killer_hdl)
	local monId = LActor.getId(mon)
	if MonstersConfig[monId].type ~= 1 then return end
	local et = LActor.getEntity(killer_hdl)
	local actor = LActor.getActor(et)
	local var = getActorVar(actor)
	for k, conf in pairs(ShilianBossConfig) do
		if conf.fbId == ins.id then
			var.refreshtime[k] = System.getNowTime() + conf.reborntime
			updateBossInfo(actor, {[1] = k})
			if conf.bossId == monId then
				local rewards = drop.dropGroup(conf.dropid)
				local isopen, dropindexs = subactivity12.checkIsStart()
				if isopen then
					for j=1, #dropindexs do
						local rewards1 = drop.dropGroup(conf.actRewards[dropindexs[j]])
						for i=1, #rewards1 do
							table.insert(rewards, {type = rewards1[i].type, id = rewards1[i].id, count = rewards1[i].count})
						end
					end
				end
				local posX, posY = LActor.getEntityScenePoint(mon)
				ins:addDropBagItem(actor, rewards, 10, posX, posY, true)
			end
			break
		end
	end

	subactivity1.onKillBoss(actor)
end
--挑战通关
function onShilianWin(ins)
	local actor = ins:getActorList()[1]
	local var = getActorVar(actor)
	if not var then return end

	for key, conf in pairs(ShilianBossConfig) do
		if conf.fbId == ins.id then
			var.fightcount[key] = (var.fightcount[key] or 0) + 1
			break
		end
	end

	s2cShilianInfo(actor)
	--actorevent.onEvent(actor, aeBeatShilianBoss, idx)
end

local function delayStartFight(_, ins)
	ins:postponeStart()
end

--延迟刷boss
function ShilianDeferEarly(ins, actor)
	ins:postponeStop()
	ins:notifyBossWarn()
	LActor.postScriptEventLite(nil, 2*1000, delayStartFight, ins)
end

local function onLogin(actor)
	s2cShilianInfo(actor)
end

local function onNewDay(actor, login)
	local var = getActorVar(actor)
	if not var then return end
	for i=1, #ShilianBossConfig do
		var.refreshtime[i] = 0
		var.fightcount[i] = 0
	end
	if not login then
		s2cShilianInfo(actor)
	end
end

local function onVip(actor, vip)
	s2cShilianInfo(actor)
end

---------------------------------------------------------------------------------------------
function s2cShilianInfo(actor)
	local var = getActorVar(actor)
	local vip = LActor.getSVipLevel(actor)
	local now = System.getNowTime()
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_ShilianInfo)
	LDataPack.writeShort(pack, #ShilianBossConfig)
	for k,v in ipairs(ShilianBossConfig) do
		LDataPack.writeShort(pack, k)
		LDataPack.writeShort(pack, ShilianCommonConfig.maxCount - (var.fightcount[k] or 0))
		LDataPack.writeInt(pack, (var.refreshtime[k] or 0) - now > 0 and (var.refreshtime[k] or 0) - now or 0)
		LDataPack.writeInt(pack, v.bossId)
		LDataPack.writeString(pack, MonstersConfig[v.bossId].name)
		LDataPack.writeString(pack, MonstersConfig[v.bossId].head)
		LDataPack.writeShort(pack, MonstersConfig[v.bossId].avatar[1])
	end
	LDataPack.flush(pack)
end

--试炼挑战
function c2sShilianFight(actor, packet)
	local idx = LDataPack.readInt(packet)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.shilianboss) then
		return
	end
	onEnterFuben(actor, idx)
end

function c2sShilianOneKey(actor)
	local svip = LActor.getSVipLevel(actor)
	if svip < ShilianCommonConfig.viplevel then return end
	local level = LActor.getLevel(actor)

	local ritems = {}
	local now = System.getNowTime()
	local var = getActorVar(actor)
	local idxs = {}
	for k,v in ipairs(ShilianBossConfig) do
		repeat
			if not (zhuansheng.checkZSLevel(actor, v.zsLevel) and level > v.level) then break end
			if ShilianCommonConfig.maxCount <= (var.fightcount[k] or 0) then break end
			if var.refreshtime[k] and var.refreshtime[k] ~= 0 and var.refreshtime[k] > now then break end
			local rewards = drop.dropGroup(v.dropid)
			local isopen, dropindexs = subactivity12.checkIsStart()
			if isopen then
				for j=1, #dropindexs do
					local rewards1 = drop.dropGroup(v.actRewards[dropindexs[j]])
					for i=1, #rewards1 do
						table.insert(rewards, {type = rewards1[i].type, id = rewards1[i].id, count = rewards1[i].count})
					end
				end
			end

			for kk, vv in pairs(rewards) do
				if vv.type == 1 then
					ritems[vv.id] = (ritems[vv.id] or 0) + vv.count
				end
			end

			idxs[#idxs + 1] = k
			var.fightcount[k] = (var.fightcount[k] or 0) + 1
			var.refreshtime[k] = now + v.reborntime
			actorevent.onEvent(actor, aeSaoDang, v.fbId, 1)
			subactivity1.onKillBoss(actor)
		until(true)
	end
	local items = {}
	for k,v in pairs(ritems) do
		items[#items + 1] = {type = 1, id = k, count = v}
	end
	if #idxs > 0 then
		updateBossInfo(actor, idxs)
	end
	if #items <= 0 then return end
	actoritem.addItems(actor, items, "shilian boss one key saodang")
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_ShilianOneKey)
	LDataPack.flush(pack)
end

local function init()	
	actorevent.reg(aeNewDayArrive, onNewDay)
	if System.isCrossWarSrv() then return end
	for _, conf in pairs(ShilianBossConfig) do
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceWin(conf.fbId, onShilianWin)
		insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
		insevent.regCustomFunc(conf.fbId, ShilianDeferEarly, "ShilianDeferEarly")
	end
	actorevent.reg(aeUserLogin, onLogin)	
	actorevent.reg(aeSVipLevel, onVip)	

	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_ShilianFight, c2sShilianFight)
	netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cFubenCmd_ShilianOneKey, c2sShilianOneKey)

end
table.insert(InitFnTable, init)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.shilianEnter = function (actor, args)
	local idx = tonumber(args[1])
	local conf = ShilianBossConfig[idx]
	local fbHandle = instancesystem.createFuBen(conf.fbId)
	if not fbHandle or fbHandle == 0 then return end
	local x, y = utils.getSceneEnterCoor(conf.fbId)
	LActor.enterFuBen(actor, fbHandle, 0, x, y)
end

gmCmdHandlers.shilianSweep = function (actor, args)
	local idx = tonumber(args[1])
	--sweepFuben(actor, idx)
end

gmCmdHandlers.shilianBuy = function (actor, args)
	local count = tonumber(args[1])
	--buyFubenCount(actor, count)
end
