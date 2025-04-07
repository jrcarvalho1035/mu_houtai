module("ckguzhanchangdata",package.seeall)
	
function checkExcel()
	local tabName = "GuzhanchangConfig";
	-- local rets = true
	-- for k, data in pairs(GuzhanchangConfig) do
	-- 	local ret = true

	-- 	ret = ckcom.ckExist(ExpConfig, "level", data.level, "level") and ret;
	-- 	ret = ckcom.ckExist(FubenConfig, "FubenConfig", data.fbId, "fbId") and ret;

	-- 	ckcom.ckFail(ret, tabName, k)
	-- 	rets = rets and ret
	-- end
	return ckcom.ckFails(rets, tabName)
end

