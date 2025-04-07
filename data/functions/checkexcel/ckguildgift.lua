module("ckguildgift",package.seeall)
	
function checkExcel()
	local tabName = "GuildGiftConfig";
	local rets = true
	for k, data in pairs(GuildGiftConfig) do
		local ret = true

		ret = ckcom.ckRewardItem(data.gift0) and ret;
		ret = ckcom.ckRewardItem(data.gift1) and ret;
		ret = ckcom.ckRewardItem(data.gift2) and ret;
		ret = ckcom.ckRewardItem(data.gift3) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

