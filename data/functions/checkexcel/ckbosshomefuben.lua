module("ckbosshomefuben",package.seeall)
	
function checkExcel()
	local tabName = "BosshomeFubenConfig";
	local rets = true
	for k, data in pairs(BosshomeFubenConfig) do
		local ret = true

		ret = ckcom.ckExist(ExpConfig, "ExpConfig", data.level, "level") and ret;
		ret = ckcom.ckExist(FubenConfig, "FubenConfig", data.fbId, "fbId") and ret;
		ret = ckcom.ckExist(MonstersConfig, "MonstersConfig", data.bossId, "bossId") and ret;
		ret = ckcom.ckExist(DropGroupConfig, "DropGroupConfig", data.belongDrop, "belongDrop") and ret;
		ret = ckcom.ckExist(DropGroupConfig, "DropGroupConfig", data.joinDrop, "joinDrop") and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

