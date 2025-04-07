module("guildcross", package.seeall)

local systemId = Protocol.CMD_Guild
function OnApplyInfo(actor, pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetApplyInfo)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeInt(npack, LActor.getGuildId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

local function onGetApplyInfo(sId, sType, cpack)
    LGuild.getGuildApplyInfo(LDataPack.readInt(cpack), LDataPack.readInt(cpack), sId)
end

local function onSendApplyInfo(sId, sType, cpack)    
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Guild, Protocol.sGuildCmd_ApplyInfo)
    if npack == nil then return end

    local count = LDataPack.readInt(cpack)
	LDataPack.writeInt(npack, count)
    for i=0, count-1 do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeByte(npack, LDataPack.readByte(cpack))
        LDataPack.writeByte(npack, LDataPack.readByte(cpack))
        LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
    end

    LDataPack.flush(npack)
end

function OnGuildLogList(actor, pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetGuildLogList)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeInt(npack, LActor.getGuildId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

local function OnGetGuildLogList(sId, sType, cpack)
    LGuild.getGuildLogList(LDataPack.readInt(cpack), LDataPack.readInt(cpack), sId)
end

local function OnSendGuildLogList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Guild, Protocol.sGuildCmd_GuildLogList)
    if npack == nil then return end

    local count = LDataPack.readInt(cpack)
	LDataPack.writeInt(npack, count)
    for i=0, count-1 do
        LDataPack.writeUInt(npack, LDataPack.readUInt(cpack))
        LDataPack.writeChar(npack, LDataPack.readChar(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
    end

    LDataPack.flush(npack)
end


function OnGuildSearchList(actor, pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetGuildLogList)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeInt(npack, LDataPack.readString(pack))
    System.sendPacketToAllGameClient(npack, 0)
end

local function OnGetSearchList(sId, sType, cpack)
    LGuild.getGuildSearchList(LDataPack.readInt(cpack), LDataPack.readString(cpack), sId)
end

local function OnSendSearchList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Guild, Protocol.sGuildCmd_GuildSearchList)
    if npack == nil then return end

    local count = LDataPack.readInt(cpack)
	LDataPack.writeInt(npack, count)
    for i=0, count-1 do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))        
        LDataPack.writeByte(npack, LDataPack.readByte(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
    end

    LDataPack.flush(npack)
end

function OnMemberList(actor, pack)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetMemberList)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeInt(npack, LActor.getGuildId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

local function onGetMemberList(sId, sType, cpack)
    LGuild.getGuildMemberList(LDataPack.readInt(cpack), LDataPack.readInt(cpack), sId)
end

local function onSendMemberList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Guild, Protocol.sGuildCmd_MemberList)
    if npack == nil then return end

    local count = LDataPack.readInt(cpack)
	LDataPack.writeInt(npack, count)
    for i=0, count-1 do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeByte(npack, LDataPack.readByte(cpack))
        LDataPack.writeByte(npack, LDataPack.readByte(cpack))
        LDataPack.writeByte(npack, LDataPack.readByte(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeByte(npack, LDataPack.readByte(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
        LDataPack.writeUInt(npack, LDataPack.readUInt(cpack))
    end

    LDataPack.flush(npack)
end

--请求公会列表
function OnGuildList(actor, pack)
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildCmd_GetGuildList)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

--跨服收到公会列表请求，
local function onGetGuildList(sId, sType, cpack)
    LGuild.onGetGuildList(LDataPack.readInt(cpack), sId)
end

--普通服收到公会列表信息
local function onSendGuildList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then
        return
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Guild, Protocol.sGuildCmd_GuildList)
    if npack == nil then return end

    local count = LDataPack.readInt(cpack)
	LDataPack.writeInt(npack, count)
    for i=0, count-1 do
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeByte(npack, LDataPack.readByte(cpack))
        LDataPack.writeInt(npack, LDataPack.readInt(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeString(npack, LDataPack.readString(cpack))
        LDataPack.writeByte(npack, LDataPack.readChar(cpack))
        LDataPack.writeDouble(npack, LDataPack.readDouble(cpack))
    end

    LDataPack.flush(npack)
end




netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_GuildList, OnGuildList)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_MemberList, OnMemberList)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ApplyInfo, OnApplyInfo)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_GuildLogList, OnGuildLogList)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_GuildSearchList, OnGuildSearchList)

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetGuildList, onGetGuildList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendGuildList, onSendGuildList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetMemberList, onGetMemberList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendMemberList, onSendMemberList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetApplyInfo, onGetApplyInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendApplyInfo, onSendApplyInfo)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetGuildLogList, OnGetGuildLogList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SenGuildLogList, OnSendGuildLogList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_GetSearchist, OnGetSearchList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_SendSearchList, OnSendSearchList)
