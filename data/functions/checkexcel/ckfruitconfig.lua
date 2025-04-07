module("ckfruitconfig",package.seeall)
	
function checkExcel()
	local tabName = "FruitConfig";
	local rets = true
	for k, data in pairs(FruitConfig) do
		local ret = true
		ret = ckcom.ckExist(ItemConfig, "ItemConfig", data.id, "id") and ret;
		ret = ckcom.ckAttr(data, "attrs", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

