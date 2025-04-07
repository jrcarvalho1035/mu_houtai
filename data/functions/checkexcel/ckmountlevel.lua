module("ckmountlevel",package.seeall)
	
function checkExcel()
	local tabName = "MountLevelConfig";
	local rets = true
	for k, data in pairs(MountLevelConfig) do
		local ret = true
		for k1, data1 in pairs(data) do
			ret = ckcom.ckExist(MountConfig, "MountConfig", data1.id, "id") and ret;
			ret = ckcom.ckReward(data1, "consume", tabName) and ret;
			ret = ckcom.ckAttr(data1, "attr", tabName) and ret;
		end
		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

