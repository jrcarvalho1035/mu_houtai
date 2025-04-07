module("ckdespairbossdata",package.seeall)
	
function checkExcel()
	local tabName = "DespairBossConfig";
	local rets = true
	for k, data in pairs(DespairBossConfig) do
		local ret = true

		ret = ckcom.ckExist(ExpConfig, "ExpConfig", data.level, "level") and ret;
		ret = ckcom.ckExist(FubenConfig, "FubenConfig", data.fbId, "fbId") and ret;
		ret = ckcom.ckExist(MonstersConfig, "MonstersConfig", data.bossId, "bossId") and ret;
		ret = ckcom.ckExist(DropGroupConfig, "DropGroupConfig", data.dropId, "dropId") and ret;
		ret = ckcom.ckExist(DropGroupConfig, "DropGroupConfig", data.rewards, "rewards") and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

