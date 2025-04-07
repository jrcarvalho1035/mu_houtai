module("ckloginrewards",package.seeall)
	
function checkExcel()
	local tabName = "LoginRewardsConfig";
	local rets = true
	for k, data in pairs(LoginRewardsConfig) do
		local ret = true

		ret = ckcom.ckReward(data, "rewards", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

