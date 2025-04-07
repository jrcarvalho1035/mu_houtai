module("ckcom", package.seeall)

function ckMaxRank()
	return #g_tbPlanData.Rank;
end

function ckExist(tab, tabName, id, field)
	if not tab then
		utils.printInfo(string.format("ckExist %s: [%s][null]", field, tabName));
		return false;
	end
	local data = tab[id]
	if not data then
		utils.printInfo(string.format("ckExist %s: [%s] not exist id [%s]", field, tabName, tostring(id) ));
		return data;
	end
	return data;
end

function ckFail(ret, tabName, id)
	if not ret then
		utils.printInfo(string.format("CHECK [%s]: id[%d] fail", tabName, id));
	end
	return ret;
end

function ckFails(ret, tabName)
	if not ret then
		utils.printInfo("CHECK Excel fail:", tabName);
	end
	return ret;
end

function ckNumberRange(value, keyName, tabName, low, high)
	if value < low or value > high then
		print(string.format("%s %s [%d] must>=%d and <=%d", tabName, keyName, value, low, high))
		return false
	end
	return true
end

function ckBackpackItem(id)
	local ret = ItemConfig[id];
	return ret;
end

function ckCurrencyItem(id)
	local ret = CurrencyConfig[id]
	return ret;
end

function ckRewardItem(id)
	local ret = ckBackpackItem(id) or ckCurrencyItem(id)
	if not ret then
		utils.printInfo("invalid item id", id);
	end
	return ret;
end

function ckRewardNumber(id, number)
	local ret = true;
	if ckBackpackItem(id) then
	else
		if id == NumericType_YuanBao then
			ret = (number>0 and number<9000);
		end
	end

	if not ret then
		print(string.format("invalid item number: id[%d], number[%d]", id, number));
	end
	return ret;
end

function ckReward(data, keyName, tabName)
	local ret = true
	if not data[keyName] then
		utils.printInfo("ckReward null:", tabName, keyName)
		ret = false
	end
	for k, v in pairs(data[keyName]) do
		ret = ckRewardItem(v.id) and ret;
		ret = ckRewardNumber(v.id, v.count) and ret;
		if v.job then
			ret = ckExist(JobConfig, "JobConfig", v.job) and ret
		end
	end
	if not ret then
		utils.printInfo("ckReward error:", tabName, keyName)
	end
	return ret;
end

function ckAttrType(id)
	local ret = AttrPowerConfig[id]
	if not ret then
		utils.printInfo("invalid attr id", id);
	end
	return ret;
end

function ckAttr(data, keyName, tabName)
	local ret = true
	if not data[keyName] then
		utils.printInfo("ckAttr null:", tabName, keyName)
		ret = false
	end
	for k, v in pairs(data[keyName]) do
		ret = ckAttrType(v.type) and ret;
	end
	if not ret then
		utils.printInfo("ckAttr error:", tabName, keyName)
	end
	return ret;
end

function ckFubenMonster(fubenId, monsterId, keyName)
	fconf = FubenConfig[fubenId]
	if not fconf then
		utils.printInfo("ckFubenMonster invalid fuben id:", fubenId, keyName)
		return false
	end
	mconf = MonstersConfig[monsterId]
	if not mconf then
		utils.printInfo("ckFubenMonster invalid monster id:", monsterId, keyName)
		return false
	end
	rconf = RefreshMonsters[fconf.refreshMonster]
	if not rconf then
		utils.printInfo("ckFubenMonster invalid refresh id:", fconf.refreshMonster, keyName)
		return false
	end
	local flag = false
	for k, v in pairs(rconf.monsters) do
		if v.monsterid == monsterId then
			flag = true
		end
	end
	if not flag then
		print(string.format("%s the fuben[%d] not invalid the monster[%d]", keyName, fubenId, monsterId))
	end
	return flag
end

