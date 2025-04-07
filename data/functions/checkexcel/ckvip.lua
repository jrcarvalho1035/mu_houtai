module("ckvip",package.seeall)
	
function checkExcel()
	local tabName = "VipConfig";
	local rets = true
	for k, data in pairs(VipConfig) do
		local ret = true

		ret = ckcom.ckReward(data, "awards", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

