module("ckjewellevel",package.seeall)
	
function checkExcel()
	local tabName = "JewelLevelConfig";
	local rets = true
	for k, data in pairs(JewelLevelConfig) do
		local ret = true
		for k1, data1 in pairs(data) do
			ret = ckcom.ckExist(JewelConfig, "JewelConfig", data1.id, "id") and ret;
			ret = ckcom.ckAttr(data1, "attr", tabName) and ret;
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

