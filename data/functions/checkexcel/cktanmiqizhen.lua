module("cktanmiqizhen",package.seeall)
	
function checkExcel()
	local tabName = "TanMiQizhenStore";
	local rets = true
	for k, data in pairs(TanMiQizhenStore) do
		local ret = true
		ret = ckcom.ckRewardItem(data.id) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

