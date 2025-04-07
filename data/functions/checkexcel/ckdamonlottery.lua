module("ckdamonlottery",package.seeall)
	
function checkExcel()
	local tabName = "DamonLotteryConfig";
	local rets = true
	for k, data in pairs(DamonLotteryConfig) do
		local ret = true
		ret = ckcom.ckReward(data, "cost", tabName) and ret;
		for k, v in pairs(data.rewards) do
			ret = ckcom.ckExist(DamonConfig, "DamonConfig", v[1], "rewards") and ret;
		end
		for k, v in pairs(data.rewards2) do
			ret = ckcom.ckExist(DamonConfig, "DamonConfig", v[1], "rewards2") and ret;
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

