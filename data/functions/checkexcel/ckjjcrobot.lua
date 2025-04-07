module("ckjjcrobot",package.seeall)
	
function checkExcel()
	local tabName = "JjcRobotConfig";
	local rets = true
	for k, data in pairs(JjcRobotConfig) do
		local ret = true

		for k1, data1 in pairs(data) do
			ret = ckcom.ckExist(ExpConfig, "ExpConfig", data1.level, "level") and ret;
			ret = ckcom.ckExist(JobConfig, "JobConfig", data1.job, "job") and ret;
			if ItemConfig[data1.weaponId].type ~=0 or ItemConfig[data1.weaponId].subType ~= EquipSlotType_Weapon then
				utils.printInfo("error weapon id", data1.weaponId)
			end
			if ItemConfig[data1.clothesId].type ~=0 or ItemConfig[data1.clothesId].subType ~= EquipSlotType_Coat then
				utils.printInfo("error cloth id", data1.clothesId)
			end 
			ret = ckcom.ckExist(WingLevelConfig, "WingLevelConfig", data1.wingLevel, "wingLevel") and ret;
			ret = ckcom.ckAttr(data1, "attrs", tabName)
			for k2, v2 in pairs(data1.skills) do
				ret = ckcom.ckExist(SkillsConfig, "SkillsConfig", v2, "skills") and ret;
				if math.floor(v2 / 100) ~= data1.job then
					utils.printInfo("error skills job", v2)
				end
			end
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

