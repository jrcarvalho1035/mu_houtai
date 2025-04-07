module("ckwingstar",package.seeall)
	
function checkExcel()
	local tabName = "WingStarConfig";
	local rets = true
	for k, data in pairs(WingStarConfig) do
		local ret = true

		ret = ckcom.ckAttr(data, "attr", tabName) and ret

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

