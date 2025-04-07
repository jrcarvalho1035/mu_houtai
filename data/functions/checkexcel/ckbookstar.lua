module("ckbookstar",package.seeall)
	
function checkExcel()
	local tabName = "BookStarConfig";
	local rets = true
	for k, data in pairs(BookStarConfig) do
		local ret = true
		
		ret = ckcom.ckAttr(data, "attr", tabName) and ret;

		ckcom.ckFail(ret, tabName, k)
		rets = rets and ret
	end
	return ckcom.ckFails(rets, tabName)
end

