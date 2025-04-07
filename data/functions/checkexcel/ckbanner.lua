module("ckbanner",package.seeall)
	
function checkExcel()
	local tabName = "BannerConfig";
	local rets = true
	for k, data in pairs(BannerConfig) do
		local ret = true
		
		ret = ckcom.ckRewardItem(data.itemId) and ret;
		ret = ckcom.ckAttr(data, "attr", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

