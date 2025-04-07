module("ckway",package.seeall)
	
function checkExcel()
	local tabName = "WayConfig";
	local rets = true
	for k, data in pairs(WayConfig) do
		local ret = true

		ret = ckcom.ckExist(ExpConfig, "ExpConfig", data.clevel, "clevel") and ret;
		-- if data.id > 0 then
		-- 	ret = ckcom.ckExist(EconomyConfig, "EconomyConfig", data.id, "id") and ret;
		-- 	if data.clevel < EconomyConfig[data.id].level then
		-- 		ret = false
		-- 		utils.printInfo("Way level client < server", k, data.clevel, EconomyConfig[data.id].level)
		-- 	end
		-- 	if data.taskId < EconomyConfig[data.id].taskId then
		-- 		ret = false
		-- 		utils.printInfo("Way task client < server", k, data.taskId, EconomyConfig[data.id].taskId)
		-- 	end
		-- end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

