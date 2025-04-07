module("cklimit",package.seeall)
	
function checkExcel()
	local tabName = "LimitConfig";
	local rets = true
	for k, data in pairs(LimitConfig) do
		local ret = true

		ret = ckcom.ckExist(ExpConfig, "ExpConfig", data.clevel, "clevel") and ret;

		-- if k == actorexp.LimitTp.daily then
		-- 	if data.clevel < DailyConfig[1].level then
		-- 		log_print("clevel[%d] < daily config[%d]", data.clevel, DailyConfig[1].level)
		-- 		ret = false
		-- 	end
		-- end
		if k == actorexp.LimitTp.loop then
			if data.clevel < LoopTaskConfig[1].minLevel then
				log_print("clevel[%d] < loop config[%d]", data.clevel, LoopTaskConfig[1].minLevel)
				ret = false
			end
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

