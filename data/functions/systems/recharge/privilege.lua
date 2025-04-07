module("privilege",package.seeall)

local autoSystemId = {
	actorexp.LimitTp.boss,
	actorexp.LimitTp.home,
	actorexp.LimitTp.crossboss,
	actorexp.LimitTp.shenmobosscross,
}

local function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then
		return nil
	end
	if var.privilege == nil then
		var.privilege = {}
	end
    if var.privilege.flag == nil then var.privilege.flag = 0 end
    if not var.privilege.auto then var.privilege.auto = {} end
	return var.privilege
end

local function sendMail(actorid)
	local mail_data = {}
	mail_data.head = PrivilegeConfig.mailHead
	mail_data.context = PrivilegeConfig.mailContext
	mail_data.tAwardList = PrivilegeConfig.mailAward
	mailsystem.sendMailById(actorid, mail_data)
end

local function calcAttr(actor, calc)
	local var = getActorVar(actor)
	local attr = LActor.getRoleSystemAttrs(actor, AttrRoleSysId_Privilege)
	attr:Reset()
	if var.flag == 1 then
		for k,v in ipairs(PrivilegeConfig.attr) do
			attr:Set(v.type, v.value)
		end
		attr:SetExtraPower(PrivilegeConfig.power)
	end
	if calc then
		LActor.reCalcAttr(actor)
	end
end

function getFightPlus(actor)
	local var = getActorVar(actor)
	if var.flag == 1 then
		return PrivilegeConfig.quickFightPlus / 10000
	end
	return 0
end

local function sendPrivilegeData(actor)
	local var = getActorVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_PrivilegeData)
	LDataPack.writeChar(npack, var.flag)
	LDataPack.writeChar(npack, #autoSystemId)
	for _, systemId in ipairs(autoSystemId) do
		LDataPack.writeShort(npack, systemId)
		LDataPack.writeChar(npack, var.auto[systemId] or 0)
	end
	LDataPack.flush(npack)
end

local function c2sAutoFight(actor, pack)
	local systemId = LDataPack.readShort(pack)
	local staus = LDataPack.readChar(pack)
	if staus ~= 0 and staus ~= 1 then return end--数据非法，状态记录只能是0和1
	if not isBuyPrivilege(actor) then return end
	if not utils.checkTableValue(autoSystemId, systemId) then return end

	local var = getActorVar(actor)
	var.auto[systemId] = staus

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_PrivilegeAutoFight)
	if not npack then return end
	LDataPack.writeShort(npack, systemId)
	LDataPack.writeChar(npack, var.auto[systemId] or 0)
	LDataPack.flush(npack)
end

function isBuyPrivilege(actor)
	local var = getActorVar(actor)
	return var.flag == 1
end


function buyPrivilege(actor)
	local var = getActorVar(actor)
	var.flag = 1
	sendMail(LActor.getActorId(actor))
	calcAttr(actor, true)
	sendPrivilegeData(actor)

    rechargesystem.addVipExp(actor, PrivilegeConfig.money)

	if LActor.getEquipBagSpace(actor) == 0 then
		LActor.smeltAllEquip(actor)
		actorevent.onEvent(actor, aeSmeltEquip, 1)
	end
	--actoritem.addItem(actor, NumericType_Diamond, PrivilegeConfig.diamond, "privilege buy")
	titlesystem.addTitle(actor, PrivilegeConfig.title, true)
	actorevent.onEvent(actor, aePrivilegeBuy)
	utils.logCounter(actor, "privilege buy")
end

function buy(actorid)
	local actor = LActor.getActorById(actorid)
	if actor then
		buyPrivilege(actor)
	else
		local npack = LDataPack.allocPacket()
		System.sendOffMsg(actorid, 0, OffMsgType_Privilege, npack)
	end
end

function OffMsgPrivilege(actor, offmsg)
	print(string.format("OffMsgPrivilege actorid:%d ", LActor.getActorId(actor)))
	buyPrivilege(actor)
end

local function onInit(actor)
	calcAttr(actor, false)
end

local function onLogin(actor)
	sendPrivilegeData(actor)
end

netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_PrivilegeAutoFight, c2sAutoFight)
msgsystem.regHandle(OffMsgType_Privilege, OffMsgPrivilege)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.buytq = function(actor)
	buyPrivilege(actor)
	return true
end
