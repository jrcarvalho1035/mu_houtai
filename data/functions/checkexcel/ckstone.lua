module("ckstone",package.seeall)
	
function checkExcel()
	local tabName = "StoneConfig";
	local rets = true
	for k, data in pairs(StoneConfig) do
		local ret = true
		ret = ckcom.ckRewardItem(k) and ret
		ret = ckcom.ckAttr(data, "attr", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

