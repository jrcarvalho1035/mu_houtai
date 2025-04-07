module("ckelementlevel",package.seeall)
	
function checkExcel()
	local tabName = "ElementLevelConfig";
	local rets = true
	for k, data in pairs(ElementLevelConfig) do
		local ret = true
		ret = ckcom.ckExist(ElementBaseConfig, "ElementBaseConfig", k, "id") and ret;
		for k1, data1 in pairs(data) do
			ret = ckcom.ckAttr(data1, "attr", tabName) and ret;
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

