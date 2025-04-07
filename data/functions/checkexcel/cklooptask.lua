module("cklooptask",package.seeall)
	
function checkExcel()
	local tabName = "LoopTaskConfig";
	local rets = true
	for k, data in pairs(LoopTaskConfig) do
		local ret = true

		ret = ckcom.ckReward(data, "awardList1", tabName) and ret;
		ret = ckcom.ckReward(data, "awardList2", tabName) and ret;
		ret = ckcom.ckReward(data, "awardList3", tabName) and ret;
		ret = ckcom.ckReward(data, "awardList4", tabName) and ret;
		ret = ckcom.ckReward(data, "awardList5", tabName) and ret;
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

