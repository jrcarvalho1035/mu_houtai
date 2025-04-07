module("ckdamon",package.seeall)
	
function checkExcel()
	local tabName = "DamonConfig";
	local rets = true
	for k, data in pairs(DamonConfig) do
		local ret = true
		ret = ckcom.ckExist(ItemConfig, "ItemConfig", data.id, "id") and ret;
		ret = ckcom.ckAttr(data, "baseAttrs", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

