module("ckmonsterconfig",package.seeall)
	
function checkExcel()
	local tabName = "MonsterTujianConfig";
	local rets = true
	for k, data in pairs(MonsterTujianConfig) do
		local ret = true

		ret = ckcom.ckRewardItem(data.needItem) and ret;
		ret = ckcom.ckAttr(data, "attr", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

