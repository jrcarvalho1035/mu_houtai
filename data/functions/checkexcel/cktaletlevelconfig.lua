module("cktaletlevelconfig",package.seeall)
	
function checkExcel()
	local tabName = "TalentLevelConfig";
	local rets = true
	for k, data in pairs(TalentLevelConfig) do
		local ret = true

		-- for k1, data1 in pairs(data) do
		-- 	for k2, v2 in pairs(data1.attr) do
		-- 		if not AttrPowerConfig[v2.type] and not SkillsConfig[v2.type] and not EffectsConfig[v2.type] then
		-- 			utils.printInfo("invalid attr id", v2.type);
		-- 			ret = false
		-- 		end
		-- 	end
		-- end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

