module("ckrefreshmonsters",package.seeall)
	
function checkExcel()
	local tabName = "RefreshMonsters";
	local rets = true
	for k, data in pairs(RefreshMonsters) do
		local ret = true

		if data.bossId > 0 then
			ret = ckcom.ckExist(MonstersConfig, "MonstersConfig", data.bossId, "bossId") and ret;
		end
		for k1, v1 in pairs(data.monsters) do
			ret = ckcom.ckExist(MonstersConfig, "MonstersConfig", v1.monsterid, "monsters") and ret;
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

