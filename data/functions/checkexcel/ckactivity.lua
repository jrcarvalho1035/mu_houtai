module("ckactivity",package.seeall)
	
function checkExcel()
	local tabName = "ActivityConfig";
	local rets = true
	for k, data in pairs(ActivityConfig) do
	end
	return ckcom.ckFails(rets, tabName)
end

