-- @version	1.0
-- @author	qianmeng
-- @date	2017-10-24 10:48:59.
-- @system	次留提醒

module("nextdaysystem", package.seeall)
require("limit.nextday")

function getDyanmicVar(actor)
	local var = LActor.getGlobalDyanmicVar(actor)
	if not var.nextdaysys then
		var.nextdaysys = {
			flag = 0,
		}
	end
	return var.nextdaysys
end

--进入静态副本
function onEnternStaticFuben(actor)
	s2cNextDayRemind(actor)
end

function onLevelUp(actor, level, oldLevel)
	local dyan = getDyanmicVar(actor)
	for lv = oldLevel+1, level do
		if NextDayConfig[lv] then
			dyan.flag = 1
			break
		end
	end
	local fbId = LActor.getFubenId(actor)
	if staticfuben.isStaticFuben(fbId) then --在静态副本内，直接显示
		s2cNextDayRemind(actor)
	end
end

----------------------------------------------------------------------------------------------
function s2cNextDayRemind(actor)
	-- local var = activitylogin.getLoginRewardsData(actor)
	-- if (var.login_day or 0) > 1 then return end --第二天或以后就不再提醒
	-- local dyan = getDyanmicVar(actor)
	-- if dyan.flag == 0 then return end
	-- local npack = LDataPack.allocPacket(actor,  Protocol.CMD_Other, Protocol.sRemindCmd_NextDay)
	-- if not npack then return end
	-- LDataPack.flush(npack)
	-- dyan.flag = 0
end

--启动初始化
local function init()
	actorevent.reg(aeLevel, onLevelUp)
	actorevent.reg(aeInterGuajifu, onEnternStaticFuben)
	actorevent.reg(aeInterMainscene, onEnternStaticFuben)
end
table.insert(InitFnTable, init)


