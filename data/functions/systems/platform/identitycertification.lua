-- @version	1.0
-- @author	youquan
-- @date	2018-6-13
-- @system	实名认证

module("identitycertification", package.seeall)
require("platform.certification")



local function getData(actor) 
	local var = LActor.getStaticVar(actor) 
	if var == nil then 
		return nil 
	end
	if var.identitycertification == nil then 
		var.identitycertification = {}
	end
	return var.identitycertification
end


local function getCertificationAwards(actor)
	local var = getData(actor)
	if var == nil then return false end
	if var.IsCertification then 
		return false
	end

	var.IsCertification = 1
	
	local mail_data = {}
	mail_data.head = SDKConfig.verifyhead
	mail_data.context = SDKConfig.verifycontext
	mail_data.tAwardList = SDKConfig.verifyrewrd
	mailsystem.sendMailById(LActor.getActorId(actor),mail_data)	

	s2cCertificationInfo(actor)

	return true
end

function s2cCertificationInfo(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PlatformActivity, Protocol.sPlatformActivityCmd_IdentityCertification)
	local var = getData(actor)
	if npack == nil or var == nil then return end

	LDataPack.writeByte(npack, var.IsCertification or 0)
	LDataPack.flush(npack)
end

local function onLogin(actor)
	s2cCertificationInfo(actor)
end


local function onGetAwrds(actor,packet)
	getCertificationAwards(actor)
end

actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_PlatformActivity, Protocol.cPlatformActivityCmd_IdentityCertification, onGetAwrds)


