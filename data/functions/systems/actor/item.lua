-- @version	1.0
-- @author	qianmeng
-- @date	2017-1-24 17:49:02.
-- @system	append

module("item", package.seeall)

require("item.hechengdata")

use_item_error_code =
{
	not_error          = 0,
	use_succeed        = 0, -- 使用成功
	bag_full           = 1, -- 背包满了
	use_succeed_notips = 2, -- 使用成功，不弹tips
	not_use            = 3, -- 不能被使用
	insufficient_level = 4, -- 级别不足
	lazy_weight        = 5, -- 数量不足够
	yuanbao_less       = 6, -- 元宝不足
	not_guild    	   = 7, -- 未加入战盟
	excel_error    	   = 8, -- 配置错误
	shenmo_actived	   = 9,	--神魔已激活
	wrong_fuben		   = 10, --不在正确的副本中
	element_bag_full   = 11, -- 元素背包已满
	footeq_bag_full    = 12, -- 足迹背包已满
}

function getActorDoubleExpVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.doubleExp then
		var.doubleExp = {}
		var.doubleExp.time = 0 	--开始时间
		var.doubleExp.id = 0	--药品id
	end
	return var.doubleExp
end


--- check func

local function checkDefault(actor,item_id,count)
	local conf = ItemConfig[item_id]
	local needLevel = conf.level
	local level = LActor.getLevel(actor)
	if level < needLevel then
		print(LActor.getActorId(actor) .. "checkDefault: insufficient_leve " .. item_id)
		return use_item_error_code.insufficient_level
	end
	if not actoritem.checkItem(actor, item_id, count) then
		print(LActor.getActorId(actor) .. "checkDefault: lazy_weight " .. item_id )
		return use_item_error_code.lazy_weight
	end
	--print(LActor.getActorId(actor) .. "checkDefault: ok " .. item_id)
	return use_item_error_code.not_error
end

local function checkUseShenmoTemp(actor, item_id, count)
	-- local conf = ItemConfig[item_id]
	-- local ret = checkDefault(actor,item_id,count)
	-- if ret ~= use_item_error_code.not_error then
	-- 	return ret
	-- end
	-- local args = conf.useArg
	-- if not ShenmoConfig[args.shenmoid] then
	-- 	return use_item_error_code.excel_error
	-- end

	-- if count ~= 1 then
	-- 	return use_item_error_code.excel_error
	-- end

	-- local shenmoVar = shenmosystem.getVar(actor, shenmosystem.PUTONG_SHENMO, args.shenmoid)
	-- if shenmoVar.level ~= 0 then
	-- 	return use_item_error_code.shenmo_actived
	-- end
	-- local fbid = LActor.getFubenId(actor)
	-- local rightFuben = false
	-- for i=1, #args.fubengroup do
	-- 	if FubenConfig[fbid].group == args.fubengroup[i] then
	-- 		rightFuben = true
	-- 		break
	-- 	end
	-- end
	-- if not rightFuben then
	-- 	return use_item_error_code.wrong_fuben
	-- end
	-- return use_item_error_code.not_error
	return use_item_error_code.not_use
end

local function checkUseCrateDrops(actor,item_id,count)
	local conf = ItemConfig[item_id]
	local ret = checkDefault(actor,item_id,count)
	if ret ~= use_item_error_code.not_error then
		return ret
	end
	local args = conf.useArg
	local useGrid = args.useGrid * count
	if useGrid ~= 0 and args.bagType and args.bagType == BagType_Equip and LActor.getEquipBagSpace(actor) < useGrid then
		print(LActor.getActorId(actor) .. "checkUseCrateDrops: bag_full " .. item_id)
		return use_item_error_code.bag_full
	end
	if useGrid ~= 0 and args.bagType and args.bagType == BagType_Element and LActor.getElementBagSpace(actor) < useGrid then
		print(LActor.getActorId(actor) .. "checkUseCrateDrops: element bag_full " .. item_id)
		return use_item_error_code.element_bag_full
	end

	if useGrid ~= 0 and args.bagType and args.bagType == BagType_FootEquip and LActor.getFootEquipBagSpace(actor) < useGrid then
		print(LActor.getActorId(actor) .. "checkUseCrateDrops: footequip bag_full " .. item_id)
		return use_item_error_code.footeq_bag_full
	end
	if (args.isGuild or 0) ~= 0 then --进入战盟验证
		if LActor.getGuildId(actor) == 0 then --没有加入战盟不能使用
			return use_item_error_code.not_guild
		end
	end
	print(LActor.getActorId(actor), "checkUseCrateDrops: ok ", item_id)
	return use_item_error_code.not_error
end

local function checkEquipBagSpace(actor, items, count)
	local needSpace = 0
	local needElement = 0
	local needFootEq = 0
	local job = LActor.getJob(actor)
	for _, item in ipairs(items) do
		local itemConf = ItemConfig[item.id]
		if itemConf and actoritem.isEquip(itemConf) then
			needSpace = needSpace + 1
		elseif itemConf and actoritem.isElement(itemConf) then
			needElement = needElement + 1
		elseif itemConf and actoritem.isFootEquip(itemConf) then
			needFootEq  = needFootEq + 1
		end
	end
	if LActor.getEquipBagSpace(actor) < needSpace * count then
		return item.use_item_error_code.bag_full
	end

	if LActor.getElementBagSpace(actor) < needElement * count then
		return item.use_item_error_code.element_bag_full
	end

	if  LActor.getFootEquipBagSpace(actor) < needFootEq * count then
		return item.use_item_error_code.footeq_bag_full
	end
	return
end

local function checkUseChooseCrate(actor, item_id, count, chooseindex)
	local conf = ItemConfig[item_id]
	local ret = checkDefault(actor,item_id,count)
	if ret ~= use_item_error_code.not_error then
		return ret
	end
	local args = conf.useArg
	if not args.chooseitem[chooseindex] then
		return use_item_error_code.excel_error
	end
	local ret = checkEquipBagSpace(actor, {args.chooseitem[chooseindex]}, count)
	if ret then
		return ret
	end
	return use_item_error_code.not_error
end


---- use func
local function useDefault(actor,item_id,count)
	actoritem.reduceItem(actor, item_id, count, "useDefault ok :"..item_id)
	return use_item_error_code.use_succeed
end

local function useCrateDrops(actor, item_id, count)
    local ret = useDefault(actor, item_id, count)
    if ret ~= use_item_error_code.use_succeed then
        return ret
    end

    local conf = ItemConfig[item_id]
    local args = conf.useArg
    local logstr = "use item"
    if conf.needyuanbao and conf.needyuanbao > 0 then
        logstr = "use yuanbao item " .. item_id
    end

    local aggregatedRewards = {}
    local items = {}
    local dropGroup = drop.dropGroup  -- Cache da função
    local ElementBaseConfig = ElementBaseConfig  -- Cache da tabela
    local table_insert = table.insert  -- Cache da função

    for i = 1, count do
        local rewards = dropGroup(args.dropId)
        for j = 1, #rewards do
            local v = rewards[j]
            local id = v.id
            local ebConf = ElementBaseConfig[v.id]
            if ebConf then
                id = ebConf.soleid
            end

            -- Acumula os drops por id
            local rewardEntry = aggregatedRewards[id]
            if rewardEntry then
                rewardEntry.count = rewardEntry.count + v.count
            else
                aggregatedRewards[id] = {type = v.type, id = id, count = v.count}
            end

            table_insert(items, v)
        end
    end

    -- Converte os drops agregados para um array
    local aggregatedRewardsArray = {}
    for _, reward in pairs(aggregatedRewards) do
        table_insert(aggregatedRewardsArray, reward)
    end

    -- Envia os itens e notifica
    actoritem.addItemsByMail(actor, aggregatedRewardsArray, logstr, 0, "crate")
    s2cCrateDrops(actor, items)
    return use_item_error_code.use_succeed
end




local function useTitle(actor,item_id,count)
	local ret = useDefault(actor,item_id,count)
	if ret ~= use_item_error_code.use_succeed then
		return ret
	end
	local conf = ItemConfig[item_id]
	local tId = conf.useArg.titleid
	titlesystem.addTitle(actor,tId, true)
	return use_item_error_code.use_succeed
end

local function useShenmoTemp(actor, item_id, count)
	local conf = ItemConfig[item_id]
	if not conf then return use_item_error_code.excel_error end

	if not shenmosystem.useShenmoTemp(actor, item_id, count) then
		return use_item_error_code.excel_error
	end

	local ret = useDefault(actor,item_id,count)
	if ret ~= use_item_error_code.use_succeed then
		return ret
	end

	return use_item_error_code.use_succeed;
end

local function useChooseCrate(actor, item_id, count, chooseindex)
	local conf = ItemConfig[item_id]
	if not conf then return use_item_error_code.excel_error end

	local args = conf.useArg
	local ret = useDefault(actor,item_id,count)
	if ret ~= use_item_error_code.use_succeed then
		return ret
	end
	local items = {{type=AwardType_Item,id=args.chooseitem[chooseindex].id, count=args.chooseitem[chooseindex].count * count}}
	actoritem.addItemsByMail(actor, items, "choose crate get item", 0, "crate")
	-- actoritem.addItem(actor, args.chooseitem[chooseindex].id, args.chooseitem[chooseindex].count, "choose crate get item")

	return use_item_error_code.use_succeed;
end

local function useDoubleExpPill(actor,item_id,count)----使用双倍经验
	local conf = ItemConfig[item_id]
	if not conf then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	local now = System.getNowTime()
	if not var.doubleExp then var.doubleExp = {} end
	local data = var.doubleExp
	local coe = conf.useArg[1]
	local delay = conf.useArg[2]
	if (data.coe or 0) == coe and (data.time or 0)+(data.delay or 0) > now then--使用倍数相同的药，持续时间累加
		delay = data.delay + delay
	end
	if delay > conf.useArg[2] then
		actorlogin.s2cDoubleExpTrailer(actor, math.max(0, data.time + data.delay + conf.useArg[2] - now), coe, item_id)
	else
		actorlogin.s2cDoubleExpTrailer(actor, delay, coe, item_id) --先发双倍经验协议，再发物品消耗协议(客户端要求)
	end

	local ret = useDefault(actor,item_id,count) --扣物品成功后，再设定双倍经验
	if ret ~= use_item_error_code.use_succeed then
		return ret
	end
	if delay > conf.useArg[2] then
		data.delay = data.delay + conf.useArg[2]
	else
		data.id = item_id
		data.coe = coe 	--经验倍数
		data.time = now--双倍经验开始时间
		data.delay = delay	--双倍经验持续时间
	end
	return use_item_error_code.use_succeed;
end

local function useChongzhi(actor, item_id, count) --充值卡
	if System.isBattleSrv() then
		return use_item_error_code.not_use
	end
	local actorid = LActor.getActorId(actor)
	local conf = ItemConfig[item_id]
	if not conf then return end
	local args = conf.useArg
	if not args.yuanbao or args.yuanbao == 0 then return end
	local ret = useDefault(actor,item_id,count)
	local packet = LDataPack.allocPacket()
    LDataPack.writeData(packet, 4, dtString, "chongzhika", dtInt, args.yuanbao, dtInt, args.yuanbao, dtInt, actorid)
    LDataPack.setPosition(packet, ret)
	sdkapi.onFeeCallback(packet)
	return use_item_error_code.use_succeed
end

local function useExpCard(actor, item_id, count)
	local actorid = LActor.getActorId(actor)
	local conf = ItemConfig[item_id]
	if not conf then return end
	local args = conf.useArg
	if not args.exp or args.exp <= 0 then return end
	local ret = useDefault(actor,item_id,count)

	LActor.addExp(actor, (args.exp * count), "use exp card", false, false, 1)

	return use_item_error_code.use_succeed
end

function getExpCoe(actor)
	local var = LActor.getStaticVar(actor)
	if not var then return 0 end
	if not var.doubleExp then return 0 end
	if var.doubleExp.time == 0 then return 0 end
	if var.doubleExp.time + var.doubleExp.delay >= System.getNowTime() then --双倍时间
		return var.doubleExp.coe
	end
	return 0
end

local function checkType20Item(actor,item_id,count)
	local ret = checkDefault(actor,item_id,count)
	if ret ~= use_item_error_code.not_error then
		return ret
	end

	local find = false
	local find_conf
	for id, list in pairs(ActivityType20ExConfig) do
		if not activitymgr.activityTimeIsEnd(id) then
			for _, conf in pairs(list) do
				if conf.item == item_id then
					find = true
					find_conf = conf
					break
				end
			end
		end
	end

	if find then
		if subactivity20.isCvNumMax(find_conf.id) then
			return use_item_error_code.not_use
		end

		if subactivity20.isGvMax(actor, find_conf.id) then
			return use_item_error_code.not_use
		end

		return use_item_error_code.not_error
	else
		return use_item_error_code.not_use
	end
end

local function useType20Item(actor, item_id, count, chooseindex)
	if System.isBattleSrv() then 
		return use_item_error_code.not_use
	end
	local ret = useDefault(actor, item_id, count)
	if ret ~= use_item_error_code.not_error then
		return ret
	end

	local use = false
	for id, list in pairs(ActivityType20ExConfig) do
		if not activitymgr.activityTimeIsEnd(id) then
			for _, conf in pairs(list) do
				if conf.item == item_id then
					subactivity20.useItem(actor, conf, count)
					use = true
					break
				end
			end
		end
	end

	if use then
		return use_item_error_code.use_succeed_notips
	else
		return use_item_error_code.not_use
	end
end

local function useAdventureItem(actor, item_id, count, chooseindex)
	local ret = useDefault(actor, item_id, count)
	if ret ~= use_item_error_code.not_error then
		return ret
	end

	adventure.useItem(actor, count)
	return use_item_error_code.use_succeed
end

local function useAddBuffer(actor, item_id, count, chooseindex)
	local ret = useDefault(actor, item_id, count)
	if ret ~= use_item_error_code.not_error then
		return ret
	end
	local conf = ItemConfig[item_id]
	if not conf then return end
	local args = conf.useArg
	for i=1, #args.buffer do
		actorlogin.addEffect(actor, args.buffer[i])
		--LActor.addSkillEffect(actor, args.buffer[i])
	end
	return use_item_error_code.use_succeed
end

local function useAddDarkTimes(actor, item_id, count)
	local ret = useDefault(actor, item_id, count)
	if ret ~= use_item_error_code.not_error then
		return ret
	end
	local conf = ItemConfig[item_id]
	if not conf then return end
	local num = count * (conf.useArg.count or 1)
	darkcross.addDrakTimes(actor, num)
	return use_item_error_code.use_succeed
end

local function useAddYsfbPoint(actor, item_id, count)
	local ret = useDefault(actor, item_id, count)
	if ret ~= use_item_error_code.not_error then
		return ret
	end
	local conf = ItemConfig[item_id]
	if not conf then return end
	local num = count * (conf.useArg.count or 1)
	yuansufuben.changeYSPoint(actor, num, "useitem")
	return use_item_error_code.use_succeed
end

local function useAddSjfbPoint(actor, item_id, count)
	local ret = useDefault(actor, item_id, count)
	if ret ~= use_item_error_code.not_error then
		return ret
	end
	local conf = ItemConfig[item_id]
	if not conf then return end
	local num = count * (conf.useArg.count or 1)
	shenjifuben.changeSJPoint(actor, num, "useitem")
	return use_item_error_code.use_succeed
end

use_item_func =
{
	[1] = useCrateDrops,
	[2] = useTitle,
	[3] = useCrateDrops,
	[4] = useDoubleExpPill, --双倍经验丹
	--[5] = useFruit, --果实
	[6] = useChongzhi,
	[7] = useExpCard,
	[9] = useShenmoTemp,
	[10] = useChooseCrate,
	-- 11 Cartão de mudança de nome
	[12] = useType20Item, -- 活动类型20的道具
	[13] = useAdventureItem, -- 探秘增加体力道具
	[14] = useAddBuffer,
	[15] = useAddDarkTimes,--暗黑神殿加归属次数
	[16] = useAddYsfbPoint,--元素幻境增加能量
	[17] = useAddSjfbPoint,--神迹秘境增加能量
}
check_use_item_func =
{
	[1] = checkUseCrateDrops, -- 宝箱
	[2] = checkDefault,
	[3] = checkUseCrateDrops,
	[4] = checkDefault,
	--[5] = checkDefault,
	[6] = checkDefault,
	[7] = checkDefault,
	[9] = checkUseShenmoTemp,
	[10] = checkUseChooseCrate,
	-- 11 Cartão de mudança de nome
	[12] = checkType20Item,
	[13] = checkDefault,
	[14] = checkDefault,
	[15] = checkDefault,
	[16] = checkDefault,
	[17] = checkDefault,
}


local function useItem(actor,item_id,count,chooseindex)
	local conf = ItemConfig[item_id]
	if conf == nil then
		return use_item_error_code.not_use
	end
	if count == nil or type(count) ~= "number" or count <= 0 then
		print("use item invalid count:"..tostring(count).." aid:"..LActor.getActorId(actor))
		count = 1
	end
	local check_func = check_use_item_func[conf.useType]

	if check_func == nil then
		print(LActor.getActorId(actor) .. "useItem: not has check func " .. conf.useType .. " " .. item_id)
		return use_item_error_code.not_use
	end
	local ret = check_func(actor,item_id,count,chooseindex)
	if ret ~= use_item_error_code.not_error then
		return ret
	end
	local use_func = use_item_func[conf.useType]
	if use_func == nil then
		print(LActor.getActorId(actor) .. "useItem: not has use func " .. conf.useType " " .. item_id)
		return use_item_error_code.not_use
	end
	return use_func(actor,item_id,count,chooseindex)
end


local function onUseItem(actor,packet)
	local item_id = LDataPack.readInt(packet)
	local count   = LDataPack.readInt(packet)
	local chooseindex = LDataPack.readChar(packet)
	count = math.min(49999, count)
	local ret     = useItem(actor, item_id, count, chooseindex)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_UseItem)
	if npack == nil then
		return
	end
	LDataPack.writeByte(npack,ret)
	LDataPack.flush(npack)
end

local function onBuyUseItem(actor, packet)
	local storeid = LDataPack.readShort(packet)

	local conf = StoreItemConfig[storeid]
	if not conf then
		return
	end
	if not actoritem.checkItem(actor, conf.itemId, 1) then
		if not actoritem.checkItem(actor, conf.needItemId, conf.price) then
			return
		end
		actoritem.reduceItem(actor, conf.needItemId, conf.price, "buy skill and learn")
		actoritem.addItem(actor, conf.itemId, 1, "buy skill and learn")
	end

	local ret = useItem(actor, conf.itemId, 1)
	if ret ~= use_item_error_code.use_succeed then
		return
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_UseItem)
	if npack == nil then
		return
	end
	LDataPack.writeByte(npack,ret)
	LDataPack.flush(npack)
end

--生成随机物品id
function createComposeItem(temp)
	local weight = 0
	for k, v in pairs(temp) do
		weight = weight + v.pro
	end
	local num = math.random(1, weight)
	for k, v in ipairs(temp) do
		if num <= v.pro then
			return v.id
		end
		num = num - v.pro
	end
	return false
end

--------------------------------------------
--[[
local function onComposeItem(actor,packet)
	local srcItemType=LDataPack.readInt(packet)----获取合成类型
	local srcItemId = LDataPack.readInt(packet)----获取合成物品ID
	local srcCnt = LDataPack.readUInt(packet)----获取合成物品的数量
	local conf = ComposeConfig[srcItemType][srcItemId]----获取物品的索引之类的
	if conf == nil then return end----没有就直接返回

	for k,v in ipairs(conf.item) do
		if not actoritem.checkItem(actor, v.id, v.count * srcCnt) then
			return
		end
	end
	for k,v in ipairs(conf.item) do
		actoritem.reduceItem(actor, v.id, v.count * srcCnt, "item_consume_compostItem")
	end

	for i=1, srcCnt do
		if conf.type == 2 then
			srcItemId = createComposeItem(conf.randoms)
		end

		actoritem.addItem(actor, srcItemId, 1, "item_give_compostItem") --生成合成物
	end

	--回包
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_ComposeItem)
	LDataPack.writeInt(npack, srcItemId)
	LDataPack.flush(npack)

	actorevent.onEvent(actor, aeComposeItem, srcItemId)
end

function s2cCrateDrops(actor, items)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_CrateDrops)
	LDataPack.writeInt(npack, #items)
	for k, v in ipairs(items) do
		LDataPack.writeInt(npack, v.type)
		LDataPack.writeInt(npack, v.id)
		LDataPack.writeInt(npack, v.count)
	end
	LDataPack.flush(npack)
end

netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.cBagCmd_UseItem, onUseItem)
netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.sBagCmd_BuyAndUse, onBuyUseItem)
netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.cBagCmd_ComposeItem, onComposeItem)


end]]
--------------------------------------------

local function onComposeItem(actor,packet)
	local srcItemId = LDataPack.readInt(packet)
	local srcCnt = LDataPack.readUInt(packet)
    composeItem(actor, srcItemId, srcCnt)
end

function s2cCrateDrops(actor, items)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_CrateDrops)
	LDataPack.writeInt(npack, #items)
	for k, v in ipairs(items) do
		LDataPack.writeInt(npack, v.type)
		LDataPack.writeInt(npack, v.id)
		LDataPack.writeInt(npack, v.count)
	end
	LDataPack.flush(npack)
end

local function onDecompose(actor, reader)
	local item_id = LDataPack.readInt(reader)
	local count = LDataPack.readInt(reader)
    
    if count <= 0 then
        return
    end
    
    --if 1000 < count then
        --count = 1000
    --end
    
    local conf = FenJieConfig[item_id]
    if conf == nil then
        return
    end
    
    if not actoritem.checkItem(actor, item_id, count) then
        return
    end
    
    actoritem.reduceItem(actor, item_id, count, 'decompose')
    
    local list = {}
    for i = 1, count do
        table.insert(list, conf.item)
    end
    list = actoritem.mergeItemsTable(list)
    actoritem.addItems(actor, list, 'decompose')
    
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_Decompose)
    if pack then
        LDataPack.writeShort(pack, #list)
        for _, t in ipairs(list) do
            LDataPack.writeInt(pack, t.id)
            LDataPack.writeInt(pack, t.count)
        end
        LDataPack.flush(pack)
    end
end

function composeItem(actor, srcItemId, srcCnt)
    local conf = HeChengConfig[srcItemId]
    if conf == nil then return end
    
    for k, v in ipairs(conf.item) do
        if not actoritem.checkItem(actor, v.id, v.count * srcCnt) then
            return
        end
    end
    for k, v in ipairs(conf.item) do
        actoritem.reduceItem(actor, v.id, v.count * srcCnt, "item_consume_compostItem")
    end
    
	if conf.type == 2 then
		for i = 1, srcCnt do
			if conf.type == 2 then
				srcItemId = createComposeItem(conf.randoms)
			end
			actoritem.addItem(actor, srcItemId, 1, "item_give_compostItem") --生成合成物
		
    end
	else
		actoritem.addItem(actor, srcItemId, srcCnt, "item_give_compostItem") --生成合成物
	end
	
    --for i = 1, srcCnt do
        --if conf.type == 2 then
            --srcItemId = createComposeItem(conf.randoms)
        --end
        
        --actoritem.addItem(actor, srcItemId, srcCnt, "item_give_compostItem") --生成合成物
    --end
    
    --回包
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_ComposeItem)
    LDataPack.writeInt(npack, srcItemId)
    LDataPack.flush(npack)
    
    actorevent.onEvent(actor, aeComposeItem, srcItemId)
end

local compose_items = {} --([viewType2] = {id,id,...})
for id, conf in pairs(HeChengConfig) do
    if not compose_items[conf.viewType2] then
        compose_items[conf.viewType2] = {}
    end
    table.insert(compose_items[conf.viewType2], id)
end
for _, tbl in pairs(compose_items) do
    table.sort(tbl)
end

local function getCanComposeItemCount(actor, items)
    local count = -1
    for _, v in pairs(items) do
        local itemCount = actoritem.getItemCount(actor, v.id)
        local temp_count = math.floor(itemCount / v.count)
        if count < 0 or temp_count < count then
            count = temp_count
        end
    end
    return count
end

function onOneKeyCompose(actor, reader)
	if not halosystem.isBuyHalo(actor) then return end
    local cType = LDataPack.readInt(reader)
    local composeItems = compose_items[cType]
    if not composeItems then return end
    for _, composeId in ipairs(composeItems) do
    	local count = getCanComposeItemCount(actor, HeChengConfig[composeId].item)
    	if count > 0 then 
        	composeItem(actor, composeId, count)
        end
    end
end

netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.cBagCmd_UseItem, onUseItem)
netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.sBagCmd_BuyAndUse, onBuyUseItem)
netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.cBagCmd_ComposeItem, onComposeItem)
netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.cBagCmd_Decompose, onDecompose)
netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.cBagCmd_OneKeyCompose, onOneKeyCompose)

----------------------------------------------------------------------------------------------------------
--获取物品公告名
function getItemDisplayName(id)
    local conf = ItemConfig[id]
    if conf == nil then return nil end

    local name = conf.name
    if (conf.zsLevel or 0) > 0 then
        return name .. string.format("(%d%s)", conf.zsLevel, ScriptTips.wordYi)
    else
        return name .. string.format("(%d%s)", conf.level or 0, ScriptTips.wordJi)
    end
end


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.clearDoubleExp = function (actor, args)
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if var.doubleExp then
		var.doubleExp.delay = 0
		actorlogin.s2cDoubleExpTime(actor)
	end
	return true
end

gmCmdHandlers.useitem = function (actor, args)
	local item_id = tonumber(args[1])
	local count = tonumber(args[2]) or 1
	local chooseindex = tonumber(args[3]) or 0
	if not item_id then return false end
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, item_id)
	LDataPack.writeInt(pack, count)
	LDataPack.writeChar(pack, chooseindex)
	LDataPack.setPosition(pack, 0)
	onUseItem(actor, pack)
	return true
end


