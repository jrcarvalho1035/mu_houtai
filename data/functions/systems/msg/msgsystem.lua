module("msgsystem", package.seeall)
--[[
	离线消息系统
--]]

-- require("protocol")
-- require("utils.net.netmsgdispatcher")
local netmsgdispatcher = netmsgdispatcher
--local actorevent       = require("actorevent.actorevent")
--local actormoney       = require("systems.actorsystem.actormoney")

-- local SystemId 			 = SystemId
-- local enMsgSystemID	 	 = SystemId.enMsgSystemID
-- local eMsgSystemCode 	 = eMsgSystemCode
local System   			 = System
local LActor   			 = LActor

local LDataPack   = LDataPack
local writeByte   = LDataPack.writeByte
local writeWord   = LDataPack.writeWord
local writeInt    = LDataPack.writeInt
local writeInt64  = LDataPack.writeInt64
local writeString = LDataPack.writeString
local writeData   = LDataPack.writeData

local readByte    = LDataPack.readByte
local readWord 	  = LDataPack.readWord
local readInt  	  = LDataPack.readInt
local readString  = LDataPack.readString
local readData    = LDataPack.readData

local handles = {}

-- Comments: 注册消息处理
function regHandle( msgtype, func )
	if not msgtype or not func or type(func) ~= "function" then 
		assert(false)
	end
	handles[msgtype] = func
end

-- Comments: 处理离线消息
function ProcessLuaMsg( actor, msgtype, offmsg )
	if not actor or not msgtype or not offmsg then return false end
	local func = handles[msgtype]
	if not func then return false end
	local ret = func(actor, offmsg)
	return ret
end

----------------  BEGIN   消息注册处理   BEGIN  ----------------
-- C++调用 
_G.ProcessLuaMsg = ProcessLuaMsg



