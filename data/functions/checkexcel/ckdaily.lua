module("ckdaily",package.seeall)
	
function checkExcel()
	local tabName = "DailyConfig";
	local rets = true
	for k, data in pairs(DailyConfig) do
		local ret = true

		if taskcommon.taskTypeHandleType[data.type] ~= taskcommon.eAddType then
			log_print("daily id[%d] type[%d] is not add type", data.id, data.type)
			ret = false
		end
		ret = ckcom.ckReward(data, "awardList", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

