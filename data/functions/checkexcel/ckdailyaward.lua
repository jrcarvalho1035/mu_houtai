module("ckdailyaward",package.seeall)
	
function checkExcel()
	local tabName = "DailyAwardConfig";
	local rets = true
	for k, data in pairs(DailyAwardConfig) do
		local ret = true

		for k1, v1 in pairs(data.awardList) do
			ret = ckcom.ckExist(ExpConfig, "ExpConfig", k1, "awardList") and ret;
			ret = ckcom.ckReward(data.awardList, k1, "awardList") and ret;
		end
		
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

