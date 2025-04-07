module("ckelementlibrary",package.seeall)
	
function checkExcel()
	local tabName = "ElementLibraryConfig";
	local rets = true
	for k, data in pairs(ElementLibraryConfig) do
		local ret = true
		for k, v in pairs(data.rewards) do
			ret = ckcom.ckExist(ElementBaseConfig, "ElementBaseConfig", v[1], "rewards") and ret;
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

