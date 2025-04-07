-- -- @version	
-- -- @author	qianmeng
-- -- @date	2018-7-30 15:23:01.
-- -- @system	aegis

-- require("aegis.aegiscommon")
-- require("aegis.aegisstar")
-- require("aegis.aegislevel")
-- require("utils.net.netmsgdispatcher")

-- module("aegissystem", package.seeall)

-- local AegisStarConfig = AegisStarConfig
-- local AegisCommonConfig = AegisCommonConfig
-- local AegisLevelConfig = AegisLevelConfig
-- local netmsgdispatcher = netmsgdispatcher


-- --获得玩家神盾信息
-- function getActorVar(actor)
-- 	if not actor then return end
-- 	local var = LActor.getStaticVar(actor)
-- 	if not var then return end
-- 	if not var.aegisdata then var.aegisdata = {} end
-- 	return var.aegisdata
-- end

-- function getActorRoleVar(actor, roleId)
-- 	local actorVar = getActorVar(actor)
-- 	if not actorVar then return end
-- 	if not actorVar[roleId] then
-- 		actorVar[roleId] = {}
-- 		actorVar[roleId].idx = roleId
-- 		actorVar[roleId].lev = 0
-- 		actorVar[roleId].starlev = 0
-- 		actorVar[roleId].exp = 0
-- 		actorVar[roleId].status = 0
-- 	end

-- 	return actorVar[roleId]
-- end

-- --最大神盾星级
-- local function isWingMaxStar(star)
-- 	if (star >= AegisCommonConfig[1].starMax) then
-- 		return true
-- 	end
-- 	return false
-- end

-- function addAegisAttr(actor,roleId)
-- 	local arVar = getActorRoleVar(actor, roleId)
-- 	if arVar ~= nil and arVar.status > 0 then
-- 		local attrList = {}
-- 		local asIdx = arVar.starlev
-- 		local starConfig = AegisStarConfig[asIdx]
-- 		if (starConfig) then
-- 			local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Talent)
-- 			attr:Reset()
-- 			for _,tb in pairs(starConfig.attr) do
-- 				attr:Set(tb.type, tb.value)
-- 			end

-- 			LActor.reCalcAttr(actor, roleId)
-- 		end
-- 	end
-- end

-- --同步神盾数据
-- local function AegisDataSync(actor)
-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Aegis, Protocol.sCMD_Aegis_RespInfo)
-- 	if pack == nil then return end
-- 	LDataPack.writeByte(pack, 1)
-- 	local arVar = getActorRoleVar(actor, 0)
-- 	if not arVar then return end

-- 	LDataPack.writeInt(pack, 0)
-- 	LDataPack.writeInt(pack, arVar.lev)
-- 	LDataPack.writeInt(pack, arVar.starlev)
-- 	LDataPack.writeUInt(pack, arVar.exp)
-- 	LDataPack.writeInt(pack, arVar.status)

-- 	LDataPack.flush(pack)
	
-- 	local arVar = getActorRoleVar(actor, 0)
-- 	if not arVar then return end
-- 	addAegisAttr(actor,0)
-- 	actorevent.onEvent(actor, aeNotifyFacade, 0)
	
-- end

-- --神盾升星
-- function c2sAegisStarLevelup(actor, pack)
-- 	local roleId = LDataPack.readInt(pack)
-- 	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.aegis) then return end
-- 	local arVar = getActorRoleVar(actor, roleId)
-- 	local asIdx = arVar.starlev
-- 	if arVar.status == 0 or AegisStarConfig[asIdx].exp == 0 then
-- 	 	return 
-- 	 end

-- 	local num = AegisLevelConfig[arVar.lev].needNum
-- 	if arVar.exp + num >= AegisStarConfig[asIdx].exp then
-- 		if AegisStarConfig[asIdx + 1] ~= nil then
-- 			arVar.exp = arVar.exp + num - AegisStarConfig[asIdx].exp
-- 			asIdx = asIdx + 1
-- 			if arVar.exp > AegisStarConfig[asIdx].exp then
-- 				num = num - arVar.exp
-- 				arVar.exp = 0
-- 			end

-- 			arVar.lev = math.floor(asIdx/11) + 1
-- 			arVar.starlev = asIdx
-- 			local pack = LDataPack.allocPacket(actor, Protocol.CMD_Aegis, Protocol.sCMD_Aegis_RespStarLevUp)
-- 			if pack == nil then return end
-- 			LDataPack.writeInt(pack, roleId)
-- 			LDataPack.writeInt(pack, arVar.lev)
-- 			LDataPack.writeInt(pack, asIdx)
-- 			LDataPack.writeUInt(pack, arVar.exp)
-- 			LDataPack.writeUInt(pack, num)
-- 			LDataPack.flush(pack)

-- 			addAegisAttr(actor,roleId)
-- 		end
-- 	else
-- 		local needNum = AegisLevelConfig[arVar.lev].needNum
-- 		local needId = AegisCommonConfig[1].expItemId
-- 		if actoritem.checkItem(actor, needId, needNum) == false then 
-- 			return 
-- 		end
-- 		actoritem.reduceItem(actor, needId, needNum, "Aegis Exp up")

-- 		arVar.exp = arVar.exp + needNum;
-- 		local pack = LDataPack.allocPacket(actor, Protocol.CMD_Aegis, Protocol.sCMD_Aegis_RespStarLevUp)
-- 		if pack == nil then return end
-- 		LDataPack.writeInt(pack, roleId)
-- 		LDataPack.writeInt(pack, arVar.lev)
-- 		LDataPack.writeInt(pack, asIdx)
-- 		LDataPack.writeUInt(pack, arVar.exp)
-- 		LDataPack.writeUInt(pack, needNum)
-- 		LDataPack.flush(pack)
-- 	end
-- end

-- --神盾升阶接口
-- function c2sAegisLevelup(actor, pack)
-- 	local roleId = LDataPack.readInt(pack)
-- 	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.aegis) then return end
-- 	local arVar = getActorRoleVar(actor, roleId)
-- 	if not arVar then return end
-- 	local asIdx = arVar.starlev
-- 	if arVar.exp ~= 0  or arVar.status == 0 then return end
-- 	if AegisStarConfig[asIdx + 1] == nil then return end -- 最高级不能升级
-- 	asIdx = asIdx + 1
-- 	arVar.exp = 0
-- 	arVar.lev = math.floor(asIdx/11) + 1
-- 	arVar.starlev = asIdx
-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Aegis, Protocol.sCMD_Aegis_RespLevUp)
-- 	if pack == nil then return end
-- 	LDataPack.writeInt(pack, roleId)
-- 	LDataPack.writeInt(pack, arVar.lev)
-- 	LDataPack.writeInt(pack, asIdx)
-- 	LDataPack.writeUInt(pack, arVar.exp)
-- 	LDataPack.flush(pack)

-- 	addAegisAttr(actor,roleId)
-- 	actorevent.onEvent(actor, aeNotifyFacade, roleId)
-- end

-- --神盾激活接口
-- function c2sAegisOpenSys(actor, pack)
-- 	local roleId = LDataPack.readInt(pack)

-- 	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.aegis) then return end
-- 	local arVar = getActorRoleVar(actor, roleId)
-- 	if not arVar then return end
-- 	if arVar.status > 0 then return end
-- 	arVar.status = 1
-- 	arVar.lev = 1
-- 	arVar.starlev = 0
-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Aegis, Protocol.sCMD_Aegis_ReqOpenSys)
-- 	if pack == nil then return end

-- 	LDataPack.writeInt(pack, roleId)
-- 	LDataPack.writeInt(pack, arVar.lev)
-- 	LDataPack.writeInt(pack, arVar.starlev)
-- 	LDataPack.writeUInt(pack, arVar.exp)
-- 	LDataPack.writeInt(pack, arVar.status)
-- 	LDataPack.flush(pack)

-- 	addAegisAttr(actor,roleId)
-- 	actorevent.onEvent(actor, aeNotifyFacade, roleId)
-- end

-- _G.aegisAttrInit = function(actor, roleId)
-- 	-- 先清空神盾属性系统的属性
-- end

-- --玩家登陆回调
-- function onLogin(actor)
-- 	AegisDataSync(actor) --发送神盾数据
-- end

-- actorevent.reg(aeUserLogin, onLogin)
-- netmsgdispatcher.reg(Protocol.CMD_Aegis, Protocol.cCMD_Aegis_ReqStarLevUp, c2sAegisStarLevelup)
-- netmsgdispatcher.reg(Protocol.CMD_Aegis, Protocol.cCMD_Aegis_ReqLevUp, c2sAegisLevelup)
-- netmsgdispatcher.reg(Protocol.CMD_Aegis, Protocol.cCMD_Aegis_ReqOpenSys, c2sAegisOpenSys)

-- local gmCmdHandlers = gmsystem.gmCmdHandlers

-- gmCmdHandlers.setAegis = function (actor, args)
-- 	local roleId = tonumber(args[1] or 0)
-- 	local level = tonumber(args[2] or 0)
-- 	local slevel = tonumber(args[3] or 0)
-- 	local exp = tonumber(args[4] or 0)
-- 	local arVar = getActorRoleVar(actor, roleId)
-- 	if not arVar then return end

-- 	if level == 0 and slevel == 0 then
-- 		arVar.lev = 0
-- 		arVar.starlev = 0
-- 		arVar.status = 0
-- 		arVar.exp = 0
-- 	else
-- 		arVar.lev = level + 1
-- 		arVar.starlev = level * 11 + slevel
-- 		arVar.status = 1
-- 		arVar.exp = exp
-- 	end

-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Aegis, Protocol.sCMD_Aegis_ReqOpenSys)
-- 	if pack == nil then return end
-- 	LDataPack.writeInt(pack, roleId)
-- 	LDataPack.writeInt(pack, arVar.lev)
-- 	LDataPack.writeInt(pack, arVar.starlev)
-- 	LDataPack.writeUInt(pack, arVar.exp)
-- 	LDataPack.writeInt(pack, arVar.status)
-- 	LDataPack.flush(pack)

-- 	addAegisAttr(actor,roleId)
-- 	actorevent.onEvent(actor, aeNotifyFacade, roleId)
-- 	return true
-- end

-- gmCmdHandlers.setAegisExp = function (actor, args)
-- 	local roleId = tonumber(args[1] or 0)
-- 	local exp = tonumber(args[2] or 0)
-- 	local arVar = getActorRoleVar(actor, roleId)
-- 	if not arVar then return end

-- 	arVar.status = 1
-- 	arVar.exp = exp

-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Aegis, Protocol.sCMD_Aegis_ReqOpenSys)
-- 	if pack == nil then return end
-- 	LDataPack.writeInt(pack, roleId)
-- 	LDataPack.writeInt(pack, arVar.lev)
-- 	LDataPack.writeInt(pack, arVar.lev * 11 + arVar.starlev)
-- 	LDataPack.writeUInt(pack, arVar.exp)
-- 	LDataPack.writeInt(pack, arVar.status)
-- 	LDataPack.flush(pack)

-- 	return true
-- end

-- local function getAegisLevel(actor, roleId)
-- 	local arVar = getActorRoleVar(actor, roleId)
-- 	return arVar.lev
-- end

-- _G.getAegisLevel = getAegisLevel
