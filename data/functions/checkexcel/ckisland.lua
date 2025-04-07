module("ckisland",package.seeall)
	
function checkExcel()
	local tabName = "IslandFubenConfig";
	local rets = true
	for k, data in pairs(IslandFubenConfig) do
		local ret = true

		ret = ckcom.ckExist(FubenConfig, "FubenConfig", data.fbId, "fbId") and ret;
		ret = ckcom.ckExist(MonstersConfig, "MonstersConfig", data.bossId, "bossId") and ret;
		ret = ckcom.ckReward(data, "passRewards", tabName) and ret;
		ret = ckcom.ckReward(data, "helpRewards", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

