module("ckdroptable",package.seeall)
	
function checkExcel()
	local tabName = "DropTableConfig";
	local rets = true
	for k, data in pairs(DropTableConfig) do
		local ret = true
		for k, v in pairs(data.rewards) do
			ret = ckcom.ckRewardItem(v.id) and ret;
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

