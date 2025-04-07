module("cksecretskill",package.seeall)
	
function checkExcel()
	local tabName = "SecretskillConfig";
	local rets = true
	for k, data in pairs(SecretskillConfig) do
		local ret = true
		
		ret = ckcom.ckReward(data, "cost1", tabName) and ret;
		ret = ckcom.ckReward(data, "cost2", tabName) and ret;
		ret = ckcom.ckReward(data, "cost3", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

