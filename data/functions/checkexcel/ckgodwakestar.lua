module("ckgodwakestar",package.seeall)
	
function checkExcel()
	local tabName = "GodWakeStarConfig";
	local rets = true
	for k, data in pairs(GodWakeStarConfig) do
		local ret = true
		ret = ckcom.ckAttr(data, "attr", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

