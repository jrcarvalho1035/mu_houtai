module("ckguildboss",package.seeall)
	
function checkExcel()
	local tabName = "GuildBossConfig";
	local rets = true
	for k, data in pairs(GuildBossConfig) do
		local ret = true

		ret = ckcom.ckExist(FubenConfig, "FubenConfig", data.fbId, "fbId") and ret;
		ret = ckcom.ckExist(MonstersConfig, "MonstersConfig", data.bossId, "bossId") and ret;
		ret = ckcom.ckReward(data, "passRewards", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

