--野外pk
module("pksystem", package.seeall)

DefRobotId = 1
MAX_LIST = 4
MAX_RECORD = 50

function getStaticVar(actor)
    local var = LActor.getStaticVar(actor)
    if not var.pk then
        var.pk = {}
        var.pk.tiredvalue = 0
        var.pk.pkvalue = 0
        var.pk.wintimes = 0
        var.pk.isfirst = 0 --是否是第一次刷新，第一次刷出的是指定机器人
        var.pk.isfirstset = 0 
        var.pk.rivals = {}
        var.pk.refreshtime = 0 --上一次刷新对手时间
        var.pk.reftiredtime = 0 --上一次刷新疲劳值时间
        var.pk.recordcount = 0
        var.pk.record = {} --pk记录
        var.pk.usetimes = 0 --内挂助手消耗次数
        local rivals = var.pk.rivals
        rivals.count = 0
        for i=1, MAX_LIST do
            rivals[i] = {}
            rivals[i].actorid = 0
            rivals[i].fbid = 0
            rivals[i].name = ""
            rivals[i].level = 0            
            rivals[i].total_power = 0
            rivals[i].job = {}
            rivals[i].jobcount = 0
            rivals[i].plunderCnt = 0
            for j=1, 3 do
                rivals[i].job[j] = 0
            end
        end
        
    end
    return var.pk
end

function getDyanmicVar(actor)
    local var = LActor.getGlobalDyanmicVar(actor)
    if not var.pkdata then
        var.pkdata = {}
        var.pkdata.pkindex = 0
        var.pkdata.pkactorid = 0
        var.pkdata.targetfbid = 0
    end
    return var.pkdata    
end
--减少对手
function decreaseRival(actor, index)
    local data = getStaticVar(actor)
    local rivals = data.rivals
    if index == rivals.count then
        rivals[index].actorid = 0
        rivals[index].fbid = 0
        rivals[index].name = ""
        rivals[index].level = 0            
        rivals[index].total_power = 0
        rivals[index].job = {}
        rivals[index].plunderCnt = 0
        rivals[index].jobcount = 0        
        for j=1, rivals[index].jobcount do
            rivals[index].job[j] = 0
        end
    else
        for i=index, rivals.count - 1 do
            rivals[i].actorid = rivals[i+1].actorid
            rivals[i].fbid = rivals[i+1].fbid
            rivals[i].name = rivals[i+1].name
            rivals[i].level = rivals[i+1].level
            rivals[i].total_power = rivals[i+1].total_power
            rivals[i].plunderCnt = rivals[i+1].plunderCnt
            rivals[i].jobcount = rivals[i+1].jobcount or 0
            for j=1, rivals[i+1].jobcount do
                rivals[i].job[j-1] = rivals[i+1].job[j-1]
            end
        end
    end
    rivals.count = rivals.count - 1
end

--生成对手
function challengActor(actor, index, sceneHandle, x, y, revengeRival)
    local data = getStaticVar(actor)
    local rival = revengeRival or data.rivals[index]
    
    --删除挂机副本中的同名玩家
    guajifuben.deleteActorClone(actor, rival.name)
    
    local roleCloneDatas, damonData, roleSuperData
    if PkRobotConfig[rival.actorid] then --是个机器人
        roleCloneDatas, damonData, roleSuperData = actorcommon.createRobotClone(PkRobotConfig, rival.actorid)
    else
        roleCloneDatas, damonData, roleSuperData = actorcommon.getCloneData(rival.actorid)
		if roleCloneDatas then
			for i = 1, #roleCloneDatas do
				local roleCloneData = roleCloneDatas[i]
				roleCloneData.ai = FubenConstConfig.jobAi[roleCloneData.job]
			end
			if damonData then
				damonData.ai = FubenConstConfig.damonAi
			end
		else --读不到数据时的容错处理
			roleCloneDatas, damonData, roleSuperData = actorcommon.createRobotClone(PkRobotConfig, DefRobotId)
		end
    end
    local roleCloneDataCount = #roleCloneDatas
	if roleCloneDataCount < 0 or roleCloneDataCount > MAX_ROLE then
		return
	end

	if damonData then
		local damonConf = DamonConfig[damonData.id]
		if damonConf then
			damonData.speed = damonConf.MvSpeed
		end
	end

	if roleSuperData then 
		roleSuperData.randChangeTime = math.random(FubenConstConfig.randChangeTime[1],FubenConstConfig.randChangeTime[2])
		roleSuperData.aiId = FubenConstConfig.roleSuperAi
    end

    local x, y = utils.getGuajiCloneCoor(rival.fbid)    
    local actorClone = LActor.createActorCloneWithData(actorid, sceneHandle, x, y, roleCloneDatas, damonData, roleSuperData)
    LActor.addSkillEffect(actorClone, PkConstConfig.bindEffectId)

    --额外效果
    local roleCloneCount = LActor.getRoleCount(actorClone)
	local myRoleCount = LActor.getRoleCount(actor)
	local maxIndex = myRoleCount > roleCloneCount and myRoleCount or roleCloneCount
	local extraEffectId = PkConstConfig.extraEffectIds[maxIndex]
	if extraEffectId then
		LActor.addSkillEffect(actor, extraEffectId)
		LActor.addSkillEffect(actorClone, extraEffectId)
		data.extraEffectId = extraEffectId
	end

    sendHandle(actor, LActor.getHandle(actorClone))
    --LActor.setAITarget(roleCloneDatas[1], LActor.getBattleLiveByOrder(actor))
    if data.tiredvalue == 0 then
        data.reftiredtime = os.time()
    end
    data.tiredvalue = data.tiredvalue + PkConstConfig.addtired * data.usetimes
    if not revengeRival then
        decreaseRival(actor, index)
    end
    checkRefreshRival(actor)
    sendPkInfo(actor)

    LActor.delSkillEffect(actor, guajifuben.guajiBufferId)
end

--发送场景镜像handle，玩家去攻击该镜像
function sendHandle(actor, handle)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_PK, Protocol.sPkCmd_PkHandle)    
    LDataPack.writeDouble(pack, handle)
    LDataPack.flush(pack)
end

--检查是否可刷新对手
function checkRefreshRival(actor)
    local data = getStaticVar(actor)    
    local ischange = false
    if data.isfirst ~= 0 and data.rivals.count < MAX_LIST then
        local maxneed = MAX_LIST - data.rivals.count
        if os.time() - data.refreshtime >= PkConstConfig.refreshtime then
            for i=1, math.min(4, (os.time() - data.refreshtime)/PkConstConfig.refreshtime) do
                if i <= maxneed then
                    refreshRivalList(actor)
                    ischange = true
                end
            end
        end
    end
    return ischange    
end

--进入副本
function onEnterFb(ins, actor)
    local dydata = getDyanmicVar(actor)
    if dydata.pkindex == 0 then
        return
    end
    if dydata.targetfbid ~= ins.id then
        challengeFail(actor, true)
        LActor.addSkillEffect(actor, guajifuben.guajiBufferId)
        return
    end

    local posx, posy = LActor.getEntityScenePos(actor)
    challengActor(actor, dydata.pkindex, ins.scene_list[1], posx, posy)
end

--离开副本
function onExitFb(ins, actor)
    local dydata = getDyanmicVar(actor)
    if dydata.pkindex == 0 then
        return
    end
    if dydata.targetfbid == ins.id then
        local guajiFuben = guajifuben.getActorVar(actor)
        guajiFuben.fbid = custom.getMaxFubenId(actor)
        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_BeforGuajifuben)    
        LDataPack.writeInt(pack, guajiFuben.fbid)
        LDataPack.flush(pack)
        challengeFail(actor, true)
        return
    end
end

--挑战玩家
function c2sChallenge(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.pk) then return end
    local index = LDataPack.readChar(pack) --挑战第几个    
    local data = getStaticVar(actor)
    if index == 0 then
        return
    end
    if index > data.rivals.count then
        return
    end
    local dydata = getDyanmicVar(actor)    
    if dydata.pkindex ~= 0 then
        chatcommon.sendSystemTips(actor, 1, 2, ScriptTips.pk01)
        return
    end
    local maxfuben = custom.getMaxFubenId(actor)
    if data.rivals[index].fbId > maxfuben then
        return
    end
    --疲劳值超过多少不可以继续挑战
    if data.tiredvalue >= PkConstConfig.maxtired then
        return
    end

    for k,v in ipairs(PkConstConfig.tiredusetimes) do
        if data.tiredvalue < v[1] then
            data.usetimes = math.min(neigua.checkOpenNeigua(actor, 0), v[2])
            break
        end    
    end

    dydata.pkindex = index
    dydata.pkactorid = data.rivals[index].actorid
    dydata.targetfbid = data.rivals[index].fbId    
    checkTiredTime(actor)

    local fbid = LActor.getFubenId(actor)
    if data.rivals[index].fbId == fbid then
        local sceneHandle = LActor.getSceneHandle(actor)
        local posx, posy = LActor.getEntityScenePos(actor)
        challengActor(actor, index, sceneHandle, posx, posy)
    else
        local fbHandle = instancesystem.createFuBen(data.rivals[index].fbId)
        if not fbHandle or fbHandle == 0 then print("enterPlotFuben:create fb fail") return end
        local posX, posY = utils.getSceneEnterCoor(data.rivals[index].fbId)
        LActor.enterFuBen(actor, fbHandle, -1, posX, posY)
    end
end


--花钻石减少疲劳值
function c2sClearTired(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.pk) then return end
    local data = getStaticVar(actor)
    if data.tiredvalue == 0 then
        return
    end

    if not actoritem.checkItem(actor, NumericType_YuanBao, PkConstConfig.needyuanbao) then
		return
	end
    actoritem.reduceItem(actor, NumericType_YuanBao, PkConstConfig.needyuanbao, "pksystem reduce tiredvalue")
    
    data.tiredvalue = data.tiredvalue - PkConstConfig.cleartired
    if data.tiredvalue < 0 then
        data.tiredvalue = 0
    end
    sendPkInfo(actor)
end

--野外pk界面信息
function sendPkInfo(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_PK, Protocol.sPkCmd_SystemInfo)    
    if not pack then return end
    local data = getStaticVar(actor)
    LDataPack.writeInt(pack, data.pkvalue)
    LDataPack.writeShort(pack, pkrank.getrank(actor)) --排行榜排名
    LDataPack.writeShort(pack, data.wintimes)
    LDataPack.writeShort(pack, data.tiredvalue)
    LDataPack.writeChar(pack, data.rivals.count)
    for i=1, data.rivals.count do
        LDataPack.writeInt(pack, data.rivals[i].fbid)
        LDataPack.writeInt(pack, data.rivals[i].plunderCnt or 0)
        LDataPack.writeChar(pack, i)
        LDataPack.writeString(pack, data.rivals[i].name)
        LDataPack.writeInt(pack, data.rivals[i].level)
        LDataPack.writeInt(pack, data.rivals[i].total_power)
        LDataPack.writeChar(pack, data.rivals[i].jobcount)
        for j=0, data.rivals[i].jobcount - 1 do
            LDataPack.writeChar(pack, data.rivals[i].job[j])
        end
    end
	LDataPack.flush(pack)
end

--当前疲劳值
function sendTiredValue(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_PK, Protocol.sPkCmd_CurTired)    
    if not pack then return end
    local data = getStaticVar(actor)
    LDataPack.writeShort(pack, data.tiredvalue)
    LDataPack.writeChar(pack, PkConstConfig.reducetired - (os.time() - data.reftiredtime > 0 and (os.time() - data.reftiredtime) or 0))
    LDataPack.flush(pack)
end

--挑战结果
function sendChallengeResult(actor, result, items, plundercount, times)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_PK, Protocol.sPkCmd_Challenge)    
    if not pack then return end
    local data = getStaticVar(actor)
    LDataPack.writeChar(pack, times)
    LDataPack.writeChar(pack, result)
    LDataPack.writeShort(pack, data.wintimes)    
    LDataPack.writeChar(pack, #items)
    for i=1, #items do
        LDataPack.writeInt(pack, items[i].type)
        LDataPack.writeInt(pack, items[i].id)
        LDataPack.writeInt(pack, items[i].count)
    end
    LDataPack.writeInt(pack, plundercount)
    LDataPack.flush(pack)
end

function checkTiredTime(actor)
    local data = getStaticVar(actor)
    if data.tiredvalue > 0 then
        data.tiredvalue = data.tiredvalue - math.floor((os.time() - data.reftiredtime)/PkConstConfig.reducetired)
        if data.tiredvalue < 0 then
            data.tiredvalue = 0
        end
        data.reftiredtime = os.time() - (os.time() - data.reftiredtime) % PkConstConfig.reducetired
        sendTiredValue(actor)
    end
end

--打开系统界面
function c2sOpenWindow(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.pk) then return end
    updateRivalInfo(actor)
    checkRefreshRival(actor)
    sendPkInfo(actor)
    checkTiredTime(actor)
end

--策划要求一打开野外pk界面就更新列表信息
function updateRivalInfo(actor)
    local data = getStaticVar(actor)
    for i=1, data.rivals.count do
        if PkRobotConfig[data.rivals[i].actorid] == nil then
            local roleCloneDatas = actorcommon.getCloneData(data.rivals[i].actorid)
            if not roleCloneDatas then
                return
            end
            
            data.rivals[i].plunderCnt = math.floor(roleCloneDatas[1].plunderCnt / 2)
            data.rivals[i].name = roleCloneDatas[1].name
            data.rivals[i].level = roleCloneDatas[1].level
            data.rivals[i].total_power = roleCloneDatas[1].total_power
            data.rivals[i].job = {}
            data.rivals[i].jobcount = #roleCloneDatas
            for j=1, #roleCloneDatas do        
                data.rivals[i].job[j-1] = roleCloneDatas[j].job
            end
        end
    end
end

local function onInit(actor)
    --刷新对手,初始化刷新对手    
    local data = getStaticVar(actor)
    if data.isfirstset == 0 then
        --刷新指定机器人   
        setRobot(data, 1)
        data.isfirstset = 1
    end
end

--刷新对手
function refreshRivalList(actor, isAll)
    local data = getStaticVar(actor)
    if isAll then
        data.rivals.count = 0
        for i=1, MAX_LIST do
            refreshOneRival(actor)
        end
    else
        refreshOneRival(actor)
    end
    data.refreshtime = os.time()
end

--刷新一个对手
function refreshOneRival(actor)
    local data = getStaticVar(actor)
    if data.rivals.count == MAX_LIST then
        assert(false)
    end
    local meid = LActor.getId(actor)
    local mepower = LActor.getActorPower(meid)
    local needsmall = false
    for i=1, data.rivals.count do
        if mepower <= data.rivals[i].total_power then --如果有战力比自身高的，则刷新比自己战力低的玩家或者数据
            needsmall = true
        end
    end
    local isfind = false    
    local maxfuben = custom.getMaxFubenId(actor)
    local fbid = maxfuben
    repeat
        if isfind then break end        
        local sysdata = guajifuben.getSystemVar(fbid)
        if sysdata.count > 0 then
            for rivalid in pairs(sysdata.actors) do
                if not checkIsHave(data, rivalid, meid) then
                    local roleCloneDatas = actorcommon.getCloneData(rivalid)
                    if not roleCloneDatas then
                        break
                    end
                    local power = LActor.getActorPower(rivalid)
                    if needsmall and power < mepower then                            
                        setRival(roleCloneDatas, data, rivalid, fbid)
                        isfind = true
                        break
                    elseif not needsmall and power > mepower then
                        setRival(roleCloneDatas, data, rivalid, fbid)
                        isfind = true
                        break
                    end
                end
            end
        end
        fbid = fbid - 1   
    until(fbid < CustomFubenConfig[0].maxfuben)
    
    fbid=maxfuben
    repeat
        if isfind then break end
        local sysdata = guajifuben.getSystemVar(fbid)
        if sysdata.count > 0 then
            for rivalid in pairs(sysdata.actors) do
                if not checkIsHave(data, rivalid, meid) then
                    local roleCloneDatas = actorcommon.getCloneData(rivalid)
                    if not roleCloneDatas then
                        break
                    end
                    setRival(roleCloneDatas, data, rivalid, fbid)
                    isfind = true
                    break
                end
            end
        end
        fbid = fbid - 1
    until(fbid < CustomFubenConfig[0].maxfuben)

    if not isfind then --如果还没有玩家，则匹配机器人
        local maxindex = getMaxIndex(maxfuben)
        if not maxindex then
            return
        end
        local randRobot = maxindex
        for i=1, 10 do
            randRobot = math.random(2, maxindex)
            local ishave = false
            for i=1, data.rivals.count do
                if data.rivals[i].actorid == randRobot then
                    ishave = true
                    break
                end
            end
            if not ishave then
                break
            end
        end
        setRobot(data, randRobot)
    end
end

--检查列表中是否已有该玩家
function checkIsHave(data, rivalid, meid)
    if meid == rivalid then
        return true
    end
    for i=1, data.rivals.count do
        if data.rivals[i].actorid == rivalid then
            return true
        end
    end
    return false
end

--得到机器人配置表中最大索引
function getMaxIndex(maxfuben)
    for i = #PkRobotConfig, 1, -1 do
        if PkRobotConfig[i][0].fbid <= maxfuben then
            return i
        end
    end
end

--设置玩家信息
function setRival(roleCloneDatas, data, rivalid, fbid)
    data.rivals.count = data.rivals.count + 1
    local index = data.rivals.count
    data.rivals[index].actorid = rivalid
    data.rivals[index].fbid = fbid
    data.rivals[index].plunderCnt = math.floor(roleCloneDatas[1].plunderCnt / 2)
    data.rivals[index].name = roleCloneDatas[1].name
    data.rivals[index].level = roleCloneDatas[1].level
    data.rivals[index].total_power = roleCloneDatas[1].total_power
    data.rivals[index].job = {}
    data.rivals[index].jobcount = #roleCloneDatas
    for j=1, #roleCloneDatas do        
        data.rivals[index].job[j-1] = roleCloneDatas[j].job
    end
end

--设置机器人信息
function setRobot(data, robotIndex)
    local count = 0
    for k in pairs(PkRobotConfig[robotIndex]) do
        count = count + 1
    end
    data.rivals.count = data.rivals.count + 1
    data.rivals[data.rivals.count].actorid = robotIndex
    data.rivals[data.rivals.count].fbid = PkRobotConfig[robotIndex][0].fbid
    data.rivals[data.rivals.count].plunderCnt = math.floor(PkRobotConfig[robotIndex][0].itemcnt / 2)
    data.rivals[data.rivals.count].name = PkRobotConfig[robotIndex][0].name
    data.rivals[data.rivals.count].level = PkRobotConfig[robotIndex][0].level          
    data.rivals[data.rivals.count].total_power = PkRobotConfig[robotIndex][0].power
    data.rivals[data.rivals.count].job = {}
    data.rivals[data.rivals.count].jobcount = count
    for j=0, count-1 do
        data.rivals[data.rivals.count].job[j] = PkRobotConfig[robotIndex][j].job
    end
end

local function onLogin(actor)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.pk) then return end
    local actorId = LActor.getActorId(actor)
    local tData = offlinedatamgr.GetDataByOffLineDataType(actorId, offlinedatamgr.EOffLineDataType.EOperable)
    if tData then
        local itemCnt = actoritem.getItemCount(actor, PkConstConfig.itemId)
        actoritem.reduceItem(actor, PkConstConfig.itemId, itemCnt - tData.plunderCnt)
        local data = getStaticVar(actor)
        data.recordcount = tData.recordcount
        for i=1, tData.recordcount do
            data.record[i] = {}
            data.record[i].time = tData.record[i].time
            data.record[i].actorid = tData.record[i].actorid
            data.record[i].name = tData.record[i].name
            data.record[i].camp = tData.record[i].camp
            data.record[i].result = tData.record[i].result
            data.record[i].plunderCnt = tData.record[i].plunderCnt
            data.record[i].isrevenge = tData.record[i].isrevenge
        end
    end
    checkRefreshRival(actor)
    sendPkInfo(actor)
    checkTiredTime(actor)
end

local function onLevelUp(actor, level, oldLevel)
    local lv = actorexp.getLimitLevel(nil, actorexp.LimitTp.pk)
	if lv > oldLevel and lv <= level then
		sendPkInfo(actor)
	end
end

--登出， 如果玩家还没有挑战完成对手，则认为失败
local function onLogout(actor)
    local dydata = getDyanmicVar(actor)
    if dydata.pkindex == 0 then
        return
    end
    challengeFail(actor)
end

--战斗记录
function addChallengeRecord(actor, beAttactId, result, count, isrevenge)
    local data = getStaticVar(actor)
    if isrevenge then
        for i = data.recordcount, 1, -1 do
            if data.record[i].actorId == beAttactId and data.record[i].isrevenge == 0 and result == 1 then
                data.record[i].isrevenge = 1
                break
            end
        end
    end
    local tname = ""
    --被挑战玩家
    if not isrevenge or (isrevenge and result == 1) then
        if PkRobotConfig[beAttactId] then
            tname = PkRobotConfig[beAttactId][0].name
        else
            local clonedata
            local actorClone = LActor.getActorById(beAttactId)
            if actorClone then --玩家在线
                clonedata = getStaticVar(actorClone)
                tname = LActor.getName(actorClone)
            else
                local actorCloneData = offlinedatamgr.GetDataByOffLineDataType(beAttactId, offlinedatamgr.EOffLineDataType.EOperable)
                if not actorCloneData then
                    return
                end
                clonedata = actorCloneData
                tname = offlinedatamgr.GetDataByOffLineDataType(beAttactId, offlinedatamgr.EOffLineDataType.EBasic).actor_name
            end
            dealRecord(clonedata, LActor.getActorId(actor), LActor.getName(actor), 1, result, count)
        end
    end
    --挑战玩家
    if not isrevenge then 
        dealRecord(data, beAttactId, tname, 0, result, count)
    end
end

--战斗记录封装
function dealRecord(data, actorid, name, camp, result, count)
    data.recordcount = data.recordcount + 1
    if data.recordcount > MAX_RECORD then
        data.recordcount = MAX_RECORD
    end
    
    for i = data.recordcount, 2, -1 do
        if not data.record[i] then data.record[i] = {} end
        data.record[i].time = data.record[i - 1].time
        data.record[i].actorid = data.record[i - 1].actorid
        data.record[i].name = data.record[i - 1].name
        data.record[i].camp = data.record[i - 1].camp
        data.record[i].result = data.record[i - 1].result
        data.record[i].plunderCnt = data.record[i - 1].plunderCnt
        data.record[i].isrevenge = data.record[i - 1].isrevenge
    end
    data.record[1] = {}
    data.record[1].time = System.getNowTime()
    data.record[1].actorid = actorid
    data.record[1].name = name
    data.record[1].camp = camp
    data.record[1].result = result    
    data.record[1].plunderCnt = count
    data.record[1].isrevenge = 0
end

--发送战斗记录
function c2sSendRecord(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_PK, Protocol.sPkCmd_Record)
    local data = getStaticVar(actor)
    print("xxxxxxxxxxxxxxxxxxxxxxxxxx", data.recordcount)
    LDataPack.writeShort(pack, data.recordcount)
    for i=1, data.recordcount do
        LDataPack.writeShort(pack, i)
        LDataPack.writeInt(pack, data.record[i].time)
        LDataPack.writeDouble(pack, data.record[i].actorid)
        LDataPack.writeString(pack, data.record[i].name)
        LDataPack.writeChar(pack, data.record[i].camp)
        LDataPack.writeChar(pack, data.record[i].result)
        LDataPack.writeInt(pack, data.record[i].plunderCnt)
        LDataPack.writeChar(pack, data.record[i].isrevenge)
    end
    LDataPack.flush(pack)
end

function getRecordCount(actor)
    local data = getStaticVar(actor)
    return data.recordcount
end

--获取战斗数据，离线时调用
function getRecord(actor)
    local data = getStaticVar(actor)
    return data.record
end

--挑战对手死亡,胜利
function onActorCloneDie(ins, killHdl, actorClone)
    local et = LActor.getEntity(killHdl)
    local attacker = LActor.getEntityType(et)
    if EntityType_Actor ~= attacker and EntityType_Role ~= attacker and EntityType_RoleSuper ~= attacker then
        return
    end
    local actor = LActor.getActor(et)
    local dydata = getDyanmicVar(actor)
    local data = getStaticVar(actor)
    local items = {}
    local count = dealPlunderItem(dydata.pkactorid)
    for times=1, data.usetimes do
        if data.isfirst == 0 then
            refreshRivalList(actor, true)
            data.isfirst = 1
        end
        data.wintimes = data.wintimes + 1
        local wintimes = PkConstConfig.vicpkvalue[data.wintimes] and data.wintimes or #PkConstConfig.vicpkvalue
        data.pkvalue = data.pkvalue + PkConstConfig.vicpkvalue[wintimes]
        pkrank.updateRankingList(actor, data.pkvalue)

        --掉落物品        
        local level = LActor.getLevel(actor)
        for i=1, #PkKillConfig do
            if level >= PkKillConfig[i].level[1] and level <= PkKillConfig[i].level[2] then
                local awards = drop.dropGroup(PkKillConfig[i].vrewards)
                local monPosX, monPosY = LActor.getEntityScenePoint(actor)
                ins:addDropBagItem(actor, awards, 100, monPosX, monPosY)
                actoritem.addItems(actor, PkKillConfig[i].vrewardsmust, "pk victory")
                for j=1, #PkKillConfig[i].vrewardsmust do
                    local ishave = false
                    for cnt = 1, #items do 
                        if PkKillConfig[i].vrewardsmust[j].id == PkConstConfig.itemId then                            
                            items[cnt].count = items[cnt].count + PkKillConfig[i].vrewardsmust[j].count
                            ishave = true
                            break
                        end
                    end
                    if not ishave then
                        items[#items + 1] = {}
                        items[#items].type = PkKillConfig[i].vrewardsmust[j].type
                        items[#items].id = PkKillConfig[i].vrewardsmust[j].id
                        items[#items].count = PkKillConfig[i].vrewardsmust[j].count
                    end
                end
                for j=1, #awards do
                    items[#items].type = awards[j].type
                    items[#items].id = awards[j].id
                    items[#items].count = awards[j].count
                    table.insert(items, awards[j])
                end            
            end
        end
        
        for i=1, #items do
            if items[i].id == PkConstConfig.itemId then
                items[i].count = items[i].count + count
                actoritem.addItem(actor, PkConstConfig.itemId, count, "pk victory")
                break
            end
        end
        
    end    

    sendChallengeResult(actor, 1, items, count, data.usetimes)
    addChallengeRecord(actor, dydata.pkactorid, 1, count, dydata.pkindex > MAX_LIST)
    sendPkInfo(actor)
    checkTiredTime(actor)

    dydata.pkindex = 0
    dydata.targetfbid = 0
    dydata.pkactorid = 0

    actorevent.onEvent(actor, aePkCnt, data.usetimes)
    
    local fbId = LActor.getFubenId(actor)
    if FubenConfig[fbId].type == 1 then
        LActor.addSkillEffect(actor, guajifuben.guajiBufferId)
    end
    local monPosX, monPosY = LActor.getEntityScenePoint(actor)
    LActor.recover(actor)
    if data.extraEffectId then
        LActor.delSkillEffect(actor, data.extraEffectId)
    end
end

--挑战玩家的掠夺道具处理
function dealPlunderItem(actorid)
    local count = 0
    if PkRobotConfig[actorid] then
        count = math.floor(PkRobotConfig[actorid][0].itemcnt / 2)
    else
        local actor = LActor.getActorById(actorid)
        if actor then
            count = math.floor(actoritem.getItemCount(actor, PkConstConfig.itemId) / 2)
            actoritem.reduceItem(actor, PkConstConfig.itemId, count)
                        
            local pack = LDataPack.allocPacket(actor, Protocol.CMD_PK, Protocol.sPkCmd_BePlunder)    
            LDataPack.flush(pack)
        else
            local actorData = offlinedatamgr.GetDataByOffLineDataType(actorid, offlinedatamgr.EOffLineDataType.EOperable)
            if not actorData then
                return 0
            end
            count = math.floor(actorData.plunderCnt / 2)
            actorData.plunderCnt = actorData.plunderCnt - count
        end
    end
    return count
end

function c2sAfterPickItem(actor, pack)
    guajifuben.enterGuajiFuben(actor, custom.getMaxFubenId(actor))
end

--玩家死亡
function onActorDie(ins, actor, killHdl)
    local et = LActor.getEntity(killHdl)
    if not et then return end
    local dydata = getDyanmicVar(actor)
    if dydata.pkindex == 0 then
        return
    end
    local attacker = LActor.getEntityType(et)    
    if EntityType_ActorClone == attacker or EntityType_RoleClone == attacker or EntityType_RoleSuperClone == attacker then --挑战失败
        challengeFail(actor)
        LActor.deleteActorClone(et)
        LActor.addSkillEffect(actor, guajifuben.guajiBufferId)
        local data = getStaticVar(actor)
        if data.extraEffectId then
            LActor.delSkillEffect(actor, data.extraEffectId)
        end
    end    
end

--挑战失败
function challengeFail(actor, notShow)
    local dydata = getDyanmicVar(actor)
    if dydata.pkindex == 0 then
        return
    end
    
    local data = getStaticVar(actor)
    local items = {}
    for times=1, data.usetimes do
        data.pkvalue = data.pkvalue + PkConstConfig.failpkvalue
        pkrank.updateRankingList(actor, data.pkvalue)
        data.wintimes = 0
        
        local level = LActor.getLevel(actor)
        for i=1, #PkKillConfig do
            if level >= PkKillConfig[i].level[1] and level <= PkKillConfig[i].level[2] then
                local awards = drop.dropGroup(PkKillConfig[i].frewards)
                actoritem.addItems(actor, awards, "pk")            
                actoritem.addItems(actor, PkKillConfig[i].frewardsmust, "pk fail")
                for j=1, #PkKillConfig[i].frewardsmust do
                    local ishave = false
                    for cnt = 1, #items do 
                        if PkKillConfig[i].frewardsmust[j].id == PkConstConfig.itemId then                            
                            items[cnt].count = items[cnt].count + PkKillConfig[i].frewardsmust[j].count
                            ishave = true
                            break
                        end
                    end
                    if not ishave then
                        items[#items + 1] = {}
                        items[#items].type = PkKillConfig[i].frewardsmust[j].type
                        items[#items].id = PkKillConfig[i].frewardsmust[j].id
                        items[#items].count = PkKillConfig[i].frewardsmust[j].count
                    end
                end
                for j=1, #awards do
                    table.insert(items, awards[j])
                end            
            end
        end

        if data.isfirst == 0 then
            refreshRivalList(actor, true)
            data.isfirst = 1
        end
        
    end
    if not notShow then
        sendChallengeResult(actor, 0, items, 0, data.usetimes)
        addChallengeRecord(actor, dydata.pkactorid, 0, 0, dydata.pkindex > MAX_LIST)
    end
    dydata.pkindex = 0
    dydata.targetfbid = 0
    sendPkInfo(actor)    
    checkTiredTime(actor)
    actorevent.onEvent(actor, aePkCnt, data.usetimes)
    
    if data.extraEffectId then
        LActor.delSkillEffect(actor, data.extraEffectId)
    end
end

--复仇
function c2sRevenge(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.pk) then return end
    local targetActorId = LDataPack.readDouble(pack) --挑战玩家id
    local dydata = getDyanmicVar(actor)

    local guajiFuben = guajifuben.getActorVar(actor)
    local fbId = LActor.getFubenId(actor)
    if not FubenConfig[fbId] then
        return
    end
    if FubenConfig[fbId].type ~= 1 then 
        if not guajifuben.enterGuajiFuben(actor, guajiFuben.fbid) then
            --确保玩家必须能进入某个副本
            guajifuben.enterGuajiFuben(actor, staticfuben.defaultFubenID)
        end
    end

    local roleCloneDatas = actorcommon.getCloneData(targetActorId)
    if not roleCloneDatas then
        return
    end
    local tmp = {}
    tmp.actorid = targetActorId
    tmp.name = roleCloneDatas[1].name
    dydata.pkactorid = targetActorId
    dydata.pkindex = MAX_LIST + 1
    local sceneHandle = LActor.getSceneHandle(actor)
    local posx, posy = LActor.getEntityScenePos(actor)
    challengActor(actor, -1, sceneHandle, posx, posy, tmp)
end

local function onNewDayArrive(actor, login)
    local data = getStaticVar(actor)
    data.pkvalue = 0
    data.wintimes = 0
    sendPkInfo(actor)
end
actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeUserLogout, onLogout)
actorevent.reg(aeLevel, onLevelUp)
actorevent.reg(aeNewDayArrive, onNewDayArrive)

local function fuBenInit()
    if System.isBattleSrv() then return end
    for k,__ in pairs(GuajiFubenConfig) do
        insevent.registerInstanceEnter(k, onEnterFb)
        insevent.regActorCloneDie(k, onActorCloneDie)
        insevent.registerInstanceActorDie(k, onActorDie)
        insevent.registerInstanceExit(k, onExitFb)
	end
end

table.insert(InitFnTable, fuBenInit)

netmsgdispatcher.reg(Protocol.CMD_PK, Protocol.cPkCmd_Challenge, c2sChallenge)
netmsgdispatcher.reg(Protocol.CMD_PK, Protocol.cPkCmd_ClearTired, c2sClearTired)
netmsgdispatcher.reg(Protocol.CMD_PK, Protocol.sPkCmd_OpenPkWin, c2sOpenWindow)
netmsgdispatcher.reg(Protocol.CMD_PK, Protocol.cPkCmd_Record, c2sSendRecord)
netmsgdispatcher.reg(Protocol.CMD_PK, Protocol.cPkCmd_Revenge, c2sRevenge)
netmsgdispatcher.reg(Protocol.CMD_PK, Protocol.cPkCmd_AfterPickItem, c2sAfterPickItem)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.pk = function (actor, args)
    refreshRivalList(actor, true)
    sendPkInfo(actor)
	return true
end

gmCmdHandlers.ctired = function (actor, args)
    local data = getStaticVar(actor)
    data.tiredvalue = tonumber(args[1])
    checkTiredTime(actor)
    sendPkInfo(actor)
	return true
end

gmCmdHandlers.pkclone = function (actor, args)
    local rivalid = LActor.getActorId(actor)
    local roleCloneDatas = actorcommon.getCloneData(rivalid)
    local data = getStaticVar(actor)
    
    local index = 1
    data.rivals[index].actorid = rivalid
    data.rivals[index].fbid = 10003
    data.rivals[index].name = roleCloneDatas[1].name
    data.rivals[index].level = roleCloneDatas[1].level
    data.rivals[index].total_power = roleCloneDatas[1].total_power
    data.rivals[index].job = {}
    data.rivals[index].jobcount = #roleCloneDatas
    for j=1, #roleCloneDatas do        
        data.rivals[index].job[j-1] = roleCloneDatas[j].job
    end
    sendPkInfo(actor)
    return true
end
