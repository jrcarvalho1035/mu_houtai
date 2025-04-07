-- @system  vip

module("vip", package.seeall)


--所需数据一部分在ActorBasicData中
-- svip level
-- vip level

local function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return nil end

	if var.vipData == nil then
		var.vipData = {}
	end
	local vipData = var.vipData
	if not vipData.sviprecord then vipData.sviprecord = 1 end
	if not vipData.gift then vipData.gift = 0 end
	if not vipData.viprecord then vipData.viprecord = 0 end
	if not vipData.dailystatus then vipData.dailystatus = 2147483647 end --每日礼包状态(16个1)
	if not vipData.nowsvip then vipData.nowsvip = 0 end  --记录上一次每日礼包的的svip等级
	return vipData
end

function updateAttr(actor, calc)
	local data = getActorVar(actor)
	local sviprecord = data.sviprecord
	local level = LActor.getSVipLevel(actor)
	local addAttr = {}
	local extraPower = 0
	if level > 0 then
		for k,attr in ipairs(SVipConfig[level].levelAttr) do
			addAttr[attr.type] = (addAttr[attr.type] or 0) + attr.value	
		end
		extraPower = extraPower + SVipConfig[level].levelExtraPower	
	end
	local vip = LActor.getVipLevel(actor)
	if vip > 0 then
		for k,attr in ipairs(VipConfig[vip].levelAttr) do
			addAttr[attr.type] = (addAttr[attr.type] or 0) + attr.value	
		end
	end
	--获取属性
	local attrs = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_VIP)
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

function c2sVipDailyRewards(actor, pack)---------------------------------------------看名字应该是vip的每日奖励，但实际上是svip的每日奖励
	local var = getActorVar(actor)	
	if LActor.getVipLevel(actor) < 0 then return end
	local level = LActor.getSVipLevel(actor)
	if not SVipConfig[var.nowsvip] then return end
	if not actoritem.checkEquipBagSpaceJob(actor, SVipConfig[var.nowsvip].dailyrewards) then return end------检查背包是否可以存放这个物品
	for i=1,#SVipConfig do
		if not (System.bitOPMask(var.dailystatus, i)) then
			var.dailystatus = System.bitOpSetMask(var.dailystatus, i, true) 
			actoritem.addItems(actor, SVipConfig[i].dailyrewards, "svip rewards")
			updateDailyStatus(actor, var.dailystatus)
			return		
		end	
	end		
end

local function onReqSVipRewards(actor, packet)
	local level = LDataPack.readShort(packet)
	local day = LDataPack.readChar(packet)
	if level < 1 then return end
	if SVipConfig[level] == nil then return end

	local data = getActorVar(actor)
	local sviprecord = data.sviprecord
	local rewards = SVipConfig[level].awards
	
	if System.bitOPMask(sviprecord, level) then
		print("onReqRewards had geted")
		return
	end

	if LActor.getSVipLevel(actor) < level then
		return
	end
	if not actoritem.checkEquipBagSpaceJob(actor, rewards) then
		return
	end
	data.sviprecord = System.bitOpSetMask(sviprecord, level , true)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_SVipUpdateRecord)
	if npack == nil then return end

	print("on ReqSVipRewards. sviprecord:"..data.sviprecord)
	LDataPack.writeInt(npack, data.sviprecord)
	LDataPack.flush(npack)
	actoritem.addItemsByJob(actor, rewards, "svip rewards", 0, "svipgift")
	updateAttr(actor, true)
end

function c2sVipRewards(actor, pack)
	local level = LDataPack.readChar(pack)
	if level < 1 then return end
	if VipConfig[level] == nil then return end

	local var = getActorVar(actor)
	local rewards = VipConfig[level].awards
	
	if System.bitOPMask(var.viprecord, level-1) then
		print("onReqRewards had geted")
		return
	end
	if LActor.getVipLevel(actor) < level then
		return
	end
	if not actoritem.checkEquipBagSpaceJob(actor, rewards) then
		return
	end
	var.viprecord = System.bitOpSetMask(var.viprecord, level -1 , true)
	actoritem.addItems(actor, rewards, "vip rewards")
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_VipGetReward)---------------19-6
	if npack == nil then return end

	LDataPack.writeInt(npack, var.viprecord)
	LDataPack.flush(npack)	
	updateAttr(actor, true)
end

function getSVipRecord(actor)
	local data = getActorVar(actor)
	return data.sviprecord
end

local function onRecharge(actor, val)
	local level = LActor.getSVipLevel(actor)
	local oldlevel = level
	local totalCharge = LActor.getRecharge(actor) --充值钻石
	local update = false
	local var = getActorVar(actor)
	local tmp = 0
	var.nowsvip = level
	while true do
		local conf = SVipConfig[level+1]
		if conf == nil then break end
		if totalCharge < conf.needYb then break end
		level = level + 1
		tmp = tmp + 1				
		update = true
	end
	if update then --更新VIP
		LActor.setSVipLevel(actor, level)
		actorevent.onEvent(actor, aeSVipLevel, level, oldlevel)		
		for i=1 ,tmp do 
			var.nowsvip = var.nowsvip + 1
			var.dailystatus = System.bitOpSetMask(var.dailystatus, var.nowsvip, false)
		end
		updateDailyStatus(actor, var.dailystatus)
		updateAttr(actor, true)
		print("setsviplevel actorid:" .. LActor.getActorId(actor) .. " svip:" .. level)
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_SVipUpdateExp)
	if npack == nil then return end
	LDataPack.writeShort(npack, level)
	LDataPack.writeInt(npack, totalCharge)
	LDataPack.flush(npack)

	local vip = LActor.getVipLevel(actor)
	if vip >= #VipConfig then return end
	local change = false
	local count = val
	for i=vip, #VipConfig do
		if count >= VipConfig[i].needYb and VipConfig[i + 1] then
			vip = vip + 1
			LActor.setVipLevel(actor, vip)
			count = count - VipConfig[i].needYb
			change = true
		end
	end
	if change then
		updateAttr(actor, true)
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_VipData)
	if npack == nil then return end
	LDataPack.writeChar(npack, vip)
	LDataPack.writeChar(npack, 1)
	LDataPack.flush(npack)
end

function updateDailyStatus(actor, status)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_VipGetDailyReward)
	local var = getActorVar(actor)
	if npack == nil then return end
	LDataPack.writeInt(npack, var.dailystatus)
	LDataPack.flush(npack)
end

local function onInit(actor)
	updateAttr(actor, false)
end

local function onNewDay(actor, login)
	local var = getActorVar(actor)
	if var.dailystatus == 2147483647 and var.nowsvip > 0 then 
		local level = LActor.getSVipLevel(actor)
		var.dailystatus = System.bitOpSetMask(var.dailystatus, level, false)
	end
	if not login then
	updateDailyStatus(actor, var.dailystatus)
	end
end

function sendSVipInfo(actor)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_SVipInitData)
	if npack == nil then return end

	print("actor svip:"..LActor.getSVipLevel(actor) .. " actorid:" .. LActor.getActorId(actor))
	LDataPack.writeChar(npack, LActor.getSVipLevel(actor))
	LDataPack.writeInt(npack, LActor.getRecharge(actor))
	LDataPack.writeInt(npack, var.sviprecord)
	LDataPack.writeInt(npack, var.gift)
	LDataPack.writeChar(npack, LActor.getVipLevel(actor))
	LDataPack.writeInt(npack, var.viprecord)
	LDataPack.writeInt(npack, var.dailystatus)
	LDataPack.flush(npack)
end

local function onLogin(actor)
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.vip) then return end
	sendSVipInfo(actor)
end

function onCustomChange(actor, custom, oldcustom)
	if LimitConfig[actorexp.LimitTp.vip].custom > oldcustom and LimitConfig[actorexp.LimitTp.vip].custom <= custom then
		sendSVipInfo(actor)
	end
	local vip = LActor.getVipLevel(actor)
	if VipConfig[vip + 1] and VipConfig[vip].needCustom > oldcustom and VipConfig[vip].needCustom <= custom then
		LActor.setVipLevel(actor, vip + 1)
		updateAttr(actor, true)
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_VipData)
		if npack == nil then return end
		LDataPack.writeChar(npack, vip + 1)
		LDataPack.writeChar(npack, 2)
		LDataPack.flush(npack)
	end
end

_G.getSVipRecord = getSVipRecord

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeRecharge, onRecharge)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)

local function init()
    --if System.isBattleSrv() then return end
	actorevent.reg(aeCustomChange, onCustomChange)

	netmsgdispatcher.reg(Protocol.CMD_Vip, Protocol.cVipCmd_SVipReqReward, onReqSVipRewards)-----------请求svip奖励
	netmsgdispatcher.reg(Protocol.CMD_Vip, Protocol.cVipCmd_VipGetReward, c2sVipRewards)---------領取vip礼包
	netmsgdispatcher.reg(Protocol.CMD_Vip, Protocol.cVipCmd_VipGetDailyReward, c2sVipDailyRewards)------领取svip每日奖励
end

table.insert(InitFnTable, init)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.setVip = function (actor, args)
	local vip = tonumber(args[1])
	if not VipConfig[vip] then return false end
	LActor.setVipLevel(actor, vip)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_VipData)
	if npack == nil then return end
	LDataPack.writeChar(npack, vip)
	LDataPack.writeChar(npack, 2)
	LDataPack.flush(npack)
end
