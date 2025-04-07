module("ckzhuansheng",package.seeall)
	
function checkExcel()
	local tabName = "ZhuanshengLevelConfig";
	local rets = true
	for k, data in pairs(ZhuanshengLevelConfig) do
		local ret = true

		ret = ckcom.ckExist(ExpConfig, "ExpConfig", data.level, "level") and ret;
		ret = ckcom.ckReward(data, "items", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

