module("ckjewelgroup",package.seeall)
	
function checkExcel()
	local tabName = "JewelGroupConfig";
	local rets = true
	for k, data in pairs(JewelGroupConfig) do
		local ret = true
		for k1, v in pairs(data.group) do
			ret = ckcom.ckExist(JewelConfig, "JewelConfig", v, "group") and ret;
		end
		ret = ckcom.ckAttr(data, "attr", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

