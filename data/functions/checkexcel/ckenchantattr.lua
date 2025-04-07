module("ckenchantattr",package.seeall)
	
function checkExcel()
	local tabName = "EnchantAttrConfig";
	local rets = true
	for k, data in pairs(EnchantAttrConfig) do
		local ret = true
		ret = ckcom.ckNumberRange(k, "slot", tabName, 0, 9) and ret
		for k1, data1 in pairs(data) do
			for k2, data2 in pairs(data1) do
				ret = ckcom.ckAttr(data2, "attr", tabName) and ret;
				ret = ckcom.ckReward(data2, "items", tabName) and ret;
			end
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

