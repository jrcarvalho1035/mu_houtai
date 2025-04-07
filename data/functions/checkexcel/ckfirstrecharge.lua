module("ckfirstrecharge",package.seeall)
	
function checkExcel()
	local tabName = "FirstRechargeConfig";
	local rets = true
	for k, data in pairs(FirstRechargeConfig) do
		local ret = true

		ret = ckcom.ckReward(data, "awardList", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

