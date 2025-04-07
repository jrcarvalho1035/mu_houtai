module("ckbravefuben",package.seeall)
	
function checkExcel()
	local tabName = "BraveFubenConfig";
	local rets = true
	for k, data in pairs(BraveFubenConfig) do
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

