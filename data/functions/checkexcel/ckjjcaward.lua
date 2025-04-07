module("ckjjcaward",package.seeall)
	
function checkExcel()
	local tabName = "JjcRewardConfig";
	local rets = true
	for k, data in pairs(JjcRewardConfig) do
		local ret = true

		if JjcRewardConfig[k+1] then
			if data.most + 1 ~= JjcRewardConfig[k+1].rank then
				log_print("interval most error: most[%d]+1 ~= next rank[%d]", data.most, JjcRewardConfig[k+1].rank)
				ret = false
			end
		end

		ret = ckcom.ckReward(data, "winReward", tabName) and ret;
		ret = ckcom.ckReward(data, "loseReward", tabName) and ret;
		ret = ckcom.ckReward(data, "dailyReward", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

