--混乱之渊(跨服BOSS)，移植沙城
module("crossbosshomesys", package.seeall)

require("crossbosshome.crossbosscommon")
require("crossbosshome.crossbossfuben")

local CrossBossFubenConfig = CrossBossFubenConfig
local CrossBossCommonConfig = CrossBossCommonConfig


local CrossSrvCmd = CrossSrvCmd
local CrossSrvSubCmd = CrossSrvSubCmd

function getSystemVar()
	--if System.getBattleSrvFlag() == bsMainBattleSrv then
	if not System.isCommSrv() then
		local s_var = System.getStaticVar()
		if s_var.crossbosshomevar == nil then s_var.crossbosshomevar = {} end
		return s_var.crossbosshomevar
	else
		local d_var = System.getDyanmicVar()
		if d_var.crossbosshomevar == nil then d_var.crossbosshomevar = {} end
		return d_var.crossbosshomevar
	end
end


--
function getAbyssStaticVar(actor)
	local var = LActor.getCrossVar(actor)
	if var.crossbosshomedata == nil then 
		var.crossbosshomedata = {}
		crossbosshomedata = var.crossbosshomedata
		crossbosshomedata.cnt = 0--CrossBossCommonConfig.belongtime --归属次数
		crossbosshomedata.stamp = 0 --上次进入副本时间剩余秒数
		crossbosshomedata.clearTime = 0 --重置数据短时间戳
		crossbosshomedata.lasttick = 0 --上次登录时间戳
		crossbosshomedata.buycount = 0 --购买次数
		crossbosshomedata.reminds = {} --关注
	end	
	return var.crossbosshomedata
end

function isOpen()
	return true
	-- local data = getAbyssSystemVar()
	-- if data.status and 0 ~= data.status then
	-- 	return true
	-- end
	-- return false
end

function getAbyssCnt(actor)
	if not actor then return 1024 end
	local data = getAbyssStaticVar(actor)
	return data.cnt
end

function changeAbyssCnt(actor, value)
	print("changeAbyssCnt begin")
	if not actor then return false end
	local data = getAbyssStaticVar(actor)
	data.cnt = data.cnt + value
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
		"othersystem", tostring(data.cnt), "", "abysssys", "", "belongCnt", "","")

	syncActorAbyssInfo(actor)
	actorevent.onEvent(actor, aeCrossBossBelong, 1)
	return true
end

function syncActorAbyssInfo(actor)
	print("syncActorAbyssInfo begin")
	local data = getAbyssStaticVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsBosshome_UserIfno)
	if npack == nil then return end
	LDataPack.writeByte(npack, data.cnt)
	local now_t = System.getNowTime()
	if data.stamp < now_t then
		data.stamp = 0
	else
		data.stamp = data.stamp - now_t
	end
	LDataPack.writeInt(npack, data.stamp)
	LDataPack.writeByte(npack, data.buycount or 0)
	LDataPack.flush(npack)
end

-- function syncAdjust(actor, adj)
-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Abyss, Protocol.sAbyssCmd_SyncIsAdjust)
-- 	if pack then
-- 		LDataPack.writeByte(pack, adj)
-- 		LDataPack.flush(pack)
-- 	end
-- end

function synAbyssSys(actor)
	--print("synAbyssSys begin")
	--下发boss数据
	crossbosshomefb.sendAllBossInfo(actor)
	--下发玩家数据
	syncActorAbyssInfo(actor)
end


function onLogin(actor)
--	syncIsOpen2Player(actor)
	--print("onLogin begin")
	synAbyssSys(actor)

	-- local now_t = System.getNowTime()
	-- local Y,M,d, _, _, _ = System.timeDecode(now_t)
	-- local min = System.timeEncode(Y,M,d,CrossAbyssCommConf.restTime[1],CrossAbyssCommConf.restTime[2], 0)
	-- local max = System.timeEncode(Y,M,d,CrossAbyssCommConf.openTime[1],CrossAbyssCommConf.openTime[2], 0)
	-- if now_t >= min and now_t < max then
	-- 	syncAdjust(actor, 0)
	-- else
	-- 	syncAdjust(actor, 1)
	-- end
end

function setLastStamp(actor)
	--if System.isCrossWarSrv() then
	if not System.isBattleSrv() then return end
	local data = getAbyssStaticVar(actor)
	data.stamp = CrossBossCommonConfig.cdTime + System.getNowTime()
end

function onNewDay(actor)
	if not isOpen() then return end
	
	local now_t = System.getNowTime()
	local data = getAbyssStaticVar(actor)
	if System.isSameDay(now_t, data.clearTime or 0) then return end
	data.buycount = 0
	data.clearTime = now_t
	local day = 1
	if data.lasttick ~= 0 then
		day = System.getDayDiff(now_t, data.lasttick)
	end
	data.lasttick = now_t
	data.cnt = math.floor(data.cnt + math.abs(day) * CrossBossCommonConfig.dailyaddtime)
	if data.cnt > CrossBossCommonConfig.maxbelongtime then
		data.cnt = CrossBossCommonConfig.maxbelongtime
	end

	syncActorAbyssInfo(actor)
end

function enterFb(actor, idx)
	if System.isCommSrv() then
		local conf = CrossBossFubenConfig[idx]

		if not zhuansheng.checkZSLevel(actor, conf.zslevel) then
			return false
		end
		if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.crossboss) then return false end

		--local now_t = System.getNowTime()
		--local data = getAbyssStaticVar(actor)
	--	if now_t >= data.stamp then
		local ret = crossbosshomefb.enterfb(actor, idx)
		-- if ret then
		-- 	actorevent.onEvent(actor, aeEnterFuben, conf.fbId, false)
		-- end
		return ret
		--end
--	elseif System.isCrossWarSrv() and System.getBattleSrvFlag() == bsMainBattleSrv then
	elseif System.isCrossWarSrv() then
		local ret = crossbosshomefb.enterfb(actor, idx)
		return ret
	end
end

function onGuanzhu(actor, pack)	
	local index = LDataPack.readChar(pack)
	local data = getAbyssStaticVar(actor)
	if not data.reminds[index] then return end
	data.reminds[index] = ((data.reminds[index] or 0) + 1)%2
	crossbosshomefb.updateSingleBossInfo(actor, index)
end

local function onZhuansheng(actor, level, oldLevel)
	local change = false
	local data = getAbyssStaticVar(actor)
	for index, conf in ipairs(CrossBossFubenConfig) do
		if conf.zslevel <= level and conf.zslevel > oldLevel then
			data.reminds[index] = 1
			change = true
			crossbosshomefb.updateSingleBossInfo(actor, index)
		end		
	end
	if change then
		for index, conf in ipairs(CrossBossFubenConfig) do
			if conf.zslevel < level and (data.reminds[index] or 0) == 1 then
				data.reminds[index] = 0
				crossbosshomefb.updateSingleBossInfo(actor, index)
			end
		end
	end
end

function onBuy(actor, packet)
	local data = getAbyssStaticVar(actor)

	local level = LActor.getSVipLevel(actor)
	if data.buycount >= SVipConfig[level].crossbuycount then
		return
	end
	if not CrossBossCommonConfig.buyNeedYuanbao[data.buycount + 1] then
		return 
	end
	if not actoritem.checkItem(actor, NumericType_YuanBao, CrossBossCommonConfig.buyNeedYuanbao[data.buycount + 1]) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, CrossBossCommonConfig.buyNeedYuanbao[data.buycount + 1], "crossboss buy")

	data.cnt = data.cnt + 1
	data.buycount = data.buycount + 1
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsBosshome_Buy)
	if npack == nil then return end
	LDataPack.writeByte(npack, data.cnt)
	LDataPack.writeByte(npack, data.buycount)
	LDataPack.flush(npack)
end

function onEnterFb(actor, packet)
	if not staticfuben.canEnterFuben(actor) then return end

	if not actorlogin.checkCanEnterCross(actor) then return end
	if not isOpen() then return end --判断是否开启

	local idx = LDataPack.readByte(packet)
	local ret = enterFb(actor, idx)
	-- if ret then
	-- 	actorevent.onEvent(actor, aeEnterFuben, CrossBossFubenConfig[idx].fbId, false)
	-- end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross, Protocol.sCsBosshome_EnterFb)
	if npack == nil then return end
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.flush(npack)
end

--
function onInitFnTable()
	--消息处理
	if System.isLianFuSrv() then return end
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive,onNewDay)
	actorevent.reg(aeZhuansheng, onZhuansheng)
	netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsBosshome_EnterFb, onEnterFb)
	netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsBosshome_Buy, onBuy)
	netmsgdispatcher.reg(Protocol.CMD_Cross, Protocol.cCsBosshome_Guanzhu, onGuanzhu)
	if not System.isBattleSrv() then return end

	-- elseif System.getBattleSrvFlag() == bsMainBattleSrv then
	-- 	netmsgdispatcher.reg(Protocol.CMD_Abyss, Protocol.cAbyssCmd_Relive, onRelive)
	-- end
end



--csmsgdispatcher.Reg(CrossSrvCmd.SCAbyssCmd, CrossSrvSubCmd.SCAbyssCmd_SyncAbyssIsOpen, onSyncAbyssIsOpen)




table.insert(InitFnTable, onInitFnTable)

