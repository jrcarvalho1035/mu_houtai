--好友数据管理器
module("friendmgr", package.seeall)

friendDataSet = friendDataSet or nil

--好友数据类型
EFriendDataType =
{
	EUndefine 	= 0,
	EAttention 	= 1, --关注
	EBlack		= 2, --黑名单
	EChat		= 3, --聊天
	EMisc		= 4, --杂数据
	EMax		= 5,
}
-- 注意跟上面一一对应！
local dbField = {
	'attentionstr', -- 关注
	'blackstr',
	'chatstr',
	'miscstr',
}
_G.EFriendDataType = EFriendDataType

--各数据列表的长度限制
--通过配置获取
EFrinedListLimit =
{
	FriendLimit.attentionListLen,
	FriendLimit.blacklistLen,
	FriendLimit.chatsListLen,
}

function IsDirty(actorId)
	local EMiscData = GetDataByType(actorId, EFriendDataType.EMisc)
	if EMiscData == nil then return false end
	return EMiscData.isDirty
end

function SetDirty(actorId, isDirty)
	local EMiscData = GetDataByType(actorId, EFriendDataType.EMisc)
	if EMiscData == nil then return false end
	EMiscData.isDirty = isDirty
end

function GetDataSet( ... )
	return friendDataSet
end

function GetData(actorId)
	if friendDataSet == nil then return end
	local fData = friendDataSet[actorId]
	if fData == nil then
		friendDataSet[actorId] = {}
		fData = friendDataSet[actorId]
	end

	for i = EFriendDataType.EUndefine + 1, EFriendDataType.EMax - 1 do
		local tdata = fData[i]
		if tdata == nil then
			fData[i] = {}
			tdata = fData[i]
		end
		if tdata.list == nil then
			tdata.list = {}
		end

		if tdata.len == nil then tdata.len = 0 end
	end
	return fData
end

function ClearData(actorId)
	if friendDataSet == nil then return end
	if friendDataSet[actorId] == nil then return end
	friendDataSet[actorId] = {}
end

function GetDataByType(actorId, dataType)
	local fData = GetData(actorId)
	if fData == nil then return end

	return fData[dataType]
end

function GetMiscData(actorId)
	local EMiscData = GetDataByType(actorId, EFriendDataType.EMisc)
	if EMiscData == nil then return end
	if not EMiscData.refuseStranger then EMiscData.refuseStranger = 0 end
	if not EMiscData.isDirty then EMiscData.isDirty = 0 end
	return EMiscData
end

function IsListFull(actorId, dataType)
	local tData = GetDataByType(actorId, dataType)
	if tData == nil then return end

	if tData.len >= EFrinedListLimit[dataType] then
		return true
	end

	return false
end

function GetBInfo(aActorId, dataType, bActorId)
	local tData = GetDataByType(aActorId, dataType)
	if tData == nil then return end

	return tData.list[bActorId]
end

function DelEarliestBInfo(aActorId, dataType)
	local tData = GetDataByType(aActorId, dataType)
	if tData == nil then return end

	local min = -1
	local delActorId = - 1
	for bActorId, bInfo in pairs(tData.list) do
		if min == -1 or min > bInfo.lastContact then
			min = bInfo.lastContact
			delActorId = bActorId
		end
	end

	if delActorId == -1 then return end
	tData.list[delActorId] = nil
	tData.len = tData.len - 1
	return delActorId
end

function AddBInfo(aActorId, dataType, bActorId)
	local tData = GetDataByType(aActorId, dataType)
	if tData == nil then return end

	if tData.list[bActorId] ~= nil then return end
	tData.list[bActorId] = {}
	tData.len = tData.len + 1
	--填入需要的信息
	local bInfo = tData.list[bActorId]
	local nowTime = System.getNowTime()
	bInfo.addtime = nowTime
	bInfo.lastContact = nowTime
	return bInfo
end

function DelBInfo(aActorId, dataType, bActorId)
	local tData = GetDataByType(aActorId, dataType)
	if tData == nil then return end

	if tData.list[bActorId] == nil then return end
	tData.list[bActorId] = nil
	tData.len = tData.len - 1
end

function bson2txt()
	if System.isCrossWarSrv() then return end
	print("friendmgr bson2txt")
	local queryStr = "call loadfriends()"
	local db = System.createActorsDbConn()
	if db == nil then return end
	local err = System.dbQuery(db, queryStr)
	if err ~= 0 then
		System.dbClose(db)
		System.delActorsDbConn(db)
		print("friendmgr bson2txt sql query error:".. queryStr)
		return
	end

	friendDataSet = {}
	local row = System.dbCurrentRow(db)
	while row do
		local actorId = tonumber(System.dbGetRow(row, 0))
		-- print('friendmgr bson2txt actorId=' .. tostring(actorId))
		local list = {}
		local fData = {}
		for i = EFriendDataType.EUndefine + 1, EFriendDataType.EMax - 1 do
			local len = System.dbGetLen(db, i)
			if len ~= 0 then
				local dbud = System.dbCopyRowToUserData(row, i, len)
				local udtable = bson.decode(dbud)
				fData[i] = udtable or {}
			else
				fData[i] = {}
			end
			table.insert(list, fData[i])
		end
		System.saveFriendData(actorId, list, dbField)
		friendDataSet[actorId] = fData

		row = System.dbNextRow(db)
	end

	System.dbResetQuery(db)
	System.dbClose(db)
	System.delActorsDbConn(db)
	print("friendmgr bson2txt end")
end

function LoadData()
	if System.isCrossWarSrv() then return end
	print("friendmgr LoadData")
	local queryStr = "SELECT actorid,attentionstr,blackstr,chatstr,miscstr FROM friends;"
	local db = System.createActorsDbConn()
	if db == nil then return end
	local err = System.dbQuery(db, queryStr)
	if err ~= 0 then
		System.dbClose(db)
		System.delActorsDbConn(db)
		print("friendmgr sql query error:".. queryStr)
		return
	end

	friendDataSet = {}
	local row = System.dbCurrentRow(db)
	while row do
		local actorId = tonumber(System.dbGetRow(row, 0))
		if actorId then
			local fData = {}
			for i = EFriendDataType.EUndefine + 1, EFriendDataType.EMax - 1 do
				local s = System.dbGetRow(row, i)
				if s then
					s = 'return ' .. s
					local chunk = loadstring(s)
					local ok, t = pcall(chunk)
					if ok then
						fData[i] = t
					else
						print('friendmgr LoadData err=' .. t .. ' actorId=' .. actorId)
					end
				-- else
				-- 	print('friendmgr LoadData s==nil i=' .. i .. ' actorId=' .. actorId)
				end


				-- local len = System.dbGetLen(db, i)
				-- if len ~= 0 then
				-- 	local dbud = System.dbCopyRowToUserData(row, i, len)
				-- 	local udtable = bson.decode(dbud)
				-- 	fData[i] = udtable or {}
				-- else
				-- 	fData[i] = {}
				-- end
			end
			--utils.printTable(fData)
			friendDataSet[actorId] = fData
		else
			print('friendmgr LoadData actorId==nil')
		end

		row = System.dbNextRow(db)
	end

	System.dbResetQuery(db)
	System.dbClose(db)
	System.delActorsDbConn(db)
	print("friendmgr LoadData end")
end

function SaveData()
	if System.isCrossWarSrv() then return end
	print("friendmgr SaveData")
	if friendDataSet == nil then
		print("friendmgr SaveData error: friendDataSet is nil")
		return
	end
	local bt = os.clock()

	for actorId, fData in pairs(friendDataSet) do
		repeat
			local EMiscData = fData[EFriendDataType.EMisc]
			if EMiscData == nil or not EMiscData.isDirty then
				break
			end
			local list = {}
			for i = EFriendDataType.EUndefine + 1, EFriendDataType.EMax - 1 do
				local tData = fData[i]
				if tData == nil then
					tData = {}
				end
				table.insert(list, tData)
			end
			System.saveFriendData(actorId, list, dbField)
			EMiscData.isDirty = false
		until(true)
	end

	local et = os.clock()
	print("friendmgr.SaveData: cost time:" .. (et-bt))
	print("friendmgr SaveData end")
end

_G.friendmgrSaveData = SaveData

--起服加载数据
engineevent.regGameStartEvent(LoadData)
--停服保存数据
engineevent.regGameStopEvent(SaveData)

local gmCmdHandlers = gmsystem.gmCmdHandlers


gmCmdHandlers.savefrd = function (actor, args)
	--SaveData2()
	friendmgr.SaveData()

	-- local bt = os.clock()
	-- local file = io.open("friend.txt", "w")
	-- --local s = utils.serialize(friendDataSet)
	-- for actorId, fData in pairs(friendDataSet) do
	-- 	local s = ""
	-- 	for i = EFriendDataType.EUndefine + 1, EFriendDataType.EMax - 1 do
	-- 		local tData = fData[i]
	-- 		tData = tData or {}
	-- 		local ud = bson.encode(tData)
	-- 		s = s .. System.EscapeUserData(ud)
	-- 	end
	-- 	file:write(s)
	-- end
	-- file:close()
	-- local et = os.clock()
	-- print("gmCmdHandlers.savefrd:file save cost:" .. (et-bt))

	-- local bt2 = os.clock()
	-- local file2 = io.open("friend.txt", "w")
	-- for actorId, fData in pairs(friendDataSet) do
	-- 	local s = ""
	-- 	for i = EFriendDataType.EUndefine + 1, EFriendDataType.EMax - 1 do
	-- 		local tData = fData[i]
	-- 		tData = tData or {}
	-- 		local ud = utils.serialize(tData)
	-- 		s = s .. ud
	-- 	end
	-- 	file2:write(s)
	-- end
	-- local et2 = os.clock()
	-- file2:close()
	-- print("gmCmdHandlers.savefrd:file save cost2:" .. (et2-bt2))

	return true
end

gmCmdHandlers.loadfrd = function (actor, args)
	friendmgr.LoadData()
	return true
end

gmCmdHandlers.frdadd  = function (actor,args)
	friendDataSet = {}
	local actorCount = tonumber(args[1])
	local dataCount = tonumber(args[2])
	for i = 1, actorCount do
		local fData = GetData(i)
		for j = 1, 4 do
			tData = fData[j]
			for k = 1, dataCount do
				tData[1] = 1
			end
		end
		fData[4].isDirty = true
	end
	return true
end
