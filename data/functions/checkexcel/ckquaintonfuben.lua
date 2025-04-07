module("ckquaintonfuben",package.seeall)
	
function checkExcel()
	local tabName = "QuaintonFubenConfig";
	local rets = true
	for k, data in pairs(QuaintonFubenConfig) do
		local ret = true

		ret = ckcom.ckExist(FubenConfig, "FubenConfig", data.fbId, "fbId") and ret;
		ret = ckcom.ckExist(DropGroupConfig, "DropGroupConfig", data.joinDrop, "joinDrop") and ret;
		ret = ckcom.ckExist(DropGroupConfig, "DropGroupConfig", data.extraDrop, "extraDrop") and ret;
		for k, v in pairs(data.rankDrop) do
			ret = ckcom.ckExist(DropGroupConfig, "DropGroupConfig", v, "rankDrop") and ret;
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

