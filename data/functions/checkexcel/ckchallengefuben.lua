module("ckchallengefuben",package.seeall)
	
function checkExcel()
	local tabName = "ChallengefbConfig";
	local rets = true
	for k, data in pairs(ChallengefbConfig) do
		local ret = true
		ret = ckcom.ckExist(FubenConfig, "FubenConfig", data.fbid, "fbid") and ret;
		ret = ckcom.ckReward(data, "normalAwards", tabName) and ret;
		ret = ckcom.ckReward(data, "saodangAwards", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

