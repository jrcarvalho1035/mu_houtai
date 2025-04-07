module("ckfortfuben",package.seeall)
	
function checkExcel()
	local tabName = "FortConfig";
	local rets = true
	for k, data in pairs(FortConfig) do
		local ret = true

		ret = ckcom.ckExist(FubenConfig, "FubenConfig", data.fbId, "fbId") and ret;
		ret = ckcom.ckReward(data, "rewards", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

