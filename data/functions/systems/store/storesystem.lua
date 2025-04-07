module("storesystem", package.seeall)

local featsDayLimit = 1
local featsNoLimit = 2

--商店的数据分了两部分，一部分是刷新次数，在lua存
--另一部分是神秘商店的商品数据，在C++存
function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then
		return
	end

	if (var.store == nil) then
		var.store = {}
	end

	local store = var.store

	if store.refreshCount == nil then
		store.refreshCount = 0
	end

	if store.refresh_start_time == nil then
		store.refresh_start_time = os.time()
	end

	if store.refresh_week_time == nil then --每周刷新购买次数
		store.refresh_week_time = System.getNowTime()
	end

	if store.dayCount == nil then
		store.dayCount = 0
	end

	if store.refresh_cd == nil then
		store.refresh_cd = 0
	end

	if store.featsExchange == nil then
		store.featsExchange = {}
	end

	if store.honorExchange == nil then
		store.honorExchange = {}
	end

	if store.campExchange == nil then
		store.campExchange = {}
	end

	if store.itemHaveBuy == nil then
		store.itemHaveBuy = {}
	end

	if store.renownHaveBuy == nil then
		store.renownHaveBuy = {}
	end

	if not store.limitHaveBuy then
		store.limitHaveBuy = {}
	end

	if not store.SVipHaveBuy then
		store.SVipHaveBuy = {}
	end

	if not store.BossHaveBuy then
		store.BossHaveBuy = {}
	end

	if not store.StarHaveBuy then
		store.StarHaveBuy = {}
	end

	if not store.CrownHaveBuy then
		store.CrownHaveBuy = {}
	end

	if not store.DartHaveBuy then
		store.DartHaveBuy = {}
	end

	if not store.YongzheHaveBuy then
		store.YongzheHaveBuy = {}
	end

	if not store.HFCupHaveBuy then
		store.HFCupHaveBuy = {}
	end

	if not store.ZhanQuHaveBuy then
		store.ZhanQuHaveBuy = {}
	end

	return store
end

--荣誉商店购买
function buyHonorItem(actor, index, count)
	local conf = StoreHonor[index]
	if count <= 0 then return false end
	if not conf then return false end
	local var = getActorVar(actor)
	if conf.daycount.count ~= 0 and (var.honorExchange[index] or 0)+count > conf.daycount.count then
		return false
	end
	local price = conf.honor * count
	if not actoritem.checkItem(actor, NumericType_Honor, price) then
		return false
	end
	actoritem.reduceItem(actor, NumericType_Honor, price, "store buy honor item")

	var.honorExchange[index] = (var.honorExchange[index] or 0) + count
	actoritem.addItem(actor, conf.id, conf.count*count, "store buy honor item")
	utils.logCounter(actor, "store honor", -price, conf.id)
	actorevent.onEvent(actor, aeBuyStoreItem, conf.id)
	return true
end

function buyItem(actor, id, count)
	for k,v in ipairs(StoreItemConfig) do
		if v.itemId == id then
			if not actoritem.checkItem(actor, v.needItemId, count * v.price) then
				return false
			end

			actoritem.reduceItem(actor, v.needItemId, count * v.price, "itemstore buy")
			return true
		end
	end
	return false
end

--道具商店购买
function handleBuyItem(actor, pack)
	local goodsList = {}
	local num = LDataPack.readInt(pack)
	for i=1,num do
		local goodsId = LDataPack.readInt(pack)
		local count = LDataPack.readInt(pack)
		if count <= 0 or goodsId <= 0 or goodsId > #StoreItemConfig then
			log_print("handleBuyItem:goodsId or count error:actorid:%d, goodsId:%d, count:%d",
					LActor.getActorId(actor), goodsId, count)
			return
		end
		table.insert(goodsList, {goodsId = goodsId, count = count})
	end

	local var = getActorVar(actor)
	local ret = 1
	repeat
		local yuanBao = 0
		local itemList = {}
		local needList = {}
		--遍历一下，看有没有非法数据，顺便把总的价钱算一下
		for _,tb in pairs(goodsList) do
			local config = StoreItemConfig[tb.goodsId]
			if (not config) then
				ret = 0
				break
			end
			if config.canbuycount ~= 0 and (var.itemHaveBuy[config.itemId] or 0) >= config.canbuycount then
				ret = 0
				break
			end

			table.insert(itemList, {itemId = config.itemId, count = tb.count * config.count})
			needList[config.needItemId] = (needList[config.needItemId] or 0) + tb.count*config.price
		end

		for id, count in pairs(needList) do
			if not actoritem.checkItem(actor, id, count) then
				ret = 0
				break
			end
		end

		if ret == 0 then
			break
		end

		--先扣钱
		for id, count in pairs(needList) do
			actoritem.reduceItem(actor, id, count, "item store buy")
			if id == NumericType_YuanBao then
				actorevent.onEvent(actor, aeStoreCost, id, count)
			end
		end

		--再发货
		for _,tb in pairs(itemList) do
			actoritem.addItem(actor, tb.itemId, tb.count , "item store buy")
		end
		for _,tb in pairs(goodsList) do
			local config = StoreItemConfig[tb.goodsId]
			var.itemHaveBuy[config.itemId] = (var.itemHaveBuy[config.itemId] or 0) + tb.count
		end
	until(true)


	--告诉前端购买成功
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_BuyItem)
	if pack == nil then return end
	LDataPack.writeByte(pack, ret)
	LDataPack.flush(pack)
	sendItemHaveBuy(actor)
end

--积分商店购买
function handleBuyRenownItem(actor,pack)
	local index = LDataPack.readInt(pack)
	local count = LDataPack.readInt(pack)
	if count <= 0 then return end
	local ret = false--buyRenownItem(actor, index, count)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_BuyIntegralItem)
	if npack == nil then return end
	LDataPack.writeByte(npack,ret and 1 or 0)
	LDataPack.writeInt(npack,index)
	LDataPack.flush(npack)
end

function handleFeatsInfo(actor, packet)
	local var = getActorVar(actor)
	print("=============")
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_FeatsInfo)
	if not pack then return end

	local n = 0
	local featsExchange = var.featsExchange
	for i = 1, 100 do
		if featsExchange[i] then
			n = n + 1
		end
	end
	print("featsExchange:"..n)
	LDataPack.writeInt(pack, n)
	for i = 1, 100 do
		if featsExchange[i] then
			LDataPack.writeInt(pack, i)
			LDataPack.writeInt(pack, featsExchange[i])
		end
	end

	LDataPack.flush(pack)
end

function handleFeatsExchange(actor, packet)
	local index = LDataPack.readInt(packet)

	local conf = StoreFeats[index]
	if not conf then
		print("handleFeatsExchange no conf")
		return
	end

	if not actoritem.checkItem(actor, NumericType_Feats, conf.feats) then
		print("handleFeatsExchange feats less")
		return
	end

	local var = getActorVar(actor)

	local featstype = (conf.daycount == nil or conf.daycount == 0) and featsNoLimit or featsDayLimit
	if featstype == featsDayLimit then
		local count = var.featsExchange[index] or 0
		if count >= conf.daycount then
			print("handleFeatsExchange count use over")
			return
		end
	elseif featstype == featsNoLimit then
	end

	local awardType, itemId, itemNum = conf.type, conf.id, conf.count
	local rewards = { { id=itemId, count=itemNum, type=awardType } }
	if not actoritem.checkEquipBagSpaceJob(actor, rewards) then
		print("handleFeatsExchange bag not enough")
		return
	end

	actoritem.reduceItem(actor, NumericType_Feats, conf.feats, "handleFeatsExchange:"..itemId..";"..itemNum)

	actoritem.addItems(actor, rewards, "handleFeatsExchange")

	if featstype == featsDayLimit then
		var.featsExchange[index] = (var.featsExchange[index] or 0) + 1
		-- LActor.log(actor,"storesystem.handleFeatsExchange","featsExchange",index,var.featsExchange[index])
	elseif featstype == featsNoLimit then
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_FeatsExchange)
	if not pack then return end
	LDataPack.writeInt(pack, index)
	LDataPack.writeInt(pack, var.featsExchange[index] or 0)
	LDataPack.flush(pack)
end

--荣誉商店信息
function handleHonorInfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_HonorInfo)
	if not pack then return end
	LDataPack.writeInt(pack, #StoreHonor)
	for k, v in ipairs(StoreHonor) do
		LDataPack.writeInt(pack, k)
		LDataPack.writeInt(pack, var.honorExchange[k] or 0)
	end
	LDataPack.flush(pack)
end

function handleCampnfo(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_CampStoreInfo)
	if not pack then return end
	LDataPack.writeInt(pack, #StoreCamp)
	for k, v in ipairs(StoreCamp) do
		LDataPack.writeInt(pack, k)
		LDataPack.writeInt(pack, var.campExchange[k] or 0)
	end
	LDataPack.flush(pack)
end


--荣誉商店购买
function handleBuyHonorItem(actor, packet)
	local index = LDataPack.readInt(packet)
	local count = LDataPack.readInt(packet)
	if count <= 0 then return end
	local ret = buyHonorItem(actor, index, count)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_BuyHonorItem)
	if npack == nil then return end
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, index)
	LDataPack.writeInt(npack, var.honorExchange[index] or 0)
	LDataPack.flush(npack)
end

--神魔商店购买
function buyCampItem(actor, index, count)
	local conf = StoreCamp[index]
	if count <= 0 then return false end
	if not conf then return false end
	local var = getActorVar(actor)
	if conf.daycount.count ~= 0 and (var.campExchange[index] or 0)+count > conf.daycount.count then
		return false
	end
	local price = conf.camp * count
	if not actoritem.checkItem(actor, NumericType_ContributionCamp, price) then
		return false
	end
	actoritem.reduceItem(actor, NumericType_ContributionCamp, price, "store buy camp item")

	var.campExchange[index] = (var.campExchange[index] or 0) + count
	actoritem.addItem(actor, conf.id, conf.count*count, "store buy camp item")
	utils.logCounter(actor, "store camp", -price, conf.id)
	actorevent.onEvent(actor, aeBuyStoreItem, conf.id)
	return true
end

function c2sCampBuy(actor, packet)
	local index = LDataPack.readInt(packet)
	local count = LDataPack.readInt(packet)
	if count <= 0 then return end
	local ret = buyCampItem(actor, index, count)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_CampStoreBuy)
	if npack == nil then return end
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, index)
	LDataPack.writeInt(npack, var.campExchange[index] or 0)
	LDataPack.flush(npack)
end

--巅峰商店购买
function buyHFCupItem(actor, index, count)
	if count <= 0 then return false end
	local conf = StoreHFCup[index]
	if not conf then return false end
	local var = getActorVar(actor)
	if conf.daycount.count ~= 0 and (var.HFCupHaveBuy[index] or 0)+count > conf.daycount.count then
		return false
	end
	local price = conf.needCount * count
	if not actoritem.checkItem(actor, NumericType_HFCupScore, price) then
		return false
	end
	actoritem.reduceItem(actor, NumericType_HFCupScore, price, "store buy hfcup item")

	var.HFCupHaveBuy[index] = (var.HFCupHaveBuy[index] or 0) + count
	actoritem.addItem(actor, conf.id, conf.count*count, "store buy hfcup item")
	utils.logCounter(actor, "store hfcup", -price, conf.id)
	actorevent.onEvent(actor, aeBuyStoreItem, conf.id)
	return true
end

--战区商店购买
function buyZhanQuItem(actor, index, count)
	if count <= 0 then return false end
	local conf = StoreZhanQu[index]
	if not conf then return false end
	local var = getActorVar(actor)
	if conf.daycount.count ~= 0 and (var.ZhanQuHaveBuy[index] or 0)+count > conf.daycount.count then
		return false
	end
	local price = conf.needCount * count
	if not actoritem.checkItem(actor, NumericType_ZhanQuBi, price) then
		return false
	end
	actoritem.reduceItem(actor, NumericType_ZhanQuBi, price, "store buy zhanqu item")

	var.ZhanQuHaveBuy[index] = (var.ZhanQuHaveBuy[index] or 0) + count
	actoritem.addItem(actor, conf.id, conf.count*count, "store buy zhanqu item")
	utils.logCounter(actor, "store zhanqu", -price, conf.id)
	actorevent.onEvent(actor, aeBuyStoreItem, conf.id)
	return true
end

local function c2sHFCupBuy(actor, packet)
	local index = LDataPack.readInt(packet)
	local count = LDataPack.readInt(packet)
	if count <= 0 then return end
	local ret = buyHFCupItem(actor, index, count)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_HFCupStoreBuy)
	if npack == nil then return end
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, index)
	LDataPack.writeInt(npack, var.HFCupHaveBuy[index] or 0)
	LDataPack.flush(npack)
end

local function c2sZhanQuBuy(actor, packet)
	local index = LDataPack.readInt(packet)
	local count = LDataPack.readInt(packet)
	if count <= 0 then return end
	local ret = buyZhanQuItem(actor, index, count)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_ZhanQuStoreBuy)
	if npack == nil then return end
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, index)
	LDataPack.writeInt(npack, var.ZhanQuHaveBuy[index] or 0)
	LDataPack.flush(npack)
end

function s2cStoreInfo(actor)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_SVipStoreInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, #SvipStoreConfig)
	for k in ipairs(SvipStoreConfig) do
		LDataPack.writeShort(npack, var.SVipHaveBuy[k] or 0)
	end
	LDataPack.flush(npack)
	npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_LimitStoreInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, #LimitStoreConfig)
	for k in ipairs(LimitStoreConfig) do
		LDataPack.writeShort(npack, var.limitHaveBuy[k] or 0)
	end
	LDataPack.flush(npack)
	npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_BossStoreInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, #BossStoreConfig)
	for k in ipairs(BossStoreConfig) do
		LDataPack.writeShort(npack, var.BossHaveBuy[k] or 0)
	end
	LDataPack.flush(npack)
	npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_StarStoreInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, #StarStoreConfig)
	for k in ipairs(StarStoreConfig) do
		LDataPack.writeShort(npack, var.StarHaveBuy[k] or 0)
	end
	LDataPack.flush(npack)
	npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_CrownStoreInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, #CrownStoreConfig)
	for k in ipairs(CrownStoreConfig) do
		LDataPack.writeShort(npack, var.CrownHaveBuy[k] or 0)
	end
	LDataPack.flush(npack)

	npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_DartStoreInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, #DartStoreConfig)
	for k in ipairs(DartStoreConfig) do
		LDataPack.writeShort(npack, var.DartHaveBuy[k] or 0)
	end
	LDataPack.flush(npack)

	npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_YongzheStoreInfo)
	if npack == nil then return end
	for storetype, conf in pairs(YongzheStoreConfig) do
		LDataPack.writeChar(npack, storetype)
		LDataPack.writeShort(npack, #conf)
		if not var.YongzheHaveBuy[storetype] then var.YongzheHaveBuy[storetype] = {} end
		for index in ipairs(conf) do
			LDataPack.writeInt(npack, var.YongzheHaveBuy[storetype][index] or 0)
		end
	end
	LDataPack.flush(npack)

	npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_HFCupStoreInfo)
	if npack == nil then return end
	LDataPack.writeInt(npack, #StoreHFCup)
	for index, conf in ipairs(StoreHFCup) do
		LDataPack.writeInt(npack, index)
		LDataPack.writeInt(npack, var.HFCupHaveBuy[index] or 0)
	end
	LDataPack.flush(npack)

	npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_ZhanQuStoreInfo)
	if npack == nil then return end
	LDataPack.writeInt(npack, #StoreZhanQu)
	for index, conf in ipairs(StoreZhanQu) do
		LDataPack.writeInt(npack, index)
		LDataPack.writeInt(npack, var.ZhanQuHaveBuy[index] or 0)
	end
	LDataPack.flush(npack)
end

function onLogin(actor, firstLogin)
	local var = getActorVar(actor)
	local svar = System.getStaticVar()
	if svar.store ~= nil then
		if svar.store[LActor.getActorId(actor)] ~= nil then
			actoritem.addItem(actor, NumericType_Integral, svar.store[LActor.getActorId(actor)], "store gm add")
			print("store gm add interal " .. svar.store[LActor.getActorId(actor)])
			svar.store[LActor.getActorId(actor)] = nil
		end
	end

	sendItemHaveBuy(actor)
	s2cStoreInfo(actor)
	handleHonorInfo(actor)
	handleCampnfo(actor)
end

function sendItemHaveBuy(actor)
	local var = getActorVar(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_ItemHaveBuy)
	local cnt = 0
	local pos = LDataPack.getPosition(pack)
	LDataPack.writeShort(pack, cnt)
	for k,v in ipairs(StoreItemConfig) do
		if v.canbuycount ~= 0 then
			LDataPack.writeInt(pack, v.itemId)
			LDataPack.writeShort(pack, var.itemHaveBuy[v.itemId] or 0)
			cnt = cnt + 1
		end
	end
	local npos = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos)
	LDataPack.writeByte(pack, cnt)
	LDataPack.setPosition(pack, npos)
	LDataPack.flush(pack)
end

function onNewDay(actor, login)
	local var = getActorVar(actor)
	if (var ~= nil) then
		var.refreshCount = 0
		var.dayCount = 0
		var.featsExchange = {}
	end

	local now = System.getNowTime()
	local isSameWeek = System.isSameWeek(now, var.refresh_week_time)
	for k,v in ipairs(LimitStoreConfig) do
		if v.daycount.type == 1 then
			var.limitHaveBuy[k] = 0
		else
			if not isSameWeek then
				var.limitHaveBuy[k] = 0
			end
		end
	end
	for k,v in ipairs(SvipStoreConfig) do
		if v.daycount.type == 1 then
			var.SVipHaveBuy[k] = 0
		else
			if not isSameWeek then
				var.SVipHaveBuy[k] = 0
			end
		end
	end
	for k,v in ipairs(BossStoreConfig) do
		if v.daycount.type == 1 then
			var.BossHaveBuy[k] = 0
		end
	end

	for k,v in ipairs(StoreHonor) do
		if v.daycount.type == 1 then
			var.honorExchange[k] = 0
		end
	end

	for k,v in ipairs(StoreCamp) do
		if v.daycount.type == 1 then
			var.campExchange[k] = 0
		elseif v.daycount.type == 2 then
			if not isSameWeek then
				var.campExchange[k] = 0
			end
		end
	end

	for k,v in ipairs(StarStoreConfig) do
		if v.daycount.type == 1 then
			var.StarHaveBuy[k] = 0
		else
			if not isSameWeek then
				var.StarHaveBuy[k] = 0
			end
		end
	end
	for k,v in ipairs(CrownStoreConfig) do
		if v.daycount.type == 1 then
			var.CrownHaveBuy[k] = 0
		else
			if not isSameWeek then
				var.CrownHaveBuy[k] = 0
			end
		end
	end

	for k,v in ipairs(DartStoreConfig) do
		if v.daycount.type == 1 then
			var.DartHaveBuy[k] = 0
		else
			if not isSameWeek then
				var.DartHaveBuy[k] = 0
			end
		end
	end

	for storetype, conf in pairs(YongzheStoreConfig) do
		if not var.YongzheHaveBuy[storetype] then
			var.YongzheHaveBuy[storetype] = {}
		end
		for idx, v in ipairs(conf) do
			if v.daycount.type == 1 then
				var.YongzheHaveBuy[storetype][idx] = 0
			elseif v.daycount.type == 2 then
				if not isSameWeek then
					var.YongzheHaveBuy[storetype][idx] = 0
				end
			end
		end
	end

	for k,v in ipairs(StoreHFCup) do
		if v.daycount.type == 1 then
			var.HFCupHaveBuy[k] = 0
		elseif v.daycount.type == 2 then
			if not isSameWeek then
				var.HFCupHaveBuy[k] = 0
			end
		end
	end

	for k,v in ipairs(StoreZhanQu) do
		if v.daycount.type == 1 then
			var.ZhanQuHaveBuy[k] = 0
		elseif v.daycount.type == 2 then
			if not isSameWeek then
				var.ZhanQuHaveBuy[k] = 0
			end
		end
	end

	var.refresh_week_time = now

	if not login then
		s2cStoreInfo(actor)
		handleHonorInfo(actor)
		handleCampnfo(actor)
	end
end


--boss商城购买
function c2sBossBuy(actor, pack)
	local index = LDataPack.readShort(pack)
	local count = LDataPack.readShort(pack)
	if count <= 0 then return end
	local config = BossStoreConfig[index]
	if not config then return end

	local var = getActorVar(actor)
	if config.daycount.count > 0 and (var.BossHaveBuy[index] or 0) >= config.daycount.count then
		return
	end
	if not actoritem.checkItem(actor, config.needitem, count * config.needcount) then
		return false
	end
	var.BossHaveBuy[index] = (var.BossHaveBuy[index] or 0) + count
	actoritem.reduceItem(actor, config.needitem, count * config.needcount, "bossstore buy")
	actoritem.addItem(actor, config.id, count * config.count, "bossstore buy")

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_BossStoreBuy)
	LDataPack.writeShort(npack, index)
	LDataPack.writeShort(npack, var.BossHaveBuy[index] or 0)
    LDataPack.flush(npack)
end

--星石宝库购买
function c2sStarBuy(actor, pack)
	local index = LDataPack.readShort(pack)
	local count = LDataPack.readShort(pack)
	if count <= 0 then return end
	local config = StarStoreConfig[index]
	if not config then return end

	local var = getActorVar(actor)
	if config.daycount.count > 0 and (var.StarHaveBuy[index] or 0) >= config.daycount.count then
		return
	end
	if not actoritem.checkItem(actor, config.needitem, count * config.needcount) then
		return false
	end
	var.StarHaveBuy[index] = (var.StarHaveBuy[index] or 0) + count
	actoritem.reduceItem(actor, config.needitem, count * config.needcount, "bossstore buy")
	actoritem.addItem(actor, config.id, count * config.count, "bossstore buy")

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_StarStoreBuy)
	LDataPack.writeShort(npack, index)
	LDataPack.writeShort(npack, var.StarHaveBuy[index] or 0)
    LDataPack.flush(npack)
end

--运镖商店购买
function c2sDartBuy(actor, pack)
	local index = LDataPack.readShort(pack)
	local count = LDataPack.readShort(pack)
	if count <= 0 then return end
	local config = DartStoreConfig[index]
	if not config then return end

	local var = getActorVar(actor)
	if config.daycount.count > 0 and (var.DartHaveBuy[index] or 0) >= config.daycount.count then
		return
	end
	if LActor.getFootEquipBagSpace(actor) < count * config.count then
		-- 背包装不下了
		return false
	end
	if not actoritem.checkItem(actor, config.needitem, count * config.needcount) then
		return false
	end
	var.DartHaveBuy[index] = (var.DartHaveBuy[index] or 0) + count
	actoritem.reduceItem(actor, config.needitem, count * config.needcount, "bossstore buy")
	actoritem.addItem(actor, config.id, count * config.count, "bossstore buy")

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_DartStoreBuy)
	LDataPack.writeShort(npack, index)
	LDataPack.writeShort(npack, var.DartHaveBuy[index] or 0)
    LDataPack.flush(npack)
end

--皇冠宝库购买
function c2sCrownBuy(actor, pack)
	local index = LDataPack.readShort(pack)
	local count = LDataPack.readShort(pack)
	if count <= 0 then return end
	local config = CrownStoreConfig[index]
	if not config then return end

	local var = getActorVar(actor)
	if config.daycount.count > 0 and (var.CrownHaveBuy[index] or 0) >= config.daycount.count then
		return
	end
	if not actoritem.checkItem(actor, config.needitem, count * config.needcount) then
		return false
	end
	var.CrownHaveBuy[index] = (var.CrownHaveBuy[index] or 0) + count
	actoritem.reduceItem(actor, config.needitem, count * config.needcount, "bossstore buy")
	actoritem.addItem(actor, config.id, count * config.count, "bossstore buy")

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_CrownStoreBuy)
	LDataPack.writeShort(npack, index)
	LDataPack.writeShort(npack, var.CrownHaveBuy[index] or 0)
    LDataPack.flush(npack)
end

--svip商城购买
function c2sSVipBuy(actor, pack)
	local index = LDataPack.readShort(pack)
	local buycount = LDataPack.readShort(pack)
	if buycount <= 0 then return end
	local config = SvipStoreConfig[index]
	if not config then return end

	local var = getActorVar(actor)
	if LActor.getSVipLevel(actor) < config.svip then return end
	if (var.SVipHaveBuy[index] or 0) + buycount > config.daycount.count then return end
	if not actoritem.checkItem(actor, NumericType_YuanBao, config.yuanbao * buycount) then
		return false
	end
	var.SVipHaveBuy[index] = (var.SVipHaveBuy[index] or 0) + buycount
	actoritem.reduceItem(actor, NumericType_YuanBao, config.yuanbao * buycount, "svipstore buy")
	actoritem.addItem(actor, config.id, config.count * buycount, "svipstore buy")

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_SVipStoreBuy)
	LDataPack.writeShort(npack, index)
    LDataPack.writeShort(npack, var.SVipHaveBuy[index])
    LDataPack.flush(npack)
end

--限购特惠购买
function c2sLimitBuy(actor, pack)
	local index = LDataPack.readShort(pack)
	local config = LimitStoreConfig[index]
	if not config then return end

	local var = getActorVar(actor)
	if (var.limitHaveBuy[index] or 0) >= config.daycount.count then return end
	if not actoritem.checkItem(actor, NumericType_YuanBao, config.yuanbao) then
		return false
	end
	var.limitHaveBuy[index] = (var.limitHaveBuy[index] or 0) + 1
	actoritem.reduceItem(actor, NumericType_YuanBao, config.yuanbao, "limitstore buy")
	actoritem.addItem(actor, config.id, config.count, "limitstore buy")

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_LimitStoreBuy)
    LDataPack.writeShort(npack, index)
	LDataPack.writeShort(npack, var.limitHaveBuy[index])
    LDataPack.flush(npack)
end

function c2sYongzheBuy(actor, pack)
	local storetype = LDataPack.readChar(pack)
	local index = LDataPack.readShort(pack)
	local num = LDataPack.readInt(pack)
	if num <= 0 then return end
	if not YongzheStoreConfig[storetype] then return end

	local config = YongzheStoreConfig[storetype][index]
	if not config then return end

	local custom = yongzhefuben.getYongzheFloor(actor)
	if custom < config.needcustom then return end

	local var = getActorVar(actor)
	if not var then return end
	if not var.YongzheHaveBuy[storetype] then var.YongzheHaveBuy[storetype] = {} end
	var = var.YongzheHaveBuy[storetype]
	if (var[index] or 0) >= config.daycount.count then return end
	if not actoritem.checkItem(actor, config.needitem, config.needcount * num) then return end
	var[index] = (var[index] or 0) + num
	actoritem.reduceItem(actor, config.needitem, config.needcount * num, "yongzhestore buy")
	actoritem.addItem(actor, config.id, config.count * num, "yongzhestore buy")

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_YongzheStoreBuy)
    if not npack then return end
	LDataPack.writeChar(npack, storetype)
    LDataPack.writeShort(npack, index)
	LDataPack.writeInt(npack, var[index])
    LDataPack.flush(npack)
end

local function fuBenInit()
    --if System.isBattleSrv() then return end
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)

	if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_BuyItem, handleBuyItem) --(61,2)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_BuyRenownItem, handleBuyRenownItem) --(61,5)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_FeatsInfo, handleFeatsInfo) --(61,6)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_FeatsExchange, handleFeatsExchange) --(61,7)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_BuyHonorItem, handleBuyHonorItem) --(61,11)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_BossStoreBuy,  c2sBossBuy)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_SVipStoreBuy, c2sSVipBuy)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_LimitStoreBuy, c2sLimitBuy)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_StarStoreBuy,  c2sStarBuy)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_CrownStoreBuy,  c2sCrownBuy)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_DartStoreBuy,  c2sDartBuy)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_YongzheStoreBuy,  c2sYongzheBuy)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_CampStoreBuy, c2sCampBuy)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_HFCupStoreBuy, c2sHFCupBuy)
	netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_ZhanQuStoreBuy, c2sZhanQuBuy)
end

table.insert(InitFnTable, fuBenInit)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.yongzheBuy = function (actor, args)
    local storetype = tonumber(args[1]) or 1
    local index = tonumber(args[2]) or 1
    local num = tonumber(args[3]) or 1
    local pack = LDataPack.allocPacket()
    LDataPack.writeChar(pack, storetype)
    LDataPack.writeShort(pack, index)
    LDataPack.writeInt(pack, num)
    LDataPack.setPosition(pack, 0)
    c2sYongzheBuy(actor, pack)
	return true
end

gmCmdHandlers.hfcupBuy = function (actor, args)
    local index = tonumber(args[1]) or 1
    local num = tonumber(args[2]) or 1
    local pack = LDataPack.allocPacket()
    LDataPack.writeInt(pack, index)
    LDataPack.writeInt(pack, num)
    LDataPack.setPosition(pack, 0)
    c2sHFCupBuy(actor, pack)
	return true
end
