-- @version	1.0
-- @author	rancho
-- @date	2019-05-31 
-- @system  改名卡
module("changename", package.seeall)

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var.ChangeName then var.ChangeName = {} end
	local ChangeName = var.ChangeName
	if not ChangeName.ChangeNameCD then ChangeName.ChangeNameCD = 0 end
	return ChangeName
end

function changeName(actor, packet)
	if chatcommon.isLimitChat(actor) then return end
	local conf = ChangeNameCardConf
	local var = getActorVar(actor)
	if var == nil then return end

	--改名cd未到
	local now_t = System.getNowTime()
	if (now_t - var.ChangeNameCD) < conf.timeCD then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_ChangeName)
		if npack == nil then return end
		LDataPack.writeChar(npack, (-1))
		LDataPack.flush(npack)
		return
	end

	local name = LDataPack.readString(packet)
	if name == nil then return end
	name = name
	local rawName = LActor.getName(actor)

	--跟现在的名字是否相同
	if rawName == name then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_ChangeName)
		if npack == nil then return end
		LDataPack.writeChar(npack, (-6))
		LDataPack.flush(npack)
		return
	end

	--长度是否合法
	local nameLen = System.getStrLenUtf8(name)
	if nameLen <= 4 or nameLen > 12 or not LActorMgr.checkNameStr(name) then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_ChangeName)
		if npack == nil then return end
		LDataPack.writeChar(npack, (-12))
		LDataPack.flush(npack)
		return
	end

	--道具是否足够
	if not actoritem.checkItem(actor, conf.needItemId, 1) then return end
	name = LActor.getServerName(actor).."."..name
	LActor.changeName(actor, name)
end

local rankListNames = 
{

}

--改名
onChangeName = function(actor, res, name, rawName, way)
	if System.isCrossWarSrv() then return end
	way = way or ChangeNameWay_Normal
	if name == nil or rawName == nil then return end
	local conf = ChangeNameCardConf

	--改名不合法
	if res ~= 0 then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_ChangeName)
		if npack == nil then return end
		LDataPack.writeChar(npack, res)
		LDataPack.flush(npack)
		return
	end

	local var = getActorVar(actor)
	if var == nil then return end

	if way == ChangeNameWay_Normal then
		--道具是否足够
		if not actoritem.checkItem(actor, conf.needItemId, 1) then return end
		actoritem.reduceItem(actor, conf.needItemId, 1, "change name")
		var.ChangeNameCD = System.getNowTime()
	end

	local aId = LActor.getActorId(actor)
	LActor.setEntityName(actor, name)

	--log
	local logStr = string.format("%s_%s", rawName, name)
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "changeName", logStr, "", "", "", "", "", "", lfDB)

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_ChangeMemberName)
	LDataPack.writeInt(npack, aId)
	LDataPack.writeString(npack, name)
	System.sendPacketToAllGameClient(npack, 0)

	--通知客户端名字修改成功
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_ChangeName)
	if npack == nil then return end
	LDataPack.writeChar(npack, 0)
	LDataPack.flush(npack)
end

function onChangeMemberName(sId, sType, cpack)
	if not System.isBattleSrv() then return end
	local actorid = LDataPack.readInt(cpack)
	local name = LDataPack.readString(cpack)
	LGuild.changeMemberName(actorid, name)
	subactivity34.onChangeName(actorid, name)
	subactivity30.onChangeName(actorid, name)
	subactivity33.onChangeName(actorid, name)
	subactivity36.onChangeName(actorid, name)
	dartrank.onChangeName(actorid, name)
end

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_ChangeMemberName, onChangeMemberName)

local function init()
	if System.isCrossWarSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.cBaseCmd_ChangeName, changeName) -- 使用改名卡改名
end

table.insert(InitFnTable, init)
actorevent.reg(aeChangeName, onChangeName, 1)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.changename = function(actor, args)
	local name = args[1]
	if not name then return end
	local pack = LDataPack.allocPacket()
	LDataPack.writeString(pack, name)
	LDataPack.setPosition(pack, 0)
	changeName(actor, pack)
	return true
end
