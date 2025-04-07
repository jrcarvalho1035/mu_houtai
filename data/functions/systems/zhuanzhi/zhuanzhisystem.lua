module("zhuanzhisystem", package.seeall)
--转职系统


function getActorVar(actor, roleId)
    local var = LActor.getStaticVar(actor)
    if not var.zhuanzhiData then var.zhuanzhiData = {} end
    if not var.zhuanzhiData.taskStatus then var.zhuanzhiData.taskStatus = 0 end
    if not var.zhuanzhiData.taskProgress then var.zhuanzhiData.taskProgress = 0 end
    if not var.zhuanzhiData.taskRoleId then var.zhuanzhiData.taskRoleId = -1 end
    if not var.zhuanzhiData[0] then
        for i=0, 2 do        
            var.zhuanzhiData[i] = {}
            var.zhuanzhiData[i].count = 0
        end
    end
    return var.zhuanzhiData
end

function calcAttr(actor, roleId, calc)
    local attr = LActor.getRoleSystemAttrs(actor, roleId, AttrRoleSysId_Zhuanzhi)
    attr:Reset()
    local data = getActorVar(actor)
    local role = LActor.getRole(actor, roleId)
    local job = LActor.getJob(role)
    local config = ZhuanzhiJobConfig[job][data[roleId].count].attr
    for k,v in pairs(config) do
        attr:Set(v.type, v.value)
    end
    if calc then
		LActor.reCalcRoleAttr(actor, roleId)
	end
end
--接受任务
function c2sAcceptTask(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zhuanzhi) then return end
    local roleId = LDataPack.readChar(pack)
    local data = getActorVar(actor)
    if data.taskRoleId ~= -1 then
        return --已接其他职业的任务
    end
    local config = ZhuanzhiConfig[roleId][data[roleId].count]
    local level = LActor.getLevel(actor)
    if not ZhuanzhiConfig[roleId][data[roleId].count + 1] then
        return --已满级
    end
    if level < config.level then
        return --等级不足
    end
    if data.taskStatus ~= 0 then
        return --任务已接
    end
    if not actoritem.checkItem(actor, NumericType_Gold, config.gold) then
        return --道具不足
    end
    actoritem.reduceItem(actor, NumericType_Gold, config.gold, "zhuanzhi gold accept task:"..data[roleId].count + 1)
    
    data.taskStatus = 1
    data.taskRoleId = roleId

    sendZhuanzhiInfo(actor)
end
--完成任务
function c2sFinishTask(actor, pack)
    if not actorexp.checkLevelCondition(actor, actorexp.LimitTp.zhuanzhi) then return end
    local roleId = LDataPack.readShort(pack)
    local data = getActorVar(actor)
    if data.taskRoleId == -1 or data.taskRoleId ~= roleId then
        return --未接任务
    end
    if data.taskStatus ~= 1 then
        return --任务已完成或者未接任务
    end
    
    local config = ZhuanzhiConfig[roleId][data[roleId].count]    
    local TaskConfig = ZhuanzhiTaskConfig[config.taskid]
    if data.taskProgress < TaskConfig.target then
        return --任务进度
    end
    local itemCount = actoritem.getItemCount(actor, TaskConfig.param[1])
    actoritem.reduceItem(actor, TaskConfig.param[1], itemCount, "zhuanzhi item finish task:"..config.taskid)
    data[roleId].count = data[roleId].count + 1
    data.taskStatus = 0
    data.taskProgress = 0
    data.taskRoleId = -1
    sendZhuanzhiInfo(actor)
    calcAttr(actor, roleId, true)
    sendFinishTask(actor, roleId)
    
    local role = LActor.getRole(actor,roleId)
    local job = LActor.getJob(role)
    noticesystem.broadCastNotice(noticesystem.NTP.zhuanzhi, LActor.getName(actor), ZhuanzhiJobConfig[job][data[roleId].count].name)
end

--转职系统信息
function sendZhuanzhiInfo(actor)
    local roleCnt = LActor.getRoleCount(actor)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Job, Protocol.sZhuanzhiCmd_Info)    
    LDataPack.writeChar(pack, roleCnt)
    for i=0, roleCnt - 1 do
        local data = getActorVar(actor, i)
        LDataPack.writeChar(pack, i)
        LDataPack.writeChar(pack, data[i].count)
        LDataPack.writeInt(pack, ZhuanzhiConfig[i][data[i].count].taskid)
        if i ~= data.taskRoleId or not ZhuanzhiConfig[i][data[i].count + 1] then
            LDataPack.writeChar(pack, 0)
            LDataPack.writeShort(pack, 0)
        else
            LDataPack.writeChar(pack, data.taskStatus)
            LDataPack.writeShort(pack, data.taskProgress)
        end
    end
    LDataPack.flush(pack)
end

--更新任务
function updateTask(actor, roleId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Job, Protocol.sZhuanzhiCmd_UpdateTask)
    local data = getActorVar(actor)
    LDataPack.writeChar(pack, roleId)
    LDataPack.writeInt(pack, ZhuanzhiConfig[roleId][data[roleId].count].taskid)
    LDataPack.writeShort(pack, data.taskProgress)
    LDataPack.flush(pack)
end
--完成任务
function sendFinishTask(actor, roleId)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Job, Protocol.sZhuanzhiCmd_FinishTask)
    LDataPack.writeChar(pack, roleId)
    LDataPack.flush(pack)
end
--怪物死亡
function onMonsterDie(ins, mon, killerHdl)
    local monId = Fuben.getMonsterId(mon)
    local config = MonstersConfig[monId]
    if not config or not next(config.taskdrop) then return end
    local actor = LActor.getActor(LActor.getEntity(killerHdl))
    if not actor then return end
    local data = getActorVar(actor)
    if data.taskRoleId ~= -1 then
        local tid = ZhuanzhiConfig[data.taskRoleId][data[data.taskRoleId].count].taskid
        if tid ~= config.taskdrop.taskid or data.taskProgress >= ZhuanzhiTaskConfig[tid].target then            
            return
        end
    else
        return
    end
    local moneyRate = 1
	local tableTmp = {}
	if next(config.taskdrop) then table.insert(tableTmp, config.taskdrop) end

	local result = {}
	for _, dropConf in pairs(tableTmp) do --1~5组物品各自计算掉落
		local count = monsterdrop.randomCount(dropConf.counts, dropConf.pros) --计算掉落物品数量
		local totalPro = 10000

		for itemIdx = 1, count do  --在一组物品里随机出count个物品
			local randNumber = System.getRandomNumber(totalPro) + 1
			local itemPro = 0
			for j, itemConf in pairs(dropConf.items) do
				itemPro = itemPro + itemConf.pro
				if randNumber <= itemPro then --抽物品判断
					if itemConf.count > 0 then
                        local finalCount = itemConf.count
						if itemConf.id == NumericType_Gold then finalCount = finalCount * moneyRate end
						table.insert(result, {type = itemConf.type, id = itemConf.id, count = finalCount})
					end
					break
				end
			end
		end
    end
    if #result > 0 then
        data.taskProgress = data.taskProgress + 1
        actoritem.addItems(actor, result, "zhuanzhi task")
        updateTask(actor, data.taskRoleId)
    end
end


local function onLogin(actor)
    sendZhuanzhiInfo(actor)
end
function onCreateRole(actor, roleId)
	sendZhuanzhiInfo(actor)
end


local function onInit(actor)
    local roleCnt = LActor.getRoleCount(actor)
    for i=0, roleCnt - 1 do
        calcAttr(actor, i, false)
    end
end

function canUpgradeSkill(actor, roleId, index, level)
    local role = LActor.getRole(actor, roleId)
    local job = LActor.getJob(role)
    local data = getActorVar(actor)

    local config = ZhuanzhiJobConfig[job][data[roleId].count].skill
    if level + 1 > config[index][2] then
        return false
    end
    return true
end
actorevent.reg(aeCreateRole,onCreateRole)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_Job, Protocol.cZhuanzhiCmd_AcceptTask, c2sAcceptTask)
netmsgdispatcher.reg(Protocol.CMD_Job, Protocol.cZhuanzhiCmd_FinishTask, c2sFinishTask)

function onInitFnTable()
    --副本事件
    for fbId in pairs(GuajiFubenConfig) do
		insevent.registerInstanceMonsterDie(fbId, onMonsterDie)
	end
end


table.insert(InitFnTable, onInitFnTable)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.zztask = function (actor, arg)
    local data = getActorVar(actor)
    data.taskProgress = tonumber(arg[1])
    updateTask(actor, data.taskRoleId)
    return true
end
