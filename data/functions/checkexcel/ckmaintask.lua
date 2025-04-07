module("ckmaintask",package.seeall)
	
function checkExcel()
	local tabName = "MainTaskConfig";
	local rets = true
	for k, data in pairs(MainTaskConfig) do
		local ret = true

		ret = ckcom.ckReward(data, "awardList", tabName) and ret;
		if data.type == taskcommon.taskType.emMonsterCount then 
			if data.acceptActionID ~= 1 then
				utils.printInfo("monster task acceptActionID no = 1", k)
				ret = false
			end
			ret = ckcom.ckFubenMonster(data.acceptActionParams[1], data.acceptActionParams[2], "acceptActionParams")
		end

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

