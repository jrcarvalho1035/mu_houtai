-- @version	1.0
-- @author	rancho
-- @date	2019-06-25
-- @system  跨服基础模块
module("csbase", package.seeall)

--服务器id和配置对应表(serverid,config)
ServerIdx = {}

CROSS_SERVER_ID = CROSS_SERVER_ID or nil
CROSS_SERVER_IP = CROSS_SERVER_IP or nil
CROSS_SERVER_PORT = CROSS_SERVER_PORT or nil
SERVER_LIST = SERVER_LIST or {} --跨服链接的所有普通服


LIANFU_SERVER_LIST = LIANFU_SERVER_LIST or {}
LIANFU_SERVER_ID = LIANFU_SERVER_ID or nil
LIANFU_SERVER_IP = LIANFU_SERVER_IP or nil
LIANFU_SERVER_PORT = LIANFU_SERVER_PORT or nil

function getSystemDynamicVar()
	local var = System.getDyanmicVar()
	if not var.csbase then var.csbase = {} end
	local csbase = var.csbase
	if not csbase.connectedList then csbase.connectedList = {} end
	return csbase
end

function getCrossServerId()
	return CROSS_SERVER_ID
end

function getLianfuServerId()
	return LIANFU_SERVER_ID
end

function setServerIdx(serverId, idx)
	ServerIdx[serverId] = idx
end

function addToConnectedList(serverId)
	local sdvar = getSystemDynamicVar()
	local connectedList = sdvar.connectedList
	for i, tempServerId in ipairs(connectedList) do
		if serverId == tempServerId then
			print("csbase.addToConnectedList server conflict serverId: " .. serverId)
			return
		end
	end
	table.insert( connectedList, serverId )
end

function getConnectList()
	local sdvar = getSystemDynamicVar()
	return sdvar.connectedList
end

function deleteFromConnectedList(serverId)
	local sdvar = getSystemDynamicVar()
	local connectedList = sdvar.connectedList
	local deleteIndex
	for i, tempServerId in ipairs(connectedList) do
		if serverId == tempServerId then
			table.remove(connectedList, i)
			return
		end
	end
end

function checkAllConnect()
	local sdvar = getSystemDynamicVar()
	local connectedList = sdvar.connectedList
	local count = 0
	for k,v in ipairs(SERVER_LIST) do
		count = count + (v.end_id - v.start_id + 1)
	end
	return count == #connectedList
end

function isConnected(serverId)
	local sdvar = getSystemDynamicVar()
	local connectedList = sdvar.connectedList
	for i, tempServerId in ipairs( connectedList) do
		if serverId == tempServerId then
			return true
		end
	end
	return false
end

function checkLianFuConnected()
	return isConnected(LIANFU_SERVER_ID)
end

local function loadCrossConfig()
	local db = System.getGameEngineGlobalDbConn()
	local ret = System.dbConnect(db)
	if not ret then
		print('loadCrossServerList error dbConnect fail ret=', ret)
		return
	end
	local srvid = System.getServerId()
	local err = System.dbQuery(db, 'SELECT `srvid`,`start_id`,`end_id`,`ip`,`port` FROM crossroute WHERE `srvid`=' .. srvid)
	if err ~= 0 then
		System.dbClose(db)
		print('loadCrossServerList error dbQuery cross err=', err)
		return
	end
	local count = System.dbGetRowCount(db)
	if count == 0 then --普通服
		System.dbResetQuery(db)
		local err = System.dbQuery(db, 'SELECT `srvid`,`start_id`,`end_id`,`ip`,`port` FROM crossroute')
		if err ~= 0 then
			System.dbClose(db)
			print('loadCrossServerList error dbQuery cross err=', err)
			return
		end
		count = System.dbGetRowCount(db)
		print('loadCrossServerList cross list count='.. count)
		if 0 < count then
			local row = System.dbCurrentRow(db)
			for i = 1, count do
				local start_id = tonumber(System.dbGetRow(row, 1))
				local end_id = tonumber(System.dbGetRow(row, 2))
				if srvid >= start_id and srvid <= end_id then
					CROSS_SERVER_ID = tonumber(System.dbGetRow(row, 0))
					CROSS_SERVER_IP = System.dbGetRow(row, 3)
					CROSS_SERVER_PORT = tonumber(System.dbGetRow(row, 4))
					break
				end
				row = System.dbNextRow(db)
			end
		end
		if not CROSS_SERVER_IP or not CROSS_SERVER_PORT or not CROSS_SERVER_ID then
			System.dbClose(db)
			print("common not have cross server")
			return
		end
		print("common server set type")
		System.setServerType(ServerType_Common)
	else --跨服
		local row = System.dbCurrentRow(db)
		for i = 1, count do
			SERVER_LIST[i] = {}
			SERVER_LIST[i].start_id = tonumber(System.dbGetRow(row, 1))
			SERVER_LIST[i].end_id = tonumber(System.dbGetRow(row, 2))
			CROSS_SERVER_PORT = tonumber(System.dbGetRow(row, 4))
			row = System.dbNextRow(db)
		end

		if not CROSS_SERVER_PORT then
			System.dbClose(db)
			print("cross not have common server")
			return
		end
		print("cross server set type")
		System.setServerType(ServerType_Battle)
	end

	System.dbResetQuery(db)
	System.dbClose(db)
end


local function loadLianFuConfig()
	local db = System.getGameEngineGlobalDbConn()
	local ret = System.dbConnect(db)
	if not ret then
		print('loadLianFuConfig error dbConnect fail ret=', ret)
		return
	end
	local srvid = System.getServerId()
	local err = System.dbQuery(db, 'SELECT `srvid`,`start_id`,`end_id`,`ip`,`port` FROM lianfuroute WHERE `srvid`=' .. srvid)
	if err ~= 0 then
		System.dbClose(db)
		print('loadLianFuConfig error dbQuery lianfu err=', err)
		return
	end
	local count = System.dbGetRowCount(db)
	if count == 0 then --普通服
		System.dbResetQuery(db)
		local err = System.dbQuery(db, 'SELECT `srvid`,`start_id`,`end_id`,`ip`,`port` FROM lianfuroute')
		if err ~= 0 then
			System.dbClose(db)
			print('loadLianFuConfig error dbQuery cross err=', err)
			return
		end
		count = System.dbGetRowCount(db)
		print('loadLianFuConfig cross list count='.. count)
		if 0 < count then
			local row = System.dbCurrentRow(db)
			for i = 1, count do
				local start_id = tonumber(System.dbGetRow(row, 1))
				local end_id = tonumber(System.dbGetRow(row, 2))
				if srvid >= start_id and srvid <= end_id then
					LIANFU_SERVER_ID = tonumber(System.dbGetRow(row, 0))
					LIANFU_SERVER_IP = System.dbGetRow(row, 3)
					LIANFU_SERVER_PORT = tonumber(System.dbGetRow(row, 4))
					break
				end
				row = System.dbNextRow(db)
			end
		end
		if not LIANFU_SERVER_IP or not LIANFU_SERVER_PORT or not LIANFU_SERVER_ID then
			System.dbClose(db)
			print("common not have lianfu server")
			return
		end
		--print("common server set type")
		--System.setServerType(ServerType_Common)
	else --连服
		local row = System.dbCurrentRow(db)
		for i = 1, count do
			LIANFU_SERVER_LIST[i] = {}
			LIANFU_SERVER_LIST[i].start_id = tonumber(System.dbGetRow(row, 1))
			LIANFU_SERVER_LIST[i].end_id = tonumber(System.dbGetRow(row, 2))
			LIANFU_SERVER_PORT = tonumber(System.dbGetRow(row, 4))
			row = System.dbNextRow(db)
		end

		if not LIANFU_SERVER_PORT then
			System.dbClose(db)
			print("cross not have common server")
			return
		end
		print("cross server set type")
		System.setServerType(ServerType_Lianfu)
	end

	System.dbResetQuery(db)
	System.dbClose(db)
end

function onGameStart()
	if System.isCommSrv() then
		print(string.format("csbase.onGameStart: startOneGameClient ip = %s, port = %d, serverId = %d", CROSS_SERVER_IP, CROSS_SERVER_PORT, CROSS_SERVER_ID))
		System.startOneGameClient(CROSS_SERVER_IP, CROSS_SERVER_PORT, CROSS_SERVER_ID, ServerType_Battle)
		if LIANFU_SERVER_IP and LIANFU_SERVER_PORT and LIANFU_SERVER_ID then
			print(string.format("csbase.onGameStart: startLianfuGameClient ip = %s, port = %d, serverId = %d", LIANFU_SERVER_IP, LIANFU_SERVER_PORT, LIANFU_SERVER_ID))
			System.startOneGameClient(LIANFU_SERVER_IP, LIANFU_SERVER_PORT, LIANFU_SERVER_ID, ServerType_Lianfu)
		end
	elseif System.isBattleSrv() then
		print(string.format("csbase.onGameStart: startGameConnSrv port = %d", CROSS_SERVER_PORT))
		System.startGameConnectMgr("0.0.0.0", CROSS_SERVER_PORT)
	elseif System.isLianFuSrv() then
		print(string.format("csbase.onGameStart: startLianfuGameConnSrv port = %d", LIANFU_SERVER_PORT))
		System.startGameConnectMgr("0.0.0.0", LIANFU_SERVER_PORT)
	end
end

RegConnectedT = {}
RegDisconnectedT = {}
--注册服务器连接建立事件
function RegConnected( func )
	for i,v in ipairs(RegConnectedT) do
		if v == func then
			print("csbase.Regconnected: the func is already RegConnected")
			return
		end
	end
	table.insert(RegConnectedT, func)
end

function RegDisconnect(func)
	for i, v in ipairs(RegDisconnectedT) do
		if v == func then
			print("csbase.RegDisconnect: the func is already RegDisconnect")
			return
		end
	end
	table.insert(RegDisconnectedT, func)
end

--跨服连接后回调
function onCrossServerConnected(serverId, serverType)
	onConnected(serverId, serverType)
	for i,func in ipairs(RegConnectedT) do
		func(serverId, serverType)
	end
end

--跨服断开后回调
function onCrossServerDisconnected(serverId)
	onDisConnected(serverId)
	for i,func in ipairs(RegDisconnectedT) do
		func(serverId)
	end
end

function cw_sendkey(sysarg, serverId, sceneid, x, y)
	serverId = tonumber(serverId)
	if sceneid == nil then
		sceneid = 11
	else
		sceneid = tonumber(sceneid)
	end

	if x == nil then x = 0 else x = tonumber(x) end
	if y == nil then y = 0 else y = tonumber(y) end
	print("loginOtherSrv:cw_sendkey,"..LActor.getActorId(sysarg))

	local var = LActor.getStaticVar(sysarg)
	var.crosswar_ticketTime = System.getCurrMiniTime() + 10

	LActor.loginOtherSrv(sysarg, serverId,
		0, sceneid, x, y)
end

function onConnected(serverId, serverType)
	print("csbase.onConnected to serverId:"..serverId..", serverType:"..serverType)

	addToConnectedList(serverId)
end

function onDisConnected(serverId)
	deleteFromConnectedList(serverId)
end

function backToNormalServer(actor)
	LActor.log(actor,"backToNormalServer","call")
	LActor.loginOtherSrv(actor, LActor.getServerId(actor), 0, 0, 0, 0, "csbase.backToNormalServer")
end

_G.onCrossServerConnected = onCrossServerConnected
_G.onCrossServerDisconnected = onCrossServerDisconnected

table.insert(InitFnTable, 1, loadCrossConfig)
table.insert(InitFnTable, 2, loadLianFuConfig)

--启动完成才监听
engineevent.regGameStartEvent(onGameStart)



