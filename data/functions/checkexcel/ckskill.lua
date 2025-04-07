module("ckskill",package.seeall)
	
function checkExcel()
	local tabName = "SkillsConfig";
	local rets = true
	for k, data in pairs(SkillsConfig) do
		local ret = true

		for k1, v1 in pairs(data.tarEff) do
			ret = ckcom.ckExist(EffectsConfig, "EffectsConfig", v1, "tarEff") and ret;
		end
		for k1, v1 in pairs(data.selfEff) do
			ret = ckcom.ckExist(EffectsConfig, "EffectsConfig", v1, "selfEff") and ret;
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

