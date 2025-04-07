--礼包兑换码
module("giftcode", package.seeall)
require("giftcode.giftcode")
require("giftcode.channelgiftcode")

--[[

 giftCodeData = {
	[id]= 1 已领取
 }
--]]
local CODE_SUCCESS = 0
local CODE_INVALID = 1 --已被使用
local CODE_NOTEXIST = 2
local CODE_USED = 3 --已使用过同类型
local CODE_ERR = 4

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then
		print("get gift code data error.")
	end

	if var.giftCodeData == nil then
		var.giftCodeData = {}
	end
	return var.giftCodeData
end

local function getChanConf(code, pfid)
	for k, v in pairs(ChannelGiftCodeConfig) do
		if v.code == code and tostring(v.pfid) == pfid then
			return v
		end
	end
	return nil
end

--Obtenha o código de ativação
local function getCodeId(code)
	local len = string.byte(string.sub(code, -1)) - 97
	local pos = string.byte(string.sub(code, -2,-2)) - 97

	local str = string.sub(code, pos + 1, pos + len)
	local id = 0
	for i=1, string.len(str) do
		id = id * 10 + (math.abs(string.byte(string.sub(str, i, i)) - 97))
	end
	return id
end

--Detectar código de resgate de pacote de presente
local function checkCode(actor, code)
	if string.len(code) ~= 16 then
		print("gift code error")
		return CODE_ERR
	end
	local id = getCodeId(code)
	if id == 0 then
		print("gift code id is 0")
		return CODE_ERR
	end

	local conf = GiftCodeConfig[id]
	if conf == nil or conf.gift == nil then
		print("gift code config is nil "..tostring(id))
		return CODE_ERR
	end

	local data = getStaticData(actor)
	if (data[id] or 0) >= (conf.count or 1) then
		print("gift code is used")
		return CODE_USED
	end

	return CODE_SUCCESS, id
end

function getgift(actorId, code)
	local conf = nil
	for i=1, #ChannelGiftCodeConfig do
		if ChannelGiftCodeConfig[i].code == code then
			conf = ChannelGiftCodeConfig[i]
			break
		end
	end
	
	if not conf then
		local id = getCodeId(code)
		if id == 0 then
			print("gift code is 0")
			return
		end
		conf = GiftCodeConfig[id]
	end

	if conf == nil or conf.gift == nil then
		print("gift code config is nil :"..tostring(id))
		return
	end

	--enviar email
	local mailData = {head=conf.mailTitle, context=conf.mailContent, tAwardList=conf.gift}
	mailsystem.sendMailById(actorId, mailData)

	local actor = LActor.getActorById(actorId)
	if actor then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
		if npack == nil then return end
		LDataPack.writeByte(npack, CODE_SUCCESS)
		LDataPack.flush(npack)
	end
	print("use gift code success", code)
end

function checkTimeAndAppId(actor, conf)
	--渠道id验证
	local appId = LActor.getAppId(actor)
	if conf.appId ~= "" and conf.appId ~= appId then
		print("appId error", conf.appId, appId)
		return false
	end

	--时间验证
	--starttime
	local Y,M,d = string.match(conf.starttime, "(%d+)%.(%d+)%.(%d+)")
	if Y == nil or M == nil or d == nil then
		print("time config error")
		return false
	end
	local st = System.timeEncode(Y, M, d, 0, 0, 0)
	--endTime
	local Y,M,d = string.match(conf.endtime, "(%d+)%.(%d+)%.(%d+)")
	if Y == nil or M == nil or d == nil then
		print("time config error")
		return false
	end
	local et = System.timeEncode(Y, M, d, 23, 59, 59)

	local ct = System.getNowTime()
	if ct < st or ct > et then
		print("out of data time")
		return false
	end
	return true
end

--处理web返回
local function onResultCheck(params, retParams)
	local actor = LActor.getActorById(params[1])
	if actor == nil then return end

	local content = retParams[1]
	local ret = retParams[2]
	if ret ~= 0 then return end

	local res = tonumber(content)
	if res == nil then
		print("onGiftCode response nil.")
		print("content:"..content)
		return
	end

	if res == CODE_SUCCESS then
		local id = params[2]
		local code = params[3]
		local data = getStaticData(actor)

		local conf = GiftCodeConfig[id]
		if conf == nil or conf.gift == nil then
			print("gift code config is nil :"..tostring(id))
			return
		end

		if (data[id] or 0) >= (conf.count or 1) then
			print("onGiftCode result check count:"..(data[id] or 0))
			return
		end --再次检查是否使用过,因为异步问题

		data[id] = (data[id] or 0) + 1

		if not checkTimeAndAppId(actor, conf) then
			print("gift code time over", id)
			return
		end

		--actoritem.addItems(actor, conf.gift, "gift code "..tostring(id))

		--发邮件
		local mailData = {head=conf.mailTitle, context=conf.mailContent, tAwardList=conf.gift}
		mailsystem.sendMailById(LActor.getActorId(actor), mailData)
		print("gift code get success", LActor.getActorId(actor), id, code)
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
	if npack == nil then return end

	LDataPack.writeByte(npack, res)
	LDataPack.flush(npack)
end

--检测平台激活码
local function checkChannelCode(actor, code)
	if code == nil or code == "" then
		return CODE_ERR
	end
	if string.len(code) > 28 then
		return CODE_ERR
	end
	local pfid = LActor.getPfId(actor)
	local conf = getChanConf(code, pfid)
	if conf == nil or conf.gift == nil then
		return CODE_ERR
	end

	local data = getStaticData(actor)
	if (data[code] or 0) >= 1 then --已领取过这激活码的奖励
		return CODE_USED
	end

	--平台id验证
	
	print("giftcode.checkChannelCode  pfid:", pfid)
	if pfid ~= "" and tostring(conf.pfid) ~= pfid then
		print("pfid error", data.pfid, pfid)
		return CODE_ERR
	end
	if not checkTimeAndAppId(actor, conf) then
		return
	end

	return CODE_SUCCESS
end

--领取平台激活码奖励
local function giveChannelCodeReward(actor, code)
	local pfid = LActor.getPfId(actor)
	local conf = getChanConf(code, pfid)
	if conf == nil then return end
	local data = getStaticData(actor)
	if data == nil then return end

	data.pf = pfid --记录渠道id
	data[code] = (data[code] or 0) + 1 --记录激活码

	--发邮件
	local mailData = {head=conf.mailTitle, context=conf.mailContent, tAwardList=conf.gift}
	mailsystem.sendMailById(LActor.getActorId(actor), mailData)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
	if npack == nil then return end

	LDataPack.writeByte(npack, CODE_SUCCESS)
	LDataPack.flush(npack)
end

--发送web验证
local function postCodeCheck(code, aid, id, pf, appid)
	local webhost, webport = System.getWebServer()
	--应后台需求appid修改成chid rancho 20180731
	local temStr = "http://%s/%s/cdk?type=2&chid=%s&cdkey=%s"
	local url = string.format(temStr, webhost, pf, appid, code)
	sendMsgToWeb(url, onResultCheck, {aid, id, code})
end

--使用渠道激活码
local function getChannelCode(actor, code)
	local ret, id = checkChannelCode(actor, code)
	if ret ~= CODE_SUCCESS then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
		if npack == nil then return end

		LDataPack.writeByte(npack, ret or 4)
		LDataPack.flush(npack)
		return
	end
	giveChannelCodeReward(actor, code)
end

local function getNormalCode(actor, code)
	local ret, id = checkCode(actor, code)
	print("getNormalCode ret = ".. ret)
	if ret ~= CODE_SUCCESS then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
		if npack == nil then return end

		LDataPack.writeByte(npack, ret or 4)
		LDataPack.flush(npack)
		return
	end
	postCodeCheck(code, LActor.getActorId(actor), id, LActor.getPf(actor), LActor.getAppId(actor))
end

local function isChannelCode(actor, code)
	local pfid = LActor.getPfId(actor)
	local conf = getChanConf(code, pfid)
	if conf and conf.pfid then
		return true
	end
	return false
end

local function onGetGift(actor, packet)
	if System.isCrossWarSrv() then
		LActor.sendTipmsg(actor, ScriptTips.gifttip001, ttScreenCenter)
		return
	end
	local code = LDataPack.readString(packet)
	if isChannelCode(actor, code) then
		getChannelCode(actor, code)
	else
		getNormalCode(actor, code)
	end
end

function gmTest(actor, code)
	local ret, id = checkCode(actor, code)
	if ret ~= CODE_SUCCESS then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
		if npack == nil then return end

		LDataPack.writeByte(npack, ret)
		LDataPack.flush(npack)
		return
	end
	postCodeCheck(code, LActor.getActorId(actor), id, LActor.getAppId(actor))
end


function onInit(actor, offtime, logout_t_, first_login_)
    if first_login_ and LActor.getAppId(actor) == "20021" then
        
        local mail_data = {}
        mail_data.head = GiftCodeConfig[11009].mailTitle
        mail_data.context = GiftCodeConfig[11009].mailContent
        mail_data.tAwardList = GiftCodeConfig[11009].gift
        mailsystem.sendMailById(LActor.getActorId(actor), mail_data)
    end
end

--/report?counter=load&key=3e6d590812e1f1d370c135feeef60f97&data=3|2012|6c8b1949748251b9f87ef4ee0b267f9e|load|loaded|0|2|114.139.195.57|2020-02-13%2013-19-51|20030|0
--pfrom_id|server_id|account|counter|kingdom|is_new|exts|ip|logdate|channel|level
--主要就是pfrom_id，server_id，account，counter填load，kingdom填logout，logdate填退出时间，

actorevent.reg(aeInit, onInit)

netmsgdispatcher.reg(Protocol.CMD_Gift, Protocol.cGiftCodeCmd_GetGift, onGetGift)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.giftcode = function(actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeString(pack, args[1])
	LDataPack.setPosition(pack, 0)
	onGetGift(actor, pack)
	return true
end
