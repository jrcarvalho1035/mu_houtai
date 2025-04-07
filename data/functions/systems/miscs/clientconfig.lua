--客户端保存配置
module("clientconfig", package.seeall)


local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then
		print("get client static data err")
		return nil
	end

	if var.clientConfig == nil then
		var.clientConfig = {}
	end
	return var.clientConfig
end


local function onUpdateConfig(actor, packet)
	local p1 = LDataPack.readByte(packet)
	local p2 = LDataPack.readByte(packet)
	local p3 = LDataPack.readInt(packet)

	local data = getStaticData(actor)
	if data == nil then return end

	data.p1 = p1
	data.p2 = p2
	data.p3 = p3
	s2cUpdateConfig(actor)
end

function s2cUpdateConfig(actor)
	local data = getStaticData(actor)
	if data == nil then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_ClientConfig)
	if npack == nil then return end

	LDataPack.writeByte(npack, data.p1 or 0)
	LDataPack.writeByte(npack, data.p2 or 0)
	LDataPack.writeInt(npack, data.p3 or 0)
	LDataPack.flush(npack)
end

local function onLogin(actor)
	s2cUpdateConfig(actor)
end

actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.cBaseCmd_ClientConfig, onUpdateConfig)
