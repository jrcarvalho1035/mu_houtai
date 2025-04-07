module("serverroute", package.seeall)

local function getSystemDynmamicVar()
	local var = System.getDyanmicVar()
	if not var.serverRoute then var.serverRoute = {} end
	local serverRoute = var.serverRoute
	if not serverRoute.selfRouteList then serverRoute.selfRouteList = {} end
	if not serverRoute.sendServerIdList then serverRoute.sendServerIdList = {} end
	return serverRoute
end

-- 发送路由数据
function sendRouteList(destServerId, routeList)
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, CrossSrvCmd.SCrossNetCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCrossNetCmd_Route)
	LDataPack.writeByte(pack, #routeList)
	for i = 1, #routeList do
		LDataPack.writeString(pack, routeList[i].host)
		LDataPack.writeInt(pack, routeList[i].port)
	end
	System.sendPacketToAllGameClient(pack, destServerId)
	print("serverroute.sendRouteList destServerId:" .. destServerId)
end

-- 收到路由数据
function recvRouteList(sourceServerId, serverType, pack)
	local count = LDataPack.readByte(pack)
	local routeList = {}
	for i = 1, count do
		local host = LDataPack.readString(pack)
		local port = LDataPack.readInt(pack)
		table.insert(routeList, {host = host or "", port = port})
	end

	print("serverroute.recvRouteList sourceServerId:".. sourceServerId)
	table.print(routeList)

	System.resetSingleGameRoute(sourceServerId)
	for i, route in ipairs(routeList) do
		System.geAddRoutes(sourceServerId, route.host, route.port)
	end
end

--从数据库中加载路由数据
function loadServerRoute()
	local db = System.getGameEngineGlobalDbConn()
	local ret = System.dbConnect(db)
	if not ret then
		print("loadServerRoute fail, globaldb cannot connect.")
		return
	end

	local err = System.dbQuery(db, "call loadserverroute()")
	if err ~= 0 then
		print("loadServerRoute fail, dbQuery fail.")
		return
	end

	System.resetGameRoute()

	local myServerId = System.getServerId()
	local sdvar = getSystemDynmamicVar()
	local selfRouteList = sdvar.selfRouteList

	local row = System.dbCurrentRow(db)
	local count = System.dbGetRowCount(db)
	for i=1, count do
		local serverid = System.dbGetRow(row, 0)
		local hostname = System.dbGetRow(row, 1)
		local port = System.dbGetRow(row, 2)
		System.geAddRoutes(tonumber(serverid), hostname or "", tonumber(port))
		row = System.dbNextRow(db)

		if tonumber(serverid) == myServerId then
			table.insert(selfRouteList, { host = hostname or "", port = tonumber(port)})
		end
	end

	System.dbResetQuery(db)
	System.dbClose(db)

	print("serverroute.loadServerRoute selfRouteList:")
	table.print(selfRouteList)

	-- 向已经连接的服务器发送自己的路由数据
	local sendServerIdList = sdvar.sendServerIdList
	for i, tempServerId in ipairs(sendServerIdList) do
		sendRouteList(tempServerId, selfRouteList)
	end
	sdvar.sendServerIdList = nil
end

local function onCrossServerConnected(serverId, serverType)
	local sdvar = getSystemDynmamicVar()
	local selfRouteList = sdvar.selfRouteList
	if selfRouteList then
		sendRouteList(serverId, selfRouteList)
	else
		local sendServerIdList = sdvar.sendServerIdList
		table.insert(sendServerIdList, serverId)
	end
end

csbase.RegConnected(onCrossServerConnected)
csmsgdispatcher.Reg(CrossSrvCmd.SCrossNetCmd, CrossSrvSubCmd.SCrossNetCmd_Route, recvRouteList)
