module("ckenhanceattr",package.seeall)
	
function checkExcel()
	local tabName = "EnhanceAttrConfig";
	local rets = true
	for k, data in pairs(EnhanceAttrConfig) do
		local ret = true
		ret = ckcom.ckNumberRange(k, "posId", tabName, 0, 9) and ret
		for k1, data1 in pairs(data) do
			ret = ckcom.ckAttr(data1, "attr", tabName) and ret;
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

