
module("dartcross", package.seeall)

local refreshGuildCount = 5

DART_END = DART_END or false

function getGlobalData()
	local data = System.getStaticDartVar()
	if not data then return end
	if not data.dart then data.dart = {} end
    if not data.dart.guilddata then data.dart.guilddata = {} end
    if not data.dart.selfrank then data.dart.selfrank = {} end
    if not data.dart.selfrank.first then data.dart.selfrank.first = {} end
    if not data.dart.guildrank then data.dart.guildrank = {} end
    if not data.dart.guildcars then data.dart.guildcars = {} end
    if not data.dart.guildcarscount then data.dart.guildcarscount = 0 end
    if not data.dart.actorrefreshs then data.dart.actorrefreshs = {} end
	return data.dart;
end

function getGuildGlobal(guildId)
    local guildvar = getGlobalData()
    if not guildvar.guilddata[guildId] then guildvar.guilddata[guildId] = {} end
    for i=1, 3 do
        if not guildvar.guilddata[guildId][i] then
            guildvar.guilddata[guildId][i] = {}
            guildvar.guilddata[guildId][i].actorlist = {}            
        end
    end

    return guildvar.guilddata[guildId]
end

function onDeleteMember(guildId, actorid)
    local guildvar = getGuildGlobal(guildId)
    for i=1, #DartConstConfig.startTimes do
        for j=1, #guildvar[i].actorlist do
            if guildvar[i].actorlist[j].actorid == actorid then
                table.remove(guildvar[i].actorlist, j)
                break
            end
        end
    end
end

function changeChoose(index, guildId, actorid, level, power, name, sId)
    print("dart actor changeChoose :", guildId, actorid, name)
    local guildvar = getGuildGlobal(guildId)
    local gvar = getGlobalData()
    local choose1 = 0
    local choose2 = 0
    local isChoose = false
    for i=1, #DartConstConfig.startTimes do
        for j=1, #guildvar[i].actorlist do
            if guildvar[i].actorlist[j].actorid == actorid then
                if choose1 == 0 then
                    choose1 = i
                elseif choose2 == 0 then
                    choose2 = i
                end
            end
        end
    end
    local ishave = false    
    for i=1, #guildvar[index].actorlist do
        if guildvar[index].actorlist[i].actorid == actorid then
            table.remove(guildvar[index].actorlist, i)
            if choose1 == index then
                choose1 = 0
            elseif choose2 == index then
                choose2 = 0
            end
            ishave = true
            break
        end
    end
    if not ishave then
        if choose1 == 0 then
            choose1 = index
        elseif choose2 == 0 then
            choose2 = index
        else
            return
        end
        table.insert(guildvar[index].actorlist, {actorid = actorid, serverid = sId, name = name, level = level, power = power})
    end

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_ChooseCarRet)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, choose1)
    LDataPack.writeChar(npack, choose2)
    System.sendPacketToAllGameClient(npack, 0)
end

local function onChooseCar(sId, sType, cpack)
    local index = LDataPack.readChar(cpack)
    local guildId = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local level = LDataPack.readInt(cpack)
    local power = LDataPack.readDouble(cpack)
    local name = LDataPack.readString(cpack)

    changeChoose(index, guildId, actorid, level, power, name, sId)
end

local function onGetCarList(sId, sType, cpack)
    local guildId = LDataPack.readInt(cpack)
    local actorid = LDataPack.readInt(cpack)
    local guildvar = getGuildGlobal(guildId)

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_SendCarList)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, #DartConstConfig.startTimes)
    for i=1, #DartConstConfig.startTimes do
        LDataPack.writeChar(npack, 0)
        LDataPack.writeChar(npack, #guildvar[i].actorlist)
        for j=1, #guildvar[i].actorlist do
            LDataPack.writeString(npack, guildvar[i].actorlist[j].name)
            LDataPack.writeInt(npack, guildvar[i].actorlist[j].level)
            LDataPack.writeDouble(npack, guildvar[i].actorlist[j].power)
        end
    end
    System.sendPacketToAllGameClient(npack, sId)
end

function getRefreshCar(gvar, actorid)
    print("dart actor onRefreshPlunderList actorid:", actorid)
    gvar.actorrefreshs[actorid] = {}
    if gvar.guildcarscount <= refreshGuildCount then
        local index = 0
        for k,v in pairs(gvar.guildcars) do
            index = index + 1
            gvar.actorrefreshs[actorid][index] = k
        end
    else
        local indexs = utils.getRandomIndexs(1, gvar.guildcarscount, refreshGuildCount) --不重复随机数，限制匹配到自身
        table.sort(indexs)
        local index = 1
        local i = 1
        for k,v in pairs(gvar.guildcars) do
            if indexs[i] == index then
                gvar.actorrefreshs[actorid][i] = k
                i=i+1
            end
            index = index + 1
        end
    end
end

local function onRefreshPlunderList(sId, sType, cpack)
    if DART_END then return end
    local type = LDataPack.readChar(cpack)
    local actorid = LDataPack.readInt(cpack)
    local gvar = getGlobalData()
    if not gvar.actorrefreshs[actorid] then gvar.actorrefreshs[actorid] = {} end
    local gvar = getGlobalData()
    if type == 1 or #gvar.actorrefreshs[actorid] == 0 then
        print("dart actor onRefreshPlunderList actorid:", actorid)
        getRefreshCar(gvar, actorid)
    end
    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_RefreshPlunerListRet)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, type)
    LDataPack.writeChar(npack, #gvar.actorrefreshs[actorid])
    local index = 1
    local carindex = 1
    for i=1, #gvar.actorrefreshs[actorid] do
        local guildcar = gvar.guildcars[gvar.actorrefreshs[actorid][i]]
        LDataPack.writeInt(npack, gvar.actorrefreshs[actorid][i])
        LDataPack.writeString(npack, guildcar.guildname)
        LDataPack.writeChar(npack, guildcar.carlevel) --镖车等级
        LDataPack.writeChar(npack, guildcar.remainpeople) --剩余镖师数量
        LDataPack.writeChar(npack, guildcar.maxpeople)--最大镖师数量
        LDataPack.writeChar(npack, DartConstConfig.dartCarBreakNum - guildcar.plundercount)--可掠夺次数
    end
    LDataPack.writeChar(npack, getOpenIndex())--最大镖师数量
    System.sendPacketToAllGameClient(npack, sId)
end

function sendPlunderList(sId, actorid)
    local gvar = getGlobalData()
    if not gvar.actorrefreshs[actorid] then gvar.actorrefreshs[actorid] = {} end
    
    if #gvar.actorrefreshs[actorid] == 0 then
        getRefreshCar(gvar, actorid)
    end
    if gvar.guildcarscount == 0 then
        gvar.actorrefreshs[actorid] = {}
    end
    for i=1, #gvar.actorrefreshs[actorid] do
        local guildcar = gvar.guildcars[gvar.actorrefreshs[actorid][i]]
        if not guildcar then
            getRefreshCar(gvar, actorid)
            break
        end
    end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_SendPlunerList)
    LDataPack.writeInt(npack, actorid)
    LDataPack.writeChar(npack, #gvar.actorrefreshs[actorid])
    local index = 1
    local carindex = 1
    for i=1, #gvar.actorrefreshs[actorid] do
        local guildcar = gvar.guildcars[gvar.actorrefreshs[actorid][i]]
        LDataPack.writeInt(npack, gvar.actorrefreshs[actorid][i])
        LDataPack.writeString(npack, guildcar.guildname)
        LDataPack.writeChar(npack, guildcar.carlevel) --镖车等级
        LDataPack.writeChar(npack, guildcar.remainpeople) --剩余镖师数量
        LDataPack.writeChar(npack, guildcar.maxpeople)--最大镖师数量
        LDataPack.writeChar(npack, DartConstConfig.dartCarBreakNum - guildcar.plundercount)--可掠夺次数
    end
    LDataPack.writeChar(npack, getOpenIndex())
    System.sendPacketToAllGameClient(npack, sId)
end

local function onGetPlunderList(sId, sType, cpack)
    local actorid = LDataPack.readInt(cpack)
    sendPlunderList(sId, actorid)
end

--开启预告
function dartReady()
    if System.isCommSrv() then
        noticesystem.broadCastNotice(DartConstConfig.advanceNoticeId, 5)
    else
        noticesystem.broadCastCrossNotice(DartConstConfig.advanceNoticeId, 5)
    end
end

local gmindex = nil
function getOpenIndex()    
    local curhour, min, sec = System.getTime()
    if curhour == 11 then
        return 1
    elseif curhour == 18 then
        return 2
    elseif (curhour == 21 and min >=30) or (curhour == 22 and min <=30) then
        return 3
    end
    return gmindex or 0
end

--活动开启
function dartStart()
    print("dart start")
    DART_END = false
    if System.isCommSrv() then
        noticesystem.broadCastNotice(DartConstConfig.openNoticeId)
    else
        noticesystem.broadCastCrossNotice(DartConstConfig.openNoticeId)    

        local openindex = getOpenIndex()
        print("dart opneindex :", openindex)
        if openindex == 0 then
            return
        end
        local now = System.getNowTime()
        local gvar = getGlobalData()
        gvar.guildcarscount = 0

        gvar.guildcars = {}
        local guildList = LGuild.getGuildList()        
        if not guildList then return end
        for i=1, #guildList do
            local guildId = LGuild.getGuildId(guildList[i])
            local guildvar = getGuildGlobal(guildId)
            local peoplecount = #guildvar[openindex].actorlist
            if peoplecount ~= 0 then                
                if not gvar.guildcars[guildId] then gvar.guildcars[guildId] = {} end
                local guildcar = gvar.guildcars[guildId]
                local guild = LGuild.getGuildById(guildId)
                local guildlevel = guildcommon.getBuildingLevel(guild, 1)
                guildcar.guildname = LGuild.getGuilNameById(guildId)
                --int（当前护镖人数 * 5 / 护镖人数上限）+ 1 = 镖车等级,  最大五级
                guildcar.carlevel = math.min( 6, math.floor(peoplecount * 5/DartConstConfig.dartCarNumber[guildlevel] + 1)) --镖车等级                
                print("dartStart guildId :", guildId, peoplecount, guildcar.carlevel)
                guildcar.remainpeople = peoplecount + #DartRobotConfig[guildcar.carlevel]
                guildcar.maxpeople = peoplecount + #DartRobotConfig[guildcar.carlevel]
                guildcar.plundercount = guildcar.plundercount or 0
                dartrank.addGuildRecord(guildId, 1, guildcar.carlevel,nil,nil,nil,nil,nil,peoplecount)
                local guildvar = getGuildGlobal(guildId)
                for kk,vv in ipairs(guildvar[openindex].actorlist) do
                    vv.hpper = 100 --镖师血量百分比
                    dartrank.addSelfRecord(vv.actorid, 1, guildcar.carlevel)
                end
                gvar.guildcarscount = gvar.guildcarscount + 1
            end
        end
        System.saveStaticDart()
    end    
end

--结算
function settlement(index)
    print("settlement index:",index)
    if index == 0 then return end

    local gvar = getGlobalData()
    for guildId, v in pairs(gvar.guildcars) do
        local guild = LGuild.getGuildById(guildId)
        if not guild then return end
        print(" settlement guildId: ",guildId, " plundercount ",v.plundercount)
        v.plundercount = v.plundercount or 0
        if v.plundercount > DartConstConfig.dartCarBreakNum then
            v.plundercount = DartConstConfig.dartCarBreakNum 
        end        
        local conf = DartCarLevelRewardConfig[v.carlevel][v.plundercount]
        dartrank.addGuildRank(gvar, guildId, conf.guild_score)
        dartrank.addGuildRecord(guildId, 2, v.carlevel, v.plundercount, conf.guild_score, conf.personal_score)
        local guildvar = getGuildGlobal(guildId)
        guildvar[index].plundercount = v.plundercount        
        for kk,vv in ipairs(guildvar[index].actorlist) do
            print("settlement actorid:", vv.actorid)
            dartrank.addSelfRank(gvar, vv.actorid, vv.serverid, conf.personal_score, vv.name, guildId, true)
            dartrank.sendSelfMail(vv.actorid, v.carlevel, vv.serverid, conf.personal_score)
            dartrank.addSelfRecord(vv.actorid, 2, v.carlevel, conf.guild_score, conf.personal_score)
        end        
    end
    dartrank.settlementSort(gvar)
    
    System.saveStaticDart()
end

--活动结束
function dartEnd()
    DART_END = true
    if not System.isBattleSrv() then return end
    print("----------dartEnd ----------")
    local index = 0
    local curhour, min, sec = System.getTime()
    if curhour == 12 then
        index = 1
    elseif curhour == 19 then
        index = 2
    elseif curhour == 22 then
        index = 3
    end
    settlement(index)
    dartFinish()    
end

function dartFinish()
    local gvar = getGlobalData()
    gvar.guildcarscount = 0
    gvar.guildcars = {}  
end

function gameStartCheck()
    local openindex = getOpenIndex()
    if openindex == 0 then
        dartFinish()
    else
        dartStart()
    end
end

local function OnGameStart()
    if not System.isBattleSrv() then return end
    LActor.postScriptEventLite(nil, 3 * 1000, gameStartCheck)    
end

_G.dartReady = dartReady
_G.dartStart = dartStart
_G.dartEnd = dartEnd

engineevent.regGameStartEvent(OnGameStart)

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_ChooseCar, onChooseCar)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_GetCarList, onGetCarList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_RefreshPlunerList, onRefreshPlunderList)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_GetPlunerList, onGetPlunderList)


local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.dartjoin = function ( actor, args )
    if not System.isBattleSrv() then return end
    local index = tonumber(args[1])
    local guildId = LActor.getGuildId(actor)
    local guild = LGuild.getGuildById(guildId)
    local member = LGuild.getMemberIdList(guild)
    for k,v in ipairs(member) do
        changeChoose(index, guildId, v, 10101, 88888, "aid:"..v)
    end
    return true
end

gmCmdHandlers.dartstart = function ( actor, args )
    if not System.isCommSrv() then return end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_GMOpenDart)
    LDataPack.writeInt(npack, tonumber(args[1]))
    System.sendPacketToAllGameClient(npack, 0)
    return true
end

local function onGmDartStart(sId, sType, cpack)
    local index = LDataPack.readInt(cpack)
    DART_END = false
    if System.isCommSrv() then
        noticesystem.broadCastNotice(DartConstConfig.openNoticeId)
    else
        noticesystem.broadCastCrossNotice(DartConstConfig.openNoticeId)    

        local openindex = index
        gmindex = index
        local now = System.getNowTime()
        local gvar = getGlobalData()
        gvar.guildcarscount = 0

        local guildList = LGuild.getGuildList()        
        if not guildList then return end
        for i=1, #guildList do
            local guildId = LGuild.getGuildId(guildList[i])
            local guildvar = getGuildGlobal(guildId)
            local peoplecount = #guildvar[openindex].actorlist
            print("------------------ guildid = "..guildId.. " peoplecount = ".. peoplecount)
            if peoplecount ~= 0 then
                if not gvar.guildcars[guildId] then gvar.guildcars[guildId] = {} end
                local guildcar = gvar.guildcars[guildId]
                local guild = LGuild.getGuildById(guildId)
                local guildlevel = guildcommon.getBuildingLevel(guild, 1)
                guildcar.guildname = LGuild.getGuilNameById(guildId)
                --int（当前护镖人数 * 5 / 护镖人数上限）+ 1 = 镖车等级,  最大五级
                guildcar.carlevel = math.min( 6, math.floor(peoplecount * 5/DartConstConfig.dartCarNumber[guildlevel] + 1)) --镖车等级
                guildcar.remainpeople = peoplecount + #DartRobotConfig[guildcar.carlevel]
                guildcar.maxpeople = peoplecount + #DartRobotConfig[guildcar.carlevel]
                guildcar.plundercount = guildcar.plundercount or 0
                dartrank.addGuildRecord(guildId, 1, guildcar.carlevel,nil,nil,nil,nil,nil,peoplecount)
                local guildvar = getGuildGlobal(guildId)
                for kk,vv in ipairs(guildvar[openindex].actorlist) do
                    vv.hpper = 100 --镖师血量百分比
                    dartrank.addSelfRecord(vv.actorid, 1, guildcar.carlevel)
                end
                gvar.guildcarscount = gvar.guildcarscount + 1
            end
        end
    end
    System.saveStaticDart()
end

gmCmdHandlers.dartend = function ( actor, args )
    if not System.isCommSrv() then return end    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_GMOpenEnd)
    LDataPack.writeInt(npack, tonumber(args[1]))
    System.sendPacketToAllGameClient(npack, 0)
    return true
end

local function onGmDartEnd(sId, sType, cpack)
    local index = LDataPack.readInt(cpack)
    settlement(index)
    dartFinish()
end

local function onGmCarLevel(sId, sType, cpack)
    local gvar = getGlobalData()
    local guildId = LDataPack.readInt(cpack)
    local guildcar = gvar.guildcars[guildId]
    if not guildcar then return end
    guildcar.carlevel = LDataPack.readChar(cpack)
end

gmCmdHandlers.carlevel = function ( actor, args )
    if not System.isCommSrv() then return end    
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, CrossSrvCmd.SCGuildDartCmd)
    LDataPack.writeByte(npack, CrossSrvSubCmd.SCGuildDartCmd_GMCarLevel)
    LDataPack.writeInt(npack, LActor.getGuildId(actor))
    LDataPack.writeChar(npack, tonumber(args[1]))
    System.sendPacketToAllGameClient(npack, 0)
    return true
end

csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_GMOpenDart, onGmDartStart)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_GMOpenEnd, onGmDartEnd)
csmsgdispatcher.Reg(CrossSrvCmd.SCGuildDartCmd, CrossSrvSubCmd.SCGuildDartCmd_GMCarLevel, onGmCarLevel)


