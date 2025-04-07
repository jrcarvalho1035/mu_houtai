module("ckdropgroup",package.seeall)
	
function checkExcel()
	local tabName = "DropGroupConfig";
	local rets = true
	for k, data in pairs(DropGroupConfig) do
		local ret = true
		for k, v in pairs(data.group) do
			ret = ckcom.ckExist(DropTableConfig, "DropTableConfig", v.id, "group") and ret;
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

