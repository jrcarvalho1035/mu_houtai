module("cktreasure",package.seeall)
	
function checkExcel()
	local tabName = "TreasurelConfig";
	local rets = true
	for k, data in pairs(TreasurelConfig) do
		local ret = true

		ret = ckcom.ckRewardItem(data.id) and ret;
		ret = ckcom.ckExist(DropGroupConfig, "DropGroupConfig", data.dropId, "dropId") and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

