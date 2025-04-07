module("storecommon", package.seeall)

EStoreType = 
{
	StoreItem = 1, --道具商店
	StoreSecret = 2, --神秘商店
}

--神秘商店商品分组
local tGroupConfig = {}
for _,tb in pairs(StoreSecretGroupConfig) do
	if (not tGroupConfig[tb.groupId]) then
		tGroupConfig[tb.groupId] = {}
		tGroupConfig[tb.groupId].groupId = tb.groupId
		tGroupConfig[tb.groupId].low = tb.low
		tGroupConfig[tb.groupId].high = tb.high
		tGroupConfig[tb.groupId].maxProb = 0
		tGroupConfig[tb.groupId].goodsList = {}
	end

	tGroupConfig[tb.groupId].maxProb = tGroupConfig[tb.groupId].maxProb + tb.prob
	table.insert(tGroupConfig[tb.groupId].goodsList, {id = tb.id, prob = tb.prob})
end

function getYuanBaoPrice(itemId)
	for _,tb in pairs(StoreItemConfig) do
		if (tb.itemId == itemId) then
			return tb.price
		end
	end
end

function getGoodsListByGroupId(actor, groupId, counts)
	local config = tGroupConfig[groupId]
	if (not config) then
		return
	end

	local maxProb = 0
	local goodsList = {}
	local job = LActor.getJob(actor)
	for _,tb in pairs(config.goodsList) do
		if not tb.job or tb.job <= 0 or job == tb.job then
			table.insert(goodsList, tb)
			if tb.Preprob and tb.Preprob[counts] then
				maxProb = maxProb + tb.Preprob[counts]
			else
				maxProb = maxProb + tb.prob
			end
		end
	end
	return goodsList,maxProb
end


function getGroupIdByLevel(level)
	for _,config in pairs(tGroupConfig) do
		if (config.low <= level and config.high >= level) then
			return config.groupId
		end
	end
	return tGroupConfig[1].groupId
end

