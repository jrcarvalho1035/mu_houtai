module("weixiguanzhu", package.seeall)
require("platform.weixiguanzhu")










local function getData(actor) 
	local var = LActor.getStaticVar(actor) 
	if var == nil then 
		return nil 
	end
	if var.weixi == nil then 
		var.weixi = {}
	end
	return var.weixi
end


local function getGuanZhuAwards(actor)
	local var = getData(actor)
	if var.guan_zhu then 
		return false
	end
	var.guan_zhu = 1
	-- local mail_data = {}
	-- mail_data.head = WeiXiGuanZhuConst.head
	-- mail_data.context = WeiXiGuanZhuConst.context
	-- mail_data.tAwardList = WeiXiGuanZhuConst.awards
	-- mailsystem.sendMailById(LActor.getActorId(actor),mail_data)	

	actoritem.addItems(actor, SDKConfig.guanzhurewrd, "wx guanzhu")
	s2cGuanzhuInfo(actor)
	return true
end

function s2cGuanzhuInfo(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PlatformActivity, Protocol.sPlatformActivityCmd_WeiXiGuanZhu)
	local var = getData(actor)
	if npack == nil or var == nil then return end

	LDataPack.writeByte(npack, var.guan_zhu or 0)
	LDataPack.flush(npack)
end

local function onLogin(actor)
	s2cGuanzhuInfo(actor)
end


local function onGetAwrds(actor,packet)
	getGuanZhuAwards(actor)
end
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_PlatformActivity, Protocol.cPlatformActivityCmd_WeiXiGuanZhu, onGetAwrds)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.wxguanzhureward = function (actor, args)
	-- getGuanZhuAwards(actor)
end

