module("crossbosshomefb", package.seeall)

require("crossbosshome.crossbosscommon")
require("crossbosshome.crossbossfuben")

local CrossBossFubenConfig = CrossBossFubenConfig
local CrossBossCommonConfig = CrossBossCommonConfig
local MonstersConfig = MonstersConfig

--副本数据
function getFbInfoSystemVar()
	local var = crossbosshomesys.getSystemVar()
	if var.abyssfb == nil then var.abyssfb = {} end
	return var.abyssfb
end


--求下一个护盾
local function getNextShield(id, hp)
	if nil == hp then hp = 101 end

	local conf = CrossBossFubenConfig[id]
	if nil == conf then return nil end
	for i, s in ipairs(conf.shield) do
		if s.hp < hp then return s end
	end
	return nil
end

function getFbInfoByIdx(idx)
	local var = getFbInfoSystemVar()
	if var[idx] == nil then
		var[idx] = {}
		local csbosshomeData = var[idx]
		csbosshomeData.fbhdl = 0
		csbosshomeData.deadstamp = 0
		csbosshomeData.bossRecord = 0
		csbosshomeData.hpPercent = 100
		csbosshomeData.id = idx
		csbosshomeData.shield = 0
		csbosshomeData.curShield = nil
		csbosshomeData.nextShield = getNextShield(idx)
		csbosshomeData.belongId = 0
	end

	return var[idx]
end

function resetFbInfoByIdx(idx)
	local var = getFbInfoSystemVar()
	var[idx] = {}
	local csbosshomeData = var[idx]
	csbosshomeData.fbhdl = 0
	csbosshomeData.deadstamp = 0
	csbosshomeData.bossRecord = 0
	csbosshomeData.hpPercent = 100
	csbosshomeData.id = idx
	csbosshomeData.shield = 0
	csbosshomeData.curShield = nil
	csbosshomeData.nextShield = getNextShield(idx)
	csbosshomeData.belongId = 0
end

function syncAllFbInfo(serverId)
	if not System.isBattleSrv() then return end
	local abyssfb = getFbInfoSystemVar()
	local pack = LDataPack.allocPacket()

	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCAbyssCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCAbyssCmd_SyncAllFbInfo)
	local count = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, #abyssfb)
	for idx, v in ipairs(abyssfb) do
		LDataPack.writeInt(pack, idx)
		LDataPack.writeInt64(pack, v.fbhdl)
		LDataPack.writeInt(pack, v.deadstamp)
		LDataPack.writeInt(pack, v.bossRecord)
		LDataPack.writeShort(pack, v.hpPercent)
		count = count + 1
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeByte(pack, count)
	LDataPack.setPosition(pack, npos)

	System.sendPacketToAllGameClient(pack, 0)
end

function onSCSyncAllFbInfo(sId, sType, dp)
	if System.isCrossWarSrv() then return end
	local num = LDataPack.readInt(dp)
	for i=1, num do
		local idx = LDataPack.readInt(dp)
		local hdl = LDataPack.readInt64(dp)
		local deadstamp = LDataPack.readInt(dp)
		local bossRecord = LDataPack.readInt(dp)
		local hpPercent = LDataPack.readShort(dp)
		local fbinfo = getFbInfoByIdx(idx)
		fbinfo.fbhdl = hdl
		fbinfo.deadstamp = deadstamp
		fbinfo.bossRecord = bossRecord
		fbinfo.hpPercent = hpPercent
	end

	local actors = System.getOnlineActorList()
	if actors then
		for _, actor in ipairs(actors) do
			sendAllBossInfo(actor)
		end
	end
end

function sendAllBossInfo(actor)

	--判断是否开启
	if not crossbosshomesys.isOpen() then return end

	local abyssfb = getFbInfoSystemVar()
	if not abyssfb or not abyssfb[1] then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsBosshome_BossIfno)
	if not npack then return end
	LDataPack.writeByte(npack, #CrossBossFubenConfig)
	local now_t = System.getNowTime()
	local data = crossbosshomesys.getAbyssStaticVar(actor)
	if data.reminds == nil then
		data.reminds = {}
	end
	for idx=1, #CrossBossFubenConfig do
		LDataPack.writeChar(npack, data.reminds[idx] or 0)
		LDataPack.writeInt(npack, idx)
		--LDataPack.writeShort(npack, boss.hpPercent)
		LDataPack.writeInt(npack, abyssfb[idx].bossRecord)
		local xx = 1
		if now_t >= abyssfb[idx].deadstamp then
			LDataPack.writeInt(npack, 0)
			xx = 0
		else
			LDataPack.writeInt(npack, abyssfb[idx].deadstamp - now_t)
			xx = abyssfb[idx].deadstamp - now_t
		end
		LDataPack.writeString(npack, MonstersConfig[abyssfb[idx].bossRecord].name)
		LDataPack.writeString(npack, MonstersConfig[abyssfb[idx].bossRecord].head)
		LDataPack.writeInt(npack, MonstersConfig[abyssfb[idx].bossRecord].avatar[1])
	end
	LDataPack.flush(npack)
end

function updateSingleFbInfo(idx, serverId)
	if not System.isBattleSrv() then return end
	--print("------------同步混乱之渊单个副本信息-----------")
	local fbinfo = getFbInfoByIdx(idx)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCAbyssCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCAbyssCmd_UpdateSingleFbInfo)
	LDataPack.writeInt(pack, idx)
	LDataPack.writeInt64(pack, fbinfo.fbhdl)
	LDataPack.writeInt(pack, fbinfo.deadstamp)
	LDataPack.writeInt(pack, fbinfo.bossRecord)
	LDataPack.writeShort(pack, fbinfo.hpPercent)
	System.sendPacketToAllGameClient(pack, serverId or 0)
end

function broadFbInfo(idx)
	local actors = System.getOnlineActorList()
	if actors then
		for _, actor in ipairs(actors) do
			sendSingleBossInfo(actor, idx)
		end
	end
end

function onSCUpdateSingleFbInfo(sId, sType, dp)
	if System.isCrossWarSrv() then return end
	local idx = LDataPack.readInt(dp)
	local hdl = LDataPack.readInt64(dp)
	local deadstamp = LDataPack.readInt(dp)
	local bossRecord = LDataPack.readInt(dp)
	local hpPercent = LDataPack.readShort(dp)

	local fbinfo = getFbInfoByIdx(idx)
	fbinfo.fbhdl = hdl
	fbinfo.deadstamp = deadstamp
	fbinfo.bossRecord = bossRecord
	fbinfo.hpPercent = hpPercent
	broadFbInfo(idx)
end

function updateSingleBossInfo(actor, idx)
	--判断是否开启
	if not crossbosshomesys.isOpen() then return end
	local abyssfb = getFbInfoSystemVar()
	if not abyssfb[idx] then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsBosshome_SingleBossIfno)
	if not npack then return end
	LDataPack.writeInt(npack, idx)
	LDataPack.writeInt(npack, abyssfb[idx].bossRecord)
	local now_t = System.getNowTime()
	if now_t > abyssfb[idx].deadstamp then
		LDataPack.writeInt(npack, 0)
	else
		LDataPack.writeInt(npack, abyssfb[idx].deadstamp - now_t)
	end
	local data = crossbosshomesys.getAbyssStaticVar(actor)
	LDataPack.writeChar(npack,  data.reminds[idx])
	LDataPack.flush(npack)
end

function sendSingleBossInfo(actor, idx)
	--判断是否开启
	if not crossbosshomesys.isOpen() then return end

	local abyssfb = getFbInfoSystemVar()
	if not abyssfb[idx] then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsBosshome_SingleBossIfno)
	if not npack then return end
	LDataPack.writeInt(npack, idx)
	LDataPack.writeInt(npack, abyssfb[idx].bossRecord)
	local now_t = System.getNowTime()
	if now_t > abyssfb[idx].deadstamp then
		LDataPack.writeInt(npack, 0)
	else
		LDataPack.writeInt(npack, abyssfb[idx].deadstamp - now_t)
	end
	local data = crossbosshomesys.getAbyssStaticVar(actor)
	LDataPack.writeChar(npack,  data.reminds[idx] or 0)
	print("------------更新混乱之渊单个副本信息end-----------"..(abyssfb[idx].deadstamp - now_t))
	--LDataPack.writeString(npack, MonstersConfig[abyssfb[idx].bossRecord].name)
	--LDataPack.writeString(npack, MonstersConfig[abyssfb[idx].bossRecord].head)
	LDataPack.flush(npack)
end

function giveReward(actor, id, bossId, awards)
	if not awards then awards = {} end
	local cnt = crossbosshomesys.getAbyssCnt(actor)
	if cnt <= 0 then return end
	if not crossbosshomesys.changeAbyssCnt(actor, -1) then return end

	local actorId = LActor.getActorId(actor)
	local serverId = LActor.getServerId(actor)
	local name = LActor.getName(actor)
	local job = LActor.getJob(actor)

	if not actoritem.checkEquipBagSpaceJob(actor, awards) then
		--邮件
		--table.print(awards)
		local bossName = MonstersConfig[bossId].name
		local str = string.format(CrossBossFubenConfig[id].mailContent, bossName)
		local mailData = {head=CrossBossFubenConfig[id].mailTitle, context=str, tAwardList=awards}
		mailsystem.sendMailById(actorId, mailData, serverId)
	else
		actoritem.addItems(actor, awards, "crossboss reward")
	end

	--奖励广播
	local actors = Fuben.getAllActor(LActor.getFubenHandle(actor))
	if actors then
		for i = 1,#actors do
			if actors[i] == actor then
				notifyCrossBossHomeRewards(actors[i], serverId, name, job, awards, 1)
			else
				notifyCrossBossHomeRewards(actors[i], serverId, name, job, awards, 0)
			end
		end
	end
end

function notifyCrossBossHomeRewards(actor, serverId, name, job, awards, win)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsBosshome_RewardInfo)
	if not npack then return end
	LDataPack.writeByte(npack, win)
	LDataPack.writeInt(npack, serverId)
	LDataPack.writeString(npack, name)
	LDataPack.writeByte(npack, job)
	LDataPack.writeByte(npack, #awards)
	for _, v in ipairs(awards) do
		LDataPack.writeInt(npack, v.type)
		LDataPack.writeInt(npack, v.id)
		LDataPack.writeInt(npack, v.count)
	end
	LDataPack.flush(npack)
	--table.print(awards)
end

--为副本内的攻击者清除归属者列表
function s2cBelongListClear(bossData)
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, Protocol.CMD_AllFuben)
	LDataPack.writeByte(npack, Protocol.sFubenCmd_InsAttackList)
	if nil == npack then return end
	LDataPack.writeUInt(npack, 0)
	Fuben.sendData(bossData.fbhdl, npack)
end

function onInit(ins)
	local conf
	local id = ins.id --副本的id
	for i, v in ipairs(CrossBossFubenConfig) do
		if id == v.fbid then
			conf = CrossBossFubenConfig[i]
			break
		end
	end
	if not conf then return end

	ins.data.phomeid = conf.id
	ins.data.bossId = conf.bossId

	local fbinfo = getFbInfoByIdx(conf.id)
	fbinfo.fbhdl = ins:getHandle()
end

--重置副本，如果boss死了就创建新副本，如果没死就满血
local function refreshBoss(_, id)
	local bossData = getFbInfoByIdx(id)
	local ins = instancesystem.getInsByHdl(bossData.fbhdl)
	if ins then --boss还没死
		local handle = ins.scene_list[1]
		local scene = Fuben.getScenePtr(handle)
		local monster = Fuben.getSceneMonsterById(scene, ins.data.bossId)
		LActor.setHp(monster, LActor.getHpMax(monster))
		bossData.hpPercent = 100
	else --boss已死，副本被毁
		local hfuben = instancesystem.createFuBen(CrossBossFubenConfig[id].fbId)
		bossData.hpPercent = 100
		bossData.fbhdl = hfuben
		local ins = instancesystem.getInsByHdl(hfuben)
		if ins then
			ins.data.phomeid = id
			ins.data.bossId = CrossBossFubenConfig[id].bossId
		end
	end

	bossData.nextShield = getNextShield(id)
	bossData.curShield = nil
	bossData.shield = 0
	if bossData.shieldEid then
		LActor.cancelScriptEvent(nil, bossData.shieldEid)
		bossData.shieldEid = nil
	end

	sendCsBossNotice(3, "", "")

	--通知跨服
	broadFbInfo(id)
	--通知普通服
	updateSingleFbInfo(id, 0)

	--s2cBosshomeUpdate(id, bossData.bossId)
end

function enterfb(actor, idx)
	if not CrossBossFubenConfig[idx] then
		return
	end

	local now_t = System.getNowTime()
	local fbinfo = getFbInfoByIdx(idx)
	if fbinfo.fbhdl == 0 or fbinfo.hpPercent == 0 or fbinfo.deadstamp > now_t then
		return
	end

	if LActor.isDeath(actor) then
		--LActor.log(actor, "crossbosssys.enterfb", "key0")
		return
	end

	local x,y = utils.getSceneEnterCoor(CrossBossFubenConfig[idx].fbId)
	if System.isCommSrv() then
		local crossId = csbase.getCrossServerId()
		-- if not System.hasGameClient(crossId) then
		-- 	--LActor.log(actor,"crossbosssys.enterfb", "key1", crossId)
		-- 	return
		-- end
		LActor.loginOtherServer(actor, crossId, fbinfo.fbhdl, 0, x, y, "cross")
	--elseif System.isCrossWarSrv() and System.getBattleSrvFlag() == bsMainBattleSrv then
	elseif System.isCrossWarSrv() then

		-- local now_t = System.getNowTime()

		-- local data = getAbyssDynamicVar(actor)

		-- if data.lastGo > 0 and (now_t < data.lastGo + 3) then
		-- 	LActor.log(actor, "crossbosssys.enterfb", "key2")
		-- 	return
		-- end

		LActor.enterFuBen(actor, fbinfo.fbhdl, 0, x, y)
	end

	print("crossbosshome enterfb end")
	return true
end

function onEnterFb(ins, actor)
	local csbossData = getFbInfoByIdx(ins.data.phomeid)

	--护盾信息
	if csbossData.curShield then
		nowShield = csbossData.shield
		if (csbossData.curShield.type or 0) == 1 then
			nowShield = nowShield - System.getNowTime()
			if nowShield < 0 then nowShield = 0 end
		end
		instancesystem.s2cShieldInfo(ins.handle, csbossData.curShield.type, nowShield, csbossData.curShield.shield)
	end

	instancesystem.s2cBelongData(actor, false, LActor.getActorById(csbossData.belongId), csbossData.fbhdl) ---归属者信息
	LActor.setCamp(actor, CampType_Normal)--设置阵营为普通模式

	--local fbname = string.sub(csbossData.sceneName, 1, 1) == "s" and csbossData.sceneName..ScriptTips.csbossData or csbossData.sceneName
	--sendCsBossNotice(1, LActor.getName(actor), fbname)
end

--护盾结束
function finishShield(_, bossData)
	bossData.shield = 0
	instancesystem.s2cShieldInfo(bossData.fbhdl, 1, 0, bossData.curShield.shield)
end

local function onBossDamage(ins, monster, value, attacker, res)
	local homeId = ins.data.phomeid
	local monid = Fuben.getMonsterId(monster)
	if monid ~= CrossBossFubenConfig[homeId].bossId then
		return
	end
	local bossData = getFbInfoByIdx(homeId)

	--第一下攻击者为boss归属者
	if 0 == bossData.belongId and bossData.fbhdl == LActor.getFubenHandle(attacker) then
		local actor = LActor.getActor(attacker)
		local data = crossbosshomesys.getAbyssStaticVar(actor)
		if actor and LActor.isDeath(actor) == false and data.cnt > 0 then
			local oldBelong = LActor.getActorById(bossData.belongId)
			bossData.belongId = LActor.getActorId(actor)
			onBelongChange(bossData, oldBelong, actor)
			--使怪物攻击归属者
			LActor.setAITarget(monster, LActor.getRole(actor))
		end
	end

	--更新boss血量信息
	local oldhp = LActor.getHp(monster)
	if oldhp <= 0 then return end

	local hp = oldhp - value
	if hp < 0 then hp = 0 end

	hp = hp / LActor.getHpMax(monster) * 100
	bossData.hpPercent = math.ceil(hp)
	--护盾判断
	if oldhp == LActor.getHpMax(monster) then
		bossData.nextShield = getNextShield(bossData.id)
		bossData.shield = 0
		bossData.curShield = nil
	end
	if not bossData.shield or 0 == bossData.shield then --现在没有护盾
		if bossData.nextShield and 0 ~= bossData.nextShield.hp and hp < bossData.nextShield.hp then --从预备护盾里取护盾
			bossData.curShield = bossData.nextShield
			bossData.nextShield = getNextShield(ins.data.phomeid, bossData.curShield.hp) --再取下一个预备护盾
			res.ret = math.floor(LActor.getHpMax(monster) * bossData.curShield.hp / 100) --避免一招秒而不触发护盾，这里要恢复血量
			bossData.hpPercent = bossData.curShield.hp --要把血量设置回原值
			LActor.setInvincible(monster, bossData.curShield.shield*1000) --设无敌状态
			bossData.shield = bossData.curShield.shield + System.getNowTime()
			instancesystem.s2cShieldInfo(bossData.fbhdl, 1, bossData.curShield.shield, bossData.curShield.shield)
			--注册护盾结束定时器
			bossData.shieldEid = LActor.postScriptEventLite(nil, bossData.curShield.shield*1000, finishShield, bossData)
			noticesystem.fubenCastNotice(bossData.fbhdl, noticesystem.NTP.homeShield)
		end
	end
end

--清空归属者
local function clearBelongInfo(ins, actor)
	local bossData = getFbInfoByIdx(ins.data.phomeid)
	if not bossData then return end
	if LActor.getActorId(actor) == bossData.belongId then
		s2cBelongListClear(bossData)
		bossData.belongId = 0
		--utils.printInfo("~~~~~~~~~~~~~bossData:", bossData);
		onBelongChange(bossData, actor, nil)
	end
end

local function onExitFb(ins, actor)
	local data = crossbosshomesys.getAbyssStaticVar(actor)
	if not ins.is_win then --胜利的副本不加CD
		crossbosshomesys.setLastStamp(actor)
	end
	LActor.setCamp(actor, CampType_Normal) --退出变回正常阵营，此行影响s2cAttackList里的攻击者数量
	local bossData = getFbInfoByIdx(ins.data.phomeid)
	clearBelongInfo(ins, actor) --清除归属者
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
	onExitFb(ins, actor)
end

--归属者改变处理
function onBelongChange(bossData, oldBelong, newBelong)
	if oldBelong then
		LActor.setCamp(oldBelong, CampType_Normal)
	end
	if newBelong then
		LActor.setCamp(newBelong, CampType_Belong)
	end
	local actors = Fuben.getAllActor(bossData.fbhdl)
	if actors ~= nil then
		for i = 1,#actors do
			if LActor.getActor(actors[i]) ~= newBelong then
				LActor.setCamp(actors[i], CampType_Normal)
			end
		end
	end
	--广播归属者信息
	instancesystem.s2cBelongData(nil, oldBelong, newBelong, bossData.fbhdl) ---归属者信息
end

local function onActorDie(ins, actor, killHdl)
	local data = crossbosshomesys.getAbyssStaticVar(actor)

	local et = LActor.getEntity(killHdl)
	if not et then return end
	local attacker = LActor.getEntityType(et)

	local bossData = getFbInfoByIdx(ins.data.phomeid)
	if nil == bossData then return end

	if LActor.getActorId(actor) == bossData.belongId then
		s2cBelongListClear(bossData)
		--归属者被玩家打死，该玩家是新归属者
		local killactor = nil
		local killbelongtimes = 0
		if actorcommon.isActor(attacker) then
			killactor = LActor.getActor(et)
			local killactorvar = crossbosshomesys.getAbyssStaticVar(killactor)
			killbelongtimes = (killactorvar and killactorvar.cnt) or 0
		end

		if killbelongtimes and killbelongtimes > 0 then
			bossData.belongId = LActor.getActorId(killactor)
			--怪物攻击新的归属者
			local handle = ins.scene_list[1]
			local scene = Fuben.getScenePtr(handle)
			local boosId = CrossBossFubenConfig[bossData.id].bossId
			local monster = Fuben.getSceneMonsterById(scene, boosId)
			if not monster then
				print("Error monster in actor belongId die")
				return
			end

			LActor.setAITarget(monster, LActor.getRole(killactor))
		elseif killbelongtimes == 0 then --归属者被怪物打死，怪物无归属
			bossData.belongId = 0
		end
		--广播归属者信息
		onBelongChange(bossData, actor, LActor.getActorById(bossData.belongId))
	else
		--不是归属者,死亡时候切换回正常阵营
		if LActor.getCamp(actor) == CampType_Attack then
			LActor.setCamp(actor, CampType_Normal)
		end
	end
end

function updateBossInfo(idx, newBossId, next_t)
	-- print("--------boss新id:"..newBossId)
	local data = getFbInfoByIdx(idx)
	data.bossRecord = newBossId
	data.deadstamp = next_t
	--通知跨服
	broadFbInfo(idx)
	--通知普通服
	updateSingleFbInfo(idx, 0)
end

function onMonsterDie(ins, mon, killerHdl)
	local id = ins.data.phomeid
	local conf = CrossBossFubenConfig[id]
	if not conf then return end

	local monId = Fuben.getMonsterId(mon)
	local bossId = ins.data.bossId

	if  not (monId == bossId) then return end
	local bossData = getFbInfoByIdx(ins.data.phomeid)
	if nil == bossData then return end
	--boss死亡弹出结算面板并发邮件奖励

	--先注册定时器通知复活,防止因为报错导致不会刷新
	LActor.postScriptEventLite(nil, conf.time * 1000, refreshBoss, id)

	local belong = LActor.getActorById(bossData.belongId)
	if belong then
		local awards = drop.dropGroup(conf.belongDrop)
		local isopen, dropindexs = subactivity12.checkIsStart()
		if isopen then
			for j=1, #dropindexs do
				local rewards1 = drop.dropGroup(conf.actRewards[dropindexs[j]])
				for i=1, #rewards1 do
					table.insert(awards, {type = rewards1[i].type, id = rewards1[i].id, count = rewards1[i].count})
				end
			end
		end
		giveReward(belong, id, ins.data.bossId, awards)
		sendCsBossNotice(2, LActor.getName(belong), MonstersConfig[ins.data.bossId].name)
		subactivity1.onKillBoss(belong)
		actorevent.onEvent(belong, aeCrossBoss)
	else
		--奖励广播
		local actors = Fuben.getAllActor(ins.handle)
		if actors then
			for i = 1,#actors do
				notifyCrossBossHomeRewards(actors[i], 0, "", 0, {}, 0)
				actorevent.onEvent(actors[i], aeCrossBoss)
			end
		end
	end

	--notifyBelong(ins, ins.data.belongId or 0, 0)
	bossData.belongId = 0
	local bossData = getFbInfoByIdx(id)
	bossData.hpPercent = 0
	bossData.fbhdl = 0

	--记录boss下次创建时间
	updateBossInfo(id, bossId, conf.time  + System.getNowTime())
end

--发送多服跨服BOSS广播
function sendCsBossNotice(ntype, aName, sName)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCAbyssCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCAbyssCmd_Notice)
	LDataPack.writeByte(pack, ntype)
	LDataPack.writeString(pack, aName)
	LDataPack.writeString(pack, sName)
	System.sendPacketToAllGameClient(pack, 0)
end

function onBroadcast(sId, sType, dp)
	local ntype = LDataPack.readByte(dp)
	local aName = LDataPack.readString(dp)
	local sName = LDataPack.readString(dp)
	if ntype == 1 then
		noticesystem.broadCastNotice(noticesystem.NTP.csboss, aName, sName)
	elseif ntype == 2 then
		noticesystem.broadCastNotice(noticesystem.NTP.cshomeKill, aName, sName)
	elseif ntype == 3 then
		noticesystem.broadCastNotice(noticesystem.NTP.cshomeResh)
	end
end


function OnConnected(serverId, serverType)
	if not System.isBattleSrv() then return end
	syncAllFbInfo(serverId)
end

--初始化副本
local function initGlobalData()
	if not System.isBattleSrv() then return end
	for id, conf in pairs(CrossBossFubenConfig) do
		resetFbInfoByIdx(id)
		local FbInfo = getFbInfoByIdx(id)
		if FbInfo and FbInfo.fbhdl == 0 then
			local hfuben = instancesystem.createFuBen(conf.fbId)
			FbInfo.fbhdl = hfuben
			FbInfo.bossRecord = conf.bossId
			local ins = instancesystem.getInsByHdl(hfuben)
			if ins then
				ins.data.phomeid = id
			 	ins.data.bossId = conf.bossId
			end
		end
	end
end

function onInitFnTable()
	if not System.isBattleSrv() then return end
	--副本事件
	for _, conf in pairs(CrossBossFubenConfig) do
		insevent.registerInstanceInit(conf.fbId, onInit)
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
		insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
		insevent.registerInstanceExit(conf.fbId, onExitFb)
		insevent.registerInstanceOffline(conf.fbId, onOffline)
		insevent.registerInstanceActorDie(conf.fbId, onActorDie)
	end

	--initGlobalData()
end


csmsgdispatcher.Reg(CrossSrvCmd.SCAbyssCmd, CrossSrvSubCmd.SCAbyssCmd_Notice, onBroadcast)
csmsgdispatcher.Reg(CrossSrvCmd.SCAbyssCmd, CrossSrvSubCmd.SCAbyssCmd_SyncAllFbInfo, onSCSyncAllFbInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCAbyssCmd, CrossSrvSubCmd.SCAbyssCmd_UpdateSingleFbInfo, onSCUpdateSingleFbInfo)


csbase.RegConnected(OnConnected)

engineevent.regGameStartEvent(initGlobalData)

table.insert(InitFnTable, onInitFnTable)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.csfbhd = function(actor, arg)
	for i=1, 7 do
		local fbinfo = getFbInfoByIdx(i)
		if i==1 then
			local ret = LActor.enterFuBen(actor, fbinfo.fbhdl)
		end
	end

	return true
end
