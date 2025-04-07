module("csmsgdispatcher" , package.seeall)

local MsgFuncT = {}

Reg = function( cmd, subCmd, fun )
	if not MsgFuncT[cmd] then
		MsgFuncT[cmd] = {}
	end

	local func = MsgFuncT[cmd][subCmd]
	if func then
		assert("the cmd "..cmd.." subCmd "..subCmd.."have reg func")
	else
		MsgFuncT[cmd][subCmd] = fun
	end
end


function OnRecvCrossServerMsg(sId, sType, pack)
	local cmdType = LDataPack.readByte(pack)
	local subCmd = LDataPack.readByte(pack)

	if not MsgFuncT[cmdType] then
		print("!!!!!!! cmdType: "..cmdType, "subCmd: ", subCmd)
		return
	end

	local func = MsgFuncT[cmdType][subCmd]

	if func then
		func(sId, sType, pack)
	else
		print("!!!!!! subCmd: ", cmdType, " subCmd: ", subCmd)
	end

end


function TestCrossSrvMsgHdl()
		local pack = LDataPack.allocPacket()
		LDataPack.writeByte(pack, CrossSrvCmd.SFuncCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SFuncCmd_Test)
		LDataPack.writeByte(pack, 1)
		System.sendPacketToAllGameClient(pack, 0)

		print(" send ".. CrossSrvCmd.SFuncCmd.." "..CrossSrvSubCmd.SFuncCmd_Test)

end
_G.OnRecvCrossServerMsg = OnRecvCrossServerMsg
