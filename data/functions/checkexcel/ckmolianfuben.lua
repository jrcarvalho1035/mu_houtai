module("ckmolianfuben",package.seeall)
	
function checkExcel()
	local tabName = "MolianFubenConfig";
	local rets = true
	for k, data in pairs(MolianFubenConfig) do
		local ret = true

		ret = ckcom.ckExist(FubenConfig, "FubenConfig", data.fbid, "fbid") and ret;
		ret = ckcom.ckReward(data, "rewards", tabName) and ret;
		ret = ckcom.ckReward(data, "passRewards", tabName) and ret;
		ret = ckcom.ckExist(MonstersConfig, "MonstersConfig", data.monsterid, "monsterid") and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

