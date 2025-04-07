module("ckshilianboss",package.seeall)
	
function checkExcel()
	local tabName = "ShilianBossConfig";
	local rets = true
	for k, data in pairs(ShilianBossConfig) do
		local ret = true

		ret = ckcom.ckExist(FubenConfig, "FubenConfig", data.fbId, "fbId") and ret;
		ret = ckcom.ckExist(MonstersConfig, "MonstersConfig", data.bossId, "bossId") and ret;
		ret = ckcom.ckExist(MainTaskConfig, "MainTaskConfig", data.taskId, "taskId") and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

