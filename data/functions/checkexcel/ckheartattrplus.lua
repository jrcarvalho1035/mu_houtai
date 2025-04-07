module("ckheartattrplus",package.seeall)
	
function checkExcel()
	local tabName = "HeartAttrPlusConfig";
	local rets = true
	for k, data in pairs(HeartAttrPlusConfig) do
		local ret = true
		ret = ckcom.ckAttr(data, "attr", tabName) and ret;
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

