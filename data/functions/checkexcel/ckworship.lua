module("ckworship",package.seeall)
	
function checkExcel()
	local tabName = "WorshipConfig";
	local rets = true
	for k, data in pairs(WorshipConfig) do
		local ret = true

		for k1, data1 in pairs(data) do
			ret = ckcom.ckExist(ExpConfig, "ExpConfig", data1.level, "level") and ret;
			ret = ckcom.ckReward(data1, "awards", tabName) and ret;
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

