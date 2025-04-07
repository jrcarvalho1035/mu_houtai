-- @version 1.0
-- @author  qianmeng
-- @date    2018-3-21 11:52:36.
-- @system  坐骑系统

require "mount.mount"
require "mount.mountlevel"
require "mount.mountrank"
require "mount.mountgroup"
require "mount.mountequip"
require "mount.mountlottery"
require "mount.mountshop"
require "mount.mountcommon"

module("mountsystem", package.seeall)

local MOUNT_COUNT = 4 --装备坐骑数量

function isOpen(actor)
	return actorexp.checkLevelCondition(actor,actorexp.LimitTp.mount)
end

--坐骑数据获取
function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.mountdata then 
		var.mountdata = {
			mounts = {}, --穿戴坐骑
			equips = {}, --坐骑装备
			freeTimes = 1, --次数
			freeNext = 0,  --上次使用时间
			mountShop = {},
			drawTime = {},
		}
		var.mountdata.drawTime[1] = 0
		var.mountdata.drawTime[2] = 0
	end
	return var.mountdata
end

--坐骑阵容加成
local function getMountFormationAttr(var)
	local mountList = {}
	local totalLevel = 0 --总精灵等级
	local talentCount = 0 --总天赋数量
	local attr1 = {}
	local attr2 = {}
	local attr3 = {}
	for i = 0, MOUNT_COUNT-1 do
		if var.mounts[i] then
			totalLevel = totalLevel + var.mounts[i].level
			talentCount = talentCount + var.mounts[i].talentsNum
			table.insert(mountList, var.mounts[i].id)
		end
	end
	for k, conf in ipairs(MountGroupConfig) do
		if conf.tp == 1 then
			if totalLevel >= conf.arg1 then
				attr1 = conf.attr
			end
		elseif conf.tp == 2 then
			if talentCount >= conf.arg2 then
				attr2 = conf.attr
			end
		elseif conf.tp == 3 then
			local flag = true --是否都装备了这个阵容
			for k1, v1 in ipairs(conf.group) do
				if not utils.checkTableValue(mountList, v1) then
					flag = false --组合不完全
					break
				end
			end
			if flag then
				for k1, v1 in pairs(conf.attr) do
					attr3[v1.type] = (attr3[v1.type] or 0) + v1.value
				end
			end
		end
	end
	return attr1, attr2, attr3
end

--计算坐骑的属性
function calcAttr(actor, calc)
	local var = getActorVar(actor)
	local mount = var.mounts[0]
	if not mount then return end
	 --出战坐骑属性
	 local levelConf = MountLevelConfig[mount.id] and MountLevelConfig[mount.id][mount.level]
	 local rankConf = MountRankConfig[mount.id] and MountRankConfig[mount.id][mount.rank]
	if (not levelConf) or (not rankConf) then return end

	--坐骑等阶属性
	local addAttrs = {}
	for k, v in pairs(levelConf.attr) do
		addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
	end
	for k, v in pairs(rankConf.attr) do
		addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
	end

	--坐骑天赋属性，取卓越属性表
	for i=1, mount.talentsNum do
		local conf = ExcellenceConfig[mount.talents[i]]
		if conf then
			addAttrs[conf.tp] = (addAttrs[conf.tp] or 0) + conf.num
		end
	end

	--坐骑阵容属性
	local attr1, attr2, attr3 = getMountFormationAttr(var)
	for k, v in pairs(attr1) do
		addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
	end
	for k, v in pairs(attr2) do
		addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
	end
	for tp, value in pairs(attr3) do
		addAttrs[tp] = (addAttrs[tp] or 0) + value
	end

	--坐骑装备属性
	for slot, config in pairs(MountEquipConfig) do
		local conf = config[var.equips[slot]]
		if conf then
			for k, v in pairs(conf.attr) do
				addAttrs[v.type] = (addAttrs[v.type] or 0) + v.value
			end
		end
	end

	local fbId = LActor.getFubenId(actor)
	if fbId == 0 then --在主城要加上移动速度
		addAttrs[Attribute.atMvSpeed] = (addAttrs[Attribute.atMvSpeed] or 0) + MountCommonConfig.speed
	end

	--属性附加上去
	local attr = LActor.getActorSystemAttrs(actor, AttrActorSysId_Mount)
	attr:Reset()
	for k, v in pairs(addAttrs) do
		attr:Set(k, v)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

--随机坐骑奖励
local function getRankdMount(rewards)
	local weight = 0 --总权值
	for k, v in pairs(rewards) do weight = weight + v[2] end
	local r = math.random(1, weight)
	for k, v in ipairs(rewards) do
		if r <= v[2] then
			return v[1]
		else
			r = r - v[2]
		end
	end
	return 0
end

--定时恢复免费抽奖次数
function setFreeTimes(actor)
	local var = getActorVar(actor)
	if var.freeTimes > 0 then return end
	local nextTime = var.freeNext - System.getNowTime()
	if nextTime > 0 then
		LActor.postScriptEventLite(actor, nextTime * 1000, function() setFreeTimes(actor) end)
	else
		var.freeTimes = 1
	end
end

--进出主城时设置坐骑实体
function setEntityByFuben(actor, inter)
	local var = getActorVar(actor)
	local mount = var.mounts[0]
	if mount then
		if inter then
			LActor.setMountId(actor, mount.id)
		else
			LActor.setMountId(actor, 0)
		end
		calcAttr(actor, true)
	end
end

--切换坐骑时设置坐骑实体
function setEntityByAdorn(actor, mount)
	local fbId = LActor.getFubenId(actor)
	if fbId == 0 then
		if mount then
			LActor.setMountId(actor, mount.id)
		else
			LActor.setMountId(actor, 0)
		end
		actorevent.onEvent(actor, aeNotifyFacade, 0) --第一个角色变装
	end
end

function adronMount(actor, pos, id, lv, rk, anum, aidx)
	local conf = MountConfig[id]
	if not conf then return end
	local var = getActorVar(actor)
	var.mounts[pos] = {}
	local mount = var.mounts[pos]
	mount.pos = pos --装备位置
	mount.id = id --编号
	mount.level = lv --等级
	mount.rank = rk --等阶
	mount.talents = {} --天赋属性
	mount.talentsNum = anum
	mount.talentsIdx = aidx
	for i=1, anum do --C++里是0~N-1，LUA里是1~N
		local idx = aidx + i
		idx = idx > #conf.exrange and (idx-#conf.exrange) or idx
		mount.talents[i] = conf.exrange[idx] --卓越属性编号
	end
end

--求取下一次出传说精灵的次数
local function getNextDrawCount(actor, tp)
	local ret = 200 --100次为循环最高值，可能会溢出最高值
	local var = getActorVar(actor)
	local times = var.drawTime[tp]
	for k, v in pairs(MountLotteryConfig[tp].times1) do
		if v == 3 or v == 4 then --必出坐骑的奖池
			if k >= times+1 and k < ret then
				ret = k
			end
			if k+100 < ret then --在这循环里后面已无坐骑的奖池
				ret = k+100
			end
		end
	end
	return ret - times - 1
end

function WriteMountData(actor, pack, mount)
	if actor == nil or pack == nil or mount == nil then return end
	LDataPack.writeChar(pack, mount.pos)
	LDataPack.writeInt64(pack, 0)
	LDataPack.writeInt(pack, mount.id)
	LDataPack.writeInt(pack, 1) --物品数量
	LDataPack.writeShort(pack, mount.level)
	LDataPack.writeChar(pack, mount.rank)
	for j=1, 6 do
		local idx = mount.talents[j] or 0
		local conf = ExcellenceConfig[idx]
		LDataPack.writeShort(pack, conf and conf.tp or 0)
		LDataPack.writeShort(pack, conf and conf.num or 0)
	end
	LDataPack.writeByte(pack, mount.talentsNum)
	LDataPack.writeChar(pack, mount.talentsIdx)

	-- LDataPack.writeInt(pack, mount.id)
	-- LDataPack.writeShort(pack, mount.level)
	-- LDataPack.writeChar(pack, mount.rank)
	-- LDataPack.writeChar(pack, mount.talentsNum)
	-- for j=1, mount.talentsNum do
	-- 	local idx = mount.talents[j]
	-- 	local conf = ExcellenceConfig[idx]
	-- 	LDataPack.writeInt(pack, conf.tp)
	-- 	LDataPack.writeInt(pack, conf.num)
	-- end
end

------------------------------------------------------------------------------------------
--坐骑信息
function s2cMountInfo(actor)
	local var = getActorVar(actor)
	if not var then return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mount, Protocol.sMountCmd_Info)
	LDataPack.writeChar(pack, MOUNT_COUNT)
	for i=0, MOUNT_COUNT-1 do
		local mount = var.mounts[i] or {id=0, level=0, rank=0, talents={}, talentsNum=0, pos=i, talentsIdx=0}
		WriteMountData(actor, pack, mount)
	end
	--坐骑装备
	LDataPack.writeChar(pack, #MountEquipConfig)
	for i=1, #MountEquipConfig do
		LDataPack.writeChar(pack, i)
		LDataPack.writeShort(pack, var.equips[i] or 0)
	end
	local cdTime = 0 --剩余时间
	if var.freeTimes <= 0 then
		cdTime = var.freeNext - System.getNowTime()
	end

	LDataPack.writeShort(pack, var.freeTimes)
	LDataPack.writeInt(pack, cdTime)
	LDataPack.writeShort(pack, getNextDrawCount(actor, 1)) --道具抽奖离必出坐骑次数
	LDataPack.writeShort(pack, getNextDrawCount(actor, 2)) --钻石抽奖离必出坐骑次数
	LDataPack.flush(pack)
end

--穿戴坐骑
function c2sMountAdorn(actor, packet)
	if not isOpen(actor) then return end
	local uid = LDataPack.readInt64(packet)
	local pos = LDataPack.readChar(packet)
	if pos < 0 or pos >= MOUNT_COUNT then return end
	local var = getActorVar(actor)
	if not var then return end
	local id, lv, rk, anum, aidx = LActor.getMountInfo(actor, uid)
	if not id then return end
	if var.mounts[pos] then --先卸下
		local mut = var.mounts[pos]
		local tmp = {id=mut.id, level=mut.level, rank=mut.rank, talentsNum=mut.talentsNum, talentsIdx=mut.talentsIdx}
		var.mounts[pos] = nil
		actoritem.addItem(actor, tmp.id, 1, "adorn mount", 2)
		LActor.setMount(actor, tmp.level, tmp.rank, tmp.talentsNum, tmp.talentsIdx)
	end
	LActor.costItemByUid(actor, uid, 1, "adron mount")
	adronMount(actor, pos, id, lv, rk, anum, aidx)
	s2cMountUpdate(actor, pos)
	if pos == 0 then
		setEntityByAdorn(actor, var.mounts[pos])
	end
	calcAttr(actor, true)--计算属性
end

--坐骑升级
function c2sMountLevel(actor, packet)
	if not isOpen(actor) then return end
	local pos = LDataPack.readChar(packet)
	if pos < 0 or pos >= MOUNT_COUNT then return end
	local var = getActorVar(actor)
	if not var then return end
	local mount = var.mounts[pos]
	if not mount then return end

	local config = MountLevelConfig[mount.id]
	if not config then return end
	if not config[mount.level + 1] then return end
	local conf = config[mount.level]
	if not actoritem.checkItems(actor, conf.consume) then --验证骑晶是否足够
		return
	end
	actoritem.reduceItems(actor, conf.consume, "up mount Level:"..mount.level) --扣骑晶
	mount.level = mount.level + 1
	s2cMountUpdate(actor, pos)
	calcAttr(actor, true)
	utils.logCounter(actor, "mount level", pos, mount.id, mount.level)
end

--坐骑进阶
function c2sMountRank(actor, packet)
	if not isOpen(actor) then return end
	local pos = LDataPack.readChar(packet)
	if pos < 0 or pos >= MOUNT_COUNT then return end
	local var = getActorVar(actor)
	if not var then return end
	local mount = var.mounts[pos]
	if not mount then return end
	local config = MountRankConfig[mount.id]
	if not config then return end
	if not config[mount.rank + 1] then return end
	local conf = config[mount.rank]
	if not conf then return end
	if mount.level < conf.levelLimit then
		return
	end
	if not actoritem.checkItems(actor, conf.consume) then --验证骑晶是否足够
		return
	end
	actoritem.reduceItems(actor, conf.consume, "up mount rank:"..mount.rank) --扣骑晶
	mount.rank = mount.rank + 1
	s2cMountUpdate(actor, pos)
	calcAttr(actor, true)
	utils.logCounter(actor, "mount rank", pos, mount.id, mount.rank)
end

--坐骑更新
function s2cMountUpdate(actor, pos)
	local var = getActorVar(actor)
	local mount = var.mounts[pos] or {pos=pos, id=0, level=0, rank=0, talentsNum=0}
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mount, Protocol.sMountCmd_Update)
	WriteMountData(actor, pack, mount)
	LDataPack.flush(pack)
end

--装备坐骑换位
function c2sMountChange(actor, packet)
	if not isOpen(actor) then return end
	local des = LDataPack.readChar(packet) --目标装备位置
	local src = LDataPack.readChar(packet) --原装备位置
	if des < 0 or des >= MOUNT_COUNT then return end
	if src < 0 or src >= MOUNT_COUNT then return end
	if des == src then return end
	local var = getActorVar(actor)
	local mut = var.mounts[src]
	if not mut then --原位置没坐骑
		return
	end
	local tmp = {id=mut.id, level=mut.level, rank=mut.rank, talentsNum=mut.talentsNum, talentsIdx=mut.talentsIdx, talents={}} --记录源坐骑数据
	for i=1, mut.talentsNum do
		table.insert(tmp.talents, mut.talents[i])
	end

	local dut = var.mounts[des]
	if dut then
		mut.id = dut.id
		mut.level = dut.level
		mut.rank = dut.rank
		mut.talentsNum = dut.talentsNum
		mut.talentsIdx = dut.talentsIdx
		mut.talents = {}
		for i=1, dut.talentsNum do 
			mut.talents[i] = dut.talents[i]
		end
	else
		var.mounts[src] = nil
	end
	dut.id = tmp.id
	dut.level = tmp.level
	dut.rank = tmp.rank
	dut.talentsNum = tmp.talentsNum
	dut.talentsIdx = tmp.talentsIdx
	dut.talents = {}
	for i=1, tmp.talentsNum do 
		mut.talents[i] = tmp.talents[i]
	end
	s2cMountUpdate(actor, des)
	s2cMountUpdate(actor, src)
	if des == 0 then
		setEntityByAdorn(actor, dut)
	end
	calcAttr(actor, true)--计算属性
end

--坐骑卸下
function c2sMountUnadorn(actor, packet)
	if not isOpen(actor) then return end
	local pos = LDataPack.readChar(pack)
	if pos < 0 or pos >= MOUNT_COUNT then return end
	local var = getActorVar(actor)
	if not var then return end
	local mount = var.mounts[pos]
	if not mount then return end
	local tmp = {id=mount.id, level=mount.level, rank=mount.rank, talentsNum=mount.talentsNum, talentsIdx=mount.talentsIdx}
	var.mounts[pos] = nil
	actoritem.addItem(actor, tmp.id, 1, "unadorn mount", 2)
	LActor.setMount(actor, tmp.level, tmp.rank, tmp.talentsNum, tmp.talentsIdx)
	s2cMountUpdate(actor, pos)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mount, Protocol.sMountCmd_Unadorn)
	LDataPack.writeChar(pack, pos)
	LDataPack.writeInt(pack, tmp.id)
	LDataPack.flush(pack)

	setEntityByAdorn(actor, nil)
	calcAttr(actor, true)--计算属性
end

--坐骑回收
function c2sMountReclain(actor, packet)
	local foods = {}  --被回收的坐骑
	local count = LDataPack.readInt(packet)
	for i=1, count do
		local fuid = LDataPack.readInt64(packet)
		table.insert(foods, fuid)
	end 
	local sum1 = 0 --返回骑晶数量
	local sum2 = 0 --返回升阶石数量
	for k, fuid in ipairs(foods) do
		local id, lv, rk, anum, aidx = LActor.getMountInfo(actor, fuid)
		local levelConfig = MountLevelConfig[id] and MountLevelConfig[id][lv]
		if levelConfig then
			sum1 = sum1 + levelConfig.recovery
		end
		local rankConfig = MountRankConfig[id] and MountRankConfig[id][rk]
		if rankConfig then
			sum2 = sum2 + rankConfig.recovery
		end
	end

	for k, fuid in ipairs(foods) do --删除被回收的坐骑
		LActor.costItemByUid(actor, fuid, 1, "reclain mount")
	end
	actoritem.addItem(actor, MountCommonConfig.levelItemId, sum1, "reclain mount1")
	actoritem.addItem(actor, MountCommonConfig.rankItemId, sum2, "reclain mount2")
end

--坐骑装备升级
function c2sMountEquipUp(actor, packet)
	if not isOpen(actor) then return end
	local slot = LDataPack.readChar(packet)
	local var = getActorVar(actor)
	if not var then return end
	local lv = var.equips[slot] or 0
	local conf = MountEquipConfig[slot] and MountEquipConfig[slot][lv]
	if not conf then return end
	if not MountEquipConfig[slot][lv+1] then return end
	if not actoritem.checkItems(actor, conf.items) then
		utils.printTable(conf.items)
		return
	end
	actoritem.reduceItems(actor, conf.items, "mount equip up")
	var.equips[slot] = lv + 1

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mount, Protocol.cMountCmd_EquipUp)
	LDataPack.writeChar(pack, slot)
	LDataPack.writeInt(pack, var.equips[slot])
	LDataPack.flush(pack)
	calcAttr(actor, true)--计算属性
end

--坐骑抽奖
function c2sMountDraw(actor, pack)
	local tp = LDataPack.readChar(pack)
	local config = MountLotteryConfig[tp]
	if not config then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.mount) then return end
	local var = getActorVar(actor)
	local flag = config.cdTime > 0 and var.freeTimes > 0 --可以免费抽
	if not flag and actoritem.checkItems(actor, config.cost) == false then
		return
	end

	if flag then
		var.freeTimes = var.freeTimes - 1
		var.freeNext = System.getNowTime() + config.cdTime
		setFreeTimes(actor) --设置某时间后恢复免费次数
	else
		actoritem.reduceItems(actor, config.cost, "mount draw")
		actoritem.addItem(actor, NumericType_MountScore, config.score, "mount draw") --增加积分
	end

	--对使用哪个抽奖池进行计算
	local rewards = config.rewards --普通抽奖池
	var.drawTime[tp] = var.drawTime[tp] + 1
	local num = config.times1[var.drawTime[tp]]
	if num then --更换抽奖池
		rewards = config["rewards"..num]
	end
	if var.drawTime[tp] == 100 then
		var.drawTime[tp] = 0 --从头轮起
	end

	local data = getRankdMount(rewards)
	actoritem.addItem(actor, data[1], data[2], "mount draw")

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mount, Protocol.sMountCmd_Draw)
	LDataPack.writeInt(pack, data[1])
	LDataPack.writeInt(pack, data[2])
	LDataPack.flush(pack)

	s2cMountInfo(actor)

	utils.logCounter(actor, "othersystem", data[1], "", "mount", "draw")
end

--返回坐骑商店数据
function s2cMountShop(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mount, Protocol.sMountCmd_Shop)
	LDataPack.writeShort(pack, #MountShopConfig)
	for idx, config in pairs(MountShopConfig) do 
		LDataPack.writeInt(pack, idx)
		LDataPack.writeShort(pack, var.mountShop[idx] or 0)
	end
	LDataPack.flush(pack)
end

--购买坐骑
function c2sMountBuy(actor, pack)
	local idx = LDataPack.readInt(pack)
	local var = getActorVar(actor)
	local conf = MountShopConfig[idx]
	if not conf then return end

	local times = var.mountShop[idx] or 0
	if times >= conf.limit then return end
	if not actoritem.checkItem(actor, NumericType_MountScore, conf.integral) then --验证积分是否足够
		return
	end

	var.mountShop[idx] = times + 1
	actoritem.reduceItem(actor, NumericType_MountScore, conf.integral, "mount buy")
	actoritem.addItem(actor, conf.id, 1, "mount buy")
	s2cMountShop(actor)
	utils.logCounter(actor, "mount buy", idx, conf.integral)
end

--------------------------------------------------------------------------------------------------------------
local function onLogin(actor)
	s2cMountInfo(actor)
	s2cMountShop(actor)
end

local function onInit(actor)
	calcAttr(actor, false)
	setFreeTimes(actor)
end

--进入主城
local function beforeEnterFb(ins, actor)
	setEntityByFuben(actor, true)
end

--离开主城
local function onExitFb(ins, actor)
	setEntityByFuben(actor, false)
end

local function regEvent()
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeUserLogin, onLogin)

	netmsgdispatcher.reg(Protocol.CMD_Mount, Protocol.cMountCmd_Adorn, c2sMountAdorn)
	netmsgdispatcher.reg(Protocol.CMD_Mount, Protocol.cMountCmd_Level, c2sMountLevel)
	netmsgdispatcher.reg(Protocol.CMD_Mount, Protocol.cMountCmd_Rank, c2sMountRank)
	netmsgdispatcher.reg(Protocol.CMD_Mount, Protocol.cMountCmd_Change, c2sMountChange)
	netmsgdispatcher.reg(Protocol.CMD_Mount, Protocol.cMountCmd_Unadorn, c2sMountUnadorn)
	netmsgdispatcher.reg(Protocol.CMD_Mount, Protocol.cMountCmd_Reclain, c2sMountReclain)
	netmsgdispatcher.reg(Protocol.CMD_Mount, Protocol.cMountCmd_EquipUp, c2sMountEquipUp)
	netmsgdispatcher.reg(Protocol.CMD_Mount, Protocol.sMountCmd_Draw, c2sMountDraw)
	netmsgdispatcher.reg(Protocol.CMD_Mount, Protocol.cMountCmd_Buy, c2sMountBuy)

	--insevent.registerInstanceEnter(0, onEnterFb)
	insevent.registerInstanceEnterBefore(0, beforeEnterFb)
	insevent.registerInstanceExit(0, onExitFb)
end

table.insert(InitFnTable, regEvent)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.mountdraw = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sMountDraw(actor, pack)
	return true
end
