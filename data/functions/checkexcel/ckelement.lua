module("ckelement",package.seeall)
	
function checkExcel()
	local tabName = "ElementBaseConfig";
	local rets = true
	for k, data in pairs(ElementBaseConfig) do
		local ret = true
		ret = ckcom.ckExist(ItemConfig, "ItemConfig", data.id, "id") and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

