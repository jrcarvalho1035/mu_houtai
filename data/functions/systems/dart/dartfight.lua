module("dartfight", package.seeall)



local function c2sPlunder(actor, pack)
    local guildId = LDataPack.readInt(pack)

    local myGuildId = LActor.getGuildId(actor)
    if guildId == 0 or guildId == myGuildId then
        print("c2sPlunder guilid is not right:",guildId)
        return
    end

    local var = dartsystem.getActorVar(actor)
    if var.nextplundertime > System.getNowTime() then
        print("c2sPlunder cooldown")
        return
    end

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_ReqPlunder)
    LDataPack.writeInt(npack, guildId)
    LDataPack.writeInt(npack, LActor.getActorId(actor))
    System.sendPacketToAllGameClient(npack, 0)
end


local function onReqPlunder(sId, sType, cpack)
    local guildId = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    
    local openindex = dartcross.getOpenIndex()
    if openindex == 0 then return end

    local gvar = dartcross.getGlobalData()
    --local guildcar = gvar.guildcars[guildId]
    if not gvar.guildcars[guildId] then
        print("on ReqPlunder not this guild id:",guildId)
        return
    end

    if gvar.guildcars[guildId].plundercount == DartConstConfig.dartCarBreakNum then
        print("on plunder remain count is zero")
        return
    end

    if dartcross.DART_END then
        print("dartcross is end")
        return
    end

    local hfuben = instancesystem.createFuBen(DartConstConfig.fbId)

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_CanPlunder)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeInt64(npack, hfuben)
    LDataPack.writeInt(npack, guildId)    
    System.sendPacketToAllGameClient(npack, 0)
end
    
local function onCanPlunder(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    if not actor then 
        print("dart onCanPlunder actorid", actorid)
        return 
    end

    local var = dartsystem.getActorVar(actor)
    var.nextplundertime = System.getNowTime() + DartConstConfig.coolingTime
    if actoritem.getItemCount(actor, NumericType_DartToken) < 1 then
        return
    end
    actoritem.reduceItem(actor, NumericType_DartToken, 1, "dart plunder")    

    local hfuben = LDataPack.readInt64(cpack)
    local guildId = LDataPack.readInt(cpack)

    var.fightGuildId = guildId

    local crossId = csbase.getCrossServerId()
    local actorPos = DartConstConfig.actorPos
    LActor.loginOtherServer(actor, crossId, hfuben, 0, actorPos.x, actorPos.y, "cross")    
end

local function onBeforeEnterFb(ins, actor)
    local var = dartsystem.getActorVar(actor)
    local guildId = var.fightGuildId
    local gvar = dartcross.getGlobalData()    
    local guildcar = gvar.guildcars[guildId]
    if not guildcar then 
        sendResult(ins, 3)
        print("dart onBeforeEnterFb guildid", guildId)
        return 
    end

    if guildcar.plundercount >= DartConstConfig.dartCarBreakNum then
        print("dart onBeforeEnterFb guildcar.plundercount ", guildcar.plundercount)
        sendResult(ins, 3)
        LActor.exitFuben(actor)
        return
    end

    local openindex = dartcross.getOpenIndex()
    if openindex == 0 then 
        sendResult(ins, 3)
        print("dart onBeforeEnterFb", openindex)
        return 
    end

    local guildvar = dartcross.getGuildGlobal(guildId)
    if not guildvar[openindex].actorlist or #guildvar[openindex].actorlist == 0 then
        sendResult(ins, 3)
        print("dart onBeforeEnterFb", openindex)
        return
    end
    ins.data.dartGuildId = guildId
    ins.data.dartopenindex = openindex
    ins.data.dartplundercount = guildcar.plundercount
    ins.data.actorlist = utils.table_clone(guildvar[openindex].actorlist)
    print("onBeforeEnterFb guildcar.dartkillrobot:", guildcar.dartkillrobot)
    if not reqClone(ins.data.actorlist, ins.handle, guildId) then
        ins.data.dartkillrobot = guildcar.dartkillrobot or 0
        for i=1, #DartRobotConfig[guildcar.carlevel] do            
            if i >= (guildcar.dartkillrobot or 0) and not ins.data.dartrefreshrobot then
                setRobot(guildcar, ins.handle, i, roleCloneData, actorData, roleSuperData)
            end            
        end
        ins.data.dartrefreshrobot = true
    end
    --actorevent.onEvent(actor, aeEnterFuben, ins.config.fbid, false)
end

function setRobot(guildcar, hfuben, i, roleCloneData, actorData, roleSuperData)
    local roleCloneData, actorData, roleSuperData = actorcommon.createRobotClone(DartRobotConfig[guildcar.carlevel], i, "")
    local addattrper = DartConstConfig.addattrper[guildcar.plundercount]
    if not addattrper then
        addattrper = 0
    end           
    for j = Attribute.atHp, Attribute.atCount - 1 do
        if j ~= Attribute.atMvSpeed then
            roleCloneData.attrs:Set(j, roleCloneData.attrs[j] * (1+ addattrper/10000))
        end
    end
    setMirror(hfuben, i, roleCloneData, actorData, roleSuperData)
end

--查不到actorid，查下一个人
function reqClone(actorlist, hfuben, guildId, count)
    curcount = count or 1
    for k,v in ipairs(actorlist) do
        if v.hpper > 0 then
            local npack = LDataPack.allocPacket()
            LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
            LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_ReqActor)
            LDataPack.writeInt(npack, v.actorid)
            LDataPack.writeInt64(npack, hfuben)
            LDataPack.writeInt(npack, guildId)
            System.sendPacketToAllGameClient(npack, v.serverid)
            curcount = curcount - 1
            if curcount == 0 then
                break
            end
        end
    end
    if curcount > 0 then --没有玩家了
        return false
    end
    return true
end

local function onOffline(ins, actor)
    LActor.exitFuben(actor)
end

local function onExitFb(ins, actor)
    if not ins then return end
    if ins.data.isExit then        
        return
    end
    ins.data.isExit = true
    local guildId = ins.data.dartGuildId
    local gvar = dartcross.getGlobalData()
    local guildcar = gvar.guildcars[guildId]
    if not guildcar then return end
    if guildcar.remainpeople > guildcar.maxpeople - (ins.data.killclonecount or 0) then
        guildcar.remainpeople = guildcar.maxpeople - (ins.data.killclonecount or 0)
        if guildcar.remainpeople == 0 then
            guildcar.remainpeople = guildcar.maxpeople
        end
    end
    guildcar.dartkillrobot = ins.data.dartkillrobot
    if ins.data.dart_is_end then
        print("dart onExitFb act is end")
        guildcar.remainpeople = guildcar.maxpeople
        return
    end
    local openindex = ins.data.dartopenindex
    
    local var = dartsystem.getActorVar(actor)
    local guildvar = dartcross.getGuildGlobal(guildId)
    if not guildvar then return end    

    actoritem.addItems(actor, DartCarConfig[guildcar.carlevel].failreward, "dart fight fail")

    local count = 0
    for k,v in ipairs(DartCarConfig[guildcar.carlevel].failreward) do
        if v.id == NumericType_DartScore then
            count = v.count
        end
    end
    local actorid = LActor.getActorId(actor)
    local killGuilID = LActor.getGuildId(actor)
    if killGuilID ~= 0 then
        dartrank.addSelfRank(gvar, actorid, LActor.getServerId(actor), count, LActor.getName(actor), killGuilID)
        dartrank.addSelfRecord(actorid, 3, guildcar.carlevel, 0, count, LGuild.getGuilNameById(guildId), 0)
    end
end


local function onReqActor(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    local actor = LActor.getActorById(actorid)
    local hfuben = LDataPack.readInt64(cpack)
    local guildId = LDataPack.readInt(cpack)
	if actor then--先暴力处理
		offlinedatamgr.CallEhLogout(actor) --保存离线数据
    end
    
    local actorData = offlinedatamgr.GetDataByOffLineDataType(actorid, offlinedatamgr.EOffLineDataType.EBasic)
    if actorData==nil then
        print(".onReqActor actorid:",actorid)
		return
	end
	local actorDataUd = bson.encode(actorData)

	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(pack, CrossSrvSubCmd.SCGuildDartCmd_SendActor)
    LDataPack.writeChar(pack, 1) --查到镜像数据
    LDataPack.writeInt(pack, guildId)
	LDataPack.writeInt(pack, actorid)
	LDataPack.writeInt64(pack, hfuben)
	LDataPack.writeUserData(pack, actorDataUd)

	System.sendPacketToAllGameClient(pack, 0)
end

local function onSendActor(sId, sType, cpack)
    local isclone = LDataPack.readChar(cpack)
    local guildId = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local hfuben = LDataPack.readInt64(cpack)
    local openindex = dartcross.getOpenIndex()
    
    if openindex == 0 then
        local ins = instancesystem.getInsByHdl(hfuben)
        if not ins then return end
        sendResult(ins, 3)
        print("onSendActor dart is end actorid:",actorid)
        return 
    end
    local gvar = dartcross.getGlobalData()
    local guildcar = gvar.guildcars[guildId]
    if not guildcar then 
        local ins = instancesystem.getInsByHdl(hfuben)
        if not ins then return end
        sendResult(ins, 3)
        print("onSendActor dart is end guild:",guildId)
        return 
    end

    local guildvar = dartcross.getGuildGlobal(guildId)
    if not guildvar or not guildvar[openindex].actorlist or #guildvar[openindex].actorlist == 0 then
        local ins = instancesystem.getInsByHdl(hfuben)
        if not ins then return end
        sendResult(ins, 3)
        print("onSendActor dart is end openindex:",openindex)
        return
    end

    local actorDataUd = LDataPack.readUserData(cpack)
    local offlinedata = bson.decode(actorDataUd)    
    local roleCloneData, actorCloneData, roleSuperData = actorcommon.getCloneDataByOffLineData(offlinedata)
    local addattrper = DartConstConfig.addattrper[guildcar.plundercount]
    if not addattrper then
        addattrper = 0
    end
    local changeHp = 0
    for k,v in ipairs(guildvar[openindex].actorlist) do
        if v.actorid == actorid then        
            for j = Attribute.atHp, Attribute.atCount - 1 do
                if j == Attribute.atHp then
                    changeHp = math.floor(roleCloneData.attrs[Attribute.atHpMax] * (100 - v.hpper)/100)
                    --roleCloneData.attrs:Set(j, math.floor(roleCloneData.attrs[Attribute.atHpMax] * v.hpper/100))
                elseif j == Attribute.atAtkPer or j == Attribute.atHpPer then
					roleCloneData.attrs:Set(j, math.floor(roleCloneData.attrs[j] * (1+ addattrper/10000)))
				end
			end
            break
        end
    end
    setMirror(hfuben, actorid, roleCloneData, actorCloneData, roleSuperData, changeHp)
end

--创建镜像玩家攻击玩家
function setMirror(hfuben, actorid, roleCloneData, actorCloneData, roleSuperData, changeHp)    
    local ins = instancesystem.getInsByHdl(hfuben)
    if not ins then return end
    local hScene = ins.scene_list[1]
    if roleSuperData then
        roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1], FubenConstConfig.randChangeTime[2])
        roleSuperData.aiId = FubenConstConfig.roleSuperAi
    end
 
    local rand = math.random(1, #DartConstConfig.randomPos)
    local pos = DartConstConfig.randomPos[rand]
    local actorClone = LActor.createActorCloneWithData(actorid, hScene, pos.x, pos.y, actorCloneData, roleCloneData, roleSuperData)
    local roleClone = LActor.getRole(actorClone)
    if roleClone then
        LActor.setEntityScenePos(roleClone, pos.x, pos.y)
        if changeHp then
            LActor.changeHp(roleClone, -changeHp)
        end
    end
    local yongbing = LActor.getYongbing(actorClone)
    if yongbing then
        LActor.setEntityScenePos(yongbing, pos.x, pos.y)
    end
end

function sendResult(ins, result)
    local actor = ins:getActorList()[1]
    if not actor then return end
    local var = dartsystem.getActorVar(actor)
    if not var then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_Result)
    LDataPack.writeShort(npack, math.max(0, var.nextplundertime - System.getNowTime()))
    LDataPack.writeChar(npack, result)
    LDataPack.flush(npack)
end

function onActorCloneDie(ins, killerHdl, actorClone)
    if not ins then return end
    local guildId = ins.data.dartGuildId
    local openindex = ins.data.dartopenindex
    local cloneActorId = LActor.getActorIdClone(actorClone)

    if dartcross.DART_END then
        sendResult(ins, 3)
        print("onActorCloneDie dart is end ")
        return
    end
    
    local guildvar = dartcross.getGuildGlobal(guildId)
    if not guildvar then return end
    if not ins.data.actorlist or #ins.data.actorlist == 0 then
        sendResult(ins, 3)
        print("onActorCloneDie dart is no actors")
        return
    end
    local gvar = dartcross.getGlobalData()
    if not gvar.guildcars[guildId] then  
        sendResult(ins, 3)
        print("onActorCloneDie dart is no guild guilid =",guildId)
        return 
    end
    
    ins.data.killclonecount = (ins.data.killclonecount or 0) + 1
    print(" dart onActorCloneDie", cloneActorId, ins.data.killclonecount)
    local carlevel = gvar.guildcars[guildId].carlevel
    local isrobot = DartRobotConfig[carlevel][cloneActorId] and true or false
    if not isrobot then        
        ins.data.killWaveCount = (ins.data.killWaveCount or 0) + 1
        for k,v in ipairs(ins.data.actorlist) do
            if v.actorid == cloneActorId then
                v.hpper = 0
                if guildvar[openindex] and guildvar[openindex].actorlist and guildvar[openindex].actorlist[k] then
                    guildvar[openindex].actorlist[k].hpper = 0
                end
            end
        end
    else        
        ins.data.dartkillrobot = (ins.data.dartkillrobot or 0) + 1
        if ins.data.dartkillrobot >= #DartRobotConfig[carlevel] then
            gvar.guildcars[guildId].dartkillrobot = 0
            --ins.data.dartkillrobot = 0
            ins:win()
            return
        end
    end

    local yongbing = LActor.getYongbing(actorClone)
    if yongbing then
        LActor.killYongbing(yongbing)
    end
    
    if (ins.data.killWaveCount or 0) >= 2 and (ins.data.killWaveCount or 0) == (ins.data.refreshcount or 2)  then
        ins.data.killWaveCount = 0
        ins.data.refreshwave = (ins.data.refreshwave or 0) + 1
        ins.data.refreshcount = (ins.data.refreshcount or 1) + 1
        if not reqClone(ins.data.actorlist, ins.handle, guildId, ins.data.refreshcount) and not ins.data.dartrefreshrobot then
            for i=1, #DartRobotConfig[carlevel] do
                local roleCloneData, actorData, roleSuperData = actorcommon.createRobotClone(DartRobotConfig[carlevel], i, "")       
                setRobot(gvar.guildcars[guildId], ins.handle, i, roleCloneData, actorData, roleSuperData)
            end
            ins.data.dartrefreshrobot = true
        end
    elseif (ins.data.killWaveCount or 0) < 2 and (ins.data.refreshwave or 0) == 0 then
        if not reqClone(ins.data.actorlist, ins.handle, guildId, 1) and not ins.data.dartrefreshrobot then
            for i=1, #DartRobotConfig[carlevel] do
                local roleCloneData, actorData, roleSuperData = actorcommon.createRobotClone(DartRobotConfig[carlevel], i, "")       
                setRobot(gvar.guildcars[guildId], ins.handle, i, roleCloneData, actorData, roleSuperData)
            end
            ins.data.dartrefreshrobot = true
        end
    end    
end

function onActorDie(ins, actor, killerHdl, killActorId, killHpper)
    if not ins then return end
    ins.data.dart_is_end = true
    if dartcross.DART_END then
        local var = dartsystem.getActorVar(actor)
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_Result)        
        LDataPack.writeShort(npack, math.max(0, var.nextplundertime - System.getNowTime()))
        LDataPack.writeChar(npack, 3)
        LDataPack.flush(npack)
        return
    end
    local et = LActor.getEntity(killerHdl)
    local name = LActor.getName(et)

    local openindex = ins.data.dartopenindex
    local guildId = ins.data.dartGuildId
    local gvar = dartcross.getGlobalData()
    local guildcar = gvar.guildcars[guildId]
    local var = dartsystem.getActorVar(actor)
    local guildvar = dartcross.getGuildGlobal(guildId)
    for k,v in ipairs(guildvar[openindex].actorlist) do
        if v.actorid == killActorId then            
            v.hpper = killHpper
        end
    end

    actoritem.addItems(actor, DartCarConfig[guildcar.carlevel].failreward, "dart fight fail")

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_Result)
    LDataPack.writeShort(npack, math.max(0, var.nextplundertime - System.getNowTime()))
    LDataPack.writeChar(npack, 0)
    LDataPack.writeChar(npack, guildcar.carlevel)
    LDataPack.writeString(npack, LGuild.getGuilNameById(guildId))
    LDataPack.writeString(npack, name)    
    LDataPack.flush(npack)
    local actorid = LActor.getActorId(actor)
    local count = 0
    for k,v in ipairs(DartCarConfig[guildcar.carlevel].failreward) do
        if v.id == NumericType_DartScore then
            count = v.count
        end
    end
    local killGuilID = LActor.getGuildId(actor)
    if killGuilID ~= 0 then
        dartrank.addSelfRank(gvar, actorid, LActor.getServerId(actor), count, LActor.getName(actor), killGuilID)
        dartrank.addSelfRecord(actorid, 3, guildcar.carlevel, 0, count, LGuild.getGuilNameById(guildId), 0, name)
    end

    print("....dart onActorDie", actorid, killGuilID, guildcar.carlevel)
end

function onWin(ins)
    if not ins then return end
    ins.data.dart_is_end = true
    local actor = ins:getActorList()[1]
    local guildId = ins.data.dartGuildId
    local gvar = dartcross.getGlobalData()
    local guildcar = gvar.guildcars[guildId]
    if not guildcar.dartwintimes then guildcar.dartwintimes = {} end
    guildcar.remainpeople = guildcar.maxpeople 
    local actorid = LActor.getActorId(actor)    
    guildcar.dartwintimes[ins.data.dartplundercount] = (guildcar.dartwintimes[ins.data.dartplundercount] or 0) + 1
    print("....dart onWin actorid", actorid, guildcar.dartwintimes[ins.data.dartplundercount])
    if guildcar.dartwintimes[ins.data.dartplundercount] == 1 then
        local killGuilID = LActor.getGuildId(actor)
        guildcar.winName = LActor.getName(actor)
        guildcar.winGuildName = LGuild.getGuilNameById(killGuilID)
        guildcar.plundercount = guildcar.plundercount + 1

        local items = {}

        for k,v in ipairs(DartCarConfig[guildcar.carlevel].plunderreward) do
            table.insert(items, {id = v.id, count = v.count})
        end

        local guildvar = dartcross.getGuildGlobal(guildId)
        for k,v in ipairs(guildvar[ins.data.dartopenindex].actorlist) do            
            v.hpper = 100
        end

        actoritem.addItems(actor, items, "dart fight win")
        local var = dartsystem.getActorVar(actor)
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_Result)
        LDataPack.writeShort(npack, math.max(0, var.nextplundertime - System.getNowTime()))
        LDataPack.writeChar(npack, 1)
        LDataPack.writeChar(npack, guildcar.carlevel)
        LDataPack.writeString(npack, LGuild.getGuilNameById(guildId))
        LDataPack.writeString(npack, guildcar.winName)        
        LDataPack.flush(npack)
        
        local selfScore = 0
        for k,v in ipairs(DartCarConfig[guildcar.carlevel].plunderreward) do
            if v.id == NumericType_DartScore then
                selfScore = selfScore + v.count
                break
            end
        end

        if killGuilID ~= 0 then
            dartrank.addGuildRank(gvar, killGuilID, DartCarConfig[guildcar.carlevel].plunderguild)        
            dartrank.addGuildRecord(guildId, 3, nil,nil,nil,nil, LGuild.getGuilNameById(killGuilID), LActor.getName(actor))        
            dartrank.addSelfRank(gvar, actorid, LActor.getServerId(actor), selfScore, LActor.getName(actor), killGuilID)
            dartrank.addSelfRecord(actorid, 3, guildcar.carlevel, DartCarConfig[guildcar.carlevel].plunderguild, selfScore, LGuild.getGuilNameById(guildId), 1)        
        end
    else
        
        actoritem.addItems(actor, DartCarConfig[guildcar.carlevel].sucreward, "dart fight win")
        local var = dartsystem.getActorVar(actor)
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Dart, Protocol.sDartCmd_Result)
        LDataPack.writeShort(npack, math.max(0, var.nextplundertime - System.getNowTime()))
        LDataPack.writeChar(npack, 2)
        LDataPack.writeChar(npack, guildcar.carlevel)
        LDataPack.writeString(npack, guildcar.winGuildName or "")
        LDataPack.writeString(npack, guildcar.winName or "")        
        LDataPack.flush(npack)

        local selfScore = 0
        for k,v in ipairs(DartCarConfig[guildcar.carlevel].sucreward) do
            if v.id == NumericType_DartScore then
                selfScore = selfScore + v.count
                break
            end
        end
        local killGuilID = LActor.getGuildId(actor)
        if killGuilID ~= 0 then
            dartrank.addSelfRank(gvar, actorid, LActor.getServerId(actor), selfScore, LActor.getName(actor), killGuilID)
            dartrank.addSelfRecord(actorid, 3, guildcar.carlevel, 0, selfScore, LGuild.getGuilNameById(guildId), 1)
        end
    end
end


function onInitFuben()
    if System.isLianFuSrv() then return end
    local fbId = DartConstConfig.fbId
    insevent.registerInstanceWin(fbId, onWin)
    insevent.registerInstanceEnterBefore(fbId, onBeforeEnterFb)
    insevent.registerInstanceExit(fbId, onExitFb)
    insevent.regActorCloneDie(fbId, onActorCloneDie)
    insevent.registerInstanceActorDie(fbId, onActorDie)
    insevent.registerInstanceOffline(fbId, onOffline)

	if System.isCrossWarSrv() then return end
    netmsgdispatcher.reg(Protocol.CMD_Dart, Protocol.cDartCmd_Plunder, c2sPlunder) --掠夺
end
table.insert(InitFnTable, onInitFuben)



csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_ReqPlunder, onReqPlunder)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_CanPlunder, onCanPlunder)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_ReqActor, onReqActor)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_SendActor, onSendActor)

