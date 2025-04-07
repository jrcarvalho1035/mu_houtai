module("ckfund",package.seeall)
	
function checkExcel()
	local tabName = "FundConfig";
	local rets = true
	for k, data in pairs(FundConfig) do
		local ret = true
		ret = ckcom.ckExist(ExpConfig, "ExpConfig", data.level, "level") and ret;
		ret = ckcom.ckReward(data, "rewards", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

