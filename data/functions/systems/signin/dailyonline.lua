
--每日在线
module("dailyonline", package.seeall)

local function getStaticVar(actor)--获得人物信息函数
	local var = LActor.getStaticVar(actor)--人物信息保存在var里面
    if not var.dailyonline then var.dailyonline = {} end--这个是命名空间之类的东西
    if not var.dailyonline.startTime then var.dailyonline.startTime = 0 end--人物当天在线的起始时间
    if not var.dailyonline.onlineTime then var.dailyonline.onlineTime = 0 end--人物当天在线时间
    if not var.dailyonline.isget then var.dailyonline.isget = 0 end--人物是否得到奖励
    if not var.dailyonline.day then var.dailyonline.day = 0 end--人物在前七天内应该获得哪一天的奖励
	return var.dailyonline
end

function getReward(actor, pack)
    local var = getStaticVar(actor)
    local index = LDataPack.readShort(pack) 
    local config
    local nowadays = System.getOpenServerDay()
    if var.day == 0 then
        var.day = 1
    end
    if var.day <= 7 then 
        config = DailyOnlineConfig[var.day][index]    
    else
        for i=1,#DailyOnlineConfigSeven do
            if DailyOnlineConfigSeven[i][1].Interval_day[1] <= nowadays and DailyOnlineConfigSeven[i][1].Interval_day[2] >= nowadays then 
                config = DailyOnlineConfigSeven[i][index]
                break
            end
        end
    end
    local count = 1
    if monthcard.isBuyMonthCard(actor) then
        count = MonthCardConfig.multiple
    end
    local rewards = {}
    for k,v in ipairs(config.rewards) do
        rewards[k] = {type = v.type, id = v.id, count = v.count * count}
    end
    if not actoritem.checkEquipBagSpaceJob(actor, config.rewards) then return end
    if System.bitOPMask(var.isget, index-1) then return end
    var.isget = System.bitOpSetMask(var.isget, index-1, true)

    
    actoritem.addItems(actor, rewards, "daily oneline rewards")
    onGetReward(actor)    
end

function onGetReward(actor)
    local var = getStaticVar(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuli, Protocol.sDailyOnline_OnGetReward)
    LDataPack.writeInt(npack, var.isget)
	LDataPack.flush(npack)
end

function sendOnline(actor)--发送每日信息
    local var = getStaticVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuli, Protocol.sDailyOnline_Info)
    LDataPack.writeInt(npack, var.isget)
    LDataPack.writeInt(npack, var.onlineTime + System.getNowTime() - var.startTime)
    local nowadays = System.getOpenServerDay()
    if var.day <= 7 then 
        LDataPack.writeChar(npack,1)
        LDataPack.writeInt(npack,var.day)
    else
        LDataPack.writeChar(npack,2)
        for i=1,#DailyOnlineConfigSeven do
            if DailyOnlineConfigSeven[i][1].Interval_day[1] <= nowadays and DailyOnlineConfigSeven[i][1].Interval_day[2] >= nowadays then 
                LDataPack.writeInt(npack,i)
                break
            end
        end      
    end
	LDataPack.flush(npack)
end

function onLogin(actor)--下面这几行都是和玩家有关系的
    local var = getStaticVar(actor)
    var.startTime = System.getNowTime()
    sendOnline(actor)
end

function onNewDay(actor, login)--这是和玩家有关系的。和系统没什么关系
    local var = getStaticVar(actor)
    var.onlineTime = 0
    var.startTime = System.getNowTime()
    var.isget = 0
    var.day = var.day + 1;--玩家每上一天线就加1
    if not login then
        sendOnline(actor)
    end
end

function onLogout(actor)    
    local var = getStaticVar(actor)
    var.onlineTime = var.onlineTime + System.getNowTime() - var.startTime
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogout, onLogout)

netmsgdispatcher.reg(Protocol.CMD_Fuli, Protocol.cDailyOnline_GetReward, getReward)

local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.setOnline = function (actor, args)
    local var = getStaticVar(actor)
    local time = tonumber(args[1]) or 0
    var.startTime = System.getNowTime() - time 
    sendOnline(actor)
end
