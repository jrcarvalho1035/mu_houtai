module("ckangelstar",package.seeall)
	
function checkExcel()
	local tabName = "AngelStarConfig";
	local rets = true
	for k, data in pairs(AngelStarConfig) do
		local ret = true

		ret = ckcom.ckReward(data, "items", tabName) and ret;
		ret = ckcom.ckAttr(data, "attr", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

