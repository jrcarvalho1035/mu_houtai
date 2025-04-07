module("ckachievement",package.seeall)
	
function checkExcel()
	local tabName = "AchievementTaskConfig";
	local rets = true
	for k, data in pairs(AchievementTaskConfig) do
		local ret = true

		if taskcommon.taskTypeHandleType[data.type] ~= taskcommon.eCoverType then
			log_print("achieve id[%d] type[%d] is not cover type", data.id, data.type)
			ret = false
		end
		ret = ckcom.ckReward(data, "awardList", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

