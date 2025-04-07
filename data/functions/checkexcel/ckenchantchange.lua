module("ckenchantchange",package.seeall)
	
function checkExcel()
	local tabName = "EnchantChangeConfig";
	local rets = true
	for k, data in pairs(EnchantChangeConfig) do
		local ret = true
		ret = ckcom.ckBackpackItem(k) and ret;
		ret = ckcom.ckReward(data, "items", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

