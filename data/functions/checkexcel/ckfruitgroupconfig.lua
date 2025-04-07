module("ckfruitgroupconfig",package.seeall)
	
function checkExcel()
	local tabName = "FruitGroupConfig";
	local rets = true
	for k, data in pairs(FruitGroupConfig) do
		local ret = true
		for k1, data1 in pairs(data) do
			for k2, v2 in pairs(data1.fruits) do
				ret = ckcom.ckExist(FruitConfig, "FruitConfig", v2, "fruits") and ret;
			end
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

