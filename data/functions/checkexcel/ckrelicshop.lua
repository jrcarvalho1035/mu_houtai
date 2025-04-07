module("ckrelicshop",package.seeall)
	
function checkExcel()
	local tabName = "RelicShopConfig";
	local rets = true
	for k, data in pairs(RelicShopConfig) do
		local ret = true

		ret = ckcom.ckRewardNumber(data.item.id, data.item.count) and ret;
		ret = ckcom.ckRewardNumber(data.cost.id, data.cost.count) and ret;
		ret = ckcom.ckRewardNumber(data.original.id, data.original.count) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

