module("ckmountlottery",package.seeall)
	
function checkExcel()
	local tabName = "MountLotteryConfig";
	local rets = true
	for k, data in pairs(MountLotteryConfig) do
		local ret = true

		ret = ckcom.ckReward(data, "cost", tabName) and ret;
		for k1, v1 in pairs(data.rewards) do
			ret = ckcom.ckRewardItem(v1[1][1]) and ret;
		end
		for k1, v1 in pairs(data.rewards2) do
			ret = ckcom.ckRewardItem(v1[1][1]) and ret;
		end
		for k1, v1 in pairs(data.rewards3) do
			ret = ckcom.ckRewardItem(v1[1][1]) and ret;
		end
		for k1, v1 in pairs(data.rewards4) do
			ret = ckcom.ckRewardItem(v1[1][1]) and ret;
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

