require("systems.instance.instanceevent")
require("utils.utils")
local section = require("systems.instance.play.section_play")
require("systems.instance.play.display") --旧系统中的显示信息模块
require("systems.instance.other.bossinfo")
require("systems.instance.refreshmonsterapi")

--section = systems.instance.play.section_play

require "scene.fuben"

local instanceConfig = FubenConfig

FubenTypes = {
	tp1 = 1, --挂机副本
	tp2 = 2, --普通副本
}
ConditionTypes = {
	tp0 = 0,
	tp1 = 1, --死了某个怪物组的怪
	tp2 = 2, --杀敌波数
	tp3 = 3, --杀光一波怪
	tp4 = 4, --杀掉特定id的怪
	tp5 = 5, --自己死掉
	tp6 = 6, --到了特定时间
	tp7 = 7, --无作用
	tp8 = 8, --某自定义数值达到数量
	tp9 = 9, --某怪物出现后
	tp10 = 10, --某怪物出现前
	tp11 = 11, --在出x波怪之前（可做处理阻断这波怪出现）
	tp12 = 12, --杀掉若干只怪
}

module("instance", package.seeall )

local ins = {
	id = 0,
	type=0,
	handle = nil,
	config = nil,

	scene_list = {},	--这里存创建后的handle

	is_end = false,		--是否结束
	is_win = false,     --是否胜利
	end_time	= 0, 	--逻辑结束时间i
	destroy_time = 0,	--销毁时间
	start_time	= {},	--逻辑开始时间 [0] 对应副本本身， 其他对应场景的
	all_afk_time = nil,	--创建时没有默认塞玩家进来的肯定按固定时间算

	actor_list = {},	--副本玩家列表 actorId:{afk_time, statistics}，掉线清掉
						--statistics统计信息 --暂时没用
						--picks 记录拾起的物品
						--exp 经验奖励
						--enter_time 进入时间
	actor_list_count = 0,	--再副本内的玩家个数

	kill_monster_cnt = 0,	--一共杀死的怪物的数量
	monster_cnt = 0, 		--当前剩余怪物数量
	monster_group_record = {}, 	-- 按组刷出的怪记录刷新批次对应的组号，杀死数，总数 index->{gid, kill, total}
	--monster_group_map = {}, 	-- 记录怪物组号索引 handle->index
	--monster_group_kill_cnt = {},  --记录死亡组数
	events = {}, -- 事件列表
	eventsIndex = {}, -- 为了保证事件按配置顺序执行，做个索引
	time_events = {},	-- 时间相关条件事件列表
	custem_timer = {},  -- 自定义时间触发器
	delay_actions = {},	--time->{event1,event2,event3}

	--display_info = {},    --显示信息: 波数，剩余怪数等
	--statistics_index = {}, --统计信息类型索引

	activity_id = 0,
	drop_refresh_time = 0, --掉落的检测时间
	drop_list = {},		--物品掉落统计
	data = {},   --自定义数据，统一放在data里
	--boss_info = {},  --bossinfo module使用数据，有boss受伤会设置
	--boss_mult = true, --是否多个bossinfo

	next_refresh_time = {},	--下一次的刷怪检测时间（用刷怪类型做key值）
	refresh_monster_idx = 0,	--这次刷到哪个怪物组了
	refresh_monster_count = 0,	--这个组的怪物已经刷了多少个了

	postponeOn = false,	--需要延迟刷怪的副本是否开启刷怪

	exhibit = {}, --展示内容

	rebornMap = {}, --玩家复活信息
	offlineHpMap = {}, --玩家离线血量
	offlineShenmoCD = 0, --离线变身cd
}

--********************************************************************************--
--外部可以用的接口，也可以通过ins对象直接访问成员
--********************************************************************************--

--获取玩家列表,不包含离线的。 或者直接用ins.actor_list
function getActorList(self)
	local actor_list = {}
	for k,v in pairs(self.actor_list) do
		if v.afk_time == nil then
			table.insert(actor_list, LActor.getActorById(k))
		end
	end
	return actor_list
end

function getHandle(self)
	return self.handle
end

function getType(self)
	return self.type
end

function getFid(self)
	return self.id
end

function getSceneIndex(self,scenehandle)
	for i=1,#self.scene_list do
		if self.scene_list[i] == scenehandle then
			return i
		end
	end
	return nil
end

function getStatisticsInfo(self,actor)
	if actor == nil then return nil end
	local aid = LActor.getActorId(actor)
	if self.actor_list[aid] == nil then return nil end
	if self.actor_list[aid].statistics == nil then
		self.actor_list[aid].statistics = {}
	end
	return self.actor_list[aid].statistics
end

function postponeStart(self)
	if self.is_end then return end
	refreshmonsterapi.postponeStart(self)
end

function postponeStop(self)
	if self.is_end then return end
	refreshmonsterapi.postponeStop(self)
end

--外部创建一个副本怪物
function createFubenMonster(self, id, posX, posY)
	if self.is_end then return end
	local ret = self:insCreateMonster(self.scene_list[1], id, posX, posY)
	if not ret then
		return
	end
	self.monster_cnt = self.monster_cnt + 1
	return ret
end

function setEndTime(self, endTime)
	self.end_time = endTime
end

function getEndTime(self)
	return self.end_time
end

--是否有等待复活事件
function isInRebornMap(self, actor)
	local actorId = LActor.getActorId(actor)
	return self.rebornMap[actorId]
end

--清空玩家等待复活事件
function cancelReborn(self, actor)
	local actorId = LActor.getActorId(actor)
	self.rebornMap[actorId] = nil
end

--检查复活
function checkReborn(self, now_t)
	for actorId, actorReborn in pairs(self.rebornMap) do
		if actorReborn.rebornWait <= now_t then
			local actor = LActor.getActorById(actorId)
			if actor then
				self:rebornProcess(actor)
			end
			self.rebornMap[actorId] = nil
			self.offlineHpMap[actorId] = nil
		end
	end
end

--****************************************************************************************--
--[[内部逻辑开始
事件机制备忘:
多种类型条件为了支持与或非合并成条件组，为了提高判断效率，做以下处理
1，条件中有时间的事件处理：在副本初始化后单独放到time_events列表中，
	每次循环时检测，可以考虑进一步做time定时器触发后再检测,不过用定时器的话，考虑不同场景的
	独立时间计算，定时器的计时时间不确定，初始化的工作非常麻烦，所以暂时不做
2. 条件中默认是达成状态（比如全否条件和无条件）的事件处理：在副本初始化后单独放进default_events中，
每次循环时检测,并将条件不成立的设置为deactive

其他条件判断的机制:
	1触发相应的条件时检测所有active的事件，有状态变化的事件再去检测事件的条件组是否达成。
	2达成条件的事件执行一次行为组，然后将重复计数器递增，判断是否有loop次数，有的话，重置条件组
	没有loop次数的设置为deactive。
	3事件触发激活的事件，active后重置所有条件和repeated计数器
因为有激活事件的行为，所以执行过的事件不能从列表中清除，只能通过设置active标记来处理
循环事件没有间隔，间隔可以通过type0的时间来处理，复杂条件需要通过激活事件来组合完成！
--]]
--****************************************************************************************--
function new()
	local o = utils.table_clone(ins)	--里面的表格默认是引用的ins的，要拷贝或写构造函数
	setmetatable(o, {__index = instance});
	--setmetatable(o, self)
	--self.__index = self
	return o;
end

function init(self,fid, handle, ...)
	--print("instance init ****************************  fid:"..fid.. " handle:"..handle)
	local config = instanceConfig[fid]
	if config == nil then
		print("Init instance failed. id: "..fid)
		return false
	end
	self.id = fid
	self.handle = handle
	self.type = config.type
	self.config = config
	--self.target = config.target

	--复制配置
	self.events = utils.table_clone(config.events)
	--做个索引
	for i,_ in pairs(self.events) do
		table.insert(self.eventsIndex, i)
	end
	table.sort(self.eventsIndex)

	if self:initEvents() == false then
		print("events init failed")
		return false
	end

	--创建场景
	if #arg ~= #config.scenes then
		print("init failed scenes count not square "..(#arg).." "..(#config.scenes))
		return false
	end

	for i=1, #arg do
		self.scene_list[i] = arg[i]
	end

	local now_t = System.getNowTime()
	self.start_time[0] = now_t
	if self.config.totalTime and self.config.totalTime > 0 then
		self.end_time = now_t + self.config.totalTime
	end

	-- if self.config.statistics then
	-- 	for _,v in self.config.statistics do
	-- 		self.statistics_index[v] = true
	-- 	end
	-- end

	insevent.onInitFuben(self)

	--刷怪接口
	--refreshmonsterapi.init(self)
	return true
end

function setEnd(self)
	self.is_end = true
	Fuben.setEnd(self.handle)
end

function onStart(self, actor)
	local now_t = System.getNowTime()

	local scenehandle = LActor.getSceneHandle(actor)
	local sceneindex = self:getSceneIndex(scenehandle)
	if sceneindex and self.start_time[sceneindex] == nil then
		self.start_time[sceneindex] = now_t
	end
end

function loadOfflineHp(self, actor)
	if staticfuben.isStaticFuben(self.id) then return end
	local actorId = LActor.getActorId(actor)
	local actorOfflineHp = self.offlineHpMap[actorId]
	if not actorOfflineHp then return end
	local role = LActor.getRole(actor)
	LActor.setHp(role, actorOfflineHp[1] or LActor.getHpMax(role))
end

--进入副本前事件
function beforeEnter(self, actor, isLogin)
	local conf = FubenConfig[self.id]
	if conf and conf.type == 1 then --挂机副本要发送刷怪配置信息
		slim.s2cRefreshConfig(actor, conf.refreshMonster)
	end

	if conf then --发前副本的怪物配置信息
		slim.fbMonsterConfig(actor, self.id)
	end
	self:loadOfflineHp(actor)
	insevent.onEnterBefore(self, actor, isLogin)
end

function onEnter(self, actor, isLogin, isCw)
	--创建玩家信息或者清除离线时间
	self:onStart(actor)	-- 在客户端处理前先自己调用
	local actorId = LActor.getActorId(actor)
	if self.actor_list[actorId] == nil then
		self.actor_list[actorId] = {}
	else
		self.actor_list[actorId].afk_time = nil
	end
	self.actor_list[actorId].enter_time = System.getNowTime()
	local count = 0
	for k, v in pairs(self.actor_list) do count = count + 1 end --人数要这样算，因为returnToLastStaticFuben的影响导致加人后删不掉
	self.actor_list_count = count
	self.all_afk_time = nil

	if self:isInRebornMap(actor) then
		self:sendReBorn(actor)
	else
		if self.config.isSaveBlood ~= 1 and not isLogin then
			LActor.recover(actor)
		end
	end

	--通知奖励信息
	self:notifyRewards(actor)
	insdisplay.notifyDisplay(self, actor) --副本剩余时间要先于其他，因为在onEnter里战盟boss又发了一次自身的倒计时
	insevent.onEnter(self, actor, isLogin, isCw)
	instancesystem.exhibitionFuben(actor, self.exhibit) --展示收获内容


	--发送进度消息
	--log
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
		"fuben", tostring(self.id), tostring(self.handle), tostring(isLogin), "enter", "", "")
end

-----------------------------奖励相关--------------------------------

local function getFubenName(fbId)
	local conf = FubenConfig[fbId]
	return FubenGroupConfig[conf.group].sname or ""
end

--把副本外的物品设为副本奖励
function setRewards(self, actor, rewards)
	local actorId = LActor.getActorId(actor)
	if rewards then
		for k, v in pairs(rewards) do
			if v.id == NumericType_Exp then
				self:addPickExp(actorId, v.count)
			else
				self:addPickItem(actorId, v.type, v.id, v.count)
			end
		end
		local fbname = getFubenName(self.id)
		local text = string.format(ScriptContents["fubendrop"], fbname)
		actoritem.addItemsByJob(actor, rewards, "fuben finish set", 2, text)
	end
end

--获得所有未拾起的掉落物与通关奖励
function giveFubenReward(self, actor)
	local actorId = LActor.getActorId(actor)
	local rewards = {}
	if self.drop_list[actorId] then
		for k, v in pairs(self.drop_list[actorId].items) do
			table.insert(rewards, v)
			self:addPickItem(actorId, v.type, v.id, v.count)
		end
	end
	local fbname = getFubenName(self.id)
	local text = string.format(ScriptContents["fubendrop"], fbname)
	actoritem.addItemsByMail(actor, rewards, "fuben finish", 2, text)

	self.drop_list[actorId] = nil
end

--对奖励物品的排序，要求货币在前，装备在前，品质高的在前
local function sortFunc(a, b)
	if a.type == b.type then
		if a.itemType == b.itemType then
			return a.quality > b.quality
		else
			return a.itemType < b.itemType
		end
	else
		return a.type < b.type
	end
end

--检测要不要发送结算
local function checkNotifyRewards(fubenId, isDie)
	if isDie then return true end
	if FubenGroupAlias[FubenConfig[fubenId].group] and FubenGroupAlias[FubenConfig[fubenId].group].isNotifyRewards == 0 then
		return false
	end
	return true
end

function getActorPicks(self, actorId)
	local actor_picks = self.actor_list[actorId]
	if actor_picks then
		return actor_picks.picks
	end
end

--结算协议，显示奖励物品
function notifyRewards(self, actor, isDie, showWin)
	if not checkNotifyRewards(self.id, isDie) then return end
	if (not isDie) and (not self.is_end) then return end
	local actorId = LActor.getActorId(actor)
	local actorinfo = self.actor_list[actorId]
	if not actorinfo then return end
	local items = {}
	local itemcount = 0
	if actorinfo.picks then
		for k,v in ipairs(actorinfo.picks) do
			if not items[v.id] then itemcount = itemcount + 1 end
			items[v.id] = (items[v.id] or 0) + v.count
		end
	end
	if (actorinfo.exp or 0) > 0 then
		if not items[NumericType_Exp] then itemcount = itemcount + 1 end
		items[NumericType_Exp] = (items[NumericType_Exp] or 0) + actorinfo.exp
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_InsResult)
	if npack == nil then return end
	LDataPack.writeByte(npack, (self.is_win or showWin or fubencommon.isShowWin(self.config.group)) and 1 or 0)
	LDataPack.writeChar(npack, self.config.needNoticeAwards)
	LDataPack.writeInt(npack, System.getNowTime() - actorinfo.enter_time)
	LDataPack.writeShort(npack, itemcount)
	for k, v in pairs(items) do
		LDataPack.writeInt(npack, 0)
		LDataPack.writeInt(npack, k)
		LDataPack.writeDouble(npack, math.floor(v) * ((self.data.double or 0) + 1))
		LDataPack.writeByte(npack, self.data.double or 0) -- 活动双倍
	end
	LDataPack.writeDouble(npack, actorinfo.extra1 or 0)
	LDataPack.writeDouble(npack, actorinfo.extra2 or 0)
	LDataPack.writeDouble(npack, actorinfo.extra3 or 0)
	LDataPack.flush(npack)
	for k, v in pairs(items) do
		if (self.data.double or 0) == 1 then --活动双倍
			actoritem.addItem(actor, k, v, "act double")
		end
	end
end

function notifyBossWarn(self)
	local actors = self:getActorList()
	for _, actor in ipairs(actors) do
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_InsBossWarn)
		if npack == nil then return end
		LDataPack.flush(npack)
	end
end

-----------------------------奖励相关--------------------------------
function win(self)
	--已经结束的副本不再触发
	if self.is_end then return end
	self:setEnd()
	self.is_win = true

	--print("------------------------win-----------------------")
	local closeTime = self.config.closeTime or 0
	if self.all_afk_time then closeTime = 0 end

	self.destroy_time = System.getNowTime() + closeTime
	for _,sceneHdl in pairs(self.scene_list) do
		Fuben.killAllMonster(sceneHdl) --不能用clearAllMonster，它会让怪物在被技能攻击前就在场景消失，导致宕机
	end

	local actors = self:getActorList()
	for _, actor in ipairs(actors) do
		self:giveFubenReward(actor) --把掉落物都收走
	end
	insevent.onWin(self) --因为日常副本要计算picks里的内容，所以win事件要在giveFubenReward后发
	for _, actor in ipairs(actors) do
		self:notifyRewards(actor)
	end
end

function lose(self)
	--已经结束的副本不再触发
	if self.is_end then return end
	self:setEnd()

	--print("------------------------lose-----------------------")
	local closeTime = self.config.closeTime or 0
	if self.all_afk_time then closeTime = 0 end

	self.destroy_time = System.getNowTime() + closeTime
	local actors = self:getActorList()
	for _, actor in ipairs(actors) do
		self:giveFubenReward(actor) --把掉落物都收走
	end
	insevent.onLose(self)
	local actors = self:getActorList()
	for _, actor in ipairs(actors) do
		self:notifyRewards(actor)
	end
end

function release(self)
	--print("------------------------release instance-------------------------   "..self.id)
	self:setEnd()
	instancesystem.releaseInstance(self.handle)
end

function runOne(self,now_t)

	--print("run instance.........hdl: "..tostring(self.handle).. "time:"..now_t)
	if self.config.type == FubenTypes.tp1 then
		local actorList = self:getActorList()
		if #actorList <= 0 then
			self:release()
			return
		end
	end
	if self.destroy_time > 0 and now_t > self.destroy_time then
		--回收副本
		self:release()
		return
	end
	--检查离线玩家是否超时
	if self.config.remainTime and self.config.remainTime > 0 then
		if self.all_afk_time and now_t - self.config.remainTime > self.all_afk_time then
		--回收副本
			self:lose()
			self:release()
			return
		end
	end

	if self.end_time > 0 and now_t > self.end_time then
		if not self.is_end then
			if FubenGroupAlias[self.config.group] and FubenGroupAlias[self.config.group].isWin == 1 then
				self:win()
			else
				--超时失败
				self:lose()
			end
			--让所有怪消失掉
			for _,sceneHdl in pairs(self.scene_list) do
				Fuben.clearAllMonster(sceneHdl)
			end
		end
		return
	end

	if self.is_end then return end

	--时间条件检测
	for _, event in ipairs(self.time_events) do
		self:tryEvent(event, self.checkTimeTriggerCondition, now_t)
	end

	--自定义定时器检测
	for id, time in pairs(self.custem_timer) do
		if now_t > time then
			self:tryConditions(self.checkCustemTimerTriggerCondition, id)
			self.custem_timer[id] = nil
		end
	end

	if not self.drop_refresh_time or self.drop_refresh_time <= now_t then
		self.drop_refresh_time = (self.drop_refresh_time or 0) + 3
		--检查过期的掉落物品
		if self.drop_list then
			for actorId, actorDrops in pairs(self.drop_list) do
				if actorDrops.length > 0 and actorDrops.items then
					--local actor = LActor.getActorById(actorId)
					for key, list in pairs(actorDrops.items) do
						if list.time > 0 and now_t >= list.time then
							sendRemoveDropResult(actorId, key, 3, self, actorDrops)
							actorDrops.items[key] = nil
						end
					end
					actorDrops.isSendMail = nil
				end
			end
		end
	end

	--玩家复活
	self:checkReborn(now_t)

	--刷怪接口(通用的刷怪规则)
	refreshmonsterapi.runOne(self, now_t)
end

function insCreateMonster(self, scene, id, posX, posY, avatarIndex)
	local isstaticfuben = (self.config.type == 1)
	if not isstaticfuben then
		self:tryConditions(self.checkMonsterBeforeCondition, id)
	end
	local monster = Fuben.createMonster(scene, id, posX, posY, 0, avatarIndex or 0)
	if not monster then
		print("create monster fail  "..id)
		return false
	end
	if not isstaticfuben then
		self:tryConditions(self.checkMonsterAppearCondition, id)
	end
	return monster
end

function checkAfk(self)
	local count = 0
	for _, info in pairs(self.actor_list) do
		if info.afk_time == nil then
			return
		end
		count = count + 1
	end
	if count == 0 and self.config.isPublic == 0 then
		self:lose()
		self.all_afk_time = System.getNowTime()
	end
end

--通过进入副本触发的离开之前副本，正常退出或其他功能拉出会调用
function onExit(self,actor)
	local actorId = LActor.getActorId(actor)
	if self.actor_list[actorId] then --避免exit与offline触发两次
		self.actor_list_count = self.actor_list_count - 1
	end

	self:checkAfk()
	self:cancelReborn(actor)
	insevent.onExit(self, actor)
	self.actor_list[actorId] = nil
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
		"fuben", tostring(self.id), tostring(self.handle), "", "exit", "", "")
end

function saveOfflineHp(self, actor)
	if staticfuben.isStaticFuben(self.id) or System.isBattleSrv() then return end
	if not actor then return end
	local actorOfflineHp = {}
	local role = LActor.getRole(actor)
	table.insert(actorOfflineHp, LActor.getHp(role))
	local actorId = LActor.getActorId(actor)
	self.offlineHpMap[actorId] = actorOfflineHp
end

--通过c++ 离开场景触发，暂时只会离线一种情况
function onOffline(self,actor)
	local actorId = LActor.getActorId(actor)
	if self.actor_list[actorId] then --避免exit与offline触发两次
		self.actor_list[actorId].afk_time = System.getNowTime() --记录离线时间
		self:checkAfk()
	end

	self:saveOfflineHp(actor) --保存离线血量
	insevent.onOffline(self, actor)
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
		"fuben", tostring(self.id), tostring(self.handle), "", "offline", "", "")
end

function onEntityDie(self, et, killer, killerHdl_double, killActorId, killHpper)
	--发送实体死亡信息
	local actors = self:getActorList()
	local entype = LActor.getEntityType(et)

	if entype == EntityType_Actor then
		self:onActorDie(et, killer, killerHdl_double, killActorId, killHpper)
	elseif entype == EntityType_Monster then
		self:onMonsterDie(et, killer)
	elseif entype == EntityType_ActorClone then
		self:onActorCloneDie(et, killer)
	elseif entype == EntityType_RoleClone then
		self:onCloneRoleDie(et, killer)
	elseif entype == EntityType_Role then
		self:onRoleDie(et,killer)
	end
	-- print("-----------------------onEtDie---------------------- type:".. entype.. " id:"..LActor.getId(et))
end

function onActorCloneDie(self, actorClone,killerHdl)
	insevent.onActorCloneDie(self, killerHdl, actorClone)
end

function onCloneRoleDie(self, mon,killerHdl)
	insevent.onCloneRoleDie(self)
end

function onMonsterDie(self, mon, killerHdl)
	local scenehandle = LActor.getSceneHandle(mon)
	local sceneIndex = self:getSceneIndex(scenehandle)

	if self.monster_cnt > 0 then
		self.monster_cnt = self.monster_cnt - 1
	end

	bossinfo.bossDieNotify(self, mon)

	self.kill_monster_cnt = (self.kill_monster_cnt or 0) + 1

	insevent.onMonsterDie(self, mon, killerHdl)
	monsterdrop.onMonsterDie(self, mon, killerHdl)

	local actor = LActor.getActor(LActor.getEntity(killerHdl))
	local group_id = LActor.getFubenGroup(actor)
	self:checkMonsterKillEvent(mon, group_id, actor)
	if actor then
		actorevent.onEvent(actor, aeMonsterDie, Fuben.getMonsterId(mon), 1)
	end
end

--记录增加掉落
function addDropBagItem(self, actor, items, limitTime, posX, posY, isNotify)
	if not actor or not items then return end

	local actorId = LActor.getActorId(actor)
	if not self.drop_list[actorId] then self.drop_list[actorId] = {} end
	if not self.drop_list[actorId].items then self.drop_list[actorId].items = {} end
	if not self.drop_list[actorId].length then self.drop_list[actorId].length = 0 end

	if not self.actor_list[actorId] then
		utils.printInfo("drop item not actor_list", actorId)
		return
	end --玩家已离开副本
	if not self.actor_list[actorId].picks then self.actor_list[actorId].picks = {} end

	local nowLength = self.drop_list[actorId].length
	local length = nowLength
	if limitTime > 0 then limitTime = System.getNowTime() + limitTime end
	for _, conf in pairs(items) do
		if conf.type == AwardType_Item then
			for i = 1, conf.count do
				length = length + 1
				self.drop_list[actorId].items[length] = {type = conf.type, id = conf.id, count = 1, time = limitTime, name = (isNotify and LActor.getName(actor))}
			end
		else
			length = length + 1
			self.drop_list[actorId].items[length] = {type = conf.type, id = conf.id, count = conf.count, time = limitTime, name = (isNotify and LActor.getName(actor))}
		end

	end
	self.drop_list[actorId].length = length

	if posX and posY then
		self:sendDropBagInfo(actor, nowLength+1, posX, posY, isNotify)
		actorevent.onEvent(actor, aeDropItem)
	end
end

--是否能拾进背包
function checkInBag(itemId, actor)
	if itemId == XueseCommonConfig.angelid then --大天使之剑不进背包
		xuese.onPickItem(actor) --通知玩家去交任务
		return false
	end
	return true
end

--拾取（获得 并 删除某一个掉落）
function removeDropBagItem(self, actor, key)
	if not actor or not key then return end
	local actorId = LActor.getActorId(actor)

	if self.is_win then --胜利后拾取的物品都是假的
		sendRemoveDropResult(actorId, key, 0)
		return
	end

	if not self.drop_list[actorId] or not self.drop_list[actorId].items or not self.drop_list[actorId].items[key] then
		sendRemoveDropResult(actorId, key, 1)	--没有这个掉落
		return
	end

	local item = self.drop_list[actorId].items[key]
	if item.type == AwardType_Item and ItemConfig[item.id].type == 0 and LActor.getEquipBagSpace(actor) < 1 then --捡装备前验证背包空间
		sendRemoveDropResult(actorId, key, 2)	--背包空间不足
		return
	end

	self.drop_list[actorId].items[key] = nil
	sendRemoveDropResult(actorId, key, 0, self)	--拾取成功
	if checkInBag(item.id, actor) then
		actoritem.addItem(actor, item.id, item.count, "loot_"..LActor.getFubenId(actor), 1) --拾取的物品有另外的类型
		insevent.onPickItem(self, actor, item.type, item.id, item.count)
		self:addPickItem(actorId, item.type, item.id, item.count) --记录副本收获物品
	end
end

--记录获得的经验
function addPickExp(self, actorId, exp)
	if self.config.needNoticeAwards <= 0 then
		return
	end
	if not self.actor_list[actorId] then --玩家可能已离开副本
		utils.printInfo("pick exp not actor_list", actorId)
		return
	end
	self.actor_list[actorId].exp = (self.actor_list[actorId].exp or 0) + exp
	if self.exhibit.id and self.exhibit.id == NumericType_Exp then
		self.exhibit.count = (self.exhibit.count or 0) + exp
		local actor = LActor.getActorById(actorId)
		instancesystem.exhibitionFuben(actor, self.exhibit)
	end
end

--记录副本收获物品
function addPickItem(self, actorId, tp, id, count)
	-- {type 类型（金钱或物品）, id 物品ID或金钱类型， count 物品数量或金钱数量， time 超过这个时间后就删除}
	-- length 累加上去的，当作唯一的标识
	if not self.actor_list[actorId] then self.actor_list[actorId] = {} end
	if not self.actor_list[actorId].picks then self.actor_list[actorId].picks = {} end
	if tp == AwardType_Item then
		table.insert(self.actor_list[actorId].picks, {type = tp, id = id, count = count})
	else
		local hasAdd = false
		for idx, rewardConf in pairs(self.actor_list[actorId].picks) do
			if rewardConf.id == id then
				rewardConf.count = rewardConf.count + count
				hasAdd = true
			end
		end
		if not hasAdd then
			table.insert(self.actor_list[actorId].picks, {type = tp, id = id, count = count})
		end
	end
	if self.exhibit.id and self.exhibit.id == id then
		self.exhibit.count = (self.exhibit.count or 0) + count
		local actor = LActor.getActorById(actorId)
		instancesystem.exhibitionFuben(actor, self.exhibit)
	end
end

--设置额外值1
function setExtraData1(self, actorId, value)
	if not self.actor_list[actorId] then --玩家可能已离开副本
		return
	end
	self.actor_list[actorId].extra1 = value
end

--设置额外值2
function setExtraData2(self, actorId, value)
	if not self.actor_list[actorId] then --玩家可能已离开副本
		return
	end
	self.actor_list[actorId].extra2 = value
end

--设置额外值3
function setExtraData3(self, actorId, value)
	if not self.actor_list[actorId] then --玩家可能已离开副本
		return
	end
	self.actor_list[actorId].extra3 = value
end

--设置物品limitTime秒后过期
function setDropBagTime(self, actor, limitTime)
	if not actor then return end
	local actorId = LActor.getActorId(actor)
	if not self.drop_list or not self.drop_list[actorId] then return end

	local timeTmp = System.getNowTime() + limitTime
	for key, list in pairs(self.drop_list[actorId].items) do
		self.drop_list[actorId].items[key].time = timeTmp
	end
end

function addMaiItem(tAwardList, items)
	local isHave = false
	for k,v in pairs(items) do
		isHave = false
		for i=1, #tAwardList do
			if tAwardList[i].id == v.id then
				tAwardList[i].count = tAwardList[i].count + v.count
				isHave = true
				break
			end
		end
		if not isHave then
			tAwardList[#tAwardList + 1] = {}
			tAwardList[#tAwardList].type = v.type
			tAwardList[#tAwardList].id = v.id
			tAwardList[#tAwardList].count = v.count
		end
	end

end

--删除掉落的结果
--0成功，1没有这个掉落，2背包空间不足，3过期删掉了
function sendRemoveDropResult(actorId, key, result, ins, drop_list)
	if not actorId or not key or not result then return end
	if drop_list and not drop_list.isSendMail and drop_list.items[key].name then
		local awardList = {}
		addMaiItem(awardList, drop_list.items)
		local mailData = {head = SMFBCommonConfig.mailTitle, context = SMFBCommonConfig.mailContent, tAwardList = awardList}
		mailsystem.sendMailById(actorId, mailData)
		drop_list.isSendMail = true
	end
	local actor = LActor.getActorById(actorId)
	local pack
	if ins then
		pack = LDataPack.allocPacket()
		LDataPack.writeByte(pack, Protocol.CMD_Base)
		LDataPack.writeByte(pack, Protocol.sBaseCmd_LootItemResult)
	else
		pack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_LootItemResult)
	end
	if not pack then return end
	LDataPack.writeInt(pack, key)
	LDataPack.writeShort(pack, result)
	if ins then
		Fuben.sendData(ins.handle, pack)
	else
		LDataPack.flush(pack)
	end
end

--发送掉落的信息
function sendDropBagInfo(self, actor, nowLength, posX, posY, isNotify)
	if not actor then return end
	if not nowLength then nowLength = 1 end
	local actorId = LActor.getActorId(actor)

	if not self.drop_list[actorId] then return end
	local pack
	if isNotify then
		pack = LDataPack.allocPacket()
		LDataPack.writeByte(pack, Protocol.CMD_Base)
		LDataPack.writeByte(pack, Protocol.sBaseCmd_DropItems)
	else
		pack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_DropItems)
	end
	if not pack then return end

	local items = {}
	for i = nowLength, self.drop_list[actorId].length do
		local item = self.drop_list[actorId].items[i]
		if item then
			table.insert(items, {key = i, type = item.type, id = item.id, count = item.count})
		end
	end

	LDataPack.writeInt(pack, posX)
	LDataPack.writeInt(pack, posY)
	LDataPack.writeString(pack, isNotify and LActor.getName(actor) or "")
	LDataPack.writeInt(pack, #items)
	for _, item in ipairs(items) do
		LDataPack.writeInt(pack, item.key)
		LDataPack.writeInt(pack, item.type)
		LDataPack.writeInt(pack, item.id)
		LDataPack.writeInt(pack, item.count)
	end

	if isNotify then
		Fuben.sendData(self.handle, pack)
	else
		LDataPack.flush(pack)
	end
end

--复活回调处理
function rebornProcess(self, actor)
	if not actor then return end
	local conf = FubenConfig[self.id]
	if not conf then return end
	local sceneId = conf.scenes[1]
	if not sceneId then return end
	local sceneConf = ScenesConfig[sceneId]
	if not sceneConf then return end
	local reborn = sceneConf.reborn
	local rebornCount = #reborn
	if rebornCount == 0 then return end

	local useConf = nil
	for i = 1, rebornCount do
		local oneReborn = reborn[i]
		if oneReborn.type ==  RebornType_Random then
			useConf = oneReborn
			break
		elseif oneReborn.type ==  RebornType_Camp then
			useConf = oneReborn
			break
		end
	end
	if useConf == nil then return end

	local posXY = nil
	if useConf.type == RebornType_Random then
		if #useConf.pos > 0 then
			local randIndex = System.getRandomNumber(#useConf.pos) + 1
			posXY = useConf.pos[randIndex]
		end
	elseif useConf.type == RebornType_Camp then
		local camp = LActor.getCamp(actor)
		local positions = useConf.pos[camp]
		if positions and #positions > 0 then
			local randIndex = System.getRandomNumber(#positions) + 1
			posXY = positions[randIndex]
		end
	end
	if not posXY then
		posXY = {}
		posXY[1], posXY[2] = LActor.getEntityScenePos(actor)
	end
	LActor.reborn(actor, posXY[1], posXY[2])
end

--发送复活信息
function sendReBorn(self, actor)
	local actorId = LActor.getActorId(actor)
	local actorReborn = self.rebornMap[actorId]
	if not actorReborn then return end
	local rebornConfig = actorReborn.rebornConfig
	local rebornCount = #rebornConfig
	if rebornCount == 0 then return end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_InsReborn)
	if npack == nil then return end
	LDataPack.writeDouble(npack, actorReborn.killerHdl)
	LDataPack.writeInt(npack, actorReborn.rebornWait - System.getNowTime())
	LDataPack.writeByte(npack, rebornCount)
	for i = 1, rebornCount do
		local oneReborn = rebornConfig[i]
		LDataPack.writeByte(npack, oneReborn.type)
		local  costItems = oneReborn.costitems
		local costItemCount = #costItems
		LDataPack.writeByte(npack, costItemCount)
		for j = 1, costItemCount do
			local item = costItems[j]
			LDataPack.writeInt(npack, item.type)
			LDataPack.writeInt(npack, item.id)
			LDataPack.writeInt(npack, item.count)
		end
	end
	LDataPack.flush(npack)
end

--增加复活信息
function addReborn(self, actor, killerHdl)
	local conf = FubenConfig[self.id]
	if not conf then return end
	local sceneId = conf.scenes[1]
	if not sceneId then return end
	local sceneConf = ScenesConfig[sceneId]
	if not sceneConf then return end

	local rebornConfig = sceneConf.reborn
	local rebornCount = #rebornConfig
	if rebornCount == 0 then return end

	--复活延迟信息
	actorReborn = {}
	actorReborn.rebornWait = sceneConf.rebornWait + System.getNowTime()
	actorReborn.killerHdl = killerHdl
	actorReborn.rebornConfig = rebornConfig
	local actorId = LActor.getActorId(actor)
	self.rebornMap[actorId] = actorReborn

	self:sendReBorn(actor)
end

--增加复活信息
function sendkillerHdl(self, actor, killerHdl)
	local et = LActor.getEntity(killerHdl)
    local killer_actor = LActor.getActor(et)
    if not killer_actor then return end

    --给被杀者发送杀人者的masterhandle
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_sendKillerHandle)
	if pack == nil then return end
	LDataPack.writeDouble(pack, LActor.getHandle(killer_actor))
	LDataPack.flush(pack)

	--给杀人者发送被杀者的masterhandle
	local pack = LDataPack.allocPacket(killer_actor, Protocol.CMD_AllFuben, Protocol.sFubenCmd_sendDeadHandle)
	if pack == nil then return end
	LDataPack.writeDouble(pack, LActor.getHandle(actor))
	LDataPack.flush(pack)
end

function onRoleDie(self, role, killer_hdl)
	insevent.onRoleDie(self,role,killer_hdl)
end

function onActorDie(self, actor, killerHdl, killerHdl_double, killActorId, killHpper)
	--处理其他模块回调函数
	insevent.onActorDie(self, actor, killerHdl, killActorId, killHpper)
	--通用复活
	self:addReborn(actor, killerHdl_double)
	--通用向双方下发master
	self:sendkillerHdl(actor, killerHdl)
	--现在不考虑，需要根据条件定义需记录数据
	self:tryConditions(self.checkActorDieCondition)
end

function onMonsterCreate(self, mon)
	--动态属性放在c++还是lua呢？
	-- print("---------------------on monster create: "..Fuben.getMonsterId(mon).."-----------------")
	insevent.onMonsterCreate(self, mon)
end

function onSectionTrigger(self, sect, scenePtr)
	local sceneindex = self:getSceneIndex(Fuben.getSceneHandleByPtr(scenePtr))
	if sceneindex ~= nil then
		print("instance on section trigger "..(sect+1).." scene:"..sceneindex)
		self:tryConditions(self.checkSectionTrigger, sect, sceneindex)
	end
end

--设置自定义变量
function onSetCustomVariable(self, name, value)
	self[name] = value
	self:onChangeCustomVariable(name, value)
end

--获取自定义变量
function onGetCustomVariable(self, name)
	return self[name] or 0
end

--自定义变量条件
function onChangeCustomVariable(self, name, value)
	insevent.onVariantChange(self, name, value)
	self:tryConditions(self.checkCustemVariableCondition, name, value)
end

function onRefreshWave(self, idx)
	self:tryConditions(self.checkRefreshIdxCondition, idx)
end

--*********************************************************************************--
--条件相关接口
--*********************************************************************************--

--返回是否有改动
function checkTimeTriggerCondition(self, condition, now_t)
	if condition.finish == true then return false end
	if condition.type ~= ConditionTypes.tp0 then return false end
	local scene = condition.scene or 1
	if self.start_time[scene] and ((now_t - self.start_time[scene]) >= (condition.time + condition.increment)) then
		condition.finish = true
		return true
	end
	return false
end

--返回是否有改动
function checkCustemTimerTriggerCondition(self, condition, id)
	if condition.finish == true then return false end
	if condition.type == ConditionTypes.tp6 and condition.id == id then
		condition.finish = true
		return true
	end
	return false
end

--返回是否有改动
function checkActorDieCondition(self, condition)
	if condition.finish == true then return false end
	if condition.type == ConditionTypes.tp5 then
		condition.diecnt = (condition.diecnt or 0) + 1
		if condition.diecnt >= (condition.count or 1)then
			condition.finish = true
			return true
		end
	end
	return false
end


--检查分段触发
function checkSectionTrigger(self, condition, sect, scene_index)
	if condition.finish == true then return false end
	if condition.type ~= ConditionTypes.tp7  then return false end
	if (condition.scene or 1) == scene_index  and condition.id == sect + 1 then
		condition.finish = true
		return true
	end
	return false;
end

--检查怪物事件接口
function checkMonsterKillCondition(self, condition, mon_id, scene_index, all_killed, gid)
	if condition.finish == true then return false end
	if (condition.scene or 1) ~= scene_index then return false end

	if condition.type == ConditionTypes.tp2 and all_killed == 1 then --累计杀敌波数
		condition.cnt = (condition.cnt or 0) + 1
		if condition.count <= condition.cnt then
			condition.finish = true
			return true
		end
	elseif condition.type == ConditionTypes.tp3 and all_killed == 1 then --杀光一波怪
		condition.finish = true
		return true
	elseif condition.type == ConditionTypes.tp4 then  --杀掉特定boss
		if condition.id == mon_id then
			condition.killcnt = (condition.killcnt or 0) + 1
			if condition.count <= condition.killcnt then
				if not condition.nofinish then
					condition.finish = true
				end
				return true
			end
		end
	elseif condition.type == ConditionTypes.tp12 then --累计杀怪数量
		condition.cnt = (condition.cnt or 0) + 1
		if condition.count <= condition.cnt then
			condition.finish = true
			return true
		end
	elseif gid and condition.type == ConditionTypes.tp1 and condition.id == gid then
		condition.finish = true
		return true
	end
	return false
end

--检查怪物出现前事件
function checkMonsterBeforeCondition(self, condition, mon_id)
	if condition.finish == true then return false end
	if condition.type == ConditionTypes.tp10 then
		if condition.id == mon_id then
			if not condition.nofinish then --如果副本是循环刷怪的话，这些条件也不会结束验证
				condition.finish = true
			end
			return true
		end
	end
	return false
end

--检查怪物出现事件
function checkMonsterAppearCondition(self, condition, mon_id)
	if condition.finish == true then return false end
	if condition.type == ConditionTypes.tp9 then
		if condition.id == mon_id then
			if not condition.nofinish then --如果副本是循环刷怪的话，这些条件也不会结束验证
				condition.finish = true
			end
			return true
		end
	end
	return false
end

function checkCustemVariableCondition(self, condition, name, value)
	if condition.finish == true then return false end
	if condition.type == ConditionTypes.tp8 then
		if condition.name == name and (condition.value == nil or condition.value == value) then
			condition.finish = true
			return true
		end
	end
	return false
end

--检查某波怪出现前事件
function checkRefreshIdxCondition(self, condition, idx)
	if condition.finish == true then return false end
	if condition.type == ConditionTypes.tp11 then
		if condition.wave == idx then
			if not condition.nofinish then --如果副本是循环刷怪的话，这些条件也不会结束验证
				condition.finish = true
			end
			return true
		end
	end
	return false
end

--返回发现时间条件
function initTimeCondition(self, condition)
	if condition.type == ConditionTypes.tp0 then
		condition.increment = 0
		condition.finish = false
		return true
	end
	return false
end

--返回否，foreach中多个条件的结果用or获得，所以最终用false判断
function findAllNotCondition(self, condition)
	if condition.flag == "not" then
		return false
	end
	return true
end

function initEvents(self)
	for i, event in pairs(self.events) do
		--时间处理优化
		if self:forEachCondition(event.conditions, self.initTimeCondition) == true then
			table.insert(self.time_events, event)
		end
		-- --全否条件处理优化
		-- if self:forEachCondition(event.conditions, self.findAllNotCondition) == false then
		--     print("init failed, invalid conditions in event: ".. i)
		--     return false
		-- end
		self:initEvent(event)
	end
	return true
end

function initEvent(self, event)
	event.repeated = 0
	self:forEachCondition(event.conditions, self.resetConditionFunc)
end

function resetConditionFunc(self, condition)
	if condition.flag == "not" then return end
	condition.finish = false
	if condition.type == ConditionTypes.tp0 then
		local s = self.start_time[condition.scene or 1]
		if s == nil then
			condition.increment = 0
		else
			condition.increment = System.getNowTime() - s
		end
	elseif condition.type == ConditionTypes.tp2 then
		condition.cnt = 0
	elseif condition.type == ConditionTypes.tp4 then
		condition.killcnt = 0
	elseif condition.type == ConditionTypes.tp5 then
		condition.diecnt = 0
	end
end


function checkMonsterKillEvent(self, mon, gid, actor)
	local mon_id = Fuben.getMonsterId(mon)
	local sceneHdl = LActor.getSceneHandle(mon)
	local scene_index = self:getSceneIndex(sceneHdl)
	local remaincount = Fuben.isKillAllMonster(sceneHdl, mon_id)
	local isAllKilled = Fuben.isKillAllMonster(sceneHdl)

	if remaincount == 0 then
		insevent.onMonsterAllDie(self, mon, actor) --团杀事件要在刷怪前
		--先触发团杀刷怪事件，再触发自定义事件，不然血色破门后会触发两次刷怪
		--有可能会导致副本结束了还会刷怪
		refreshmonsterapi.monsterAllKilled(self)
		guajifuben.monsterAllKilled(self, mon, actor)
	end
	if not self.is_end and FubenGroupAlias[self.config.group]
		and FubenGroupAlias[self.config.group].monsterdie == 1 and isAllKilled == 1 then
		shenghun.onMonsterAllDie(self)
		refreshmonsterapi.refreshMonsters6(self)
	end
	self:tryConditions(self.checkMonsterKillCondition, mon_id, scene_index, isAllKilled, gid)
end

function checkConditions(self, conditions)
	if conditions.flag == "or" then
		local ret = false
		for _, condition in ipairs(conditions) do
			ret = ret or self:checkConditions(condition)
		end
		return ret
	elseif conditions.flag == "and" then
		local ret = true
		for _, condition in ipairs(conditions) do
			ret = ret and self:checkConditions(condition)
		end
		return ret
	elseif conditions.flag == "is" then
		if conditions.finish == true then
			return true
		else
			return false
		end
	elseif conditions.flag == "not" then
		if (conditions.finish == false or conditions.finish == nil) then
			return true
		else
			return false
		end
	else --not conditions.flag
		if conditions.finish == true then
			return true
		elseif conditions.nofinish == 1 then
			return true
		end
	end
end

function tryEvent(self, event, func, ...)
	if event.conditions ~= nil then
		if event.active == nil or event.active == true then
			if self:forEachCondition(event.conditions, func, ...) == true then --状态有变化
				local ret = self:checkConditions(event.conditions)
				if ret == true then   --验证条件集合
					self:doActions(event.actions)   --执行行为列表
					event.repeated = (event.repeated or 0) + 1
					if event.loop ~= 0 and event.repeated >= (event.loop or 1) then
						event.active = false
					else
						self:forEachCondition(event.conditions, self.resetConditionFunc)
					end
				end
			end
		end
	end
end

function tryConditions(self, func, ...)
	if self.is_end then return end
	for _, i in ipairs(self.eventsIndex) do
		self:tryEvent(self.events[i], func, ...)
	end
end

function forEachCondition(self, conditions, func, ...)
   if conditions.flag == "or" or conditions.flag == "and" then
	   local ret = false
	   for _, condition in ipairs(conditions) do
		   ret = ret or self:forEachCondition(condition, func, ...)
	   end
	   return ret
   else
		local ret = func(self, conditions, ...)
		return ret
   end
end


--**************************************************************--
--事件相关
--**************************************************************--
function doActions(self, actions)
	for _, action in ipairs(actions) do
		self:doAction(action)
	end
end

function doAction(self, action)
	--print(string.format("fbid:%d, handle:%d ------do action %d------", self.id, self.handle, action.type))
	if action.delay == nil or action.delay == 0 then
		self:realDoAction(action)
	else
		local time = System.getNowTime() + action.delay
		self.delay_actions[time] = self.delay_actions[time] or {}
		table.insert(self.delay_actions[time], action)
	end
end

-- action处理函数
local actionfunctions = {}
actionfunctions[1] = function(self, action) --玩家胜利事件
	self:win()
end
actionfunctions[2] = function(self, action) --玩家失败事件
	self:lose()
end

actionfunctions[3] = function(self, action)
end

actionfunctions[4] = function(self, action)
	--todo 发消息告诉客户端进入哪个屏
	local sceneidx = action.scene or 1
	local sceneHdl = self.scene_list[sceneidx]
	if sceneHdl == nil then return end
	section.SetSectionPass(sceneHdl, action.id - 1)
	print("===========set sect pass: scene:"..tostring(sceneidx).." sect:"..tostring(action.id).."============")
end
actionfunctions[5] = function(self, action) --发送副本内容（已不用）
	--insdisplay.setDisplay(self, action)
end
actionfunctions[6] = function(self, action) --时间触发事件
	self.custem_timer[action.id] = System.getNowTime() + (action.time or 0)
	print("===========fb action 6: set timer id: param:"..tostring(action.id).." time:"..tostring(action.time).."============")
end
actionfunctions[7] = function(self, action)
	if action.id == nil then return end

	self.custem_timer[action.id] = nil
	print("===========fb action 7: delete timer id:"..tostring(action.id).."============")
end

actionfunctions[8] = function(self, action) --副本清空怪事件
	local sceneidx = action.scene or 1
	local sceneHdl = self.scene_list[sceneidx]
	if sceneHdl == nil then return end
	if action.kill == true then
		Fuben.killAllMonster(sceneHdl)
	else
		Fuben.clearAllMonster(sceneHdl)--, action.id or 0)
	end
	self.monster_cnt = 0 --因为不会触发onMonsterDie事件，所以要在这里置0
end

actionfunctions[9] = function(self, action)
	print("on action 9")
	if action.id == nil then return end
	local event = self.events[action.id]
	if event == nil or event.active == true then return end --这里有待考虑
	event.active = true
	self:initEvent(event)
	print("active event:"..action.id)
end

actionfunctions[11] = function(self, action) --物品掉落事件
	-- if action.drops == nil then return end
	-- local rate = math.random(0, 99)
	-- for _, drop in ipairs(action.drops) do
	-- 	if rate < drop.rate then
	-- 		local sceneidx = action.scene or 1
	-- 		local sceneHdl = self.scene_list[sceneidx]
	-- 		dropsys.createDropById(sceneHdl, drop.id, action.x, action.y)
	-- 	end
	-- end
end

actionfunctions[12] = function(self, action)  --自定义数值变化
	if action.name == nil then return end
	if self[action.name] == nil then self[action.name] = 0 end
	if action.method=="change" then
		self[action.name] = self[action.name] + (action.value or 1)
	elseif action.method == "set" then
		self[action.name] = (action.value or 1)
	else
		self[action.name] = self[action.name] + 1
	end
	self:onChangeCustomVariable(action.name, self[action.name])
end

actionfunctions[13] = function(self, action)
	if action.events == nil then return end
	local r = math.random(0,99)
	for id, rate in pairs(action.events) do
		if r < rate then
			local event = self.events[id]
			if event == nil or event.active == true then return end --这里有待考虑
			event.active = true
			self:initEvent(event)
			print("active event:"..id)
			return
		end
		r = r - rate
	end
end

actionfunctions[14] = function(self, action) --调用自定义函数
	if action.name == nil then
		print("instance action.name is nil")
		return
	end
	insevent.callCustomFunc(self, action.name)
end

function realDoAction(self, action)
	eventfunc = actionfunctions[action.type]
	if eventfunc ~= nil then
		eventfunc(self, action)
	end
end
