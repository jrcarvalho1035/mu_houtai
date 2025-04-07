--跨服挖矿文件
module("minecross", package.seeall)

function getGlobalData()
	local data = System.getStaticMineVar()
	if not data then return end
	if not data.mineSet then data.mineSet = {} end
	if not data.mineSet.fields then data.mineSet.fields = {} end
	if not data.mineSet.recordList then data.mineSet.recordList = {} end
	if not data.mineSet.roberInfo then data.mineSet.roberInfo = {} end --矿位被掠夺的记录
	if not data.mineSet.eids then data.mineSet.eids = {} end --采矿结束定时器
	return data.mineSet;
end

--找玩家矿位矿场的序号，没矿位返回0
function getMyPitFieldIdx(actorId)
	local data = getGlobalData()
	for hf_idx, field in ipairs(data.fields) do
		for j = 1, MineCommonConfig.number do
			if field.pits[j] and field.pits[j].actor_id == actorId then
				return hf_idx
			end
		end
	end
	return 0
end

--创建新矿场
function createField()
	local data = getGlobalData()
	local hfuben = instancesystem.createFuBen(MineCommonConfig.fbId)
	if hfuben == 0 then print("mine create hfuben false") return end
	local field = {pits={},hfuben=hfuben}
	table.insert(data.fields, field)
	for hf_idx, field in ipairs(data.fields) do
		s2cMineFieldUpdateId(field.hfuben, hf_idx, #data.fields)
	end
	return hfuben, #data.fields
end

function getMineIndex(sId, sType, cpack)
    local actorId = LDataPack.readInt(cpack)
    local data = getGlobalData()
    local hf_idx = getMyPitFieldIdx(actorId)
    local hfuben = 0
	if hf_idx > 0 then --已有矿
		hfuben = data.fields[hf_idx].hfuben
	end
	--返回空矿位矿场
	if hfuben == 0 then
		for idx, field in ipairs(data.fields) do
			hf_idx = idx
			for j = 1, MineCommonConfig.number do
				if not field.pits[j] then --有空矿位
					hfuben = field.hfuben                
					break
				end
			end
			if hfuben ~= 0 then
				break
			end
		end
	end
	if hfuben == 0 then
		hf_idx = hf_idx + 1
		hfuben = minesystem.getNextFieldFuben(hf_idx)
	end
	
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCMineCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCMineCmd_SendMineHandle)
    LDataPack.writeInt(npack, actorId)
    LDataPack.writeDouble(npack, hfuben)
    LDataPack.writeChar(npack, hf_idx)
    System.sendPacketToAllGameClient(npack, sId)
end

local function onGameStart()
    if not System.isBattleSrv() then return end
	--设置矿位结束时间
	local data = getGlobalData()
	if not data then return end
	local now = System.getNowTime()

	for hf_idx, field in ipairs(data.fields) do
		--为每个矿场创建副本
		local hfuben = instancesystem.createFuBen(MineCommonConfig.fbId)
		if hfuben > 0 then
			field.hfuben = hfuben
		end
		--设置矿位的结束定时器
		for j = 1, MineCommonConfig.number do
			local pit = field.pits[j]
			if pit then
				local leftTime = pit.finish_time - now
				if leftTime > 0 then
					local eid = LActor.postScriptEventLite(nil, leftTime * 1000, minesystem.finishTimer, pit.actor_id, j)
					minesystem.setEndTimerId(pit.actor_id, eid)
				end
			end
		end
	end
end

local function MineInit()
	if not System.isBattleSrv() then return end
    engineevent.regGameStartEvent(onGameStart)
    csmsgdispatcher.Reg(CrossSrvCmd.SCMineCmd, CrossSrvSubCmd.SCMineCmd_ReqMineIndex, getMineIndex)
end

table.insert(InitFnTable, MineInit)


