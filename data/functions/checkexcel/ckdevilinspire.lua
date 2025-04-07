module("ckdevilinspire",package.seeall)
	
function checkExcel()
	local tabName = "DevilInspireConfig";
	local rets = true
	for k, data in pairs(DevilInspireConfig) do
		local ret = true

		ret = ckcom.ckAttr(data, "attrs", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

