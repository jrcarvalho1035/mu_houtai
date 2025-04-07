module("ckdamonlevel",package.seeall)
	
function checkExcel()
	local tabName = "DamonLevelConfig";
	local rets = true
	for k, data in pairs(DamonLevelConfig) do
		local ret = true
		for k1, v in pairs(data.baseAttrs) do
			ret = ckcom.ckExist(AttrPowerConfig, "AttrPowerConfig", k1, "baseAttrs") and ret;
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

