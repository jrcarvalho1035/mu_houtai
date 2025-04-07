module("ckrelicfuben",package.seeall)
	
function checkExcel()
	local tabName = "RelicfbConfig";
	local rets = true
	for k, data in pairs(RelicfbConfig) do
		local ret = true

		for k1, data1 in pairs(data) do
			ret = ckcom.ckExist(ExpConfig, "ExpConfig", data1.level, "level") and ret;
			ret = ckcom.ckExist(FubenConfig, "FubenConfig", data1.fbId, "fbId") and ret;
			ret = ckcom.ckReward(data1, "rewards", tabName)
			ret = ckcom.ckExist(MonstersConfig, "MonstersConfig", data1.monsterId, "monsterId") and ret;
			for k2, v2 in pairs(data1.events) do
				if v2.tp == 1 then
					ret = ckcom.ckExist(RelicShopConfig, "RelicShopConfig", v2.id, "events") and ret;
				elseif v2.tp == 2 then
					ret = ckcom.ckExist(RelicRewardConfig, "RelicRewardConfig", v2.id, "events") and ret;
				end
			end
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

