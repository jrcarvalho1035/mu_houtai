module("ckfootlevel",package.seeall)
	
function checkExcel()
	local tabName = "FootLevel";
	local rets = true
	for k, data in pairs(FootLevel) do
		local ret = true
		ret = ckcom.ckAttr(data, "attr", tabName) and ret;
		ret = ckcom.ckAttr(data, "attrTotal", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

