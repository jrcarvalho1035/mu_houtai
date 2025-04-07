module("ckheart",package.seeall)
	
function checkExcel()
	local tabName = "HeartAttrConfig";
	local rets = true
	for k, data in pairs(HeartAttrConfig) do
		local ret = true
		ret = ckcom.ckAttr(data, "attr", tabName) and ret;
		ret = ckcom.ckReward(data, "items", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

