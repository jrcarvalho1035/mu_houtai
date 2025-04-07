module("cscheck", package.seeall)

--发生连接时候加个版本检查

function OnConnCsWar(serverId, serverType)
	if System.isCommSrv() then
	elseif System.isCrossWarSrv() then
		local pack = LDataPack.allocPacket()
		if pack == nil then return end
		LDataPack.writeByte(pack, CrossSrvCmd.SCCheckCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCCheckCmd_CheckVersion)
		System.sendPacketToAllGameClient(pack, serverId)
	end

end

function onCheckVersion(sId, sType, dp)
	if System.isCommSrv() then
		local version = System.version()
		local pack = LDataPack.allocPacket()
		if pack == nil then return end
		LDataPack.writeByte(pack, CrossSrvCmd.SCCheckCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCCheckCmd_CheckVersion)
		LDataPack.writeInt(pack, version)
		System.sendPacketToAllGameClient(pack, sId)
	elseif System.isCrossWarSrv() then
		local tarVersion = LDataPack.readInt(dp)
		local srcVersion = System.version()
		if tarVersion ~= srcVersion then
			System.log("cscheck", "onCheckVersion", sId, srcVersion, tarVersion)
			assert(false)
		end
	end
end

csbase.RegConnected(OnConnCsWar)
csmsgdispatcher.Reg(CrossSrvCmd.SCCheckCmd, CrossSrvSubCmd.SCCheckCmd_CheckVersion, onCheckVersion)