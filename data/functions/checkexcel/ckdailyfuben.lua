module("ckdailyfuben",package.seeall)
	
function checkExcel()
	local tabName = "DailyFubenConfig";
	local rets = true
	for k, data in pairs(DailyFubenConfig) do
		local ret = true
		for k1, data1 in pairs(data) do
			ret = ckcom.ckExist(ExpConfig, "ExpConfig", data1.limitLevel, "limitLevel") and ret;
			ret = ckcom.ckExist(FubenConfig, "FubenConfig", data1.fbId, "fbId") and ret;
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

