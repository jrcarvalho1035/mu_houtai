module("sdkapi", package.seeall)

require("dbprotocol")
require("sdk.sdk")



--邀请好友分享奖励的appid列表
SharedChannelAppIdList = {"", '2000005', '2000004', '2000007', '2000012', '2000003', '2000014', '2000013', '2000010' }


local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return nil end

	if var.SDKData == nil then
		var.SDKData = {}
	end
	return var.SDKData
end
--[[
	微信分享数据
	wxSharedTime    已分享次数
	wxLastSharedTime 上次分享时间
--]]

--充值回调
function onFeeCallback(packet)
	if not System.isCommSrv() then return end
	--@rancho 20170914
	--itemid:元宝数量
	--num:现在已经无用
	local openid, itemid, num, actorid = LDataPack.readData(packet, 4, dtString, dtInt, dtInt,dtInt)
	print(string.format("onFeeCallback:recv fee data:%s, %d, %d , %d ", openid, itemid, num, actorid));

	local count = itemid

	if yyqgsystem.yyqgisbuy(count) then ----一元抢购
		yyqgsystem.buy(actorid,count)
	elseif yymssystem.oneisbuy(count) then ----一元秒杀
		yymssystem.buy(actorid,count)
	elseif yyms2system.isBuy(count) then -- 一元秒杀2
		yyms2system.buy(actorid, count)
	elseif svipmssystem.sviponeisbuy(count) then ----svip秒杀
		svipmssystem.buy(actorid, count)
	elseif count == FirstRechargeConfig[1].pay then ----首冲
		firstchargeactive.buy(actorid, count)
	elseif count == MonthCardConfig.money then --月卡
		monthcard.buy(actorid)
	elseif count == PrivilegeConfig.money then --特权卡购买
		privilege.buy(actorid)
	elseif count == RechagePowerConstConfig.zclbuycount then --黄金圣龙
		dragonsystem.buy(actorid)
	elseif count == RechagePowerConstConfig.zlxzbuycount then --战力勋章
		zlxzsystem.buy(actorid)
	elseif count == RechagePowerConstConfig.grailbuycount then --不朽圣杯
		grailsystem.buy(actorid)
	elseif count == YongZheConfig.vipExp then -- 勇者圣徵
		yongzhe.buy(actorid)
	elseif subactivity11.isActivity11(count) then --活动11
		subactivity11.buy(actorid, count)
	elseif zhenhongsystem.isZHXG(count) then --真红限购礼包
		zhenhongsystem.buy(actorid, count)
	elseif subactivity39.isActivity39(count) then --活动39
		subactivity39.buy(actorid, count)
	elseif count == HaloConfig.money then --主角光环购买
		halosystem.buy(actorid)
	else --正常元宝充值
		local actor = LActor.getActorById(actorid)
		if actor then
			local config = PayMoneyConfig[count]
			if config then
				local vipExp = rechargesystem.getVipExpByPf(actor, count)
				LActor.addRecharge(actor, vipExp, count)
			else
				LActor.addRecharge(actor, count, count)
			end
		else
			local npack = LDataPack.allocPacket()
			LDataPack.writeInt(npack, count)
			System.sendOffMsg(actorid, 0, OffMsgType_Recharge, npack)
		end
	end

	-- local temStr = "http://%s/%s/cdk?type=2&chid=%s&cdkey=%s"
	-- local url = string.format(temStr, webhost, pf, appid, code)
	-- sendMsgToWeb(url, onResultCheck, {aid, id, code})
end

function OffMsgRecharge(actor, offmsg)
	local count = LDataPack.readInt(offmsg)
	if count <= 0 then return end
	local yb = count
	local config = PayMoneyConfig[count]
	if config then
		yb = config.vipExp
	end
	print(string.format("OffMsgRecharge actorid:%d yb:%d", LActor.getActorId(actor), yb))
	LActor.addRecharge(actor, yb, count)
end

--爱微游5级的时候要上报一次,发给后台/前端处理
local function onLevelUp(actor, level, oldLevel)
	if oldLevel < 15 and level >= 15 then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_PlatformActivity, Protocol.sPlatformActivityCmd_15LevelNotify)
		if npack == nil then return end

		LDataPack.flush(npack)
	end
end

local function onResultCheck(params, retParams)
	--local actor = LActor.getActorById(params[1])
	--if actor == nil then return end

	local content = retParams[1]
	local ret = retParams[2]

	print("ret:"..ret)
	print("content:"..tostring(content))
end

-- --爱微游创角处理
-- local function onFirstLogin(actor, isFirst)
-- 	if isFirst == 1 then
-- 		LActor.postScriptEventLite(actor, 5000, onFirstLoginReport)
-- 	end
-- end


-----------------------------------微信分享--------------------------------------------------------------
--判断这个平台是否有分享奖励
local function checkSharedChannel(pf)
	for _, appid in ipairs(SharedChannelAppIdList) do
		if pf == appid then return true end
	end
	--return false
	return true --不限制平台分享
end


local function notifyWXInfo(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PlatformActivity, Protocol.sPlatformActivityCmd_WeiXinShare)
	local data = getStaticData(actor)
	if npack == nil or data == nil then return end

	local time = math.max(0, (data.wxLastSharedTime or 0) + SDKConfig.shareInterval - System.getNowTime()) --剩余时间
	LDataPack.writeInt(npack, data.wxSharedTime or 0)
	LDataPack.writeInt(npack, time)
	LDataPack.flush(npack)
end

local function onNewDay(actor)
	local pf = LActor.getPfId(actor)
	if not checkSharedChannel(pf) then return end
	local data = getStaticData(actor)
	data.wxSharedTime = 0
	data.wxLastSharedTime = 0
	notifyWXInfo(actor)

	--LActor.postScriptEventLite(actor, 5000, onNewDayReport)
end

-- function onNewDayReport(actor)
-- 	local basicData = LActor.getActorData(actor)
-- 	local webhost, webport = System.getWebServer()
-- 	local temStr = "http://%s/%s/rebate/simulateRecharge?account=%s&role_id=%d&server_id=%d&pfid=%d"
-- 	local url = string.format(temStr, webhost, LActor.getPf(actor), basicData.account_name, LActor.getActorId(actor), basicData.server_index, LActor.getPfId(actor))
-- 	sendMsgToWeb(url, onResultCheck, {})
-- end

-- function onFirstLoginReport(actor)
-- 	local basicData = LActor.getActorData(actor)
-- 	local webhost, webport = System.getWebServer()
-- 	local temStr = "http://%s/%s/rebate/normalRebate?account=%s&role_id=%d&server_id=%d&pfid=%d"
-- 	local url = string.format(temStr, webhost, LActor.getPf(actor), basicData.account_name, LActor.getActorId(actor), basicData.server_index, LActor.getPfId(actor))
-- 	sendMsgToWeb(url, onResultCheck, {})
-- end

local function onLogin(actor, isFirst)
	local pf = LActor.getPfId(actor)
	if not checkSharedChannel(pf) then return end
	notifyWXInfo(actor)
end

--进行微信分享领奖
function onGetShareReward(actor, packet)
	local pf = LActor.getPfId(actor)
	if not checkSharedChannel(pf) then return end

	local data = getStaticData(actor)
	if pf == '2000007' then -- 新浪渠道特殊处理暂时
		if (data.wxSharedTime or 0) >= 1 then
			print("wx share invalid. r:count, a:"..LActor.getActorId(actor))
			return
		end
	end
	if (data.wxSharedTime or 0) >= SDKConfig.shareCount then --今日分享次数达到上限
		print("wx share invalid. r:count, a:"..LActor.getActorId(actor))
		return
	end

	if System.getNowTime() - (data.wxLastSharedTime or 0) < SDKConfig.shareInterval then --冷却时间未过
		print("wx share invalid. r:interval, a:"..LActor.getActorId(actor))
		return
	end

	data.wxSharedTime = (data.wxSharedTime or 0) + 1
	data.wxLastSharedTime = System.getNowTime()
	actoritem.addItems(actor, SDKConfig.shareReward, "wx share")
	notifyWXInfo(actor)
end


msgsystem.regHandle(OffMsgType_Recharge, OffMsgRecharge)

dbretdispatcher = require("utils.net.dbretdispatcher")
dbretdispatcher.reg(dbTxApi, DbCmd.TxApiCmd.sFeeCallBack, onFeeCallback)

netmsgdispatcher.reg(Protocol.CMD_PlatformActivity, Protocol.cPlatformActivityCmd_WeiXinShare, onGetShareReward)

actorevent.reg(aeLevel, onLevelUp)
--actorevent.reg(aeUserLogin, onFirstLogin)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.wxsharereward = function (actor, args)
	onGetShareReward(actor)
	return true
end

gmCmdHandlers.trmsg = function (actor, args)
	local count = tonumber(args[1])
	local actorid = LActor.getActorId(actor)
	actorid = tonumber(args[2])
	print("gmCmdHandlers.trmsg actorid:" .. actorid)

	local npack = LDataPack.allocPacket()
	LDataPack.writeInt(npack, count)
	System.sendOffMsg(actorid, 0, OffMsgType_Recharge, npack)
	return true
end

gmCmdHandlers.chongzhi = function(actor, args)
    local count = tonumber(args[1])
    local actorid = tonumber(args[2]) or LActor.getActorId(actor)
    local packet = LDataPack.allocPacket()
    LDataPack.writeData(packet, 4, dtString, "ceshi", dtInt, count, dtInt, count, dtInt, actorid)
    LDataPack.setPosition(packet, 0)
    onFeeCallback(packet)
    return true
end

gmCmdHandlers.tttt = function(actor, args)
    -- onFirstLoginReport(actor)
    return true
end
