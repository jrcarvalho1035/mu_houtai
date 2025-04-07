module("ckpurifyattr",package.seeall)
	
function checkExcel()
	local tabName = "PurifyAttrConfig";
	local rets = true
	for k, data in pairs(PurifyAttrConfig) do
		local ret = true
		for k1, data1 in pairs(data.cost) do
			ret = ckcom.ckReward(data1, "items", tabName) and ret;
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

