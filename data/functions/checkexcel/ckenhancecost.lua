module("ckenhancecost",package.seeall)
	
function checkExcel()
	local tabName = "EnhanceCostConfig";
	local rets = true
	for k, data in pairs(EnhanceCostConfig) do
		local ret = true
		ret = ckcom.ckReward(data, "items", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

