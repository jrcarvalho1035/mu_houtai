-- @version	1.0
-- @author	qianmeng
-- @date	2017-10-14 20:08:01.
-- @system	充值提醒

module("remindsystem", package.seeall)
require("limit.remind")

function getDyanmicVar(actor)
	local var = LActor.getGlobalDyanmicVar(actor)
	if not var.remindsys then
		var.remindsys = {
			flag = 0,
		}
	end
	return var.remindsys
end

--进入静态副本
function onEnternStaticFuben(actor)
	s2cRemindRecharge(actor)
end

function onLevelUp(actor, level, oldLevel)
	local dyan = getDyanmicVar(actor)
	for lv = oldLevel+1, level do
		if RemindConfig[lv] then
			dyan.flag = 1
			break
		end
	end
	local fbId = LActor.getFubenId(actor)
	if staticfuben.isStaticFuben(fbId) then --在静态副本内，直接显示
		s2cRemindRecharge(actor)
	end
end

----------------------------------------------------------------------------------------------
function s2cRemindRecharge(actor)
	if LActor.getRecharge(actor) > 0 then return end --已首充不会提醒
	-- local dyan = getDyanmicVar(actor)
	-- if dyan.flag == 0 then return end
	-- local npack = LDataPack.allocPacket(actor,  Protocol.CMD_Other, Protocol.sRemindCmd_Recharge)
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


