module("ckgatherextra",package.seeall)
	
function checkExcel()
	local tabName = "GatherExtraConfig";
	local rets = true
	for k, data in pairs(GatherExtraConfig) do
		local ret = true
		for k1, data1 in pairs(data) do
			ret = ckcom.ckAttr(data1, "attr", tabName) and ret;
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

