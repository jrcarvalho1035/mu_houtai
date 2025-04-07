module("ckfuben",package.seeall)
	
function checkExcel()
	local tabName = "FubenConfig";
	local rets = true
	for k, data in pairs(FubenConfig) do
		local ret = true
		for k1, v1 in pairs(data.scenes) do
			ret = ckcom.ckExist(ScenesConfig, "ScenesConfig", v1, "scenes") and ret;
		end
		if data.refreshMonster > 0 then
			ret = ckcom.ckExist(RefreshMonsters, "RefreshMonsters", data.refreshMonster, "refreshMonster") and ret;
		end
		for k1 ,v1 in pairs(data.events) do
			ret = v1.conditions and ret;
			if v1.conditions.type == 0 then
				ret = v1.conditions.time and ret;
			elseif v1.conditions.type == 1 then
				ret = v1.conditions.id and ret;
			elseif v1.conditions.type == 2 then
				ret = v1.conditions.count and ret;
			elseif v1.conditions.type == 4 then
				ret = v1.conditions.id and ret;
			elseif v1.conditions.type == 6 then
				ret = v1.conditions.id and ret;
			elseif v1.conditions.type == 8 then
				ret = v1.conditions.name and ret;
				ret = v1.conditions.value and ret;
			elseif v1.conditions.type == 9 then
				ret = v1.conditions.id and ret;
			elseif v1.conditions.type == 10 then
				ret = v1.conditions.id and ret;
			elseif v1.conditions.type == 11 then
				ret = v1.conditions.wave and ret;
			end
			ret = v1.actions and ret;
			if v1.actions == 7 or v1.actions == 9 then
				ret = v1.actions.id and ret;
			elseif v1.actions == 11 then
				ret = v1.actions.drops and ret;
			elseif v1.actions == 12 or v1.actions == 14 then
				ret = v1.actions.name and ret;
			elseif v1.actions == 13 then
				ret = v1.actions.events and ret;
			end
			if not ret then
				utils.printInfo("error events")
			end
		end
		for k1, v1 in pairs(data.monsterCounts) do
			ret = ckcom.ckExist(MonstersConfig, "MonstersConfig", v1.monsterid, "monsterCounts") and ret;
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

