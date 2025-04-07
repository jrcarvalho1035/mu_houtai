module("cktype16",package.seeall)
	
function checkExcel()
	local tabName = "ActivityType16Config";
	local rets = true
	for k, data in pairs(ActivityType16Config) do
		local ret = true
		local count = 0
		for k1, data1 in pairs(data) do
			--ret = ckcom.ckExist(ActivityConfig,  "ActivityConfig", data1.id, "id") and ret;
			ret = ckcom.ckReward(data1, "rewards", tabName) and ret;
			count = count + 1
		end
		ret = ckcom.ckNumberRange(count, "count", tabName, 0, 31) and ret
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

