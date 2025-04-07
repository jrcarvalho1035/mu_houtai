module("ckfootstage",package.seeall)
	
function checkExcel()
	local tabName = "FootStage";
	local rets = true
	for k, data in pairs(FootStage) do
		local ret = true
		ret = ckcom.ckAttr(data, "attr", tabName) and ret;
		ret = ckcom.ckAttr(data, "attrTotal", tabName) and ret;
		ret = ckcom.ckAttr(data, "tupoattr", tabName) and ret;
		ret = ckcom.ckReward(data, "tupocost", tabName) and ret;
		ret = ckcom.ckAttr(data, "skillattr", tabName) and ret;
		ret = ckcom.ckReward(data, "costItems", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

