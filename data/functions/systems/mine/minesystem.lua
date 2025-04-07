-- @version	2.0
-- @author	qianmeng
-- @date	2018-1-3 21:31:34.
-- @system	水晶采矿

module("minesystem", package.seeall )

require("mine.minecommon")
require("mine.miner")

function getActorVar(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.minedata then
		var.minedata = {
			isfirst = 1, --是否第一次提升
			curId = 1, --当前矿工品质
			blessing = 0, --祝福值
			upcount = 0, --已提升次数
			digcount = 0, --挖掘次数
			robcount = 0, --掠夺次数
			hf_idx = 0,	--当前矿场序号
			pit_idx = 0, --当前矿位
			buycount = 0, --购买到的采矿次数
			isReward = 0, --是否能领矿
			rivalId = 0, --对手ID
			rivalCurId = 0, --对手矿工品质
			robPitIdx = 0, --要掠夺的矿位
			fightTp = 0, --战斗类型
			revengeIdx = 0, --复仇的掠夺记录索引
			toendTime = 0,
			field_idx = 0,--上一个所进入矿场的idx
		}
	end
	return var.minedata
end

--选择适合矿场进入，有自己的矿就进自己的矿场，没有就找有空矿场的
function findFieldFuben(actor)
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCMineCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCMineCmd_ReqMineIndex)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

--返回下一个矿场，矿场可新建
function getNextFieldFuben(hf_idx)
	local data = minecross.getGlobalData()
	if data.fields[hf_idx] then
		return data.fields[hf_idx].hfuben
	end
	if hf_idx ~= #data.fields+1 then return end
	return createField() --创建新矿场
end

--创建新矿场
function createField()
	local data = minecross.getGlobalData()
	local hfuben = instancesystem.createFuBen(MineCommonConfig.fbId)
	if hfuben == 0 then print("mine create hfuben false") return end
	local field = {pits={},hfuben=hfuben}
	table.insert(data.fields, field)
	for hf_idx, field in ipairs(data.fields) do
		s2cMineFieldUpdateId(field.hfuben, hf_idx, #data.fields)
	end
	return hfuben, #data.fields
end

--返回一个已存在的矿场
function getFieldFuben(hf_idx)
	local data = minecross.getGlobalData()
	if data.fields[hf_idx] then
		return data.fields[hf_idx].hfuben
	end
	return false
end

--每分钟判断清理没人没矿的矿场
function checkClearField()
	if not System.isBattleSrv() then return end
	local data = minecross.getGlobalData()
	local isClear = false
	for i = #data.fields, 1, -1 do
		local field = data.fields[i]
		local ins = instancesystem.getInsByHdl(field.hfuben)
		if ins.actor_list_count <= 0 then --副本没人
			local isEmpty = true --矿场没矿位
			for j = 1, MineCommonConfig.number do
				if field.pits[j] then isEmpty = false end
			end
			if isEmpty then
				ins:release()
				data.fields[i] = data.fields[#data.fields] --用最后一个矿场覆盖这个矿场
				table.remove(data.fields, #data.fields) --删除最后一个矿场
				isClear = true
			end
		end
	end
	if isClear then --通知矿场内的玩家序号更新
		for hf_idx, field in ipairs(data.fields) do
			s2cMineFieldUpdateId(field.hfuben, hf_idx)
		end
	end
end

function getCurIns(actor)
	local fuben = LActor.getFubenPrt(actor)
	local hf = Fuben.getFubenHandle(fuben)
	return instancesystem.getInsByHdl(hf)
end

--创建一个开采的矿位
function createPit(actor, idx)
	local var = getActorVar(actor)
	local actordata = LActor.getActorData(actor)
	local pit = {
		id = var.curId,
		idx = idx,
		finish_time = System.getNowTime() + MinerConfig[var.curId].gatherTime,
		actor_id = LActor.getActorId(actor),
		beAttack = 0,
		serverid = LActor.getServerId(actor),
		actor_name = actordata.actor_name,
		total_power = actordata.total_power,
		job = actordata.job,
	}
	return pit
end

function getPit(hf_idx, pit_idx)
	if hf_idx == 0 or pit_idx == 0 then return end
	local data = minecross.getGlobalData()
	if not data.fields[hf_idx] then return end
	return data.fields[hf_idx].pits[pit_idx]
end

function getEndTime(actor)
	local var = getActorVar(actor)
	if not var then return 0 end
	return var.toendTime
end

function getRandomId()
	local r = math.random(1, 100)
	for k, v in pairs(MinerConfig) do
		if r <= v.prob then
			return k
		else
			r = r - v.prob
		end
	end
	return 0
end

function addRoberToActor(actorId, roberId, isWin)
	local data = minecross.getGlobalData()
	data.roberInfo[actorId] = data.roberInfo[actorId] or {}
	table.insert(data.roberInfo[actorId], {roberId, isWin})
end

function getRobers(actorId)
	local data = minecross.getGlobalData()
	return data.roberInfo[actorId] or {}
end

function getSucRobers(actorId)
	local robers = {}
	local data = minecross.getGlobalData()
	for k, v in pairs(data.roberInfo[actorId] or {}) do
		if v[2] > 0 then table.insert(robers, v[1]) end
	end
	return robers
end

function setEndTimerId(actorId, eid)
	local data = minecross.getGlobalData()
	data.eids[actorId] = eid
end

function getEndTimerId(actorId)
	local data = minecross.getGlobalData()
	return data.eids[actorId] or 0
end

--领奖后采矿数据重置
function resetMine(actor)
	local var = getActorVar(actor)
	if not var then return end
	var.pit_idx = 0
	var.blessing = 0
	var.upcount = 0
	var.curId = getRandomId()

	local data = minecross.getGlobalData()
	data.roberInfo[LActor.getActorId(actor)] = nil
end

--获取采矿奖励内容
function getRewardInfo(actor)
	local var = getActorVar(actor)
	local conf = MinerConfig[var.curId]
	local actorId = LActor.getActorId(actor)
	local hf_idx = minecross.getMyPitFieldIdx(actorId)
	local robers = getSucRobers(actorId)
	local count = math.min(#robers, MineCommonConfig.berob)
	local pre = MineCommonConfig.lot
	--扣奖励
	local reward = {}
	for k, v in pairs(conf.reward) do
		table.insert(reward, {id=v.id, type=v.type, count=v.count-math.ceil(v.count * count * pre / 10000)})
	end
	for k, v in pairs(conf.extra) do
		table.insert(reward, {id=v.id, type=v.type, count=v.count})
	end
	return reward
end

--获取掠夺奖励内容
local function getRobRewardInfo(id)
	local conf = MinerConfig[id]
	if not conf then return end
	local pre = MineCommonConfig.lot
	local reward = {}
	for k, v in pairs(conf.reward) do
		table.insert(reward, {id=v.id, type=v.type, count=math.ceil(v.count * pre / 10000)})
	end
	return reward
end

--获取复仇奖励内容
local function getRevengeRewardInfo(id)
	local conf = MinerConfig[id]
	if not conf then return end
	local pre = MineCommonConfig.lot
	local reward = {}
	for k, v in pairs(conf.reward) do
		table.insert(reward, {id=v.id, type=v.type, count=math.ceil(v.count * pre / 10000 * 2)})
	end
	return reward
end

--增加掠夺记录
function addRecord(actorId, isRob, isWin, isRev, torId, torName, torPower, id, serverid)
	local data = minecross.getGlobalData()
	data.recordList[actorId] = data.recordList[actorId] or {}
	local records = data.recordList[actorId]
	table.insert(data.recordList[actorId], 1, {[1] = isRob,	[2] = isWin,[3] = isRev,[4] = System.getNowTime(),
		[5] = torId, [6] = id, [7] = serverid, [8] = torName, [9] = torPower})
	--只保留固定条记录
	if #records > 20 then
		table.remove(records)
	end
	records.update = true
	local actor = LActor.getActorById(actorId)
	if actor then s2cMineUpdateRecord(actor) end
end

function getRecords(actorId)
	local data = minecross.getGlobalData()
	return data.recordList[actorId] or {}
end

--更新掠夺记录的复仇
function updateRecord(actorId, idx)
	local data = minecross.getGlobalData()
	if data.recordList[actorId] == nil or not data.recordList[actorId][idx] == nil then return end
	data.recordList[actorId][idx][3] = 1
	data.recordList[actorId][idx].update = true
	local actor = LActor.getActorById(actorId)
	if actor then s2cMineUpdateRecord(actor) end
end

--掠夺结果
function robResult(actor, ins, win)
	local actorId = LActor.getActorId(actor)
	local var = getActorVar(actor)
	if not var then return end
	--local rivaldata = LActor.getActorDataById(var.rivalId)
	--if not rivaldata then return end
	local actordata = LActor.getActorDataById(actorId)
	local isWin = win and 1 or 0

	local hf_idx = minecross.getMyPitFieldIdx(var.rivalId)
	local pit = getPit(hf_idx, var.robPitIdx)
	if pit then --未结束的矿才作记录
		addRoberToActor(pit.actor_id, actorId, isWin)
		pit.beAttack = 0
	end
	if pit then
		--自己掠夺记录
		addRecord(actorId, 1,isWin, 0, var.rivalId, pit.actor_name, pit.total_power, var.rivalCurId, LActor.getServerId(actor))
	end

	--别人被掠夺记录
	addRecord(var.rivalId, 0, isWin, 0, actorId, actordata.actor_name, actordata.total_power, var.rivalCurId, LActor.getServerId(actor))

	local hfuben = getFieldFuben(hf_idx)
	if hfuben and pit then
		s2cMinePitUpdate(hfuben, pit, pit.idx)
	end
end

--复仇结果
function revengeResult(actor, ins, win)
	if win then
		local var = getActorVar(actor)
		if not var then return end
		updateRecord(LActor.getActorId(actor), var.revengeIdx)
		--noticesystem.broadCastNotice(noticesystem.NTP.mine3, LActor.getName(actor), LActor.getActorName(var.rivalId))
	end
end

--进入副本战斗
function fightActorClone(actor, rivalId, sceneHandle, offlinedata)
	local roleCloneData, actorCloneData, roleSuperData = actorcommon.getCloneDataByOffLineData(offlinedata)

	if roleSuperData then
		roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1],FubenConstConfig.randChangeTime[2])
		roleSuperData.aiId = FubenConstConfig.roleSuperAi
	end

	local tarPos = MineCommonConfig.tarPos
	local x = tarPos[1][1]
	local y = tarPos[1][2]
	local actorClone = LActor.createActorCloneWithData(rivalId, sceneHandle, x, y, actorCloneData, roleCloneData, roleSuperData)

	local roleClone = LActor.getRole(actorClone)
	if roleClone then
		local pos = tarPos[1]
		LActor.setEntityScenePos(roleClone, pos[1], pos[2])
	end

	local yongbing = LActor.getYongbing(actorClone)
	if yongbing then
		local pos = tarPos[2]
		LActor.setEntityScenePos(yongbing, pos[1], pos[2])
	end

	--定身
	LActor.addSkillEffect(actorClone, MineCommonConfig.bindEffectId)
	LActor.addSkillEffect(actor, MineCommonConfig.bindEffectId)
end

--矿位清除
function deletePit(actorId, pit_idx)
	local hf_idx = minecross.getMyPitFieldIdx(actorId)
	if hf_idx == 0 then return end
	local data = minecross.getGlobalData()
	if data.fields[hf_idx] and data.fields[hf_idx].pits[pit_idx] then
		data.fields[hf_idx].pits[pit_idx] = nil
		local hfuben = getFieldFuben(hf_idx)
		if not hfuben then return end
		s2cMinePitUpdate(hfuben, nil, pit_idx)
	end
end

function onFinishPit(actor)
	local var = getActorVar(actor)
	var.isReward = 1
	var.eid = nil
	var.pit_idx = 0
	var.toendTime = 0 --标记这矿已经完结
	setEndTimerId(LActor.getActorId(actor), nil)
	s2cMineInfo(actor)
	s2cMineResult(actor)
end

--矿位结束采矿
function finishTimer(_, actorId, pit_idx)
	deletePit(actorId, pit_idx) --清除矿位
	local actor = LActor.getActorById(actorId)
	if actor then --玩家在线处理
		onFinishPit(actor)
	end
end

--采矿定时器
local function setTimer(actor)
	local var = getActorVar(actor)
	local leftTime = getEndTime(actor) - System.getNowTime()
	if leftTime > 0 then
		local eid = LActor.postScriptEventLite(nil, leftTime * 1000, finishTimer, LActor.getActorId(actor), var.pit_idx)
		setEndTimerId(LActor.getActorId(actor), eid)
	end
end

--退出战场后回到矿场
function enterMineFuben(actor)
	local var = getActorVar(actor)
	if not var then return end
	local hfuben = getFieldFuben(var.field_idx)
	if hfuben then
		local x, y = utils.getSceneEnterCoor(MineCommonConfig.fbId)
		LActor.enterFuBen(actor, hfuben, 0, x, y)
		return true
	end
	return false
end

-------------------------------------------------------------------------------------
--采矿信息
function s2cMineInfo(actor)
	local var = getActorVar(actor)
	if not var then return end
	local records = getRecords(LActor.getActorId(actor))
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mine, Protocol.sMineCmd_Info)
	if pack == nil then return end
	LDataPack.writeChar(pack, var.curId)
	LDataPack.writeInt(pack, var.blessing)
	LDataPack.writeChar(pack, var.upcount)
	LDataPack.writeChar(pack, var.digcount)
	LDataPack.writeChar(pack, var.robcount)
	LDataPack.writeChar(pack, var.buycount)
	LDataPack.writeByte(pack, records.update and 1 or 0)
	LDataPack.writeChar(pack, var.isReward)
	LDataPack.flush(pack)
end

function onRecvMineHandle(sId, sType, cpack)
	--if System.isBattleSrv() then return end
	local actorId = LDataPack.readInt(cpack)
	local hfuben = LDataPack.readDouble(cpack)
	local hf_idx = LDataPack.readChar(cpack)
	local actor = LActor.getActorById(actorId)
	if not actor or hfuben == 0 then return end
	local var = getActorVar(actor)
	var.field_idx = hf_idx
	local x, y = utils.getSceneEnterCoor(MineCommonConfig.fbId)
	local crossId = csbase.getCrossServerId()
	LActor.loginOtherServer(actor, crossId, hfuben, 0, x, y, "cross")
end

--进入矿场
function c2sMineEnter(actor, packet)
	if not actorlogin.checkCanEnterCross(actor) then return end
	local tp = LDataPack.readInt(packet)
	local var = getActorVar(actor)
	if not var then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.mine) then return end
	local actorId = LActor.getActorId(actor)
	local hfuben, hf_idx
	if tp == 0 then
		if System.isCrossWarSrv() then return end
		return findFieldFuben(actor)
	elseif tp == 1 then
		if not System.isBattleSrv() then return end
		hf_idx = var.field_idx - 1
		hfuben = getFieldFuben(hf_idx)
	elseif tp == 2 then
		if not System.isBattleSrv() then return end
		hf_idx = var.field_idx + 1
		-- hfuben = getFieldFuben(hf_idx)
		hfuben = getNextFieldFuben(hf_idx)
	end
	if not hfuben then
		local hf_idx = minecross.getMyPitFieldIdx(actorId)
		utils.printInfo("Error hfuben is null, ", tp, hf_idx, var.field_idx)
		return
	end
	var.field_idx = hf_idx
	local x, y = utils.getSceneEnterCoor(MineCommonConfig.fbId)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
end

--矿场信息
function s2cMineEnter(actor)
	local data = minecross.getGlobalData()
	local ins = getCurIns(actor)
	local now = System.getNowTime()
	local actorId = LActor.getActorId(actor)
	local var = getActorVar(actor)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mine, Protocol.sMineCmd_Enter)
	if pack == nil then return end
	LDataPack.writeInt(pack, var.field_idx) --所在矿场序号
	LDataPack.writeChar(pack, var.pit_idx) --自己矿位
	LDataPack.writeInt(pack, var.toendTime - now) --剩余时间
	LDataPack.writeChar(pack, MineCommonConfig.number)
	for i=1, MineCommonConfig.number do
		LDataPack.writeChar(pack, i)
		local pit = data.fields[var.field_idx].pits[i]
		if pit then
			local robers = getSucRobers(pit.actor_id)
			LDataPack.writeChar(pack, pit.id) --矿工品质
			LDataPack.writeChar(pack, pit.job)
			LDataPack.writeInt(pack, pit.finish_time - now)
			LDataPack.writeInt(pack, pit.actor_id)
			LDataPack.writeString(pack, pit.actor_name)
			LDataPack.writeDouble(pack, pit.total_power)
			LDataPack.writeChar(pack, #robers) --被掠夺次数
			for k, v in pairs(robers) do
				LDataPack.writeInt(pack, v)
			end
			LDataPack.writeByte(pack, pit.beAttack) --正在被攻击
		else
			LDataPack.writeChar(pack, 0) --矿工品质
			LDataPack.writeChar(pack, 0)
			LDataPack.writeInt(pack, 0)
			LDataPack.writeInt(pack, 0)
			LDataPack.writeString(pack, "")
			LDataPack.writeDouble(pack, 0)
			LDataPack.writeChar(pack, 0)
			LDataPack.writeByte(pack, 0)
		end
	end

	LDataPack.writeChar(pack, ins.actor_list_count)
	LDataPack.flush(pack)
end

--开始采矿
function c2sMineStart(actor, packet)
	if not System.isBattleSrv() then return end
	if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.mine) then return end
	if LActor.getFubenId(actor) ~= MineCommonConfig.fbId then
		return
	end
	local var = getActorVar(actor)
	if var.digcount >= MineCommonConfig.count + var.buycount then --没有采矿次数
		return
	end
	if var.toendTime > 0 then return end --已有矿
	if var.isReward == 1 then return end --原来的矿未领奖

	local fuben = LActor.getFubenPrt(actor)
	local hfuben = Fuben.getFubenHandle(fuben)

	local data = minecross.getGlobalData()
	local field = data.fields[var.field_idx]
	if not field then return end

	local pit = false
	for j=1, MineCommonConfig.number do
		if not field.pits[j] then --有空矿位
			pit = createPit(actor, j)
			field.pits[j] = pit
			var.toendTime = pit.finish_time
			break
		end
	end
	if pit then
		var.pit_idx = pit.idx
		var.digcount = var.digcount + 1
		s2cMineInfo(actor)
		setTimer(actor)
		s2cMinePitUpdate(hfuben, pit, pit.idx)

		local isFull = true
		for j=1, MineCommonConfig.number do
			if not field.pits[j] then isFull = false end
		end
		if isFull then --矿位满，要判断要不要新建矿场
			s2cMineFieldUpdateId(hfuben, var.field_idx)
		end
	end
	actorevent.onEvent(actor, aeMineMonsterCnt)
end

--采矿回包
-- function s2cMineStart(actor, pit)
-- 	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mine, Protocol.sMineCmd_Start)
-- 	if pack == nil then return end
-- 	LDataPack.writeInt(pack, pit.finish_time - System.getNowTime())
-- 	LDataPack.writeChar(pack, pit.idx)
-- 	LDataPack.flush(pack)
-- end

--提升矿工品质
function c2sMineUp(actor, packet)
	local var = getActorVar(actor)
	if not var then return end
	if var.curId >= #MinerConfig then return end
	if var.toendTime > 0 then return end --采矿时不能升级

	local price = MineCommonConfig.consume[var.upcount+1] or MineCommonConfig.consume[#MineCommonConfig.consume]

	if not actoritem.checkItem(actor, NumericType_YuanBao, price) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, price, "miner up")
	var.upcount = var.upcount + 1

	local ret = false --是否成功
	if var.isfirst == 1 then --第一次提升必定提升到最高级
		var.isfirst = 0
		var.curId = #MinerConfig
		ret = true
	else
		local conf = MinerConfig[var.curId]
		if var.blessing >= conf.needBless then
			ret = true
		else
			ret = math.random(1, 100) <= conf.rate
		end
		if ret then
			var.curId = var.curId + 1
		else --提升失败加祝福值
			var.blessing = var.blessing + conf.bless
		end
	end
	if ret then
		var.blessing = 0
	end
	s2cMineUp(actor, ret, var.curId, var.blessing, var.upcount)
	if var.curId == #MinerConfig then
		noticesystem.broadCastNotice(noticesystem.NTP.mine1, actorcommon.getVipShow(actor), LActor.getName(actor))
	end
end

--提升矿工回包
function s2cMineUp(actor, ret, newId, blessing, upcount)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mine, Protocol.sMineCmd_UpMiner)
	if pack == nil then return end
	LDataPack.writeByte(pack, ret and 1 or 0)
	LDataPack.writeChar(pack, newId)
	LDataPack.writeInt(pack, blessing)
	LDataPack.writeChar(pack, upcount)
	LDataPack.flush(pack)
end

--快速完成
function c2sMineQuick(actor, packet)
	local var = getActorVar(actor)
	local time = getEndTime(actor) - System.getNowTime() --剩余秒数
	if time <= 0 then return end

	local price = math.ceil(time / 60) * MineCommonConfig.unitPrice
	if not actoritem.checkItem(actor, NumericType_YuanBao, price) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, price, "mine quick")

	local eid = getEndTimerId(LActor.getActorId(actor))
	if eid then LActor.cancelScriptEvent(nil, eid) end
	finishTimer(nil, LActor.getActorId(actor), var.pit_idx)
end

--采矿结算界面
function s2cMineResult(actor)
	local var = getActorVar(actor)
	if not var then return end
	if LActor.getFubenId(actor) ~= MineCommonConfig.fbId then --在矿场才会有结算界面
		return
	end
	local data = minecross.getGlobalData()
	local isDouble = subactivity12.checkIsStart()

	local rewards = getRewardInfo(actor)
	local roberList = getRobers(LActor.getActorId(actor))
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mine, Protocol.sMineCmd_Result)
	if pack == nil then return end
	LDataPack.writeChar(pack, var.curId)
	LDataPack.writeShort(pack, #rewards)
	for k, v in pairs(rewards) do
		LDataPack.writeInt(pack, v.type)
		LDataPack.writeInt(pack, v.id)
		LDataPack.writeInt(pack, v.count * (isDouble and 2 or 1))
		LDataPack.writeByte(pack, isDouble and 1 or 0) -- 活动双倍
	end
	LDataPack.writeShort(pack, #roberList)
	for k, v in ipairs(roberList) do
		LDataPack.writeString(pack, LActor.getActorName(v[1]))
		LDataPack.writeByte(pack, v[2])
	end

	LDataPack.writeChar(pack, var.isReward)
	LDataPack.flush(pack)
end

--领取采矿物
function c2sMineDouble(actor, packet)
	local tp = LDataPack.readChar(packet)
	local var = getActorVar(actor)
	if not var then return end
	if var.isReward == 0 then return end

	local reward = getRewardInfo(actor)
	if tp == 1 then
		if not actoritem.checkItem(actor, NumericType_YuanBao, MineCommonConfig.doublePrice) then
			return
		end
		actoritem.reduceItem(actor, NumericType_YuanBao, MineCommonConfig.doublePrice, "mine double")
		for _, v in pairs(reward) do v.count = v.count * 2 end --双倍
		noticesystem.broadCastNotice(noticesystem.NTP.mine2, actorcommon.getVipShow(actor), LActor.getName(actor))
	end

	if subactivity12.checkIsStart() then
		for _, v in pairs(reward) do v.count = v.count * 2 end --双倍
	end

	local conf = MinerConfig[var.curId]
	actoritem.addItems(actor, reward, "mine get")
	var.isReward = 0
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mine, Protocol.sMineCmd_DoubleReturn)
	LDataPack.flush(pack)
	resetMine(actor)
	s2cMineInfo(actor)
end

--查看掠夺记录
function c2sMineRecord(actor, packet)
	s2cMineRecord(actor)
	s2cMineUpdateRecord(actor)
end

--掠夺记录
function s2cMineRecord(actor)
	local var = getActorVar(actor)
	if not var then return end
	local records = getRecords(LActor.getActorId(actor))
	records.update = nil
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mine, Protocol.sMineCmd_CheckRecord)
	if pack == nil then return end
	local count = math.min(20, #records)
	LDataPack.writeShort(pack, count)
	for i = 1, count do
		local record = records[i]
		LDataPack.writeInt(pack, i)
		LDataPack.writeByte(pack, record[1])
		LDataPack.writeByte(pack, record[2])
		LDataPack.writeByte(pack, record[3])
		LDataPack.writeInt(pack, record[4])
		LDataPack.writeInt(pack, record[5])
		LDataPack.writeString(pack, record[8])
		LDataPack.writeDouble(pack, record[9])
		LDataPack.writeChar(pack, record[6])
		LDataPack.writeChar(pack, 0)
	end
	LDataPack.flush(pack)
end

local function onGetCurPower(sId, sType, cpack)
	local reqActorId = LDataPack.readInt(cpack)
	local actorId = LDataPack.readInt(cpack)
	local power = 0
	local basicData = LActor.getActorDataById(actorId)
	if basicData then
		power = basicData.total_power
	end
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCMineCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCMineCmd_SendCurPower)
	LDataPack.writeInt(npack, reqActorId)
	LDataPack.writeDouble(npack, power)
	LDataPack.writeInt(npack, actorId)
	LDataPack.writeInt(npack, LDataPack.readInt(cpack))
	LDataPack.writeChar(npack, LDataPack.readChar(cpack))
	System.sendPacketToAllGameClient(npack, sId)
end

local function onRecvCurPower(sId, sType, cpack)
	local reqActorId = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(reqActorId)
	if not actor then return end
	local power = LDataPack.readDouble(cpack)
	local actorId = LDataPack.readInt(cpack)
	local hf_idx = LDataPack.readInt(cpack)
	local pit_idx = LDataPack.readChar(cpack)

	local pit = getPit(hf_idx, pit_idx)
	if not pit then return end
	if pit.actor_id ~= actorId then return end
	pit.total_power = power

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mine, Protocol.sMineCmd_Plunder)
	if pack == nil then return end
	LDataPack.writeDouble(pack, power)
	LDataPack.writeInt(pack, hf_idx)
	LDataPack.writeChar(pack, pit_idx)
	LDataPack.flush(pack)
end

--掠夺
function c2sMinePlunder(actor, packet)
	if not actorlogin.checkCanEnterCross(actor) then return end
	local hf_idx = LDataPack.readInt(packet)
	local pit_idx = LDataPack.readChar(packet)
	local times = LDataPack.readChar(packet)
	local pit = getPit(hf_idx, pit_idx)
	if not pit then return end
	if times == 1 then
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCMineCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCMineCmd_GetCurPower)
		LDataPack.writeInt(npack, LActor.getActorId(actor))
		LDataPack.writeInt(npack, pit.actor_id)
		LDataPack.writeInt(npack, hf_idx)
		LDataPack.writeChar(npack, pit_idx)
		System.sendPacketToAllGameClient(npack, pit.serverid)
	elseif times == 2 then
		mineplunder(actor, hf_idx, pit_idx)
	end
end

function mineplunder(actor, hf_idx, pit_idx)
	local var = getActorVar(actor)
	if not var then return end
	if var.robcount > MineCommonConfig.rob then return end
	local pit = getPit(hf_idx, pit_idx)
	if not pit then return end
	local actorId = LActor.getActorId(actor)
	if actorId == pit.actor_id then return end --不能掠夺自己
	if (pit.beAttack or 0) == 1 then return end --正在被攻击不能掠夺
	local robers = getSucRobers(pit.actor_id)
	if #robers >= MineCommonConfig.berob then return end --已被抢3次了
	for k, v in pairs(robers) do --已被你掠夺过
		if v == actorId then return end
	end

	var.robcount = var.robcount + 1
	var.rivalId = pit.actor_id
	var.serverid = pit.serverid
	var.rivalCurId = pit.id
	var.robPitIdx = pit_idx
	var.fightTp = 1 --战斗类型为掠夺
	pit.beAttack = 1

	local hfuben = instancesystem.createFuBen(MineCommonConfig.pkfbId)
	if hfuben == 0 then return end
	local ins = instancesystem.getInsByHdl(hfuben)
	if ins == nil then return end
	local x,y = utils.getSceneEnterCoor(ins.id)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
	s2cMineInfo(actor)

	local hf = getFieldFuben(hf_idx)
	if hf then
		s2cMinePitUpdate(hf, pit, pit_idx)
	end
end

--复仇
function c2sMineRevenge(actor, packet)
	local recordId = LDataPack.readInt(packet)
	local records = getRecords(LActor.getActorId(actor))
	local record = records[recordId]
	if not record then return end

	--自己掠夺别人，没有成功掠夺，已经复仇的情况都不能继续复仇
	if record[1] == 1 or record[2] == 0 or record[3] == 1 then
		return
	end

	local var = getActorVar(actor)
	if not var then return end
	var.rivalId = record[5]
	var.rivalCurId = record[6]
	var.serverid = record[7]
	var.fightTp = 2 --战斗类型为复仇
	var.revengeIdx = recordId

	local hfuben = instancesystem.createFuBen(MineCommonConfig.pkfbId)
	if hfuben == 0 then return end
	local ins = instancesystem.getInsByHdl(hfuben)
	if ins == nil then return end
	local x,y = utils.getSceneEnterCoor(ins.id)
	LActor.enterFuBen(actor, hfuben, 0, x, y)
end

--矿场人数更新
function s2cMinePeople(hfuben, count)
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, Protocol.CMD_Mine)
	LDataPack.writeByte(pack, Protocol.sMineCmd_People)
	if pack == nil then return end
	LDataPack.writeInt(pack, count)
	Fuben.sendData(hfuben, pack)
end

--矿位状态更新
function s2cMinePitUpdate(hfuben, pit, idx)
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, Protocol.CMD_Mine)
	LDataPack.writeByte(pack, Protocol.sMineCmd_Appear)
	if pack == nil then return end
	LDataPack.writeChar(pack, idx)
	if pit then
		local isRob = 0
		local robers = getSucRobers(pit.actor_id)
		LDataPack.writeChar(pack, pit.id) --矿工品质
		LDataPack.writeChar(pack, pit.job)
		LDataPack.writeInt(pack, pit.finish_time - System.getNowTime())
		LDataPack.writeInt(pack, pit.actor_id)
		LDataPack.writeString(pack, pit.actor_name)
		LDataPack.writeDouble(pack, pit.total_power)
		LDataPack.writeChar(pack, #robers) --被掠夺次数
		for k, v in pairs(robers) do
			LDataPack.writeInt(pack, v)
		end
		LDataPack.writeByte(pack, pit.beAttack) --正在被攻击
	else
		LDataPack.writeChar(pack, 0) --矿工品质
		LDataPack.writeChar(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeString(pack, "")
		LDataPack.writeDouble(pack, 0)
		LDataPack.writeChar(pack, 0)
		LDataPack.writeByte(pack, 0)
	end
	Fuben.sendData(hfuben, pack)
end

--购买次数
function c2sMineBuy(actor, packet)
	local var = getActorVar(actor)
	local vip = LActor.getSVipLevel(actor)
	if var.buycount >= SVipConfig[vip].mine then
		return
	end

	local price = MineCommonConfig.prices[var.buycount+1] or MineCommonConfig.prices[#MineCommonConfig.prices]
	if not actoritem.checkItem(actor, NumericType_YuanBao, price) then
		return
	end
	actoritem.reduceItem(actor, NumericType_YuanBao, price, "mine buy")

	var.buycount = var.buycount + 1
	s2cMineInfo(actor)
end

--掠夺记录有更新
function s2cMineUpdateRecord(actor)
	local records = getRecords(LActor.getActorId(actor))
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mine, Protocol.sMineCmd_RecordUpdate)
	if pack == nil then return end
	LDataPack.writeByte(pack, records.update and 1 or 0) --是否有记录更新
	LDataPack.flush(pack)
end

--矿场最高序号更新
function s2cMineFieldUpdateId(hfuben, hf_idx, fieldCount)
	local data = minecross.getGlobalData()
	if not fieldCount then
		local isFull = true
		for hf_idx, field in ipairs(data.fields) do
			for j = 1, MineCommonConfig.number do
				if not field.pits[j] then --有空矿位
					isFull = false
					break
				end
			end
		end
		fieldCount = isFull and #data.fields+1 or #data.fields --矿位满就矿场数+1
	end

	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, Protocol.CMD_Mine)
	LDataPack.writeByte(pack, Protocol.sMineCmd_FieldMax)
	if pack == nil then return end
	LDataPack.writeInt(pack, fieldCount)
	LDataPack.writeInt(pack, hf_idx)
	Fuben.sendData(hfuben, pack)
end

--战斗开始倒计时
function s2cMineFightCountDown( actor, countDown)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mine, Protocol.sMineCmd_CountDown)
	if pack == nil then return end
	LDataPack.writeByte(pack, countDown) --倒计时
	LDataPack.flush(pack)
end

---------------------------------------------------------------------------------------------------
function onLogin(actor)
	s2cMineInfo(actor)
	if not System.isBattleSrv() then return end
	local records = getRecords(LActor.getActorId(actor))
	if #records > 20 then
		for i=21, #records do
			table.remove(records)
		end
	end
	s2cMineUpdateRecord(actor)

	--对自己已结束但未结算的矿位进行结算
	local finishTime = getEndTime(actor)
	if finishTime > 0 then
		local leftTime = finishTime - System.getNowTime()
		if leftTime <= 0 then
			local var = getActorVar(actor)
			finishTimer(nil, LActor.getActorId(actor), var.pit_idx)
		end
	end
end

function onNewDay(actor, login)
	local var = getActorVar(actor)
	var.digcount = 0
	var.robcount = 0
	var.buycount = 0
	if not login then
		s2cMineInfo(actor)
	end
end

function onEnterMine(ins, actor)
	local fuben = LActor.getFubenPrt(actor)
	local hfuben = Fuben.getFubenHandle(fuben)
	s2cMineEnter(actor)
	s2cMinePeople(hfuben, ins.actor_list_count)
	local var = getActorVar(actor)
	s2cMineFieldUpdateId(hfuben, var.field_idx)

	local var = getActorVar(actor)
	if var.isReward == 1 then
		onFinishPit(actor)
		return
	end
end

function onExitMine(ins, actor)
	local fuben = LActor.getFubenPrt(actor)
	local hfuben = Fuben.getFubenHandle(fuben)
	s2cMinePeople(hfuben, ins.actor_list_count)
end

function onOfflineMine(ins, actor)
	LActor.exitFuben(actor)
end

function onReqCloneInfo(sId, sType, cpack)
	local actorId = LDataPack.readInt(cpack)
	local rivalId = LDataPack.readInt(cpack)
	local sceneHandle = LDataPack.readDouble(cpack)
	local actor = LActor.getActorById(rivalId)
	if actor then--先暴力处理
		offlinedatamgr.CallEhLogout(actor) --保存离线数据
	end

	local actorData = offlinedatamgr.GetDataByOffLineDataType(rivalId, offlinedatamgr.EOffLineDataType.EBasic)
	if actorData==nil then
		local pack = LDataPack.allocPacket()
		if pack == nil then return end
		LDataPack.writeByte(pack, CrossSrvCmd.SCMineCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCMineCmd_SendCloneInfo)
        LDataPack.writeInt(pack, rivalId)
        LDataPack.writeDouble(pack, sceneHandle)
		LDataPack.writeUserData(pack, bson.encode({}))
		System.sendPacketToAllGameClient(pack, sId)
		return
	end

	local actorDataUd = bson.encode(actorData)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCMineCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCMineCmd_SendCloneInfo)
	LDataPack.writeInt(pack, actorId)
	LDataPack.writeInt(pack, rivalId)
	LDataPack.writeDouble(pack, sceneHandle)
	LDataPack.writeUserData(pack, actorDataUd)
	System.sendPacketToAllGameClient(pack, sId)
end

function onEnterFuBen(ins, actor)
	--设置角色位置
	local myPos = MineCommonConfig.myPos
	local role = LActor.getRole(actor)
	LActor.setEntityScenePos(role, myPos[1][1], myPos[1][2])
	local yongbing = LActor.getYongbing(actor)
	if yongbing then
		LActor.setEntityScenePos(yongbing, myPos[2][1], myPos[2][2])
	end

	--清除技能cd
	LActor.ClearCD(actor)

	local var = getActorVar(actor)
	if not var then return end
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCMineCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCMineCmd_ReqCloneInfo)
	LDataPack.writeInt(npack, LActor.getActorId(actor))
	LDataPack.writeInt(npack, var.rivalId)
	LDataPack.writeDouble(npack, ins.scene_list[1])
	System.sendPacketToAllGameClient(npack, var.serverid)

	-- fightActorClone(actor, ins, var.rivalId)
	-- s2cMineFightCountDown(actor, MineCommonConfig.fightCountDown)
end

function onRecvCloneInfo(sId, sType, cpack)
	local actorId = LDataPack.readInt(cpack)
	local rivalId = LDataPack.readInt(cpack)
	local actor = LActor.getActorById(actorId)
	if not actor then return end
	local sceneHandle = LDataPack.readDouble(cpack)
	local actorDataUd = LDataPack.readUserData(cpack)
	local offlinedata = bson.decode(actorDataUd)
	fightActorClone(actor, rivalId, sceneHandle, offlinedata)
	s2cMineFightCountDown(actor, MineCommonConfig.fightCountDown)
end

function setClone(actorId, offlinedata, sceneHandle)

end

function onExitFb(ins, actor)
	if not ins.is_end then --主动退出，以失败处理
		onLose(ins, actor) --因副本内已没有actor,所以不能用ins:lose()
	end
end

function onWin(ins, actor)
	local actor = ins:getActorList()[1]
	if not actor then return end
	local var = getActorVar(actor)
	if var.fightTp == 1 then
		robResult(actor, ins, true)
	else
		revengeResult(actor, ins, true)
	end
end

function onLose(ins, actor)
	if not actor then
		actor = ins:getActorList()[1]
	end
	if not actor then return end
	local var = getActorVar(actor)
	if var.fightTp == 1 then
		robResult(actor, ins, false)
	else
		revengeResult(actor, ins, false)
	end
end

function onActorDie(ins, actor)
	ins:lose()
end

function onActorCloneDie(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end
	local var = getActorVar(actor)
	if var.rivalCurId == 0 then return end
	local rewards
	if var.fightTp == 1 then --是掠夺战斗
		rewards = getRobRewardInfo(var.rivalCurId)
	else --是复仇战斗
		rewards = getRevengeRewardInfo(var.rivalCurId)
	end
	local posX, posY = LActor.getEntityScenePoint(actor)
	ins:addDropBagItem(actor, rewards, 100, posX, posY)
	ins:win()
end

function onOffline(ins, actor)
	guajifuben.enterGuajiFuben(actor)
	--mainscenefuben.enterMainScene(actor) --离线时要直接回主城，直接退出会使矿场人数增加
end


local function onRecvMine(sId, sType, cpack)
	if System.isCrossWarSrv() then return end
	local data = minecross.getGlobalData()
	local count = LDataPack.readChar(cpack)
	for i=1, count do
		data.fields[i] = LDataPack.readDouble(cpack)
	end
end

local function MineInit()
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)

	if System.isLianFuSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_Mine, Protocol.cMineCmd_Enter, c2sMineEnter)
	csmsgdispatcher.Reg(CrossSrvCmd.SCMineCmd, CrossSrvSubCmd.SCMineCmd_SendMineInfo, onRecvMine)
	csmsgdispatcher.Reg(CrossSrvCmd.SCMineCmd, CrossSrvSubCmd.SCMineCmd_SendMineHandle, onRecvMineHandle)
	csmsgdispatcher.Reg(CrossSrvCmd.SCMineCmd, CrossSrvSubCmd.SCMineCmd_ReqCloneInfo, onReqCloneInfo)
	csmsgdispatcher.Reg(CrossSrvCmd.SCMineCmd, CrossSrvSubCmd.SCMineCmd_SendCloneInfo, onRecvCloneInfo)
	csmsgdispatcher.Reg(CrossSrvCmd.SCMineCmd, CrossSrvSubCmd.SCMineCmd_GetCurPower, onGetCurPower)
	csmsgdispatcher.Reg(CrossSrvCmd.SCMineCmd, CrossSrvSubCmd.SCMineCmd_SendCurPower, onRecvCurPower)

	netmsgdispatcher.reg(Protocol.CMD_Mine, Protocol.cMineCmd_Start, c2sMineStart)
	netmsgdispatcher.reg(Protocol.CMD_Mine, Protocol.cMineCmd_UpMiner, c2sMineUp)
	netmsgdispatcher.reg(Protocol.CMD_Mine, Protocol.cMineCmd_Quick, c2sMineQuick)
	netmsgdispatcher.reg(Protocol.CMD_Mine, Protocol.cMineCmd_Double, c2sMineDouble)
	netmsgdispatcher.reg(Protocol.CMD_Mine, Protocol.cMineCmd_CheckRecord, c2sMineRecord)
	netmsgdispatcher.reg(Protocol.CMD_Mine, Protocol.cMineCmd_Plunder, c2sMinePlunder)
	netmsgdispatcher.reg(Protocol.CMD_Mine, Protocol.cMineCmd_Revenge, c2sMineRevenge)
    netmsgdispatcher.reg(Protocol.CMD_Mine, Protocol.cMineCmd_Buy, c2sMineBuy)

	engineevent.regGameTimer(checkClearField)

	local mineFb = MineCommonConfig.fbId
	local fightFb = MineCommonConfig.pkfbId
	insevent.registerInstanceEnter(mineFb, onEnterMine)
	insevent.registerInstanceExit(mineFb, onExitMine)
	insevent.registerInstanceOffline(mineFb, onOfflineMine)

	insevent.registerInstanceEnter(fightFb, onEnterFuBen)
	insevent.registerInstanceExit(fightFb, onExitFb)
	insevent.registerInstanceWin(fightFb, onWin)
	insevent.registerInstanceLose(fightFb, onLose)
	insevent.registerInstanceActorDie(fightFb, onActorDie)
	insevent.regActorCloneDie(fightFb, onActorCloneDie)
	insevent.registerInstanceOffline(fightFb, onOffline)
end
table.insert(InitFnTable, MineInit)

function gmClearRecrod()
	local data = minecross.getGlobalData()
	data.recordList = nil
end

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.mineenter = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sMineEnter(actor, pack)
	return true
end

gmCmdHandlers.minestart = function (actor, args)
	c2sMineStart(actor)
	return true
end

gmCmdHandlers.minebuy = function (actor, args)
	c2sMineBuy(actor)
	return true
end

gmCmdHandlers.mineup = function (actor, args)
	c2sMineUp(actor)
	return true
end

gmCmdHandlers.minequick = function (actor, args)
	c2sMineQuick(actor)
	return true
end

gmCmdHandlers.minedouble = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeChar(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sMineDouble(actor, pack)
	return true
end

gmCmdHandlers.minefield = function (actor, args)
	s2cMineEnter(actor)
	return true
end

gmCmdHandlers.minefieldinfo = function (actor, args)
	local data = minecross.getGlobalData()
	utils.printTable(data.fields)
	-- utils.printTable(data.fields)
	-- utils.printTable(data.roberInfo)
	-- utils.printTable(data.recordList)
	return true
end

gmCmdHandlers.mineplunder = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.writeChar(pack, args[2])
	LDataPack.setPosition(pack, 0)
	c2sMinePlunder(actor, pack)
	return true
end

gmCmdHandlers.minerevenge = function (actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1])
	LDataPack.setPosition(pack, 0)
	c2sMineRevenge(actor, pack)
	return true
end

gmCmdHandlers.minerecord = function (actor, args)
	s2cMineRecord(actor)
	return true
end

gmCmdHandlers.mineclear = function (actor, args)
	checkClearField()
	return true
end

gmCmdHandlers.minetest = function (actor, args)
	createField()
	return true
end

gmCmdHandlers.mineset = function (actor, args)
	local var = getActorVar(actor)
	var.curId = tonumber(args[1]) or 0
	s2cMineInfo(actor)
	return true
end

gmCmdHandlers.fubenfail = function (actor, args)
	local ins = getCurIns(actor)
	ins:lose()
	return true
end
