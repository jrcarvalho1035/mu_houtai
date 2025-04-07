-- @version 1.0
-- @author  qianmeng
-- @date    2017-2-6 21:16:29.
-- @system  vip

module("vip", package.seeall)


--所需数据一部分在ActorBasicData中
-- vip level
-- recharge --充值元宝数
-- 增加一个vip奖励领取记录

local zhizhunlevel = 3 --至尊礼包等级，策划要求可领取3次

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return nil end

	if var.vipData == nil then
		var.vipData = {}
	end
	local vipData = var.vipData
	if not vipData.record then vipData.record = 0 end
	if not vipData.gift then vipData.gift = 0 end
	if not vipData.getv3count then vipData.getv3count = 0 end
	if not vipData.v3record then vipData.v3record = 0 end
	return vipData
end

function updateAttr(actor, calc)
	local data = getStaticData(actor)
	local record = data.record
	local level = LActor.getVipLevel(actor)
	if level < 1 then return end

	local addAttr = {}
	local extraPower = 0
	print("updateAttr #VipConfig:" .. #VipConfig)
	for i = 1, #VipConfig do
		repeat
			local config = VipConfig[i]
			if not System.bitOPMask(record, config.idx -1) then break end
			local levelAttr = config.levelAttr
			for j = 1, #levelAttr  do
				local attr = levelAttr[j]	
				addAttr[attr.type] = (addAttr[attr.type] or 0) + attr.value	
			end
			extraPower = extraPower + config.levelExtraPower	
		until(true)
	end

	--获取属性
	local attrs = LActor.getActorSystemAttrs(actor, AttrActorSysId_VIP)
	if attrs == nil then return end
	--清空属性
	attrs:Reset()
	for k, v in pairs(addAttr) do
		attrs:Set(k, v)
	end
	attrs:SetExtraPower(extraPower)
	if calc then
		LActor.reCalcAttr(actor)
	end
end

--已购买礼包数量
function getBuyCount(actor)
	local sum = 0
	local data = getStaticData(actor)
	for k, v in pairs(VipGiftConfig) do
		if System.bitOPMask(data.gift, k) then
			sum = sum + 1
		end
	end
	return sum
end

local function onReqRewards(actor, packet)
	local level = LDataPack.readShort(packet)
	local day = LDataPack.readChar(packet)
	if level < 1 then return end
	if VipConfig[level] == nil then return end

	local data = getStaticData(actor)
	local record = data.record
	local rewards = VipConfig[level].awards
	if level == zhizhunlevel then
		if day > data.getv3count then
			return
		end
		if System.bitOPMask(data.v3record, day-1) then
			return
		end		
		rewards = Vip3GiftConfig[zhizhunlevel][day].awards
		if not rewards then
			return
		end
	else
		if System.bitOPMask(record, level-1) then
			print("onReqRewards had geted")
			return
		end
	end

	if LActor.getVipLevel(actor) < level then
		return
	end
	if not actoritem.checkEquipBagSpaceJob(actor, rewards) then
		return
	end

	if level == zhizhunlevel then 
		data.v3record = System.bitOpSetMask(data.v3record, day -1 , true)
		if day == 1 then
			data.record = System.bitOpSetMask(record, level -1 , true)
		end
	else
		data.record = System.bitOpSetMask(record, level -1 , true)
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_UpdateRecord)
	if npack == nil then return end

	print("on ReqVipRewards. record:"..data.record)
	LDataPack.writeInt(npack, data.record)
	LDataPack.writeInt(npack, data.v3record)
	LDataPack.flush(npack)
	actoritem.addItemsByJob(actor, rewards, "vip rewards", 0, "vipgift")
	updateAttr(actor, true)
end

--请求购买VIP礼包
local function onBuyGift(actor, packet)
	local id = LDataPack.readByte(packet)
	--获取配置
	local cfg = VipGiftConfig[id]
	if not cfg then
		print(LActor.getActorId(actor).." actorvip.onBuyGift not cfg id:"..id)
		return
	end
	local data = getStaticData(actor)
	--判断是否已经购买
	if System.bitOPMask(data.gift, id) then
		print(LActor.getActorId(actor).." actorvip.onBuyGift gift is buy id:"..id)
		return
	end
	--判断VIP等级
	if cfg.vipLv > LActor.getVipLevel(actor) then
		print(LActor.getActorId(actor).." actorvip.onBuyGift vip lv limit id:"..id..",needLv:"..cfg.vipLv..",curLv:"..LActor.getVipLevel(actor))
		return
	end
	--判断钱是否足够
	if not actoritem.checkItem(actor, NumericType_YuanBao, cfg.needYb) then
		print(LActor.getActorId(actor).." actorvip.onBuyGift yuanbao not enough id:"..id)
		return
	end

	--判断前置的条件是否都已经购买
	if cfg.cond then
		for _,nid in ipairs(cfg.cond) do
			if not System.bitOPMask(data.gift, nid) then
				print(LActor.getActorId(actor).." actorvip.onBuyGift cond not enough id:"..id..",nid:"..nid)
				return
			end
		end
	end
	--判断背包是否能放得下
	if not actoritem.checkEquipBagSpace(actor, cfg.awards) then
		print(LActor.getActorId(actor).." actorvip.onBuyGift not canGiveAwards id:"..id)
		return
	end
	--扣钱
	actoritem.reduceItem(actor, NumericType_YuanBao, cfg.needYb, "buy vip gift:"..id)
	
	--发礼包奖励
	actoritem.addItemsByJob(actor, cfg.awards, "buy vip gift", 0, "buy vip gift")

	--设置已经购买
	data.gift = System.bitOpSetMask(data.gift, id, true)
	--返回消息给客户端
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_GiftInfo)
    if npack == nil then return end
    LDataPack.writeInt(npack, data.gift)
    LDataPack.flush(npack)
    actorevent.onEvent(actor, aeBuyVipGift)
end

function getVipRecord(actor)
	local data = getStaticData(actor)
	return data.record
end

local function onRecharge(actor, val)
	local level = LActor.getVipLevel(actor)
	local totalCharge = LActor.getRecharge(actor) --充值钻石
	local update = false
	while true do
		local conf = VipConfig[level+1]
		if conf == nil then break end
		if totalCharge < conf.needYb then break end
		level = level + 1
		update = true
	end
	if update then --更新VIP
		LActor.setVipLevel(actor, level)
		actorevent.onEvent(actor, aeVipLevel, level)
		print("setviplevel actorid:" .. LActor.getActorId(actor) .. " vip:" .. level)
		if level >= zhizhunlevel then
			local data = getStaticData(actor)
			if data.getv3count == 0 then
				data.getv3count = 1
			end
		end
		sendVipInfo(actor)
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_UpdateExp)
	if npack == nil then return end
	LDataPack.writeShort(npack, level)
	LDataPack.writeInt(npack, totalCharge)
	LDataPack.flush(npack)
end

local function onInit(actor)
	updateAttr(actor, false)
end

local function onNewDay(actor, login)
	local var = getStaticData(actor)
	if var.getv3count < 3 and LActor.getVipLevel(actor) >= zhizhunlevel then
		var.getv3count = var.getv3count + 1
		sendVipInfo(actor)
	end
end

function sendVipInfo(actor)
	local data = getStaticData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_InitData)
	if npack == nil then return end

	print("actor vip:"..LActor.getVipLevel(actor) .. " actorid:" .. LActor.getActorId(actor))
	LDataPack.writeShort(npack, LActor.getVipLevel(actor))
	LDataPack.writeInt(npack, LActor.getRecharge(actor))
	LDataPack.writeInt(npack, data.record)
	LDataPack.writeInt(npack, data.gift)
	LDataPack.writeInt(npack, data.v3record)
	LDataPack.writeChar(npack, data.getv3count)
	LDataPack.flush(npack)
end

local function onLogin(actor)
	sendVipInfo(actor)
end

_G.getVipRecord = getVipRecord

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeRecharge, onRecharge)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_Vip, Protocol.cVipCmd_ReqReward, onReqRewards)
netmsgdispatcher.reg(Protocol.CMD_Vip, Protocol.cVipCmd_BuyGift, onBuyGift)


--测试充值命令
function gmTestRecharge(actor, yb)
	LActor.addRecharge(actor, yb)
end

