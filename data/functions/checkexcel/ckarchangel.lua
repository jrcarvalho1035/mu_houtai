module("ckarchangel",package.seeall)
	
function checkExcel()
	local tabName = "ArchangelConfig";
	local rets = true
	for k, data in pairs(ArchangelConfig) do
		local ret = true
		
		for k1, v1 in pairs(data) do
			ret = ckcom.ckRewardItem(v1.equipid) and ret;
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

