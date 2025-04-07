module("cksceneconfig",package.seeall)
	
function checkExcel()
	local tabName = "SceneTujianConfig";
	local rets = true
	for k, data in pairs(SceneTujianConfig) do
		local ret = true

		for k1, v1 in pairs(data.needMonsters) do
			ret = ckcom.ckExist(MonsterTujianConfig, "MonsterTujianConfig", v1, "needMonsters") and ret;
		end
		ret = ckcom.ckAttr(data, "attr", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

