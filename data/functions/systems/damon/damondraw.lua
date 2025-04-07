-- @version 1.0
-- @author  qianmeng
-- @date    2017-1-6 21:14:25.
-- @system  damon

module("damondarw", package.seeall)

local MAX_BAGNUM = 200 --精灵背包最高上限

--精灵数据获取
function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var.damondarw then
		var.damondarw = {}
		var.damondarw.freeTimes = 1 --次数
		var.damondarw.freeTime = 0  --上次使用时间
		var.damondarw.damonBag = {}
		var.damondarw.bagCount = 0
		var.damondarw.damonShop = {}
		var.drawTime = {}
		var.drawTime[1] = 0
		var.drawTime[2] = 0
	end
	return var
end

--生成一个精灵
local function createDamon(actor, damonData, id)
	local type = 2
	if not damonData.damonBag[id] then 
		damonData.damonBag[id] = {} 
		damonData.damonBag[id].cnt = 0 
		type = 1
	end
	if damonData.damonBag[id].cnt == 0 then type = 1 end
	damonData.damonBag[id].cnt = damonData.damonBag[id].cnt + 1
	s2cDamonCreate(actor, id)
	actorevent.onEvent(actor, aeDamonCnt, DamonConfig[id].quality)
	return damonData.damonBag[id], type
end

--外部生成精灵接口
function addDamon(actor, id, number)
	if not DamonConfig[id] then return end
	local damonData = getActorVar(actor)
	for i=1, number do
		local damon, type = createDamon(actor, damonData, id)
		if damon then
			s2cDamonUpdate(actor, damon, id, type)
		end
	end
end

--复制精灵数据
function copyDamonVar(damons, damonBag, pos, damon)
	if not damon then
		damonBag[pos] = nil
		return
	end
	damonBag[pos] = {}
	damonBag[pos].id = damon.id
	damonBag[pos].idx = damon.idx --如果要回收的精灵后面的精灵被装备，这个idx也要被移动
	damonBag[pos].level = damon.level 
	damonBag[pos].talents = {} 
	damonBag[pos].talentsNum = damon.talentsNum
	for i=1, damon.talentsNum do 
		damonBag[pos].talents[i] = damon.talents[i] 
	end
	if damon.skills then--转移技能
		for i=1, #DamonSkillComConfig.slotOpen do
			local sk = damon.skills[i]
			if sk then
				if not damonBag[pos].skills then
					damonBag[pos].skills = {}
				end
				if not damonBag[pos].skills[i] then
					damonBag[pos].skills[i] = {}
				end
				damonBag[pos].skills[i].id = sk.id
				damonBag[pos].skills[i].lv = sk.lv
			end
		end
	end
end

--删除一个精灵
function deleteDamon(damonData, id)
	damonData.damonBag[id] = damonData.damonBag[id] - 1
	utils.logCounter(actor, "damon delete", id)
	return true
end

function getPower(actor)
	local var = getActorVar(actor)
	if not var then return 0 end
	return var.power
end

--组合数量
function getGruopCount(actor)
	local var = getActorVar(actor)
	if not var then return 0 end
	return var.groutcount
end

--计算精灵的属性
function calcAttr(actor, roleId, calc)
	local damonData = getActorVar(actor)
	local damons = damonData.damons[roleId]
	local addAttrs = {}
	--精灵升级属性
	for id, conf in pairs(DamonConfig) do
		if damons[id] and damons[id].level > 0 then		
			for __,v in ipairs(DamonLevelConfig[id][damons[id].level].baseAttrs) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
			end
			--精灵力量丹属性
			for __,v in ipairs(DamonCommonConfig.atPower[conf.quality].attr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * (damons[id].atPowerPill or 0)
			end 
			--精灵防御丹属性
			for __,v in ipairs(DamonCommonConfig.def[conf.quality].attr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value * (damons[id].defPill or 0)
			end 
		end
	end

	--精灵组合
	for __, v in ipairs(DamonFormationConfig) do		
		if #v.arg3 > 0 then
			local isActive = true
			for i=1, #v.arg3 do
				if not damons[v.arg3[i]] or damons[v.arg3[i]].level == 0 then
					isActive = false
					break
				end
			end
			if isActive then
				for __,tmpAttr in ipairs(v.attr) do
					addAttrs[tmpAttr.type] = (addAttrs[tmpAttr.type] or 0) + tmpAttr.value
				end
			end
		end
	end
	--精灵印记
	for id in pairs(DamonConfig) do
		if damons[id] and damons[id].signetLv or 0 > 0 then
			for __,v in ipairs(DamonSignetConfig[damons[id].signetLv].baseAttrs) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
			end
		end
	end
	
	local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Damon)
	attr:Reset()
    for k, v in pairs(addAttrs) do
		attr:Set(k, v)
    end
	if calc then
		LActor.reCalcRoleAttr(actor, roleId)
		
		damons.power = utils.getAttrPower0(addAttrs)
		local power = 0
		for i=0, LActor.getRoleCount(actor) - 1 do
			power = power + (damonData.damons[i].power or 0)
		end
		updateRankingList(actor, power) --记入精灵排行榜
	end
end

--随机精灵奖励
local function getRankdDamon(rewards)
	local weight = 0 --总权值
	for k, v in pairs(rewards) do
		weight = weight + v[2]
	end

	local num = math.random(1, weight)
	local count = 0
	for k, v in ipairs(rewards) do
		count = count + v[2]
		if count >= num then
			return v[1]
		end
	end
	return 0
end

--定时恢复免费抽奖次数
function setFreeTimes(actor)
	local damonData = getActorVar(actor)
	if damonData.freeTimes > 0 then
		return
	end
	local nextTime = damonData.freeTime - System.getNowTime()
	if nextTime > 0 then
		LActor.postScriptEventLite(actor, nextTime * 1000, function() setFreeTimes(actor) end)
	else
		damonData.freeTimes = 1
	end
end

--设置精灵的实体
function setDamonEntity(actor)
	local damonData = getActorVar(actor)
	local id = damonData.fightId or 0
	if id ~= 0 then		
		LActor.setDamonId(actor, id, 1, DamonConfig[id].MvSpeed)
	end 
end

--获取主精灵
function getMainDamonID(actor)
	local damonData = getActorVar(actor)
	return damonData.fightId or 0
end

function sortRank(a, b)
    return DamonConfig[a].rank > DamonConfig[b].rank
end

--取序号前三的精灵id
function getDamonRankId(actor)
	local damonData = getActorVar(actor)	
	local roleCnt = LActor.getRoleCount(actor)
	local damnoids = {}
	for i=0, LActor.getRoleCount(actor) - 1 do
		local damons = damonData.damons[i]
		for id in pairs(DamonConfig) do
			if damons[id] and damons[id].level > 0 then
				table.insert(damnoids, id)
			end
		end
	end
	table.sort(damnoids, sortRank)
	local tmp = {}
	for i=1, 3 do
		tmp[i] = damnoids[i]
	end

	return tmp
end

function getDamonRankIds(actor)
	local damnoids = getDamonRankId(actor)
	if damnoids[1] and damnoids[2] and damnoids[3] then
		return damnoids[1], damnoids[2], damnoids[3]
	elseif damnoids[1] and damnoids[2] then
		return damnoids[1], damnoids[2]
	elseif damnoids[1] then
		return damnoids[1]
	end
end

_G.getDamonRankId = getDamonRankIds

--获取主精灵等级
function getMainDamonLevel(actor)
	-- local damonData = getActorVar(actor)
	-- local damons = damonData.damons
	-- if damons[damonData.roleId][damonData.fightId] then
	-- 	return damons[damonData.roleId][damonData.fightId].level
	-- end 
	return 1
end

local function onLogin(actor)
	checkDamonData(actor)
	setDamonEntity(actor)
	s2cDamonData(actor)
	s2cDamonBag(actor)
end

local function onInit(actor)
	local roleCnt = LActor.getRoleCount(actor)
	for i=0, roleCnt - 1 do
		calcAttr(actor, i, false)
	end
	setFreeTimes(actor)
end

function getDamonEquipCount(actor)
	local damonData = getActorVar(actor)
	local damons = damonData.damons
	local count = 0
	for i=1, 4 do
		local damon = damonData.damonBag[damons[i]] 
		if damon then
			count = count + 1
		end
	end
	return count
end

function getDamonTotalLevel(actor)
	local damonData = getActorVar(actor)
	local damons = damonData.damons
	local level = 0
	for i=1, 4 do
		local damon = damonData.damonBag[damons[i]] 
		if damon then
			level = level + damon.level
		end
	end
	return level
end

--对精灵背包数据进行检测，把不存在的精灵id变成存在的id
function checkDamonData(actor)
	local damonData = getActorVar(actor)
	local damonBag = damonData.damonBag
	for i=0, damonData.bagCount-1 do
		if not DamonConfig[damonBag[i].id] then
			damonBag[i].id = next(DamonConfig)
		end
	end
end

--求取下一次出传说精灵的次数
local function getNextDrawCount(actor, tp)
	local ret = 200 --100次为循环最高值，可能会溢出最高值
	local damonData = getActorVar(actor)
	local times = damonData.drawTime[tp]
	for k, v in pairs(subactivity10.getLotteryConfig()[tp].times1) do
		if v==2 or v == 3 or v == 4 then --能出传说精灵的奖池
			if k >= times+1 and k < ret then
				ret = k
			end
			if k+100 < ret then --在这循环里后面已无传说精灵的奖池
				ret = k+100
			end
		end
	end
	return ret - times - 1
end

--求回收灵晶数量
function getReclaimCrystal(damon)
end

--技能灵晶回收数量
function getReclaimSkill(damon)
	local value = 0
	if damon.skills then
		for i = 1, #DamonSkillComConfig.slotOpen do
			local sk = damon.skills[i]
			if sk then
				value = value + (DamonSkillComConfig.reclaim[sk.lv] or 0)
			end
		end
	end
	return value
end
------------------------------------------------------------------------------------------
--获得精灵通知
function s2cDamonCreate(actor, id)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_Create)
	LDataPack.writeInt(pack, id)
	LDataPack.flush(pack)
end

--发送精灵数据
function s2cDamonData(actor)
	local damonData = getActorVar(actor)	
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_Data)
	local roleCnt = LActor.getRoleCount(actor)
	LDataPack.writeChar(pack, roleCnt)
	for i=0, roleCnt-1 do
		local damons = damonData.damons[i]
		LDataPack.writeChar(pack, i)
		local cnt = 0
		for id,__ in pairs(DamonConfig) do
			cnt = cnt + 1
		end
		LDataPack.writeShort(pack, cnt)
		for id,__ in pairs(DamonConfig) do
			LDataPack.writeInt(pack, id)			
			LDataPack.writeShort(pack, damons[id] and damons[id].level or 0)
			LDataPack.writeShort(pack, damons[id] and damons[id].signetLv or 0)
			LDataPack.writeShort(pack, damons[id] and damons[id].atPowerPill or 0)
			LDataPack.writeShort(pack, damons[id] and damons[id].defPill or 0)
		end
	end

	local surTime = 0 --剩余时间
	if damonData.freeTimes <= 0 then
		surTime = damonData.freeTime - System.getNowTime()
	end
	LDataPack.writeShort(pack, damonData.freeTimes)
	LDataPack.writeInt(pack, surTime)
	LDataPack.writeShort(pack, getNextDrawCount(actor, 1)) --代券抽奖离传说精灵次数
	LDataPack.writeShort(pack, getNextDrawCount(actor, 2)) --钻石抽奖离传说精灵次数
	LDataPack.writeChar(pack, damonData.roleId or 0)
	LDataPack.writeInt(pack, damonData.fightId or 0)
	LDataPack.flush(pack)
end

--发送精灵背包
function s2cDamonBag(actor)
	local damonData = getActorVar(actor)
	local damonBag = damonData.damonBag
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_Bag)
	local count = 0	
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, count)
	for id,__ in pairs(DamonConfig) do		
		if damonBag[id] and damonBag[id].cnt ~= 0 then 
			LDataPack.writeInt(pack, id)
			LDataPack.writeUInt(pack, damonBag[id].cnt)
			count = count + 1
		end
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeInt(pack, count)
	LDataPack.setPosition(pack, npos)
	LDataPack.flush(pack)
end

--精灵抽奖
function c2sDamonDraw(actor, pack)
	local tp = LDataPack.readChar(pack)
	local config = subactivity10.getLotteryConfig()[tp]
	if not config then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.damon) then return end
	local damonData = getActorVar(actor)
	-- if damonData.bagCount >= MAX_BAGNUM then --精灵过多将导致协议过大而程序崩溃
	-- 	return
	-- end 
	local flag = config.cdTime > 0 and damonData.freeTimes > 0 --可以免费抽
	if not flag and actoritem.checkItems(actor, config.cost) == false then
		return
	end

	if flag then
		damonData.freeTimes = damonData.freeTimes - 1
		damonData.freeTime = System.getNowTime() + config.cdTime
		setFreeTimes(actor) --设置某时间后恢复免费次数
	else
		actoritem.reduceItems(actor, config.cost, "damon draw")
		actoritem.addItem(actor, NumericType_Debris, config.score, "damon draw") --增加积分
	end

	--对使用哪个抽奖池进行计算
	local rewards = config.rewards --普通抽奖池
	damonData.drawTime[tp] = damonData.drawTime[tp] + 1
	local num = config.times1[damonData.drawTime[tp]]
	if num then --更换抽奖池
		rewards = config["rewards"..num]
	end
	if damonData.drawTime[tp] == 100 then
		damonData.drawTime[tp] = 0 --从头轮起
	end

	local id = getRankdDamon(rewards)
	local damonBag = damonData.damonBag
	local damon, type = createDamon(actor, damonData, id)
	if not damon then return end

	s2cDamonUpdate(actor, damon, id, type)--回包
	s2cDamonData(actor)

	actorevent.onEvent(actor, aeDamonDraw)
	if DamonConfig[id].quality >= 4 then
		noticesystem.broadCastNotice(noticesystem.NTP.damon,LActor.getName(actor), DamonConfig[id].name)
	end
	utils.logCounter(actor, "othersystem", damon.id, "", "damon", "draw")
end

--精灵升级
function c2sDamonLevel(actor, pack)	
	local roleId = LDataPack.readChar(pack)
	local id = LDataPack.readInt(pack)	
	if not DamonConfig[id] or not DamonLevelConfig[id] then	return end
	local damonData = getActorVar(actor)
	local damons = damonData.damons[roleId]
	if not damons[id] then
		damons[id] = {}
		damons[id].level = 0
		damons[id].signetLv = 0
	end
	local damon = damons[id]

	local levelConfig = DamonLevelConfig[id][damon.level]
	if not levelConfig then return end
	if not DamonLevelConfig[id][damon.level + 1] then return end	
	local needcnt = levelConfig.needcnt
	if not damonData.damonBag[id] or damonData.damonBag[id].cnt < needcnt then
		return
	end
	damonData.damonBag[id].cnt = damonData.damonBag[id].cnt - needcnt

	damon.level = damon.level + 1
	calcAttr(actor, roleId, true)
	local type = 2
	if damonData.damonBag[id].cnt == 0 then
		type = 3
	end
	s2cDamonUpdate(actor, damonData.damonBag[id], id, type)
	s2cDamonBag(actor)
	
	if damonData.fightId == 0 then
		damonFight(actor, roleId, id)
	end
	if damon.level == 1 then --激活精灵
		actorevent.onEvent(actor, aeActiveDamon, DamonConfig[id].quality)
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_Level)
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeInt(pack, id)
	LDataPack.writeShort(pack, damon.level)
	LDataPack.flush(pack)
	
	actorevent.onEvent(actor, aeDamonLevel, damon.level)
	utils.logCounter(actor, "damon level", idx, damon.id, damon.level)
end

--返回精灵商店数据
function s2cDamonShop(actor)
	local damonData = getActorVar(actor)
	local damonShop = damonData.damonShop
	local count = utils.getTableCount(DamonShopConfig)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_Shop)
	LDataPack.writeShort(pack, count)
	for id, config in pairs(DamonShopConfig) do 
		LDataPack.writeInt(pack, id)
		LDataPack.writeShort(pack, damonShop[id] or 0)
	end
	LDataPack.flush(pack)
end

--查看精灵商店
function c2sDamonShop(actor, pack)
	s2cDamonShop(actor)
end

--购买精灵
function c2sDamonBuy(actor, pack)
	local id = LDataPack.readInt(pack)
	local damonData = getActorVar(actor)
	local damonShop = damonData.damonShop
	local config = DamonShopConfig[id]
	if not config then
		return
	end

	local times = damonShop[id] or 0
	if times >= config.limit then
		return
	end
	if not actoritem.checkItem(actor, NumericType_Debris, config.integral) then --验证积分是否足够
		return
	end

	damonShop[id] = times + 1
	actoritem.reduceItem(actor, NumericType_Debris, config.integral, "damon buy")
	local damon, type = createDamon(actor, damonData, id)
	if not damon then return end

	s2cDamonUpdate(actor, damon, id, type)
	s2cDamonShop(actor)
	utils.logCounter(actor, "damon buy", id, config.integral)
end

--精灵出战
function c2sDamonFight(actor, pack)
	local roleId = LDataPack.readChar(pack)
	local id = LDataPack.readInt(pack)
	damonFight(actor, roleId, id)	
end


function damonFight(actor, roleId, id)
	if not DamonConfig[id] then return end
	local damonData = getActorVar(actor)
	LActor.setDamonId(actor, id, 1, DamonConfig[id].MvSpeed)
	damonData.fightId = id
	damonData.roleId = roleId
	s2cDamonFight(actor, roleId, id)
	actorevent.onEvent(actor,aeDamonFight, 1)
end

--精灵出站返回
function s2cDamonFight(actor, roleId, id)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_Fight)
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeInt(pack, id)
	LDataPack.flush(pack)
end

function s2cDamonUpdate(actor, damon, id, type)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_Update)
	LDataPack.writeInt(pack, id)
	LDataPack.writeUInt(pack, damon.cnt)
	LDataPack.writeChar(pack, type)
	LDataPack.flush(pack)
end

function WriteDamonData(actor, pack)
	local damonData = getActorVar(actor)	
	local roleCnt = LActor.getRoleCount(actor)
	for i=1, roleCnt do
		local damons = damonData.damons[i-1]
		LDataPack.writeChar(pack, i-1)
		local cnt = 0
		for id,__ in pairs(DamonConfig) do
			cnt = cnt + 1
		end
		LDataPack.writeShort(pack, cnt)
		for id,__ in pairs(DamonConfig) do
			LDataPack.writeInt(pack, id)			
			LDataPack.writeShort(pack, damons[id] and damons[id].level or 0)
		end
	end
	LDataPack.writeChar(pack, damonData.roleId or 0)
	LDataPack.writeInt(pack, damonData.fightId or 0)
end

--足迹丹使用信息
function sendPillUseInfo(actor, roleId, damonId)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_PillInfo)
	local damonData = getActorVar(actor)
	local damon = damonData.damons[roleId][damonId]
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeInt(pack, damonId)
	LDataPack.writeWord(pack, damon and damon.atPowerPill or 0)
	LDataPack.writeWord(pack, damon and damon.defPill or 0)
	LDataPack.flush(pack)
end

--精灵印记升级返回
function sendSignetUpInfo(actor, roleId, damonId)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Damon, Protocol.sDamonCmd_SignetInfo)
	local damonData = getActorVar(actor)
	local damon = damonData.damons[roleId][damonId]
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeInt(pack, damonId)
	LDataPack.writeShort(pack, damon.signetLv)
	LDataPack.flush(pack)
end

--精灵印记升级
function c2sDamonSignetUp(actor, pack)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.damonsignet) then return end
	local roleId = LDataPack.readChar(pack)
	local damonId = LDataPack.readInt(pack)
	local damonData = getActorVar(actor)
	local damon = damonData.damons[roleId][damonId]
	if not damon then return end
	damon.signetLv = damon.signetLv or 0
	if not DamonSignetConfig[damon.signetLv + 1] then return end
	local conf = DamonSignetConfig[damon.signetLv]
	if not actoritem.checkItems(actor, conf.costItems) then
		return false
	end
	actoritem.reduceItems(actor, conf.costItems, "damon signet up")
	damon.signetLv = damon.signetLv + 1
	sendSignetUpInfo(actor, roleId, damonId)
	calcAttr(actor, roleId, true)
end

--精灵属性丹使用
function c2sDamonPillUse(actor, pack)
	local roleId = LDataPack.readChar(pack)
	local damonId = LDataPack.readInt(pack)
	local type = LDataPack.readChar(pack)	
	local damonData = getActorVar(actor)
	local damon = damonData.damons[roleId][damonId]
	damon.atPowerPill = damon.atPowerPill or 0
	damon.defPill = damon.defPill or 0
	if type == 0 then
		id = DamonCommonConfig.atPower[DamonConfig[damonId].quality].id
		if damon.atPowerPill >= DamonLevelConfig[damonId][damon.level].atPowerCnt then return end
	else
		id = DamonCommonConfig.def[DamonConfig[damonId].quality].id
		if damon.defPill >= DamonLevelConfig[damonId][damon.level].defCnt then return end
	end

	local costItems = {{id = id, count = 1}}
	if not actoritem.checkItems(actor, costItems) then
		return false
	end
	actoritem.reduceItems(actor, costItems, "damon pill use")

	if type == 0 then
		damon.atPowerPill = damon.atPowerPill + 1
	else
		damon.defPill = damon.defPill + 1
	end

	sendPillUseInfo(actor, roleId, damonId)
	calcAttr(actor, roleId, true)
end

_G.addDamon = addDamon
_G.WriteDamonData = WriteDamonData

local function onCreateRole(actor)
	s2cDamonData(actor)
end

local function regEvent()
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeCreateRole, onCreateRole)

	netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_Draw, c2sDamonDraw)
	netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_Level, c2sDamonLevel)
	netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_Shop, c2sDamonShop)
	netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_Buy, c2sDamonBuy)
	netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_SignetUp, c2sDamonSignetUp)
	netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_Fight, c2sDamonFight)
	netmsgdispatcher.reg(Protocol.CMD_Damon, Protocol.cDamonCmd_PillUse, c2sDamonPillUse)
end

table.insert(InitFnTable, regEvent)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.damonFreeTimes = function (actor, args)
	local damonData = getActorVar(actor)
	damonData.freeTimes = 1
	return true
end

gmCmdHandlers.damonCreate = function (actor, args)
	local damonData = getActorVar(actor)
	local id = tonumber(args[1])
	local cnt = tonumber(args[2])
	for i=1, cnt do
		local damon, type = createDamon(actor, damonData, id)
		if not damon then return end
		s2cDamonUpdate(actor, damon, id, type)
	end		
	return true
end

gmCmdHandlers.damonClean = function (actor, args)
	local var = LActor.getStaticVar(actor)
	var.damondarw = nil
	return true
end

gmCmdHandlers.damonTest = function (actor, args)
	local des = tonumber(args[1])
	local src = tonumber(args[2])
	if des <= 0 or des > 4 then return end
	if src <= 0 or src > 4 then return end
	local damonData = getActorVar(actor)
	local damonBag = damonData.damonBag
	local damons = damonData.damons
	if not damons[src] then --原位置没精灵
		return
	end
	local tmp = damons[des] --保持原目标位置的精灵
	damons[des] = damons[src] 
	damonBag[damons[des]].idx = des
	damons[src] = tmp
	if tmp then
		damonBag[damons[src]].idx = src
	end
	s2cDamonData(actor)
	return true
end

gmCmdHandlers.SetDamonAll = function (actor, args)
    local damonData = getActorVar(actor)
    local count = LActor.getRoleCount(actor)
    for roleId = 0, count - 1 do
        local damons = damonData.damons[roleId]
        for k, v in pairs(DamonConfig) do
            if not damons[k] then damons[k] = {} end
            damons[k].level = #DamonLevelConfig[k]
            damons[k].atPowerPill = DamonLevelConfig[k][#DamonLevelConfig[k]].atPowerCnt
            damons[k].defPill = DamonLevelConfig[k][#DamonLevelConfig[k]].defCnt
            damons[k].signetLv = #DamonSignetConfig
        end
        calcAttr(actor, roleId, true)
    end
    damonFight(actor, 0, 500020)
    s2cDamonData(actor)
    return true
end

gmCmdHandlers.DamonDrawTest = function (actor, args)
	local tp = tonumber(args[1])
	if not tp or type(tp) ~="number" then return end
	for i=1,10000 do
		local pack = LDataPack.allocPacket()
		LDataPack.writeChar(pack, args[1])
		LDataPack.setPosition(pack, 0)
		c2sDamonDraw(actor, pack)
	end
end

gmCmdHandlers.DamonDrawTest1 = function (actor, args)
    local tp = tonumber(args[1]) or 2
    local config = subactivity10.getLotteryConfig()[tp]
    local DConfig = DamonConfig
    local damons = {}
    local drawTime = 0
    if not config then return end
    repeat
        local rewards = config.rewards --普通抽奖池
        drawTime = drawTime + 1
        local num = config.times1[drawTime]
        if num then --更换抽奖池
            rewards = config["rewards"..num]
        end
        if drawTime == 100 then drawTime = 0 end
        local id = getRankdDamon(rewards)
        if id == 0 then
            print ("未抽取到精灵,奖池编号： "..num)
        end
        damons["num"] = (damons["num"] or 0) + 1
        damons[id] = (damons[id] or 0) + 1
        --if id == 500020 then break end
        if damons["num"] >= 10000 then break end
    until (false)
    for k, v in pairs(damons) do
        if type (k) == "number" then
            local name = DConfig[k] and DConfig[k].name or "未知"
            utils.printInfo(name, v)
        end
    end
    print ("总计抽取： "..damons["num"])
    return true
end
