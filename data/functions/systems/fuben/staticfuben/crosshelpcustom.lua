module("crosshelpcustom", package.seeall)


function getCustomSystemVar()
	local s_var = System.getStaticVar()
	if not s_var.seekHelps then s_var.seekHelps = {} end
	return s_var.seekHelps
end

--申请帮助
function seekHelp(actor, custom)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCCustomCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCCustomCmd_SeekHelp)
    LDataPack.writeString(npack, LActor.getName(actor))
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    LDataPack.writeShort(npack, custom)
    LDataPack.writeInt(npack, LActor.getServerId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end

--收到申请帮助
function onSyncCustomHelp(sId, sType, cpack)
    if System.isBattleSrv() then
        System.sendPacketToAllGameClient(cpack, 0)
    end
    
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_AllFuben)
    LDataPack.writeByte(pack, Protocol.sGuajiCmd_SeekHelpRet)
    LDataPack.writeChar(pack, 2)
    local name = LDataPack.readString(cpack)
    LDataPack.writeString(pack, name)
    local actorid = LDataPack.readInt(cpack)
    LDataPack.writeInt(pack, actorid)
    local custom = LDataPack.readShort(cpack)
    LDataPack.writeShort(pack, custom)
    local serverid = LDataPack.readInt(cpack)
    System.broadcastData(pack)

    --记录申请帮助玩家所在服务器id
    local cvar = getCustomSystemVar()
    cvar[actorid] = {}
    cvar[actorid].custom = custom
    cvar[actorid].serverid = serverid
    cvar[actorid].name = name
end


function sendCustomSeekHelp(sId, sType, cpack)
    print("...... sendCustomSeekHelp start")
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_AllFuben)
    LDataPack.writeByte(pack, Protocol.sGuajiCmd_SeekHelpRet)
    LDataPack.writeChar(pack, 2)
    LDataPack.writeString(pack, LDataPack.readString(cpack))
    LDataPack.writeInt(pack, LDataPack.readInt(cpack))
    LDataPack.writeShort(pack, LDataPack.readShort(cpack))
    System.broadcastData(pack)
end

--帮助玩家
function helpActor(helpActor, helpvar, actorid, custom)
    print("...... helpActor start")
    local cvar = getCustomSystemVar()
    if not cvar[actorid] then 
        guajifuben.s2cHelpResult(helpActor, 2, helpvar.help_count)
        return 
    end
    if cvar[actorid].custom ~= custom then
		guajifuben.s2cHelpResult(helpActor, 2, helpvar.help_count)
		return
	end
	if LActor.getActorData(helpActor).total_power < GuajiFubenConfig[cvar[actorid].custom].power then
        guajifuben.s2cHelpResult(helpActor, 3, helpvar.help_count) --战力不足，不帮助玩家
        return
	end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCCustomCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCCustomCmd_HelpActor)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeInt(npack, cvar[actorid].serverid)
    LDataPack.writeInt(npack, LActor.getActorId(helpActor))
    LDataPack.writeInt(npack, LActor.getServerId(helpActor))
    LDataPack.writeString(npack, LActor.getName(helpActor))
    LDataPack.writeShort(npack, custom)
    System.sendPacketToAllGameClient(npack, 0)
end

function onSyncHelpBro(sId, sType, cpack)
    print("...... onSyncHelpBro start")
    if System.isBattleSrv() then
        System.sendPacketToAllGameClient(cpack, 0)
    end
    local pack = LDataPack.allocPacket()
    LDataPack.writeByte(pack, Protocol.CMD_AllFuben)
    LDataPack.writeByte(pack, Protocol.sGuajiCmd_HelpBrocast)
    LDataPack.writeChar(pack, 2)
    LDataPack.writeString(pack, LDataPack.readString(cpack))
    LDataPack.writeString(pack, LDataPack.readString(cpack))
    LDataPack.writeShort(pack, LDataPack.readShort(cpack))
    LDataPack.writeString(pack, LDataPack.readString(cpack))
    System.broadcastData(pack)
end

local function helpBrocast(helpname, name, custom)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCCustomCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCCustomCmd_HelpBro)
    LDataPack.writeString(npack, helpname)
    LDataPack.writeString(npack, name)
    LDataPack.writeShort(npack, custom)
    System.sendPacketToAllGameClient(npack, 0)
end

local function sendResult(result, actorid, helpactorid, helpserverid, helpname)
    print("...... sendResult start ")
    local name = ""
    if result == 1 then --成功
        local actor = LActor.getActorById(actorid)
        local var = guajifuben.getActorVar(actor)
        name = LActor.getName(actor)
        var.request_help_count = var.request_help_count + 1
		var.custom = var.custom + 1		
		var.kill_monster_idx = 0
		local ins = instancesystem.getActorIns(actor)
		if System.isCommSrv() and ins.config.type == 1 then
			guajifuben.enterGuajiFuben(actor)
		end
		guajifuben.s2cUpdateWaves(actor)
		guajifuben.onCustomChange(actor, var.custom)
		guajifuben.s2cReqHelpResult(actor, var.request_help_count, var.custom)
        local sheadstr = string.format(GuajiConstConfig.shead,  var.custom-1)
	    local snamestr = helpname
        local rewards = drop.dropGroup(GuajiFubenConfig[var.custom - 1].drop)
	    local mailData = {head = sheadstr, context = string.format(GuajiConstConfig.scontent, snamestr, var.custom - 1), tAwardList = rewards}
	    mailsystem.sendMailById(actorid, mailData)
		helpBrocast(helpname, LActor.getName(actor), var.custom - 1)
    end

    --向帮助玩家服发送帮助结果
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCCustomCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCCustomCmd_HelpResult)
    LDataPack.writeByte(npack, result)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeInt(npack, helpactorid)
    LDataPack.writeInt(npack, helpserverid)
    System.sendPacketToAllGameClient(npack, 0)
end

--其他服收到玩家帮助
function onSyncHelpActor(sId, sType, cpack)
    print("...... onSyncHelpActor start")
    local actorid = LDataPack.readInt(cpack) --请求人id
    local serverid = LDataPack.readInt(cpack) --请求人服务器id
    local helpactorid = LDataPack.readInt(cpack) --帮助人id
    local helpserverid = LDataPack.readInt(cpack) --帮助人服务器id
    local helpName = LDataPack.readString(cpack) --帮助人名字
    local helpcustom = LDataPack.readShort(cpack) --帮助关卡id
    local actor = LActor.getActorById(actorid)
    if System.isBattleSrv() then
        if actor then
            local dvar = guajifuben.getDyanmicVar(actor)	
            if not guajifuben.eid or guajifuben.getCustom(actor) ~= helpcustom then
                sendResult(0, actorid, helpactorid, helpserverid)
                return
            end
            sendResult(1, actorid, helpactorid, helpserverid, helpName)
        else
            System.sendPacketToAllGameClient(cpack, serverid)
        end
    else
        if actor then
            local dvar = guajifuben.getDyanmicVar(actor)
            if not dvar.eid or guajifuben.getCustom(actor)+1 ~= helpcustom then
                sendResult(0, actorid, helpactorid, helpserverid)
                return
            end
            sendResult(1, actorid, helpactorid, helpserverid, helpName)
        else
            sendResult(0, actorid, helpactorid, helpserverid)
        end
    end
end

function helpResult(helpActor, result, actorid, helpactorid)
    print("...... helpResult start")
    local cvar = getCustomSystemVar()
    if not cvar[actorid] then
        return
    end
    local helpvar = guajifuben.getActorVar(helpActor)
    if result == 0 then
        guajifuben.s2cHelpResult(helpActor, 2, helpvar.help_count)
        return
    end
    helpvar.help_count = helpvar.help_count + 1
    guajifuben.s2cHelpResult(helpActor, 1, helpvar.help_count)
    local hhcontext = string.format(GuajiConstConfig.hcontent, cvar[actorid].name, cvar[actorid].custom)
    mailData = {head = GuajiConstConfig.hhead, context = hhcontext, tAwardList= GuajiFubenConfig[cvar[actorid].custom].helprewards}	
    mailsystem.sendMailById(helpactorid, mailData)
end


function onSyncHelpActorResult(sId, sType, cpack)
    print("...... onSyncHelpActorResult start")
    local result = LDataPack.readByte(cpack)
    local actorid = LDataPack.readInt(cpack) --请求人id
    local helpactorid = LDataPack.readInt(cpack) --帮助人id    
    local helpserverid = LDataPack.readInt(cpack) --帮助人服务器id
    local helpActor = LActor.getActorById(helpactorid)
    if System.isBattleSrv() then
        if helpActor then
            helpResult(helpActor, result, actorid, helpactorid)
        else
            System.sendPacketToAllGameClient(cpack, helpserverid)
        end
    else
        if helpActor then
            helpResult(helpActor, result, actorid, helpactorid)
        end
    end
    local cvar = getCustomSystemVar()
    cvar[actorid] = nil
end

csmsgdispatcher.Reg(CrossSrvCmd.SCCustomCmd, CrossSrvSubCmd.SCCustomCmd_SeekHelp, onSyncCustomHelp)
csmsgdispatcher.Reg(CrossSrvCmd.SCCustomCmd, CrossSrvSubCmd.SCCustomCmd_HelpActor, onSyncHelpActor)
csmsgdispatcher.Reg(CrossSrvCmd.SCCustomCmd, CrossSrvSubCmd.SCCustomCmd_HelpResult, onSyncHelpActorResult)
csmsgdispatcher.Reg(CrossSrvCmd.SCCustomCmd, CrossSrvSubCmd.SCCustomCmd_HelpBro, onSyncHelpBro)


netmsgdispatcher.reg(Protocol.CMD_AllFuben, Protocol.cGuajiCmd_HelpActor, c2sHelpActor)






