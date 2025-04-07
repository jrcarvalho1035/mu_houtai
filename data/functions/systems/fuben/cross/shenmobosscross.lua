-- 跨服神魔Boss圣殿
module("shenmobosscross", package.seeall)

SHENMOBOSS_DATA = SHENMOBOSS_DATA or {}
local function getShenmoBossData()
	return SHENMOBOSS_DATA
end

function getVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.shenmoboss then
		var.shenmoboss = {}
		var.shenmoboss.svip_use = 0 -- SVIP归属宝箱使用次数
		var.shenmoboss.remind_list = {} -- 提醒或自动挑战
	end
	return var.shenmoboss
end

local function getBossData(id)
	return SHENMOBOSS_DATA[id]
end

local function getConfigBybossId(bossId)
    for _, v in ipairs(ShenmoFubenConfig) do
        if v.bossId == bossId then
            return v
        end
	end
end

--求下一个护盾
local function getNextShield(id, hp)
	if nil == hp then hp = 101 end

	local conf = ShenmoFubenConfig[id]
	if nil == conf then return nil end
	for _, s in ipairs(conf.shield) do
        if s.hp < hp then
            return s
        end
	end
end


local function getMonsterName(bossId)
	if MonstersConfig[bossId] then
		return tostring(MonstersConfig[bossId].name)
	end
	return "nil"
end

--清空归属者
local function clearBelongInfo(ins, actor, bossData)
	if LActor.getActorId(actor) == bossData.belongId then
        local x, y = LActor.getEntityScenePos(actor)
        instancesystem.s2cBelongListClear(bossData.hfuben, x, y)
		bossData.belongId = 0
		onBelongChange(bossData, actor, nil, x, y)
		return true
	end
	return false
end

--归属者改变处理
function onBelongChange(bossData, oldBelong, newBelong, x, y)
	if oldBelong then
		LActor.setCamp(oldBelong, CampType_Normal)
	end
	if newBelong then
		LActor.setCamp(newBelong, CampType_Belong)
	end
	--广播归属者信息
    instancesystem.s2cBelongData(nil, oldBelong, LActor.getActorById(bossData.belongId), bossData.hfuben, x, y) ---归属者信息
end

--重置副本，如果boss死了就创建新副本，如果没死就满血
local function refreshBoss(_, id)
	local bossData = getBossData(id)
	local ins = instancesystem.getInsByHdl(bossData.hfuben)
	local handle = ins.scene_list[1]
	-- local scene = Fuben.getScenePtr(handle)
	local refreshConf = RefreshMonsters[ins.config.refreshMonster]
	local position = refreshConf.position[ShenmoFubenConfig[bossData.id].index]
	local boss = ins:insCreateMonster(handle, bossData.bossId, position.x, position.y)
	bossData.hpPercent = 100
	bossData.damageList = {}
	bossData.nextShield = getNextShield(id)
	bossData.curShield = nil
	bossData.shield = 0
	bossData.refreshtime = 0
	if bossData.shieldEid then
		LActor.cancelScriptEvent(nil, bossData.shieldEid)
		bossData.shieldEid = nil
	end
	bossinfo.createBossInfo(ins, bossData.bossId, boss)

	sendServerBossInfo(id)
end

--护盾结束
function finishShield(_, bossData)
	if bossData.curShield == nil then
		return
	end

	bossData.shieldEid = nil
    bossData.shield = 0
    local x, y = LActor.getEntityScenePos(bossData.monster)
	-- LActor.setInvincible(bossData.monster, false)
	instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, bossData.curShield.shield, nil, x, y)
end

-------------------------------------------------------------------------------------------------------

local function sendOpenBoxInfo(actor, id, end_time)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsShenmoBoss_OpenBoxInfo)
	if npack == nil then return end
	LDataPack.writeChar(npack, id)
    LDataPack.writeInt(npack, end_time)
	LDataPack.flush(npack)
end

local function sendResult(actor, res, belongInfo, rewards)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsShenmoBoss_Result)
	if npack == nil then return end
	LDataPack.writeChar(npack, res)
	LDataPack.writeInt(npack, belongInfo.id)
	LDataPack.writeString(npack, belongInfo.name)
	LDataPack.writeChar(npack, belongInfo.job)
	if rewards then
		LDataPack.writeChar(npack, #rewards)
		for _, t in ipairs(rewards) do
			LDataPack.writeInt(npack, t.type)
			LDataPack.writeInt(npack, t.id)
			LDataPack.writeInt(npack, t.count)
		end
	else
		LDataPack.writeChar(npack, 0)
	end
    LDataPack.flush(npack)
end

local function killTomb(_, hdl)
	LActor.destroyEntity(hdl)
end

local function broadcastBossInfo(fbhdl, id, endtime)
	local npack = LDataPack.allocPacket()
    if npack then
        LDataPack.writeByte(npack, Protocol.CMD_Cross)
        LDataPack.writeByte(npack, Protocol.sCsShenmoBoss_BossInfo)
        LDataPack.writeChar(npack, id)
        LDataPack.writeInt(npack, endtime)
		Fuben.sendData(fbhdl, npack)
    end
end

local function onBossCreate(ins, monster)
	if not ins.data.bossPos then
		ins.data.bossPos = {}
	end

	local bossId = Fuben.getMonsterId(monster)
	local x, y = LActor.getEntityScenePos(monster)
	ins.data.bossPos[bossId] = {
		x = x,
		y = y,
	}
end

local function onMonsterAiReset(ins, monster)
	local bossId = Fuben.getMonsterId(monster)
	local config = getConfigBybossId(bossId)
	if config == nil then
		print('shenmobosscross.onMonsterAiReset config==nil bossId=' .. bossId)
		return
	end
	local index = config.id
	local bossData = getBossData(index)
	if bossData == nil then
		return
	end
	finishShield(nil, bossData)
	-- bug:6929 【Boss圣殿】进入Boss区域需要立即更新Boss的血条数据​
	if ins.boss_info then
		local info = ins.boss_info[bossId]
		if info then
			info.hp = LActor.getHp(monster)
		end
	end
end

function getBossPos(ins, bossId)
	if ins.data.bossPos then
		local t = ins.data.bossPos[bossId]
		return t.x, t.y
	end
	return 0, 0
end

local function onBossDie(ins, monster, killHdl)
    local bossId = Fuben.getMonsterId(monster)
	local config = getConfigBybossId(bossId)
	if config == nil then
		print('shenmobosscross.onBossDie config==nil bossId=' .. bossId)
		return
	end

	local index = config.id
	local bossData = getBossData(index)
	--先注册定时器通知复活,防止因为报错导致不会刷新
	LActor.postScriptEventLite(nil, config.refreshtime*1000, refreshBoss, bossData.id)

	local belong = LActor.getActorById(bossData.belongId)
	if not belong then
		print('shenmobosscross.onBossDie belong==nil index=' .. index)
		return
	end
	local bName = LActor.getActorName(bossData.belongId)
	local bJob = LActor.getJob(belong)
	local belongInfo = {
		name = bName,
		job = bJob,
		id = bossData.belongId
	}

	if not config then return end

	local scene_hdl = LActor.getSceneHandle(monster)
	local x, y = LActor.getEntityScenePos(monster)

	for actorId in pairs(bossData.damageList) do
		if actorId == bossData.belongId then --归属者
			local belongLv = config.belongLv or 0
			local lv = LActor.getZhuansheng(belong)
			-- 当玩家等级等于或高于最高掉落等级时，不会掉落归属奖励和归属宝箱
			if belongLv == 0 or lv < belongLv then
				local rewards = drop.dropGroup(config.belongDrop)
				local posX, posY = LActor.getEntityScenePoint(monster)
				local isopen, dropindexs = subactivity12.checkIsStart()
				if isopen then
					for j=1, #dropindexs do
						local rewards1 = drop.dropGroup(config.actRewards[dropindexs[j]])
						for i=1, #rewards1 do
							table.insert(rewards, {type = rewards1[i].type, id = rewards1[i].id, count = rewards1[i].count})
						end
					end
				end

				for _, v in ipairs(rewards) do
					local item_conf = ItemConfig[v.id]
					if item_conf and item_conf.type == 54 then
						noticesystem.broadCastNotice(noticesystem.NTP.smbossdrop, actorcommon.getVipShow(LActor.getActorById(actorId)), LActor.getActorName(actorId), config.scenename, getMonsterName(config.bossId), ItemConfig[v.id].name)
					end
				end

				ins:addDropBagItem(belong, rewards, 10, posX, posY, true)

				local end_time =  System.getNowTime() + config.belongTime
				local var = getVar(belong)
				var[index] = end_time
				sendOpenBoxInfo(belong, index, end_time)
				-- 创建宝箱怪物
				local box_mon = Fuben.createMonster(scene_hdl, SMFBCommonConfig.boxMonId, x-2, y+1)
				if box_mon then
					local hdl = LActor.getRealHandle(box_mon)
					LActor.postScriptEventLite(nil, config.belongTime*1000-1, killTomb, hdl)
				end
				-- 归属结算
				sendResult(belong, 1, belongInfo, rewards)
			else
				print('shenmobosscross.onBossDie bad lv=' .. lv .. ' config.belongLv=' .. belongLv .. ' belongId=' .. bossData.belongId .. ' index=' .. index)
				sendResult(belong, 1, belongInfo)
			end
			-- 跨服公告广播
			if config.notice then
				local mon_name = MonstersConfig[bossId].name
				noticesystem.broadCastNotice(config.notice, actorcommon.getVipShow(belong), bName, config.floor, mon_name)
			end
			LActor.setCamp(belong, CampType_Normal)
			subactivity1.onKillBoss(belong)
			actorevent.onEvent(belong, aeShenmoBoss)
		else
			-- 非归属结算
			local actor = LActor.getActorById(actorId)
			if actor then
				LActor.setCamp(actor, CampType_Normal)
				sendResult(actor, 0, belongInfo)
				actorevent.onEvent(actor, aeShenmoBoss)
			end
		end
	end
	instancesystem.s2cBelongData(nil, nil, nil, bossData.hfuben, x, y) ---归属者信息
	--boss信息重置
	bossData.hpPercent = 0
	local refreshtime = config.refreshtime
	local refresh_endtime = refreshtime + System.getNowTime()
    bossData.refreshtime = refresh_endtime
    bossData.damageList = {}
	clearBelongInfo(ins, belong, bossData) --清除归属者
	bossData.belongId = 0

	-- 更新副本玩家
	broadcastBossInfo(ins.handle, index, refresh_endtime)
	-- 更新普通服
	sendServerBossInfo(index)
	-- 创建boss墓碑
	local tomb = Fuben.createMonster(scene_hdl, SMFBCommonConfig.tombMonId, x, y, refreshtime, 0, bName)
	if tomb then
		local hdl = LActor.getRealHandle(tomb)
		LActor.postScriptEventLite(nil, refreshtime*1000-1, killTomb, hdl)
	end
end

function onEnerBossArea(ins, actor, bossId)
    local config = getConfigBybossId(bossId)
    local bossData = getBossData(config.id)
    -- local actorId = LActor.getActorId(actor)

	local handle = ins.scene_list[1]
	local scene = Fuben.getScenePtr(handle)
	local monster = Fuben.getSceneMonsterById(scene, bossData.bossId)
	--护盾信息
	if bossData.curShield then
        nowShield = bossData.shield
		if (bossData.curShield.type or 0) == 1 then
			nowShield = nowShield - System.getNowTime()
			if nowShield < 0 then
				nowShield = 0
			end
        end

		instancesystem.s2cShieldInfo(ins.handle, bossData.curShield.type, nowShield, bossData.curShield.shield, actor)
	else
		instancesystem.s2cShieldInfo(bossData.hfuben, 1, 0, config.shield[1].shield, actor)
    end
	instancesystem.s2cBelongData(actor, nil, LActor.getActorById(bossData.belongId), bossData.hfuben)
	LActor.setCamp(actor, CampType_Normal)--设置阵营为普通模式
end

local function onEnterBefore(ins, actor)
	slim.s2cMonsterConfig(actor, {SMFBCommonConfig.tombMonId, SMFBCommonConfig.boxMonId})
end

local function onEnterFb(ins, actor)
	LActor.setCamp(actor, CampType_Normal)--设置阵营为普通模式
end

local function onBossDamage(ins, monster, value, attacker, res)
    local bossId = Fuben.getMonsterId(monster)
	local config = getConfigBybossId(bossId)
	if config == nil then
		print('shenmobosscross.onBossDamage config==nil bossId=' .. bossId)
		return
	end

	local index = config.id
	-- local bossId = Fuben.getMonsterId(monster)
    local bossData = getBossData(index)
    local actor = LActor.getActor(attacker)
	-- local var = getVar(actor)
	local actorId = LActor.getActorId(actor)

	bossData.damageList[actorId] = bossData.damageList[actorId] or 0

	--第一下攻击者为boss归属者
	if 0 == bossData.belongId and bossData.hfuben == LActor.getFubenHandle(attacker) and actor then
		if LActor.isDeath(actor) == false and bossId == Fuben.getBossIdInArea(actor) then
			local oldBelong = LActor.getActorById(bossData.belongId)
            bossData.belongId = LActor.getActorId(actor)
			local x, y = LActor.getEntityScenePos(monster)
			onBelongChange(bossData, oldBelong, actor, x, y)
			--使怪物攻击归属者
			--LActor.setAITarget(monster, LActor.getBattleLiveByOrder(actor))
		end
	end

	--更新boss血量信息
	local oldhp = LActor.getHp(monster)
	if oldhp <= 0 then return end

	local hp = oldhp - value
	if hp < 0 then hp = 0 end

	hp = hp / LActor.getHpMax(monster) * 100
	bossData.hpPercent = math.ceil(hp)

	bossData.monster = monster --记录BOSS实体

	--护盾判断
	local needShield = false
    if oldhp == LActor.getHpMax(monster) then
		bossData.nextShield = getNextShield(bossData.id)
		bossData.shield = 0
		bossData.curShield = nil
		-- 一刀秒死boss
		if hp == 0 then
			needShield = true
		end
	end
	if 0 == bossData.shield then --现在没有护盾
		if bossData.nextShield and 0 ~= bossData.nextShield.hp and hp < bossData.nextShield.hp then --从预备护盾里取护盾
			needShield = true
		end
	end

	if needShield then
		bossData.curShield = bossData.nextShield
		bossData.nextShield = getNextShield(bossData.id, bossData.curShield.hp) --再取下一个预备护盾

		res.ret = math.floor(LActor.getHpMax(monster) * bossData.curShield.hp / 100) --避免一招秒而不触发护盾，这里要恢复血量
		bossData.hpPercent = bossData.curShield.hp --要把血量设置回原值
		LActor.setInvincible(monster, bossData.curShield.shield * 1000) --设无敌状态
		bossData.shield = bossData.curShield.shield + System.getNowTime()
		local x, y = LActor.getEntityScenePos(monster)
		instancesystem.s2cShieldInfo(bossData.hfuben, 1, bossData.curShield.shield, bossData.curShield.shield, nil, x, y)
		--注册护盾结束定时器
		bossData.shieldEid = LActor.postScriptEventLite(nil, bossData.curShield.shield*1000, finishShield, bossData)
		noticesystem.fubenAreaCastNotice(bossData.hfuben, noticesystem.NTP.homeShield, bossData.bossId)
	end
end

local function onExitFb(ins, actor)
    local bossId = Fuben.getBossIdInArea(actor)
	if bossId == 0 then return end
    onExitBossArea(ins, actor, bossId)
end

function onExitBossArea(ins, actor, bossId)
	if not ins then return end
    local config = getConfigBybossId(bossId)
    -- local data = getVar(actor)

	LActor.setCamp(actor, CampType_Normal) --退出变回正常阵营，此行影响s2cAttackList里的攻击者数量
	local bossData = getBossData(config.id)
	local actorId = LActor.getActorId(actor)
	bossData.damageList[actorId] = nil

	local isBelong = clearBelongInfo(ins, actor, bossData) --清除归属者
	local x, y = getBossPos(ins, bossId)
	instancesystem.s2cBelongData(actor, nil, nil, bossData.hfuben, x, y)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben2, Protocol.sFubenCmd_SMBossDisappear)
    LDataPack.writeByte(pack, config.id)
	LDataPack.flush(pack)

	-- 尝试转移归属
	if isBelong then
		Fuben.bossAttackActorInArea(bossId, actor)
	end
end

local function onOffline(ins, actor)
	-- local var = getVar(actor)
    local bossId = Fuben.getBossIdInArea(actor)
	if bossId == 0 then return end
    onExitBossArea(ins, actor, bossId)
end

local function onActorDie(ins, actor, killHdl)
	-- local var = getVar(actor)
	local et = LActor.getEntity(killHdl)
	if not et then return end
    local attacker = LActor.getEntityType(et)
	local bossId = Fuben.getBossIdInArea(actor)
	local config = getConfigBybossId(bossId)
	if not config then return end
	local bossData = getBossData(config.id)
    if nil == bossData then return end
    local x,y = LActor.getEntityScenePos(actor)

	if LActor.getActorId(actor) == bossData.belongId then
		instancesystem.s2cBelongListClear(bossData.hfuben, x, y)
		--归属者被玩家打死，该玩家是新归属者
		if actorcommon.isActor(attacker) then
            local newactor = LActor.getActor(et)
            bossData.belongId = LActor.getActorId(newactor)
			--怪物攻击新的归属者
			local handle = ins.scene_list[1]
			local scene = Fuben.getScenePtr(handle)
			local monster = Fuben.getSceneMonsterById(scene, bossData.bossId)
			if not monster then
				print("Error monster in actor belongId die")
			end
			LActor.setAITarget(monster, et)
		elseif EntityType_Monster == attacker then --归属者被怪物打死，怪物无归属
			bossData.belongId = 0
		end
		local belong = LActor.getActorById(bossData.belongId)
		if belong then
			x, y = LActor.getEntityScenePos(belong)
			--广播归属者信息
			onBelongChange(bossData, actor, belong, x, y)
		else
			bossData.belongId = 0
		end
	else
		--不是归属者,死亡时候切换回正常阵营
		if LActor.getCamp(actor) == CampType_Attack then
			LActor.setCamp(actor, CampType_Normal)
		end
	end
	-- 点券进入，马上退出副本
	if LActor.getSVipLevel(actor) < config.svip then
		LActor.exitFuben(actor)
	end
end

function s2cSvipUse(actor, count)
	if count == nil then
		local var = getVar(actor)
		count = var.svip_use or 0
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsShenmoBoss_SVIPUse)
    if npack == nil then return end
    LDataPack.writeShort(npack, count)
    LDataPack.flush(npack)
end

--注册事件
function onNewDay(actor, login)
	local var = getVar(actor)
	var.svip_use = 0

	if not login then
		s2cSvipUse(actor, 0)
	end
end

-- id：配置的id, 0 for all
function sendServerBossInfo(id, serverId)
	local list = {}
	if id == 0 then
		for _, info in pairs(SHENMOBOSS_DATA) do
			table.insert(list, info)
		end
	else
		local info = SHENMOBOSS_DATA[id]
		if info then
			table.insert(list, info)
		else
			assert(id, debug.traceback())
		end
	end

	if #list <= 0 then
		return
	end

	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCShenMoCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCShenMoBossCmd_SendServerBossInfo)
	LDataPack.writeShort(npack, #list)
	for _, info in ipairs(list) do
		LDataPack.writeInt(npack, info.id)
		LDataPack.writeInt(npack, info.refreshtime)
		LDataPack.writeInt64(npack, info.hfuben)
	end
    System.sendPacketToAllGameClient(npack, serverId or 0)
end

local function onServerConnect(serverId, serverType)
	print('shenmobosscross.onServerConnect serverId=' .. serverId .. ' serverType=' .. serverType)
	sendServerBossInfo(0, serverId) -- 0 for all
end

local function sendBoxRewardList(actor, rewards)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsShenmoBoss_BoxRewardList)
	if npack == nil then return end
	LDataPack.writeChar(npack, #rewards)
	for _, t in pairs(rewards) do
		LDataPack.writeInt(npack, t.type)
		LDataPack.writeInt(npack, t.id)
		LDataPack.writeInt(npack, t.count)
	end
	LDataPack.flush(npack)
end

function openBox(actor, id, stype)
	local conf = ShenmoFubenConfig[id]
	if conf == nil then
		print('shenmobosscross.openBox conf==nil id=' .. id)
		return
	end

	local svip_lv = LActor.getSVipLevel(actor)
	local svip_conf = SVipConfig[svip_lv]
	if svip_conf == nil then
		print('shenmobosscross.openBox svip_conf==nil svip_lv=' .. svip_lv)
		return
	end

	local var = getVar(actor)
	local old = var.svip_use or 0
	if svip_conf.kfBossSdBoxCount <= old then
		print('shenmobosscross.openBox svip_conf.kfBossSdBoxCount=' .. svip_conf.kfBossSdBoxCount .. ' old=' .. old)
		return
	end

	local end_time = var[id] or 0
	local now_time = System.getNowTime()
	if end_time < now_time then
		print('shenmobosscross.openBox timeout dt=' .. (end_time - now_time))
		return
	end

	if stype == 0 then -- 普通
		if not actoritem.checkItems(actor, {conf.openBox[1]}) then
			print('shenmobosscross.openBox stype==0 check items fail')
			return
		end
	end
	if stype == 1 then -- 普通
		if not actoritem.checkItems(actor, {conf.openBox[2]}) then
			print('shenmobosscross.openBox stype==1 check items fail')
			return
		end
	end
	if stype == 2 then -- 普通
		if not actoritem.checkItems(actor, {conf.openBox[3]}) then
			print('shenmobosscross.openBox stype==2 check items fail')
			return
		end
	end

	local drop_id
	if stype == 0 then
		drop_id = conf.boxDrop[1]
	end
	if stype == 1 then
		drop_id = conf.boxDrop[2]
	end
	if stype == 2 then
		drop_id = conf.boxDrop[3]
	end
	if drop_id == nil then
		print('shenmobosscross.openBox drop_id==nil id=' .. id)
		return
	end
	
	
	local new_use
	if stype == 2 then
		new_use = old + 100
	else
		new_use = old + 1
	end
	var.svip_use = new_use
	-- var[id] = nil
	s2cSvipUse(actor, new_use)

	if stype == 0 then
		actoritem.reduceItems(actor, {conf.openBox[1]}, 'shenmoboss open box 0')
	end
	if stype == 1 then
		actoritem.reduceItems(actor, {conf.openBox[2]}, 'shenmoboss open box 1')
	end
	if stype == 2 then
		actoritem.reduceItems(actor, {conf.openBox[3]}, 'shenmoboss open box 2')
	end

	local rewards = drop.dropGroup(drop_id)
	actoritem.addItems(actor, rewards, 'shenmoboss open box ID: ', stype)
	-- sendOpenBoxInfo(actor, id, 0)
	sendBoxRewardList(actor, rewards)
end

local function c2sShenmoBossOpenBox(actor, reader)
	local id = LDataPack.readChar(reader)
	local stype = LDataPack.readChar(reader)

	openBox(actor, id, stype)
end

function gmRefreshBoss(id)
	print('shenmobosscross.gmRefreshBoss id=' .. tostring(id))
	refreshBoss(nil, id)
end

local function initGlobalData()
	actorevent.reg(aeNewDayArrive, onNewDay)

	if not System.isBattleSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsShenmoBoss_OpenBox, c2sShenmoBossOpenBox) -- 开启宝箱

	local fb_list = {}
	for _, conf in pairs(ShenmoFubenConfig) do
		if fb_list[conf.fbId] == nil then
			fb_list[conf.fbId] = true
			insevent.registerInstanceMonsterDie(conf.fbId, onBossDie)
			insevent.registerInstanceEnterBefore(conf.fbId, onEnterBefore)
			insevent.registerInstanceEnter(conf.fbId, onEnterFb)
			insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
			insevent.registerInstanceExit(conf.fbId, onExitFb)
			insevent.registerInstanceOffline(conf.fbId, onOffline)
			insevent.registerInstanceActorDie(conf.fbId, onActorDie)
			insevent.registerInstanceMonsterCreate(conf.fbId, onBossCreate)
			insevent.registerInstanceEnerBossArea(conf.fbId, onEnerBossArea)
			insevent.registerInstanceExitBossArea(conf.fbId, onExitBossArea)
		end
	end

	csbase.RegConnected(onServerConnect)

	if next(SHENMOBOSS_DATA) then return end
	local hfubenlist = {}
	for id, conf in pairs(ShenmoFubenConfig) do
        if not SHENMOBOSS_DATA[id] then
            if not hfubenlist[conf.floor] then
                hfubenlist[conf.floor] = instancesystem.createFuBen(conf.fbId)
			end
			local hfuben = hfubenlist[conf.floor]
			SHENMOBOSS_DATA[id] = {
				id = conf.id,
				hpPercent = 100,
				hfuben = hfuben,
				shield = 0,
				curShield = nil,
				nextShield = getNextShield(conf.id),
				belongId = 0,
				damageList = {},
				bossId = conf.bossId,
				refreshtime = 0,
			}

			local ins = instancesystem.getInsByHdl(hfuben)
			if ins then
				ins.boss_mult = true -- 多个bossinfo
                if not ins.data.smbossindex then
                    ins.data.smbossindex = {}
                    ins.data.smbossid = {}
                end
                ins.data.smbossindex[#ins.data.smbossindex+1] = id
                ins.data.smbossid[#ins.data.smbossid+1] = conf.bossId
			end
		end
	end
end
table.insert(InitFnTable, initGlobalData)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.fulshShenmo = function (actor, args)
	local id = tonumber(args[1])
	refreshBoss(nil, id)
	return true
end
