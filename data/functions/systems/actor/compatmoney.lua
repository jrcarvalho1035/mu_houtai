-- 支持跨服和普通服使用的值
module("compatmoney" , package.seeall)



-----------------------跨服天梯荣耀开始-----------------------
function getCSTTVar(actor)
	local var = LActor.getCrossVar(actor)
	if var.cstiantiVar == nil then
		var.cstiantiVar = {}
		var.cstiantiVar.honourValue = 0 --荣耀点
	end
	return var.cstiantiVar
end

function getCSTTHonourValue(actor)
	local data = getCSTTVar(actor)
	return data.honourValue
end

function changeCSTTHonourValue(actor, value)
	if value == 0 then return end

	local data = getCSTTVar(actor)
	local oldValue = data.honourValue
	local newValue = oldValue + value
	if newValue < 0 then
		newValue = 0
	end
	if newValue >= 2147483647 then
		newValue = 2147483647
	end
	data.honourValue = newValue
	return data.honourValue
end
-----------------------跨服天梯荣耀结束-----------------------