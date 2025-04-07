module("ckbagvip",package.seeall)
	
function checkExcel()
	local tabName = "BagVipConfig";
	local rets = true
	for k, data in pairs(BagVipConfig) do
		local ret = true
		ret = ckcom.ckExist(VipConfig, "VipConfig", k, "vip") and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

