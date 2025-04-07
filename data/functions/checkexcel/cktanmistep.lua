module("cktanmistep",package.seeall)
	
function checkExcel()
	local tabName = "TanMiStepConf";
	local rets = true
	for k, data in pairs(TanMiStepConf) do
		local ret = true
		ret = ckcom.ckExist(TanMiCeilConf, "TanMiCeilConf", data.step, "step") and ret;
		ret = ckcom.ckReward(data, "items", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

