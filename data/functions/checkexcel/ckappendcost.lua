module("ckappendcost",package.seeall)
	
function checkExcel()
	local tabName = "AppendCostConfig";
	local rets = true
	for k, data in pairs(AppendCostConfig) do
		local ret = true
		ret = ckcom.ckReward(data, "items", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

