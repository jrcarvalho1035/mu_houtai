module("ckculturepos",package.seeall)
	
function checkExcel()
	local tabName = "CulturePosConfig";
	local rets = true
	for k, data in pairs(CulturePosConfig) do
		local ret = true
		ret = ckcom.ckNumberRange(k, "posId", tabName, 0, 9) and ret
		for k1, v1 in pairs(data.attr) do
			ret = ckcom.ckAttrType(k1) and ret;
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

