module("ckminer",package.seeall)
	
function checkExcel()
	local tabName = "MinerConfig";
	local rets = true
	for k, data in pairs(MinerConfig) do
		local ret = true

		ret = ckcom.ckReward(data, "reward", tabName) and ret;
		ret = ckcom.ckReward(data, "extra", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

