module("ckaiconfig",package.seeall)
	
function checkExcel()
	local tabName = "AiConfig";
	local rets = true
	for k, data in pairs(AiConfig) do
		local ret = true
		for k, v in pairs(data.skills) do
			ret = ckcom.ckExist(SkillsConfig, "SkillsConfig", v.id, "skills") and ret;
		end
		for k, v in pairs(data.born) do
			for k1, v1 in pairs(v.actions) do
				ret = ckcom.ckExist(EffectsConfig, "EffectsConfig", v1.id, "actions") and ret;
			end
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

