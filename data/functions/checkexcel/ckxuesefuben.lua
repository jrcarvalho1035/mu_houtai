module("ckxuesefuben",package.seeall)
	
function checkExcel()
	local tabName = "XuesefbConfig";
	local rets = true
	for k, data in pairs(XuesefbConfig) do
		local ret = true

		ret = ckcom.ckExist(ExpConfig, "ExpConfig", data.level, "level") and ret;
		ret = ckcom.ckExist(ExpConfig, "ExpConfig", data.level2, "level2") and ret;
		ret = ckcom.ckExist(FubenConfig, "FubenConfig", data.fbId, "fbId") and ret;
		ret = ckcom.ckReward(data, "rewards", tabName) and ret;
		ret = ckcom.ckReward(data, "items", tabName) and ret;
		ret = ckcom.ckReward(data, "goldSp", tabName) and ret;
		ret = ckcom.ckReward(data, "diamondSp", tabName) and ret;
		ret = ckcom.ckExist(MonstersConfig, "MonstersConfig", data.boss, "boss") and ret;
		ret = ckcom.ckExist(MonstersConfig, "MonstersConfig", data.gate, "gate") and ret;


		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

