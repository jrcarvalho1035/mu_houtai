module("ckxueseinspire",package.seeall)
	
function checkExcel()
	local tabName = "XueseInspireConfig";
	local rets = true
	for k, data in pairs(XueseInspireConfig) do
		local ret = true

		ret = ckcom.ckAttr(data, "attrs", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

