-- @version 1.0
-- @author  qianmeng
-- @date    2017-2-6 21:16:29.
-- @system  版本更新处理

module("actorversion", package.seeall)

version = 2

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return nil end
	if var.versionData == nil then
		var.versionData = {
			version = 1
		}
	end
	return var.versionData
end

local function onLogin(actor)
	local var = getStaticData(actor)
	var.version = version
end

actorevent.reg(aeUserLogin, onLogin)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.setversion = function (actor, args)
	local var = getStaticData(actor)
	var.version = tonumber(args[1])
end
