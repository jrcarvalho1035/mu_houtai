-- @version	1.0
-- @author	rancho
-- @date	2019-06-21 
-- @system  合服事件
module("hefuevent", package.seeall)

local dispatcher = {}
function reg(fun, ...)
    table.insert(dispatcher, {fun, arg})
end

function onEvent(master, slaveTbl)
    for k,v in ipairs(dispatcher) do
        v[1](master, slaveTbl, unpack(v[2]))
    end
end

local hefuEvents = hefuEvents or {}
function hefuCallBack(master, slaveTbl)
    if not System.isCommSrv() then return end
    --如果连接了就马上发去跨服，还没有连接就先保存到hefuEvents里面
    if csbase.isConnected(csbase.getCrossServerId()) then
        print("hefuevent.hefuCallBack server is connected")
        local pack = LDataPack.allocPacket()
        if pack == nil then return end
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFuCmd)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHeFuCmd_HeFuEvents)

        LDataPack.writeInt(pack, master)
        LDataPack.writeByte(pack, #slaveTbl)
        for i=1, #slaveTbl do
            LDataPack.writeInt(pack, slaveTbl[i])
        end

        System.sendPacketToAllGameClient(pack, csbase.getCrossServerId())
    else
        print("hefuevent.hefuCallBack server is disconnected")
        local tbl = {mId=master, sbl=slaveTbl}
        table.insert(hefuEvents, tbl)
    end
end

local function onCrossServerConnected(serverId, serverType)
    if not System.isCommSrv() then return end
    print("hefuevent.onCrossServerConnected send hefuEvents")
    for k,v in ipairs(hefuEvents) do
        local pack = LDataPack.allocPacket()
        if pack == nil then return end
        LDataPack.writeByte(pack, CrossSrvCmd.SCHeFuCmd)
        LDataPack.writeByte(pack, CrossSrvSubCmd.SCHeFuCmd_HeFuEvents)

        LDataPack.writeInt(pack, v.mId)
        LDataPack.writeByte(pack, #v.sbl)
        for i=1, #v.sbl do
            LDataPack.writeInt(pack, v.sbl[i])
        end

        System.sendPacketToAllGameClient(pack, csbase.getCrossServerId())
    end
    hefuEvents = {}
end

local function onRecvHeFuEvents(sId, sType, dp)
    local master = LDataPack.readInt(dp)
    local num = LDataPack.readByte(dp)
    local tbl = {}
    for i=1, num do
        local slave = LDataPack.readInt(dp)
        table.insert(tbl, slave)
    end
    print("hefuevent.onRecvHeFuEvents master:"..master..",num:"..num..",sId:"..sId)
    onEvent(master, tbl)
end

reg(hefuCallBack)

csbase.RegConnected(onCrossServerConnected)
csmsgdispatcher.Reg(CrossSrvCmd.SCHeFuCmd, CrossSrvSubCmd.SCHeFuCmd_HeFuEvents, onRecvHeFuEvents)
